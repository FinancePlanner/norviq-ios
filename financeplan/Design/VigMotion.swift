#if DEBUG || BETA
  import Foundation

  /// How the 3D Vig bust moves (BRD-001). The numbers are `vig-motion.json`, a byte copy of
  /// `norviq-web-v2/design/vig-motion.json`; this type only turns a time and a drag into a pose. It
  /// imports no renderer: `Vig3DView` applies what it returns. The web `src/lib/vig-motion.ts` is the
  /// same arithmetic, and both tests check `vig-motion.fixtures.json`.
  ///
  /// Debug and Beta only: the Release build excludes this file and the JSON
  /// (`EXCLUDED_SOURCE_FILE_NAMES`), and `scripts/verify-release-no-3d.sh` proves it.
  nonisolated struct VigMotion: Decodable, Sendable, Equatable {
    enum Easing: String, Decodable, Sendable {
      case linear, sine, decelerate
    }

    struct Entrance: Decodable, Sendable, Equatable {
      let durationSeconds: Double
      let easing: Easing
      let fromOpacity: Double
      let fromRise: Double
      let fromYawDegrees: Double
    }

    struct Idle: Decodable, Sendable, Equatable {
      let amplitudeDegrees: Double
      let periodSeconds: Double
      let startsAfterEntrance: Bool
    }

    struct Pointer: Decodable, Sendable, Equatable {
      let maxYawDegrees: Double
      let maxPitchDegrees: Double
      let followSeconds: Double
      let returnSeconds: Double
    }

    struct Limits: Decodable, Sendable, Equatable {
      let maxYawDegrees: Double
      let maxPitchDegrees: Double
    }

    /// Opacity, rise and yaw during the entrance. Rise is in model heights (the model is 1.0 tall);
    /// negative is below rest.
    struct EntranceState: Equatable, Sendable {
      let opacity: Double
      let rise: Double
      let yawDegrees: Double
    }

    struct Tilt: Equatable, Sendable {
      let yawDegrees: Double
      let pitchDegrees: Double
    }

    struct Pose: Equatable, Sendable {
      let opacity: Double
      let rise: Double
      let yawDegrees: Double
      let pitchDegrees: Double
    }

    let version: Int
    let entrance: Entrance
    let idle: Idle
    let pointer: Pointer
    let limits: Limits

    /// The motion bundled with the app.
    static func load(from bundle: Bundle = .main) throws -> Self {
      guard let url = bundle.url(forResource: "vig-motion", withExtension: "json") else {
        throw CocoaError(.fileNoSuchFile)
      }
      return try JSONDecoder().decode(Self.self, from: Data(contentsOf: url))
    }

    /// 0 to 1 along a span; `u` is held inside 0…1.
    static func ease(_ easing: Easing, _ u: Double) -> Double {
      let x = min(1, max(0, u))
      switch easing {
      case .linear: return x
      case .sine: return 0.5 - 0.5 * cos(Double.pi * x)
      case .decelerate: return 1 - pow(1 - x, 3)
      }
    }

    /// The entrance `seconds` after the first frame: fading in, rising, turning to face front.
    func entranceState(at seconds: Double) -> EntranceState {
      let k = Self.ease(entrance.easing, seconds / entrance.durationSeconds)
      return EntranceState(
        opacity: entrance.fromOpacity + (1 - entrance.fromOpacity) * k,
        rise: entrance.fromRise * (1 - k),
        yawDegrees: entrance.fromYawDegrees * (1 - k)
      )
    }

    /// The idle sway's yaw at `seconds`; it starts from zero once the entrance ends.
    func sway(at seconds: Double) -> Double {
      let s = idle.startsAfterEntrance ? max(0, seconds - entrance.durationSeconds) : seconds
      return idle.amplitudeDegrees * sin(2 * Double.pi * s / idle.periodSeconds)
    }

    /// Where the bust tilts for a drag at (`x`, `y`), each -1…1 across the view, right and up
    /// positive, held inside that range. Up is a negative pitch (positive pitch tips the face down).
    func pointerTarget(x: Double, y: Double) -> Tilt {
      Tilt(
        yawDegrees: min(1, max(-1, x)) * pointer.maxYawDegrees,
        pitchDegrees: -min(1, max(-1, y)) * pointer.maxPitchDegrees
      )
    }

    /// How quickly the tilt follows: briskly toward an active drag, slowly back to rest.
    func pointerTimeConstant(active: Bool) -> Double {
      active ? pointer.followSeconds : pointer.returnSeconds
    }

    /// One frame's step from `current` toward `target`: quick at first, never past it.
    static func approach(
      _ current: Double, toward target: Double, deltaSeconds: Double, timeConstantSeconds: Double
    ) -> Double {
      guard timeConstantSeconds > 0 else {
        return target
      }
      return current + (target - current) * (1 - exp(-deltaSeconds / timeConstantSeconds))
    }

    /// The whole pose at `seconds`, given the smoothed drag tilt. Yaw and pitch never pass the
    /// limits, so the relief's flat back never shows.
    func pose(at seconds: Double, pointerYawDegrees: Double, pointerPitchDegrees: Double) -> Pose {
      let e = entranceState(at: seconds)
      let yaw = e.yawDegrees + sway(at: seconds) + pointerYawDegrees
      return Pose(
        opacity: e.opacity,
        rise: e.rise,
        yawDegrees: min(limits.maxYawDegrees, max(-limits.maxYawDegrees, yaw)),
        pitchDegrees: min(limits.maxPitchDegrees, max(-limits.maxPitchDegrees, pointerPitchDegrees))
      )
    }
  }
#endif
