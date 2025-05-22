//
//  Maze.swift
//  Mazes
//
//  Created by acemavrick on 5/15/25.
//

import Foundation
import simd
import Metal

// --- Disjoint Set (Union-Find) Data Structure ---
struct DisjointSet {
    private var parent: [Int]
    private var rank: [Int] // For union by rank optimization

    init(size: Int) {
        parent = Array(0..<size)
        rank = Array(repeating: 0, count: size)
    }

    // Find the parent of the set
    mutating func find(_ i: Int) -> Int {
        if parent[i] == i {
            return i
        }
        // Path compression
        parent[i] = find(parent[i])
        return parent[i]
    }

    // Union the sets
    mutating func union(_ i: Int, _ j: Int) {
        let rootI = find(i)
        let rootJ = find(j)

        if rootI != rootJ {
            // Union by rank
            if rank[rootI] < rank[rootJ] {
                parent[rootI] = rootJ
            } else if rank[rootI] > rank[rootJ] {
                parent[rootJ] = rootI
            } else {
                parent[rootJ] = rootI
                rank[rootI] += 1
            }
        }
    }
}

// Custom error to signal a deliberate stop by the user
enum MazeGenerationError: Error {
    case stoppedByUser
}

class Maze {
    // pointer to uniform buffer
    var coordinator : Controller.Coordinator
    
    // Maze dimensions
    private var width: Int
    private var height: Int
    
    private var cellBuffer: MTLBuffer
    private var device: MTLDevice
    private let MAX_DFS_RECURSION_DEPTH = 1000
    
    // --- Properties for Generation Control ---
    private var isGenerating: Bool = false
    private var isPaused: Bool = false
    private var shouldStop: Bool = false
    private let pauseCondition = NSCondition() // For managing pause/resume thread synchronization
    private let generationQueue = DispatchQueue(label: "com.mazes.generationQueue", qos: .userInitiated)
    private let MIN_SLEEP_INTERVAL: TimeInterval = 0.00000001 // Minimum sleep for responsiveness
    private let BFS_SLEEP_INTERVAL: TimeInterval = 0.0001 // Sleep for BFS to avoid tight loops
    private var animationDelay: TimeInterval = 0.001 // Current animation delay for the active generation
    private var customAnimationDelays: [MazeTypes: TimeInterval] = [:] // Stores user-set custom delays
    private var lastHuntRowForScan: Int = 0 // For Hunt-and-Kill optimization
    private var lastHuntColForScan: Int = 0 // For Hunt-and-Kill optimization

    // Initialize with device and dimensions
    init(device: MTLDevice, width: Int, height: Int, coordinator coord: Controller.Coordinator) {
        self.device = device
        self.width = width
        self.height = height
        self.coordinator = coord
        
        let bufferSize = MemoryLayout<Cell>.stride * width * height
        self.cellBuffer = self.device.makeBuffer(length: bufferSize, options: .storageModeShared)!
        clearMaze()
    }
    
    private func reinitBuffer() {
        let bufferSize = MemoryLayout<Cell>.stride * width * height
        self.cellBuffer = self.device.makeBuffer(length: bufferSize, options: .storageModeShared)!
    }
    
    func resizeMaze(width: Int, height: Int) -> Bool {
        if self.width == width && self.height == height { return false }
        self.width = width
        self.height = height
        reinitBuffer()
        clearMaze()
        return true
    }
    
    func clearMaze() {
        let cellsPtr = cellBuffer.contents().bindMemory(to: Cell.self, capacity: width * height)
        for row in 0..<height {
            for col in 0..<width {
                let index = row * width + col
                cellsPtr[index] = Cell(
                    posCR: simd_float2(Float(col), Float(row)),
                    northWall: 0, eastWall: 0, southWall: 0, westWall: 0
                )
            }
        }
    }
    
    func resetFillState() {
        let cellsPtr = cellBuffer.contents().bindMemory(to: Cell.self, capacity: width * height)
        for i in 0..<(width * height) {
            cellsPtr[i].fillVisited = 0
            cellsPtr[i].dist = -1
        }
    }

    // --- Generation Control Methods ---
    public func pauseGeneration() {
        pauseCondition.lock()
        if isGenerating && !isPaused {
            isPaused = true
            print("Maze generation paused.")
        }
        pauseCondition.unlock()
    }

    public func resumeGeneration() {
        pauseCondition.lock()
        if isGenerating && isPaused {
            isPaused = false
            pauseCondition.signal() // Wake up the waiting generation thread
            print("Maze generation resumed.")
        }
        pauseCondition.unlock()
    }

    public func stopGeneration() {
        pauseCondition.lock()
        if isGenerating {
            shouldStop = true
            if isPaused { // If paused, unpause it briefly so it can check shouldStop
                isPaused = false
                pauseCondition.signal()
            }
            print("Maze generation stop requested.")
        }
        pauseCondition.unlock()
    }

    // Internal helper to be called periodically within generation algorithms
    private func checkPauseAndStopFlags() throws {
        pauseCondition.lock()
        while isPaused && !shouldStop {
            // print("Generation waiting on pauseCondition...")
            pauseCondition.wait() // Releases lock and waits; reacquires lock on signal
            // print("Generation woke from pauseCondition.")
        }
        let stopRequested = shouldStop
        pauseCondition.unlock()

        if stopRequested {
            // print("Stopping generation as per flag.")
            throw MazeGenerationError.stoppedByUser
        }
        // Yield thread briefly to allow UI updates and prevent tight loops
        Thread.sleep(forTimeInterval: MIN_SLEEP_INTERVAL)
    }
    
    // --- Main Generation Method ---
    public func generate(type: MazeTypes, completion: @escaping (Bool) -> Void) {
        guard !isGenerating else {
            print("Maze.generate: Generation already in progress.")
            completion(false)
            return
        }

        isGenerating = true
        isPaused = false
        shouldStop = false
        self.lastHuntRowForScan = 0 // Reset for Hunt-and-Kill
        self.lastHuntColForScan = 0 // Reset for Hunt-and-Kill

        // Set animation delay: use custom if set, otherwise default from enum
        if let customDelay = customAnimationDelays[type] {
            self.animationDelay = customDelay
        } else {
            self.animationDelay = type.defaultAnimationDelay
        }
        
        clearMaze()

        generationQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false) }
                return
            }

            var success = true
            let startTime = CFAbsoluteTimeGetCurrent()
            // print("Maze.generate: Starting generation of type: \(type.rawValue) on background thread.")
            do {
                switch type {
                case .recursiveDFS:
                    try self.genRecursiveDFSInternal()
                case .kruskals:
                    try self.genKruskalsInternal()
                case .prims:
                    try self.genPrimsInternal()
                case .aldousBroder:
                    try self.genAldousBroderInternal()
                case .wilsons:
                    try self.genWilsonsInternal()
                case .huntAndKill:
                    try self.genHuntAndKillInternal()
                case .sidewinder: // Added Sidewinder
                    try self.genSidewinderInternal()
                }
                // print("Maze.generate: Maze generation completed for type: \(type.rawValue).")
            } catch MazeGenerationError.stoppedByUser {
                // print("Maze.generate: Maze generation stopped by user for type: \(type.rawValue).")
                success = false // Or true if partial generation is an acceptable outcome
            } catch {
                print("Maze.generate: An unexpected error occurred during maze generation: \(error)")
                success = false
            }
            
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            print("Maze.generate: Finished type: \(type.rawValue). Success: \(success). Time: \(String(format: "%.3f", timeElapsed))s.")

            // Finalize generation state
            self.pauseCondition.lock()
            self.isGenerating = false
            self.isPaused = false
            self.shouldStop = false
            self.pauseCondition.unlock()
            
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }

    // --- Internal Generation Algorithms ---
    private func genRecursiveDFSInternal() throws {
        // print("Starting Recursive DFS Internal")
        let startRow = Int.random(in: 0..<height)
        let startCol = Int.random(in: 0..<width)
        try backtrack(row_current: startRow, col_current: startCol, currentDepth: 0)
    }

    private func backtrack(row_current cr: Int, col_current cc: Int, currentDepth: Int) throws {
        try checkPauseAndStopFlags() // Check at the beginning of each call

        if currentDepth >= MAX_DFS_RECURSION_DEPTH {
            // print("DFS recursion depth limit reached at (\(cr), \(cc)), depth: \(currentDepth). Backtracking.")
            return
        }

        guard let cellPtr = getCell(row: cr, col: cc) else { return }
        cellPtr.pointee.genVisited = 1
        
        var directions = [(0, 1), (0, -1), (1, 0), (-1, 0)].shuffled()
        
        while !directions.isEmpty {
            let (dr, dc) = directions.removeFirst()
            let nextRow = cr + dr
            let nextCol = cc + dc
            
            if nextRow >= 0, nextRow < height, nextCol >= 0, nextCol < width,
               let nextCellPtr = getCell(row: nextRow, col: nextCol),
               nextCellPtr.pointee.genVisited == 0 {
                connect(row1: cr, col1: cc, row2: nextRow, col2: nextCol)
                Thread.sleep(forTimeInterval: self.animationDelay)
                try backtrack(row_current: nextRow, col_current: nextCol, currentDepth: currentDepth + 1)
            }
        }
    }

    private func genKruskalsInternal() throws {
        // print("Starting Kruskal's Internal")
        var edges: [(r1: Int, c1: Int, r2: Int, c2: Int)] = []
        for r in 0..<height {
            for c in 0..<width {
                if r + 1 < height { edges.append((r, c, r + 1, c)) }
                if c + 1 < width { edges.append((r, c, r, c + 1)) }
            }
        }
        edges.shuffle()
        
        var ds = DisjointSet(size: width * height)
        var edgesConnected = 0
        let requiredEdges = width * height - 1

        for edge in edges {
            if edgesConnected >= requiredEdges { break }
            try checkPauseAndStopFlags()
            
            let idx1 = edge.r1 * width + edge.c1
            let idx2 = edge.r2 * width + edge.c2
            if ds.find(idx1) != ds.find(idx2) {
                connect(row1: edge.r1, col1: edge.c1, row2: edge.r2, col2: edge.c2)
                ds.union(idx1, idx2)
                edgesConnected += 1
                Thread.sleep(forTimeInterval: self.animationDelay)
            }
        }
    }

    private func genPrimsInternal() throws {
        // print("Starting Prim's Internal")
        let startRow = Int.random(in: 0..<height)
        let startCol = Int.random(in: 0..<width)
        
        guard let startCell = getCell(row: startRow, col: startCol) else { return }
        startCell.pointee.genVisited = 1
        
        var frontier: [(r1: Int, c1: Int, r2: Int, c2: Int)] = []
        
        func addWallsToFrontier(r: Int, c: Int) throws {
            try checkPauseAndStopFlags() // Check when adding walls
            let directions = [(r - 1, c), (r + 1, c), (r, c - 1), (r, c + 1)]
            for (nr, nc) in directions {
                if nr >= 0, nr < height, nc >= 0, nc < width {
                    frontier.append((r, c, nr, nc))
                }
            }
        }
        
        try addWallsToFrontier(r: startRow, c: startCol)
        
        while !frontier.isEmpty {
            try checkPauseAndStopFlags() // Check at the start of each loop iteration
            
            let randomIndex = Int.random(in: 0..<frontier.count)
            let (r1, c1, r2, c2) = frontier.remove(at: randomIndex)
            
            guard let cell2 = getCell(row: r2, col: c2) else { continue }
            
            if cell2.pointee.genVisited == 0 {
                connect(row1: r1, col1: c1, row2: r2, col2: c2)
                cell2.pointee.genVisited = 1
                Thread.sleep(forTimeInterval: self.animationDelay) // Animation delay after connection
                try addWallsToFrontier(r: r2, c: c2)
            }
        }
    }

    private func genAldousBroderInternal() throws {
        // print("Starting Aldous-Broder Internal")
        var currentRow = Int.random(in: 0..<height)
        var currentCol = Int.random(in: 0..<width)

        guard let startCell = getCell(row: currentRow, col: currentCol) else { return }
        startCell.pointee.genVisited = 1
        var visitedCount = 1
        let totalCells = width * height

        var stepCounter: Int = 0
        let checkFlagsInterval: Int = 100 // Check for pause/stop every 100 steps

        while visitedCount < totalCells {
            stepCounter += 1
            if stepCounter % checkFlagsInterval == 0 {
                try checkPauseAndStopFlags()
            }

            let directions = [(0, 1), (0, -1), (1, 0), (-1, 0)].shuffled()
            let (dr, dc) = directions[0]
            
            let nextRow = currentRow + dr
            let nextCol = currentCol + dc

            if nextRow >= 0, nextRow < height, nextCol >= 0, nextCol < width {
                guard let nextCellPtr = getCell(row: nextRow, col: nextCol) else {
                    // Should not happen if bounds check is correct
                    currentRow = nextRow
                    currentCol = nextCol
                    continue
                }

                if nextCellPtr.pointee.genVisited == 0 {
                    connect(row1: currentRow, col1: currentCol, row2: nextRow, col2: nextCol)
                    nextCellPtr.pointee.genVisited = 1
                    visitedCount += 1
                }
                currentRow = nextRow
                currentCol = nextCol
                // Sleep after each step (whether a connection was made or just moved)
                Thread.sleep(forTimeInterval: self.animationDelay)
            } else {
                // If move was out of bounds, still consider it a step and sleep
                Thread.sleep(forTimeInterval: self.animationDelay)
            }
        }
    }

    private func genHuntAndKillInternal() throws {
        // print("Starting Hunt-and-Kill Internal")
        var currentRow = Int.random(in: 0..<height)
        var currentCol = Int.random(in: 0..<width)

        guard let startCell = getCell(row: currentRow, col: currentCol) else { return }
        startCell.pointee.genVisited = 1
        var visitedCount = 1
        let totalCells = width * height

        while visitedCount < totalCells {
            try checkPauseAndStopFlags()

            // Walk phase
            var madeAMoveInWalk = false
            walkLoop: while true {
                try checkPauseAndStopFlags()
                var unvisitedNeighbors: [(r: Int, c: Int)] = []
                let directions = [(0, 1), (0, -1), (1, 0), (-1, 0)].shuffled()

                for (dr, dc) in directions {
                    let nextRow = currentRow + dr
                    let nextCol = currentCol + dc

                    if nextRow >= 0, nextRow < height, nextCol >= 0, nextCol < width,
                       let neighborCell = getCell(row: nextRow, col: nextCol),
                       neighborCell.pointee.genVisited == 0 {
                        unvisitedNeighbors.append((nextRow, nextCol))
                    }
                }

                if !unvisitedNeighbors.isEmpty {
                    let (nextRow, nextCol) = unvisitedNeighbors.randomElement()!
                    connect(row1: currentRow, col1: currentCol, row2: nextRow, col2: nextCol)
                    Thread.sleep(forTimeInterval: self.animationDelay)
                    guard let newCell = getCell(row: nextRow, col: nextCol) else { break walkLoop } // Should not fail
                    newCell.pointee.genVisited = 1
                    visitedCount += 1
                    currentRow = nextRow
                    currentCol = nextCol
                    madeAMoveInWalk = true
                    if visitedCount >= totalCells { break walkLoop }
                } else {
                    break walkLoop // No unvisited neighbors, end walk phase
                }
            }
            
            if visitedCount >= totalCells { break } // Maze complete

            // Hunt phase
            var foundNextStart = false
            // Optimized hunt: resume scanning from/near where last successful hunt/walk ended.
            huntLoop: for r_offset in 0..<height {
                let r_hunt = (self.lastHuntRowForScan + r_offset) % height
                
                // Check for pause/stop once per row scan to reduce overhead but maintain responsiveness.
                try checkPauseAndStopFlags()

                for c_offset in 0..<width {
                    // Start scan from last column if on the same starting row, else start from column 0
                    let c_hunt = ( (r_offset == 0 ? self.lastHuntColForScan : 0) + c_offset ) % width
                    
                    // Potentially add a very small sleep here if scanning itself is too CPU intensive without visual feedback
                    // if animationDelay == 0 { Thread.sleep(forTimeInterval: self.MIN_SLEEP_INTERVAL) } 

                    guard let cellToInspect = getCell(row: r_hunt, col: c_hunt) else { continue }
                    if cellToInspect.pointee.genVisited == 0 { // Found an unvisited cell
                        var visitedNeighbors: [(r: Int, c: Int)] = []
                        let directions = [(0, 1), (0, -1), (1, 0), (-1, 0)]
                        for (dr, dc) in directions {
                            let nr = r_hunt + dr
                            let nc = c_hunt + dc
                            if nr >= 0, nr < height, nc >= 0, nc < width,
                               let potentialNeighbor = getCell(row: nr, col: nc),
                               potentialNeighbor.pointee.genVisited == 1 {
                                visitedNeighbors.append((nr, nc))
                            }
                        }

                        if !visitedNeighbors.isEmpty {
                            currentRow = r_hunt
                            currentCol = c_hunt
                            cellToInspect.pointee.genVisited = 1
                            visitedCount += 1
                            
                            let (vnRow, vnCol) = visitedNeighbors.randomElement()!
                            connect(row1: currentRow, col1: currentCol, row2: vnRow, col2: vnCol)
                            Thread.sleep(forTimeInterval: self.animationDelay) // Sleep after connection

                            self.lastHuntRowForScan = r_hunt // Update for next hunt's starting point
                            self.lastHuntColForScan = c_hunt
                            foundNextStart = true
                            break huntLoop
                        }
                    }
                }
            }
            if !foundNextStart && !madeAMoveInWalk { 
                print("Hunt phase could not find a new start. Visited: \(visitedCount)/\(totalCells)")
                break 
            }
        }
    }

    private func genWilsonsInternal() throws {
        // print("Starting Wilson's Internal")
        var unvisitedCells = Set<Int>()
        for r in 0..<height {
            for c in 0..<width {
                unvisitedCells.insert(r * width + c)
            }
        }

        // Mark a random cell as part of the maze
        let startR = Int.random(in: 0..<height)
        let startC = Int.random(in: 0..<width)
        guard let initialCell = getCell(row: startR, col: startC) else { return }
        initialCell.pointee.genVisited = 1
        unvisitedCells.remove(startR * width + startC)

        while !unvisitedCells.isEmpty {
            try checkPauseAndStopFlags()

            guard let randomUnvisitedIndex = unvisitedCells.randomElement() else { break }
            var currentWalkRow = randomUnvisitedIndex / width
            var currentWalkCol = randomUnvisitedIndex % width
            
            var currentPath: [(r: Int, c: Int)] = [(currentWalkRow, currentWalkCol)]
            var pathMap: [Int: Int] = [ (currentWalkRow * width + currentWalkCol) : 0 ] // cellIndex : pathIndex

            while true {
                try checkPauseAndStopFlags()
                let directions = [(0, 1), (0, -1), (1, 0), (-1, 0)].shuffled()
                let (dr, dc) = directions[0]
                let nextRow = currentWalkRow + dr
                let nextCol = currentWalkCol + dc

                // Ensure next cell is within bounds
                guard nextRow >= 0, nextRow < height, nextCol >= 0, nextCol < width else {
                    // If walk hits boundary, it must choose another direction from currentWalkCell
                    // This iteration of inner while loop will restart, picking new random direction
                    continue
                }
                
                currentWalkRow = nextRow
                currentWalkCol = nextCol
                let currentWalkIndex = currentWalkRow * width + currentWalkCol

                if let existingPathIndex = pathMap[currentWalkIndex] {
                    // Loop detected, erase the loop from path and map
                    for i in (existingPathIndex + 1)..<currentPath.count {
                        let cellToRemove = currentPath[i]
                        pathMap.removeValue(forKey: cellToRemove.r * width + cellToRemove.c)
                    }
                    currentPath.removeLast(currentPath.count - (existingPathIndex + 1))
                }
                
                currentPath.append((currentWalkRow, currentWalkCol))
                pathMap[currentWalkIndex] = currentPath.count - 1
                
                guard let walkedCell = getCell(row: currentWalkRow, col: currentWalkCol) else { break } // Should not fail
                // Each step in the random walk gets a delay
                Thread.sleep(forTimeInterval: self.animationDelay)

                if walkedCell.pointee.genVisited == 1 {
                    // Path has hit the existing maze, carve it
                    for i in 0..<currentPath.count - 1 {
                        let cell1 = currentPath[i]
                        let cell2 = currentPath[i+1]
                        connect(row1: cell1.r, col1: cell1.c, row2: cell2.r, col2: cell2.c)
                        // No separate sleep here, as the main walk step already slept.
                        guard let pathCell = getCell(row: cell1.r, col: cell1.c) else { continue }
                        if pathCell.pointee.genVisited == 0 {
                             pathCell.pointee.genVisited = 1
                        }
                        unvisitedCells.remove(cell1.r * width + cell1.c)
                    }
                    // The last cell in currentPath is already in the maze, ensure it's marked visited and removed from unvisited
                    if walkedCell.pointee.genVisited == 0 { // Should be 1, but defensive
                        walkedCell.pointee.genVisited = 1
                    }
                    unvisitedCells.remove(currentWalkIndex)
                    break // End current random walk
                }
            }
        }
    }

    // --- Utility and Helper Methods ---
    private func genSidewinderInternal() throws {
        for r in 0..<height {
            var currentRunStartCol = 0
            for c in 0..<width {
                try checkPauseAndStopFlags()

                let atEastBoundary = (c == width - 1)

                if r == 0 {
                    // For the top row, always carve East if not at the boundary.
                    // No Northward carving from the top row.
                    if !atEastBoundary {
                        connect(row1: r, col1: c, row2: r, col2: c + 1)
                        if animationDelay > 0 { Thread.sleep(forTimeInterval: animationDelay) }
                    }
                    currentRunStartCol = c + 1
                } else {
                    // Decide whether to carve East or close the current run and carve North.
                    if atEastBoundary || Bool.random() {
                        // Close the run: choose a random cell from currentRunStartCol to c (inclusive), and carve North from it
                        let randomColInRun = Int.random(in: currentRunStartCol...c)
                        connect(row1: r, col1: randomColInRun, row2: r - 1, col2: randomColInRun)
                        if animationDelay > 0 { Thread.sleep(forTimeInterval: animationDelay) }
                        
                        // Start a new run from the next cell.
                        currentRunStartCol = c + 1
                    } else {
                        // Continue the run: carve East to cell c + 1.
                        connect(row1: r, col1: c, row2: r, col2: c + 1)
                        if animationDelay > 0 { Thread.sleep(forTimeInterval: animationDelay) }
                        // currentRunStartCol remains the same as the run continues.
                    }
                }
            }
        }
        // print("Sidewinder generation complete.")
    }


    func bfsFill(fromx x: Int, fromy y: Int) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in // Added weak self
            guard let self = self else { return }

//             print("BFS Fill from (\(x), \(y))")
            guard x >= 0, x < self.width, y >= 0, y < self.height,
                  let startCell = self.getCell(row: y, col: x) else {
                return
            }
            
            // Reset fill state for this specific BFS operation
            self.resetFillState() 
            
            var queue: [(row: Int, col: Int)] = []
            queue.append((y, x))
            startCell.pointee.fillVisited = 1 // Mark as visited for BFS context
            startCell.pointee.dist = 0
            self.coordinator.uniforms.maxDist = 1
            
            while !queue.isEmpty {
                let current = queue.removeFirst()
                let currentCell = self.getCell(row: current.row, col: current.col)!
                let currentDist = currentCell.pointee.dist
                self.coordinator.uniforms.maxDist = max(self.coordinator.uniforms.maxDist, currentDist+1)
                
                let directions = [(-1, 0), (0, 1), (1, 0), (0, -1)]
                for (dx, dy) in directions {
                    let newRow = current.row + dy
                    let newCol = current.col + dx
                    
                    guard newRow >= 0, newRow < self.width, newCol >= 0, newCol < self.height,
                          let neighborCell = self.getCell(row: newRow, col: newCol),
                          neighborCell.pointee.dist < 0 else { // dist < 0 means not yet visited in this BFS pass
                        continue
                    }
                    
                    var canMove = false
                    if dy == -1 && currentCell.pointee.northWall == 1 { canMove = true }
                    else if dy == 1 && currentCell.pointee.southWall == 1 { canMove = true }
                    else if dx == -1 && currentCell.pointee.westWall == 1 { canMove = true }
                    else if dx == 1 && currentCell.pointee.eastWall == 1 { canMove = true }
                    
                    if canMove {
                        neighborCell.pointee.fillVisited = 1
                        neighborCell.pointee.dist = currentDist + 1
                        queue.append((newRow, newCol))
                        Thread.sleep(forTimeInterval: self.BFS_SLEEP_INTERVAL) // Use defined constant
                    }
                }
            }
        }
    }
    
    private func connect(row1: Int, col1: Int, row2: Int, col2: Int) {
        guard row1 >= 0, row1 < height, col1 >= 0, col1 < width,
              row2 >= 0, row2 < height, col2 >= 0, col2 < width else {
            return
        }
        
        let cellsPtr = cellBuffer.contents().bindMemory(to: Cell.self, capacity: width * height)
        let index1 = row1 * width + col1
        let index2 = row2 * width + col2
        
        if row1 == row2 {
            if col1 < col2 { cellsPtr[index1].eastWall = 1; cellsPtr[index2].westWall = 1 }
            else { cellsPtr[index1].westWall = 1; cellsPtr[index2].eastWall = 1 }
        } else if col1 == col2 {
            if row1 < row2 { cellsPtr[index1].southWall = 1; cellsPtr[index2].northWall = 1 }
            else { cellsPtr[index1].northWall = 1; cellsPtr[index2].southWall = 1 }
        }
    }
    
    public func getCell(row: Int, col: Int) -> UnsafeMutablePointer<Cell>? {
        guard row >= 0, row < height, col >= 0, col < width else { return nil }
        let cellsPtr = cellBuffer.contents().bindMemory(to: Cell.self, capacity: width * height)
        return cellsPtr.advanced(by: row * width + col)
    }
    
    public func getCellBuffer() -> MTLBuffer { return cellBuffer }
    public func getWidth() -> Int { return width }
    public func getHeight() -> Int { return height }

    // --- Customization Methods ---
    public func setCustomAnimationDelay(forType type: MazeTypes, delay: TimeInterval?) {
        if let delay = delay {
            customAnimationDelays[type] = delay
            // print("Custom animation delay for \(type.rawValue) set to \(delay)s")
        } else {
            customAnimationDelays.removeValue(forKey: type)
            // print("Custom animation delay for \(type.rawValue) removed, will use default.")
        }
    }
    
    // Enum to define maze generation algorithm types
    public enum MazeTypes: String, CaseIterable, Identifiable {
        case recursiveDFS = "Recursive DFS"
        case kruskals = "Kruskal's"
        case prims = "Prim's"
        case aldousBroder = "Aldous-Broder"
        case wilsons = "Wilson's"
        case huntAndKill = "Hunt-and-Kill"
        case sidewinder = "Sidewinder"
        public var id: String { self.rawValue }

        // Default animation delay for each algorithm type
        var defaultAnimationDelay: TimeInterval {
            switch self {
            case .recursiveDFS, .kruskals, .sidewinder:
                return 0.00001
            case .prims, .aldousBroder, .wilsons, .huntAndKill:
                return 0.0
            }
        }

    }
}
