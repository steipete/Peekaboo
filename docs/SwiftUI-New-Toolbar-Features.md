# SwiftUI New Toolbar Features

## Overview

SwiftUI has introduced significant enhancements to its toolbar system, providing developers with more flexibility, customization options, and improved user experiences. These new features enable the creation of more sophisticated and interactive toolbars across Apple platforms, including iOS, iPadOS, and macOS. Key improvements include customizable toolbars, enhanced search integration, new placement options, and transition effects.

## Customizable Toolbars

### Creating a Customizable Toolbar

SwiftUI now supports customizable toolbars that users can personalize by adding, removing, and rearranging items.

```swift
ContentView()
    .toolbar(id: "main-toolbar") {
        ToolbarItem(id: "tag") {
           TagButton()
        }
        ToolbarItem(id: "share") {
           ShareButton()
        }
        ToolbarSpacer(.fixed)
        ToolbarItem(id: "more") {
           MoreButton()
        }
    }
```

The `toolbar(id:)` modifier creates a customizable toolbar with a unique identifier. Each item in a customizable toolbar must have its own ID.

### Toolbar Spacers

Toolbar spacers create visual breaks between items and can be fixed or flexible.

```swift
ToolbarSpacer(.fixed)  // Creates a fixed-width space
ToolbarSpacer(.flexible)  // Creates a flexible space that pushes items apart
```

Spacers are also customizable - users can add multiple copies of spacers from the customization panel if the toolbar supports it.

## Enhanced Search Integration

### Search Toolbar Behavior

Control how search fields appear and behave in toolbars:

```swift
@State private var searchText = ""

NavigationStack {
    RecipeList()
        .searchable($searchText)
        .searchToolbarBehavior(.minimize)
}
```

The `.minimize` behavior renders the search field as a button-like control that expands when tapped, optimizing space in the toolbar.

### Repositioning Search Items

Reposition the default search item in the toolbar:

```swift
NavigationSplitView {
    AllCalendarsView()
} detail: {
    SelectedCalendarView()
        .searchable($query)
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                CalendarPicker()
            }
            ToolbarItem(placement: .bottomBar) {
                Invites()
            }
            DefaultToolbarItem(kind: .search, placement: .bottomBar)
            ToolbarSpacer(placement: .bottomBar)
            ToolbarItem(placement: .bottomBar) { 
                NewEventButton() 
            }
        }
}
```

The `DefaultToolbarItem` with `.search` kind allows you to reposition the search field within the toolbar.

## New Toolbar Item Placements

### Large Subtitle Placement

Place custom content in the subtitle area of the navigation bar:

```swift
NavigationStack {
    DetailView()
        .navigationTitle("Title")
        .navigationSubtitle("Subtitle")
        .toolbar {
            ToolbarItem(placement: .largeSubtitle) {
                CustomLargeNavigationSubtitle()
            }
        }
}
```

The `.largeSubtitle` placement takes precedence over the value provided to the `navigationSubtitle(_:)` modifier.

## Visual Effects and Transitions

### Matched Transition Source

Create smooth transitions between toolbar items and other views:

```swift
struct ContentView: View {
    @State private var isPresented = false
    @Namespace private var namespace

    var body: some View {
        NavigationStack {
            DetailView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Show Sheet", systemImage: "globe") {
                            isPresented = true
                        }
                    }
                    .matchedTransitionSource(
                        id: "world", in: namespace)
                }
                .sheet(isPresented: $isPresented) {
                    SheetView()
                        .navigationTransition(
                            .zoom(sourceID: "world", in: namespace))
                }
        }
    }
}
```

The `matchedTransitionSource(id:in:)` modifier identifies a toolbar item as the source of a navigation transition.

### Shared Background Visibility

Control the glass background effect on toolbar items:

```swift
ContentView()
    .toolbar(id: "main") {
        ToolbarItem(id: "build-status", placement: .principal) {
            BuildStatus()
        }
        .sharedBackgroundVisibility(.hidden)
    }
```

The `sharedBackgroundVisibility(_:)` modifier adjusts the visibility of the glass background effect, allowing items to stand out visually.

## System-Defined Toolbar Items

Use system-defined toolbar items with custom placements:

```swift
.toolbar {
    DefaultToolbarItem(kind: .search, placement: .bottomBar)
    DefaultToolbarItem(kind: .sidebar, placement: .navigationBarLeading)
}
```

The `DefaultToolbarItem` initializer creates system-defined toolbar items with specific placements, allowing you to leverage system functionality while controlling positioning.

## Platform-Specific Considerations

### iOS and iPadOS

- Bottom bar placement is particularly useful on iPhones
- Search minimization works well on smaller screens
- Consider using `.searchToolbarBehavior(.minimize)` for better space utilization

### macOS

- Customizable toolbars are particularly valuable for productivity apps
- Users expect to be able to customize toolbars in complex applications
- Consider toolbar spacers to create logical groupings of related items

## Best Practices

1. **Use meaningful IDs** for toolbar items in customizable toolbars
2. **Group related actions** together with appropriate spacing
3. **Consider platform differences** when designing toolbar layouts
4. **Use system-defined items** when appropriate to maintain platform consistency
5. **Test toolbar customization** to ensure a good user experience
6. **Use transitions thoughtfully** to enhance the user experience without being distracting

## References

- [SwiftUI Documentation: SearchToolbarBehavior](https://developer.apple.com/documentation/SwiftUI/SearchToolbarBehavior)
- [SwiftUI Documentation: ToolbarSpacer](https://developer.apple.com/documentation/SwiftUI/ToolbarSpacer)
- [SwiftUI Documentation: DefaultToolbarItem](https://developer.apple.com/documentation/SwiftUI/DefaultToolbarItem)
- [SwiftUI Documentation: ToolbarItemPlacement](https://developer.apple.com/documentation/SwiftUI/ToolbarItemPlacement)
- [SwiftUI Documentation: CustomizableToolbarContent](https://developer.apple.com/documentation/SwiftUI/CustomizableToolbarContent)