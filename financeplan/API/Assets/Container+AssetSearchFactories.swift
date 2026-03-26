import Factory

extension Container {
  var assetSearchService: Factory<AssetSearchServicing> {
    self { AssetSearchService() }.singleton
  }
}
