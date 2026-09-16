extends Node

const PORT := 19107
const MAX_PLAYERS := 5
const MAP_SIZE := Vector2(4096, 2816)
const CORRIDOR_Y := 1008.0

const MATCH_SECONDS := 600.0
const SHORT_MATCH_SECONDS := 180.0
const COUNTDOWN := 3.0

const HOURS_START := 100.0
const ENERGY_START := 0.0
const ENERGY_MAX := 100.0
const ENERGY_CELLS := 6
const ENERGY_START_CELLS := 3
const ENERGY_CHARGE_SEC := 24.0
const ENERGY_SLACK_SEC := 9.0
const TASK_COUNT := 5
const TASK_TIME := 10.0
const TASK_ENERGY_COST := 3.0
const TASK_NAMES := ["日报", "周报", "对齐", "复盘", "纪要"]
const TASK_DOCS := [
	{
		"title": "Q4 项目数据整理",
		"lead": "请根据各部门提交的数据，完成汇总表并核对关键指标。",
		"side": ["数据整理", "报告填写", "会议材料", "邮件回复", "其他任务"],
		"cols": ["部门", "本月完成", "目标值", "完成率", "备注"],
		"rows": [
			["产品部", "320", "400", "80%", "—"],
			["技术部", "560", "600", "93%", "—"],
			["市场部", "280", "500", "56%", "需跟进"],
			["运营部", "410", "450", "91%", "—"],
			["人力资源部", "95", "120", "79%", "—"],
			["财务部", "230", "260", "88%", "—"],
		],
		"checks": ["整理各部门上报数据", "核对异常并确认", "完成汇总表（初版）", "补充市场部数据", "生成图表与分析结论", "提交最终版"],
		"note": "市场部的数据仍有缺口，已发邮件催促。先完成其他部分，不要拖延。",
		"warn": "截止时间：今天 18:00",
	},
	{
		"title": "本周交付周报",
		"lead": "把本周颗粒度对齐进一页纸，别写成长篇小说。",
		"side": ["进度汇总", "风险清单", "资源申请", "下周计划", "其他任务"],
		"cols": ["事项", "负责人", "状态", "完成度", "卡点"],
		"rows": [
			["登录重构", "小马", "进行中", "70%", "联调"],
			["素材替换", "袋鼠", "进行中", "55%", "审核"],
			["结算页", "鹈鹕", "待开始", "10%", "接口"],
			["压测", "小狗", "延期", "40%", "环境"],
			["周会纪要", "小马", "已完成", "100%", "—"],
			["老板评审", "全员", "未开始", "0%", "会议室"],
		],
		"checks": ["收集各组进度", "标红延期项", "写风险与对策", "对齐下周目标", "压缩成一页", "提交周报"],
		"note": "延期项请用红字，不要藏。老板只看红色。",
		"warn": "周五 17:30 前提交",
	},
	{
		"title": "跨组口径对齐",
		"lead": "把三组说法收成一个版本，避免会上互撕。",
		"side": ["口径表", "异议记录", "决策稿", "会后待办", "其他任务"],
		"cols": ["议题", "产品", "技术", "运营", "结论"],
		"rows": [
			["指标口径", "GMV", "订单数", "GMV", "待定"],
			["截止日期", "18:00", "19:00", "18:00", "18:00"],
			["责任人", "产品", "研发", "运营", "产品"],
			["是否公示", "要", "不要", "要", "要"],
			["复盘模板", "V2", "V1", "V2", "V2"],
			["升级路径", "主管", "主管", "老板", "主管"],
		],
		"checks": ["收集三组说法", "标出冲突项", "给出建议结论", "会前预对齐", "写成决策稿", "同步全员"],
		"note": "冲突项先私下对齐，别带到大会上现问。",
		"warn": "对齐会 16:00 开始",
	},
	{
		"title": "事故复盘草稿",
		"lead": "先把时间线写清楚，再谈责任和动作。",
		"side": ["时间线", "影响面", "根因", "动作项", "其他任务"],
		"cols": ["时间", "现象", "动作", "结果", "备注"],
		"rows": [
			["10:12", "接口超时", "重启", "未恢复", "—"],
			["10:21", "报警升级", "回滚", "部分恢复", "—"],
			["10:40", "老板进群", "写说明", "群炸了", "—"],
			["11:05", "全量恢复", "复盘会", "进行中", "—"],
			["11:30", "客户投诉", "客服顶", "仍在跟", "严重"],
			["12:00", "午餐取消", "继续写", "—", "—"],
		],
		"checks": ["拉完整时间线", "统计影响面", "写直接原因", "写根因", "列出动作项", "提交草稿"],
		"note": "不要先写「人的问题」。先写系统和流程。",
		"warn": "复盘会后 1 小时内交稿",
	},
	{
		"title": "会议纪要整理",
		"lead": "把会上的空话滤掉，只留结论和谁来做。",
		"side": ["结论", "待办", "风险", "下次会议", "其他任务"],
		"cols": ["决议", "负责人", "截止", "状态", "备注"],
		"rows": [
			["补市场数据", "市场", "今日", "催中", "缺口"],
			["改口径表", "产品", "明日", "未开始", "—"],
			["修导出", "技术", "明日", "进行中", "—"],
			["约老板", "助理", "本周", "待定", "会议室"],
			["发纪要", "你", "今天", "编写中", "—"],
			["归档录音", "你", "今天", "未开始", "—"],
		],
		"checks": ["整理结论清单", "写清负责人", "标截止日期", "标未决议项", "发给相关人", "归档"],
		"note": "没人认领的待办不要写进纪要，会变成空气。",
		"warn": "散会后 30 分钟内发出",
	},
]

const WORK_HOURS_PER_SEC := 1.15
const EMPTY_HOURS_PER_SEC := 0.0
const WORK_ENERGY_PER_SEC := 0.0
const SLACK_ENERGY_PER_SEC := 2.0
const COFFEE_ENERGY_PER_SEC := 6.0
const TOILET_ENERGY_PER_SEC := 7.0
const MEETING_ENERGY_PER_SEC := 0.15
const DIZZY_SPEED_MUL := 0.72
const DIZZY_TIME_MIN := 1.0
const DIZZY_TIME_MAX := 2.0
const DIZZY_PLAY_GAIN := 2
const DIZZY_PLAY_GOOD := 3

const COFFEE_BUFF_TIME := 20.0
const COFFEE_BUFF_MUL := 1.2

const SUPERVISE_DIST := 78.0
const SUPERVISE_WORK_MUL := 0.4
const TIGER_SUPERVISE_MUL := 0.3
const SLACK_CATCH_DELAY := 1.2

const CATCH_HOURS_FIRST := 12.0
const CATCH_HOURS_REPEAT := 18.0
const CATCH_STAND_LOCK := 0.0
const CATCH_CHAIN_WINDOW := 12.0
const CATCH_RANGE := 70.0
const CATCH_GRACE := 8.0
const TIGER_CATCH_RANGE := 70.0

const PERF_MAX := 100.0
const PERF_CELLS := 4
const PERF_FIRE := 25.0
const PERF_TALK_DPS := 4.0
const PERF_DRAG_DPS := 3.0
const PERF_MEET_DPS := 3.0
const PERF_MEET_QTE_MUL := 0.5

const TALK_TIME := 10.0
const TALK_WATCH_TIME := 10.0
const TALK_ALONE_TIME := 10.0
const REVIEW_TIME := 10.0
const REVIEW_QTE_BOOST := 0.25
const REVIEW_HELP_MUL := 0.85
const REVIEW_STEPS := 3
const REVIEW_MASH := 4
const REVIEW_SEQ_LEN := 3
const REVIEW_STAMP_HIT := 0.12
const REVIEW_HELP_HIT := 0.40
const REVIEW_KEY_NAME := ["A", "D", "E"]
const REVIEW_FIRST_DELAY := 0.0
const REVIEW_STEP_DELAY := 0.0
const REVIEW_WINDOW := 0.0
const REVIEW_MISS_PENALTY := 0.0
const REVIEW_EARLY_PENALTY := 0.0
const REVIEW_HELP_STEP := 0.40
const RESCUE_TIME := 2.5
const RESCUE_RANGE := 72.0
const RESCUE_BOOST_TIME := 0.0
const RESCUE_BOOST_MUL := 1.0
const RESCUE_SLOW_TIME := 2.0

const TALK_QUIPS := ["来，对对齐颗粒度", "这个产出我们展开讲讲", "你这周的交付呢", "先写个复盘吧"]

const MEETING_TIME := 14.0
const MEETING_CD := 18.0
const TIGER_MEETING_TIME := 14.0
const TIGER_MEETING_CD := 0.0
const TIGER_MEETING_RANGE := 180.0
const TIGER_POWER_MAX := 3
const TIGER_DRAG_WINDUP := 0.80
const TIGER_DRAG_SPEED_MUL := 0.82
const TIGER_DRAG_OFFSET := 34.0
const TIGER_BIND_RANGE := 58.0

const TIGER_LUNGE_TIME := 0.32
const TIGER_LUNGE_SPEED := 320.0
const TIGER_LUNGE_RADIUS := 46.0
const TIGER_LUNGE_MISS_STUN := 1.5
const TIGER_LUNGE_HIT_STUN := 0.4
const AUDIT_HIT_TIME := 0.62
const AUDIT_HIT_RECOIL := 16.0
const TIGER_THROW_POSE := 0.32
const TIGER_ULT_POSE := 0.48

const KPI_HOURS := 10.0
const KPI_CD := 75.0
const KPI_UNLOCK := 40.0

const TIGER_SPEED_MUL := 1.15
const EMPLOYEE_SPEED := 168.0
const BOSS_BASE_SPEED := 182.0
const TIGER_DASH_CD := 12.0
const TIGER_DASH_TIME := 0.28
const TIGER_DASH_SPEED := 420.0
const FX_CLAW := "res://assets/game/fx/tiger_claw.png"
const FX_LUNGE := "res://assets/game/fx/tiger_lunge_arc.png"
const FX_STAMP := "res://assets/game/fx/talk_stamp.png"
const FX_MEETING := "res://assets/game/fx/meeting_ult.png"
const FX_LOCK_RING := "res://assets/game/fx/meeting_lock_ring.png"
const UI_POWER_ON := "res://assets/game/ui/power_pip_on.png"
const UI_POWER_OFF := "res://assets/game/ui/power_pip_off.png"
const UI_TASK_ON := "res://assets/game/ui/cell_task_on.png"
const UI_TASK_OFF := "res://assets/game/ui/cell_task_off.png"
const UI_ENERGY_ON := "res://assets/game/ui/cell_energy_on.png"
const UI_ENERGY_OFF := "res://assets/game/ui/cell_energy_off.png"
const UI_PERF_ON := "res://assets/game/ui/cell_perf_on.png"
const UI_PERF_OFF := "res://assets/game/ui/cell_perf_off.png"
const UI_ICON_TASK := "res://assets/game/ui/icon_task.png"
const UI_ICON_ENERGY := "res://assets/game/ui/icon_energy.png"
const UI_ICON_PERF := "res://assets/game/ui/icon_perf.png"
const UI_MARK_DIZZY := "res://assets/game/ui/mark_dizzy.png"
const UI_OVERLAY_REVIEW := "res://assets/game/ui/overlay_review.png"
const UI_OVERLAY_DRAG := "res://assets/game/ui/overlay_drag.png"
const UI_OVERLAY_MEETING := "res://assets/game/ui/overlay_meeting.png"
const UI_KICKOFF_CLOCK := "res://assets/game/ui/kickoff/clock.png"
const UI_KICKOFF_TITLE_10 := "res://assets/game/ui/kickoff/title_10.png"
const UI_KICKOFF_TITLE_3 := "res://assets/game/ui/kickoff/title_3.png"
const UI_FIRED_STAMP := "res://assets/game/ui/fired/stamp.png"
const UI_FIRED_IMPRINT := "res://assets/game/ui/fired/imprint.png"
const UI_FIRED_NOTICE := "res://assets/game/ui/fired/notice.png"
const UI_FIRED_SHARD := "res://assets/game/ui/fired/shard.png"
const UI_FIRED_BANG := "res://assets/game/ui/fired/bang.png"
const UI_FIRED_DEBRIS := "res://assets/game/ui/fired/debris.png"
const UI_FIRED_SHADOW := "res://assets/game/ui/fired/shadow.png"
const UI_FIRED_NEXT := "res://assets/game/ui/fired/next.png"
const UI_FIRED_REACT := "res://assets/game/ui/fired/react.png"
const EMP_DASH_CD := 8.0
const EMP_DASH_TIME := 0.28
const EMP_DASH_SPEED := 360.0
const PELICAN_FLY_CD := 10.0
const PELICAN_FLY_TIME := 0.45
const PELICAN_FLY_SPEED := 480.0
const PELICAN_FLY_LIFT := 92.0

const REPORT_SPEED := 310.0
const REPORT_LIFE := 1.35
const REPORT_HIT_RADIUS := 34.0
const REPORT_SLOW_TIME := 3.0
const REPORT_SLOW_MUL := 0.5
const REPORT_CD := 0.8
const REPORT_FAN_CD := 2.2
const REPORT_FAN_COUNT := 7
const REPORT_FAN_SPREAD := 90.0

# 线上事故
const INCIDENT_CD := 90.0
const INCIDENT_UNLOCK := 90.0
const INCIDENT_DURATION := 30.0
const INCIDENT_FIX_TIME := 8.0
const INCIDENT_ASSIST_REDUCE := 5.0
const INCIDENT_BLAME_TIME := 1.5
const INCIDENT_FAIL_HOURS := 20.0
const INCIDENT_BOSS_SPEED_MUL := 1.25
const INCIDENT_BOSS_RANGE_MUL := 1.4
const INCIDENT_CATCH_DELAY_MUL := 0.5
const INCIDENT_FIX_ENERGY := 1

const INCIDENT_BOSS_QUIPS := ["谁上线的？查！", "这谁写的代码？", "你们组谁负责这块？", "马上查，别下班了"]
const INCIDENT_BLAME_QUIPS := ["不是我提交的啊", "我看看 git blame", "这块不归我管吧", "？？？"]
const INCIDENT_FIX_QUIPS := ["hotfix 上了", "先回滚再说", "日志看完了，修了", "CI 过了，合"]
const INCIDENT_ASSIST_QUIPS := ["我来 review", "我帮你看看日志", "一起 debug", "我查监控"]
const INCIDENT_FAIL_QUIPS := ["写复盘吧", "明天早会讲", "这个锅背定了"]
const INCIDENT_PASS_QUIPS := ["这块不归我管", "找原 owner 吧", "我这边没问题啊", "你看看你那边"]

# 随机事件系统
const EVENT_FIRST_DELAY := 60.0
const EVENT_MIN_INTERVAL := 45.0
const EVENT_MAX_INTERVAL := 65.0
const EVENT_MAX_PER_MATCH := 4
const EVENT_MAX_PER_SHORT := 2

# 匿名举报
const ANON_REPORT_REVEAL := 8.0
const ANON_REPORT_QUIPS := ["收到匿名反馈，已转交管理层", "有人不在工位，已上报", "内部信箱收到举报信"]

# 停电
const BLACKOUT_DURATION := 25.0
const BLACKOUT_VISION := 120.0
const BLACKOUT_QUIPS := ["B 座配电房故障", "应急电源启动中", "请勿惊慌，保持原位"]

# 外卖到了
const DELIVERY_DURATION := 15.0
const DELIVERY_COUNT := 2
const DELIVERY_BOOST_TIME := 5.0
const DELIVERY_BOOST_MUL := 1.3
const DELIVERY_QUIPS := ["您的外卖已送达前台", "谁点的瑞幸？快来取", "隔壁组已经在拆了"]

# 内网崩了
const INTRANET_DURATION := 20.0
const INTRANET_BOOST_TIME := 5.0
const INTRANET_BOOST_MUL := 1.5
const INTRANET_QUIPS := ["内网维护中，请勿刷新", "VPN 又断了", "IT 说重启一下试试"]

const INTERACT_RANGE := 64.0
const DOOR_RANGE := 62.0
const DOOR_OPEN_TIME := 1.65
const CLOCK_RANGE := 48.0
const SPRITE_SCALE := 0.088
const CARRY_RANGE := 76.0
const CARRY_WINDUP := 0.32
const CARRY_DURATION := 8.0
const CARRY_RECOVERY := 0.65
const BIKE_DURATION := 10.0
const BIKE_SPEED_MUL := 1.45
const BIKE_CD := 3.0
const DOG_PACK_COUNT := 3
const DOG_PACK_TIME := 8.0
const DOG_PACK_CD := 12.0
const DOG_PACK_SPEED_MUL := 1.12
const DOG_PACK_HIT := 36.0
const DOG_PACK_STUN := 0.55

const STOCK_TIME := 10.0
const STOCK_START := 100.0
const STOCK_TICK := 0.12
const STOCK_BOOST_TIME := 5.0
const STOCK_CD := 40.0
const STOCK_NEAR := 280.0
const STOCK_WIN := 0.5
const STOCK_ENERGY_GAIN := 1

const BOSS_SPRITE := 0.11

enum Slot { BOSS, EMP_A, EMP_B, EMP_C, EMP_D }
enum Kind { BOSS, EMPLOYEE }
enum EmpState { WALK, WORK, SLACK, COFFEE, TOILET, MEETING, CLOCKING, LEFT, TALK, CARRIED, TRADE, DRAGGED, FIRED }
enum CharSkin { HORSE, PELICAN, KANGAROO, TIGER, DOG }

const EMPLOYEE_SLOTS := [Slot.EMP_A, Slot.EMP_B, Slot.EMP_C, Slot.EMP_D]

const SLOT_NAMES := {
	Slot.BOSS: "老板",
	Slot.EMP_A: "员工·小马",
	Slot.EMP_B: "员工·鹈鹕",
	Slot.EMP_C: "员工·袋鼠",
	Slot.EMP_D: "员工·小狗",
}

const SKIN_FOR_SLOT := {
	Slot.BOSS: CharSkin.TIGER,
	Slot.EMP_A: CharSkin.HORSE,
	Slot.EMP_B: CharSkin.PELICAN,
	Slot.EMP_C: CharSkin.KANGAROO,
	Slot.EMP_D: CharSkin.DOG,
}

const BODY_FOR_SKIN := {
	CharSkin.HORSE: Color("25262C"),
}

const SCARF_FOR_SKIN := {
	CharSkin.HORSE: Color("3EE0F2"),
	CharSkin.PELICAN: Color("7B5CFF"),
	CharSkin.KANGAROO: Color("FF9A1A"),
	CharSkin.DOG: Color("E1251B"),
	CharSkin.TIGER: Color("E02020"),
}

const BIKE_COLOR_FOR_SKIN := {
	CharSkin.KANGAROO: Color("FF9A1A"),
}

const STATE_NAMES := {
	EmpState.WALK: "划水",
	EmpState.WORK: "在卷",
	EmpState.SLACK: "摸鱼",
	EmpState.COFFEE: "续命",
	EmpState.TOILET: "暂时离线",
	EmpState.MEETING: "开会中",
	EmpState.CLOCKING: "润了",
	EmpState.LEFT: "已下班",
	EmpState.TALK: "复盘中",
	EmpState.CARRIED: "顺风嘴 · 搭乘中",
	EmpState.TRADE: "盘中",
	EmpState.DRAGGED: "被拖去开会",
	EmpState.FIRED: "已开除",
}

func body_color(skin: int) -> Color:
	return BODY_FOR_SKIN.get(skin, Color("25262C"))


func scarf_color(skin: int) -> Color:
	return SCARF_FOR_SKIN.get(skin, Color("3EE0F2"))


func bike_color(skin: int) -> Color:
	return BIKE_COLOR_FOR_SKIN.get(skin, Color("F5C116"))


func slot_is_employee(slot: int) -> bool:
	return slot >= Slot.EMP_A and slot <= Slot.EMP_D


func employee_index(slot: int) -> int:
	return slot - Slot.EMP_A


func talk_quip(slot: int) -> String:
	return TALK_QUIPS[slot % TALK_QUIPS.size()]


func task_name(done: int) -> String:
	if TASK_NAMES.is_empty():
		return "工作"
	return str(TASK_NAMES[clampi(done, 0, TASK_NAMES.size() - 1)])


func task_doc(done: int) -> Dictionary:
	if TASK_DOCS.is_empty():
		return {}
	return TASK_DOCS[clampi(done, 0, TASK_DOCS.size() - 1)]


func task_saves_for(slot: int, done: int) -> PackedFloat32Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(hash("%d:%d:saves" % [slot, done]) & 0x7fffffff)
	var n := 1 + rng.randi() % 2
	var out := PackedFloat32Array()
	if n == 1:
		out.append(snappedf(rng.randf_range(0.36, 0.64), 0.01))
	else:
		out.append(snappedf(rng.randf_range(0.26, 0.42), 0.01))
		out.append(snappedf(rng.randf_range(0.58, 0.76), 0.01))
	return out


func task_checkpoint_of(progress: float, saves: PackedFloat32Array) -> float:
	var best := 0.0
	for s in saves:
		if progress + 0.0001 >= s:
			best = maxf(best, s)
	return best


func review_fill_rate(helpers: int) -> float:
	return (1.0 / maxf(REVIEW_TIME, 0.1)) * (1.0 + float(maxi(helpers, 0)) * REVIEW_HELP_MUL)


func office_clock_text(progress: float) -> String:
	var t := 17 * 60 + 50 + int(round(clampf(progress, 0.0, 1.0) * 10.0))
	return "%d:%02d" % [t / 60, t % 60]


static var _tex_cache: Dictionary = {}


static func tex(path: String) -> Texture2D:
	if path == "":
		return null
	if _tex_cache.has(path):
		return _tex_cache[path] as Texture2D
	var result: Texture2D = null
	var abs_path := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path) or FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img != null and not img.is_empty():
			result = ImageTexture.create_from_image(img)
	if result == null and ResourceLoader.exists(path):
		var loaded: Resource = ResourceLoader.load(path)
		if loaded is Texture2D:
			result = loaded
	_tex_cache[path] = result
	return result
