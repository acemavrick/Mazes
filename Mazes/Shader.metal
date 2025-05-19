//
//  Shader.metal
//  Mazes
//
//  Created by acemavrick on 5/15/25.
//

#include <metal_stdlib>
#define default_color float4(1.0)
#define default_transparent float4(0.0)
using namespace metal;

// current time (seconds) and viewport size (pixels)
struct Uniforms {
    float time;
    float2 resolution;
    float2 mazeDims;
    float cellSize;
};

struct Cell {
    float2 posCR; // column, row
    
    int northWall; // 1 = wall, 0 = no wall
    int eastWall; // 1 = wall, 0 = no wall
    int southWall; // 1 = wall, 0 = no wall
    int westWall; // 1 = wall, 0 = no wall
    // will be used to determine fill color (distance along trail)
    int dist; // distance along trail
    // for use in fill algorithm
    int visited; // 1 = visited, 0 = not visited
    int _padding;
};
    

vertex float4 main_vertex(uint vertexID [[vertex_id]]) {
    float4 positions[6] = {
        float4(-1.0, -1.0, 0.0, 1.0),
        float4( 1.0, -1.0, 0.0, 1.0),
        float4(-1.0,  1.0, 0.0, 1.0),
        float4(-1.0,  1.0, 0.0, 1.0),
        float4( 1.0, -1.0, 0.0, 1.0),
        float4( 1.0,  1.0, 0.0, 1.0)
    };
    return positions[vertexID];
}

inline float pulse(float phase) {
    return smoothstep(0.0, 1.0, abs(fract(phase * 0.5 + 0.5) * 2.0 - 1.0));
}

// color
fragment float4 color_fragment(float4 coord [[position]],
                         constant Uniforms& uniforms [[buffer(0)]],
                               constant Cell *cells [[buffer(1)]]) {
    // compute cell‐space coords
    float2 gridPos   = coord.xy / uniforms.cellSize;
    
    // check if out of bounds
    float inX = step(0.0, gridPos.x) * step(gridPos.x, uniforms.mazeDims.x);
    float inY = step(0.0, gridPos.y) * step(gridPos.y, uniforms.mazeDims.y);
    float inBounds = inX * inY;
    
    // clamp to valid cell indices
    int maxCol = int(uniforms.mazeDims.x) - 1;
    int maxRow = int(uniforms.mazeDims.y) - 1;
    int colSafe = clamp(int(gridPos.x), 0, maxCol);
    int rowSafe = clamp(int(gridPos.y), 0, maxRow);
    
    // compute index
    int index = rowSafe * int(uniforms.mazeDims.x) + colSafe;
    Cell cell = cells[index];
    
    if (cell.dist == -1) return default_color;
    
    // local pixel position within each cell
    float2 posInCell = fract(gridPos) * uniforms.cellSize;

    float phase = uniforms.time * 0.5 - float(cell.dist) * 0.01;
    
    float p = pulse(phase);
    
    float3 colorA = float3(0.5, 0.3, 0.7);
    float3 colorB = float3(0.7, 0.9, 1.0);
    
    float3 rgb = mix(colorA, colorB, p);
    
    return float4(rgb, 1.0);
}
        


// draw borders
fragment float4 border_fragment(float4 coord [[position]],
                             constant Uniforms& uniforms [[buffer(0)]],
                             constant Cell *cells [[buffer(1)]]) {
    // compute cell‐space coords
    float2 gridPos   = coord.xy / uniforms.cellSize;

    // check if out of bounds
    float inX = step(0.0, gridPos.x) * step(gridPos.x, uniforms.mazeDims.x);
    float inY = step(0.0, gridPos.y) * step(gridPos.y, uniforms.mazeDims.y);
    float inBounds = inX * inY;

    // local pixel position within each cell
    float2 posInCell = fract(gridPos) * uniforms.cellSize;

    // clamp to valid cell indices
    int maxCol = int(uniforms.mazeDims.x) - 1;
    int maxRow = int(uniforms.mazeDims.y) - 1;
    int colSafe = clamp(int(gridPos.x), 0, maxCol);
    int rowSafe = clamp(int(gridPos.y), 0, maxRow);

    // compute index
    int index = rowSafe * int(uniforms.mazeDims.x) + colSafe;

    Cell cell = cells[index];
    
    float4 oobColor = default_color;
    float color = 1.0;
    float thickness = max(uniforms.cellSize/20, 1.0);
    float mthickness = uniforms.cellSize - thickness;

    // [dir] wall missing & [x|y] ≤ thickness ? zero
    color *= 1.0 - step(posInCell.y, thickness) * (1.0 - float(cell.northWall));
    color *= 1.0 - step(posInCell.x, thickness) * (1.0 - float(cell.westWall));
    color *= 1.0 - step(mthickness, posInCell.x) * (1.0 - float(cell.eastWall));
    color *= 1.0 - step(mthickness, posInCell.y) * (1.0 - float(cell.southWall));
    float4 cellColor = float4(color, color, color, 1.0 - color);
    return mix(oobColor, cellColor, inBounds);
}
