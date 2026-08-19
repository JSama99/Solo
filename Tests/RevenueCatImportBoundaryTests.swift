import Foundation
import XCTest

final class RevenueCatImportBoundaryTests: XCTestCase {
  func testRevenueCatImportsRemainInSubscriptionAdapterFiles() throws {
    let projectRoot = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let appDirectory = projectRoot.appendingPathComponent("App")
    let allowed = Set(["SubscriptionScreen.swift", "SubscriptionStore.swift", "VentureUnlockScreen.swift"])
    let files: [URL]
    do {
      files = try FileManager.default.contentsOfDirectory(at: appDirectory, includingPropertiesForKeys: nil)
    } catch {
      throw XCTSkip("Source directory is not readable in this test environment: \(error.localizedDescription)")
    }
    let swiftFiles = files
      .filter { $0.pathExtension == "swift" }
    for file in swiftFiles where !allowed.contains(file.lastPathComponent) {
      let source = try String(contentsOf: file, encoding: .utf8)
      XCTAssertFalse(source.contains("import RevenueCat"), "\(file.lastPathComponent) crossed the RevenueCat adapter boundary")
    }
  }
}
