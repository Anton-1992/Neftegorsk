## TextureRegistry.gd
## Loads PNG textures from supplementary textures.pck at runtime.
## Uses FileAccess + Image.load_png_from_buffer() to bypass Godot's broken
## import pipeline (headless CI can't import textures — no GPU for VRAM compression).
##
## textures.pck contains raw PNG source files, included in main PCK via include_filter.
## ProjectSettings.load_resource_pack() makes PNG paths accessible via FileAccess.
## Then we read PNG bytes and decode with Image.load_png_from_buffer().
##
## Usage: TextureRegistry.instance.get_texture("res://assets/ui/map_background.png")

extends Node

static var instance = null

var textures: Dictionary = {}  # res_path -> Texture2D
var pck_loaded: bool = false
var load_errors: String = ""
var textures_loaded_count: int = 0

func _ready() -> void:
	instance = self
	# Only load the PCK here — textures are loaded lazily via get_texture()
	_load_textures_pck()

func _load_textures_pck() -> bool:
	# Try loading supplementary PCK (contains raw PNG files)
	# replace=true: supplementary PCK entries override main PCK (critical!)
	
	# Method 1: Load from res:// (inside main PCK via include_filter)
	if FileAccess.file_exists("res://textures.pck"):
		pck_loaded = ProjectSettings.load_resource_pack("res://textures.pck", true)
		if pck_loaded:
			return true
		# If direct loading failed, extract to user:// first (res:// may be read-only)
		var src = FileAccess.open("res://textures.pck", FileAccess.READ)
		if src != null:
			var file_size = src.get_length()
			var buffer = src.get_buffer(file_size)
			src.close()
			var dst = FileAccess.open("user://textures.pck", FileAccess.WRITE)
			if dst != null:
				dst.store_buffer(buffer)
				dst.close()
				pck_loaded = ProjectSettings.load_resource_pack("user://textures.pck", true)
				if pck_loaded:
					return true
	
	# Method 2: Load from user:// (already extracted previously)
	if FileAccess.file_exists("user://textures.pck"):
		pck_loaded = ProjectSettings.load_resource_pack("user://textures.pck", true)
		return pck_loaded
	
	return false

func get_texture(path: String) -> Texture2D:
	# Return cached texture if already loaded
	if textures.has(path):
		return textures[path]
	
	# Try loading the texture
	var tex = _load_texture_from_png(path)
	if tex != null:
		textures[path] = tex
		textures_loaded_count += 1
	return tex

func _load_texture_from_png(path: String) -> Texture2D:
	# Method 1: Try FileAccess + Image.load_png_from_buffer() (most robust)
	# This bypasses Godot's import/resource system entirely
	if FileAccess.file_exists(path):
		var f = FileAccess.open(path, FileAccess.READ)
		if f != null:
			var buffer = f.get_buffer(f.get_length())
			f.close()
			if buffer.size() > 0:
				var img = Image.new()
				var err = img.load_png_from_buffer(buffer)
				if err == OK and img.get_width() > 0:
					var tex = ImageTexture.create_from_image(img)
					if tex != null:
						return tex
				else:
					load_errors += path + ":PNG_DECODE_ERR=" + str(err) + "\n"
			else:
				load_errors += path + ":EMPTY\n"
		else:
			load_errors += path + ":FA_FAIL\n"
	
	# Method 2: Try Image.load() directly (alternative path resolution)
	var img2 = Image.new()
	var err2 = img2.load(path)
	if err2 == OK and img2.get_width() > 0:
		var tex2 = ImageTexture.create_from_image(img2)
		if tex2 != null:
			return tex2
	
	load_errors += path + ":ALL_FAIL\n"
	return null

func preload_all_textures() -> void:
	## 
	var paths = [
		"res://assets/ui/map_background.png",
		"res://assets/ui/district_bg.png",
		"res://assets/ui/road_texture.png",
		"res://assets/ui/station_icon.png",
		"res://assets/ui/station_standard.png",
		"res://assets/ui/station_premium.png",
		"res://assets/ui/station_ev.png",
		"res://assets/ui/station_shark.png",
		"res://assets/ui/station_miser.png",
		"res://assets/ui/station_local.png",
		"res://assets/ui/station_green.png",
		"res://assets/ui/station_tycoon.png",
		"res://assets/ui/station_opportunist.png",
		"res://assets/icons/app_icon.png",
		"res://assets/icons/portrait_green.png",
		"res://assets/icons/portrait_local.png",
		"res://assets/icons/portrait_miser.png",
		"res://assets/icons/portrait_opportunist.png",
		"res://assets/icons/portrait_shark.png",
		"res://assets/icons/portrait_tycoon.png",
		"res://assets/maps/tileset_ground.png",
		"res://assets/maps/tileset_roads.png",
		"res://assets/maps/tileset_water.png",
		"res://assets/maps/tileset_park.png",
		"res://assets/maps/tileset_buildings.png",
	]
	for path in paths:
		get_texture(path)
