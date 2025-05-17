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
        var renderState: MTLRenderPipelineState?
        var commandQueue: MTLCommandQueue?
        var lastUpdateTime: CFTimeInterval = 0
        
//        var DEF_START_DIM: Int = 50
        var DEF_START_DIM: Int = 300

        #if os(macOS)
        var displayScale: Float = 1.0
        #endif
        
        init(_ parent: Controller, model: Model) {
            self.model = model
            self.parent = parent
            self.uniforms = Uniforms()
            super.init()
            model.coordinator = self
            setupMetal()
            self.maze = Maze(device: self.device!, width: DEF_START_DIM, height: DEF_START_DIM)
            self.uniforms.setMazeDims(height: DEF_START_DIM, width: DEF_START_DIM)
        }
        
        func generateMaze(type: MazeTypes) {
            self.maze!.generate(type: type)
        }
        
        func setupMetal() {
            guard let device = MTLCreateSystemDefaultDevice() else {
                fatalError("Metal is not supported on this device.")
            }
            self.device = device
            
            self.commandQueue = device.makeCommandQueue()
            
            let library = device.makeDefaultLibrary()
            
            let vertexFunction = library?.makeFunction(name: "main_vertex")
            let fragmentFunction = library?.makeFunction(name: "main_fragment")
            
            let renderPipelineDescriptor = MTLRenderPipelineDescriptor()
            renderPipelineDescriptor.vertexFunction = vertexFunction
            renderPipelineDescriptor.fragmentFunction = fragmentFunction
            renderPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm

            do {
                self.renderState = try device.makeRenderPipelineState(descriptor: renderPipelineDescriptor)
            } catch {
                fatalError("Unable to compile render pipeline state: \(error)")
            }
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            if uniforms.setResolution(size) {
                #if os(macOS)
                if let window = view.window {
                    self.displayScale = Float(window.backingScaleFactor)
                }
                #endif
            }
        }
        
        func draw(in view: MTKView) {
            // update time
            let currentTime = CACurrentMediaTime()
            let deltaTime: Float = Float(currentTime - lastUpdateTime)
            lastUpdateTime = currentTime
            uniforms.time += deltaTime
            
            guard let drawable = view.currentDrawable,
                  let commandQueue = self.commandQueue,
                  let renderState = self.renderState else { return }
            
            let commandBuffer = commandQueue.makeCommandBuffer()
            
            guard let renderPassDescriptor = view.currentRenderPassDescriptor,
                  let renderEncoder = commandBuffer?.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else { return }
            
            renderEncoder.setRenderPipelineState(renderState)
            
            renderEncoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 0)
            renderEncoder.setFragmentBuffer(maze!.getCellBuffer(), offset: 0, index: 1)
            
            // Draw full-screen quad
            renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 6)
            renderEncoder.endEncoding()
            
            commandBuffer?.present(drawable)
            commandBuffer?.commit()
        }
    }
}

// Type erasure for multi-platform compatibility
#if os(iOS)
typealias ViewRepresentable = UIViewRepresentable
#elseif os(macOS)
typealias ViewRepresentable = NSViewRepresentable
#endif
