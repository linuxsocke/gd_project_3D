shader_type spatial;

// This is the reference shader of the plugin, and has the most features.
// it should be preferred for high-end graphics cards.
// For less features but lower-end targets, see the lite version.

uniform sampler2D u_terrain_heightmap;
uniform sampler2D u_terrain_normalmap;
uniform sampler2D u_terrain_colormap : hint_albedo;
uniform sampler2D u_terrain_splatmap;
uniform sampler2D u_terrain_splatmap_1;
uniform sampler2D u_terrain_globalmap : hint_albedo;
uniform mat4 u_terrain_inverse_transform;
uniform mat3 u_terrain_normal_basis;

// the reason bump is preferred with albedo is, roughness looks better with normal maps.
// If we want no normal mapping, roughness would only give flat mirror surfaces,
// while bump still allows to do depth-blending for free.
// ground
uniform sampler2D u_ground_albedo_bump_0 : hint_albedo;
uniform sampler2D u_ground_albedo_bump_1 : hint_albedo;
uniform sampler2D u_ground_albedo_bump_2 : hint_albedo;
uniform sampler2D u_ground_albedo_bump_3 : hint_albedo;
// vegetation
uniform sampler2D u_ground_albedo_bump_4 : hint_albedo;
uniform sampler2D u_ground_albedo_bump_5 : hint_albedo;
uniform sampler2D u_ground_albedo_bump_6 : hint_albedo;
uniform sampler2D u_ground_albedo_bump_7 : hint_albedo;

// ground
uniform sampler2D u_ground_normal_roughness_0;
uniform sampler2D u_ground_normal_roughness_1;
uniform sampler2D u_ground_normal_roughness_2;
uniform sampler2D u_ground_normal_roughness_3;
// vegetation
uniform sampler2D u_ground_normal_roughness_4;
uniform sampler2D u_ground_normal_roughness_5;
uniform sampler2D u_ground_normal_roughness_6;
uniform sampler2D u_ground_normal_roughness_7;

uniform float u_ground_uv_scale = 20.0;
uniform bool u_depth_blending = true;
uniform bool u_triplanar = false;

uniform float u_globalmap_blend_start;
uniform float u_globalmap_blend_distance;

varying vec4 v_tint;
varying vec4 v_splat_0;
varying vec4 v_splat_1;
varying vec3 v_ground_uv;
varying float v_distance;


vec3 unpack_normal(vec4 rgba) {
	return rgba.xzy * 2.0 - vec3(1.0);
}


vec3 get_triplanar_blend(vec3 world_normal) {
	vec3 blending = abs(world_normal);
	blending = normalize(max(blending, vec3(0.00001))); // Force weights to sum to 1.0
	float b = blending.x + blending.y + blending.z;
	return blending / vec3(b, b, b);
}

vec4 texture_triplanar(sampler2D tex, vec3 world_pos, vec3 blend) {
	vec4 xaxis = texture(tex, world_pos.yz);
	vec4 yaxis = texture(tex, world_pos.xz);
	vec4 zaxis = texture(tex, world_pos.xy);
	// blend the results of the 3 planar projections.
	return xaxis * blend.x + yaxis * blend.y + zaxis * blend.z;
}

void vertex() {
	vec4 wpos = WORLD_MATRIX * vec4(VERTEX, 1);
	vec2 cell_coords = (u_terrain_inverse_transform * wpos).xz;

	// Normalized UV
	UV = cell_coords / vec2(textureSize(u_terrain_heightmap, 0));

	// Height displacement
	float h = texture(u_terrain_heightmap, UV).r;
	VERTEX.y = h;
	wpos.y = h;

	v_ground_uv = vec3(cell_coords.x, h * WORLD_MATRIX[1][1], cell_coords.y) / u_ground_uv_scale;

	// Putting this in vertex saves 2 fetches from the fragment shader,
	// which is good for performance at a negligible quality cost,
	// provided that geometry is a regular grid that decimates with LOD.
	// (downside is LOD will also decimate tint and splat, but it's not bad overall)
	v_tint = texture(u_terrain_colormap, UV);
	v_splat_0 = texture(u_terrain_splatmap, UV);
	v_splat_1 = texture(u_terrain_splatmap_1, UV);

	// Need to use u_terrain_normal_basis to handle scaling.
	// For some reason I also had to invert Z when sampling terrain normals... not sure why
	NORMAL = u_terrain_normal_basis * (unpack_normal(texture(u_terrain_normalmap, UV)) * vec3(1,1,-1));

	// Distance to camera
	v_distance = distance(wpos.xyz, CAMERA_MATRIX[3].xyz);
}

void fragment() {

	if(v_tint.a < 0.5)
		// TODO Add option to use vertex discarding instead, using NaNs
		discard;

	vec3 terrain_normal_world = u_terrain_normal_basis * (unpack_normal(texture(u_terrain_normalmap, UV)) * vec3(1,1,-1));
	terrain_normal_world = normalize(terrain_normal_world);
	vec3 normal = terrain_normal_world;

	float globalmap_factor = clamp((v_distance - u_globalmap_blend_start) * u_globalmap_blend_distance, 0.0, 1.0);
	globalmap_factor *= globalmap_factor; // slower start, faster transition but far away
	vec3 global_albedo = texture(u_ground_albedo_bump_0, UV).rgb;
	ALBEDO = global_albedo;

	// Doing this branch allows to spare a bunch of texture fetches for distant pixels.
	// Eventually, there could be a split between near and far shaders in the future, if relevant on high-end GPUs
	if (globalmap_factor < 1.0) {

		vec2 ground_uv = v_ground_uv.xz;

		vec4 ab3;
		vec4 nr3;
		if (u_triplanar) {
			// Only do triplanar on one texture slot,
			// because otherwise it would be very expensive and cost many more ifs.
			// I chose the last slot because first slot is the default on new splatmaps,
			// and that's a feature used for cliffs, which are usually designed later.

			vec3 blending = get_triplanar_blend(terrain_normal_world);

			ab3 = texture_triplanar(u_ground_albedo_bump_3, v_ground_uv, blending);
			nr3 = texture_triplanar(u_ground_normal_roughness_3, v_ground_uv, blending);

		} else {
			ab3 = texture(u_ground_albedo_bump_3, ground_uv);
			nr3 = texture(u_ground_normal_roughness_3, ground_uv);
		}

		vec4 ab0 = texture(u_ground_albedo_bump_0, ground_uv);
		vec4 ab1 = texture(u_ground_albedo_bump_1, ground_uv);
		vec4 ab2 = texture(u_ground_albedo_bump_2, ground_uv);
		vec4 ab4 = texture(u_ground_albedo_bump_4, ground_uv);
		vec4 ab5 = texture(u_ground_albedo_bump_5, ground_uv);
		vec4 ab6 = texture(u_ground_albedo_bump_6, ground_uv);
		vec4 ab7 = texture(u_ground_albedo_bump_7, ground_uv);

		vec4 nr0 = texture(u_ground_normal_roughness_0, ground_uv);
		vec4 nr1 = texture(u_ground_normal_roughness_1, ground_uv);
		vec4 nr2 = texture(u_ground_normal_roughness_2, ground_uv);
		vec4 nr4 = texture(u_ground_normal_roughness_4, ground_uv);
		vec4 nr5 = texture(u_ground_normal_roughness_5, ground_uv);
		vec4 nr6 = texture(u_ground_normal_roughness_6, ground_uv);
		vec4 nr7 = texture(u_ground_normal_roughness_7, ground_uv);

		vec3 col0 = ab0.rgb;
		vec3 col1 = ab1.rgb;
		vec3 col2 = ab2.rgb;
		vec3 col3 = ab3.rgb;
		vec3 col4 = ab4.rgb;
		vec3 col5 = ab5.rgb;
		vec3 col6 = ab6.rgb;
		vec3 col7 = ab7.rgb;

		vec4 rough_0 = vec4(nr0.a, nr1.a, nr2.a, nr3.a);
		vec4 rough_1 = vec4(nr4.a, nr5.a, nr6.a, nr7.a);

		vec3 normal0 = unpack_normal(nr0);
		vec3 normal1 = unpack_normal(nr1);
		vec3 normal2 = unpack_normal(nr2);
		vec3 normal3 = unpack_normal(nr3);
		vec3 normal4 = unpack_normal(nr4);
		vec3 normal5 = unpack_normal(nr5);
		vec3 normal6 = unpack_normal(nr6);
		vec3 normal7 = unpack_normal(nr7);

		vec4 w_0;
		vec4 w_1;
		// TODO An #ifdef macro would be nice! Or copy/paste everything in a different shader...
		if (u_depth_blending) {

			vec4 bumps_0 = vec4(ab0.a, ab1.a, ab2.a, ab3.a);
			vec4 bumps_1 = vec4(ab4.a, ab5.a, ab6.a, ab7.a);

			vec4 h_0 = bumps_0 + v_splat_0;
			vec4 h_1 = bumps_1 + v_splat_1;

			h_0 *= smoothstep(0, 0.05, v_splat_0);
			h_1 *= smoothstep(0, 0.05, v_splat_1);

			float dh = 0.2;
			w_0 = h_0 + dh;
			w_1 = h_1 + dh;

			float h_max_0 = max(h_0.r, max(h_0.g, max(h_0.b, h_0.a)));
			float h_max_1 = max(w_1.r, max(w_1.g, max(w_1.b, w_1.a)));
			
			w_0.r -= max(h_0.g, max(h_0.b, max(h_0.a, h_max_1)));
			w_0.g -= max(h_0.r, max(h_0.b, max(h_0.a, h_max_1)));
			w_0.b -= max(h_0.g, max(h_0.r, max(h_0.a, h_max_1)));
			w_0.a -= max(h_0.g, max(h_0.b, max(h_0.r, h_max_1)));
			w_1.r -= max(h_1.g, max(h_1.b, max(h_1.a, h_max_0)));
			w_1.g -= max(h_1.r, max(h_1.b, max(h_1.a, h_max_0)));
			w_1.b -= max(h_1.g, max(h_1.r, max(h_1.a, h_max_0)));
			w_1.a -= max(h_1.g, max(h_1.b, max(h_1.r, h_max_0)));

			w_0 = clamp(w_0, 0, 1);
			w_1 = clamp(w_1, 0, 1);
		} else {
			w_0 = v_splat_0.rgba;
			w_1 = v_splat_1.rgba; 
		}

		float w_sum = (w_0.r + w_0.g + w_0.b + w_0.a + w_1.r + w_1.g + w_1.b + w_1.a);

		ALBEDO = v_tint.rgb * (
			w_0.r * col0.rgb +
			w_0.g * col1.rgb +
			w_0.b * col2.rgb +
			w_0.a * col3.rgb +
			w_1.r * col4.rgb +
			w_1.g * col5.rgb +
			w_1.b * col6.rgb +
			w_1.a * col7.rgb) / w_sum;

		ROUGHNESS = (
			w_0.r * rough_0.r +
			w_0.g * rough_0.g +
			w_0.b * rough_0.b +
			w_0.a * rough_0.a +
			w_1.r * rough_1.r +
			w_1.g * rough_1.g +
			w_1.b * rough_1.b +
			w_1.a * rough_1.a) / w_sum;

		vec3 ground_normal = /*u_terrain_normal_basis **/ (
			w_0.r * normal0 +
			w_0.g * normal1 +
			w_0.b * normal2 +
			w_0.a * normal3 +
			w_1.r * normal4 +
			w_1.g * normal5 +
			w_1.b * normal6 +
			w_1.a * normal7) / w_sum;
		// If no splat textures are defined, normal vectors will default to (1,1,1), which is incorrect,
		// and causes the terrain to be shaded wrongly in some directions.
		// However, this should not be a problem to fix in the shader, because there MUST be at least one splat texture set.
		//ground_normal = normalize(ground_normal);
		// TODO Make the plugin insert a default normalmap if it's empty

		// Combine terrain normals with detail normals (not sure if correct but looks ok)
		normal = normalize(vec3(
			terrain_normal_world.x + ground_normal.x,
			terrain_normal_world.y,
			terrain_normal_world.z + ground_normal.z));

		normal = mix(normal, terrain_normal_world, globalmap_factor);

		ALBEDO = mix(ALBEDO, global_albedo, globalmap_factor);
		ROUGHNESS = mix(ROUGHNESS, 1.0, globalmap_factor);

		// Calculate Ambient Occlusion


		// Show splatmap weights
		//ALBEDO = w.rgb;
	}
	// Highlight all pixels undergoing no splatmap at all
//	else {
//		ALBEDO = vec3(1.0, 0.0, 0.0);
//	}

	NORMAL = (INV_CAMERA_MATRIX * (vec4(normal, 0.0))).xyz;
}
