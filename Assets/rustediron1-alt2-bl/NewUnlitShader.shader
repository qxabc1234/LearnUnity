// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unlit/SphereTexturedShader"
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

        float4 _MainTex_ST;

        // 顶点着色器输入
        struct appdata
        {
            float4 vertex : POSITION; // 顶点位置
            float3 normal : NORMAL;
            float2 uv : TEXCOORD0; // 纹理坐标
            float3 tangent : TANGENT;

        };

        // 顶点着色器输出（"顶点到片元"）
        struct v2f
        {
            float2 uv : TEXCOORD0; // 纹理坐标
            float4 vertex : SV_POSITION; // 裁剪空间位置
            fixed3 tangentLightDir : TEXCOORD1;
            fixed3 tangentViewDir : TEXCOORD2;
            float3 worldNormal : TEXCOORD3;
            fixed3 worldViewDir : TEXCOORD4;
        };

        // 顶点着色器
        v2f vert(appdata v)
        {
            v2f o;

            o.vertex = UnityObjectToClipPos(v.vertex);

            o.uv = v.uv * _MainTex_ST.xy + _MainTex_ST.zw;

            float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
            float3 worldNormal = UnityObjectToWorldNormal(v.normal);
            float3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
            float3 worldBinormal = cross(worldNormal, worldTangent);
            float3 OTT0 = float3(worldTangent.x, worldBinormal.x, worldNormal.x);
            float3 OTT1 = float3(worldTangent.y, worldBinormal.y, worldNormal.y);
            float3 OTT2 = float3(worldTangent.z, worldBinormal.z, worldNormal.z);
            fixed3 lightDir = ObjSpaceLightDir(o.vertex);
            fixed3 viewDir = ObjSpaceViewDir(o.vertex);
            o.tangentLightDir = normalize(half3(dot(OTT0.xyz, lightDir), dot(OTT1.xyz, lightDir), dot(OTT2.xyz, lightDir)));
            o.tangentViewDir = normalize(half3(dot(OTT0.xyz, viewDir), dot(OTT1.xyz, viewDir), dot(OTT2.xyz, viewDir)));
            o.worldNormal = worldNormal;
            o.worldViewDir = WorldSpaceViewDir(o.vertex);
            return o;
        }

        sampler2D _MainTex;
        sampler2D _BumpMap;
        sampler2D _AOTex;
        sampler2D _RoughnessTex;
        sampler2D _metallic;
        float PI = 3.14159265359;

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
                fixed4 normal = tex2D(_BumpMap, i.uv);
                fixed3 tangentNormal = normalize(normal.rgb);
                float roughness = tex2D(_RoughnessTex, i.uv).r;
                float ao = tex2D(_AOTex, i.uv).r;
                float metallic = tex2D(_metallic, i.uv).r;

               // fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * col.rgb;


              //  fixed3 diffuse = _LightColor0.rgb * col.rgb * max(0, dot(tangentNormal, i.tangentLightDir));

                fixed3 halfDir = normalize(i.tangentLightDir + i.tangentViewDir);

               // fixed3 specular = _LightColor0.rgb * specularcol.rgb * pow(max(0, dot(tangentNormal, halfDir)), 32);

                fixed3 F0 = fixed3(0.04, 0.04, 0.04);
                fixed3 albedo = fixed3(pow(col.r, 2.2), pow(col.g, 2.2), pow(col.b, 2.2));
                F0 = lerp(F0, albedo, metallic);

                //Fresnel
                float cosTheta = max(dot(halfDir, i.tangentViewDir), 0.0);
                fixed3 F = F0 + (1 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5);

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
                fixed3 radiance = _LightColor0.rgb;
                fixed3 kS = F;
                fixed3 kD = fixed3(1.0 - kS.x, 1.0 - kS.y, 1.0 - kS.z) * (1.0 - metallic);
                fixed3 nominator = NDF * G * F;
                float denominator = 4.0 * NdotV * NdotL + 0.001;
                fixed3 specular = nominator / denominator;

                fixed3 ambient = albedo * 0.03 * ao;
                fixed3 Lo = (kD * albedo / PI + specular) * radiance * NdotL;

                fixed3 color = ambient + Lo;

                return fixed4(color, 1.0);

        }
        ENDCG
        }
    }
}