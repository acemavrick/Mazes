//
//  Frontend_macOS.swift
//  Mazes
//
//  Created by acemavrick on 5/16/25.
//  Rewritten by Cascade on 2025-05-20.
//

import SwiftUI

struct Frontend_macOS: View {
    @StateObject private var model = Model() // Manages maze state and logic

    var body: some View {
        HSplitView {
            // Maze View (Primary Content)
            MazeView(model: model)
                .layoutPriority(1) // Ensures MazeView gets more space if available

            // Controls Panel (Secondary Content)
            ControlsView(model: model)
                .frame(minWidth: 220, idealWidth: 260, maxWidth: 350) // Define size constraints for the control panel
        }
        .navigationTitle("Mazes") // Sets the window title
        .frame(minWidth: 700, minHeight: 500) // Suggest a minimum window size for usability
    }
}

struct MazeView: View {
    @ObservedObject var model: Model
    @Environment(\.displayScale) var displayScale: CGFloat
    private let controllerPadding: CGFloat = 8 // Padding around the Metal view, inside the rounded rect

    var body: some View {
        GeometryReader { geometryProxyOfAllocatedSpace in
            // Determine the largest possible square side length within the allocated space
            let mazeDisplaySideLength = min(geometryProxyOfAllocatedSpace.size.width, geometryProxyOfAllocatedSpace.size.height)
            
            // The actual size of the Controller's renderable area
            let controllerRenderSize = CGSize(
                width: mazeDisplaySideLength - 2 * controllerPadding,
                height: mazeDisplaySideLength - 2 * controllerPadding
            )

            ZStack {
                // Background for the maze container
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.textBackgroundColor)) // A standard background color for content areas
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3) // A slightly more pronounced shadow
                
                // The Controller (MTKView)
                if controllerRenderSize.width > 0 && controllerRenderSize.height > 0 { // Ensure valid size before creating Controller
                    Controller(model: model)
                        .frame(width: controllerRenderSize.width, height: controllerRenderSize.height)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    if value.location.x >= 0 && value.location.x <= controllerRenderSize.width &&
                                        value.location.y >= 0 && value.location.y <= controllerRenderSize.height {
                                        model.handleMazeTap(at: value.location, in: controllerRenderSize)
                                    }
                                })
                } else {
                    // Placeholder if the size is too small to render
                    Text("Window too small")
                        .foregroundColor(.secondary)
                }
            }
            // Frame the ZStack (maze container) to be square and centered
            .frame(width: mazeDisplaySideLength, height: mazeDisplaySideLength)
            // Center the square ZStack within the available geometryProxyOfAllocatedSpace
            .frame(width: geometryProxyOfAllocatedSpace.size.width, height: geometryProxyOfAllocatedSpace.size.height)
            .animation(.default, value: mazeDisplaySideLength) // Animate size changes
        }
        .padding() // Padding around the entire MazeView content
        .background(Color(NSColor.windowBackgroundColor).ignoresSafeArea()) // Background for the MazeView panel
    }
}

// Preview for Xcode Canvas
#Preview {
    Frontend_macOS()
}
