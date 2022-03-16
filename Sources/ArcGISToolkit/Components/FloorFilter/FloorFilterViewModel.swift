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
import ArcGIS

/// Manages the state for a `FloorFilter`.
@MainActor
final class FloorFilterViewModel: ObservableObject {
    /// Creates a `FloorFilterViewModel`.
    /// - Parameters:
    ///   - floorManager: The floor manager used by the `FloorFilterViewModel`.
    ///   - viewpoint: Viewpoint updated when the selected site or facility changes.
    init(
        floorManager: FloorManager,
        viewpoint: Binding<Viewpoint>? = nil
    ) {
        self.floorManager = floorManager
        self.viewpoint = viewpoint

        Task {
            do {
                try await floorManager.load()
                if sites.count == 1 {
                    // If we have only one site, select it.
                    setSite(sites.first!, zoomTo: true)
                }
            } catch {
                print("error: \(error)")
            }
            isLoading = false
        }
    }

    /// The `Viewpoint` used to pan/zoom to the selected site/facilty.
    /// If `nil`, there will be no automatic pan/zoom operations.
    var viewpoint: Binding<Viewpoint>?

    /// The `FloorManager` containing the site, floor, and level information.
    let floorManager: FloorManager

    /// The floor manager sites.
    var sites: [FloorSite] {
        floorManager.sites
    }

    /// The floor manager facilities.
    var facilities: [FloorFacility] {
        floorManager.facilities
    }

    /// The floor manager levels.
    var levels: [FloorLevel] {
        floorManager.levels
    }

    /// `true` if the model is loading it's properties, `false` if not loading.
    @Published
    private(set) var isLoading = true

    /// Gets the default level for a facility.
    /// - Parameter facility: The facility to get the default level for.
    /// - Returns: The default level for the facility, which is the level with vertical order 0;
    /// if there's no level with vertical order of 0, it returns the lowest level.
    func defaultLevel(for facility: FloorFacility?) -> FloorLevel? {
        return levels.first(where: { level in
            level.facility == facility && level.verticalOrder == .zero
        }) ?? lowestLevel()
    }

    /// Returns the level with the lowest vertical order.
    private func lowestLevel() -> FloorLevel? {
        let sortedLevels = levels.sorted {
            $0.verticalOrder < $1.verticalOrder
        }
        return sortedLevels.first {
            $0.verticalOrder != .min && $0.verticalOrder != .max
        }
    }

    @Published
    var selectedSite: FloorSite?

    @Published
    var selectedFacility: FloorFacility?

    @Published
    private(set) var selectedLevel: FloorLevel?

    // MARK: Set selectionmethods

    /// Updates the selected site, facility, and level based on a newly selected site.
    /// - Parameters:
    ///   - floorSite: The selected site.
    ///   - zoomTo: The viewpoint should be updated to show to the extent of this site.
    func setSite(
        _ floorSite: FloorSite?,
        zoomTo: Bool = false
    ) {
        selectedSite = floorSite
        selectedFacility = nil
        selectedLevel = nil
        if zoomTo {
            zoomToExtent(extent: floorSite?.geometry?.extent)
        }
    }

    /// Updates the selected site, facility, and level based on a newly selected facility.
    /// - Parameters:
    ///   - floorFacility: The selected facility.
    ///   - zoomTo: The viewpoint should be updated to show to the extent of this facility.
    func setFacility(
        _ floorFacility: FloorFacility?,
        zoomTo: Bool = false
    ) {
        selectedSite = floorFacility?.site
        selectedFacility = floorFacility
        selectedLevel = defaultLevel(for: floorFacility)
        if zoomTo {
            zoomToExtent(extent: floorFacility?.geometry?.extent)
        }
    }

    /// Updates the selected site, facility, and level based on a newly selected level.
    /// - Parameter floorLevel: The selected level.
    func setLevel(_ floorLevel: FloorLevel?) {
        selectedSite = floorLevel?.facility?.site
        selectedFacility = floorLevel?.facility
        selectedLevel = floorLevel
        filterMapToSelectedLevel()
    }

    /// Updates the viewpoint to display a given extent.
    /// - Parameter extent: The new extent to be shown.
    private func zoomToExtent(extent: Envelope?) {
        // Make sure we have an extent and viewpoint to zoom to.
        guard let extent = extent,
              let viewpoint = viewpoint
        else { return }

        let builder = EnvelopeBuilder(envelope: extent)
        builder.expand(factor: 1.5)
        let targetExtent = builder.toGeometry()
        if !targetExtent.isEmpty {
            viewpoint.wrappedValue = Viewpoint(
                targetExtent: targetExtent
            )
        }
    }

    /// Sets the visibility of all the levels on the map based on the vertical order of the current selected level.
    private func filterMapToSelectedLevel() {
        guard let selectedLevel = selectedLevel else { return }
        levels.forEach {
            $0.isVisible = $0.verticalOrder == selectedLevel.verticalOrder
        }
    }
}

extension FloorSite: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.siteId)
        hasher.combine(self.name)
    }
}
