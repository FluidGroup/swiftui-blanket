# swiftui-blanket

A draggable, bottom-aligned sheet **inside a SwiftUI view's bounds**, with content-sized, fixed-height, and fractional detents. Unlike `.sheet`, a blanket does not create a system modal presentation. You provide the sheet's appearance.

## Requirements

- iOS 18 or later (iPhone and iPad)
- Swift 6 / Xcode 16 or later

Other Apple platforms are not supported. Add this repository through Xcode's **Add Package Dependencies** and select the `main` branch while the package is pre-release, then link the `SwiftUIBlanket` product.

## Inline blanket

Inline mode leaves the area outside the blanket interactive.

```swift
import SwiftUI
import SwiftUIBlanket

struct Example: View {
  @State private var isPresented = false

  var body: some View {
    VStack {
      Button("Show") { isPresented = true }
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .blanket(isPresented: $isPresented, onDismiss: {
      print("Dismissed")
    }) {
      VStack {
        Text("A blanket")
        Button("Close") { isPresented = false }
      }
      .padding()
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
      .blanketContentDetents(.content, .fraction(1))
    }
  }
}
```

Attach `.blanket` to the container it should cover. It does not cover navigation bars or other views outside that container. An initially `true` binding also presents the blanket.

## Presentation mode

Presentation mode adds a backdrop within the same container. By default, tapping it dismisses the blanket. Set `handlesOutOfContent` to `false` to let touches pass through the backdrop instead.

```swift
.blanket(
  isPresented: $isPresented,
  configuration: .init(mode: .presentation(.init(
    backgroundColor: .black.opacity(0.3),
    handlesOutOfContent: true
  )))
) {
  MyBlanketContent()
    .blanketContentDetents(.height(240), .fraction(1))
}
```

## Detents and scrolling

- `.content` uses the content's ideal height and tracks changes independently of the current displayed height. Give a bare `ScrollView` an `idealHeight`, or use fixed/fractional detents when it has no meaningful intrinsic height.
- `.height(240)` specifies a height in points.
- `.fraction(0.5)` uses half the container's available height.
- Heights are clamped to the container, negative values to zero, and NaN to zero. Equal resolved heights are treated as one stop. The smallest detent is selected initially; omitting detents or passing an empty collection uses `.content`.
- Drag upward to expand. Below the largest detent, vertical scrolling is locked so the gesture resizes the blanket first. At the largest detent, the `ScrollView` can scroll; dragging downward from its top edge moves the blanket again. Horizontal scroll views remain independent.
- Dragging sufficiently far or quickly below the smallest detent dismisses the blanket. Setting the binding to `false` also animates dismissal. `onDismiss` runs once when a dismissal finishes, not when it is cancelled by re-presentation.
- The blanket supports the accessibility escape action and uses a shorter, non-spring animation when Reduce Motion is enabled.

## Item-driven content

```swift
.blanket(item: $selectedItem, onDismiss: didDismiss) { item in
  DetailContent(item: item)
    .blanketContentDetents(.content, .fraction(1))
}
```

The item only needs to conform to `Identifiable`. Replacing its identity replaces the content and resets that content's local state without calling `onDismiss`. Setting the item to `nil`, or dismissing by dragging, closes the blanket and clears the binding. The last item remains rendered during the exit animation.

## Development and tests

Open `Development/Development.xcodeproj` for examples of inline mode, presentation mode, initial presentation, resizing content, nested scroll views, and item replacement. No submodule checkout is needed for this app.

Because the package uses UIKit, run tests against an iOS simulator rather than using a macOS `swift test`:

```sh
xcodebuild -scheme swiftui-blanket \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  test CODE_SIGNING_ALLOWED=NO

xcodebuild -project Development/Development.xcodeproj -scheme Development \
  -destination 'generic/platform=iOS Simulator' \
  build CODE_SIGNING_ALLOWED=NO
```

Replace the simulator name with one installed in your Xcode. Tests cover detent resolution, lifecycle cancellation, and SwiftUI hosting (initial presentation, dismissal/re-presentation, content/container resizing, and item replacement). Gesture feel still needs validation in the sample app on a simulator or device.
