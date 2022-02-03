import XCTest
@testable import DangerSwiftJUnit
@testable import Danger
@testable import DangerFixtures

final class DangerSwiftJUnitTests: XCTestCase {
    private var plugin: DangerSwiftJUnit!
    private let danger = githubWithFilesDSL(created: ["file.swift"], fileMap: ["file.swift": "//  Created by Colin Humber"])

    override func setUp() {
        plugin = DangerSwiftJUnit(dangerDSL: danger)
        resetDangerResults()
    }
    
    func testEigenResults() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/eigen_fail", withExtension: "xml"))
        
        try plugin.parseFiles([url.path])
        
        XCTAssertEqual(plugin.failures.count, 2)
        XCTAssertEqual(plugin.passes.count, 1109)
        XCTAssertEqual(plugin.errors.count, 0)
        XCTAssertEqual(plugin.skipped.count, 0)
    }

    func testSeleniumResults() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/selenium", withExtension: "xml"))
        
        try plugin.parseFiles([url.path])
        
        XCTAssertEqual(plugin.failures.count, 1)
        XCTAssertEqual(plugin.passes.count, 0)
        XCTAssertEqual(plugin.errors.count, 0)
        XCTAssertEqual(plugin.skipped.count, 0)
    }

    func testTrainerResults() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/fastlane_trainer", withExtension: "xml"))
        
        try plugin.parseFiles([url.path])
        
        XCTAssertEqual(plugin.failures.count, 1)
        XCTAssertEqual(plugin.passes.count, 1)
        XCTAssertEqual(plugin.errors.count, 0)
        XCTAssertEqual(plugin.skipped.count, 0)
    }

    func testDangerRspecResults() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/rspec_fail", withExtension: "xml"))
        
        try plugin.parseFiles([url.path])
        
        XCTAssertEqual(plugin.failures.count, 1)
        XCTAssertEqual(plugin.passes.count, 190)
        XCTAssertEqual(plugin.errors.count, 0)
        XCTAssertEqual(plugin.skipped.count, 7)
    }
    
    func testReportShowsAKnownMarkdownRow() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/rspec_fail", withExtension: "xml"))
        
        try plugin.parseFiles([url.path])
        plugin.reportHeaders = ["name", "file", "time"]
        try plugin.report()

        let row = "Danger::CISource::CircleCI validates when circle all env vars are set | ./spec/lib/danger/ci_sources/circle_spec.rb | 0.012097|"

        let output = try XCTUnwrap(danger.markdowns.first)
        let encodedOutput = try JSONEncoder().encode(output)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: encodedOutput, options: []) as? [String: AnyHashable])
        let message = try XCTUnwrap(json["message"] as? String)
        
        XCTAssertTrue(message.contains(row))
    }

    func testReportShowsAKnownMarkdownHeader() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/rspec_fail", withExtension: "xml"))
        
        try plugin.parseFiles([url.path])
        plugin.reportHeaders = ["time"]
        try plugin.report()

        let row = "Time|\n"

        let output = try XCTUnwrap(danger.markdowns.first)
        let encodedOutput = try JSONEncoder().encode(output)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: encodedOutput, options: []) as? [String: AnyHashable])
        let message = try XCTUnwrap(json["message"] as? String)
        
        XCTAssertTrue(message.contains(row))
    }
    
    func testReportShowsWarningForSkippedTests() throws {
        let url = try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/rspec_fail", withExtension: "xml"))
        
        try plugin.parseFiles([url.path])
        plugin.showSkippedTests = true
        try plugin.report()

        let warning = try XCTUnwrap(danger.warnings.first)
        let encodedOutput = try JSONEncoder().encode(warning)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: encodedOutput, options: []) as? [String: AnyHashable])
        let message = try XCTUnwrap(json["message"] as? String)

        XCTAssertEqual(message, "Skipped 7 tests.")
    }
    
    func testParsingMultipleFiles() throws {
        let urls = [try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/rspec_fail", withExtension: "xml")),
                    try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/fastlane_trainer", withExtension: "xml"))]

        try plugin.parseFiles(urls.map { $0.path })
        try plugin.report()

        // sums are from rspec_fail and fastlane_trainer results
        XCTAssertEqual(plugin.failures.count, 1 + 1)
        XCTAssertEqual(plugin.passes.count, 190 + 1)
        XCTAssertEqual(plugin.errors.count, 0 + 0)
        XCTAssertEqual(plugin.skipped.count, 7 + 0)
    }
    
    func testParsingMultipleFilesUsesCommonAttributesForHeaders() throws {
        let urls = [try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/rspec_fail", withExtension: "xml")),
                    try XCTUnwrap(Bundle.module.url(forResource: "Fixtures/eigen_fail", withExtension: "xml"))]

        try plugin.parseFiles(urls.map { $0.path })
        try plugin.report()

        let output = try XCTUnwrap(danger.markdowns.first)
        let encodedOutput = try JSONEncoder().encode(output)
        let json = try XCTUnwrap(try JSONSerialization.jsonObject(with: encodedOutput, options: []) as? [String: AnyHashable])
        let message = try XCTUnwrap(json["message"] as? String)

        XCTAssertTrue(message.contains("Classname | Name"))
    }
}
