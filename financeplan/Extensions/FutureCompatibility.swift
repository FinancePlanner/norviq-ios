import SwiftUI

// This file provides shims for "Future SwiftUI" APIs (Liquid Glass) 
// to allow the project to compile on current CI runners that lack 
// the experimental iOS 26+ SDK features.

#if !canImport(LiquidGlassFramework) // Dummy check for the future framework

// MARK: - Dummy Types
public struct Glass: Sendable {
    public static let regular = Glass()
    public func tint(_ color: Color) -> Glass { self }
    public func interactive() -> Glass { self }
}

public enum GlassEffectTransition {
    case matchedGeometry
    case materialize
}

// MARK: - View Shims
extension View {
    @ViewBuilder
    public func glassEffect(_ style: Glass = .regular) -> some View {
        self
    }
    
    @ViewBuilder
    public func glassEffect<S: Shape>(_ style: Glass = .regular, in shape: S) -> some View {
        self
    }
    
    @ViewBuilder
    public func glassEffectID(_ id: AnyHashable, in namespace: Namespace.ID) -> some View {
        self
    }
}

// MARK: - Container Shim
public struct GlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    let content: () -> Content
    
    public init(spacing: CGFloat = 0, @ViewBuilder content: @escaping () -> Content) {
        self.spacing = spacing
        self.content = content
    }
    
    public var body: some View {
        ZStack {
            content()
        }
    }
}

#endif
