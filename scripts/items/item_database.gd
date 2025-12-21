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
	items["jacket_blue"] = _create_item("jacket_blue", "파란 재킷", "jacket", Color(0.2, 0.4, 0.8), true)
	items["jacket_red"] = _create_item("jacket_red", "빨간 재킷", "jacket", Color(0.9, 0.2, 0.2))
	items["jacket_green"] = _create_item("jacket_green", "초록 재킷", "jacket", Color(0.2, 0.8, 0.3))
	items["jacket_yellow"] = _create_item("jacket_yellow", "노란 재킷", "jacket", Color(0.9, 0.9, 0.2))
	items["jacket_black"] = _create_item("jacket_black", "검은 재킷", "jacket", Color(0.1, 0.1, 0.1))
	items["jacket_white"] = _create_item("jacket_white", "흰색 재킷", "jacket", Color(0.95, 0.95, 0.95))
	items["jacket_purple"] = _create_item("jacket_purple", "보라 재킷", "jacket", Color(0.6, 0.2, 0.8))
	items["jacket_orange"] = _create_item("jacket_orange", "주황 재킷", "jacket", Color(1.0, 0.6, 0.2))
	items["jacket_pink"] = _create_item("jacket_pink", "분홍 재킷", "jacket", Color(1.0, 0.4, 0.7))

	# === 3D 모델 예시 (주석 처리됨) ===
	# items["jacket_leather"] = _create_item("jacket_leather", "가죽 재킷", "jacket", Color(0.3, 0.2, 0.1), false, false, "res://assets/models/jackets/jacket_leather.glb")
	# items["jacket_puffy"] = _create_item("jacket_puffy", "패딩 재킷", "jacket", Color(0.1, 0.1, 0.1), false, false, "res://assets/models/jackets/jacket_puffy.glb")

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

	# === Poles (폴) ===
	items["none_pole"] = _create_item("none_pole", "착용 안 함", "pole", Color(0, 0, 0, 0), false, true)
	items["pole_grey"] = _create_item("pole_grey", "회색 폴", "pole", Color(0.3, 0.3, 0.3), true)
	items["pole_red"] = _create_item("pole_red", "빨간 폴", "pole", Color(0.9, 0.2, 0.2))
	items["pole_blue"] = _create_item("pole_blue", "파란 폴", "pole", Color(0.2, 0.4, 0.9))
	items["pole_black"] = _create_item("pole_black", "검은 폴", "pole", Color(0.1, 0.1, 0.1))
	items["pole_yellow"] = _create_item("pole_yellow", "노란 폴", "pole", Color(0.95, 0.95, 0.2))
	items["pole_green"] = _create_item("pole_green", "초록 폴", "pole", Color(0.2, 0.8, 0.3))
	items["pole_white"] = _create_item("pole_white", "흰색 폴", "pole", Color(0.95, 0.95, 0.95))
	items["pole_purple"] = _create_item("pole_purple", "보라 폴", "pole", Color(0.6, 0.2, 0.8))
	items["pole_orange"] = _create_item("pole_orange", "주황 폴", "pole", Color(1.0, 0.6, 0.2))

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
		"res://assets/models/helmets/rodolph_helmet_thumnail.png"  # 썸네일 경로
	)
	items["helmet_white"] = _create_item("helmet_white", "흰색 헬멧", "helmet", Color(1.0, 0.95, 0.9), true)
	items["helmet_black"] = _create_item("helmet_black", "검은 헬멧", "helmet", Color(0.1, 0.1, 0.1))
	items["helmet_red"] = _create_item("helmet_red", "빨간 헬멧", "helmet", Color(0.9, 0.2, 0.2))
	items["helmet_blue"] = _create_item("helmet_blue", "파란 헬멧", "helmet", Color(0.2, 0.4, 0.9))
	items["helmet_yellow"] = _create_item("helmet_yellow", "노란 헬멧", "helmet", Color(0.95, 0.95, 0.2))
	items["helmet_green"] = _create_item("helmet_green", "초록 헬멧", "helmet", Color(0.2, 0.8, 0.3))
	items["helmet_purple"] = _create_item("helmet_purple", "보라 헬멧", "helmet", Color(0.6, 0.2, 0.8))
	items["helmet_orange"] = _create_item("helmet_orange", "주황 헬멧", "helmet", Color(1.0, 0.6, 0.2))
	items["helmet_pink"] = _create_item("helmet_pink", "분홍 헬멧", "helmet", Color(1.0, 0.4, 0.7))


func _create_item(id: String, name: String, category: String, color: Color, is_default: bool = false, is_none: bool = false, mesh_path: String = "", thumbnail_path: String = "") -> Dictionary:
	return {
		"id": id,  # Use provided ID (should match Dictionary key)
		"name": name,
		"category": category,
		"color": color,
		"is_default": is_default,
		"is_unlocked": true,
		"is_none": is_none,  # "착용 안 함" 아이템 표시
		"mesh_path": mesh_path,  # 3D 모델 파일 경로 (비어있으면 색상만 변경)
		"thumbnail_path": thumbnail_path  # 썸네일 이미지 경로 (옷장 화면에 표시)
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
