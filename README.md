# nucleus-swift

A description of this package.


## Getting started

* Make sure to check enable both "Incoming and outgoing connections" for your app in XCode under "Signing & Capabilities" * 

If you have a server-side Swift application, or maybe a cross-platform (for example Linux & macOS) app/library, and you would like to log, we think targeting this logging API package is a great idea. Below you'll find all you need to know to get started.

### Adding the dependency
NucleusSwift is designed for Swift 5, the 1.0 release requires Swift 5. To depend on the logging API package, you need to declare your dependency in your Package.swift:

```swift
.package(url: "https://github.com/apple/nucleus-swift.git", from: "1.0.0"),
```

and to your application/library target, add "NucleusSwift" to your dependencies, e.g. like this:
```swift
.target(name: "BestExampleApp", dependencies: ["NucleusSwift"]),
```

###

```swift
import NucleusSwift

Nucleus.shared.setup("5e6d0f14341df6a7e35d5859")
Nucleus.shared.appStarted()

Nucleus.shared.track("BTN-CLICKED")
```
