shader_type spatial;

uniform float tiles : hint_range(1, 64, 1);
uniform float rng;

uniform sampler2D albedo : hint_albedo;

float rand_range(vec2 Seed, float Min, float Max)
{
    float randomno =  fract(sin(dot(Seed, vec2(12.9898, 78.233)))*43758.5453);
    return mix(Min, Max, randomno);
}

vec2 rand_tiled_uv(vec2 uv)
{
	float texture_size = float(textureSize(albedo, 0).x);
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

void fragment()
{
	vec2 final_uv = rand_tiled_uv(UV);
	
	//triplanar
	vec3 camXvertex = vec4(CAMERA_MATRIX * vec4(VERTEX, 0)).xyz;
	
	
	ALBEDO = texture(albedo, final_uv).rgb;
	//ALBEDO = vec3(final_uv, 0);
}