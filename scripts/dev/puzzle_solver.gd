class_name PuzzleSolver
extends RefCounted

const TYPES := ["fire","ice","lightning","wind","life","shield"]

static func solve(level: LevelDefinition, capacity := 7, state_limit := 750000) -> Dictionary:
	var stacks: Array = []; for stack in level.stacks: stacks.append(stack.tile_types)
	var context := {"stacks":stacks,"capacity":capacity,"explored":0,"limit":state_limit,"aborted":false}
	for peak in range(capacity):
		var tops: Array[int] = []; tops.resize(stacks.size()); tops.fill(0)
		var tray: Array[int] = []; tray.resize(TYPES.size()); tray.fill(0)
		var path: Array[int] = []
		if _search(tops,tray,peak,{},path,context):
			return {"solvable":true,"sample_path":PackedInt32Array(path),"best_peak_tray":peak,"winning_first_moves":PackedInt32Array(_first_moves(stacks,capacity,peak,state_limit)),"explored_states":context.explored,"aborted":false}
		if context.aborted: break
	return {"solvable":false,"sample_path":PackedInt32Array(),"best_peak_tray":-1,"winning_first_moves":PackedInt32Array(),"explored_states":context.explored,"aborted":context.aborted}

static func _search(tops:Array[int],tray:Array[int],peak:int,memo:Dictionary,path:Array[int],context:Dictionary)->bool:
	context.explored += 1
	if context.explored > context.limit: context.aborted=true; return false
	var complete:=true; for i in tops.size():
		if tops[i] < context.stacks[i].size(): complete=false; break
	if complete:
		for count in tray:
			if count != 0:return false
		return true
	var key:=",".join(tops.map(func(v):return str(v)))+"|"+"".join(tray.map(func(v):return str(v)))
	if memo.has(key):return false
	memo[key]=true
	var choices:Array[int]=[]; for i in tops.size():
		if tops[i]<context.stacks[i].size():choices.append(i)
	choices.sort_custom(func(a,b):
		var ai:=TYPES.find(context.stacks[a][tops[a]]);var bi:=TYPES.find(context.stacks[b][tops[b]])
		return tray[ai]>tray[bi] if tray[ai]!=tray[bi] else a<b)
	for stack_id in choices:
		var ti:=TYPES.find(context.stacks[stack_id][tops[stack_id]])
		if ti<0:continue
		var nt:=tops.duplicate();nt[stack_id]+=1
		var nr:=tray.duplicate();nr[ti]=(nr[ti]+1)%3
		var occupancy:=0;for count in nr:occupancy+=count
		if occupancy>peak or occupancy>=context.capacity:continue
		path.append(stack_id)
		if _search(nt,nr,peak,memo,path,context):return true
		path.pop_back()
		if context.aborted:return false
	return false

static func _first_moves(stacks:Array,capacity:int,peak:int,state_limit:int)->Array[int]:
	var result:Array[int]=[]
	for first in stacks.size():
		if stacks[first].is_empty() or peak<1:continue
		var tops:Array[int]=[];tops.resize(stacks.size());tops.fill(0);tops[first]=1
		var tray:Array[int]=[];tray.resize(TYPES.size());tray.fill(0);tray[TYPES.find(stacks[first][0])]=1
		var context:={"stacks":stacks,"capacity":capacity,"explored":0,"limit":maxi(10000,state_limit/4),"aborted":false}
		var path:Array[int]=[]
		if _search(tops,tray,peak,{},path,context):result.append(first)
	return result

static func metrics(level:LevelDefinition,solution:Dictionary={})->Dictionary:
	var tops:={};var distinct:={};var total:=0
	for stack in level.stacks:
		total+=stack.tile_types.size()
		if not stack.tile_types.is_empty():tops[stack.tile_types[0]]=tops.get(stack.tile_types[0],0)+1;distinct[stack.tile_types[0]]=true
	var immediate:=0;for count in tops.values():immediate+=int(count/3)
	var prefix_max:=0
	for a in level.stacks.size():
		for b in range(a+1,level.stacks.size()):
			var p:=0;while p<level.stacks[a].tile_types.size() and p<level.stacks[b].tile_types.size() and level.stacks[a].tile_types[p]==level.stacks[b].tile_types[p]:p+=1
			prefix_max=maxi(prefix_max,p)
	return {"immediate_top_triples":immediate,"distinct_top_types":distinct.size(),"maximum_repeated_stack_prefix":prefix_max,"stack_count":level.stacks.size(),"average_stack_depth":float(total)/maxi(1,level.stacks.size()),"best_peak_tray":solution.get("best_peak_tray",-1),"winning_first_moves":solution.get("winning_first_moves",PackedInt32Array()).size()}
