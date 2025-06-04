//
//  Controller.swift
//  Mazes
//
//  Created by acemavrick on 5/15/25.
//

import Foundation
import SwiftUI
import MetalKit
import Combine

// Unified controller for iOS and macOS
struct Controller: ViewRepresentable {
    @ObservedObject var model: Model
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self, model: self.model)
    }
    
    // MARK: - Platform-specific implementations
    #if os(iOS)
    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        setupView(view, context: context)
        return view
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        // Updates handled by MTKViewDelegate
    }
    
    typealias UIViewType = MTKView
    #elseif os(macOS)
    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        setupView(view, context: context)
        return view
    }
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        // Updates handled by MTKViewDelegate
    }
    
    typealias NSViewType = MTKView
    #endif
    
    // Common setup for both platforms
    private func setupView(_ view: MTKView, context: Context) {
        view.device = MTLCreateSystemDefaultDevice()
        view.delegate = context.coordinator
        view.framebufferOnly = false
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        #if os(iOS)
        view.enableSetNeedsDisplay = false
        #endif
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, MTKViewDelegate {
        var model: Model
        var parent: Controller
        var device: MTLDevice?
        var maze: Maze?
        var uniforms: Uniforms
        var renderColorState: MTLRenderPipelineState?
        var renderBorderState: MTLRenderPipelineState?
        var commandQueue: MTLCommandQueue?
        var lastUpdateTime: CFTimeInterval = 0
        
        
        
        #if os(macOS)
        var DEF_START_DIM: Int = 300
        #elseif os(iOS)
        var DEF_START_DIM: Int = 100
        #endif

        var displayScale: Float = 1.0
        
        init(_ parent: Controller, model: Model) {
            self.model = model
            self.parent = parent
            self.uniforms = Uniforms()
            super.init()
            model.coordinator = self
            setupMetal()
            self.maze = Maze(device: self.device!, width: DEF_START_DIM, height: DEF_START_DIM, coordinator: self)
            _ = self.uniforms.setMazeDims(height: DEF_START_DIM, width: DEF_START_DIM)
        }
        
        func generateMaze(type: MazeTypes, completion: @escaping (Bool) -> Void) {
            guard let maze = self.maze else {
                print("Coordinator: Maze object not initialized.")
                completion(false)
                return
            }
            // Call the new generate method in Maze.swift which handles async and completion
            maze.generate(type: type, completion: completion)
        }

        // Add these new methods for controlling maze generation
        func pauseMazeGeneration() {
            self.maze?.pauseGeneration()
        }

        func resumeMazeGeneration() {
            self.maze?.resumeGeneration()
        }

        func stopMazeGeneration() {
            self.maze?.stopGeneration()
        }
        
        // New method to be called by the Model to start solving
        func solveMaze(using algo: SolveTypes) {
            solveMaze(using: algo, completion: { _ in }) // Call new one with dummy completion
        }

        // Updated method to be called by the Model to start solving with completion
        func solveMaze(using algo: SolveTypes, completion: @escaping (Bool) -> Void) {
            guard let maze = self.maze else {
                print("Coordinator: Maze object not initialized, cannot solve.")
                completion(false)
                return
            }
            // Ensure maze is not currently being generated before attempting to solve
            // The Model should ideally guard this, but an extra check here is fine.
            // if model.generationState == .generating { print("Coordinator: Cannot solve while generating."); return }
            
            print("Coordinator: Telling Maze to solve using \(algo.rawValue).")
            maze.start_solve(using: algo, completion: completion)
        }
        
        func handleMazeTap(at point: CGPoint, in size: CGSize) {
            // This method will likely be deprecated in favor of startBfsFill with completion
            // For now, call startBfsFill with a dummy completion if this is still used.
            startBfsFill(at: point, in: size, completion: { success in
                print("Legacy handleMazeTap to bfsFill completed: \(success)")
            })
        }

        // New method for initiating bfsFill with completion handler
        func startBfsFill(at point: CGPoint, in size: CGSize, completion: @escaping (Bool) -> Void) {
            guard let maze = self.maze else {
                print("Coordinator: Maze object not initialized for bfsFill.")
                completion(false)
                return
            }
            
            let mazeWidth = maze.getWidth()
            let mazeHeight = maze.getHeight()
            
            let col: Int
            let row: Int
            
            #if os(iOS)
            let normalizedX = point.x / size.width
            let normalizedY = point.y / size.height
            col = Int(normalizedX * CGFloat(mazeWidth))
            row = Int(normalizedY * CGFloat(mazeHeight))
            #else // macOS
            let ds = CGFloat(self.displayScale)
            let physicalTapX = point.x * ds
            let physicalTapY = point.y * ds
            let cellWidthValue = CGFloat(self.uniforms.cellSize)
            // Ensure cellWidth is not zero to prevent division by zero
            guard cellWidthValue > 0 else {
                print("Coordinator: Cell width is zero, cannot calculate tap position for bfsFill.")
                completion(false)
                return
            }
            col = Int(physicalTapX / cellWidthValue)
            row = Int(physicalTapY / cellWidthValue)
            #endif
            
            guard row >= 0, row < mazeHeight, col >= 0, col < mazeWidth else { 
                print("Coordinator: Tap out of bounds for bfsFill: (row: \(row), col: \(col)) - Maze (h: \(mazeHeight), w: \(mazeWidth))")
                completion(false)
                return
            }
            
            print("Coordinator: Calling bfsFill(fromx: \(col), fromy: \(row)) with completion.")
            maze.bfsFill(fromx: col, fromy: row, completion: completion)
        }

        // --- Solving Control Passthrough Methods ---
        func pauseMazeSolving() {
            self.maze?.pauseSolving()
        }

        func resumeMazeSolving() {
            self.maze?.resumeSolving()
        }

        func stopMazeSolving() {
            self.maze?.stopSolving()
        }

        // --- Filling Control Passthrough Methods ---
        func pauseMazeFilling() {
            self.maze?.pauseFilling()
        }

        func resumeMazeFilling() {
            self.maze?.resumeFilling()
        }

        func stopMazeFilling() {
            self.maze?.stopFilling()
        }
        
        func setupMetal() {
            guard let device = MTLCreateSystemDefaultDevice() else {
                fatalError("Metal is not supported on this device.")
            }
            self.device = device
            
            self.commandQueue = device.makeCommandQueue()
            
            let library = device.makeDefaultLibrary()
            
            let vertexFunction = library?.makeFunction(name: "main_vertex")
            let colorFragmentFunction = library?.makeFunction(name: "color_fragment")
            let borderFragmentFunction = library?.makeFunction(name: "border_fragment")
            
            let renderBorderPipelineDescriptor = MTLRenderPipelineDescriptor()
            renderBorderPipelineDescriptor.vertexFunction = vertexFunction
            renderBorderPipelineDescriptor.fragmentFunction = borderFragmentFunction
            renderBorderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
            renderBorderPipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
            renderBorderPipelineDescriptor.colorAttachments[0].rgbBlendOperation = .add
            renderBorderPipelineDescriptor.colorAttachments[0].alphaBlendOperation = .add
            renderBorderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
            renderBorderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
            renderBorderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
            renderBorderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            
            let renderColorPipelineDescriptor = MTLRenderPipelineDescriptor()
            renderColorPipelineDescriptor.vertexFunction = vertexFunction
            renderColorPipelineDescriptor.fragmentFunction = colorFragmentFunction
            renderColorPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            do {
                self.renderColorState = try device.makeRenderPipelineState(descriptor: renderColorPipelineDescriptor)
                self.renderBorderState = try device.makeRenderPipelineState(descriptor: renderBorderPipelineDescriptor)
            } catch {
                fatalError("Unable to compile render pipeline state: \(error)")
            }
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            if uniforms.setResolution(size) {
                if let window = view.window {
                    #if os(macOS)
                    self.displayScale = Float(window.backingScaleFactor)
                    #endif
                    #if os(iOS)
                    self.displayScale = Float(window.contentScaleFactor)
                    #endif
                }
            }
        }
        
        func draw(in view: MTKView) {
            // update time…
            let currentTime = CACurrentMediaTime()
            let deltaTime: Float = Float(currentTime - lastUpdateTime)
            lastUpdateTime = currentTime
            
            #if os(iOS)
            uniforms.time += 1.0/Float(view.preferredFramesPerSecond)
            #else
            uniforms.time += deltaTime
            #endif


            guard let drawable        = view.currentDrawable,
                  let descriptor      = view.currentRenderPassDescriptor,
                  let queue           = commandQueue,
                  let borderPipeline  = renderBorderState,
                  let colorPipeline   = renderColorState else { return }

            let cmdBuf = queue.makeCommandBuffer()!

            let encoder = cmdBuf.makeRenderCommandEncoder(descriptor: descriptor)!
            encoder.setFragmentBytes(&uniforms,
                                     length: MemoryLayout<Uniforms>.stride,
                                     index: 0)
            encoder.setFragmentBuffer(maze!.getCellBuffer(),
                                      offset: 0,
                                      index: 1)

            // first draw: color
            encoder.setRenderPipelineState(colorPipeline)
            encoder.drawPrimitives(type: .triangleStrip,
                                   vertexStart: 0,
                                   vertexCount: 6)
            
            // second draw: borders
            encoder.setRenderPipelineState(borderPipeline)
            encoder.drawPrimitives(type: .triangleStrip,
                                   vertexStart: 0,
                                   vertexCount: 6)

            encoder.endEncoding()

            cmdBuf.present(drawable)
            cmdBuf.commit()
        }
    }
}

// Type erasure for multi-platform compatibility
#if os(iOS)
typealias ViewRepresentable = UIViewRepresentable
#elseif os(macOS)
typealias ViewRepresentable = NSViewRepresentable
#endif
