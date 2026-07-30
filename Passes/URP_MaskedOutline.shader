Pass  // ======================== 描边 Pass URP管线 + 遮罩控制 + 外壳法========================
        {
            Name "Outline"
            Tags { "LightMode" = "SRPDefaultUnlit" }  // 使用 SRP 默认的无光照模式，此 Pass 不参与光照计算
            
            Cull Front  // 剔除正面，只渲染背面。配合顶点外扩，实现"外壳法"描边效果
            ZWrite On   // 开启深度写入，描边会写入深度缓冲，遮挡后面的物体
            ZTest LEqual // 深度测试模式：当前像素深度 <= 缓冲区深度时才绘制（默认行为）
            Blend SrcAlpha OneMinusSrcAlpha // 标准 Alpha 混合：最终颜色 = 源颜色×源Alpha + 目标颜色×(1-源Alpha)
            
            HLSLPROGRAM
            #pragma vertex OutlineVertex    // 指定顶点着色器入口函数
            #pragma fragment OutlineFragment // 指定片元着色器入口函数
            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" // 引入 URP 核心库（坐标变换等基础函数）
            
            // 顶点着色器的输入结构体，对应 Mesh 的顶点数据
            struct Attributes
            {
                float4 positionOS : POSITION;   // 物体空间（Object Space）下的顶点位置
                float3 normalOS   : NORMAL;     // 物体空间下的顶点法线方向
                float4 color      : COLOR;      // 顶点颜色（通常由顶点绘制或骨骼动画传入）
                float2 texcoord0  : TEXCOORD0;  // 第一套 UV 坐标
                half4  texcoord1  : TEXCOORD1;  // 第二套 UV 坐标（可用于光照贴图或自定义数据）
            };
            
            // 顶点着色器的输出 / 片元着色器的输入结构体
            struct Varyings
            {
                float4 positionCS : SV_POSITION; // 裁剪空间（Clip Space）下的顶点位置，GPU 用于光栅化
                float4 color      : COLOR;       // 顶点颜色，传递到片元着色器
                float2 uv0        : TEXCOORD0;   // 第一套 UV 坐标，用于纹理采样
                float4 uv1        : TEXCOORD2;   // 第二套 UV 坐标
            };
            
            // 常量缓冲区：将所有材质属性打包在一起，减少 GPU 的 SetConstantBuffer 调用次数，提升性能
            CBUFFER_START(UnityPerMaterial)
                half4 _AlbedoColor;              // 基础色
                half  _AlbedoStrength;           // 基础色亮部强度
                half  _AlbedoDarkStrength;       // 基础色暗部强度
                half  _AlbedoDarkSaturation;     // 基础色暗部饱和度
                half  _NormalStrength;           // 法线强度
                half  _RampStrength;             // Ramp 贴图强度
                half4 _AnisotropicMap_ST;        // 各向异性贴图变换参数（平铺/偏移）
                half4 _HairLine_ST;              // 发丝线贴图变换参数
                half4 _HairLineColor;            // 发丝线颜色
                half  _AnisotropicStrength;      // 各向异性高光强度
                half  _AnisotropicOffset;        // 各向异性高光偏移
                half  _AnisotropicRange;         // 各向异性高光范围
                half  _CutOffset;                // 裁切偏移
                half4 _SpecularColor;            // 高光颜色
                half  _SpecularRefineOffset_U;   // 高光精修 U 方向偏移
                half  _SpecularRefineOffset_V;   // 高光精修 V 方向偏移
                half4 _DepthRimColor;            // 深度边缘光颜色
                float _DepthRimOffset;           // 深度边缘光偏移
                float _DepthRimIntensity;        // 深度边缘光强度
                half  _DepthRimLerp;             // 深度边缘光与基础色的混合比例
                half4 _RimLightColor;            // 边缘光颜色
                half  _FresnelRimOffset;         // 菲涅尔边缘光偏移
                float _FresnelRimPower;          // 菲涅尔边缘光指数（控制边缘光的集中程度）
                float _FresnelRimIntensity;      // 菲涅尔边缘光强度
                float _RimMaskSoftness;          // 边缘光遮罩软硬度过渡
                float _RimMaskOffset;            // 边缘光遮罩偏移
                float4 _RimLightDirection;       // 边缘光方向
                half  _LutStrength;              // LUT 调色强度
                half  _AOStrength;               // 环境光遮蔽强度
                half4 _EnvColor;                 // 环境光颜色
                half  _EnvLightStrength;         // 环境光强度
                half4 _EnvRotation;              // 环境光旋转参数
                half  _SpecularRefineRamp;       // 高光精修 Ramp
                half  _SpecularRefineIntensity;  // 高光精修强度
                half4 _DoubleSpecularColor;      // 双层高光颜色
                half  _DoubleSpecularRange;      // 双层高光范围
                half4 _OutlineColor;             // 描边颜色
                half  _OutlineWidth;             // 描边宽度（基础值）
                half  _OutlineWidthMapStrength;  // 描边遮罩对宽度的影响强度
                half  _OutlineZOffset;           // 描边 Z 轴偏移（防止 Z-Fighting）
                half  _Alpha;                    // 透明度
                half  _Test;                     // 测试用变量
                float3 _FaceForward;             // 面部朝向（前方向量）
                float3 _FaceRight;               // 面部朝向（右方向量）
                float3 _FaceUp;                  // 面部朝向（上方向量）
                float4 _HeadPosition;            // 头部位置
            CBUFFER_END
            
            // 声明纹理资源和对应的采样器状态
            TEXTURE2D(_AlbedoMap);   SAMPLER(sampler_AlbedoMap);   // 基础色贴图
            TEXTURE2D(_OutLineMask); SAMPLER(sampler_OutLineMask); // 描边遮罩贴图（控制不同区域的描边宽度）
            
            // 顶点着色器：负责将顶点沿法线方向外扩，实现描边的"外壳"
            Varyings OutlineVertex(Attributes input)
            {
                Varyings output = (Varyings)0; // 初始化输出结构体，所有字段清零
                
                // 采样描边遮罩贴图的 R 通道，获取当前顶点对应区域的描边宽度系数（0~1）
                // SAMPLE_TEXTURE2D_LOD 的最后一个参数 0 表示使用最高精度的 Mipmap 级别
                half widthMap = SAMPLE_TEXTURE2D_LOD(_OutLineMask, sampler_OutLineMask, input.texcoord0, 0).r;
                
                // 计算最终的描边宽度：
                // _OutlineWidth * 0.001：将描边宽度从"显示友好值"转换为实际的小数值
                // lerp(1.0, widthMap, _OutlineWidthMapStrength)：根据遮罩强度在"均匀宽度"和"遮罩控制宽度"之间插值
                //   - 当 _OutlineWidthMapStrength = 0 时，所有区域宽度一致
                //   - 当 _OutlineWidthMapStrength = 1 时，完全由遮罩贴图控制各区域的宽度
                half outlineWidth = (_OutlineWidth * 0.001) * lerp(1.0, widthMap, _OutlineWidthMapStrength);
                
                // 沿顶点法线方向外扩顶点位置，生成比原模型稍大的"外壳"
                float3 positionOS = input.positionOS.xyz + input.normalOS * outlineWidth;
                
                // 将物体空间坐标转换为裁剪空间坐标（供 GPU 进行光栅化）
                output.positionCS = TransformObjectToHClip(positionOS);
                output.uv0.xy = input.texcoord0; // 传递 UV 坐标到片元着色器
                output.color = input.color;      // 传递顶点颜色到片元着色器
                return output;
            }
            
            // 片元着色器：负责计算每个像素的最终颜色
            half4 OutlineFragment(Varyings input) : SV_Target
            {
                // 采样基础色贴图，获取该像素的纹理颜色
                half4 albedo = SAMPLE_TEXTURE2D(_AlbedoMap, sampler_AlbedoMap, input.uv0.xy);
                
                // 最终描边颜色 = 描边颜色 × 基础色贴图颜色
                // Alpha 取贴图透明度和 _Alpha 属性中的较大值，确保描边不会被意外裁切
                return half4(_OutlineColor.rgb * albedo.rgb, max(albedo.a, _Alpha));
            }
            ENDHLSL
        }