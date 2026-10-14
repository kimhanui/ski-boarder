class_name SkiAssets
extends RefCounted
## 눈(0번) / 바위(1번) 텍스처를 코드로 생성. auto_shader 가 경사에 따라 섞어 줌.
## 한 번 만들면 res://ski/assets/ski_assets.res 에 캐시.

const CACHE_PATH := "res://ski/assets/ski_assets.res"
const TEX_SIZE := 256


## Terrain3D 를 스키 코스용으로 설정 (region 256, 배경 없음, 경사 기반 자동 텍스처).
static func setup_terrain(terrain: Terrain3D) -> void:
	if terrain.region_size != ChunkSpec.SIZE:
		terrain.region_size = ChunkSpec.SIZE
	terrain.vertex_spacing = 1.0
	if terrain.material == null:
		terrain.material = Terrain3DMaterial.new()
	terrain.material.world_background = Terrain3DMaterial.NONE
	terrain.material.auto_shader = true
	terrain.material.set_shader_param("auto_slope", 2.0)
	terrain.material.set_shader_param("blend_sharpness", 0.9)
	if terrain.assets == null or terrain.assets.get_texture_count() < 2:
		terrain.assets = get_or_create()


static func get_or_create() -> Terrain3DAssets:
	if ResourceLoader.exists(CACHE_PATH):
		var cached := load(CACHE_PATH) as Terrain3DAssets
		if cached and cached.get_texture_count() >= 2:
			return cached
	var assets := create()
	if Engine.is_editor_hint():
		DirAccess.make_dir_recursive_absolute(CACHE_PATH.get_base_dir())
		# 텍스처를 개별 파일로 저장해 두면 Terrain3D 의 "not connected to a file" 경고가 사라짐
		for i in 2:
			var ta: Terrain3DTextureAsset = assets.get_texture(i)
			for pair in [["alb", ta.albedo_texture], ["nrm", ta.normal_texture]]:
				var path: String = "%s/%s_%s.res" % [CACHE_PATH.get_base_dir(), ta.name.to_lower(), pair[0]]
				ResourceSaver.save(pair[1], path)
				pair[1].take_over_path(path)
		var err := ResourceSaver.save(assets, CACHE_PATH)
		if err != OK:
			push_warning("SkiAssets: 캐시 저장 실패 (%d)" % err)
	return assets


static func create() -> Terrain3DAssets:
	var assets := Terrain3DAssets.new()
	assets.set_texture(0, _make_texture("Snow", Color(0.80, 0.85, 0.92), Color(1.0, 1.0, 1.0), 0.004, 0.35, 11))
	assets.set_texture(1, _make_texture("Rock", Color(0.22, 0.22, 0.24), Color(0.48, 0.47, 0.46), 0.03, 0.85, 23))
	return assets


static func _make_texture(tex_name: String, dark: Color, light: Color, freq: float, roughness: float, seed_value: int) -> Terrain3DTextureAsset:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = freq * 4.0
	noise.fractal_octaves = 4
	var h_img: Image = noise.get_seamless_image(TEX_SIZE, TEX_SIZE)  # L8
	h_img.convert(Image.FORMAT_RGBA8)

	# Albedo(RGB) + Height(A)
	var alb := Image.create_empty(TEX_SIZE, TEX_SIZE, false, Image.FORMAT_RGBA8)
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var n: float = h_img.get_pixel(x, y).r
			var c: Color = dark.lerp(light, n)
			c.a = n
			alb.set_pixel(x, y, c)
	alb.generate_mipmaps()

	# Normal(RGB) + Roughness(A)
	var nrm: Image = h_img.duplicate()
	nrm.bump_map_to_normal_map(2.0)
	nrm.convert(Image.FORMAT_RGBA8)
	for y in TEX_SIZE:
		for x in TEX_SIZE:
			var c: Color = nrm.get_pixel(x, y)
			c.a = roughness
			nrm.set_pixel(x, y, c)
	nrm.generate_mipmaps()

	var ta := Terrain3DTextureAsset.new()
	ta.name = tex_name
	ta.albedo_texture = ImageTexture.create_from_image(alb)
	ta.normal_texture = ImageTexture.create_from_image(nrm)
	ta.uv_scale = 0.1
	return ta
