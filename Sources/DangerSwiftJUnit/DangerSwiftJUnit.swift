import Danger
import Foundation
import SWXMLHash

public enum DangerSwiftJUnitError: Error {
    case fileDoesNotExist
    case headersUnavailable
}

public struct DangerSwiftJUnit {
    public private(set) var tests: [SWXMLHash.XMLElement] = []
    public private(set) var passes: [SWXMLHash.XMLElement] = []
    public private(set) var failures: [SWXMLHash.XMLElement] = []
    public private(set) var errors: [SWXMLHash.XMLElement] = []
    public private(set) var skipped: [SWXMLHash.XMLElement] = []
    public var showSkippedTests: Bool = false
    public var reportHeaders: [String]? = nil
    public var skippedTestReportHeaders: [String] = []
    
    internal let danger = Danger()
    
    public init() {
    }
    
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

            let suiteRoot = doc["testsuites"]
            let allTests = suiteRoot["testsuite"].children
            
            tests += allTests.compactMap { $0.element }
            failures += allTests.filter { $0["failure"].element != nil }.compactMap { $0.element }
            errors += allTests.filter { $0["error"].element != nil }.compactMap { $0.element }
            skipped += allTests.filter { $0["skipped"].element != nil }.compactMap { $0.element }
            passes += allTests.filter { $0.children.count == 0 }.compactMap { $0.element }
        }
    }
    
    public func report() throws {
        if showSkippedTests && !skipped.isEmpty {
            warn("Skipped \(skipped.count) tests.")
            
            let message = "### Skipped: \n\n\(try getReportContent(tests: skipped, headers: skippedTestReportHeaders))"
            markdown(message)
        }
        
        if !failures.isEmpty || !errors.isEmpty {
            fail("Tests have failed. See below for more information.")
            
            let tests = failures + errors
            
            let message = "### Tests: \n\n\(try getReportContent(tests: tests, headers: reportHeaders))"
            markdown(message)
        }
    }
}

private extension DangerSwiftJUnit {
    func getReportContent(tests: [SWXMLHash.XMLElement], headers: [String]?) throws -> String {
        var message = ""
        let commonAttributes = Array(Set(tests.flatMap { $0.allAttributes.keys }))
        
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
            let rowValues = keys
                .compactMap { key in test.attribute(by: key)?.text }
                .map { autoLink(value: $0) }
            
            message += rowValues.joined(separator: " | ") + "|\n"
        }
        
        return message
    }
    
    func autoLink(value: String) -> String {
        if danger.github != nil && FileManager.default.fileExists(atPath: value) {
            return danger.github.createHtmlLink(for: value)
        }
        
        return value
    }
}

extension Danger.GitHub {
    func createHtmlLink(for value: String) -> String {
        let repoRoot = pullRequest.head.repo.htmlURL
    
        guard var link = URL(string: "\(repoRoot)/blob/\(pullRequest.head.ref)") else { return "" }
        
        link.appendPathComponent(value)
        
        return createLink(href: link.absoluteString, text: value)
    }
    
    private func createLink(href: String, text: String?) -> String {
        "<a href='\(href)'>\(text ?? href)</a>"
    }
}
