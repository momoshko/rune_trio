extends SceneTree
func _init()->void:
	print("LEVEL | SOLVABLE | PEAK | TOP TRIPLES | FIRST MOVES | STATES")
	var failed:=false
	for number in range(1,21):
		var suffix:="1_mixed" if number==1 else str(number)
		var level:LevelDefinition=load("res://resources/levels/level_%s.tres"%suffix)
		var solution:=PuzzleSolver.solve(level);var metrics:=PuzzleSolver.metrics(level,solution)
		print("%02d    | %s       | %d/7  | %d           | %d           | %d"%[number,"YES" if solution.solvable else "NO ",solution.best_peak_tray,metrics.immediate_top_triples,metrics.winning_first_moves,solution.explored_states])
		if not solution.solvable:failed=true
	quit(1 if failed else 0)
