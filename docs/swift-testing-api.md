# https://developer.apple.com/documentation/testing llms-full.txt

## Swift Testing Overview
[Skip Navigation](https://developer.apple.com/documentation/testing#app-main)

Framework

# Swift Testing

Create and run tests for your Swift packages and Xcode projects.

Swift 6.0+Xcode 16.0+

## [Overview](https://developer.apple.com/documentation/testing\#Overview)

![The Swift logo on a blue gradient background that contains function, number, tag, and checkmark diamond symbols.](https://docs-assets.developer.apple.com/published/bb0ec39fe3198b15d431887aac09a527/swift-testing-hero%402x.png)

With Swift Testing you leverage powerful and expressive capabilities of the Swift programming language to develop tests with more confidence and less code. The library integrates seamlessly with Swift Package Manager testing workflow, supports flexible test organization, customizable metadata, and scalable test execution.

- Define test functions almost anywhere with a single attribute.

- Group related tests into hierarchies using Swift’s type system.

- Integrate seamlessly with Swift concurrency.

- Parameterize test functions across wide ranges of inputs.

- Enable tests dynamically depending on runtime conditions.

- Parallelize tests in-process.

- Categorize tests using tags.

- Associate bugs directly with the tests that verify their fixes or reproduce their problems.


#### [Related videos](https://developer.apple.com/documentation/testing\#Related-videos)

[![](https://devimages-cdn.apple.com/wwdc-services/images/C03E6E6D-A32A-41D0-9E50-C3C6059820AA/E94A25C1-8734-483C-A4C1-862533C307AC/9309_wide_250x141_3x.jpg)\\
\\
Meet Swift Testing](https://developer.apple.com/videos/play/wwdc2024/10179)

[![](https://devimages-cdn.apple.com/wwdc-services/images/C03E6E6D-A32A-41D0-9E50-C3C6059820AA/52DB5AB3-48AF-40E1-98C7-CCC9132EDD39/9325_wide_250x141_3x.jpg)\\
\\
Go further with Swift Testing](https://developer.apple.com/videos/play/wwdc2024/10195)

## [Topics](https://developer.apple.com/documentation/testing\#topics)

### [Essentials](https://developer.apple.com/documentation/testing\#Essentials)

[Defining test functions](https://developer.apple.com/documentation/testing/definingtests)

Define a test function to validate that code is working correctly.

[Organizing test functions with suite types](https://developer.apple.com/documentation/testing/organizingtests)

Organize tests into test suites.

[Migrating a test from XCTest](https://developer.apple.com/documentation/testing/migratingfromxctest)

Migrate an existing test method or test class written using XCTest.

[`macro Test(String?, any TestTrait...)`](https://developer.apple.com/documentation/testing/test(_:_:))

Declare a test.

[`struct Test`](https://developer.apple.com/documentation/testing/test)

A type representing a test or suite.

[`macro Suite(String?, any SuiteTrait...)`](https://developer.apple.com/documentation/testing/suite(_:_:))

Declare a test suite.

### [Test parameterization](https://developer.apple.com/documentation/testing\#Test-parameterization)

[Implementing parameterized tests](https://developer.apple.com/documentation/testing/parameterizedtesting)

Specify different input parameters to generate multiple test cases from a test function.

[`macro Test<C>(String?, any TestTrait..., arguments: C)`](https://developer.apple.com/documentation/testing/test(_:_:arguments:)-8kn7a)

Declare a test parameterized over a collection of values.

[`macro Test<C1, C2>(String?, any TestTrait..., arguments: C1, C2)`](https://developer.apple.com/documentation/testing/test(_:_:arguments:_:))

Declare a test parameterized over two collections of values.

[`macro Test<C1, C2>(String?, any TestTrait..., arguments: Zip2Sequence<C1, C2>)`](https://developer.apple.com/documentation/testing/test(_:_:arguments:)-3rzok)

Declare a test parameterized over two zipped collections of values.

[`protocol CustomTestArgumentEncodable`](https://developer.apple.com/documentation/testing/customtestargumentencodable)

A protocol for customizing how arguments passed to parameterized tests are encoded, which is used to match against when running specific arguments.

[`struct Case`](https://developer.apple.com/documentation/testing/test/case)

A single test case from a parameterized [`Test`](https://developer.apple.com/documentation/testing/test).

### [Behavior validation](https://developer.apple.com/documentation/testing\#Behavior-validation)

[API Reference\\
Expectations and confirmations](https://developer.apple.com/documentation/testing/expectations)

Check for expected values, outcomes, and asynchronous events in tests.

[API Reference\\
Known issues](https://developer.apple.com/documentation/testing/known-issues)

Highlight known issues when running tests.

### [Test customization](https://developer.apple.com/documentation/testing\#Test-customization)

[API Reference\\
Traits](https://developer.apple.com/documentation/testing/traits)

Annotate test functions and suites, and customize their behavior.

Current page is Swift Testing

## Adding Tags to Tests
[Skip Navigation](https://developer.apple.com/documentation/testing/addingtags#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Traits](https://developer.apple.com/documentation/testing/traits)
- Adding tags to tests

Article

# Adding tags to tests

Use tags to provide semantic information for organization, filtering, and customizing appearances.

## [Overview](https://developer.apple.com/documentation/testing/addingtags\#Overview)

A complex package or project may contain hundreds or thousands of tests and suites. Some subset of those tests may share some common facet, such as being _critical_ or _flaky_. The testing library includes a type of trait called _tags_ that you can add to group and categorize tests.

Tags are different from test suites: test suites impose structure on test functions at the source level, while tags provide semantic information for a test that can be shared with any number of other tests across test suites, source files, and even test targets.

## [Add a tag](https://developer.apple.com/documentation/testing/addingtags\#Add-a-tag)

To add a tag to a test, use the [`tags(_:)`](https://developer.apple.com/documentation/testing/trait/tags(_:)) trait. This trait takes a sequence of tags as its argument, and those tags are then applied to the corresponding test at runtime. If any tags are applied to a test suite, then all tests in that suite inherit those tags.

The testing library doesn’t assign any semantic meaning to any tags, nor does the presence or absence of tags affect how the testing library runs tests.

Tags themselves are instances of [`Tag`](https://developer.apple.com/documentation/testing/tag) and expressed as named constants declared as static members of [`Tag`](https://developer.apple.com/documentation/testing/tag). To declare a named constant tag, use the [`Tag()`](https://developer.apple.com/documentation/testing/tag()) macro:

```
extension Tag {
  @Tag static var legallyRequired: Self
}

@Test("Vendor's license is valid", .tags(.legallyRequired))
func licenseValid() { ... }

```

If two tags with the same name ( `legallyRequired` in the above example) are declared in different files, modules, or other contexts, the testing library treats them as equivalent.

If it’s important for a tag to be distinguished from similar tags declared elsewhere in a package or project (or its dependencies), use reverse-DNS naming to create a unique Swift symbol name for your tag:

```
extension Tag {
  enum com_example_foodtruck {}
}

extension Tag.com_example_foodtruck {
  @Tag static var extraSpecial: Tag
}

@Test(
  "Extra Special Sauce recipe is secret",
  .tags(.com_example_foodtruck.extraSpecial)
)
func secretSauce() { ... }

```

### [Where tags can be declared](https://developer.apple.com/documentation/testing/addingtags\#Where-tags-can-be-declared)

Tags must always be declared as members of [`Tag`](https://developer.apple.com/documentation/testing/tag) in an extension to that type or in a type nested within [`Tag`](https://developer.apple.com/documentation/testing/tag). Redeclaring a tag under a second name has no effect and the additional name will not be recognized by the testing library. The following example is unsupported:

```
extension Tag {
  @Tag static var legallyRequired: Self // ✅ OK: Declaring a new tag.

  static var requiredByLaw: Self { // ❌ ERROR: This tag name isn't
                                   // recognized at runtime.
    legallyRequired
  }
}

```

If a tag is declared as a named constant outside of an extension to the [`Tag`](https://developer.apple.com/documentation/testing/tag) type (for example, at the root of a file or in another unrelated type declaration), it cannot be applied to test functions or test suites. The following declarations are unsupported:

```
@Tag let needsKetchup: Self // ❌ ERROR: Tags must be declared in an extension
                            // to Tag.
struct Food {
  @Tag var needsMustard: Self // ❌ ERROR: Tags must be declared in an extension
                              // to Tag.
}

```

## [See Also](https://developer.apple.com/documentation/testing/addingtags\#see-also)

### [Annotating tests](https://developer.apple.com/documentation/testing/addingtags\#Annotating-tests)

[Adding comments to tests](https://developer.apple.com/documentation/testing/addingcomments)

Add comments to provide useful information about tests.

[Associating bugs with tests](https://developer.apple.com/documentation/testing/associatingbugs)

Associate bugs uncovered or verified by tests.

[Interpreting bug identifiers](https://developer.apple.com/documentation/testing/bugidentifiers)

Examine how the testing library interprets bug identifiers provided by developers.

[`macro Tag()`](https://developer.apple.com/documentation/testing/tag())

Declare a tag that can be applied to a test function or test suite.

[`static func bug(String, Comment?) -> Self`](https://developer.apple.com/documentation/testing/trait/bug(_:_:))

Constructs a bug to track with a test.

[`static func bug(String?, id: String, Comment?) -> Self`](https://developer.apple.com/documentation/testing/trait/bug(_:id:_:)-10yf5)

Constructs a bug to track with a test.

[`static func bug(String?, id: some Numeric, Comment?) -> Self`](https://developer.apple.com/documentation/testing/trait/bug(_:id:_:)-3vtpl)

Constructs a bug to track with a test.

Current page is Adding tags to tests

## Swift Test Overview
[Skip Navigation](https://developer.apple.com/documentation/testing/test#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- Test

Structure

# Test

A type representing a test or suite.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
struct Test
```

## [Overview](https://developer.apple.com/documentation/testing/test\#overview)

An instance of this type may represent:

- A type containing zero or more tests (i.e. a _test suite_);

- An individual test function (possibly contained within a type); or

- A test function parameterized over one or more sequences of inputs.


Two instances of this type are considered to be equal if the values of their [`id`](https://developer.apple.com/documentation/testing/test/id-swift.property) properties are equal.

## [Topics](https://developer.apple.com/documentation/testing/test\#topics)

### [Structures](https://developer.apple.com/documentation/testing/test\#Structures)

[`struct Case`](https://developer.apple.com/documentation/testing/test/case)

A single test case from a parameterized [`Test`](https://developer.apple.com/documentation/testing/test).

### [Instance Properties](https://developer.apple.com/documentation/testing/test\#Instance-Properties)

[`var associatedBugs: [Bug]`](https://developer.apple.com/documentation/testing/test/associatedbugs)

The set of bugs associated with this test.

[`var comments: [Comment]`](https://developer.apple.com/documentation/testing/test/comments)

The complete set of comments about this test from all of its traits.

[`var displayName: String?`](https://developer.apple.com/documentation/testing/test/displayname)

The customized display name of this instance, if specified.

[`var isParameterized: Bool`](https://developer.apple.com/documentation/testing/test/isparameterized)

Whether or not this test is parameterized.

[`var isSuite: Bool`](https://developer.apple.com/documentation/testing/test/issuite)

Whether or not this instance is a test suite containing other tests.

[`var name: String`](https://developer.apple.com/documentation/testing/test/name)

The name of this instance.

[`var sourceLocation: SourceLocation`](https://developer.apple.com/documentation/testing/test/sourcelocation)

The source location of this test.

[`var tags: Set<Tag>`](https://developer.apple.com/documentation/testing/test/tags)

The complete, unique set of tags associated with this test.

[`var timeLimit: Duration?`](https://developer.apple.com/documentation/testing/test/timelimit)

The maximum amount of time this test’s cases may run for.

[`var traits: [any Trait]`](https://developer.apple.com/documentation/testing/test/traits)

The set of traits added to this instance when it was initialized.

### [Type Properties](https://developer.apple.com/documentation/testing/test\#Type-Properties)

[`static var current: Test?`](https://developer.apple.com/documentation/testing/test/current)

The test that is running on the current task, if any.

### [Default Implementations](https://developer.apple.com/documentation/testing/test\#Default-Implementations)

[API Reference\\
Equatable Implementations](https://developer.apple.com/documentation/testing/test/equatable-implementations)

[API Reference\\
Hashable Implementations](https://developer.apple.com/documentation/testing/test/hashable-implementations)

[API Reference\\
Identifiable Implementations](https://developer.apple.com/documentation/testing/test/identifiable-implementations)

## [Relationships](https://developer.apple.com/documentation/testing/test\#relationships)

### [Conforms To](https://developer.apple.com/documentation/testing/test\#conforms-to)

- [`Copyable`](https://developer.apple.com/documentation/Swift/Copyable)
- [`Equatable`](https://developer.apple.com/documentation/Swift/Equatable)
- [`Hashable`](https://developer.apple.com/documentation/Swift/Hashable)
- [`Identifiable`](https://developer.apple.com/documentation/Swift/Identifiable)
- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable)

## [See Also](https://developer.apple.com/documentation/testing/test\#see-also)

### [Essentials](https://developer.apple.com/documentation/testing/test\#Essentials)

[Defining test functions](https://developer.apple.com/documentation/testing/definingtests)

Define a test function to validate that code is working correctly.

[Organizing test functions with suite types](https://developer.apple.com/documentation/testing/organizingtests)

Organize tests into test suites.

[Migrating a test from XCTest](https://developer.apple.com/documentation/testing/migratingfromxctest)

Migrate an existing test method or test class written using XCTest.

[`macro Test(String?, any TestTrait...)`](https://developer.apple.com/documentation/testing/test(_:_:))

Declare a test.

[`macro Suite(String?, any SuiteTrait...)`](https://developer.apple.com/documentation/testing/suite(_:_:))

Declare a test suite.

Current page is Test

## Adding Comments to Tests
[Skip Navigation](https://developer.apple.com/documentation/testing/addingcomments#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Traits](https://developer.apple.com/documentation/testing/traits)
- Adding comments to tests

Article

# Adding comments to tests

Add comments to provide useful information about tests.

## [Overview](https://developer.apple.com/documentation/testing/addingcomments\#Overview)

It’s often useful to add comments to code to:

- Provide context or background information about the code’s purpose

- Explain how complex code implemented

- Include details which may be helpful when diagnosing issues


Test code is no different and can benefit from explanatory code comments, but often test issues are shown in places where the source code of the test is unavailable such as in continuous integration (CI) interfaces or in log files.

Seeing comments related to tests in these contexts can help diagnose issues more quickly. Comments can be added to test declarations and the testing library will automatically capture and show them when issues are recorded.

## [Add a code comment to a test](https://developer.apple.com/documentation/testing/addingcomments\#Add-a-code-comment-to-a-test)

To include a comment on a test or suite, write an ordinary Swift code comment immediately before its `@Test` or `@Suite` attribute:

```
// Assumes the standard lunch menu includes a taco
@Test func lunchMenu() {
  let foodTruck = FoodTruck(
    menu: .lunch,
    ingredients: [.tortillas, .cheese]
  )
  #expect(foodTruck.menu.contains { $0 is Taco })
}

```

The comment, `// Assumes the standard lunch menu includes a taco`, is added to the test.

The following language comment styles are supported:

| Syntax | Style |
| --- | --- |
| `// ...` | Line comment |
| `/// ...` | Documentation line comment |
| `/* ... */` | Block comment |
| `/** ... */` | Documentation block comment |

### [Comment formatting](https://developer.apple.com/documentation/testing/addingcomments\#Comment-formatting)

Test comments which are automatically added from source code comments preserve their original formatting, including any prefixes like `//` or `/**`. This is because the whitespace and formatting of comments can be meaningful in some circumstances or aid in understanding the comment — for example, when a comment includes an example code snippet or diagram.

## [Use test comments effectively](https://developer.apple.com/documentation/testing/addingcomments\#Use-test-comments-effectively)

As in normal code, comments on tests are generally most useful when they:

- Add information that isn’t obvious from reading the code

- Provide useful information about the operation or motivation of a test


If a test is related to a bug or issue, consider using the [`Bug`](https://developer.apple.com/documentation/testing/bug) trait instead of comments. For more information, see [Associating bugs with tests](https://developer.apple.com/documentation/testing/associatingbugs).

## [See Also](https://developer.apple.com/documentation/testing/addingcomments\#see-also)

### [Annotating tests](https://developer.apple.com/documentation/testing/addingcomments\#Annotating-tests)

[Adding tags to tests](https://developer.apple.com/documentation/testing/addingtags)

Use tags to provide semantic information for organization, filtering, and customizing appearances.

[Associating bugs with tests](https://developer.apple.com/documentation/testing/associatingbugs)

Associate bugs uncovered or verified by tests.

[Interpreting bug identifiers](https://developer.apple.com/documentation/testing/bugidentifiers)

Examine how the testing library interprets bug identifiers provided by developers.

[`macro Tag()`](https://developer.apple.com/documentation/testing/tag())

Declare a tag that can be applied to a test function or test suite.

[`static func bug(String, Comment?) -> Self`](https://developer.apple.com/documentation/testing/trait/bug(_:_:))

Constructs a bug to track with a test.

[`static func bug(String?, id: String, Comment?) -> Self`](https://developer.apple.com/documentation/testing/trait/bug(_:id:_:)-10yf5)

Constructs a bug to track with a test.

[`static func bug(String?, id: some Numeric, Comment?) -> Self`](https://developer.apple.com/documentation/testing/trait/bug(_:id:_:)-3vtpl)

Constructs a bug to track with a test.

Current page is Adding comments to tests

## Organizing Test Functions
[Skip Navigation](https://developer.apple.com/documentation/testing/organizingtests#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- Organizing test functions with suite types

Article

# Organizing test functions with suite types

Organize tests into test suites.

## [Overview](https://developer.apple.com/documentation/testing/organizingtests\#Overview)

When working with a large selection of test functions, it can be helpful to organize them into test suites.

A test function can be added to a test suite in one of two ways:

- By placing it in a Swift type.

- By placing it in a Swift type and annotating that type with the `@Suite` attribute.


The `@Suite` attribute isn’t required for the testing library to recognize that a type contains test functions, but adding it allows customization of a test suite’s appearance in the IDE and at the command line. If a trait such as [`tags(_:)`](https://developer.apple.com/documentation/testing/trait/tags(_:)) or [`disabled(_:sourceLocation:)`](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:)) is applied to a test suite, it’s automatically inherited by the tests contained in the suite.

In addition to containing test functions and any other members that a Swift type might contain, test suite types can also contain additional test suites nested within them. To add a nested test suite type, simply declare an additional type within the scope of the outer test suite type.

By default, tests contained within a suite run in parallel with each other. For more information about test parallelization, see [Running tests serially or in parallel](https://developer.apple.com/documentation/testing/parallelization).

### [Customize a suite’s name](https://developer.apple.com/documentation/testing/organizingtests\#Customize-a-suites-name)

To customize a test suite’s name, supply a string literal as an argument to the `@Suite` attribute:

```
@Suite("Food truck tests") struct FoodTruckTests {
  @Test func foodTruckExists() { ... }
}

```

To further customize the appearance and behavior of a test function, use [traits](https://developer.apple.com/documentation/testing/traits) such as [`tags(_:)`](https://developer.apple.com/documentation/testing/trait/tags(_:)).

## [Test functions in test suite types](https://developer.apple.com/documentation/testing/organizingtests\#Test-functions-in-test-suite-types)

If a type contains a test function declared as an instance method (that is, without either the `static` or `class` keyword), the testing library calls that test function at runtime by initializing an instance of the type, then calling the test function on that instance. If a test suite type contains multiple test functions declared as instance methods, each one is called on a distinct instance of the type. Therefore, the following test suite and test function:

```
@Suite struct FoodTruckTests {
  @Test func foodTruckExists() { ... }
}

```

Are equivalent to:

```
@Suite struct FoodTruckTests {
  func foodTruckExists() { ... }

  @Test static func staticFoodTruckExists() {
    let instance = FoodTruckTests()
    instance.foodTruckExists()
  }
}

```

### [Constraints on test suite types](https://developer.apple.com/documentation/testing/organizingtests\#Constraints-on-test-suite-types)

When using a type as a test suite, it’s subject to some constraints that are not otherwise applied to Swift types.

#### [An initializer may be required](https://developer.apple.com/documentation/testing/organizingtests\#An-initializer-may-be-required)

If a type contains test functions declared as instance methods, it must be possible to initialize an instance of the type with a zero-argument initializer. The initializer may be any combination of:

- implicit or explicit

- synchronous or asynchronous

- throwing or non-throwing

- `private`, `fileprivate`, `internal`, `package`, or `public`


For example:

```
@Suite struct FoodTruckTests {
  var batteryLevel = 100

  @Test func foodTruckExists() { ... } // ✅ OK: The type has an implicit init().
}

@Suite struct CashRegisterTests {
  private init(cashOnHand: Decimal = 0.0) async throws { ... }

  @Test func calculateSalesTax() { ... } // ✅ OK: The type has a callable init().
}

struct MenuTests {
  var foods: [Food]
  var prices: [Food: Decimal]

  @Test static func specialOfTheDay() { ... } // ✅ OK: The function is static.
  @Test func orderAllFoods() { ... } // ❌ ERROR: The suite type requires init().
}

```

The compiler emits an error when presented with a test suite that doesn’t meet this requirement.

### [Test suite types must always be available](https://developer.apple.com/documentation/testing/organizingtests\#Test-suite-types-must-always-be-available)

Although `@available` can be applied to a test function to limit its availability at runtime, a test suite type (and any types that contain it) must _not_ be annotated with the `@available` attribute:

```
@Suite struct FoodTruckTests { ... } // ✅ OK: The type is always available.

@available(macOS 11.0, *) // ❌ ERROR: The suite type must always be available.
@Suite struct CashRegisterTests { ... }

@available(macOS 11.0, *) struct MenuItemTests { // ❌ ERROR: The suite type's
                                                 // containing type must always
                                                 // be available too.
  @Suite struct BurgerTests { ... }
}

```

The compiler emits an error when presented with a test suite that doesn’t meet this requirement.

## [See Also](https://developer.apple.com/documentation/testing/organizingtests\#see-also)

### [Essentials](https://developer.apple.com/documentation/testing/organizingtests\#Essentials)

[Defining test functions](https://developer.apple.com/documentation/testing/definingtests)

Define a test function to validate that code is working correctly.

[Migrating a test from XCTest](https://developer.apple.com/documentation/testing/migratingfromxctest)

Migrate an existing test method or test class written using XCTest.

[`macro Test(String?, any TestTrait...)`](https://developer.apple.com/documentation/testing/test(_:_:))

Declare a test.

[`struct Test`](https://developer.apple.com/documentation/testing/test)

A type representing a test or suite.

[`macro Suite(String?, any SuiteTrait...)`](https://developer.apple.com/documentation/testing/suite(_:_:))

Declare a test suite.

Current page is Organizing test functions with suite types

## Custom Test Argument Encoding
[Skip Navigation](https://developer.apple.com/documentation/testing/customtestargumentencodable#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- CustomTestArgumentEncodable

Protocol

# CustomTestArgumentEncodable

A protocol for customizing how arguments passed to parameterized tests are encoded, which is used to match against when running specific arguments.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
protocol CustomTestArgumentEncodable : Sendable
```

## [Mentioned in](https://developer.apple.com/documentation/testing/customtestargumentencodable\#mentions)

[Implementing parameterized tests](https://developer.apple.com/documentation/testing/parameterizedtesting)

## [Overview](https://developer.apple.com/documentation/testing/customtestargumentencodable\#overview)

The testing library checks whether a test argument conforms to this protocol, or any of several other known protocols, when running selected test cases. When a test argument conforms to this protocol, that conformance takes highest priority, and the testing library will then call [`encodeTestArgument(to:)`](https://developer.apple.com/documentation/testing/customtestargumentencodable/encodetestargument(to:)) on the argument. A type that conforms to this protocol is not required to conform to either `Encodable` or `Decodable`.

See [Implementing parameterized tests](https://developer.apple.com/documentation/testing/parameterizedtesting) for a list of the other supported ways to allow running selected test cases.

## [Topics](https://developer.apple.com/documentation/testing/customtestargumentencodable\#topics)

### [Instance Methods](https://developer.apple.com/documentation/testing/customtestargumentencodable\#Instance-Methods)

[`func encodeTestArgument(to: some Encoder) throws`](https://developer.apple.com/documentation/testing/customtestargumentencodable/encodetestargument(to:))

Encode this test argument.

**Required**

## [Relationships](https://developer.apple.com/documentation/testing/customtestargumentencodable\#relationships)

### [Inherits From](https://developer.apple.com/documentation/testing/customtestargumentencodable\#inherits-from)

- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable)

## [See Also](https://developer.apple.com/documentation/testing/customtestargumentencodable\#see-also)

### [Related Documentation](https://developer.apple.com/documentation/testing/customtestargumentencodable\#Related-Documentation)

[Implementing parameterized tests](https://developer.apple.com/documentation/testing/parameterizedtesting)

Specify different input parameters to generate multiple test cases from a test function.

### [Test parameterization](https://developer.apple.com/documentation/testing/customtestargumentencodable\#Test-parameterization)

[Implementing parameterized tests](https://developer.apple.com/documentation/testing/parameterizedtesting)

Specify different input parameters to generate multiple test cases from a test function.

[`macro Test<C>(String?, any TestTrait..., arguments: C)`](https://developer.apple.com/documentation/testing/test(_:_:arguments:)-8kn7a)

Declare a test parameterized over a collection of values.

[`macro Test<C1, C2>(String?, any TestTrait..., arguments: C1, C2)`](https://developer.apple.com/documentation/testing/test(_:_:arguments:_:))

Declare a test parameterized over two collections of values.

[`macro Test<C1, C2>(String?, any TestTrait..., arguments: Zip2Sequence<C1, C2>)`](https://developer.apple.com/documentation/testing/test(_:_:arguments:)-3rzok)

Declare a test parameterized over two zipped collections of values.

[`struct Case`](https://developer.apple.com/documentation/testing/test/case)

A single test case from a parameterized [`Test`](https://developer.apple.com/documentation/testing/test).

Current page is CustomTestArgumentEncodable

## Defining Test Functions
[Skip Navigation](https://developer.apple.com/documentation/testing/definingtests#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- Defining test functions

Article

# Defining test functions

Define a test function to validate that code is working correctly.

## [Overview](https://developer.apple.com/documentation/testing/definingtests\#Overview)

Defining a test function for a Swift package or project is straightforward.

### [Import the testing library](https://developer.apple.com/documentation/testing/definingtests\#Import-the-testing-library)

To import the testing library, add the following to the Swift source file that contains the test:

```
import Testing

```

### [Declare a test function](https://developer.apple.com/documentation/testing/definingtests\#Declare-a-test-function)

To declare a test function, write a Swift function declaration that doesn’t take any arguments, then prefix its name with the `@Test` attribute:

```
@Test func foodTruckExists() {
  // Test logic goes here.
}

```

This test function can be present at file scope or within a type. A type containing test functions is automatically a _test suite_ and can be optionally annotated with the `@Suite` attribute. For more information about suites, see [Organizing test functions with suite types](https://developer.apple.com/documentation/testing/organizingtests).

Note that, while this function is a valid test function, it doesn’t actually perform any action or test any code. To check for expected values and outcomes in test functions, add [expectations](https://developer.apple.com/documentation/testing/expectations) to the test function.

### [Customize a test’s name](https://developer.apple.com/documentation/testing/definingtests\#Customize-a-tests-name)

To customize a test function’s name as presented in an IDE or at the command line, supply a string literal as an argument to the `@Test` attribute:

```
@Test("Food truck exists") func foodTruckExists() { ... }

```

To further customize the appearance and behavior of a test function, use [traits](https://developer.apple.com/documentation/testing/traits) such as [`tags(_:)`](https://developer.apple.com/documentation/testing/trait/tags(_:)).

### [Write concurrent or throwing tests](https://developer.apple.com/documentation/testing/definingtests\#Write-concurrent-or-throwing-tests)

As with other Swift functions, test functions can be marked `async` and `throws` to annotate them as concurrent or throwing, respectively. If a test is only safe to run in the main actor’s execution context (that is, from the main thread of the process), it can be annotated `@MainActor`:

```
@Test @MainActor func foodTruckExists() async throws { ... }

```

### [Limit the availability of a test](https://developer.apple.com/documentation/testing/definingtests\#Limit-the-availability-of-a-test)

If a test function can only run on newer versions of an operating system or of the Swift language, use the `@available` attribute when declaring it. Use the `message` argument of the `@available` attribute to specify a message to log if a test is unable to run due to limited availability:

```
@available(macOS 11.0, *)
@available(swift, introduced: 8.0, message: "Requires Swift 8.0 features to run")
@Test func foodTruckExists() { ... }

```

## [See Also](https://developer.apple.com/documentation/testing/definingtests\#see-also)

### [Essentials](https://developer.apple.com/documentation/testing/definingtests\#Essentials)

[Organizing test functions with suite types](https://developer.apple.com/documentation/testing/organizingtests)

Organize tests into test suites.

[Migrating a test from XCTest](https://developer.apple.com/documentation/testing/migratingfromxctest)

Migrate an existing test method or test class written using XCTest.

[`macro Test(String?, any TestTrait...)`](https://developer.apple.com/documentation/testing/test(_:_:))

Declare a test.

[`struct Test`](https://developer.apple.com/documentation/testing/test)

A type representing a test or suite.

[`macro Suite(String?, any SuiteTrait...)`](https://developer.apple.com/documentation/testing/suite(_:_:))

Declare a test suite.

Current page is Defining test functions

## Interpreting Bug Identifiers
[Skip Navigation](https://developer.apple.com/documentation/testing/bugidentifiers#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Traits](https://developer.apple.com/documentation/testing/traits)
- Interpreting bug identifiers

Article

# Interpreting bug identifiers

Examine how the testing library interprets bug identifiers provided by developers.

## [Overview](https://developer.apple.com/documentation/testing/bugidentifiers\#Overview)

The testing library supports two distinct ways to identify a bug:

1. A URL linking to more information about the bug; and

2. A unique identifier in the bug’s associated bug-tracking system.


A bug may have both an associated URL _and_ an associated unique identifier. It must have at least one or the other in order for the testing library to be able to interpret it correctly.

To create an instance of [`Bug`](https://developer.apple.com/documentation/testing/bug) with a URL, use the [`bug(_:_:)`](https://developer.apple.com/documentation/testing/trait/bug(_:_:)) trait. At compile time, the testing library will validate that the given string can be parsed as a URL according to [RFC 3986](https://www.ietf.org/rfc/rfc3986.txt).

To create an instance of [`Bug`](https://developer.apple.com/documentation/testing/bug) with a bug’s unique identifier, use the [`bug(_:id:_:)`](https://developer.apple.com/documentation/testing/trait/bug(_:id:_:)-10yf5) trait. The testing library does not require that a bug’s unique identifier match any particular format, but will interpret unique identifiers starting with `"FB"` as referring to bugs tracked with the [Apple Feedback Assistant](https://feedbackassistant.apple.com/). For convenience, you can also directly pass an integer as a bug’s identifier using [`bug(_:id:_:)`](https://developer.apple.com/documentation/testing/trait/bug(_:id:_:)-3vtpl).

### [Examples](https://developer.apple.com/documentation/testing/bugidentifiers\#Examples)

| Trait Function | Inferred Bug-Tracking System |
| --- | --- |
| `.bug(id: 12345)` | None |
| `.bug(id: "12345")` | None |
| `.bug("https://www.example.com?id=12345", id: "12345")` | None |
| `.bug("https://github.com/swiftlang/swift/pull/12345")` | [GitHub Issues for the Swift project](https://github.com/swiftlang/swift/issues) |
| `.bug("https://bugs.webkit.org/show_bug.cgi?id=12345")` | [WebKit Bugzilla](https://bugs.webkit.org/) |
| `.bug(id: "FB12345")` | Apple Feedback Assistant |

## [See Also](https://developer.apple.com/documentation/testing/bugidentifiers\#see-also)

### [Annotating tests](https://developer.apple.com/documentation/testing/bugidentifiers\#Annotating-tests)

[Adding tags to tests](https://developer.apple.com/documentation/testing/addingtags)

Use tags to provide semantic information for organization, filtering, and customizing appearances.

[Adding comments to tests](https://developer.apple.com/documentation/testing/addingcomments)

Add comments to provide useful information about tests.

[Associating bugs with tests](https://developer.apple.com/documentation/testing/associatingbugs)

Associate bugs uncovered or verified by tests.

[`macro Tag()`](https://developer.apple.com/documentation/testing/tag())

Declare a tag that can be applied to a test function or test suite.

[`static func bug(String, Comment?) -> Self`](https://developer.apple.com/documentation/testing/trait/bug(_:_:))

Constructs a bug to track with a test.

[`static func bug(String?, id: String, Comment?) -> Self`](https://developer.apple.com/documentation/testing/trait/bug(_:id:_:)-10yf5)

Constructs a bug to track with a test.

[`static func bug(String?, id: some Numeric, Comment?) -> Self`](https://developer.apple.com/documentation/testing/trait/bug(_:id:_:)-3vtpl)

Constructs a bug to track with a test.

Current page is Interpreting bug identifiers

## Limiting Test Execution Time
[Skip Navigation](https://developer.apple.com/documentation/testing/limitingexecutiontime#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Traits](https://developer.apple.com/documentation/testing/traits)
- Limiting the running time of tests

Article

# Limiting the running time of tests

Set limits on how long a test can run for until it fails.

## [Overview](https://developer.apple.com/documentation/testing/limitingexecutiontime\#Overview)

Some tests may naturally run slowly: they may require significant system resources to complete, may rely on downloaded data from a server, or may otherwise be dependent on external factors.

If a test may hang indefinitely or may consume too many system resources to complete effectively, consider setting a time limit for it so that it’s marked as failing if it runs for an excessive amount of time. Use the [`timeLimit(_:)`](https://developer.apple.com/documentation/testing/trait/timelimit(_:)) trait as an upper bound:

```
@Test(.timeLimit(.minutes(60))
func serve100CustomersInOneHour() async {
  for _ in 0 ..< 100 {
    let customer = await Customer.next()
    await customer.order()
    ...
  }
}

```

If the above test function takes longer than an hour (60 x 60 seconds) to execute, the task in which it’s running is [cancelled](https://developer.apple.com/documentation/swift/task/cancel()) and the test fails with an issue of kind [`Issue.Kind.timeLimitExceeded(timeLimitComponents:)`](https://developer.apple.com/documentation/testing/issue/kind-swift.enum/timelimitexceeded(timelimitcomponents:)).

The testing library may adjust the specified time limit for performance reasons or to ensure tests have enough time to run. In particular, a granularity of (by default) one minute is applied to tests. The testing library can also be configured with a maximum time limit per test that overrides any applied time limit traits.

### [Time limits applied to test suites](https://developer.apple.com/documentation/testing/limitingexecutiontime\#Time-limits-applied-to-test-suites)

When a time limit is applied to a test suite, it’s recursively applied to all test functions and child test suites within that suite.

### [Time limits applied to parameterized tests](https://developer.apple.com/documentation/testing/limitingexecutiontime\#Time-limits-applied-to-parameterized-tests)

When a time limit is applied to a parameterized test function, it’s applied to each invocation _separately_ so that if only some arguments cause failures, then successful arguments aren’t incorrectly marked as failing too.

## [See Also](https://developer.apple.com/documentation/testing/limitingexecutiontime\#see-also)

### [Customizing runtime behaviors](https://developer.apple.com/documentation/testing/limitingexecutiontime\#Customizing-runtime-behaviors)

[Enabling and disabling tests](https://developer.apple.com/documentation/testing/enablinganddisabling)

Conditionally enable or disable individual tests before they run.

[`static func enabled(if: @autoclosure () throws -> Bool, Comment?, sourceLocation: SourceLocation) -> Self`](https://developer.apple.com/documentation/testing/trait/enabled(if:_:sourcelocation:))

Constructs a condition trait that disables a test if it returns `false`.

[`static func enabled(Comment?, sourceLocation: SourceLocation, () async throws -> Bool) -> Self`](https://developer.apple.com/documentation/testing/trait/enabled(_:sourcelocation:_:))

Constructs a condition trait that disables a test if it returns `false`.

[`static func disabled(Comment?, sourceLocation: SourceLocation) -> Self`](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:))

Constructs a condition trait that disables a test unconditionally.

[`static func disabled(if: @autoclosure () throws -> Bool, Comment?, sourceLocation: SourceLocation) -> Self`](https://developer.apple.com/documentation/testing/trait/disabled(if:_:sourcelocation:))

Constructs a condition trait that disables a test if its value is true.

[`static func disabled(Comment?, sourceLocation: SourceLocation, () async throws -> Bool) -> Self`](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:_:))

Constructs a condition trait that disables a test if its value is true.

[`static func timeLimit(TimeLimitTrait.Duration) -> Self`](https://developer.apple.com/documentation/testing/trait/timelimit(_:))

Construct a time limit trait that causes a test to time out if it runs for too long.

Current page is Limiting the running time of tests

## Test Scoping Protocol
[Skip Navigation](https://developer.apple.com/documentation/testing/testscoping#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- TestScoping

Protocol

# TestScoping

A protocol that tells the test runner to run custom code before or after it runs a test suite or test function.

Swift 6.1+Xcode 16.3+

```
protocol TestScoping : Sendable
```

## [Overview](https://developer.apple.com/documentation/testing/testscoping\#overview)

Provide custom scope for tests by implementing the [`scopeProvider(for:testCase:)`](https://developer.apple.com/documentation/testing/trait/scopeprovider(for:testcase:)) method, returning a type that conforms to this protocol. Create a custom scope to consolidate common set-up and tear-down logic for tests which have similar needs, which allows each test function to focus on the unique aspects of its test.

## [Topics](https://developer.apple.com/documentation/testing/testscoping\#topics)

### [Instance Methods](https://developer.apple.com/documentation/testing/testscoping\#Instance-Methods)

[`func provideScope(for: Test, testCase: Test.Case?, performing: () async throws -> Void) async throws`](https://developer.apple.com/documentation/testing/testscoping/providescope(for:testcase:performing:))

Provide custom execution scope for a function call which is related to the specified test or test case.

**Required**

## [Relationships](https://developer.apple.com/documentation/testing/testscoping\#relationships)

### [Inherits From](https://developer.apple.com/documentation/testing/testscoping\#inherits-from)

- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable)

## [See Also](https://developer.apple.com/documentation/testing/testscoping\#see-also)

### [Creating custom traits](https://developer.apple.com/documentation/testing/testscoping\#Creating-custom-traits)

[`protocol Trait`](https://developer.apple.com/documentation/testing/trait)

A protocol describing traits that can be added to a test function or to a test suite.

[`protocol TestTrait`](https://developer.apple.com/documentation/testing/testtrait)

A protocol describing a trait that you can add to a test function.

[`protocol SuiteTrait`](https://developer.apple.com/documentation/testing/suitetrait)

A protocol describing a trait that you can add to a test suite.

Current page is TestScoping

## Event Confirmation Type
[Skip Navigation](https://developer.apple.com/documentation/testing/confirmation#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- Confirmation

Structure

# Confirmation

A type that can be used to confirm that an event occurs zero or more times.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
struct Confirmation
```

## [Mentioned in](https://developer.apple.com/documentation/testing/confirmation\#mentions)

[Testing asynchronous code](https://developer.apple.com/documentation/testing/testing-asynchronous-code)

[Migrating a test from XCTest](https://developer.apple.com/documentation/testing/migratingfromxctest)

## [Topics](https://developer.apple.com/documentation/testing/confirmation\#topics)

### [Instance Methods](https://developer.apple.com/documentation/testing/confirmation\#Instance-Methods)

[`func callAsFunction(count: Int)`](https://developer.apple.com/documentation/testing/confirmation/callasfunction(count:))

Confirm this confirmation.

[`func confirm(count: Int)`](https://developer.apple.com/documentation/testing/confirmation/confirm(count:))

Confirm this confirmation.

## [Relationships](https://developer.apple.com/documentation/testing/confirmation\#relationships)

### [Conforms To](https://developer.apple.com/documentation/testing/confirmation\#conforms-to)

- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable)

## [See Also](https://developer.apple.com/documentation/testing/confirmation\#see-also)

### [Confirming that asynchronous events occur](https://developer.apple.com/documentation/testing/confirmation\#Confirming-that-asynchronous-events-occur)

[Testing asynchronous code](https://developer.apple.com/documentation/testing/testing-asynchronous-code)

Validate whether your code causes expected events to happen.

[`func confirmation<R>(Comment?, expectedCount: Int, isolation: isolated (any Actor)?, sourceLocation: SourceLocation, (Confirmation) async throws -> sending R) async rethrows -> R`](https://developer.apple.com/documentation/testing/confirmation(_:expectedcount:isolation:sourcelocation:_:)-5mqz2)

Confirm that some event occurs during the invocation of a function.

[`func confirmation<R>(Comment?, expectedCount: some RangeExpression<Int> & Sendable & Sequence<Int>, isolation: isolated (any Actor)?, sourceLocation: SourceLocation, (Confirmation) async throws -> sending R) async rethrows -> R`](https://developer.apple.com/documentation/testing/confirmation(_:expectedcount:isolation:sourcelocation:_:)-l3il)

Confirm that some event occurs during the invocation of a function.

Current page is Confirmation

## Tag Type Overview
[Skip Navigation](https://developer.apple.com/documentation/testing/tag#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- Tag

Structure

# Tag

A type representing a tag that can be applied to a test.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
struct Tag
```

## [Mentioned in](https://developer.apple.com/documentation/testing/tag\#mentions)

[Adding tags to tests](https://developer.apple.com/documentation/testing/addingtags)

## [Overview](https://developer.apple.com/documentation/testing/tag\#overview)

To apply tags to a test, use the [`tags(_:)`](https://developer.apple.com/documentation/testing/trait/tags(_:)) function.

## [Topics](https://developer.apple.com/documentation/testing/tag\#topics)

### [Structures](https://developer.apple.com/documentation/testing/tag\#Structures)

[`struct List`](https://developer.apple.com/documentation/testing/tag/list)

A type representing one or more tags applied to a test.

### [Default Implementations](https://developer.apple.com/documentation/testing/tag\#Default-Implementations)

[API Reference\\
CodingKeyRepresentable Implementations](https://developer.apple.com/documentation/testing/tag/codingkeyrepresentable-implementations)

[API Reference\\
Comparable Implementations](https://developer.apple.com/documentation/testing/tag/comparable-implementations)

[API Reference\\
CustomStringConvertible Implementations](https://developer.apple.com/documentation/testing/tag/customstringconvertible-implementations)

[API Reference\\
Decodable Implementations](https://developer.apple.com/documentation/testing/tag/decodable-implementations)

[API Reference\\
Encodable Implementations](https://developer.apple.com/documentation/testing/tag/encodable-implementations)

[API Reference\\
Equatable Implementations](https://developer.apple.com/documentation/testing/tag/equatable-implementations)

[API Reference\\
Hashable Implementations](https://developer.apple.com/documentation/testing/tag/hashable-implementations)

## [Relationships](https://developer.apple.com/documentation/testing/tag\#relationships)

### [Conforms To](https://developer.apple.com/documentation/testing/tag\#conforms-to)

- [`CodingKeyRepresentable`](https://developer.apple.com/documentation/Swift/CodingKeyRepresentable)
- [`Comparable`](https://developer.apple.com/documentation/Swift/Comparable)
- [`Copyable`](https://developer.apple.com/documentation/Swift/Copyable)
- [`CustomStringConvertible`](https://developer.apple.com/documentation/Swift/CustomStringConvertible)
- [`Decodable`](https://developer.apple.com/documentation/Swift/Decodable)
- [`Encodable`](https://developer.apple.com/documentation/Swift/Encodable)
- [`Equatable`](https://developer.apple.com/documentation/Swift/Equatable)
- [`Hashable`](https://developer.apple.com/documentation/Swift/Hashable)
- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable)

## [See Also](https://developer.apple.com/documentation/testing/tag\#see-also)

### [Supporting types](https://developer.apple.com/documentation/testing/tag\#Supporting-types)

[`struct Bug`](https://developer.apple.com/documentation/testing/bug)

A type that represents a bug report tracked by a test.

[`struct Comment`](https://developer.apple.com/documentation/testing/comment)

A type that represents a comment related to a test.

[`struct ConditionTrait`](https://developer.apple.com/documentation/testing/conditiontrait)

A type that defines a condition which must be satisfied for the testing library to enable a test.

[`struct ParallelizationTrait`](https://developer.apple.com/documentation/testing/parallelizationtrait)

A type that defines whether the testing library runs this test serially or in parallel.

[`struct List`](https://developer.apple.com/documentation/testing/tag/list)

A type representing one or more tags applied to a test.

[`struct TimeLimitTrait`](https://developer.apple.com/documentation/testing/timelimittrait)

A type that defines a time limit to apply to a test.

Current page is Tag

## SuiteTrait Protocol
[Skip Navigation](https://developer.apple.com/documentation/testing/suitetrait#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- SuiteTrait

Protocol

# SuiteTrait

A protocol describing a trait that you can add to a test suite.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
protocol SuiteTrait : Trait
```

## [Overview](https://developer.apple.com/documentation/testing/suitetrait\#overview)

The testing library defines a number of traits that you can add to test suites. You can also define your own traits by creating types that conform to this protocol, or to the [`TestTrait`](https://developer.apple.com/documentation/testing/testtrait) protocol.

## [Topics](https://developer.apple.com/documentation/testing/suitetrait\#topics)

### [Instance Properties](https://developer.apple.com/documentation/testing/suitetrait\#Instance-Properties)

[`var isRecursive: Bool`](https://developer.apple.com/documentation/testing/suitetrait/isrecursive)

Whether this instance should be applied recursively to child test suites and test functions.

**Required** Default implementation provided.

## [Relationships](https://developer.apple.com/documentation/testing/suitetrait\#relationships)

### [Inherits From](https://developer.apple.com/documentation/testing/suitetrait\#inherits-from)

- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable)
- [`Trait`](https://developer.apple.com/documentation/testing/trait)

### [Conforming Types](https://developer.apple.com/documentation/testing/suitetrait\#conforming-types)

- [`Bug`](https://developer.apple.com/documentation/testing/bug)
- [`Comment`](https://developer.apple.com/documentation/testing/comment)
- [`ConditionTrait`](https://developer.apple.com/documentation/testing/conditiontrait)
- [`ParallelizationTrait`](https://developer.apple.com/documentation/testing/parallelizationtrait)
- [`Tag.List`](https://developer.apple.com/documentation/testing/tag/list)
- [`TimeLimitTrait`](https://developer.apple.com/documentation/testing/timelimittrait)

## [See Also](https://developer.apple.com/documentation/testing/suitetrait\#see-also)

### [Creating custom traits](https://developer.apple.com/documentation/testing/suitetrait\#Creating-custom-traits)

[`protocol Trait`](https://developer.apple.com/documentation/testing/trait)

A protocol describing traits that can be added to a test function or to a test suite.

[`protocol TestTrait`](https://developer.apple.com/documentation/testing/testtrait)

A protocol describing a trait that you can add to a test function.

[`protocol TestScoping`](https://developer.apple.com/documentation/testing/testscoping)

A protocol that tells the test runner to run custom code before or after it runs a test suite or test function.

Current page is SuiteTrait

## Trait Protocol
[Skip Navigation](https://developer.apple.com/documentation/testing/trait#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- Trait

Protocol

# Trait

A protocol describing traits that can be added to a test function or to a test suite.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
protocol Trait : Sendable
```

## [Overview](https://developer.apple.com/documentation/testing/trait\#overview)

The testing library defines a number of traits that can be added to test functions and to test suites. Define your own traits by creating types that conform to [`TestTrait`](https://developer.apple.com/documentation/testing/testtrait) or [`SuiteTrait`](https://developer.apple.com/documentation/testing/suitetrait):

[`TestTrait`](https://developer.apple.com/documentation/testing/testtrait)

Conform to this type in traits that you add to test functions.

[`SuiteTrait`](https://developer.apple.com/documentation/testing/suitetrait)

Conform to this type in traits that you add to test suites.

You can add a trait that conforms to both [`TestTrait`](https://developer.apple.com/documentation/testing/testtrait) and [`SuiteTrait`](https://developer.apple.com/documentation/testing/suitetrait) to test functions and test suites.

## [Topics](https://developer.apple.com/documentation/testing/trait\#topics)

### [Enabling and disabling tests](https://developer.apple.com/documentation/testing/trait\#Enabling-and-disabling-tests)

[`static func enabled(if: @autoclosure () throws -> Bool, Comment?, sourceLocation: SourceLocation) -> Self`](https://developer.apple.com/documentation/testing/trait/enabled(if:_:sourcelocation:))

Constructs a condition trait that disables a test if it returns `false`.

[`static func enabled(Comment?, sourceLocation: SourceLocation, () async throws -> Bool) -> Self`](https://developer.apple.com/documentation/testing/trait/enabled(_:sourcelocation:_:))

Constructs a condition trait that disables a test if it returns `false`.

[`static func disabled(Comment?, sourceLocation: SourceLocation) -> Self`](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:))

Constructs a condition trait that disables a test unconditionally.

[`static func disabled(if: @autoclosure () throws -> Bool, Comment?, sourceLocation: SourceLocation) -> Self`](https://developer.apple.com/documentation/testing/trait/disabled(if:_:sourcelocation:))

Constructs a condition trait that disables a test if its value is true.

[`static func disabled(Comment?, sourceLocation: SourceLocation, () async throws -> Bool) -> Self`](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:_:))

Constructs a condition trait that disables a test if its value is true.

### [Controlling how tests are run](https://developer.apple.com/documentation/testing/trait\#Controlling-how-tests-are-run)

[`static func timeLimit(TimeLimitTrait.Duration) -> Self`](https://developer.apple.com/documentation/testing/trait/timelimit(_:))

Construct a time limit trait that causes a test to time out if it runs for too long.

[`static var serialized: ParallelizationTrait`](https://developer.apple.com/documentation/testing/trait/serialized)

A trait that serializes the test to which it is applied.

### [Categorizing tests and adding information](https://developer.apple.com/documentation/testing/trait\#Categorizing-tests-and-adding-information)

[`static func tags(Tag...) -> Self`](https://developer.apple.com/documentation/testing/trait/tags(_:))

Construct a list of tags to apply to a test.

[`var comments: [Comment]`](https://developer.apple.com/documentation/testing/trait/comments)

The user-provided comments for this trait.

**Required** Default implementation provided.

### [Associating bugs](https://developer.apple.com/documentation/testing/trait\#Associating-bugs)

[`static func bug(String, Comment?) -> Self`](https://developer.apple.com/documentation/testing/trait/bug(_:_:))

Constructs a bug to track with a test.

[`static func bug(String?, id: String, Comment?) -> Self`](https://developer.apple.com/documentation/testing/trait/bug(_:id:_:)-10yf5)

Constructs a bug to track with a test.

[`static func bug(String?, id: some Numeric, Comment?) -> Self`](https://developer.apple.com/documentation/testing/trait/bug(_:id:_:)-3vtpl)

Constructs a bug to track with a test.

### [Running code before and after a test or suite](https://developer.apple.com/documentation/testing/trait\#Running-code-before-and-after-a-test-or-suite)

[`protocol TestScoping`](https://developer.apple.com/documentation/testing/testscoping)

A protocol that tells the test runner to run custom code before or after it runs a test suite or test function.

[`func scopeProvider(for: Test, testCase: Test.Case?) -> Self.TestScopeProvider?`](https://developer.apple.com/documentation/testing/trait/scopeprovider(for:testcase:))

Get this trait’s scope provider for the specified test and optional test case.

**Required** Default implementations provided.

[`associatedtype TestScopeProvider : TestScoping = Never`](https://developer.apple.com/documentation/testing/trait/testscopeprovider)

The type of the test scope provider for this trait.

**Required**

[`func prepare(for: Test) async throws`](https://developer.apple.com/documentation/testing/trait/prepare(for:))

Prepare to run the test that has this trait.

**Required** Default implementation provided.

## [Relationships](https://developer.apple.com/documentation/testing/trait\#relationships)

### [Inherits From](https://developer.apple.com/documentation/testing/trait\#inherits-from)

- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable)

### [Inherited By](https://developer.apple.com/documentation/testing/trait\#inherited-by)

- [`SuiteTrait`](https://developer.apple.com/documentation/testing/suitetrait)
- [`TestTrait`](https://developer.apple.com/documentation/testing/testtrait)

### [Conforming Types](https://developer.apple.com/documentation/testing/trait\#conforming-types)

- [`Bug`](https://developer.apple.com/documentation/testing/bug)
- [`Comment`](https://developer.apple.com/documentation/testing/comment)
- [`ConditionTrait`](https://developer.apple.com/documentation/testing/conditiontrait)
- [`ParallelizationTrait`](https://developer.apple.com/documentation/testing/parallelizationtrait)
- [`Tag.List`](https://developer.apple.com/documentation/testing/tag/list)
- [`TimeLimitTrait`](https://developer.apple.com/documentation/testing/timelimittrait)

## [See Also](https://developer.apple.com/documentation/testing/trait\#see-also)

### [Creating custom traits](https://developer.apple.com/documentation/testing/trait\#Creating-custom-traits)

[`protocol TestTrait`](https://developer.apple.com/documentation/testing/testtrait)

A protocol describing a trait that you can add to a test function.

[`protocol SuiteTrait`](https://developer.apple.com/documentation/testing/suitetrait)

A protocol describing a trait that you can add to a test suite.

[`protocol TestScoping`](https://developer.apple.com/documentation/testing/testscoping)

A protocol that tells the test runner to run custom code before or after it runs a test suite or test function.

Current page is Trait

## Expectation Failed Error
[Skip Navigation](https://developer.apple.com/documentation/testing/expectationfailederror#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- ExpectationFailedError

Structure

# ExpectationFailedError

A type describing an error thrown when an expectation fails during evaluation.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
struct ExpectationFailedError
```

## [Overview](https://developer.apple.com/documentation/testing/expectationfailederror\#overview)

The testing library throws instances of this type when the `#require()` macro records an issue.

## [Topics](https://developer.apple.com/documentation/testing/expectationfailederror\#topics)

### [Instance Properties](https://developer.apple.com/documentation/testing/expectationfailederror\#Instance-Properties)

[`var expectation: Expectation`](https://developer.apple.com/documentation/testing/expectationfailederror/expectation)

The expectation that failed.

## [Relationships](https://developer.apple.com/documentation/testing/expectationfailederror\#relationships)

### [Conforms To](https://developer.apple.com/documentation/testing/expectationfailederror\#conforms-to)

- [`Error`](https://developer.apple.com/documentation/Swift/Error)
- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable)

## [See Also](https://developer.apple.com/documentation/testing/expectationfailederror\#see-also)

### [Retrieving information about checked expectations](https://developer.apple.com/documentation/testing/expectationfailederror\#Retrieving-information-about-checked-expectations)

[`struct Expectation`](https://developer.apple.com/documentation/testing/expectation)

A type describing an expectation that has been evaluated.

[`protocol CustomTestStringConvertible`](https://developer.apple.com/documentation/testing/customteststringconvertible)

A protocol describing types with a custom string representation when presented as part of a test’s output.

Current page is ExpectationFailedError

## Time Limit Trait
[Skip Navigation](https://developer.apple.com/documentation/testing/timelimittrait#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- TimeLimitTrait

Structure

# TimeLimitTrait

A type that defines a time limit to apply to a test.

iOS 16.0+iPadOS 16.0+Mac Catalyst 16.0+macOS 13.0+tvOS 16.0+visionOSwatchOS 9.0+Swift 6.0+Xcode 16.0+

```
struct TimeLimitTrait
```

## [Overview](https://developer.apple.com/documentation/testing/timelimittrait\#overview)

To add this trait to a test, use [`timeLimit(_:)`](https://developer.apple.com/documentation/testing/trait/timelimit(_:)).

## [Topics](https://developer.apple.com/documentation/testing/timelimittrait\#topics)

### [Structures](https://developer.apple.com/documentation/testing/timelimittrait\#Structures)

[`struct Duration`](https://developer.apple.com/documentation/testing/timelimittrait/duration)

A type representing the duration of a time limit applied to a test.

### [Instance Properties](https://developer.apple.com/documentation/testing/timelimittrait\#Instance-Properties)

[`var isRecursive: Bool`](https://developer.apple.com/documentation/testing/timelimittrait/isrecursive)

Whether this instance should be applied recursively to child test suites and test functions.

[`var timeLimit: Duration`](https://developer.apple.com/documentation/testing/timelimittrait/timelimit)

The maximum amount of time a test may run for before timing out.

### [Type Aliases](https://developer.apple.com/documentation/testing/timelimittrait\#Type-Aliases)

[`typealias TestScopeProvider`](https://developer.apple.com/documentation/testing/timelimittrait/testscopeprovider)

The type of the test scope provider for this trait.

### [Default Implementations](https://developer.apple.com/documentation/testing/timelimittrait\#Default-Implementations)

[API Reference\\
Trait Implementations](https://developer.apple.com/documentation/testing/timelimittrait/trait-implementations)

## [Relationships](https://developer.apple.com/documentation/testing/timelimittrait\#relationships)

### [Conforms To](https://developer.apple.com/documentation/testing/timelimittrait\#conforms-to)

- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable)
- [`SuiteTrait`](https://developer.apple.com/documentation/testing/suitetrait)
- [`TestTrait`](https://developer.apple.com/documentation/testing/testtrait)
- [`Trait`](https://developer.apple.com/documentation/testing/trait)

## [See Also](https://developer.apple.com/documentation/testing/timelimittrait\#see-also)

### [Supporting types](https://developer.apple.com/documentation/testing/timelimittrait\#Supporting-types)

[`struct Bug`](https://developer.apple.com/documentation/testing/bug)

A type that represents a bug report tracked by a test.

[`struct Comment`](https://developer.apple.com/documentation/testing/comment)

A type that represents a comment related to a test.

[`struct ConditionTrait`](https://developer.apple.com/documentation/testing/conditiontrait)

A type that defines a condition which must be satisfied for the testing library to enable a test.

[`struct ParallelizationTrait`](https://developer.apple.com/documentation/testing/parallelizationtrait)

A type that defines whether the testing library runs this test serially or in parallel.

[`struct Tag`](https://developer.apple.com/documentation/testing/tag)

A type representing a tag that can be applied to a test.

[`struct List`](https://developer.apple.com/documentation/testing/tag/list)

A type representing one or more tags applied to a test.

Current page is TimeLimitTrait

## Swift Expectation Type
[Skip Navigation](https://developer.apple.com/documentation/testing/expectation#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- Expectation

Structure

# Expectation

A type describing an expectation that has been evaluated.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
struct Expectation
```

## [Topics](https://developer.apple.com/documentation/testing/expectation\#topics)

### [Instance Properties](https://developer.apple.com/documentation/testing/expectation\#Instance-Properties)

[`var isPassing: Bool`](https://developer.apple.com/documentation/testing/expectation/ispassing)

Whether the expectation passed or failed.

[`var isRequired: Bool`](https://developer.apple.com/documentation/testing/expectation/isrequired)

Whether or not the expectation was required to pass.

[`var sourceLocation: SourceLocation`](https://developer.apple.com/documentation/testing/expectation/sourcelocation)

The source location where this expectation was evaluated.

## [Relationships](https://developer.apple.com/documentation/testing/expectation\#relationships)

### [Conforms To](https://developer.apple.com/documentation/testing/expectation\#conforms-to)

- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable)

## [See Also](https://developer.apple.com/documentation/testing/expectation\#see-also)

### [Retrieving information about checked expectations](https://developer.apple.com/documentation/testing/expectation\#Retrieving-information-about-checked-expectations)

[`struct ExpectationFailedError`](https://developer.apple.com/documentation/testing/expectationfailederror)

A type describing an error thrown when an expectation fails during evaluation.

[`protocol CustomTestStringConvertible`](https://developer.apple.com/documentation/testing/customteststringconvertible)

A protocol describing types with a custom string representation when presented as part of a test’s output.

Current page is Expectation

## Parameterized Testing in Swift
[Skip Navigation](https://developer.apple.com/documentation/testing/parameterizedtesting#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- Implementing parameterized tests

Article

# Implementing parameterized tests

Specify different input parameters to generate multiple test cases from a test function.

## [Overview](https://developer.apple.com/documentation/testing/parameterizedtesting\#Overview)

Some tests need to be run over many different inputs. For instance, a test might need to validate all cases of an enumeration. The testing library lets developers specify one or more collections to iterate over during testing, with the elements of those collections being forwarded to a test function. An invocation of a test function with a particular set of argument values is called a test _case_.

By default, the test cases of a test function run in parallel with each other. For more information about test parallelization, see [Running tests serially or in parallel](https://developer.apple.com/documentation/testing/parallelization).

### [Parameterize over an array of values](https://developer.apple.com/documentation/testing/parameterizedtesting\#Parameterize-over-an-array-of-values)

It is very common to want to run a test _n_ times over an array containing the values that should be tested. Consider the following test function:

```
enum Food {
  case burger, iceCream, burrito, noodleBowl, kebab
}

@Test("All foods available")
func foodsAvailable() async throws {
  for food: Food in [.burger, .iceCream, .burrito, .noodleBowl, .kebab] {
    let foodTruck = FoodTruck(selling: food)
    #expect(await foodTruck.cook(food))
  }
}

```

If this test function fails for one of the values in the array, it may be unclear which value failed. Instead, the test function can be _parameterized over_ the various inputs:

```
enum Food {
  case burger, iceCream, burrito, noodleBowl, kebab
}

@Test("All foods available", arguments: [Food.burger, .iceCream, .burrito, .noodleBowl, .kebab])
func foodAvailable(_ food: Food) async throws {
  let foodTruck = FoodTruck(selling: food)
  #expect(await foodTruck.cook(food))
}

```

When passing a collection to the `@Test` attribute for parameterization, the testing library passes each element in the collection, one at a time, to the test function as its first (and only) argument. Then, if the test fails for one or more inputs, the corresponding diagnostics can clearly indicate which inputs to examine.

### [Parameterize over the cases of an enumeration](https://developer.apple.com/documentation/testing/parameterizedtesting\#Parameterize-over-the-cases-of-an-enumeration)

The previous example includes a hard-coded list of `Food` cases to test. If `Food` is an enumeration that conforms to `CaseIterable`, you can instead write:

```
enum Food: CaseIterable {
  case burger, iceCream, burrito, noodleBowl, kebab
}

@Test("All foods available", arguments: Food.allCases)
func foodAvailable(_ food: Food) async throws {
  let foodTruck = FoodTruck(selling: food)
  #expect(await foodTruck.cook(food))
}

```

This way, if a new case is added to the `Food` enumeration, it’s automatically tested by this function.

### [Parameterize over a range of integers](https://developer.apple.com/documentation/testing/parameterizedtesting\#Parameterize-over-a-range-of-integers)

It is possible to parameterize a test function over a closed range of integers:

```
@Test("Can make large orders", arguments: 1 ... 100)
func makeLargeOrder(count: Int) async throws {
  let foodTruck = FoodTruck(selling: .burger)
  #expect(await foodTruck.cook(.burger, quantity: count))
}

```

### [Test with more than one collection](https://developer.apple.com/documentation/testing/parameterizedtesting\#Test-with-more-than-one-collection)

It’s possible to test more than one collection. Consider the following test function:

```
@Test("Can make large orders", arguments: Food.allCases, 1 ... 100)
func makeLargeOrder(of food: Food, count: Int) async throws {
  let foodTruck = FoodTruck(selling: food)
  #expect(await foodTruck.cook(food, quantity: count))
}

```

Elements from the first collection are passed as the first argument to the test function, elements from the second collection are passed as the second argument, and so forth.

Assuming there are five cases in the `Food` enumeration, this test function will, when run, be invoked 500 times (5 x 100) with every possible combination of food and order size. These combinations are referred to as the collections’ Cartesian product.

To avoid the combinatoric semantics shown above, use [`zip()`](https://developer.apple.com/documentation/swift/zip(_:_:)):

```
@Test("Can make large orders", arguments: zip(Food.allCases, 1 ... 100))
func makeLargeOrder(of food: Food, count: Int) async throws {
  let foodTruck = FoodTruck(selling: food)
  #expect(await foodTruck.cook(food, quantity: count))
}

```

The zipped sequence will be “destructured” into two arguments automatically, then passed to the test function for evaluation.

This revised test function is invoked once for each tuple in the zipped sequence, for a total of five invocations instead of 500 invocations. In other words, this test function is passed the inputs `(.burger, 1)`, `(.iceCream, 2)`, …, `(.kebab, 5)` instead of `(.burger, 1)`, `(.burger, 2)`, `(.burger, 3)`, …, `(.kebab, 99)`, `(.kebab, 100)`.

### [Run selected test cases](https://developer.apple.com/documentation/testing/parameterizedtesting\#Run-selected-test-cases)

If a parameterized test meets certain requirements, the testing library allows people to run specific test cases it contains. This can be useful when a test has many cases but only some are failing since it enables re-running and debugging the failing cases in isolation.

To support running selected test cases, it must be possible to deterministically match the test case’s arguments. When someone attempts to run selected test cases of a parameterized test function, the testing library evaluates each argument of the tests’ cases for conformance to one of several known protocols, and if all arguments of a test case conform to one of those protocols, that test case can be run selectively. The following lists the known protocols, in precedence order (highest to lowest):

1. [`CustomTestArgumentEncodable`](https://developer.apple.com/documentation/testing/customtestargumentencodable)

2. `RawRepresentable`, where `RawValue` conforms to `Encodable`

3. `Encodable`

4. `Identifiable`, where `ID` conforms to `Encodable`


If any argument of a test case doesn’t meet one of the above requirements, then the overall test case cannot be run selectively.

## [See Also](https://developer.apple.com/documentation/testing/parameterizedtesting\#see-also)

### [Test parameterization](https://developer.apple.com/documentation/testing/parameterizedtesting\#Test-parameterization)

[`macro Test<C>(String?, any TestTrait..., arguments: C)`](https://developer.apple.com/documentation/testing/test(_:_:arguments:)-8kn7a)

Declare a test parameterized over a collection of values.

[`macro Test<C1, C2>(String?, any TestTrait..., arguments: C1, C2)`](https://developer.apple.com/documentation/testing/test(_:_:arguments:_:))

Declare a test parameterized over two collections of values.

[`macro Test<C1, C2>(String?, any TestTrait..., arguments: Zip2Sequence<C1, C2>)`](https://developer.apple.com/documentation/testing/test(_:_:arguments:)-3rzok)

Declare a test parameterized over two zipped collections of values.

[`protocol CustomTestArgumentEncodable`](https://developer.apple.com/documentation/testing/customtestargumentencodable)

A protocol for customizing how arguments passed to parameterized tests are encoded, which is used to match against when running specific arguments.

[`struct Case`](https://developer.apple.com/documentation/testing/test/case)

A single test case from a parameterized [`Test`](https://developer.apple.com/documentation/testing/test).

Current page is Implementing parameterized tests

## Condition Trait
[Skip Navigation](https://developer.apple.com/documentation/testing/conditiontrait#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- ConditionTrait

Structure

# ConditionTrait

A type that defines a condition which must be satisfied for the testing library to enable a test.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
struct ConditionTrait
```

## [Mentioned in](https://developer.apple.com/documentation/testing/conditiontrait\#mentions)

[Migrating a test from XCTest](https://developer.apple.com/documentation/testing/migratingfromxctest)

## [Overview](https://developer.apple.com/documentation/testing/conditiontrait\#overview)

To add this trait to a test, use one of the following functions:

- [`enabled(if:_:sourceLocation:)`](https://developer.apple.com/documentation/testing/trait/enabled(if:_:sourcelocation:))

- [`enabled(_:sourceLocation:_:)`](https://developer.apple.com/documentation/testing/trait/enabled(_:sourcelocation:_:))

- [`disabled(_:sourceLocation:)`](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:))

- [`disabled(if:_:sourceLocation:)`](https://developer.apple.com/documentation/testing/trait/disabled(if:_:sourcelocation:))

- [`disabled(_:sourceLocation:_:)`](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:_:))


## [Topics](https://developer.apple.com/documentation/testing/conditiontrait\#topics)

### [Instance Properties](https://developer.apple.com/documentation/testing/conditiontrait\#Instance-Properties)

[`var comments: [Comment]`](https://developer.apple.com/documentation/testing/conditiontrait/comments)

The user-provided comments for this trait.

[`var isRecursive: Bool`](https://developer.apple.com/documentation/testing/conditiontrait/isrecursive)

Whether this instance should be applied recursively to child test suites and test functions.

[`var sourceLocation: SourceLocation`](https://developer.apple.com/documentation/testing/conditiontrait/sourcelocation)

The source location where this trait is specified.

### [Instance Methods](https://developer.apple.com/documentation/testing/conditiontrait\#Instance-Methods)

[`func prepare(for: Test) async throws`](https://developer.apple.com/documentation/testing/conditiontrait/prepare(for:))

Prepare to run the test that has this trait.

### [Type Aliases](https://developer.apple.com/documentation/testing/conditiontrait\#Type-Aliases)

[`typealias TestScopeProvider`](https://developer.apple.com/documentation/testing/conditiontrait/testscopeprovider)

The type of the test scope provider for this trait.

### [Default Implementations](https://developer.apple.com/documentation/testing/conditiontrait\#Default-Implementations)

[API Reference\\
Trait Implementations](https://developer.apple.com/documentation/testing/conditiontrait/trait-implementations)

## [Relationships](https://developer.apple.com/documentation/testing/conditiontrait\#relationships)

### [Conforms To](https://developer.apple.com/documentation/testing/conditiontrait\#conforms-to)

- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable)
- [`SuiteTrait`](https://developer.apple.com/documentation/testing/suitetrait)
- [`TestTrait`](https://developer.apple.com/documentation/testing/testtrait)
- [`Trait`](https://developer.apple.com/documentation/testing/trait)

## [See Also](https://developer.apple.com/documentation/testing/conditiontrait\#see-also)

### [Supporting types](https://developer.apple.com/documentation/testing/conditiontrait\#Supporting-types)

[`struct Bug`](https://developer.apple.com/documentation/testing/bug)

A type that represents a bug report tracked by a test.

[`struct Comment`](https://developer.apple.com/documentation/testing/comment)

A type that represents a comment related to a test.

[`struct ParallelizationTrait`](https://developer.apple.com/documentation/testing/parallelizationtrait)

A type that defines whether the testing library runs this test serially or in parallel.

[`struct Tag`](https://developer.apple.com/documentation/testing/tag)

A type representing a tag that can be applied to a test.

[`struct List`](https://developer.apple.com/documentation/testing/tag/list)

A type representing one or more tags applied to a test.

[`struct TimeLimitTrait`](https://developer.apple.com/documentation/testing/timelimittrait)

A type that defines a time limit to apply to a test.

Current page is ConditionTrait

## SourceLocation in Swift
[Skip Navigation](https://developer.apple.com/documentation/testing/sourcelocation#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- SourceLocation

Structure

# SourceLocation

A type representing a location in source code.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
struct SourceLocation
```

## [Topics](https://developer.apple.com/documentation/testing/sourcelocation\#topics)

### [Initializers](https://developer.apple.com/documentation/testing/sourcelocation\#Initializers)

[`init(fileID: String, filePath: String, line: Int, column: Int)`](https://developer.apple.com/documentation/testing/sourcelocation/init(fileid:filepath:line:column:))

Initialize an instance of this type with the specified location details.

### [Instance Properties](https://developer.apple.com/documentation/testing/sourcelocation\#Instance-Properties)

[`var column: Int`](https://developer.apple.com/documentation/testing/sourcelocation/column)

The column in the source file.

[`var fileID: String`](https://developer.apple.com/documentation/testing/sourcelocation/fileid)

The file ID of the source file.

[`var fileName: String`](https://developer.apple.com/documentation/testing/sourcelocation/filename)

The name of the source file.

[`var line: Int`](https://developer.apple.com/documentation/testing/sourcelocation/line)

The line in the source file.

[`var moduleName: String`](https://developer.apple.com/documentation/testing/sourcelocation/modulename)

The name of the module containing the source file.

### [Default Implementations](https://developer.apple.com/documentation/testing/sourcelocation\#Default-Implementations)

[API Reference\\
Comparable Implementations](https://developer.apple.com/documentation/testing/sourcelocation/comparable-implementations)

[API Reference\\
CustomDebugStringConvertible Implementations](https://developer.apple.com/documentation/testing/sourcelocation/customdebugstringconvertible-implementations)

[API Reference\\
CustomStringConvertible Implementations](https://developer.apple.com/documentation/testing/sourcelocation/customstringconvertible-implementations)

[API Reference\\
Decodable Implementations](https://developer.apple.com/documentation/testing/sourcelocation/decodable-implementations)

[API Reference\\
Encodable Implementations](https://developer.apple.com/documentation/testing/sourcelocation/encodable-implementations)

[API Reference\\
Equatable Implementations](https://developer.apple.com/documentation/testing/sourcelocation/equatable-implementations)

[API Reference\\
Hashable Implementations](https://developer.apple.com/documentation/testing/sourcelocation/hashable-implementations)

## [Relationships](https://developer.apple.com/documentation/testing/sourcelocation\#relationships)

### [Conforms To](https://developer.apple.com/documentation/testing/sourcelocation\#conforms-to)

- [`Comparable`](https://developer.apple.com/documentation/Swift/Comparable)
- [`Copyable`](https://developer.apple.com/documentation/Swift/Copyable)
- [`CustomDebugStringConvertible`](https://developer.apple.com/documentation/Swift/CustomDebugStringConvertible)
- [`CustomStringConvertible`](https://developer.apple.com/documentation/Swift/CustomStringConvertible)
- [`Decodable`](https://developer.apple.com/documentation/Swift/Decodable)
- [`Encodable`](https://developer.apple.com/documentation/Swift/Encodable)
- [`Equatable`](https://developer.apple.com/documentation/Swift/Equatable)
- [`Hashable`](https://developer.apple.com/documentation/Swift/Hashable)
- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable)

Current page is SourceLocation

## Bug Reporting Structure
[Skip Navigation](https://developer.apple.com/documentation/testing/bug#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- Bug

Structure

# Bug

A type that represents a bug report tracked by a test.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
struct Bug
```

## [Mentioned in](https://developer.apple.com/documentation/testing/bug\#mentions)

[Interpreting bug identifiers](https://developer.apple.com/documentation/testing/bugidentifiers)

[Adding comments to tests](https://developer.apple.com/documentation/testing/addingcomments)

## [Overview](https://developer.apple.com/documentation/testing/bug\#overview)

To add this trait to a test, use one of the following functions:

- [`bug(_:_:)`](https://developer.apple.com/documentation/testing/trait/bug(_:_:))

- [`bug(_:id:_:)`](https://developer.apple.com/documentation/testing/trait/bug(_:id:_:)-10yf5)

- [`bug(_:id:_:)`](https://developer.apple.com/documentation/testing/trait/bug(_:id:_:)-3vtpl)


## [Topics](https://developer.apple.com/documentation/testing/bug\#topics)

### [Instance Properties](https://developer.apple.com/documentation/testing/bug\#Instance-Properties)

[`var id: String?`](https://developer.apple.com/documentation/testing/bug/id)

A unique identifier in this bug’s associated bug-tracking system, if available.

[`var title: Comment?`](https://developer.apple.com/documentation/testing/bug/title)

The human-readable title of the bug, if specified by the test author.

[`var url: String?`](https://developer.apple.com/documentation/testing/bug/url)

A URL that links to more information about the bug, if available.

### [Default Implementations](https://developer.apple.com/documentation/testing/bug\#Default-Implementations)

[API Reference\\
Decodable Implementations](https://developer.apple.com/documentation/testing/bug/decodable-implementations)

[API Reference\\
Encodable Implementations](https://developer.apple.com/documentation/testing/bug/encodable-implementations)

[API Reference\\
Equatable Implementations](https://developer.apple.com/documentation/testing/bug/equatable-implementations)

[API Reference\\
Hashable Implementations](https://developer.apple.com/documentation/testing/bug/hashable-implementations)

[API Reference\\
SuiteTrait Implementations](https://developer.apple.com/documentation/testing/bug/suitetrait-implementations)

[API Reference\\
Trait Implementations](https://developer.apple.com/documentation/testing/bug/trait-implementations)

## [Relationships](https://developer.apple.com/documentation/testing/bug\#relationships)

### [Conforms To](https://developer.apple.com/documentation/testing/bug\#conforms-to)

- [`Copyable`](https://developer.apple.com/documentation/Swift/Copyable)
- [`Decodable`](https://developer.apple.com/documentation/Swift/Decodable)
- [`Encodable`](https://developer.apple.com/documentation/Swift/Encodable)
- [`Equatable`](https://developer.apple.com/documentation/Swift/Equatable)
- [`Hashable`](https://developer.apple.com/documentation/Swift/Hashable)
- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable)
- [`SuiteTrait`](https://developer.apple.com/documentation/testing/suitetrait)
- [`TestTrait`](https://developer.apple.com/documentation/testing/testtrait)
- [`Trait`](https://developer.apple.com/documentation/testing/trait)

## [See Also](https://developer.apple.com/documentation/testing/bug\#see-also)

### [Supporting types](https://developer.apple.com/documentation/testing/bug\#Supporting-types)

[`struct Comment`](https://developer.apple.com/documentation/testing/comment)

A type that represents a comment related to a test.

[`struct ConditionTrait`](https://developer.apple.com/documentation/testing/conditiontrait)

A type that defines a condition which must be satisfied for the testing library to enable a test.

[`struct ParallelizationTrait`](https://developer.apple.com/documentation/testing/parallelizationtrait)

A type that defines whether the testing library runs this test serially or in parallel.

[`struct Tag`](https://developer.apple.com/documentation/testing/tag)

A type representing a tag that can be applied to a test.

[`struct List`](https://developer.apple.com/documentation/testing/tag/list)

A type representing one or more tags applied to a test.

[`struct TimeLimitTrait`](https://developer.apple.com/documentation/testing/timelimittrait)

A type that defines a time limit to apply to a test.

Current page is Bug

## Swift Test Traits
[Skip Navigation](https://developer.apple.com/documentation/testing/traits#app-main)

Collection

- [Swift Testing](https://developer.apple.com/documentation/testing)
- Traits

API Collection

# Traits

Annotate test functions and suites, and customize their behavior.

## [Overview](https://developer.apple.com/documentation/testing/traits\#Overview)

Pass built-in traits to test functions or suite types to comment, categorize, classify, and modify the runtime behavior of test suites and test functions. Implement the [`TestTrait`](https://developer.apple.com/documentation/testing/testtrait), and [`SuiteTrait`](https://developer.apple.com/documentation/testing/suitetrait) protocols to create your own types that customize the behavior of your tests.

## [Topics](https://developer.apple.com/documentation/testing/traits\#topics)

### [Customizing runtime behaviors](https://developer.apple.com/documentation/testing/traits\#Customizing-runtime-behaviors)

[Enabling and disabling tests](https://developer.apple.com/documentation/testing/enablinganddisabling)

Conditionally enable or disable individual tests before they run.

[Limiting the running time of tests](https://developer.apple.com/documentation/testing/limitingexecutiontime)

Set limits on how long a test can run for until it fails.

[`static func enabled(if: @autoclosure () throws -> Bool, Comment?, sourceLocation: SourceLocation) -> Self`](https://developer.apple.com/documentation/testing/trait/enabled(if:_:sourcelocation:))

Constructs a condition trait that disables a test if it returns `false`.

[`static func enabled(Comment?, sourceLocation: SourceLocation, () async throws -> Bool) -> Self`](https://developer.apple.com/documentation/testing/trait/enabled(_:sourcelocation:_:))

Constructs a condition trait that disables a test if it returns `false`.

[`static func disabled(Comment?, sourceLocation: SourceLocation) -> Self`](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:))

Constructs a condition trait that disables a test unconditionally.

[`static func disabled(if: @autoclosure () throws -> Bool, Comment?, sourceLocation: SourceLocation) -> Self`](https://developer.apple.com/documentation/testing/trait/disabled(if:_:sourcelocation:))

Constructs a condition trait that disables a test if its value is true.

[`static func disabled(Comment?, sourceLocation: SourceLocation, () async throws -> Bool) -> Self`](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:_:))

Constructs a condition trait that disables a test if its value is true.

[`static func timeLimit(TimeLimitTrait.Duration) -> Self`](https://developer.apple.com/documentation/testing/trait/timelimit(_:))

Construct a time limit trait that causes a test to time out if it runs for too long.

### [Running tests serially or in parallel](https://developer.apple.com/documentation/testing/traits\#Running-tests-serially-or-in-parallel)

[Running tests serially or in parallel](https://developer.apple.com/documentation/testing/parallelization)

Control whether tests run serially or in parallel.

[`static var serialized: ParallelizationTrait`](https://developer.apple.com/documentation/testing/trait/serialized)

A trait that serializes the test to which it is applied.

### [Annotating tests](https://developer.apple.com/documentation/testing/traits\#Annotating-tests)

[Adding tags to tests](https://developer.apple.com/documentation/testing/addingtags)

Use tags to provide semantic information for organization, filtering, and customizing appearances.

[Adding comments to tests](https://developer.apple.com/documentation/testing/addingcomments)

Add comments to provide useful information about tests.

[Associating bugs with tests](https://developer.apple.com/documentation/testing/associatingbugs)

Associate bugs uncovered or verified by tests.

[Interpreting bug identifiers](https://developer.apple.com/documentation/testing/bugidentifiers)

Examine how the testing library interprets bug identifiers provided by developers.

[`macro Tag()`](https://developer.apple.com/documentation/testing/tag())

Declare a tag that can be applied to a test function or test suite.

[`static func bug(String, Comment?) -> Self`](https://developer.apple.com/documentation/testing/trait/bug(_:_:))

Constructs a bug to track with a test.

[`static func bug(String?, id: String, Comment?) -> Self`](https://developer.apple.com/documentation/testing/trait/bug(_:id:_:)-10yf5)

Constructs a bug to track with a test.

[`static func bug(String?, id: some Numeric, Comment?) -> Self`](https://developer.apple.com/documentation/testing/trait/bug(_:id:_:)-3vtpl)

Constructs a bug to track with a test.

### [Creating custom traits](https://developer.apple.com/documentation/testing/traits\#Creating-custom-traits)

[`protocol Trait`](https://developer.apple.com/documentation/testing/trait)

A protocol describing traits that can be added to a test function or to a test suite.

[`protocol TestTrait`](https://developer.apple.com/documentation/testing/testtrait)

A protocol describing a trait that you can add to a test function.

[`protocol SuiteTrait`](https://developer.apple.com/documentation/testing/suitetrait)

A protocol describing a trait that you can add to a test suite.

[`protocol TestScoping`](https://developer.apple.com/documentation/testing/testscoping)

A protocol that tells the test runner to run custom code before or after it runs a test suite or test function.

### [Supporting types](https://developer.apple.com/documentation/testing/traits\#Supporting-types)

[`struct Bug`](https://developer.apple.com/documentation/testing/bug)

A type that represents a bug report tracked by a test.

[`struct Comment`](https://developer.apple.com/documentation/testing/comment)

A type that represents a comment related to a test.

[`struct ConditionTrait`](https://developer.apple.com/documentation/testing/conditiontrait)

A type that defines a condition which must be satisfied for the testing library to enable a test.

[`struct ParallelizationTrait`](https://developer.apple.com/documentation/testing/parallelizationtrait)

A type that defines whether the testing library runs this test serially or in parallel.

[`struct Tag`](https://developer.apple.com/documentation/testing/tag)

A type representing a tag that can be applied to a test.

[`struct List`](https://developer.apple.com/documentation/testing/tag/list)

A type representing one or more tags applied to a test.

[`struct TimeLimitTrait`](https://developer.apple.com/documentation/testing/timelimittrait)

A type that defines a time limit to apply to a test.

Current page is Traits

## Custom Test String
[Skip Navigation](https://developer.apple.com/documentation/testing/customteststringconvertible#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- CustomTestStringConvertible

Protocol

# CustomTestStringConvertible

A protocol describing types with a custom string representation when presented as part of a test’s output.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
protocol CustomTestStringConvertible
```

## [Overview](https://developer.apple.com/documentation/testing/customteststringconvertible\#overview)

Values whose types conform to this protocol use it to describe themselves when they are present as part of the output of a test. For example, this protocol affects the display of values that are passed as arguments to test functions or that are elements of an expectation failure.

By default, the testing library converts values to strings using `String(describing:)`. The resulting string may be inappropriate for some types and their values. If the type of the value is made to conform to [`CustomTestStringConvertible`](https://developer.apple.com/documentation/testing/customteststringconvertible), then the value of its [`testDescription`](https://developer.apple.com/documentation/testing/customteststringconvertible/testdescription) property will be used instead.

For example, consider the following type:

```
enum Food: CaseIterable {
  case paella, oden, ragu
}

```

If an array of cases from this enumeration is passed to a parameterized test function:

```
@Test(arguments: Food.allCases)
func isDelicious(_ food: Food) { ... }

```

Then the values in the array need to be presented in the test output, but the default description of a value may not be adequately descriptive:

```
◇ Passing argument food → .paella to isDelicious(_:)
◇ Passing argument food → .oden to isDelicious(_:)
◇ Passing argument food → .ragu to isDelicious(_:)

```

By adopting [`CustomTestStringConvertible`](https://developer.apple.com/documentation/testing/customteststringconvertible), customized descriptions can be included:

```
extension Food: CustomTestStringConvertible {
  var testDescription: String {
    switch self {
    case .paella:
      "paella valenciana"
    case .oden:
      "おでん"
    case .ragu:
      "ragù alla bolognese"
    }
  }
}

```

The presentation of these values will then reflect the value of the [`testDescription`](https://developer.apple.com/documentation/testing/customteststringconvertible/testdescription) property:

```
◇ Passing argument food → paella valenciana to isDelicious(_:)
◇ Passing argument food → おでん to isDelicious(_:)
◇ Passing argument food → ragù alla bolognese to isDelicious(_:)

```

## [Topics](https://developer.apple.com/documentation/testing/customteststringconvertible\#topics)

### [Instance Properties](https://developer.apple.com/documentation/testing/customteststringconvertible\#Instance-Properties)

[`var testDescription: String`](https://developer.apple.com/documentation/testing/customteststringconvertible/testdescription)

A description of this instance to use when presenting it in a test’s output.

**Required** Default implementation provided.

## [See Also](https://developer.apple.com/documentation/testing/customteststringconvertible\#see-also)

### [Retrieving information about checked expectations](https://developer.apple.com/documentation/testing/customteststringconvertible\#Retrieving-information-about-checked-expectations)

[`struct Expectation`](https://developer.apple.com/documentation/testing/expectation)

A type describing an expectation that has been evaluated.

[`struct ExpectationFailedError`](https://developer.apple.com/documentation/testing/expectationfailederror)

A type describing an error thrown when an expectation fails during evaluation.

Current page is CustomTestStringConvertible

## Swift Testing Issues
[Skip Navigation](https://developer.apple.com/documentation/testing/issue#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- Issue

Structure

# Issue

A type describing a failure or warning which occurred during a test.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
struct Issue
```

## [Mentioned in](https://developer.apple.com/documentation/testing/issue\#mentions)

[Associating bugs with tests](https://developer.apple.com/documentation/testing/associatingbugs)

[Interpreting bug identifiers](https://developer.apple.com/documentation/testing/bugidentifiers)

## [Topics](https://developer.apple.com/documentation/testing/issue\#topics)

### [Instance Properties](https://developer.apple.com/documentation/testing/issue\#Instance-Properties)

[`var comments: [Comment]`](https://developer.apple.com/documentation/testing/issue/comments)

Any comments provided by the developer and associated with this issue.

[`var error: (any Error)?`](https://developer.apple.com/documentation/testing/issue/error)

The error which was associated with this issue, if any.

[`var kind: Issue.Kind`](https://developer.apple.com/documentation/testing/issue/kind-swift.property)

The kind of issue this value represents.

[`var sourceLocation: SourceLocation?`](https://developer.apple.com/documentation/testing/issue/sourcelocation)

The location in source where this issue occurred, if available.

### [Type Methods](https://developer.apple.com/documentation/testing/issue\#Type-Methods)

[`static func record(any Error, Comment?, sourceLocation: SourceLocation) -> Issue`](https://developer.apple.com/documentation/testing/issue/record(_:_:sourcelocation:))

Record a new issue when a running test unexpectedly catches an error.

[`static func record(Comment?, sourceLocation: SourceLocation) -> Issue`](https://developer.apple.com/documentation/testing/issue/record(_:sourcelocation:))

Record an issue when a running test fails unexpectedly.

### [Enumerations](https://developer.apple.com/documentation/testing/issue\#Enumerations)

[`enum Kind`](https://developer.apple.com/documentation/testing/issue/kind-swift.enum)

Kinds of issues which may be recorded.

### [Default Implementations](https://developer.apple.com/documentation/testing/issue\#Default-Implementations)

[API Reference\\
CustomDebugStringConvertible Implementations](https://developer.apple.com/documentation/testing/issue/customdebugstringconvertible-implementations)

[API Reference\\
CustomStringConvertible Implementations](https://developer.apple.com/documentation/testing/issue/customstringconvertible-implementations)

## [Relationships](https://developer.apple.com/documentation/testing/issue\#relationships)

### [Conforms To](https://developer.apple.com/documentation/testing/issue\#conforms-to)

- [`Copyable`](https://developer.apple.com/documentation/Swift/Copyable)
- [`CustomDebugStringConvertible`](https://developer.apple.com/documentation/Swift/CustomDebugStringConvertible)
- [`CustomStringConvertible`](https://developer.apple.com/documentation/Swift/CustomStringConvertible)
- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable)

Current page is Issue

## Migrating from XCTest
[Skip Navigation](https://developer.apple.com/documentation/testing/migratingfromxctest#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- Migrating a test from XCTest

Article

# Migrating a test from XCTest

Migrate an existing test method or test class written using XCTest.

## [Overview](https://developer.apple.com/documentation/testing/migratingfromxctest\#Overview)

The testing library provides much of the same functionality of XCTest, but uses its own syntax to declare test functions and types. Here, you’ll learn how to convert XCTest-based content to use the testing library instead.

### [Import the testing library](https://developer.apple.com/documentation/testing/migratingfromxctest\#Import-the-testing-library)

XCTest and the testing library are available from different modules. Instead of importing the XCTest module, import the Testing module:

```
// Before
import XCTest

```

```
// After
import Testing

```

A single source file can contain tests written with XCTest as well as other tests written with the testing library. Import both XCTest and Testing if a source file contains mixed test content.

### [Convert test classes](https://developer.apple.com/documentation/testing/migratingfromxctest\#Convert-test-classes)

XCTest groups related sets of test methods in test classes: classes that inherit from the [`XCTestCase`](https://developer.apple.com/documentation/xctest/xctestcase) class provided by the [XCTest](https://developer.apple.com/documentation/xctest) framework. The testing library doesn’t require that test functions be instance members of types. Instead, they can be _free_ or _global_ functions, or can be `static` or `class` members of a type.

If you want to group your test functions together, you can do so by placing them in a Swift type. The testing library refers to such a type as a _suite_. These types do _not_ need to be classes, and they don’t inherit from `XCTestCase`.

To convert a subclass of `XCTestCase` to a suite, remove the `XCTestCase` conformance. It’s also generally recommended that a Swift structure or actor be used instead of a class because it allows the Swift compiler to better-enforce concurrency safety:

```
// Before
class FoodTruckTests: XCTestCase {
  ...
}

```

```
// After
struct FoodTruckTests {
  ...
}

```

For more information about suites and how to declare and customize them, see [Organizing test functions with suite types](https://developer.apple.com/documentation/testing/organizingtests).

### [Convert setup and teardown functions](https://developer.apple.com/documentation/testing/migratingfromxctest\#Convert-setup-and-teardown-functions)

In XCTest, code can be scheduled to run before and after a test using the [`setUp()`](https://developer.apple.com/documentation/xctest/xctest/3856481-setup) and [`tearDown()`](https://developer.apple.com/documentation/xctest/xctest/3856482-teardown) family of functions. When writing tests using the testing library, implement `init()` and/or `deinit` instead:

```
// Before
class FoodTruckTests: XCTestCase {
  var batteryLevel: NSNumber!
  override func setUp() async throws {
    batteryLevel = 100
  }
  ...
}

```

```
// After
struct FoodTruckTests {
  var batteryLevel: NSNumber
  init() async throws {
    batteryLevel = 100
  }
  ...
}

```

The use of `async` and `throws` is optional. If teardown is needed, declare your test suite as a class or as an actor rather than as a structure and implement `deinit`:

```
// Before
class FoodTruckTests: XCTestCase {
  var batteryLevel: NSNumber!
  override func setUp() async throws {
    batteryLevel = 100
  }
  override func tearDown() {
    batteryLevel = 0 // drain the battery
  }
  ...
}

```

```
// After
final class FoodTruckTests {
  var batteryLevel: NSNumber
  init() async throws {
    batteryLevel = 100
  }
  deinit {
    batteryLevel = 0 // drain the battery
  }
  ...
}

```

### [Convert test methods](https://developer.apple.com/documentation/testing/migratingfromxctest\#Convert-test-methods)

The testing library represents individual tests as functions, similar to how they are represented in XCTest. However, the syntax for declaring a test function is different. In XCTest, a test method must be a member of a test class and its name must start with `test`. The testing library doesn’t require a test function to have any particular name. Instead, it identifies a test function by the presence of the `@Test` attribute:

```
// Before
class FoodTruckTests: XCTestCase {
  func testEngineWorks() { ... }
  ...
}

```

```
// After
struct FoodTruckTests {
  @Test func engineWorks() { ... }
  ...
}

```

As with XCTest, the testing library allows test functions to be marked `async`, `throws`, or `async`- `throws`, and to be isolated to a global actor (for example, by using the `@MainActor` attribute.)

For more information about test functions and how to declare and customize them, see [Defining test functions](https://developer.apple.com/documentation/testing/definingtests).

### [Check for expected values and outcomes](https://developer.apple.com/documentation/testing/migratingfromxctest\#Check-for-expected-values-and-outcomes)

XCTest uses a family of approximately 40 functions to assert test requirements. These functions are collectively referred to as [`XCTAssert()`](https://developer.apple.com/documentation/xctest/1500669-xctassert). The testing library has two replacements, [`expect(_:_:sourceLocation:)`](https://developer.apple.com/documentation/testing/expect(_:_:sourcelocation:)) and [`require(_:_:sourceLocation:)`](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-5l63q). They both behave similarly to `XCTAssert()` except that [`require(_:_:sourceLocation:)`](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-5l63q) throws an error if its condition isn’t met:

```
// Before
func testEngineWorks() throws {
  let engine = FoodTruck.shared.engine
  XCTAssertNotNil(engine.parts.first)
  XCTAssertGreaterThan(engine.batteryLevel, 0)
  try engine.start()
  XCTAssertTrue(engine.isRunning)
}

```

```
// After
@Test func engineWorks() throws {
  let engine = FoodTruck.shared.engine
  try #require(engine.parts.first != nil)
  #expect(engine.batteryLevel > 0)
  try engine.start()
  #expect(engine.isRunning)
}

```

### [Check for optional values](https://developer.apple.com/documentation/testing/migratingfromxctest\#Check-for-optional-values)

XCTest also has a function, [`XCTUnwrap()`](https://developer.apple.com/documentation/xctest/3380195-xctunwrap), that tests if an optional value is `nil` and throws an error if it is. When using the testing library, you can use [`require(_:_:sourceLocation:)`](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-6w9oo) with optional expressions to unwrap them:

```
// Before
func testEngineWorks() throws {
  let engine = FoodTruck.shared.engine
  let part = try XCTUnwrap(engine.parts.first)
  ...
}

```

```
// After
@Test func engineWorks() throws {
  let engine = FoodTruck.shared.engine
  let part = try #require(engine.parts.first)
  ...
}

```

### [Record issues](https://developer.apple.com/documentation/testing/migratingfromxctest\#Record-issues)

XCTest has a function, [`XCTFail()`](https://developer.apple.com/documentation/xctest/1500970-xctfail), that causes a test to fail immediately and unconditionally. This function is useful when the syntax of the language prevents the use of an `XCTAssert()` function. To record an unconditional issue using the testing library, use the [`record(_:sourceLocation:)`](https://developer.apple.com/documentation/testing/issue/record(_:sourcelocation:)) function:

```
// Before
func testEngineWorks() {
  let engine = FoodTruck.shared.engine
  guard case .electric = engine else {
    XCTFail("Engine is not electric")
    return
  }
  ...
}

```

```
// After
@Test func engineWorks() {
  let engine = FoodTruck.shared.engine
  guard case .electric = engine else {
    Issue.record("Engine is not electric")
    return
  }
  ...
}

```

The following table includes a list of the various `XCTAssert()` functions and their equivalents in the testing library:

| XCTest | Swift Testing |
| --- | --- |
| `XCTAssert(x)`, `XCTAssertTrue(x)` | `#expect(x)` |
| `XCTAssertFalse(x)` | `#expect(!x)` |
| `XCTAssertNil(x)` | `#expect(x == nil)` |
| `XCTAssertNotNil(x)` | `#expect(x != nil)` |
| `XCTAssertEqual(x, y)` | `#expect(x == y)` |
| `XCTAssertNotEqual(x, y)` | `#expect(x != y)` |
| `XCTAssertIdentical(x, y)` | `#expect(x === y)` |
| `XCTAssertNotIdentical(x, y)` | `#expect(x !== y)` |
| `XCTAssertGreaterThan(x, y)` | `#expect(x > y)` |
| `XCTAssertGreaterThanOrEqual(x, y)` | `#expect(x >= y)` |
| `XCTAssertLessThanOrEqual(x, y)` | `#expect(x <= y)` |
| `XCTAssertLessThan(x, y)` | `#expect(x < y)` |
| `XCTAssertThrowsError(try f())` | `#expect(throws: (any Error).self) { try f() }` |
| `XCTAssertThrowsError(try f()) { error in … }` | `let error = #expect(throws: (any Error).self) { try f() }` |
| `XCTAssertNoThrow(try f())` | `#expect(throws: Never.self) { try f() }` |
| `try XCTUnwrap(x)` | `try #require(x)` |
| `XCTFail("…")` | `Issue.record("…")` |

The testing library doesn’t provide an equivalent of [`XCTAssertEqual(_:_:accuracy:_:file:line:)`](https://developer.apple.com/documentation/xctest/3551607-xctassertequal). To compare two numeric values within a specified accuracy, use `isApproximatelyEqual()` from [swift-numerics](https://github.com/apple/swift-numerics).

### [Continue or halt after test failures](https://developer.apple.com/documentation/testing/migratingfromxctest\#Continue-or-halt-after-test-failures)

An instance of an `XCTestCase` subclass can set its [`continueAfterFailure`](https://developer.apple.com/documentation/xctest/xctestcase/1496260-continueafterfailure) property to `false` to cause a test to stop running after a failure occurs. XCTest stops an affected test by throwing an Objective-C exception at the time the failure occurs.

The behavior of an exception thrown through a Swift stack frame is undefined. If an exception is thrown through an `async` Swift function, it typically causes the process to terminate abnormally, preventing other tests from running.

The testing library doesn’t use exceptions to stop test functions. Instead, use the [`require(_:_:sourceLocation:)`](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-5l63q) macro, which throws a Swift error on failure:

```
// Before
func testTruck() async {
  continueAfterFailure = false
  XCTAssertTrue(FoodTruck.shared.isLicensed)
  ...
}

```

```
// After
@Test func truck() throws {
  try #require(FoodTruck.shared.isLicensed)
  ...
}

```

When using either `continueAfterFailure` or [`require(_:_:sourceLocation:)`](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-5l63q), other tests will continue to run after the failed test method or test function.

### [Validate asynchronous behaviors](https://developer.apple.com/documentation/testing/migratingfromxctest\#Validate-asynchronous-behaviors)

XCTest has a class, [`XCTestExpectation`](https://developer.apple.com/documentation/xctest/xctestexpectation), that represents some asynchronous condition. You create an instance of this class (or a subclass like [`XCTKeyPathExpectation`](https://developer.apple.com/documentation/xctest/xctkeypathexpectation)) using an initializer or a convenience method on `XCTestCase`. When the condition represented by an expectation occurs, the developer _fulfills_ the expectation. Concurrently, the developer _waits for_ the expectation to be fulfilled using an instance of [`XCTWaiter`](https://developer.apple.com/documentation/xctest/xctwaiter) or using a convenience method on `XCTestCase`.

Wherever possible, prefer to use Swift concurrency to validate asynchronous conditions. For example, if it’s necessary to determine the result of an asynchronous Swift function, it can be awaited with `await`. For a function that takes a completion handler but which doesn’t use `await`, a Swift [continuation](https://developer.apple.com/documentation/swift/withcheckedcontinuation(function:_:)) can be used to convert the call into an `async`-compatible one.

Some tests, especially those that test asynchronously-delivered events, cannot be readily converted to use Swift concurrency. The testing library offers functionality called _confirmations_ which can be used to implement these tests. Instances of [`Confirmation`](https://developer.apple.com/documentation/testing/confirmation) are created and used within the scope of the functions [`confirmation(_:expectedCount:isolation:sourceLocation:_:)`](https://developer.apple.com/documentation/testing/confirmation(_:expectedcount:isolation:sourcelocation:_:)-5mqz2) and [`confirmation(_:expectedCount:isolation:sourceLocation:_:)`](https://developer.apple.com/documentation/testing/confirmation(_:expectedcount:isolation:sourcelocation:_:)-l3il).

Confirmations function similarly to the expectations API of XCTest, however, they don’t block or suspend the caller while waiting for a condition to be fulfilled. Instead, the requirement is expected to be _confirmed_ (the equivalent of _fulfilling_ an expectation) before `confirmation()` returns, and records an issue otherwise:

```
// Before
func testTruckEvents() async {
  let soldFood = expectation(description: "…")
  FoodTruck.shared.eventHandler = { event in
    if case .soldFood = event {
      soldFood.fulfill()
    }
  }
  await Customer().buy(.soup)
  await fulfillment(of: [soldFood])
  ...
}

```

```
// After
@Test func truckEvents() async {
  await confirmation("…") { soldFood in
    FoodTruck.shared.eventHandler = { event in
      if case .soldFood = event {
        soldFood()
      }
    }
    await Customer().buy(.soup)
  }
  ...
}

```

By default, `XCTestExpectation` expects to be fulfilled exactly once, and will record an issue in the current test if it is not fulfilled or if it is fulfilled more than once. `Confirmation` behaves the same way and expects to be confirmed exactly once by default. You can configure the number of times an expectation should be fulfilled by setting its [`expectedFulfillmentCount`](https://developer.apple.com/documentation/xctest/xctestexpectation/2806572-expectedfulfillmentcount) property, and you can pass a value for the `expectedCount` argument of [`confirmation(_:expectedCount:isolation:sourceLocation:_:)`](https://developer.apple.com/documentation/testing/confirmation(_:expectedcount:isolation:sourcelocation:_:)-5mqz2) for the same purpose.

`XCTestExpectation` has a property, [`assertForOverFulfill`](https://developer.apple.com/documentation/xctest/xctestexpectation/2806575-assertforoverfulfill), which when set to `false` allows an expectation to be fulfilled more times than expected without causing a test failure. When using a confirmation, you can pass a range to [`confirmation(_:expectedCount:isolation:sourceLocation:_:)`](https://developer.apple.com/documentation/testing/confirmation(_:expectedcount:isolation:sourcelocation:_:)-l3il) as its expected count to indicate that it must be confirmed _at least_ some number of times:

```
// Before
func testRegularCustomerOrders() async {
  let soldFood = expectation(description: "…")
  soldFood.expectedFulfillmentCount = 10
  soldFood.assertForOverFulfill = false
  FoodTruck.shared.eventHandler = { event in
    if case .soldFood = event {
      soldFood.fulfill()
    }
  }
  for customer in regularCustomers() {
    await customer.buy(customer.regularOrder)
  }
  await fulfillment(of: [soldFood])
  ...
}

```

```
// After
@Test func regularCustomerOrders() async {
  await confirmation(
    "…",
    expectedCount: 10...
  ) { soldFood in
    FoodTruck.shared.eventHandler = { event in
      if case .soldFood = event {
        soldFood()
      }
    }
    for customer in regularCustomers() {
      await customer.buy(customer.regularOrder)
    }
  }
  ...
}

```

Any range expression with a lower bound (that is, whose type conforms to both [`RangeExpression<Int>`](https://developer.apple.com/documentation/swift/rangeexpression) and [`Sequence<Int>`](https://developer.apple.com/documentation/swift/sequence)) can be used with [`confirmation(_:expectedCount:isolation:sourceLocation:_:)`](https://developer.apple.com/documentation/testing/confirmation(_:expectedcount:isolation:sourcelocation:_:)-l3il). You must specify a lower bound for the number of confirmations because, without one, the testing library cannot tell if an issue should be recorded when there have been zero confirmations.

### [Control whether a test runs](https://developer.apple.com/documentation/testing/migratingfromxctest\#Control-whether-a-test-runs)

When using XCTest, the [`XCTSkip`](https://developer.apple.com/documentation/xctest/xctskip) error type can be thrown to bypass the remainder of a test function. As well, the [`XCTSkipIf()`](https://developer.apple.com/documentation/xctest/3521325-xctskipif) and [`XCTSkipUnless()`](https://developer.apple.com/documentation/xctest/3521326-xctskipunless) functions can be used to conditionalize the same action. The testing library allows developers to skip a test function or an entire test suite before it starts running using the [`ConditionTrait`](https://developer.apple.com/documentation/testing/conditiontrait) trait type. Annotate a test suite or test function with an instance of this trait type to control whether it runs:

```
// Before
class FoodTruckTests: XCTestCase {
  func testArepasAreTasty() throws {
    try XCTSkipIf(CashRegister.isEmpty)
    try XCTSkipUnless(FoodTruck.sells(.arepas))
    ...
  }
  ...
}

```

```
// After
@Suite(.disabled(if: CashRegister.isEmpty))
struct FoodTruckTests {
  @Test(.enabled(if: FoodTruck.sells(.arepas)))
  func arepasAreTasty() {
    ...
  }
  ...
}

```

### [Annotate known issues](https://developer.apple.com/documentation/testing/migratingfromxctest\#Annotate-known-issues)

A test may have a known issue that sometimes or always prevents it from passing. When written using XCTest, such tests can call [`XCTExpectFailure(_:options:failingBlock:)`](https://developer.apple.com/documentation/xctest/3727246-xctexpectfailure) to tell XCTest and its infrastructure that the issue shouldn’t cause the test to fail. The testing library has an equivalent function with synchronous and asynchronous variants:

- [`withKnownIssue(_:isIntermittent:sourceLocation:_:)`](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:sourcelocation:_:))

- [`withKnownIssue(_:isIntermittent:isolation:sourceLocation:_:)`](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:isolation:sourcelocation:_:))


This function can be used to annotate a section of a test as having a known issue:

```
// Before
func testGrillWorks() async {
  XCTExpectFailure("Grill is out of fuel") {
    try FoodTruck.shared.grill.start()
  }
  ...
}

```

```
// After
@Test func grillWorks() async {
  withKnownIssue("Grill is out of fuel") {
    try FoodTruck.shared.grill.start()
  }
  ...
}

```

If a test may fail intermittently, the call to `XCTExpectFailure(_:options:failingBlock:)` can be marked _non-strict_. When using the testing library, specify that the known issue is _intermittent_ instead:

```
// Before
func testGrillWorks() async {
  XCTExpectFailure(
    "Grill may need fuel",
    options: .nonStrict()
  ) {
    try FoodTruck.shared.grill.start()
  }
  ...
}

```

```
// After
@Test func grillWorks() async {
  withKnownIssue(
    "Grill may need fuel",
    isIntermittent: true
  ) {
    try FoodTruck.shared.grill.start()
  }
  ...
}

```

Additional options can be specified when calling `XCTExpectFailure()`:

- [`isEnabled`](https://developer.apple.com/documentation/xctest/xctexpectedfailure/options/3726085-isenabled) can be set to `false` to skip known-issue matching (for instance, if a particular issue only occurs under certain conditions)

- [`issueMatcher`](https://developer.apple.com/documentation/xctest/xctexpectedfailure/options/3726086-issuematcher) can be set to a closure to allow marking only certain issues as known and to allow other issues to be recorded as test failures


The testing library includes overloads of `withKnownIssue()` that take additional arguments with similar behavior:

- [`withKnownIssue(_:isIntermittent:sourceLocation:_:when:matching:)`](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:sourcelocation:_:when:matching:))

- [`withKnownIssue(_:isIntermittent:isolation:sourceLocation:_:when:matching:)`](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:isolation:sourcelocation:_:when:matching:))


To conditionally enable known-issue matching or to match only certain kinds of issues:

```
// Before
func testGrillWorks() async {
  let options = XCTExpectedFailure.Options()
  options.isEnabled = FoodTruck.shared.hasGrill
  options.issueMatcher = { issue in
    issue.type == thrownError
  }
  XCTExpectFailure(
    "Grill is out of fuel",
    options: options
  ) {
    try FoodTruck.shared.grill.start()
  }
  ...
}

```

```
// After
@Test func grillWorks() async {
  withKnownIssue("Grill is out of fuel") {
    try FoodTruck.shared.grill.start()
  } when: {
    FoodTruck.shared.hasGrill
  } matching: { issue in
    issue.error != nil
  }
  ...
}

```

### [Run tests sequentially](https://developer.apple.com/documentation/testing/migratingfromxctest\#Run-tests-sequentially)

By default, the testing library runs all tests in a suite in parallel. The default behavior of XCTest is to run each test in a suite sequentially. If your tests use shared state such as global variables, you may see unexpected behavior including unreliable test outcomes when you run tests in parallel.

Annotate your test suite with [`serialized`](https://developer.apple.com/documentation/testing/trait/serialized) to run tests within that suite serially:

```
// Before
class RefrigeratorTests : XCTestCase {
  func testLightComesOn() throws {
    try FoodTruck.shared.refrigerator.openDoor()
    XCTAssertEqual(FoodTruck.shared.refrigerator.lightState, .on)
  }

  func testLightGoesOut() throws {
    try FoodTruck.shared.refrigerator.openDoor()
    try FoodTruck.shared.refrigerator.closeDoor()
    XCTAssertEqual(FoodTruck.shared.refrigerator.lightState, .off)
  }
}

```

```
// After
@Suite(.serialized)
class RefrigeratorTests {
  @Test func lightComesOn() throws {
    try FoodTruck.shared.refrigerator.openDoor()
    #expect(FoodTruck.shared.refrigerator.lightState == .on)
  }

  @Test func lightGoesOut() throws {
    try FoodTruck.shared.refrigerator.openDoor()
    try FoodTruck.shared.refrigerator.closeDoor()
    #expect(FoodTruck.shared.refrigerator.lightState == .off)
  }
}

```

For more information, see [Running tests serially or in parallel](https://developer.apple.com/documentation/testing/parallelization).

## [See Also](https://developer.apple.com/documentation/testing/migratingfromxctest\#see-also)

### [Related Documentation](https://developer.apple.com/documentation/testing/migratingfromxctest\#Related-Documentation)

[Defining test functions](https://developer.apple.com/documentation/testing/definingtests)

Define a test function to validate that code is working correctly.

[Organizing test functions with suite types](https://developer.apple.com/documentation/testing/organizingtests)

Organize tests into test suites.

[API Reference\\
Expectations and confirmations](https://developer.apple.com/documentation/testing/expectations)

Check for expected values, outcomes, and asynchronous events in tests.

[API Reference\\
Known issues](https://developer.apple.com/documentation/testing/known-issues)

Highlight known issues when running tests.

### [Essentials](https://developer.apple.com/documentation/testing/migratingfromxctest\#Essentials)

[Defining test functions](https://developer.apple.com/documentation/testing/definingtests)

Define a test function to validate that code is working correctly.

[Organizing test functions with suite types](https://developer.apple.com/documentation/testing/organizingtests)

Organize tests into test suites.

[`macro Test(String?, any TestTrait...)`](https://developer.apple.com/documentation/testing/test(_:_:))

Declare a test.

[`struct Test`](https://developer.apple.com/documentation/testing/test)

A type representing a test or suite.

[`macro Suite(String?, any SuiteTrait...)`](https://developer.apple.com/documentation/testing/suite(_:_:))

Declare a test suite.

Current page is Migrating a test from XCTest

## TestTrait Protocol
[Skip Navigation](https://developer.apple.com/documentation/testing/testtrait#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- TestTrait

Protocol

# TestTrait

A protocol describing a trait that you can add to a test function.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
protocol TestTrait : Trait
```

## [Overview](https://developer.apple.com/documentation/testing/testtrait\#overview)

The testing library defines a number of traits that you can add to test functions. You can also define your own traits by creating types that conform to this protocol, or to the [`SuiteTrait`](https://developer.apple.com/documentation/testing/suitetrait) protocol.

## [Relationships](https://developer.apple.com/documentation/testing/testtrait\#relationships)

### [Inherits From](https://developer.apple.com/documentation/testing/testtrait\#inherits-from)

- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable)
- [`Trait`](https://developer.apple.com/documentation/testing/trait)

### [Conforming Types](https://developer.apple.com/documentation/testing/testtrait\#conforming-types)

- [`Bug`](https://developer.apple.com/documentation/testing/bug)
- [`Comment`](https://developer.apple.com/documentation/testing/comment)
- [`ConditionTrait`](https://developer.apple.com/documentation/testing/conditiontrait)
- [`ParallelizationTrait`](https://developer.apple.com/documentation/testing/parallelizationtrait)
- [`Tag.List`](https://developer.apple.com/documentation/testing/tag/list)
- [`TimeLimitTrait`](https://developer.apple.com/documentation/testing/timelimittrait)

## [See Also](https://developer.apple.com/documentation/testing/testtrait\#see-also)

### [Creating custom traits](https://developer.apple.com/documentation/testing/testtrait\#Creating-custom-traits)

[`protocol Trait`](https://developer.apple.com/documentation/testing/trait)

A protocol describing traits that can be added to a test function or to a test suite.

[`protocol SuiteTrait`](https://developer.apple.com/documentation/testing/suitetrait)

A protocol describing a trait that you can add to a test suite.

[`protocol TestScoping`](https://developer.apple.com/documentation/testing/testscoping)

A protocol that tells the test runner to run custom code before or after it runs a test suite or test function.

Current page is TestTrait

## Parallelization Trait
[Skip Navigation](https://developer.apple.com/documentation/testing/parallelizationtrait#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- ParallelizationTrait

Structure

# ParallelizationTrait

A type that defines whether the testing library runs this test serially or in parallel.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
struct ParallelizationTrait
```

## [Overview](https://developer.apple.com/documentation/testing/parallelizationtrait\#overview)

When you add this trait to a parameterized test function, that test runs its cases serially instead of in parallel. This trait has no effect when you apply it to a non-parameterized test function.

When you add this trait to a test suite, that suite runs its contained test functions (including their cases, when parameterized) and sub-suites serially instead of in parallel. If the sub-suites have children, they also run serially.

This trait does not affect the execution of a test relative to its peers or to unrelated tests. This trait has no effect if you disable test parallelization globally (for example, by passing `--no-parallel` to the `swift test` command.)

To add this trait to a test, use [`serialized`](https://developer.apple.com/documentation/testing/trait/serialized).

## [Topics](https://developer.apple.com/documentation/testing/parallelizationtrait\#topics)

### [Instance Properties](https://developer.apple.com/documentation/testing/parallelizationtrait\#Instance-Properties)

[`var isRecursive: Bool`](https://developer.apple.com/documentation/testing/parallelizationtrait/isrecursive)

Whether this instance should be applied recursively to child test suites and test functions.

### [Type Aliases](https://developer.apple.com/documentation/testing/parallelizationtrait\#Type-Aliases)

[`typealias TestScopeProvider`](https://developer.apple.com/documentation/testing/parallelizationtrait/testscopeprovider)

The type of the test scope provider for this trait.

### [Default Implementations](https://developer.apple.com/documentation/testing/parallelizationtrait\#Default-Implementations)

[API Reference\\
Trait Implementations](https://developer.apple.com/documentation/testing/parallelizationtrait/trait-implementations)

## [Relationships](https://developer.apple.com/documentation/testing/parallelizationtrait\#relationships)

### [Conforms To](https://developer.apple.com/documentation/testing/parallelizationtrait\#conforms-to)

- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable)
- [`SuiteTrait`](https://developer.apple.com/documentation/testing/suitetrait)
- [`TestTrait`](https://developer.apple.com/documentation/testing/testtrait)
- [`Trait`](https://developer.apple.com/documentation/testing/trait)

## [See Also](https://developer.apple.com/documentation/testing/parallelizationtrait\#see-also)

### [Supporting types](https://developer.apple.com/documentation/testing/parallelizationtrait\#Supporting-types)

[`struct Bug`](https://developer.apple.com/documentation/testing/bug)

A type that represents a bug report tracked by a test.

[`struct Comment`](https://developer.apple.com/documentation/testing/comment)

A type that represents a comment related to a test.

[`struct ConditionTrait`](https://developer.apple.com/documentation/testing/conditiontrait)

A type that defines a condition which must be satisfied for the testing library to enable a test.

[`struct Tag`](https://developer.apple.com/documentation/testing/tag)

A type representing a tag that can be applied to a test.

[`struct List`](https://developer.apple.com/documentation/testing/tag/list)

A type representing one or more tags applied to a test.

[`struct TimeLimitTrait`](https://developer.apple.com/documentation/testing/timelimittrait)

A type that defines a time limit to apply to a test.

Current page is ParallelizationTrait

## Test Execution Control
[Skip Navigation](https://developer.apple.com/documentation/testing/parallelization#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Traits](https://developer.apple.com/documentation/testing/traits)
- Running tests serially or in parallel

Article

# Running tests serially or in parallel

Control whether tests run serially or in parallel.

## [Overview](https://developer.apple.com/documentation/testing/parallelization\#Overview)

By default, tests run in parallel with respect to each other. Parallelization is accomplished by the testing library using task groups, and tests generally all run in the same process. The number of tests that run concurrently is controlled by the Swift runtime.

## [Disabling parallelization](https://developer.apple.com/documentation/testing/parallelization\#Disabling-parallelization)

Parallelization can be disabled on a per-function or per-suite basis using the [`serialized`](https://developer.apple.com/documentation/testing/trait/serialized) trait:

```
@Test(.serialized, arguments: Food.allCases) func prepare(food: Food) {
  // This function will be invoked serially, once per food, because it has the
  // .serialized trait.
}

@Suite(.serialized) struct FoodTruckTests {
  @Test(arguments: Condiment.allCases) func refill(condiment: Condiment) {
    // This function will be invoked serially, once per condiment, because the
    // containing suite has the .serialized trait.
  }

  @Test func startEngine() async throws {
    // This function will not run while refill(condiment:) is running. One test
    // must end before the other will start.
  }
}

```

When added to a parameterized test function, this trait causes that test to run its cases serially instead of in parallel. When applied to a non-parameterized test function, this trait has no effect. When applied to a test suite, this trait causes that suite to run its contained test functions and sub-suites serially instead of in parallel.

This trait is recursively applied: if it is applied to a suite, any parameterized tests or test suites contained in that suite are also serialized (as are any tests contained in those suites, and so on.)

This trait doesn’t affect the execution of a test relative to its peers or to unrelated tests. This trait has no effect if test parallelization is globally disabled (by, for example, passing `--no-parallel` to the `swift test` command.)

## [See Also](https://developer.apple.com/documentation/testing/parallelization\#see-also)

### [Running tests serially or in parallel](https://developer.apple.com/documentation/testing/parallelization\#Running-tests-serially-or-in-parallel)

[`static var serialized: ParallelizationTrait`](https://developer.apple.com/documentation/testing/trait/serialized)

A trait that serializes the test to which it is applied.

Current page is Running tests serially or in parallel

## Enabling Tests
[Skip Navigation](https://developer.apple.com/documentation/testing/enablinganddisabling#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Traits](https://developer.apple.com/documentation/testing/traits)
- Enabling and disabling tests

Article

# Enabling and disabling tests

Conditionally enable or disable individual tests before they run.

## [Overview](https://developer.apple.com/documentation/testing/enablinganddisabling\#Overview)

Often, a test is only applicable in specific circumstances. For instance, you might want to write a test that only runs on devices with particular hardware capabilities, or performs locale-dependent operations. The testing library allows you to add traits to your tests that cause runners to automatically skip them if conditions like these are not met.

### [Disable a test](https://developer.apple.com/documentation/testing/enablinganddisabling\#Disable-a-test)

If you need to disable a test unconditionally, use the [`disabled(_:sourceLocation:)`](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:)) function. Given the following test function:

```
@Test("Food truck sells burritos")
func sellsBurritos() async throws { ... }

```

Add the trait _after_ the test’s display name:

```
@Test("Food truck sells burritos", .disabled())
func sellsBurritos() async throws { ... }

```

The test will now always be skipped.

It’s also possible to add a comment to the trait to present in the output from the runner when it skips the test:

```
@Test("Food truck sells burritos", .disabled("We only sell Thai cuisine"))
func sellsBurritos() async throws { ... }

```

### [Enable or disable a test conditionally](https://developer.apple.com/documentation/testing/enablinganddisabling\#Enable-or-disable-a-test-conditionally)

Sometimes, it makes sense to enable a test only when a certain condition is met. Consider the following test function:

```
@Test("Ice cream is cold")
func isCold() async throws { ... }

```

If it’s currently winter, then presumably ice cream won’t be available for sale and this test will fail. It therefore makes sense to only enable it if it’s currently summer. You can conditionally enable a test with [`enabled(if:_:sourceLocation:)`](https://developer.apple.com/documentation/testing/trait/enabled(if:_:sourcelocation:)):

```
@Test("Ice cream is cold", .enabled(if: Season.current == .summer))
func isCold() async throws { ... }

```

It’s also possible to conditionally _disable_ a test and to combine multiple conditions:

```
@Test(
  "Ice cream is cold",
  .enabled(if: Season.current == .summer),
  .disabled("We ran out of sprinkles")
)
func isCold() async throws { ... }

```

If a test is disabled because of a problem for which there is a corresponding bug report, you can use one of these functions to show the relationship between the test and the bug report:

- [`bug(_:_:)`](https://developer.apple.com/documentation/testing/trait/bug(_:_:))

- [`bug(_:id:_:)`](https://developer.apple.com/documentation/testing/trait/bug(_:id:_:)-10yf5)

- [`bug(_:id:_:)`](https://developer.apple.com/documentation/testing/trait/bug(_:id:_:)-3vtpl)


For example, the following test cannot run due to bug number `"12345"`:

```
@Test(
  "Ice cream is cold",
  .enabled(if: Season.current == .summer),
  .disabled("We ran out of sprinkles"),
  .bug(id: "12345")
)
func isCold() async throws { ... }

```

If a test has multiple conditions applied to it, they must _all_ pass for it to run. Otherwise, the test notes the first condition to fail as the reason the test is skipped.

### [Handle complex conditions](https://developer.apple.com/documentation/testing/enablinganddisabling\#Handle-complex-conditions)

If a condition is complex, consider factoring it out into a helper function to improve readability:

```
func allIngredientsAvailable(for food: Food) -> Bool { ... }

@Test(
  "Can make sundaes",
  .enabled(if: Season.current == .summer),
  .enabled(if: allIngredientsAvailable(for: .sundae))
)
func makeSundae() async throws { ... }

```

## [See Also](https://developer.apple.com/documentation/testing/enablinganddisabling\#see-also)

### [Customizing runtime behaviors](https://developer.apple.com/documentation/testing/enablinganddisabling\#Customizing-runtime-behaviors)

[Limiting the running time of tests](https://developer.apple.com/documentation/testing/limitingexecutiontime)

Set limits on how long a test can run for until it fails.

[`static func enabled(if: @autoclosure () throws -> Bool, Comment?, sourceLocation: SourceLocation) -> Self`](https://developer.apple.com/documentation/testing/trait/enabled(if:_:sourcelocation:))

Constructs a condition trait that disables a test if it returns `false`.

[`static func enabled(Comment?, sourceLocation: SourceLocation, () async throws -> Bool) -> Self`](https://developer.apple.com/documentation/testing/trait/enabled(_:sourcelocation:_:))

Constructs a condition trait that disables a test if it returns `false`.

[`static func disabled(Comment?, sourceLocation: SourceLocation) -> Self`](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:))

Constructs a condition trait that disables a test unconditionally.

[`static func disabled(if: @autoclosure () throws -> Bool, Comment?, sourceLocation: SourceLocation) -> Self`](https://developer.apple.com/documentation/testing/trait/disabled(if:_:sourcelocation:))

Constructs a condition trait that disables a test if its value is true.

[`static func disabled(Comment?, sourceLocation: SourceLocation, () async throws -> Bool) -> Self`](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:_:))

Constructs a condition trait that disables a test if its value is true.

[`static func timeLimit(TimeLimitTrait.Duration) -> Self`](https://developer.apple.com/documentation/testing/trait/timelimit(_:))

Construct a time limit trait that causes a test to time out if it runs for too long.

Current page is Enabling and disabling tests

## Testing Expectations
[Skip Navigation](https://developer.apple.com/documentation/testing/expectations#app-main)

Collection

- [Swift Testing](https://developer.apple.com/documentation/testing)
- Expectations and confirmations

API Collection

# Expectations and confirmations

Check for expected values, outcomes, and asynchronous events in tests.

## [Overview](https://developer.apple.com/documentation/testing/expectations\#Overview)

Use [`expect(_:_:sourceLocation:)`](https://developer.apple.com/documentation/testing/expect(_:_:sourcelocation:)) and [`require(_:_:sourceLocation:)`](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-5l63q) macros to validate expected outcomes. To validate that an error is thrown, or _not_ thrown, the testing library provides several overloads of the macros that you can use. For more information, see [Testing for errors in Swift code](https://developer.apple.com/documentation/testing/testing-for-errors-in-swift-code).

Use a [`Confirmation`](https://developer.apple.com/documentation/testing/confirmation) to confirm the occurrence of an asynchronous event that you can’t check directly using an expectation. For more information, see [Testing asynchronous code](https://developer.apple.com/documentation/testing/testing-asynchronous-code).

### [Validate your code’s result](https://developer.apple.com/documentation/testing/expectations\#Validate-your-codes-result)

To validate that your code produces an expected value, use [`expect(_:_:sourceLocation:)`](https://developer.apple.com/documentation/testing/expect(_:_:sourcelocation:)). This macro captures the expression you pass, and provides detailed information when the code doesn’t satisfy the expectation.

```
@Test func calculatingOrderTotal() {
  let calculator = OrderCalculator()
  #expect(calculator.total(of: [3, 3]) == 7)
  // Prints "Expectation failed: (calculator.total(of: [3, 3]) → 6) == 7"
}

```

Your test keeps running after [`expect(_:_:sourceLocation:)`](https://developer.apple.com/documentation/testing/expect(_:_:sourcelocation:)) fails. To stop the test when the code doesn’t satisfy a requirement, use [`require(_:_:sourceLocation:)`](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-5l63q) instead:

```
@Test func returningCustomerRemembersUsualOrder() throws {
  let customer = try #require(Customer(id: 123))
  // The test runner doesn't reach this line if the customer is nil.
  #expect(customer.usualOrder.countOfItems == 2)
}

```

[`require(_:_:sourceLocation:)`](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-5l63q) throws an instance of [`ExpectationFailedError`](https://developer.apple.com/documentation/testing/expectationfailederror) when your code fails to satisfy the requirement.

## [Topics](https://developer.apple.com/documentation/testing/expectations\#topics)

### [Checking expectations](https://developer.apple.com/documentation/testing/expectations\#Checking-expectations)

[`macro expect(Bool, @autoclosure () -> Comment?, sourceLocation: SourceLocation)`](https://developer.apple.com/documentation/testing/expect(_:_:sourcelocation:))

Check that an expectation has passed after a condition has been evaluated.

[`macro require(Bool, @autoclosure () -> Comment?, sourceLocation: SourceLocation)`](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-5l63q)

Check that an expectation has passed after a condition has been evaluated and throw an error if it failed.

[`macro require<T>(T?, @autoclosure () -> Comment?, sourceLocation: SourceLocation) -> T`](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-6w9oo)

Unwrap an optional value or, if it is `nil`, fail and throw an error.

### [Checking that errors are thrown](https://developer.apple.com/documentation/testing/expectations\#Checking-that-errors-are-thrown)

[Testing for errors in Swift code](https://developer.apple.com/documentation/testing/testing-for-errors-in-swift-code)

Ensure that your code handles errors in the way you expect.

[`macro expect<E, R>(throws: E.Type, @autoclosure () -> Comment?, sourceLocation: SourceLocation, performing: () async throws -> R) -> E?`](https://developer.apple.com/documentation/testing/expect(throws:_:sourcelocation:performing:)-1hfms)

Check that an expression always throws an error of a given type.

[`macro expect<E, R>(throws: E, @autoclosure () -> Comment?, sourceLocation: SourceLocation, performing: () async throws -> R) -> E?`](https://developer.apple.com/documentation/testing/expect(throws:_:sourcelocation:performing:)-7du1h)

Check that an expression always throws a specific error.

[`macro expect<R>(@autoclosure () -> Comment?, sourceLocation: SourceLocation, performing: () async throws -> R, throws: (any Error) async throws -> Bool) -> (any Error)?`](https://developer.apple.com/documentation/testing/expect(_:sourcelocation:performing:throws:))

Check that an expression always throws an error matching some condition.

Deprecated

[`macro require<E, R>(throws: E.Type, @autoclosure () -> Comment?, sourceLocation: SourceLocation, performing: () async throws -> R) -> E`](https://developer.apple.com/documentation/testing/require(throws:_:sourcelocation:performing:)-7n34r)

Check that an expression always throws an error of a given type, and throw an error if it does not.

[`macro require<E, R>(throws: E, @autoclosure () -> Comment?, sourceLocation: SourceLocation, performing: () async throws -> R) -> E`](https://developer.apple.com/documentation/testing/require(throws:_:sourcelocation:performing:)-4djuw)

[`macro require<R>(@autoclosure () -> Comment?, sourceLocation: SourceLocation, performing: () async throws -> R, throws: (any Error) async throws -> Bool) -> any Error`](https://developer.apple.com/documentation/testing/require(_:sourcelocation:performing:throws:))

Check that an expression always throws an error matching some condition, and throw an error if it does not.

Deprecated

### [Confirming that asynchronous events occur](https://developer.apple.com/documentation/testing/expectations\#Confirming-that-asynchronous-events-occur)

[Testing asynchronous code](https://developer.apple.com/documentation/testing/testing-asynchronous-code)

Validate whether your code causes expected events to happen.

[`func confirmation<R>(Comment?, expectedCount: Int, isolation: isolated (any Actor)?, sourceLocation: SourceLocation, (Confirmation) async throws -> sending R) async rethrows -> R`](https://developer.apple.com/documentation/testing/confirmation(_:expectedcount:isolation:sourcelocation:_:)-5mqz2)

Confirm that some event occurs during the invocation of a function.

[`func confirmation<R>(Comment?, expectedCount: some RangeExpression<Int> & Sendable & Sequence<Int>, isolation: isolated (any Actor)?, sourceLocation: SourceLocation, (Confirmation) async throws -> sending R) async rethrows -> R`](https://developer.apple.com/documentation/testing/confirmation(_:expectedcount:isolation:sourcelocation:_:)-l3il)

Confirm that some event occurs during the invocation of a function.

[`struct Confirmation`](https://developer.apple.com/documentation/testing/confirmation)

A type that can be used to confirm that an event occurs zero or more times.

### [Retrieving information about checked expectations](https://developer.apple.com/documentation/testing/expectations\#Retrieving-information-about-checked-expectations)

[`struct Expectation`](https://developer.apple.com/documentation/testing/expectation)

A type describing an expectation that has been evaluated.

[`struct ExpectationFailedError`](https://developer.apple.com/documentation/testing/expectationfailederror)

A type describing an error thrown when an expectation fails during evaluation.

[`protocol CustomTestStringConvertible`](https://developer.apple.com/documentation/testing/customteststringconvertible)

A protocol describing types with a custom string representation when presented as part of a test’s output.

### [Representing source locations](https://developer.apple.com/documentation/testing/expectations\#Representing-source-locations)

[`struct SourceLocation`](https://developer.apple.com/documentation/testing/sourcelocation)

A type representing a location in source code.

## [See Also](https://developer.apple.com/documentation/testing/expectations\#see-also)

### [Behavior validation](https://developer.apple.com/documentation/testing/expectations\#Behavior-validation)

[API Reference\\
Known issues](https://developer.apple.com/documentation/testing/known-issues)

Highlight known issues when running tests.

Current page is Expectations and confirmations

## Known Issue Matcher
[Skip Navigation](https://developer.apple.com/documentation/testing/knownissuematcher#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- KnownIssueMatcher

Type Alias

# KnownIssueMatcher

A function that is used to match known issues.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
typealias KnownIssueMatcher = (Issue) -> Bool
```

## [Parameters](https://developer.apple.com/documentation/testing/knownissuematcher\#parameters)

`issue`

The issue to match.

## [Return Value](https://developer.apple.com/documentation/testing/knownissuematcher\#return-value)

Whether or not `issue` is known to occur.

## [See Also](https://developer.apple.com/documentation/testing/knownissuematcher\#see-also)

### [Recording known issues in tests](https://developer.apple.com/documentation/testing/knownissuematcher\#Recording-known-issues-in-tests)

[`func withKnownIssue(Comment?, isIntermittent: Bool, sourceLocation: SourceLocation, () throws -> Void)`](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:sourcelocation:_:))

Invoke a function that has a known issue that is expected to occur during its execution.

[`func withKnownIssue(Comment?, isIntermittent: Bool, isolation: isolated (any Actor)?, sourceLocation: SourceLocation, () async throws -> Void) async`](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:isolation:sourcelocation:_:))

Invoke a function that has a known issue that is expected to occur during its execution.

[`func withKnownIssue(Comment?, isIntermittent: Bool, sourceLocation: SourceLocation, () throws -> Void, when: () -> Bool, matching: KnownIssueMatcher) rethrows`](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:sourcelocation:_:when:matching:))

Invoke a function that has a known issue that is expected to occur during its execution.

[`func withKnownIssue(Comment?, isIntermittent: Bool, isolation: isolated (any Actor)?, sourceLocation: SourceLocation, () async throws -> Void, when: () async -> Bool, matching: KnownIssueMatcher) async rethrows`](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:isolation:sourcelocation:_:when:matching:))

Invoke a function that has a known issue that is expected to occur during its execution.

Current page is KnownIssueMatcher

## Associating Bugs with Tests
[Skip Navigation](https://developer.apple.com/documentation/testing/associatingbugs#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Traits](https://developer.apple.com/documentation/testing/traits)
- Associating bugs with tests

Article

# Associating bugs with tests

Associate bugs uncovered or verified by tests.

## [Overview](https://developer.apple.com/documentation/testing/associatingbugs\#Overview)

Tests allow developers to prove that the code they write is working as expected. If code isn’t working correctly, bug trackers are often used to track the work necessary to fix the underlying problem. It’s often useful to associate specific bugs with tests that reproduce them or verify they are fixed.

## [Associate a bug with a test](https://developer.apple.com/documentation/testing/associatingbugs\#Associate-a-bug-with-a-test)

To associate a bug with a test, use one of these functions:

- [`bug(_:_:)`](https://developer.apple.com/documentation/testing/trait/bug(_:_:))

- [`bug(_:id:_:)`](https://developer.apple.com/documentation/testing/trait/bug(_:id:_:)-10yf5)

- [`bug(_:id:_:)`](https://developer.apple.com/documentation/testing/trait/bug(_:id:_:)-3vtpl)


The first argument to these functions is a URL representing the bug in its bug-tracking system:

```
@Test("Food truck engine works", .bug("https://www.example.com/issues/12345"))
func engineWorks() async {
  var foodTruck = FoodTruck()
  await foodTruck.engine.start()
  #expect(foodTruck.engine.isRunning)
}

```

You can also specify the bug’s _unique identifier_ in its bug-tracking system in addition to, or instead of, its URL:

```
@Test(
  "Food truck engine works",
  .bug(id: "12345"),
  .bug("https://www.example.com/issues/67890", id: 67890)
)
func engineWorks() async {
  var foodTruck = FoodTruck()
  await foodTruck.engine.start()
  #expect(foodTruck.engine.isRunning)
}

```

A bug’s URL is passed as a string and must be parseable according to [RFC 3986](https://www.ietf.org/rfc/rfc3986.txt). A bug’s unique identifier can be passed as an integer or as a string. For more information on the formats recognized by the testing library, see [Interpreting bug identifiers](https://developer.apple.com/documentation/testing/bugidentifiers).

## [Add titles to associated bugs](https://developer.apple.com/documentation/testing/associatingbugs\#Add-titles-to-associated-bugs)

A bug’s unique identifier or URL may be insufficient to uniquely and clearly identify a bug associated with a test. Bug trackers universally provide a “title” field for bugs that is not visible to the testing library. To add a bug’s title to a test, include it after the bug’s unique identifier or URL:

```
@Test(
  "Food truck has napkins",
  .bug(id: "12345", "Forgot to buy more napkins")
)
func hasNapkins() async {
  ...
}

```

## [See Also](https://developer.apple.com/documentation/testing/associatingbugs\#see-also)

### [Annotating tests](https://developer.apple.com/documentation/testing/associatingbugs\#Annotating-tests)

[Adding tags to tests](https://developer.apple.com/documentation/testing/addingtags)

Use tags to provide semantic information for organization, filtering, and customizing appearances.

[Adding comments to tests](https://developer.apple.com/documentation/testing/addingcomments)

Add comments to provide useful information about tests.

[Interpreting bug identifiers](https://developer.apple.com/documentation/testing/bugidentifiers)

Examine how the testing library interprets bug identifiers provided by developers.

[`macro Tag()`](https://developer.apple.com/documentation/testing/tag())

Declare a tag that can be applied to a test function or test suite.

[`static func bug(String, Comment?) -> Self`](https://developer.apple.com/documentation/testing/trait/bug(_:_:))

Constructs a bug to track with a test.

[`static func bug(String?, id: String, Comment?) -> Self`](https://developer.apple.com/documentation/testing/trait/bug(_:id:_:)-10yf5)

Constructs a bug to track with a test.

[`static func bug(String?, id: some Numeric, Comment?) -> Self`](https://developer.apple.com/documentation/testing/trait/bug(_:id:_:)-3vtpl)

Constructs a bug to track with a test.

Current page is Associating bugs with tests

## Test Comment Structure
[Skip Navigation](https://developer.apple.com/documentation/testing/comment#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- Comment

Structure

# Comment

A type that represents a comment related to a test.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
struct Comment
```

## [Overview](https://developer.apple.com/documentation/testing/comment\#overview)

Use this type to provide context or background information about a test’s purpose, explain how a complex test operates, or include details which may be helpful when diagnosing issues recorded by a test.

To add a comment to a test or suite, add a code comment before its `@Test` or `@Suite` attribute. See [Adding comments to tests](https://developer.apple.com/documentation/testing/addingcomments) for more details.

## [Topics](https://developer.apple.com/documentation/testing/comment\#topics)

### [Initializers](https://developer.apple.com/documentation/testing/comment\#Initializers)

[`init(rawValue: String)`](https://developer.apple.com/documentation/testing/comment/init(rawvalue:))

Creates a new instance with the specified raw value.

### [Instance Properties](https://developer.apple.com/documentation/testing/comment\#Instance-Properties)

[`var rawValue: String`](https://developer.apple.com/documentation/testing/comment/rawvalue-swift.property)

The single comment string that this comment contains.

### [Type Aliases](https://developer.apple.com/documentation/testing/comment\#Type-Aliases)

[`typealias RawValue`](https://developer.apple.com/documentation/testing/comment/rawvalue-swift.typealias)

The raw type that can be used to represent all values of the conforming type.

### [Default Implementations](https://developer.apple.com/documentation/testing/comment\#Default-Implementations)

[API Reference\\
CustomStringConvertible Implementations](https://developer.apple.com/documentation/testing/comment/customstringconvertible-implementations)

[API Reference\\
Equatable Implementations](https://developer.apple.com/documentation/testing/comment/equatable-implementations)

[API Reference\\
ExpressibleByExtendedGraphemeClusterLiteral Implementations](https://developer.apple.com/documentation/testing/comment/expressiblebyextendedgraphemeclusterliteral-implementations)

[API Reference\\
ExpressibleByStringInterpolation Implementations](https://developer.apple.com/documentation/testing/comment/expressiblebystringinterpolation-implementations)

[API Reference\\
ExpressibleByStringLiteral Implementations](https://developer.apple.com/documentation/testing/comment/expressiblebystringliteral-implementations)

[API Reference\\
ExpressibleByUnicodeScalarLiteral Implementations](https://developer.apple.com/documentation/testing/comment/expressiblebyunicodescalarliteral-implementations)

[API Reference\\
RawRepresentable Implementations](https://developer.apple.com/documentation/testing/comment/rawrepresentable-implementations)

[API Reference\\
SuiteTrait Implementations](https://developer.apple.com/documentation/testing/comment/suitetrait-implementations)

[API Reference\\
Trait Implementations](https://developer.apple.com/documentation/testing/comment/trait-implementations)

## [Relationships](https://developer.apple.com/documentation/testing/comment\#relationships)

### [Conforms To](https://developer.apple.com/documentation/testing/comment\#conforms-to)

- [`Copyable`](https://developer.apple.com/documentation/Swift/Copyable)
- [`CustomStringConvertible`](https://developer.apple.com/documentation/Swift/CustomStringConvertible)
- [`Decodable`](https://developer.apple.com/documentation/Swift/Decodable)
- [`Encodable`](https://developer.apple.com/documentation/Swift/Encodable)
- [`Equatable`](https://developer.apple.com/documentation/Swift/Equatable)
- [`ExpressibleByExtendedGraphemeClusterLiteral`](https://developer.apple.com/documentation/Swift/ExpressibleByExtendedGraphemeClusterLiteral)
- [`ExpressibleByStringInterpolation`](https://developer.apple.com/documentation/Swift/ExpressibleByStringInterpolation)
- [`ExpressibleByStringLiteral`](https://developer.apple.com/documentation/Swift/ExpressibleByStringLiteral)
- [`ExpressibleByUnicodeScalarLiteral`](https://developer.apple.com/documentation/Swift/ExpressibleByUnicodeScalarLiteral)
- [`Hashable`](https://developer.apple.com/documentation/Swift/Hashable)
- [`RawRepresentable`](https://developer.apple.com/documentation/Swift/RawRepresentable)
- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable)
- [`SuiteTrait`](https://developer.apple.com/documentation/testing/suitetrait)
- [`TestTrait`](https://developer.apple.com/documentation/testing/testtrait)
- [`Trait`](https://developer.apple.com/documentation/testing/trait)

## [See Also](https://developer.apple.com/documentation/testing/comment\#see-also)

### [Supporting types](https://developer.apple.com/documentation/testing/comment\#Supporting-types)

[`struct Bug`](https://developer.apple.com/documentation/testing/bug)

A type that represents a bug report tracked by a test.

[`struct ConditionTrait`](https://developer.apple.com/documentation/testing/conditiontrait)

A type that defines a condition which must be satisfied for the testing library to enable a test.

[`struct ParallelizationTrait`](https://developer.apple.com/documentation/testing/parallelizationtrait)

A type that defines whether the testing library runs this test serially or in parallel.

[`struct Tag`](https://developer.apple.com/documentation/testing/tag)

A type representing a tag that can be applied to a test.

[`struct List`](https://developer.apple.com/documentation/testing/tag/list)

A type representing one or more tags applied to a test.

[`struct TimeLimitTrait`](https://developer.apple.com/documentation/testing/timelimittrait)

A type that defines a time limit to apply to a test.

Current page is Comment

## Swift Test Time Limit
[Skip Navigation](https://developer.apple.com/documentation/testing/test/timelimit#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Test](https://developer.apple.com/documentation/testing/test)
- timeLimit

Instance Property

# timeLimit

The maximum amount of time this test’s cases may run for.

iOS 16.0+iPadOS 16.0+Mac Catalyst 16.0+macOS 13.0+tvOS 16.0+visionOSwatchOS 9.0+Swift 6.0+Xcode 16.0+

```
var timeLimit: Duration? { get }
```

## [Discussion](https://developer.apple.com/documentation/testing/test/timelimit\#discussion)

Associate a time limit with tests by using [`timeLimit(_:)`](https://developer.apple.com/documentation/testing/trait/timelimit(_:)).

If a test has more than one time limit associated with it, the value of this property is the shortest one. If a test has no time limits associated with it, the value of this property is `nil`.

Current page is timeLimit

## Swift fileID Property
[Skip Navigation](https://developer.apple.com/documentation/testing/sourcelocation/fileid#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [SourceLocation](https://developer.apple.com/documentation/testing/sourcelocation)
- fileID

Instance Property

# fileID

The file ID of the source file.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
var fileID: String { get set }
```

## [Discussion](https://developer.apple.com/documentation/testing/sourcelocation/fileid\#discussion)

## [See Also](https://developer.apple.com/documentation/testing/sourcelocation/fileid\#see-also)

### [Related Documentation](https://developer.apple.com/documentation/testing/sourcelocation/fileid\#Related-Documentation)

[`var moduleName: String`](https://developer.apple.com/documentation/testing/sourcelocation/modulename)

The name of the module containing the source file.

[`var fileName: String`](https://developer.apple.com/documentation/testing/sourcelocation/filename)

The name of the source file.

Current page is fileID

## Tag() Macro
[Skip Navigation](https://developer.apple.com/documentation/testing/tag()#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- Tag()

Macro

# Tag()

Declare a tag that can be applied to a test function or test suite.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
@attached(accessor) @attached(peer)
macro Tag()
```

## [Mentioned in](https://developer.apple.com/documentation/testing/tag()\#mentions)

[Adding tags to tests](https://developer.apple.com/documentation/testing/addingtags)

## [Overview](https://developer.apple.com/documentation/testing/tag()\#overview)

Use this tag with members of the [`Tag`](https://developer.apple.com/documentation/testing/tag) type declared in an extension to mark them as usable with tests. For more information on declaring tags, see [Adding tags to tests](https://developer.apple.com/documentation/testing/addingtags).

## [See Also](https://developer.apple.com/documentation/testing/tag()\#see-also)

### [Annotating tests](https://developer.apple.com/documentation/testing/tag()\#Annotating-tests)

[Adding tags to tests](https://developer.apple.com/documentation/testing/addingtags)

Use tags to provide semantic information for organization, filtering, and customizing appearances.

[Adding comments to tests](https://developer.apple.com/documentation/testing/addingcomments)

Add comments to provide useful information about tests.

[Associating bugs with tests](https://developer.apple.com/documentation/testing/associatingbugs)

Associate bugs uncovered or verified by tests.

[Interpreting bug identifiers](https://developer.apple.com/documentation/testing/bugidentifiers)

Examine how the testing library interprets bug identifiers provided by developers.

[`static func bug(String, Comment?) -> Self`](https://developer.apple.com/documentation/testing/trait/bug(_:_:))

Constructs a bug to track with a test.

[`static func bug(String?, id: String, Comment?) -> Self`](https://developer.apple.com/documentation/testing/trait/bug(_:id:_:)-10yf5)

Constructs a bug to track with a test.

[`static func bug(String?, id: some Numeric, Comment?) -> Self`](https://developer.apple.com/documentation/testing/trait/bug(_:id:_:)-3vtpl)

Constructs a bug to track with a test.

Current page is Tag()

## Swift Testing Error
[Skip Navigation](https://developer.apple.com/documentation/testing/issue/error#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Issue](https://developer.apple.com/documentation/testing/issue)
- error

Instance Property

# error

The error which was associated with this issue, if any.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
var error: (any Error)? { get }
```

## [Discussion](https://developer.apple.com/documentation/testing/issue/error\#discussion)

The value of this property is non- `nil` when [`kind`](https://developer.apple.com/documentation/testing/issue/kind-swift.property) is [`Issue.Kind.errorCaught(_:)`](https://developer.apple.com/documentation/testing/issue/kind-swift.enum/errorcaught(_:)).

Current page is error

## Test Description Property
[Skip Navigation](https://developer.apple.com/documentation/testing/customteststringconvertible/testdescription#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [CustomTestStringConvertible](https://developer.apple.com/documentation/testing/customteststringconvertible)
- testDescription

Instance Property

# testDescription

A description of this instance to use when presenting it in a test’s output.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
var testDescription: String { get }
```

**Required** Default implementation provided.

## [Discussion](https://developer.apple.com/documentation/testing/customteststringconvertible/testdescription\#discussion)

Do not use this property directly. To get the test description of a value, use `Swift/String/init(describingForTest:)`.

## [Default Implementations](https://developer.apple.com/documentation/testing/customteststringconvertible/testdescription\#default-implementations)

### [CustomTestStringConvertible Implementations](https://developer.apple.com/documentation/testing/customteststringconvertible/testdescription\#CustomTestStringConvertible-Implementations)

[`var testDescription: String`](https://developer.apple.com/documentation/testing/customteststringconvertible/testdescription-3ar66)

A description of this instance to use when presenting it in a test’s output.

Current page is testDescription

## Source Location Trait
[Skip Navigation](https://developer.apple.com/documentation/testing/conditiontrait/sourcelocation#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [ConditionTrait](https://developer.apple.com/documentation/testing/conditiontrait)
- sourceLocation

Instance Property

# sourceLocation

The source location where this trait is specified.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
var sourceLocation: SourceLocation
```

Current page is sourceLocation

## Swift Testing Name Property
[Skip Navigation](https://developer.apple.com/documentation/testing/test/name#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Test](https://developer.apple.com/documentation/testing/test)
- name

Instance Property

# name

The name of this instance.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
var name: String
```

## [Discussion](https://developer.apple.com/documentation/testing/test/name\#discussion)

The value of this property is equal to the name of the symbol to which the [`Test`](https://developer.apple.com/documentation/testing/test) attribute is applied (that is, the name of the type or function.) To get the customized display name specified as part of the [`Test`](https://developer.apple.com/documentation/testing/test) attribute, use the [`displayName`](https://developer.apple.com/documentation/testing/test/displayname) property.

Current page is name

## isRecursive Trait
[Skip Navigation](https://developer.apple.com/documentation/testing/suitetrait/isrecursive#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [SuiteTrait](https://developer.apple.com/documentation/testing/suitetrait)
- isRecursive

Instance Property

# isRecursive

Whether this instance should be applied recursively to child test suites and test functions.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
var isRecursive: Bool { get }
```

**Required** Default implementation provided.

## [Discussion](https://developer.apple.com/documentation/testing/suitetrait/isrecursive\#discussion)

If the value is `true`, then the testing library applies this trait recursively to child test suites and test functions. Otherwise, it only applies the trait to the test suite to which you added the trait.

By default, traits are not recursively applied to children.

## [Default Implementations](https://developer.apple.com/documentation/testing/suitetrait/isrecursive\#default-implementations)

### [SuiteTrait Implementations](https://developer.apple.com/documentation/testing/suitetrait/isrecursive\#SuiteTrait-Implementations)

[`var isRecursive: Bool`](https://developer.apple.com/documentation/testing/suitetrait/isrecursive-2z41z)

Whether this instance should be applied recursively to child test suites and test functions.

Current page is isRecursive

## Swift fileName Property
[Skip Navigation](https://developer.apple.com/documentation/testing/sourcelocation/filename#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [SourceLocation](https://developer.apple.com/documentation/testing/sourcelocation)
- fileName

Instance Property

# fileName

The name of the source file.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
var fileName: String { get }
```

## [Discussion](https://developer.apple.com/documentation/testing/sourcelocation/filename\#discussion)

The name of the source file is derived from this instance’s [`fileID`](https://developer.apple.com/documentation/testing/sourcelocation/fileid) property. It consists of the substring of the file ID after the last forward-slash character ( `"/"`.) For example, if the value of this instance’s [`fileID`](https://developer.apple.com/documentation/testing/sourcelocation/fileid) property is `"FoodTruck/WheelTests.swift"`, the file name is `"WheelTests.swift"`.

The structure of file IDs is described in the documentation for [`#fileID`](https://developer.apple.com/documentation/swift/fileID()) in the Swift standard library.

## [See Also](https://developer.apple.com/documentation/testing/sourcelocation/filename\#see-also)

### [Related Documentation](https://developer.apple.com/documentation/testing/sourcelocation/filename\#Related-Documentation)

[`var fileID: String`](https://developer.apple.com/documentation/testing/sourcelocation/fileid)

The file ID of the source file.

[`var moduleName: String`](https://developer.apple.com/documentation/testing/sourcelocation/modulename)

The name of the module containing the source file.

Current page is fileName

## Developer Comments Management
[Skip Navigation](https://developer.apple.com/documentation/testing/issue/comments#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Issue](https://developer.apple.com/documentation/testing/issue)
- comments

Instance Property

# comments

Any comments provided by the developer and associated with this issue.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
var comments: [Comment]
```

## [Discussion](https://developer.apple.com/documentation/testing/issue/comments\#discussion)

If no comment was supplied when the issue occurred, the value of this property is the empty array.

Current page is comments

## Source Location in Testing
[Skip Navigation](https://developer.apple.com/documentation/testing/issue/sourcelocation#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Issue](https://developer.apple.com/documentation/testing/issue)
- sourceLocation

Instance Property

# sourceLocation

The location in source where this issue occurred, if available.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
var sourceLocation: SourceLocation? { get set }
```

Current page is sourceLocation

## Test Comments
[Skip Navigation](https://developer.apple.com/documentation/testing/test/comments#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Test](https://developer.apple.com/documentation/testing/test)
- comments

Instance Property

# comments

The complete set of comments about this test from all of its traits.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
var comments: [Comment] { get }
```

Current page is comments

## Test Duration Type
[Skip Navigation](https://developer.apple.com/documentation/testing/timelimittrait/duration#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [TimeLimitTrait](https://developer.apple.com/documentation/testing/timelimittrait)
- TimeLimitTrait.Duration

Structure

# TimeLimitTrait.Duration

A type representing the duration of a time limit applied to a test.

iOS 16.0+iPadOS 16.0+Mac Catalyst 16.0+macOS 13.0+tvOS 16.0+visionOSwatchOS 9.0+Swift 6.0+Xcode 16.0+

```
struct Duration
```

## [Overview](https://developer.apple.com/documentation/testing/timelimittrait/duration\#overview)

Use this type to specify a test timeout with [`TimeLimitTrait`](https://developer.apple.com/documentation/testing/timelimittrait). `TimeLimitTrait` uses this type instead of Swift’s built-in `Duration` type because the testing library doesn’t support high-precision, arbitrarily short durations for test timeouts. The smallest unit of time you can specify in a `Duration` is minutes.

## [Topics](https://developer.apple.com/documentation/testing/timelimittrait/duration\#topics)

### [Type Methods](https://developer.apple.com/documentation/testing/timelimittrait/duration\#Type-Methods)

[`static func minutes(some BinaryInteger) -> TimeLimitTrait.Duration`](https://developer.apple.com/documentation/testing/timelimittrait/duration/minutes(_:))

Construct a time limit duration given a number of minutes.

## [Relationships](https://developer.apple.com/documentation/testing/timelimittrait/duration\#relationships)

### [Conforms To](https://developer.apple.com/documentation/testing/timelimittrait/duration\#conforms-to)

- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable)

Current page is TimeLimitTrait.Duration

## Test Tags Overview
[Skip Navigation](https://developer.apple.com/documentation/testing/test/tags#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Test](https://developer.apple.com/documentation/testing/test)
- tags

Instance Property

# tags

The complete, unique set of tags associated with this test.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
var tags: Set<Tag> { get }
```

## [Discussion](https://developer.apple.com/documentation/testing/test/tags\#discussion)

Tags are associated with tests using the [`tags(_:)`](https://developer.apple.com/documentation/testing/trait/tags(_:)) function.

Current page is tags

## Customizing Display Names
[Skip Navigation](https://developer.apple.com/documentation/testing/test/displayname#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Test](https://developer.apple.com/documentation/testing/test)
- displayName

Instance Property

# displayName

The customized display name of this instance, if specified.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
var displayName: String?
```

Current page is displayName

## Serialized Trait
[Skip Navigation](https://developer.apple.com/documentation/testing/trait/serialized#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Trait](https://developer.apple.com/documentation/testing/trait)
- serialized

Type Property

# serialized

A trait that serializes the test to which it is applied.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
static var serialized: ParallelizationTrait { get }
```

Available when `Self` is `ParallelizationTrait`.

## [Mentioned in](https://developer.apple.com/documentation/testing/trait/serialized\#mentions)

[Migrating a test from XCTest](https://developer.apple.com/documentation/testing/migratingfromxctest)

[Running tests serially or in parallel](https://developer.apple.com/documentation/testing/parallelization)

## [See Also](https://developer.apple.com/documentation/testing/trait/serialized\#see-also)

### [Related Documentation](https://developer.apple.com/documentation/testing/trait/serialized\#Related-Documentation)

[`struct ParallelizationTrait`](https://developer.apple.com/documentation/testing/parallelizationtrait)

A type that defines whether the testing library runs this test serially or in parallel.

### [Running tests serially or in parallel](https://developer.apple.com/documentation/testing/trait/serialized\#Running-tests-serially-or-in-parallel)

[Running tests serially or in parallel](https://developer.apple.com/documentation/testing/parallelization)

Control whether tests run serially or in parallel.

Current page is serialized

## Swift Test Source Location
[Skip Navigation](https://developer.apple.com/documentation/testing/test/sourcelocation#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Test](https://developer.apple.com/documentation/testing/test)
- sourceLocation

Instance Property

# sourceLocation

The source location of this test.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
var sourceLocation: SourceLocation
```

Current page is sourceLocation

## Test Case Overview
[Skip Navigation](https://developer.apple.com/documentation/testing/test/case#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Test](https://developer.apple.com/documentation/testing/test)
- Test.Case

Structure

# Test.Case

A single test case from a parameterized [`Test`](https://developer.apple.com/documentation/testing/test).

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
struct Case
```

## [Overview](https://developer.apple.com/documentation/testing/test/case\#overview)

A test case represents a test run with a particular combination of inputs. Tests that are _not_ parameterized map to a single instance of [`Test.Case`](https://developer.apple.com/documentation/testing/test/case).

## [Topics](https://developer.apple.com/documentation/testing/test/case\#topics)

### [Instance Properties](https://developer.apple.com/documentation/testing/test/case\#Instance-Properties)

[`var isParameterized: Bool`](https://developer.apple.com/documentation/testing/test/case/isparameterized)

Whether or not this test case is from a parameterized test.

### [Type Properties](https://developer.apple.com/documentation/testing/test/case\#Type-Properties)

[`static var current: Test.Case?`](https://developer.apple.com/documentation/testing/test/case/current)

The test case that is running on the current task, if any.

## [Relationships](https://developer.apple.com/documentation/testing/test/case\#relationships)

### [Conforms To](https://developer.apple.com/documentation/testing/test/case\#conforms-to)

- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable)

## [See Also](https://developer.apple.com/documentation/testing/test/case\#see-also)

### [Test parameterization](https://developer.apple.com/documentation/testing/test/case\#Test-parameterization)

[Implementing parameterized tests](https://developer.apple.com/documentation/testing/parameterizedtesting)

Specify different input parameters to generate multiple test cases from a test function.

[`macro Test<C>(String?, any TestTrait..., arguments: C)`](https://developer.apple.com/documentation/testing/test(_:_:arguments:)-8kn7a)

Declare a test parameterized over a collection of values.

[`macro Test<C1, C2>(String?, any TestTrait..., arguments: C1, C2)`](https://developer.apple.com/documentation/testing/test(_:_:arguments:_:))

Declare a test parameterized over two collections of values.

[`macro Test<C1, C2>(String?, any TestTrait..., arguments: Zip2Sequence<C1, C2>)`](https://developer.apple.com/documentation/testing/test(_:_:arguments:)-3rzok)

Declare a test parameterized over two zipped collections of values.

[`protocol CustomTestArgumentEncodable`](https://developer.apple.com/documentation/testing/customtestargumentencodable)

A protocol for customizing how arguments passed to parameterized tests are encoded, which is used to match against when running specific arguments.

Current page is Test.Case

## Tag List Overview
[Skip Navigation](https://developer.apple.com/documentation/testing/tag/list#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Tag](https://developer.apple.com/documentation/testing/tag)
- Tag.List

Structure

# Tag.List

A type representing one or more tags applied to a test.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
struct List
```

## [Overview](https://developer.apple.com/documentation/testing/tag/list\#overview)

To add this trait to a test, use the [`tags(_:)`](https://developer.apple.com/documentation/testing/trait/tags(_:)) function.

## [Topics](https://developer.apple.com/documentation/testing/tag/list\#topics)

### [Instance Properties](https://developer.apple.com/documentation/testing/tag/list\#Instance-Properties)

[`var tags: [Tag]`](https://developer.apple.com/documentation/testing/tag/list/tags)

The list of tags contained in this instance.

### [Default Implementations](https://developer.apple.com/documentation/testing/tag/list\#Default-Implementations)

[API Reference\\
CustomStringConvertible Implementations](https://developer.apple.com/documentation/testing/tag/list/customstringconvertible-implementations)

[API Reference\\
Equatable Implementations](https://developer.apple.com/documentation/testing/tag/list/equatable-implementations)

[API Reference\\
Hashable Implementations](https://developer.apple.com/documentation/testing/tag/list/hashable-implementations)

[API Reference\\
SuiteTrait Implementations](https://developer.apple.com/documentation/testing/tag/list/suitetrait-implementations)

[API Reference\\
Trait Implementations](https://developer.apple.com/documentation/testing/tag/list/trait-implementations)

## [Relationships](https://developer.apple.com/documentation/testing/tag/list\#relationships)

### [Conforms To](https://developer.apple.com/documentation/testing/tag/list\#conforms-to)

- [`Copyable`](https://developer.apple.com/documentation/Swift/Copyable)
- [`CustomStringConvertible`](https://developer.apple.com/documentation/Swift/CustomStringConvertible)
- [`Equatable`](https://developer.apple.com/documentation/Swift/Equatable)
- [`Hashable`](https://developer.apple.com/documentation/Swift/Hashable)
- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable)
- [`SuiteTrait`](https://developer.apple.com/documentation/testing/suitetrait)
- [`TestTrait`](https://developer.apple.com/documentation/testing/testtrait)
- [`Trait`](https://developer.apple.com/documentation/testing/trait)

## [See Also](https://developer.apple.com/documentation/testing/tag/list\#see-also)

### [Supporting types](https://developer.apple.com/documentation/testing/tag/list\#Supporting-types)

[`struct Bug`](https://developer.apple.com/documentation/testing/bug)

A type that represents a bug report tracked by a test.

[`struct Comment`](https://developer.apple.com/documentation/testing/comment)

A type that represents a comment related to a test.

[`struct ConditionTrait`](https://developer.apple.com/documentation/testing/conditiontrait)

A type that defines a condition which must be satisfied for the testing library to enable a test.

[`struct ParallelizationTrait`](https://developer.apple.com/documentation/testing/parallelizationtrait)

A type that defines whether the testing library runs this test serially or in parallel.

[`struct Tag`](https://developer.apple.com/documentation/testing/tag)

A type representing a tag that can be applied to a test.

[`struct TimeLimitTrait`](https://developer.apple.com/documentation/testing/timelimittrait)

A type that defines a time limit to apply to a test.

Current page is Tag.List

## Test Suite Indicator
[Skip Navigation](https://developer.apple.com/documentation/testing/test/issuite#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Test](https://developer.apple.com/documentation/testing/test)
- isSuite

Instance Property

# isSuite

Whether or not this instance is a test suite containing other tests.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
var isSuite: Bool { get }
```

## [Discussion](https://developer.apple.com/documentation/testing/test/issuite\#discussion)

Instances of [`Test`](https://developer.apple.com/documentation/testing/test) attached to types rather than functions are test suites. They do not contain any test logic of their own, but they may have traits added to them that also apply to their subtests.

A test suite can be declared using the [`Suite(_:_:)`](https://developer.apple.com/documentation/testing/suite(_:_:)) macro.

Current page is isSuite

## Swift moduleName Property
[Skip Navigation](https://developer.apple.com/documentation/testing/sourcelocation/modulename#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [SourceLocation](https://developer.apple.com/documentation/testing/sourcelocation)
- moduleName

Instance Property

# moduleName

The name of the module containing the source file.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
var moduleName: String { get }
```

## [Discussion](https://developer.apple.com/documentation/testing/sourcelocation/modulename\#discussion)

The name of the module is derived from this instance’s [`fileID`](https://developer.apple.com/documentation/testing/sourcelocation/fileid) property. It consists of the substring of the file ID up to the first forward-slash character ( `"/"`.) For example, if the value of this instance’s [`fileID`](https://developer.apple.com/documentation/testing/sourcelocation/fileid) property is `"FoodTruck/WheelTests.swift"`, the module name is `"FoodTruck"`.

The structure of file IDs is described in the documentation for the [`#fileID`](https://developer.apple.com/documentation/swift/fileID()) macro in the Swift standard library.

## [See Also](https://developer.apple.com/documentation/testing/sourcelocation/modulename\#see-also)

### [Related Documentation](https://developer.apple.com/documentation/testing/sourcelocation/modulename\#Related-Documentation)

[`var fileID: String`](https://developer.apple.com/documentation/testing/sourcelocation/fileid)

The file ID of the source file.

[`var fileName: String`](https://developer.apple.com/documentation/testing/sourcelocation/filename)

The name of the source file.

[#fileID](https://developer.apple.com/documentation/swift/fileID())

Current page is moduleName

## Swift Testing Comments
[Skip Navigation](https://developer.apple.com/documentation/testing/comment/comments#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Comment](https://developer.apple.com/documentation/testing/comment)
- comments

Instance Property

# comments

The user-provided comments for this trait.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
var comments: [Comment] { get }
```

## [Discussion](https://developer.apple.com/documentation/testing/comment/comments\#discussion)

The default value of this property is an empty array.

Current page is comments

## Associated Bugs in Testing
[Skip Navigation](https://developer.apple.com/documentation/testing/test/associatedbugs#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Test](https://developer.apple.com/documentation/testing/test)
- associatedBugs

Instance Property

# associatedBugs

The set of bugs associated with this test.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
var associatedBugs: [Bug] { get }
```

## [Discussion](https://developer.apple.com/documentation/testing/test/associatedbugs\#discussion)

For information on how to associate a bug with a test, see the documentation for [`Bug`](https://developer.apple.com/documentation/testing/bug).

Current page is associatedBugs

## Expectation Requirement
[Skip Navigation](https://developer.apple.com/documentation/testing/expectation/isrequired#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Expectation](https://developer.apple.com/documentation/testing/expectation)
- isRequired

Instance Property

# isRequired

Whether or not the expectation was required to pass.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
var isRequired: Bool
```

Current page is isRequired

## Testing Asynchronous Code
[Skip Navigation](https://developer.apple.com/documentation/testing/testing-asynchronous-code#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Expectations and confirmations](https://developer.apple.com/documentation/testing/expectations)
- Testing asynchronous code

Article

# Testing asynchronous code

Validate whether your code causes expected events to happen.

## [Overview](https://developer.apple.com/documentation/testing/testing-asynchronous-code\#Overview)

The testing library integrates with Swift concurrency, meaning that in many situations you can test asynchronous code using standard Swift features. Mark your test function as `async` and, in the function body, `await` any asynchronous interactions:

```
@Test func priceLookupYieldsExpectedValue() async {
  let mozarellaPrice = await unitPrice(for: .mozarella)
  #expect(mozarellaPrice == 3)
}

```

In more complex situations you can use [`Confirmation`](https://developer.apple.com/documentation/testing/confirmation) to discover whether an expected event happens.

### [Confirm that an event happens](https://developer.apple.com/documentation/testing/testing-asynchronous-code\#Confirm-that-an-event-happens)

Call [`confirmation(_:expectedCount:isolation:sourceLocation:_:)`](https://developer.apple.com/documentation/testing/confirmation(_:expectedcount:isolation:sourcelocation:_:)-5mqz2) in your asynchronous test function to create a `Confirmation` for the expected event. In the trailing closure parameter, call the code under test. Swift Testing passes a `Confirmation` as the parameter to the closure, which you call as a function in the event handler for the code under test when the event you’re testing for occurs:

```
@Test("OrderCalculator successfully calculates subtotal for no pizzas")
func subtotalForNoPizzas() async {
  let calculator = OrderCalculator()
  await confirmation() { confirmation in
    calculator.successHandler = { _ in confirmation() }
    _ = await calculator.subtotal(for: PizzaToppings(bases: []))
  }
}

```

If you expect the event to happen more than once, set the `expectedCount` parameter to the number of expected occurrences. The test passes if the number of occurrences during the test matches the expected count, and fails otherwise.

You can also pass a range to [`confirmation(_:expectedCount:isolation:sourceLocation:_:)`](https://developer.apple.com/documentation/testing/confirmation(_:expectedcount:isolation:sourcelocation:_:)-l3il) if the exact number of times the event occurs may change over time or is random:

```
@Test("Customers bought sandwiches")
func boughtSandwiches() async {
  await confirmation(expectedCount: 0 ..< 1000) { boughtSandwich in
    var foodTruck = FoodTruck()
    foodTruck.orderHandler = { order in
      if order.contains(.sandwich) {
        boughtSandwich()
      }
    }
    await FoodTruck.operate()
  }
}

```

In this example, there may be zero customers or up to (but not including) 1,000 customers who order sandwiches. Any [range expression](https://developer.apple.com/documentation/swift/rangeexpression) which includes an explicit lower bound can be used:

| Range Expression | Usage |
| --- | --- |
| `1...` | If an event must occur _at least_ once |
| `5...` | If an event must occur _at least_ five times |
| `1 ... 5` | If an event must occur at least once, but not more than five times |
| `0 ..< 100` | If an event may or may not occur, but _must not_ occur more than 99 times |

### [Confirm that an event doesn’t happen](https://developer.apple.com/documentation/testing/testing-asynchronous-code\#Confirm-that-an-event-doesnt-happen)

To validate that a particular event doesn’t occur during a test, create a `Confirmation` with an expected count of `0`:

```
@Test func orderCalculatorEncountersNoErrors() async {
  let calculator = OrderCalculator()
  await confirmation(expectedCount: 0) { confirmation in
    calculator.errorHandler = { _ in confirmation() }
    calculator.subtotal(for: PizzaToppings(bases: []))
  }
}

```

## [See Also](https://developer.apple.com/documentation/testing/testing-asynchronous-code\#see-also)

### [Confirming that asynchronous events occur](https://developer.apple.com/documentation/testing/testing-asynchronous-code\#Confirming-that-asynchronous-events-occur)

[`func confirmation<R>(Comment?, expectedCount: Int, isolation: isolated (any Actor)?, sourceLocation: SourceLocation, (Confirmation) async throws -> sending R) async rethrows -> R`](https://developer.apple.com/documentation/testing/confirmation(_:expectedcount:isolation:sourcelocation:_:)-5mqz2)

Confirm that some event occurs during the invocation of a function.

[`func confirmation<R>(Comment?, expectedCount: some RangeExpression<Int> & Sendable & Sequence<Int>, isolation: isolated (any Actor)?, sourceLocation: SourceLocation, (Confirmation) async throws -> sending R) async rethrows -> R`](https://developer.apple.com/documentation/testing/confirmation(_:expectedcount:isolation:sourcelocation:_:)-l3il)

Confirm that some event occurs during the invocation of a function.

[`struct Confirmation`](https://developer.apple.com/documentation/testing/confirmation)

A type that can be used to confirm that an event occurs zero or more times.

Current page is Testing asynchronous code

## Swift Testing Tags
[Skip Navigation](https://developer.apple.com/documentation/testing/tag/list/tags#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Tag](https://developer.apple.com/documentation/testing/tag)
- [Tag.List](https://developer.apple.com/documentation/testing/tag/list)
- tags

Instance Property

# tags

The list of tags contained in this instance.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
var tags: [Tag]
```

## [Discussion](https://developer.apple.com/documentation/testing/tag/list/tags\#discussion)

This preserves the list of the tags exactly as they were originally specified, in their original order, including duplicate entries. To access the complete, unique set of tags applied to a [`Test`](https://developer.apple.com/documentation/testing/test), see [`tags`](https://developer.apple.com/documentation/testing/test/tags).

Current page is tags

## Current Test Case
[Skip Navigation](https://developer.apple.com/documentation/testing/test/case/current#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Test](https://developer.apple.com/documentation/testing/test)
- [Test.Case](https://developer.apple.com/documentation/testing/test/case)
- current

Type Property

# current

The test case that is running on the current task, if any.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
static var current: Test.Case? { get }
```

## [Discussion](https://developer.apple.com/documentation/testing/test/case/current\#discussion)

If the current task is running a test, or is a subtask of another task that is running a test, the value of this property describes the test’s currently-running case. If no test is currently running, the value of this property is `nil`.

If the current task is detached from a task that started running a test, or if the current thread was created without using Swift concurrency (e.g. by using [`Thread.detachNewThread(_:)`](https://developer.apple.com/documentation/foundation/thread/2088563-detachnewthread) or [`DispatchQueue.async(execute:)`](https://developer.apple.com/documentation/dispatch/dispatchqueue/2016103-async)), the value of this property may be `nil`.

Current page is current

## Parallelization Trait
[Skip Navigation](https://developer.apple.com/documentation/testing/parallelizationtrait?changes=__2#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing?changes=__2)
- ParallelizationTrait

Structure

# ParallelizationTrait

A type that defines whether the testing library runs this test serially or in parallel.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
struct ParallelizationTrait
```

## [Overview](https://developer.apple.com/documentation/testing/parallelizationtrait?changes=__2\#overview)

When you add this trait to a parameterized test function, that test runs its cases serially instead of in parallel. This trait has no effect when you apply it to a non-parameterized test function.

When you add this trait to a test suite, that suite runs its contained test functions (including their cases, when parameterized) and sub-suites serially instead of in parallel. If the sub-suites have children, they also run serially.

This trait does not affect the execution of a test relative to its peers or to unrelated tests. This trait has no effect if you disable test parallelization globally (for example, by passing `--no-parallel` to the `swift test` command.)

To add this trait to a test, use [`serialized`](https://developer.apple.com/documentation/testing/trait/serialized?changes=__2).

## [Topics](https://developer.apple.com/documentation/testing/parallelizationtrait?changes=__2\#topics)

### [Instance Properties](https://developer.apple.com/documentation/testing/parallelizationtrait?changes=__2\#Instance-Properties)

[`var isRecursive: Bool`](https://developer.apple.com/documentation/testing/parallelizationtrait/isrecursive?changes=__2)

Whether this instance should be applied recursively to child test suites and test functions.

### [Type Aliases](https://developer.apple.com/documentation/testing/parallelizationtrait?changes=__2\#Type-Aliases)

[`typealias TestScopeProvider`](https://developer.apple.com/documentation/testing/parallelizationtrait/testscopeprovider?changes=__2)

The type of the test scope provider for this trait.

### [Default Implementations](https://developer.apple.com/documentation/testing/parallelizationtrait?changes=__2\#Default-Implementations)

[API Reference\\
Trait Implementations](https://developer.apple.com/documentation/testing/parallelizationtrait/trait-implementations?changes=__2)

## [Relationships](https://developer.apple.com/documentation/testing/parallelizationtrait?changes=__2\#relationships)

### [Conforms To](https://developer.apple.com/documentation/testing/parallelizationtrait?changes=__2\#conforms-to)

- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable?changes=__2)
- [`SuiteTrait`](https://developer.apple.com/documentation/testing/suitetrait?changes=__2)
- [`TestTrait`](https://developer.apple.com/documentation/testing/testtrait?changes=__2)
- [`Trait`](https://developer.apple.com/documentation/testing/trait?changes=__2)

## [See Also](https://developer.apple.com/documentation/testing/parallelizationtrait?changes=__2\#see-also)

### [Supporting types](https://developer.apple.com/documentation/testing/parallelizationtrait?changes=__2\#Supporting-types)

[`struct Bug`](https://developer.apple.com/documentation/testing/bug?changes=__2)

A type that represents a bug report tracked by a test.

[`struct Comment`](https://developer.apple.com/documentation/testing/comment?changes=__2)

A type that represents a comment related to a test.

[`struct ConditionTrait`](https://developer.apple.com/documentation/testing/conditiontrait?changes=__2)

A type that defines a condition which must be satisfied for the testing library to enable a test.

[`struct Tag`](https://developer.apple.com/documentation/testing/tag?changes=__2)

A type representing a tag that can be applied to a test.

[`struct List`](https://developer.apple.com/documentation/testing/tag/list?changes=__2)

A type representing one or more tags applied to a test.

[`struct TimeLimitTrait`](https://developer.apple.com/documentation/testing/timelimittrait?changes=__2)

A type that defines a time limit to apply to a test.

Current page is ParallelizationTrait

## Condition Trait Overview
[Skip Navigation](https://developer.apple.com/documentation/testing/conditiontrait?changes=_1#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing?changes=_1)
- ConditionTrait

Structure

# ConditionTrait

A type that defines a condition which must be satisfied for the testing library to enable a test.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
struct ConditionTrait
```

## [Mentioned in](https://developer.apple.com/documentation/testing/conditiontrait?changes=_1\#mentions)

[Migrating a test from XCTest](https://developer.apple.com/documentation/testing/migratingfromxctest?changes=_1)

## [Overview](https://developer.apple.com/documentation/testing/conditiontrait?changes=_1\#overview)

To add this trait to a test, use one of the following functions:

- [`enabled(if:_:sourceLocation:)`](https://developer.apple.com/documentation/testing/trait/enabled(if:_:sourcelocation:)?changes=_1)

- [`enabled(_:sourceLocation:_:)`](https://developer.apple.com/documentation/testing/trait/enabled(_:sourcelocation:_:)?changes=_1)

- [`disabled(_:sourceLocation:)`](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:)?changes=_1)

- [`disabled(if:_:sourceLocation:)`](https://developer.apple.com/documentation/testing/trait/disabled(if:_:sourcelocation:)?changes=_1)

- [`disabled(_:sourceLocation:_:)`](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:_:)?changes=_1)


## [Topics](https://developer.apple.com/documentation/testing/conditiontrait?changes=_1\#topics)

### [Instance Properties](https://developer.apple.com/documentation/testing/conditiontrait?changes=_1\#Instance-Properties)

[`var comments: [Comment]`](https://developer.apple.com/documentation/testing/conditiontrait/comments?changes=_1)

The user-provided comments for this trait.

[`var isRecursive: Bool`](https://developer.apple.com/documentation/testing/conditiontrait/isrecursive?changes=_1)

Whether this instance should be applied recursively to child test suites and test functions.

[`var sourceLocation: SourceLocation`](https://developer.apple.com/documentation/testing/conditiontrait/sourcelocation?changes=_1)

The source location where this trait is specified.

### [Instance Methods](https://developer.apple.com/documentation/testing/conditiontrait?changes=_1\#Instance-Methods)

[`func prepare(for: Test) async throws`](https://developer.apple.com/documentation/testing/conditiontrait/prepare(for:)?changes=_1)

Prepare to run the test that has this trait.

### [Type Aliases](https://developer.apple.com/documentation/testing/conditiontrait?changes=_1\#Type-Aliases)

[`typealias TestScopeProvider`](https://developer.apple.com/documentation/testing/conditiontrait/testscopeprovider?changes=_1)

The type of the test scope provider for this trait.

### [Default Implementations](https://developer.apple.com/documentation/testing/conditiontrait?changes=_1\#Default-Implementations)

[API Reference\\
Trait Implementations](https://developer.apple.com/documentation/testing/conditiontrait/trait-implementations?changes=_1)

## [Relationships](https://developer.apple.com/documentation/testing/conditiontrait?changes=_1\#relationships)

### [Conforms To](https://developer.apple.com/documentation/testing/conditiontrait?changes=_1\#conforms-to)

- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable?changes=_1)
- [`SuiteTrait`](https://developer.apple.com/documentation/testing/suitetrait?changes=_1)
- [`TestTrait`](https://developer.apple.com/documentation/testing/testtrait?changes=_1)
- [`Trait`](https://developer.apple.com/documentation/testing/trait?changes=_1)

## [See Also](https://developer.apple.com/documentation/testing/conditiontrait?changes=_1\#see-also)

### [Supporting types](https://developer.apple.com/documentation/testing/conditiontrait?changes=_1\#Supporting-types)

[`struct Bug`](https://developer.apple.com/documentation/testing/bug?changes=_1)

A type that represents a bug report tracked by a test.

[`struct Comment`](https://developer.apple.com/documentation/testing/comment?changes=_1)

A type that represents a comment related to a test.

[`struct ParallelizationTrait`](https://developer.apple.com/documentation/testing/parallelizationtrait?changes=_1)

A type that defines whether the testing library runs this test serially or in parallel.

[`struct Tag`](https://developer.apple.com/documentation/testing/tag?changes=_1)

A type representing a tag that can be applied to a test.

[`struct List`](https://developer.apple.com/documentation/testing/tag/list?changes=_1)

A type representing one or more tags applied to a test.

[`struct TimeLimitTrait`](https://developer.apple.com/documentation/testing/timelimittrait?changes=_1)

A type that defines a time limit to apply to a test.

Current page is ConditionTrait

## TestScopeProvider Overview
[Skip Navigation](https://developer.apple.com/documentation/testing/comment/testscopeprovider#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Comment](https://developer.apple.com/documentation/testing/comment)
- Comment.TestScopeProvider

Type Alias

# Comment.TestScopeProvider

The type of the test scope provider for this trait.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
typealias TestScopeProvider = Never
```

## [Discussion](https://developer.apple.com/documentation/testing/comment/testscopeprovider\#discussion)

The default type is `Never`, which can’t be instantiated. The `scopeProvider(for:testCase:)-cjmg` method for any trait with `Never` as its test scope provider type must return `nil`, meaning that the trait doesn’t provide a custom scope for tests it’s applied to.

Current page is Comment.TestScopeProvider

## Bug Identifier Overview
[Skip Navigation](https://developer.apple.com/documentation/testing/bug/id?changes=_6#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing?changes=_6)
- [Bug](https://developer.apple.com/documentation/testing/bug?changes=_6)
- id

Instance Property

# id

A unique identifier in this bug’s associated bug-tracking system, if available.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
var id: String?
```

## [Discussion](https://developer.apple.com/documentation/testing/bug/id?changes=_6\#discussion)

For more information on how the testing library interprets bug identifiers, see [Interpreting bug identifiers](https://developer.apple.com/documentation/testing/bugidentifiers?changes=_6).

Current page is id

## TestScopeProvider Overview
[Skip Navigation](https://developer.apple.com/documentation/testing/timelimittrait/testscopeprovider?language=objc#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing?language=objc)
- [TimeLimitTrait](https://developer.apple.com/documentation/testing/timelimittrait?language=objc)
- TimeLimitTrait.TestScopeProvider

Type Alias

# TimeLimitTrait.TestScopeProvider

The type of the test scope provider for this trait.

iOS 16.0+iPadOS 16.0+Mac Catalyst 16.0+macOS 13.0+tvOS 16.0+visionOSwatchOS 9.0+Swift 6.0+Xcode 16.0+

```
typealias TestScopeProvider = Never
```

## [Discussion](https://developer.apple.com/documentation/testing/timelimittrait/testscopeprovider?language=objc\#discussion)

The default type is `Never`, which can’t be instantiated. The `scopeProvider(for:testCase:)-cjmg` method for any trait with `Never` as its test scope provider type must return `nil`, meaning that the trait doesn’t provide a custom scope for tests it’s applied to.

Current page is TimeLimitTrait.TestScopeProvider

## Test Duration Limit
[Skip Navigation](https://developer.apple.com/documentation/testing/timelimittrait/timelimit?changes=_3#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing?changes=_3)
- [TimeLimitTrait](https://developer.apple.com/documentation/testing/timelimittrait?changes=_3)
- timeLimit

Instance Property

# timeLimit

The maximum amount of time a test may run for before timing out.

iOS 16.0+iPadOS 16.0+Mac Catalyst 16.0+macOS 13.0+tvOS 16.0+visionOSwatchOS 9.0+Swift 6.0+Xcode 16.0+

```
var timeLimit: Duration
```

Current page is timeLimit

## Swift Issue Kind
[Skip Navigation](https://developer.apple.com/documentation/testing/issue/kind-swift.property#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Issue](https://developer.apple.com/documentation/testing/issue)
- kind

Instance Property

# kind

The kind of issue this value represents.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
var kind: Issue.Kind
```

Current page is kind

## Time Limit Trait
[Skip Navigation](https://developer.apple.com/documentation/testing/trait/timelimit(_:)#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Trait](https://developer.apple.com/documentation/testing/trait)
- timeLimit(\_:)

Type Method

# timeLimit(\_:)

Construct a time limit trait that causes a test to time out if it runs for too long.

iOS 16.0+iPadOS 16.0+Mac Catalyst 16.0+macOS 13.0+tvOS 16.0+visionOSwatchOS 9.0+Swift 6.0+Xcode 16.0+

```
static func timeLimit(_ timeLimit: TimeLimitTrait.Duration) -> Self
```

Available when `Self` is `TimeLimitTrait`.

## [Parameters](https://developer.apple.com/documentation/testing/trait/timelimit(_:)\#parameters)

`timeLimit`

The maximum amount of time the test may run for.

## [Return Value](https://developer.apple.com/documentation/testing/trait/timelimit(_:)\#return-value)

An instance of [`TimeLimitTrait`](https://developer.apple.com/documentation/testing/timelimittrait).

## [Mentioned in](https://developer.apple.com/documentation/testing/trait/timelimit(_:)\#mentions)

[Limiting the running time of tests](https://developer.apple.com/documentation/testing/limitingexecutiontime)

## [Discussion](https://developer.apple.com/documentation/testing/trait/timelimit(_:)\#discussion)

Test timeouts do not support high-precision, arbitrarily short durations due to variability in testing environments. You express the duration in minutes, with a minimum duration of one minute.

When you associate this trait with a test, that test must complete within a time limit of, at most, `timeLimit`. If the test runs longer, the testing library records a [`Issue.Kind.timeLimitExceeded(timeLimitComponents:)`](https://developer.apple.com/documentation/testing/issue/kind-swift.enum/timelimitexceeded(timelimitcomponents:)) issue, which it treats as a test failure.

The testing library can use a shorter time limit than that specified by `timeLimit` if you configure it to enforce a maximum per-test limit. When you configure a maximum per-test limit, the time limit of the test this trait is applied to is the shorter of `timeLimit` and the maximum per-test limit. For information on configuring maximum per-test limits, consult the documentation for the tool you use to run your tests.

If a test is parameterized, this time limit is applied to each of its test cases individually. If a test has more than one time limit associated with it, the testing library uses the shortest time limit.

## [See Also](https://developer.apple.com/documentation/testing/trait/timelimit(_:)\#see-also)

### [Customizing runtime behaviors](https://developer.apple.com/documentation/testing/trait/timelimit(_:)\#Customizing-runtime-behaviors)

[Enabling and disabling tests](https://developer.apple.com/documentation/testing/enablinganddisabling)

Conditionally enable or disable individual tests before they run.

[Limiting the running time of tests](https://developer.apple.com/documentation/testing/limitingexecutiontime)

Set limits on how long a test can run for until it fails.

[`static func enabled(if: @autoclosure () throws -> Bool, Comment?, sourceLocation: SourceLocation) -> Self`](https://developer.apple.com/documentation/testing/trait/enabled(if:_:sourcelocation:))

Constructs a condition trait that disables a test if it returns `false`.

[`static func enabled(Comment?, sourceLocation: SourceLocation, () async throws -> Bool) -> Self`](https://developer.apple.com/documentation/testing/trait/enabled(_:sourcelocation:_:))

Constructs a condition trait that disables a test if it returns `false`.

[`static func disabled(Comment?, sourceLocation: SourceLocation) -> Self`](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:))

Constructs a condition trait that disables a test unconditionally.

[`static func disabled(if: @autoclosure () throws -> Bool, Comment?, sourceLocation: SourceLocation) -> Self`](https://developer.apple.com/documentation/testing/trait/disabled(if:_:sourcelocation:))

Constructs a condition trait that disables a test if its value is true.

[`static func disabled(Comment?, sourceLocation: SourceLocation, () async throws -> Bool) -> Self`](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:_:))

Constructs a condition trait that disables a test if its value is true.

Current page is timeLimit(\_:)

## Swift Testing Comment
[Skip Navigation](https://developer.apple.com/documentation/testing/comment/rawvalue-swift.property#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Comment](https://developer.apple.com/documentation/testing/comment)
- rawValue

Instance Property

# rawValue

The single comment string that this comment contains.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
var rawValue: String
```

## [Discussion](https://developer.apple.com/documentation/testing/comment/rawvalue-swift.property\#discussion)

To get the complete set of comments applied to a test, see [`comments`](https://developer.apple.com/documentation/testing/test/comments).

Current page is rawValue

## isRecursive Property Overview
[Skip Navigation](https://developer.apple.com/documentation/testing/timelimittrait/isrecursive?language=objc#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing?language=objc)
- [TimeLimitTrait](https://developer.apple.com/documentation/testing/timelimittrait?language=objc)
- isRecursive

Instance Property

# isRecursive

Whether this instance should be applied recursively to child test suites and test functions.

iOS 16.0+iPadOS 16.0+Mac Catalyst 16.0+macOS 13.0+tvOS 16.0+visionOSwatchOS 9.0+Swift 6.0+Xcode 16.0+

```
var isRecursive: Bool { get }
```

## [Discussion](https://developer.apple.com/documentation/testing/timelimittrait/isrecursive?language=objc\#discussion)

If the value is `true`, then the testing library applies this trait recursively to child test suites and test functions. Otherwise, it only applies the trait to the test suite to which you added the trait.

By default, traits are not recursively applied to children.

Current page is isRecursive

## Test Preparation Method
[Skip Navigation](https://developer.apple.com/documentation/testing/conditiontrait/prepare(for:)#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [ConditionTrait](https://developer.apple.com/documentation/testing/conditiontrait)
- prepare(for:)

Instance Method

# prepare(for:)

Prepare to run the test that has this trait.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
func prepare(for test: Test) async throws
```

## [Parameters](https://developer.apple.com/documentation/testing/conditiontrait/prepare(for:)\#parameters)

`test`

The test that has this trait.

## [Discussion](https://developer.apple.com/documentation/testing/conditiontrait/prepare(for:)\#discussion)

The testing library calls this method after it discovers all tests and their traits, and before it begins to run any tests. Use this method to prepare necessary internal state, or to determine whether the test should run.

The default implementation of this method does nothing.

Current page is prepare(for:)

## Test Preparation Method
[Skip Navigation](https://developer.apple.com/documentation/testing/trait/prepare(for:)#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Trait](https://developer.apple.com/documentation/testing/trait)
- prepare(for:)

Instance Method

# prepare(for:)

Prepare to run the test that has this trait.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
func prepare(for test: Test) async throws
```

**Required** Default implementation provided.

## [Parameters](https://developer.apple.com/documentation/testing/trait/prepare(for:)\#parameters)

`test`

The test that has this trait.

## [Discussion](https://developer.apple.com/documentation/testing/trait/prepare(for:)\#discussion)

The testing library calls this method after it discovers all tests and their traits, and before it begins to run any tests. Use this method to prepare necessary internal state, or to determine whether the test should run.

The default implementation of this method does nothing.

## [Default Implementations](https://developer.apple.com/documentation/testing/trait/prepare(for:)\#default-implementations)

### [Trait Implementations](https://developer.apple.com/documentation/testing/trait/prepare(for:)\#Trait-Implementations)

[`func prepare(for: Test) async throws`](https://developer.apple.com/documentation/testing/trait/prepare(for:)-4pe01)

Prepare to run the test that has this trait.

## [See Also](https://developer.apple.com/documentation/testing/trait/prepare(for:)\#see-also)

### [Running code before and after a test or suite](https://developer.apple.com/documentation/testing/trait/prepare(for:)\#Running-code-before-and-after-a-test-or-suite)

[`protocol TestScoping`](https://developer.apple.com/documentation/testing/testscoping)

A protocol that tells the test runner to run custom code before or after it runs a test suite or test function.

[`func scopeProvider(for: Test, testCase: Test.Case?) -> Self.TestScopeProvider?`](https://developer.apple.com/documentation/testing/trait/scopeprovider(for:testcase:))

Get this trait’s scope provider for the specified test and optional test case.

**Required** Default implementations provided.

[`associatedtype TestScopeProvider : TestScoping = Never`](https://developer.apple.com/documentation/testing/trait/testscopeprovider)

The type of the test scope provider for this trait.

**Required**

Current page is prepare(for:)

## Swift Testing Tags
[Skip Navigation](https://developer.apple.com/documentation/testing/trait/tags(_:)#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Trait](https://developer.apple.com/documentation/testing/trait)
- tags(\_:)

Type Method

# tags(\_:)

Construct a list of tags to apply to a test.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
static func tags(_ tags: Tag...) -> Self
```

Available when `Self` is `Tag.List`.

## [Parameters](https://developer.apple.com/documentation/testing/trait/tags(_:)\#parameters)

`tags`

The list of tags to apply to the test.

## [Return Value](https://developer.apple.com/documentation/testing/trait/tags(_:)\#return-value)

An instance of [`Tag.List`](https://developer.apple.com/documentation/testing/tag/list) containing the specified tags.

## [Mentioned in](https://developer.apple.com/documentation/testing/trait/tags(_:)\#mentions)

[Organizing test functions with suite types](https://developer.apple.com/documentation/testing/organizingtests)

[Defining test functions](https://developer.apple.com/documentation/testing/definingtests)

[Adding tags to tests](https://developer.apple.com/documentation/testing/addingtags)

## [See Also](https://developer.apple.com/documentation/testing/trait/tags(_:)\#see-also)

### [Categorizing tests and adding information](https://developer.apple.com/documentation/testing/trait/tags(_:)\#Categorizing-tests-and-adding-information)

[`var comments: [Comment]`](https://developer.apple.com/documentation/testing/trait/comments)

The user-provided comments for this trait.

**Required** Default implementation provided.

Current page is tags(\_:)

## Swift Testing ID
[Skip Navigation](https://developer.apple.com/documentation/testing/test/id-swift.property#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Test](https://developer.apple.com/documentation/testing/test)
- id

Instance Property

# id

The stable identity of the entity associated with this instance.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
var id: Test.ID { get }
```

Current page is id

## Swift Test Description
[Skip Navigation](https://developer.apple.com/documentation/testing/customteststringconvertible/testdescription-3ar66?changes=_1#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing?changes=_1)
- [CustomTestStringConvertible](https://developer.apple.com/documentation/testing/customteststringconvertible?changes=_1)
- testDescription

Instance Property

# testDescription

A description of this instance to use when presenting it in a test’s output.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
var testDescription: String { get }
```

Available when `Self` conforms to `StringProtocol`.

## [Discussion](https://developer.apple.com/documentation/testing/customteststringconvertible/testdescription-3ar66?changes=_1\#discussion)

Do not use this property directly. To get the test description of a value, use `Swift/String/init(describingForTest:)`.

Current page is testDescription

## Bug Tracking Method
[Skip Navigation](https://developer.apple.com/documentation/testing/trait/bug(_:_:)#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Trait](https://developer.apple.com/documentation/testing/trait)
- bug(\_:\_:)

Type Method

# bug(\_:\_:)

Constructs a bug to track with a test.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
static func bug(
    _ url: String,
    _ title: Comment? = nil
) -> Self
```

Available when `Self` is `Bug`.

## [Parameters](https://developer.apple.com/documentation/testing/trait/bug(_:_:)\#parameters)

`url`

A URL that refers to this bug in the associated bug-tracking system.

`title`

Optionally, the human-readable title of the bug.

## [Return Value](https://developer.apple.com/documentation/testing/trait/bug(_:_:)\#return-value)

An instance of [`Bug`](https://developer.apple.com/documentation/testing/bug) that represents the specified bug.

## [Mentioned in](https://developer.apple.com/documentation/testing/trait/bug(_:_:)\#mentions)

[Associating bugs with tests](https://developer.apple.com/documentation/testing/associatingbugs)

[Enabling and disabling tests](https://developer.apple.com/documentation/testing/enablinganddisabling)

[Interpreting bug identifiers](https://developer.apple.com/documentation/testing/bugidentifiers)

## [See Also](https://developer.apple.com/documentation/testing/trait/bug(_:_:)\#see-also)

### [Annotating tests](https://developer.apple.com/documentation/testing/trait/bug(_:_:)\#Annotating-tests)

[Adding tags to tests](https://developer.apple.com/documentation/testing/addingtags)

Use tags to provide semantic information for organization, filtering, and customizing appearances.

[Adding comments to tests](https://developer.apple.com/documentation/testing/addingcomments)

Add comments to provide useful information about tests.

[Associating bugs with tests](https://developer.apple.com/documentation/testing/associatingbugs)

Associate bugs uncovered or verified by tests.

[Interpreting bug identifiers](https://developer.apple.com/documentation/testing/bugidentifiers)

Examine how the testing library interprets bug identifiers provided by developers.

[`macro Tag()`](https://developer.apple.com/documentation/testing/tag())

Declare a tag that can be applied to a test function or test suite.

[`static func bug(String?, id: String, Comment?) -> Self`](https://developer.apple.com/documentation/testing/trait/bug(_:id:_:)-10yf5)

Constructs a bug to track with a test.

[`static func bug(String?, id: some Numeric, Comment?) -> Self`](https://developer.apple.com/documentation/testing/trait/bug(_:id:_:)-3vtpl)

Constructs a bug to track with a test.

Current page is bug(\_:\_:)

## Record Test Issues
[Skip Navigation](https://developer.apple.com/documentation/testing/issue/record(_:sourcelocation:)#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Issue](https://developer.apple.com/documentation/testing/issue)
- record(\_:sourceLocation:)

Type Method

# record(\_:sourceLocation:)

Record an issue when a running test fails unexpectedly.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
@discardableResult
static func record(
    _ comment: Comment? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
) -> Issue
```

## [Parameters](https://developer.apple.com/documentation/testing/issue/record(_:sourcelocation:)\#parameters)

`comment`

A comment describing the expectation.

`sourceLocation`

The source location to which the issue should be attributed.

## [Return Value](https://developer.apple.com/documentation/testing/issue/record(_:sourcelocation:)\#return-value)

The issue that was recorded.

## [Mentioned in](https://developer.apple.com/documentation/testing/issue/record(_:sourcelocation:)\#mentions)

[Migrating a test from XCTest](https://developer.apple.com/documentation/testing/migratingfromxctest)

## [Discussion](https://developer.apple.com/documentation/testing/issue/record(_:sourcelocation:)\#discussion)

Use this function if, while running a test, an issue occurs that cannot be represented as an expectation (using the [`expect(_:_:sourceLocation:)`](https://developer.apple.com/documentation/testing/expect(_:_:sourcelocation:)) or [`require(_:_:sourceLocation:)`](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-5l63q) macros.)

Current page is record(\_:sourceLocation:)

## Scope Provider Method
[Skip Navigation](https://developer.apple.com/documentation/testing/trait/scopeprovider(for:testcase:)#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Trait](https://developer.apple.com/documentation/testing/trait)
- scopeProvider(for:testCase:)

Instance Method

# scopeProvider(for:testCase:)

Get this trait’s scope provider for the specified test and optional test case.

Swift 6.1+Xcode 16.3+

```
func scopeProvider(
    for test: Test,
    testCase: Test.Case?
) -> Self.TestScopeProvider?
```

**Required** Default implementations provided.

## [Parameters](https://developer.apple.com/documentation/testing/trait/scopeprovider(for:testcase:)\#parameters)

`test`

The test for which a scope provider is being requested.

`testCase`

The test case for which a scope provider is being requested, if any. When `test` represents a suite, the value of this argument is `nil`.

## [Return Value](https://developer.apple.com/documentation/testing/trait/scopeprovider(for:testcase:)\#return-value)

A value conforming to [`TestScopeProvider`](https://developer.apple.com/documentation/testing/trait/testscopeprovider) which you use to provide custom scoping for `test` or `testCase`. Returns `nil` if the trait doesn’t provide any custom scope for the test or test case.

## [Discussion](https://developer.apple.com/documentation/testing/trait/scopeprovider(for:testcase:)\#discussion)

If this trait’s type conforms to [`TestScoping`](https://developer.apple.com/documentation/testing/testscoping), the default value returned by this method depends on the values of `test` and `testCase`:

- If `test` represents a suite, this trait must conform to [`SuiteTrait`](https://developer.apple.com/documentation/testing/suitetrait). If the value of this suite trait’s [`isRecursive`](https://developer.apple.com/documentation/testing/suitetrait/isrecursive) property is `true`, then this method returns `nil`, and the suite trait provides its custom scope once for each test function the test suite contains. If the value of [`isRecursive`](https://developer.apple.com/documentation/testing/suitetrait/isrecursive) is `false`, this method returns `self`, and the suite trait provides its custom scope once for the entire test suite.

- If `test` represents a test function, this trait also conforms to [`TestTrait`](https://developer.apple.com/documentation/testing/testtrait). If `testCase` is `nil`, this method returns `nil`; otherwise, it returns `self`. This means that by default, a trait which is applied to or inherited by a test function provides its custom scope once for each of that function’s cases.


A trait may override this method to further customize the default behaviors above. For example, if a trait needs to provide custom test scope both once per-suite and once per-test function in that suite, it implements the method to return a non- `nil` scope provider under those conditions.

A trait may also implement this method and return `nil` if it determines that it does not need to provide a custom scope for a particular test at runtime, even if the test has the trait applied. This can improve performance and make diagnostics clearer by avoiding an unnecessary call to [`provideScope(for:testCase:performing:)`](https://developer.apple.com/documentation/testing/testscoping/providescope(for:testcase:performing:)).

If this trait’s type does not conform to [`TestScoping`](https://developer.apple.com/documentation/testing/testscoping) and its associated [`TestScopeProvider`](https://developer.apple.com/documentation/testing/trait/testscopeprovider) type is the default `Never`, then this method returns `nil` by default. This means that instances of this trait don’t provide a custom scope for tests to which they’re applied.

## [Default Implementations](https://developer.apple.com/documentation/testing/trait/scopeprovider(for:testcase:)\#default-implementations)

### [Trait Implementations](https://developer.apple.com/documentation/testing/trait/scopeprovider(for:testcase:)\#Trait-Implementations)

[`func scopeProvider(for: Test, testCase: Test.Case?) -> Never?`](https://developer.apple.com/documentation/testing/trait/scopeprovider(for:testcase:)-9fxg4)

Get this trait’s scope provider for the specified test or test case.

[`func scopeProvider(for: Test, testCase: Test.Case?) -> Self?`](https://developer.apple.com/documentation/testing/trait/scopeprovider(for:testcase:)-1z8kh)

Get this trait’s scope provider for the specified test or test case.

[`func scopeProvider(for: Test, testCase: Test.Case?) -> Self?`](https://developer.apple.com/documentation/testing/trait/scopeprovider(for:testcase:)-inmj)

Get this trait’s scope provider for the specified test and optional test case.

## [See Also](https://developer.apple.com/documentation/testing/trait/scopeprovider(for:testcase:)\#see-also)

### [Running code before and after a test or suite](https://developer.apple.com/documentation/testing/trait/scopeprovider(for:testcase:)\#Running-code-before-and-after-a-test-or-suite)

[`protocol TestScoping`](https://developer.apple.com/documentation/testing/testscoping)

A protocol that tells the test runner to run custom code before or after it runs a test suite or test function.

[`associatedtype TestScopeProvider : TestScoping = Never`](https://developer.apple.com/documentation/testing/trait/testscopeprovider)

The type of the test scope provider for this trait.

**Required**

[`func prepare(for: Test) async throws`](https://developer.apple.com/documentation/testing/trait/prepare(for:))

Prepare to run the test that has this trait.

**Required** Default implementation provided.

Current page is scopeProvider(for:testCase:)

## Swift Testing Expectation
[Skip Navigation](https://developer.apple.com/documentation/testing/expect(_:_:sourcelocation:)#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- expect(\_:\_:sourceLocation:)

Macro

# expect(\_:\_:sourceLocation:)

Check that an expectation has passed after a condition has been evaluated.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
@freestanding(expression)
macro expect(
    _ condition: Bool,
    _ comment: @autoclosure () -> Comment? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
)
```

## [Parameters](https://developer.apple.com/documentation/testing/expect(_:_:sourcelocation:)\#parameters)

`condition`

The condition to be evaluated.

`comment`

A comment describing the expectation.

`sourceLocation`

The source location to which recorded expectations and issues should be attributed.

## [Mentioned in](https://developer.apple.com/documentation/testing/expect(_:_:sourcelocation:)\#mentions)

[Testing for errors in Swift code](https://developer.apple.com/documentation/testing/testing-for-errors-in-swift-code)

[Migrating a test from XCTest](https://developer.apple.com/documentation/testing/migratingfromxctest)

## [Overview](https://developer.apple.com/documentation/testing/expect(_:_:sourcelocation:)\#overview)

If `condition` evaluates to `false`, an [`Issue`](https://developer.apple.com/documentation/testing/issue) is recorded for the test that is running in the current task.

## [See Also](https://developer.apple.com/documentation/testing/expect(_:_:sourcelocation:)\#see-also)

### [Checking expectations](https://developer.apple.com/documentation/testing/expect(_:_:sourcelocation:)\#Checking-expectations)

[`macro require(Bool, @autoclosure () -> Comment?, sourceLocation: SourceLocation)`](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-5l63q)

Check that an expectation has passed after a condition has been evaluated and throw an error if it failed.

[`macro require<T>(T?, @autoclosure () -> Comment?, sourceLocation: SourceLocation) -> T`](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-6w9oo)

Unwrap an optional value or, if it is `nil`, fail and throw an error.

Current page is expect(\_:\_:sourceLocation:)

## System Issue Kind
[Skip Navigation](https://developer.apple.com/documentation/testing/issue/kind-swift.enum/system#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Issue](https://developer.apple.com/documentation/testing/issue)
- [Issue.Kind](https://developer.apple.com/documentation/testing/issue/kind-swift.enum)
- Issue.Kind.system

Case

# Issue.Kind.system

An issue due to a failure in the underlying system, not due to a failure within the tests being run.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
case system
```

Current page is Issue.Kind.system

## Disable Test Condition
[Skip Navigation](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:)#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Trait](https://developer.apple.com/documentation/testing/trait)
- disabled(\_:sourceLocation:)

Type Method

# disabled(\_:sourceLocation:)

Constructs a condition trait that disables a test unconditionally.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
static func disabled(
    _ comment: Comment? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
) -> Self
```

Available when `Self` is `ConditionTrait`.

## [Parameters](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:)\#parameters)

`comment`

An optional comment that describes this trait.

`sourceLocation`

The source location of the trait.

## [Return Value](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:)\#return-value)

An instance of [`ConditionTrait`](https://developer.apple.com/documentation/testing/conditiontrait) that always disables the test to which it is added.

## [Mentioned in](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:)\#mentions)

[Enabling and disabling tests](https://developer.apple.com/documentation/testing/enablinganddisabling)

[Organizing test functions with suite types](https://developer.apple.com/documentation/testing/organizingtests)

## [See Also](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:)\#see-also)

### [Customizing runtime behaviors](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:)\#Customizing-runtime-behaviors)

[Enabling and disabling tests](https://developer.apple.com/documentation/testing/enablinganddisabling)

Conditionally enable or disable individual tests before they run.

[Limiting the running time of tests](https://developer.apple.com/documentation/testing/limitingexecutiontime)

Set limits on how long a test can run for until it fails.

[`static func enabled(if: @autoclosure () throws -> Bool, Comment?, sourceLocation: SourceLocation) -> Self`](https://developer.apple.com/documentation/testing/trait/enabled(if:_:sourcelocation:))

Constructs a condition trait that disables a test if it returns `false`.

[`static func enabled(Comment?, sourceLocation: SourceLocation, () async throws -> Bool) -> Self`](https://developer.apple.com/documentation/testing/trait/enabled(_:sourcelocation:_:))

Constructs a condition trait that disables a test if it returns `false`.

[`static func disabled(if: @autoclosure () throws -> Bool, Comment?, sourceLocation: SourceLocation) -> Self`](https://developer.apple.com/documentation/testing/trait/disabled(if:_:sourcelocation:))

Constructs a condition trait that disables a test if its value is true.

[`static func disabled(Comment?, sourceLocation: SourceLocation, () async throws -> Bool) -> Self`](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:_:))

Constructs a condition trait that disables a test if its value is true.

[`static func timeLimit(TimeLimitTrait.Duration) -> Self`](https://developer.apple.com/documentation/testing/trait/timelimit(_:))

Construct a time limit trait that causes a test to time out if it runs for too long.

Current page is disabled(\_:sourceLocation:)

## Hashing Method
[Skip Navigation](https://developer.apple.com/documentation/testing/tag/list/hash(into:)#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Tag](https://developer.apple.com/documentation/testing/tag)
- [Tag.List](https://developer.apple.com/documentation/testing/tag/list)
- hash(into:)

Instance Method

# hash(into:)

Hashes the essential components of this value by feeding them into the given hasher.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
func hash(into hasher: inout Hasher)
```

## [Parameters](https://developer.apple.com/documentation/testing/tag/list/hash(into:)\#parameters)

`hasher`

The hasher to use when combining the components of this instance.

## [Discussion](https://developer.apple.com/documentation/testing/tag/list/hash(into:)\#discussion)

Implement this method to conform to the `Hashable` protocol. The components used for hashing must be the same as the components compared in your type’s `==` operator implementation. Call `hasher.combine(_:)` with each of these components.

Current page is hash(into:)

## Tag Comparison Operator
[Skip Navigation](https://developer.apple.com/documentation/testing/tag/_(_:_:)#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Tag](https://developer.apple.com/documentation/testing/tag)
- <(\_:\_:)

Operator

# <(\_:\_:)

Returns a Boolean value indicating whether the value of the first argument is less than that of the second argument.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
static func < (lhs: Tag, rhs: Tag) -> Bool
```

## [Parameters](https://developer.apple.com/documentation/testing/tag/_(_:_:)\#parameters)

`lhs`

A value to compare.

`rhs`

Another value to compare.

## [Discussion](https://developer.apple.com/documentation/testing/tag/_(_:_:)\#discussion)

This function is the only requirement of the `Comparable` protocol. The remainder of the relational operator functions are implemented by the standard library for any type that conforms to `Comparable`.

Current page is <(\_:\_:)

## Test Execution Control
[Skip Navigation](https://developer.apple.com/documentation/testing/parallelization?changes=_3#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing?changes=_3)
- [Traits](https://developer.apple.com/documentation/testing/traits?changes=_3)
- Running tests serially or in parallel

Article

# Running tests serially or in parallel

Control whether tests run serially or in parallel.

## [Overview](https://developer.apple.com/documentation/testing/parallelization?changes=_3\#Overview)

By default, tests run in parallel with respect to each other. Parallelization is accomplished by the testing library using task groups, and tests generally all run in the same process. The number of tests that run concurrently is controlled by the Swift runtime.

## [Disabling parallelization](https://developer.apple.com/documentation/testing/parallelization?changes=_3\#Disabling-parallelization)

Parallelization can be disabled on a per-function or per-suite basis using the [`serialized`](https://developer.apple.com/documentation/testing/trait/serialized?changes=_3) trait:

```
@Test(.serialized, arguments: Food.allCases) func prepare(food: Food) {
  // This function will be invoked serially, once per food, because it has the
  // .serialized trait.
}

@Suite(.serialized) struct FoodTruckTests {
  @Test(arguments: Condiment.allCases) func refill(condiment: Condiment) {
    // This function will be invoked serially, once per condiment, because the
    // containing suite has the .serialized trait.
  }

  @Test func startEngine() async throws {
    // This function will not run while refill(condiment:) is running. One test
    // must end before the other will start.
  }
}

```

When added to a parameterized test function, this trait causes that test to run its cases serially instead of in parallel. When applied to a non-parameterized test function, this trait has no effect. When applied to a test suite, this trait causes that suite to run its contained test functions and sub-suites serially instead of in parallel.

This trait is recursively applied: if it is applied to a suite, any parameterized tests or test suites contained in that suite are also serialized (as are any tests contained in those suites, and so on.)

This trait doesn’t affect the execution of a test relative to its peers or to unrelated tests. This trait has no effect if test parallelization is globally disabled (by, for example, passing `--no-parallel` to the `swift test` command.)

## [See Also](https://developer.apple.com/documentation/testing/parallelization?changes=_3\#see-also)

### [Running tests serially or in parallel](https://developer.apple.com/documentation/testing/parallelization?changes=_3\#Running-tests-serially-or-in-parallel)

[`static var serialized: ParallelizationTrait`](https://developer.apple.com/documentation/testing/trait/serialized?changes=_3)

A trait that serializes the test to which it is applied.

Current page is Running tests serially or in parallel

## Scope Provider Method
[Skip Navigation](https://developer.apple.com/documentation/testing/conditiontrait/scopeprovider(for:testcase:)#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [ConditionTrait](https://developer.apple.com/documentation/testing/conditiontrait)
- scopeProvider(for:testCase:)

Instance Method

# scopeProvider(for:testCase:)

Get this trait’s scope provider for the specified test or test case.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
func scopeProvider(
    for test: Test,
    testCase: Test.Case?
) -> Never?
```

Available when `TestScopeProvider` is `Never`.

## [Parameters](https://developer.apple.com/documentation/testing/conditiontrait/scopeprovider(for:testcase:)\#parameters)

`test`

The test for which the testing library requests a scope provider.

`testCase`

The test case for which the testing library requests a scope provider, if any. When `test` represents a suite, the value of this argument is `nil`.

## [Discussion](https://developer.apple.com/documentation/testing/conditiontrait/scopeprovider(for:testcase:)\#discussion)

The testing library uses this implementation of [`scopeProvider(for:testCase:)`](https://developer.apple.com/documentation/testing/trait/scopeprovider(for:testcase:)) when the trait type’s associated [`TestScopeProvider`](https://developer.apple.com/documentation/testing/trait/testscopeprovider) type is `Never`.

Current page is scopeProvider(for:testCase:)

## Swift Test Issues
[Skip Navigation](https://developer.apple.com/documentation/testing/issue?changes=_8#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing?changes=_8)
- Issue

Structure

# Issue

A type describing a failure or warning which occurred during a test.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
struct Issue
```

## [Mentioned in](https://developer.apple.com/documentation/testing/issue?changes=_8\#mentions)

[Associating bugs with tests](https://developer.apple.com/documentation/testing/associatingbugs?changes=_8)

[Interpreting bug identifiers](https://developer.apple.com/documentation/testing/bugidentifiers?changes=_8)

## [Topics](https://developer.apple.com/documentation/testing/issue?changes=_8\#topics)

### [Instance Properties](https://developer.apple.com/documentation/testing/issue?changes=_8\#Instance-Properties)

[`var comments: [Comment]`](https://developer.apple.com/documentation/testing/issue/comments?changes=_8)

Any comments provided by the developer and associated with this issue.

[`var error: (any Error)?`](https://developer.apple.com/documentation/testing/issue/error?changes=_8)

The error which was associated with this issue, if any.

[`var kind: Issue.Kind`](https://developer.apple.com/documentation/testing/issue/kind-swift.property?changes=_8)

The kind of issue this value represents.

[`var sourceLocation: SourceLocation?`](https://developer.apple.com/documentation/testing/issue/sourcelocation?changes=_8)

The location in source where this issue occurred, if available.

### [Type Methods](https://developer.apple.com/documentation/testing/issue?changes=_8\#Type-Methods)

[`static func record(any Error, Comment?, sourceLocation: SourceLocation) -> Issue`](https://developer.apple.com/documentation/testing/issue/record(_:_:sourcelocation:)?changes=_8)

Record a new issue when a running test unexpectedly catches an error.

[`static func record(Comment?, sourceLocation: SourceLocation) -> Issue`](https://developer.apple.com/documentation/testing/issue/record(_:sourcelocation:)?changes=_8)

Record an issue when a running test fails unexpectedly.

### [Enumerations](https://developer.apple.com/documentation/testing/issue?changes=_8\#Enumerations)

[`enum Kind`](https://developer.apple.com/documentation/testing/issue/kind-swift.enum?changes=_8)

Kinds of issues which may be recorded.

### [Default Implementations](https://developer.apple.com/documentation/testing/issue?changes=_8\#Default-Implementations)

[API Reference\\
CustomDebugStringConvertible Implementations](https://developer.apple.com/documentation/testing/issue/customdebugstringconvertible-implementations?changes=_8)

[API Reference\\
CustomStringConvertible Implementations](https://developer.apple.com/documentation/testing/issue/customstringconvertible-implementations?changes=_8)

## [Relationships](https://developer.apple.com/documentation/testing/issue?changes=_8\#relationships)

### [Conforms To](https://developer.apple.com/documentation/testing/issue?changes=_8\#conforms-to)

- [`Copyable`](https://developer.apple.com/documentation/Swift/Copyable?changes=_8)
- [`CustomDebugStringConvertible`](https://developer.apple.com/documentation/Swift/CustomDebugStringConvertible?changes=_8)
- [`CustomStringConvertible`](https://developer.apple.com/documentation/Swift/CustomStringConvertible?changes=_8)
- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable?changes=_8)

Current page is Issue

## Confirmation Testing
[Skip Navigation](https://developer.apple.com/documentation/testing/confirmation?language=objc#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing?language=objc)
- Confirmation

Structure

# Confirmation

A type that can be used to confirm that an event occurs zero or more times.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
struct Confirmation
```

## [Mentioned in](https://developer.apple.com/documentation/testing/confirmation?language=objc\#mentions)

[Testing asynchronous code](https://developer.apple.com/documentation/testing/testing-asynchronous-code?language=objc)

[Migrating a test from XCTest](https://developer.apple.com/documentation/testing/migratingfromxctest?language=objc)

## [Topics](https://developer.apple.com/documentation/testing/confirmation?language=objc\#topics)

### [Instance Methods](https://developer.apple.com/documentation/testing/confirmation?language=objc\#Instance-Methods)

[`func callAsFunction(count: Int)`](https://developer.apple.com/documentation/testing/confirmation/callasfunction(count:)?language=objc)

Confirm this confirmation.

[`func confirm(count: Int)`](https://developer.apple.com/documentation/testing/confirmation/confirm(count:)?language=objc)

Confirm this confirmation.

## [Relationships](https://developer.apple.com/documentation/testing/confirmation?language=objc\#relationships)

### [Conforms To](https://developer.apple.com/documentation/testing/confirmation?language=objc\#conforms-to)

- [`Sendable`](https://developer.apple.com/documentation/Swift/Sendable?language=objc)

## [See Also](https://developer.apple.com/documentation/testing/confirmation?language=objc\#see-also)

### [Confirming that asynchronous events occur](https://developer.apple.com/documentation/testing/confirmation?language=objc\#Confirming-that-asynchronous-events-occur)

[Testing asynchronous code](https://developer.apple.com/documentation/testing/testing-asynchronous-code?language=objc)

Validate whether your code causes expected events to happen.

[`func confirmation<R>(Comment?, expectedCount: Int, isolation: isolated (any Actor)?, sourceLocation: SourceLocation, (Confirmation) async throws -> sending R) async rethrows -> R`](https://developer.apple.com/documentation/testing/confirmation(_:expectedcount:isolation:sourcelocation:_:)-5mqz2?language=objc)

Confirm that some event occurs during the invocation of a function.

[`func confirmation<R>(Comment?, expectedCount: some RangeExpression<Int> & Sendable & Sequence<Int>, isolation: isolated (any Actor)?, sourceLocation: SourceLocation, (Confirmation) async throws -> sending R) async rethrows -> R`](https://developer.apple.com/documentation/testing/confirmation(_:expectedcount:isolation:sourcelocation:_:)-l3il?language=objc)

Confirm that some event occurs during the invocation of a function.

Current page is Confirmation

## Parameterized Test Macro
[Skip Navigation](https://developer.apple.com/documentation/testing/test(_:_:arguments:)-3rzok#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- Test(\_:\_:arguments:)

Macro

# Test(\_:\_:arguments:)

Declare a test parameterized over two zipped collections of values.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
@attached(peer)
macro Test<C1, C2>(
    _ displayName: String? = nil,
    _ traits: any TestTrait...,
    arguments zippedCollections: Zip2Sequence<C1, C2>
) where C1 : Collection, C1 : Sendable, C2 : Collection, C2 : Sendable, C1.Element : Sendable, C2.Element : Sendable
```

## [Parameters](https://developer.apple.com/documentation/testing/test(_:_:arguments:)-3rzok\#parameters)

`displayName`

The customized display name of this test. If the value of this argument is `nil`, the display name of the test is derived from the associated function’s name.

`traits`

Zero or more traits to apply to this test.

`zippedCollections`

Two zipped collections of values to pass to `testFunction`.

## [Overview](https://developer.apple.com/documentation/testing/test(_:_:arguments:)-3rzok\#overview)

During testing, the associated test function is called once for each element in `zippedCollections`.

## [See Also](https://developer.apple.com/documentation/testing/test(_:_:arguments:)-3rzok\#see-also)

### [Related Documentation](https://developer.apple.com/documentation/testing/test(_:_:arguments:)-3rzok\#Related-Documentation)

[Defining test functions](https://developer.apple.com/documentation/testing/definingtests)

Define a test function to validate that code is working correctly.

### [Test parameterization](https://developer.apple.com/documentation/testing/test(_:_:arguments:)-3rzok\#Test-parameterization)

[Implementing parameterized tests](https://developer.apple.com/documentation/testing/parameterizedtesting)

Specify different input parameters to generate multiple test cases from a test function.

[`macro Test<C>(String?, any TestTrait..., arguments: C)`](https://developer.apple.com/documentation/testing/test(_:_:arguments:)-8kn7a)

Declare a test parameterized over a collection of values.

[`macro Test<C1, C2>(String?, any TestTrait..., arguments: C1, C2)`](https://developer.apple.com/documentation/testing/test(_:_:arguments:_:))

Declare a test parameterized over two collections of values.

[`protocol CustomTestArgumentEncodable`](https://developer.apple.com/documentation/testing/customtestargumentencodable)

A protocol for customizing how arguments passed to parameterized tests are encoded, which is used to match against when running specific arguments.

[`struct Case`](https://developer.apple.com/documentation/testing/test/case)

A single test case from a parameterized [`Test`](https://developer.apple.com/documentation/testing/test).

Current page is Test(\_:\_:arguments:)

## Known Issue Function
[Skip Navigation](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:sourcelocation:_:)#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- withKnownIssue(\_:isIntermittent:sourceLocation:\_:)

Function

# withKnownIssue(\_:isIntermittent:sourceLocation:\_:)

Invoke a function that has a known issue that is expected to occur during its execution.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
func withKnownIssue(
    _ comment: Comment? = nil,
    isIntermittent: Bool = false,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ body: () throws -> Void
)
```

## [Parameters](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:sourcelocation:_:)\#parameters)

`comment`

An optional comment describing the known issue.

`isIntermittent`

Whether or not the known issue occurs intermittently. If this argument is `true` and the known issue does not occur, no secondary issue is recorded.

`sourceLocation`

The source location to which any recorded issues should be attributed.

`body`

The function to invoke.

## [Mentioned in](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:sourcelocation:_:)\#mentions)

[Migrating a test from XCTest](https://developer.apple.com/documentation/testing/migratingfromxctest)

## [Discussion](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:sourcelocation:_:)\#discussion)

Use this function when a test is known to raise one or more issues that should not cause the test to fail. For example:

```
@Test func example() {
  withKnownIssue {
    try flakyCall()
  }
}

```

Because all errors thrown by `body` are caught as known issues, this function is not throwing. If only some errors or issues are known to occur while others should continue to cause test failures, use [`withKnownIssue(_:isIntermittent:sourceLocation:_:when:matching:)`](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:sourcelocation:_:when:matching:)) instead.

## [See Also](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:sourcelocation:_:)\#see-also)

### [Recording known issues in tests](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:sourcelocation:_:)\#Recording-known-issues-in-tests)

[`func withKnownIssue(Comment?, isIntermittent: Bool, isolation: isolated (any Actor)?, sourceLocation: SourceLocation, () async throws -> Void) async`](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:isolation:sourcelocation:_:))

Invoke a function that has a known issue that is expected to occur during its execution.

[`func withKnownIssue(Comment?, isIntermittent: Bool, sourceLocation: SourceLocation, () throws -> Void, when: () -> Bool, matching: KnownIssueMatcher) rethrows`](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:sourcelocation:_:when:matching:))

Invoke a function that has a known issue that is expected to occur during its execution.

[`func withKnownIssue(Comment?, isIntermittent: Bool, isolation: isolated (any Actor)?, sourceLocation: SourceLocation, () async throws -> Void, when: () async -> Bool, matching: KnownIssueMatcher) async rethrows`](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:isolation:sourcelocation:_:when:matching:))

Invoke a function that has a known issue that is expected to occur during its execution.

[`typealias KnownIssueMatcher`](https://developer.apple.com/documentation/testing/knownissuematcher)

A function that is used to match known issues.

Current page is withKnownIssue(\_:isIntermittent:sourceLocation:\_:)

## Event Confirmation Function
[Skip Navigation](https://developer.apple.com/documentation/testing/confirmation(_:expectedcount:sourcelocation:_:)#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Expectations and confirmations](https://developer.apple.com/documentation/testing/expectations)
- confirmation(\_:expectedCount:sourceLocation:\_:)

Function

# confirmation(\_:expectedCount:sourceLocation:\_:)

Confirm that some event occurs during the invocation of a function.

Swift 6.0+Xcode 16.0+

```
func confirmation<R>(
    _ comment: Comment? = nil,
    expectedCount: Int = 1,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ body: (Confirmation) async throws -> R
) async rethrows -> R
```

## [Parameters](https://developer.apple.com/documentation/testing/confirmation(_:expectedcount:sourcelocation:_:)\#parameters)

`comment`

An optional comment to apply to any issues generated by this function.

`expectedCount`

The number of times the expected event should occur when `body` is invoked. The default value of this argument is `1`, indicating that the event should occur exactly once. Pass `0` if the event should _never_ occur when `body` is invoked.

`sourceLocation`

The source location to which any recorded issues should be attributed.

`body`

The function to invoke.

## [Return Value](https://developer.apple.com/documentation/testing/confirmation(_:expectedcount:sourcelocation:_:)\#return-value)

Whatever is returned by `body`.

## [Mentioned in](https://developer.apple.com/documentation/testing/confirmation(_:expectedcount:sourcelocation:_:)\#mentions)

[Migrating a test from XCTest](https://developer.apple.com/documentation/testing/migratingfromxctest)

[Testing asynchronous code](https://developer.apple.com/documentation/testing/testing-asynchronous-code)

## [Discussion](https://developer.apple.com/documentation/testing/confirmation(_:expectedcount:sourcelocation:_:)\#discussion)

Use confirmations to check that an event occurs while a test is running in complex scenarios where `#expect()` and `#require()` are insufficient. For example, a confirmation may be useful when an expected event occurs:

- In a context that cannot be awaited by the calling function such as an event handler or delegate callback;

- More than once, or never; or

- As a callback that is invoked as part of a larger operation.


To use a confirmation, pass a closure containing the work to be performed. The testing library will then pass an instance of [`Confirmation`](https://developer.apple.com/documentation/testing/confirmation) to the closure. Every time the event in question occurs, the closure should call the confirmation:

```
let n = 10
await confirmation("Baked buns", expectedCount: n) { bunBaked in
  foodTruck.eventHandler = { event in
    if event == .baked(.cinnamonBun) {
      bunBaked()
    }
  }
  await foodTruck.bake(.cinnamonBun, count: n)
}

```

When the closure returns, the testing library checks if the confirmation’s preconditions have been met, and records an issue if they have not.

## [See Also](https://developer.apple.com/documentation/testing/confirmation(_:expectedcount:sourcelocation:_:)\#see-also)

### [Confirming that asynchronous events occur](https://developer.apple.com/documentation/testing/confirmation(_:expectedcount:sourcelocation:_:)\#Confirming-that-asynchronous-events-occur)

[Testing asynchronous code](https://developer.apple.com/documentation/testing/testing-asynchronous-code)

Validate whether your code causes expected events to happen.

[`struct Confirmation`](https://developer.apple.com/documentation/testing/confirmation)

A type that can be used to confirm that an event occurs zero or more times.

Current page is confirmation(\_:expectedCount:sourceLocation:\_:)

## Disable Test Trait
[Skip Navigation](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:_:)#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Trait](https://developer.apple.com/documentation/testing/trait)
- disabled(\_:sourceLocation:\_:)

Type Method

# disabled(\_:sourceLocation:\_:)

Constructs a condition trait that disables a test if its value is true.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
static func disabled(
    _ comment: Comment? = nil,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: @escaping () async throws -> Bool
) -> Self
```

Available when `Self` is `ConditionTrait`.

## [Parameters](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:_:)\#parameters)

`comment`

An optional comment that describes this trait.

`sourceLocation`

The source location of the trait.

`condition`

A closure that contains the trait’s custom condition logic. If this closure returns `false`, the trait allows the test to run. Otherwise, the testing library skips the test.

## [Return Value](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:_:)\#return-value)

An instance of [`ConditionTrait`](https://developer.apple.com/documentation/testing/conditiontrait) that evaluates the specified closure.

## [See Also](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:_:)\#see-also)

### [Customizing runtime behaviors](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:_:)\#Customizing-runtime-behaviors)

[Enabling and disabling tests](https://developer.apple.com/documentation/testing/enablinganddisabling)

Conditionally enable or disable individual tests before they run.

[Limiting the running time of tests](https://developer.apple.com/documentation/testing/limitingexecutiontime)

Set limits on how long a test can run for until it fails.

[`static func enabled(if: @autoclosure () throws -> Bool, Comment?, sourceLocation: SourceLocation) -> Self`](https://developer.apple.com/documentation/testing/trait/enabled(if:_:sourcelocation:))

Constructs a condition trait that disables a test if it returns `false`.

[`static func enabled(Comment?, sourceLocation: SourceLocation, () async throws -> Bool) -> Self`](https://developer.apple.com/documentation/testing/trait/enabled(_:sourcelocation:_:))

Constructs a condition trait that disables a test if it returns `false`.

[`static func disabled(Comment?, sourceLocation: SourceLocation) -> Self`](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:))

Constructs a condition trait that disables a test unconditionally.

[`static func disabled(if: @autoclosure () throws -> Bool, Comment?, sourceLocation: SourceLocation) -> Self`](https://developer.apple.com/documentation/testing/trait/disabled(if:_:sourcelocation:))

Constructs a condition trait that disables a test if its value is true.

[`static func timeLimit(TimeLimitTrait.Duration) -> Self`](https://developer.apple.com/documentation/testing/trait/timelimit(_:))

Construct a time limit trait that causes a test to time out if it runs for too long.

Current page is disabled(\_:sourceLocation:\_:)

## Test Disabling Trait
[Skip Navigation](https://developer.apple.com/documentation/testing/trait/disabled(if:_:sourcelocation:)#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Trait](https://developer.apple.com/documentation/testing/trait)
- disabled(if:\_:sourceLocation:)

Type Method

# disabled(if:\_:sourceLocation:)

Constructs a condition trait that disables a test if its value is true.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
static func disabled(
    if condition: @autoclosure @escaping () throws -> Bool,
    _ comment: Comment? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
) -> Self
```

Available when `Self` is `ConditionTrait`.

## [Parameters](https://developer.apple.com/documentation/testing/trait/disabled(if:_:sourcelocation:)\#parameters)

`condition`

A closure that contains the trait’s custom condition logic. If this closure returns `false`, the trait allows the test to run. Otherwise, the testing library skips the test.

`comment`

An optional comment that describes this trait.

`sourceLocation`

The source location of the trait.

## [Return Value](https://developer.apple.com/documentation/testing/trait/disabled(if:_:sourcelocation:)\#return-value)

An instance of [`ConditionTrait`](https://developer.apple.com/documentation/testing/conditiontrait) that evaluates the closure you provide.

## [See Also](https://developer.apple.com/documentation/testing/trait/disabled(if:_:sourcelocation:)\#see-also)

### [Customizing runtime behaviors](https://developer.apple.com/documentation/testing/trait/disabled(if:_:sourcelocation:)\#Customizing-runtime-behaviors)

[Enabling and disabling tests](https://developer.apple.com/documentation/testing/enablinganddisabling)

Conditionally enable or disable individual tests before they run.

[Limiting the running time of tests](https://developer.apple.com/documentation/testing/limitingexecutiontime)

Set limits on how long a test can run for until it fails.

[`static func enabled(if: @autoclosure () throws -> Bool, Comment?, sourceLocation: SourceLocation) -> Self`](https://developer.apple.com/documentation/testing/trait/enabled(if:_:sourcelocation:))

Constructs a condition trait that disables a test if it returns `false`.

[`static func enabled(Comment?, sourceLocation: SourceLocation, () async throws -> Bool) -> Self`](https://developer.apple.com/documentation/testing/trait/enabled(_:sourcelocation:_:))

Constructs a condition trait that disables a test if it returns `false`.

[`static func disabled(Comment?, sourceLocation: SourceLocation) -> Self`](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:))

Constructs a condition trait that disables a test unconditionally.

[`static func disabled(Comment?, sourceLocation: SourceLocation, () async throws -> Bool) -> Self`](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:_:))

Constructs a condition trait that disables a test if its value is true.

[`static func timeLimit(TimeLimitTrait.Duration) -> Self`](https://developer.apple.com/documentation/testing/trait/timelimit(_:))

Construct a time limit trait that causes a test to time out if it runs for too long.

Current page is disabled(if:\_:sourceLocation:)

## Condition Trait Management
[Skip Navigation](https://developer.apple.com/documentation/testing/trait/enabled(if:_:sourcelocation:)#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [Trait](https://developer.apple.com/documentation/testing/trait)
- enabled(if:\_:sourceLocation:)

Type Method

# enabled(if:\_:sourceLocation:)

Constructs a condition trait that disables a test if it returns `false`.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
static func enabled(
    if condition: @autoclosure @escaping () throws -> Bool,
    _ comment: Comment? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
) -> Self
```

Available when `Self` is `ConditionTrait`.

## [Parameters](https://developer.apple.com/documentation/testing/trait/enabled(if:_:sourcelocation:)\#parameters)

`condition`

A closure that contains the trait’s custom condition logic. If this closure returns `true`, the trait allows the test to run. Otherwise, the testing library skips the test.

`comment`

An optional comment that describes this trait.

`sourceLocation`

The source location of the trait.

## [Return Value](https://developer.apple.com/documentation/testing/trait/enabled(if:_:sourcelocation:)\#return-value)

An instance of [`ConditionTrait`](https://developer.apple.com/documentation/testing/conditiontrait) that evaluates the closure you provide.

## [Mentioned in](https://developer.apple.com/documentation/testing/trait/enabled(if:_:sourcelocation:)\#mentions)

[Enabling and disabling tests](https://developer.apple.com/documentation/testing/enablinganddisabling)

## [See Also](https://developer.apple.com/documentation/testing/trait/enabled(if:_:sourcelocation:)\#see-also)

### [Customizing runtime behaviors](https://developer.apple.com/documentation/testing/trait/enabled(if:_:sourcelocation:)\#Customizing-runtime-behaviors)

[Enabling and disabling tests](https://developer.apple.com/documentation/testing/enablinganddisabling)

Conditionally enable or disable individual tests before they run.

[Limiting the running time of tests](https://developer.apple.com/documentation/testing/limitingexecutiontime)

Set limits on how long a test can run for until it fails.

[`static func enabled(Comment?, sourceLocation: SourceLocation, () async throws -> Bool) -> Self`](https://developer.apple.com/documentation/testing/trait/enabled(_:sourcelocation:_:))

Constructs a condition trait that disables a test if it returns `false`.

[`static func disabled(Comment?, sourceLocation: SourceLocation) -> Self`](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:))

Constructs a condition trait that disables a test unconditionally.

[`static func disabled(if: @autoclosure () throws -> Bool, Comment?, sourceLocation: SourceLocation) -> Self`](https://developer.apple.com/documentation/testing/trait/disabled(if:_:sourcelocation:))

Constructs a condition trait that disables a test if its value is true.

[`static func disabled(Comment?, sourceLocation: SourceLocation, () async throws -> Bool) -> Self`](https://developer.apple.com/documentation/testing/trait/disabled(_:sourcelocation:_:))

Constructs a condition trait that disables a test if its value is true.

[`static func timeLimit(TimeLimitTrait.Duration) -> Self`](https://developer.apple.com/documentation/testing/trait/timelimit(_:))

Construct a time limit trait that causes a test to time out if it runs for too long.

Current page is enabled(if:\_:sourceLocation:)

## Swift Testing Macro
[Skip Navigation](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-6w9oo#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- require(\_:\_:sourceLocation:)

Macro

# require(\_:\_:sourceLocation:)

Unwrap an optional value or, if it is `nil`, fail and throw an error.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
@freestanding(expression)
macro require<T>(
    _ optionalValue: T?,
    _ comment: @autoclosure () -> Comment? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
) -> T
```

## [Parameters](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-6w9oo\#parameters)

`optionalValue`

The optional value to be unwrapped.

`comment`

A comment describing the expectation.

`sourceLocation`

The source location to which recorded expectations and issues should be attributed.

## [Return Value](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-6w9oo\#return-value)

The unwrapped value of `optionalValue`.

## [Mentioned in](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-6w9oo\#mentions)

[Migrating a test from XCTest](https://developer.apple.com/documentation/testing/migratingfromxctest)

## [Overview](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-6w9oo\#overview)

If `optionalValue` is `nil`, an [`Issue`](https://developer.apple.com/documentation/testing/issue) is recorded for the test that is running in the current task and an instance of [`ExpectationFailedError`](https://developer.apple.com/documentation/testing/expectationfailederror) is thrown.

## [See Also](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-6w9oo\#see-also)

### [Checking expectations](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-6w9oo\#Checking-expectations)

[`macro expect(Bool, @autoclosure () -> Comment?, sourceLocation: SourceLocation)`](https://developer.apple.com/documentation/testing/expect(_:_:sourcelocation:))

Check that an expectation has passed after a condition has been evaluated.

[`macro require(Bool, @autoclosure () -> Comment?, sourceLocation: SourceLocation)`](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-5l63q)

Check that an expectation has passed after a condition has been evaluated and throw an error if it failed.

Current page is require(\_:\_:sourceLocation:)

## Parameterized Test Declaration
[Skip Navigation](https://developer.apple.com/documentation/testing/test(_:_:arguments:)-8kn7a#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- Test(\_:\_:arguments:)

Macro

# Test(\_:\_:arguments:)

Declare a test parameterized over a collection of values.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
@attached(peer)
macro Test<C>(
    _ displayName: String? = nil,
    _ traits: any TestTrait...,
    arguments collection: C
) where C : Collection, C : Sendable, C.Element : Sendable
```

## [Parameters](https://developer.apple.com/documentation/testing/test(_:_:arguments:)-8kn7a\#parameters)

`displayName`

The customized display name of this test. If the value of this argument is `nil`, the display name of the test is derived from the associated function’s name.

`traits`

Zero or more traits to apply to this test.

`collection`

A collection of values to pass to the associated test function.

## [Overview](https://developer.apple.com/documentation/testing/test(_:_:arguments:)-8kn7a\#overview)

During testing, the associated test function is called once for each element in `collection`.

## [See Also](https://developer.apple.com/documentation/testing/test(_:_:arguments:)-8kn7a\#see-also)

### [Related Documentation](https://developer.apple.com/documentation/testing/test(_:_:arguments:)-8kn7a\#Related-Documentation)

[Defining test functions](https://developer.apple.com/documentation/testing/definingtests)

Define a test function to validate that code is working correctly.

### [Test parameterization](https://developer.apple.com/documentation/testing/test(_:_:arguments:)-8kn7a\#Test-parameterization)

[Implementing parameterized tests](https://developer.apple.com/documentation/testing/parameterizedtesting)

Specify different input parameters to generate multiple test cases from a test function.

[`macro Test<C1, C2>(String?, any TestTrait..., arguments: C1, C2)`](https://developer.apple.com/documentation/testing/test(_:_:arguments:_:))

Declare a test parameterized over two collections of values.

[`macro Test<C1, C2>(String?, any TestTrait..., arguments: Zip2Sequence<C1, C2>)`](https://developer.apple.com/documentation/testing/test(_:_:arguments:)-3rzok)

Declare a test parameterized over two zipped collections of values.

[`protocol CustomTestArgumentEncodable`](https://developer.apple.com/documentation/testing/customtestargumentencodable)

A protocol for customizing how arguments passed to parameterized tests are encoded, which is used to match against when running specific arguments.

[`struct Case`](https://developer.apple.com/documentation/testing/test/case)

A single test case from a parameterized [`Test`](https://developer.apple.com/documentation/testing/test).

Current page is Test(\_:\_:arguments:)

## Swift Testing Macro
[Skip Navigation](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-5l63q#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- require(\_:\_:sourceLocation:)

Macro

# require(\_:\_:sourceLocation:)

Check that an expectation has passed after a condition has been evaluated and throw an error if it failed.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
@freestanding(expression)
macro require(
    _ condition: Bool,
    _ comment: @autoclosure () -> Comment? = nil,
    sourceLocation: SourceLocation = #_sourceLocation
)
```

## [Parameters](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-5l63q\#parameters)

`condition`

The condition to be evaluated.

`comment`

A comment describing the expectation.

`sourceLocation`

The source location to which recorded expectations and issues should be attributed.

## [Mentioned in](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-5l63q\#mentions)

[Migrating a test from XCTest](https://developer.apple.com/documentation/testing/migratingfromxctest)

[Testing for errors in Swift code](https://developer.apple.com/documentation/testing/testing-for-errors-in-swift-code)

## [Overview](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-5l63q\#overview)

If `condition` evaluates to `false`, an [`Issue`](https://developer.apple.com/documentation/testing/issue) is recorded for the test that is running in the current task and an instance of [`ExpectationFailedError`](https://developer.apple.com/documentation/testing/expectationfailederror) is thrown.

## [See Also](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-5l63q\#see-also)

### [Checking expectations](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-5l63q\#Checking-expectations)

[`macro expect(Bool, @autoclosure () -> Comment?, sourceLocation: SourceLocation)`](https://developer.apple.com/documentation/testing/expect(_:_:sourcelocation:))

Check that an expectation has passed after a condition has been evaluated.

[`macro require<T>(T?, @autoclosure () -> Comment?, sourceLocation: SourceLocation) -> T`](https://developer.apple.com/documentation/testing/require(_:_:sourcelocation:)-6w9oo)

Unwrap an optional value or, if it is `nil`, fail and throw an error.

Current page is require(\_:\_:sourceLocation:)

## Condition Trait Testing
[Skip Navigation](https://developer.apple.com/documentation/testing/conditiontrait/enabled(_:sourcelocation:_:)#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- [ConditionTrait](https://developer.apple.com/documentation/testing/conditiontrait)
- enabled(\_:sourceLocation:\_:)

Type Method

# enabled(\_:sourceLocation:\_:)

Constructs a condition trait that disables a test if it returns `false`.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
static func enabled(
    _ comment: Comment? = nil,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: @escaping () async throws -> Bool
) -> Self
```

Available when `Self` is `ConditionTrait`.

## [Parameters](https://developer.apple.com/documentation/testing/conditiontrait/enabled(_:sourcelocation:_:)\#parameters)

`comment`

An optional comment that describes this trait.

`sourceLocation`

The source location of the trait.

`condition`

A closure that contains the trait’s custom condition logic. If this closure returns `true`, the trait allows the test to run. Otherwise, the testing library skips the test.

## [Return Value](https://developer.apple.com/documentation/testing/conditiontrait/enabled(_:sourcelocation:_:)\#return-value)

An instance of [`ConditionTrait`](https://developer.apple.com/documentation/testing/conditiontrait) that evaluates the closure you provide.

Current page is enabled(\_:sourceLocation:\_:)

## Known Issue Invocation
[Skip Navigation](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:sourcelocation:_:when:matching:)#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- withKnownIssue(\_:isIntermittent:sourceLocation:\_:when:matching:)

Function

# withKnownIssue(\_:isIntermittent:sourceLocation:\_:when:matching:)

Invoke a function that has a known issue that is expected to occur during its execution.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
func withKnownIssue(
    _ comment: Comment? = nil,
    isIntermittent: Bool = false,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ body: () throws -> Void,
    when precondition: () -> Bool = { true },
    matching issueMatcher: @escaping KnownIssueMatcher = { _ in true }
) rethrows
```

## [Parameters](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:sourcelocation:_:when:matching:)\#parameters)

`comment`

An optional comment describing the known issue.

`isIntermittent`

Whether or not the known issue occurs intermittently. If this argument is `true` and the known issue does not occur, no secondary issue is recorded.

`sourceLocation`

The source location to which any recorded issues should be attributed.

`body`

The function to invoke.

`precondition`

A function that determines if issues are known to occur during the execution of `body`. If this function returns `true`, encountered issues that are matched by `issueMatcher` are considered to be known issues; if this function returns `false`, `issueMatcher` is not called and they are treated as unknown.

`issueMatcher`

A function to invoke when an issue occurs that is used to determine if the issue is known to occur. By default, all issues match.

## [Mentioned in](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:sourcelocation:_:when:matching:)\#mentions)

[Migrating a test from XCTest](https://developer.apple.com/documentation/testing/migratingfromxctest)

## [Discussion](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:sourcelocation:_:when:matching:)\#discussion)

Use this function when a test is known to raise one or more issues that should not cause the test to fail, or if a precondition affects whether issues are known to occur. For example:

```
@Test func example() throws {
  try withKnownIssue {
    try flakyCall()
  } when: {
    callsAreFlakyOnThisPlatform()
  } matching: { issue in
    issue.error is FileNotFoundError
  }
}

```

It is not necessary to specify both `precondition` and `issueMatcher` if only one is relevant. If all errors and issues should be considered known issues, use [`withKnownIssue(_:isIntermittent:sourceLocation:_:)`](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:sourcelocation:_:)) instead.

## [See Also](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:sourcelocation:_:when:matching:)\#see-also)

### [Recording known issues in tests](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:sourcelocation:_:when:matching:)\#Recording-known-issues-in-tests)

[`func withKnownIssue(Comment?, isIntermittent: Bool, sourceLocation: SourceLocation, () throws -> Void)`](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:sourcelocation:_:))

Invoke a function that has a known issue that is expected to occur during its execution.

[`func withKnownIssue(Comment?, isIntermittent: Bool, isolation: isolated (any Actor)?, sourceLocation: SourceLocation, () async throws -> Void) async`](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:isolation:sourcelocation:_:))

Invoke a function that has a known issue that is expected to occur during its execution.

[`func withKnownIssue(Comment?, isIntermittent: Bool, isolation: isolated (any Actor)?, sourceLocation: SourceLocation, () async throws -> Void, when: () async -> Bool, matching: KnownIssueMatcher) async rethrows`](https://developer.apple.com/documentation/testing/withknownissue(_:isintermittent:isolation:sourcelocation:_:when:matching:))

Invoke a function that has a known issue that is expected to occur during its execution.

[`typealias KnownIssueMatcher`](https://developer.apple.com/documentation/testing/knownissuematcher)

A function that is used to match known issues.

Current page is withKnownIssue(\_:isIntermittent:sourceLocation:\_:when:matching:)

## Parameterized Testing in Swift
[Skip Navigation](https://developer.apple.com/documentation/testing/test(_:_:arguments:_:)#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- Test(\_:\_:arguments:\_:)

Macro

# Test(\_:\_:arguments:\_:)

Declare a test parameterized over two collections of values.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
@attached(peer)
macro Test<C1, C2>(
    _ displayName: String? = nil,
    _ traits: any TestTrait...,
    arguments collection1: C1,
    _ collection2: C2
) where C1 : Collection, C1 : Sendable, C2 : Collection, C2 : Sendable, C1.Element : Sendable, C2.Element : Sendable
```

## [Parameters](https://developer.apple.com/documentation/testing/test(_:_:arguments:_:)\#parameters)

`displayName`

The customized display name of this test. If the value of this argument is `nil`, the display name of the test is derived from the associated function’s name.

`traits`

Zero or more traits to apply to this test.

`collection1`

A collection of values to pass to `testFunction`.

`collection2`

A second collection of values to pass to `testFunction`.

## [Overview](https://developer.apple.com/documentation/testing/test(_:_:arguments:_:)\#overview)

During testing, the associated test function is called once for each pair of elements in `collection1` and `collection2`.

## [See Also](https://developer.apple.com/documentation/testing/test(_:_:arguments:_:)\#see-also)

### [Related Documentation](https://developer.apple.com/documentation/testing/test(_:_:arguments:_:)\#Related-Documentation)

[Defining test functions](https://developer.apple.com/documentation/testing/definingtests)

Define a test function to validate that code is working correctly.

### [Test parameterization](https://developer.apple.com/documentation/testing/test(_:_:arguments:_:)\#Test-parameterization)

[Implementing parameterized tests](https://developer.apple.com/documentation/testing/parameterizedtesting)

Specify different input parameters to generate multiple test cases from a test function.

[`macro Test<C>(String?, any TestTrait..., arguments: C)`](https://developer.apple.com/documentation/testing/test(_:_:arguments:)-8kn7a)

Declare a test parameterized over a collection of values.

[`macro Test<C1, C2>(String?, any TestTrait..., arguments: Zip2Sequence<C1, C2>)`](https://developer.apple.com/documentation/testing/test(_:_:arguments:)-3rzok)

Declare a test parameterized over two zipped collections of values.

[`protocol CustomTestArgumentEncodable`](https://developer.apple.com/documentation/testing/customtestargumentencodable)

A protocol for customizing how arguments passed to parameterized tests are encoded, which is used to match against when running specific arguments.

[`struct Case`](https://developer.apple.com/documentation/testing/test/case)

A single test case from a parameterized [`Test`](https://developer.apple.com/documentation/testing/test).

Current page is Test(\_:\_:arguments:\_:)

## Test Declaration Macro
[Skip Navigation](https://developer.apple.com/documentation/testing/test(_:_:)#app-main)

- [Swift Testing](https://developer.apple.com/documentation/testing)
- Test(\_:\_:)

Macro

# Test(\_:\_:)

Declare a test.

iOSiPadOSMac CatalystmacOStvOSvisionOSwatchOSSwift 6.0+Xcode 16.0+

```
@attached(peer)
macro Test(
    _ displayName: String? = nil,
    _ traits: any TestTrait...
)
```

## [Parameters](https://developer.apple.com/documentation/testing/test(_:_:)\#parameters)

`displayName`

The customized display name of this test. If the value of this argument is `nil`, the display name of the test is derived from the associated function’s name.

`traits`

Zero or more traits to apply to this test.

## [See Also](https://developer.apple.com/documentation/testing/test(_:_:)\#see-also)

### [Related Documentation](https://developer.apple.com/documentation/testing/test(_:_:)\#Related-Documentation)

[Defining test functions](https://developer.apple.com/documentation/testing/definingtests)

Define a test function to validate that code is working correctly.

### [Essentials](https://developer.apple.com/documentation/testing/test(_:_:)\#Essentials)

[Defining test functions](https://developer.apple.com/documentation/testing/definingtests)

Define a test function to validate that code is working correctly.

[Organizing test functions with suite types](https://developer.apple.com/documentation/testing/organizingtests)

Organize tests into test suites.

[Migrating a test from XCTest](https://developer.apple.com/documentation/testing/migratingfromxctest)

Migrate an existing test method or test class written using XCTest.

[`struct Test`](https://developer.apple.com/documentation/testing/test)

A type representing a test or suite.

[`macro Suite(String?, any SuiteTrait...)`](https://developer.apple.com/documentation/testing/suite(_:_:))

Declare a test suite.

Current page is Test(\_:\_:)

