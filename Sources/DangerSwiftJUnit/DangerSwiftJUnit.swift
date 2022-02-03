import Danger
import Foundation
import SWXMLHash

public enum DangerSwiftJUnitError: Error {
    /// The report file does not exist.
    case fileDoesNotExist
    /// The provided headers do not exist in the report.
    case headersUnavailable
}

/// Danger plugin that parses a set of JUnit reports and can report test failures, errors, and optionally skipped tests into a PR.
///
/// There are a number of ways to configure usage of this plugin. The most basic is to provide a report path and let the plugin do the rest.
/// ```swift
/// let plugin = DangerSwiftJUnit()
/// try plugin.parseFile(["/path/to/report"])
/// try plugin.report()
/// ```
///
/// Multiple reports can also be parsed:
/// ```swift
/// let plugin = DangerSwiftJUnit()
/// try plugin.parseFiles(["/path/to/report",
///                        "/path/to/other_report"])
/// try plugin.report()
/// ```
///
/// Reporting can also be done manually:
/// ```swift
/// let plugin = DangerSwiftJUnit()
/// try plugin.parse("/path/to/report")
///
/// if !plugin.failures.isEmpty {
///     fail("Tests failed.")
/// }
/// ```
///
/// Skipped tests can provide a warning:
/// ```swift
/// let plugin = DangerSwiftJUnit()
/// try plugin.parse("/path/to/report_with_skipped_tests")
/// plugin.showSkippedTests = true
/// try plugin.report()
/// ```
///
/// Show only a portion of the results:
/// ```swift
/// let plugin = DangerSwiftJUnit()
/// try plugin.parse("/path/to/report")
/// plugin.reportHeaders = ["name", "time"]
/// try plugin.report()
/// ```

/// Testing frameworks have standardized on the JUnit XML format for reporting results, this means that projects using Rspec, Jasmine, Mocha,
/// XCTest and more - can all use the same Danger error reporting. Perfect.
///
/// All props for this plugin go to Orta Therox and contributors for their work on [danger-junit](https://github.com/orta/danger-junit).
public struct DangerSwiftJUnit {
    // MARK: Public Properties
    /// An array of XML elements the represents all run tests.
    public private(set) var tests: [SWXMLHash.XMLElement] = []
    /// An array of XML elements the represents all passed tests.
    public private(set) var passes: [SWXMLHash.XMLElement] = []
    /// An array of XML elements the represents all failed tests.
    public private(set) var failures: [SWXMLHash.XMLElement] = []
    /// An array of XML elements the represents all tests with errors.
    public private(set) var errors: [SWXMLHash.XMLElement] = []
    /// An array of XML elements the represents all skipped tests.
    public private(set) var skipped: [SWXMLHash.XMLElement] = []
    /// If true, skipped tests will generate a warning when `report()` is called. Default is `false`.
    public var showSkippedTests: Bool = false
    /// An array of headers that will be displayed. All provided headers must exist within the JUnit reports, otherwise a
    /// ``DangerSwiftJUnitError.headersUnavailable`` error will be thrown. If `nil`, all common attributes across all provided
    /// reports will be used. Default is `nil`.
    public var reportHeaders: [String]? = nil
    /// An array of headers for skipped tests that will be displayed. All provided headers must exist within the JUnit reports, otherwise a
    /// ``DangerSwiftJUnitError.headersUnavailable`` error will be thrown. If `nil`, all common attributes across all provided
    /// reports will be used. Default is `nil`.
    public var skippedTestReportHeaders: [String] = []
    
    // MARK: Private Properties
    private let danger: DangerDSL
    
    
    // MARK: - Lifecycle
    
    /// Creates a new ``DangerSwiftJUnit`` instance.
    ///
    /// A custom `DangerDSL` can be provided which is useful for testing.
    /// - Parameter dangerDSL: The `DangerDSL` to use. Default is `Danger()`.
    public init(dangerDSL: DangerDSL = Danger()) {
        danger = dangerDSL
    }
    
    
    // MARK: - Public Methods
    
    /// Parses a report file.
    /// - Parameter file: The path to the report file to parse.
    /// - Throws: If the provided path does not exist, a ``DangerSwiftJUnitError.fileDoesNotExist`` error will be thrown.
    public mutating func parseFile(_ file: String) throws {
        try parseFiles([file])
    }
    
    /// Parses a collection of report files.
    /// - Parameter file: The paths to the report files to parse.
    /// - Throws: If any of the provided paths do not exist, a ``DangerSwiftJUnitError.fileDoesNotExist`` error will be thrown.
    public mutating func parseFiles(_ files: [String]) throws {
        tests = []
        passes = []
        failures = []
        errors = []
        skipped = []

        for file in files {
            guard FileManager.default.fileExists(atPath: file) else { throw DangerSwiftJUnitError.fileDoesNotExist }
            
            let xmlData = try Data(contentsOf: URL(fileURLWithPath: file))
            let doc = XMLHash.parse(xmlData)
            var allTests: [XMLIndexer]
            
            do {
                allTests = try doc.byKey("testsuites").byKey("testsuite").children.filter { $0.element?.name == "testcase" }
            }
            catch IndexingError.key {
                allTests = try doc.byKey("testsuite").children.filter { $0.element?.name == "testcase" }
            }
                        
            tests += allTests.compactMap { $0.element }
            failures += allTests.filter { $0["failure"].element != nil }.compactMap { $0.element }
            errors += allTests.filter { $0["error"].element != nil }.compactMap { $0.element }
            skipped += allTests.filter { $0["skipped"].element != nil }.compactMap { $0.element }
            passes += allTests.filter { $0.children.count == 0 }.compactMap { $0.element }
        }
    }
    
    /// Fails a build if there are failed tests included in the parsed reports and outputs a markdown table of the reports to the pull request.
    public func report() throws {
        if showSkippedTests && !skipped.isEmpty {
            danger.warn("Skipped \(skipped.count) tests.")
            
            let message = "### Skipped: \n\n\(try getReportContent(tests: skipped, headers: skippedTestReportHeaders))"
            danger.markdown(message)
        }
        
        if !failures.isEmpty || !errors.isEmpty {
            danger.fail("Tests have failed. See below for more information.")
            
            let tests = failures + errors
            
            let message = "### Tests: \n\n\(try getReportContent(tests: tests, headers: reportHeaders))"
            danger.markdown(message)
        }
    }
}

private extension DangerSwiftJUnit {
    /// Generates the report Markdown content.
    /// - Parameters:
    ///   - tests: The tests to include in the report.
    ///   - headers: The report headers to display. If `nil`, all common headers across all provided tests will be used.
    /// - Returns: A Markdown table containing details headers and associated details from each test as separate rows.
    func getReportContent(tests: [SWXMLHash.XMLElement], headers: [String]?) throws -> String {
        var message = ""
        let commonAttributes = Array(tests
            .map { Set($0.allAttributes.keys) }
            .reduce(Set<String>()) { $0.isEmpty ? $1 : $0.intersection($1) }
            .sorted(by: <)
        )
        
        // check if the provided headers are available
        if let headers = headers, !headers.isEmpty && !Set(headers).isSubset(of: commonAttributes) {
            throw DangerSwiftJUnitError.headersUnavailable
        }
        
        let keys = headers ?? commonAttributes
        let attributes = keys.map(\.capitalized)
        
        // create the headers
        message += attributes.joined(separator: " | ") + "|\n"
        message += attributes.map { _ in  "---" }.joined(separator: " | ") + "|\n"
        
        // map out the keys to the tests
        tests.forEach { test in
            let rowValues = keys.compactMap { key in test.attribute(by: key)?.text }
            
            message += rowValues.joined(separator: " | ") + "|\n"
        }
        
        return message
    }
}
