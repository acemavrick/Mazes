//
//  MazeAlgorithmPickerView.swift
//  Mazes
//
//  Created by acemavrick on 6/13/25.
//

import SwiftUI

struct MazeAlgorithmOptionView: View {
    @ObservedObject var model: Model
    var type: MazeTypes
    
    @State private var hovering: Bool = false
    
    var isSelected: Bool {
        model.currentMazeAlgorithm == type
    }
    
    var borderColor : Color {
        if hovering { return .accent }
        if isSelected {return .accentLight}
        return Color(NSColor.separatorColor)
    }
    
    var body: some View {
        Button(action: {
            if model.generationState == .idle {
                withAnimation {
                    model.currentMazeAlgorithm = type
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
        }
    }
}

// Helper View for Maze Algorithm Picker
struct MazeAlgorithmPickerView: View {
    @ObservedObject var model: Model

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(MazeTypes.allCases) { type in
                MazeAlgorithmOptionView(model: model, type: type)
                    .buttonStyle(.plain)
                    .disabled(model.generationState != .idle)
            }
        }
    }
}

// Helper View for Generation Controls
struct GenerationControlsButtonView: View {
    @ObservedObject var model: Model
    
    @State var hovering: Bool = false

    var body: some View {
        Group {
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
                .tint(.accent)
                .scaleEffect(hovering ? 1.03 : 1)
                
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
            } // end switch
        } // end group
        .onHover { inside in
            withAnimation {
                hovering = inside
            }
        }
    } // end body
}
