import SwiftUI

struct Frontend_iOS: View {
    @StateObject private var model = Model() // Manages maze state and logic

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // Maze view occupies most of the screen
                MazeView_iOS(model: model)
                    .edgesIgnoringSafeArea([.horizontal])
                
                // Controls panel slides up from bottom
                ControlsPanel_iOS(model: model)
            }
            .background(Color(UIColor.systemBackground).edgesIgnoringSafeArea(.all))
            .navigationTitle("Mazes")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
    }
}

struct MazeView_iOS: View {
    @ObservedObject var model: Model
    private let controllerPadding: CGFloat = 8 // Padding around the Metal view

    var body: some View {
        GeometryReader { geometryProxy in
            // Determine available space considering safe areas
            let availableWidth = geometryProxy.size.width
            let availableHeight = geometryProxy.size.height * 0.65 // Allow 65% of height for maze
            
            // Calculate square size based on available space
            let mazeDisplaySideLength = min(availableWidth, availableHeight) - 32 // Padding
            
            // Calculate controller size accounting for padding
            let controllerRenderSize = CGSize(
                width: mazeDisplaySideLength - 2 * controllerPadding,
                height: mazeDisplaySideLength - 2 * controllerPadding
            )

            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Material.regularMaterial) // iOS material background
                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                
                if controllerRenderSize.width > 0 && controllerRenderSize.height > 0 {
                    Controller(model: model)
                        .frame(width: controllerRenderSize.width, height: controllerRenderSize.height)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
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
            .position(
                x: geometryProxy.frame(in: .local).midX,
                y: geometryProxy.frame(in: .local).midY - 60 // Shift up to make room for controls
            )
        }
    }
}

// Combined control panel with generation on top and solving on bottom
struct ControlsPanel_iOS: View {
    @ObservedObject var model: Model
    
    var body: some View {
        VStack(spacing: 0) {
            // Generation section
            GenerationView(model: model)
            
            Divider()
                .padding(.vertical, 8)
            
            // Solver section
            SolverView(model: model)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Material.thin)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: -5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }
}

struct GenerationView: View {
    @ObservedObject var model: Model
    
    var body: some View {
        VStack(spacing: 12) {
            // Header and algorithm picker
            HStack {
                Text("Generation")
                    .font(.headline)
                
                Spacer()
                
                // Dropdown for algorithm selection
                Menu {
                    ForEach(MazeTypes.allCases) { type in
                        Button(action: {
                            if model.generationState == .idle {
                                model.currentMazeAlgorithm = type
                            }
                        }) {
                            HStack {
                                Text(type.rawValue)
                                if model.currentMazeAlgorithm == type {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(model.currentMazeAlgorithm.rawValue)
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                }
                .disabled(model.generationState != .idle)
            }
            
            // Generation controls
            switch model.generationState {
            case .idle:
                Button {
                    withAnimation {
                        model.startMazeGeneration()
                    }
                } label: {
                    Text("Generate New Maze")
                        .fontWeight(.semibold)
                        .frame(height: 44)
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)

            case .generating:
                VStack(spacing: 10) {
                    ProgressView("Generating...")
                        .progressViewStyle(.linear)
                        .padding(.bottom, 4)
                    
                    HStack(spacing: 12) {
                        Button {
                            model.pauseMazeGeneration()
                        } label: {
                            Label("Pause", systemImage: "pause.fill")
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color(UIColor.secondarySystemBackground))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)

                        Button {
                            model.stopMazeGeneration()
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.red.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            
            case .paused:
                VStack(spacing: 10) {
                    Text("Generation Paused")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                    
                    HStack(spacing: 12) {
                        Button {
                            model.resumeMazeGeneration()
                        } label: {
                            Label("Resume", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)

                        Button {
                            model.stopMazeGeneration()
                        } label: {
                            Label("Stop", systemImage: "stop.fill")
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.red.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

struct SolverView: View {
    @ObservedObject var model: Model
    
    var body: some View {
        VStack(spacing: 12) {
            // Header and algorithm picker
            HStack {
                Text("Solver")
                    .font(.headline)
                
                Spacer()
                
                // Dropdown for algorithm selection
                Menu {
                    ForEach(SolveTypes.allCases) { type in
                        Button(action: {
                            if model.generationState == .idle {
                                model.currentSolveAlgorithm = type
                            }
                        }) {
                            HStack {
                                Text(type.rawValue)
                                if model.currentSolveAlgorithm == type {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(model.currentSolveAlgorithm.rawValue)
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                }
                .disabled(model.generationState != .idle || model.solvingState != .idle || model.fillState != .idle)
            }
            
            // Solve button and controls
            switch model.solvingState {
            case .idle:
                Button {
                    model.startMazeSolving()
                } label: {
                    Text("Solve Maze")
                        .fontWeight(.semibold)
                        .frame(height: 44)
                        .frame(maxWidth: .infinity)
                        .background(model.generationState == .idle && model.fillState == .idle ? Color.accentColor : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(model.generationState != .idle || model.fillState != .idle)

            case .generating:
                VStack(spacing: 10) {
                    ProgressView("Solving Maze...")
                        .progressViewStyle(.linear)
                        .padding(.bottom, 4)
                    
                    HStack(spacing: 12) {
                        Button {
                            model.pauseMazeSolving()
                        } label: {
                            Label("Pause Solving", systemImage: "pause.fill")
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color(UIColor.secondarySystemBackground))
                                .foregroundColor(.primary)
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)

                        Button {
                            model.stopMazeSolving()
                        } label: {
                            Label("Stop Solving", systemImage: "stop.fill")
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.red.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            
            case .paused:
                VStack(spacing: 10) {
                    Text("Solving Paused")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 4)
                    
                    HStack(spacing: 12) {
                        Button {
                            model.resumeMazeSolving()
                        } label: {
                            Label("Resume Solving", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)

                        Button {
                            model.stopMazeSolving()
                        } label: {
                            Label("Stop Solving", systemImage: "stop.fill")
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.red.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
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
            .previewDevice("iPhone 13")
        
        Frontend_iOS()
            .preferredColorScheme(.dark)
            .previewDevice("iPhone 13")
            .previewDisplayName("Dark Mode")
    }
}
#endif
