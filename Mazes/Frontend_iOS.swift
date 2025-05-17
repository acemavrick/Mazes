import SwiftUI

struct Frontend_iOS: View {
    @StateObject private var model = Model()
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background that extends edge to edge
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 12) {
                    // Top spacer
                    Spacer()
                    
                    // Side-by-side controls with smaller sizing
                    HStack(spacing: 10) {
                        // Maze type picker - smaller and simplified
                        Menu {
                            Picker("", selection: $model.currentOption) {
                                ForEach(MazeTypes.allCases) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                        } label: {
                            HStack {
                                Text(model.currentOption.rawValue)
                                    .font(.system(size: 14))
                                    .foregroundColor(.black)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10))
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white)
                            )
                        }
                        
                        // Generate button - smaller and simplified
                        Button {
                            withAnimation {
                                model.generateMaze()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 12))
                                Text("Generate")
                                    .font(.system(size: 14))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .contentShape(Rectangle())
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // Maze display - maximum size
                    ZStack {
                        Controller(model: model)
                    }
                    .frame(
                        width: calculateOptimalSize(geometry: geometry),
                        height: calculateOptimalSize(geometry: geometry)
                    )
                    .background(Color.white)
                    
                    // Bottom spacer
                    Spacer()
                }
                .ignoresSafeArea(.all)
            }
        }
    }
    
    // Calculate optimal square size without referencing UIKit directly
    private func calculateOptimalSize(geometry: GeometryProxy) -> CGFloat {
        let horizontalPadding: CGFloat = 32
        let controlsHeight: CGFloat = 60  // Much smaller now with side-by-side controls
        
        // Use the geometry provided size directly
        let availableWidth = geometry.size.width - horizontalPadding
        let availableHeight = geometry.size.height - controlsHeight - 32
        
        return min(availableWidth, availableHeight)
    }
}

#Preview {
    Frontend_iOS()
}
