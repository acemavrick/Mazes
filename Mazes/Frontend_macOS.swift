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

struct ControlsView: View {
    @ObservedObject var model: Model

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Maze Configuration")
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.bottom, 8)

            // Maze Type Picker - Modernized
            Text("Algorithm:")
                .font(.headline)
                .padding(.bottom, 2)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Maze.MazeTypes.allCases) { type in
                    Button(action: {
                        if model.generationState == .idle {
                            model.currentOption = type
                        }
                    }) {
                        HStack {
                            Text(type.rawValue)
                                .foregroundColor(model.currentOption == type ? .white : .primary)
                            Spacer()
                            if model.currentOption == type {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(model.currentOption == type ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(model.currentOption == type ? 0.1 : 0.05), radius: model.currentOption == type ? 3 : 1, x: 0, y: model.currentOption == type ? 2 : 1)
                    }
                    .buttonStyle(.plain) // Use .plain to allow full background customization
                    .disabled(model.generationState != .idle)
                }
            }
            .padding(.bottom, 10) // Add some space after the picker

            // Conditional Controls based on generation state
            switch model.generationState {
            case .idle:
                Button {
                    withAnimation {
                        model.startMazeGeneration() // Call the new method
                    }
                } label: {
                    Label("Generate New Maze", systemImage: "wand.and.sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)

            case .generating:
                VStack(spacing: 10) {
                    HStack {
                        Button {
                            model.pauseMazeGeneration()
                        } label: {
                            Label("Pause", systemImage: "pause.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)

                        Button {
                            model.stopMazeGeneration()
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                        .tint(.red) // Make stop button visually distinct
                    }
                    ProgressView("Generating Maze...")
                        .progressViewStyle(.linear)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }
            
            case .paused:
                VStack(spacing: 10) {
                    Text("Generation Paused")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 5)
                    HStack {
                        Button {
                            model.resumeMazeGeneration()
                        } label: {
                            Label("Resume", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)

                        Button {
                            model.stopMazeGeneration()
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .controlSize(.large)
                        .tint(.red)
                    }
                }
            }

            Divider()
                .padding(.vertical, 10)

            // Placeholder for future controls (e.g., solver)
            Group {
                Text("Solver Options")
                    .font(.headline)
                Text("Pathfinding controls will appear here in a future update.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer() // Pushes controls to the top
        }
        .padding()
        .background(.thinMaterial) // Modern translucent background for the control panel
        .animation(.easeInOut(duration: 0.2), value: model.generationState) // Animate state changes smoothly
    }
}

// Preview for Xcode Canvas
#if DEBUG
struct Frontend_macOS_Previews: PreviewProvider {
    static var previews: some View {
        Frontend_macOS()
    }
}
#endif
