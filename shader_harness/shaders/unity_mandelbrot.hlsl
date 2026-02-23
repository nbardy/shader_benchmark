Shader "Examples/Mandelbrot" {
    Properties {
        _Zoom ("Zoom Level", Float) = 1.0
        _CenterX ("Center X", Float) = -0.5
        _CenterY ("Center Y", Float) = 0.0
        _MaxIterations ("Max Iterations", Int) = 100
        _ColorScale ("Color Scale", Float) = 1.0
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

            float _Zoom;
            float _CenterX;
            float _CenterY;
            int _MaxIterations;
            float _ColorScale;

            v2f vert (appdata v) {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag (v2f i) : SV_Target {
                // Map UV to complex plane
                float2 uv = (i.uv - 0.5) * 4.0 / _Zoom;
                float2 c = float2(uv.x + _CenterX, uv.y + _CenterY);

                // Mandelbrot iteration
                float2 z = float2(0.0, 0.0);
                int iter = 0;

                for (int n = 0; n < _MaxIterations; n++) {
                    // z = z^2 + c
                    float x = z.x * z.x - z.y * z.y + c.x;
                    float y = 2.0 * z.x * z.y + c.y;
                    z = float2(x, y);

                    // Check if diverged
                    if (length(z) > 2.0) {
                        iter = n;
                        break;
                    }

                    if (n == _MaxIterations - 1) {
                        iter = _MaxIterations;
                    }
                }

                // Color based on iteration count
                float t = float(iter) / float(_MaxIterations);
                t = t * _ColorScale;

                // Create colorful gradient
                float3 color = float3(
                    0.5 + 0.5 * cos(6.28318 * (t + 0.0)),
                    0.5 + 0.5 * cos(6.28318 * (t + 0.33)),
                    0.5 + 0.5 * cos(6.28318 * (t + 0.67))
                );

                // Set color to black if in Mandelbrot set
                if (iter == _MaxIterations) {
                    color = float3(0, 0, 0);
                }

                return float4(color, 1.0);
            }
            ENDCG
        }
    }
}
