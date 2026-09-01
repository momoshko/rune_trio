class_name LevelGenerator
extends RefCounted
static func generate_candidate(o:Dictionary)->Dictionary:
	var depths:Array=o.get("depths",[]);var count:int=o.get("stack_count",6)
	if depths.is_empty():for i in count:depths.append(6)
	var total:=0;for d in depths:total+=d
	var pool:Array[String]=[]
	for type_id in o.type_counts:
		if o.type_counts[type_id]%3!=0:return {"accepted":false,"error":"counts must be multiples of three"}
		for i in o.type_counts[type_id]:pool.append(type_id)
	if pool.size()!=total:return {"accepted":false,"error":"count/depth mismatch"}
	var rng:=RandomNumberGenerator.new();rng.seed=o.get("seed",1);var last:={}
	for attempt in o.get("attempts",300):
		var shuffled:=pool.duplicate()
		for i in range(shuffled.size()-1,0,-1):var j:=rng.randi_range(0,i);var v:String=shuffled[i];shuffled[i]=shuffled[j];shuffled[j]=v
		var level:=_build(shuffled,depths,o.get("id","candidate"));var rules:=DifficultyProfile.config(o.get("profile",DifficultyProfile.EASY));var quick:=PuzzleSolver.metrics(level)
		if quick.immediate_top_triples>rules.top or quick.maximum_repeated_stack_prefix>rules.prefix:continue
		var solution:=PuzzleSolver.solve(level);last={"accepted":DifficultyProfile.accepts(level,o.get("profile",DifficultyProfile.EASY),solution),"level":level,"solution":solution,"metrics":PuzzleSolver.metrics(level,solution),"seed":o.get("seed",1),"attempt":attempt}
		if last.accepted:return last
	return last if not last.is_empty() else {"accepted":false,"error":"no candidate accepted"}
static func _build(pool:Array[String],depths:Array,id:String)->LevelDefinition:
	var level:=LevelDefinition.new();level.id=id;level.name_key=id.to_upper();var cursor:=0
	for stack_id in depths.size():
		var stack:=StackDefinition.new();stack.stack_id=stack_id;stack.position=Vector2(70+(stack_id%4)*140,90+int(stack_id/4)*320)
		for i in depths[stack_id]:stack.tile_types.append(pool[cursor]);cursor+=1
		level.stacks.append(stack)
	return level
