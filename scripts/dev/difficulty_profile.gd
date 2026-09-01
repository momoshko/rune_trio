class_name DifficultyProfile
extends RefCounted
const TUTORIAL:="tutorial";const EASY:="easy";const NORMAL:="normal";const HARD:="hard"
static func config(id:String)->Dictionary:
	match id:
		TUTORIAL:return {"peak_min":2,"peak_max":4,"top":2,"streak":3,"prefix":3}
		EASY:return {"peak_min":3,"peak_max":4,"top":1,"streak":2,"prefix":2}
		NORMAL:return {"peak_min":4,"peak_max":5,"top":0,"streak":2,"prefix":1}
		HARD:return {"peak_min":5,"peak_max":6,"top":0,"streak":1,"prefix":1}
	return config(EASY)
static func accepts(level:LevelDefinition,id:String,solution:Dictionary)->bool:
	if not solution.get("solvable",false):return false
	var r:=config(id);var m:=PuzzleSolver.metrics(level,solution)
	if m.immediate_top_triples>r.top or m.maximum_repeated_stack_prefix>r.prefix:return false
	for stack in level.stacks:
		var streak:=1
		for i in range(1,stack.tile_types.size()):
			streak=streak+1 if stack.tile_types[i]==stack.tile_types[i-1] else 1
			if streak>r.streak:return false
	return solution.best_peak_tray>=r.peak_min and solution.best_peak_tray<=r.peak_max
