extends RefCounted
## Independent 3D slot. The Flutter application and its data are never touched.
const PATH := "user://expedition_3d_v1.json"
const HEROES := ["Rowan", "Sky", "Fern"]
const RECIPES := {
	"bow": {"wood": 3, "crystal": 2}, "arrows": {"wood": 1}, "tonic": {"herbs": 2, "crystal": 1}
}
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
		"islands": {},
		"bag": starter_bag(true)
	}


static func starter_bag(ranged: bool = false) -> Dictionary:
	return {
		"wood": 0,
		"crystal": 0,
		"herbs": 0,
		"tonic": 0,
		"arrows": 24 if ranged else 0,
		"bow": ranged,
		"weapon": 1 if ranged else 0
	}


func load_save() -> bool:
	for file in [path, path + ".bak"]:
		if not FileAccess.file_exists(file):
			continue
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(file)) == OK and valid(json.data):
			data = json.data
			if not data.has("bag"):
				data.bag = starter_bag()
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
	if value.has("bag"):
		var bag = value.bag
		if not bag is Dictionary or not bag.get("bow") is bool:
			return false
		for key in ["wood", "crystal", "herbs", "tonic", "arrows", "weapon"]:
			var number = bag.get(key)
			if (
				not (number is int or number is float)
				or number < 0
				or number != floor(number)
				or number > 10000
			):
				return false
		if bag.weapon > 1 or (bag.weapon == 1 and not bag.bow):
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


func weight() -> float:
	var b: Dictionary = data.bag
	return float(b.wood + b.crystal + b.herbs + b.tonic) + float(b.arrows) * 0.1


func capacity() -> float:
	return [40.0, 30.0, 60.0][int(data.hero)]


func gather(id: String, resource: String) -> bool:
	if resource not in ["wood", "crystal", "herbs"] or id in memory().picked:
		return false
	if weight() + 2 > capacity():
		last_error = "Backpack full. Craft at camp to free some space."
		return false
	return transact(
		func():
			memory().picked.append(id)
			data.bag[resource] += 2
	)


func craft(recipe: String) -> bool:
	if not RECIPES.has(recipe) or (recipe == "bow" and data.bag.bow):
		last_error = "This equipment is already crafted."
		return false
	for ingredient in RECIPES[recipe]:
		if data.bag[ingredient] < RECIPES[recipe][ingredient]:
			last_error = "Gather more materials along the trails."
			return false
	if recipe == "arrows" and data.bag.arrows > 192:
		last_error = "Your quiver already holds enough arrows (maximum 200)."
		return false
	return transact(
		func():
			for ingredient in RECIPES[recipe]:
				data.bag[ingredient] -= RECIPES[recipe][ingredient]
			if recipe == "bow":
				data.bag.bow = true
			else:
				data.bag[recipe] += 8 if recipe == "arrows" else 1
	)


func equip(weapon: int) -> bool:
	if weapon not in [0, 1] or (weapon == 1 and not data.bag.bow):
		return false
	return transact(func(): data.bag.weapon = weapon)


func claim_drop(id: String, elite: bool) -> bool:
	if id in memory().picked:
		return false
	return transact(
		func():
			memory().picked.append(id)
			data.bag.arrows = mini(200, int(data.bag.arrows) + (8 if elite else 3))
			data.coins += 10 if elite else 2
			if weight() + 1 <= capacity():
				data.bag.crystal += 1
	)
