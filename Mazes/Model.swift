//
//  Model.swift
//  Mazes
//
//  Created by acemavrick on 5/16/25.
//

import Foundation
import SwiftUI

// Enum to represent the current state of maze generation
enum MazeGenerationState {
    case idle       // Not generating, ready to start
    case generating // Actively generating
    case paused     // Generation is paused
    // Potentially: case solving // If solving becomes a longer process with its own states
}

class Model: ObservableObject {
    @Published var coordinator: Controller.Coordinator? = nil
    @Published var currentMazeAlgorithm: MazeTypes = .prims // Renamed for clarity
    @Published var currentSolveAlgorithm: SolveTypes = .bfs // Default solve algorithm
    @Published var generationState: MazeGenerationState = .idle

    // Handles tap gestures on the maze view
    public func handleMazeTap(at point: CGPoint, in size: CGSize) {
        // Only allow tap if not currently generating a maze
        if generationState != .generating {
            if currentSolveAlgorithm == .bfs {
                // If current algorithm is BFS, perform BFS fill from tap
                coordinator?.handleMazeTap(at: point, in: size)
                print("Model: BFS fill initiated by tap at cell: (\(point.x), \(point.y)) in size (\(size.width), \(size.height)).")
            } else {
                // Tap functionality for other algorithms or general interaction (if any)
                // coordinator?.handleMazeTap(at: point, in: size) // Keep if other tap interactions are needed.
                print("Maze tapped at cell: (\(point.x), \(point.y)) in size (\(size.width), \(size.height)). Current algorithm is \(currentSolveAlgorithm.rawValue). Solving is button-triggered for this algorithm.")
            }
        } else {
            print("Model: Maze tap ignored, generation in progress.")
        }
    }

    // Initiates maze generation
    public func startMazeGeneration() {
        guard generationState == .idle else {
            print("Model: Maze generation already in progress or paused.")
            return
        }
        
        generationState = .generating
        print("Model: Starting maze generation for type \(currentMazeAlgorithm.rawValue).")
        
        coordinator?.generateMaze(type: currentMazeAlgorithm, completion: { [weak self] success in
            guard let self = self else { return }
            
            if self.generationState == .generating { // Ensure state wasn't changed by a quick stop
                 self.generationState = .idle
            }
            print("Model: Maze generation finished. Success: \(success). Final state: \(self.generationState)")
        })
    }

    // Initiates maze solving
    public func startMazeSolving() {
        guard generationState == .idle else {
            print("Model: Cannot solve maze while generation is in progress or paused.")
            return
        }
        guard coordinator?.maze != nil else {
            print("Model: Maze is not available to solve.")
            return
        }
        
        print("Model: Starting maze solving using \(currentSolveAlgorithm.rawValue).")
        // Consider adding a .solving state if feedback during solving is needed
        coordinator?.solveMaze(using: currentSolveAlgorithm)
        // After solving, it remains in .idle state unless solving becomes a longer process
    }

    // Pauses the ongoing maze generation
    public func pauseMazeGeneration() {
        if generationState == .generating {
            coordinator?.pauseMazeGeneration()
            generationState = .paused
            print("Model: Pausing maze generation.")
        }
    }

    // Resumes a paused maze generation
    public func resumeMazeGeneration() {
        if generationState == .paused {
            generationState = .generating // Set state to generating before calling resume
            coordinator?.resumeMazeGeneration()
            print("Model: Resuming maze generation.")
        }
    }

    // Stops the ongoing maze generation
    public func stopMazeGeneration() {
        if generationState == .generating || generationState == .paused {
            coordinator?.stopMazeGeneration()
            generationState = .idle // Set to idle immediately as stop is final
            print("Model: Stopping maze generation.")
        }
    }
}
