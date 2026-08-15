import Foundation
import XCTest

final class RevenueCatImportBoundaryTests: XCTestCase {
  func testRevenueCatImportsRemainInSubscriptionAdapterFiles() throws {
    let projectRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let appDirectory = projectRoot.appendingPathComponent("App")
    let allowed = Set(["SubscriptionScreen.swift", "SubscriptionStore.swift", "VentureUnlockScreen.swift"])
    let files = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
      .filter { $0.pathExtension == "swift" }
    for file in files where !allowed.contains(file.lastPathComponent) {
      let source = try String(contentsOf: file)
      XCTAssertFalse(source.contains("import RevenueCat"), "\(file.lastPathComponent) crossed the RevenueCat adapter boundary")
    }
  }
}
