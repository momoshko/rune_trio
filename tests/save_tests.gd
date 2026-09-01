extends SceneTree
var failures:=0
func check(v:bool,l:String)->void:
	if v:print("PASS: ",l)
	else:failures+=1;push_error("FAIL: "+l)
func _init()->void:
	var path:="user://save_test_v06.cfg";var absolute:=ProjectSettings.globalize_path(path);DirAccess.remove_absolute(absolute)
	var clean:=CampaignSave.new();clean.load_file(path);check(clean.highest_unlocked_level==1 and clean.relic_ids.is_empty(),"missing save uses defaults")
	clean.complete("level_10",10,"golem_heart");check(clean.save_file()==OK,"progress saves")
	var restored:=CampaignSave.new();restored.load_file(path);check(restored.highest_unlocked_level==11 and restored.completed_level_ids.has("level_10"),"relaunch restores unlock");check(restored.relic_ids.has("golem_heart"),"relaunch restores relic")
	var file:=FileAccess.open(absolute,FileAccess.WRITE);file.store_string("not a valid config [[[");file.close();var bad:=CampaignSave.new();bad.load_file(path);check(bad.highest_unlocked_level==1 and bad.completed_level_ids.is_empty(),"corrupt save uses defaults")
	DirAccess.remove_absolute(absolute);print("\n","ALL SAVE TESTS PASSED" if failures==0 else "%d SAVE TESTS FAILED"%failures);quit(failures)

