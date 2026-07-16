extends RefCounted

const NewsFeed = preload("res://scripts/domain/news_feed.gd")
const SideDrawerController = preload("res://scripts/side_drawer_controller.gd")
const NewsWindow = preload("res://scripts/news_window.gd")
const PET_NAME_SENTINEL := "绝不能播出的宠物名"
const FORBIDDEN_COPY_FRAGMENTS := [
	"{pet}",
	"深渊",
	"凝视",
	"低语",
	"梦",
	"下水道叫我名字",
	"会在凌晨轻声喘气",
	"抵达了昨天",
	"自行增加",
	"又回到公告栏",
	"自行多印",
	"低潮时间",
	"一小片多云",
	"此前不存在",
	"明日会议纪要",
	"邮戳日期是明天",
	"一只宠物",
	"宠物",
	"打呼噜",
	"叼",
	"拖鞋",
	"车票",
	"快递箱",
	"外卖平台",
	"物业",
	"保洁员",
	"工牌",
	"押金",
	"调查员",
	"圣迹",
	"圣道",
	"传教节点",
	"污染",
	"理性指数",
	"归顺",
	"未启蒙者",
	"启示",
	"戒律"
]


static func run() -> Array[String]:
	var failures: Array[String] = []
	_test_ambient_templates(failures)
	_test_event_templates(failures)
	_test_direct_copy_contract(failures)
	_test_milestones(failures)
	_test_history_and_restore(failures)
	_test_copy_version_migration(failures)
	_test_cooldown_and_cadence(failures)
	_test_news_bookmark_signal(failures)
	_test_news_window_fitting(failures)
	return failures


static func _test_ambient_templates(failures: Array[String]) -> void:
	var feed := NewsFeed.new()
	feed.restore({}, 0.85, 12.0)
	var scope_cases := [
		{"tier": 0, "prefix": "scope_local_", "category": "异闻"},
		{"tier": 3, "prefix": "scope_region_", "category": "传播"},
		{"tier": 5, "prefix": "scope_bio_", "category": "传播"},
		{"tier": 7, "prefix": "scope_planet_", "category": "信仰"},
		{"tier": 10, "prefix": "scope_cosmic_", "category": "教团"}
	]
	for case_value in scope_cases:
		var scope_case: Dictionary = case_value
		var context := {
			"pet_name": PET_NAME_SENTINEL,
			"faith_rate": 123.0,
			"followers": 456.0,
			"spread_tier": int(scope_case.get("tier", 0))
		}
		var article: Dictionary = feed.make_ambient(context, 0.999, 0.17, 0.42)
		if String(article.get("category", "")) != String(scope_case.get("category", "")):
			failures.append("ambient news must use the category of its unlocked expansion scale")
		if not String(article.get("template_id", "")).begins_with(String(scope_case.get("prefix", ""))):
			failures.append("ambient news must unlock local, regional, biosphere, planetary, and cosmic scales gradually")
		var headline := String(article.get("headline", ""))
		if headline.is_empty() or headline.contains("{") or headline.contains("}"):
			failures.append("ambient news templates must render complete non-empty headlines")
		if headline.contains(PET_NAME_SENTINEL):
			failures.append("ambient news must never expose a pet display name")

	var seen_ids := {}
	var dedupe_feed := NewsFeed.new()
	dedupe_feed.restore({}, 0.0, 0.0)
	var local_context := {"faith_rate": 0.0, "followers": 0.0, "spread_tier": 0}
	for _index in 6:
		var article: Dictionary = dedupe_feed.make_ambient(local_context, 0.0, 0.0, 0.0)
		seen_ids[String(article.get("template_id", ""))] = true
	if seen_ids.size() != 6:
		failures.append("ambient news must avoid recently used templates")


static func _test_event_templates(failures: Array[String]) -> void:
	var feed := NewsFeed.new()
	feed.restore({}, 0.0, 0.0)
	var offering: Dictionary = feed.make_event(
		"offering",
		{"pet_name": PET_NAME_SENTINEL, "item_name": "眼球汤"},
		0.0
	)
	var offering_text := String(offering.get("headline", ""))
	if offering_text.contains(PET_NAME_SENTINEL) or not offering_text.contains("眼球汤"):
		failures.append("offering news must keep the item name without exposing the pet name")

	var wall: Dictionary = feed.make_event("wall_crawl", {"pet_name": PET_NAME_SENTINEL}, 0.0)
	if (
		String(wall.get("category", "")) != "信仰"
		or String(wall.get("headline", "")).contains(PET_NAME_SENTINEL)
	):
		failures.append("runtime incidents must report anonymous contamination instead of pet behavior")

	var hide: Dictionary = feed.make_event("hide", {"pet_name": PET_NAME_SENTINEL}, 0.0)
	if (
		String(hide.get("category", "")) != "信仰"
		or String(hide.get("headline", "")).contains(PET_NAME_SENTINEL)
	):
		failures.append("visibility incidents must describe external contamination without lowering the sacred source")

	for template_roll in [0.0, 0.75]:
		var upgrade: Dictionary = feed.make_event(
			"upgrade",
			{"pet_name": PET_NAME_SENTINEL, "level": 12},
			template_roll
		)
		var upgrade_text := String(upgrade.get("headline", ""))
		if upgrade_text.contains(PET_NAME_SENTINEL) or not upgrade_text.contains("12"):
			failures.append("every upgrade news template must report the level without the pet name")
		if upgrade_text.contains("种群") or upgrade_text.contains("{level}"):
			failures.append("upgrade news must not retain population or unresolved level wording")
	if not feed.make_event("evolution", {"pet_name": PET_NAME_SENTINEL}, 0.0).is_empty():
		failures.append("removed evolution events must not produce news")
	if not feed.make_event("unknown", {}, 0.0).is_empty():
		failures.append("unknown news events must not create malformed articles")


static func _test_direct_copy_contract(failures: Array[String]) -> void:
	var feed := NewsFeed.new()
	feed.restore({}, 0.0, 0.0)
	var context := {
		"pet_name": PET_NAME_SENTINEL,
		"item_name": "眼球汤",
		"level": 12,
		"faith_rate": 123.0,
		"followers": 456.75,
		"spread_tier": 4
	}
	var numbered_people := RegEx.new()
	if numbered_people.compile("[0-9]+(\\.[0-9]+)?(万|亿)?(名|人|户|种|群|个|颗|片|支|座|台|艘|架|项|份|道|层|块|场|条|区|%)") != OK:
		failures.append("direct-news test pattern must compile")
		return

	var ambient_pools := [
		NewsFeed.LOCAL_TEMPLATES,
		NewsFeed.REGIONAL_TEMPLATES,
		NewsFeed.BIOSPHERE_TEMPLATES,
		NewsFeed.PLANETARY_TEMPLATES,
		NewsFeed.COSMIC_TEMPLATES
	]
	for pool_value in ambient_pools:
		var pool: Array = pool_value
		for template_value in pool:
			var template: Dictionary = template_value
			var template_id := String(template.get("id", "ambient"))
			var headline := String(feed.call("_render_template", template, context, 0.42))
			_assert_direct_headline(failures, headline, template_id, numbered_people)

	for event_type_value in NewsFeed.EVENT_TEMPLATES:
		var event_type := String(event_type_value)
		var event_templates: Array = NewsFeed.EVENT_TEMPLATES[event_type]
		for template_value in event_templates:
			var template: Dictionary = template_value
			var template_id := String(template.get("id", event_type))
			var headline := String(feed.call("_render_template", template, context, 0.42))
			_assert_direct_headline(failures, headline, template_id, numbered_people)

	var fallback := String(feed.call("_render_template", {}, context, 0.42))
	_assert_direct_headline(failures, fallback, "fallback", numbered_people)


static func _assert_direct_headline(
	failures: Array[String],
	headline: String,
	source_id: String,
	numbered_people: RegEx
) -> void:
	if headline.is_empty():
		failures.append("news template %s must render a headline" % source_id)
		return
	if headline.contains(PET_NAME_SENTINEL):
		failures.append("news template %s must never expose a pet display name" % source_id)
	if headline.contains("{") or headline.contains("}"):
		failures.append("news template %s must resolve every placeholder" % source_id)
	if not headline.contains("教团"):
		failures.append("news template %s must keep the focus on cult expansion or action" % source_id)
	for fragment in FORBIDDEN_COPY_FRAGMENTS:
		if headline.contains(String(fragment)):
			failures.append("news template %s retains abstract copy: %s" % [source_id, fragment])
	if numbered_people.search(headline) == null:
		failures.append("news template %s must report a concrete numbered group" % source_id)


static func _test_milestones(failures: Array[String]) -> void:
	var feed := NewsFeed.new()
	feed.restore({}, 0.85, 0.0)
	var articles: Array[Dictionary] = feed.collect_milestones(750.0, 6000.0, 0.25)
	if articles.size() != 2:
		failures.append("crossing many faith and follower milestones must emit one summary per track")
	else:
		if not String(articles[0].get("headline", "")).contains("500"):
			failures.append("faith milestone news must report the highest crossed threshold")
		if not String(articles[1].get("headline", "")).contains("5000"):
			failures.append("follower milestone news must report the highest crossed threshold")
		if not String(articles[0].get("headline", "")).contains("23座物资中心"):
			failures.append("faith milestones must report a concrete larger-scale cult project")
		if not String(articles[1].get("headline", "")).contains("4片大陆"):
			failures.append("follower milestones must expand into planetary-scale conversion")
		for article in articles:
			var headline := String(article.get("headline", ""))
			if headline.contains(PET_NAME_SENTINEL) or headline.contains("{") or headline.contains("}"):
				failures.append("milestone news must stay anonymous and fully rendered")
			for fragment in FORBIDDEN_COPY_FRAGMENTS:
				if headline.contains(String(fragment)):
					failures.append("milestone news must not restore abstract legacy copy")
	if not feed.collect_milestones(750.0, 6000.0, 0.8).is_empty():
		failures.append("already seen news milestones must not repeat")
	if NewsFeed.get_faith_tier(-1.0) != 0 or NewsFeed.get_follower_tier(NAN) != 0:
		failures.append("news milestone tiers must safely reject invalid progression values")


static func _test_history_and_restore(failures: Array[String]) -> void:
	var feed := NewsFeed.new()
	feed.restore({}, 0.0, 0.0)
	for index in 85:
		feed.add_article(
			{"category": "异闻", "headline": "测试新闻 %d" % index},
			1000.0 + index,
			"12:34"
		)
	var history: Array[Dictionary] = feed.get_history()
	if history.size() != NewsFeed.MAX_HISTORY:
		failures.append("news history must stay within its persistent entry limit")
	if String(history[0].get("headline", "")) != "测试新闻 84":
		failures.append("news history must keep the newest entry first")

	var restored := NewsFeed.new()
	restored.restore(feed.get_state(), 0.0, 0.0)
	if restored.get_history() != history:
		failures.append("news history must survive a save-state round trip")
	var next_entry: Dictionary = restored.add_article({"category": "坏分类", "headline": "仍应保存"}, 0.0, "")
	if String(next_entry.get("category", "")) != "异闻":
		failures.append("restored news must normalize unknown categories")

	var oversized := ""
	for _index in 260:
		oversized += "字"
	var sanitized := NewsFeed.sanitize_history([
		{"id": -2, "category": "???", "headline": oversized, "created_at": NAN},
		{"headline": "   "},
		"not a dictionary"
	])
	if sanitized.size() != 1:
		failures.append("news save sanitization must discard malformed entries")
	elif String(sanitized[0].get("headline", "")).length() != NewsFeed.MAX_HEADLINE_LENGTH:
		failures.append("news save sanitization must cap headline length")


static func _test_copy_version_migration(failures: Array[String]) -> void:
	var legacy_without_version := {
		"history": [
			{
				"id": 7,
				"category": "宠物",
				"headline": "%s开始做梦并凝视深渊" % PET_NAME_SENTINEL,
				"created_at": 100.0
			}
		],
		"next_id": 8,
		"faith_tier": 4,
		"follower_tier": 5,
		"recent_templates": ["pet_corner", "event_sleep_dream"]
	}
	var legacy_old_version: Dictionary = legacy_without_version.duplicate(true)
	legacy_old_version["copy_version"] = NewsFeed.NEWS_COPY_VERSION - 1
	var legacy_states: Array[Dictionary] = [legacy_without_version, legacy_old_version]
	for legacy_state in legacy_states:
		var migrated := NewsFeed.new()
		migrated.restore(legacy_state, 0.0, 0.0)
		var migrated_state: Dictionary = migrated.get_state()
		if not migrated.get_history().is_empty():
			failures.append("legacy news-copy migrations must clear saved headlines")
		var recent_value: Variant = migrated_state.get("recent_templates", [])
		if not recent_value is Array or not recent_value.is_empty():
			failures.append("legacy news-copy migrations must clear recent template ids")
		if (
			int(migrated_state.get("faith_tier", -1)) != 4
			or int(migrated_state.get("follower_tier", -1)) != 5
		):
			failures.append("news-copy migrations must preserve milestone tiers")
		if int(migrated_state.get("copy_version", 0)) != NewsFeed.NEWS_COPY_VERSION:
			failures.append("news state must persist the current copy version")

	var current := NewsFeed.new()
	current.restore(
		{
			"copy_version": NewsFeed.NEWS_COPY_VERSION,
			"history": [
				{
					"id": 9,
					"category": "教团",
					"headline": "教团已在12个恒星系成立当地分会",
					"created_at": 200.0
				}
			],
			"recent_templates": ["scope_cosmic_systems"]
		},
		0.0,
		0.0
	)
	if current.get_history().size() != 1:
		failures.append("current-version news copy must survive restore")
	var current_recent: Variant = current.get_state().get("recent_templates", [])
	if not current_recent is Array or current_recent != ["scope_cosmic_systems"]:
		failures.append("current-version recent news templates must survive restore")


static func _test_cooldown_and_cadence(failures: Array[String]) -> void:
	var feed := NewsFeed.new()
	feed.restore({}, 0.0, 0.0)
	if not feed.can_emit_event("pet:test", 100.0, 10.0):
		failures.append("a new news event key must be immediately eligible")
	if feed.can_emit_event("pet:test", 105.0, 10.0):
		failures.append("news event cooldowns must suppress repeated incidents")
	if not feed.can_emit_event("pet:test", 110.0, 10.0):
		failures.append("news events must become eligible when their cooldown expires")

	var minimum_interval := NewsFeed.get_ambient_interval(0.0)
	var middle_interval := NewsFeed.get_ambient_interval(0.5)
	var maximum_interval := NewsFeed.get_ambient_interval(1.0)
	if not is_equal_approx(minimum_interval, NewsFeed.AMBIENT_INTERVAL_MIN_SECONDS):
		failures.append("ambient broadcasts must wait at least 240 seconds")
	if not is_equal_approx(middle_interval, 300.0):
		failures.append("ambient cadence must depend only on the random interval roll")
	if not is_equal_approx(maximum_interval, NewsFeed.AMBIENT_INTERVAL_MAX_SECONDS):
		failures.append("ambient broadcasts must wait at most 360 seconds")
	if not is_equal_approx(NewsFeed.get_ambient_interval(-1.0), 240.0):
		failures.append("ambient cadence must safely clamp rolls below its interval")
	if not is_equal_approx(NewsFeed.get_ambient_interval(2.0), 360.0):
		failures.append("ambient cadence must safely clamp rolls above its interval")
	if not is_equal_approx(NewsFeed.get_ambient_interval(NAN), 240.0):
		failures.append("ambient cadence must safely reject non-finite rolls")


static func _test_news_bookmark_signal(failures: Array[String]) -> void:
	var drawer := SideDrawerController.new()
	var emissions: Array[bool] = []
	drawer.news_requested.connect(func() -> void: emissions.append(true))
	drawer.call("_on_news_bookmark_pressed")
	if emissions.size() != 1:
		failures.append("the news bookmark must emit exactly one window request")
	drawer.free()


static func _test_news_window_fitting(failures: Array[String]) -> void:
	var fitted := NewsWindow.fit_window_size(Vector2i(1280, 680))
	if fitted != Vector2i(760, 632):
		failures.append("the news archive must fit inside the usable screen and taskbar margins")
	var compact := NewsWindow.fit_window_size(Vector2i(640, 480))
	if compact.x > 640 or compact.y > 480 or compact.x <= 0 or compact.y <= 0:
		failures.append("the news archive must remain valid on compact screens")
