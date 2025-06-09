import SwiftUI

struct Frontend_iOS: View {
    @StateObject private var model = Model() // Manages maze state and logic

    var body: some View {
        // todo add an info/help button on the top right, navlink to an info page
        VStack() {
            // todo make the maze dimensions match the screen
            MazeView_iOS(model: model)
                .padding(5)

            // todo make this panel collapsible
            ControlsPanel_iOS(model: model)
        }
        .background(.mazeBG)
        // we can do bottom bc never allow app to be upside down (no dynamic island)
        .ignoresSafeArea(edges: .bottom)
    }
}

struct MazeView_iOS: View {
    @ObservedObject var model: Model
    private let controllerPadding: CGFloat = 5 // Padding around the Metal view

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
            
            // todo fix tap gesture to work without GeometryReader

            ZStack {
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.mazeBG)
                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                
                    Controller(model: model)
                    .padding(6)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onEnded { value in
                                    if value.location.x >= 0 && value.location.x <= controllerRenderSize.width &&
                                       value.location.y >= 0 && value.location.y <= controllerRenderSize.height {
                                        model.handleMazeTap(at: value.location, in: controllerRenderSize)
                                    }
                                }
                        )
            }
        }
    }
}

// Combined control panel with generation on top and solving on bottom
// todo fix to be on the left side when ipad is in landscape
struct ControlsPanel_iOS: View {
    @ObservedObject var model: Model
    
    var body: some View {
        VStack(spacing: 0) {
            GenerationView(model: model)
            
            Divider()
                .padding(.vertical, 8)
            
            // Solver section
            SolverView(model: model)
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 30)
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
        VStack (alignment: .leading) {
            // Algorithm Picker
            HStack {
                // Dropdown for algorithm selection
                Text("Algorithm:")
                    .font(.headline)
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
                    HStack {
                        Text(model.currentMazeAlgorithm.rawValue)
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundStyle(.accent)
                    .padding(.vertical, 6)
                }
                .disabled(model.generationState != .idle)
                
                switch model.generationState {
                case .generating:
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("Generating...")
                        .font(.footnote)
                case .paused:
                    Image(systemName: "pause.fill")
                        .font(.footnote)
                    Text("Paused")
                        .font(.footnote)
                default:
                    EmptyView()
                }
            }
            .padding(.trailing)
            switch model.generationState {
            case .idle:
                Button {
                    model.startMazeGeneration()
                } label: {
                    Text("Generate New Maze")
                        .fontWeight(.semibold)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.accentLight)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

            case .generating:
                    HStack(spacing: 12) {
                        Button {
                            model.pauseMazeGeneration()
                        } label: {
                            Image(systemName: "pause.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(.accentLight)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation {
                                model.stopMazeGeneration()
                            }
                        } label: {
                            Image(systemName: "stop.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.red.opacity(0.8))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                }
            
            case .paused:
                HStack(spacing: 12) {
                    Button {
                        model.resumeMazeGeneration()
                    } label: {
                        Image(systemName: "play.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.accentLight)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        withAnimation {
                            model.stopMazeGeneration()
                        }
                    } label: {
                        Image(systemName: "stop.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.8))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct SolverView: View {
    @ObservedObject var model: Model
    
    var body: some View {
        VStack(alignment: .leading) {
            // Header and algorithm picker
            HStack {
                Text("Solver: ")
                    .font(.headline)
                
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
                    HStack {
                        Text(model.currentSolveAlgorithm.rawValue)
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundStyle(.accent)
                    .padding(.vertical, 6)
                }
                .disabled(model.generationState != .idle || model.solvingState != .idle || model.fillState != .idle)
                
                switch model.solvingState {
                case .generating:
                    ProgressView()
                        .progressViewStyle(.circular)
                    Text("Solving...")
                        .font(.footnote)
                case .paused:
                    Image(systemName: "pause.fill")
                        .font(.footnote)
                    Text("Paused")
                        .font(.footnote)
                default:
                    EmptyView()
                }
            }
            // Solve button and controls
            switch model.solvingState {
            case .idle:
                Button {
                    model.startMazeSolving()
                } label: {
                    Text("Solve Maze")
                        .fontWeight(.semibold)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(.accentLight)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(model.generationState != .idle || model.fillState != .idle)

            case .generating:
                HStack(spacing: 12) {
                    
                    Button {
                        model.pauseMazeSolving()
                    } label: {
                        Image(systemName: "pause.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.accentLight)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        withAnimation {
                            model.stopMazeSolving()
                        }
                    } label: {
                        Image(systemName: "stop.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.8))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            
            case .paused:
                HStack(spacing: 12) {
                    Button {
                        model.resumeMazeSolving()
                    } label: {
                        Image(systemName: "play.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.accentLight)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        model.stopMazeSolving()
                    } label: {
                        Image(systemName: "stop.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.red.opacity(0.8))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

#Preview {
    Frontend_iOS()
}
