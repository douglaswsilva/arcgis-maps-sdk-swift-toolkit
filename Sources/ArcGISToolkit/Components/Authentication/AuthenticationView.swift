// Copyright 2022 Esri.

// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import SwiftUI

struct AuthenticationView: View {
    init(challenge: QueuedChallenge) {
        self.challenge = challenge
    }

    let challenge: QueuedChallenge
    
    var body: some View {
        fatalError()
//        switch challenge {
//        case let challenge as QueuedArcGISChallenge:
////            Sheet {
////                UsernamePasswordView(challenge: challenge)
////            }
//        case let challenge as QueuedURLChallenge:
//            switch challenge.urlChallenge.protectionSpace.authenticationMethod {
//            case NSURLAuthenticationMethodServerTrust:
//                //TrustHostView(challenge: challenge)
//                fatalError()
//            case NSURLAuthenticationMethodClientCertificate:
//                CertificatePickerView(challenge: challenge)
//            case NSURLAuthenticationMethodDefault,
//                NSURLAuthenticationMethodNTLM,
//                NSURLAuthenticationMethodHTMLForm,
//                NSURLAuthenticationMethodHTTPBasic,
//            NSURLAuthenticationMethodHTTPDigest:
//                UsernamePasswordView(challenge: challenge)
//            default:
//                fatalError()
//            }
//        default:
//            fatalError()
//        }
    }
}

public extension View {
    @MainActor
    @ViewBuilder
    func authentication(authenticator: Authenticator) -> some View {
        modifier(AuthenticationModifier(authenticator: authenticator))
    }
}

struct AuthenticationModifier: ViewModifier {
    @ObservedObject var authenticator: Authenticator
    @State private var isPresented = false
    
    func body(content: Content) -> some View {
        guard let challenge = authenticator.currentChallenge else {
            return AnyView(content)
        }
        
        switch challenge {
        case let challenge as QueuedArcGISChallenge:
            return AnyView(content.modifier(UsernamePasswordViewModifier(challenge: challenge)))
        case let challenge as QueuedURLChallenge:
            switch challenge.urlChallenge.protectionSpace.authenticationMethod {
            case NSURLAuthenticationMethodServerTrust:
                return AnyView(content.modifier(TrustHostViewModifier(challenge: challenge)))
            case NSURLAuthenticationMethodClientCertificate:
                return AnyView(content.modifier(CertificatePickerViewModifier(challenge: challenge)))
            case NSURLAuthenticationMethodDefault,
                NSURLAuthenticationMethodNTLM,
                NSURLAuthenticationMethodHTMLForm,
                NSURLAuthenticationMethodHTTPBasic,
            NSURLAuthenticationMethodHTTPDigest:
                return AnyView(content.modifier(UsernamePasswordViewModifier(challenge: challenge)))
            default:
                fatalError()
            }
        default:
            fatalError()
        }
    }
}

extension Authenticator: Identifiable {}
