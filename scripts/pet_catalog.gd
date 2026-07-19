extends RefCounted

const ACTIVE_DESKTOP_PETS := [
	"pet1", "pet2", "pet3", "pet4", "pet5", "pet6", "pet7",
	"pet8", "pet9", "pet10"
]
const STARTER_UNLOCKED_PETS := ["pet1"]
const GACHA_PETS := [
	"pet2", "pet3", "pet4", "pet5", "pet6", "pet7",
	"pet8", "pet9", "pet10"
]
const INVENTORY_STARTER_PETS := STARTER_UNLOCKED_PETS

const BASE_COMBAT_POWER := {
	"pet1": 12.0, "pet2": 17.0, "pet3": 22.0, "pet4": 28.0,
	"pet5": 34.0, "pet6": 40.0, "pet7": 45.0, "pet8": 52.0,
	"pet9": 60.0, "pet10": 70.0
}

const EVOLUTION_POWER_MULTIPLIER := 1.85
const EVOLUTION_PRODUCTION_MULTIPLIER := 1.5

const ENGLISH_METADATA := {
	"pet1": {
		"name": "Fungal Kin",
		"species": "Aberrant Kin",
		"description": "A low-crawling fungal kin that steadily gathers faith.",
		"personality": "Quiet and cautious. It rests near the taskbar and occasionally changes its spot."
	},
	"pet2": {
		"name": "Abyssal Gaze",
		"species": "Abyssal Kin",
		"description": "A great-eyed abyssal kin whose stare draws in stronger faith.",
		"personality": "Drowsy and gentle. It sometimes hides near desktop folders before suddenly reappearing."
	},
	"pet3": {
		"name": "Burrowing Whelp",
		"species": "Burrow Kin",
		"description": "A shy whelp that slips into shadows and gathers faith beneath the ground.",
		"personality": "Curious but timid. It stays near the taskbar and occasionally burrows for a moment."
	},
	"pet4": {
		"name": "Star-Sea Crawler",
		"species": "Star-Sea Kin",
		"description": "A soft creature from between the stars. Slow steps amplify its whispers.",
		"personality": "Quiet and observant. It can stare at the same icon for a very long time."
	},
	"pet5": {
		"name": "Moonshadow Maw",
		"species": "Dream-Eater Kin",
		"description": "A strange being that devours nightmares and moonlight, spreading potent faith after a meal.",
		"personality": "Bold but calm. It guards the taskbar and occasionally rolls along the screen edge."
	},
	"pet6": {
		"name": "Deep-Sea Lurker",
		"species": "Humanoid Deep-Sea Kin",
		"description": "A humanoid kin that crouches in desktop corners, like an old coat left behind.",
		"personality": "Taciturn and sleepy. It prefers quiet corners beside the taskbar."
	},
	"pet7": {
		"name": "Abyss-Gazing Coin",
		"species": "Living Coin",
		"age": "Age unknown",
		"description": "An ancient coin etched with kin sigils. It rests by the taskbar and rolls in its travel direction.",
		"personality": "Silent and steady. It usually stays put, then rolls a short distance along the taskbar."
	},
	"pet8": {
		"name": "Spiked Gear Eye",
		"species": "Stargate Kin",
		"description": "A floating eye in a spiked shell, gliding quietly across the desktop without limbs.",
		"personality": "Alert and restrained. It enjoys slow patrols through the air."
	},
	"pet9": {
		"name": "Floating Obelisk",
		"species": "Deep-Space Relic",
		"age": "Age unknown",
		"description": "A tentacled triangular obelisk that floats instead of walking.",
		"personality": "Taciturn and aloof. It occasionally crosses the desktop at high altitude."
	},
	"pet10": {
		"name": "Juvenile Vortex Core",
		"species": "Living Singularity",
		"age": "Birth date unknown",
		"description": "A conscious miniature vortex whose center flickers with an unformed cluster of stars.",
		"personality": "Curious and dangerous. It quietly drifts around the other kin."
	}
}

const ENGLISH_EVOLUTION_NAMES := {
	"pet1": "Fungal Broodmother",
	"pet2": "Void Gaze Watcher",
	"pet3": "Bone Burrower",
	"pet4": "Deep-Tide Devourer",
	"pet5": "Eclipsed Crawler",
	"pet6": "Deep-Sea Lurker Lord",
	"pet7": "Ancient Coin Demon Disc",
	"pet8": "Spiked Gear Celestial Eye",
	"pet9": "Crowned Obelisk",
	"pet10": "World-Eating Vortex Core"
}

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
		"frame_foot_y": 110,
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
		"walk": "res://assets/NewCharacters/pet1/pet1Walk.png",
		"attack": "res://assets/NewCharacters/pet1/pet1Attack.png",
		"attack_columns": 4,
		"attack_rows": 3,
		"attack_align_to_floor": false,
		"faces_right": true,
		"attack_faces_right": true
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
		"frame_foot_y": 106,
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
		"walk": "res://assets/NewCharacters/pet2/pet2Idle.png",
		"attack": "res://assets/NewCharacters/pet2/pet2Idle.png",
		"attack_align_to_floor": false,
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
		"frame_foot_y": 109,
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
		"attack_rows": 3,
		"attack_faces_right": true,
		"attack_frame_foot_y": 172,
		"burrow": "res://assets/NewCharacters/pet3/pet3Burrow.png"
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
		"frame_foot_y": 111,
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
		"attack_faces_right": true,
		"attack_frame_foot_y": 172,
		"attack_align_to_floor": true
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
		"desktop_scale": 0.90,
		"behavior": "roller",
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
		"wall_chance": 0.0,
		"can_wall_crawl": false,
		"rolls_while_walking": true,
		"walk_rotation_speed": 5.6,
		"special_time_min": 1.0,
		"special_time_max": 4.0,
		"frame_center_y": 64.0,
		"frame_foot_y": 121,
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
		"idle": "res://assets/NewCharacters/pet5/pet5_Idle_Walk_Attack.png",
		"walk": "res://assets/NewCharacters/pet5/pet5_Idle_Walk_Attack.png",
		"attack": "res://assets/NewCharacters/pet5/pet5_Idle_Walk_Attack.png",
		"idle_frame_indices": [0],
		"attack_columns": 4,
		"attack_rows": 3,
		"align_frames_to_floor": false,
		"attack_align_to_floor": false,
		"attack_faces_right": true
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
		"frame_center_y": 64.0,
		"frame_foot_y": 106,
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
		"attack": "res://assets/NewCharacters/pet6/pet6Attack.png",
		"attack_columns": 4,
		"attack_rows": 3,
		"faces_right": false,
		"attack_faces_right": false,
		# pet6's authored strike reaches far beyond its compact idle body. Battle
		# proximity is measured from actor origins, so use the visible strike reach
		# instead of the generic small-pet melee radius.
		"battle_attack_range": 320.0,
		"attack_align_to_floor": false,
		"attack_frame_foot_y": 175
	},
	"pet7": {
		"id": "pet7",
		"name": "窥渊古币",
		"species": "活体钱币",
		"description": "刻着眷族纹样的古币，静止时贴在任务栏边，移动时会朝前进方向滚动。",
		"rarity_stars": 5,
		"age": "年代无法考证",
		"personality": "沉默、稳重，大部分时间原地待着，偶尔沿任务栏滚一段路。",
		"desktop_scale": 0.70,
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
		"frame_center_y": 64.0,
		"frame_foot_y": 126,
		"ground_offset_y": 0.0,
		"ambient_emotion_interval_min": 190.0,
		"ambient_emotion_interval_max": 300.0,
		"emotion_weights": {"confused": 0.40, "suprised": 0.30, "happy": 0.20, "sleepy": 0.10},
		"petting_emotion_weights": {"suprised": 0.42, "happy": 0.30, "confused": 0.20, "sleepy": 0.08},
		"upgrade_cost_base": 90,
		"upgrade_cost_growth": 1.18,
		"base_fps": 0.16,
		"power_growth": 1.035,
		"icon": "res://assets/NewCharacters/pet7/pet7.png",
		"idle": "res://assets/NewCharacters/pet7/pet7Idle_Walk_Attack.png",
		"walk": "res://assets/NewCharacters/pet7/pet7Idle_Walk_Attack.png",
		"attack": "res://assets/NewCharacters/pet7/pet7Idle_Walk_Attack.png",
		"attack_align_to_floor": false
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
		"frame_foot_y": 126,
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
		"idle": "res://assets/NewCharacters/pet8/pet8Idle_Walk_Attack.png",
		"walk": "res://assets/NewCharacters/pet8/pet8Idle_Walk_Attack.png",
		"attack": "res://assets/NewCharacters/pet8/pet8Idle_Walk_Attack.png",
		"attack_align_to_floor": false
	},
	"pet9": {
		"id": "pet9",
		"name": "浮游尖碑",
		"species": "深空遗物",
		"description": "长出触须的三棱尖碑，以漂浮代替步行。",
		"rarity_stars": 4,
		"age": "年代无法测定",
		"personality": "寡言、冷淡，偶尔沿高处横穿桌面。",
		"desktop_scale": 1.00,
		"behavior": "sleepy_floater",
		"walk_speed": 22.0,
		"walk_speed_variance": 2.0,
		"walk_distance_min": 110.0,
		"walk_distance_max": 260.0,
		"activity_chance": 0.14,
		"idle_time_min": 13.0,
		"idle_time_max": 26.0,
		"special_chance": 0.0,
		"doze_chance": 0.0,
		"hide_chance": 0.0,
		"can_hide": false,
		"can_wall_crawl": false,
		"frame_center_y": 64.0,
		"frame_foot_y": 120,
		"align_frames_to_floor": false,
		"ground_offset_y": -72.0,
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
		"idle": "res://assets/NewCharacters/pet9/pet9Idle_Walk_Attack.png",
		"walk": "res://assets/NewCharacters/pet9/pet9Idle_Walk_Attack.png",
		"attack": "res://assets/NewCharacters/pet9/pet9Idle_Walk_Attack.png",
		"attack_align_to_floor": false
	},
	"pet10": {
		"id": "pet10",
		"name": "幼生涡核",
		"species": "活体奇点",
		"description": "一枚有意识的微型涡核，中心闪烁着尚未成形的星群。",
		"rarity_stars": 4,
		"age": "诞生时间未知",
		"personality": "好奇且危险，喜欢安静地绕着其他眷族漂游。",
		"desktop_scale": 0.68,
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
		"frame_foot_y": 125,
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
		"idle": "res://assets/NewCharacters/pet10/pet10Idle_Walk_Attack.png",
		"walk": "res://assets/NewCharacters/pet10/pet10Idle_Walk_Attack.png",
		"attack": "res://assets/NewCharacters/pet10/pet10Idle_Walk_Attack.png",
		"idle_skip_empty_frames": true,
		"walk_skip_empty_frames": true,
		"attack_skip_empty_frames": true,
		"attack_align_to_floor": false
	}
}

# Evolution overrides are deliberately complete for animation-specific fields.
# Empty paths prevent an evolved form from accidentally borrowing incompatible
# sleep/burrow sheets from its smaller base form.
const EVOLUTION_DEFINITIONS := {
	"pet1": {
		"evolution_name": "腐生母巢",
		"icon": "res://assets/NewCharacters/pet1/pet1Evolved/pet1Evolved.png",
		"idle": "res://assets/NewCharacters/pet1/pet1Evolved/pet1EvolvedIdle.png",
		"walk": "res://assets/NewCharacters/pet1/pet1Evolved/pet1EvolvedWalk.png",
		"attack": "res://assets/NewCharacters/pet1/pet1Evolved/pet1EvolvedAttack.png",
		"closing_eye": "",
		"sleep": "",
		"burrow": "",
		"desktop_scale": 1.0,
		"frame_center_y": 64.0,
		"frame_foot_y": 101,
		"align_frames_to_floor": false,
		"attack_columns": 4,
		"attack_rows": 3,
		"attack_frame_foot_y": 209,
		"attack_align_to_floor": false,
		"faces_right": true,
		"attack_faces_right": true,
		"battle_attack_range": 245.0,
		"can_wall_crawl": false,
		"wall_chance": 0.0,
		"doze_chance": 0.0
	},
	"pet2": {
		"evolution_name": "渊空凝视者",
		"icon": "res://assets/NewCharacters/pet2/pet2Evolved/pet2Evolved.png",
		"idle": "res://assets/NewCharacters/pet2/pet2Evolved/pet2Evolved_Idle_sleep_closingEyes_Attack.png",
		"walk": "res://assets/NewCharacters/pet2/pet2Evolved/pet2Evolved_Idle_sleep_closingEyes_Attack.png",
		"attack": "res://assets/NewCharacters/pet2/pet2Evolved/pet2Evolved_Idle_sleep_closingEyes_Attack.png",
		"closing_eye": "res://assets/NewCharacters/pet2/pet2Evolved/pet2Evolved_Idle_sleep_closingEyes_Attack.png",
		"sleep": "res://assets/NewCharacters/pet2/pet2Evolved/pet2Evolved_Idle_sleep_closingEyes_Attack.png",
		"burrow": "",
		"desktop_scale": 0.68,
		"frame_center_y": 64.0,
		"frame_foot_y": 102,
		"align_frames_to_floor": false,
		"attack_columns": 4,
		"attack_rows": 3,
		"attack_align_to_floor": false,
		"closing_eye_columns": 4,
		"closing_eye_rows": 3,
		"sleep_columns": 4,
		"sleep_rows": 3,
		"sleep_skip_empty_frames": false,
		"faces_right": false,
		"attack_faces_right": false,
		"doze_chance": 0.0,
		"hide_chance": 0.0,
		"can_hide": false,
		"special_chance": 0.0
	},
	"pet3": {
		"evolution_name": "白骨掘行者",
		"icon": "res://assets/NewCharacters/pet3/pet3Evolved/pet3Evolved.png",
		"idle": "res://assets/NewCharacters/pet3/pet3Evolved/pet3EvolvedIdle.png",
		"walk": "res://assets/NewCharacters/pet3/pet3Evolved/pet3EvolvedWalk.png",
		"attack": "res://assets/NewCharacters/pet3/pet3Evolved/pet3EvolvedAttack.png",
		"burrow": "res://assets/NewCharacters/pet3/pet3Evolved/pet3EvolvedBurrow.png",
		"closing_eye": "",
		"sleep": "",
		"desktop_scale": 1.0,
		"frame_center_y": 64.0,
		"frame_foot_y": 106,
		"align_frames_to_floor": false,
		"attack_columns": 4,
		"attack_rows": 4,
		"attack_frame_foot_y": 188,
		"attack_align_to_floor": false,
		"faces_right": false,
		"attack_faces_right": false,
		"battle_attack_range": 205.0,
		"doze_chance": 0.0
	},
	"pet4": {
		"evolution_name": "深潮巨噬体",
		"icon": "res://assets/NewCharacters/pet4/pet4Evolved/pet4Evolved.png",
		"idle": "res://assets/NewCharacters/pet4/pet4Evolved/pet4EvolvedIdle.png",
		"walk": "res://assets/NewCharacters/pet4/pet4Evolved/pet4EvolvedWalk.png",
		"attack": "res://assets/NewCharacters/pet4/pet4Evolved/pet4EvolvedAttack.png",
		"closing_eye": "",
		"sleep": "",
		"burrow": "",
		"desktop_scale": 0.82,
		"frame_center_y": 64.0,
		"frame_foot_y": 105,
		"align_frames_to_floor": false,
		"attack_columns": 4,
		"attack_rows": 3,
		"attack_align_to_floor": false,
		"faces_right": false,
		"attack_faces_right": false,
		"battle_attack_range": 235.0,
		"can_wall_crawl": false,
		"wall_chance": 0.0,
		"doze_chance": 0.0
	},
	"pet5": {
		"evolution_name": "月蚀蠕行者",
		"icon": "res://assets/NewCharacters/pet5/pet5Evolved/pet5.png",
		"idle": "res://assets/NewCharacters/pet5/pet5Evolved/pet5Idle.png",
		"walk": "res://assets/NewCharacters/pet5/pet5Evolved/pet5Walk.png",
		"attack": "res://assets/NewCharacters/pet5/pet5Evolved/pet5Attack.png",
		"closing_eye": "",
		"sleep": "",
		"burrow": "",
		"desktop_scale": 1.12,
		"frame_center_y": 64.0,
		"frame_foot_y": 102,
		"align_frames_to_floor": false,
		"attack_columns": 4,
		"attack_rows": 3,
		"attack_align_to_floor": false,
		"faces_right": false,
		"attack_faces_right": true,
		"battle_attack_range": 245.0,
		"behavior": "wanderer",
		"rolls_while_walking": false,
		"walk_rotation_speed": 0.0,
		"can_wall_crawl": false,
		"wall_chance": 0.0,
		"doze_chance": 0.0
	},
	"pet6": {
		"evolution_name": "深海潜伏领主",
		"icon": "res://assets/NewCharacters/pet6/pet6Evolved/pet6Evolved.png",
		"idle": "res://assets/NewCharacters/pet6/pet6Evolved/pet6EvolvedIdle.png",
		"walk": "res://assets/NewCharacters/pet6/pet6Evolved/pet6EvolvedWalk.png",
		"attack": "res://assets/NewCharacters/pet6/pet6Evolved/pet6EvolvedAttack.png",
		"closing_eye": "",
		"sleep": "",
		"burrow": "",
		"desktop_scale": 0.58,
		"frame_center_y": 128.0,
		"frame_foot_y": 235,
		"align_frames_to_floor": false,
		"attack_columns": 4,
		"attack_rows": 3,
		"attack_align_to_floor": false,
		"faces_right": false,
		"attack_faces_right": true,
		"battle_attack_range": 345.0,
		"can_wall_crawl": false,
		"wall_chance": 0.0,
		"doze_chance": 0.0
	},
	"pet7": {
		"evolution_name": "古币魔盘",
		"icon": "res://assets/NewCharacters/pet7/pet7Evolved/pet7Evolved.png",
		"idle": "res://assets/NewCharacters/pet7/pet7Evolved/pet7Evolved_Idle_Walk_Attack.png",
		"walk": "res://assets/NewCharacters/pet7/pet7Evolved/pet7Evolved_Idle_Walk_Attack.png",
		"attack": "res://assets/NewCharacters/pet7/pet7Evolved/pet7Evolved_Idle_Walk_Attack.png",
		"closing_eye": "",
		"sleep": "",
		"burrow": "",
		"desktop_scale": 0.54,
		"frame_center_y": 128.0,
		"frame_foot_y": 242,
		"align_frames_to_floor": false,
		"attack_columns": 4,
		"attack_rows": 3,
		"attack_align_to_floor": false,
		"faces_right": false,
		"attack_faces_right": false,
		"doze_chance": 0.0
	},
	"pet8": {
		"evolution_name": "棘轮天眼",
		"icon": "res://assets/NewCharacters/pet8/pet8Evolved/pet8Evolved.png",
		"idle": "res://assets/NewCharacters/pet8/pet8Evolved/pet8Evolved_Idle_Walk_Attack.png",
		"walk": "res://assets/NewCharacters/pet8/pet8Evolved/pet8Evolved_Idle_Walk_Attack.png",
		"attack": "res://assets/NewCharacters/pet8/pet8Evolved/pet8Evolved_Idle_Walk_Attack.png",
		"closing_eye": "",
		"sleep": "",
		"burrow": "",
		"desktop_scale": 0.98,
		"frame_center_y": 64.0,
		"frame_foot_y": 126,
		"align_frames_to_floor": false,
		"attack_columns": 4,
		"attack_rows": 3,
		"attack_align_to_floor": false,
		"faces_right": false,
		"attack_faces_right": false,
		"doze_chance": 0.0
	},
	"pet9": {
		"evolution_name": "环冠方尖碑",
		"icon": "res://assets/NewCharacters/pet9/pet9Evolved/pet9Evolved.png",
		"idle": "res://assets/NewCharacters/pet9/pet9Evolved/pet9Evolved_Idle_Walk_Attack.png",
		"walk": "res://assets/NewCharacters/pet9/pet9Evolved/pet9Evolved_Idle_Walk_Attack.png",
		"attack": "res://assets/NewCharacters/pet9/pet9Evolved/pet9Evolved_Idle_Walk_Attack.png",
		"closing_eye": "",
		"sleep": "",
		"burrow": "",
		"desktop_scale": 0.55,
		"frame_center_y": 128.0,
		"frame_foot_y": 254,
		"align_frames_to_floor": false,
		"attack_columns": 4,
		"attack_rows": 3,
		"attack_align_to_floor": false,
		"faces_right": false,
		"attack_faces_right": false,
		"doze_chance": 0.0
	},
	"pet10": {
		"evolution_name": "噬界涡核",
		"icon": "res://assets/NewCharacters/pet10/pet10Evolved/pet10Evolved.png",
		"idle": "res://assets/NewCharacters/pet10/pet10Evolved/pet10Evolved_Idle_Walk_Attack.png",
		"walk": "res://assets/NewCharacters/pet10/pet10Evolved/pet10Evolved_Idle_Walk_Attack.png",
		"attack": "res://assets/NewCharacters/pet10/pet10Evolved/pet10Evolved_Idle_Walk_Attack.png",
		"closing_eye": "",
		"sleep": "",
		"burrow": "",
		"desktop_scale": 1.02,
		"frame_center_y": 64.0,
		"frame_foot_y": 125,
		"align_frames_to_floor": false,
		"attack_columns": 4,
		"attack_rows": 3,
		"attack_align_to_floor": false,
		"faces_right": false,
		"attack_faces_right": false,
		"doze_chance": 0.0
	}
}

const SHEET_COLUMNS := 4
const SHEET_ROWS := 3
const CHROMA_KEY_TOLERANCE := 0.075

# Evolved forms may inherit gameplay behaviour, but never animation sources or
# slicing metadata from the base form.  This keeps a newly-authored evolved
# sheet from silently reusing base-only frame selections (pet5 is the clearest
# example: its base idle is a single ball frame while its evolved idle is a
# complete animation).
const EVOLUTION_ANIMATION_KEYS := [
	"idle", "walk", "attack", "closing_eye", "sleep", "burrow",
	"idle_speed", "walk_speed_fps",
	"idle_columns", "idle_rows", "idle_skip_empty_frames", "idle_frame_indices",
	"walk_columns", "walk_rows", "walk_skip_empty_frames", "walk_frame_indices",
	"attack_columns", "attack_rows", "attack_skip_empty_frames", "attack_frame_indices",
	"closing_eye_columns", "closing_eye_rows", "closing_eye_skip_empty_frames", "closing_eye_frame_indices",
	"sleep_columns", "sleep_rows", "sleep_skip_empty_frames", "sleep_frame_indices",
	"burrow_columns", "burrow_rows", "burrow_skip_empty_frames", "burrow_frame_indices",
	"frame_center_y", "frame_foot_y", "align_frames_to_floor",
	"attack_frame_foot_y", "attack_align_to_floor",
	"faces_right", "attack_faces_right"
]

static var _frame_cache := {}
static var _icon_texture_cache := {}
static var _runtime_definition_cache := {}


static func get_definition(pet_id: String) -> Dictionary:
	if DEFINITIONS.has(pet_id):
		return DEFINITIONS[pet_id]

	return DEFINITIONS[ACTIVE_DESKTOP_PETS[0]]


static func get_localized_field(pet_id: String, field: String, language_code: String) -> String:
	var definition := get_definition(pet_id)
	if language_code != "zh":
		var english_value: Variant = ENGLISH_METADATA.get(pet_id, {}).get(field, "")
		if not String(english_value).is_empty():
			return String(english_value)
	return String(definition.get(field, pet_id if field == "name" else ""))


static func get_localized_name(pet_id: String, language_code: String) -> String:
	return get_localized_field(pet_id, "name", language_code)


static func get_localized_evolution_name(pet_id: String, language_code: String) -> String:
	if language_code != "zh":
		var english_name := String(ENGLISH_EVOLUTION_NAMES.get(pet_id, ""))
		if not english_name.is_empty():
			return english_name
	return String(get_evolution_definition(pet_id).get("evolution_name", get_localized_name(pet_id, language_code)))


static func has_evolution(pet_id: String) -> bool:
	return EVOLUTION_DEFINITIONS.has(pet_id)


static func can_evolve(pet_id: String) -> bool:
	return has_evolution(pet_id)


static func get_evolution_definition(pet_id: String) -> Dictionary:
	return EVOLUTION_DEFINITIONS.get(pet_id, {})


static func get_runtime_definition(pet_id: String, evolved := false) -> Dictionary:
	var cache_key := "%s:%s" % [pet_id, "evolved" if evolved else "base"]
	var cached_value: Variant = _runtime_definition_cache.get(cache_key, null)
	if cached_value is Dictionary:
		return cached_value
	var runtime_definition := get_definition(pet_id).duplicate(true)
	if evolved and has_evolution(pet_id):
		for animation_key in EVOLUTION_ANIMATION_KEYS:
			runtime_definition.erase(animation_key)
		runtime_definition.merge(get_evolution_definition(pet_id), true)
		runtime_definition["evolved"] = true
	runtime_definition.make_read_only()
	_runtime_definition_cache[cache_key] = runtime_definition
	return runtime_definition


static func get_combat_power(pet_id: String, level := 1, evolved := false) -> float:
	var base_power := float(BASE_COMBAT_POWER.get(pet_id, 10.0))
	var safe_level := maxi(1, level)
	var result := base_power * (1.0 + log(float(safe_level)) / log(10.0) * 0.32)
	return result * (EVOLUTION_POWER_MULTIPLIER if evolved and can_evolve(pet_id) else 1.0)


static func make_inventory_entry(pet_id: String, language_code := "en") -> Dictionary:
	var pet_data := get_definition(pet_id)
	return {
		"id": String(pet_data.get("id", pet_id)),
		"name": get_localized_name(pet_id, language_code),
		"texture": String(pet_data.get("icon", ""))
	}


static func make_inventory_entries(pet_ids: Array, language_code := "en") -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for pet_id in pet_ids:
		entries.append(make_inventory_entry(String(pet_id), language_code))
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


static func build_frames(pet_id: String, evolved := false) -> SpriteFrames:
	var cache_key := "%s:%s" % [pet_id, "evolved" if evolved else "base"]
	var cached_frames := _frame_cache.get(cache_key) as SpriteFrames
	if cached_frames != null:
		return cached_frames

	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")

	var pet_data := get_runtime_definition(pet_id, evolved)
	var frame_foot_y := int(pet_data.get("frame_foot_y", 102))
	var align_frames_to_floor := bool(pet_data.get("align_frames_to_floor", true))
	_add_sheet_animation(
		frames,
		"idle",
		String(pet_data.get("idle", "")),
		float(pet_data.get("idle_speed", 4.8)),
		frame_foot_y,
		align_frames_to_floor,
		maxi(1, int(pet_data.get("idle_columns", SHEET_COLUMNS))),
		maxi(1, int(pet_data.get("idle_rows", SHEET_ROWS))),
		true,
		bool(pet_data.get("idle_skip_empty_frames", false)),
		pet_data.get("idle_frame_indices", []) as Array
	)
	_add_sheet_animation(
		frames,
		"walk",
		String(pet_data.get("walk", "")),
		float(pet_data.get("walk_speed_fps", 9.0)),
		frame_foot_y,
		align_frames_to_floor,
		maxi(1, int(pet_data.get("walk_columns", SHEET_COLUMNS))),
		maxi(1, int(pet_data.get("walk_rows", SHEET_ROWS))),
		true,
		bool(pet_data.get("walk_skip_empty_frames", false)),
		pet_data.get("walk_frame_indices", []) as Array
	)
	_add_sheet_animation(
		frames,
		"attack",
		String(pet_data.get("attack", "")),
		12.0,
		int(pet_data.get("attack_frame_foot_y", frame_foot_y)),
		bool(pet_data.get("attack_align_to_floor", align_frames_to_floor)),
		maxi(1, int(pet_data.get("attack_columns", SHEET_COLUMNS))),
		maxi(1, int(pet_data.get("attack_rows", SHEET_ROWS))),
		false,
		true,
		pet_data.get("attack_frame_indices", []) as Array
	)
	_add_sheet_animation(
		frames, "close_eye", String(pet_data.get("closing_eye", "")), 10.0,
		frame_foot_y, align_frames_to_floor,
		maxi(1, int(pet_data.get("closing_eye_columns", 4))),
		maxi(1, int(pet_data.get("closing_eye_rows", 4))), false,
		bool(pet_data.get("closing_eye_skip_empty_frames", false)),
		pet_data.get("closing_eye_frame_indices", []) as Array
	)
	_add_sheet_animation(
		frames, "sleep", String(pet_data.get("sleep", "")), 3.5,
		frame_foot_y, align_frames_to_floor,
		maxi(1, int(pet_data.get("sleep_columns", 4))),
		maxi(1, int(pet_data.get("sleep_rows", 2))), true,
		bool(pet_data.get("sleep_skip_empty_frames", true)),
		pet_data.get("sleep_frame_indices", []) as Array
	)
	_add_sheet_animation(
		frames, "burrow", String(pet_data.get("burrow", "")), 9.0,
		frame_foot_y, align_frames_to_floor,
		maxi(1, int(pet_data.get("burrow_columns", 4))),
		maxi(1, int(pet_data.get("burrow_rows", 3))), false,
		bool(pet_data.get("burrow_skip_empty_frames", false)),
		pet_data.get("burrow_frame_indices", []) as Array
	)
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

	_frame_cache[cache_key] = frames
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
	skip_empty_frames := false,
	frame_indices: Array = []
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
	var key_color := source_image.get_pixel(0, 0)
	_apply_chroma_key(source_image, key_color)
	var frame_size := Vector2i(
		int(source_image.get_width() / float(columns)),
		int(source_image.get_height() / float(rows))
	)

	if not frames.has_animation(animation_name):
		frames.add_animation(animation_name)

	frames.set_animation_loop(animation_name, loop)
	frames.set_animation_speed(animation_name, speed)

	var ordered_indices: Array[int] = []
	if frame_indices.is_empty():
		for frame_index in columns * rows:
			ordered_indices.append(frame_index)
	else:
		for frame_index_value in frame_indices:
			var frame_index := int(frame_index_value)
			if frame_index >= 0 and frame_index < columns * rows:
				ordered_indices.append(frame_index)

	for frame_index in ordered_indices:



		var row := int(frame_index / columns)
		var column := frame_index % columns
		var frame_image := Image.create_empty(frame_size.x, frame_size.y, false, Image.FORMAT_RGBA8)
		var source_rect := Rect2i(Vector2i(column * frame_size.x, row * frame_size.y), frame_size)
		frame_image.blit_rect(source_image, source_rect, Vector2i.ZERO)
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
	if image == null or image.is_empty():
		return
	image.convert(Image.FORMAT_RGBA8)
	var pixels := image.get_data()
	var key_r := roundi(key_color.r * 255.0)
	var key_g := roundi(key_color.g * 255.0)
	var key_b := roundi(key_color.b * 255.0)
	var tolerance_squared := CHROMA_KEY_TOLERANCE * CHROMA_KEY_TOLERANCE * 255.0 * 255.0
	for byte_index in range(0, pixels.size(), 4):
		var dr := int(pixels[byte_index]) - key_r
		var dg := int(pixels[byte_index + 1]) - key_g
		var db := int(pixels[byte_index + 2]) - key_b
		if float(dr * dr + dg * dg + db * db) <= tolerance_squared:
			pixels[byte_index + 3] = 0
	image.set_data(image.get_width(), image.get_height(), false, Image.FORMAT_RGBA8, pixels)


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
