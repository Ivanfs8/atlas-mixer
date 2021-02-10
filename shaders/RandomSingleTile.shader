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
	vec2 seed = floor(uv);
	
	float x = 1. - ( 1. / ceil( rand_range(seed + rng, 0, tiles) ) );
	float y = rand_range(seed + rng + 1., 0, tiles);
	vec2 rand_offset = vec2(1.) - ( vec2(1. / tiles) * ceil(vec2(x,y)) );
	
	
	return (uv / tiles) + rand_offset;
} 

void fragment()
{
	vec2 final_uv = rand_tiled_uv(UV);
	
	ALBEDO = texture(albedo, final_uv).rgb;
	//ALBEDO = vec3(final_uv, 0);
}