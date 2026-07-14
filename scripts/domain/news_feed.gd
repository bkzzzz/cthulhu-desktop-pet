extends RefCounted

## Deterministic news rules and persistent history. Runtime timing and UI live in
## main.gd so this class stays headless-testable.

const MAX_HISTORY := 80
const MAX_HEADLINE_LENGTH := 220
const RECENT_TEMPLATE_LIMIT := 6
const NEWS_COPY_VERSION := 1
const AMBIENT_INTERVAL_MIN_SECONDS := 240.0
const AMBIENT_INTERVAL_MAX_SECONDS := 360.0

const VALID_CATEGORIES := ["公告", "异闻", "传播", "信仰", "宠物", "教团"]
const FAITH_RATE_MILESTONES := [
	1.0,
	5.0,
	25.0,
	100.0,
	500.0,
	2500.0,
	10000.0,
	50000.0,
	250000.0,
	1000000.0
]
const FOLLOWER_MILESTONES := [
	1,
	10,
	50,
	100,
	500,
	1000,
	5000,
	10000,
	50000,
	100000,
	500000,
	1000000
]

const PLACES := [
	"南码头",
	"旧城区菜市场",
	"地铁三号线",
	"北郊花卉市场",
	"海滨社区卫生站",
	"市政服务大厅",
	"城西居民楼",
	"中心客运站",
	"市立大学第二食堂",
	"城北政务分中心"
]

const ABSURD_TEMPLATES := [
	{"id": "absurd_sewer", "text": "市政热线记录：37名市民趴在下水道口等待神谕，环卫工已摆出9块警示牌。"},
	{"id": "absurd_dough", "text": "城南面包店有22名顾客给吐司做心肺复苏；店员已把该桌登记为团建区。"},
	{"id": "absurd_weather", "text": "气象台发布小雨预警后，61名市民带着汤锅去广场接雨；保安发出14张号码牌。"},
	{"id": "absurd_clock", "text": "地铁三号线晚点13分钟后，48名乘客在站台倒着走；保安劝停了9人。"},
	{"id": "absurd_pigeon", "text": "中心广场有29名市民穿灰衣蹲地讨要薯条；城管误发了6袋鸽粮。"},
	{"id": "absurd_library", "text": "市图书馆发现31名读者用尺子把圆形量成方形；数学区增派了2名管理员。"},
	{"id": "absurd_moon", "text": "昨夜有14户居民主动缴纳月光照明费；供电公司退回13份，只受理了1份。"},
	{"id": "absurd_well", "text": "旧城区有9名居民轮流向封井道歉，理由是上周忘记打招呼；物业提供了号码牌。"},
	{"id": "absurd_radio", "text": "52名出租车司机听完凌晨节目后把计价单位改成海里；交通部门要求当天改回公里。"},
	{"id": "absurd_elevator", "text": "海滨小区有17名住户排队乘电梯去地下130层；物业卖出11张月票后封住按钮。"}
]

const PET_TEMPLATES := [
	{"id": "pet_corner", "text": "一只宠物盯着墙角时，12名教众也面壁站了10分钟；物业按团体活动收取场地费。"},
	{"id": "pet_coin", "text": "一只宠物叼回旧公交代币后，18名教众排队要求补票；公交公司只收了3人的现金。"},
	{"id": "pet_alarm", "text": "一只宠物午睡打呼噜，隔壁公司有24名员工跟着趴下；人事部取消了下午例会。"},
	{"id": "pet_shadow", "text": "一只宠物把拖鞋拖到桌下，11名教众随后献上另一只；失物招领处拒收了7双。"},
	{"id": "pet_fog", "text": "一只宠物守在窗边，16名教众排队向窗外敬礼；物业提醒他们不要堵住消防通道。"},
	{"id": "pet_box", "text": "一只宠物钻进快递箱后，9名教众为纸箱购买车票；快递员按宠物托运重新计费。"},
	{"id": "pet_receipt", "text": "一只宠物叼来超市小票，27名教众照单抢购盐和鸡蛋；超市实行每人限购2份。"},
	{"id": "pet_window", "text": "一只宠物对窗外挥手后，21名教众跟着挥了15分钟；对面写字楼拉上了窗帘。"}
]

const SPREAD_TEMPLATES := [
	{"id": "spread_doctrine", "text": "{place}有7户居民每天凌晨对着水管朗读教规；物业本周上门劝阻3次。"},
	{"id": "spread_bookclub", "text": "{place}新增23名信众参加“盐的用途”读书会；报名者须自带2公斤粗盐。"},
	{"id": "spread_nightshift", "text": "{place}有18名夜班员工用咖啡渣投票安排轮班；人事部称迟到率下降12%。"},
	{"id": "spread_password", "text": "登记信众已达{followers}人；{place}门禁出现31次同一密码尝试，物业找到7名排队者。"},
	{"id": "spread_leaflet", "text": "{place}有26名教众把186张传单贴满公告栏；保洁员清理4次后申请了加班费。"},
	{"id": "spread_chant", "text": "{place}有42名晨练者把七拍祷词编进健身操；社区比赛因此延长了6分钟。"}
]

const FAITH_TEMPLATES := [
	{"id": "faith_drain", "text": "信仰产量达到{rate}/秒后，37名市民抢购蜡烛和瓶装水；超市实行每人限购3件。"},
	{"id": "faith_compass", "text": "监测到{rate}点/秒的信仰增长；14名住户倒着抄写电表读数，供电公司逐户纠正。"},
	{"id": "faith_accountant", "text": "信仰增速升至{rate}/秒，12名教团会计把粗盐申报为交通费；税务窗口退回11份。"},
	{"id": "faith_meter", "text": "仪表读数达到{rate}/秒；19名质检员连续校准设备3次，最后共同申请调岗。"},
	{"id": "faith_echo", "text": "每秒产生{rate}点信仰后，楼上公司有28名员工戴着耳塞开会；物业补贴了2小时场地费。"}
]

const CULT_TEMPLATES := [
	{"id": "cult_minutes", "text": "教团例会有16人投票封存地下室3号门；行政部随后确认租赁合同没有地下室。"},
	{"id": "cult_budget", "text": "教团财务批准购买240根蜡烛；12名员工为争夺发票抬头开了3次会议。"},
	{"id": "cult_uniform", "text": "26名教众穿着湿教袍参加晨会；行政部把清洁费计入服装预算。"},
	{"id": "cult_hr", "text": "人事部发现18名员工用仪式照片代替考勤；其中7人被要求周末补班。"},
	{"id": "cult_archive", "text": "档案室有9名员工同时提交同一份会议纪要；行政部只保留最先盖章的1份。"}
]

const EVENT_TEMPLATES := {
	"petting": [
		{"id": "event_petting_forgive", "text": "一只宠物被抚摸47次后，12名教众拒绝洗手；保洁员发出8包湿巾。"},
		{"id": "event_petting_lights", "text": "宠物医院记录：23名市民排队抚摸同一只宠物，其中6人要求开具纪念证明。"},
		{"id": "event_petting_weather", "text": "一只宠物接受抚摸时，19名教众在旁鼓掌11分钟；行政部登记为员工活动。"}
	],
	"burrow": [
		{"id": "event_burrow_tunnel", "text": "一只宠物钻到桌下后，9名教众趴地等待20分钟；物业按堵塞通道处理。"},
		{"id": "event_burrow_return", "text": "一只宠物从桌下返回时，14名教众争抢它脚边的泥；保洁员封存了3袋。"}
	],
	"sleep": [
		{"id": "event_sleep_weather", "text": "一只宠物睡着后，16名教众围成一圈轻声办公；当天取消了3场会议。"},
		{"id": "event_sleep_dream", "text": "邻居投诉宠物呼噜声后，11名教众带着枕头来旁听；保安劝走了7人。"}
	],
	"air_roam": [
		{"id": "event_air_gravity", "text": "一只宠物飞到天花板附近，23名教众举着纸箱等它降落；物业没收了4把梯子。"},
		{"id": "event_air_route", "text": "一只宠物在房间上空绕了4圈，18名教众举着纸箱跟随；物业登记了3次险情。"}
	],
	"wall_crawl": [
		{"id": "event_wall_permit", "text": "一只宠物沿墙爬行时，11名教众贴着墙根跟了6圈；保安登记为消防演练。"},
		{"id": "event_wall_up", "text": "一只宠物爬到高处后，15名教众排队递交营救方案；物业只批准了2份。"}
	],
	"hide": [
		{"id": "event_hide_folder", "text": "一只宠物藏到桌面文件夹后，17名教众假装没有看见；它跳出时有6人打翻咖啡。"},
		{"id": "event_hide_watch", "text": "一只宠物躲藏期间，13名教众轮流盯着空位；它突然跳出后，物业收到4起噪音投诉。"}
	],
	"offering": [
		{"id": "event_food_spoons", "text": "一只宠物吃完{item}后，18名教众争抢空碗；食堂改用一次性餐具。"},
		{"id": "event_food_expand", "text": "一只宠物吞下{item}后，27名教众在外卖平台抢购同款；10分钟内卖出63份。"},
		{"id": "event_food_review", "text": "一只宠物吃完{item}后，14名教众提交了32页试吃报告；采购部只看了第1页。"}
	],
	"upgrade": [
		{"id": "event_upgrade_registry", "text": "一只宠物完成第{level}次强化；32名教众当天为它补办工牌和社保。"},
		{"id": "event_upgrade_meter", "text": "一只宠物强化至 Lv.{level}后，21名教众申请上调宠物押金；物业批准了1份。"}
	],
	"gacha": [
		{"id": "event_gacha_probability", "text": "教团抽中“{item}”后，27名教众在财务室排队申请报销；会计只批准了3份。"},
		{"id": "event_gacha_receipt", "text": "“{item}”入库当天，18名教众带着购物袋等候分发；仓库只发出1件样品。"}
	]
}

var _history: Array[Dictionary] = []
var _next_id := 1
var _faith_tier := 0
var _follower_tier := 0
var _recent_template_ids: Array[String] = []
var _event_last_at := {}


func restore(state_value: Variant, current_faith_rate: float, current_followers: float) -> void:
	var state: Dictionary = state_value if state_value is Dictionary else {}
	var saved_copy_version := maxi(0, int(state.get("copy_version", 0)))
	var can_restore_saved_copy := saved_copy_version >= NEWS_COPY_VERSION
	_history.clear()
	if can_restore_saved_copy:
		_history = sanitize_history(state.get("history", []))
	_next_id = maxi(1, int(state.get("next_id", 1)))
	for entry in _history:
		_next_id = maxi(_next_id, int(entry.get("id", 0)) + 1)

	var current_faith_tier := get_faith_tier(current_faith_rate)
	var current_follower_tier := get_follower_tier(current_followers)
	_faith_tier = (
		clampi(int(state.get("faith_tier", current_faith_tier)), 0, FAITH_RATE_MILESTONES.size())
		if state.has("faith_tier")
		else current_faith_tier
	)
	_follower_tier = (
		clampi(int(state.get("follower_tier", current_follower_tier)), 0, FOLLOWER_MILESTONES.size())
		if state.has("follower_tier")
		else current_follower_tier
	)

	_recent_template_ids.clear()
	var recent_value: Variant = state.get("recent_templates", []) if can_restore_saved_copy else []
	if recent_value is Array:
		for template_id_value in recent_value:
			var template_id := String(template_id_value).strip_edges().left(64)
			if template_id.is_empty() or _recent_template_ids.has(template_id):
				continue
			_recent_template_ids.append(template_id)
			if _recent_template_ids.size() >= RECENT_TEMPLATE_LIMIT:
				break
	_event_last_at.clear()


func get_state() -> Dictionary:
	return {
		"copy_version": NEWS_COPY_VERSION,
		"history": get_history(),
		"next_id": _next_id,
		"faith_tier": _faith_tier,
		"follower_tier": _follower_tier,
		"recent_templates": _recent_template_ids.duplicate()
	}


func get_history() -> Array[Dictionary]:
	return _history.duplicate(true)


func add_article(article: Dictionary, created_at: float, clock_text: String) -> Dictionary:
	var category := String(article.get("category", "异闻"))
	if not VALID_CATEGORIES.has(category):
		category = "异闻"
	var headline := String(article.get("headline", "")).strip_edges().left(MAX_HEADLINE_LENGTH)
	if headline.is_empty():
		return {}

	var safe_created_at := created_at if is_finite(created_at) else 0.0
	var entry := {
		"id": _next_id,
		"created_at": maxf(0.0, safe_created_at),
		"time_text": clock_text.strip_edges().left(16),
		"category": category,
		"headline": headline
	}
	_next_id += 1
	_history.push_front(entry)
	if _history.size() > MAX_HISTORY:
		_history.resize(MAX_HISTORY)
	return entry.duplicate(true)


func make_ambient(
	context: Dictionary,
	category_roll: float,
	template_roll: float,
	detail_roll: float
) -> Dictionary:
	var safe_category_roll := _safe_unit_roll(category_roll)
	var template_pool: Array
	var category := "异闻"
	if safe_category_roll < 0.24:
		template_pool = ABSURD_TEMPLATES
	elif safe_category_roll < 0.52:
		template_pool = PET_TEMPLATES
		category = "宠物"
	elif safe_category_roll < 0.74 and float(context.get("followers", 0.0)) >= 1.0:
		template_pool = SPREAD_TEMPLATES
		category = "传播"
	elif safe_category_roll < 0.9:
		template_pool = FAITH_TEMPLATES
		category = "信仰"
	else:
		template_pool = CULT_TEMPLATES
		category = "教团"

	var template := _choose_template(template_pool, template_roll)
	return {
		"category": category,
		"headline": _render_template(template, context, detail_roll),
		"template_id": String(template.get("id", ""))
	}


func make_event(event_type: String, context: Dictionary, template_roll: float) -> Dictionary:
	var templates_value: Variant = EVENT_TEMPLATES.get(event_type, [])
	if not templates_value is Array or templates_value.is_empty():
		return {}
	var templates: Array = templates_value
	var template := _choose_template(templates, template_roll)
	return {
		"category": "宠物" if event_type in ["petting", "burrow", "sleep", "air_roam", "wall_crawl", "hide", "offering"] else "教团",
		"headline": _render_template(template, context, template_roll),
		"template_id": String(template.get("id", ""))
	}


func collect_milestones(faith_rate: float, followers: float, detail_roll: float) -> Array[Dictionary]:
	var articles: Array[Dictionary] = []
	var next_faith_tier := get_faith_tier(faith_rate)
	if next_faith_tier > _faith_tier:
		_faith_tier = next_faith_tier
		var threshold := float(FAITH_RATE_MILESTONES[next_faith_tier - 1])
		var shopper_count := 6 + (next_faith_tier * 4)
		articles.append({
			"category": "信仰",
			"headline": "信仰产量突破%s/秒；%s有%d名市民凌晨抢购粗盐，超市实行每人限购3袋。" % [
				format_number(threshold),
				_get_place(detail_roll, next_faith_tier),
				shopper_count
			]
		})

	var next_follower_tier := get_follower_tier(followers)
	if next_follower_tier > _follower_tier:
		_follower_tier = next_follower_tier
		var threshold := int(FOLLOWER_MILESTONES[next_follower_tier - 1])
		var active_count := maxi(1, mini(threshold, int(round(sqrt(float(threshold))))))
		articles.append({
			"category": "传播",
			"headline": "登记信众达到%s人；其中%s人把%s附近的出租屋客厅改成礼拜区，房东加收2个月押金。" % [
				format_number(float(threshold)),
				format_number(float(active_count)),
				_get_place(1.0 - _safe_unit_roll(detail_roll), next_follower_tier)
			]
		})
	return articles


func can_emit_event(event_key: String, now: float, cooldown_seconds: float) -> bool:
	if not is_event_ready(event_key, now, cooldown_seconds):
		return false
	mark_event(event_key, now)
	return true


func is_event_ready(event_key: String, now: float, cooldown_seconds: float) -> bool:
	if event_key.is_empty():
		return false
	var safe_now := now if is_finite(now) else 0.0
	var last_at := float(_event_last_at.get(event_key, -INF))
	return safe_now - last_at >= maxf(0.0, cooldown_seconds)


func mark_event(event_key: String, now: float) -> void:
	if event_key.is_empty():
		return
	_event_last_at[event_key] = now if is_finite(now) else 0.0


static func get_faith_tier(faith_rate: float) -> int:
	var safe_rate := maxf(0.0, faith_rate) if is_finite(faith_rate) else 0.0
	var tier := 0
	for threshold in FAITH_RATE_MILESTONES:
		if safe_rate < float(threshold):
			break
		tier += 1
	return tier


static func get_follower_tier(followers: float) -> int:
	var safe_followers := maxf(0.0, followers) if is_finite(followers) else 0.0
	var tier := 0
	for threshold in FOLLOWER_MILESTONES:
		if safe_followers < float(threshold):
			break
		tier += 1
	return tier


# Ambient cadence intentionally accepts no faith-rate input: progression news is
# handled by milestones, while idle reports stay in the same low-frequency band.
static func get_ambient_interval(unit_roll: float) -> float:
	var safe_roll := clampf(unit_roll, 0.0, 1.0) if is_finite(unit_roll) else 0.0
	return lerpf(AMBIENT_INTERVAL_MIN_SECONDS, AMBIENT_INTERVAL_MAX_SECONDS, safe_roll)


static func sanitize_history(raw_value: Variant) -> Array[Dictionary]:
	var sanitized: Array[Dictionary] = []
	if not raw_value is Array:
		return sanitized
	for entry_value in raw_value:
		if not entry_value is Dictionary:
			continue
		var raw_entry: Dictionary = entry_value
		var headline := String(raw_entry.get("headline", "")).strip_edges().left(MAX_HEADLINE_LENGTH)
		if headline.is_empty():
			continue
		var category := String(raw_entry.get("category", "异闻"))
		if not VALID_CATEGORIES.has(category):
			category = "异闻"
		var created_at := float(raw_entry.get("created_at", 0.0))
		if not is_finite(created_at):
			created_at = 0.0
		sanitized.append({
			"id": maxi(0, int(raw_entry.get("id", 0))),
			"created_at": maxf(0.0, created_at),
			"time_text": String(raw_entry.get("time_text", "")).strip_edges().left(16),
			"category": category,
			"headline": headline
		})
		if sanitized.size() >= MAX_HISTORY:
			break
	return sanitized


static func format_number(value: float) -> String:
	var safe_value := maxf(0.0, value) if is_finite(value) else 0.0
	if safe_value >= 100000000.0:
		return _trim_decimal(String.num(safe_value / 100000000.0, 1)) + "亿"
	if safe_value >= 10000.0:
		return _trim_decimal(String.num(safe_value / 10000.0, 1)) + "万"
	if safe_value >= 100.0:
		return String.num(safe_value, 0)
	if safe_value >= 10.0:
		return _trim_decimal(String.num(safe_value, 1))
	return _trim_decimal(String.num(safe_value, 2))


func _choose_template(templates: Array, unit_roll: float) -> Dictionary:
	if templates.is_empty():
		return {}
	var start_index := mini(templates.size() - 1, int(floor(_safe_unit_roll(unit_roll) * templates.size())))
	var chosen: Dictionary = templates[start_index]
	for offset in templates.size():
		var candidate: Dictionary = templates[(start_index + offset) % templates.size()]
		if not _recent_template_ids.has(String(candidate.get("id", ""))):
			chosen = candidate
			break
	_remember_template(String(chosen.get("id", "")))
	return chosen


func _remember_template(template_id: String) -> void:
	if template_id.is_empty():
		return
	_recent_template_ids.erase(template_id)
	_recent_template_ids.push_front(template_id)
	if _recent_template_ids.size() > RECENT_TEMPLATE_LIMIT:
		_recent_template_ids.resize(RECENT_TEMPLATE_LIMIT)


func _render_template(template: Dictionary, context: Dictionary, detail_roll: float) -> String:
	if template.is_empty():
		return "本台收到23封内容相同的市民投诉；18名寄件人要求匿名，其余5人排队撤回。"
	var place := _get_place(detail_roll, int(context.get("spread_tier", 0)))
	var raw_followers := float(context.get("followers", 0.0))
	var follower_count := maxi(0, int(floor(raw_followers))) if is_finite(raw_followers) else 0
	return String(template.get("text", "")).format({
		"place": place,
		"followers": format_number(float(follower_count)),
		"rate": format_number(float(context.get("faith_rate", 0.0))),
		"item": String(context.get("item_name", "一份贡品")).strip_edges().left(40),
		"level": maxi(1, int(context.get("level", 1)))
	})


static func _get_place(unit_roll: float, tier_hint: int) -> String:
	var unlocked_count := clampi(4 + maxi(0, tier_hint), 4, PLACES.size())
	var index := mini(unlocked_count - 1, int(floor(_safe_unit_roll(unit_roll) * unlocked_count)))
	return String(PLACES[index])


static func _safe_unit_roll(value: float) -> float:
	return clampf(value, 0.0, 0.999999) if is_finite(value) else 0.0


static func _trim_decimal(text: String) -> String:
	while text.contains(".") and text.ends_with("0"):
		text = text.left(text.length() - 1)
	if text.ends_with("."):
		text = text.left(text.length() - 1)
	return text
