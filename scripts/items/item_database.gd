extends Node

## Item Database - Autoload singleton
## Manages all available items for player customization

var items: Dictionary = {}

func _ready() -> void:
	_load_default_items()
	print("[ItemDatabase] Loaded %d items" % items.size())


func _load_default_items() -> void:
	# === Jackets (재킷) ===
	items["none_jacket"] = _create_item("none_jacket", "착용 안 함", "jacket", Color(0, 0, 0, 0), false, true)
	items["jacket_red"] = _create_item("jacket_red", "빨간 재킷", "jacket", Color(0.9, 0.2, 0.2))

	# === Skis (스키) ===
	items["none_ski"] = _create_item("none_ski", "착용 안 함", "ski", Color(0, 0, 0, 0), false, true)
	items["ski_red"] = _create_item("ski_red", "빨간 스키", "ski", Color(0.9, 0.1, 0.1), true)
	items["ski_blue"] = _create_item("ski_blue", "파란 스키", "ski", Color(0.2, 0.4, 0.9))
	items["ski_black"] = _create_item("ski_black", "검은 스키", "ski", Color(0.1, 0.1, 0.1))
	items["ski_yellow"] = _create_item("ski_yellow", "노란 스키", "ski", Color(0.95, 0.95, 0.2))
	items["ski_green"] = _create_item("ski_green", "초록 스키", "ski", Color(0.2, 0.8, 0.3))
	items["ski_white"] = _create_item("ski_white", "흰색 스키", "ski", Color(0.95, 0.95, 0.95))
	items["ski_purple"] = _create_item("ski_purple", "보라 스키", "ski", Color(0.6, 0.2, 0.8))
	items["ski_orange"] = _create_item("ski_orange", "주황 스키", "ski", Color(1.0, 0.6, 0.2))
	items["ski_pink"] = _create_item("ski_pink", "분홍 스키", "ski", Color(1.0, 0.4, 0.7))
	items["ski_pink2"] = _create_item("ski_pink2", "분홍 스키", "ski", Color(1.0, 0.4, 0.7))
	items["ski_pink3"] = _create_item("ski_pink3", "분홍 스키", "ski", Color(1.0, 0.4, 0.7))

	# === Poles (폴) ===
	items["none_pole"] = _create_item("none_pole", "착용 안 함", "pole", Color(0, 0, 0, 0), false, true)

	# === Helmets (헬멧) ===
	items["none_helmet"] = _create_item("none_helmet", "착용 안 함", "helmet", Color(0, 0, 0, 0), false, true)
	items["rudolph_helmet"] = _create_item(
		"rudolph_helmet",                                    # ID (Dictionary 키와 동일)
		"루돌프 헬멧",                                    # 표시 이름
		"helmet",                                        # 카테고리
		Color(1.0, 0.0, 0.0),                            # 기본 색상 (폴백용)
		true,                                            # 기본 아이템 여부
		false,                                           # "착용 안 함" 여부
		"res://assets/models/helmets/rudolph_helmet.glb",        # 모델 파일 경로
		"res://assets/models/helmets/rodolph_helmet_thumbnail.png",  # 썸네일 경로
		Vector3(0, -0.2, 0) # 위치 조정
	)
	items["rudolph2_helmet"] = _create_item(
		"rudolph2_helmet",                                    # ID (Dictionary 키와 동일)
		"루돌프2 헬멧",                                    # 표시 이름
		"helmet",                                        # 카테고리
		Color(1.0, 0.0, 0.0),                            # 기본 색상 (폴백용)
		true,                                            # 기본 아이템 여부
		false,                                           # "착용 안 함" 여부
		"res://assets/models/helmets/rudolph2_helmet.glb",        # 모델 파일 경로
		"res://assets/models/helmets/rodolph2_helmet_thumbnail.png",  # 썸네일 경로
		Vector3(0, 0.2, 0) # 위치 조정
	)
	items["tree_helmet"] = _create_item(
		"tree_helmet",                                    # ID (Dictionary 키와 동일)
		"트리 헬멧",                                    # 표시 이름
		"helmet",                                        # 카테고리
		Color(1.0, 0.0, 0.0),                            # 기본 색상 (폴백용)
		true,                                            # 기본 아이템 여부
		false,                                           # "착용 안 함" 여부
		"res://assets/models/helmets/tree_helmet.glb",        # 모델 파일 경로
		"res://assets/models/helmets/tree_helmet_thumbnail.png",  # 썸네일 경로
		Vector3(0, -0.3, 0), # 위치 조정
		Vector3(0.6, 0.6, 0.7) # 크기 조정
	)
	items["poop_helmet"] = _create_item(
		"poop_helmet",                                    # ID (Dictionary 키와 동일)
		"똥 헬멧",                                    # 표시 이름
		"helmet",                                        # 카테고리
		Color(1.0, 0.0, 0.0),                            # 기본 색상 (폴백용)
		true,                                            # 기본 아이템 여부
		false,                                           # "착용 안 함" 여부
		"res://assets/models/helmets/poop_helmet.glb",        # 모델 파일 경로
		"res://assets/models/helmets/poop_helmet_thumbnail.png",  # 썸네일 경로
		Vector3(0, 0.2, 0), # 위치 조정
		Vector3(0.15, 0.15, 0.15)
	)
	
	items["banana_jacket"] = _create_item(
		"banana_jacket",                                    # ID (Dictionary 키와 동일)
		"바나나 자켓",                                    # 표시 이름
		"jacket",                                        # 카테고리
		Color(1.0, 0.0, 0.0),                            # 기본 색상 (폴백용)
		true,                                            # 기본 아이템 여부
		false,                                           # "착용 안 함" 여부
		"res://assets/models/helmets/banana_helmet.glb",        # 모델 파일 경로
		"res://assets/models/helmets/banana_helmet_thumbnail.png",  # 썸네일 경로
		Vector3(0, -1.35, 0), # 위치 조정
		Vector3(20, 20, 28) # 크기 조정
	)
	items["banana_helmet"] = _create_item(
		"banana_helmet",                                    # ID (Dictionary 키와 동일)
		"바나나 헬멧",                                    # 표시 이름
		"helmet",                                        # 카테고리
		Color(1.0, 0.0, 0.0),                            # 기본 색상 (폴백용)
		true,                                            # 기본 아이템 여부
		false,                                           # "착용 안 함" 여부
		"res://assets/models/helmets/banana_helmet.glb",        # 모델 파일 경로
		"res://assets/models/helmets/banana_helmet_thumbnail.png",  # 썸네일 경로
		Vector3(0, -1.8, 0), # 위치 조정
		Vector3(20, 20, 28) # 크기 조정
	)

func _create_item(id: String, name: String, category: String, color: Color, is_default: bool = false, is_none: bool = false, mesh_path: String = "", thumbnail_path: String = "", position_offset: Vector3 = Vector3(0, 0, 0), scale: Vector3 = Vector3(0.5, 0.5, 0.5)) -> Dictionary:
	return {
		"id": id,  # Use provided ID (should match Dictionary key)
		"name": name,
		"category": category,
		"color": color,
		"is_default": is_default,
		"is_unlocked": true,
		"is_none": is_none,  # "착용 안 함" 아이템 표시
		"mesh_path": mesh_path,  # 3D 모델 파일 경로 (비어있으면 색상만 변경)
		"thumbnail_path": thumbnail_path,  # 썸네일 이미지 경로 (옷장 화면에 표시)
		"position_offset": position_offset,  # Helmet position offset
		"scale": scale  # Helmet scale
	}


## Get all items in a specific category
func get_items_by_category(category: String) -> Array:
	var result: Array = []
	for item_id in items:
		var item = items[item_id]
		if item.category == category:
			result.append(item)
	return result


## Get default item for a category
func get_default_item(category: String) -> Dictionary:
	for item_id in items:
		var item = items[item_id]
		if item.category == category and item.is_default:
			return item
	# Fallback: return first item in category
	var category_items = get_items_by_category(category)
	if category_items.size() > 0:
		return category_items[0]
	return {}


## Get item by ID
func get_item(item_id: String) -> Dictionary:
	if items.has(item_id):
		return items[item_id]
	return {}
