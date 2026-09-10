extends SceneTree

func _initialize() -> void:
	var provider := RuntimeLayoutProvider.new()
	var failures := provider.validation_errors()
	var checked := 0
	for entry in provider.bank.get("entries", []):
		var result := provider.reconstruct_entry(entry)
		if result.source != "approved": failures.append("failed: " + str(entry.layout_id))
		else: checked += 1
	print("M10B3 bank reconstruction: %d/%d" % [checked, provider.bank.get("entries", []).size()])
	for failure in failures: print("FAIL: ", failure)
	quit(0 if failures.is_empty() and checked == 15 else 1)
