// Using modified code from http://wiki.unity3d.com/index.php/CGVertexLit
// N64 3-point Filtering from http://www.emutalk.net/threads/54215-Emulating-Nintendo-64-3-sample-Bilinear-Filtering-using-Shaders
Shader "Reality Shader 64" {
	Properties {
		_MainTex("Diffuse Texture", 2D) = "white" {}
		[Toggle] _N64("3-point Texture Filtering", Float) = 0
		_AlphaCutoff("Alpha Cutoff", Range(0, 1)) = 0.5
		_Transparency("Transparency", Range(0, 1)) = 1
		[HideInInspector] _SrcBlend ("_SrcBlend", Float) = 1
		[HideInInspector] _DstBlend ("_DstBlend", Float) = 0
		[HideInInspector] _ZWrite ("_ZWrite", Float) = 1

		_Tint("Tint", Color) = (1,1,1,0)
		[Header(Vertex Color options)]
		[Toggle] _GammaToLinear("In gamma space?", Float) = 0
		[Toggle] _IgnoreVertexColor("Ignore?", Float) = 0

		[Header(Specular)]
		[Toggle] _Spec("Enabled?", Float) = 0
		_SpecColor ("Spec Color", Color) = (1,1,1,0)
		_Shininess ("Shininess", Range (0.01, 1)) = 1

		[Header(Emission)]
		[Toggle] _Emission("Enabled?", Float) = 0
		_EmissionColor("Emissive Color", Color) = (0,0,0,0)
		_EmissionTex("Emission Texture", 2D) = "black" {}

		[Header(Overlay Texture)]
		[KeywordEnum(None, Add, Multiply, Blend)] _Overlay("Overlay mode", Float) = 0
		[KeywordEnum(MainTex, Spherical, ViewSpace, X, Y, Z)] _UV("UV mapping", Float) = 0
		[Toggle] _WorldPos("Use World Position", Float) = 1
		_Blend("Blend amount", Range(0, 1)) = 1.0
		_OverlayTex("Overlay Texture", 2D) = "white"{}
		_OverlayColor("Overlay Color", Color) = (1,1,1,0)
		_ScrollSpeedX("Scroll speed X", Float) = 0.0
		_ScrollSpeedY("Scroll speed Y", Float) = 0.0

		[Header(Lighting)]
		_SelfIllum("Self-Illumination", Range(0, 1)) = 0

		[Header(Other)]
		[HideInInspector] _Cull ("Backface Culling", Float) = 2
	}
 
	SubShader {
		Tags {"Queue"="Geometry" "RenderType"="Opaque" "IgnoreProjector"="True" "LightMode"="Vertex"}
		LOD 100
 
		Blend [_SrcBlend] [_DstBlend]
		ZWrite [_ZWrite]

		Cull [_Cull]

		Pass {
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#pragma shader_feature __ _RENDERING_CUTOUT _RENDERING_FADE _RENDERING_TRANSPARENT

			#pragma shader_feature __ _SPEC_ON
			#pragma shader_feature __ _EMISSION_ON
			#pragma shader_feature __ _GAMMATOLINEAR_ON
			#pragma shader_feature __ _IGNOREVERTEXCOLOR_ON
			#pragma shader_feature __ _N64_ON

			// make fog work
			#pragma multi_compile_fog

			// overlay texture blending modes
			#pragma shader_feature _OVERLAY_NONE _OVERLAY_ADD _OVERLAY_MULTIPLY _OVERLAY_BLEND

			// overlay texture UV mapping modes
			#pragma shader_feature _UV_MAINTEX _UV_SPHERICAL _UV_VIEWSPACE _UV_X _UV_Y _UV_Z
			#pragma shader_feature __ _WORLDPOS_ON
 
			#include "UnityCG.cginc"
  
			// main texture
			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4 _MainTex_TexelSize;

			// alpha
			float _AlphaCutoff;
			float _Transparency;

			// color tint
			fixed4 _Tint;

			// spec
			fixed4 _SpecColor;
			half _Shininess;

			// emission
			fixed4 _EmissionColor;
			sampler2D _EmissionTex;
			float4 _EmissionTex_ST;
			float4 _EmissionTex_TexelSize;

			// overlay texture
			sampler2D _OverlayTex;
			fixed4 _OverlayColor;
			float4 _OverlayTex_ST;
			float4 _OverlayTex_TexelSize;
			float _Overlay;
			float _Blend;
			float _ScrollSpeedX;
			float _ScrollSpeedY;

			// self-illumination
			float _SelfIllum;
 
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
				float2 emissionUV : TEXCOORD1;
				float2 overlayUV : TEXCOORD2;
				fixed3 color : COLOR0;

				UNITY_FOG_COORDS(3)

				#if _SPEC_ON
				fixed3 spec : COLOR1;
				#endif
			};
 
			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.emissionUV = TRANSFORM_TEX(v.texcoord, _EmissionTex);

				UNITY_TRANSFER_FOG(o, o.pos);

				// overlay texture UV mapping
				float4 worldPos = mul(unity_ObjectToWorld, v.vertex);

				#if _UV_MAINTEX
				o.overlayUV = TRANSFORM_TEX(v.texcoord, _OverlayTex);
				#endif

				#if _UV_X
				#if _WORLDPOS_ON
				o.overlayUV = TRANSFORM_TEX(worldPos.zy, _OverlayTex);
				#else
				o.overlayUV = TRANSFORM_TEX(v.vertex.zy, _OverlayTex);
				#endif
				#endif

				#if _UV_Y
				#if _WORLDPOS_ON
				o.overlayUV = TRANSFORM_TEX(worldPos.xz, _OverlayTex);
				#else
				o.overlayUV = TRANSFORM_TEX(v.vertex.xz, _OverlayTex);
				#endif
				#endif

				#if _UV_Z
				#if _WORLDPOS_ON
				o.overlayUV = TRANSFORM_TEX(worldPos.xy, _OverlayTex);
				#else
				o.overlayUV = TRANSFORM_TEX(v.vertex.xy, _OverlayTex);
				#endif
				#endif

				#if _UV_SPHERICAL
				float3 viewDir = normalize(ObjSpaceViewDir(v.vertex));
				float3 r = reflect(-viewDir, v.normal);
				r = mul((float3x3)UNITY_MATRIX_MV, r);
				r.z += 1;
				float m = 2 * length(r);
				o.overlayUV = TRANSFORM_TEX((r.xy / m + 0.5), _OverlayTex);
				#endif

				#if _UV_VIEWSPACE
				o.overlayUV = TRANSFORM_TEX(UnityObjectToViewPos(v.vertex), _OverlayTex);
				#endif

				float3 viewPos = UnityObjectToViewPos(v.vertex).xyz;
				fixed3 viewDirObj = normalize(ObjSpaceViewDir(v.vertex));

				half3 vertexColor;

				#if _GAMMATOLINEAR_ON
				vertexColor = GammaToLinearSpace(v.color);
				#else
				vertexColor = v.color;
				#endif

				#if _IGNOREVERTEXCOLOR_ON
				vertexColor = half3(1, 1, 1);
				#endif

				half3 tempColor = vertexColor * _SelfIllum + UNITY_LIGHTMODEL_AMBIENT.xyz;

				// calculate lighting for 4 lights
				for (int i = 0; i < 4; i++) {
					half3 lightDir = unity_LightPosition[i].xyz - viewPos.xyz * unity_LightPosition[i].w;
					half distanceSq = dot(lightDir, lightDir);

					half atten = 1.0 / (1.0 + unity_LightAtten[i].z * distanceSq);

					if (unity_LightPosition[i].w != 0 && distanceSq > unity_LightAtten[i].w) atten = 0.0; // set to 0 if outside of range

					fixed3 lightDirObj = mul((float3x3)UNITY_MATRIX_T_MV, lightDir);	// view => model
					lightDirObj = normalize(lightDirObj);

					fixed NdotL = max (0, dot (v.normal, lightDirObj));
					fixed intensity = saturate(NdotL);

					tempColor += vertexColor * unity_LightColor[i].rgb * intensity * atten * (1 - _SelfIllum);
 
					#if _SPEC_ON
					fixed3 H = normalize(viewDirObj + lightDirObj);
					fixed HdotN = max(0, dot(v.normal, H));

					fixed spec = pow(saturate(HdotN), _Shininess * 128.0);
					o.spec += spec * unity_LightColor[i].rgb * atten *_SpecColor * (1 - _SelfIllum);
					#endif
				}
				
				o.color = tempColor * _Tint;

				return o;
			}

			#if _N64_ON
			float4 N64BilinearFilter(sampler2D tex, float2 texcoord, float4 texelsize)
			{

				float2 tex_pix_a = float2(1 / texelsize.z, 0);
				float2 tex_pix_b = float2(0, 1 / texelsize.w);
				float2 tex_pix_c = float2(tex_pix_a.x, tex_pix_b.y);
				float2 half_tex = float2(tex_pix_a.x*0.5, tex_pix_b.y*0.5);
				float2 UVCentered = texcoord - half_tex;

				float4 diffuseColor = tex2D(tex, UVCentered);
				float4 sample_a = tex2D(tex, UVCentered + tex_pix_a);
				float4 sample_b = tex2D(tex, UVCentered + tex_pix_b);
				float4 sample_c = tex2D(tex, UVCentered + tex_pix_c);

				float interp_x = modf(UVCentered.x * texelsize.z, texelsize.z);
				float interp_y = modf(UVCentered.y * texelsize.w, texelsize.w);

				if (UVCentered.x < 0)
				{
					interp_x = 1 - interp_x * (-1);
				}
				if (UVCentered.y < 0)
				{
					interp_y = 1 - interp_y * (-1);
				}

				diffuseColor = (diffuseColor + interp_x * (sample_a - diffuseColor) + interp_y * (sample_b - diffuseColor))*(1 - step(1, interp_x + interp_y));
				diffuseColor += (sample_c + (1 - interp_x) * (sample_b - sample_c) + (1 - interp_y) * (sample_a - sample_c))*step(1, interp_x + interp_y);

				return diffuseColor;
			}
			#endif

			fixed4 frag (v2f i) : SV_TARGET {
				fixed4 c;
				
				fixed4 mainTex;
				fixed4 overlayTex;
				
				// scroll the uv of the overlay texture
				/*
				#if _UV_MAINTEX
				if (_ScrollSpeedX != 0 || _ScrollSpeedY != 0) {
					i.overlayUV.xy -= frac(_Time.x * float2((_ScrollSpeedX * _OverlayTex_ST.x), (_ScrollSpeedY * _OverlayTex_ST.y)));
				}
				#else
				if (_ScrollSpeedX != 0 || _ScrollSpeedY != 0) {
					i.overlayUV.xy -= frac(_Time.x * float2(_ScrollSpeedX , _ScrollSpeedY));
				}
				#endif
				*/
				if (_ScrollSpeedX != 0 || _ScrollSpeedY != 0) {
					i.overlayUV.xy -= frac(_Time.x * float2(_ScrollSpeedX, _ScrollSpeedY));
				}
				
				// sample using tex2D or custom filter
				#if _N64_ON
				mainTex = N64BilinearFilter(_MainTex, i.uv, _MainTex_TexelSize);
				overlayTex = N64BilinearFilter(_OverlayTex, i.overlayUV, _OverlayTex_TexelSize);
				#else
				mainTex = tex2D(_MainTex, i.uv);
				overlayTex = tex2D(_OverlayTex, i.overlayUV);
				#endif
				overlayTex.rgb *= _OverlayColor;


				// alpha
				float alpha = mainTex.a;

				// blend modes for the overlay texture
				#ifdef _OVERLAY_NONE
				c.rgb = mainTex.rgb;
				#endif
				#ifdef _OVERLAY_ADD
				c.rgb = mainTex.rgb + (overlayTex.rgb * _Blend);
				#endif
				#ifdef _OVERLAY_MULTIPLY
				c.rgb = mainTex.rgb;
				mainTex.rgb *= overlayTex.rgb;
				c.rgb = lerp(c.rgb, mainTex.rgb, _Blend);
				#endif
				#ifdef _OVERLAY_BLEND
				c.rgb = lerp(mainTex.rgb, overlayTex.rgb, _Blend);
				#endif

				// color tint
				c.rgb *= i.color;

				// transparency pre-multiplied alpha
				#if defined(_RENDERING_TRANSPARENT)
				c.rgb *= alpha * _Transparency;
				#endif

				// add specular highlights
				#if _SPEC_ON
				c.rgb += (i.spec * (1 - _SelfIllum));
				#endif

				// add emission
				#if _EMISSION_ON
				#if _N64_ON
				fixed4 emissionTex = N64BilinearFilter(_EmissionTex, i.emissionUV, _EmissionTex_TexelSize);
				#else
				fixed4 emissionTex = tex2D(_EmissionTex, i.emissionUV);
				#endif
				c.rgb += (emissionTex.rgb + _EmissionColor.rgb);
				#endif

				// alpha
				#if defined(_RENDERING_FADE) || defined(_RENDERING_TRANSPARENT)
				c.a = alpha * _Transparency;
				#else
				c.a = 1;
				#endif
				#if defined (_RENDERING_CUTOUT)
				clip(alpha - _AlphaCutoff);
				#endif

				UNITY_APPLY_FOG(i.fogCoord, c);

				return c;
			}
			ENDCG
		}
	}
	Fallback "Legacy Shaders\Vertex Lit"
	CustomEditor "RealityShader64GUI"
}