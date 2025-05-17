//
//  Model.swift
//  Mazes
//
//  Created by acemavrick on 5/16/25.
//

import Foundation
import SwiftUI

class Model: ObservableObject {
    @Published var coordinator: Controller.Coordinator? = nil
    @Published var currentOption: MazeTypes = .prims
    
    public func generateMaze() {
        coordinator?.generateMaze(type: currentOption)
    }
}
