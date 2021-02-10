shader_type spatial;

uniform float tiles : hint_range(1, 64, 1);
uniform float rng;

render_mode blend_mix,depth_draw_always,cull_disabled,diffuse_burley,specular_schlick_ggx,world_vertex_coords;
uniform vec4 albedo : hint_color;
uniform sampler2D texture_albedo : hint_albedo;
uniform float specular;
uniform float metallic;
uniform float roughness : hint_range(0,1);
uniform sampler2D texture_roughness : hint_white;
uniform vec4 roughness_texture_channel;
uniform sampler2D texture_refraction;
uniform float refraction : hint_range(-16,16);
uniform vec4 refraction_texture_channel;
uniform sampler2D texture_normal : hint_normal;
uniform float normal_scale : hint_range(-16,16) = 1.;
uniform float subsurface_scattering_strength : hint_range(0,1) = 1.;
uniform sampler2D texture_subsurface_scattering : hint_white;
varying vec3 uv1_triplanar_pos;
uniform float uv1_blend_sharpness = 1.;
varying vec3 uv1_power_normal;
uniform vec3 uv1_scale = vec3(1.);
uniform vec3 uv1_offset;
uniform vec3 uv2_scale = vec3(1.);
uniform vec3 uv2_offset;

//uniform sampler2D albedo : hint_albedo;

float rand_range(vec2 Seed, float Min, float Max)
{
    float randomno =  fract(sin(dot(Seed, vec2(12.9898, 78.233)))*43758.5453);
    return mix(Min, Max, randomno);
}

vec2 rand_tiled_uv(vec2 uv)
{
	float texture_size = float(textureSize(texture_albedo, 0).x);
	float tile_size = texture_size / tiles;
	
	vec2 mul_uv = uv * tiles;
	
	vec2 div_uv = fract(mul_uv);
	vec2 seed = floor(mul_uv);
	
	//float time = floor(TIME * 2.0) * 5.;
	
	float x = rand_range(seed + rng, 0, tiles);
	float y = rand_range(seed + rng + 1.0 , 0, tiles);
	vec2 rand_uv = floor(vec2(x, y));
	
	return (div_uv + rand_uv) * (tile_size / texture_size);
} 

vec4 triplanar_texture(sampler2D p_sampler,vec3 p_weights,vec3 p_triplanar_pos) {
	vec4 samp=vec4(0.0);
	samp+= texture(p_sampler,rand_tiled_uv(p_triplanar_pos.xy)) * p_weights.z;
	samp+= texture(p_sampler,rand_tiled_uv(p_triplanar_pos.xz)) * p_weights.y;
	samp+= texture(p_sampler,rand_tiled_uv(p_triplanar_pos.zy) * vec2(-1.0,1.0)) * p_weights.x;
	return samp;
}

void vertex() 
{
	TANGENT = vec3(0.0,0.0,-1.0) * abs(NORMAL.x);
	TANGENT+= vec3(1.0,0.0,0.0) * abs(NORMAL.y);
	TANGENT+= vec3(1.0,0.0,0.0) * abs(NORMAL.z);
	TANGENT = normalize(TANGENT);
	BINORMAL = vec3(0.0,-1.0,0.0) * abs(NORMAL.x);
	BINORMAL+= vec3(0.0,0.0,1.0) * abs(NORMAL.y);
	BINORMAL+= vec3(0.0,-1.0,0.0) * abs(NORMAL.z);
	BINORMAL = normalize(BINORMAL);
	uv1_power_normal=pow(abs(NORMAL),vec3(uv1_blend_sharpness));
	uv1_power_normal/=dot(uv1_power_normal,vec3(1.0));
	uv1_triplanar_pos = VERTEX * uv1_scale + uv1_offset;
	uv1_triplanar_pos *= vec3(1.0,-1.0, 1.0);
}

void fragment()
{
	//vec2 final_uv = rand_tiled_uv(UV);
	//vec3 final_texture = texture(texture_albedo, final_uv).rgb;
	
	vec4 albedo_tex = triplanar_texture(texture_albedo, uv1_power_normal, uv1_triplanar_pos);
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	METALLIC = metallic;
	float roughness_tex = dot(triplanar_texture(texture_roughness,uv1_power_normal,uv1_triplanar_pos),roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	SPECULAR = specular;
	NORMALMAP = triplanar_texture(texture_normal,uv1_power_normal,uv1_triplanar_pos).rgb;
	NORMALMAP_DEPTH = normal_scale;
	vec3 ref_normal = normalize( mix(NORMAL,TANGENT * NORMALMAP.x + BINORMAL * NORMALMAP.y + NORMAL * NORMALMAP.z,NORMALMAP_DEPTH) );
	vec2 ref_ofs = SCREEN_UV - ref_normal.xy * dot(triplanar_texture(texture_refraction,uv1_power_normal,uv1_triplanar_pos),refraction_texture_channel) * refraction;
	float ref_amount = 1.0 - albedo.a * albedo_tex.a;
	EMISSION += textureLod(SCREEN_TEXTURE,ref_ofs,ROUGHNESS * 8.0).rgb * ref_amount;
	ALBEDO *= 1.0 - ref_amount;
	ALPHA = 1.0;
	float sss_tex = triplanar_texture(texture_subsurface_scattering,uv1_power_normal,uv1_triplanar_pos).r;
	SSS_STRENGTH=subsurface_scattering_strength*sss_tex;
}