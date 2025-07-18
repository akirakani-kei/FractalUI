#include <metal_stdlib>
using namespace metal;

struct MandelbrotParams {
    float2 center;
    float scale;
    uint iterations;
    uint2 viewportSize;
};

float3 hsv2rgb(float3 hsv) {
    float h = hsv.x, s = hsv.y, v = hsv.z;
    float3 k = float3(1.0, 2.0/3.0, 1.0/3.0);
    float3 p = abs(fract(float3(h) + k) * 6.0 - 3.0);
    return v * mix(k.xxx, clamp(p - k.xxx, 0.0, 1.0), s);
}

kernel void mandelbrotKernel(
    texture2d<float, access::write> output [[texture(0)]],
    constant MandelbrotParams &params [[buffer(0)]],
    uint2 gid [[thread_position_in_grid]]
) {
    if (gid.x >= params.viewportSize.x || gid.y >= params.viewportSize.y) return;

    float aspectRatio = float(params.viewportSize.x) / float(params.viewportSize.y);
    float2 uv = float2(gid) / float2(params.viewportSize);
    float2 c = params.center + (uv - 0.5) * params.scale * float2(1.0, 1.0 / aspectRatio);

    float2 z = 0.0;
    uint i = 0;
    float len = 0.0;
    for (; i < params.iterations; ++i) {
        z = float2(z.x * z.x - z.y * z.y + c.x, 2.0 * z.x * z.y + c.y);
        len = dot(z, z);
        if (len > 4.0) break;
    }

    if (i == params.iterations) {
        output.write(float4(0.0, 0.0, 0.0, 1.0), gid);
        return;
    }

    float smoothIter = float(i) + 1.0 - log2(max(1.0, log2(len)));
    float color = smoothIter / float(params.iterations);

    float3 hsv = float3(color * 0.7, 0.9, 0.9);
    float3 rgb = hsv2rgb(hsv);
    output.write(float4(rgb, 1.0), gid);
}
