// Copyright 2024 Esri
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//   https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import XCTest

final class AttachmentCameraControllerTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
    }
    
    /// Test `AttachmentCameraController.onCameraCaptureModeChanged(perform:)`
    func testOnCameraCaptureModeChanged() throws {
#if targetEnvironment(simulator)
        XCTSkip("This test intended for iOS devices only.")
#elseif targetEnvironment(macCatalyst)
        XCTSkip("This test intended for iOS devices only.")
#endif
        let app = XCUIApplication()
        let cameraModeController = app.otherElements["CameraMode"]
        let cameraModeLabel = app.staticTexts["Camera Capture Mode"]
        app.launch()
        
        addUIInterruptionMonitor(withDescription: "Camera access alert") { (alert) -> Bool in
            alert.buttons["Allow"].tap()
            return true
        }
        addUIInterruptionMonitor(withDescription: "Microphone access alert") { (alert) -> Bool in
            alert.buttons["Allow"].tap()
            return true
        }
        
        let attachmentCameraControllerTestsButton = app.buttons["AttachmentCameraController Tests"]
        
        XCTAssertTrue(
            attachmentCameraControllerTestsButton.exists,
            "The AttachmentCameraController Tests button wasn't found."
        )
        attachmentCameraControllerTestsButton.tap()
        
        XCTAssertTrue(
            cameraModeController.waitForExistence(timeout: 5)
        )
        cameraModeController.swipeDown()
        
        XCTAssertEqual(cameraModeLabel.label, "Video")
        
        cameraModeController.swipeUp()
        
        XCTAssertEqual(cameraModeLabel.label, "Photo")
    }
}
