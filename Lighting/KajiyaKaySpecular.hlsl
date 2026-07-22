#ifndef KAJIYAKAY_SPECULAR_INCLUDED
#define KAJIYAKAY_SPECULAR_INCLUDED

// Kajiya-Kay 各向异性高光
// 适用：头发、毛皮、丝绸等需沿切线方向拉伸高光的材质
// 依赖：需传入世界空间切线(TangentWS)、视线方向(ViewDirWS)、光线方向(LightDirWS)
// 参数：specColor - 高光颜色，shift - 偏移量（正/负），smoothness - 光滑度（0~1，内部乘128）
// Kajiya-Kay 各向异性高光函数（头发渲染核心）
            half3 KajiyaKaySpecular(
                half3 tangentWS,    // 世界空间切线方向
                half3 viewDirWS,    // 世界空间视线方向
                half3 lightDirWS,   // 世界空间光线方向
                half3 specColor,    // 高光颜色
                half shift,         // 高光偏移量
                half smoothness)    // 高光光滑度
            {
                half3 halfDir = normalize(lightDirWS + viewDirWS);
                // 计算半角向量（光线方向和视线方向的中间向量）

                half TdotH = dot(tangentWS, halfDir);
                // 切线与半角向量的点积
                // 传统Blinn-Phong用法线点积，这里改用切线点积
                // 使高光沿切线方向拉伸呈条状，模拟头发丝光泽

                half spec = pow(saturate(TdotH + shift), smoothness * 128);
                // saturate: 钳制到[0,1]
                // + shift: 偏移高光带位置
                // pow(..., smoothness*128): 指数运算控制高光宽度，值越大越窄越锐利

                return specColor * spec;  // 返回颜色×高光强度
            }

#endif