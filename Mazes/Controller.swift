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
        
        func generateMaze(type: Maze.MazeTypes, completion: @escaping (Bool) -> Void) {
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
        
        func handleMazeTap(at point: CGPoint, in size: CGSize) {
            guard let maze = self.maze else {
                print("Error: Maze object not initialized.")
                return
            }
            
            let mazeWidth = maze.getWidth()
            let mazeHeight = maze.getHeight()
            
            let ds = CGFloat(self.displayScale)
            let physicalTapX = point.x * ds
            let physicalTapY = point.y * ds

            // Calculate physical cell size, mirroring shader logic
            // uniforms.resolution is already in physical pixels.
            // mazeWidth/mazeHeight (local vars) are in cells.
            guard mazeWidth > 0, mazeHeight > 0 else {
                print("Error: Maze dimensions (cells) are zero.")
                return
            }
            guard self.uniforms.resolution.x > 0, self.uniforms.resolution.y > 0 else {
                print("Error: Uniforms resolution (physical pixels) is zero.")
                return
            }

            let cellWidth = CGFloat(self.uniforms.cellSize)
            
            // get the col and row from the tap
            let col = Int(physicalTapX / cellWidth)
            let row = Int(physicalTapY / cellWidth)
            
            // Ensure the tap is within bounds
            guard row >= 0, row < mazeHeight, col >= 0, col < mazeWidth else { 
                print("Tap out of bounds: (row: \(row), col: \(col)) - Maze (h: \(mazeHeight), w: \(mazeWidth))")
                return
            }
            
            //            print("Filling from cell: (\(row), \(col))")
            // maze.resetFillState()
            maze.bfsFill(fromx: col, fromy: row)
            print("Called bfsFill(fromx: \(col), fromy: \(row))")
//             for _ in 0..<50 {
//                 let x = Int.random(in: 0..<mazeHeight)
//                 let y = Int.random(in: 0..<mazeWidth)
//                 maze.bfsFill(fromx: x, fromy: y)
//             }
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
            uniforms.time += deltaTime

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
