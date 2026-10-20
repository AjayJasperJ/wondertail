extends RefCounted
## Independent 3D slot. The Flutter application and its data are never touched.
const PATH := "user://expedition_3d_v1.json"
const HEROES := ["Rowan", "Sky", "Fern"]
var path := PATH
var data: Dictionary = fresh()
var last_error := ""


static func fresh() -> Dictionary:
	return {
		"schema": 1,
		"seed": 47021,
		"island": 0,
		"unlocked": 0,
		"hero": 0,
		"coins": 0,
		"volume": 0.4,
		"quality": 1,
		"sensitivity": 1.0,
		"islands": {}
	}


func load_save() -> bool:
	for file in [path, path + ".bak"]:
		if not FileAccess.file_exists(file):
			continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(file)) == OK and valid(json.data):
			data = json.data
			return true
	return false


static func valid(value: Variant) -> bool:
	if not value is Dictionary or value.get("schema") != 1:
		return false
	for key in ["seed", "island", "unlocked", "hero", "coins", "volume", "quality", "sensitivity"]:
		if not value.get(key) is float and not value.get(key) is int:
			return false
	if (
		value.hero < 0
		or value.hero > 2
		or value.island < 0
		or value.island > value.unlocked
		or value.coins < 0
	):
		return false
	if not value.get("islands") is Dictionary:
		return false
	for key in value.islands:
		var island = value.islands[key]
		if (
			not island is Dictionary
			or not island.get("picked") is Array
			or not island.get("seeds") is Array
		):
			return false
		for flag in ["cloud", "restored", "cave"]:
			if not island.get(flag) is bool:
				return false
	return true


func memory(index: int = -1) -> Dictionary:
	if index < 0:
		index = int(data.island)
	var key := str(index)
	if not data.islands.has(key):
		data.islands[key] = {
			"picked": [], "seeds": [], "cloud": false, "restored": false, "cave": false
		}
	return data.islands[key]


func transact(change: Callable) -> bool:
	var previous := data.duplicate(true)
	change.call()
	if persist():
		return true
	data = previous
	return false


func persist() -> bool:
	last_error = ""
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		last_error = "Storage unavailable. Progress has not changed."
		return false
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		last_error = "Could not save. Progress has not changed."
		return false
	var absolute := ProjectSettings.globalize_path(path)
	# Copy the previous committed checkpoint before atomically replacing it.
	if FileAccess.file_exists(path):
		if DirAccess.copy_absolute(absolute, absolute + ".bak") != OK:
			last_error = "Could not back up progress. Please free storage."
			return false
	if DirAccess.rename_absolute(absolute + ".tmp", absolute) != OK:
		last_error = "Could not commit progress. Please free storage."
		return false
	return true


func collect(id: String, amount: int, seed_id: int = -1) -> bool:
	if id in memory().picked:
		return false
	return transact(
		func():
			memory().picked.append(id)
			data.coins += amount
			if seed_id >= 0 and not seed_id in memory().seeds:
				memory().seeds.append(seed_id)
	)
