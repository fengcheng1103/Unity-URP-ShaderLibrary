Shader "TA/SkinShader"
{
    Properties
    {
        // ============================================================
        // 1. 基础贴图
        // ============================================================
        [Header(Base)]
        [MainColor] _BaseColor("Base Color", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}

        // ============================================================
        // 2. 卡通漫反射与阴影
        // ============================================================
        [Header(Diffuse & Shadow)]
        _ShadowColor("Shadow Color", Color) = (0.5,0.5,0.5,1)
        _ShadowStep("Shadow Step (软硬)", Range(0, 1)) = 0.5

        // ============================================================
        // 3. 高光（Blinn-Phong）
        // ============================================================
        [Header(Specular)]
        _SpecularColor("Specular Color", Color) = (1,1,1,1)
        _Smoothness("Smoothness", Range(0, 1)) = 0.5

        // ============================================================
        // 4. 描边（与 Passes/OutlinePass.shader 保持同步）
        // ============================================================
        [Header(Outline)]
        _OutlineColor("Outline Color", Color) = (0, 0, 0, 1)
        _OutlineWidth("Outline Width", Range(0, 0.1)) = 0.02
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "Queue" = "Geometry" }

        // ============================================================
        // Pass 1: 描边（直接复制自 Passes/OutlinePass.shader）
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
        // Pass 2: 主光照（ForwardLit）
        // ============================================================
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // ---- 编译变体（主文件必须保留） ----
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS

            // ---- 引入 URP 核心库 ----
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // ---- 引入自定义模块 ----
            #include "Inputs/SkinShaderInputs.hlsl"        // 皮肤材质参数
            #include "Shadows/ShadowReceipt.hlsl"          // 带阴影的主光源
            #include "Lighting/ToonDiffuse.hlsl"           // 卡通漫反射（复用！）
            #include "Lighting/BlinnPhongSpecular.hlsl"    // 皮肤高光（新增）

            // ============================================================
            // 顶点着色器
            // ============================================================
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                return output;
            }

            // ============================================================
            // 片元着色器
            // ============================================================
            half4 frag(Varyings input) : SV_Target
            {
                // ---- 1. 基础颜色 ----
                half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                half3 baseColor = baseMap.rgb * _BaseColor.rgb;

                // ---- 2. 归一化向量 ----
                half3 normalWS = normalize(input.normalWS);
                half3 viewDirWS = normalize(_WorldSpaceCameraPos - input.positionWS);

                // ---- 3. 主光源（含阴影） ----
                Light mainLight = GetMainLightWithShadow(input.positionWS);
                half shadowAtten = mainLight.shadowAttenuation;

                // ---- 4. 卡通漫反射（直接调用复用模块） ----
                half3 diffuseColor = ToonDiffuse(
                    normalWS,
                    mainLight.direction,
                    shadowAtten,
                    _ShadowStep,
                    _ShadowColor.rgb,
                    baseColor
                );

                // ---- 5. Blinn-Phong 高光（新增模块） ----
                half3 specular = BlinnPhongSpecular(
                    normalWS,
                    viewDirWS,
                    mainLight.direction,
                    _SpecularColor.rgb,
                    _Smoothness
                ) * mainLight.color * shadowAtten;

                // ---- 6. 环境光 ----
                half3 ambient = SampleSH(normalWS) * baseColor;

                // ---- 7. 合成 ----
                half3 finalColor = diffuseColor * mainLight.color + specular + ambient;
                return half4(finalColor, 1);
            }
            ENDHLSL
        }

        // ============================================================
        // Pass 3: 阴影投射
        // ============================================================
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }

    FallBack "Universal Render Pipeline/Lit"
}