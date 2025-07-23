Shader "VideoMatting/CompositionWithThreshold"
{
    Properties
    {
        [HideInInspector] _MainTex ("Main Texture", 2D) = "white" {}
        
        [Header(Video Matting Results)]
        [NoScaleOffset] _FgrTex ("Foreground", 2D) = "white" {}
        [NoScaleOffset] _PhaTex ("Alpha Mask", 2D) = "white" {}
        
        [Header(Background Settings)]
        [NoScaleOffset] _BackgroundTex ("Background", 2D) = "black" {}
        [Toggle] _UseBackground ("Enable Background", Float) = 0
        
        [Header(Alpha Settings)]
        [Range(0.0, 1.0)] _AlphaThreshold ("Alpha Threshold", Float) = 0.5
        [Range(0.0, 1.0)] _AlphaSmoothness ("Alpha Smoothness", Float) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Transparent" "Queue"="Transparent" }
        
        Blend SrcAlpha OneMinusSrcAlpha
        ZWrite Off
        
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
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
            };

            sampler2D _MainTex;
            sampler2D _FgrTex;
            sampler2D _PhaTex;
            sampler2D _BackgroundTex;
            
            float _UseBackground;
            float _AlphaThreshold;
            float _AlphaSmoothness;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // 포그라운드와 알파 값 샘플링
                fixed4 fgr = tex2D(_FgrTex, i.uv);
                fixed alpha = tex2D(_PhaTex, i.uv).r;
                
                // 알파 threshold 적용
                fixed processedAlpha;
                if (_AlphaSmoothness > 0.001)
                {
                    // 부드러운 threshold (smoothstep)
                    float thresholdMin = _AlphaThreshold - _AlphaSmoothness * 0.5;
                    float thresholdMax = _AlphaThreshold + _AlphaSmoothness * 0.5;
                    processedAlpha = smoothstep(thresholdMin, thresholdMax, alpha);
                }
                else
                {
                    // 하드 threshold
                    processedAlpha = alpha >= _AlphaThreshold ? alpha : 0.0;
                }

                fixed4 finalColor;
                
                // 배경 사용 여부에 따른 분기
                if (_UseBackground > 0.5)
                {
                    // 배경 사용: 기존 알파 블렌딩
                    fixed4 bg = tex2D(_BackgroundTex, i.uv);
                    finalColor = fgr * processedAlpha + bg * (1.0 - processedAlpha);
                    finalColor.a = 1.0; // 불투명
                }
                else
                {
                    // 배경 미사용: 투명 배경
                    finalColor = fgr;
                    finalColor.a = processedAlpha; // ✨ 처리된 알파 값 사용
                }

                return finalColor;
            }
            ENDCG
        }
    }
}