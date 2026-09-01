extends SceneTree
func _init()->void:
	var args:=OS.get_cmdline_user_args();var seed:=int(args[0]) if not args.is_empty() else 12345
	var options:={"id":"candidate","seed":seed,"stack_count":8,"depths":[6,6,6,6,6,6,6,6],"type_counts":{"fire":9,"ice":9,"lightning":9,"wind":9,"life":6,"shield":6},"profile":DifficultyProfile.NORMAL,"attempts":500}
	var result:=LevelGenerator.generate_candidate(options)
	print("ACCEPTED: ",result.get("accepted",false)," SEED: ",seed)
	if result.has("metrics"):print("METRICS: ",result.metrics)
	if result.has("level"):
		for stack in result.level.stacks:print("STACK ",stack.stack_id,": ",stack.tile_types)
	quit(0 if result.get("accepted",false) else 1)

