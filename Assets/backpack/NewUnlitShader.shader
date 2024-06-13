// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unlit/SimpleUnlitTexturedShader"
{
    Properties
    {
        _MainTex("diffuse", 2D) = "white" {}
        _BumpMap("normal", 2D) = "bump" {}
        _SpecularTex("specular", 2D) = "white" {}
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
            return o;
        }

        sampler2D _MainTex;
        sampler2D _SpecularTex;
        sampler2D _BumpMap;

        fixed4 frag(v2f i) : SV_Target
        {

                fixed4 col = tex2D(_MainTex, i.uv);
                fixed4 specularcol = tex2D(_SpecularTex, i.uv);
                fixed4 normal = tex2D(_BumpMap, i.uv);
                fixed3 tangentNormal = normalize(normal.rgb);

                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * col.rgb;
                
                fixed3 diffuse = _LightColor0.rgb * col.rgb * max(0, dot(tangentNormal, i.tangentLightDir));
                
                fixed3 halfDir = normalize(i.tangentLightDir + i.tangentViewDir);
                
                fixed3 specular = _LightColor0.rgb * specularcol.rgb * pow(max(0, dot(tangentNormal, halfDir)), 32);

                return fixed4(ambient + diffuse + specular, 1.0);

        }
        ENDCG
        }
    }
}