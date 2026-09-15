package sim

// Keep in sync with src/game/Rules.gd

const (
	MapW = 2560.0
	MapH = 1520.0

	CorridorY = 670.0
	TopY      = 560.0
	BotY      = 780.0
	XToilet   = 500.0
	XNorth    = 980.0
	XTea      = 1700.0
	XDesk     = 1340.0

	MatchSeconds      = 600.0
	ShortMatchSeconds = 180.0
	Countdown         = 3.0

	HoursStart  = 100.0
	EnergyStart = 100.0
	EnergyMax   = 100.0

	WorkHoursPerSec    = 1.15
	EmptyHoursPerSec   = 0.05
	WorkEnergyPerSec   = 2.0
	SlackEnergyPerSec  = 2.0
	CoffeeEnergyPerSec = 6.0
	ToiletEnergyPerSec = 7.0
	MeetingEnergyPerSec = 0.4

	CoffeeBuffTime = 20.0
	CoffeeBuffMul  = 1.2

	SuperviseDist     = 78.0
	TigerSuperviseMul = 0.3
	SlackCatchDelay   = 1.2

	CatchHoursFirst  = 12.0
	CatchHoursRepeat = 18.0
	CatchStandLock   = 3.0
	CatchChainWindow = 12.0
	CatchRange       = 70.0

	TalkWatchTime  = 10.0
	TalkAloneTime  = 10.0
	TalkTime       = 10.0
	RescueTime     = 2.5
	RescueRange    = 72.0
	RescueBoostTime = 0.0
	RescueBoostMul  = 1.0
	RescueSlowTime  = 2.0

	MeetingTime    = 30.0
	TigerMeetingCD = 0.0
	MeetingRange   = 180.0
	TigerPowerMax  = 3
	TigerLungeTime   = 0.32
	TigerLungeSpeed  = 320.0
	TigerLungeRadius = 46.0
	TigerLungeMiss   = 1.5
	TigerLungeHit    = 0.4

	KPIHours  = 10.0
	KPICD     = 75.0
	KPIUnlock = 40.0

	// 线上事故
	IncidentCD       = 90.0
	IncidentUnlock   = 90.0
	IncidentDuration = 30.0
	IncidentFixTime  = 8.0
	IncidentFailHours = 20.0
	IncidentBossSpeedMul = 1.25
	IncidentBossRangeMul = 1.4

	// 随机事件
	EventFirstDelay  = 60.0
	EventMinInterval = 45.0
	EventMaxInterval = 65.0

	// 匿名举报
	AnonReportReveal = 8.0

	// 停电
	BlackoutDuration = 25.0

	// 外卖
	DeliveryDuration = 15.0
	DeliveryCount    = 2

	// 内网崩了
	IntranetDuration   = 20.0
	IntranetBoostTime  = 5.0
	IntranetBoostMul   = 1.5

	TigerSpeedMul  = 1.15
	EmployeeSpeed  = 168.0
	BossBaseSpeed  = 182.0
	TigerDashCD    = 12.0
	TigerDashTime  = 0.28
	TigerDashSpeed = 420.0
	PelicanFlyCD    = 10.0
	PelicanFlyTime  = 0.45
	PelicanFlySpeed = 480.0

	InteractRange = 64.0
	DoorRange     = 62.0
	DoorOpenTime  = 1.65
	ClockRange    = 48.0
	CarryRange    = 76.0
	CarryWindup   = 0.32
	CarryDuration = 8.0
	CarryRecovery = 0.65
	BikeDuration  = 10.0
	BikeSpeedMul  = 1.45

	ActorRadius = 11.0
)

const (
	SlotBoss = 0
	SlotEmpA = 1
	SlotEmpB = 2
	SlotEmpC = 3
	SlotEmpD = 4
	SlotEmpE = 5
)

const (
	KindBoss     = 0
	KindEmployee = 1
)

const (
	StateWalk     = 0
	StateWork     = 1
	StateSlack    = 2
	StateCoffee   = 3
	StateToilet   = 4
	StateMeeting  = 5
	StateClocking = 6
	StateLeft     = 7
	StateTalk     = 8
	StateCarried  = 9
)

const (
	SkinHorse    = 0
	SkinRabbit   = 1
	SkinCow      = 2
	SkinPelican  = 3
	SkinKangaroo = 4
	SkinTiger    = 5
)

var EmployeeSlots = []int{SlotEmpA, SlotEmpB, SlotEmpC, SlotEmpD, SlotEmpE}

var SlotNames = map[int]string{
	SlotBoss: "老板",
	SlotEmpA: "员工·小马",
	SlotEmpB: "员工·兔子",
	SlotEmpC: "员工·牛",
	SlotEmpD: "员工·鹈鹕",
	SlotEmpE: "员工·袋鼠",
}

var SkinForSlot = map[int]int{
	SlotBoss: SkinTiger,
	SlotEmpA: SkinHorse,
	SlotEmpB: SkinRabbit,
	SlotEmpC: SkinCow,
	SlotEmpD: SkinPelican,
	SlotEmpE: SkinKangaroo,
}

func SlotIsEmployee(slot int) bool {
	return slot >= SlotEmpA && slot <= SlotEmpE
}

func EmployeeIndex(slot int) int {
	return slot - SlotEmpA
}
