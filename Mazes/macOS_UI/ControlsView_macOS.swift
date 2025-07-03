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
                } // end solver vstack
            }
            .padding() // Apply padding to the content within the ScrollView
            
            Divider()
                .padding(.bottom, 2)
            
            VStack(alignment: .leading, spacing: 8) {
                // settings panel
                Text("Settings")
                    .font(.headline)
                SettingsPanel(model: model)
                Spacer()
            }
            .padding()
        }
        .background(.thinMaterial)
    }
}

struct SettingsPanel: View {
    @ObservedObject var model: Model
    
    var body: some View {
        VStack(spacing: 4) {
            VStack(alignment: .leading) {
                Text(String(format: "Speed factor (%.3f):", model.speedFactor))
                HStack {
                    Button {
                        withAnimation {
                            model.speedFactor = 1.0
                            model.syncSpeedFactor()
                        }
                    } label: {
                        Image(systemName: "arrow.trianglehead.counterclockwise")
                    }
                    
                    Slider(value: $model.speedFactor,
                           in: 0.1...5) {   }
                    onEditingChanged: { _ in
                        model.syncSpeedFactor()
                    }
                    .tint(.accent)
                    
                    // stepper buttons
                    HStack(spacing: 2) {
                        Button {
                            withAnimation {
                                model.speedFactor -= 0.001
                                model.syncSpeedFactor()
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        
                        Button {
                            withAnimation {
                                model.speedFactor += 0.001
                                model.syncSpeedFactor()
                            }
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                    } // end hstack
                } // end hstack
                .font(.caption)
            }
            
            HStack {
                Text("WxH: ")
            }
        }
    }
}
