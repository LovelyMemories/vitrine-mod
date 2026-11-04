#include <metal_stdlib>
using namespace metal;
#ifndef SGA_COMPOSED
#include "SGAmbientShared.h"
#endif

struct SGAVertex {
    float4 position [[position]];
    float2 uv;
};

vertex SGAVertex sgaFullscreen(uint id [[vertex_id]]) {
    float2 p = float2(float((id << 1) & 2), float(id & 2));
    SGAVertex out;
    out.position = float4(p * 2.0 - 1.0, 0.0, 1.0);
    out.uv = float2(p.x, 1.0 - p.y);
    return out;
}

// The procedural cabin's fire: x across, and the flames' root as a share of the height. Its plate holds the room
// the fire lights; the flames are drawn live over it (sgaHearthFire).
constant float2 sgaHearth = float2(0.5, 0.80);

constexpr sampler sgaLinear(filter::linear, mip_filter::linear, address::clamp_to_edge);
constexpr sampler sgaLinearWrapX(filter::linear, mip_filter::linear, s_address::repeat, t_address::clamp_to_edge);
constexpr sampler sgaWrap(filter::linear, mip_filter::linear, address::repeat);

// Integer hashing: no sin(), so it stays stable at large coordinates and on every GPU.
inline uint sgaHashU(uint x) {
    x ^= x >> 16;
    x *= 0x7feb352du;
    x ^= x >> 15;
    x *= 0x846ca68bu;
    x ^= x >> 16;
    return x;
}

inline float sgaHash(int2 cell, uint seed) {
    uint h = sgaHashU(uint(cell.x) * 0x8da6b343u ^ uint(cell.y) * 0xd8163841u ^ seed * 0xcb1ab31fu);
    return float(h & 0xffffffu) / 16777216.0;
}

inline float2 sgaHash2(int2 cell, uint seed) {
    return float2(sgaHash(cell, seed), sgaHash(cell, seed + 0x51u));
}

inline float sgaHash1(float x, uint seed) {
    return sgaHash(int2(int(floor(x)), 0), seed);
}

// Value noise with a quintic fade, periodic in x over `period` cells when period > 0.
inline float sgaNoise(float2 p, uint seed, int period) {
    float2 i = floor(p), f = p - i;
    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    int2 c = int2(i);
    int2 c1 = c + int2(1, 0), c2 = c + int2(0, 1), c3 = c + int2(1, 1);
    if (period > 0) {
        c.x = ((c.x % period) + period) % period;
        c1.x = ((c1.x % period) + period) % period;
        c2.x = c.x;
        c3.x = c1.x;
    }
    float a = sgaHash(c, seed), b = sgaHash(c1, seed), d = sgaHash(c2, seed), e = sgaHash(c3, seed);
    return mix(mix(a, b, u.x), mix(d, e, u.x), u.y);
}

inline float sgaFbm(float2 p, uint seed, int octaves, int period) {
    float sum = 0.0, amp = 0.5, norm = 0.0;
    for (int i = 0; i < octaves; i++) {
        sum += amp * sgaNoise(p, seed + uint(i) * 17u, period);
        norm += amp;
        amp *= 0.5;
        // Exactly 2 keeps a periodic noise periodic; otherwise a little off it hides the octaves' grid.
        p = p * (period > 0 ? 2.0 : 2.03) + 11.7;
        period *= 2;
    }
    return sum / norm;
}

inline float sgaLuma(float3 c) {
    return dot(c, float3(0.2126, 0.7152, 0.0722));
}

inline float3 sgaToLinear(float3 c) {
    return select(pow((c + 0.055) / 1.055, 2.4), c / 12.92, c <= 0.04045);
}

inline float3 sgaToSRGB(float3 c) {
    c = max(c, 0.0);
    return select(1.055 * pow(c, 1.0 / 2.4) - 0.055, c * 12.92, c <= 0.0031308);
}

// A cubic B-spline lookup from four bilinear ones: a magnified small mip stays smooth instead of showing
// its texel grid. The taps are placed on one mip's grid, so a fractional level takes one lookup per mip.
inline float3 sgaCubicAt(texture2d<float> t, sampler s, float2 uv, uint mip) {
    float2 size = float2(t.get_width(mip), t.get_height(mip));
    float2 p = uv * size - 0.5, i = floor(p), f = p - i;
    float2 f2 = f * f, f3 = f2 * f;
    float2 w0 = (1.0 - 3.0 * f + 3.0 * f2 - f3) / 6.0;
    float2 w1 = (4.0 - 6.0 * f2 + 3.0 * f3) / 6.0;
    float2 w2 = (1.0 + 3.0 * f + 3.0 * f2 - 3.0 * f3) / 6.0;
    float2 w3 = f3 / 6.0;
    float2 g0 = w0 + w1, g1 = w2 + w3;
    float2 h0 = (w1 / g0 - 1.0 + i + 0.5) / size, h1 = (w3 / g1 + 1.0 + i + 0.5) / size;
    float lod = float(mip);
    float3 a = t.sample(s, float2(h0.x, h0.y), level(lod)).rgb;
    float3 b = t.sample(s, float2(h1.x, h0.y), level(lod)).rgb;
    float3 c = t.sample(s, float2(h0.x, h1.y), level(lod)).rgb;
    float3 d = t.sample(s, float2(h1.x, h1.y), level(lod)).rgb;
    return g0.y * (g0.x * a + g1.x * b) + g1.y * (g0.x * c + g1.x * d);
}

inline float3 sgaSmooth(texture2d<float> t, sampler s, float2 uv, float lod) {
    lod = clamp(lod, 0.0, float(t.get_num_mip_levels() - 1));
    uint below = uint(floor(lod));
    float between = lod - float(below);
    float3 c = sgaCubicAt(t, s, uv, below);
    if (between > 0.01) c = mix(c, sgaCubicAt(t, s, uv, below + 1u), between);
    return c;
}
#endif
