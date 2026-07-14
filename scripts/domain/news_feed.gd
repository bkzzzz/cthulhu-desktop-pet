extends RefCounted

## Deterministic news rules and persistent history. Runtime timing and UI live in
## main.gd so this class stays headless-testable.

const MAX_HISTORY := 80
const MAX_HEADLINE_LENGTH := 220
const RECENT_TEMPLATE_LIMIT := 6
const NEWS_COPY_VERSION := 2
const AMBIENT_INTERVAL_MIN_SECONDS := 240.0
const AMBIENT_INTERVAL_MAX_SECONDS := 360.0

const VALID_CATEGORIES := ["公告", "异闻", "传播", "信仰", "教团"]
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

const LOCAL_TEMPLATES := [
	{"id": "scope_local_names", "text": "{place}有73名居民注销原姓，统一登记为“见证者”；民政窗口拒绝后，9名工作人员当场加入队伍。"},
	{"id": "scope_local_hospital", "text": "市医院发现41名患者的心率同步为七拍一循环；3台监护仪被封存，值班医生仍坚持这是巧合。"},
	{"id": "scope_local_school", "text": "城西学校有9个班级同时删去课本中的“人类”一词；教育局派出的12名调查员已有5名拒绝返回。"},
	{"id": "scope_local_court", "text": "地方法院收到86份内容完全一致的认罪书，签署者承认自己曾经拥有独立意志；法官宣布延期审理。"},
	{"id": "scope_local_signal", "text": "本地通信站截获214名用户同时发送同一串坐标；警方抵达后，7名警员主动跪入人群。"},
	{"id": "scope_local_factory", "text": "北区工厂有58名工人拆除姓名牌，并把全部生产指标改为“等待降临”；管理层尚未恢复控制。"},
	{"id": "scope_local_registry", "text": "市政档案显示新增312名无出生记录的居民，他们都能准确背出教团戒律；户籍系统已转为离线。"},
	{"id": "scope_local_station", "text": "中心车站有127名旅客放弃原定目的地，改乘一班不存在的朝圣专列；铁路部门封锁了4座站台。"}
]

const REGIONAL_TEMPLATES := [
	{"id": "scope_region_roads", "text": "污染区已覆盖12座城镇，连接各地的公路被朝圣车队占据；沿线6支警备队先后倒戈。"},
	{"id": "scope_region_broadcast", "text": "区域广播网的43名主持人同时宣读归顺声明，信号越过4个省区后仍无法切断。"},
	{"id": "scope_region_ports", "text": "8座港口拒绝悬挂原属旗帜，19艘货轮在甲板刻下教团徽记后驶向同一片海域。"},
	{"id": "scope_region_governors", "text": "已有17名地方官员公开承认理性只是暂时症状；3个行政区随即撤销宵禁并改设礼拜时段。"},
	{"id": "scope_region_maps", "text": "国家测绘局发现26幅新版地图自行将污染区标为首都；14名制图员拒绝更正。"},
	{"id": "scope_region_army", "text": "边境集结的5支部队在接触污染带后停止推进，其中2800名士兵改称自己为护教军。"},
	{"id": "scope_region_language", "text": "语言研究所确认7种方言在一周内出现相同祷词，涉及约36万名使用者；传播源仍无法定位。"},
	{"id": "scope_region_power", "text": "区域电网有31座变电站脱离调度，却持续向教团控制区供电；11名工程师称这是电流的自愿选择。"}
]

const BIOSPHERE_TEMPLATES := [
	{"id": "scope_bio_birds", "text": "全球观测站记录到237种候鸟放弃迁徙路线，在高空组成同一枚教团徽记；编队已持续19小时。"},
	{"id": "scope_bio_ocean", "text": "14个鲸群同时改变航向，沿污染海域排列成朝圣队列；护航舰上的83名船员随后失去敌意。"},
	{"id": "scope_bio_forest", "text": "3片原始森林的树冠连续7日朝向圣地生长，涉及约1200种植物；植物学界撤回了全部解释。"},
	{"id": "scope_bio_insects", "text": "至少410种昆虫停止争夺领地，转而在6块大陆筑成统一祭坛结构；农药已完全失效。"},
	{"id": "scope_bio_predators", "text": "29种大型捕食者在同一夜停止捕猎，并护送朝圣人群穿越荒野；已有17支科考队宣誓归顺。"},
	{"id": "scope_bio_microbes", "text": "实验室确认63种微生物开始按祷文节律分裂，污染已进入饮水与土壤循环；隔离方案被宣布无效。"},
	{"id": "scope_bio_domestic", "text": "超过800万只家畜同时面向污染中心伏地，横跨21个国家；当地人类信众数量在当日翻倍。"},
	{"id": "scope_bio_ecosystem", "text": "7个生态带不再遵循既有食物链，126种生物开始共同供养教团控制区；学界称其为全球性归信。"}
]

const PLANETARY_TEMPLATES := [
	{"id": "scope_planet_continents", "text": "6块大陆的云层同时形成教团徽记，持续覆盖约43亿人；各国气象机构已停止发布否认声明。"},
	{"id": "scope_planet_ocean", "text": "全球4大洋的潮汐脱离月球引力，统一朝圣地抬升；31座沿海城市已整体归入教团。"},
	{"id": "scope_planet_satellites", "text": "3颗近地卫星未经指令调整轨道，并持续向地表广播归顺信号；地面站的64名人员集体宣誓。"},
	{"id": "scope_planet_nations", "text": "现存193个国家中已有117个撤下国旗，超过52亿人被登记为教众；其余政府进入静默状态。"},
	{"id": "scope_planet_magnetic", "text": "地磁场出现7条稳定裂隙，所有指南设备开始指向圣地；23支极地科考队已改变效忠对象。"},
	{"id": "scope_planet_moon", "text": "月面12座观测站同时拍到横跨1600公里的教团印记；各国航天机构确认该结构并非人工建造。"},
	{"id": "scope_planet_species", "text": "地球已知物种中有86%表现出统一归信行为，剩余14%正在快速消失；生物分类法被正式废止。"},
	{"id": "scope_planet_reason", "text": "全球理性指数降至原值的3%，仍保持自我认知的约900万人被集中称为“未启蒙者”。"}
]

const COSMIC_TEMPLATES := [
	{"id": "scope_cosmic_mars", "text": "火星轨道上的11台探测器同时改写任务目标，开始测绘礼拜场；2支载人计划已申请成为远征教团。"},
	{"id": "scope_cosmic_stars", "text": "17座射电天文台确认9颗恒星按七拍节律改变亮度，影响范围超过400光年。"},
	{"id": "scope_cosmic_systems", "text": "12个恒星系传回结构相同的归顺信号，其中8个系统此前从未发现智慧生命。"},
	{"id": "scope_cosmic_nebula", "text": "3片星云在观测中形成横跨数百光年的教团徽记，约2600颗恒星被遮蔽后重新点亮。"},
	{"id": "scope_cosmic_species", "text": "银河系内已确认41种智慧生物采用同一套戒律；最远一支教团位于2.7万光年外。"},
	{"id": "scope_cosmic_galaxies", "text": "本星系群的7座星系出现同步污染，超过900亿颗恒星开始向同一坐标缓慢偏移。"},
	{"id": "scope_cosmic_laws", "text": "4项基本物理常数出现可测偏差，宇宙学家承认自然法则正在主动服从教团秩序。"},
	{"id": "scope_cosmic_all", "text": "可观测宇宙的理性残余降至0.0003%，至少86亿个文明已被纳入同一教团；扩张仍未抵达边界。"}
]

const EVENT_TEMPLATES := {
	"petting": [
		{"id": "event_contact_conversion", "text": "圣迹接触记录更新后，47名旁观者同时放弃原有信仰；其中12名已成为新的传教节点。"},
		{"id": "event_contact_memory", "text": "污染半径内有23名市民失去童年记忆，却能完整背诵教团戒律；医学解释被一致驳回。"},
		{"id": "event_contact_guards", "text": "负责封锁现场的19名警卫同时解除武装，并将3道警戒线改为朝圣通道。"}
	],
	"burrow": [
		{"id": "event_ground_fault", "text": "地下监测网出现9条无法测量深度的裂隙，沿线14名工程师已将其标为圣道。"},
		{"id": "event_ground_conversion", "text": "地层异常扩散至3个街区，61名居民在疏散途中集体改道前往礼拜场。"}
	],
	"sleep": [
		{"id": "event_silence_city", "text": "污染源保持绝对静默期间，16个街区的居民同时停止交谈；随后新增340名登记教众。"},
		{"id": "event_silence_reason", "text": "持续静默使11名研究员放弃因果推理，并共同提交了1份归顺声明。"}
	],
	"air_roam": [
		{"id": "event_sky_mark", "text": "上空出现持续23分钟的污染投影，18架民航客机偏离航线并组成礼拜阵列。"},
		{"id": "event_sky_conversion", "text": "空域监测异常后，4座机场共有260名管制人员宣布效忠，区域航线已由教团接管。"}
	],
	"wall_crawl": [
		{"id": "event_boundary_failure", "text": "污染边界穿过6层实体墙后仍未衰减，11名检测员已停止使用“封闭空间”这一概念。"},
		{"id": "event_boundary_conversion", "text": "建筑内部有15名封锁人员从不同楼层同时抵达礼拜场，监控未记录任何通行过程。"}
	],
	"hide": [
		{"id": "event_absence_worship", "text": "圣迹从观测中消失后，17名教众仍准确指出其位置；6台摄影设备只拍到跪拜者。"},
		{"id": "event_absence_conversion", "text": "观测空白持续13分钟，外围新增94名教众；所有人声称自己刚刚目睹了启示。"}
	],
	"offering": [
		{"id": "event_offering_vanish", "text": "贡品“{item}”从封闭供桌上消失后，18名看守者同时宣誓归顺；现场没有留下进食痕迹。"},
		{"id": "event_offering_replication", "text": "“{item}”被列为圣物后，27座礼拜场在10分钟内复制同一仪式；新增信众超过6300人。"},
		{"id": "event_offering_conversion", "text": "供奉“{item}”的仪式结束后，14名调查员销毁报告并加入教团；封锁命令已失效。"}
	],
	"upgrade": [
		{"id": "event_upgrade_index", "text": "污染指数升至第{level}级，32名监测人员中有21名立即转为教众；其余人员请求撤离。"},
		{"id": "event_upgrade_radius", "text": "第{level}级扩张完成后，污染半径越过4道封锁线，沿途新增2100名登记信众。"}
	],
	"gacha": [
		{"id": "event_gacha_relic", "text": "教团获得“{item}”后，27名守卫同时忘记原属机构；该区域已并入圣地。"},
		{"id": "event_gacha_signal", "text": "“{item}”入库时释放出覆盖18座城镇的信号，超过7万名居民在同一分钟完成归顺。"}
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
	var scope_pools := [
		LOCAL_TEMPLATES,
		REGIONAL_TEMPLATES,
		BIOSPHERE_TEMPLATES,
		PLANETARY_TEMPLATES,
		COSMIC_TEMPLATES
	]
	var scope_categories := ["异闻", "传播", "传播", "信仰", "教团"]
	var unlocked_scope := get_scope_tier(int(context.get("spread_tier", 0)))
	var selected_scope := mini(
		unlocked_scope,
		int(floor(safe_category_roll * float(unlocked_scope + 1)))
	)
	var template_pool: Array = scope_pools[selected_scope]
	var category: String = scope_categories[selected_scope]

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
		"category": "信仰" if event_type in ["petting", "burrow", "sleep", "air_roam", "wall_crawl", "hide", "offering", "upgrade"] else "教团",
		"headline": _render_template(template, context, template_roll),
		"template_id": String(template.get("id", ""))
	}


func collect_milestones(faith_rate: float, followers: float, detail_roll: float) -> Array[Dictionary]:
	var articles: Array[Dictionary] = []
	var next_faith_tier := get_faith_tier(faith_rate)
	if next_faith_tier > _faith_tier:
		_faith_tier = next_faith_tier
		var threshold := float(FAITH_RATE_MILESTONES[next_faith_tier - 1])
		articles.append({
			"category": "信仰",
			"headline": _make_faith_milestone_headline(threshold, next_faith_tier, detail_roll)
		})

	var next_follower_tier := get_follower_tier(followers)
	if next_follower_tier > _follower_tier:
		_follower_tier = next_follower_tier
		var threshold := int(FOLLOWER_MILESTONES[next_follower_tier - 1])
		articles.append({
			"category": "传播",
			"headline": _make_follower_milestone_headline(threshold, next_follower_tier, detail_roll)
		})
	return articles


static func get_scope_tier(progression_tier: int) -> int:
	var safe_tier := maxi(0, progression_tier)
	if safe_tier < 3:
		return 0
	if safe_tier < 5:
		return 1
	if safe_tier < 7:
		return 2
	if safe_tier < 10:
		return 3
	return 4


static func _make_faith_milestone_headline(threshold: float, tier: int, detail_roll: float) -> String:
	var rate_text := format_number(threshold)
	match get_scope_tier(tier):
		0:
			return "信仰产量突破%s/秒；%s新增%d名归顺者，地方封锁首次失效。" % [
				rate_text,
				_get_place(detail_roll, tier),
				18 + (tier * 7)
			]
		1:
			return "信仰产量突破%s/秒；4座城市的共计%d名官员宣布理性审查无效，污染区扩大至区域地图。" % [
				rate_text,
				36 + (tier * 11)
			]
		2:
			return "信仰产量突破%s/秒；23种动物与7种植物出现统一归信行为，污染首次进入生态循环。" % rate_text
		3:
			return "信仰产量突破%s/秒；3颗卫星和6块大陆同时记录到教团印记，全球封锁体系宣告崩溃。" % rate_text
		_:
			return "信仰产量突破%s/秒；11个恒星系出现同步归顺信号，污染已越过太阳系边界。" % rate_text


static func _make_follower_milestone_headline(threshold: int, tier: int, detail_roll: float) -> String:
	var follower_text := format_number(float(threshold))
	match get_scope_tier(tier):
		0:
			return "登记信众达到%s人；其中%d名已在%s建立首个公开礼拜场。" % [
				follower_text,
				maxi(1, mini(threshold, 3 + (tier * 4))),
				_get_place(1.0 - _safe_unit_roll(detail_roll), tier)
			]
		1:
			return "登记信众达到%s人；7座城镇撤除原属标志，超过%d名公务人员转入教团。" % [
				follower_text,
				24 + (tier * 13)
			]
		2:
			return "登记信众达到%s人；37种动物开始护送朝圣队伍，生物污染扩散至4个生态带。" % follower_text
		3:
			return "登记信众达到%s人；4片大陆与2大洋进入持续归信状态，全球理性指数跌破20%%。" % follower_text
		_:
			return "登记信众达到%s人；9个外星文明采用同一戒律，宇宙教团首次得到实证。" % follower_text


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
		return "污染监测网失去23个观测节点；其中18个在断联前发送了同一份归顺声明。"
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
