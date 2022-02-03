# DangerSwiftJUnit

Danger-Swift plugin that parses a JUnit test report and provides automatic reporting and build failures if any reports include failed tests.

Most test runners have the ability to generated a test report conforming to the JUnit XML standard. This plugin can parse these files, extract all passed, failed, error'd, or skipped tests.

Migrated to Swift from [danger-junit](https://github.com/orta/danger-junit). Props to Orta Therox and contributers for all their hard work on this.

## How Does It Look?

![image](https://user-images.githubusercontent.com/104855/152434861-afb44e06-6913-4378-9e3b-66b700fd3340.png)

### Install DangerSwiftJUnit
- Add to your `Package.swift`:

```swift
let package = Package(
    ...
    products: [
        ...
    ],
    dependencies: [
        ...
        // Danger Plugins
        .package(url: "https://github.com/colinhumber/DangerSwiftJUnit", from: "1.0.0") // dev
        ...
    ],
    targets: [
        ...
    ]
)
```

- Add the correct import to your `Dangerfile.swift`:
```swift
import DangerSwiftJUnit

let plugin = DangerSwiftJUnit()
try? plugin.parse("/path/to/report")
try? plugin.report()
```

Check out the [plugin](https://github.com/colinhumber/DangerSwiftJUnit/blob/main/Sources/DangerSwiftJUnit/DangerSwiftJUnit.swift) for more customization options.
