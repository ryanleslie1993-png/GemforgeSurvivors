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


func set_run_exp_bar(level: int, xp: int, xp_need: int) -> void:
	var need: int = maxi(1, xp_need)
	$BottomExpBar/ExpVBox/ExpLabel.text = "Lv %d — Run EXP: %d / %d" % [level, xp, need]
	$BottomExpBar/ExpVBox/ExpProgress.max_value = float(need)
	$BottomExpBar/ExpVBox/ExpProgress.value = float(clampi(xp, 0, need))
