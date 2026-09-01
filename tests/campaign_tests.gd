extends SceneTree
var failures:=0
func check(v:bool,l:String)->void:
	if v:print("PASS: ",l)
	else:failures+=1;push_error("FAIL: "+l)
func levels()->Array[LevelDefinition]:
	var r:Array[LevelDefinition]=[]
	for n in range(1,21):r.append(load("res://resources/levels/level_%s.tres"%("1_mixed" if n==1 else str(n))))
	return r
func defeat(c:GameController)->void:
	while c.state=="playing":c.battle.enemy_hp=1;c.resolve_triples(["fire","fire","fire"])
func _init()->void:
	var ls:=levels();check(ls.size()==20 and ls.all(func(x):return x!=null),"campaign contains exactly 20 Levels")
	check(ls[4].boss_id=="stone_guard" and ls[4].milestone=="mini_boss","Level 5 is Stone Guard Mini-Boss");check(ls[9].boss_id=="stone_golem" and ls[9].milestone=="boss","Level 10 is Stone Golem Boss");check(ls[14].boss_id=="frost_beast","Level 15 is Frost Beast Mini-Boss");check(ls[19].boss_id=="frost_witch","Level 20 is Frost Witch Boss")
	var c:=GameController.new();c.levels=ls;c.balance=BalanceConfig.new();c.ensure_progress();check(c.progress.highest_unlocked_level==1 and not c.start_campaign_level(1),"locked Levels inaccessible initially")
	for i in range(9):c.start_level(i);defeat(c);check(c.progress.highest_unlocked_level==i+2,"sequential unlock %d"%(i+2))
	c.start_level(9);defeat(c);check(c.state=="milestone" and c.progress.has_location_two() and c.progress.relic_ids.has("golem_heart"),"Level 10 grants relic and Location 2")
	for i in range(10,19):c.start_level(i);defeat(c)
	c.start_level(19);defeat(c);check(c.state=="campaign_complete" and c.progress.relic_ids.has("frozen_crown"),"Level 20 grants relic and completes Campaign")
	c.free();print("\n","ALL CAMPAIGN TESTS PASSED" if failures==0 else "%d CAMPAIGN TESTS FAILED"%failures);quit(failures)

