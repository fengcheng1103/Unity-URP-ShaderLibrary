#ifndef TOON_DIFFUSE_INCLUDED
#define TOON_DIFFUSE_INCLUDED

// 卡通漫反射 + 阴影衰减混合
// 输入：normalWS - 世界法线，lightDir - 主光方向，shadowAtten - 阴影衰减，shadowStep - 过渡软硬，shadowColor - 暗部颜色，baseColor - 亮部颜色
// 输出：漫反射颜色（已混合阴影色和亮色）
half3 ToonDiffuse(
    half3 normalWS,
    half3 lightDir,
    half shadowAtten,
    half shadowStep,
    half3 shadowColor,
    half3 baseColor)
{
    half NdotL = dot(normalWS, lightDir);
    half diffuse = smoothstep(0, shadowStep, NdotL * 0.5 + 0.5);
    diffuse = min(diffuse, shadowAtten);
    return lerp(shadowColor, baseColor, diffuse);
}

#endif