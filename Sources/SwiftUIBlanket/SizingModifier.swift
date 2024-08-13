import SwiftUI

struct SizingModifier: ViewModifier {
  
  @StateObject private var proxy: Proxy = .init()
  private let onChange: (CGSize) -> Void
  
  init(
    onChange: @escaping (CGSize) -> Void
  ) {
    self.onChange = onChange
  }
  
  func body(content: Content) -> some View {
    content
      .onReceive(proxy.$size) { size in
        onChange(size ?? .zero)
      }
      .background(
        _Layout(proxy: proxy) {
          Color.clear   
        }
      )
    
  }
  
}

@MainActor
private final class Proxy: ObservableObject {
  @Published var size: CGSize?
}

/**
 This is a workaround to get the size of the view instead of using GeometryReader.
 Using GeometryReader gets a wrong value in particular case like a shape expanding out of safe-area.
 Given Layout protocol provides the constrained size for laying out its subviews, uses this value for measuring container size.
 */
private struct _Layout: Layout {
  
  private let proxy: Proxy
  
  init(proxy: Proxy) {
    self.proxy = proxy
  }
  
  func placeSubviews(
    in bounds: CGRect,
    proposal: ProposedViewSize,
    subviews: Subviews,
    cache: inout ()
  ) {
    for subview in subviews {
      subview
        .place(
          at: bounds.origin,
          proposal: .init(
            width: proposal.width,
            height: proposal.height
          )
        )
    }
  }
  
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let size = CGSize.init(width: proposal.width ?? 0 , height: proposal.height ?? 0)
    Task { @MainActor in
      proxy.size = size
    }
    return size
  }
}
