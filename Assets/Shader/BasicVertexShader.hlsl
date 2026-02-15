#include"BasicType.hlsli"

cbuffer cbuff0 : register(b0) {
    float2 time; // x = elapsedTime, y = deltaTime
    float2 resolution; // x = width, y = height
	matrix mat;
}

BasicType main(float4 pos : POSITION, float2 uv : TEXCOORD)
{
	BasicType output;
    float ndcX = (pos.x / resolution.x) * 2.0f - 1.0f;
    float ndcY = 1.0f - (pos.y / resolution.y) * 2.0f;
    output.position = float4(ndcX, ndcY, 0.0f, 1.0f);
    output.uv = uv;
    output.time = time;
    output.resolution = resolution;
	return output;
}