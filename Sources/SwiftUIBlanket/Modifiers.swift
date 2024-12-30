import SwiftUI

// MARK: - XTranslationEffect

/// A custom `GeometryEffect` that animates a translation along the X-axis.
///
/// This effect allows you to apply a horizontal translation offset (`X`) to a view. It also includes a callback to 
/// update the offset value on each animation frame. This enables custom behavior during the animation lifecycle.
///
/// - Parameters:
///   - offset: The horizontal translation offset applied to the view, in points.
///   - onUpdate: A closure that is called with the new offset value on each animation frame during the animation,
///     executed on the main thread to ensure UI updates are performed on the correct thread.
struct XTranslationEffect: GeometryEffect {
  // MARK: - Properties
  
  /// The current horizontal translation offset applied to the view.
  /// This value is animatable, and when it changes, it triggers the `onUpdate` closure.
  var offset: CGFloat = .zero
  
  /// A closure that is called with the new offset value during each animation frame.
  /// It allows the caller to update the state with the current offset.
  let onUpdate: @MainActor (CGFloat) -> Void
    
  // MARK: - Initializer
  
  /// Initializes the `XTranslationEffect` with an initial offset and an update callback.
  ///
  /// - Parameters:
  ///   - offset: The initial horizontal translation offset applied to the view.
  ///   - onUpdate: A closure that will be called with the updated offset value on each animation frame.
  init(offset: CGFloat, onUpdate: @escaping @MainActor (CGFloat) -> Void) {
    self.offset = offset
    self.onUpdate = onUpdate
  }
  
  // MARK: - GeometryEffect
  
  /// The animatable data for the `XTranslationEffect`. This allows the view to be animated
  /// between different offset values, triggering the `onUpdate` closure to notify the caller of the new value.
  ///
  /// - Note: This property is marked as `nonisolated` to allow access from outside the effect context
  ///   while ensuring UI updates happen on the main thread.
  nonisolated
  var animatableData: CGFloat {
    get { offset }
    set {
      Task { @MainActor [onUpdate] in 
        onUpdate(newValue)
      }
      offset = newValue
    }
  }
  
  /// Returns a `ProjectionTransform` representing the current translation effect.
  /// This method is called during the animation to apply the current translation offset.
  ///
  /// - Parameter size: The size of the view to which the effect is applied (not used in this effect, but required
  ///   by the `GeometryEffect` protocol).
  /// - Returns: A `ProjectionTransform` that applies the X-axis translation to the view.
  nonisolated
  func effectValue(size: CGSize) -> ProjectionTransform {
    return .init(.init(translationX: offset, y: 0))
  }
}

// MARK: - YTranslationEffect

/// A custom `GeometryEffect` that animates a translation along the Y-axis.
///
/// This effect allows you to apply a vertical translation offset (`Y`) to a view. It also includes a callback to 
/// update the offset value on each animation frame, enabling dynamic behavior during animations.
///
/// - Parameters:
///   - offset: The vertical translation offset applied to the view, in points.
///   - onUpdate: A closure that is called with the new offset value on each animation frame during the animation,
///     executed on the main thread to ensure UI updates are performed on the correct thread.
struct YTranslationEffect: GeometryEffect {
  // MARK: - Properties
  
  /// The current vertical translation offset applied to the view.
  /// This value is animatable, and when it changes, it triggers the `onUpdate` closure.
  var offset: CGFloat = .zero
  
  /// A closure that is called with the new offset value during each animation frame.
  /// It allows the caller to update the state with the current offset.
  let onUpdate: @MainActor (CGFloat) -> Void
  
  // MARK: - Initializer
  
  /// Initializes the `YTranslationEffect` with an initial offset and an update callback.
  ///
  /// - Parameters:
  ///   - offset: The initial vertical translation offset applied to the view.
  ///   - onUpdate: A closure that will be called with the updated offset value on each animation frame.
  init(offset: CGFloat, onUpdate: @escaping @MainActor (CGFloat) -> Void) {
    self.offset = offset
    self.onUpdate = onUpdate
  }
  
  // MARK: - GeometryEffect
  
  /// The animatable data for the `YTranslationEffect`. This allows the view to be animated
  /// between different offset values, triggering the `onUpdate` closure to notify the caller of the new value.
  ///
  /// - Note: This property is marked as `nonisolated` to allow access from outside the effect context
  ///   while ensuring UI updates happen on the main thread.
  nonisolated
  var animatableData: CGFloat {
    get { offset }
    set {
      Task { @MainActor [onUpdate] in 
        onUpdate(newValue)
      }
      offset = newValue
    }
  }
  
  /// Returns a `ProjectionTransform` representing the current translation effect.
  /// This method is called during the animation to apply the current translation offset.
  ///
  /// - Parameter size: The size of the view to which the effect is applied (not used in this effect, but required
  ///   by the `GeometryEffect` protocol).
  /// - Returns: A `ProjectionTransform` that applies the Y-axis translation to the view.
  nonisolated
  func effectValue(size: CGSize) -> ProjectionTransform {
    return .init(.init(translationX: 0, y: offset))
  }
}

// MARK: - View Extensions

extension View {
  // MARK: - Animatable X Translation
  
  /// Applies an animatable horizontal translation effect to the view.
  ///
  /// This modifier uses the `XTranslationEffect` to apply a translation effect along the X-axis,
  /// allowing for smooth animations with state updates during the translation.
  ///
  /// - Parameters:
  ///   - x: The horizontal translation offset to apply to the view.
  ///   - onUpdate: A closure that is called with the updated offset value on each animation frame.
  /// - Returns: A view with the applied animatable translation effect along the X-axis.
  func _animatableOffset(x: CGFloat, onUpdate: @escaping @MainActor (CGFloat) -> Void) -> some View {
    self.modifier(XTranslationEffect(offset: x, onUpdate: onUpdate))
  }
  
  // MARK: - Animatable Y Translation
  
  /// Applies an animatable vertical translation effect to the view.
  ///
  /// This modifier uses the `YTranslationEffect` to apply a translation effect along the Y-axis,
  /// allowing for smooth animations with state updates during the translation.
  ///
  /// - Parameters:
  ///   - y: The vertical translation offset to apply to the view.
  ///   - onUpdate: A closure that is called with the updated offset value on each animation frame.
  /// - Returns: A view with the applied animatable translation effect along the Y-axis.
  func _animatableOffset(y: CGFloat, onUpdate: @escaping @MainActor (CGFloat) -> Void) -> some View {
    self.modifier(YTranslationEffect(offset: y, onUpdate: onUpdate))
  }
}
