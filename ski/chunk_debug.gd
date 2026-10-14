class_name ChunkDebug
extends RefCounted
## 청크 하나의 디버그 표시(타입 색 중심선 + 라벨). 청크 원점 기준 로컬 좌표로 만들어
## 반환 노드의 position 만 옮기면 리센터에도 그대로 따라감.


static func make(t: ChunkType, global_index: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Chunk_%d" % global_index

	var im := ImmediateMesh.new()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = t.color
	mat.no_depth_test = true
	im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, mat)
	var steps: int = ChunkSpec.SIZE / 4
	for s in steps + 1:
		im.surface_add_vertex(ChunkBuilder.center_point(t, float(s) / steps) + Vector3.UP)
	im.surface_end()
	var line := MeshInstance3D.new()
	line.mesh = im
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(line)

	var lbl := Label3D.new()
	lbl.name = "Label"
	lbl.text = "#%d %s" % [global_index, t.describe()]
	lbl.modulate = t.color
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.fixed_size = true
	lbl.pixel_size = 0.002
	lbl.font_size = 40
	lbl.outline_size = 12
	lbl.position = ChunkBuilder.center_point(t, 0.08) + Vector3.UP * 12.0
	root.add_child(lbl)
	return root


static func set_label_visible(dbg: Node3D, value: bool) -> void:
	var lbl := dbg.get_node_or_null("Label") as Label3D
	if lbl:
		lbl.visible = value
