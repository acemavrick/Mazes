//
//  ControlsView.swift
//  Mazes
//
//  Created by acemavrick on 6/13/25.
//

import SwiftUI

struct ControlsView: View {
    @ObservedObject var model: Model
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Maze Configuration Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Generation")
                            .font(.headline)
                        switch (model.generationState){
                        case .idle:
                            EmptyView()
                        case .working:
                            ProgressView()
                                .tint(.accentLight)
                                .progressViewStyle(.circular)
                                .controlSize(.mini)
                        case .paused:
                            Image(systemName: "pause")
                                .foregroundColor(.accent)
                                .font(.headline)
                        }
                    }
                    .padding(.bottom, 2)

                    MazeAlgorithmPickerView(model: model)
                        .padding(.bottom, 5)
                    
                    GenerationControlsButtonView(model: model)
                } // end maze config vstack
                
                Divider()
                    .padding(.vertical, 2)
                
                // Solver Options Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Solving")
                            .font(.headline)
                        switch (model.solvingState){
                        case .idle:
                            EmptyView()
                        case .working:
                            ProgressView()
                                .tint(.accentLight)
                                .progressViewStyle(.circular)
                                .controlSize(.mini)
                        case .paused:
                            Image(systemName: "pause")
                                .foregroundColor(.accent)
                                .font(.headline)
                        }
                    }
                    .padding(.bottom, 2)

                    SolverAlgorithmPickerView(model: model)
                        .padding(.bottom, 5)
                    
                    SolverControlsButtonView(model: model)
                    Spacer()
                } // end solver vstack
            }
            .padding() // Apply padding to the content within the ScrollView
        }
        .background(.thinMaterial)
        .animation(.easeInOut(duration: 0.2), value: model.generationState)
        .animation(.easeInOut(duration: 0.2), value: model.solvingState) // Add animation for solvingState changes
    }
}
