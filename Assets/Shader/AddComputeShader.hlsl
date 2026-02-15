#include"BasicType.hlsli"

cbuffer cbuff0 : register(b0)
{
    float2 time; // x = elapsedTime, y = deltaTime
    float2 resolution; // x = width, y = height
    matrix mat;
};

StructuredBuffer<float> gFFTAmplitude : register(t1);
RWStructuredBuffer<int> computeTex : register(u0);

#define PI 3.14159265
#define PI2 (PI * 2.0)
#define Speed 0.5
#define Pers 0.5
#define Lacu 1.5

float hash(float p)
{
    uint x = asuint(p);
    x = ((x >> 8u) ^ x) * 1106585295u;
    x = ((x >> 8u) ^ x) * 1283515847u;
    x = ((x >> 8u) ^ x) * 1145617283u;
    return float(x) / float(0xFFFFFFFFu);
}

float random(inout float seed)
{
    seed += 1.0;
    return hash(seed);
}

float2 hash_sphare(inout float seed)
{
    float r = random(seed);
    float a = random(seed) * PI2;
    return float2(cos(a), sin(a)) * r;
}

float2x2 rotate2D(float angle)
{
    float c = cos(angle);
    float s = sin(angle);
    return float2x2(c, -s, s, c);
}

float3x3 camera(float3 direction)
{
    float3 dir = normalize(direction);
    float3 u = lerp(float3(0.0, 0.0, 1.0), float3(1.0, 1.0, 0.0), abs(dir.y) < 0.999);
    float3 side = normalize(cross(dir, u));
    float3 up = cross(side, dir);
    return float3x3(side, up, dir);
}

float2 proj(float3 pos, float3 ro, float3x3 cam, float fov, float dofFocus, float dofAmount, inout float seed)
{
    float3 p = pos - ro;
    p = mul(cam, p);
    if (p.z < 0.0) { return float2(-1.0, -1.0); }
    p.xy /= p.z * tan(radians(fov) * 0.5);
    p.xy += hash_sphare(seed) * abs(p.z - dofFocus) * dofAmount;
    return (p.xy * float2(resolution.y / resolution.x, 1.0) + 0.5) * resolution;
}

float3 cyclic(float3 p, float pers, float lacu)
{
    float3 pos = p;
    float4 sum = float4(0.0, 0.0, 0.0, 0.0);
    float3x3 rot = camera(float3(2, 1, -1));
    for (int i = 0; i < 5; i++)
    {
        p = mul(rot, p);
        p += sin(p.zxy);
        sum += float4(cross(cos(p), sin(p.yzx)), 1.0);
        sum /= pers;
        p *= lacu;
    }
    return sum.xyz / sum.w + pos;
}

float3 hsv(float h, float s, float v)
{
    float3 res = frac(h + float3(0., 2., 1.) / 3.);
    res = clamp(abs(res * 6. - 3.) - 1., float3(0,0,0), float3(1,1,1));
    res = (res - 1.) * s + 1.;
    res *= v;
    return res;
}

void add(uint2 p, float3 v)
{
    if (p.x >= (uint) resolution.x || p.y >= (uint) resolution.y)
    {
        return;
    }
    int3 q = int3(v * 2048.0);
    uint index = (p.y * (uint) resolution.x + p.x) * 3;
    InterlockedAdd(computeTex[index + 0], q.r);
    InterlockedAdd(computeTex[index + 1], q.g);
    InterlockedAdd(computeTex[index + 2], q.b);
}

[numthreads(16, 16, 1)]
void main(uint3 id : SV_DispatchThreadID)
{
    if (id.x >= (uint) resolution.x || id.y >= (uint) resolution.y) { return; }
    float cubeId = id.y;
    float trailId = id.x;
    float t = time.x * BPM / 120 * 0.5;
    float ft = frac(time.x);
    float fov = 60.0 + sin(t * 0.5) * 10.0;
    
    float3 ro = float3(0.0, 0.01, 1.0);
    ro.xz = mul(rotate2D(sin(t * 0.5) * PI), ro.xz);
    ro += t * Speed + 1.5;
    float3 ta = cyclic(t * Speed, Pers, Lacu);
    float dofFocus = length(ta - ro);
    float3 dir = normalize(ta - ro);
    float3x3 cam = camera(dir);

    float seed = cubeId;
    float3 cubeoffset = float3(random(seed), random(seed), random(seed));
    float3 cubePos = cyclic(cubeoffset + t * Speed, Pers, Lacu);
    float3 cubePrev = cyclic(cubeoffset + t * Speed - 0.01, Pers, Lacu);
    float3 cubeDir = normalize(cubePos - cubePrev);
    float3 cubeXZ = float3(cubeDir.x, 0.0, cubeDir.z);
    float2x2 cubeRotYZ = rotate2D(sign(cubeDir.y) * acos(dot(cubeXZ, cubeDir)));
    float2x2 cubeRotXZ = rotate2D(sign(cubeDir.x) * acos(dot(float3(0, 0, 1), cubeXZ)));
    float3 cubeCol = hsv(random(seed), 0.9, 1.0);

    float tL = 1.0;
    float rate = 0.2;
    float x = trailId / resolution.x / rate;
    float delta = 1.0 / resolution.x / rate;
    float3 trailPos = cyclic(cubeoffset + t * Speed - x * tL, Pers, Lacu);
    float3 trailPrev = cyclic(cubeoffset + t * Speed - (x + delta) * tL, Pers, Lacu);
    float3 trailDelta = (trailPos - trailPrev) / numSamples;
    
    for (uint i = 0; i < numSamples; ++i)
    {
        seed = trailId.x + float(i);
        float3 pos = lerp(cubePos + float3(random(seed), random(seed), random(seed)) * sin(t) * 0.03, trailPos + trailDelta * float(i), x < 1.0);
        
        seed = float(i);
        float2 uv = proj(pos, ro, cam, fov, dofFocus, 0.005, seed) * 0.5;
        if (uv.x < 0.0 || uv.y < 0.0 || uv.x >= resolution.x || uv.y >= resolution.y)
        {
            continue;
        }
        add(uint2(uv), cubeCol);
    }
}
