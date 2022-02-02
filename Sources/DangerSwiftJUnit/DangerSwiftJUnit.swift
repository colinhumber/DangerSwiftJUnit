import Danger
import Foundation
import SWXMLHash

public enum DangerSwiftJUnitError: Error {
    case fileDoesNotExist
    case headersUnavailable
}

public struct DangerSwiftJUnit {
    var tests: [SWXMLHash.XMLElement] = []
    var passes: [SWXMLHash.XMLElement] = []
    var failures: [SWXMLHash.XMLElement] = []
    var errors: [SWXMLHash.XMLElement] = []
    var skipped: [SWXMLHash.XMLElement] = []
    var showSkippedTests: Bool = false
    var headers: [String]? = nil
    var skippedHeaders: [String] = []
    
    let danger = Danger()
    
    mutating func parseFiles(_ files: [String]) throws {
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
    
    func report() throws {
        if showSkippedTests && !skipped.isEmpty {
            warn("Skipped \(skipped.count) tests.")
            
            let message = "### Skipped: \n\n\(try getReportContent(tests: skipped, headers: skippedHeaders))"
            markdown(message)
        }
        
        if !failures.isEmpty || !errors.isEmpty {
            fail("Tests have failed. See below for more information.")
            
            let tests = failures + errors
            
            let message = "### Tests: \n\n\(try getReportContent(tests: tests, headers: headers))"
            markdown(message)
        }
    }
    
    private func getReportContent(tests: [SWXMLHash.XMLElement], headers: [String]?) throws -> String {
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
    
    private func autoLink(value: String) -> String {
        if danger.github != nil && FileManager.default.fileExists(atPath: value) {
            return danger.github.createHtmlLink(for: value)
        }
        
        return value
    }
    
    private func createLink(href: String, text: String?) -> String {
        "<a href='\(href)'>\(text ?? href)</a>"
    }
}

extension Danger.GitHub {
    func createHtmlLink(for value: String) -> String {
        let filename = URL(fileURLWithPath: value).lastPathComponent
        let repoRoot = pullRequest.head.repo.htmlURL
    
        let link = "\(repoRoot)/blob/\(pullRequest.head.ref)/\(filename)"
        
        return createLink(href: link, text: filename)
    }
    
    private func createLink(href: String, text: String?) -> String {
        "<a href='\(href)'>\(text ?? href)</a>"
    }
}


//const fileLinks = (paths: string[], useBasename: boolean = true, repoSlug?: string, branch?: string): string => {
//  // To support enterprise github, we need to handle custom github domains
//  // this can be pulled out of the repo url metadata
//
//  const githubRoot = pr && pr.head.repo.html_url.split(pr.head.repo.owner.login)[0]
//  const slug = repoSlug || (pr && pr.head.repo.full_name)
//  const ref = branch || (pr && pr.head.ref)
//
//  const toHref = (path: string) => `${githubRoot}${slug}/blob/${ref}/${path}`
//  // As we should only be getting paths we can ignore the nullability
//  const hrefs = paths.map(p => href(toHref(p), useBasename ? basename(p) : p)) as string[]
//  return sentence(hrefs)
//}
//
//# @!group GitHub Misc
//# Returns an HTML link for a file in the head repository. An example would be
//# `<a href='https://github.com/artsy/eigen/blob/561827e46167077b5e53515b4b7349b8ae04610b/file.txt'>file.txt</a>`
//# @return String
//def html_link(paths)
//  paths = [paths] unless paths.kind_of?(Array)
//  commit = head_commit
//  repo = pr_json[:head][:repo][:html_url]
//  paths = paths.map do |path|
//    path_with_slash = "/#{path}" unless path.start_with? "/"
//    create_link("#{repo}/blob/#{commit}#{path_with_slash}", path)
//  end
//
//  return paths.first if paths.count < 2
//  paths.first(paths.count - 1).join(", ") + " & " + paths.last
//end
//
//private
//
//def create_link(href, text)
//  "<a href='#{href}'>#{text}</a>"
//end
