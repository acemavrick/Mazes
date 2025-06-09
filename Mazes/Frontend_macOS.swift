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

// Helper View for Maze Algorithm Picker
struct MazeAlgorithmPickerView: View {
    @ObservedObject var model: Model

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(MazeTypes.allCases) { type in
                Button(action: {
                    if model.generationState == .idle {
                        model.currentMazeAlgorithm = type
                    }
                }) {
                    HStack {
                        Text(type.rawValue)
                            .foregroundColor(model.currentMazeAlgorithm == type ? .white : .primary)
                        Spacer()
                        if model.currentMazeAlgorithm == type {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(model.currentMazeAlgorithm == type ? Color.green : Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(model.currentMazeAlgorithm == type ? 0.1 : 0.05), radius: model.currentMazeAlgorithm == type ? 3 : 1, x: 0, y: model.currentMazeAlgorithm == type ? 2 : 1)
                }
                .buttonStyle(.plain)
                .disabled(model.generationState != .idle)
            }
        }
    }
}

// Helper View for Solver Algorithm Picker
struct SolverAlgorithmPickerView: View {
    @ObservedObject var model: Model

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(SolveTypes.allCases) { type in
                Button(action: {
                    if model.generationState == .idle {
                        model.currentSolveAlgorithm = type
                    }
                }) {
                    HStack {
                        Text(type.rawValue)
                            .foregroundColor(model.currentSolveAlgorithm == type ? .white : .primary)
                        Spacer()
                        if model.currentSolveAlgorithm == type {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(model.currentSolveAlgorithm == type ? Color.green : Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(model.currentSolveAlgorithm == type ? 0.1 : 0.05), radius: model.currentSolveAlgorithm == type ? 3 : 1, x: 0, y: model.currentSolveAlgorithm == type ? 2 : 1)
                }
                .buttonStyle(.plain)
                .disabled(model.generationState != .idle)
            }
        }
    }
}

// Helper View for Generation Controls
struct GenerationControlsView: View {
    @ObservedObject var model: Model

    var body: some View {
        switch model.generationState {
        case .idle:
            Button {
                withAnimation {
                    model.startMazeGeneration()
                }
            } label: {
                Label("Generate New Maze", systemImage: "wand.and.sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .tint(Color.green)

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
                    .tint(Color.green)

                    Button {
                        model.stopMazeGeneration()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .tint(.red)
                }
                ProgressView("Generating Maze...")
                    .progressViewStyle(.linear)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
            }
        
        case .paused:
            VStack(spacing: 10) {
                HStack {
                    Button {
                        model.resumeMazeGeneration()
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .tint(Color.green)

                    Button {
                        model.stopMazeGeneration()
                    } label: {
                        Label("Stop", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .controlSize(.large)
                    .tint(.red)
                }
                Text("Generation Paused")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 5)
            }
        }
    }
}

struct ControlsView: View {
    @ObservedObject var model: Model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Maze Configuration Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Maze Configuration")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Algorithm:")
                        .font(.headline)
                        .padding(.bottom, 2)
                    
                    MazeAlgorithmPickerView(model: model)
                        .padding(.bottom, 10)

                    GenerationControlsView(model: model)
                }

                Divider()
                    .padding(.vertical, 10)

                // Solver Options Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Solver Options")
                        .font(.headline)

                    SolverAlgorithmPickerView(model: model)
                        .padding(.bottom, 10)

                    // Dynamic Solver Controls based on model.solvingState
                    switch model.solvingState {
                    case .idle:
                        Button {
                            model.startMazeSolving()
                        } label: {
                            Label("Solve Maze", systemImage: "figure.walk.motion")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent) // Changed to borderedProminent for consistency
                        .controlSize(.large)
                        .disabled(model.generationState != .idle || model.fillState != .idle) // Disable if generating or filling
                        .tint(Color.green)
                    
                    case .generating: // Actively solving
                        VStack(spacing: 10) {
                            HStack {
                                Button {
                                    model.pauseMazeSolving()
                                } label: {
                                    Label("Pause Solving", systemImage: "pause.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .controlSize(.large)
                                .tint(Color.orange) // Use orange for pause

                                Button {
                                    model.stopMazeSolving()
                                } label: {
                                    Label("Stop Solving", systemImage: "stop.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .controlSize(.large)
                                .tint(.red)
                            }
                            ProgressView("Solving Maze...")
                                .progressViewStyle(.linear)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                        }

                    case .paused: // Solving is paused
                        VStack(spacing: 10) {
                            HStack {
                                Button {
                                    model.resumeMazeSolving()
                                } label: {
                                    Label("Resume Solving", systemImage: "play.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .controlSize(.large)
                                .tint(Color.green)

                                Button {
                                    model.stopMazeSolving()
                                } label: {
                                    Label("Stop Solving", systemImage: "stop.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .controlSize(.large)
                                .tint(.red)
                            }
                            Text("Solving Paused")
                                .font(.headline)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 5)
                        }
                    }
                }
                
                Spacer()
            }
            .padding() // Apply padding to the content within the ScrollView
        }
        .background(.thinMaterial)
        .animation(.easeInOut(duration: 0.2), value: model.generationState)
        .animation(.easeInOut(duration: 0.2), value: model.solvingState) // Add animation for solvingState changes
    }
}

// Preview for Xcode Canvas
#Preview {
        Frontend_macOS()
}
