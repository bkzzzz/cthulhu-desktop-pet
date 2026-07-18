extends RefCounted

const ACTIVE_DESKTOP_PETS := [
	"pet1", "pet2", "pet3", "pet4", "pet5", "pet6", "pet7",
	"pet8", "pet9", "pet10", "pet11"
]
const STARTER_UNLOCKED_PETS := ["pet1"]
const GACHA_PETS := [
	"pet2", "pet3", "pet4", "pet5", "pet6", "pet7",
	"pet8", "pet9", "pet10", "pet11"
]
const INVENTORY_STARTER_PETS := STARTER_UNLOCKED_PETS

const DEFINITIONS := {
	"pet1": {
		"id": "pet1",
		"name": "腐生眷族",
		"species": "异形眷族",
		"description": "伏地蠕行的腐生眷族，擅长稳定积累信仰。",
		"rarity_stars": 1,
		"age": "3岁",
		"base_age_years": 3,
		"personality": "安静谨慎，通常趴在任务栏边休息，偶尔换个位置。",
		"desktop_scale": 0.92,
		"behavior": "skitterer",
		"walk_speed": 40.0,
		"walk_speed_variance": 5.0,
		"walk_distance_min": 50.0,
		"walk_distance_max": 140.0,
		"activity_chance": 0.16,
		"idle_time_min": 8.0,
		"idle_time_max": 16.0,
		"special_chance": 0.0,
		"doze_chance": 0.10,
		"hide_chance": 0.0,
		"can_hide": false,
		"doze_time_min": 5.0,
		"doze_time_max": 11.0,
		"hide_time_min": 3.0,
		"hide_time_max": 8.0,
		"wall_chance": 0.08,
		"can_wall_crawl": true,
		"frame_center_y": 64.0,
		"frame_foot_y": 105,
		"ground_offset_y": 0.0,
		"ambient_emotion_interval_min": 150.0,
		"ambient_emotion_interval_max": 250.0,
		"emotion_weights": {"happy": 0.34, "suprised": 0.40, "confused": 0.18, "sleepy": 0.08},
		"petting_emotion_weights": {"happy": 0.38, "suprised": 0.42, "confused": 0.16, "sleepy": 0.04},
		"upgrade_cost_base": 1,
		"upgrade_cost_growth": 1.18,
		"base_fps": 0.0025,
		"power_growth": 1.035,
		"icon": "res://assets/NewCharacters/pet1/pet1.png",
		"idle": "res://assets/NewCharacters/pet1/pet1Idle.png",
		"walk": "res://assets/NewCharacters/pet1/pet1Walk.png"
	},
	"pet2": {
		"id": "pet2",
		"name": "深渊凝视",
		"species": "深渊眷族",
		"description": "睁开巨眼的深渊眷族，以凝视汇聚更强的信仰。",
		"rarity_stars": 2,
		"age": "8岁",
		"base_age_years": 8,
		"personality": "困倦而温吞，偶尔躲进桌面左侧的文件夹区域，再突然跳出来。",
		"desktop_scale": 0.62,
		"behavior": "sleepy_floater",
		"walk_speed": 20.0,
		"walk_speed_variance": 3.0,
		"walk_distance_min": 50.0,
		"walk_distance_max": 140.0,
		"activity_chance": 0.18,
		"idle_time_min": 10.0,
		"idle_time_max": 18.0,
		"special_chance": 0.18,
		"doze_chance": 0.0,
		"hide_chance": 0.35,
		"can_hide": true,
		"air_roam_chance": 0.05,
		"can_wall_crawl": false,
		"air_roam_legs_min": 2,
		"air_roam_legs_max": 5,
		"float_bob_amplitude": 30.0,
		"special_time_min": 10.0,
		"special_time_max": 24.0,
		"hide_time_min": 5.0,
		"hide_time_max": 11.0,
		"pop_distance_min": 100.0,
		"pop_distance_max": 230.0,
		"pop_height_min": 44.0,
		"pop_height_max": 78.0,
		"frame_center_y": 64.0,
		"frame_foot_y": 112,
		"ground_offset_y": -86.0,
		"faces_right": true,
		"ambient_emotion_interval_min": 160.0,
		"ambient_emotion_interval_max": 260.0,
		"emotion_weights": {"sleepy": 0.70, "confused": 0.13, "happy": 0.10, "suprised": 0.07},
		"petting_emotion_weights": {"sleepy": 0.68, "happy": 0.16, "confused": 0.12, "suprised": 0.04},
		"upgrade_cost_base": 2,
		"upgrade_cost_growth": 1.18,
		"base_fps": 0.00875,
		"power_growth": 1.035,
		"icon": "res://assets/NewCharacters/pet2/pet2.png",
		"idle": "res://assets/NewCharacters/pet2/pet2Idle.png",
		"walk": "",
		"closing_eye": "res://assets/NewCharacters/pet2/pet2ClosingEye.png",
		"sleep": "res://assets/NewCharacters/pet2/pet2Sleep.png"
	},
	"pet3": {
		"id": "pet3",
		"name": "掘地幼兽",
		"species": "穴居眷族",
		"description": "喜欢钻入阴影的穴居幼兽，会从地底收集散落的信仰。",
		"rarity_stars": 2,
		"age": "5岁",
		"base_age_years": 5,
		"personality": "好奇又怕生，大部分时间贴着任务栏休息，偶尔短暂钻地。",
		"desktop_scale": 1.08,
		"behavior": "burrower",
		"walk_speed": 32.0,
		"walk_speed_variance": 4.0,
		"walk_distance_min": 45.0,
		"walk_distance_max": 120.0,
		"activity_chance": 0.14,
		"idle_time_min": 10.0,
		"idle_time_max": 20.0,
		"special_chance": 0.08,
		"doze_chance": 0.10,
		"hide_chance": 0.0,
		"can_hide": false,
		"doze_time_min": 6.0,
		"doze_time_max": 13.0,
		"hide_time_min": 2.5,
		"hide_time_max": 6.0,
		"can_wall_crawl": false,
		"special_time_min": 1.3,
		"special_time_max": 3.6,
		"frame_center_y": 64.0,
		"frame_foot_y": 108,
		"ground_offset_y": 0.0,
		"ambient_emotion_interval_min": 150.0,
		"ambient_emotion_interval_max": 260.0,
		"emotion_weights": {"confused": 0.44, "suprised": 0.28, "happy": 0.20, "sleepy": 0.08},
		"petting_emotion_weights": {"confused": 0.48, "suprised": 0.27, "happy": 0.20, "sleepy": 0.05},
		"upgrade_cost_base": 11,
		"upgrade_cost_growth": 1.18,
		"base_fps": 0.0375,
		"power_growth": 1.035,
		"icon": "res://assets/NewCharacters/pet3/pet3.png",
		"idle": "res://assets/NewCharacters/pet3/pet3Idle.png",
		"walk": "res://assets/NewCharacters/pet3/pet3Walk.png",
		"attack": "res://assets/NewCharacters/pet3/pet3Attack.png",
		"attack_columns": 4,
		"attack_rows": 4,
		"attack_frame_foot_y": 172,
		"burrow": "res://assets/NewCharacters/pet3/pet3BurrowUnder.png"
	},
	"pet4": {
		"id": "pet4",
		"name": "星海蠕兽",
		"species": "星海眷族",
		"description": "从群星间漂来的柔软眷族，步伐迟缓却能放大低语。",
		"rarity_stars": 3,
		"age": "12岁",
		"base_age_years": 12,
		"personality": "安静且爱观察，能盯着同一个图标看上很久。",
		"desktop_scale": 0.78,
		"behavior": "watcher",
		"walk_speed": 16.0,
		"walk_speed_variance": 2.5,
		"walk_distance_min": 180.0,
		"walk_distance_max": 320.0,
		"activity_chance": 0.12,
		"idle_time_min": 14.0,
		"idle_time_max": 28.0,
		"special_chance": 0.0,
		"doze_chance": 0.28,
		"hide_chance": 0.0,
		"can_hide": false,
		"doze_time_min": 9.0,
		"doze_time_max": 22.0,
		"hide_time_min": 5.0,
		"hide_time_max": 13.0,
		"wall_chance": 0.05,
		"can_wall_crawl": true,
		"frame_center_y": 64.0,
		"frame_foot_y": 108,
		"ground_offset_y": 0.0,
		"ambient_emotion_interval_min": 170.0,
		"ambient_emotion_interval_max": 280.0,
		"emotion_weights": {"happy": 0.42, "sleepy": 0.30, "confused": 0.18, "suprised": 0.10},
		"petting_emotion_weights": {"happy": 0.46, "sleepy": 0.28, "confused": 0.18, "suprised": 0.08},
		"upgrade_cost_base": 55,
		"upgrade_cost_growth": 1.18,
		"base_fps": 0.15,
		"power_growth": 1.035,
		"icon": "res://assets/NewCharacters/pet4/pet4.png",
		"idle": "res://assets/NewCharacters/pet4/pet4Idle.png",
		"walk": "res://assets/NewCharacters/pet4/pet4Walk.png",
		"attack": "res://assets/NewCharacters/pet4/pet4Attack.png",
		"attack_columns": 4,
		"attack_rows": 3,
		"attack_frame_foot_y": 172
	},
	"pet5": {
		"id": "pet5",
		"name": "月影巨口",
		"species": "噬梦眷族",
		"description": "吞食噩梦与月光的古怪生灵，饱餐后会散播浓烈的信仰。",
		"rarity_stars": 4,
		"age": "19岁",
		"base_age_years": 19,
		"personality": "胆大但不吵闹，通常守在任务栏附近，偶尔沿屏幕边缘活动。",
		"desktop_scale": 1.25,
		"behavior": "wall_climber",
		"walk_speed": 27.0,
		"walk_speed_variance": 5.0,
		"walk_distance_min": 55.0,
		"walk_distance_max": 130.0,
		"activity_chance": 0.14,
		"idle_time_min": 12.0,
		"idle_time_max": 24.0,
		"special_chance": 0.0,
		"doze_chance": 0.12,
		"hide_chance": 0.0,
		"can_hide": false,
		"doze_time_min": 7.0,
		"doze_time_max": 16.0,
		"hide_time_min": 4.0,
		"hide_time_max": 10.0,
		"wall_chance": 0.08,
		"can_wall_crawl": true,
		"special_time_min": 1.0,
		"special_time_max": 4.0,
		"frame_center_y": 64.0,
		"frame_foot_y": 108,
		"ground_offset_y": 0.0,
		"ambient_emotion_interval_min": 160.0,
		"ambient_emotion_interval_max": 270.0,
		"emotion_weights": {"suprised": 0.42, "happy": 0.28, "confused": 0.20, "sleepy": 0.10},
		"petting_emotion_weights": {"suprised": 0.48, "happy": 0.27, "confused": 0.19, "sleepy": 0.06},
		"upgrade_cost_base": 300,
		"upgrade_cost_growth": 1.18,
		"base_fps": 0.625,
		"power_growth": 1.035,
		"icon": "res://assets/NewCharacters/pet5/pet5.png",
		"idle": "res://assets/NewCharacters/pet5/pet5Idle.png",
		"walk": "res://assets/NewCharacters/pet5/pet5Walk.png",
		"attack": "res://assets/NewCharacters/pet5/rika_d80c62be.png",
		"attack_columns": 4,
		"attack_rows": 3,
		"attack_frame_foot_y": 172
	},
	"pet6": {
		"id": "pet6",
		"name": "深海潜伏者",
		"species": "人形深海眷族",
		"description": "习惯蹲在桌面角落的人形眷族，安静时像一件被忘掉的旧外套。",
		"rarity_stars": 5,
		"age": "约27岁",
		"base_age_years": 27,
		"age_qualifier": "about",
		"personality": "寡言、嗜睡，喜欢安静地待在任务栏角落。",
		"desktop_scale": 0.58,
		"behavior": "lurker",
		"walk_speed": 23.0,
		"walk_speed_variance": 4.0,
		"walk_distance_min": 50.0,
		"walk_distance_max": 120.0,
		"activity_chance": 0.12,
		"idle_time_min": 16.0,
		"idle_time_max": 30.0,
		"special_chance": 0.0,
		"doze_chance": 0.24,
		"hide_chance": 0.0,
		"can_hide": false,
		"doze_time_min": 8.0,
		"doze_time_max": 19.0,
		"hide_time_min": 4.0,
		"hide_time_max": 12.0,
		"wall_chance": 0.0,
		"can_wall_crawl": false,
		"frame_center_y": 128.0,
		# The body/feet use y=232 as their authored contact line. The long hand
		# reaches y=236 and is intentionally allowed to extend below that line.
		"frame_foot_y": 232,
		"align_frames_to_floor": false,
		"ground_offset_y": 0.0,
		"ambient_emotion_interval_min": 180.0,
		"ambient_emotion_interval_max": 300.0,
		"emotion_weights": {"sleepy": 0.38, "confused": 0.30, "suprised": 0.22, "happy": 0.10},
		"petting_emotion_weights": {"confused": 0.36, "sleepy": 0.30, "suprised": 0.22, "happy": 0.12},
		"upgrade_cost_base": 75,
		"upgrade_cost_growth": 1.18,
		"base_fps": 0.125,
		"power_growth": 1.035,
		"icon": "res://assets/NewCharacters/pet6/pet6.png",
		"idle": "res://assets/NewCharacters/pet6/pet6Idle.png",
		"walk": "res://assets/NewCharacters/pet6/pet6Walk.png",
		"attack": "res://assets/NewCharacters/pet6/rika_72dcf180.png",
		"attack_columns": 4,
		"attack_rows": 3,
		"attack_frame_foot_y": 296
	},
	"pet7": {
		"id": "pet7",
		"name": "窥渊古币",
		"species": "活体钱币",
		"description": "刻着眷族纹样的古币，静止时贴在任务栏边，移动时会朝前进方向滚动。",
		"rarity_stars": 5,
		"age": "年代无法考证",
		"personality": "沉默、稳重，大部分时间原地待着，偶尔沿任务栏滚一段路。",
		"desktop_scale": 0.42,
		"behavior": "roller",
		"walk_speed": 55.0,
		"walk_speed_variance": 5.0,
		"walk_distance_min": 70.0,
		"walk_distance_max": 180.0,
		"activity_chance": 0.15,
		"idle_time_min": 12.0,
		"idle_time_max": 24.0,
		"special_chance": 0.0,
		"doze_chance": 0.0,
		"hide_chance": 0.0,
		"can_hide": false,
		"wall_chance": 0.0,
		"can_wall_crawl": false,
		"rolls_while_walking": true,
		"walk_rotation_speed": 5.2,
		"frame_center_y": 128.0,
		"frame_foot_y": 214,
		"ground_offset_y": 6.0,
		"ambient_emotion_interval_min": 190.0,
		"ambient_emotion_interval_max": 300.0,
		"emotion_weights": {"confused": 0.40, "suprised": 0.30, "happy": 0.20, "sleepy": 0.10},
		"petting_emotion_weights": {"suprised": 0.42, "happy": 0.30, "confused": 0.20, "sleepy": 0.08},
		"upgrade_cost_base": 90,
		"upgrade_cost_growth": 1.18,
		"base_fps": 0.16,
		"power_growth": 1.035,
		"icon": "res://assets/NewCharacters/pet7/pet7.png",
		"idle": "res://assets/NewCharacters/pet7/pet7Idle.png",
		"walk": ""
	},
	"pet8": {
		"id": "pet8",
		"name": "棘轮之眼",
		"species": "星门眷族",
		"description": "披着棘刺外壳的浮游眼球，没有肢体，会安静地滑过桌面。",
		"rarity_stars": 3,
		"age": "约31岁",
		"base_age_years": 31,
		"age_qualifier": "about",
		"personality": "警觉而克制，喜欢在半空缓慢巡游。",
		"desktop_scale": 0.98,
		"behavior": "sleepy_floater",
		"walk_speed": 24.0,
		"walk_speed_variance": 3.0,
		"walk_distance_min": 90.0,
		"walk_distance_max": 240.0,
		"activity_chance": 0.16,
		"idle_time_min": 11.0,
		"idle_time_max": 22.0,
		"special_chance": 0.0,
		"doze_chance": 0.0,
		"hide_chance": 0.0,
		"can_hide": false,
		"air_roam_chance": 0.16,
		"air_roam_legs_min": 2,
		"air_roam_legs_max": 4,
		"float_bob_amplitude": 18.0,
		"frame_center_y": 64.0,
		"frame_foot_y": 112,
		"align_frames_to_floor": false,
		"ground_offset_y": -56.0,
		"ambient_emotion_interval_min": 165.0,
		"ambient_emotion_interval_max": 270.0,
		"emotion_weights": {"confused": 0.38, "suprised": 0.30, "happy": 0.22, "sleepy": 0.10},
		"petting_emotion_weights": {"suprised": 0.38, "happy": 0.30, "confused": 0.24, "sleepy": 0.08},
		"upgrade_cost_base": 140,
		"upgrade_cost_growth": 1.18,
		"base_fps": 0.23,
		"power_growth": 1.035,
		"base_money_rate": 14.0,
		"icon": "res://assets/NewCharacters/pet8/pet8.png",
		"idle": "res://assets/NewCharacters/pet8/pet8Idle.png",
		"walk": ""
	},
	"pet9": {
		"id": "pet9",
		"name": "环冠古根",
		"species": "远古根系眷族",
		"description": "背负环冠的古老根系，移动时会使用专门的行走姿态。",
		"rarity_stars": 4,
		"age": "至少400岁",
		"base_age_years": 400,
		"age_qualifier": "at_least",
		"personality": "沉稳而固执，会缓慢巡视自己认定的领地。",
		"desktop_scale": 1.00,
		"behavior": "watcher",
		"walk_speed": 22.0,
		"walk_speed_variance": 2.0,
		"walk_distance_min": 110.0,
		"walk_distance_max": 260.0,
		"activity_chance": 0.14,
		"idle_time_min": 13.0,
		"idle_time_max": 26.0,
		"special_chance": 0.0,
		"doze_chance": 0.12,
		"hide_chance": 0.0,
		"can_hide": false,
		"can_wall_crawl": false,
		"frame_center_y": 64.0,
		"frame_foot_y": 127,
		"ground_offset_y": 0.0,
		"ambient_emotion_interval_min": 175.0,
		"ambient_emotion_interval_max": 285.0,
		"emotion_weights": {"sleepy": 0.34, "confused": 0.28, "happy": 0.24, "suprised": 0.14},
		"petting_emotion_weights": {"happy": 0.36, "confused": 0.30, "sleepy": 0.22, "suprised": 0.12},
		"upgrade_cost_base": 220,
		"upgrade_cost_growth": 1.18,
		"base_fps": 0.34,
		"power_growth": 1.035,
		"base_money_rate": 17.0,
		"icon": "res://assets/NewCharacters/pet9/pet9.png",
		"idle": "res://assets/NewCharacters/pet9/pet9Idle.png",
		"walk": "res://assets/NewCharacters/pet9/pet9Walk.png"
	},
	"pet10": {
		"id": "pet10",
		"name": "浮游尖碑",
		"species": "深空遗物",
		"description": "长出触须的黑色尖碑，以漂浮代替步行。",
		"rarity_stars": 4,
		"age": "年代无法测定",
		"personality": "寡言、冷淡，偶尔沿高处横穿桌面。",
		"desktop_scale": 1.02,
		"behavior": "sleepy_floater",
		"walk_speed": 27.0,
		"walk_speed_variance": 3.0,
		"walk_distance_min": 120.0,
		"walk_distance_max": 300.0,
		"activity_chance": 0.15,
		"idle_time_min": 12.0,
		"idle_time_max": 24.0,
		"special_chance": 0.0,
		"doze_chance": 0.0,
		"hide_chance": 0.0,
		"can_hide": false,
		"air_roam_chance": 0.22,
		"air_roam_legs_min": 2,
		"air_roam_legs_max": 5,
		"float_bob_amplitude": 15.0,
		"frame_center_y": 64.0,
		"frame_foot_y": 110,
		"align_frames_to_floor": false,
		"ground_offset_y": -72.0,
		"ambient_emotion_interval_min": 180.0,
		"ambient_emotion_interval_max": 290.0,
		"emotion_weights": {"confused": 0.36, "sleepy": 0.28, "suprised": 0.22, "happy": 0.14},
		"petting_emotion_weights": {"confused": 0.38, "suprised": 0.28, "happy": 0.22, "sleepy": 0.12},
		"upgrade_cost_base": 360,
		"upgrade_cost_growth": 1.18,
		"base_fps": 0.50,
		"power_growth": 1.035,
		"base_money_rate": 20.0,
		"icon": "res://assets/NewCharacters/pet10/pet10.png",
		"idle": "res://assets/NewCharacters/pet10/pet10Idle.png",
		"walk": ""
	},
	"pet11": {
		"id": "pet11",
		"name": "噬界涡核",
		"species": "活体奇点",
		"description": "一枚有意识的微型涡核，偶尔会把其他宠物吸入体内，再过一会吐出来。",
		"rarity_stars": 5,
		"age": "诞生时间未知",
		"personality": "好奇且危险，把同伴短暂吞进去似乎只是它的游戏。",
		"desktop_scale": 1.10,
		"behavior": "sleepy_floater",
		"walk_speed": 25.0,
		"walk_speed_variance": 3.0,
		"walk_distance_min": 100.0,
		"walk_distance_max": 260.0,
		"activity_chance": 0.13,
		"idle_time_min": 14.0,
		"idle_time_max": 27.0,
		"special_chance": 0.0,
		"doze_chance": 0.0,
		"hide_chance": 0.0,
		"can_hide": false,
		"air_roam_chance": 0.16,
		"air_roam_legs_min": 2,
		"air_roam_legs_max": 4,
		"float_bob_amplitude": 13.0,
		"frame_center_y": 64.0,
		"frame_foot_y": 111,
		"align_frames_to_floor": false,
		"ground_offset_y": -82.0,
		"ambient_emotion_interval_min": 190.0,
		"ambient_emotion_interval_max": 310.0,
		"emotion_weights": {"suprised": 0.40, "confused": 0.30, "happy": 0.20, "sleepy": 0.10},
		"petting_emotion_weights": {"happy": 0.36, "suprised": 0.34, "confused": 0.24, "sleepy": 0.06},
		"upgrade_cost_base": 600,
		"upgrade_cost_growth": 1.18,
		"base_fps": 0.80,
		"power_growth": 1.035,
		"base_money_rate": 26.0,
		"icon": "res://assets/NewCharacters/pet11/pet11.png",
		"idle": "res://assets/NewCharacters/pet11/pet11Idle.png",
		"walk": ""
	}
}

const SHEET_COLUMNS := 4
const SHEET_ROWS := 3
const CHROMA_KEY_TOLERANCE := 0.075

static var _frame_cache := {}
static var _icon_texture_cache := {}


static func get_definition(pet_id: String) -> Dictionary:
	if DEFINITIONS.has(pet_id):
		return DEFINITIONS[pet_id]

	return DEFINITIONS[ACTIVE_DESKTOP_PETS[0]]


static func make_inventory_entry(pet_id: String) -> Dictionary:
	var pet_data := get_definition(pet_id)
	return {
		"id": String(pet_data.get("id", pet_id)),
		"name": String(pet_data.get("name", pet_id)),
		"texture": String(pet_data.get("icon", ""))
	}


static func make_inventory_entries(pet_ids: Array) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for pet_id in pet_ids:
		entries.append(make_inventory_entry(String(pet_id)))
	return entries


static func choose_weighted_emotion(pet_id: String, unit_roll: float, weights_key := "emotion_weights") -> String:
	var weights_value: Variant = get_definition(pet_id).get(weights_key, {})
	if not weights_value is Dictionary:
		return "happy"
	var weights: Dictionary = weights_value
	var total := 0.0
	for emotion_value in weights:
		total += maxf(0.0, float(weights[emotion_value]))
	if total <= 0.0:
		return "happy"

	var target := clampf(unit_roll, 0.0, 0.999999) * total
	var accumulated := 0.0
	for emotion_value in weights:
		accumulated += maxf(0.0, float(weights[emotion_value]))
		if target < accumulated:
			return String(emotion_value)
	return String(weights.keys().back())


static func build_frames(pet_id: String) -> SpriteFrames:
	var cached_frames := _frame_cache.get(pet_id) as SpriteFrames
	if cached_frames != null:
		return cached_frames

	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")

	var pet_data := get_definition(pet_id)
	var frame_foot_y := int(pet_data.get("frame_foot_y", 102))
	var align_frames_to_floor := bool(pet_data.get("align_frames_to_floor", true))
	_add_sheet_animation(frames, "idle", String(pet_data.get("idle", "")), 4.8, frame_foot_y, align_frames_to_floor)
	_add_sheet_animation(frames, "walk", String(pet_data.get("walk", "")), 9.0, frame_foot_y, align_frames_to_floor)
	_add_sheet_animation(
		frames,
		"attack",
		String(pet_data.get("attack", "")),
		12.0,
		int(pet_data.get("attack_frame_foot_y", frame_foot_y)),
		align_frames_to_floor,
		maxi(1, int(pet_data.get("attack_columns", SHEET_COLUMNS))),
		maxi(1, int(pet_data.get("attack_rows", SHEET_ROWS))),
		false,
		true
	)
	_add_sheet_animation(frames, "close_eye", String(pet_data.get("closing_eye", "")), 10.0, frame_foot_y, align_frames_to_floor, 4, 4, false)
	_add_sheet_animation(frames, "sleep", String(pet_data.get("sleep", "")), 3.5, frame_foot_y, align_frames_to_floor, 4, 2, true, true)
	_add_sheet_animation(frames, "burrow", String(pet_data.get("burrow", "")), 9.0, frame_foot_y, align_frames_to_floor, 4, 3, false)
	_add_reversed_animation(frames, "close_eye", "open_eye")
	_add_reversed_animation(frames, "burrow", "emerge")

	if not frames.has_animation("idle") or frames.get_frame_count("idle") == 0:
		frames.add_animation("idle")
		var fallback := load(String(pet_data.get("icon", ""))) as Texture2D
		if fallback != null:
			frames.add_frame("idle", fallback)
		frames.set_animation_loop("idle", true)
		frames.set_animation_speed("idle", 1.0)

	if not frames.has_animation("walk") or frames.get_frame_count("walk") == 0:
		frames.add_animation("walk")
		for index in frames.get_frame_count("idle"):
			frames.add_frame("walk", frames.get_frame_texture("idle", index))
		frames.set_animation_loop("walk", true)
		frames.set_animation_speed("walk", 1.0)

	_frame_cache[pet_id] = frames
	return frames


static func make_icon_texture(texture_path: String, padding := 8) -> Texture2D:
	# Padding only adds transparent breathing room. Reusing one crop per source avoids
	# a second full pixel scan when drawer/inventory/gacha request different padding.
	var cache_key := texture_path
	if _icon_texture_cache.has(cache_key):
		return _icon_texture_cache[cache_key] as Texture2D
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return null

	var image := texture.get_image()
	if image == null or image.is_empty():
		_icon_texture_cache[cache_key] = texture
		return texture

	image.convert(Image.FORMAT_RGBA8)
	var bounds := _get_visible_bounds(image)
	if bounds.size == Vector2i.ZERO or bounds.size == image.get_size():
		_icon_texture_cache[cache_key] = texture
		return texture

	var crop_position := Vector2i(
		maxi(0, bounds.position.x - padding),
		maxi(0, bounds.position.y - padding)
	)
	var crop_end := Vector2i(
		mini(image.get_width(), bounds.position.x + bounds.size.x + padding),
		mini(image.get_height(), bounds.position.y + bounds.size.y + padding)
	)
	var crop_size := crop_end - crop_position
	var cropped := Image.create_empty(crop_size.x, crop_size.y, false, Image.FORMAT_RGBA8)
	cropped.fill(Color(0.0, 0.0, 0.0, 0.0))
	cropped.blit_rect(image, Rect2i(crop_position, crop_size), Vector2i.ZERO)
	var icon_texture := ImageTexture.create_from_image(cropped)
	_icon_texture_cache[cache_key] = icon_texture
	return icon_texture


static func _add_sheet_animation(
	frames: SpriteFrames,
	animation_name: String,
	sheet_path: String,
	speed: float,
	frame_foot_y: int,
	align_to_floor := true,
	columns := SHEET_COLUMNS,
	rows := SHEET_ROWS,
	loop := true,
	skip_empty_frames := false
) -> void:
	if sheet_path.is_empty():
		return

	var sheet_texture := load(sheet_path) as Texture2D
	if sheet_texture == null:
		push_warning("Missing pet animation sheet: %s" % sheet_path)
		return

	var source_image := sheet_texture.get_image()
	if source_image == null or source_image.is_empty():
		push_warning("Could not read pet animation sheet: %s" % sheet_path)
		return

	source_image.convert(Image.FORMAT_RGBA8)
	var frame_size := Vector2i(
		int(source_image.get_width() / float(columns)),
		int(source_image.get_height() / float(rows))
	)
	var key_color := source_image.get_pixel(0, 0)

	if not frames.has_animation(animation_name):
		frames.add_animation(animation_name)

	frames.set_animation_loop(animation_name, loop)
	frames.set_animation_speed(animation_name, speed)

	for row in rows:
		for column in columns:
			var frame_image := Image.create_empty(frame_size.x, frame_size.y, false, Image.FORMAT_RGBA8)
			var source_rect := Rect2i(Vector2i(column * frame_size.x, row * frame_size.y), frame_size)
			frame_image.blit_rect(source_image, source_rect, Vector2i.ZERO)
			_apply_chroma_key(frame_image, key_color)
			if skip_empty_frames and _get_visible_bounds(frame_image).size == Vector2i.ZERO:
				continue
			if align_to_floor:
				frame_image = _align_frame_to_floor(frame_image, frame_foot_y)
			frames.add_frame(animation_name, ImageTexture.create_from_image(frame_image))


static func _add_reversed_animation(frames: SpriteFrames, source_name: String, target_name: String) -> void:
	if not frames.has_animation(source_name):
		return
	var frame_count := frames.get_frame_count(source_name)
	if frame_count == 0:
		return

	frames.add_animation(target_name)
	frames.set_animation_loop(target_name, false)
	frames.set_animation_speed(target_name, frames.get_animation_speed(source_name))
	for index in range(frame_count - 1, -1, -1):
		frames.add_frame(target_name, frames.get_frame_texture(source_name, index))


static func _apply_chroma_key(image: Image, key_color: Color) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var color := image.get_pixel(x, y)
			if _color_distance(color, key_color) <= CHROMA_KEY_TOLERANCE:
				color.a = 0.0
				image.set_pixel(x, y, color)


static func _align_frame_to_floor(image: Image, frame_foot_y: int) -> Image:
	var bounds := _get_visible_bounds(image)
	if bounds.size == Vector2i.ZERO:
		return image

	var visible_bottom := bounds.position.y + bounds.size.y - 1
	var offset_y := frame_foot_y - visible_bottom
	if offset_y == 0:
		return image

	var aligned := Image.create_empty(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8)
	aligned.fill(Color(0.0, 0.0, 0.0, 0.0))
	aligned.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(0, offset_y))
	return aligned


static func _get_visible_bounds(image: Image) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1

	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.02:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)

	if max_x < min_x or max_y < min_y:
		return Rect2i()

	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


static func _color_distance(a: Color, b: Color) -> float:
	var dr := a.r - b.r
	var dg := a.g - b.g
	var db := a.b - b.b
	return sqrt((dr * dr) + (dg * dg) + (db * db))
