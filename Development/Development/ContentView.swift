//
//  ContentView.swift
//  Development
//
//  Created by Muukii on 2024/07/27.
//

import SwiftUI
import SwiftUIBlanket

struct ContentView: View {
  var body: some View {
    InlinePreview()
  }
}

struct SheetContent: View {
  
  @State var isExpanded = false
  
  private let title: String
  
  init(title: String) {
    self.title = title
  }
  
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 20).fill(.background)
      HStack {
        VStack(alignment: .leading) {
          
          Text(title)
            .font(.title)
          
          HStack {
            VStack {
              Text("Hello, World!")
              Text("Hello, World!")
              Text("Hello, World!")
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(.tertiary))
            
            ScrollView {
              VStack {
                ForEach(0..<50) { index in
                  Text("Hello, World!")
                }
              }
            }
            .frame(height: 300)
          }
          
          ScrollView(.horizontal) {
            HStack {
              Text("Horizontal ScrollView")
              Text("Horizontal ScrollView")
              Text("Horizontal ScrollView")
            }
          }
          
          if isExpanded {
            VStack {
              Text("Hello, World!")
              Text("Hello, World!")
              Text("Hello, World!")
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(.tertiary))
          }
          
          HStack {
            Spacer()
            Button("Detail") {
              withAnimation(.spring) {
                isExpanded.toggle()
              }
            }
            .buttonBorderShape(.roundedRectangle)
          }
        }
        Spacer(minLength: 0)
      }
      .padding()
      .background(Color.red)
    }
    .clipped()
    .shadow(color: Color.black.opacity(0.2), radius: 6, x: 0, y: 0)
    .padding(8)
  }
}

struct InlinePreview: View {
  
  @State var isPresented = false
  
  var body: some View {
    VStack {
      Button("Show") {
        isPresented.toggle()
      }
      Rectangle()
        .fill(Color.purple)
        .ignoresSafeArea()
    }
    .blanket(isPresented: $isPresented) {
      SheetContent(title: "This is a blanket")
    }
  }
}

#Preview("isPresented"){
  
  return InlinePreview()
  
}

#Preview("item"){
  
  struct Item: Identifiable {
    let id = UUID()
    let title: String
  }
  
  struct Preview: View {
    
    @State var item: Item?
    
    var body: some View {
      VStack {
        Button("Show A") {
          item = .init(title: "This is a blanket A")
        }
        Button("Show B") {
          item = .init(title: "This is a blanket B")
        }
        Button("Show C") {
          item = .init(title: "This is a blanket C")
        }
        Rectangle()
          .fill(Color.purple)
          .ignoresSafeArea()
      }
      .blanket(item: $item) { item in
        SheetContent(
          title: item.title
        )
      }
    }
  }
  
  return Preview()
}

struct InlineView: View {
  @State private var showSettings = false
  
  var body: some View {
    Button("View Settings") {
      showSettings = true
    }
    .sheet(isPresented: $showSettings) {
      SheetContent(title: "Standard")
        .presentationDetents([.medium, .fraction(0.2), .large])
    }
  }
}


@available(iOS 16.0, *)
#Preview("Sheet"){

  return InlineView()
}
