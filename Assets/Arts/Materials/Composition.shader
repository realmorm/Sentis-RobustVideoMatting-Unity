Shader "VideoMatting/Composition"
{
    Properties
    {
        [HideInInspector] _MainTex ("Main Texture", 2D) = "white" {}
        
        _FgrTex ("Foreground (RGB)", 2D) = "white" {}
        _PhaTex ("Alpha Matte (R)", 2D) = "white" {}

        _BackgroundTex ("Background (RGB)", 2D) = "black" {}
        
        [Toggle] _UseBackground ("Use Background", Float) = 0
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

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 fgr = tex2D(_FgrTex, i.uv);
                fixed alpha = tex2D(_PhaTex, i.uv).r;

                fixed4 finalColor;
                
                if (_UseBackground > 0.5)
                {
                    fixed4 bg = tex2D(_BackgroundTex, i.uv);
                    finalColor = fgr * alpha + bg * (1.0 - alpha);
                    finalColor.a = 1.0; 
                }
                else
                {
                    finalColor = fgr;
                    finalColor.a = alpha; 
                }

                return finalColor;
            }
            ENDCG
        }
    }
}