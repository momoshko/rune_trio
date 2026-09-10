extends SceneTree

func _initialize() -> void:
	var definition: RunDefinition = load("res://resources/runs/m4_run.tres")
	var results := RunLayoutValidation.validate_runtime_pairs(definition, BalanceConfig.new())
	print("M10A_BATCH_JSON=" + JSON.stringify(results))
	quit()
