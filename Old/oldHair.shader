Shader "TA/HairShader"  // 声明Shader名称，在材质面板中显示为 TA/HairShader 路径
{
    Properties  // 开始定义材质面板上可调节的属性
    {
        [MainColor] _BaseColor("Base Color", Color) = (1,1,1,1)
        // [MainColor] 标记为主颜色，编辑器会高亮显示
        // _BaseColor 是Shader内部变量名，"Base Color" 是面板显示名
        // Color 类型为RGBA四分量颜色，默认值 (1,1,1,1) 为纯白不透明

        [MainTexture] _BaseMap("Base Map", 2D) = "white" {}
        // [MainTexture] 标记为主纹理
        // _BaseMap 是2D纹理变量名，默认使用纯白纹理（不影响颜色）

        _AmbientStrength("Ambient Blend", Range(0,1)) = 0.5
        // 控制自定义环境光与球谐环境光(SH)的混合比例，0=纯SH，1=纯自定义，默认各占一半

        _AmbientColor("Ambient Color", Color) = (1,1,1,1)
        // 自定义环境光的颜色，默认白色

        _ShadowColor("Shadow Color", Color) = (0.5,0.5,0.5,1)
        // 阴影区域的颜色，默认中灰色，暗部偏灰

        _ShadowStep("Shadow Step", Range(0, 1)) = 0.5
        // 控制明暗过渡的软硬程度，值越大过渡越柔和，值越小越硬边（卡通感）

        _SpecularColor("Specular Color", Color) = (1,1,1,1)
        // 主高光的颜色

        _SpecularShift("Specular Shift", Range(-1, 1)) = 0.2
        // 主高光沿切线方向的偏移量，正值正向偏移，负值反向偏移，用于模拟头发高光不在正中间

        _Smoothness("Smoothness", Range(0, 1)) = 0.5
        // 主高光的光滑度/锐度，值越大高光越窄越锐利

        _SecondarySpecularColor("Secondary Specular Color", Color) = (1,1,1,1)
        // 次高光颜色

        _SecondarySpecularShift("Secondary Specular Shift", Range(-1, 1)) = -0.2
        // 次高光偏移量，与主高光方向相反（负值），形成两条高光带

        _SecondarySmoothness("Secondary Smoothness", Range(0, 1)) = 0.3
        // 次高光光滑度，比主高光更低（更宽更柔和）

        // ========== 新增描边属性 ==========
        _OutlineColor("Outline Color", Color) = (0, 0, 0, 1)
        // 描边颜色，默认黑色

        _OutlineWidth("Outline Width", Range(0, 0.1)) = 0.02
        // 描边宽度（世界空间单位），默认0.02
        // ==================================
    }

    SubShader  // 开始定义SubShader（一组Pass的集合）
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "Queue" = "Geometry" }
        // "RenderType"="Opaque" 标记为不透明物体
        // "RenderPipeline"="UniversalPipeline" 声明专用于URP管线
        // "Queue"="Geometry" 渲染队列为2000，正常不透明物体的渲染顺序

        // ============================================================
        // Pass 1: 描边渲染（背面外扩）
        // 必须放在 ForwardLit 之前，确保描边在主体下方
        // ============================================================
        Pass
        {
            Name "Outline"  // Pass名称为"Outline"
            Tags { "LightMode" = "SRPDefaultUnlit" }
            // LightMode设为SRPDefaultUnlit，作为无光照的默认Pass，避免被光照系统干扰

            Cull Front          // 剔除正面，只渲染背面（描边核心原理）
            ZWrite On           // 开启深度写入，防止与其他物体穿插闪烁
            Blend Off           // 关闭混合，描边完全不透明
            ColorMask RGB       // 只写入RGB通道，不写Alpha通道

            HLSLPROGRAM  // 开始HLSL代码块
            #pragma vertex vert    // 指定顶点着色器函数名为vert
            #pragma fragment frag  // 指定片元着色器函数名为frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // 引入URP核心库，提供TransformObjectToHClip等坐标变换函数

            struct Attributes  // 顶点输入结构体
            {
                float4 positionOS : POSITION;  // 模型空间(Object Space)下的顶点位置
                float3 normalOS : NORMAL;      // 模型空间下的法线方向
            };

            struct Varyings  // 顶点到片元的输出结构体
            {
                float4 positionCS : SV_POSITION;  // 裁剪空间(Clip Space)位置，GPU光栅化用
            };

            // 从材质属性块读取描边参数
            CBUFFER_START(UnityPerMaterial)  // 开始常量缓冲区，UnityPerMaterial是URP推荐命名，兼容SRP Batcher
                float4 _OutlineColor;  // 描边颜色
                float _OutlineWidth;   // 描边宽度
            CBUFFER_END  // 结束常量缓冲区

            Varyings vert(Attributes input)  // 顶点着色器
            {
                Varyings output;
                // 核心：将顶点沿法线方向向外"撑开" _OutlineWidth 的距离
                float3 positionOS = input.positionOS.xyz + input.normalOS * _OutlineWidth;
                // 将外扩后的位置从模型空间变换到裁剪空间
                output.positionCS = TransformObjectToHClip(positionOS);
                return output;
            }

            half4 frag(Varyings input) : SV_Target  // 片元着色器，SV_Target表示输出到渲染目标
            {
                return _OutlineColor;  // 直接返回描边颜色，不做任何光照计算
            }
            ENDHLSL  // 结束HLSL代码块
        }

        // ============================================================
        // Pass 2: 主光照渲染（ForwardLit）
        // ============================================================
        Pass
        {
            Name "ForwardLit"  // Pass名称
            Tags { "LightMode" = "UniversalForward" }
            // LightMode=UniversalForward，告诉URP这是前向渲染的主光照Pass

            HLSLPROGRAM
            #pragma vertex vert   // 顶点着色器
            #pragma fragment frag // 片元着色器

            // 多编译变体：根据主光源阴影模式生成不同Shader变体
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            // _ 表示无阴影
            // _MAIN_LIGHT_SHADOWS 表示Shadow Map阴影
            // _MAIN_LIGHT_SHADOWS_CASCADE 表示级联阴影(Cascaded Shadow Map)
            // _MAIN_LIGHT_SHADOWS_SCREEN 表示屏幕空间阴影

            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            // 额外光源(点光、聚光灯等)阴影的编译变体

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // 引入URP核心库：坐标变换、基础数学函数

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            // 引入URP光照库：GetMainLight()、SampleSH()等光照函数

            struct Attributes  // 顶点输入结构体
            {
                float4 positionOS : POSITION;   // 模型空间顶点位置
                float3 normalOS : NORMAL;       // 模型空间法线
                float4 tangentOS : TANGENT;     // 模型空间切线（用于各向异性高光）
                float2 uv : TEXCOORD0;          // UV坐标（纹理采样用）
            };

            struct Varyings  // 顶点到片元的输出结构体
            {
                float4 positionCS : SV_POSITION;  // 裁剪空间位置
                float2 uv : TEXCOORD0;            // UV坐标（传递给片元着色器）
                float3 positionWS : TEXCOORD1;    // 世界空间位置（光照计算用）
                float3 normalWS : TEXCOORD2;      // 世界空间法线
                float3 tangentWS : TEXCOORD3;     // 世界空间切线
            };

            TEXTURE2D(_BaseMap);           // 声明2D纹理（URP推荐的分离写法，支持SRP Batcher）
            SAMPLER(sampler_BaseMap);      // 声明对应的采样器

            CBUFFER_START(UnityPerMaterial)  // 开始常量缓冲区
                float4 _BaseColor;                // 基础颜色
                float4 _ShadowColor;              // 阴影颜色
                float _ShadowStep;                // 明暗过渡软硬程度
                float4 _SpecularColor;            // 主高光颜色
                float _SpecularShift;             // 主高光偏移量
                float _Smoothness;                // 主高光光滑度
                float4 _SecondarySpecularColor;   // 次高光颜色
                float _SecondarySpecularShift;    // 次高光偏移量
                float _SecondarySmoothness;       // 次高光光滑度
                float4 _BaseMap_ST;               // 纹理的Tiling(缩放)和Offset(偏移)，TRANSFORM_TEX宏使用
                float4 _AmbientColor;             // 自定义环境光颜色
                float _AmbientStrength;           // 环境光混合强度
                float4 _OutlineColor;             // 描边颜色（此Pass虽不用，但CBUFFER需完整声明）
                float _OutlineWidth;              // 描边宽度
            CBUFFER_END

            Varyings vert(Attributes input)  // 顶点着色器
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                // 模型空间 → 裁剪空间

                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                // 模型空间 → 世界空间（用于光照计算）

                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                // 法线从模型空间 → 世界空间（内部处理了非均匀缩放的逆转置）

                output.tangentWS = TransformObjectToWorldDir(input.tangentOS.xyz);
                // 切线从模型空间 → 世界空间

                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                // 根据材质的Tiling/Offset对UV进行变换

                return output;
            }

            // Kajiya-Kay 各向异性高光函数（头发渲染核心）
            half3 KajiyaKaySpecular(
                half3 tangentWS,    // 世界空间切线方向
                half3 normalWS,     // 世界空间法线（此函数内未直接使用）
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

            half4 frag(Varyings input) : SV_Target  // 片元着色器
            {
                // ---- 基础颜色 ----
                half4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                // 根据UV坐标采样基础纹理

                half3 baseColor = baseMap.rgb * _BaseColor.rgb;
                // 纹理颜色 × 基础颜色 = 最终基础颜色

                // ---- 准备向量 ----
                half3 normalWS = normalize(input.normalWS);
                // 归一化世界空间法线（插值后需重新归一化）

                half3 tangentWS = normalize(input.tangentWS);
                // 归一化世界空间切线

                half3 viewDirWS = normalize(_WorldSpaceCameraPos - input.positionWS);
                // 计算视线方向：从当前片段指向摄像机

                // ---- 获取主光源信息 ----
                Light mainLight = GetMainLight(TransformWorldToShadowCoord(input.positionWS));
                // GetMainLight(): 获取主光源的方向、颜色、阴影衰减等信息
                // TransformWorldToShadowCoord(): 将世界坐标转换到阴影坐标，用于采样Shadow Map

                half shadowAttenuation = mainLight.shadowAttenuation;
                // 阴影衰减因子：0=完全阴影，1=完全照亮

                // ---- 漫反射（卡通风格） ----
                half NdotL = dot(normalWS, mainLight.direction);
                // 法线与光线方向的点积（Lambert漫反射基础）

                half diffuse = smoothstep(0, _ShadowStep, NdotL * 0.5 + 0.5);
                // NdotL * 0.5 + 0.5: 将[-1,1]映射到[0,1]
                // smoothstep: 阶梯式过渡，实现卡通明暗分界
                // _ShadowStep 控制过渡带宽度

                diffuse = min(diffuse, shadowAttenuation);
                // 与阴影贴图结果取最小值，确保阴影区域内也变暗

                half3 diffuseColor = lerp(_ShadowColor.rgb, baseColor, diffuse);
                // 在阴影色和基础色之间插值
                // diffuse=0时显示_ShadowColor（暗部），diffuse=1时显示baseColor（亮部）

                // ---- 各向异性高光（双高光叠加） ----
                half3 spec1 = KajiyaKaySpecular(tangentWS, normalWS, viewDirWS, mainLight.direction,
                                                _SpecularColor.rgb, _SpecularShift, _Smoothness);
                // 计算主高光：偏移正值，较锐利

                half3 spec2 = KajiyaKaySpecular(tangentWS, normalWS, viewDirWS, mainLight.direction,
                                                _SecondarySpecularColor.rgb, _SecondarySpecularShift, _SecondarySmoothness);
                // 计算次高光：偏移负值（方向相反），更宽更柔和

                half3 specular = (spec1 + spec2) * mainLight.color * shadowAttenuation;
                // 两个高光相加，乘以光源颜色和阴影衰减（阴影中不应有高光）

                // ---- 环境光 ----
                half3 shAmbient = SampleSH(normalWS);
                // 从球谐函数(Spherical Harmonics)中采样Unity预计算的全局环境光

                half3 customAmbient = _AmbientColor.rgb;
                // 自定义环境光颜色

                half3 mixedAmbient = lerp(shAmbient, customAmbient, _AmbientStrength);
                // 用_AmbientStrength在球谐环境光和自定义环境光之间混合

                half3 ambient = mixedAmbient * baseColor;
                // 最终环境光 × 基础颜色（环境光也应受物体颜色影响）

                // ---- 最终合成 ----
                half3 finalColor = diffuseColor * mainLight.color + specular + ambient;
                // 漫反射×光源颜色 + 高光 + 环境光

                return half4(finalColor, 1);
                // 输出最终颜色，Alpha固定为1（不透明）
            }
            ENDHLSL
        }

        // Pass 3: 阴影投射（复用内置）
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
        // 直接复用URP内置Lit Shader的ShadowCaster Pass
        // 用于将此物体投射阴影到其他物体上，避免手写阴影投射逻辑
    }

    FallBack "Universal Render Pipeline/Lit"
    // 如果当前GPU不支持此Shader，降级使用URP内置Lit Shader作为后备方案
}