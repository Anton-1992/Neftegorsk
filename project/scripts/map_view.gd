## MapView — draws isometric map using Control._draw()
extends Control

var tiles = []
var car_data = []
var labels = []
var TW = 64
var TH = 32
var font = null

func _draw():
	for tile in tiles:
		var bh = tile.get("bh", 0)
		if bh > 0:
			# Left face
			var lp = PackedVector2Array()
			lp.append(Vector2(tile.x - TW / 2, tile.y))
			lp.append(Vector2(tile.x, tile.y + TH / 2))
			lp.append(Vector2(tile.x, tile.y + TH / 2 + bh))
			lp.append(Vector2(tile.x - TW / 2, tile.y + bh))
			draw_polygon(lp, PackedColorArray([tile.lc]))
			# Right face
			var rp = PackedVector2Array()
			rp.append(Vector2(tile.x + TW / 2, tile.y))
			rp.append(Vector2(tile.x, tile.y + TH / 2))
			rp.append(Vector2(tile.x, tile.y + TH / 2 + bh))
			rp.append(Vector2(tile.x + TW / 2, tile.y + bh))
			draw_polygon(rp, PackedColorArray([tile.rc]))
		# Top diamond
		var dp = PackedVector2Array()
		dp.append(Vector2(tile.x, tile.y - TH / 2))
		dp.append(Vector2(tile.x + TW / 2, tile.y))
		dp.append(Vector2(tile.x, tile.y + TH / 2))
		dp.append(Vector2(tile.x - TW / 2, tile.y))
		draw_polygon(dp, PackedColorArray([tile.tc]))
	# Labels
	for lbl in labels:
		if font != null:
			draw_string(font, Vector2(lbl.x - 20, lbl.y + lbl.fs / 2), lbl.text, HORIZONTAL_ALIGNMENT_CENTER, 40, lbl.fs, lbl.color)
	# Cars
	for car in car_data:
		var cp = PackedVector2Array()
		cp.append(Vector2(car.x - 8, car.y - 4))
		cp.append(Vector2(car.x + 8, car.y - 4))
		cp.append(Vector2(car.x + 8, car.y + 4))
		cp.append(Vector2(car.x - 8, car.y + 4))
		draw_polygon(cp, PackedColorArray([car.color]))

func request_redraw():
	queue_redraw()
