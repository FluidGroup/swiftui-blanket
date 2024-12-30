import SwiftUI
import WithPrerender

// MARK: - SizingModifier

/// A `ViewModifier` that provides a way to track the size of a view without using `GeometryReader`.
/// 
/// This modifier works around issues with `GeometryReader` (such as incorrect values when shapes expand
/// beyond the safe area) by using a custom layout proxy to measure the size. The `onChange` closure is
/// invoked with the new size whenever the size of the view changes.
///
/// - Parameters:
///   - onChange: A closure that is called when the size of the view changes. It provides the new size (`CGSize`).
struct SizingModifier: ViewModifier {
  // MARK: - Properties
  
  /// The `Proxy` object used to track the size of the view. It is an `@StateObject` to ensure it persists across view updates.
  @StateObject 
  private var proxy: Proxy = .init()
  
  /// A closure that gets called when the size of the view changes.
  private let onChange: (CGSize) -> Void
  
  // MARK: - Initializer
  
  /// Initializes the `SizingModifier` with an `onChange` closure that will be called with the new size.
  ///
  /// - Parameters:
  ///   - onChange: A closure that is called when the size of the view changes, providing the new size.
  init(
    onChange: @escaping (CGSize) -> Void
  ) {
    self.onChange = onChange
  }
  
  // MARK: - ViewModifier Body
  
  /// The body of the view modifier, which applies the size tracking to the view.
  ///
  /// The `onReceive` modifier listens for changes to the `proxy.size` and triggers the `onChange` closure
  /// with the new size. The view content is also wrapped in a custom `_Layout` to access the size without
  /// using `GeometryReader`.
  ///
  /// - Parameter content: The view being modified.
  /// - Returns: A view with the size-tracking modifier applied.
  func body(content: Content) -> some View {
    content
      .onReceive(proxy.$size) { size in
        onChange(size ?? .zero)  // Pass the new size (or zero if nil) to the onChange closure
      }
      .background(
        _Layout(proxy: proxy) {  // Apply custom layout to measure size
          Color.clear  // Invisible background for size measurement
        }
      )
  }
}

// MARK: - Proxy

/// A `@MainActor` `ObservableObject` that tracks the size of the view. It holds an optional `CGSize`.
///
/// This class is used by `SizingModifier` to propagate size changes and trigger the `onChange` closure.
@MainActor
private final class Proxy: ObservableObject {
  // MARK: - Properties
  
  /// The current size of the view. It's marked as `@Published` to trigger updates when it changes.
  @Published 
  var size: CGSize?
}

// MARK: - _Layout

/// A custom `Layout` that uses a proxy to measure and track the size of a view.
///
/// This layout works around limitations in `GeometryReader` by using the `Layout` protocol's constraints
/// and providing the measured size to the `Proxy` object for use by the `SizingModifier`.
///
/// - Note: This layout ensures the correct size even when a view expands beyond safe areas.
private struct _Layout: Layout {
  // MARK: - Properties
  
  /// The `Proxy` object used to store the size information.
  private let proxy: Proxy
  
  // MARK: - Initializer
  
  /// Initializes the `_Layout` with a `Proxy` to store the size of the view.
  ///
  /// - Parameter proxy: The `Proxy` instance used to store and pass the size.
  init(proxy: Proxy) {
    self.proxy = proxy
  }
  
  // MARK: - Layout Methods
  
  /// Positions subviews within the given bounds using the proposal for size.
  ///
  /// - Parameters:
  ///   - bounds: The bounds within which to place the subviews.
  ///   - proposal: The proposed size for the subviews.
  ///   - subviews: The subviews to position.
  ///   - cache: Cache used for optimizing layout (not used here).
  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) {
    for subview in subviews {
      subview
        .place(
          at: bounds.origin,  // Place subview at the origin of the bounds
          proposal: .init(
            width: proposal.width,  // Use proposed width
            height: proposal.height  // Use proposed height
          )
        )
    }
  }
  
  /// Returns the size that best fits the given proposal, using the size from the proxy.
  ///
  /// - Parameters:
  ///   - proposal: The proposed size for the view.
  ///   - subviews: The subviews (not used here).
  ///   - cache: Cache used for optimization (not used here).
  /// - Returns: The calculated size based on the proposal.
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    // Calculate the size based on the proposed dimensions
    let size = CGSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    
    // Use `withPrerender` to ensure that the size is set on the main thread before rendering
    MainActor.assumeIsolated {
      withPrerender {  // Ensure the update happens without triggering a layout pass
        proxy.size = size  // Update the size in the proxy
      }
    }
    return size  // Return the calculated size
  }
}
