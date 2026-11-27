extends SceneTree
## godot --headless --path . -s tools/inspect_scene.gd -- res://path.glb


func _walk(n: Node, xf: Transform3D, out: Dictionary) -> void:
	var t := xf
	if n is Node3D:
		t = xf * n.transform
	if n is MeshInstance3D and n.mesh:
		var a: AABB = t * n.get_aabb()
		out["aabb"] = a if not out.has("aabb") else out["aabb"].merge(a)
		for s in n.mesh.get_surface_count():
			var m: Material = n.mesh.surface_get_material(s)
			var info := "none"
			if m is StandardMaterial3D:
				info = "%s col=%s tex=%s" % [m.resource_name, m.albedo_color.to_html(false), m.albedo_texture.resource_path if m.albedo_texture else "-"]
			out["mats"][info] = true
	for c in n.get_children():
		_walk(c, t, out)


func _initialize() -> void:
	for p in OS.get_cmdline_user_args():
		var inst: Node = load(p).instantiate()
		var out := {"mats": {}}
		_walk(inst, Transform3D(), out)
		print(p.get_file(), " size=", out.get("aabb", AABB()).size.snapped(Vector3.ONE * 0.01), " pos=", out.get("aabb", AABB()).position.snapped(Vector3.ONE * 0.01))
		for k in out["mats"].keys():
			print("    ", k)
	quit()
