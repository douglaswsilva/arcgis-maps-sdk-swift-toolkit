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

/// A floating panel is a view that overlays a view and supplies view-related
/// content. For a map view, for instance, it could display a legend, bookmarks, search results, etc..
/// Apple Maps, Google Maps, Windows 10, and Collector have floating panel
/// implementations, sometimes referred to as a "bottom sheet".
///
/// Floating panels are non-modal and can be transient, only displaying
/// information for a short period of time like identify results,
/// or persistent, where the information is always displayed, for example a
/// dedicated search panel. They will also be primarily simple containers
/// that clients will fill with their own content.
struct FloatingPanel<Content>: View where Content: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) var verticalSizeClass
    
    /// The background color of the floating panel.
    let backgroundColor: Color
    
    /// The content shown in the floating panel.
    let content: Content
    
    /// Creates a `FloatingPanel`.
    /// - Parameters:
    ///   - backgroundColor: The background color of the floating panel.
    ///   - selection: Controls the height of the panel.
    ///   - isPresented: A Boolean value indicating if the view is presented.
    ///   - content: The view shown in the floating panel.
    init(
        backgroundColor: Color,
        selection: Binding<FloatingPanelDetent>,
        isPresented: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.backgroundColor = backgroundColor
        self.selectedDetent = selection
        self.isPresented = isPresented
        self.content = content()
    }
    
    /// A binding to the currently selected detent.
    private var selectedDetent: Binding<FloatingPanelDetent>
    
    /// The color of the handle.
    @State private var handleColor: Color = .defaultHandleColor
    
    /// The height of the content.
    @State private var height: CGFloat = .minHeight
    
    /// A binding to a Boolean value that determines whether the view is presented.
    private var isPresented: Binding<Bool>
    
    /// The maximum allowed height of the content.
    @State private var maximumHeight: CGFloat = .infinity
    
    /// A Boolean value indicating whether the panel should be configured for a compact environment.
    private var isCompact: Bool {
        horizontalSizeClass == .compact && verticalSizeClass == .regular
    }
    
    public var body: some View {
        if isPresented.wrappedValue {
            GeometryReader { geometryProxy in
                VStack(spacing: 0) {
                    if isCompact {
                        makeHandleView()
                        Divider()
                    }
                    content
                        .frame(height: height)
                        .padding(.bottom, isCompact ? 25 : .zero)
                    if !isCompact {
                        Divider()
                        makeHandleView()
                    }
                }
                .background(backgroundColor)
                .cornerRadius(10, corners: isCompact ? [.topLeft, .topRight] : [.allCorners])
                .shadow(radius: 10)
                .opacity(isPresented.wrappedValue ? 1.0 : .zero)
                .frame(
                    width: geometryProxy.size.width,
                    height: geometryProxy.size.height,
                    alignment: isCompact ? .bottom : .top
                )
                .onSizeChange {
                    maximumHeight = $0.height
                    if height > maximumHeight {
                        height = maximumHeight
                    }
                }
                .onChange(of: selectedDetent.wrappedValue) { _ in
                    withAnimation {
                        height = heightFor(detent: selectedDetent.wrappedValue)
                    }
                }
                .onChange(of: isPresented.wrappedValue) {
                    height = $0 ? heightFor(detent: selectedDetent.wrappedValue) : .zero
                }
                .onAppear {
                    withAnimation {
                        height = heightFor(detent: selectedDetent.wrappedValue)
                    }
                }
                .animation(.default, value: isPresented.wrappedValue)
            }
            .padding([.leading, .top, .trailing], isCompact ? 0 : 10)
            .padding([.bottom], isCompact ? 0 : 50)
        }
    }
    
    var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                handleColor = .activeHandleColor
                let proposedHeight: CGFloat
                if isCompact {
                    proposedHeight = max(
                        .minHeight,
                        height - value.translation.height
                    )
                } else {
                    proposedHeight = max(
                        .minHeight,
                        height + value.translation.height
                    )
                }
                height = min(proposedHeight, maximumHeight)
            }
            .onEnded { _ in
                handleColor = .defaultHandleColor
                withAnimation {
                    selectedDetent.wrappedValue = closestDetent
                    height = heightFor(detent: closestDetent)
                }
            }
    }
    
    /// The detent that would produce a height that is closest to the current height.
    var closestDetent: FloatingPanelDetent {
        return FloatingPanelDetent.allCases.min {
            abs(heightFor(detent: $0) - height) <
                abs(heightFor(detent: $1) - height)
        } ?? .half
    }
    
    /// Calculates the height for the `detent`.
    /// - Parameter detent: The detent to use when calculating height
    /// - Returns: A height for the provided detent based on the current maximum height
    func heightFor(detent: FloatingPanelDetent) -> CGFloat {
        switch detent {
        case .summary:
            return max(.minHeight, maximumHeight * 0.15)
        case .half:
            return maximumHeight * 0.4
        case .full:
            return maximumHeight * (isCompact ? 0.90 : 1.0)
        case let .fraction(fraction):
            return min(maximumHeight, max(.minHeight, maximumHeight * fraction))
        case let .height(height):
            return min(maximumHeight, max(.minHeight, height))
        }
    }
    
    /// Configures a handle view.
    /// - Returns: A configured handle view, suitable for placement in the panel.
    @ViewBuilder func makeHandleView() -> some View {
        ZStack {
            backgroundColor
            Handle(color: handleColor)
        }
        .frame(height: 30)
        .gesture(drag)
        .zIndex(1)
    }
}

/// The "Handle" view of the floating panel.
private struct Handle: View {
    /// The color of the handle.
    var color: Color
    
    var body: some View {
        RoundedRectangle(cornerRadius: 4.0)
            .foregroundColor(color)
            .frame(width: 100, height: 8.0)
    }
}

private extension CGFloat {
    static let minHeight: CGFloat = 66
}

private extension Color {
    static var defaultHandleColor: Color { .secondary }
    static var activeHandleColor: Color { .primary }
}

private struct RoundedCorners: Shape {
    var corners: UIRectCorner
    
    var radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(
                width: radius,
                height: radius
            )
        )
        return Path(path.cgPath)
    }
}

private extension View {
    /// Clips this view to its bounding frame, with the specified corner radius, on the specified corners.
    /// - Parameters:
    ///   - radius: The radius used to round the corners.
    ///   - corners: The corners to be rounded.
    /// - Returns: A view that clips this view to its bounding frame with the specified corner radius and
    /// corners.
    func cornerRadius(
        _ radius: CGFloat,
        corners: UIRectCorner
    ) -> some View {
        clipShape(RoundedCorners(
            corners: corners,
            radius: radius
        ))
    }
}
