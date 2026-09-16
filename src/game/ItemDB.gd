extends Node

# ── 装备数据库 ──
# 每个装备用 int ID 标识，分员工/Boss 两套

enum Tier { BASIC, ADVANCED, LEGENDARY }
enum Side { EMPLOYEE, BOSS }

const MAX_SLOTS := 3
const SELL_RATIO := 0.5

# 货币常量
const COIN_START := 30
const COIN_TASK_DONE := 20
const COIN_FIX_BUG := 10
const COIN_RESCUE := 8
const COIN_DELIVERY := 5
const COIN_SLACK_INTERVAL := 15.0
const COIN_SLACK_REWARD := 3
const COIN_CATCH := 15
const COIN_MEETING := 10
const COIN_KPI := 8
const COIN_INCIDENT_FAIL := 12
const COIN_SUPERVISE_SLACK := 5

# 贩卖机激活延迟
const SHOP_UNLOCK_TIME := 30.0

# ── 装备 ID ──
# 员工基础件 100-199
const E_POWERBANK := 100
const E_SNEAKERS := 101
const E_EARPHONE := 102
const E_STICKYNOTE := 103
const E_COFFEE_COUPON := 104
const E_BADGE_CASE := 105
const E_DAYOFF := 106
const E_TOMATO := 107
const E_LABOR_LAW := 108
# 员工进阶件 200-299
const E_NOISE_CANCEL := 200
const E_FLIPFLOP := 201
const E_FISH_PHONE := 202
const E_FLEX_HOURS := 203
const E_ARBITRATION := 204
# 员工神装 300-399
const E_WFH := 300
const E_GRIND_BADGE := 301
const E_FISH_KING := 302
const E_SPRINT_KIT := 303
const E_35H := 304

# Boss 基础件 500-599
const B_CAMERA := 500
const B_SCANNER := 501
const B_DINGTALK := 502
const B_DOORPASS := 503
const B_BRIEFCASE := 504
const B_WEEKLY := 505
const B_OVERTIME := 506
const B_OKR := 507
const B_ATTENDANCE := 508
# Boss 进阶件 600-699
const B_HD_CAM := 600
const B_EAGLE := 601
const B_SUIT := 602
const B_996 := 603
const B_HOURS_SCREEN := 604
# Boss 神装 700-799
const B_PANOPTICON := 700
const B_CLIENT := 701
const B_SPEED_MGR := 702
const B_PUA := 703

# ── 装备定义 ──
class ItemDef:
	var id: int
	var name: String
	var icon: String
	var tier: int
	var side: int
	var cost: int
	var recipe: Array[int]  # 合成所需子件 ID
	var combine_cost: int   # 合成差价
	var desc: String
	# buff keys
	var buffs: Dictionary = {}
	# 主动技能 CD（0 = 无主动）
	var active_cd: float = 0.0

var items: Dictionary = {}  # id -> ItemDef

func _ready() -> void:
	_register_all()


func _def(id: int, nm: String, icon: String, tier: int, side: int, cost: int, recipe: Array[int], combine_cost: int, desc: String, buffs: Dictionary, active_cd := 0.0) -> void:
	var d := ItemDef.new()
	d.id = id; d.name = nm; d.icon = icon; d.tier = tier; d.side = side
	d.cost = cost; d.recipe = recipe; d.combine_cost = combine_cost
	d.desc = desc; d.buffs = buffs; d.active_cd = active_cd
	items[id] = d


func _register_all() -> void:
	# ════════ 员工基础件 ════════
	_def(E_POWERBANK, "充电宝", "🔋", Tier.BASIC, Side.EMPLOYEE, 25, [], 0,
		"精力恢复速度 +20%", {"energy_regen": 0.20})
	_def(E_SNEAKERS, "运动鞋", "👟", Tier.BASIC, Side.EMPLOYEE, 25, [], 0,
		"移速 +12%", {"speed": 0.12})
	_def(E_EARPHONE, "耳机", "🎧", Tier.BASIC, Side.EMPLOYEE, 25, [], 0,
		"被抓站立惩罚 -30%", {"stand_lock_reduce": 0.30})
	_def(E_STICKYNOTE, "便利贴", "📝", Tier.BASIC, Side.EMPLOYEE, 25, [], 0,
		"工作速度 +15%", {"work_speed": 0.15})
	_def(E_COFFEE_COUPON, "咖啡券", "☕", Tier.BASIC, Side.EMPLOYEE, 25, [], 0,
		"咖啡 Buff 持续 +50%", {"coffee_buff_dur": 0.50})
	_def(E_BADGE_CASE, "工卡套", "🔑", Tier.BASIC, Side.EMPLOYEE, 25, [], 0,
		"打卡速度 +40%", {"clock_speed": 0.40})
	_def(E_DAYOFF, "调休单", "📅", Tier.BASIC, Side.EMPLOYEE, 25, [], 0,
		"初始工时 -5", {"hours_reduce": 5.0})
	_def(E_TOMATO, "番茄钟", "⏱️", Tier.BASIC, Side.EMPLOYEE, 25, [], 0,
		"连续工作 8s 后速度 +25%", {"tomato_bonus": 0.25})
	_def(E_LABOR_LAW, "劳动法手册", "🛡️", Tier.BASIC, Side.EMPLOYEE, 25, [], 0,
		"被抓加时惩罚 -20%", {"catch_hours_reduce": 0.20})

	# ════════ 员工进阶件 ════════
	_def(E_NOISE_CANCEL, "降噪耳机", "🎧", Tier.ADVANCED, Side.EMPLOYEE, 60,
		[E_EARPHONE, E_STICKYNOTE], 10,
		"Boss 监督范围对你 -25%，工速 +10%", {"supervise_shrink": 0.25, "work_speed": 0.10})
	_def(E_FLIPFLOP, "人字拖", "🩴", Tier.ADVANCED, Side.EMPLOYEE, 60,
		[E_SNEAKERS, E_POWERBANK], 10,
		"移速 +18%，精力恢复 +15%", {"speed": 0.18, "energy_regen": 0.15})
	_def(E_FISH_PHONE, "摸鱼手机", "📱", Tier.ADVANCED, Side.EMPLOYEE, 60,
		[E_EARPHONE, E_COFFEE_COUPON], 10,
		"摸鱼被发现延迟 +1.5s，咖啡 +30%", {"slack_delay": 1.5, "coffee_buff_dur": 0.30})
	_def(E_FLEX_HOURS, "弹性工时协议", "📑", Tier.ADVANCED, Side.EMPLOYEE, 60,
		[E_DAYOFF, E_TOMATO], 10,
		"工时 -5，被抓后工速叠加 +10%（最多 3 层）", {"hours_reduce": 5.0, "catch_stack_work": 0.10})
	_def(E_ARBITRATION, "劳动仲裁书", "⚖️", Tier.ADVANCED, Side.EMPLOYEE, 60,
		[E_LABOR_LAW, E_DAYOFF], 10,
		"被抓惩罚 -35%，工时 -3", {"catch_hours_reduce": 0.35, "hours_reduce": 3.0})

	# ════════ 员工神装 ════════
	_def(E_WFH, "居家办公证", "🏠", Tier.LEGENDARY, Side.EMPLOYEE, 120,
		[E_NOISE_CANCEL, E_FLIPFLOP], 0,
		"监督 -40%，移速 +22%，精力 +20%，每 60s 自动完成 5% 任务",
		{"supervise_shrink": 0.40, "speed": 0.22, "energy_regen": 0.20, "auto_task_pct": 0.05, "auto_task_interval": 60.0})
	_def(E_GRIND_BADGE, "卷王工牌", "👑", Tier.LEGENDARY, Side.EMPLOYEE, 120,
		[E_FLEX_HOURS, E_NOISE_CANCEL], 0,
		"工速 +35%，惩罚 -50%，任务 >80% 免疫一次抓捕",
		{"work_speed": 0.35, "stand_lock_reduce": 0.50, "catch_immune_threshold": 0.80})
	_def(E_FISH_KING, "摸鱼之王", "🥷", Tier.LEGENDARY, Side.EMPLOYEE, 120,
		[E_FISH_PHONE, E_FLIPFLOP], 0,
		"摸鱼延迟 +2.5s，移速 +20%，主动：8s 隐身（CD 90s）",
		{"slack_delay": 2.5, "speed": 0.20}, 90.0)
	_def(E_SPRINT_KIT, "冲刺套装", "🚀", Tier.LEGENDARY, Side.EMPLOYEE, 120,
		[E_FLIPFLOP, E_BADGE_CASE], 0,
		"移速 +15%，打卡 +60%，≤1 任务时移速额外 +25%",
		{"speed": 0.15, "clock_speed": 0.60, "sprint_threshold": 1})
	_def(E_35H, "35 小时工作制", "🏆", Tier.LEGENDARY, Side.EMPLOYEE, 120,
		[E_FLEX_HOURS, E_ARBITRATION], 0,
		"工时 -8，惩罚 -40%，<15h 时加速 +30% 且免疫 KPI",
		{"hours_reduce": 8.0, "catch_hours_reduce": 0.40, "low_hours_boost": 0.30, "low_hours_threshold": 15.0, "kpi_immune_threshold": 15.0})

	# ════════ Boss 基础件 ════════
	_def(B_CAMERA, "监控探头", "📷", Tier.BASIC, Side.BOSS, 25, [], 0,
		"监督范围 +15%", {"supervise_range": 0.15})
	_def(B_SCANNER, "工牌扫描器", "🏷️", Tier.BASIC, Side.BOSS, 25, [], 0,
		"抓捕范围 +12%", {"catch_range": 0.12})
	_def(B_DINGTALK, "钉钉通知", "📊", Tier.BASIC, Side.BOSS, 25, [], 0,
		"KPI 扣时效果 +20%", {"kpi_power": 0.20})
	_def(B_DOORPASS, "门禁卡", "🚪", Tier.BASIC, Side.BOSS, 25, [], 0,
		"门自动为你打开", {"auto_door": true})
	_def(B_BRIEFCASE, "公文包", "💼", Tier.BASIC, Side.BOSS, 25, [], 0,
		"移速 +10%", {"speed": 0.10})
	_def(B_WEEKLY, "周报模板", "📋", Tier.BASIC, Side.BOSS, 25, [], 0,
		"周报/扇形 CD -20%", {"report_cd_reduce": 0.20})
	_def(B_OVERTIME, "加班铃", "🔔", Tier.BASIC, Side.BOSS, 25, [], 0,
		"全员每 30s +0.5 工时", {"overtime_interval": 30.0, "overtime_hours": 0.5})
	_def(B_OKR, "OKR 看板", "📊", Tier.BASIC, Side.BOSS, 25, [], 0,
		"HUD 显示全员剩余工时", {"show_hours": true})
	_def(B_ATTENDANCE, "考勤系统", "📊", Tier.BASIC, Side.BOSS, 25, [], 0,
		"抓捕加时 +15%", {"catch_hours_boost": 0.15})

	# ════════ Boss 进阶件 ════════
	_def(B_HD_CAM, "高清监控", "📹", Tier.ADVANCED, Side.BOSS, 60,
		[B_CAMERA, B_DINGTALK], 10,
		"监督 +25%，KPI +15%", {"supervise_range": 0.25, "kpi_power": 0.15})
	_def(B_EAGLE, "鹰眼系统", "🦅", Tier.ADVANCED, Side.BOSS, 60,
		[B_SCANNER, B_CAMERA], 10,
		"抓捕 +20%，看到摸鱼标记", {"catch_range": 0.20, "see_slack": true})
	_def(B_SUIT, "管理套装", "👔", Tier.ADVANCED, Side.BOSS, 60,
		[B_BRIEFCASE, B_DOORPASS], 10,
		"移速 +15%，穿门不减速", {"speed": 0.15, "auto_door": true, "door_nospeed": true})
	_def(B_996, "996 通知书", "📈", Tier.ADVANCED, Side.BOSS, 60,
		[B_ATTENDANCE, B_OVERTIME], 10,
		"抓捕加时 +20%，全员 25s +0.8h，最少工时标记",
		{"catch_hours_boost": 0.20, "overtime_interval": 25.0, "overtime_hours": 0.8, "mark_lowest": true})
	_def(B_HOURS_SCREEN, "工时大屏", "🖥️", Tier.ADVANCED, Side.BOSS, 60,
		[B_OKR, B_ATTENDANCE], 10,
		"全员工时可见，监督区工速 -15%",
		{"show_hours": true, "show_state": true, "supervise_slow": 0.15})

	# ════════ Boss 神装 ════════
	_def(B_PANOPTICON, "全域监控", "👁️", Tier.LEGENDARY, Side.BOSS, 120,
		[B_HD_CAM, B_EAGLE], 0,
		"监督 +40%，抓捕 +25%，每 45s 闪现全员位置 2s",
		{"supervise_range": 0.40, "catch_range": 0.25, "flash_interval": 45.0, "flash_duration": 2.0})
	_def(B_CLIENT, "永远的甲方", "🏢", Tier.LEGENDARY, Side.BOSS, 120,
		[B_996, B_HOURS_SCREEN], 0,
		"20s +1h，全员可见，主动：需求变更（CD 75s）",
		{"overtime_interval": 20.0, "overtime_hours": 1.0, "show_hours": true, "show_state": true}, 75.0)
	_def(B_SPEED_MGR, "极速管理", "⚡", Tier.LEGENDARY, Side.BOSS, 120,
		[B_SUIT, B_EAGLE], 0,
		"移速 +22%，冲刺 CD -30%，主动：瞬移到随机员工（CD 60s）",
		{"speed": 0.22, "dash_cd_reduce": 0.30}, 60.0)
	_def(B_PUA, "PUA 圣经", "🗡️", Tier.LEGENDARY, Side.BOSS, 120,
		[B_996, B_HD_CAM], 0,
		"KPI +30%，抓捕加时 +25%，被抓额外扣 1 格精力",
		{"kpi_power": 0.30, "catch_hours_boost": 0.25, "catch_drain_energy": 1})


# ── 查询接口 ──

func get_item(id: int) -> ItemDef:
	return items.get(id)


func items_for_side(side: int) -> Array:
	var result := []
	for d in items.values():
		if d.side == side:
			result.append(d)
	result.sort_custom(func(a, b): return a.cost < b.cost or (a.cost == b.cost and a.id < b.id))
	return result


func sell_price(id: int) -> int:
	var d := get_item(id)
	if d == null:
		return 0
	return int(d.cost * SELL_RATIO)


func can_combine(owned: Array[int], target_id: int) -> bool:
	var d := get_item(target_id)
	if d == null or d.recipe.is_empty():
		return false
	var temp := owned.duplicate()
	for need_id in d.recipe:
		var idx := temp.find(need_id)
		if idx < 0:
			return false
		temp.remove_at(idx)
	return true


func combine_result(owned: Array[int]) -> int:
	for d in items.values():
		if d.recipe.is_empty():
			continue
		if can_combine(owned, d.id):
			return d.id
	return -1


func find_combinable(owned: Array[int], side: int) -> Array:
	var result := []
	for d in items.values():
		if d.side != side or d.recipe.is_empty():
			continue
		if can_combine(owned, d.id):
			result.append(d.id)
	return result


func total_buff(owned_ids: Array[int], key: String) -> float:
	var total := 0.0
	for id in owned_ids:
		var d := get_item(id)
		if d != null and d.buffs.has(key):
			var v = d.buffs[key]
			if v is float or v is int:
				total += float(v)
	return total


func has_buff(owned_ids: Array[int], key: String) -> bool:
	for id in owned_ids:
		var d := get_item(id)
		if d != null and d.buffs.has(key):
			if d.buffs[key]:
				return true
	return false
