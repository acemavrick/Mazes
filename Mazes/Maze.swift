//
//  Maze.swift
//  Mazes
//
//  Created by acemavrick on 5/15/25.
//

import Foundation
import simd

import Foundation
import simd
import Metal

class Maze {
    // Maze dimensions
    private var block: Bool = false
    private var width: Int
    private var height: Int
    
    private var cellBuffer: MTLBuffer
    private var device: MTLDevice
    
    // Initialize with device and dimensions
    init(device: MTLDevice, width: Int, height: Int) {
        self.device = device
        self.width = width
        self.height = height
        
        // Create the buffer
        let bufferSize = MemoryLayout<Cell>.stride * width * height
        self.cellBuffer = self.device.makeBuffer(length: bufferSize, options: .storageModeShared)!

        // Initialize cells with proper positions
        clearMaze()
    }
    
    func reinitBuffer() {
        let bufferSize = MemoryLayout<Cell>.stride * width * height
        self.cellBuffer = self.device.makeBuffer(length: bufferSize, options: .storageModeShared)!
    }
    
    func resizeMaze(width: Int, height: Int) -> Bool {
        // Don't do anything if dimensions haven't changed
        if self.width == width && self.height == height {
            return false;
        }
        self.width = width
        self.height = height
        
        // Create new buffer with new dimensions
        reinitBuffer()
        
        // clear the maze
        clearMaze()
        
        return true;
    }
    
    // Reset all cells to walls
    func clearMaze() {
        let cellsPtr = cellBuffer.contents().bindMemory(to: Cell.self, capacity: width * height)
        
        for row in 0..<height {
            for col in 0..<width {
                let index = row * width + col
                cellsPtr[index] = Cell(
                    posCR: simd_float2(Float(col), Float(row)),
                    northWall: 0, // All walls present (0 = wall)
                    eastWall: 0,
                    southWall: 0,
                    westWall: 0,
                    // dist, visited and _padding automatically filled out
                )
            }
        }
    }
    
    // Reset only the fill state
    func resetFillState() {
        let cellsPtr = cellBuffer.contents().bindMemory(to: Cell.self, capacity: width * height)
        
        for i in 0..<(width * height) {
            cellsPtr[i].visited = 0
        }
    }
    
    // Check if two cells are connected
    func areConnected(row1: Int, col1: Int, row2: Int, col2: Int) -> Bool {
        let cell1 = getCell(row: row1, col: col1)!.pointee
        let cell2 = getCell(row: row2, col: col2)!.pointee
        
        // Horizontal adjacency
        if row1 == row2 {
            if col1 + 1 == col2 { // c1 is left of c2
                return cell1.eastWall == 1 && cell2.westWall == 1
            }
            if col1 - 1 == col2 { // c1 is right of c2
                return cell1.westWall == 1 && cell2.eastWall == 1
            }
        }
        // Vertical adjacency
        else if col1 == col2 {
            if row1 + 1 == row2 { // c1 is above c2
                return cell1.southWall == 1 && cell2.northWall == 1
            }
            if row1 - 1 == row2 { // c1 is below c2
                return cell1.northWall == 1 && cell2.southWall == 1
            }
        }
        
        return false // Not adjacent or not connected
    }
    
    // Connect two cells by removing the wall between them
    func connect(row1: Int, col1: Int, row2: Int, col2: Int) {
        guard row1 >= 0, row1 < height, col1 >= 0, col1 < width,
              row2 >= 0, row2 < height, col2 >= 0, col2 < width else {
            return
        }
        
        let cellsPtr = cellBuffer.contents().bindMemory(to: Cell.self, capacity: width * height)
        let index1 = row1 * width + col1
        let index2 = row2 * width + col2
        
        // Horizontal connection
        if row1 == row2 {
            if col1 < col2 { // Cell 1 is left of Cell 2
                cellsPtr[index1].eastWall = 1
                cellsPtr[index2].westWall = 1
            } else { // Cell 1 is right of Cell 2
                cellsPtr[index1].westWall = 1
                cellsPtr[index2].eastWall = 1
            }
        }
        // Vertical connection
        else if col1 == col2 {
            if row1 < row2 { // Cell 1 is above Cell 2
                cellsPtr[index1].southWall = 1
                cellsPtr[index2].northWall = 1
            } else { // Cell 1 is below Cell 2
                cellsPtr[index1].northWall = 1
                cellsPtr[index2].southWall = 1
            }
        }
    }
    
    func generate(type: MazeTypes) {
        if (self.block) {
            print("Maze generation is already in progress")
            return
        }
        DispatchQueue.global(qos: .userInitiated).async {
            self.block = true;
            switch type {
            case .random:
                print("generating random maze")
                self.genRandom()
                break;
            case .recursive_dfs:
                if (self.width * self.height > 9000) {
                    print("Maze is too large for recursive DFS")
                    break;
                }
                print("generating recursive DFS maze")
                self.genRecursiveDFS()
                break;
            case .prims:
                print("generating prims maze")
                self.genPrims()
                break;
            }
            self.block = false;
        }
    }
    
    // Get cell at specific coordinates (row, col)
    private func getCell(row: Int, col: Int) -> UnsafeMutablePointer<Cell>? {
        guard row >= 0, row < height, col >= 0, col < width else {
            return nil
        }
        
        let basePointer = self.cellBuffer.contents().assumingMemoryBound(to: Cell.self)
        let index = row * width + col
        return basePointer.advanced(by: index)
    }
    
    private func getNeighbors(row: Int, col: Int) -> [(row: Int, col: Int)] {
        var neighbors: [(row: Int, col: Int)] = []
        
        // Check the four possible neighbors (up, down, left, right)
        if row > 0 { // Up
            neighbors.append((row: row - 1, col: col))
        }
        if row < height - 1 { // Down
            neighbors.append((row: row + 1, col: col))
        }
        
        if col > 0 { // Left
            neighbors.append((row: row, col: col - 1))
        }
        
        if col < width - 1 { // Right
            neighbors.append((row: row, col: col + 1))
        }
        
        return neighbors
    }
    
    func genRandom() {
        clearMaze()
        for row in 0..<height {
            for col in 0..<width {
                // flip a coin for each side to decide if it should be connected
                for c in getNeighbors(row: row, col: col) {
                    // flip a coin
                    let coin = Int.random(in: 0...1)
                    if coin == 0 && !areConnected(row1: row, col1: col, row2: c.row, col2: c.col) {
                        // connect the two cells
                        connect(row1: row, col1: col, row2: c.row, col2: c.col)
                        Thread.sleep(forTimeInterval: 0.0001)
                    }
                }
            }
        }
    }
        
    func genRecursiveDFS() {
        clearMaze()
        let startRow = Int.random(in: 0..<height), startCol = Int.random(in: 0..<width)
        backtrack(row_current: startRow, col_current: startCol)
    }
    
    private func backtrack(row_current cr : Int, col_current cc : Int, dist : Int = 0) {
        guard let cellPtr = getCell(row: cr, col: cc) else {
            return
        }
        
        if (cellPtr.pointee.visited == 1) {
            return
        }
        cellPtr.pointee.visited = 1
        cellPtr.pointee.dist = Int32(dist)
        
        let neighbors = getNeighbors(row: cr, col: cc)
        let shuffledNeighbors = neighbors.shuffled()
        
        // Visit each neighbor
        for neighbor in shuffledNeighbors {
            let row = neighbor.row
            let col = neighbor.col
            
            guard let neighborCell = getCell(row: row, col: col) else {
                continue
            }
            
            if (neighborCell.pointee.visited == 0) {
                // Connect the current cell to the neighbor
                connect(row1: cr, col1: cc, row2: row, col2: col)
                Thread.sleep(forTimeInterval: 0.001)
                
                // Recursively backtrack from the neighbor
                backtrack(row_current: row, col_current: col, dist: dist + 1)
            }
        }
    }
    
    func genPrims() {
        clearMaze()
        var frontier: [(row: Int, col: Int)] = []
        
        let startRow = Int.random(in: 0..<height)
        let startCol = Int.random(in: 0..<width)
        frontier.append((startRow, startCol))
        getCell(row: startRow, col: startCol)?.pointee.visited = 1
        
        while !frontier.isEmpty {
            // Randomly select a cell from the frontier
            let randomIndex = Int.random(in: 0..<frontier.count)
            let currentCell = frontier[randomIndex]
            let cellPtr = getCell(row: currentCell.row, col: currentCell.col)
            frontier.remove(at: randomIndex)
            
            let neighbors = getNeighbors(row: currentCell.row, col: currentCell.col).shuffled()
            for neighbor in neighbors {
                guard let neighborCell = getCell(row: neighbor.row, col: neighbor.col) else {
                    continue
                }
                if (neighborCell.pointee.visited == 0) {
                    // Connect the current cell to the neighbor
                    connect(row1: currentCell.row, col1: currentCell.col, row2: neighbor.row, col2: neighbor.col)
                    // add to frontier
                    if !frontier.contains(where: { $0.row == neighbor.row && $0.col == neighbor.col }) {
                        frontier.append((neighbor.row, neighbor.col))
                        Thread.sleep(forTimeInterval: 0.00001)
                    }
                    // Mark the neighbor as visited
                    neighborCell.pointee.visited = 1
                    neighborCell.pointee.dist = cellPtr!.pointee.dist + 1
                }
            }
        }
    }

    // Getters
    func getWidth() -> Int {
        return width
    }
    
    func getHeight() -> Int {
        return height
    }
    
    // Get the buffer for rendering
    func getCellBuffer() -> MTLBuffer {
        return cellBuffer
    }
}
