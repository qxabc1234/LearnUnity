// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Qiu/PBRShader"
{
    Properties
    {
        _MainTex("diffuse", 2D) = "white" {}
        _BumpMap("normal", 2D) = "bump" {}
        _metallic("metallic", 2D) = "white" {}
        _RoughnessTex("roughness", 2D) = "white" {}
        _AOTex("ao", 2D) = "white" {}
    }
        SubShader
    {
        Pass
        {
            Tags {"LightMode" = "ForwardBase"}

            CGPROGRAM
        // 使用 "vert" 函数作为顶点着色器
        #pragma vertex vert
        // 使用 "frag" 函数作为像素（片元）着色器
        #pragma fragment frag
        #include "UnityCG.cginc" // 对于 UnityObjectToWorldNormal
        #include "UnityLightingCommon.cginc" // 对于 _LightColor0


        #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight
        #include "AutoLight.cginc"

        float4 _MainTex_ST;

        // 顶点着色器输入
        struct appdata
        {
            float4 vertex : POSITION; // 顶点位置
            float3 normal : NORMAL;
            float2 uv : TEXCOORD0; // 纹理坐标
            float4 tangent : TANGENT;

        };

        // 顶点着色器输出（"顶点到片元"）
        struct v2f
        {
            float4 pos : SV_POSITION; // 裁剪空间位置
            float2 uv : TEXCOORD0; // 纹理坐标
            fixed3 tangentLightDir : TEXCOORD1;
            fixed3 tangentViewDir : TEXCOORD2;
            float3 worldNormal : TEXCOORD3;
            fixed3 worldViewDir : TEXCOORD4;
            SHADOW_COORDS(5)
        };

        // 顶点着色器
        v2f vert(appdata v)
        {
            v2f o;

            o.pos = UnityObjectToClipPos(v.vertex);

            o.uv = v.uv * _MainTex_ST.xy + _MainTex_ST.zw;

            float4 worldPos = mul(unity_ObjectToWorld, v.vertex);
            float3 worldNormal = normalize(UnityObjectToWorldNormal(v.normal));
            float3 worldTangent = normalize(UnityObjectToWorldDir(v.tangent.xyz));
            float3 worldBinormal = normalize(cross(worldNormal, worldTangent)) * v.tangent.w;
            float3 OTT0 = float3(worldTangent.x, worldTangent.y, worldTangent.z);
            float3 OTT1 = float3(worldBinormal.x, worldBinormal.y, worldBinormal.z);
            float3 OTT2 = float3(worldNormal.x, worldNormal.y, worldNormal.z);
            fixed3 lightDir = WorldSpaceLightDir(v.vertex);
            fixed3 viewDir = WorldSpaceViewDir(v.vertex);
            o.tangentLightDir = normalize(half3(dot(OTT0.xyz, lightDir), dot(OTT1.xyz, lightDir), dot(OTT2.xyz, lightDir)));
            o.tangentViewDir = normalize(half3(dot(OTT0.xyz, viewDir), dot(OTT1.xyz, viewDir), dot(OTT2.xyz, viewDir)));

            TRANSFER_SHADOW(o)
            return o;
        }

        sampler2D _MainTex;
        sampler2D _BumpMap;
        sampler2D _AOTex;
        sampler2D _RoughnessTex;
        sampler2D _metallic;
        #define  PI 3.14159265359

        float GeometrySchlickGGX(float NdotV, float roughness)
        {
            float r = (roughness + 1.0);
            float k = (r * r) / 8.0;

            float num = NdotV;
            float denom = NdotV * (1.0 - k) + k;

            return num / denom;
        }

        fixed4 frag(v2f i) : SV_Target
        {

                fixed4 col = tex2D(_MainTex, i.uv);
                fixed3 normal = UnpackNormal(tex2D(_BumpMap, i.uv));
                fixed3 tangentNormal = normalize(normal.rgb);
                float smoothness = tex2D(_metallic, i.uv).a;
                float roughness = 1.0 - smoothness;
  
                float ao = tex2D(_AOTex, i.uv).r;
                float metallic = tex2D(_metallic, i.uv).r;

              //  fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * col.rgb;


              //  fixed3 diffuse = _LightColor0.rgb * col.rgb * max(0, dot(tangentNormal, i.tangentLightDir));

                fixed3 halfDir = normalize(i.tangentLightDir + i.tangentViewDir);

             //   fixed3 specular = _LightColor0.rgb * specularcol.rgb * pow(max(0, dot(tangentNormal, halfDir)), 32);

                float3 F0 = 0.04;
                float3 albedo = col;
                F0 = lerp(F0, albedo, metallic);

                //Fresnel
                float cosTheta = max(dot(halfDir, i.tangentViewDir), 0.0);
                float3 F = F0 + (1 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5);

                //DistributionGGX
                float a = roughness * roughness;
                float a2 = a * a;
                float NdotH = max(dot(tangentNormal, halfDir), 0.0);
                float NdotH2 = NdotH * NdotH;

                float num = a2;
                float denom = (NdotH2 * (a2 - 1.0) + 1.0);
                denom = PI * denom * denom;

                float NDF = num / denom;

                //GeometrySmith
                float NdotV = max(dot(tangentNormal, i.tangentViewDir), 0.0);
                float NdotL = max(dot(tangentNormal, i.tangentLightDir), 0.0);
                float ggx1 = GeometrySchlickGGX(NdotV, roughness);
                float ggx2 = GeometrySchlickGGX(NdotL, roughness);

                float G = ggx1 * ggx2;

                //Cook-Torrance BRDF
                float3 radiance = _LightColor0.rgb;
                float3 kS = F;
                float3 kD = float3(1, 1, 1) - kS;
                kD *= 1.0 - metallic;
                float3 nominator = NDF * G * F;
                float denominator = 4.0 * NdotV * NdotL + 0.001;
                float3 specular = nominator / denominator;

                float3 ambient = albedo * ao * 0.8 ;
                float3 diffuse = kD * albedo / PI;
                float3 Lo = (diffuse + specular) * radiance * NdotL;
                fixed shadow = SHADOW_ATTENUATION(i);

                float3 color = ambient + Lo * shadow;
                color = color / (color + 1);

                return fixed4(color, 1.0);

        }
        ENDCG
        }


        Pass
        {
            Tags {"LightMode" = "ShadowCaster"}

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_shadowcaster
            #include "UnityCG.cginc"

            struct v2f {
                V2F_SHADOW_CASTER;
            };

            v2f vert(appdata_base v)
            {
                v2f o;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                return o;
            }

            float4 frag(v2f i) : SV_Target
            {
                SHADOW_CASTER_FRAGMENT(i)
            }
            ENDCG
        }

    }
}