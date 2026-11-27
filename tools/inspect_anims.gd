extends SceneTree
## godot --headless --path . -s tools/inspect_anims.gd -- res://model.glb


func _initialize() -> void:
	for p in OS.get_cmdline_user_args():
		var inst: Node = load(p).instantiate()
		print("== ", p.get_file())
		for ap in inst.find_children("*", "AnimationPlayer", true, false):
			print("  anims: ", (ap as AnimationPlayer).get_animation_list())
		for sk in inst.find_children("*", "Skeleton3D", true, false):
			var names := []
			for i in (sk as Skeleton3D).get_bone_count():
				names.append((sk as Skeleton3D).get_bone_name(i))
			print("  bones: ", names)
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			print("  mesh: ", mi.name, " aabb=", (mi as MeshInstance3D).get_aabb().size.snapped(Vector3.ONE * 0.01))
	quit()
