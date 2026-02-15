struct BasicType {
    float4 position : SV_POSITION;
    float2 uv : TEXCOORD0;
    float2 time : TEXCOORD1; // x = elapsedTime, y = deltaTime
    float2 resolution : TEXCOORD2;
};

#define numSamples 10
#define mod(a,b) ((a) - (b) * floor((a) / (b)))
#define BPM 110.0