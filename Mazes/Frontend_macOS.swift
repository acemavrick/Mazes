//
//  Frontend_macOS.swift
//  Mazes
//
//  Created by acemavrick on 5/16/25.
//

import SwiftUI

struct Frontend_macOS: View {
    @StateObject private var model = Model()
    
    // Custom gradient colors - vibrant multicolor gradient
    private let gradientStart = Color(red: 0.0, green: 0.8, blue: 0.8) // Teal
    private let gradientMiddle = Color(red: 0.1, green: 0.6, blue: 0.9) // Blue
    private let gradientEnd = Color(red: 0.5, green: 0.2, blue: 0.9) // Purple
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background using macOS standard window background
                Color(NSColor.windowBackgroundColor)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Top controls area - simplified with full-width dropdown
                    HStack {
                        Text("Maze Type:")
                            .font(.system(size: 13))
                        
                        Picker("", selection: $model.currentOption) {
                            ForEach(MazeTypes.allCases) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    
                    // Generate button - full-width gradient button with entire area clickable
                    Button {
                        withAnimation {
                            model.generateMaze()
                        }
                    } label: {
                        HStack {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 14))
                            Text("Generate Maze")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [gradientStart, gradientMiddle, gradientEnd]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(4)
                        .contentShape(Rectangle()) // Make entire area clickable
                    }
                    .buttonStyle(ClickableButtonStyle()) // Custom style to ensure full area is clickable
                    .padding(.horizontal, 16)
                    
                    // Maze display - maximized
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white)
                            .shadow(color: Color.black.opacity(0.05), radius: 1)
                        
                        Controller(model: model)
                            .padding(8)
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onEnded { value in
                                        let location = value.location
                                        let size = CGSize(
                                            width: calculateOptimalSize(geometry: geometry) - 16,
                                            height: calculateOptimalSize(geometry: geometry) - 16
                                        )
                                        model.handleMazeTap(at: location, in: size)
                                    }
                            )
                    }
                    .frame(
                        width: calculateOptimalSize(geometry: geometry),
                        height: calculateOptimalSize(geometry: geometry)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    
                    Spacer(minLength: 0)
                }
            }
        }
    }
    
    // Calculate optimal square size for Controller
    private func calculateOptimalSize(geometry: GeometryProxy) -> CGFloat {
        let horizontalPadding: CGFloat = 32
        let controlsHeight: CGFloat = 96 // Height of top controls and generate button
        
        let availableWidth = geometry.size.width - horizontalPadding
        let availableHeight = geometry.size.height - controlsHeight - 32
        
        return min(availableWidth, availableHeight)
    }
}

// Custom button style that ensures the entire button area is clickable
struct ClickableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

#Preview {
    Frontend_macOS()
}
