import ArgumentParser
import CoreGraphics

@_silgen_name("CGSConfigureDisplayEnabled")
func CGSConfigureDisplayEnabled(_ config: CGDisplayConfigRef, _ displayID: CGDirectDisplayID, _ enabled: Bool) -> CGError

@main
struct DisplayTool: ParsableCommand {
  static let configuration: CommandConfiguration = .init(subcommands: [List.self, Set.self])
}

extension DisplayTool {
  // MARK: - List
  struct List: ParsableCommand {
    func run() throws {
      let result = try listDisplayIDs()
      print("Active Display IDs:\n\(result.map(String.init).joined(separator: ", "))")
    }

    func listDisplayIDs() throws -> [CGDirectDisplayID] {
      var displayCount: UInt32 = 0

      var result = CGGetActiveDisplayList(.max, nil, &displayCount)
      guard result == .success else {
        throw APIError.coreGraphics(api: "CGGetActiveDisplayList", error: result)
      }

      let activeDisplays = UnsafeMutablePointer<CGDirectDisplayID>.allocate(capacity: Int(displayCount))
      result = CGGetActiveDisplayList(displayCount, activeDisplays, &displayCount)
      guard result == .success else {
        throw APIError.coreGraphics(api: "CGGetActiveDisplayList", error: result)
      }

      let count = Int(displayCount)
      var ids: [CGDirectDisplayID] = []
      ids.reserveCapacity(count)
      for i in 0..<count {
        ids.append(activeDisplays[i])
      }

      activeDisplays.deallocate()

      return ids
    }
  }

  // MARK: - Set
  struct Set: ParsableCommand {
    @Argument var displayID: CGDirectDisplayID
    @Flag var configuration: Configuration

    func run() throws {
      try configureDisplay(id: displayID, enabled: configuration != .disabled)
    }

    func configureDisplay(id: CGDirectDisplayID, enabled: Bool) throws {
      var config: CGDisplayConfigRef?

      var result = CGBeginDisplayConfiguration(&config)
      guard result == .success, let config else {
        throw APIError.coreGraphics(api: "CGBeginDisplayConfiguration", error: result)
      }
      result = CGSConfigureDisplayEnabled(config, id, enabled)
      guard result == .success else {
        throw APIError.coreGraphics(api: "CGSConfigureDisplayEnabled", error: result)
      }
      result = CGCompleteDisplayConfiguration(config, .permanently)
      guard result == .success else {
        throw APIError.coreGraphics(api: "CGCompleteDisplayConfiguration", error: result)
      }
    }

    enum Configuration: String, EnumerableFlag {
      case enabled
      case disabled
    }
  }
}

// MARK: - Error
extension DisplayTool {
  enum APIError: Error {
    case coreGraphics(api: String, error: CGError)
  }
}
