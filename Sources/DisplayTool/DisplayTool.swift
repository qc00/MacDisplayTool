import ArgumentParser
import CoreGraphics
import AppKit

@_silgen_name("CGSConfigureDisplayEnabled")
func CGSConfigureDisplayEnabled(_ config: CGDisplayConfigRef, _ displayID: CGDirectDisplayID, _ enabled: Bool) -> CGError

@main
struct DisplayTool: ParsableCommand {
  static let configuration: CommandConfiguration = .init(subcommands: [List.self, E.self, D.self, T.self])
}

extension DisplayTool {
  // MARK: - List
  struct List: ParsableCommand {
    func run() throws {
      let result = try listDisplayIDs()
      let names = iterDeviceNames()
      print("ID\tVendor\tModel\tName")
      for id in result {
        let vendor = CGDisplayVendorNumber(id)
        let model = CGDisplayModelNumber(id)
        let name = names[id] ?? "-"
        print("\(id)\t\(vendor)\t\(model)\t\(name)")
      }
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

    func iterDeviceNames() -> [CGDirectDisplayID:String] {
      var names: [CGDirectDisplayID: String] = [:]
      if #available(macOS 10.15, *) {
        for screen in NSScreen.screens {
          if let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID {
            names[id] = screen.localizedName
        }
      }
      }
      return names
    }
  }

  static func configureDisplay(id: CGDirectDisplayID, enabled: Bool) throws {
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

  struct E: ParsableCommand {
    @Argument var displayID: CGDirectDisplayID
    func run() throws {
      try DisplayTool.configureDisplay(id: displayID, enabled: true)
    }
  }

  struct D: ParsableCommand {
    @Argument var displayID: CGDirectDisplayID
    func run() throws {
      try DisplayTool.configureDisplay(id: displayID, enabled: false)
    }
  }

  struct T: ParsableCommand {
    @Argument var displayID: CGDirectDisplayID
    func run() throws {
      let activeIDs = try List().listDisplayIDs()
      let enabled = !activeIDs.contains(displayID)
      try DisplayTool.configureDisplay(id: displayID, enabled: enabled)
    }
  }
}

// MARK: - Error
extension DisplayTool {
  enum APIError: Error {
    case coreGraphics(api: String, error: CGError)
  }
}
