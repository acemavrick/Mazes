import SwiftUI

struct Frontend_iOS: View {
    @StateObject private var model = Model() // Manages maze state and logic

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                MazeView_iOS(model: model)
                    .layoutPriority(1) // Give more space to the maze

                ControlsView_iOS(model: model)
                    .frame(maxHeight: .infinity, alignment: .bottom) // Push controls to bottom
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Mazes")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack) // Use stack style for a more standard iOS appearance
    }
}

struct MazeView_iOS: View {
    @ObservedObject var model: Model
    private let controllerPadding: CGFloat = 8 // Padding around the Metal view

    var body: some View {
        GeometryReader { geometryProxyOfAllocatedSpace in
            let mazeDisplaySideLength = min(geometryProxyOfAllocatedSpace.size.width, geometryProxyOfAllocatedSpace.size.height) - 2 * 16 // 16 for overall padding
            
            let controllerRenderSize = CGSize(
                width: max(0, mazeDisplaySideLength - 2 * controllerPadding),
                height: max(0, mazeDisplaySideLength - 2 * controllerPadding)
            )

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Material.regular) // iOS-style material background
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                
                if controllerRenderSize.width > 0 && controllerRenderSize.height > 0 {
                    Controller(model: model) // Assuming Controller is your UIViewRepresentable for MTKView
                        .frame(width: controllerRenderSize.width, height: controllerRenderSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: 12 - controllerPadding)) // Clip MTKView to inner bounds
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    // Ensure tap is within the controller's bounds
                                    if value.location.x >= 0 && value.location.x <= controllerRenderSize.width &&
                                       value.location.y >= 0 && value.location.y <= controllerRenderSize.height {
                                        model.handleMazeTap(at: value.location, in: controllerRenderSize)
                                    }
                                }
                        )
                } else {
                    Text("View too small")
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: mazeDisplaySideLength, height: mazeDisplaySideLength)
            .frame(width: geometryProxyOfAllocatedSpace.size.width, height: geometryProxyOfAllocatedSpace.size.height) // Center in available space
            .animation(.default, value: mazeDisplaySideLength)
        }
        .padding(.vertical, 16) // Add some vertical padding for the whole MazeView container
        .padding(.horizontal, 16)
    }
}

struct ControlsView_iOS: View {
    @ObservedObject var model: Model

    var body: some View {
        VStack(spacing: 16) {
            // Maze Type Picker
            Picker("Algorithm", selection: $model.currentOption) {
                ForEach(Maze.MazeTypes.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented) // A common iOS picker style for few options
            .disabled(model.generationState != .idle)

            // Conditional Controls based on generation state
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

            case .generating:
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Button {
                            model.pauseMazeGeneration()
                        } label: {
                            Label("Pause", systemImage: "pause.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)

                        Button {
                            model.stopMazeGeneration()
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .controlSize(.large)
                    }
                    ProgressView("Generating Maze...")
                        .progressViewStyle(.linear)
                        .padding(.vertical, 5)
                }
            
            case .paused:
                VStack(spacing: 10) {
                    Text("Generation Paused")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                    HStack(spacing: 10) {
                        Button {
                            model.resumeMazeGeneration()
                        } label: {
                            Label("Resume", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Button {
                            model.stopMazeGeneration()
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .controlSize(.large)
                    }
                }
            }
            
            // Placeholder for future solver controls
            DisclosureGroup("Solver Options (Coming Soon)") {
                Text("Pathfinding controls will appear here in a future update.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            .disabled(true) // Disable until implemented

        }
        .padding()
        .background(.thinMaterial) // Modern translucent background for the control panel
        .cornerRadius(16, corners: [.topLeft, .topRight]) // Round top corners if against bottom edge
        .animation(.easeInOut(duration: 0.2), value: model.generationState)
    }
}

// Helper for rounding specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}


#if DEBUG
struct Frontend_iOS_Previews: PreviewProvider {
    static var previews: some View {
        Frontend_iOS()
            .preferredColorScheme(.dark) // Example with dark mode
        
        Frontend_iOS()
            .preferredColorScheme(.light) // Example with light mode
            .previewDisplayName("Frontend_iOS Light")
    }
}
#endif
