#ifndef KAJIYAKAY_SPECULAR_INCLUDED
#define KAJIYAKAY_SPECULAR_INCLUDED

// Kajiya-Kay 各向异性高光
// 适用：头发、毛皮、丝绸等需沿切线方向拉伸高光的材质
// 依赖：需传入世界空间切线(TangentWS)、视线方向(ViewDirWS)、光线方向(LightDirWS)
// 参数：specColor - 高光颜色，shift - 偏移量（正/负），smoothness - 光滑度（0~1，内部乘128）
half3 KajiyaKaySpecular(
    half3 tangentWS,
    half3 viewDirWS,
    half3 lightDirWS,
    half3 specColor,
    half shift,
    half smoothness)
{
    half3 halfDir = normalize(lightDirWS + viewDirWS);
    half TdotH = dot(tangentWS, halfDir);
    half spec = pow(saturate(TdotH + shift), smoothness * 128);
    return specColor * spec;
}

#endif