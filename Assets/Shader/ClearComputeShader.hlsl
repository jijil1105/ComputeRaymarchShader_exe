
cbuffer cbuff0 : register(b0)
{
    float2 time; // x = elapsedTime, y = deltaTime
    float2 resolution; // x = width, y = height
    matrix mat;
}

RWStructuredBuffer<int> computeTex : register(u0);

[numthreads(16, 16, 1)]
void main(uint3 id : SV_DispatchThreadID)
{
    if (id.x >= resolution.x || id.y >= resolution.y)
        return;

    uint indexR = (id.y * uint(resolution.x) + id.x) * 3 + 0;
    uint indexG = indexR + 1;
    uint indexB = indexR + 2;

    // RGB‚ğƒ[ƒ‚ÉƒŠƒZƒbƒg
    computeTex[indexR] = 0;
    computeTex[indexG] = 0;
    computeTex[indexB] = 0;
}
