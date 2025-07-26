import SwiftUI
import UniformTypeIdentifiers

struct DragDropView: View {
    @EnvironmentObject var actionLogger: ActionLogger
    @State private var draggedItem: DraggableItem?
    @State private var dropZoneStates: [String: Bool] = [:]
    @State private var itemPositions: [String: CGPoint] = [
        "item1": CGPoint(x: 50, y: 50),
        "item2": CGPoint(x: 150, y: 50),
        "item3": CGPoint(x: 250, y: 50)
    ]
    @State private var droppedItems: [String: [DraggableItem]] = [
        "zone1": [],
        "zone2": [],
        "zone3": []
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                SectionHeader(title: "Drag & Drop Testing", icon: "hand.draw")
                
                // Draggable items
                GroupBox("Draggable Items") {
                    HStack(spacing: 30) {
                        ForEach(draggableItems) { item in
                            DraggableItemView(item: item)
                                .onDrag {
                                    self.draggedItem = item
                                    actionLogger.log(.drag, "Started dragging: \(item.name)")
                                    return NSItemProvider(object: item.id as NSString)
                                }
                                .accessibilityIdentifier("draggable-\(item.id)")
                        }
                        
                        Spacer()
                        
                        Button("Reset Items") {
                            resetItems()
                            actionLogger.log(.drag, "Reset all items to original positions")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("reset-drag-items")
                    }
                }
                
                // Drop zones
                GroupBox("Drop Zones") {
                    HStack(spacing: 20) {
                        ForEach(["zone1", "zone2", "zone3"], id: \.self) { zoneId in
                            DropZoneView(
                                zoneId: zoneId,
                                isTargeted: dropZoneStates[zoneId] ?? false,
                                droppedItems: droppedItems[zoneId] ?? []
                            )
                            .onDrop(of: [.text], isTargeted: Binding(
                                get: { dropZoneStates[zoneId] ?? false },
                                set: { targeted in
                                    dropZoneStates[zoneId] = targeted
                                    if targeted {
                                        actionLogger.log(.drag, "Hovering over \(zoneId)")
                                    }
                                }
                            )) { providers in
                                handleDrop(providers: providers, in: zoneId)
                            }
                            .accessibilityIdentifier("drop-\(zoneId)")
                        }
                    }
                }
                
                // Reorderable list
                GroupBox("Reorderable List") {
                    VStack(alignment: .leading) {
                        Text("Drag items to reorder:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        List {
                            ForEach(listItems) { item in
                                HStack {
                                    Image(systemName: "line.3.horizontal")
                                        .foregroundColor(.secondary)
                                    Text(item.name)
                                    Spacer()
                                    Text("#\(listItems.firstIndex(where: { $0.id == item.id })! + 1)")
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                                .accessibilityIdentifier("list-item-\(item.id)")
                            }
                            .onMove { source, destination in
                                listItems.move(fromOffsets: source, toOffset: destination)
                                actionLogger.log(.drag, "List reordered", 
                                               details: "Moved from \(source) to \(destination)")
                            }
                        }
                        .frame(height: 200)
                    }
                }
                
                // Free-form drag area
                GroupBox("Free-form Drag Area") {
                    ZStack {
                        // Background
                        Rectangle()
                            .fill(Color.gray.opacity(0.1))
                            .overlay(
                                Rectangle()
                                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                                    .foregroundColor(.gray)
                            )
                        
                        // Draggable elements
                        ForEach(Array(itemPositions.keys), id: \.self) { itemId in
                            if let position = itemPositions[itemId] {
                                FreeDraggableView(
                                    itemId: itemId,
                                    position: Binding(
                                        get: { position },
                                        set: { itemPositions[itemId] = $0 }
                                    )
                                ) { startPos, endPos in
                                    actionLogger.log(.drag, "Free drag completed", 
                                                   details: "Item: \(itemId), From: (\(Int(startPos.x)), \(Int(startPos.y))) To: (\(Int(endPos.x)), \(Int(endPos.y)))")
                                }
                            }
                        }
                    }
                    .frame(height: 300)
                    .accessibilityIdentifier("free-drag-area")
                }
                
                // Drag statistics
                if !droppedItems.values.flatMap({ $0 }).isEmpty {
                    GroupBox("Drag Statistics") {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(["zone1", "zone2", "zone3"], id: \.self) { zoneId in
                                if let items = droppedItems[zoneId], !items.isEmpty {
                                    HStack {
                                        Text("\(zoneId.capitalized):")
                                        Text(items.map { $0.name }.joined(separator: ", "))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    @State private var draggableItems = [
        DraggableItem(id: "1", name: "Item A", color: .blue),
        DraggableItem(id: "2", name: "Item B", color: .green),
        DraggableItem(id: "3", name: "Item C", color: .orange)
    ]
    
    @State private var listItems = [
        ListItem(id: "l1", name: "First Item"),
        ListItem(id: "l2", name: "Second Item"),
        ListItem(id: "l3", name: "Third Item"),
        ListItem(id: "l4", name: "Fourth Item"),
        ListItem(id: "l5", name: "Fifth Item")
    ]
    
    private func handleDrop(providers: [NSItemProvider], in zoneId: String) -> Bool {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { (data, error) in
                if let data = data as? Data, let itemId = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async {
                        if let item = self.draggableItems.first(where: { $0.id == itemId }) {
                            self.droppedItems[zoneId]?.append(item)
                            actionLogger.log(.drag, "Item dropped", 
                                           details: "\(item.name) dropped in \(zoneId)")
                        }
                    }
                }
            }
        }
        return true
    }
    
    private func resetItems() {
        droppedItems = [
            "zone1": [],
            "zone2": [],
            "zone3": []
        ]
        itemPositions = [
            "item1": CGPoint(x: 50, y: 50),
            "item2": CGPoint(x: 150, y: 50),
            "item3": CGPoint(x: 250, y: 50)
        ]
    }
}

struct DraggableItem: Identifiable {
    let id: String
    let name: String
    let color: Color
}

struct ListItem: Identifiable {
    let id: String
    let name: String
}

struct DraggableItemView: View {
    let item: DraggableItem
    
    var body: some View {
        VStack {
            Image(systemName: "square.fill")
                .font(.largeTitle)
                .foregroundColor(item.color)
            Text(item.name)
                .font(.caption)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct DropZoneView: View {
    let zoneId: String
    let isTargeted: Bool
    let droppedItems: [DraggableItem]
    
    var body: some View {
        VStack {
            Text(zoneId.capitalized)
                .font(.headline)
            
            if droppedItems.isEmpty {
                Text("Drop here")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                VStack(spacing: 5) {
                    ForEach(droppedItems) { item in
                        HStack {
                            Circle()
                                .fill(item.color)
                                .frame(width: 10, height: 10)
                            Text(item.name)
                                .font(.caption)
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 120, height: 120)
        .background(isTargeted ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isTargeted ? Color.accentColor : Color.gray, lineWidth: 2)
        )
    }
}

struct FreeDraggableView: View {
    let itemId: String
    @Binding var position: CGPoint
    let onDragEnded: (CGPoint, CGPoint) -> Void
    
    @State private var dragStartPosition: CGPoint = .zero
    
    var body: some View {
        Circle()
            .fill(Color.purple)
            .frame(width: 50, height: 50)
            .overlay(
                Text(String(itemId.suffix(1)))
                    .foregroundColor(.white)
                    .fontWeight(.bold)
            )
            .position(position)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if dragStartPosition == .zero {
                            dragStartPosition = position
                        }
                        position = CGPoint(
                            x: dragStartPosition.x + value.translation.width,
                            y: dragStartPosition.y + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        onDragEnded(dragStartPosition, position)
                        dragStartPosition = .zero
                    }
            )
    }
}