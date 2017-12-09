// The shader code is converted to use in Unity3D from
// Protophore created by otaviogood on Shadertoy(https://www.shadertoy.com/view/XljGDz)

Shader "Custom/Protophore" {
	Properties{
		iMouse("mouse", Vector) = (0.0, 0.0, 0.0, 1.0)
	}
	SubShader{
		Tags{ "RenderType" = "Opaque" }
		LOD 200
		Pass{
		CGPROGRAM
		#pragma vertex vert_img
		#pragma fragment frag

		#include "UnityCG.cginc"

		// Number of times the fractal repeats
		#define RECURSION_LEVELS 4
		// Animation splits the sphere in different directions
		// This ended up running a significantly slower fps and not looking very different. :(
		//#define SPLIT_ANIM
		uniform float2 iMouse = float2(0.5, 0.5);

		float localTime = 0.0;
		float marchCount;

		static const float PI = 3.14159265;

		float3 saturate(float3 a) { return clamp(a, 0.0, 1.0); }
		float2 saturate(float2 a) { return clamp(a, 0.0, 1.0); }
		float saturate(float a) { return clamp(a, 0.0, 1.0); }

		float3 RotateX(float3 v, float rad)
		{
			float cosX = cos(rad);
			float sinX = sin(rad);
			return float3(v.x, cosX * v.y + sinX * v.z, -sinX * v.y + cosX * v.z);
		}
		float3 RotateY(float3 v, float rad)
		{
			float cosY = cos(rad);
			float sinY = sin(rad);
			return float3(cosY * v.x - sinY * v.z, v.y, sinY * v.x + cosY * v.z);
		}
		float3 RotateZ(float3 v, float rad)
		{
			float cosZ = cos(rad);
			float sinZ = sin(rad);
			return float3(cosZ * v.x + sinZ * v.y, -sinZ * v.x + cosZ * v.y, v.z);
		}

		// This is a procedural environment map with a giant overhead softbox,
		// 4 lights in a horizontal circle, and a bottom-to-top fade.
		float3 GetEnvColor2(float3 rayDir, float3 sunDir)
		{
			// fade bottom to top so it looks like the softbox is casting light on a floor
			// and it's bouncing back
			float3 final = float3(1.0, 1.0, 1.0) * dot(-rayDir, sunDir) * 0.5 + 0.5;
			final *= 0.125;
			// overhead softbox, stretched to a rectangle
			if ((rayDir.y > abs(rayDir.x)*1.0) && (rayDir.y > abs(rayDir.z*0.25))) final = float3(2.0, 2.0, 2.0)*rayDir.y;
			// fade the softbox at the edges with a rounded rectangle.
			float roundBox = length(max(abs(rayDir.xz / max(0.0, rayDir.y)) - float2(0.9, 4.0), 0.0)) - 0.1;
			final += float3(0.8, 0.8, 0.8)* pow(saturate(1.0 - roundBox*0.5), 6.0);
			// purple lights from side
			final += float3(8.0, 6.0, 7.0) * saturate(0.001 / (1.0 - abs(rayDir.x)));
			// yellow lights from side
			final += float3(8.0, 7.0, 6.0) * saturate(0.001 / (1.0 - abs(rayDir.z)));
			return float3(final);
		}

		float3 camPos = float3(0.0, 0.0, 0.0), camFacing;
		float3 camLookat = float3(0, 0.0, 0);

		// polynomial smooth min (k = 0.1);
		float smin(float a, float b, float k)
		{
			float h = clamp(0.5 + 0.5*(b - a) / k, 0.0, 1.0);
			// replace mix with lerp
			return lerp(b, a, h) - k*h*(1.0 - h);
		}

		float2 matMin(float2 a, float2 b)
		{
			if (a.x < b.x) return a;
			else return b;
		}

		float spinTime;
		static const float3 diagN = normalize(float3(-1.0, -1.0, -1.0));
		float cut = 0.77;
		static const float inner = 0.333;
		static const float outness = 1.414;
		float finWidth;
		float teeth;
		float globalTeeth;

		float2 sphereIter(float3 p, float radius, float subA)
		{
			finWidth = 0.1;
			teeth = globalTeeth;
			float blender = 0.25;
			float2 final = float2(1000000.0, 0.0);
			for (int i = 0; i < RECURSION_LEVELS; i++)
			{
#ifdef SPLIT_ANIM
				// rotate top and bottom of sphere opposite directions
				p = RotateY(p, spinTime*sign(p.y)*0.05 / blender);
#endif
				// main sphere
				float d = length(p) - radius*outness;
#ifdef SPLIT_ANIM
				// subtract out disc at the place where rotation happens so we don't have artifacts
				d = max(d, -(max(length(p) - radius*outness + 0.1, abs(p.y) - finWidth*0.25)));
#endif

				// calc new position at 8 vertices of cube, scaled
				float3 corners = abs(p) + diagN * radius;
				float lenCorners = length(corners);
				// subtract out main sphere hole, mirrored on all axises
				float subtracter = lenCorners - radius * subA;
				// make mirrored fins that go through all vertices of the cube
				float3 ap = abs(-p) * 0.7071;	// 1/sqrt(2) to keep distance field normalized
				subtracter = max(subtracter, -(abs(ap.x - ap.y) - finWidth));
				subtracter = max(subtracter, -(abs(ap.y - ap.z) - finWidth));
				subtracter = max(subtracter, -(abs(ap.z - ap.x) - finWidth));
				// subtract sphere from fins so they don't intersect the inner spheres.
				// also animate them so they are like teeth
				subtracter = min(subtracter, lenCorners - radius * subA + teeth);
				// smoothly subtract out that whole complex shape
				d = -smin(-d, subtracter, blender);
				//vec2 sphereDist = sphereB(abs(p) + diagN * radius, radius * inner, cut);	// recurse
				// do a material-min with the last iteration
				final = matMin(final, float2(d, float(i)));

#ifndef SPLIT_ANIM
				corners = RotateY(corners, spinTime*0.25 / blender);
#endif
				// Simple rotate 90 degrees on X axis to keep things fresh
				p = float3(corners.x, corners.z, -corners.y);
				// Scale things for the next iteration / recursion-like-thing
				radius *= inner;
				teeth *= inner;
				finWidth *= inner;
				blender *= inner;
			}
			// Bring in the final smallest-sized sphere
			float d = length(p) - radius*outness;
			final = matMin(final, float2(d, 6.0));
			return final;
		}

		float2 DistanceToObject(float3 p)
		{
			float2 distMat = sphereIter(p, 5.2 / outness, cut);
			return distMat;
		}

		// dirVec MUST BE NORMALIZED FIRST!!!!
		float SphereIntersect(float3 pos, float3 dirVecPLZNormalizeMeFirst, float3 spherePos, float rad)
		{
			float3 radialVec = pos - spherePos;
			float b = dot(radialVec, dirVecPLZNormalizeMeFirst);
			float c = dot(radialVec, radialVec) - rad * rad;
			float h = b * b - c;
			if (h < 0.0) return -1.0;
			return -b - sqrt(h);
		}

		fixed4 frag(v2f_img i) : SV_Target
		{
			localTime = _Time.y - 0.0;
			// ---------------- First, set up the camera rays for ray marching ----------------
			float2 uv = i.uv *2.0 - 1.0;
			float zoom = 1.7;
			uv /= zoom;

			// Camera up vector.
			float3 camUp = float3(0, 1, 0);

			// Camera lookat.
			camLookat = float3(0, 0.0, 0);

			// debugging camera
			float mx = iMouse.x / _ScreenParams.x*PI*2.0 - 0.7 + localTime*3.1415 * 0.0625*0.666;
			float my = -iMouse.y / _ScreenParams.y*10.0 - sin(localTime * 0.31)*0.5;//*PI/2.01;
			camPos += float3(cos(my)*cos(mx), sin(my), cos(my)*sin(mx))*(12.2);

			// Camera setup.
			float3 camVec = normalize(camLookat - camPos);
			float3 sideNorm = normalize(cross(camUp, camVec));
			float3 upNorm = cross(camVec, sideNorm);
			float3 worldFacing = (camPos + camVec);
			float3 worldPix = worldFacing + uv.x * sideNorm * (_ScreenParams.x / _ScreenParams.y) + uv.y * upNorm;
			float3 rayVec = normalize(worldPix - camPos);

			// ----------------------------------- Animate ------------------------------------
			localTime = _Time.y*0.5;
			// This is a wave function like a triangle wave, but with flat tops and bottoms.
			// period is 1.0
			float rampStep = min(3.0, max(1.0, abs((frac(localTime) - 0.5)*1.0)*8.0))*0.5 - 0.5;
			rampStep = smoothstep(0.0, 1.0, rampStep);
			// lopsided triangle wave - goes up for 3 time units, down for 1.
			float step31 = (max(0.0, (frac(localTime + 0.125) - 0.25)) - min(0.0, (frac(localTime + 0.125) - 0.25))*3.0)*0.333;

			spinTime = step31 + localTime;
			//globalTeeth = 0.0 + max(0.0, sin(localTime*3.0))*0.9;
			globalTeeth = rampStep*0.99;
			cut = max(0.48, min(0.77, localTime));
			// --------------------------------------------------------------------------------
			float2 distAndMat = float2(0.5, 0.0);
			float t = 0.0;
			//float inc = 0.02;
			float maxDepth = 24.0;
			float3 pos = float3(0, 0, 0);
			marchCount = 0.0;
			// intersect with sphere first as optimization so we don't ray march more than is needed.
			float hit = SphereIntersect(camPos, rayVec, float3(0.0, 0.0, 0.0), 5.6);
			if (hit >= 0.0)
			{
				t = hit;
				// ray marching time
				for (int i = 0; i < 290; i++)	// This is the count of the max times the ray actually marches.
				{
					pos = camPos + rayVec * t;
					// *******************************************************
					// This is _the_ function that defines the "distance field".
					// It's really what makes the scene geometry.
					// *******************************************************
					distAndMat = DistanceToObject(pos);
					// adjust by constant because deformations mess up distance function.
					t += distAndMat.x * 0.7;
					//if (t > maxDepth) break;
					if ((t > maxDepth) || (abs(distAndMat.x) < 0.0025)) break;
					marchCount += 1.0;
				}
			}
			else
			{
				t = maxDepth + 1.0;
				distAndMat.x = 1000000.0;
			}
			// --------------------------------------------------------------------------------
			// Now that we have done our ray marching, let's put some color on this geometry.

			float3 sunDir = normalize(float3(3.93, 10.82, -1.5));
			float3 finalColor = float3(0.0, 0.0, 0.0);

			// If a ray actually hit the object, let's light it.
			//if (abs(distAndMat.x) < 0.75)
			if (t <= maxDepth)
			{
				// calculate the normal from the distance field. The distance field is a volume, so if you
				// sample the current point and neighboring points, you can use the difference to get
				// the normal.
				float3 smallVec = float3(0.005, 0, 0);
				float3 normalU = float3(distAndMat.x - DistanceToObject(pos - smallVec.xyy).x,
					distAndMat.x - DistanceToObject(pos - smallVec.yxy).x,
					distAndMat.x - DistanceToObject(pos - smallVec.yyx).x);

				float3 normal = normalize(normalU);

				// calculate 2 ambient occlusion values. One for global stuff and one
				// for local stuff
				float ambientS = 1.0;
				ambientS *= saturate(DistanceToObject(pos + normal * 0.1).x*10.0);
				ambientS *= saturate(DistanceToObject(pos + normal * 0.2).x*5.0);
				ambientS *= saturate(DistanceToObject(pos + normal * 0.4).x*2.5);
				ambientS *= saturate(DistanceToObject(pos + normal * 0.8).x*1.25);
				float ambient = ambientS * saturate(DistanceToObject(pos + normal * 1.6).x*1.25*0.5);
				ambient *= saturate(DistanceToObject(pos + normal * 3.2).x*1.25*0.25);
				ambient *= saturate(DistanceToObject(pos + normal * 6.4).x*1.25*0.125);
				ambient = max(0.035, pow(ambient, 0.3));	// tone down ambient with a pow and min clamp it.
				ambient = saturate(ambient);

				// calculate the reflection vector for highlights
				float3 ref = reflect(rayVec, normal);
				ref = normalize(ref);

				// Trace a ray for the reflection
				float sunShadow = 1.0;
				float iter = 0.1;
				float3 nudgePos = pos + normal*0.02;	// don't start tracing too close or inside the object
				for (int i = 0; i < 40; i++)
				{
					float tempDist = DistanceToObject(nudgePos + ref * iter).x;
					sunShadow *= saturate(tempDist*50.0);
					if (tempDist <= 0.0) break;
					//iter *= 1.5;	// constant is more reliable than distance-based
					iter += max(0.00, tempDist)*1.0;
					if (iter > 4.2) break;
				}
				sunShadow = saturate(sunShadow);

				// ------ Calculate texture color ------
				float3 texColor;
				texColor = float3(1.0, 1.0, 1.0);// vec3(0.65, 0.5, 0.4)*0.1;
				texColor = float3(0.85, 0.945 - distAndMat.y * 0.15, 0.93 + distAndMat.y * 0.35)*0.951;
				if (distAndMat.y == 6.0) texColor = float3(0.91, 0.1, 0.41)*10.5;
				//texColor *= mix(vec3(0.3), vec3(1.0), tex3d(pos*0.5, normal).xxx);
				texColor = max(texColor, float3(0.0, 0.0, 0.0));
				texColor *= 0.25;

				// ------ Calculate lighting color ------
				// Start with sun color, standard lighting equation, and shadow
				float3 lightColor = float3(0.0, 0.0, 0.0);// sunCol * saturate(dot(sunDir, normal)) * sunShadow*14.0;
											// sky color, hemisphere light equation approximation, ambient occlusion
				lightColor += float3(0.1, 0.35, 0.95) * (normal.y * 0.5 + 0.5) * ambient * 0.2;
				// ground color - another hemisphere light
				lightColor += float3(1.0, 1.0, 1.0) * ((-normal.y) * 0.5 + 0.5) * ambient * 0.2;


				// finally, apply the light to the texture.
				finalColor = texColor * lightColor;
				//if (distAndMat.y == ceil(mod(localTime, 4.0))) finalColor += vec3(0.0, 0.41, 0.72)*0.925;

				// reflection environment map - this is most of the light
				float3 refColor = GetEnvColor2(ref, sunDir)*sunShadow;
				finalColor += refColor * 0.35 * ambient;// * sunCol * sunShadow * 9.0 * texColor.g;

														// fog
				finalColor = lerp(float3(1.0, 0.41, 0.41) + float3(1.0, 1.0, 1.0), finalColor, exp(-t*0.0007));
				// visualize length of gradient of distance field to check distance field correctness
				//finalColor = vec3(0.5) * (length(normalU) / smallVec.x);
			}
			else
			{
				finalColor = GetEnvColor2(rayVec, sunDir);// + vec3(0.1, 0.1, 0.1);
			}
			//finalColor += marchCount * vec3(1.0, 0.3, 0.91) * 0.001;

			// vignette?
			//finalColor *= vec3(1.0) * saturate(1.0 - length(uv/2.5));
			//finalColor *= 1.95;

			// output the final color with sqrt for "gamma correction"
			return float4(sqrt(clamp(finalColor, 0.0, 1.0)), 1.0);
		}
		ENDCG
	}
	}
	FallBack "Diffuse"
}