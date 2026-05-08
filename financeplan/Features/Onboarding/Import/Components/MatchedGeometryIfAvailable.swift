//
//  MatchedGeometryIfAvailable.swift
//  financeplan
//
import SwiftUI

struct MatchedGeometryIfAvailable: ViewModifier {
  let id: String
  let namespace: Namespace.ID?
  var isSource: Bool = true
  func body(content: Content) -> some View {
    if let ns = namespace {
      content.matchedGeometryEffect(id: id, in: ns, isSource: isSource)
    } else {
      content
    }
  }
}
