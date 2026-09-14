extends Node

const PORT := 19107
const MAX_PLAYERS := 8
const MAP_SIZE := Vector2(1680, 980)
const CORRIDOR_Y := 330.0

const MATCH_SECONDS := 600.0
const SHORT_MATCH_SECONDS := 180.0
const COUNTDOWN := 3.0

const HOURS_START := 100.0
const ENERGY_START := 100.0
const ENERGY_MAX := 100.0

const WORK_HOURS_PER_SEC := 1.15
const EMPTY_HOURS_PER_SEC := 0.05
const WORK_ENERGY_PER_SEC := 2.0
const SLACK_ENERGY_PER_SEC := 2.0
const COFFEE_ENERGY_PER_SEC := 6.0
const TOILET_ENERGY_PER_SEC := 7.0
const MEETING_ENERGY_PER_SEC := 0.4

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

const MEETING_TIME := 9.0
const MEETING_CD := 18.0
const TIGER_MEETING_TIME := 9.0
const TIGER_MEETING_CD := 22.0

const KPI_HOURS := 10.0
const KPI_CD := 75.0
const KPI_UNLOCK := 40.0

const TIGER_SPEED_MUL := 1.15
const EMPLOYEE_SPEED := 320.0
const BOSS_BASE_SPEED := 340.0
const TIGER_DASH_CD := 12.0
const TIGER_DASH_TIME := 0.28
const TIGER_DASH_SPEED := 720.0

const INTERACT_RANGE := 78.0
const CLOCK_RANGE := 56.0
const CHAR_SCALE := 3.05
const BOSS_SCALE := 3.45

enum Slot { BOSS, EMP_A, EMP_B, EMP_C, EMP_D }
enum Kind { BOSS, EMPLOYEE }
enum EmpState { WALK, WORK, SLACK, COFFEE, TOILET, MEETING, CLOCKING, LEFT }
enum CharSkin { CAT, RABBIT, PENGUIN, PANDA, TIGER }

const SLOT_NAMES := {
	Slot.BOSS: "老板",
	Slot.EMP_A: "员工·黑猫",
	Slot.EMP_B: "员工·兔子",
	Slot.EMP_C: "员工·企鹅",
	Slot.EMP_D: "员工·熊猫",
}

const SKIN_FOR_SLOT := {
	Slot.BOSS: CharSkin.TIGER,
	Slot.EMP_A: CharSkin.CAT,
	Slot.EMP_B: CharSkin.RABBIT,
	Slot.EMP_C: CharSkin.PENGUIN,
	Slot.EMP_D: CharSkin.PANDA,
}

const STATE_NAMES := {
	EmpState.WALK: "走路",
	EmpState.WORK: "上班",
	EmpState.SLACK: "摸鱼",
	EmpState.COFFEE: "喝咖啡",
	EmpState.TOILET: "上厕所",
	EmpState.MEETING: "开会",
	EmpState.CLOCKING: "去打卡",
	EmpState.LEFT: "已下班",
}

func slot_is_employee(slot: int) -> bool:
	return slot >= Slot.EMP_A and slot <= Slot.EMP_D


func employee_index(slot: int) -> int:
	return slot - Slot.EMP_A
