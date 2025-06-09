//
//  SwiftUIView.swift
//  Mazes
//
//  Created by acemavrick on 6/8/25.
//

import SwiftUI

struct SwiftUIView: View {
    var genState: MazeGenerationState = .paused
    var currentAlgorithm: MazeTypes = .prims
    var body: some View {
        HStack {
            // Algorithm Picker
            HStack {
                // Dropdown for algorithm selection
                Menu {
                    ForEach(MazeTypes.allCases) { type in
                        Button(action: {
                        }) {
                            HStack {
                                Text(type.rawValue)
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text("Algorithm:")
                            .font(.headline)
                        Text(currentAlgorithm.rawValue)
                            .font(.subheadline)
                            .foregroundColor(.accent)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.accent)
                    }
                    .foregroundStyle(.black)
                    .padding(.vertical, 6)
                    .background(.secondary) // ignore
                }
                .disabled(genState != .idle)
            }
            .padding(.trailing)
            Spacer()
            switch genState {
            case .idle:
                Button {
                    withAnimation {
                    }
                } label: {
                    Text("Generate New Maze")
                        .fontWeight(.semibold)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.accentLight)
                        .foregroundColor(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                
            case .generating:
                VStack(spacing: 10) {
                    HStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.large)
                        Button {
                        } label: {
                                Image(systemName: "pause.fill")
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(Color(UIColor.secondarySystemBackground))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                        } label: {
                            Image(systemName: "stop.fill")
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity)
                                .background(Color.red.opacity(0.8))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
            case .paused:
                    HStack(spacing: 12) {
                        Button {
                        } label: {
                            Image(systemName: "play.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(.accentLight)
                                .foregroundStyle(.black)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                        } label: {
                            Image(systemName: "stop.fill")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.red.opacity(0.8))
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
            }
        }
    }
}

#Preview {
    SwiftUIView()
}
