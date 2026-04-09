import Factory

extension Container {
  var assetSearchService: Factory<AssetSearchServicing> {
    self { @MainActor [unowned self] in
      AssetSearchService(client: self.marketDataHTTPClient())
    }.singleton
  }
}
