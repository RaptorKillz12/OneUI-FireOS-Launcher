extends Control

# ==============================================================================
# ONE UI 7 TABLET LAUNCHER & LOCK SCREEN FOR FIRE OS (GODOT 4.x)
# Attach to a root Control node set to Layout -> Full Rect.
# ==============================================================================

# --- THEME & PALETTE ---
const COLOR_SURFACE := Color("#F4F6FA")
const COLOR_SURFACE_GLASS := Color(0.95, 0.96, 0.99, 0.78)
const COLOR_CARD_WHITE := Color(1.0, 1.0, 1.0, 0.92)
const COLOR_ACCENT := Color("#3478F6")
const COLOR_TEXT_PRIMARY := Color("#17191F")
const COLOR_TEXT_SECONDARY := Color("#5C6475")
const SETTINGS_PATH := "user://launcher_settings.cfg"
const SOUND_ROOT := "user://sounds/"
const SOUND_CATEGORIES := ["notifications", "ui", "alarms"]

# --- FIRE OS / ANDROID PACKAGE REGISTRY ---
var installed_apps: Array[Dictionary] = [
	{"name": "Settings", "color": Color("#4A90E2"), "uri": "intent:#Intent;action=android.settings.SETTINGS;end", "dock": true, "home": false},
	{"name": "Silk Browser", "color": Color("#FF9500"), "uri": "https://www.amazon.com", "dock": true, "home": false},
	{"name": "Prime Video", "color": Color("#00A8E1"), "uri": "intent:#Intent;package=com.amazon.avod;end", "dock": true, "home": false},
	{"name": "Appstore", "color": Color("#FF9900"), "uri": "intent:#Intent;package=com.amazon.venezia;end", "dock": true, "home": false},
	{"name": "Files", "color": Color("#34C759"), "uri": "intent:#Intent;action=android.intent.action.VIEW;type=resource/folder;end", "dock": true, "home": false},
	{"name": "Camera", "color": Color("#FF3B30"), "uri": "intent:#Intent;action=android.media.action.IMAGE_CAPTURE;end", "dock": true, "home": false},
	{"name": "Clock", "color": Color("#5856D6"), "uri": "intent:#Intent;action=android.intent.action.SHOW_ALARMS;end", "dock": false, "home": true},
	{"name": "Calculator", "color": Color("#FF2D55"), "uri": "intent:#Intent;package=com.android.calculator2;end", "dock": false, "home": true},
	{"name": "Gallery", "color": Color("#AF52DE"), "uri": "intent:#Intent;action=android.intent.action.VIEW;type=image/*;end", "dock": false, "home": true},
	{"name": "Music", "color": Color("#FA2D48"), "uri": "intent:#Intent;package=com.amazon.mp3;end", "dock": false, "home": true},
	{"name": "Kindle", "color": Color("#1D70B8"), "uri": "intent:#Intent;package=com.amazon.kindle;end", "dock": false, "home": true},
	{"name": "Fire TV", "color": Color("#232F3E"), "uri": "intent:#Intent;package=com.amazon.storm.lightning.client.aosp;end", "dock": false, "home": false}
]

# --- SAMPLE NOTIFICATIONS ---
var notifications_data: Array[Dictionary] = [
	{"app": "System UI", "title": "One UI 7 Tablet Active", "body": "Split notification and quick panel gestures enabled."},
	{"app": "Prime Video", "title": "Continue Watching", "body": "New episodes available to stream offline."}
]

# --- LAUNCHER STATE ---
var is_locked := true
var is_drawer_open := false
var is_notif_open := false
var is_qs_open := false
var is_playing_media := false
var drag_start_pos := Vector2.ZERO
var drag_mode := ""

# --- HOME EDIT MENU STATE ---
var desktop_hold_timer := 0.0
var is_desktop_holding := false
var home_edit_menu: PanelContainer

# --- UI REFERENCES ---
var master_container: Control
var wallpaper_rect: ColorRect
var blur_backdrop: ColorRect
var status_bar: HBoxContainer
var status_time_lbl: Label
var home_layer: Control
var home_clock_lbl: Label
var home_date_lbl: Label
var app_drawer_panel: PanelContainer
var drawer_scroll: ScrollContainer
var drawer_grid: GridContainer
var search_input: LineEdit
var notif_shade: PanelContainer
var notif_list: VBoxContainer
var notif_scroll: ScrollContainer
var qs_shade: PanelContainer
var qs_scroll: ScrollContainer
var qs_header: HBoxContainer
var brightness_slider: HSlider
var volume_slider: HSlider
var media_play_btn: Button
var dim_overlay: ColorRect
var lock_screen: PanelContainer
var lock_clock_lbl: Label
var lock_date_lbl: Label
var now_bar_label: Label
var nav_bar: HBoxContainer

# --- SOUND & ALARM STATE ---
var notification_player: AudioStreamPlayer
var ui_player: AudioStreamPlayer
var alarm_player: AudioStreamPlayer
var alarm_check_timer: Timer
var alarm_repeat_timer: Timer
var sound_config := ConfigFile.new()
var selected_sounds: Dictionary = {"notifications": "", "ui": "", "alarms": ""}
var alarm_entries: Array[Dictionary] = []
var last_alarm_minute := ""
var active_alarm_name := ""
var alarm_dialog: AcceptDialog
var sound_settings_panel: PanelContainer
var alarm_manager_panel: PanelContainer
var sound_file_dialog: FileDialog
var import_category := "notifications"
var sound_selector_controls: Dictionary = {}

# Native Android bridge. It is present only in Android exports that include
# addons/FireOSTabletBridge and its compiled AAR.
var android_bridge: Variant = null
var android_notifications_timer: Timer
var seen_android_notification_ids: Dictionary = {}
var android_notifications_initialized := false
var android_notifications_start_time_ms := 0
var android_status_label: Label
var system_tile_buttons: Dictionary = {}
var home_grid_reference: GridContainer
var drawer_grid_reference: GridContainer
var _is_resizing := false

func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	_setup_sound_players()
	_load_sound_settings()
	_load_alarms()
	_connect_android_bridge()
	android_notifications_start_time_ms = int(Time.get_unix_time_from_system() * 1000.0)
	if android_bridge != null:
		android_bridge.setSystemBarsHidden(true)
	_refresh_installed_apps_from_android()
	_build_ui()
	_update_clock()
	_update_now_bar()
	_update_android_status()
	_wire_ui_sounds(self)

	var clock_timer := Timer.new()
	clock_timer.wait_time = 1.0
	clock_timer.autostart = true
	clock_timer.timeout.connect(_update_clock)
	add_child(clock_timer)

	alarm_check_timer = Timer.new()
	alarm_check_timer.wait_time = 1.0
	alarm_check_timer.autostart = true
	alarm_check_timer.timeout.connect(_check_alarms)
	add_child(alarm_check_timer)

	alarm_repeat_timer = Timer.new()
	alarm_repeat_timer.wait_time = 2.0
	alarm_repeat_timer.one_shot = true
	alarm_repeat_timer.timeout.connect(_repeat_alarm_sound)
	add_child(alarm_repeat_timer)

	android_notifications_timer = Timer.new()
	android_notifications_timer.wait_time = 2.0
	android_notifications_timer.autostart = true
	android_notifications_timer.timeout.connect(_poll_android_notifications)
	add_child(android_notifications_timer)
	_sync_native_alarms()

func _process(delta: float) -> void:
	if is_desktop_holding:
		desktop_hold_timer += delta
		if desktop_hold_timer >= 0.7:
			is_desktop_holding = false
			_open_home_edit_menu()

# ==============================================================================
# SOUND SYSTEM
# ==============================================================================
func _setup_sound_players() -> void:
	notification_player = AudioStreamPlayer.new()
	notification_player.name = "NotificationSoundPlayer"
	notification_player.bus = "Master"
	add_child(notification_player)

	ui_player = AudioStreamPlayer.new()
	ui_player.name = "UISoundPlayer"
	ui_player.bus = "Master"
	add_child(ui_player)

	alarm_player = AudioStreamPlayer.new()
	alarm_player.name = "AlarmSoundPlayer"
	alarm_player.bus = "Master"
	alarm_player.finished.connect(_on_alarm_sound_finished)
	add_child(alarm_player)

func _load_sound_settings() -> void:
	var err := sound_config.load(SETTINGS_PATH)
	for category in SOUND_CATEGORIES:
		if err == OK:
			selected_sounds[category] = str(sound_config.get_value("sounds", category, ""))
		else:
			selected_sounds[category] = ""

func _save_sound_settings() -> void:
	for category in SOUND_CATEGORIES:
		sound_config.set_value("sounds", category, str(selected_sounds[category]))
	sound_config.save(SETTINGS_PATH)

func _ensure_sound_directories() -> void:
	for category in SOUND_CATEGORIES:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SOUND_ROOT + category + "/"))

func _scan_sounds(category: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = [{"label": "Silent", "path": ""}]
	var folders := ["res://audio/" + category + "/", SOUND_ROOT + category + "/"]
	for folder in folders:
		var dir := DirAccess.open(folder)
		if dir == null:
			continue
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and _is_supported_audio(file_name):
				var path = folder + file_name
				var label := file_name.get_basename()
				var already_added := false
				for item in found:
					if item["path"] == path:
						already_added = true
						break
				if not already_added:
					found.append({"label": label, "path": path})
			file_name = dir.get_next()
		dir.list_dir_end()
	return found

func _is_supported_audio(file_name: String) -> bool:
	return file_name.get_extension().to_lower() in ["ogg", "wav", "mp3"]

func _load_audio_stream(path: String) -> AudioStream:
	if path.is_empty():
		return null
	var global_path := ProjectSettings.globalize_path(path) if path.begins_with("user://") or path.begins_with("res://") else path
	match path.get_extension().to_lower():
		"ogg": return AudioStreamOggVorbis.load_from_file(global_path)
		"wav": return AudioStreamWAV.load_from_file(global_path)
		"mp3": return AudioStreamMP3.load_from_file(global_path)
	return null

func _play_category_sound(category: String) -> void:
	var path := str(selected_sounds.get(category, ""))
	if path.is_empty():
		return
	var stream := _load_audio_stream(path)
	if stream == null:
		push_warning("Could not load sound: " + path)
		return
	var player: AudioStreamPlayer
	match category:
		"notifications": player = notification_player
		"ui": player = ui_player
		"alarms": player = alarm_player
		_: return
	player.stop()
	player.stream = stream
	player.play()

func play_notification_sound() -> void:
	_play_category_sound("notifications")

func play_ui_sound() -> void:
	_play_category_sound("ui")

func play_alarm_sound() -> void:
	_play_category_sound("alarms")

func _wire_ui_sounds(node: Node) -> void:
	if node is Button and not node.has_meta("ui_sound_wired"):
		node.set_meta("ui_sound_wired", true)
		(node as Button).pressed.connect(play_ui_sound)
	for child in node.get_children():
		_wire_ui_sounds(child)

func _open_sound_settings() -> void:
	if is_instance_valid(sound_settings_panel):
		sound_settings_panel.queue_free()
	sound_settings_panel = PanelContainer.new()
	sound_settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	sound_settings_panel.add_theme_stylebox_override("panel", _make_squircle_style(Color(0.95, 0.96, 0.99, 0.97), 0))
	master_container.add_child(sound_settings_panel)

	var center := CenterContainer.new()
	sound_settings_panel.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(minf(680.0, get_viewport_rect().size.x - 64.0), minf(620.0, get_viewport_rect().size.y - 80.0))
	card.add_theme_stylebox_override("panel", _make_squircle_style(COLOR_CARD_WHITE, 32))
	center.add_child(card)

	var outer := MarginContainer.new()
	for key in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		outer.add_theme_constant_override(key, 32)
	card.add_child(outer)

	var content_scroll := ScrollContainer.new()
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(content_scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 16)
	content_scroll.add_child(column)

	var heading := Label.new()
	heading.text = "Sound & Alarm Settings"
	heading.add_theme_font_size_override("font_size", 26)
	heading.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	column.add_child(heading)

	var description := Label.new()
	description.text = "Choose sounds for One UI notifications, system touches, and alarms."
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	column.add_child(description)

	for category in SOUND_CATEGORIES:
		_add_sound_selector(column, category)

	var import_row := HBoxContainer.new()
	import_row.add_theme_constant_override("separation", 12)
	column.add_child(import_row)
	var import_button := Button.new()
	import_button.text = "Import custom sound"
	import_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	import_button.custom_minimum_size.y = 48
	import_button.pressed.connect(_show_import_category_picker)
	import_row.add_child(import_button)

	var test_button := Button.new()
	test_button.text = "Test selected"
	test_button.custom_minimum_size = Vector2(150, 48)
	test_button.pressed.connect(_test_selected_sounds)
	import_row.add_child(test_button)

	var alarm_button := Button.new()
	alarm_button.text = "Manage alarms"
	alarm_button.custom_minimum_size.y = 48
	alarm_button.pressed.connect(_open_alarm_manager)
	column.add_child(alarm_button)

	var android_access_row := HBoxContainer.new()
	android_access_row.add_theme_constant_override("separation", 10)
	column.add_child(android_access_row)
	var notif_access_button := Button.new()
	notif_access_button.text = "Enable notification access"
	notif_access_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notif_access_button.custom_minimum_size.y = 46
	notif_access_button.pressed.connect(_open_android_notification_access)
	android_access_row.add_child(notif_access_button)
	var home_button := Button.new()
	home_button.text = "Default Home app"
	home_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home_button.custom_minimum_size.y = 46
	home_button.pressed.connect(_open_android_home_settings)
	android_access_row.add_child(home_button)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	var close_button := Button.new()
	close_button.text = "Done"
	close_button.custom_minimum_size.y = 50
	close_button.add_theme_color_override("font_color", Color.WHITE)
	close_button.add_theme_stylebox_override("normal", _make_squircle_style(COLOR_ACCENT, 25))
	close_button.pressed.connect(func(): sound_settings_panel.queue_free())
	column.add_child(close_button)
	_wire_ui_sounds(sound_settings_panel)

func _add_sound_selector(parent: VBoxContainer, category: String) -> void:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 5)
	parent.add_child(section)

	var label := Label.new()
	label.text = {"notifications": "Notification sound", "ui": "UI touch sound", "alarms": "Alarm sound"}[category]
	label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	section.add_child(label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	section.add_child(row)
	var selector := OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.custom_minimum_size.y = 44
	var sounds := _scan_sounds(category)
	var selected_index := 0
	for i in range(sounds.size()):
		selector.add_item(str(sounds[i]["label"]))
		selector.set_item_metadata(i, str(sounds[i]["path"]))
		if str(sounds[i]["path"]) == str(selected_sounds[category]):
			selected_index = i
	selector.select(selected_index)
	selector.item_selected.connect(func(index: int):
		selected_sounds[category] = str(selector.get_item_metadata(index))
		_save_sound_settings()
	)
	row.add_child(selector)

	var import_button := Button.new()
	import_button.text = "+"
	import_button.custom_minimum_size = Vector2(48, 44)
	import_button.pressed.connect(func(): _open_sound_importer(category))
	row.add_child(import_button)
	sound_selector_controls[category] = selector

func _show_import_category_picker() -> void:
	var picker := ConfirmationDialog.new()
	picker.title = "Import sound for"
	picker.dialog_text = "Choose which sound setting should use the imported file."
	var buttons := HBoxContainer.new()
	for category in SOUND_CATEGORIES:
		var category_name := category
		var button := Button.new()
		button.text = category_name.capitalize()
		button.pressed.connect(func():
			picker.queue_free()
			_open_sound_importer(category_name)
		)
		buttons.add_child(button)
	picker.add_child(buttons)
	add_child(picker)
	picker.popup_centered(Vector2i(520, 150))

func _open_sound_importer(category: String) -> void:
	import_category = category
	_ensure_sound_directories()
	if not is_instance_valid(sound_file_dialog):
		sound_file_dialog = FileDialog.new()
		sound_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		sound_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		sound_file_dialog.filters = PackedStringArray(["*.ogg ; OGG Audio", "*.wav ; WAV Audio", "*.mp3 ; MP3 Audio"])
		sound_file_dialog.file_selected.connect(_import_custom_sound)
		add_child(sound_file_dialog)
	sound_file_dialog.title = "Select custom " + category + " sound"
	sound_file_dialog.popup_centered(Vector2i(850, 600))

func _import_custom_sound(source_path: String) -> void:
	if not _is_supported_audio(source_path.get_file()):
		_show_message("Unsupported audio", "Choose an OGG, WAV or MP3 file.")
		return
	_ensure_sound_directories()
	var destination := SOUND_ROOT + import_category + "/custom_" + str(Time.get_ticks_msec()) + "." + source_path.get_extension().to_lower()
	var input := FileAccess.open(source_path, FileAccess.READ)
	if input == null:
		_show_message("Import failed", "Godot could not read that file. Android file permissions may be limiting access.")
		return
	var bytes := input.get_buffer(input.get_length())
	input.close()
	var output := FileAccess.open(destination, FileAccess.WRITE)
	if output == null:
		_show_message("Import failed", "Could not create the sound file in user://sounds/.")
		return
	output.store_buffer(bytes)
	output.close()
	selected_sounds[import_category] = destination
	_save_sound_settings()
	_refresh_sound_selector(import_category)
	_play_category_sound(import_category)
	_show_message("Sound imported", "The custom sound is now selected for " + import_category + ".")

func _refresh_sound_selector(category: String) -> void:
	if not sound_selector_controls.has(category):
		return
	var selector: OptionButton = sound_selector_controls[category]
	selector.clear()
	var sounds := _scan_sounds(category)
	for i in range(sounds.size()):
		selector.add_item(str(sounds[i]["label"]))
		selector.set_item_metadata(i, str(sounds[i]["path"]))
		if str(sounds[i]["path"]) == str(selected_sounds[category]):
			selector.select(i)

func _test_selected_sounds() -> void:
	play_notification_sound()
	await get_tree().create_timer(0.25).timeout
	play_ui_sound()
	await get_tree().create_timer(0.25).timeout
	play_alarm_sound()

func _show_message(title_text: String, body_text: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = title_text
	dialog.dialog_text = body_text
	add_child(dialog)
	dialog.confirmed.connect(func(): dialog.queue_free())
	dialog.close_requested.connect(func(): dialog.queue_free())
	dialog.popup_centered()

# ==============================================================================
# ALARM MANAGER
# ==============================================================================
func _load_alarms() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		alarm_entries.clear()
		return
	var saved: Variant = config.get_value("alarms", "entries", [])
	alarm_entries.clear()
	if saved is Array:
		for item in saved:
			if item is Dictionary:
				alarm_entries.append(item.duplicate(true))
	_sync_native_alarms()

func _save_alarms() -> void:
	sound_config.set_value("alarms", "entries", alarm_entries)
	sound_config.save(SETTINGS_PATH)

func add_alarm(hour: int, minute: int) -> void:
	var new_alarm := {"id": int(Time.get_ticks_msec()), "hour": clampi(hour, 0, 23), "minute": clampi(minute, 0, 59), "enabled": true}
	alarm_entries.append(new_alarm)
	_schedule_native_alarm(new_alarm)
	_save_alarms()
	_update_now_bar()
	if is_instance_valid(alarm_manager_panel):
		_refresh_alarm_list()

func _check_alarms() -> void:
	if alarm_entries.is_empty():
		return
	var now := Time.get_datetime_dict_from_system()
	var hour_now := int(now["hour"])
	var minute_now := int(now["minute"])
	var date_key := "%04d-%02d-%02d-%02d-%02d" % [now["year"], now["month"], now["day"], hour_now, minute_now]
	if date_key == last_alarm_minute:
		return
	var matched_count := 0
	for alarm in alarm_entries:
		if bool(alarm.get("enabled", true)) and int(alarm.get("hour", -1)) == hour_now and int(alarm.get("minute", -1)) == minute_now:
			matched_count += 1
	if matched_count > 0:
		last_alarm_minute = date_key
		var alarm_label := "%02d:%02d" % [hour_now, minute_now]
		if matched_count > 1:
			alarm_label += " · %d alarms" % matched_count
		_start_alarm(alarm_label)

func _start_alarm(alarm_name: String) -> void:
	active_alarm_name = alarm_name
	_update_now_bar()
	play_alarm_sound()
	if not is_instance_valid(alarm_dialog):
		alarm_dialog = AcceptDialog.new()
		alarm_dialog.confirmed.connect(_stop_alarm)
		alarm_dialog.close_requested.connect(_stop_alarm)
		add_child(alarm_dialog)
	alarm_dialog.title = "Alarm"
	alarm_dialog.dialog_text = "It's " + alarm_name + "."
	alarm_dialog.ok_button_text = "Stop alarm"
	alarm_dialog.popup_centered(Vector2i(420, 180))

func _on_alarm_sound_finished() -> void:
	if is_instance_valid(alarm_dialog) and alarm_dialog.visible:
		alarm_repeat_timer.start()

func _repeat_alarm_sound() -> void:
	if is_instance_valid(alarm_dialog) and alarm_dialog.visible:
		play_alarm_sound()

func _stop_alarm() -> void:
	if is_instance_valid(alarm_repeat_timer):
		alarm_repeat_timer.stop()
	if is_instance_valid(alarm_player):
		alarm_player.stop()
	active_alarm_name = ""
	_update_now_bar()

func _open_alarm_manager() -> void:
	if is_instance_valid(alarm_manager_panel):
		alarm_manager_panel.queue_free()
	alarm_manager_panel = PanelContainer.new()
	alarm_manager_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	alarm_manager_panel.add_theme_stylebox_override("panel", _make_squircle_style(Color(0.95, 0.96, 0.99, 0.98), 0))
	master_container.add_child(alarm_manager_panel)

	var center := CenterContainer.new()
	alarm_manager_panel.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(minf(680.0, get_viewport_rect().size.x - 64.0), 540.0)
	card.add_theme_stylebox_override("panel", _make_squircle_style(COLOR_CARD_WHITE, 32))
	center.add_child(card)

	var margin := MarginContainer.new()
	for key in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(key, 32)
	card.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	var title := Label.new()
	title.text = "Alarms"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	column.add_child(title)

	var add_card := PanelContainer.new()
	add_card.add_theme_stylebox_override("panel", _make_squircle_style(COLOR_SURFACE, 22))
	column.add_child(add_card)
	var add_margin := MarginContainer.new()
	for key in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		add_margin.add_theme_constant_override(key, 14)
	add_card.add_child(add_margin)
	var add_row := HBoxContainer.new()
	add_row.add_theme_constant_override("separation", 12)
	add_margin.add_child(add_row)

	var hour_spin := SpinBox.new()
	hour_spin.min_value = 0
	hour_spin.max_value = 23
	hour_spin.value = 7
	hour_spin.prefix = "Hour "
	hour_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_child(hour_spin)

	var minute_spin := SpinBox.new()
	minute_spin.min_value = 0
	minute_spin.max_value = 59
	minute_spin.value = 0
	minute_spin.prefix = "Min "
	minute_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_row.add_child(minute_spin)

	var add_button := Button.new()
	add_button.text = "Add"
	add_button.custom_minimum_size = Vector2(84, 44)
	add_button.pressed.connect(func(): add_alarm(int(hour_spin.value), int(minute_spin.value)))
	add_row.add_child(add_button)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var alarm_list := VBoxContainer.new()
	alarm_list.name = "AlarmList"
	alarm_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alarm_list.add_theme_constant_override("separation", 10)
	scroll.add_child(alarm_list)

	var close := Button.new()
	close.text = "Done"
	close.custom_minimum_size.y = 48
	close.add_theme_color_override("font_color", Color.WHITE)
	close.add_theme_stylebox_override("normal", _make_squircle_style(COLOR_ACCENT, 24))
	close.pressed.connect(func(): alarm_manager_panel.queue_free())
	column.add_child(close)
	alarm_manager_panel.set_meta("alarm_list", alarm_list)
	_refresh_alarm_list()
	_wire_ui_sounds(alarm_manager_panel)

func _refresh_alarm_list() -> void:
	if not is_instance_valid(alarm_manager_panel):
		return
	var list_node: Variant = alarm_manager_panel.get_meta("alarm_list", null)
	if not is_instance_valid(list_node):
		return
	var alarm_list := list_node as VBoxContainer
	for child in alarm_list.get_children():
		child.queue_free()
	if alarm_entries.is_empty():
		var empty_label := Label.new()
		empty_label.text = "No alarms yet. Add one above."
		empty_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		alarm_list.add_child(empty_label)
		_wire_ui_sounds(alarm_list)
		return
	for i in range(alarm_entries.size()):
		var index := i
		var alarm: Dictionary = alarm_entries[index]
		var row := PanelContainer.new()
		row.add_theme_stylebox_override("panel", _make_squircle_style(COLOR_SURFACE, 18))
		alarm_list.add_child(row)
		var inner_margin := MarginContainer.new()
		for key in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
			inner_margin.add_theme_constant_override(key, 10)
		row.add_child(inner_margin)
		var inner := HBoxContainer.new()
		inner.add_theme_constant_override("separation", 12)
		inner_margin.add_child(inner)
		var time_label := Label.new()
		time_label.text = "%02d:%02d" % [int(alarm.get("hour", 7)), int(alarm.get("minute", 0))]
		time_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		time_label.add_theme_font_size_override("font_size", 24)
		time_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		inner.add_child(time_label)
		var enabled_toggle := CheckButton.new()
		enabled_toggle.button_pressed = bool(alarm.get("enabled", true))
		enabled_toggle.toggled.connect(func(enabled: bool):
			if index < alarm_entries.size():
				alarm_entries[index]["enabled"] = enabled
				if enabled:
					_schedule_native_alarm(alarm_entries[index])
				else:
					_cancel_native_alarm(alarm_entries[index])
				_save_alarms()
				_update_now_bar()
		)
		inner.add_child(enabled_toggle)
		var delete_button := Button.new()
		delete_button.text = "Delete"
		delete_button.pressed.connect(func():
			if index < alarm_entries.size():
				var removed_alarm: Dictionary = alarm_entries[index]
				_cancel_native_alarm(removed_alarm)
				alarm_entries.remove_at(index)
				_save_alarms()
				_refresh_alarm_list()
				_update_now_bar()
		)
		inner.add_child(delete_button)

	_wire_ui_sounds(alarm_list)

# ==============================================================================
# PROCEDURAL ONE UI 7 TABLET BUILDER
# ==============================================================================
func _build_ui() -> void:
	master_container = Control.new()
	master_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(master_container)

	wallpaper_rect = ColorRect.new()
	wallpaper_rect.color = Color("#D6E4FA")
	wallpaper_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	master_container.add_child(wallpaper_rect)

	var glow_a := Panel.new()
	glow_a.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow_a.offset_left = -get_viewport_rect().size.x * 0.10
	glow_a.offset_top = get_viewport_rect().size.y * 0.28
	glow_a.offset_right = get_viewport_rect().size.x * 0.45
	glow_a.offset_bottom = get_viewport_rect().size.y * 0.95
	glow_a.add_theme_stylebox_override("panel", _make_squircle_style(Color("#9EC0F5"), 280))
	master_container.add_child(glow_a)

	var glow_b := Panel.new()
	glow_b.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow_b.offset_left = get_viewport_rect().size.x * 0.50
	glow_b.offset_top = -get_viewport_rect().size.y * 0.22
	glow_b.offset_right = get_viewport_rect().size.x * 0.20
	glow_b.offset_bottom = get_viewport_rect().size.y * 0.38
	glow_b.add_theme_stylebox_override("panel", _make_squircle_style(Color("#B2DCEB"), 280))
	master_container.add_child(glow_b)

	_build_home_screen()

	blur_backdrop = ColorRect.new()
	blur_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	blur_backdrop.visible = false
	blur_backdrop.modulate.a = 0.0
	blur_backdrop.material = _make_blur_material(3.5)
	master_container.add_child(blur_backdrop)

	_build_app_drawer()
	_build_notification_shade()
	_build_quick_settings()
	_build_navigation_bar()
	_build_status_bar()
	_build_lock_screen()
	_build_home_edit_menu()

	dim_overlay = ColorRect.new()
	dim_overlay.color = Color(0, 0, 0, 0)
	dim_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	master_container.add_child(dim_overlay)

func _make_blur_material(blur_lod: float) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = """
	shader_type canvas_item;
	uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
	uniform float lod : hint_range(0.0, 6.0) = 3.5;
	uniform vec4 tint : source_color = vec4(0.94, 0.96, 1.0, 0.35);
	void fragment() {
		vec4 blurred = textureLod(SCREEN_TEXTURE, SCREEN_UV, lod);
		COLOR = mix(blurred, tint, tint.a);
	}
	"""
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("lod", blur_lod)
	return mat

func _build_status_bar() -> void:
	status_bar = HBoxContainer.new()
	status_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	status_bar.offset_left = 28
	status_bar.offset_right = -28
	status_bar.offset_top = 8
	status_bar.custom_minimum_size = Vector2(0, 34)
	master_container.add_child(status_bar)

	status_time_lbl = Label.new()
	status_time_lbl.text = "12:00"
	status_time_lbl.add_theme_font_size_override("font_size", 15)
	status_time_lbl.add_theme_color_override("font_color", Color("#1D2534"))
	status_bar.add_child(status_time_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_bar.add_child(spacer)

	android_status_label = Label.new()
	android_status_label.text = "Wi-Fi   ●   --%"
	android_status_label.add_theme_font_size_override("font_size", 15)
	android_status_label.add_theme_color_override("font_color", Color("#1D2534"))
	status_bar.add_child(android_status_label)

func _build_home_screen() -> void:
	home_layer = Control.new()
	home_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	master_container.add_child(home_layer)

	var main_margin := MarginContainer.new()
	main_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_margin.add_theme_constant_override("margin_left", 56)
	main_margin.add_theme_constant_override("margin_right", 56)
	main_margin.add_theme_constant_override("margin_top", 68)
	main_margin.add_theme_constant_override("margin_bottom", 64)
	home_layer.add_child(main_margin)

	var home_vbox := VBoxContainer.new()
	home_vbox.add_theme_constant_override("separation", 24)
	main_margin.add_child(home_vbox)

	var top_widgets := HBoxContainer.new()
	top_widgets.add_theme_constant_override("separation", 24)
	home_vbox.add_child(top_widgets)

	var clock_box := VBoxContainer.new()
	clock_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clock_box.add_theme_constant_override("separation", -4)
	top_widgets.add_child(clock_box)

	home_clock_lbl = Label.new()
	home_clock_lbl.text = "12:00"
	home_clock_lbl.add_theme_font_size_override("font_size", 76 if get_viewport_rect().size.x >= 900 else 58)
	home_clock_lbl.add_theme_color_override("font_color", Color("#162136"))
	clock_box.add_child(home_clock_lbl)

	home_date_lbl = Label.new()
	home_date_lbl.text = "Wed, Nov 18"
	home_date_lbl.add_theme_font_size_override("font_size", 20)
	home_date_lbl.add_theme_color_override("font_color", Color("#3C4A63"))
	clock_box.add_child(home_date_lbl)

	var weather := PanelContainer.new()
	weather.custom_minimum_size = Vector2(280, 118)
	weather.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	weather.add_theme_stylebox_override("panel", _make_squircle_style(Color(1.0, 1.0, 1.0, 0.56), 30))
	top_widgets.add_child(weather)

	var weather_margin := MarginContainer.new()
	for key in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		weather_margin.add_theme_constant_override(key, 18)
	weather.add_child(weather_margin)

	var weather_col := VBoxContainer.new()
	weather_col.add_theme_constant_override("separation", 4)
	weather_margin.add_child(weather_col)

	var weather_value := Label.new()
	weather_value.text = "☀  72°"
	weather_value.add_theme_font_size_override("font_size", 32)
	weather_value.add_theme_color_override("font_color", Color("#1A263B"))
	weather_col.add_child(weather_value)

	var weather_note := Label.new()
	weather_note.text = "Mostly Sunny · Tap for forecast"
	weather_note.add_theme_font_size_override("font_size", 13)
	weather_note.add_theme_color_override("font_color", Color("#4F5E78"))
	weather_col.add_child(weather_note)

	var mid_spacer := Control.new()
	mid_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	home_vbox.add_child(mid_spacer)

	var home_grid := GridContainer.new()
	home_grid.columns = 5
	home_grid_reference = home_grid
	home_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home_grid.add_theme_constant_override("h_separation", 28)
	home_grid.add_theme_constant_override("v_separation", 20)
	home_vbox.add_child(home_grid)
	for app in installed_apps:
		if app.get("home", false):
			home_grid.add_child(_create_app_icon(app, true))

	var dots_row := HBoxContainer.new()
	dots_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dots_row.add_theme_constant_override("separation", 10)
	home_vbox.add_child(dots_row)
	for i in range(2):
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(18 if i == 0 else 7, 7)
		dot.add_theme_stylebox_override("panel", _make_squircle_style(Color(1, 1, 1, 0.95 if i == 0 else 0.45), 4))
		dots_row.add_child(dot)

	var dock_panel := PanelContainer.new()
	dock_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dock_panel.add_theme_stylebox_override("panel", _make_squircle_style(Color(1.0, 1.0, 1.0, 0.55), 34))
	home_vbox.add_child(dock_panel)

	var dock_margin := MarginContainer.new()
	for key in ["margin_top", "margin_bottom"]:
		dock_margin.add_theme_constant_override(key, 12)
	for key in ["margin_left", "margin_right"]:
		dock_margin.add_theme_constant_override(key, 22)
	dock_panel.add_child(dock_margin)

	var dock_hbox := HBoxContainer.new()
	dock_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	dock_hbox.add_theme_constant_override("separation", 24)
	dock_margin.add_child(dock_hbox)

	var drawer_btn := Button.new()
	drawer_btn.text = "⋮⋮⋮"
	drawer_btn.custom_minimum_size = Vector2(64, 64)
	drawer_btn.add_theme_font_size_override("font_size", 22)
	drawer_btn.add_theme_color_override("font_color", Color("#1D2738"))
	drawer_btn.add_theme_stylebox_override("normal", _make_squircle_style(Color(1.0, 1.0, 1.0, 0.65), 22))
	drawer_btn.pressed.connect(_open_drawer)
	dock_hbox.add_child(drawer_btn)

	for app in installed_apps:
		if app["dock"]:
			dock_hbox.add_child(_create_app_icon(app, false))

func _build_app_drawer() -> void:
	app_drawer_panel = PanelContainer.new()
	app_drawer_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	app_drawer_panel.add_theme_stylebox_override("panel", _make_squircle_style(Color(0.94, 0.96, 1.0, 0.25), 0))
	app_drawer_panel.visible = false
	app_drawer_panel.position.y = 1200
	master_container.add_child(app_drawer_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 56)
	margin.add_theme_constant_override("margin_bottom", 64)
	margin.add_theme_constant_override("margin_left", 64)
	margin.add_theme_constant_override("margin_right", 64)
	app_drawer_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 20)
	margin.add_child(vbox)

	drawer_scroll = ScrollContainer.new()
	drawer_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(drawer_scroll)

	drawer_grid = GridContainer.new()
	drawer_grid.columns = 7 if get_viewport_rect().size.x >= 1000 else 5
	drawer_grid_reference = drawer_grid
	drawer_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drawer_grid.add_theme_constant_override("h_separation", 28)
	drawer_grid.add_theme_constant_override("v_separation", 30)
	drawer_scroll.add_child(drawer_grid)
	for app in installed_apps:
		drawer_grid.add_child(_create_app_icon(app, true))

	var bottom_bar := HBoxContainer.new()
	bottom_bar.add_theme_constant_override("separation", 16)
	vbox.add_child(bottom_bar)

	var search_pill := PanelContainer.new()
	search_pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_pill.add_theme_stylebox_override("panel", _make_squircle_style(Color(1.0, 1.0, 1.0, 0.72), 29))
	bottom_bar.add_child(search_pill)

	var pill_hbox := HBoxContainer.new()
	search_pill.add_child(pill_hbox)

	search_input = LineEdit.new()
	search_input.placeholder_text = "Search"
	search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_input.custom_minimum_size = Vector2(0, 56)
	search_input.add_theme_font_size_override("font_size", 18)
	search_input.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	search_input.add_theme_color_override("font_placeholder_color", COLOR_TEXT_SECONDARY)
	var empty_sb := StyleBoxEmpty.new()
	empty_sb.content_margin_left = 22
	search_input.add_theme_stylebox_override("normal", empty_sb)
	search_input.add_theme_stylebox_override("focus", empty_sb)
	search_input.text_changed.connect(_filter_apps)
	pill_hbox.add_child(search_input)

	var more_btn := Button.new()
	more_btn.text = "⋮"
	more_btn.flat = true
	more_btn.custom_minimum_size = Vector2(52, 56)
	more_btn.add_theme_font_size_override("font_size", 22)
	more_btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	more_btn.pressed.connect(_open_sound_settings)
	pill_hbox.add_child(more_btn)

	var knox_lbl := Label.new()
	knox_lbl.text = "Secured by\nKnox"
	knox_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	knox_lbl.add_theme_font_size_override("font_size", 12)
	knox_lbl.add_theme_color_override("font_color", Color(0.15, 0.20, 0.30, 0.75))
	bottom_bar.add_child(knox_lbl)

func _build_notification_shade() -> void:
	notif_shade = PanelContainer.new()
	notif_shade.set_anchors_preset(Control.PRESET_TOP_LEFT)
	notif_shade.offset_left = 36
	notif_shade.offset_top = 48
	notif_shade.offset_right = minf(560.0, get_viewport_rect().size.x - 36.0)
	notif_shade.offset_bottom = get_viewport_rect().size.y - 68
	notif_shade.add_theme_stylebox_override("panel", _make_squircle_style(COLOR_SURFACE_GLASS, 34))
	notif_shade.visible = false
	notif_shade.position.y = -1200
	master_container.add_child(notif_shade)

	var margin := MarginContainer.new()
	for key in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(key, 24)
	notif_shade.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	margin.add_child(col)

	var header := HBoxContainer.new()
	col.add_child(header)

	var title := Label.new()
	title.text = "Notifications"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var switch_qs_btn := Button.new()
	switch_qs_btn.text = "Quick panel →"
	switch_qs_btn.flat = true
	switch_qs_btn.add_theme_color_override("font_color", COLOR_ACCENT)
	switch_qs_btn.pressed.connect(func():
		_close_notif()
		_open_qs()
	)
	header.add_child(switch_qs_btn)

	notif_scroll = ScrollContainer.new()
	notif_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notif_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(notif_scroll)
	notif_list = VBoxContainer.new()
	notif_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notif_list.add_theme_constant_override("separation", 10)
	notif_scroll.add_child(notif_list)
	_populate_notifications()
	_wire_ui_sounds(notif_list)

	var footer := HBoxContainer.new()
	col.add_child(footer)

	var notif_settings_btn := Button.new()
	notif_settings_btn.text = "Notification settings"
	notif_settings_btn.flat = true
	notif_settings_btn.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	notif_settings_btn.pressed.connect(_open_android_notification_access)
	footer.add_child(notif_settings_btn)

	var f_spacer := Control.new()
	f_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(f_spacer)

	var clear_button := Button.new()
	clear_button.text = "Clear all"
	clear_button.flat = true
	clear_button.add_theme_color_override("font_color", COLOR_ACCENT)
	clear_button.pressed.connect(_clear_notifications)
	footer.add_child(clear_button)

func _build_quick_settings() -> void:
	qs_shade = PanelContainer.new()
	qs_shade.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var viewport_width := get_viewport_rect().size.x
	var panel_width := minf(580.0, maxf(280.0, viewport_width - 72.0))
	qs_shade.offset_left = -panel_width - 36.0
	qs_shade.offset_top = 48.0
	qs_shade.offset_right = -36.0
	qs_shade.offset_bottom = get_viewport_rect().size.y - 68.0
	qs_shade.add_theme_stylebox_override("panel", _make_squircle_style(COLOR_SURFACE_GLASS, 34))
	qs_shade.visible = false
	qs_shade.position.y = -1200
	master_container.add_child(qs_shade)

	var margin := MarginContainer.new()
	for key in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(key, 24)
	qs_shade.add_child(margin)

	var quick_scroll := ScrollContainer.new()
	qs_scroll = quick_scroll
	quick_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	quick_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(quick_scroll)
	var outer := VBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_theme_constant_override("separation", 16)
	quick_scroll.add_child(outer)

	var header := HBoxContainer.new()
	qs_header = header
	header.add_theme_constant_override("separation", 8)
	outer.add_child(header)

	var title := Label.new()
	title.text = "Quick settings"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	header.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var settings_btn := Button.new()
	settings_btn.text = "⚙"
	settings_btn.custom_minimum_size = Vector2(44, 44)
	settings_btn.add_theme_font_size_override("font_size", 20)
	settings_btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	settings_btn.add_theme_stylebox_override("normal", _make_squircle_style(COLOR_CARD_WHITE, 22))
	settings_btn.pressed.connect(func(): _launch_app("intent:#Intent;action=android.settings.SETTINGS;end"))
	header.add_child(settings_btn)

	var lock_btn := Button.new()
	lock_btn.text = "Lock"
	lock_btn.custom_minimum_size = Vector2(72, 44)
	lock_btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	lock_btn.add_theme_stylebox_override("normal", _make_squircle_style(COLOR_CARD_WHITE, 22))
	lock_btn.pressed.connect(func():
		_close_qs()
		_lock_device()
	)
	header.add_child(lock_btn)

	var device_lock_btn := Button.new()
	device_lock_btn.text = "Device lock"
	device_lock_btn.custom_minimum_size = Vector2(112, 44)
	device_lock_btn.add_theme_stylebox_override("normal", _make_squircle_style(COLOR_CARD_WHITE, 22))
	device_lock_btn.pressed.connect(_android_lock_device)
	header.add_child(device_lock_btn)

	var tile_card := PanelContainer.new()
	tile_card.add_theme_stylebox_override("panel", _make_squircle_style(COLOR_CARD_WHITE, 28))
	outer.add_child(tile_card)
	var tile_margin := MarginContainer.new()
	for key in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		tile_margin.add_theme_constant_override(key, 16)
	tile_card.add_child(tile_margin)

	var tile_grid := GridContainer.new()
	tile_grid.columns = 2
	tile_grid.add_theme_constant_override("h_separation", 12)
	tile_grid.add_theme_constant_override("v_separation", 12)
	tile_margin.add_child(tile_grid)

	for tile_name in ["Wi-Fi", "Bluetooth", "Sound & Alarms", "Do not disturb", "Auto rotate", "Airplane mode"]:
		var tile := Button.new()
		tile.text = "●   " + tile_name
		tile.toggle_mode = tile_name != "Sound & Alarms"
		tile.button_pressed = _get_native_tile_state(tile_name)
		tile.custom_minimum_size = Vector2(0, 62)
		tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tile.add_theme_font_size_override("font_size", 15)
		tile.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		tile.add_theme_color_override("font_pressed_color", Color.WHITE)
		tile.add_theme_stylebox_override("normal", _make_squircle_style(Color("#E6ECF5"), 31))
		tile.add_theme_stylebox_override("pressed", _make_squircle_style(COLOR_ACCENT, 31))
		if tile_name == "Sound & Alarms":
			tile.pressed.connect(_open_sound_settings)
		else:
			var tile_key := tile_name
			var tile_ref := tile
			tile.toggled.connect(func(enabled: bool): _handle_system_tile(tile_key, enabled, tile_ref))
		system_tile_buttons[tile_name] = tile
		tile_grid.add_child(tile)

	var brightness_card := PanelContainer.new()
	brightness_card.add_theme_stylebox_override("panel", _make_squircle_style(COLOR_CARD_WHITE, 26))
	outer.add_child(brightness_card)
	var brightness_margin := MarginContainer.new()
	for key in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		brightness_margin.add_theme_constant_override(key, 16)
	brightness_card.add_child(brightness_margin)

	var brightness_col := VBoxContainer.new()
	brightness_col.add_theme_constant_override("separation", 6)
	brightness_margin.add_child(brightness_col)
	var brightness_label := Label.new()
	brightness_label.text = "☀  Display brightness"
	brightness_label.add_theme_font_size_override("font_size", 14)
	brightness_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	brightness_col.add_child(brightness_label)

	brightness_slider = HSlider.new()
	brightness_slider.min_value = 0.15
	brightness_slider.max_value = 1.0
	brightness_slider.step = 0.01
	brightness_slider.value = 1.0
	brightness_slider.custom_minimum_size = Vector2(0, 32)
	if android_bridge != null and bool(android_bridge.canWriteSettings()):
		brightness_slider.value = clampf(float(android_bridge.getScreenBrightness()), 0.15, 1.0)
	brightness_slider.value_changed.connect(_on_brightness_changed)
	brightness_col.add_child(brightness_slider)

	var volume_label := Label.new()
	volume_label.text = "♪  Media volume"
	volume_label.add_theme_font_size_override("font_size", 14)
	volume_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	brightness_col.add_child(volume_label)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.01
	volume_slider.custom_minimum_size = Vector2(0, 30)
	if android_bridge != null:
		volume_slider.value = float(android_bridge.getMediaVolume())
	volume_slider.value_changed.connect(_on_volume_changed)
	brightness_col.add_child(volume_slider)

	var media_card := PanelContainer.new()
	media_card.add_theme_stylebox_override("panel", _make_squircle_style(COLOR_CARD_WHITE, 26))
	outer.add_child(media_card)
	var media_margin := MarginContainer.new()
	for key in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		media_margin.add_theme_constant_override(key, 18)
	media_card.add_child(media_margin)

	var media_col := VBoxContainer.new()
	media_col.add_theme_constant_override("separation", 10)
	media_margin.add_child(media_col)
	var media_title := Label.new()
	media_title.text = "Media output"
	media_title.add_theme_font_size_override("font_size", 16)
	media_title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	media_col.add_child(media_title)

	var media_sub := Label.new()
	media_sub.text = "Fire Tablet Speakers · Ready"
	media_sub.add_theme_font_size_override("font_size", 13)
	media_sub.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
	media_col.add_child(media_sub)

	var media_row := HBoxContainer.new()
	media_row.add_theme_constant_override("separation", 10)
	media_col.add_child(media_row)

	media_play_btn = Button.new()
	media_play_btn.text = "▶  Play"
	media_play_btn.custom_minimum_size = Vector2(115, 42)
	media_play_btn.add_theme_color_override("font_color", Color.WHITE)
	media_play_btn.add_theme_stylebox_override("normal", _make_squircle_style(COLOR_ACCENT, 21))
	media_play_btn.pressed.connect(func():
		is_playing_media = not is_playing_media
		media_play_btn.text = "Ⅱ  Pause" if is_playing_media else "▶  Play"
		media_sub.text = "Playing on Tablet Speakers" if is_playing_media else "Fire Tablet Speakers · Paused"
		_update_now_bar()
	)
	media_row.add_child(media_play_btn)

	var alarm_quick_btn := Button.new()
	alarm_quick_btn.text = "⏰  Alarms"
	alarm_quick_btn.custom_minimum_size = Vector2(0, 42)
	alarm_quick_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	alarm_quick_btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	alarm_quick_btn.add_theme_stylebox_override("normal", _make_squircle_style(Color("#E6ECF5"), 21))
	alarm_quick_btn.pressed.connect(_open_alarm_manager)
	media_row.add_child(alarm_quick_btn)

func _build_home_edit_menu() -> void:
	home_edit_menu = PanelContainer.new()
	home_edit_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	home_edit_menu.add_theme_stylebox_override("panel", _make_squircle_style(Color(0.04, 0.06, 0.10, 0.92), 0))
	home_edit_menu.visible = false
	master_container.add_child(home_edit_menu)

	var center := CenterContainer.new()
	home_edit_menu.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(420, 380)
	card.add_theme_stylebox_override("panel", _make_squircle_style(COLOR_CARD_WHITE, 30))
	center.add_child(card)

	var margin := MarginContainer.new()
	for key in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(key, 26)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "Home screen settings"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	vbox.add_child(title)

	for opt_text in ["Wallpaper and style", "Widgets", "Home screen grid", "Settings"]:
		var option_name := opt_text
		var btn := Button.new()
		btn.text = option_name
		btn.custom_minimum_size = Vector2(0, 48)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_font_size_override("font_size", 16)
		btn.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		btn.add_theme_stylebox_override("normal", _make_squircle_style(Color("#EAF0FA"), 22))
		btn.pressed.connect(func():
			_close_home_edit_menu()
			if option_name == "Settings":
				_open_sound_settings()
			else:
				_show_message(option_name, "Customize " + option_name.to_lower() + " in One UI settings.")
		)
		vbox.add_child(btn)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var close_btn := Button.new()
	close_btn.text = "Done"
	close_btn.custom_minimum_size = Vector2(0, 48)
	close_btn.add_theme_color_override("font_color", Color.WHITE)
	close_btn.add_theme_stylebox_override("normal", _make_squircle_style(COLOR_ACCENT, 24))
	close_btn.pressed.connect(_close_home_edit_menu)
	vbox.add_child(close_btn)

func _open_home_edit_menu() -> void:
	home_edit_menu.visible = true
	home_edit_menu.modulate.a = 0.0
	create_tween().tween_property(home_edit_menu, "modulate:a", 1.0, 0.2)
	play_ui_sound()

func _close_home_edit_menu() -> void:
	var tw := create_tween()
	tw.tween_property(home_edit_menu, "modulate:a", 0.0, 0.15)
	tw.finished.connect(func(): home_edit_menu.visible = false)

func _populate_notifications() -> void:
	for child in notif_list.get_children():
		child.queue_free()
	for item in notifications_data:
		var notification_item: Dictionary = item
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", _make_squircle_style(COLOR_CARD_WHITE, 24))
		notif_list.add_child(card)
		var margin := MarginContainer.new()
		for key in ["margin_top", "margin_bottom"]:
			margin.add_theme_constant_override(key, 12)
		for key in ["margin_left", "margin_right"]:
			margin.add_theme_constant_override(key, 16)
		card.add_child(margin)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		margin.add_child(col)
		var row := HBoxContainer.new()
		col.add_child(row)
		var app_label := Label.new()
		app_label.text = str(notification_item.get("app", "App"))
		app_label.add_theme_font_size_override("font_size", 12)
		app_label.add_theme_color_override("font_color", COLOR_ACCENT)
		row.add_child(app_label)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		var dismiss := Button.new()
		dismiss.text = "×"
		dismiss.flat = true
		dismiss.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		dismiss.pressed.connect(func():
			var idx := notifications_data.find(notification_item)
			if idx >= 0:
				notifications_data.remove_at(idx)
			card.queue_free()
		)
		row.add_child(dismiss)
		var title_label := Label.new()
		title_label.text = str(notification_item.get("title", ""))
		title_label.add_theme_font_size_override("font_size", 15)
		title_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		col.add_child(title_label)
		var body_label := Label.new()
		body_label.text = str(notification_item.get("body", ""))
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body_label.add_theme_font_size_override("font_size", 13)
		body_label.add_theme_color_override("font_color", COLOR_TEXT_SECONDARY)
		col.add_child(body_label)

func add_notification(app_name: String, title_text: String, body_text: String, play_sound: bool = true) -> void:
	notifications_data.push_front({"app": app_name, "title": title_text, "body": body_text})
	while notifications_data.size() > 50:
		notifications_data.pop_back()
	if is_instance_valid(notif_list):
		_populate_notifications()
		_wire_ui_sounds(notif_list)
	if play_sound:
		play_notification_sound()

func _clear_notifications() -> void:
	for child in notif_list.get_children():
		var notification_card := child
		var tw := create_tween()
		tw.tween_property(notification_card, "modulate:a", 0.0, 0.15)
		tw.finished.connect(func(): notification_card.queue_free())
	notifications_data.clear()

func _build_lock_screen() -> void:
	lock_screen = PanelContainer.new()
	lock_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	lock_screen.add_theme_stylebox_override("panel", _make_squircle_style(Color("#D4E2F8"), 0))
	master_container.add_child(lock_screen)

	var margin := MarginContainer.new()
	for key in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(key, 36)
	lock_screen.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var top_space := Control.new()
	top_space.custom_minimum_size = Vector2(0, 32)
	vbox.add_child(top_space)

	lock_clock_lbl = Label.new()
	lock_clock_lbl.text = "12:00"
	lock_clock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_clock_lbl.add_theme_font_size_override("font_size", 104)
	lock_clock_lbl.add_theme_color_override("font_color", Color("#162136"))
	vbox.add_child(lock_clock_lbl)

	lock_date_lbl = Label.new()
	lock_date_lbl.text = "Wednesday, November 18"
	lock_date_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lock_date_lbl.add_theme_font_size_override("font_size", 22)
	lock_date_lbl.add_theme_color_override("font_color", Color("#43526B"))
	vbox.add_child(lock_date_lbl)

	var mid_space := Control.new()
	mid_space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(mid_space)

	var bottom_row := HBoxContainer.new()
	bottom_row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(bottom_row)

	var left_shortcut := Button.new()
	left_shortcut.text = "⚙"
	left_shortcut.custom_minimum_size = Vector2(54, 54)
	left_shortcut.add_theme_font_size_override("font_size", 20)
	left_shortcut.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	left_shortcut.add_theme_stylebox_override("normal", _make_squircle_style(Color(1, 1, 1, 0.55), 27))
	left_shortcut.pressed.connect(_open_sound_settings)
	bottom_row.add_child(left_shortcut)

	var sp1 := Control.new()
	sp1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(sp1)

	var now_bar := PanelContainer.new()
	now_bar.custom_minimum_size = Vector2(340, 56)
	now_bar.add_theme_stylebox_override("panel", _make_squircle_style(Color(1.0, 1.0, 1.0, 0.85), 28))
	bottom_row.add_child(now_bar)

	now_bar_label = Label.new()
	now_bar_label.text = "Swipe up to unlock"
	now_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	now_bar_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	now_bar_label.add_theme_font_size_override("font_size", 15)
	now_bar_label.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
	now_bar.add_child(now_bar_label)

	var sp2 := Control.new()
	sp2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(sp2)

	var right_shortcut := Button.new()
	right_shortcut.text = "📷"
	right_shortcut.custom_minimum_size = Vector2(54, 54)
	right_shortcut.add_theme_font_size_override("font_size", 20)
	right_shortcut.add_theme_stylebox_override("normal", _make_squircle_style(Color(1, 1, 1, 0.55), 27))
	right_shortcut.pressed.connect(func(): _launch_app("intent:#Intent;action=android.media.action.IMAGE_CAPTURE;end"))
	bottom_row.add_child(right_shortcut)

func _update_now_bar() -> void:
	if not is_instance_valid(now_bar_label):
		return
	if not active_alarm_name.is_empty():
		now_bar_label.text = "⏰  Alarm Ringing · " + active_alarm_name
	elif is_playing_media:
		now_bar_label.text = "🎵  Playing · Fire Tablet Speakers"
	else:
		var active_alarms := 0
		for a in alarm_entries:
			if bool(a.get("enabled", true)):
				active_alarms += 1
		if active_alarms > 0:
			now_bar_label.text = "⏰  %d alarm(s) active · Swipe up" % active_alarms
		else:
			now_bar_label.text = "Swipe up to unlock"

func _build_navigation_bar() -> void:
	nav_bar = HBoxContainer.new()
	nav_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	nav_bar.custom_minimum_size = Vector2(0, 44)
	nav_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	nav_bar.add_theme_constant_override("separation", 96)
	master_container.add_child(nav_bar)

	for symbol in ["Ⅲ", "▢", "‹"]:
		var button := Button.new()
		button.text = symbol
		button.flat = true
		button.custom_minimum_size = Vector2(48, 38)
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_color_override("font_color", Color("#2B374C"))
		if symbol == "Ⅲ":
			button.pressed.connect(_toggle_qs)
		elif symbol == "▢":
			button.pressed.connect(_go_home)
		else:
			button.pressed.connect(_go_back)
		nav_bar.add_child(button)

func _make_squircle_style(bg: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.corner_radius_top_left = radius
	sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius
	sb.corner_radius_bottom_right = radius
	sb.anti_aliasing = true
	return sb

func _create_app_icon(app_data: Dictionary, show_label: bool = true) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL if show_label else Control.SIZE_SHRINK_CENTER
	container.add_theme_constant_override("separation", 7)
	container.set_meta("app_name", str(app_data["name"]).to_lower())

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(64, 64)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.text = str(app_data["name"]).left(2).to_upper()
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_stylebox_override("normal", _make_squircle_style(app_data["color"], 22))
	btn.add_theme_stylebox_override("pressed", _make_squircle_style(app_data["color"].darkened(0.25), 22))
	var icon_b64 := str(app_data.get("icon_png_b64", ""))
	if not icon_b64.is_empty():
		var icon_bytes := Marshalls.base64_to_raw(icon_b64)
		var icon_image := Image.new()
		if icon_image.load_png_from_buffer(icon_bytes) == OK:
			btn.icon = ImageTexture.create_from_image(icon_image)
			btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			btn.expand_icon = true
			btn.text = ""
	btn.button_down.connect(func(): create_tween().tween_property(btn, "scale", Vector2(0.92, 0.92), 0.08))
	btn.button_up.connect(func(): create_tween().tween_property(btn, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK))
	btn.pressed.connect(func(): _launch_app_data(app_data))
	container.add_child(btn)

	if show_label:
		var lbl := Label.new()
		lbl.text = str(app_data["name"])
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", COLOR_TEXT_PRIMARY)
		container.add_child(lbl)
	return container

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_go_back()
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pressed: bool = event.pressed
		var pos: Vector2 = event.position
		if pressed:
			drag_start_pos = pos
			if is_locked:
				drag_mode = "unlock"
			elif is_qs_open:
				var on_brightness := brightness_slider.get_global_rect().has_point(pos)
				var on_header := qs_header.get_global_rect().has_point(pos)
				var on_qs_content := qs_scroll.get_global_rect().has_point(pos)
				drag_mode = "qs_active" if on_header or not on_qs_content and not on_brightness else ""
			elif is_notif_open:
				drag_mode = "" if notif_scroll.get_global_rect().has_point(pos) else "notif_active"
			elif is_drawer_open:
				var on_search := search_input.get_global_rect().has_point(pos)
				var on_app_grid := drawer_scroll.get_global_rect().has_point(pos)
				if on_search or on_app_grid:
					drag_mode = ""
				elif pos.y < 120.0 or pos.y > size.y - 120.0:
					drag_mode = "drawer_close"
				else:
					drag_mode = ""
			elif pos.y < 80:
				drag_mode = "notif_down" if pos.x < size.x * 0.5 else "qs_down"
			elif pos.y > size.y * 0.45:
				drag_mode = "drawer_up"
			else:
				is_desktop_holding = true
				desktop_hold_timer = 0.0
				drag_mode = ""
		else:
			is_desktop_holding = false
			var delta := pos - drag_start_pos
			if drag_mode == "unlock" and delta.y < -140:
				_unlock_device()
			elif drag_mode == "unlock":
				create_tween().tween_property(lock_screen, "position:y", 0.0, 0.2)
			elif drag_mode == "notif_down" and delta.y > 110:
				_open_notif()
			elif drag_mode == "qs_down" and delta.y > 110:
				_open_qs()
			elif drag_mode == "notif_active":
				if delta.x < -120:
					_close_notif()
					_open_qs()
				elif delta.y < -110:
					_close_notif()
				else:
					create_tween().tween_property(notif_shade, "position:y", 0.0, 0.2)
			elif drag_mode == "qs_active":
				if delta.x > 120:
					_close_qs()
					_open_notif()
				elif delta.y < -110:
					_close_qs()
				else:
					create_tween().tween_property(qs_shade, "position:y", 0.0, 0.2)
			elif drag_mode == "drawer_up" and delta.y < -120:
				_open_drawer()
			elif drag_mode == "drawer_close" and delta.y > 120:
				_close_drawer()
			elif drag_mode == "drawer_close":
				create_tween().tween_property(app_drawer_panel, "position:y", 0.0, 0.2)
			drag_mode = ""

	elif event is InputEventScreenDrag or (event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)):
		var pos = event.position
		if is_desktop_holding and pos.distance_to(drag_start_pos) > 12.0:
			is_desktop_holding = false
		var delta_y: float = pos.y - drag_start_pos.y
		if drag_mode == "unlock" and delta_y < 0:
			lock_screen.position.y = delta_y
		elif drag_mode == "notif_active" and delta_y < 0:
			notif_shade.position.y = delta_y
		elif drag_mode == "qs_active" and delta_y < 0:
			qs_shade.position.y = delta_y
		elif drag_mode == "drawer_close" and delta_y > 0:
			app_drawer_panel.position.y = delta_y

func _set_blur_active(active: bool) -> void:
	if active:
		blur_backdrop.visible = true
		create_tween().tween_property(blur_backdrop, "modulate:a", 1.0, 0.22)
	elif not is_drawer_open and not is_qs_open and not is_notif_open:
		var tw := create_tween()
		tw.tween_property(blur_backdrop, "modulate:a", 0.0, 0.20)
		tw.finished.connect(func(): blur_backdrop.visible = false)

func _unlock_device() -> void:
	is_locked = false
	var tw := create_tween()
	tw.tween_property(lock_screen, "position:y", -size.y, 0.28).set_trans(Tween.TRANS_CUBIC)
	tw.finished.connect(func(): lock_screen.visible = false)

func _lock_device() -> void:
	is_locked = true
	lock_screen.visible = true
	lock_screen.position.y = -size.y
	create_tween().tween_property(lock_screen, "position:y", 0.0, 0.28).set_trans(Tween.TRANS_CUBIC)

func _open_drawer() -> void:
	if is_drawer_open: return
	is_drawer_open = true
	_set_blur_active(true)
	app_drawer_panel.visible = true
	app_drawer_panel.position.y = size.y
	create_tween().tween_property(app_drawer_panel, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_CUBIC)

func _close_drawer() -> void:
	if not is_drawer_open: return
	is_drawer_open = false
	search_input.text = ""
	_filter_apps("")
	var tw := create_tween()
	tw.tween_property(app_drawer_panel, "position:y", size.y, 0.22)
	tw.finished.connect(func():
		app_drawer_panel.visible = false
		_set_blur_active(false)
	)

func _open_notif() -> void:
	if is_notif_open: return
	if is_qs_open: _close_qs()
	is_notif_open = true
	_set_blur_active(true)
	notif_shade.visible = true
	notif_shade.position.y = -size.y
	create_tween().tween_property(notif_shade, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_CUBIC)

func _close_notif() -> void:
	if not is_notif_open: return
	is_notif_open = false
	var tw := create_tween()
	tw.tween_property(notif_shade, "position:y", -size.y, 0.22)
	tw.finished.connect(func():
		notif_shade.visible = false
		_set_blur_active(false)
	)

func _open_qs() -> void:
	if is_qs_open: return
	if is_notif_open: _close_notif()
	is_qs_open = true
	_set_blur_active(true)
	qs_shade.visible = true
	qs_shade.position.y = -size.y
	create_tween().tween_property(qs_shade, "position:y", 0.0, 0.25).set_trans(Tween.TRANS_CUBIC)

func _close_qs() -> void:
	if not is_qs_open: return
	is_qs_open = false
	var tw := create_tween()
	tw.tween_property(qs_shade, "position:y", -size.y, 0.22)
	tw.finished.connect(func():
		qs_shade.visible = false
		_set_blur_active(false)
	)

func _toggle_qs() -> void:
	if is_qs_open: _close_qs()
	else: _open_qs()

func _go_home() -> void:
	if is_qs_open: _close_qs()
	if is_notif_open: _close_notif()
	if is_drawer_open: _close_drawer()

func _go_back() -> void:
	if is_instance_valid(alarm_manager_panel):
		alarm_manager_panel.queue_free()
	elif is_instance_valid(sound_settings_panel):
		sound_settings_panel.queue_free()
	elif is_qs_open:
		_close_qs()
	elif is_notif_open:
		_close_notif()
	elif is_drawer_open:
		_close_drawer()

func _filter_apps(query: String) -> void:
	var q := query.strip_edges().to_lower()
	for child in drawer_grid.get_children():
		var app_name: String = child.get_meta("app_name", "")
		child.visible = q.is_empty() or app_name.contains(q)

func _launch_app_data(app_data: Dictionary) -> void:
	var package_name := str(app_data.get("package", ""))
	if android_bridge != null and not package_name.is_empty():
		if bool(android_bridge.launchApp(package_name)):
			return
	_launch_app(str(app_data.get("uri", "")))

func _launch_app(uri: String) -> void:
	if OS.get_name() == "Android":
		if android_bridge != null and android_bridge.has_method("launchIntent"):
			if bool(android_bridge.launchIntent(uri)):
				return
		OS.shell_open(uri)
	else:
		print("Fire OS Intent Triggered: ", uri)

# ==============================================================================
# RESPONSIVE LAYOUT + ANDROID BRIDGE
# ==============================================================================
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_inside_tree() and not _is_resizing:
		_is_resizing = true
		call_deferred("_layout_responsive")

func _layout_responsive() -> void:
	_is_resizing = false
	var viewport := get_viewport_rect().size
	if is_instance_valid(qs_shade):
		var panel_width := minf(580.0, maxf(280.0, viewport.x - 72.0))
		qs_shade.offset_left = -panel_width - 36.0
		qs_shade.offset_right = -36.0
		qs_shade.offset_bottom = viewport.y - 68.0
	if is_instance_valid(notif_shade):
		notif_shade.offset_right = minf(560.0, viewport.x - 36.0)
		notif_shade.offset_bottom = viewport.y - 68.0
	if is_instance_valid(home_grid_reference):
		home_grid_reference.columns = 5 if viewport.x >= 900.0 else 4
	if is_instance_valid(drawer_grid_reference):
		drawer_grid_reference.columns = 7 if viewport.x >= 1100.0 else (5 if viewport.x >= 700.0 else 4)
	if is_instance_valid(app_drawer_panel) and is_drawer_open:
		app_drawer_panel.position.y = 0.0
	if is_instance_valid(notif_shade) and is_notif_open:
		notif_shade.position.y = 0.0
	if is_instance_valid(qs_shade) and is_qs_open:
		qs_shade.position.y = 0.0

func _connect_android_bridge() -> void:
	if OS.get_name() != "Android":
		return
	if Engine.has_singleton("FireOSTabletBridge"):
		android_bridge = Engine.get_singleton("FireOSTabletBridge")
	else:
		push_warning("FireOSTabletBridge is not installed in this Android export. Native controls will be unavailable.")

func _refresh_installed_apps_from_android() -> void:
	if android_bridge == null or not android_bridge.has_method("getInstalledAppsJson"):
		return
	var raw := str(android_bridge.getInstalledAppsJson())
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Array) or parsed.is_empty():
		return
	var discovered: Array[Dictionary] = []
	var palette: Array[Color] = [Color("#3478F6"), Color("#20A66A"), Color("#F28C28"), Color("#8C62D9"), Color("#E45D75"), Color("#1D9BBF")]
	for i in range(parsed.size()):
		var item: Variant = parsed[i]
		if not (item is Dictionary):
			continue
		var package_name := str(item.get("package", ""))
		if package_name.is_empty():
			continue
		discovered.append({
			"name": str(item.get("label", package_name)),
			"package": package_name,
			"color": palette[i % palette.size()],
			"uri": "",
			"dock": discovered.size() < 5,
			"home": discovered.size() >= 5 and discovered.size() < 20,
			"icon_png_b64": str(item.get("icon", ""))
		})
	if not discovered.is_empty():
		installed_apps = discovered

func _get_native_tile_state(tile_name: String) -> bool:
	if android_bridge == null:
		return tile_name == "Wi-Fi"
	match tile_name:
		"Wi-Fi": return bool(android_bridge.getWifiEnabled())
		"Bluetooth": return bool(android_bridge.getBluetoothEnabled())
		"Do not disturb": return bool(android_bridge.getDndEnabled())
		"Auto rotate": return bool(android_bridge.getAutoRotateEnabled())
		"Airplane mode": return bool(android_bridge.getAirplaneModeEnabled())
	return false

func _handle_system_tile(tile_name: String, enabled: bool, tile_button: Button = null) -> void:
	if android_bridge == null:
		_show_message("Android integration unavailable", "Build and install the Fire OS Android bridge plugin to control system settings.")
		return
	var success := false
	match tile_name:
		"Wi-Fi": success = bool(android_bridge.setWifiEnabled(enabled))
		"Bluetooth": success = bool(android_bridge.setBluetoothEnabled(enabled))
		"Do not disturb":
			if not bool(android_bridge.hasDndAccess()):
				android_bridge.openDndAccessSettings()
			else:
				success = bool(android_bridge.setDndEnabled(enabled))
		"Auto rotate":
			if not bool(android_bridge.canWriteSettings()):
				android_bridge.requestWriteSettingsPermission()
			else:
				success = bool(android_bridge.setAutoRotateEnabled(enabled))
		"Airplane mode":
			android_bridge.openSettings("android.settings.AIRPLANE_MODE_SETTINGS")
			_show_message("Airplane mode", "Fire OS does not allow ordinary apps to switch airplane mode directly. Use the system settings page.")
	if not success and tile_name not in ["Airplane mode", "Do not disturb", "Auto rotate"]:
		_show_message(tile_name, "Fire OS rejected the direct toggle. The system settings page will open instead.")
		if tile_name == "Wi-Fi":
			android_bridge.openSettings("android.settings.WIFI_SETTINGS")
		elif tile_name == "Bluetooth":
			android_bridge.openSettings("android.settings.BLUETOOTH_SETTINGS")
	if not success and is_instance_valid(tile_button):
		tile_button.set_pressed_no_signal(_get_native_tile_state(tile_name))
	_update_android_status()

func _on_brightness_changed(value: float) -> void:
	if android_bridge != null:
		if bool(android_bridge.canWriteSettings()):
			if bool(android_bridge.setScreenBrightness(value)):
				dim_overlay.color.a = 0.0
				return
		else:
			android_bridge.requestWriteSettingsPermission()
	dim_overlay.color.a = 1.0 - value

func _on_volume_changed(value: float) -> void:
	if android_bridge != null:
		android_bridge.setMediaVolume(value)

func _android_lock_device() -> void:
	if android_bridge == null:
		_show_message("Device lock unavailable", "The Android bridge plugin is not installed.")
		return
	if bool(android_bridge.lockDevice()):
		return
	android_bridge.requestDeviceAdmin()
	_show_message("Device administrator required", "Enable the launcher as a device administrator, then tap Device lock again. You can revoke this permission in Android Settings.")

func _sync_native_alarms() -> void:
	if android_bridge == null:
		return
	for alarm in alarm_entries:
		if bool(alarm.get("enabled", true)):
			_schedule_native_alarm(alarm)
		else:
			_cancel_native_alarm(alarm)
	_save_alarms()

func _schedule_native_alarm(alarm: Dictionary) -> void:
	if android_bridge == null or not android_bridge.has_method("scheduleDailyAlarm"):
		return
	var alarm_id := int(alarm.get("id", 0))
	if alarm_id == 0:
		alarm_id = int(Time.get_ticks_msec())
		alarm["id"] = alarm_id
	if bool(alarm.get("enabled", true)):
		android_bridge.scheduleDailyAlarm(int(alarm.get("hour", 7)), int(alarm.get("minute", 0)), alarm_id)

func _cancel_native_alarm(alarm: Dictionary) -> void:
	if android_bridge != null and android_bridge.has_method("cancelDailyAlarm"):
		android_bridge.cancelDailyAlarm(int(alarm.get("id", 0)))

func _poll_android_notifications() -> void:
	if android_bridge == null or not android_bridge.has_method("getRecentNotificationsJson"):
		return
	var raw := str(android_bridge.getRecentNotificationsJson())
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Array):
		return
	if not android_notifications_initialized:
		for old_item in parsed:
			if old_item is Dictionary:
				var old_id := str(old_item.get("id", ""))
				var posted_at := int(old_item.get("time", 0))
				if not old_id.is_empty():
					seen_android_notification_ids[old_id] = true
				if posted_at >= android_notifications_start_time_ms and not old_id.is_empty():
					add_notification(str(old_item.get("app", "Android")), str(old_item.get("title", "Notification")), str(old_item.get("text", "")), true)
		android_notifications_initialized = true
		return
	for item in parsed:
		if not (item is Dictionary):
			continue
		var event_id := str(item.get("id", ""))
		if event_id.is_empty() or seen_android_notification_ids.has(event_id):
			continue
		seen_android_notification_ids[event_id] = true
		add_notification(str(item.get("app", "Android")), str(item.get("title", "Notification")), str(item.get("text", "")), true)
	while seen_android_notification_ids.size() > 150:
		seen_android_notification_ids.erase(seen_android_notification_ids.keys()[0])

func _update_android_status() -> void:
	if not is_instance_valid(android_status_label):
		return
	if android_bridge == null:
		android_status_label.text = "Android bridge not installed"
		return
	android_bridge.setSystemBarsHidden(true)
	var battery := int(android_bridge.getBatteryPercent())
	var battery_text := "%d%%" % battery if battery >= 0 else "--%"
	var wifi := "Wi-Fi" if bool(android_bridge.getWifiEnabled()) else "No Wi-Fi"
	android_status_label.text = "%s   %s" % [wifi, battery_text]
	for tile_name in ["Wi-Fi", "Bluetooth", "Do not disturb", "Auto rotate", "Airplane mode"]:
		if system_tile_buttons.has(tile_name):
			var tile: Button = system_tile_buttons[tile_name]
			if is_instance_valid(tile):
				tile.set_pressed_no_signal(_get_native_tile_state(tile_name))

func _update_clock() -> void:
	if not is_instance_valid(status_time_lbl):
		return
	var date_dict := Time.get_datetime_dict_from_system()
	var hour: int = int(date_dict["hour"])
	var minute: int = int(date_dict["minute"])
	var ampm := "AM" if hour < 12 else "PM"
	var display_hour := hour % 12
	if display_hour == 0:
		display_hour = 12
	status_time_lbl.text = "%d:%02d %s" % [display_hour, minute, ampm]
	if is_instance_valid(home_clock_lbl):
		home_clock_lbl.text = "%d:%02d" % [display_hour, minute]
	if is_instance_valid(lock_clock_lbl):
		lock_clock_lbl.text = "%d:%02d" % [display_hour, minute]
	var weekday_names := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
	var month_names := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
	var weekday: String = weekday_names[clampi(int(date_dict.get("weekday", 0)), 0, 6)]
	var month: String = month_names[clampi(int(date_dict.get("month", 1)) - 1, 0, 11)]
	var day: int = int(date_dict.get("day", 1))
	if is_instance_valid(home_date_lbl):
		home_date_lbl.text = "%s, %s %d" % [weekday.left(3), month.left(3), day]
	if is_instance_valid(lock_date_lbl):
		lock_date_lbl.text = "%s, %s %d" % [weekday, month, day]
	_update_android_status()
