import SwiftUI

struct ScrollTestingView: View {
    @EnvironmentObject var actionLogger: ActionLogger
    @State private var scrollPosition: CGPoint = .zero
    @State private var lastGesture = ""
    @State private var magnification: CGFloat = 1.0
    @State private var rotation: Angle = .zero
    
    var body: some View {
        VStack(spacing: 20) {
            SectionHeader(title: "Scroll & Gesture Testing", icon: "scroll")
            
            HStack(spacing: 20) {
                // Vertical scroll
                GroupBox("Vertical Scroll") {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(spacing: 10) {
                                ForEach(1..<31) { index in
                                    HStack {
                                        Text("Item \(index)")
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Spacer()
                                        Image(systemName: "\(index).circle")
                                    }
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                    .id(index)
                                    .onAppear {
                                        if index == 1 || index == 15 || index == 30 {
                                            actionLogger.log(.scroll, "Visible item: \(index)")
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                        .frame(height: 300)
                        .background(Color(NSColor.controlBackgroundColor))
                        .accessibilityIdentifier("vertical-scroll")
                        
                        HStack {
                            Button("Top") {
                                withAnimation {
                                    proxy.scrollTo(1, anchor: .top)
                                }
                                actionLogger.log(.scroll, "Scrolled to top")
                            }
                            .accessibilityIdentifier("scroll-to-top")
                            
                            Button("Middle") {
                                withAnimation {
                                    proxy.scrollTo(15, anchor: .center)
                                }
                                actionLogger.log(.scroll, "Scrolled to middle")
                            }
                            .accessibilityIdentifier("scroll-to-middle")
                            
                            Button("Bottom") {
                                withAnimation {
                                    proxy.scrollTo(30, anchor: .bottom)
                                }
                                actionLogger.log(.scroll, "Scrolled to bottom")
                            }
                            .accessibilityIdentifier("scroll-to-bottom")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                
                // Horizontal scroll
                GroupBox("Horizontal Scroll") {
                    VStack {
                        ScrollView(.horizontal) {
                            HStack(spacing: 10) {
                                ForEach(1..<21) { index in
                                    VStack {
                                        Image(systemName: "photo")
                                            .font(.largeTitle)
                                        Text("Image \(index)")
                                            .font(.caption)
                                    }
                                    .frame(width: 100, height: 100)
                                    .background(Color.purple.opacity(0.2))
                                    .cornerRadius(8)
                                    .onAppear {
                                        if index == 1 || index == 10 || index == 20 {
                                            actionLogger.log(.scroll, "Horizontal item visible: \(index)")
                                        }
                                    }
                                }
                            }
                            .padding()
                        }
                        .frame(height: 150)
                        .background(Color(NSColor.controlBackgroundColor))
                        .accessibilityIdentifier("horizontal-scroll")
                    }
                }
            }
            
            // Gesture testing area
            GroupBox("Gesture Testing") {
                HStack(spacing: 20) {
                    // Swipe gestures
                    GestureArea(
                        title: "Swipe Area",
                        color: .green,
                        identifier: "swipe-area"
                    ) {
                        Image(systemName: "hand.draw")
                            .font(.largeTitle)
                    }
                    .onTapGesture {
                        actionLogger.log(.gesture, "Tap on swipe area")
                    }
                    .gesture(
                        DragGesture(minimumDistance: 30)
                            .onEnded { value in
                                let horizontal = abs(value.translation.width)
                                let vertical = abs(value.translation.height)
                                
                                if horizontal > vertical {
                                    let direction = value.translation.width > 0 ? "right" : "left"
                                    actionLogger.log(.gesture, "Swipe \(direction)", 
                                                   details: "Distance: \(Int(horizontal))px")
                                } else {
                                    let direction = value.translation.height > 0 ? "down" : "up"
                                    actionLogger.log(.gesture, "Swipe \(direction)", 
                                                   details: "Distance: \(Int(vertical))px")
                                }
                            }
                    )
                    
                    // Pinch/Zoom
                    GestureArea(
                        title: "Pinch/Zoom",
                        color: .orange,
                        identifier: "pinch-area"
                    ) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.largeTitle)
                            .scaleEffect(magnification)
                    }
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                magnification = value
                            }
                            .onEnded { value in
                                actionLogger.log(.gesture, "Pinch gesture ended", 
                                               details: "Scale: \(String(format: "%.2f", value))x")
                                withAnimation {
                                    magnification = 1.0
                                }
                            }
                    )
                    
                    // Rotation
                    GestureArea(
                        title: "Rotation",
                        color: .blue,
                        identifier: "rotation-area"
                    ) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.largeTitle)
                            .rotationEffect(rotation)
                    }
                    .gesture(
                        RotationGesture()
                            .onChanged { angle in
                                rotation = angle
                            }
                            .onEnded { angle in
                                actionLogger.log(.gesture, "Rotation gesture ended", 
                                               details: "Angle: \(Int(angle.degrees))°")
                                withAnimation {
                                    rotation = .zero
                                }
                            }
                    )
                    
                    // Long press
                    GestureArea(
                        title: "Long Press",
                        color: .red,
                        identifier: "long-press-area"
                    ) {
                        Image(systemName: "hand.tap.fill")
                            .font(.largeTitle)
                    }
                    .onLongPressGesture(minimumDuration: 1.0) {
                        actionLogger.log(.gesture, "Long press detected", 
                                       details: "Duration: 1.0s")
                    }
                }
            }
            
            // Nested scroll views
            GroupBox("Nested Scroll Views") {
                ScrollView {
                    VStack(spacing: 10) {
                        Text("Outer scroll view")
                            .font(.headline)
                        
                        ScrollView {
                            VStack(spacing: 5) {
                                ForEach(1..<11) { index in
                                    Text("Inner item \(index)")
                                        .padding(.horizontal)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                        }
                        .frame(height: 150)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                        .accessibilityIdentifier("nested-inner-scroll")
                        
                        ForEach(1..<6) { index in
                            Text("Outer item \(index)")
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                }
                .frame(height: 200)
                .background(Color(NSColor.controlBackgroundColor))
                .accessibilityIdentifier("nested-outer-scroll")
            }
            
            Spacer()
        }
        .padding()
    }
}

struct GestureArea: View {
    let title: String
    let color: Color
    let identifier: String
    let content: () -> AnyView
    
    init(title: String, color: Color, identifier: String, @ViewBuilder content: @escaping () -> some View) {
        self.title = title
        self.color = color
        self.identifier = identifier
        self.content = { AnyView(content()) }
    }
    
    var body: some View {
        VStack {
            content()
            Text(title)
                .font(.caption)
                .padding(.top, 5)
        }
        .frame(width: 120, height: 120)
        .background(color.opacity(0.2))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(color, lineWidth: 2)
        )
        .accessibilityIdentifier(identifier)
    }
}