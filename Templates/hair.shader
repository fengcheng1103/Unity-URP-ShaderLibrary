Shader "TA/HairShader"
{
    Properties
    {
        // ============================================================
        // 1. 基础贴图
        // ============================================================
        [Header(Base Map)]
        [MainColor] _BaseColor("Base Color", Color) = (1,1,1,1)
        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}

        // ============================================================
        // 2. 漫反射与阴影（卡通风格）
        // ============================================================
        [Header(Diffuse & Shadow)]
        _ShadowColor("Shadow Color", Color) = (0.5,0.5,0.5,1)
        _ShadowStep("Shadow Step (软硬)", Range(0, 1)) = 0.5

        // ============================================================
        // 3. 环境光混合
        // ============================================================
        [Header(Ambient)]
        _AmbientStrength("Ambient Blend", Range(0,1)) = 0.5
        _AmbientColor("Ambient Color", Color) = (1,1,1,1)

        // ============================================================
        // 4. 各向异性高光（头发核心 - 双层）
        // ============================================================
        [Header(Specular - Primary)]
        _SpecularColor("Primary Color", Color) = (1,1,1,1)
        _SpecularShift("Primary Shift", Range(-1, 1)) = 0.2
        _Smoothness("Primary Smoothness", Range(0, 1)) = 0.5

        [Header(Specular - Secondary)]
        _SecondarySpecularColor("Secondary Color", Color) = (1,1,1,1)
        _SecondarySpecularShift("Secondary Shift", Range(-1, 1)) = -0.2
        _SecondarySmoothness("Secondary Smoothness", Range(0, 1)) = 0.3

        // ============================================================
        // 5. 描边
        // ============================================================
        [Header(Outline)]
        _OutlineColor("Outline Color", Color) = (0, 0, 0, 1)
        _OutlineWidth("Outline Width", Range(0, 0.1)) = 0.02
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "Queue" = "Geometry" }

        // ============================================================
        // Pass 1: 描边（背面外扩）
        // 直接复制自 Passes/OutlinePass.shader
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
        // Pass 2: 主光照渲染（ForwardLit）
        // ============================================================
        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // ---- 编译变体（必须保留在主文件中） ----
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS

            // ---- 引入 URP 核心库 ----
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            // ---- 引入自定义模块 ----
            #include "Inputs/HairShaderInputs.hlsl"        // 材质参数（CBUFFER + 纹理）
            #include "Shadows/ShadowReceipt.hlsl"          // 带阴影的主光源获取
            #include "Lighting/ToonDiffuse.hlsl"           // 卡通漫反射
            #include "Lighting/KajiyaKaySpecular.hlsl"     // 各向异性高光

            // ============================================================
            // 顶点着色器
            // ============================================================
            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 tangentWS : TEXCOORD3;
            };

            Varyings vert(Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.tangentWS = TransformObjectToWorldDir(input.tangentOS.xyz);
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
                half3 tangentWS = normalize(input.tangentWS);
                half3 viewDirWS = normalize(_WorldSpaceCameraPos - input.positionWS);

                // ---- 3. 主光源（含阴影衰减） ----
                Light mainLight = GetMainLightWithShadow(input.positionWS);
                half shadowAttenuation = mainLight.shadowAttenuation;

                // ---- 4. 卡通漫反射（含阴影混合） ----
                half3 diffuseColor = ToonDiffuse(
                    normalWS,
                    mainLight.direction,
                    shadowAttenuation,
                    _ShadowStep,
                    _ShadowColor.rgb,
                    baseColor
                );

                // ---- 5. 双层各向异性高光（Kajiya-Kay） ----
                half3 spec1 = KajiyaKaySpecular(
                    tangentWS,
                    viewDirWS,
                    mainLight.direction,
                    _SpecularColor.rgb,
                    _SpecularShift,
                    _Smoothness
                );

                half3 spec2 = KajiyaKaySpecular(
                    tangentWS,
                    viewDirWS,
                    mainLight.direction,
                    _SecondarySpecularColor.rgb,
                    _SecondarySpecularShift,
                    _SecondarySmoothness
                );

                half3 specular = (spec1 + spec2) * mainLight.color * shadowAttenuation;

                // ---- 6. 环境光（球谐 + 自定义混合） ----
                half3 shAmbient = SampleSH(normalWS);
                half3 customAmbient = _AmbientColor.rgb;
                half3 mixedAmbient = lerp(shAmbient, customAmbient, _AmbientStrength);
                half3 ambient = mixedAmbient * baseColor;

                // ---- 7. 最终合成 ----
                half3 finalColor = diffuseColor * mainLight.color + specular + ambient;
                return half4(finalColor, 1);
            }
            ENDHLSL
        }

        // ============================================================
        // Pass 3: 阴影投射（复用URP内置）
        // ============================================================
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }

    FallBack "Universal Render Pipeline/Lit"
}