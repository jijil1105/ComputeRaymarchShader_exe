#include"BasicType.hlsli"

SamplerState g_preFramesampler : register(s0);
Texture2D g_preFrameTex : register(t0);
StructuredBuffer<float> gFFTAmplitude : register(t1);
StructuredBuffer<int> gComputeTex : register(t2);

#define preTex(uv) g_preFrameTex.Sample(g_preFramesampler, uv)
#define fft gFFTAmplitude[clamp(.05*512, 0.0, 512.0)]
#define phase_0 60.0
#define phase_1 64.0
#define phase_2 128.0 - 0.5
#define phase_offset 1.134
#define light 0.005

float3 LoadComputeTex(float2 uv, float2 resolution)
{
    if(uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0)
    {
        return float3(0.0, 0.0, 0.0);
    }
    uint2 pixel = uint2(uv * resolution);
    uint index = (pixel.y * uint(resolution.x) + pixel.x) * 3;
    return float3(gComputeTex[index + 0], gComputeTex[index + 1], gComputeTex[index + 2]) / 2048.0 / numSamples;
}

float hash(float t)
{
    return frac(sin(t * 159.3524) * sin(t * 98.4356));
}

float hash31(float3 v)
{
    float a = dot(v, float3(159.3524, 98.4356, 12.456));
    float b = dot(v, float3(78.233, 37.719, 26.123));
    return frac(sin(a) * sin(b));
}

float3 hash23(float2 t)
{
    return frac(float3(hash(t.x), hash(t.y * 12.456), hash(t.x + t.y)));
}

float3 hash33(float3 v)
{
    // 異なる線形結合とオフセットで成分間の相関を下げる
    float hx = hash(dot(v, float3(1.0, 57.0, 113.0)) + 0.0);
    float hy = hash(dot(v, float3(23.0, 7.0, 91.0)) + 19.19);
    float hz = hash(dot(v, float3(17.0, 89.0, 41.0)) + 73.73);
    return float3(hx, hy, hz);
}

float3 reinhard(float3 col, float L)
{
    return col / (1.0 + col) * (1.0 + col / (L * L));
}

float3 chromatic(float2 uv, float3 col, float iTime)
{
    float2 p = uv * 2.0 - 1.0;
    float dis = length(p);
    float2 dir = normalize(p);
    float chromaticAmount = 0.1;
    col.r += col.r * chromaticAmount * dis * hash(iTime + col.r);
    col.b -= col.b * chromaticAmount * dis * hash(iTime + col.b);
    return col;
}

float2x2 rot(float t)
{
    float c = cos(t);
    float s = sin(t);
    return float2x2(c, s, -s, c);
}

float sphare(float3 p, float s)
{
    return length(p) - s;
}

float map(float3 p, float iTime)
{
    float time = iTime;
    float3 pt = p;
    float grid = 5.0;
    pt = mod(p, grid) - grid / 2.0;
    float3 cellId = floor(p / grid);
    time += hash31(p) * 0.05;
    float3 shift = float3(1.4, 1.4, 1.4);
    for (int i = 0; i < 3; i++)
    {
        pt = abs(pt) - lerp(float3(0.0, 0.0, 0.0), pow(shift, float3(-float(i), -float(i), -float(i))), frac(time * 0.5 + hash31(cellId)));
        pt += hash(i) * 1.0;
        pt.xy = mul(rot(sin(time * 3.0)), pt.xy);
        pt.yz = mul(rot(cos(time * 3.0)), pt.yz);
    }
    return sphare(pt, .15);;
}

float map_0(float3 p, float iTime)
{
    float time = iTime;
    float3 pt = p;
    float grid = 5.0;
    pt = mod(p, grid) - grid / 2.0;
    float3 cellId = floor(p / grid);
    time += hash31(p) * 0.05;
    float3 shift = float3(1.4, 1.4, 1.4);
    for (int i = 0; i < 3; i++)
    {
        pt = abs(pt) - lerp(float3(0.0, 0.0, 0.0), pow(shift, float3(-float(i), -float(i), -float(i))), frac(time * 0.5 + hash31(cellId)));
        pt += hash(i) * 1.0;
        pt.xy = mul(rot(sin(time * 3.0)), pt.xy);
        pt.yz = mul(rot(cos(time * 3.0)), pt.yz);
    }
    return sphare(pt, .3);;
}

float3 computeTileTex(float2 uv, float iTime, float2 iResolution, float iTimeDelta)
{
    float time = (iTime / 4.0) + 1.;
    float3 pink = float3(.62, .21, .69);
    float3 col = float3(1, 1, 1) * light;
    float2 p = uv * 2. - 1.0;
    //p /= float2(iResolution.y / iResolution.x, 1.);
    float3 ro = float3(0., 3. + floor(time), floor(time));
    float3 rd = normalize(float3(p, -1.));
    rd.xy = mul(rot(.5 + floor(time)), rd.xy);
    rd.yz = mul(rot(.5 + floor(time)), rd.yz);
    float3 rp = ro;
    float rl = 0.;
    float d = 0.;
    int loopCount = 5;
    for (int i = 0; i < loopCount; i++)
    {
        d = map(rp, time);
        rl += d;
        rp = ro + rd * rl;
        if (d < .01)
        {
            col += lerp(cos(rp), pink, .5) * .5 + .5;
            break;
        }
    }
    return col;
}

float3 computeTileTex_0(float2 uv, float iTime, float2 iResolution, float iTimeDelta)
{
    float time = floor(iTime / 4.0);
    float3 pink = float3(.62, .21, .69);
    float3 col = float3(1, 1, 1) * light;
    float2 p = uv * 2. - 1.0;
    //p /= float2(iResolution.y / iResolution.x, 1.);
    float3 ro = float3(0., 3. + floor(time), floor(time));
    float3 rd = normalize(float3(p, -1.));
    rd.xy = mul(rot(.5 + floor(time)), rd.xy);
    rd.yz = mul(rot(.5 + floor(time)), rd.yz);
    float3 rp = ro;
    float rl = 0.;
    float d = 0.;
    int loopCount = 5;
    for (int i = 0; i < loopCount; i++)
    {
        d = map_0(rp, time);
        rl += d;
        rp = ro + rd * rl;
        if (d < .01)
        {
            col += lerp(cos(rp), pink, .5) * .5 + .5;
            break;
        }
    }
    return col;
}

float3 computeTileTex_1(float2 uv, float iTime, float2 iResolution, float iTimeDelta)
{
    //iTime += 0.5;
    float2 p = uv * 2. - 1.;
    //p /= float2(iResolution.y / iResolution.x, 1.);
    float d = length(p) - frac(iTime * 0.2)*5.0;
    float t = step(0.0, d) * step(d, 0.1);
    float3 col = float3(t, t, t);
    //col = chromatic(uv, col, iTime);
    return col + light;
}

float3 computeTileTex_butterfly(float2 uv, float iTime, float2 iResolution, float iTimeDelta)
{
    uv *= 0.8;
    float2 p = uv * 2.0 - 1.0;
    //p *= float2(iResolution.y / iResolution.x, 1.0);
    
    float chromaticAmount = 0.01;
    float2 dir = normalize(p);
    float dist = length(p);
    float2 offset = dir * chromaticAmount * dist * hash(iTime + dist);
    float3 col = float3(0.0, 0.0, 0.0);
    col.r = LoadComputeTex(uv + offset, iResolution).r;
    col.g = LoadComputeTex(uv, iResolution).g;
    col.b = LoadComputeTex(uv - offset, iResolution).b;
    col = reinhard(col, 20.0);
    return col + light;
}

float3 selectTileTex(float2 uv, float iTime, float2 iResolution, float iTimeDelta)
{
    if (iTime < phase_0)
    {
        return computeTileTex_0(uv, iTime, iResolution, iTimeDelta);
    }
    else if(phase_0 <= iTime && iTime < phase_1)
    {
        return computeTileTex_1(uv, iTime, iResolution, iTimeDelta);
    }
    else if(phase_1 <= iTime && iTime < phase_2)
    {
        return computeTileTex(uv, iTime, iResolution, iTimeDelta);
    }
    else
    {
        return computeTileTex_butterfly(uv, iTime, iResolution, iTimeDelta);
    }
}

float3 scene(float2 uv, float iTime, float2 iResolution, float iTimeDelta)
{
    float3 col = float3(0.0, 0.0, 0.0);
    float2 p = uv * 2. - 1.;
    float3 sceneSize = float3(1., 1., 1.);
    float sampleCount = 10.;
    float bounceCount = 3.;
    for (float i = 0.; i < sampleCount; i++)
    {
        float sampleTime = iTime + i * (.03 / sampleCount);
        float3 ro = float3(1., 0., 0);
        float3 rd = normalize(float3(-p, -1.));
        rd.yz = mul(rot(.2), rd.yz);
        //rd.xz = mul(rot(.1), rd.xz);
        float throughput = 1.0;
        for (float j = 0.; j < bounceCount; j++)
        {
            float3 tMax = (sceneSize - ro) / rd;
            float3 tMin = (-sceneSize - ro) / rd;
            float3 tHit = max(tMax, tMin);
            float d = min(tHit.y, tHit.z);
            float3 rp = ro + rd * d;
            float3 s = sign(rd);
            float2 cellUV = rp.zx;
            float3 normal = float3(0., -s.y, 0.);
            float3 emit = float3(0, 0, 0);
            float metal = .5;
            float fac = 1.0;
            if (tHit.z < tHit.y)
            {
                cellUV = rp.xy + float2(-.1, 1);
                cellUV /= 2.;
                cellUV = clamp(cellUV, 0., 1.);
                normal = float3(0., 0., -s.z);
                emit = selectTileTex(cellUV, iTime, iResolution, iTimeDelta);
                metal = .1;
                fac = 0.1;
            }
            col += emit * throughput;
            throughput -= clamp(dot(rd, normal), 0., 1.);
            throughput = max(0., throughput) * fac;
            float3 reflected = reflect(rd, normal);
            float3 randref = reflect(rd, hash23(cellUV + sampleTime));
            ro = rp;
            rd = normalize(lerp(randref, reflected, metal));
        }
    }
    float3 finalCol = col / sampleCount;
    return finalCol;
}

float4 main(BasicType input) : SV_TARGET
{
    float2 resolution = input.resolution;
    float iTime = input.time.x * (BPM / 60) - phase_offset;
    float iTimeDelta = input.time.y;
    float2 uv = input.uv;
    float2 p = uv * 2. - 1.;
    float3 sceneSize = float3(1., 1., 1.);
    float sampleCount = 4.;
    float bounceCount = 3.;
    float3 col = float3(0, 0, 0);
    if(iTime < 0.0)
    {
        return float4(col, 1);
    }
    
    col = scene(uv, iTime, resolution, iTimeDelta);
    col = reinhard(col, 1.0);
    col = pow(col, 0.4545);
    if (phase_1 <= iTime && iTime < phase_2)
    {
        col = max(col, g_preFrameTex.Sample(g_preFramesampler, uv).rgb - iTimeDelta);

    }
    
    return float4(col, 1);
}