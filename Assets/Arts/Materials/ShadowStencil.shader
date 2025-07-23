Shader "VideoMatting/ShadowStencil"
{
    Properties
    {
        [HideInInspector] _MainTex ("Main Texture", 2D) = "white" {}
        
        [Header(Video Matting Results)]
        [NoScaleOffset] _FgrTex ("Foreground", 2D) = "white" {}
        [NoScaleOffset] _PhaTex ("Alpha Mask", 2D) = "white" {}
        
        [Header(Shadow Settings)]
        _ShadowColor ("Shadow Color", Color) = (0, 0, 0, 0.5)
        _ShadowIntensity ("Shadow Intensity", Range(0, 1)) = 0.8
        [Toggle] _UseOriginalColors ("Use Original Colors", Float) = 0
        
        [Header(Alpha Settings)]
        [Range(0.0, 1.0)] _AlphaThreshold ("Alpha Threshold", Float) = 0.5
        [Range(0.0, 1.0)] _AlphaSmoothness ("Alpha Smoothness", Float) = 0.5
        
        [Header(Stencil Settings)]
        _StencilRef ("Stencil Reference", Range(0, 255)) = 1
        [Enum(UnityEngine.Rendering.CompareFunction)] _StencilComp ("Stencil Comparison", Float) = 8
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilOp ("Stencil Operation", Float) = 2
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilFail ("Stencil Fail Op", Float) = 0
        [Enum(UnityEngine.Rendering.StencilOp)] _StencilZFail ("Stencil ZFail Op", Float) = 0
        _StencilWriteMask ("Stencil Write Mask", Range(0, 255)) = 255
        _StencilReadMask ("Stencil Read Mask", Range(0, 255)) = 255
    }
    SubShader
    {
        Tags { 
            "RenderType"="Transparent" 
            "Queue"="Transparent"
            "IgnoreProjector"="True"
        }
        
        Stencil
        {
            Ref [_StencilRef]
            Comp [_StencilComp]
            Pass [_StencilOp]
            Fail [_StencilFail]
            ZFail [_StencilZFail]
            ReadMask [_StencilReadMask]
            WriteMask [_StencilWriteMask]
        }
        
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        Cull Off
        
        Pass
        {
            Name "ShadowStencil"
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile _ USE_ORIGINAL_COLORS
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 worldPos : TEXCOORD1;
            };

            sampler2D _MainTex;
            sampler2D _FgrTex;
            sampler2D _PhaTex;
            
            fixed4 _ShadowColor;
            float _ShadowIntensity;
            float _UseOriginalColors;
            float _AlphaThreshold;
            float _AlphaSmoothness;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 fgr = tex2D(_FgrTex, i.uv);
                fixed alpha = tex2D(_PhaTex, i.uv).r;
                
                fixed processedAlpha;
                if (_AlphaSmoothness > 0.001)
                {
                    float thresholdMin = _AlphaThreshold - _AlphaSmoothness * 0.5;
                    float thresholdMax = _AlphaThreshold + _AlphaSmoothness * 0.5;
                    processedAlpha = smoothstep(thresholdMin, thresholdMax, alpha);
                }
                else
                {
                    processedAlpha = alpha >= _AlphaThreshold ? alpha : 0.0;
                }
                
                fixed4 finalColor;
                
                if (_UseOriginalColors > 0.5)
                {
                    finalColor.rgb = fgr.rgb * _ShadowIntensity;
                }
                else
                {
                    finalColor.rgb = _ShadowColor.rgb;
                }
                
                finalColor.a = processedAlpha * _ShadowIntensity;
                
                clip(finalColor.a - 0.001);
                
                return finalColor;
            }
            ENDCG
        }
    }
    
    Fallback "Sprites/Default"
}