extends SceneTree
var failures:=0
func check(v:bool,l:String)->void:
	if v:print("PASS: ",l)
	else:failures+=1;push_error("FAIL: "+l)
func levels()->Array[LevelDefinition]:
	var r:Array[LevelDefinition]=[]
	for n in range(1,21):r.append(load("res://resources/levels/level_%s.tres"%("1_mixed" if n==1 else str(n))))
	return r
func triple(c:GameController,type:="life")->void:c.resolve_triples([type,type,type])
func _init()->void:
	var c:=GameController.new();c.levels=levels();c.balance=BalanceConfig.new()
	c.start_level(4);check(c.battle.current_enemy.id=="stone_guard","Stone Guard Level 5");triple(c);triple(c);check(c.battle.boss_telegraph=="heavy_attack","Heavy Attack telegraphs")
	c.start_level(14);check(c.battle.current_enemy.id=="frost_beast","Frost Beast Level 15");triple(c);triple(c);check(c.battle.boss_telegraph=="frost_attack","Frost Attack telegraphs");triple(c);check(c.board.locked_stack_id>=0 and c.board.available_ids().size()>0,"Frost Beast lock safe")
	c.start_level(19);check(c.battle.current_enemy.id=="frost_witch","Frost Witch Level 20");triple(c);triple(c);check(c.battle.boss_telegraph=="ice_bolt","Ice Bolt telegraphs");var hp:=c.battle.core_hp;triple(c);check(c.battle.core_hp==hp-9,"Ice Bolt damages");triple(c);triple(c);check(c.battle.boss_telegraph=="frost_seal","Frost Seal telegraphs");triple(c);check(c.board.locked_stack_id>=0 and c.board.available_ids().size()>0,"Frost Seal lock safe");c.battle.enemy_hp=1;triple(c,"fire");check(c.state=="campaign_complete","Witch death completes Campaign")
	c.free();print("\n","ALL CAMPAIGN BOSS TESTS PASSED" if failures==0 else "%d CAMPAIGN BOSS TESTS FAILED"%failures);quit(failures)

