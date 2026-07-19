extends RefCounted

const DEFAULT_LANGUAGE := "en"
const ENGLISH := "en"
const CHINESE := "zh"
const SUPPORTED_LANGUAGES := [ENGLISH, CHINESE]
const ENGLISH_DISPLAY_FONT := "res://assets/ui/font/NormalFont.ttf"

static var _english_body_font: Font
static var _english_display_font: Font
static var _chinese_font: Font
static var _chinese_display_font: Font


static func sanitize(language_code: String) -> String:
	return CHINESE if language_code.strip_edges().to_lower() == CHINESE else ENGLISH


static func get_ui_font(language_code: String) -> Font:
	if sanitize(language_code) == CHINESE:
		if _chinese_font == null:
			var system_font := SystemFont.new()
			system_font.font_names = PackedStringArray([
				"Microsoft YaHei UI",
				"Microsoft YaHei",
				"SimHei",
				"Noto Sans CJK SC",
				"Arial Unicode MS"
			])
			system_font.allow_system_fallback = true
			system_font.font_weight = 400
			_chinese_font = system_font
		return _chinese_font

	if _english_body_font == null:
		var system_font := SystemFont.new()
		system_font.font_names = PackedStringArray([
			"Segoe UI Variable Text",
			"Segoe UI",
			"Arial"
		])
		system_font.allow_system_fallback = true
		system_font.font_weight = 400
		_english_body_font = system_font
	return _english_body_font


static func get_display_font(language_code: String) -> Font:
	if sanitize(language_code) == CHINESE:
		if _chinese_display_font == null:
			var system_font := SystemFont.new()
			system_font.font_names = PackedStringArray([
				"Microsoft YaHei UI",
				"Microsoft YaHei",
				"Noto Sans CJK SC"
			])
			system_font.allow_system_fallback = true
			system_font.font_weight = 700
			_chinese_display_font = system_font
		return _chinese_display_font
	if _english_display_font == null:
		_english_display_font = load(ENGLISH_DISPLAY_FONT) as Font
		if _english_display_font == null:
			_english_display_font = get_ui_font(ENGLISH)
	return _english_display_font


static func get_numeric_display_font() -> Font:
	return get_display_font(ENGLISH)


static func make_ui_theme(language_code: String) -> Theme:
	var ui_theme := Theme.new()
	ui_theme.default_font = get_ui_font(language_code)
	return ui_theme
