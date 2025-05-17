//
//  Shader.metal
//  Mazes
//
//  Created by acemavrick on 5/15/25.
//

#include <metal_stdlib>
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

// A colorful plasma effect combining UV and time
fragment float4 main_fragment(float4 coord [[position]],
                             constant Uniforms& uniforms [[buffer(0)]],
                             constant Cell *cells [[buffer(1)]]) {
    
    int col = coord.x / uniforms.cellSize;
    int row = coord.y / uniforms.cellSize;
    
    if (col < 0 || col >= uniforms.mazeDims.x || row < 0 || row >= uniforms.mazeDims.y) {
        return float4(1.0);
    }

    float2 posInCell = fmod(coord.xy, uniforms.cellSize);
    int index = row * uniforms.mazeDims.x + col;
    
    Cell cell = cells[index];
    
    float color = 1.0;
    float thickness = max(uniforms.cellSize/20, 1.0);
    float mthickness = uniforms.cellSize - thickness;
    if (cell.northWall == 0 && posInCell.y <= thickness) color = 0;
    if (cell.westWall == 0 && posInCell.x <= thickness) color = 0;
    if (cell.eastWall == 0 && posInCell.x >= mthickness) color = 0;
    if (cell.southWall == 0 && posInCell.y >= mthickness) color = 0;
//    color += cell.westWall * step(uniforms.cellSize / div, posInCell.x);
//    color += cell.eastWall * step(posInCell.x, 2 * uniforms.cellSize/3);
//    color += cell.southWall * step(posInCell.y, 2 * uniforms.cellSize/3);
//    color = 1 - color;
    return float4(float3(color), 1.0);
}
