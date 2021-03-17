# EasyDocument
[![MIT License](https://img.shields.io/apm/l/atomic-design-ui.svg?)](https://github.com/tterb/atomic-design-ui/blob/master/LICENSEs)
[![Swift Package Manager](https://img.shields.io/badge/SwiftPM-Compatible-green.svg)](https://swift.org/package-manager/)

===
This package provides an easy way to perform deep copies of Core Data objects, and an easy way to export and import deep-copied managed objects in a shareable document. It can support sophisticated Core Data object graphs with customization options.

```EasyDocument```includes support for relationships that are either **ordered** or **unordered**, and **one-to-many** or **many-to-many**. Inverse relationships are also properly configured.

Requirements
----
* Swift 5.3+
* iOS 12.0+
* macOS 10.14+
* tvOS 12.0+
* watchOS 5.0+

Install
----
### Swift Package Manager

``` swift
let package = Package(
  name: ...
  dependencies: [
    .package(url: "https://github.com/alekseyn/EasyDocument")
  ],
  targets: ...
)
```
Usage Scenarios
----
Start with adding an import statement.

``` swift
import EasyDocument
```
For best results, your Core Data model must be properly configured. In particular, entities that have an 'ownership' relationship with another entity should have a *Cascade* relationship deletion rule.

```EasyDocument``` only performs a deep copy of entity relationships that are marked with a *Cascade* deletion rule. Related entities that have any other deletion rule are ignored. This is critical to ensure the proper ordering of **ordered** relationships. However, this can be customized.

#### 1. Deep copies of managed objects
Deep copy of a managed object is straightforward.

#### 2. Managed object archives for copy and paste

#### 3. Exporting and importing managed objects

Customization
----

Common Pitfalls
----
#### 1. Managed objects that automatically create other dependent managed objects in awakeFromInsert()

#### 2. Not implementing proper cascade deletion rules.

#### 3. Forgeting to add duplicated managed objects into the existing object graph.

#### 4. Ordered Sets

Unit Tests
----

You can find unit tests in `EasyDocumentTests` target. Press `⌘+U` to run tests in Xcode.
