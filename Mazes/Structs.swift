//
//  Uniforms.swift
//  Mazes
//
//  Created by acemavrick on 5/15/25.
//

import Foundation
import simd
import Metal

enum MazeTypes: String, CaseIterable, Identifiable {
    case random = "Random"
    case recursive_dfs = "Rec DFS"
    
    var id: String { self.rawValue }
}
 
struct Uniforms {
    var time: Float = 0
    var resolution: simd_float2 = [0.0, 0.0]
    // maze dimensions, height x width
    var mazeDims: simd_float2 = [0.0, 0.0]
    var cellSize: Float = 0
    
    mutating func setResolution(_ size: CGSize) -> Bool {
        let newResolution = SIMD2<Float>(Float(size.width), Float(size.height))
        if newResolution != resolution {
            resolution = newResolution
            syncCellSize()
            return true
        }
        return false
    }
    
    mutating func setMazeDims(height: Int, width: Int) -> Bool {
        let newMazeDims = SIMD2<Float>(Float(height), Float(width))
        if newMazeDims != mazeDims {
            mazeDims = newMazeDims
            syncCellSize()
            return true
        }
        return false
    }
    
    mutating func syncCellSize() {
        // Calculate cell size based on resolution and maze dimensions
        let minRes = min(resolution.x, resolution.y)
        let minDim = min(mazeDims.x, mazeDims.y)
        
        // find the smallest dimension of the maze
        if (minRes == 0 || minDim == 0) {
            cellSize = 0
        } else {
            cellSize = floor(minRes / minDim)
        }
//        print(resolution)
//        print(mazeDims)
//        print(cellSize)
    }
}

struct Cell {
    // column, row
    var posCR: simd_float2
    // 0 = wall, 1 = no wall
    var northWall: Int32 = 0
    var eastWall: Int32 = 0
    var southWall: Int32 = 0
    var westWall: Int32 = 0
    // will be used to determine fill color (distance along trail)
    var dist: Int32 = 0
    // for use in fill algorithm
    var visited: Int32 = 0
    var _padding: Int32 = 0
}
