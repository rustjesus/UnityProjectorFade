///
/// INFORMATION
/// 
/// Project: Chloroplast Games Framework
/// Game: Chloroplast Games Framework
/// Date: 21/03/2019
/// Author: Chloroplast Games
/// Website: http://www.chloroplastgames.com
/// Programmers: Pau Elias Soriano
/// Description: Unlit/VFX/Projector shader.
///

Shader "CG Framework/Unlit/VFX/Projector" {

	Properties {	
		[Header(Projector)]
		_ShadowTex("Cookie (RGB)", 2D) = "white" {}
		_ShadowTexTiling("Cookie Tiling", Vector) = (1,1,0,0)
		_ShadowTexOffset("Cookie Offset", Vector) = (0,0,0,0)
		_Tint ("Color (RGB)", Color) = (1,1,1,1)
		_ShadowLevel("Cookie Level", Range( 0 , 1)) = 1
		_FalloffMap("Falloff Map", 2D) = "white" {}
        _HorizontalFade("Horizontal Fade", Float) = 0
		[Toggle]_BackfaceCulling("Backface Culling", Float) = 1
		[Toggle]_UseVertexPosition("Use Vertex Position", Float) = 0

		[Header(UV Scroll)]
		[Toggle(_UVSCROLL_ON)] _UVScroll("UV Scroll", Float) = 0
		[Toggle]_FlipUVHorizontal("Flip UV Horizontal", Float) = 0
		[Toggle]_FlipUVVertical("Flip UV Vertical", Float) = 0
		[Toggle]_UVScrollAnimation("UV Scroll Animation", Float) = 1
		_UVScrollSpeed("UV Scroll Speed", Vector) = (0,0,0,0)

		[HideInInspector]_BlendType("Blend Type", Float) = 0.0
		[HideInInspector]_SrcBlendFactor ("Src Blend Factor", Float) = 1.0
        [HideInInspector]_DstBlendFactor ("Dst Blend Factor", Float) = 0.0
		[HideInInspector]_BlendOperation ("Blend Operation", Float) = 0.0
	}

	CGINCLUDE

	#define FOG_DISTANCE

	ENDCG
	
	SubShader {	

		// ------------------------------------------------------------------
		//  Projector rendering pass
		Pass {

			// Pass information
			Name "Projector"
			Tags {
				"RenderType"="Opaque"
				"Queue"="Geometry"
				"LightMode"="ForwardBase"
			}
			LOD 100
			Blend [_SrcBlendFactor] [_DstBlendFactor]
			BlendOp [_BlendOperation]
			Cull Back
			ColorMask RGB
			ZWrite Off
			ZTest LEqual
			Offset -1, -1

			CGPROGRAM

			// Shader compilation target level
			#pragma target 2.0

			// Shader variants
			#pragma shader_feature_local _UVSCROLL_ON

			// Untiy fog
			#pragma multi_compile_fog

			// GPU instancing
			#pragma multi_compile_instancing
			#pragma instancing_options maxcount:511
			#pragma instancing_options lodfade

			// VR defines
			#ifndef UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX
			//only defining to not throw compilation error over Unity 5.5
			#define UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input)
			#endif

			// Pass functions
			#pragma vertex vert
			#pragma fragment frag


			//UNITY_SHADER_NO_UPGRADE


			/*** Includes ***/
			#include "UnityCG.cginc"
			#include "UnityShaderVariables.cginc"
			#if !defined(CG_HELPERS_INCLUDED) 
				#include "Assets/CGF/Shaders/CGIncludes/CGHelpers.cginc"
			#endif


			/*** Defines ***/
			#if defined(FOG_LINEAR) || defined(FOG_EXP) || defined(FOG_EXP2)
				#if !defined(FOG_DISTANCE)
					#define FOG_DEPTH 1
				#endif
				#define FOG_ON 1
			#endif


			/*** Variables ***/
			sampler2D _ShadowTex;
			float2 _ShadowTexTiling;
			float2 _ShadowTexOffset;
			//fixed4 _Tint;
			float _HorizontalFade;
			float _ShadowLevel;
			sampler2D _FalloffMap;
			half _BackfaceCulling;
			float _UseVertexPosition;
			float4x4 unity_Projector;
			float4x4 unity_ProjectorClip;
			
			half _FlipUVHorizontal;
			half _FlipUVVertical;
			float2 _UVScrollSpeed;
			half _UVScrollAnimation;

			// Instance properties.
			#if UNITY_VERSION <= 20172
				UNITY_INSTANCING_CBUFFER_START(InstanceProperties)
					UNITY_DEFINE_INSTANCED_PROP(fixed4, _Tint)
				UNITY_INSTANCING_CBUFFER_END
			#endif

			#if UNITY_VERSION >= 20173
				UNITY_INSTANCING_BUFFER_START(InstanceProperties)
					UNITY_DEFINE_INSTANCED_PROP(fixed4, _Tint)
				UNITY_INSTANCING_BUFFER_END(InstanceProperties)
			#endif

			struct InstancedProperties
			{
				fixed4 Tint;
			};


			/*** Vertex data ***/
			struct appdata {
				UNITY_VERTEX_INPUT_INSTANCE_ID

				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};

			/*** Vertex to fragment interpolators ***/
			struct v2f {
				UNITY_VERTEX_OUTPUT_STEREO

				float4 position : SV_POSITION;
				float4 projectorPosition : TEXCOORD1;
				float4 projectorClipPosition : TEXCOORD2;
				float3 projectorPositionBackface : TEXCOORD3;

				#if FOG_DEPTH
					float4 worldPos : TEXCOORD4;
				#else
					float3 worldPos : TEXCOORD4;
				#endif
			};
			

			/*** Vertex function. ***/
			v2f vert (appdata v) {
				v2f o;

				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				o.projectorPosition = mul(unity_Projector, v.vertex);
				o.projectorClipPosition = mul(unity_ProjectorClip, v.vertex);
				o.projectorPositionBackface = mul(unity_Projector, float3(lerp(v.normal, v.vertex.xyz, _UseVertexPosition))).xyz;

				o.position = UnityObjectToClipPos(v.vertex);

				#if FOG_DEPTH
					o.worldPos.xyz = mul(unity_ObjectToWorld, v.vertex);
					o.worldPos.w = o.position.z;
				#endif
				
				return o;
			}


			// Fog application.
			float4 ApplyFog (float4 color, v2f o) {
				#if FOG_ON
					float viewDistance = length(_WorldSpaceCameraPos - o.worldPos.xyz);
					
					#if FOG_DEPTH
						viewDistance = UNITY_Z_0_FAR_FROM_CLIPSPACE(o.worldPos.w);
					#endif
					
					UNITY_CALC_FOG_FACTOR_RAW(viewDistance);
					
					float3 fogColor = 0;
					
					#if defined(FORWARD_BASE_PASS)
						fogColor = unity_FogColor.rgb;
					#endif
					
					color.rgb = lerp(fogColor, color.rgb, saturate(unityFogFactor));
				#endif
				
				return color;
			}
			

			/*** Fragmen function. ***/
			fixed4 frag (v2f i ) : SV_Target {

				// Initialize the instanciated properties struct.
				InstancedProperties insPro;

				#if UNITY_VERSION <= 20172
					insPro.Tint = UNITY_ACCESS_INSTANCED_PROP(_Tint);
				#endif

				#if UNITY_VERSION >= 20173
					insPro.Tint = UNITY_ACCESS_INSTANCED_PROP(InstanceProperties, _Tint);
				#endif


				// This operation must be compute in the fragment program to avoid an visual error.
				float2 projection_ScaleOffset = (_ShadowTexTiling * (_ShadowTexOffset + i.projectorPosition.xy)) / i.projectorPosition.w;

				float2 uv = float2(lerp(projection_ScaleOffset.x, (1.0 - projection_ScaleOffset.x), _FlipUVHorizontal), lerp(projection_ScaleOffset.y, (1.0 - projection_ScaleOffset.y), _FlipUVVertical));
				

				// UV scroll
				#ifdef _UVSCROLL_ON
					float2 projection_ScrollSpeed = _UVScrollSpeed * _Time.y;
					float2 projection_Scrolled = float2(projection_ScrollSpeed.x + lerp(projection_ScaleOffset.x, (1.0 - projection_ScaleOffset.x), _FlipUVHorizontal), projection_ScrollSpeed.y + lerp(projection_ScaleOffset.y, (1.0 - projection_ScaleOffset.y), _FlipUVVertical));
					
					uv = lerp(uv, projection_Scrolled, _UVScrollAnimation);
				#endif
				// End


				float4 baseColor = tex2D(_ShadowTex, uv) * insPro.Tint;

				float4 projection_Attenuation = tex2D(_FalloffMap, i.projectorClipPosition.xy / i.projectorClipPosition.w);
				float backFaceMask = saturate(dot(i.projectorPositionBackface, float3(0, 0, -1)));

				float4 projection_Final = lerp(fixed4(1, 1, 1, 0), baseColor, lerp(projection_Attenuation.a, projection_Attenuation.a * backFaceMask, _BackfaceCulling));
				float4 projection_Level = lerp(fixed4(1, 1, 1, 0), projection_Final, _ShadowLevel);
				fixed4 finalColor = projection_Level;


				// Fog application.
				finalColor = ApplyFog(finalColor, i);

				//HORIZONTAL FADE STARTS HERE
				// Adjust this section for horizontal fading only
				float2 center = float2(0.5, 0.5); // assuming the center is at (0.5, 0.5) in normalized coordinates
				float2 projectorCoord = i.projectorClipPosition.xy / i.projectorClipPosition.w;
				
				// Calculate distance from center only in the X direction
				float distanceFromCenter = abs(projectorCoord.x - center.x);

				// Adjust alpha based on the horizontal distance
				float alpha = 1.0 - saturate(distanceFromCenter * 2.0); // scale factor might need adjustment

	
				// Combine alpha with the existing color
				if (_HorizontalFade == 0)
				{
		
					finalColor.a *= alpha;
				}
				//HORIZONTAL FADE ENDS HERE

				return finalColor;
			}
			ENDCG
		}
	}
	CustomEditor "CGFUnlitProjectorMaterialEditor"
}