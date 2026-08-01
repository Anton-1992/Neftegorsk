## MapView — v0.1.44: isometric map renderer using Control._draw() + Label nodes
## v0.1.44: ALL dict access uses bracket notation — dict["key"] NOT dict.key
extends Control

var tiles = []
var car_data = []
var labels = []
var TW = 64
var TH = 32
var font = null
var _label_nodes = []

func _draw():
	for tile in tiles:
		var bh = tile.get("bh", 0)
		var tx = tile["x"]
		var ty = tile["y"]
		if bh > 0:
			var lp = PackedVector2Array()
			lp.append(Vector2(tx - TW / 2, ty))
			lp.append(Vector2(tx, ty + TH / 2))
			lp.append(Vector2(tx, ty + TH / 2 + bh))
			lp.append(Vector2(tx - TW / 2, ty + bh))
			draw_polygon(lp, PackedColorArray([tile["lc"]]))
			var rp = PackedVector2Array()
			rp.append(Vector2(tx + TW / 2, ty))
			rp.append(Vector2(tx, ty + TH / 2))
			rp.append(Vector2(tx, ty + TH / 2 + bh))
			rp.append(Vector2(tx + TW / 2, ty + bh))
			draw_polygon(rp, PackedColorArray([tile["rc"]]))
		var dp = PackedVector2Array()
		dp.append(Vector2(tx, ty - TH / 2))
		dp.append(Vector2(tx + TW / 2, ty))
		dp.append(Vector2(tx, ty + TH / 2))
		dp.append(Vector2(tx - TW / 2, ty))
		draw_polygon(dp, PackedColorArray([tile["tc"]]))
	# Draw cars as small diamonds
	for car in car_data:
		var cx = car["x"]
		var cy = car["y"]
		var cp = PackedVector2Array()
		cp.append(Vector2(cx - 8, cy - 4))
		cp.append(Vector2(cx + 8, cy - 4))
		cp.append(Vector2(cx + 8, cy + 4))
		cp.append(Vector2(cx - 8, cy + 4))
		draw_polygon(cp, PackedColorArray([car["color"]]))

func request_redraw():
	queue_redraw()

func rebuild_labels():
	# Remove old label nodes
	for ln in _label_nodes:
		if is_instance_valid(ln):
			remove_child(ln)
			ln.free()
	_label_nodes.clear()
	# Create Label nodes for P/E/B
	for lbl in labels:
		var l = Label.new()
		l.text = lbl["text"]
		l.position = Vector2(lbl["x"] - 20, lbl["y"] - lbl["fs"] / 2)
		l.size = Vector2(40, lbl["fs"] + 4)
		l.horizontal_alignment = 1
		l.vertical_alignment = 1
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if font != null:
			l.add_theme_font_override("font", font)
		l.add_theme_font_size_override("font_size", lbl["fs"])
		l.add_theme_color_override("font_color", lbl["color"])
		add_child(l)
		_label_nodes.append(l)
