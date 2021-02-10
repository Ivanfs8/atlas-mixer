shader_type spatial;

uniform sampler2D albedo : hint_albedo;
uniform sampler2D normal_map : hint_normal;

uniform vec2 speed;
uniform float refraction : hint_range(-1, 1, 0.01) = 0.05;
uniform float murk = 1.5;

void fragment()
{
	vec2 base_uv_offset = UV;
	base_uv_offset += TIME * speed;
	
	ALBEDO = texture(albedo, base_uv_offset).rgb * 0.5;
	METALLIC = 0.0;
	ROUGHNESS = 0.1;
	NORMALMAP = texture(normal_map, base_uv_offset).rgb;
	NORMALMAP_DEPTH = 0.2;
	
	if (ALBEDO.r > 0.9 && ALBEDO.g > 0.9 && ALBEDO.b > 0.9) {
		ALPHA = 0.9;
	} else {
		// sample our depth buffer
		float depth = texture(DEPTH_TEXTURE, SCREEN_UV).r;
		
		// grab to values
		//depth = depth * 50.0 - 49.0;
		
		// unproject depth
		depth = depth * 2.0 - 1.0;
		float z = -PROJECTION_MATRIX[3][2] / (depth + PROJECTION_MATRIX[2][2]);
		float delta = -(z - VERTEX.z); // z is negative.
		
		// beers law
		float att = exp(-delta * murk);
		
		ALPHA = clamp(1.0 - att, 0.0, 1.0);
	}
	
	vec3 ref_normal = normalize( mix(NORMAL,TANGENT * NORMALMAP.x + BINORMAL * NORMALMAP.y + NORMAL * NORMALMAP.z,NORMALMAP_DEPTH) );
	vec2 ref_ofs = SCREEN_UV - ref_normal.xy * refraction;
	EMISSION += textureLod(SCREEN_TEXTURE,ref_ofs,ROUGHNESS * 2.0).rgb * (1.0 - ALPHA);
	
	ALBEDO *= ALPHA;
	ALPHA = 1.0;
}