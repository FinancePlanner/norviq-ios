#if DEBUG || BETA
  import RealityKit
  import SwiftUI
  import UIKit

  /// The RealityKit view: a virtual camera, no AR, clear background.
  private struct VigScene: View {
    let stage: VigStage
    let scheme: ColorScheme

    var body: some View {
      RealityView { content in
        content.camera = .virtual
        guard let root = await stage.load(scheme: scheme) else {
          return
        }
        content.add(root)
        stage.updates = content.subscribe(to: SceneEvents.Update.self) { event in
          stage.step(event.deltaTime)
        }
      }
      .allowsHitTesting(false)
    }
  }

  /// `vig-model.json`, written by `norviq-web-v2/scripts/brand/vig_3d.py` beside the model.
  private nonisolated struct VigModelInfo: Decodable {
    struct Framing: Decodable {
      let fovDegrees: Float
      let target: [Float]
      let distance: Float
    }

    let version: Int
    let framing: Framing
  }

  /// The `lights` block of `vig-motion.json`; `VigMotion` itself carries only the motion.
  private nonisolated struct VigLights: Decodable {
    struct Spec: Decodable {
      struct Tokens: Decodable {
        let sky: String?
        let ground: String?
        let color: String?
      }

      let role: String
      let kind: String
      let ios: Tokens
      let direction: [Float]?
      let intensity: Float
    }

    let lights: [Spec]
  }

  /// The loaded bust, its camera and lights, and its motion.
  @MainActor @Observable
  final class VigStage {
    /// three.js light intensity 1 as RealityKit lux. RealityKit has no hemisphere light: a
    /// hemisphere is a sky light from above and a ground light from below, half each.
    private static let luxPerUnit: Float = 1_000
    /// A frame that took longer (the app coming back) moves Vig this far and no further.
    private static let longestStep = 0.1

    /// The canvas's share of the cross-fade: 0 until the first frame, then the entrance opacity.
    private(set) var opacity = 0.0
    /// The model or its data could not be read: the still stays.
    private(set) var failed = false
    @ObservationIgnored var updates: EventSubscription?

    @ObservationIgnored private var motion: VigMotion?
    @ObservationIgnored private var lightSpecs: [VigLights.Spec] = []
    @ObservationIgnored private var lights: [(entity: Entity, token: String)] = []
    @ObservationIgnored private let bust = Entity()
    @ObservationIgnored private var seconds = 0.0
    @ObservationIgnored private var firstFrame = true
    @ObservationIgnored private var target = VigMotion.Tilt(yawDegrees: 0, pitchDegrees: 0)
    @ObservationIgnored private var active = false
    @ObservationIgnored private var yaw = 0.0
    @ObservationIgnored private var pitch = 0.0

    /// Reads the model, its framing, the motion and the lights from the bundle. Nil, and
    /// `failed`, when any is missing or a light names an unknown token.
    func load(scheme: ColorScheme) async -> Entity? {
      guard
        let motion = try? VigMotion.load(),
        let info: VigModelInfo = decode("vig-model"),
        let lights: VigLights = decode("vig-motion"),
        info.framing.target.count == 3,
        let model = try? await Entity(named: "Vig", in: .main)
      else {
        failed = true
        return nil
      }
      self.motion = motion
      lightSpecs = lights.lights

      let root = Entity()
      bust.addChild(model)
      root.addChild(bust)
      root.addChild(camera(info.framing))
      for spec in lightSpecs {
        guard let made = light(spec) else {
          failed = true
          return nil
        }
        for item in made {
          root.addChild(item.entity)
          self.lights.append(item)
        }
      }
      colourLights(for: scheme)
      step(0)
      return root
    }

    /// Turns toward `point`, given where Vig is on screen: half a stage away is the whole turn,
    /// as on the web.
    func point(at point: CGPoint?, in frame: CGRect) {
      guard let motion, let point, !frame.isEmpty else {
        active = false
        target = VigMotion.Tilt(yawDegrees: 0, pitchDegrees: 0)
        return
      }
      active = true
      target = motion.pointerTarget(
        x: (point.x - frame.midX) / (frame.width / 2),
        y: (frame.midY - point.y) / (frame.height / 2)
      )
    }

    /// One frame of the pose.
    func step(_ elapsed: TimeInterval) {
      guard let motion else {
        return
      }
      let delta = min(elapsed, Self.longestStep)
      if !firstFrame {
        seconds += delta
      }
      let tau = motion.pointerTimeConstant(active: active)
      yaw = VigMotion.approach(yaw, toward: target.yawDegrees, deltaSeconds: delta, timeConstantSeconds: tau)
      pitch = VigMotion.approach(
        pitch, toward: target.pitchDegrees, deltaSeconds: delta, timeConstantSeconds: tau
      )
      let pose = motion.pose(at: seconds, pointerYawDegrees: yaw, pointerPitchDegrees: pitch)
      // three.js Euler XYZ: pitch about X, then yaw about Y, as the web composes them.
      bust.orientation = turn(pose.pitchDegrees, about: [1, 0, 0]) * turn(pose.yawDegrees, about: [0, 1, 0])
      bust.position.y = Float(pose.rise) // the model is 1.0 tall
      // The first call (from load) draws nothing yet: the still stays until a real frame.
      if elapsed > 0 {
        firstFrame = false
        if abs(opacity - pose.opacity) > 0.01 || (pose.opacity == 1 && opacity != 1) {
          opacity = pose.opacity
        }
      }
    }

    /// Light colours from `AppTheme`, resolved for the current scheme.
    func colourLights(for scheme: ColorScheme) {
      let traits = UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light)
      for item in lights {
        guard let colour = Self.token(item.token) else { continue }
        let resolved = UIColor(colour).resolvedColor(with: traits)
        item.entity.components[DirectionalLightComponent.self]?.color = resolved
      }
    }

    private static func token(_ name: String) -> Color? {
      switch name {
      case "elevatedCardBackground": AppTheme.Colors.elevatedCardBackground
      case "pageBackground": AppTheme.Colors.pageBackground
      case "tint": AppTheme.Colors.tint
      default: nil
      }
    }

    private func decode<T: Decodable>(_ name: String) -> T? {
      guard
        let url = Bundle.main.url(forResource: name, withExtension: "json"),
        let data = try? Data(contentsOf: url)
      else { return nil }
      return try? JSONDecoder().decode(T.self, from: data)
    }

    private func camera(_ framing: VigModelInfo.Framing) -> Entity {
      let entity = Entity()
      var lens = PerspectiveCameraComponent()
      lens.fieldOfViewInDegrees = framing.fovDegrees
      entity.components.set(lens)
      let target = SIMD3(framing.target[0], framing.target[1], framing.target[2])
      entity.look(at: target, from: [target.x, target.y, framing.distance], relativeTo: nil)
      return entity
    }

    /// One spec as RealityKit lights, each tagged with the token that colours it.
    private func light(_ spec: VigLights.Spec) -> [(entity: Entity, token: String)]? {
      let centre = SIMD3<Float>(0, 0.5, 0)
      switch spec.kind {
      case "hemisphere":
        guard
          let sky = spec.ios.sky, let ground = spec.ios.ground,
          Self.token(sky) != nil, Self.token(ground) != nil
        else { return nil }
        let half = spec.intensity * Self.luxPerUnit / 2
        return [
          (directional(intensity: half, from: centre + [0, 2, 0.5], at: centre), sky),
          (directional(intensity: half, from: centre + [0, -2, 0.5], at: centre), ground),
        ]
      case "directional":
        guard let token = spec.ios.color, Self.token(token) != nil else {
          return nil
        }
        let d = spec.direction ?? [0, 0, 1]
        let from = centre + SIMD3(d.count == 3 ? d[0] : 0, d.count == 3 ? d[1] : 0, d.count == 3 ? d[2] : 1)
        return [(directional(intensity: spec.intensity * Self.luxPerUnit, from: from, at: centre), token)]
      default:
        return nil
      }
    }

    private func directional(intensity: Float, from: SIMD3<Float>, at: SIMD3<Float>) -> Entity {
      let entity = Entity()
      entity.components.set(DirectionalLightComponent(color: .white, intensity: intensity))
      entity.look(at: at, from: from, relativeTo: nil)
      return entity
    }

    private func turn(_ degrees: Double, about axis: SIMD3<Float>) -> simd_quatf {
      simd_quatf(angle: Float(degrees * .pi / 180), axis: axis)
    }
  }

  /// Vig in 3D (BRD-001: a beta-only experiment; DESIGN.md "Empty, loading and gated states",
  /// `norviq-web-v2/docs/vig-3d.md`). A non-AR RealityView with a virtual camera, clear over
  /// SwiftUI. The flat bust (`vig-poster.png`, else `VigFull`) shows until the model's first frame, and stays under
  /// Reduce
  /// Motion, in Low Power Mode, and when the model or its data cannot be read.
  ///
  /// Motion is `VigMotion` (entrance, slow sway, tilt toward a finger); this view only applies
  /// it. Debug and Beta only: Release excludes this file, `VigMotion.swift`, `Vig.usdz`, the poster
  /// and both JSON files, and `scripts/verify-release-no-3d.sh` proves it.
  struct Vig3DView: View {
    /// A finger on the screen, in global coordinates (`vigFollows`). Nil: Vig rests.
    var pointer: CGPoint?
    var height: CGFloat = 200

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var stage = VigStage()
    @State private var frame = CGRect.zero
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
    /// The bust's own still (`vig-poster.png`, fetched with the model), so the swap to 3D keeps the
    /// pose. Without it, the app's flat Vig.
    @State private var poster = Bundle.main.path(forResource: "vig-poster", ofType: "png")
      .flatMap(UIImage.init(contentsOfFile:))

    private var draws: Bool {
      !reduceMotion && !lowPower && !stage.failed
    }

    var body: some View {
      ZStack {
        still
          .opacity(draws ? 1 - stage.opacity : 1)
        if draws {
          VigScene(stage: stage, scheme: colorScheme)
            .opacity(stage.opacity)
        }
      }
      .frame(height: height)
      .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { frame = $0 }
      .onChange(of: pointer) { _, point in stage.point(at: point, in: frame) }
      .onChange(of: colorScheme) { _, scheme in stage.colourLights(for: scheme) }
      .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
        lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
      }
      .accessibilityHidden(true)
    }

    @ViewBuilder
    private var still: some View {
      if let poster {
        // 5.4% inset: vig-model.json frames the bust with 12% around it, as on the web.
        Image(uiImage: poster)
          .resizable()
          .scaledToFit()
          .padding(height * 0.054)
      } else {
        Image("VigFull")
          .resizable()
          .scaledToFit()
      }
    }
  }

  extension View {
    /// Reports where a finger is on this view, in global coordinates, for a `Vig3DView` inside it
    /// to turn toward. Taps and scrolling go on as before.
    func vigFollows(_ pointer: Binding<CGPoint?>) -> some View {
      simultaneousGesture(
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
          .onChanged { pointer.wrappedValue = $0.location }
          .onEnded { _ in pointer.wrappedValue = nil }
      )
    }
  }
#endif
