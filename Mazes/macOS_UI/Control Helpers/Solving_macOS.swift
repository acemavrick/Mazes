//
//  SolverAlgorithmPickerView.swift
//  Mazes
//
//  Created by acemavrick on 6/13/25.
//


import SwiftUI

struct SolverAlgorithmOptionView: View {
    @ObservedObject var model: Model
    var type: SolveTypes
    
    @State private var hovering: Bool = false
    
    var isSelected: Bool {
        model.currentSolveAlgorithm == type
    }
    
    var borderColor: Color {
        if hovering { return .accent }
        if isSelected {return .accentLight }
        return Color(NSColor.separatorColor)
    }

    var body: some View {
        Button(action: {
            if model.solvingState == .idle {
                withAnimation {
                    model.currentSolveAlgorithm = type
                }
            }
        }) {
            HStack {
                Text(type.rawValue)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.accentLight)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? .accentLight : .accent)
                    .opacity(hovering || isSelected ? 0.2 : 0)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: hovering ? 1.5 : 1)
            )
            .onHover { ishovering in
                withAnimation {
                    hovering = ishovering
                }
            }
            .shadow(color: Color.black.opacity(isSelected ? 0.1 : 0.05), radius: isSelected ? 3 : 1, x: 0, y: isSelected ? 2 : 1)
        } // end button
    }
}

struct SolverAlgorithmPickerView: View {
    @ObservedObject var model: Model
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(SolveTypes.allCases) { type in
                SolverAlgorithmOptionView(model: model, type: type)
                    .buttonStyle(.plain)
                    .disabled(model.generationState != .idle)
            }
        }
    }
}

struct SolverControlsButtonView: View {
    @ObservedObject var model: Model
    
    @State var hovering: Bool = false
    
    var body: some View {
        Group {
            switch model.solvingState {
            case .idle:
                Button {
                    withAnimation {
                        model.startMazeSolving()
                    }
                } label: {
                    Label("Solve Maze", systemImage: "figure.walk.motion")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(model.generationState != .idle || model.fillState != .idle)
                .tint(.accent)
                .scaleEffect(hovering ? 1.03 : 1)
                
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
                } // end case .paused
            } // end switch
        } // end group
        .onHover { inside in
            withAnimation {
                hovering = inside
            }
        }
    } // end body
}

