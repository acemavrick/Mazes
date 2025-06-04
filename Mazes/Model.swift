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
    @Published var solvingState: MazeGenerationState = .idle // For solving algorithms
    @Published var fillState: MazeGenerationState = .idle    // For bfsFill triggered by tap

    // Handles tap gestures on the maze view
    public func handleMazeTap(at point: CGPoint, in size: CGSize) {
        // Only allow tap if no other major operation is running
        guard generationState == .idle, solvingState == .idle, fillState == .idle else {
            print("Model: Maze tap ignored, another operation is in progress (\(generationState), \(solvingState), \(fillState))")
            return
        }

        fillState = .generating // Mark fill as active
        print("Model: BFS fill initiated by tap at point: (\(point.x), \(point.y)) in size (\(size.width), \(size.height)). Setting fillState to generating.")
        
        // Call the new coordinator method that handles completion
        coordinator?.startBfsFill(at: point, in: size, completion: { [weak self] success in
            guard let self = self else { return }
            // Ensure state is reset correctly even if stop was called externally
            if self.fillState == .generating { // only transition from active to idle if not already stopped
                self.fillState = .idle
            }
            print("Model: BFS fill finished. Success: \(success). Final fillState: \(self.fillState)")
        })
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
        guard generationState == .idle, solvingState == .idle, fillState == .idle else {
            print("Model: Cannot solve maze, another operation is in progress. (\(generationState), \(solvingState), \(fillState))")
            return
        }
        guard coordinator?.maze != nil else {
            print("Model: Maze is not available to solve.")
            return
        }
        
        solvingState = .generating // Mark solving as active
        print("Model: Starting maze solving using \(currentSolveAlgorithm.rawValue). Setting solvingState to generating.")
        
        coordinator?.solveMaze(using: currentSolveAlgorithm, completion: { [weak self] success in
            guard let self = self else { return }
            // Ensure state is reset correctly
            if self.solvingState == .generating { // only transition from active to idle if not already stopped
                self.solvingState = .idle
            }
            print("Model: Maze solving finished. Success: \(success). Final solvingState: \(self.solvingState)")
        })
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

    // Pauses the ongoing maze solving
    public func pauseMazeSolving() {
        if solvingState == .generating {
            coordinator?.pauseMazeSolving()
            solvingState = .paused
            print("Model: Pausing maze solving.")
        }
    }

    // Resumes a paused maze solving
    public func resumeMazeSolving() {
        if solvingState == .paused {
            solvingState = .generating // Set state to active before calling resume
            coordinator?.resumeMazeSolving()
            print("Model: Resuming maze solving.")
        }
    }

    // Stops the ongoing maze solving
    public func stopMazeSolving() {
        if solvingState == .generating || solvingState == .paused {
            coordinator?.stopMazeSolving()
            solvingState = .idle // Set to idle immediately as stop is final
            print("Model: Stopping maze solving.")
        }
    }
}
