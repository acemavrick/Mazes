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
                
                Divider()
                    .padding(.vertical, 2)
                
                VStack(alignment: .leading, spacing: 8) {
                    // settings panel
                    Text("Settings")
                        .font(.headline)
                    SettingsPanel(model: model)
                }
            }
            .padding() // Apply padding to the content within the ScrollView
            .fixedSize(horizontal: true, vertical: false)
        }
        .background(.thinMaterial)
    }
}

struct SpeedSettingsView: View {
    @ObservedObject var model: Model

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(String(format: "Pulse Animation Speed: %.3f", model.speedFactor))
                        .font(.subheadline)
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            model.speedFactor = 1.0
                            model.syncSpeedFactor()
                        }
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                            .font(.caption)
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.borderless)
                    .help("Reset to default speed")
                }
                
                HStack(spacing: 8) {
                    Image(systemName: "tortoise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Slider(value: $model.speedFactor, in: 0.1...5)
                        .tint(.accent)
                        .onChange(of: model.speedFactor) {
                            model.syncSpeedFactor()
                        }
                    
                    Image(systemName: "hare")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // Fine adjustment controls
                    HStack(spacing: 2) {
                        Button {
                            withAnimation {
                                model.speedFactor = max(0.1, model.speedFactor - 0.001)
                                model.syncSpeedFactor()
                            }
                        } label: {
                            Image(systemName: "minus")
                                .font(.caption2)
                        }
                        .buttonStyle(.borderless)
                        .contentShape(Rectangle())
                        
                        Button {
                            withAnimation {
                                model.speedFactor = min(5, model.speedFactor + 0.001)
                                model.syncSpeedFactor()
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.caption2)
                        }
                        .buttonStyle(.borderless)
                        .contentShape(Rectangle())
                    }
                    .padding(3)
                    .background(.quaternary.opacity(0.3))
                    .cornerRadius(4)
                }
            }
        }
    }
}

struct DimensionSettingsView: View {
    @ObservedObject var model: Model
    @State private var width: String
    @State private var height: String
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case width, height
    }

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
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Width")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextField("Width", text: $width)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .multilineTextAlignment(.center)
                            .focused($focusedField, equals: .width)
                            .onSubmit { focusedField = .height }
                            .onChange(of: width) {
                                let filtered = width.filter { "0123456789".contains($0) }
                                if filtered != width {
                                    width = filtered
                                }
                            }
                            .overlay {
                                if !widthMatches {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(Color("Accent").opacity(0.2))
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(Color("AccentLight"), lineWidth: 1.5)
                                    }
                                }
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Height")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        TextField("Height", text: $height)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                            .multilineTextAlignment(.center)
                            .focused($focusedField, equals: .height)
                            .onSubmit {
                                focusedField = nil
                                if let w = Int(width), let h = Int(height) {
                                    model.sendMazeSize(width: w, height: h)
                                }
                            }
                            .onChange(of: height) {
                                let filtered = height.filter { "0123456789".contains($0) }
                                if filtered != height {
                                    height = filtered
                                }
                            }
                            .overlay {
                                if !heightMatches {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(Color("Accent").opacity(0.2))
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(Color("AccentLight"), lineWidth: 1.5)
                                    }
                                }
                            }
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 4) {
                        Button(action: {
                            focusedField = nil
                            if let w = Int(width), let h = Int(height) {
                                model.sendMazeSize(width: w, height: h)
                            }
                        }) {
                            Text("Apply")
                                .frame(minWidth: 60)
                        }
                        .controlSize(.small)
                        .disabled(widthMatches && heightMatches)
                        .buttonStyle(.borderedProminent)

                        Button(action: {
                            focusedField = nil
                            width = String(model.trueMazeWidth)
                            height = String(model.trueMazeHeight)
                        }) {
                            Text("Reset")
                                .frame(minWidth: 60)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(widthMatches && heightMatches)
                    }
                }
            }
        } label: {
            Text("Maze Dimensions")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .onChange(of: model.trueMazeWidth) {
            width = String(model.trueMazeWidth)
        }
        .onChange(of: model.trueMazeHeight) {
            height = String(model.trueMazeHeight)
        }
    }
}

struct SettingsPanel: View {
    @ObservedObject var model: Model

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SpeedSettingsView(model: model)
            DimensionSettingsView(model: model)
        }
    }
}
