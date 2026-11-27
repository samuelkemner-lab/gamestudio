extends SceneTree
## Prints size (AABB) and material names of models: godot --headless --path . -s tools/inspect_models.gd -- name1 name2


func _initialize() -> void:
	for n in OS.get_cmdline_user_args():
		var ps: PackedScene = load("res://assets/models/kenney_furniture/%s.glb" % n)
		if ps == null:
			print(n, ": NOT FOUND")
			continue
		var inst: Node3D = ps.instantiate()
		root.add_child(inst)
		var box := AABB()
		var first := true
		var mats := {}
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var a: AABB = mi.global_transform * mi.get_aabb()
			box = a if first else box.merge(a)
			first = false
			for s in mi.mesh.get_surface_count():
				var m: Material = mi.mesh.surface_get_material(s)
				var col := ""
				if m is StandardMaterial3D:
					col = "#" + m.albedo_color.to_html(false)
				mats[(m.resource_name if m else "none") + col] = true
		print("%-24s size=%s pos=%s mats=%s" % [n, str(box.size.snapped(Vector3.ONE * 0.001)), str(box.position.snapped(Vector3.ONE * 0.001)), str(mats.keys())])
		inst.queue_free()
	quit()
