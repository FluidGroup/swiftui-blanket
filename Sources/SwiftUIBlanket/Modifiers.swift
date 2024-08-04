import SwiftUI

struct XTranslationEffect: GeometryEffect {
  
  var offset: CGFloat = .zero
  
  let onUpdate: @MainActor (CGFloat) -> Void
    
  init(offset: CGFloat, onUpdate: @escaping @MainActor (CGFloat) -> Void) {
    self.offset = offset
    self.onUpdate = onUpdate
  }
  
  nonisolated
  var animatableData: CGFloat {
    get {
      offset
    }
    set {
      Task { @MainActor [onUpdate] in 
        onUpdate(newValue)
      }
      offset = newValue
    }
  }
  
  nonisolated
  func effectValue(size: CGSize) -> ProjectionTransform {
    return .init(.init(translationX: offset, y: 0))
  }
  
}

struct YTranslationEffect: GeometryEffect {
  
  var offset: CGFloat = .zero
  
  let onUpdate: @MainActor (CGFloat) -> Void
  
  init(offset: CGFloat, onUpdate: @escaping @MainActor (CGFloat) -> Void) {
    self.offset = offset
    self.onUpdate = onUpdate
  }
  
  nonisolated
  var animatableData: CGFloat {
    get {
      offset
    }
    set {
      Task { @MainActor [onUpdate] in 
        onUpdate(newValue)
      }
      offset = newValue
    }
  }
  
  nonisolated
  func effectValue(size: CGSize) -> ProjectionTransform {
    return .init(.init(translationX: 0, y: offset))
  }
  
}

extension View {
  
  /// Applies offset effect that is animatable against ``SwiftUI/View/offset``
  func _animatableOffset(x: CGFloat, onUpdate: @escaping @MainActor (CGFloat) -> Void) -> some View {
    self.modifier(XTranslationEffect(offset: x, onUpdate: onUpdate))
  }
  
  /// Applies offset effect that is animatable against ``SwiftUI/View/offset``
  func _animatableOffset(y: CGFloat, onUpdate: @escaping @MainActor (CGFloat) -> Void) -> some View {
    self.modifier(YTranslationEffect(offset: y, onUpdate: onUpdate))
  }
  
}
