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