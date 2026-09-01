extends SceneTree
var failures:=0
func check(value:bool,label:String)->void:
	if value:print("PASS: ",label)
	else:failures+=1;push_error("FAIL: "+label)
func make_level(stacks:Array)->LevelDefinition:
	var level:=LevelDefinition.new()
	for i in stacks.size():var stack:=StackDefinition.new();stack.stack_id=i;stack.tile_types.assign(stacks[i]);level.stacks.append(stack)
	return level
func _init()->void:
	var easy:=make_level([["fire","ice"],["fire","ice"],["fire","ice"]]);var solved:=PuzzleSolver.solve(easy)
	check(solved.solvable and not solved.sample_path.is_empty(),"solver returns a winning sample path")
	check(solved.best_peak_tray==2,"solver reports exact minimum peak on a small known puzzle")
	var impossible:=make_level([["fire"],["ice"]]);check(not PuzzleSolver.solve(impossible).solvable,"solver detects an impossible layout")
	for number in range(1,21):
		var suffix:="1_mixed" if number==1 else str(number);check(PuzzleSolver.solve(load("res://resources/levels/level_%s.tres"%suffix)).solvable,"production Level %d is puzzle-solvable"%number)
	var options:={"id":"generated_test","seed":12345,"stack_count":6,"depths":[3,3,3,3,3,3],"type_counts":{"fire":6,"ice":6,"lightning":6},"profile":DifficultyProfile.TUTORIAL,"attempts":100}
	var a:=LevelGenerator.generate_candidate(options);var b:=LevelGenerator.generate_candidate(options)
	check(a.has("level") and b.has("level"),"generator creates a candidate with requested counts")
	if a.has("level") and b.has("level"):
		check(a.level.stacks.size()==6 and a.level.tile_count()==18,"generator respects stack/depth profile")
		var same:=true;for i in a.level.stacks.size():same=same and a.level.stacks[i].tile_types==b.level.stacks[i].tile_types
		check(same,"generator is deterministic for the same seed")
		check(a.solution.solvable,"accepted/analyzed generator candidate passes solver")
	var normal_level:=make_level([["fire","ice","wind"],["fire","wind","ice"],["fire","lightning","shield"],["ice","life","fire"]]);var fake_solution:={"solvable":true,"best_peak_tray":4,"winning_first_moves":PackedInt32Array()}
	check(not DifficultyProfile.accepts(normal_level,DifficultyProfile.NORMAL,fake_solution),"Normal profile rejects excessive initial Top triples")
	print("\n","ALL SOLVER GENERATOR TESTS PASSED" if failures==0 else "%d SOLVER GENERATOR TESTS FAILED"%failures);quit(failures)
