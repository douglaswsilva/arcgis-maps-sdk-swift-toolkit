// Copyright 2023 Esri.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import Foundation
import ARKit
import SwiftUI
import ArcGIS

struct ARSwiftUIView {
    private(set) var alpha: CGFloat = 1.0
    private(set) var onRenderAction: ((SCNSceneRenderer, SCNScene, TimeInterval) -> Void)?
    private(set) var onCameraTrackingStateChangeAction: ((ARSession, ARCamera) -> Void)?
    private(set) var onGeoTrackingStatusChangeAction: ((ARSession, ARGeoTrackingStatus) -> Void)?
    private(set) var onProxyAvailableAction: ((ARSwiftUIView.Proxy) -> Void)?
    
    init() {
    }
    
    func alpha(_ alpha: CGFloat) -> Self {
        var view = self
        view.alpha = alpha
        return view
    }
    
    func onRender(
        perform action: @escaping (SCNSceneRenderer, SCNScene, TimeInterval) -> Void
    ) -> Self {
        var view = self
        view.onRenderAction = action
        return view
    }
    
    func onCameraTrackingStateChange(
        perform action: @escaping (ARSession, ARCamera) -> Void
    ) -> Self {
        var view = self
        view.onCameraTrackingStateChangeAction = action
        return view
    }
    
    func onGeoTrackingStatusChange(
        perform action: @escaping (ARSession, ARGeoTrackingStatus) -> Void
    ) -> Self {
        var view = self
        view.onGeoTrackingStatusChangeAction = action
        return view
    }
    
    func onProxyAvailable(
        perform action: @escaping (ARSwiftUIView.Proxy) -> Void
    ) -> Self {
        var view = self
        view.onProxyAvailableAction = action
        return view
    }
}

extension ARSwiftUIView: UIViewRepresentable {
    func makeUIView(context: Context) -> ARSCNView {
        let arView = ARSCNView()
        arView.delegate = context.coordinator
        DispatchQueue.main.async {
            onProxyAvailableAction?(Proxy(arView: arView))
        }
        return arView
    }
    
    func updateUIView(_ uiView: ARSCNView, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(arSwiftUIView: self)
    }
}

extension ARSwiftUIView {
    class Coordinator: NSObject, ARSCNViewDelegate {
        private let view: ARSwiftUIView
        
        init(arSwiftUIView: ARSwiftUIView) {
            self.view = arSwiftUIView
        }
        
        func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
            view.onRenderAction?(renderer, scene, time)
        }
        
        func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            view.onCameraTrackingStateChangeAction?(session, camera)
        }
        
        func session(_ session: ARSession, didChange geoTrackingStatus: ARGeoTrackingStatus) {
            view.onGeoTrackingStatusChangeAction?(session, geoTrackingStatus)
        }
    }
}

extension ARSwiftUIView {
    class Proxy {
        private let arView: ARSCNView
        
        init(arView: ARSCNView) {
            self.arView = arView
        }
        
        var session: ARSession {
            arView.session
        }
        
        var pointOfView: SCNNode? {
            arView.pointOfView
        }
    }
}

public struct ARGeoView3: View {
    private let scene: ArcGIS.Scene
    private let configuration: ARWorldTrackingConfiguration
    private let cameraController: TransformationMatrixCameraController
    
    /// The last portrait or landscape orientation value.
    @State private var lastGoodDeviceOrientation = UIDeviceOrientation.portrait
    
    @State private var arViewProxy: ARSwiftUIView.Proxy?
    @State private var sceneViewProxy: SceneViewProxy?
    
    public init(
        scene: ArcGIS.Scene,
        cameraController: TransformationMatrixCameraController
    ) {
        self.cameraController = cameraController
        self.scene = scene
        
        configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        configuration.planeDetection = [.horizontal]
    }
    
    public var body: some View {
        ZStack {
            ARSwiftUIView()
                .alpha(0)
                .onProxyAvailable { proxy in
                    self.arViewProxy = proxy
                    proxy.session.run(configuration)
                }
                .onRender { _, _, _ in
                    if let arViewProxy, let sceneViewProxy {
                        render(arViewProxy: arViewProxy, sceneViewProxy: sceneViewProxy)
                    }
                }
            SceneViewReader { sceneViewProxy in
                SceneView(
                    scene: scene,
                    cameraController: cameraController
                )
                .attributionBarHidden(true)
                .spaceEffect(.transparent)
                .viewDrawingMode(.manual)
                .atmosphereEffect(.off)
                .onAppear {
                    self.sceneViewProxy = sceneViewProxy
                }
            }
        }
    }
}

private extension ARGeoView3 {
    func render(arViewProxy: ARSwiftUIView.Proxy, sceneViewProxy: SceneViewProxy) {
        // Get transform from SCNView.pointOfView.
        guard let transform = arViewProxy.pointOfView?.transform else { return }
        let cameraTransform = simd_double4x4(transform)
        
        let cameraQuat = simd_quatd(cameraTransform)
        let transformationMatrix = TransformationMatrix.normalized(
            quaternionX: cameraQuat.vector.x,
            quaternionY: cameraQuat.vector.y,
            quaternionZ: cameraQuat.vector.z,
            quaternionW: cameraQuat.vector.w,
            translationX: cameraTransform.columns.3.x,
            translationY: cameraTransform.columns.3.y,
            translationZ: cameraTransform.columns.3.z
        )
        
        // Set the matrix on the camera controller.
        cameraController.transformationMatrix = .identity.adding(transformationMatrix)
        
        // Set FOV on camera.
        if let camera = arViewProxy.session.currentFrame?.camera {
            let intrinsics = camera.intrinsics
            let imageResolution = camera.imageResolution
            
            // Get the device orientation, but don't allow non-landscape/portrait values.
            let deviceOrientation = UIDevice.current.orientation
            if deviceOrientation.isValidInterfaceOrientation {
                lastGoodDeviceOrientation = deviceOrientation
            }
            
            sceneViewProxy.setFieldOfViewFromLensIntrinsics(
                xFocalLength: intrinsics[0][0],
                yFocalLength: intrinsics[1][1],
                xPrincipal: intrinsics[2][0],
                yPrincipal: intrinsics[2][1],
                xImageSize: Float(imageResolution.width),
                yImageSize: Float(imageResolution.height),
                deviceOrientation: lastGoodDeviceOrientation
            )
        }
        
        // Render the Scene with the new transformation.
        sceneViewProxy.draw()
        //print("-- drawing")
    }
}
