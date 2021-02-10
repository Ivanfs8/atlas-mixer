tool
extends SpatialMaterial
class_name AtlasMixerMaterial

export (float, 1, 64, 1) var tiles: float = 1 setget set_tiles
func set_tiles(value: float):
	if VisualServer.material_get_param(get_rid(), "tiles") != null:
		VisualServer.material_set_param(get_rid(), "tiles", value)
	
	if (value < 2 || (value > 1 && tiles == 1)) && bake_shader:
		connect_update()
		emit_signal("changed")
	
	tiles = value

export var rng: float = 0.0 setget set_rng
func set_rng(value: float):
	rng = value
	if VisualServer.material_get_param(get_rid(), "rng") != null:
		VisualServer.material_set_param(get_rid(), "rng", rng)
export var rotate: bool = false setget set_rotate
func set_rotate(value):
	rotate = value
	if bake_shader: 
		connect_update()
		emit_signal("changed")
	
export (float, -359, 359, 0.01) var rotation_amount: float = 90
func set_rotation(value: float):
	rotation_amount = value
	if VisualServer.material_get_param(get_rid(), "rotation_d") != null:
		VisualServer.material_set_param(get_rid(), "rotation_d", rotation_amount)

export var bake_shader: bool = false setget set_make
func set_make(value: bool):
	bake_shader = value
	if value: 
		make_shader()
		connect_update()
	else: disconnect_update()

const DEFAULT_SPATIAL_CODE := """
shader_type spatial;
render_mode blend_mix,depth_draw_opaque,cull_back,diffuse_burley,specular_schlick_ggx;
uniform vec4 albedo : hint_color;
uniform sampler2D texture_albedo : hint_albedo;
uniform float specular;
uniform float metallic;
uniform float roughness : hint_range(0,1);
uniform float point_size : hint_range(0,128);
uniform vec3 uv1_scale;
uniform vec3 uv1_offset;
uniform vec3 uv2_scale;
uniform vec3 uv2_offset;

void vertex() {
	UV=UV*uv1_scale.xy+uv1_offset.xy;
}

void fragment() {
	vec2 base_uv = UV;
	vec4 albedo_tex = texture(texture_albedo,base_uv);
	ALBEDO = albedo.rgb * albedo_tex.rgb;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = specular;
}
"""

const SHADER_PARAM: String = """
//PARAM
uniform float tiles : hint_range(1, 64, 1);
uniform float rng;
uniform float rotation_d = 90.;
"""

const RANDOM_RANGE: String = """
//RANDOM_RANGE
float rand_range(vec2 Seed, float Min, float Max)
{
	float randomno =  fract(sin(dot(Seed, vec2(12.9898, 78.233)))*43758.5453);
	return mix(Min, Max, randomno);
}
"""

const ROTATE_UV: String = """
//ROTATE_UV
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
"""

const RANDOM_TILED: String = """
//RANDOM_TILED
vec2 rand_tiled_uv(in vec2 uv)
{
	vec2 seed = floor(uv);
	
	lowp float x = rand_range(seed + rng, 0f, tiles);
	lowp float y = rand_range(seed + rng + 1., 0f, tiles);
	vec2 rand_offset = vec2(1.) - ( vec2(1. / tiles) * ceil(vec2(x,y)) );
	
	return (uv / tiles) + rand_offset;
}
"""

const TEXTURE_FUNC: String = """
vec4 am_tex(sampler2D sample, in vec2 uv, in vec2 scale)
{
	vec2 dx = dFdx(uv / scale / tiles), dy = dFdy(uv / scale / tiles);
	
	//CALL_FUNCTIONS
	//RAND_TILED
	//ROTATE_UV
	
	return textureGrad(sample, uv, dx, dy);
}
"""

func _init():
	if bake_shader:
		update_shader()
		connect_update()
	else:
		disconnect_update()

func _set(_property, _value):
	_property = _value
	if bake_shader: 
		connect_update()
		emit_signal("changed")

func update_shader(): 
	if bake_shader:
		yield(VisualServer, "frame_post_draw")
		make_shader()

func connect_update():
	if !bake_shader: return
	if !is_connected("changed", self, "update_shader"):
		var err := connect("changed", self, "update_shader")
		if err != OK: print(err)

func disconnect_update():
	for sig in get_signal_connection_list("changed"):
		disconnect(sig["signal"], sig["target"], sig["method"])

func make_shader():
	var code := VisualServer.shader_get_code(
			VisualServer.material_get_shader(get_rid())
	)
	
	if code.empty(): code = DEFAULT_SPATIAL_CODE
	
	#ADD the shader parameters
	if code.find("PARAM") == -1:
		var shader_type_line_end := code.find(";")
		if shader_type_line_end == -1:
			return ""
		code = code.insert(shader_type_line_end + 1, SHADER_PARAM)
	
	#FIND the ideal line for FUNCTIONS
	var function_line: int = code.find("FUNCTIONS")
	var func_found: bool = function_line != -1
	function_line += 9 if func_found else 0
	if !func_found: function_line = code.find("void vertex") - 2
	
	#ALL custom functions to be stored 
	var functions: String = "//FUNCTIONS\n" if !func_found else ""
	
	if code.find("RANDOM_RANGE") == -1:
		functions += RANDOM_RANGE

	if code.find("RANDOM_TILED") == -1:
		functions += RANDOM_TILED
		
	if rotate && code.find("ROTATE_UV") == -1:
		functions += ROTATE_UV
	
	#CONFIGURE the am_tex functions
	#Get the clean and cons function
	var new_tex_func: String = TEXTURE_FUNC
	
	#ADD the proper functions to apply on uv in am_tex
	if tiles > 1:
		new_tex_func = new_tex_func.replace("//RAND_TILED", "uv = rand_tiled_uv(uv);")
	if rotate:
		new_tex_func = new_tex_func.replace("//ROTATE_UV", "uv = rotateUV( uv, vec2(0.5), rotation_d * floor( rand_range(floor(uv) + rng, 0,4) ));")
	
	#ADD or REPLACE the am_tex function
	var tex_func_line: int = code.find("vec4 am_tex")
	if tex_func_line != -1: #will be REPLACED
		#tex_func_line = code.find("vec4 am_tex", tex_func_line)
		var tex_func_line_end: int = code.find("}", tex_func_line) + 1
		var length: int = tex_func_line_end - tex_func_line
		var tex_func: String = code.substr(tex_func_line, length)
		
		code = code.replace(tex_func, new_tex_func)
	else:
		functions += new_tex_func
		
	#ADD ALL necesary functions to the shader 
	
	code = code.insert(function_line, functions)
	
	#REPLACE the triplanar_texture function to use am_tex
	if uv1_triplanar:
		var triplanar_func_line: int = code.find("triplanar_texture") + 18
		var triplanar_func_line_end: int = code.find("}", triplanar_func_line) + 1
		var length: int = triplanar_func_line_end - triplanar_func_line
		
		var triplanar_func: String = code.substr(triplanar_func_line, length)
		if triplanar_func.find("am_tex") == -1:
			var new_triplanar_func: String = triplanar_func.replace("texture", "am_tex")
			
			var line_1: int = new_triplanar_func.find("pos.xy") + 6
			new_triplanar_func = new_triplanar_func.insert(line_1, ", uv1_scale.xy")
			
			var line_2: int = new_triplanar_func.find("pos.xz") + 6
			new_triplanar_func = new_triplanar_func.insert(line_2, ", uv1_scale.xz")
			
			var line_3: int = new_triplanar_func.find("pos.zy * vec2(-1.0,1.0)") + 23
			new_triplanar_func = new_triplanar_func.insert(line_3, ", uv1_scale.zy")
			
			code = code.replace(triplanar_func, new_triplanar_func)
	
	#CONFIGURE the fragment to use am_tex (if not triplanar)
	if !uv1_triplanar:
		var fragment_func_line: int = code.find("void fragment()")
		var fragment_func_line_end: int = code.find_last("}") + 1
		var frag_len: int = fragment_func_line_end - fragment_func_line
		var fragment_func: String = code.substr(fragment_func_line, frag_len)
		
		var new_frag_func: String = fragment_func.replace("texture(", "am_tex(")
		new_frag_func = new_frag_func.replace("base_uv)", "base_uv, uv1_scale.xz)")
		code = code.replace(fragment_func, new_frag_func)
	
	#print("code: \n", code)
	VisualServer.shader_set_code(VisualServer.material_get_shader(get_rid()), code)
	
	#SET parameters
	VisualServer.material_set_param(get_rid(), "tiles", tiles)
	VisualServer.material_set_param(get_rid(), "rng", rng)
	VisualServer.material_set_param(get_rid(), "rotation_d", rotation_amount)
	
	print("shader baked")
