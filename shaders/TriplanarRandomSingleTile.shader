shader_type spatial;

render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx;

const highp float PI = 3.14159265358979323846;

uniform float tiles : hint_range(1, 64, 1);
uniform float rng;
uniform bool rotate;
uniform float rotation_d = 90.;

uniform vec4 albedo : hint_color = vec4(1.);
uniform sampler2D texture_albedo : hint_albedo;
uniform float specular = .5;
uniform float metallic = 0.;
uniform float roughness : hint_range(0,1) = 1.;
uniform sampler2D texture_roughness : hint_white;
uniform vec4 roughness_texture_channel = vec4(0.,1.,0.,0.);
uniform sampler2D texture_normal : hint_normal;
uniform float normal_scale : hint_range(-16,16) = 1.;
varying vec3 uv1_triplanar_pos;
uniform float uv1_blend_sharpness = 1.;
varying vec3 uv1_power_normal;
uniform vec3 uv1_scale = vec3(1.);
uniform vec3 uv1_offset = vec3(0.);
uniform vec3 uv2_scale = vec3(1.);
uniform vec3 uv2_offset = vec3(0.);

float rand_range(vec2 Seed, float Min, float Max)
{
    float randomno =  fract(sin(dot(Seed, vec2(12.9898, 78.233)))*43758.5453);
    return mix(Min, Max, randomno);
}

vec2 rotateUV(in vec2 uv, in vec2 pivot, in float rotation)
{
	float texture_size = float(textureSize(texture_albedo, 0).x);
	float tile_size = texture_size / tiles;
	
	rotation = radians(rotation);
	
	float cosa = cos(rotation);
	float sina = sin(rotation);
	
	mat2 rot_m = mat2(vec2(cosa, sina), vec2(-sina, cosa));
	
	uv -= floor(uv);
	uv -= pivot;
	uv *= rot_m;
	uv += pivot;
	
	return uv;
}

vec2 rand_tiled_uv(in vec2 uv)
{
	vec2 seed = floor(uv);
	
	vec2 r_uv;
	if (rotate)
	{
		r_uv = rotateUV( uv, vec2(0.5), rotation_d * floor( rand_range(seed + rng, 0,4) ));
	}
	else
	{
		r_uv = uv;
	}
	
	lowp float x = rand_range(seed + rng, 0, tiles);
	lowp float y = rand_range(seed + rng + 1., 0, tiles);
	vec2 rand_offset = vec2(1.) - ( vec2(1. / tiles) * ceil(vec2(x,y)) );
	
	
	return (uv / tiles) + rand_offset;
}

vec4 am_texture(sampler2D sample, in vec2 uv, in vec2 scale)
{
	vec2 dx = dFdx(uv / scale / tiles), dy = dFdy(uv / scale / tiles);
	
	//CALL_FUNCTIONS
	uv = rand_tiled_uv(uv);
	if (rotate)
	{
		uv = rotateUV( uv, vec2(0.5), rotation_d * floor( rand_range(floor(uv) + rng, 0,4) ));
	}
	
	return textureGrad(sample, uv, dx, dy);
}

void vertex() {
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

vec4 triplanar_texture(sampler2D p_sampler,vec3 p_weights,vec3 p_triplanar_pos) 
{
	vec4 samp=vec4(0.0);
	samp+= am_texture( p_sampler, p_triplanar_pos.xy, uv1_scale.xy ) * p_weights.z;
	samp+= am_texture( p_sampler, p_triplanar_pos.xz, uv1_scale.xz ) * p_weights.y;
	samp+= am_texture( p_sampler, p_triplanar_pos.zy * vec2(-1.0,1.0), uv1_scale.yz ) * p_weights.x;
	
	return samp;
}

void fragment() 
{
	vec4 albedo_tex = triplanar_texture(texture_albedo,uv1_power_normal,uv1_triplanar_pos);
	
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	METALLIC = metallic;
	float roughness_tex = dot(triplanar_texture(texture_roughness,uv1_power_normal,uv1_triplanar_pos), roughness_texture_channel);
	ROUGHNESS = roughness_tex * roughness;
	SPECULAR = specular;
	NORMALMAP = triplanar_texture(texture_normal,uv1_power_normal,uv1_triplanar_pos).rgb;
	NORMALMAP_DEPTH = normal_scale;
}
