import SwiftUI
import WithPrerender

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
        if let size { onChange(size) }
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
    MainActor.assumeIsolated {
      withPrerender {      
        if proxy.size != size { proxy.size = size }
      }
    }
    return size
  }
}

struct ContentSizingView<Content: View>: View {
  @StateObject private var proxy = Proxy()
  let onChange: (CGSize) -> Void
  @ViewBuilder let content: () -> Content

  var body: some View {
    ContentLayout(proxy: proxy) { content() }
      .onReceive(proxy.$size) { size in
        if let size { onChange(size) }
      }
  }
}

private struct ContentLayout: Layout {
  let proxy: Proxy

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let ideal = subviews.first?.sizeThatFits(.init(width: proposal.width, height: nil)) ?? .zero
    MainActor.assumeIsolated {
      withPrerender {
        if proxy.size != ideal { proxy.size = ideal }
      }
    }
    return .init(width: proposal.width ?? ideal.width, height: proposal.height ?? ideal.height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    for subview in subviews {
      subview.place(at: bounds.origin, anchor: .topLeading, proposal: .init(bounds.size))
    }
  }
}
