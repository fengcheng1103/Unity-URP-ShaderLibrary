#ifndef SHADOW_RECEIPT_INCLUDED
#define SHADOW_RECIPT_INCLUDED

// ============================================================
// 阴影接收工具（封装阴影坐标转换与主光源获取）
// 依赖：主Shader必须包含 "Lighting.hlsl"
// 使用：在片元着色器中调用 Light mainLight = GetMainLightWithShadow(positionWS);
//       然后通过 mainLight.shadowAttenuation 获取阴影衰减值
// 注意：使用此函数前，主Shader必须定义对应的 _MAIN_LIGHT_SHADOWS 多编译变体
// ============================================================
Light GetMainLightWithShadow(float3 positionWS)
{
    // 将世界坐标转换到阴影贴图采样坐标
    float4 shadowCoord = TransformWorldToShadowCoord(positionWS);
    // 获取主光源（包含方向、颜色、阴影衰减）
    return GetMainLight(shadowCoord);
}

#endif