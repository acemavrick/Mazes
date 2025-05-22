//
//  Shader.metal
//  Mazes
//
//  Created by acemavrick on 5/15/25.
//

#include <metal_stdlib>
using namespace metal;

// Default colors
#define DEFAULT_COLOR float4(0.95, 0.95, 0.95, 1.0)  // Light gray for unvisited cells
#define TRANSPARENT float4(0.0)

// current time (seconds) and viewport size (pixels)
struct Uniforms {
    float time;
    float2 resolution;
    float2 mazeDims;
    float cellSize;
    int maxDist;
};

struct Cell {
    float2 posCR; // column, row
    
    int northWall; // 1 = wall, 0 = no wall
    int eastWall;  // 1 = wall, 0 = no wall
    int southWall; // 1 = wall, 0 = no wall
    int westWall;  // 1 = wall, 0 = no wall
    int dist;      // distance from start (-1 = unvisited)
    int genVisited;   // 1 = visited, 0 = not visited
    int fillVisited;
};

// Earth Tones Gradient for distance-based coloring
float3 getColorForDistance(float t) {
    const float3 colors[10] = {
        float3(0.45, 0.30, 0.15), // 1. Deep Brown
        float3(0.75, 0.45, 0.25), // 2. Terracotta
        float3(0.85, 0.75, 0.55), // 3. Sandy Beige
        float3(0.40, 0.50, 0.30), // 4. Moss Green
        float3(0.55, 0.60, 0.35),  // 5. Muted Olive
        float3(0.65, 0.87, 0.85), // 6. Crystal
        float3(0.05, 0.75, 0.35),  // 7. Tiffany Blue
        float3(0.41, 0.51, 0.91),  // 8. Cornflower Blue
        float3(0.65, 0.87, 0.85),  // 9. Palatinate Blue
        float3(0.45, 0.30, 0.15) // 1. Deep Brown
    };
    
    t = clamp(t, 0.0, 1.0); // Ensure t is within [0,1]
    float scaledT = t * 9.0; // Scale t to map across the (n-1) transitions between (n) colors
    int index = min(8, int(floor(scaledT))); // Select the first color in the pair
    float localT = fract(scaledT); // Get the interpolation factor within the pair
    
    return mix(colors[index], colors[index + 1], localT);
}

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

// Color fragment shader for distance-based cell coloring
fragment float4 color_fragment(float4 coord [[position]],
                         constant Uniforms& uniforms [[buffer(0)]],
                         constant Cell *cells [[buffer(1)]]) {
    // Compute cell-space coordinates
    float2 gridPos = coord.xy / uniforms.cellSize;
    
    // Check if out of bounds
    float inX = step(0.0, gridPos.x) * step(gridPos.x, uniforms.mazeDims.x);
    float inY = step(0.0, gridPos.y) * step(gridPos.y, uniforms.mazeDims.y);
    float inBounds = inX * inY;
    
    // Clamp to valid cell indices
    int maxCol = int(uniforms.mazeDims.x) - 1;
    int maxRow = int(uniforms.mazeDims.y) - 1;
    int colSafe = clamp(int(gridPos.x), 0, maxCol);
    int rowSafe = clamp(int(gridPos.y), 0, maxRow);
    
    // Compute index and get cell data
    int index = rowSafe * int(uniforms.mazeDims.x) + colSafe;
    Cell cell = cells[index];
    
    // Return default color for unvisited cells or out of bounds
    if (cell.fillVisited == 0 || inBounds < 0.5) {
        return DEFAULT_COLOR;
    }
    
    // Calculate normalized distance (0 to 1) for color mapping
    // use a max distance to ensure colors repeat nicely
    const float maxDist = uniforms.maxDist;
    float normalizedDist = fract(float(cell.dist) / maxDist);
    
    // Get color from gradient
    float3 color = getColorForDistance(normalizedDist);
    
    // Slower, outward, asymmetrical wave with more contrast
    float phase = uniforms.time * 1.2 - float(cell.dist) * 0.1; // Slower wave speed, outward direction
    float wave_val = (sin(phase) + 1.0) * 0.5; // Normalize sin output to 0.0 (trough) - 1.0 (peak)
    
    // Shape the wave: make dark parts (low wave_val) longer, light parts (high wave_val) shorter and sharper.
    // pow(1.0 - wave_val, N) makes the peak (wave_val=1) component shorter.
    // 1.0 - pow(1.0 - wave_val, N) inverts this, making the trough (wave_val=0) component longer.
    float shaped_wave = pow(1.0 - wave_val, 4.0); // Exponent 3.0 for more emphasis on dark duration

    // Apply to pulse: range 0.5 (darkest) to 1.0 (brightest) -> 50% brightness reduction at darkest
    float pulse = 0.5 + 0.5 * shaped_wave; 
    color *= pulse;
    
    // Apply a subtle vignette effect based on distance from center
    float2 center = uniforms.mazeDims * 0.5;
    float distFromCenter = distance(gridPos, center) / length(center);
    float vignette = 1.0 - smoothstep(0.7, 1.0, distFromCenter) * 0.3;
    color *= vignette;
    
    return float4(color, 1.0);
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
    
    float4 oobColor = DEFAULT_COLOR;
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
