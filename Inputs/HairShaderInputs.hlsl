#ifndef HAIR_SHADER_INPUTS_INCLUDED
#define HAIR_SHADER_INPUTS_INCLUDED

// 声明纹理和采样器
TEXTURE2D(_BaseMap);
SAMPLER(sampler_BaseMap);

// 常量缓冲区（必须与 Properties 顺序和类型完全一致）
CBUFFER_START(UnityPerMaterial)
    // 1. 基础贴图
    float4 _BaseColor;
    float4 _BaseMap_ST; // 纹理的 Tiling/Offset 一定要紧跟纹理声明！

    // 2. 漫反射与阴影
    float4 _ShadowColor;
    float _ShadowStep;

    // 3. 环境光
    float4 _AmbientColor;
    float _AmbientStrength;

    // 4. 主高光
    float4 _SpecularColor;
    float _SpecularShift;
    float _Smoothness;

    // 5. 次高光
    float4 _SecondarySpecularColor;
    float _SecondarySpecularShift;
    float _SecondarySmoothness;

    // 6. 描边
    float4 _OutlineColor;
    float _OutlineWidth;
CBUFFER_END

#endif