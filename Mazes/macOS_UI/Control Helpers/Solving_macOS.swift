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
                    .disabled(model.solvingState != .idle)
            }
        }
    }
}

struct SolverControlsButtonView: View {
    @ObservedObject var model: Model
    
    @State var hovering1: Bool = false
    @State var hovering2: Bool = false

    var body: some View {
        switch model.solvingState {
        case .idle:
            //        case .paused:
            Button {
                withAnimation {
                    model.startMazeSolving()
                }
            } label: {
                Label("Solve Maze", systemImage: "location.north.line.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .tint(.accent)
            .scaleEffect(hovering1 ? 1.03 : 1)
            .onHover { hovering in
                withAnimation {
                    self.hovering1 = hovering
                }
            }
            
        case .working:
            HStack {
                Button {
                    model.pauseMazeSolving()
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.accent)
                .scaleEffect(hovering1 ? 1.03 : 1)
                .onHover { hovering in
                    withAnimation {
                        self.hovering1 = hovering
                    }
                }
                
                Button {
                    model.stopMazeSolving()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.red)
                .scaleEffect(hovering2 ? 1.03 : 1)
                .onHover { hovering in
                    withAnimation {
                        self.hovering2 = hovering
                    }
                }
            } // end hstack
            
        case .paused:
            HStack {
                Button {
                    model.resumeMazeSolving()
                } label: {
                    Label("Resume", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.accent)
                .scaleEffect(hovering1 ? 1.03 : 1)
                .onHover { hovering in
                    withAnimation {
                        self.hovering1 = hovering
                    }
                }
                
                Button {
                    model.stopMazeSolving()
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(.red)
                .scaleEffect(hovering2 ? 1.03 : 1)
                .onHover { hovering in
                    withAnimation {
                        self.hovering2 = hovering
                    }
                }
            }
        } // end switch
    } // end body
}
