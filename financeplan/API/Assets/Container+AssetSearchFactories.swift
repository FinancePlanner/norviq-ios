import Factory

extension Container {
  var assetSearchService: Factory<AssetSearchServicing> {
    self { [unowned self] in
      AssetSearchService(client: self.marketDataHTTPClient())
    }.singleton
  }
}
