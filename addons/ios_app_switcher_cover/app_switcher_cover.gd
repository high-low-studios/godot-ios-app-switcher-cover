@tool
extends EditorPlugin

## iOS App Switcher Cover
##
## Fixes the blank/white card iOS shows in the app switcher (multitasking)
## snapshot for Godot apps. iOS snapshots the UIKit view hierarchy, which
## EXCLUDES Godot's GPU render layer, so the card captures the empty window.
##
## On iOS export this plugin links a small prebuilt Objective-C++ static lib
## (bin/libAppSwitcherCover.a, source in src/, built by build_ios_lib.sh) that
## covers the key window with a configured image (or a solid color) on
## background and removes it on foreground. Configuration flows from Project
## Settings -> Info.plist -> the native code at runtime, so the prebuilt lib is
## generic and consumers never recompile.
##
## Project Settings (added under "ios_app_switcher_cover/"):
##   image             - a res:// image shown over the window (empty = color only)
##   background_color  - solid background behind the image (and the cover when no image)
##   scale_mode        - "fill" (cover, may crop) or "fit" (contain, centered on color)
##
## iOS-only. On Android the hook never fires (Android's Recents captures the
## window surface directly and shows the real last frame).

var _export_plugin: _ExportPlugin


func _enter_tree() -> void:
	_register_settings()
	_export_plugin = _ExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


func _register_settings() -> void:
	_ensure_setting(_ExportPlugin.SETTING_IMAGE, "", TYPE_STRING, PROPERTY_HINT_FILE, "*.png,*.jpg,*.jpeg")
	_ensure_setting(_ExportPlugin.SETTING_BG, Color.BLACK, TYPE_COLOR, PROPERTY_HINT_NONE, "")
	_ensure_setting(_ExportPlugin.SETTING_SCALE, "fill", TYPE_STRING, PROPERTY_HINT_ENUM, "fill,fit")


func _ensure_setting(setting: String, default_value: Variant, type: int, hint: int, hint_string: String) -> void:
	if not ProjectSettings.has_setting(setting):
		ProjectSettings.set_setting(setting, default_value)
	ProjectSettings.set_initial_value(setting, default_value)
	ProjectSettings.add_property_info({
		"name": setting,
		"type": type,
		"hint": hint,
		"hint_string": hint_string,
	})


class _ExportPlugin extends EditorExportPlugin:
	const SETTING_IMAGE := "ios_app_switcher_cover/image"
	const SETTING_BG := "ios_app_switcher_cover/background_color"
	const SETTING_SCALE := "ios_app_switcher_cover/scale_mode"

	# Prebuilt native cover library (arm64 device). Rebuild via build_ios_lib.sh.
	const STATIC_LIB := "res://addons/ios_app_switcher_cover/bin/libAppSwitcherCover.a"

	func _get_name() -> String:
		return "ios_app_switcher_cover"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformIOS

	func _export_begin(features: PackedStringArray, is_debug: bool, path: String, flags: int) -> void:
		if not features.has("ios"):
			return

		# Link the cover lib. "-ObjC" is REQUIRED: the class is never referenced
		# from the app's code, so without it the linker dead-strips the object
		# file and its +load never runs (no observers -> no cover).
		add_ios_project_static_lib(STATIC_LIB)
		add_ios_linker_flags("-ObjC")

		# Write the configuration into Info.plist (read by the native code).
		var plist := ""

		var image_path := str(ProjectSettings.get_setting(SETTING_IMAGE, ""))
		if image_path != "" and FileAccess.file_exists(image_path):
			add_ios_bundle_file(image_path)
			plist += _plist_string("GodotIOSAppSwitcherCoverImage", image_path.get_file())
		elif image_path != "":
			push_warning("[ios_app_switcher_cover] image not found, using background color only: " + image_path)

		var bg: Color = ProjectSettings.get_setting(SETTING_BG, Color.BLACK)
		plist += _plist_string("GodotIOSAppSwitcherCoverBackground", "#" + bg.to_html(false))

		var scale := str(ProjectSettings.get_setting(SETTING_SCALE, "fill"))
		plist += _plist_string("GodotIOSAppSwitcherCoverScaleMode", scale)

		add_ios_plist_content(plist)

	func _plist_string(key: String, value: String) -> String:
		return "<key>%s</key>\n<string>%s</string>\n" % [key, value]
