import SwiftUI
import ArcGIS
import ArcGISToolkit

struct SearchExampleView: View {
    let locatorDataSource = SmartLocatorSearchSource(
        name: "My locator",
        maximumResults: 16,
        maximumSuggestions: 16
    )
    
    @StateObject private var dataModel = MapDataModel(
        map: Map(basemapStyle: .arcGISImagery)
    )
    
    private let searchResultsOverlay = GraphicsOverlay()
    
    @State private var searchResultViewpoint: Viewpoint? = Viewpoint(
        center: Point(x: -93.258133, y: 44.986656, spatialReference: .wgs84),
        scale: 1000000
    )
    
    @State private var isGeoViewNavigating = false
}
