extends RefCounted
## Independent 3D slot. The Flutter application and its data are never touched.
const PATH := "user://expedition_3d_v1.json"
const HEROES := ["Rowan", "Sky", "Fern"]
const RECIPES := {
	"bow": {"wood": 3, "crystal": 2},
	"arrows": {"wood": 1},
	"tonic": {"herbs": 2, "crystal": 1},
	"gun": {"wood": 4, "crystal": 5},
	"bullets": {"crystal": 1}
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
		"gun": false,
		"bullets": 0,
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
			data.bag.merge({"gun": false, "bullets": 0}, false)
			for island in data.islands.values():
				island.seeds = island.seeds.map(func(value): return int(value))
				if island.has("expedition"):
					island.expedition.kind = int(island.expedition.kind)
					island.expedition.done = island.expedition.done.map(
						func(value): return int(value)
					)
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
	if (
		value.has("pack_level")
		and (
			not (value.pack_level is int or value.pack_level is float)
			or value.pack_level < 0
			or value.pack_level > 3
			or value.pack_level != floor(value.pack_level)
		)
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
		if (
			bag.weapon > 2
			or (bag.weapon == 1 and not bag.bow)
			or (bag.weapon == 2 and not bag.get("gun", false))
		):
			return false
		if (
			not bag.get("gun", false) is bool
			or not (bag.get("bullets", 0) is int or bag.get("bullets", 0) is float)
			or bag.get("bullets", 0) < 0
			or bag.get("bullets", 0) > 10000
			or bag.get("bullets", 0) != floor(bag.get("bullets", 0))
		):
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
		if island.has("expedition"):
			var contract = island.expedition
			if (
				not contract is Dictionary
				or not (contract.get("kind") is int or contract.get("kind") is float)
				or contract.kind < 0
				or contract.kind > 2
				or contract.kind != floor(contract.kind)
				or not contract.get("done") is Array
			):
				return false
			var seen := []
			for step in contract.done:
				if (
					not (step is int or step is float)
					or step < 0
					or step > 2
					or step != floor(step)
					or step in seen
				):
					return false
				seen.append(step)
		if (
			island.has("drop_serial")
			and (
				not (island.drop_serial is int or island.drop_serial is float)
				or island.drop_serial < 0
				or island.drop_serial != floor(island.drop_serial)
			)
		):
			return false
		if island.has("ground"):
			if not island.ground is Dictionary or island.ground.size() > 128:
				return false
			for id in island.ground:
				var entry = island.ground[id]
				if (
					not entry is Dictionary
					or (
						entry.get("item", "")
						not in [
							"wood", "crystal", "herbs", "tonic", "arrows", "bow", "gun", "bullets"
						]
					)
					or not entry.get("amount", 0) is float and not entry.get("amount", 0) is int
				):
					return false
				if (
					entry.amount <= 0
					or entry.amount > 10000
					or entry.amount != floor(entry.amount)
					or not entry.get("cave") is bool
					or not entry.get("at") is Array
					or entry.at.size() != 3
				):
					return false
				for coordinate in entry.at:
					if (
						not (coordinate is int or coordinate is float)
						or not is_finite(coordinate)
						or absf(coordinate) > 100000
					):
						return false
	return true


func memory(index: int = -1) -> Dictionary:
	if index < 0:
		index = int(data.island)
	var key := str(index)
	if not data.islands.has(key):
		data.islands[key] = {
			"picked": [], "seeds": [], "cloud": false, "restored": false, "cave": false, "layout": 2
		}
	data.islands[key].merge({"ground": {}, "drop_serial": 0}, false)
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
	return (
		float(b.wood + b.crystal + b.herbs + b.tonic) + float(b.arrows + b.get("bullets", 0)) * 0.1
	)


func capacity() -> float:
	return [40.0, 30.0, 60.0][int(data.hero)] + 10.0 * int(data.get("pack_level", 0))


func gather(id: String, resource: String) -> bool:
	if resource not in ["wood", "crystal", "herbs"] or id in memory().picked:
		return false
	if weight() + 2 > capacity():
		last_error = "Backpack full. Open PACK to drop items or craft at camp."
		return false
	return transact(
		func():
			memory().picked.append(id)
			data.bag[resource] += 2
	)


func craft(recipe: String) -> bool:
	if not RECIPES.has(recipe) or (recipe in ["bow", "gun"] and data.bag.get(recipe, false)):
		last_error = "This equipment is already crafted."
		return false
	for ingredient in RECIPES[recipe]:
		if data.bag[ingredient] < RECIPES[recipe][ingredient]:
			last_error = "Gather more materials along the trails."
			return false
	if (
		recipe in ["arrows", "bullets"]
		and data.bag.get(recipe, 0) > (192 if recipe == "arrows" else 188)
	):
		last_error = "Your quiver already holds enough arrows (maximum 200)."
		return false
	var next_weight := weight()
	for ingredient in RECIPES[recipe]:
		next_weight -= float(RECIPES[recipe][ingredient])
	next_weight += (
		0.8
		if recipe == "arrows"
		else (1.2 if recipe == "bullets" else (1.0 if recipe == "tonic" else 0.0))
	)
	if next_weight > capacity() + 0.001:
		last_error = "Drop a stack before crafting more ammunition."
		return false
	return transact(
		func():
			for ingredient in RECIPES[recipe]:
				data.bag[ingredient] -= RECIPES[recipe][ingredient]
			if recipe in ["bow", "gun"]:
				data.bag[recipe] = true
			else:
				data.bag[recipe] += 8 if recipe == "arrows" else (12 if recipe == "bullets" else 1)
	)


func equip(weapon: int) -> bool:
	if (
		weapon not in [0, 1, 2]
		or (weapon == 1 and not data.bag.bow)
		or (weapon == 2 and not data.bag.get("gun", false))
	):
		return false
	return transact(func(): data.bag.weapon = weapon)


func claim_drop(id: String, elite: bool) -> bool:
	if id in memory().picked:
		return false
	return transact(
		func():
			memory().picked.append(id)
			data.bag.arrows = mini(
				200,
				(
					int(data.bag.arrows)
					+ mini(8 if elite else 3, maxi(0, floori((capacity() - weight()) * 10)))
				)
			)
			data.coins += 10 if elite else 2
			if weight() + 1 <= capacity():
				data.bag.crystal += 1
	)


func item_count(item: String) -> int:
	if item == "sword":
		return 1
	return int(data.bag.get(item, 0))


func drop_item(item: String, amount: int, at: Vector3, cave: bool) -> bool:
	if (
		item not in ["wood", "crystal", "herbs", "tonic", "arrows", "bow", "gun", "bullets"]
		or amount <= 0
		or amount > item_count(item)
	):
		last_error = "Select a carried item. Your starter sword and quest items stay safe."
		return false
	if memory().ground.size() >= 128:
		last_error = "Reclaim some dropped stacks on this island first."
		return false
	return transact(
		func():
			var m := memory()
			m.drop_serial += 1
			m.ground["ground_%d" % m.drop_serial] = {
				"item": item, "amount": amount, "at": [at.x, at.y, at.z], "cave": cave
			}
			if item in ["bow", "gun"]:
				data.bag[item] = false
				if int(data.bag.weapon) == (1 if item == "bow" else 2):
					data.bag.weapon = 0
			else:
				data.bag[item] -= amount
	)


func reclaim(id: String) -> bool:
	if not memory().ground.has(id):
		return false
	var entry: Dictionary = memory().ground[id]
	var item: String = entry.item
	var amount := int(entry.amount)
	if item in ["bow", "gun"] and item_count(item) > 0:
		last_error = "You already carry this weapon."
		return false
	var added_weight := (
		float(amount)
		* (0.1 if item in ["arrows", "bullets"] else (0.0 if item in ["bow", "gun"] else 1.0))
	)
	if (
		weight() + added_weight > capacity() + 0.001
		or (item in ["arrows", "bullets"] and item_count(item) + amount > 200)
	):
		last_error = "Not enough space for this stack. Drop another item first."
		return false
	return transact(
		func():
			if item in ["bow", "gun"]:
				data.bag[item] = true
			else:
				data.bag[item] = item_count(item) + amount
			memory().ground.erase(id)
	)


func grid_recipe(grid: Array) -> String:
	var ingredients := {}
	for item in grid:
		if item != "":
			ingredients[item] = ingredients.get(item, 0) + 1
	for recipe in RECIPES:
		if ingredients == RECIPES[recipe]:
			return recipe
	return ""


func upgrade_pack() -> bool:
	if int(data.get("pack_level", 0)) >= 3:
		last_error = "Backpack already has all three upgrades."
		return false
	if int(data.coins) < 50:
		last_error = "An expedition pays enough for an upgrade. You need 50 Starlight."
		return false
	return transact(
		func():
			data.coins -= 50
			data.pack_level = int(data.get("pack_level", 0)) + 1
	)
