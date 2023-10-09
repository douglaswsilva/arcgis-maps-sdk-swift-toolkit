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

import ARKit
import SwiftUI
import ArcGIS

/// A scene view that provides an augmented reality world scale experience.
public struct WorldScaleSceneView2: View {
    /// The proxy for the ARSwiftUIView.
    @State private var arViewProxy = ARSwiftUIViewProxy()
    /// The proxy for the scene view.
    @State private var sceneViewProxy: SceneViewProxy?
    /// The camera controller that will be set on the scene view.
    @State private var cameraController: TransformationMatrixCameraController
    /// The current interface orientation.
    @State private var interfaceOrientation: InterfaceOrientation?
    /// The closure that builds the scene view.
    private let sceneViewBuilder: (SceneViewProxy) -> SceneView
    /// The configuration for the AR session.
    private let configuration: ARConfiguration
    
    @State private var statusText: String = ""
    @State private var locationDatasSource = SystemLocationDataSource()
    @State private var currentHeading: Double?
    @State private var currentLocation: Location?
    @State private var locationDataSourceError: Error?
    @State private var shouldShowSceneView = false
    
    /// Creates a world scale scene view.
    /// - Parameters:
    ///   - sceneView: A closure that builds the scene view to be overlayed on top of the
    ///   augmented reality video feed.
    /// - Remark: The provided scene view will have certain properties overridden in order to
    /// be effectively viewed in augmented reality. Properties such as the camera controller,
    /// and view drawing mode.
    public init(
        @ViewBuilder sceneView: @escaping (SceneViewProxy) -> SceneView
    ) {
        self.sceneViewBuilder = sceneView
        
        let cameraController = TransformationMatrixCameraController()
        cameraController.translationFactor = 1
        _cameraController = .init(initialValue: cameraController)
        
        configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
    }
    
    public var body: some View {
        ZStack {
            ARSwiftUIView(proxy: arViewProxy)
                .onDidUpdateFrame { _, frame in
                    guard let sceneViewProxy, let interfaceOrientation else { return }
                    
                    sceneViewProxy.updateCamera(
                        frame: frame,
                        cameraController: cameraController,
                        orientation: interfaceOrientation
                    )
//                    sceneViewProxy.setFieldOfView(
//                        for: frame,
//                        orientation: interfaceOrientation
//                    )
                }
            
            if shouldShowSceneView {
                SceneViewReader { proxy in
                    sceneViewBuilder(proxy)
                        .cameraController(cameraController)
                        .attributionBarHidden(true)
                        .spaceEffect(.transparent)
                        .atmosphereEffect(.off)
                        .onAppear {
                            // Capture scene view proxy as a workaround for a bug where
                            // preferences set for `ARSwiftUIView` are not honored. The
                            // issue has been logged with a bug report with ID FB13188508.
                            self.sceneViewProxy = proxy
                        }
                }
            }
        }
        .overlay(alignment: .top) {
            if !statusText.isEmpty {
                statusView(for: statusText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(8)
                    .background(.regularMaterial, ignoresSafeAreaEdges: .horizontal)
            }
        }
        .observingInterfaceOrientation($interfaceOrientation)
        .onAppear {
            arViewProxy.session.run(configuration, options: [.resetTracking])
        }
        .task {
            do {
                try await locationDatasSource.start()
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        for await heading in locationDatasSource.headings {
                            self.currentHeading = heading
                            updateSceneView()
                        }
                    }
                    group.addTask {
                        for await location in locationDatasSource.locations {
                            self.currentLocation = location
                            updateSceneView()
                        }
                    }
                }
            } catch {
                locationDataSourceError = error
            }
        }
    }
    
    func updateSceneView() {
        guard let currentHeading, let currentLocation else { return }
        cameraController.originCamera = Camera(
            latitude: currentLocation.position.y,
            longitude: currentLocation.position.x,
            altitude: 15,
            heading: currentHeading + 90,
            pitch: 90,
            roll: 0
        )
        arViewProxy.session.run(configuration, options: [.resetTracking])
        shouldShowSceneView = true
    }
    
    @ViewBuilder func statusView(for status: String) -> some View {
        Text(status)
            .multilineTextAlignment(.center)
    }
}
