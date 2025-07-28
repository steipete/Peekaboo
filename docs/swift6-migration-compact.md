# The Swift Concurrency Migration Guide

## Overview

Swift's concurrency system, introduced in Swift 5.5, makes asynchronous and parallel code easier to write and understand.
With the Swift 6 language mode, the compiler can now guarantee that concurrent programs are free of data races.

Adopting the Swift 6 language mode is entirely under your control on a per-target basis.
Targets that build with previous modes can interoperate with modules that have been migrated to the Swift 6 language mode.

> Important: The Swift 6 language mode is _opt-in_.
Existing projects will not switch to this mode without configuration changes.
There is a distinction between the _compiler version_ and _language mode_.
The Swift 6 compiler supports four distinct language modes: "6", "5", "4.2", and "4".

# Data Race Safety

Learn about the fundamental concepts Swift uses to enable data-race-free concurrent code.

Traditionally, mutable state had to be manually protected via careful runtime synchronization.
Using tools such as locks and queues, the prevention of data races was entirely up to the programmer.
This is notoriously difficult not just to do correctly, but also to keep correct over time.

More formally, a data race occurs when one thread accesses memory while the same memory is being mutated by another thread.
The Swift 6 language mode eliminates these problems by preventing data races at compile time.

## Data Isolation

Swift's concurrency system allows the compiler to understand and verify the safety of all mutable state.
It does this with a mechanism called _data isolation_.
Data isolation guarantees mutually exclusive access to mutable state.

### Isolation Domains

Data isolation is the _mechanism_ used to protect shared mutable state.
An _isolation domain_ is an independent unit of isolation.

All function and variable declarations have a well-defined static isolation domain:

1. Non-isolated
2. Isolated to an actor value
3. Isolated to a global actor

### Non-isolated

Functions and variables do not have to be a part of an explicit isolation domain.
In fact, a lack of isolation is the default, called _non-isolated_.

```swift
func sailTheSea() {
}
```

This top-level function has no static isolation, making it non-isolated.

```swift
class Chicken {
    let name: String
    var currentHunger: HungerLevel
}
```

This is an example of a non-isolated type.

### Actors

Actors give the programmer a way to define an isolation domain, along with methods that operate within that domain.
All stored properties of an actor are isolated to the enclosing actor instance.

```swift
actor Island {
    var flock: [Chicken]
    var food: [Pineapple]

    func addToFlock() {
        flock.append(Chicken())
    }
}
```

Here, every `Island` instance will define a new domain, which will be used to protect access to its properties.
The method `Island.addToFlock` is said to be isolated to `self`.

Actor isolation can be selectively disabled:

```swift
actor Island {
    var flock: [Chicken]
    var food: [Pineapple]

    nonisolated func canGrow() -> PlantSpecies {
        // neither flock nor food are accessible here
    }
}
```

### Global Actors

Global actors share all of the properties of regular actors, but also provide a means of statically assigning declarations to their isolation domain.

```swift
@MainActor
class ChickenValley {
    var flock: [Chicken]
    var food: [Pineapple]
}
```

This class is statically-isolated to `MainActor`.

### Tasks

A `task` is a unit of work that can run concurrently within your program.
Tasks may run concurrently with one another, but each individual task only executes one function at a time.

```swift
Task {
    flock.map(Chicken.produce)
}
```

A task always has an isolation domain. They can be isolated to an actor instance, a global actor, or could be non-isolated.

### Isolation Inference and Inheritance

There are many ways to specify isolation explicitly.
But there are cases where the context of a declaration establishes isolation implicitly, via _isolation inference_.

#### Classes

A subclass will always have the same isolation as its parent.

```swift
@MainActor
class Animal {
}

class Chicken: Animal {
}
```

Because `Chicken` inherits from `Animal`, the static isolation of the `Animal` type also implicitly applies.

The static isolation of a type will also be inferred for its properties and methods by default.

#### Protocols

A protocol conformance can implicitly affect isolation.
However, the protocol's effect on isolation depends on how the conformance is applied.

```swift
@MainActor
protocol Feedable {
    func eat(food: Pineapple)
}

// inferred isolation applies to the entire type
class Chicken: Feedable {
}

// inferred isolation only applies within the extension
extension Pirate: Feedable {
}
```

## Isolation Boundaries

Moving values into or out of an isolation domain is known as _crossing_ an isolation boundary.
Values are only ever permitted to cross an isolation boundary where there is no potential for concurrent access to shared mutable state.

### Sendable Types

In some cases, all values of a particular type are safe to pass across isolation boundaries because thread-safety is a property of the type itself.
This is represented by the `Sendable` protocol.

Swift encourages using value types because they are naturally safe.
Value types in Swift are implicitly `Sendable` when all their stored properties are also Sendable.
However, this implicit conformance is not visible outside of their defining module.

```swift
enum Ripeness {
    case hard
    case perfect
    case mushy(daysPast: Int)
}

struct Pineapple {
    var weight: Double
    var ripeness: Ripeness
}
```

Here, both types are implicitly `Sendable` since they are composed entirely of `Sendable` value types.

### Actor-Isolated Types

Actors are not value types, but because they protect all of their state in their own isolation domain, they are inherently safe to pass across boundaries.
This makes all actor types implicitly `Sendable`.

Global-actor-isolated types are also implicitly `Sendable` for similar reasons.

### Reference Types

Unlike value types, reference types cannot be implicitly `Sendable`.
To make a class `Sendable` it must contain no mutable state and all immutable properties must also be `Sendable`.
Further, the compiler can only validate the implementation of final classes.

```swift
final class Chicken: Sendable {
    let name: String
}
```

### Suspension Points

A task can switch between isolation domains when a function in one domain calls a function in another.
A call that crosses an isolation boundary must be made asynchronously.

```swift
@MainActor
func stockUp() {
    // beginning execution on MainActor
    let food = Pineapple()

    // switching to the island actor's domain
    await island.store(food)
}
```

Potential suspension points are marked in source code with the `await` keyword.

### Atomicity

While actors do guarantee safety from data races, they do not ensure atomicity across suspension points.
Because the current isolation domain is freed up to perform other work, actor-isolated state may change after an asynchronous call.

```swift
func deposit(pineapples: [Pineapple], onto island: Island) async {
   var food = await island.food
   food += pineapples
   await island.store(food)
}
```

This code assumes, incorrectly, that the `island` actor's `food` value will not change between asynchronous calls.
Critical sections should always be structured to run synchronously.

# Common Compiler Errors

Identify, understand, and address common problems you can encounter while working with Swift concurrency.

After enabling complete checking, many projects can contain a large number of warnings and errors.
_Don't_ get overwhelmed!
Most of these can be tracked down to a much smaller set of root causes.

## Unsafe Global and Static Variables

Global state, including static variables, are accessible from anywhere in a program.
This visibility makes them particularly susceptible to concurrent access.

### Sendable Types

```swift
var supportedStyleCount = 42
```

Here, we have defined a global variable that is both non-isolated _and_ mutable from any isolation domain.

Two functions with different isolation domains accessing this variable risks a data race:

```swift
@MainActor
func printSupportedStyles() {
    print("Supported styles: ", supportedStyleCount)
}

func addNewStyle() {
    let style = Style()
    supportedStyleCount += 1
    storeStyle(style)
}
```

One way to address the problem is by changing the variable's isolation:

```swift
@MainActor
var supportedStyleCount = 42
```

If the variable is meant to be constant:

```swift
let supportedStyleCount = 42
```

If there is synchronization in place that protects this variable:

```swift
/// This value is only ever accessed while holding `styleLock`.
nonisolated(unsafe) var supportedStyleCount = 42
```

Only use `nonisolated(unsafe)` when you are carefully guarding all access to the variable with an external synchronization mechanism.

### Non-Sendable Types

Global _reference_ types present an additional challenge, because they are typically not `Sendable`.

```swift
class WindowStyler {
    var background: ColorComponents

    static let defaultStyler = WindowStyler()
}
```

The issue is `WindowStyler` is a non-`Sendable` type, making its internal state unsafe to share across isolation domains.

One option is to isolate the variable to a single domain using a global actor.
Alternatively, it might make sense to add a conformance to `Sendable` directly.

## Protocol Conformance Isolation Mismatch

A protocol defines requirements that a conforming type must satisfy, including static isolation.
This can result in isolation mismatches between a protocol's declaration and conforming types.

### Under-Specified Protocol

```swift
protocol Styler {
    func applyStyle()
}

@MainActor
class WindowStyler: Styler {
    func applyStyle() {
        // access main-actor-isolated state
    }
}
```

It is possible that the protocol actually _should_ be isolated, but has not yet been updated for concurrency.

#### Adding Isolation

If protocol requirements are always called from the main actor, adding `@MainActor` is the best solution:

```swift
// entire protocol
@MainActor
protocol Styler {
    func applyStyle()
}

// per-requirement
protocol Styler {
    @MainActor
    func applyStyle()
}
```

#### Asynchronous Requirements

For methods that implement synchronous protocol requirements the isolation of implementations must match exactly.
Making a requirement _asynchronous_ offers more flexibility:

```swift
protocol Styler {
    func applyStyle() async
}

@MainActor
class WindowStyler: Styler {
    // matches, even though it is synchronous and actor-isolated
    func applyStyle() {
    }
}
```

#### Preconcurrency Conformance

Annotating a protocol conformance with `@preconcurrency` makes it possible to suppress errors about any isolation mismatches:

```swift
@MainActor
class WindowStyler: @preconcurrency Styler {
    func applyStyle() {
        // implementation body
    }
}
```

### Isolated Conforming Type

Sometimes the protocol's static isolation is appropriate, and the issue is only caused by the conforming type.

#### Non-Isolated

```swift
@MainActor
class WindowStyler: Styler {
    nonisolated func applyStyle() {
        // perhaps this implementation doesn't involve
        // other MainActor-isolated state
    }
}
```

## Crossing Isolation Boundaries

The compiler will only permit a value to move from one isolation domain to another when it can prove it will not introduce data races.

### Implicitly-Sendable Types

Many value types consist entirely of `Sendable` properties.
The compiler will treat types like this as implicitly `Sendable`, but _only_ when they are non-public.

```swift
public struct ColorComponents {
    public let red: Float
    public let green: Float
    public let blue: Float
}

@MainActor
func applyBackground(_ color: ColorComponents) {
}

func updateStyle(backgroundColor: ColorComponents) async {
    await applyBackground(backgroundColor)
}
```

Because `ColorComponents` is marked `public`, it will not implicitly conform to `Sendable`.

A straightforward solution is to make the type's `Sendable` conformance explicit:

```swift
public struct ColorComponents: Sendable {
    // ...
}
```

### Preconcurrency Import

Even if the type in another module is actually `Sendable`, it is not always possible to modify its definition.
Use a `@preconcurrency import` to downgrade diagnostics:

```swift
// ColorComponents defined here
@preconcurrency import UnmigratedModule

func updateStyle(backgroundColor: ColorComponents) async {
    // crossing an isolation domain here
    await applyBackground(backgroundColor)
}
```

### Latent Isolation

Sometimes the _apparent_ need for a `Sendable` type can actually be the symptom of a more fundamental isolation problem.

```swift
@MainActor
func applyBackground(_ color: ColorComponents) {
}

func updateStyle(backgroundColor: ColorComponents) async {
    await applyBackground(backgroundColor)
}
```

Since `updateStyle(backgroundColor:)` is working directly with `MainActor`-isolated functions and non-`Sendable` types, just applying `MainActor` isolation may be more appropriate:

```swift
@MainActor
func updateStyle(backgroundColor: ColorComponents) async {
    applyBackground(backgroundColor)
}
```

### Sending Argument

The compiler will permit non-`Sendable` values to cross an isolation boundary if the compiler can prove it can be done safely:

```swift
func updateStyle(backgroundColor: sending ColorComponents) async {
    // this boundary crossing can now be proven safe in all cases
    await applyBackground(backgroundColor)
}
```

### Sendable Conformance

When encountering problems related to crossing isolation domains, you can make a type `Sendable` in four ways:

#### Global Isolation

```swift
@MainActor
public struct ColorComponents {
    // ...
}
```

#### Actors

```swift
actor Style {
    private var background: ColorComponents
}
```

#### Manual Synchronization

```swift
class Style: @unchecked Sendable {
    private var background: ColorComponents
    private let queue: DispatchQueue
}
```

#### Sendable Reference Types

To allow a checked `Sendable` conformance, a class:

- Must be `final`
- Cannot inherit from another class other than `NSObject`
- Cannot have any non-isolated mutable properties

```swift
final class Style: Sendable {
    private let background: ColorComponents
}
```

### Non-Isolated Initialization

Actor-isolated types can present a problem when they are initialized in a non-isolated context:

```swift
@MainActor
class WindowStyler {
    nonisolated init(name: String) {
        self.primaryStyleName = name
    }
}
```

### Non-Isolated Deinitialization

Even if a type has actor isolation, deinitializers are _always_ non-isolated:

```swift
actor BackgroundStyler {
    private let store = StyleStore()

    deinit {
        Task { [store] in
            await store.stopNotifications()
        }
    }
}
```

> Important: **Never** extend the life-time of `self` from within `deinit`.

# Migration Strategy

Get started migrating your project to the Swift 6 language mode.

When faced with a large number of problems, **don't panic.**
Frequently, you'll find yourself making substantial progress with just a few changes.

## Strategy

The approach has three key steps:

- Select a module
- Enable stricter checking with Swift 5
- Address warnings

This process will be inherently _iterative_.

## Begin from the Outside

It can be easier to start with the outer-most root module in a project.
Changes here can only have local effects, making it possible to keep work contained.

## Use the Swift 5 Language Mode

It is possible to incrementally enable more of the Swift 6 checking mechanisms while remaining in Swift 5 mode.
This will surface issues only as warnings.

To start, enable a single upcoming concurrency feature:

Proposal    | Description | Feature Flag 
:-----------|-------------|-------------
[SE-0401][] | Remove Actor Isolation Inference caused by Property Wrappers | `DisableOutwardActorInference`
[SE-0412][] | Strict concurrency for global variables | `GlobalConcurrency`
[SE-0418][] | Inferring `Sendable` for methods and key path literals | `InferSendableFromCaptures`

[SE-0401]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0401-remove-property-wrapper-isolation.md
[SE-0412]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0412-strict-concurrency-for-global-variables.md
[SE-0418]: https://github.com/swiftlang/swift-evolution/blob/main/proposals/0418-inferring-sendable-for-methods.md

After you have addressed issues uncovered by upcoming feature flags, enable complete checking for the module.

## Address Warnings

There is one guiding principle: **express what is true now**.
Resist the urge to refactor your code to address issues.

# Enabling Complete Concurrency Checking

Incrementally address data-race safety issues by enabling diagnostics as warnings in your project.

## Using the Swift compiler

```
~ swift -strict-concurrency=complete main.swift
```

## Using SwiftPM

### Command-line invocation

```
~ swift build -Xswiftc -strict-concurrency=complete
~ swift test -Xswiftc -strict-concurrency=complete
```

### Package manifest

With Swift 5.9 or Swift 5.10 tools:

```swift
.target(
  name: "MyTarget",
  swiftSettings: [
    .enableExperimentalFeature("StrictConcurrency")
  ]
)
```

When using Swift 6.0 tools or later:

```swift
.target(
  name: "MyTarget",
  swiftSettings: [
    .enableUpcomingFeature("StrictConcurrency")
  ]
)
```

## Using Xcode

Set the "Strict Concurrency Checking" setting to "Complete" in the Xcode build settings.

# Enabling The Swift 6 Language Mode

Guarantee your code is free of data races by enabling the Swift 6 language mode.

## Using the Swift compiler

```
~ swift -swift-version 6 main.swift
```

## Using SwiftPM

### Package manifest

A `Package.swift` file that uses `swift-tools-version` of `6.0` will enable the Swift 6 language mode for all targets:

```swift
// swift-tools-version: 6.0

let package = Package(
    name: "MyPackage",
    targets: [
        .target(name: "FullyMigrated"),
        .target(
            name: "NotQuiteReadyYet",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
```

## Using Xcode

Set the "Swift Language Version" setting to "6" in the Xcode build settings.

# Incremental Adoption

Learn how you can introduce Swift concurrency features into your project incrementally.

## Wrapping Callback-Based Functions

APIs that accept and invoke a single function on completion are an extremely common pattern in Swift.
You can wrap this function up into an asynchronous version using _continuations_:

```swift
func updateStyle(backgroundColor: ColorComponents) async {
    await withCheckedContinuation { continuation in
        updateStyle(backgroundColor: backgroundColor) {
            continuation.resume()
        }
    }
}
```

> Note: You have to take care to _resume_ the continuation _exactly once_.

## Dynamic Isolation

Dynamic isolation provides runtime mechanisms you can use as a fallback for describing data isolation.
It can be an essential tool for interfacing a Swift 6 component with another that has not yet been updated.

### Preconcurrency

You can stage in diagnostics caused by adding global actor isolation on a protocol using `@preconcurrency`:

```swift
@preconcurrency @MainActor
protocol Styler {
    func applyStyle()
}
```

### Assume Isolated

When you know code is running on a specific actor but the compiler cannot verify this statically:

```swift
func doSomething() {
    MainActor.assumeIsolated {
        // Code that requires MainActor
    }
}
```

# Runtime Behavior

Learn how Swift concurrency runtime semantics differ from other runtimes.

## Limiting concurrency using Task Groups

When dealing with a large list of work, avoid creating thousands of tasks at once:

```swift
let lotsOfWork: [Work] = ... 
let maxConcurrentWorkTasks = min(lotsOfWork.count, 10)

await withTaskGroup(of: Something.self) { group in
    var submittedWork = 0
    for _ in 0..<maxConcurrentWorkTasks {
        group.addTask {
            await lotsOfWork[submittedWork].work() 
        }
        submittedWork += 1
    }
    
    for await result in group {
        process(result)
    
        if submittedWork < lotsOfWork.count, 
           let remainingWorkItem = lotsOfWork[submittedWork] {
            group.addTask {
                await remainingWorkItem.work() 
            }  
            submittedWork += 1
        }
    }
}
```

# Source Compatibility

Swift 6 includes a number of evolution proposals that could potentially affect source compatibility.
These are all opt-in for the Swift 5 language mode.

## Key Changes

- **NonfrozenEnumExhaustivity**: Lack of a required `@unknown default` has changed from a warning to an error
- **StrictConcurrency**: Will introduce errors for any code that risks data races
- **DeprecateApplicationMain**: Will introduce an error for any code that has not migrated to using `@main`

For a complete list of source compatibility changes, consult the Swift Evolution proposals.