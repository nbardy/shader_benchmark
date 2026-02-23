Shader "Examples/CirclePattern" {
    Properties {
        _CircleCount ("Circle Count", Float) = 10.0
        _CircleRadius ("Circle Radius", Float) = 0.5
        _BackgroundColor ("Background Color", Color) = (0,0,0,1)
        _CircleColor ("Circle Color", Color) = (1,1,1,1)
    }

    SubShader {
        Tags { "RenderType"="Opaque" }

        Pass {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            float _CircleCount;
            float _CircleRadius;
            float4 _BackgroundColor;
            float4 _CircleColor;

            v2f vert (appdata v) {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target {
                // Center UV coordinates
                float2 uv = i.uv * 2.0 - 1.0;

                // Create grid of circles
                float2 gridUV = frac(uv * _CircleCount) * 2.0 - 1.0;
                float dist = length(gridUV);

                // Circle pattern with smooth edges
                float circle = smoothstep(_CircleRadius, _CircleRadius - 0.02, dist);

                // Mix between background and circle color
                float4 color = lerp(_BackgroundColor, _CircleColor, circle);

                return color;
            }
            ENDCG
        }
    }
}
