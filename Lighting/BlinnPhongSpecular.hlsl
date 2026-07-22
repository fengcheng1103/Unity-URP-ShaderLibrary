#ifndef BLINN_PHONG_SPECULAR_INCLUDED
#define BLINN_PHONG_SPECULAR_INCLUDED

// 标准 Blinn-Phong 镜面高光
// 适用：皮肤、金属、塑料等各向同性材质
// 参数：smoothness 范围 0~1，内部自动乘以 128 控制锐度
half3 BlinnPhongSpecular(
                half3 normalWS,     // 世界空间法线（此函数内未直接使用）
                half3 viewDirWS,    // 世界空间视线方向
                half3 lightDirWS,   // 世界空间光线方向
                half3 specColor,    // 高光颜色
                half smoothness)    // 高光光滑度
            {
                half3 halfDir = normalize(lightDirWS + viewDirWS);
                // 计算半角向量（光线方向和视线方向的中间向量）

                half NdotH = dot(normalWS, halfDir);
                

                half spec = pow(saturate(NdotH), smoothness * 128);
                // saturate: 钳制到[0,1]
                // pow(..., smoothness*128): 指数运算控制高光宽度，值越大越窄越锐利

                return specColor * spec;  // 返回颜色×高光强度
            
            }
#endif
