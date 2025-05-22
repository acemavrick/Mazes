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
}

class Model: ObservableObject {
    @Published var coordinator: Controller.Coordinator? = nil
    @Published var currentOption: Maze.MazeTypes = .prims
    @Published var generationState: MazeGenerationState = .idle

    // Handles tap gestures on the maze view
    public func handleMazeTap(at point: CGPoint, in size: CGSize) {
        // Only allow tap if not currently generating a maze
        if generationState != .generating {
            coordinator?.handleMazeTap(at: point, in: size)
        }
    }

    // Initiates maze generation
    public func startMazeGeneration() {
        guard generationState == .idle else {
            print("Model: Maze generation already in progress or paused.")
            return
        }
        
        generationState = .generating
        print("Model: Starting maze generation for type \(currentOption.rawValue).")
        
        // The actual generation happens on a background thread within Maze.swift
        // The coordinator will call Maze's generate method which now has a completion handler
        coordinator?.generateMaze(type: currentOption, completion: { [weak self] success in
            // This completion block is called on the main thread from Maze.swift
            guard let self = self else { return }
            
            // If generation wasn't manually stopped and is still in a 'generating' state,
            // it means it completed normally or via an internal error (not user stop).
            // If it was stopped, the state would have been changed by stopMazeGeneration.
            if self.generationState == .generating {
                 self.generationState = .idle
            }
            print("Model: Maze generation finished. Success: \(success). Final state: \(self.generationState)")
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
}
