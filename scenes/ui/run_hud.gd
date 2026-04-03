extends CanvasLayer


func set_timer_text(t: String) -> void:
	$TopCenter/TimerLabel.text = t


func set_kills_line(total_kills: int, active_enemies: int, cap: int) -> void:
	$TopCenter/KillsLabel.text = "Kills: %d  |  Active enemies: %d / %d" % [total_kills, active_enemies, cap]


func set_boss_bar(boss_title: String, hp: int, hp_max: int, visible_bar: bool) -> void:
	$TopCenter/BossName.visible = visible_bar
	$TopCenter/BossBar.visible = visible_bar
	if not visible_bar:
		return
	$TopCenter/BossName.text = boss_title
	$TopCenter/BossBar.max_value = float(maxi(1, hp_max))
	$TopCenter/BossBar.value = float(maxi(0, hp))


func set_meta_exp_bar(level: int, xp: int, xp_need: int) -> void:
	var need: int = maxi(1, xp_need)
	$BottomExpBar/ExpProgress.max_value = float(need)
	$BottomExpBar/ExpProgress.value = float(clampi(xp, 0, need))
	$BottomExpBar/ExpProgress/ExpText.text = "Level %d  |  EXP: %d / %d" % [level, xp, need]


func set_run_exp_bar(level: int, xp: int, xp_need: int) -> void:
	# Backward-compatible alias for older callers.
	set_meta_exp_bar(level, xp, xp_need)


func show_skill_popup(skill_name: String) -> void:
	if skill_name == "":
		return
	var label := Label.new()
	label.text = skill_name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.modulate = Color(0.92, 0.96, 1.0, 0.88)
	label.add_theme_font_size_override("font_size", 20)
	$SkillPopupAnchor/SkillPopupVBox.add_child(label)
	$SkillPopupAnchor/SkillPopupVBox.move_child(label, 0)
	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 0.0, 1.8)
	tween.finished.connect(label.queue_free)


func set_skill_cast_state(skill_name: String, auto_cast: bool) -> void:
	var mode := "Auto" if auto_cast else "Manual"
	$CastStateLabel.text = "Skill: %s [%s]" % [skill_name, mode]
