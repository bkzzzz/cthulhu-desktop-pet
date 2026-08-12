extends SceneTree

const OfferingCatalog = preload("res://scripts/domain/offering_catalog.gd")
const DesktopItemCatalog = preload("res://scripts/domain/desktop_item_catalog.gd")
const DesktopItemActor = preload("res://scripts/desktop_item_actor.gd")
const CoinCollectorShovel = preload("res://scripts/coin_collector_shovel.gd")
const ShopWindow = preload("res://scripts/shop_window.gd")
const OUTPUT_DIR := "res://tests/_artifacts"


func _initialize() -> void:
	call_deferred("_render_previews")


func _render_previews() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var shop := ShopWindow.new()
	root.add_child(shop)
	shop.setup()
	var goods := OfferingCatalog.make_shop_goods()
	goods.append_array(DesktopItemCatalog.make_shop_goods())
	shop.set_goods(goods)
	shop.set_language("en")
	shop.set_coin_balance(5_000_000)
	shop.set_item_states({
		"coin_collector": {"owned": true, "deployed": true},
		"sofa": {"owned": true, "deployed": false}
	})
	shop.set("_active_category", ShopWindow.ITEM_KIND)
	shop.call("_refresh_page")
	shop.visible = true
	await process_frame
	await process_frame
	var item_shop_path := ProjectSettings.globalize_path(
		OUTPUT_DIR.path_join("shop_item_actions_preview.png")
	)
	shop.get_texture().get_image().save_png(item_shop_path)

	# Keep a Chinese hover/detail capture beside the actions preview.  This guards
	# the two-line item copy area against future truncation without filling empty
	# slots with placeholder text.
	shop.set_language("zh")
	var collector := shop.get_good("coin_collector")
	shop.call("_show_info_panel", collector, ShopWindow.INFO_STRIP_POSITION)
	await process_frame
	var item_detail_path := ProjectSettings.globalize_path(
		OUTPUT_DIR.path_join("shop_item_detail_zh_preview.png")
	)
	shop.get_texture().get_image().save_png(item_detail_path)
	shop.visible = false

	var stage_size := root.size
	var item := DesktopItemActor.new()
	root.add_child(item)
	item.setup(
		"coin_collector",
		Vector2(float(stage_size.x) * 0.5, float(stage_size.y) - 6.0),
		stage_size
	)
	var shovel := CoinCollectorShovel.new()
	shovel.name = "CoinCollectorShovel"
	item.add_child(shovel)
	shovel.setup()
	item.set_language("en")
	item.call("_set_pointer_hovered", true)
	await process_frame
	await process_frame
	var hover_path := ProjectSettings.globalize_path(
		OUTPUT_DIR.path_join("desktop_item_hover_preview.png")
	)
	root.get_texture().get_image().save_png(hover_path)

	print("PREVIEW_ITEM_SHOP=%s" % item_shop_path)
	print("PREVIEW_ITEM_DETAIL_ZH=%s" % item_detail_path)
	print("PREVIEW_ITEM_HOVER=%s" % hover_path)
	quit(0)
