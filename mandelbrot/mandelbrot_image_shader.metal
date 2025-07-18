#include <metal_stdlib>
using namespace metal;

struct MandelbrotParams {
    float centerX;
    float centerY;
    float scale;
    int iterationDepth;
    int width;
    int height;
};

float3 hsvToRGB(float h, float s, float v) {
    float c = v * s;
    float hPrime = h / 60.0;
    float x = c * (1.0 - abs(fmod(hPrime, 2.0) - 1.0));
    float m = v - c;
    float3 rgb;
    if (hPrime < 1.0) rgb = float3(c, x, 0.0);
    else if (hPrime < 2.0) rgb = float3(x, c, 0.0);
    else if (hPrime < 3.0) rgb = float3(0.0, c, x);
    else if (hPrime < 4.0) rgb = float3(0.0, x, c);
    else if (hPrime < 5.0) rgb = float3(x, 0.0, c);
    else rgb = float3(c, 0.0, x);
    return rgb + m;
}

kernel void mandelbrotShader(
    texture2d<float, access::write> output [[texture(0)]],
    constant MandelbrotParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= uint(params.width) || gid.y >= uint(params.height)) return;

    float x0 = params.centerX + (float(gid.x) / float(params.width) - 0.5) * params.scale * 2.0;
    float y0 = params.centerY + (float(gid.y) / float(params.height) - 0.5) * params.scale * 2.0;
    float x = 0.0;
    float y = 0.0;
    int iteration = 0;

    while (iteration < params.iterationDepth && x * x + y * y <= 4.0) {
        float xtemp = x * x - y * y + x0;
        y = 2.0 * x * y + y0;
        x = xtemp;
        iteration++;
    }

    float4 color;
    if (iteration < params.iterationDepth) {
        float smoothIter = float(iteration) + 1.0 - log2(max(1e-10, log2(x * x + y * y)));
        float hue = fmod(smoothIter / float(params.iterationDepth) * 360.0, 360.0);
        float saturation = 0.9;
        float value = min(0.7 + smoothIter / float(params.iterationDepth) * 0.3, 1.0);
        float3 rgb = hsvToRGB(hue, saturation, value);
        color = float4(rgb, 1.0);
    } else {
        color = float4(0.0, 0.0, 0.0, 1.0);
    }

    output.write(color, gid);
}
