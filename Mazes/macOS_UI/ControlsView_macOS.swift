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
                    Text("Maze Configuration")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Algorithm:")
                        .font(.headline)
                        .padding(.bottom, 2)
                    
                    MazeAlgorithmPickerView(model: model)
                        .padding(.bottom, 10)
                    
                    GenerationControlsButtonView(model: model)
                } // end maze config vstack
                
                Divider()
                    .padding(.vertical, 10)
                
                // Solver Options Section
                VStack(alignment: .leading, spacing: 8) {
                    Text("Solver Options")
                        .font(.headline)
                    
                    SolverAlgorithmPickerView(model: model)
                        .padding(.bottom, 10)
                    
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
