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
                ControlsView_iOS(model: model)
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
            .animation(.default, value: mazeDisplaySideLength)
        }
    }
}

struct ControlsView_iOS: View {
    @ObservedObject var model: Model
    @State private var selectedTab = 0 // 0 = Generate, 1 = Solve
    
    var body: some View {
        VStack(spacing: 0) {
            // Tab selector
            Picker("Options", selection: $selectedTab) {
                Text("Generate").tag(0)
                Text("Solve").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 12)
            
            // Dynamic content based on selected tab
            if selectedTab == 0 {
                GenerationView(model: model)
            } else {
                SolverView(model: model)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Material.thin)
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: -5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .animation(.spring(), value: selectedTab)
    }
}

struct GenerationView: View {
    @ObservedObject var model: Model
    @State private var showAlgorithmPicker = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Algorithm selection button
            Button {
                withAnimation {
                    showAlgorithmPicker.toggle()
                }
            } label: {
                HStack {
                    Text("Algorithm: \(model.currentMazeAlgorithm.rawValue)")
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: showAlgorithmPicker ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(model.generationState != .idle)
            .padding(.horizontal)
            
            // Expandable algorithm picker
            if showAlgorithmPicker {
                MazeAlgorithmPickerView_iOS(model: model)
                    .padding(.horizontal)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
            
            // Generation controls
            GenerationControlsView_iOS(model: model)
                .padding(.horizontal)
                .padding(.bottom, 8)
                .padding(.top, showAlgorithmPicker ? 0 : 8)
            
            // Status bar area - safe area padding
            Color.clear
                .frame(height: 16)
        }
        .padding(.top, 8)
    }
}

struct SolverView: View {
    @ObservedObject var model: Model
    @State private var showAlgorithmPicker = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Algorithm selection button
            Button {
                withAnimation {
                    showAlgorithmPicker.toggle()
                }
            } label: {
                HStack {
                    Text("Algorithm: \(model.currentSolveAlgorithm.rawValue)")
                        .fontWeight(.medium)
                    Spacer()
                    Image(systemName: showAlgorithmPicker ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(model.generationState != .idle)
            .padding(.horizontal)
            
            // Expandable algorithm picker
            if showAlgorithmPicker {
                SolverAlgorithmPickerView_iOS(model: model)
                    .padding(.horizontal)
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
            
            // Solve button
            Button {
                model.startMazeSolving()
            } label: {
                Text("Solve Maze")
                    .fontWeight(.semibold)
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(model.generationState == .idle ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .disabled(model.generationState != .idle)
            .padding(.horizontal)
            .padding(.bottom, model.generationState == .idle ? 24 : 8)
            
            // Instructions for BFS tap solving
            if model.currentSolveAlgorithm == .bfs && model.generationState == .idle {
                HStack {
                    Image(systemName: "hand.tap.fill")
                        .foregroundColor(.secondary)
                    Text("Tap the maze to fill from that point")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 24)
            }
            
            // Status bar area - safe area padding
            Color.clear
                .frame(height: 16)
        }
        .padding(.top, 8)
    }
}

struct MazeAlgorithmPickerView_iOS: View {
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
                            Image(systemName: "checkmark")
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(model.currentMazeAlgorithm == type ? Color.blue : Color.clear)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(model.generationState != .idle)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemBackground))
        )
        .padding(.bottom, 4)
    }
}

struct SolverAlgorithmPickerView_iOS: View {
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
                            Image(systemName: "checkmark")
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(model.currentSolveAlgorithm == type ? Color.blue : Color.clear)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(model.generationState != .idle)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemBackground))
        )
        .padding(.bottom, 4)
    }
}

struct GenerationControlsView_iOS: View {
    @ObservedObject var model: Model

    var body: some View {
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
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)

        case .generating:
            VStack(spacing: 10) {
                ProgressView("Generating Maze...")
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
                            .background(Color.blue)
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
