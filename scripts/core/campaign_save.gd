class_name CampaignSave
extends RefCounted
var highest_unlocked_level:=1
var completed_level_ids:Array[String]=[]
var relic_ids:Array[String]=[]
var path:="user://rune_trio_progress.cfg"
func reset()->void:highest_unlocked_level=1;completed_level_ids.clear();relic_ids.clear()
func load_file(save_path:String=path)->void:
	path=save_path;reset();var config:=ConfigFile.new()
	if config.load(path)!=OK:return
	highest_unlocked_level=clampi(int(config.get_value("campaign","highest_unlocked_level",1)),1,20)
	completed_level_ids.assign(config.get_value("campaign","completed_level_ids",[]))
	relic_ids.assign(config.get_value("campaign","relic_ids",[]))
func save_file()->Error:
	var config:=ConfigFile.new();config.set_value("campaign","highest_unlocked_level",highest_unlocked_level);config.set_value("campaign","completed_level_ids",completed_level_ids);config.set_value("campaign","relic_ids",relic_ids);return config.save(path)
func complete(level_id:String,level_number:int,relic_id:="")->void:
	if not completed_level_ids.has(level_id):completed_level_ids.append(level_id)
	highest_unlocked_level=maxi(highest_unlocked_level,mini(20,level_number+1))
	if relic_id!="" and not relic_ids.has(relic_id):relic_ids.append(relic_id)
func is_unlocked(index:int)->bool:return index+1<=highest_unlocked_level
func has_location_two()->bool:return highest_unlocked_level>=11

