Shader "Examples/SimpleGradient" {
    Properties {
        _Color ("Main Color", Color) = (1,1,1,1)
        _GradientSpeed ("Gradient Speed", Float) = 1.0
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

            float4 _Color;
            float _GradientSpeed;

            v2f vert (appdata v) {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target {
                // Create animated gradient using UV coordinates
                float2 uv = i.uv;

                // Animated gradient with time
                float t = _Time.y * _GradientSpeed;
                float3 gradient = float3(
                    0.5 + 0.5 * cos(t + uv.x * 6.28318),
                    0.5 + 0.5 * cos(t + uv.y * 6.28318 + 2.094),
                    0.5 + 0.5 * cos(t + (uv.x + uv.y) * 6.28318 + 4.189)
                );

                return float4(gradient, 1.0) * _Color;
            }
            ENDCG
        }
    }
}
