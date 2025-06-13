//
//  SolverAlgorithmPickerView.swift
//  Mazes
//
//  Created by acemavrick on 6/13/25.
//


import SwiftUI

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
                    .background(model.currentSolveAlgorithm == type ? Color.accentLight : Color(NSColor.controlBackgroundColor))
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(model.currentSolveAlgorithm == type ? 0.1 : 0.05), radius: model.currentSolveAlgorithm == type ? 3 : 1, x: 0, y: model.currentSolveAlgorithm == type ? 2 : 1)
                }
                .buttonStyle(.plain)
                .disabled(model.generationState != .idle)
            }
        }
    }
}

struct SolverControlsButtonView: View {
    @ObservedObject var model: Model
    
    var body: some View {
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
            .tint(.accentLight)
        
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
}
