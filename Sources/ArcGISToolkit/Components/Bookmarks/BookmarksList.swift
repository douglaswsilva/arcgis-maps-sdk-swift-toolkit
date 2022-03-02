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

import ArcGIS
import SwiftUI

/// `BookmarksList` displays a list of selectable bookmarks.
struct BookmarksList: View {
    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass: UserInterfaceSizeClass?

    @Environment(\.verticalSizeClass)
    private var verticalSizeClass: UserInterfaceSizeClass?

    /// A list of bookmarks for display.
    var bookmarks: [Bookmark]

    /// If `true`, the bookmarks will display as sheet.
    /// If `false`, the bookmarks will display as a popover.
    private var isCompact: Bool {
        return horizontalSizeClass == .compact || verticalSizeClass == .compact
    }

    /// The height of the list content.
    @State
    private var listContentHeight: CGFloat = .zero

    /// Action to be performed when a bookmark is selected.
    var onSelectionChanged: ((Bookmark) -> Void)? = nil

    /// Sets a closure to perform when the bookmark selection changes.
    /// - Parameters:
    ///   - action: The closure to perform when the bookmark selection has changed.
    public func onSelectionChanged(
        perform action: @escaping (Bookmark) -> Void
    ) -> BookmarksList {
        var copy = self
        copy.onSelectionChanged = action
        return copy
    }

    var body: some View {
        Group {
            if bookmarks.isEmpty {
                Label {
                    Text("No bookmarks")
                } icon: {
                    Image(systemName: "bookmark.slash")
                }
                .foregroundColor(.primary)
            } else {
                ScrollView {
                    VStack(alignment: .leading) {
                        ForEach(
                            bookmarks.sorted { $0.name <  $1.name },
                            id: \.viewpoint
                        ) { bookmark in
                            Button {
                                onSelectionChanged?(bookmark)
                            } label: {
                                Text(bookmark.name)
                                    .foregroundColor(.primary)
                            }
                            .padding(4)
                            Divider()
                        }
                    }
                    .padding()
                    .onSizeChange {
                        listContentHeight = $0.height
                    }
                }
                .frame(
                    maxHeight: isCompact ? .infinity : listContentHeight
                )
            }
        }
    }
}
