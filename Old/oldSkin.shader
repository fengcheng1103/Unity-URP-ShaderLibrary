Shader "TA/SkinShader"
{
    // ==================== 材质属性面板 ====================
    Properties
    {
        // [MainColor] 标签告诉 URP 这是主颜色，用于材质预览等
        // _BaseColor：基础颜色，默认白色 (1,1,1,1)
        [MainColor] _BaseColor("Base Color", Color) = (1,1,1,1)

        // [MainTexture] 标签告诉 URP 这是主贴图
        // _BaseMap：基础颜色贴图（漫反射贴图），默认白色纹理
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}

        // _ShadowColor：阴影区域的颜色，默认中灰色
        _ShadowColor("Shadow Color", Color) = (0.5,0.5,0.5,1)

        // _ShadowStep：控制明暗分界的阈值（0~1），值越大暗部区域越大
        _ShadowStep("Shadow Step", Range(0, 1)) = 0.5

        // _Smoothness：高光光滑度（0~1），控制镜面反射的集中程度
        _Smoothness("Smoothness", Range(0, 1)) = 0.5

        // _SpecularColor：镜面高光颜色，默认白色
        _SpecularColor("Specular Color", Color) = (1,1,1,1)


        // ========== 描边属性 ==========

        // _OutlineColor：描边颜色，默认黑色
        _OutlineColor("Outline Color", Color) = (0, 0, 0, 1)

        // _OutlineWidth：描边宽度，沿法线方向外扩的距离（0~0.1）
        _OutlineWidth("Outline Width", Range(0, 0.1)) = 0.02

    }


    // ==================== 子着色器 ====================
    SubShader
    {
        // 渲染标签：告诉渲染管线如何处理这个物体
        Tags
        {
            "RenderType" = "Opaque"           // 渲染类型为不透明物体
            "RenderPipeline" = "UniversalPipeline"  // 专用于 URP 渲染管线
            "Queue" = "Geometry"              // 渲染队列为 Geometry（默认不透明队列）
        }


        // ============================================================
        // Pass 1: Outline（描边 Pass）
        // 渲染顺序：最先渲染，绘制一圈外扩的轮廓
        // ============================================================
        Pass
            {
                Name "Outline"
                Tags { "LightMode" = "SRPDefaultUnlit" }
                Cull Front
                ZWrite On
                Blend Off
                ColorMask RGB

                HLSLPROGRAM
                #pragma vertex vert
                #pragma fragment frag
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

                struct Attributes
                {
                    float4 positionOS : POSITION;
                    float3 normalOS : NORMAL;
                };

                struct Varyings
                {
                    float4 positionCS : SV_POSITION;
                };

                CBUFFER_START(UnityPerMaterial)
                    float4 _OutlineColor;
                    float _OutlineWidth;
                CBUFFER_END

                Varyings vert(Attributes input)
                {
                    Varyings output;
                    float3 positionOS = input.positionOS.xyz + input.normalOS * _OutlineWidth;
                    output.positionCS = TransformObjectToHClip(positionOS);
                    return output;
                }

                half4 frag(Varyings input) : SV_Target
                {
                    return _OutlineColor;
                }
                ENDHLSL
            }


        // ============================================================
        // Pass 2: ForwardLit（主光照 Pass）
        // 渲染顺序：在描边之后渲染，绘制物体的主体部分
        // ============================================================
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }  // URP 前向渲染 Pass

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // 编译多个变体，支持不同类型的主光源阴影
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            // 编译多个变体，支持额外光源的阴影
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS

            // 引入 URP 核心库和光照库
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


            // ---------- 顶点着色器输入结构 ----------
            struct Attributes
            {
                float4 positionOS : POSITION;  // 模型空间顶点位置
                float3 normalOS : NORMAL;      // 模型空间法线
                float2 uv : TEXCOORD0;         // 纹理坐标
            };

            // ---------- 顶点着色器输出结构 ----------
            struct Varyings
            {
                float4 positionCS : SV_POSITION;  // 裁剪空间位置
                float2 uv : TEXCOORD0;            // 纹理坐标（传递给片元）
                float3 positionWS : TEXCOORD1;    // 世界空间位置（用于光照计算）
                float3 normalWS : TEXCOORD2;      // 世界空间法线（用于光照计算）
            };


            // ---------- 纹理和采样器声明 ----------
            TEXTURE2D(_BaseMap);                // 声明 2D 纹理 _BaseMap
            SAMPLER(sampler_BaseMap);           // 声明对应的采样器（URP 要求分离声明）


            // ---------- 材质常量缓冲区 ----------
            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;       // 基础颜色
                float4 _ShadowColor;     // 阴影颜色
                float _ShadowStep;       // 阴影阈值
                float _Smoothness;       // 光滑度
                float4 _SpecularColor;   // 镜面高光颜色
                float4 _BaseMap_ST;      // 贴图的平铺(Tiling)和偏移(Offset)，_ST = Scale + Translate
               
            CBUFFER_END


            // ---------- 顶点着色器 ----------
            Varyings vert(Attributes input)
            {
                Varyings output;

                // 模型空间 → 裁剪空间（用于光栅化）
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

                // 模型空间 → 世界空间（用于光照和阴影计算）
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);

                // 模型空间法线 → 世界空间法线（用于光照计算）
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);

                // 处理纹理坐标的平铺和偏移：uv * _BaseMap_ST.xy + _BaseMap_ST.zw
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);

                return output;
            }


            // ---------- 片元着色器 ----------
            half4 frag(Varyings input) : SV_Target
            {
                // --- 步骤1：采样基础颜色 ---
                // 从 _BaseMap 采样得到纹理颜色
                half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                // 纹理颜色 × 基础颜色 = 最终基色
                half3 baseColor = baseMap.rgb * _BaseColor.rgb;


                // --- 步骤2：准备光照所需的向量 ---
                // 归一化世界空间法线
                half3 normalWS = normalize(input.normalWS);
                // 计算视线方向：从像素指向摄像机
                half3 viewDirWS = normalize(_WorldSpaceCameraPos - input.positionWS);


                // --- 步骤3：获取主光源信息 ---
                // TransformWorldToShadowCoord 将世界坐标转换到阴影空间，用于阴影采样
                Light mainLight = GetMainLight(TransformWorldToShadowCoord(input.positionWS));
                // 阴影衰减系数：0 = 完全在阴影中，1 = 完全被照亮
                half shadowAttenuation = mainLight.shadowAttenuation;


                // --- 步骤4：计算卡通风格的漫反射 ---
                // 法线与光照方向的点积，范围 [-1, 1]
                // 注意：mainLight.direction 是从像素指向光源的方向
                half NdotL = dot(normalWS, mainLight.direction);

                // 将 NdotL 从 [-1, 1] 映射到 [0, 1]
                // 然后使用 smoothstep 在 [0, _ShadowStep] 区间内做平滑插值
                // 实现卡通风格的硬边阴影过渡效果
                half diffuse = smoothstep(0, _ShadowStep, NdotL * 0.5 + 0.5);

                // 将阴影贴图的遮挡效果叠加进来
                // 如果该点在阴影中（shadowAttenuation 接近 0），漫反射会被进一步减弱
                diffuse = min(diffuse, shadowAttenuation);


                // --- 步骤5：混合明暗颜色 ---
                // lerp(a, b, t) = a * (1-t) + b * t
                // diffuse = 0 → 输出 _ShadowColor（暗部）
                // diffuse = 1 → 输出 baseColor（亮部）
                half3 diffuseColor = lerp(_ShadowColor.rgb, baseColor, diffuse);


                // --- 步骤6：计算镜面高光（Blinn-Phong 模型） ---
                // 计算半程向量：光线方向与视线方向的中间方向
                half3 halfDir = normalize(mainLight.direction + viewDirWS);

                // 法线与半程向量的点积，saturate 确保结果在 [0, 1] 范围内
                // 再通过 pow 函数控制高光集中程度
                // _Smoothness 越大 → 指数越大 → 高光越锐利、越集中
                half spec = pow(saturate(dot(normalWS, halfDir)), _Smoothness * 128);

                // 最终高光颜色 = 高光色 × 高光强度 × 光源颜色 × 阴影衰减
                half3 specularColor = _SpecularColor.rgb * spec * mainLight.color * shadowAttenuation;


                // --- 步骤7：计算环境光（球谐光照） ---
                // SampleSH 采样球谐函数，获取基于法线方向的间接环境光
                // 乘以 baseColor 让环境光也带有物体的基础色调
                half3 ambient = SampleSH(normalWS) * baseColor;


                // --- 步骤8：合成最终颜色 ---
                // 最终颜色 = 漫反射 × 光源色 + 镜面高光 + 环境光
                half3 finalColor = diffuseColor * mainLight.color + specularColor + ambient;

                // 输出最终颜色，Alpha 固定为 1（不透明）
                return half4(finalColor, 1);
            }
            ENDHLSL
        }  // End of ForwardLit Pass


        // ============================================================
        // Pass 3: ShadowCaster（阴影投射 Pass）
        // 作用：让使用该 Shader 的物体能够向其他物体投射阴影
        // ============================================================
        // 直接复用 URP 内置 Lit Shader 的 ShadowCaster Pass
        // 无需自己编写阴影投射逻辑，URP 已提供标准实现
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }


    // ==================== 回退着色器 ====================
    // 如果当前 SubShader 因硬件不支持等原因无法运行
    // 则回退到 URP 的标准 Lit Shader，保证兼容性
    FallBack "Universal Render Pipeline/Lit"
}