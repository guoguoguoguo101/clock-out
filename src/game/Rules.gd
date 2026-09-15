extends Node

const PORT := 19107
const MAX_PLAYERS := 8
const MAP_SIZE := Vector2(2560, 1520)
const CORRIDOR_Y := 670.0

const MATCH_SECONDS := 600.0
const SHORT_MATCH_SECONDS := 180.0
const COUNTDOWN := 3.0

const HOURS_START := 100.0
const ENERGY_START := 0.0
const ENERGY_MAX := 100.0
const ENERGY_CELLS := 4
const ENERGY_CHARGE_SEC := 24.0
const ENERGY_SLACK_SEC := 9.0
const TASK_COUNT := 5
const TASK_TIME := 10.0
const TASK_NAMES := ["日报", "周报", "对齐", "复盘", "纪要"]

const WORK_HOURS_PER_SEC := 1.15
const EMPTY_HOURS_PER_SEC := 0.0
const WORK_ENERGY_PER_SEC := 0.0
const SLACK_ENERGY_PER_SEC := 2.0
const COFFEE_ENERGY_PER_SEC := 6.0
const TOILET_ENERGY_PER_SEC := 7.0
const MEETING_ENERGY_PER_SEC := 0.0

const COFFEE_BUFF_TIME := 20.0
const COFFEE_BUFF_MUL := 1.2

const SUPERVISE_DIST := 78.0
const SUPERVISE_WORK_MUL := 0.4
const TIGER_SUPERVISE_MUL := 0.3
const SLACK_CATCH_DELAY := 1.2

const CATCH_HOURS_FIRST := 12.0
const CATCH_HOURS_REPEAT := 18.0
const CATCH_STAND_LOCK := 3.0
const CATCH_CHAIN_WINDOW := 12.0
const CATCH_RANGE := 70.0
const TIGER_CATCH_RANGE := 70.0

const TALK_WATCH_TIME := 5.0
const TALK_ALONE_TIME := 10.0
const RESCUE_TIME := 1.2
const RESCUE_RANGE := 72.0
const RESCUE_BOOST_TIME := 1.6
const RESCUE_BOOST_MUL := 1.28

const TALK_QUIPS := ["来，对对齐颗粒度", "这个产出我们展开讲讲", "你这周的交付呢", "先写个复盘吧"]

const MEETING_TIME := 9.0
const MEETING_CD := 18.0
const TIGER_MEETING_TIME := 9.0
const TIGER_MEETING_CD := 22.0

const KPI_HOURS := 10.0
const KPI_CD := 75.0
const KPI_UNLOCK := 40.0

const TIGER_SPEED_MUL := 1.15
const EMPLOYEE_SPEED := 168.0
const BOSS_BASE_SPEED := 182.0
const TIGER_DASH_CD := 12.0
const TIGER_DASH_TIME := 0.28
const TIGER_DASH_SPEED := 420.0
const EMP_DASH_CD := 8.0
const EMP_DASH_TIME := 0.28
const EMP_DASH_SPEED := 360.0

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

const STOCK_TIME := 10.0
const STOCK_START := 100.0
const STOCK_TICK := 0.12
const STOCK_BOOST_TIME := 5.0
const STOCK_CD := 40.0
const STOCK_NEAR := 280.0
const STOCK_WIN := 0.5
const STOCK_ENERGY_GAIN := 1

const BOSS_SPRITE := 0.11

enum Slot { BOSS, EMP_A, EMP_B, EMP_C, EMP_D, EMP_E, EMP_F }
enum Kind { BOSS, EMPLOYEE }
enum EmpState { WALK, WORK, SLACK, COFFEE, TOILET, MEETING, CLOCKING, LEFT, TALK, CARRIED, TRADE }
enum CharSkin { HORSE, RABBIT, COW, PELICAN, KANGAROO, TIGER, DOG }

const EMPLOYEE_SLOTS := [Slot.EMP_A, Slot.EMP_B, Slot.EMP_C, Slot.EMP_D, Slot.EMP_E, Slot.EMP_F]

const SLOT_NAMES := {
	Slot.BOSS: "老板",
	Slot.EMP_A: "员工·小马",
	Slot.EMP_B: "员工·兔子",
	Slot.EMP_C: "员工·牛",
	Slot.EMP_D: "员工·鹈鹕",
	Slot.EMP_E: "员工·袋鼠",
	Slot.EMP_F: "员工·小狗",
}

const SKIN_FOR_SLOT := {
	Slot.BOSS: CharSkin.TIGER,
	Slot.EMP_A: CharSkin.HORSE,
	Slot.EMP_B: CharSkin.RABBIT,
	Slot.EMP_C: CharSkin.COW,
	Slot.EMP_D: CharSkin.PELICAN,
	Slot.EMP_E: CharSkin.KANGAROO,
	Slot.EMP_F: CharSkin.DOG,
}

const BODY_FOR_SKIN := {
	CharSkin.HORSE: Color("25262C"),
}

const SCARF_FOR_SKIN := {
	CharSkin.HORSE: Color("3EE0F2"),
	CharSkin.RABBIT: Color("F4C14A"),
	CharSkin.COW: Color("E23B3B"),
	CharSkin.PELICAN: Color("7B5CFF"),
	CharSkin.KANGAROO: Color("FF9A1A"),
	CharSkin.DOG: Color("E1251B"),
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
	EmpState.MEETING: "被拉去开会",
	EmpState.CLOCKING: "润了",
	EmpState.LEFT: "已下班",
	EmpState.TALK: "约谈中",
	EmpState.CARRIED: "顺风嘴 · 搭乘中",
	EmpState.TRADE: "盘中",
}

func body_color(skin: int) -> Color:
	return BODY_FOR_SKIN.get(skin, Color("25262C"))


func scarf_color(skin: int) -> Color:
	return SCARF_FOR_SKIN.get(skin, Color("3EE0F2"))


func bike_color(skin: int) -> Color:
	return BIKE_COLOR_FOR_SKIN.get(skin, Color("F5C116"))


func slot_is_employee(slot: int) -> bool:
	return slot >= Slot.EMP_A and slot <= Slot.EMP_F


func employee_index(slot: int) -> int:
	return slot - Slot.EMP_A


func talk_quip(slot: int) -> String:
	return TALK_QUIPS[slot % TALK_QUIPS.size()]


func task_name(done: int) -> String:
	if TASK_NAMES.is_empty():
		return "工作"
	return str(TASK_NAMES[clampi(done, 0, TASK_NAMES.size() - 1)])


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
