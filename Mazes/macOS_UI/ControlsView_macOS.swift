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
    @State private var width: String
    @State private var height: String

    init(model: Model) {
        self.model = model
        _width = State(initialValue: String(model.trueMazeWidth))
        _height = State(initialValue: String(model.trueMazeHeight))
    }
    
    var widthMatches: Bool {
        Int(width) == model.trueMazeWidth
    }
    
    var heightMatches: Bool {
        Int(height) == model.trueMazeHeight
    }

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
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Size (WxH):")
                    .font(.caption)
                HStack {
                    TextField("W", text: $width)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 60)
                        .multilineTextAlignment(.center)
                        .background(widthMatches ? Color.clear : Color.red.opacity(0.3))
                        .cornerRadius(5)

                    TextField("H", text: $height)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 60)
                        .multilineTextAlignment(.center)
                        .background(heightMatches ? Color.clear : Color.red.opacity(0.3))
                        .cornerRadius(5)

                    Spacer()

                    Button(action: {
                        if let w = Int(width), let h = Int(height) {
                            model.sendMazeSize(width: w, height: h)
                        }
                    }) {
                        Text("Submit")
                    }
                    .disabled(widthMatches && heightMatches)

                    Button(action: {
                        let trueWidth = model.trueMazeWidth
                        let trueHeight = model.trueMazeHeight
                        width = String(trueWidth)
                        height = String(trueHeight)
                    }) {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
            }
        }
        .onChange(of: model.trueMazeWidth) {
            width = String(model.trueMazeWidth)
        }
        .onChange(of: model.trueMazeHeight) {
            height = String(model.trueMazeHeight)
        }
    }
}
