extends RefCounted

const MAX_HISTORY := 80
const MAX_HEADLINE_LENGTH := 220
const RECENT_TEMPLATE_LIMIT := 6
const NEWS_COPY_VERSION := 7
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
	1000000,
	5000000,
	50000000,
	500000000,
	5000000000,
	50000000000
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
	{"id": "scope_local_names", "text": "{place}新增73名教团信众；他们租下一间店面作为公开聚会点，并开始招募附近居民。"},
	{"id": "scope_local_hospital", "text": "41名医护人员加入教团后，在市医院外设立免费餐点，并向来往居民发放入团说明。"},
	{"id": "scope_local_school", "text": "教团在城西学校附近组织9场公开讲座，已有12名教职员工报名负责下一轮活动。"},
	{"id": "scope_local_court", "text": "86名教团信众在地方法院门前集会，要求开放更多公共场地供教团使用。"},
	{"id": "scope_local_signal", "text": "教团买下本地通信站的3个晚间时段，214名志愿者开始轮班播送招募消息。"},
	{"id": "scope_local_factory", "text": "北区工厂的58名工人组建教团分会，并把一座闲置仓库改成物资中心。"},
	{"id": "scope_local_registry", "text": "市政登记显示本周新增312名教团成员，他们已在4个社区设立固定联络点。"},
	{"id": "scope_local_station", "text": "中心车站附近聚集127名教团志愿者，他们包下4辆客车接送新成员参加集会。"}
]

const REGIONAL_TEMPLATES := [
	{"id": "scope_region_roads", "text": "教团已进入12座城镇，6支运输车队每天沿公路运送成员与活动物资。"},
	{"id": "scope_region_broadcast", "text": "区域广播网的43名主持人加入教团，招募节目现已覆盖4个省区。"},
	{"id": "scope_region_ports", "text": "教团在8座港口成立分会，并租用19艘货轮向沿海城市运送人员和物资。"},
	{"id": "scope_region_governors", "text": "17名地方官员公开支持教团活动，3个行政区随后批准建设大型集会场。"},
	{"id": "scope_region_maps", "text": "教团公布26条跨城招募路线，14支宣传队将在本月走遍沿线社区。"},
	{"id": "scope_region_army", "text": "教团组织5支大型建设队，2800名成员正在扩建区域总部和住宿区。"},
	{"id": "scope_region_language", "text": "教团将宣传材料翻译成7种方言，首批内容已送达约36万名居民。"},
	{"id": "scope_region_power", "text": "教团接管31座小型发电设施，11名工程师负责保障各地分会的长期供电。"}
]

const BIOSPHERE_TEMPLATES := [
	{"id": "scope_bio_birds", "text": "教团在6个国家建立237座野生动物救助站，借此招募当地志愿者并扩充分会。"},
	{"id": "scope_bio_ocean", "text": "14支教团船队开始在沿海城市巡回活动，83名船员负责运送新成员和生活物资。"},
	{"id": "scope_bio_forest", "text": "教团在3片林区建设长期营地，1200名成员已完成道路、供水和仓库工程。"},
	{"id": "scope_bio_insects", "text": "教团在6块大陆开设410座农业合作站，以免费种子和食物吸引更多居民加入。"},
	{"id": "scope_bio_predators", "text": "29支教团护送队开通荒野路线，另有17支建设队沿途建立补给点。"},
	{"id": "scope_bio_microbes", "text": "教团资助63座净水站，并把免费供水点作为新分会的固定活动地点。"},
	{"id": "scope_bio_domestic", "text": "教团在21个国家建立大型牧场，超过800万份食品将优先供应新加入的家庭。"},
	{"id": "scope_bio_ecosystem", "text": "教团控制的7个农业区开始统一调配物资，126支运输队正在向各地分会送货。"}
]

const PLANETARY_TEMPLATES := [
	{"id": "scope_planet_continents", "text": "教团已在6块大陆设立总部，公开活动覆盖约43亿人，全球招募仍在继续。"},
	{"id": "scope_planet_ocean", "text": "教团的4支远洋船队连接31座沿海城市，每周运送成员、食品和建筑材料。"},
	{"id": "scope_planet_satellites", "text": "教团租用3颗通信卫星向全球播送节目，64名技术人员负责全天维护。"},
	{"id": "scope_planet_nations", "text": "教团已在117个国家完成正式登记，全球信众总数超过52亿人。"},
	{"id": "scope_planet_magnetic", "text": "教团派出23支极地建设队，准备在7条远洋航线的终点建立新分会。"},
	{"id": "scope_planet_moon", "text": "教团资助12项月面工程，首批1600名成员正在接受长期驻留训练。"},
	{"id": "scope_planet_species", "text": "教团在86个大型自然保护区设立服务站，14万名志愿者负责日常运营。"},
	{"id": "scope_planet_reason", "text": "教团完成全球900万名地区负责人的培训，他们将负责下一阶段的城市招募。"}
]

const COSMIC_TEMPLATES := [
	{"id": "scope_cosmic_mars", "text": "教团组建2支火星远征队，11台探测器正在为第一座火星分会选择地点。"},
	{"id": "scope_cosmic_stars", "text": "教团与17座天文台合作，已向9个恒星方向连续发送招募广播。"},
	{"id": "scope_cosmic_systems", "text": "教团收到来自12个恒星系的回应，其中8个星系已经成立当地分会。"},
	{"id": "scope_cosmic_nebula", "text": "教团派出3支星际建设队，计划在2600颗恒星附近建立长期补给网络。"},
	{"id": "scope_cosmic_species", "text": "银河系内已有41个文明建立教团分会，最远的分会位于2.7万光年外。"},
	{"id": "scope_cosmic_galaxies", "text": "教团的跨星系联络网已连接7座星系，超过900亿名成员参与物资与信息交换。"},
	{"id": "scope_cosmic_laws", "text": "教团召开4场跨星系大会，各地分会决定统一招募、运输和建设标准。"},
	{"id": "scope_cosmic_all", "text": "至少86亿个文明已建立教团组织，扩张队伍仍在前往更远的宇宙区域。"}
]

const EVENT_TEMPLATES := {
	"petting": [
		{"id": "event_contact_conversion", "text": "教团举行一次街边招募，7名居民报名，其中2人愿意协助下一场活动。"},
		{"id": "event_contact_memory", "text": "5名教团志愿者完成入门培训，随后前往1个社区张贴活动通知。"},
		{"id": "event_contact_guards", "text": "3名场地管理员加入教团，并腾出1间空房作为临时聚会点。"}
	],
	"burrow": [
		{"id": "event_ground_fault", "text": "教团清理1处地下储藏室，4名志愿者正在加固入口并登记物资。"},
		{"id": "event_ground_conversion", "text": "教团借地下通道向1个街区运送12箱物资，6名居民随后报名加入。"}
	],
	"sleep": [
		{"id": "event_silence_city", "text": "教团在1个街区举行夜间集会，活动结束后新增8名信众。"},
		{"id": "event_silence_reason", "text": "4名夜班工作人员加入教团，并共同看守1处夜间聚会点。"}
	],
	"air_roam": [
		{"id": "event_sky_mark", "text": "教团放飞3架小型宣传飞行器，在旧城区上空展示了12分钟招募信息。"},
		{"id": "event_sky_conversion", "text": "教团在1座民用机场设置临时咨询台，已有9名工作人员报名协助。"}
	],
	"wall_crawl": [
		{"id": "event_boundary_failure", "text": "教团在6栋建筑外墙设置大型招募海报，11支小队负责维护和更新内容。"},
		{"id": "event_boundary_conversion", "text": "15名教团成员完成高层建筑宣传活动，并在不同楼层开设临时咨询点。"}
	],
	"hide": [
		{"id": "event_absence_worship", "text": "教团将物资存入2处小型仓库，5名成员负责送往附近聚会点。"},
		{"id": "event_absence_conversion", "text": "教团在13分钟内完成一次快闪招募，活动结束时新增6名信众。"}
	],
	"offering": [
		{"id": "event_offering_vanish", "text": "教团用“{item}”举办分享餐会，18名到场居民在活动结束后加入。"},
		{"id": "event_offering_replication", "text": "教团准备了9份“{item}”，并邀请附近21名居民参加小型餐会。"},
		{"id": "event_offering_conversion", "text": "教团完成“{item}”主题招募活动，14名工作人员将负责筹备下一场。"}
	],
	"upgrade": [
		{"id": "event_upgrade_index", "text": "教众登记更新：教团当前共有{followers}名信众，其中8名成员开始负责附近街区的招募。"},
		{"id": "event_upgrade_radius", "text": "教众登记更新：教团当前共有{followers}名信众，新设2个活动区并安排17名志愿者值守。"}
	],
	"gacha": [
		{"id": "event_gacha_relic", "text": "教团为“{item}”举行见面会，7名志愿者负责接待访客并介绍入团方式。"},
		{"id": "event_gacha_signal", "text": "教团围绕“{item}”制作了16张新海报，并在2个街区开始试发。"}
	]
}

var _history: Array[Dictionary] = []
var _next_id := 1
var _faith_tier := 0
var _follower_tier := 0
var _recent_template_ids: Array[String] = []
var _event_last_at := {}
static var _report_number_regex: RegEx


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
	var headline_en := String(article.get("headline_en", "")).strip_edges().left(MAX_HEADLINE_LENGTH)

	var safe_created_at := created_at if is_finite(created_at) else 0.0
	var entry := {
		"id": _next_id,
		"created_at": maxf(0.0, safe_created_at),
		"time_text": clock_text.strip_edges().left(16),
		"category": category,
		"headline": headline
	}
	if not headline_en.is_empty():
		entry["headline_en"] = headline_en
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
		"headline_en": _make_ambient_headline_en(selected_scope, context, detail_roll),
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
		"headline_en": _make_event_headline_en(event_type, context),
		"template_id": String(template.get("id", ""))
	}


func collect_milestones(faith_rate: float, followers: float, detail_roll: float) -> Array[Dictionary]:
	var articles: Array[Dictionary] = []
	var current_follower_tier := get_follower_tier(followers)
	var next_faith_tier := get_faith_tier(faith_rate)
	if next_faith_tier > _faith_tier:
		_faith_tier = next_faith_tier
		var threshold := float(FAITH_RATE_MILESTONES[next_faith_tier - 1])
		articles.append({
			"category": "信仰",
			"headline": _make_faith_milestone_headline(
				threshold,
				mini(next_faith_tier, current_follower_tier),
				detail_roll
			),
			"headline_en": "Faith production reached %s per second; new public recruitment centers are opening." % format_number_en(threshold)
		})

	var next_follower_tier := current_follower_tier
	if next_follower_tier > _follower_tier:
		_follower_tier = next_follower_tier
		var threshold := int(FOLLOWER_MILESTONES[next_follower_tier - 1])
		articles.append({
			"category": "传播",
			"headline": _make_follower_milestone_headline(threshold, next_follower_tier, detail_roll),
			"headline_en": "Registered followers reached %s; the cult is establishing new chapters and supply routes." % format_number_en(float(threshold))
		})
	return articles


static func _make_ambient_headline_en(scope: int, context: Dictionary, detail_roll: float) -> String:
	var followers := format_number_en(float(context.get("followers", 0.0)))
	match scope:
		0:
			return "A new local chapter opened near the old district; %d volunteers are recruiting residents and preparing a public meeting place." % _report_number(18, detail_roll, 1)
		1:
			return "Regional chapters expanded into %d towns, with %d transport teams moving members and supplies between gathering sites." % [_report_number(12, detail_roll, 2), _report_number(6, detail_roll, 3)]
		2:
			return "Cult service stations now operate across %d countries, drawing new volunteers through food, water, and agricultural programs." % _report_number(9, detail_roll, 4)
		3:
			return "The cult expanded its global network of chapters, broadcasts, and transport routes; registered followers now number %s." % followers
		_:
			return "Interstellar chapters reported contacts in %d star systems, and %d expansion teams are preparing routes to distant civilizations." % [_report_number(12, detail_roll, 5), _report_number(3, detail_roll, 6)]


static func _make_event_headline_en(event_type: String, context: Dictionary) -> String:
	var followers := format_number_en(maxf(0.0, float(context.get("followers", 0.0))))
	match event_type:
		"petting": return "A street recruitment drive welcomed new residents and trained volunteers for the next gathering."
		"burrow": return "Volunteers secured an underground storehouse and opened a supply route to a nearby chapter."
		"sleep": return "A quiet nighttime gathering ended with several workers joining the cult."
		"air_roam": return "Aerial displays carried recruitment messages across the old district."
		"wall_crawl": return "Recruitment teams placed new signs across several high-rise buildings."
		"hide": return "A rapid recruitment operation established new storage and meeting points."
		"offering": return "A gathering centered on a new offering attracted members and volunteers."
		"upgrade": return "Follower registry update: the cult now has %s registered followers, with new volunteers assigned to recruitment posts." % followers
		"gacha": return "The cult welcomed a newly summoned companion at a public gathering and began a recruitment campaign."
		_: return "Cult activity increased as new volunteers joined local chapters."


static func get_scope_tier(progression_tier: int) -> int:
	var safe_tier := maxi(0, progression_tier)
	if safe_tier < 6:
		return 0
	if safe_tier < 12:
		return 1
	if safe_tier < 15:
		return 2
	if safe_tier < 17:
		return 3
	return 4


static func _make_faith_milestone_headline(threshold: float, tier: int, detail_roll: float) -> String:
	var rate_text := format_number(threshold)
	match get_scope_tier(tier):
		0:
			return "信仰产量突破%s/秒；教团在%s新增%d名成员，并开设新的公开招募点。" % [
				rate_text,
				_get_place(detail_roll, tier),
				18 + (tier * 7)
			]
		1:
			return "信仰产量突破%s/秒；教团进入4座城市，共有%d名地区负责人开始组织分会。" % [
				rate_text,
				36 + (tier * 11)
			]
		2:
			return "信仰产量突破%s/秒；教团新建23座物资中心，7支运输队开始跨地区供给分会。" % rate_text
		3:
			return "信仰产量突破%s/秒；教团租用3颗通信卫星，招募节目现已覆盖6块大陆。" % rate_text
		_:
			return "信仰产量突破%s/秒；教团已在11个恒星系成立分会，星际扩张继续进行。" % rate_text


static func _make_follower_milestone_headline(threshold: int, tier: int, detail_roll: float) -> String:
	var follower_text := format_number(float(threshold))
	match get_scope_tier(tier):
		0:
			return "登记信众达到%s人；其中%d名成员已在%s建立首个公开聚会点。" % [
				follower_text,
				maxi(1, mini(threshold, 3 + (tier * 4))),
				_get_place(1.0 - _safe_unit_roll(detail_roll), tier)
			]
		1:
			return "登记信众达到%s人；教团在7座城镇设立分会，超过%d名志愿者负责日常运营。" % [
				follower_text,
				24 + (tier * 13)
			]
		2:
			return "登记信众达到%s人；教团组建37支地区服务队，并在4个大型农业区建立补给站。" % follower_text
		3:
			return "登记信众达到%s人；教团总部已覆盖4片大陆，并开通2条远洋人员运输线。" % follower_text
		_:
			return "登记信众达到%s人；9个外星文明成立当地教团分会，并加入统一联络网。" % follower_text


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
		var sanitized_entry := {
			"id": maxi(0, int(raw_entry.get("id", 0))),
			"created_at": maxf(0.0, created_at),
			"time_text": String(raw_entry.get("time_text", "")).strip_edges().left(16),
			"category": category,
			"headline": headline
		}
		var headline_en := String(raw_entry.get("headline_en", "")).strip_edges().left(MAX_HEADLINE_LENGTH)
		if not headline_en.is_empty():
			sanitized_entry["headline_en"] = headline_en
		sanitized.append(sanitized_entry)
		if sanitized.size() >= MAX_HISTORY:
			break
	return sanitized


static func get_localized_headline(entry: Dictionary, language_code: String) -> String:
	if language_code != "zh":
		var english_headline := String(entry.get("headline_en", "")).strip_edges()
		if not english_headline.is_empty():
			return english_headline
	return String(entry.get("headline", "")).strip_edges()


static func get_localized_category(category: String, language_code: String) -> String:
	if language_code == "zh":
		return category
	var english_names := {
		"公告": "NOTICE",
		"异闻": "REPORT",
		"传播": "SPREAD",
		"信仰": "FAITH",
		"教团": "CULT",
		"宠物": "PETS"
	}
	return String(english_names.get(category, category))


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


static func format_number_en(value: float) -> String:
	var safe_value := maxf(0.0, value) if is_finite(value) else 0.0
	for scale_value in [
		[1.0e15, "Qa"],
		[1.0e12, "T"],
		[1.0e9, "B"],
		[1.0e6, "M"],
		[1.0e3, "K"]
	]:
		var scale: float = scale_value[0]
		if safe_value >= scale:
			return _trim_decimal(String.num(safe_value / scale, 1)) + String(scale_value[1])
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
		return "教团新增23个地区联络点，其中18个已经开始公开招募和物资发放。"
	var place := _get_place(detail_roll, int(context.get("spread_tier", 0)))
	var raw_followers := float(context.get("followers", 0.0))
	var follower_count := maxi(0, int(floor(raw_followers))) if is_finite(raw_followers) else 0
	var report_text := _vary_report_numbers(String(template.get("text", "")), detail_roll)
	return report_text.format({
		"place": place,
		"followers": format_number(float(follower_count)),
		"rate": format_number(float(context.get("faith_rate", 0.0))),
		"item": String(context.get("item_name_zh", context.get("item_name", "一份贡品"))).strip_edges().left(40),
		"level": maxi(1, int(context.get("level", 1)))
	})


static func _vary_report_numbers(text: String, unit_roll: float) -> String:
	if _report_number_regex == null:
		_report_number_regex = RegEx.new()
		_report_number_regex.compile("[0-9]+(?:\\.[0-9]+)?")
	var matches := _report_number_regex.search_all(text)
	var varied := text
	# Replace backwards so earlier match offsets remain valid. Placeholder values
	# are formatted afterwards and therefore keep exact player progression values.
	for match_index in range(matches.size() - 1, -1, -1):
		var number_match: RegExMatch = matches[match_index]
		var original_text := number_match.get_string()
		var original := float(original_text)
		var varied_value := _report_number(original, unit_roll, match_index + 1)
		var replacement := (
			_trim_decimal("%.1f" % float(varied_value))
			if original_text.contains(".")
			else str(varied_value)
		)
		varied = varied.left(number_match.get_start()) + replacement + varied.substr(number_match.get_end())
	return varied


static func _report_number(base_value: float, unit_roll: float, salt: int) -> int:
	var safe_base := maxf(1.0, base_value)
	var mixed := fposmod(_safe_unit_roll(unit_roll) * 0.754877666 + float(salt) * 0.569840291, 1.0)
	var spread := 0.34 if safe_base < 20.0 else 0.22
	var result := maxi(1, int(round(safe_base * lerpf(1.0 - spread, 1.0 + spread, mixed))))
	if result == int(round(safe_base)) and safe_base >= 3.0:
		result += -1 if mixed < 0.5 else 1
	return result


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
