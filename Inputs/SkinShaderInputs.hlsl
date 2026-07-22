#ifndef SKIN_SHADER_INPUTS_INCLUDED
#define SKIN_SHADER_INPUTS_INCLUDED

// 纹理声明
TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

// 材质参数缓冲区（与 Properties 严格对应）
CBUFFER_START(UnityPerMaterial)
    float4 _BaseColor;
    float4 _ShadowColor;
    float _ShadowStep;
    float _Smoothness;
    float4 _SpecularColor;
    float4 _BaseMap_ST;   // Tiling & Offset
CBUFFER_END
#endif