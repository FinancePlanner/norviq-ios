import Foundation

struct ChartBuilderExportItem: Identifiable {
  let url: URL

  var id: URL { url }
}
