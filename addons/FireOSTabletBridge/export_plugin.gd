@tool
extends EditorPlugin

var export_plugin: AndroidExportPlugin

func _enter_tree() -> void:
	export_plugin = AndroidExportPlugin.new()
	add_export_plugin(export_plugin)

func _exit_tree() -> void:
	if export_plugin != null:
		remove_export_plugin(export_plugin)
		export_plugin = null

class AndroidExportPlugin extends EditorExportPlugin:
	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if debug:
			return PackedStringArray(["FireOSTabletBridge/bin/debug/FireOSTabletBridge.aar"])
		return PackedStringArray(["FireOSTabletBridge/bin/release/FireOSTabletBridge.aar"])

	func _get_android_manifest_activity_element_contents(platform: EditorExportPlatform, debug: bool) -> String:
		# Makes the Godot activity eligible to be selected as the user's Home app.
		return """
<intent-filter>
    <action android:name=\"android.intent.action.MAIN\" />
    <category android:name=\"android.intent.category.HOME\" />
    <category android:name=\"android.intent.category.DEFAULT\" />
</intent-filter>
"""

	func _get_name() -> String:
		return "FireOSTabletBridge"
