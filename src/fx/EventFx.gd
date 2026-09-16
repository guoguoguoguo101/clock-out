extends RefCounted
class_name EventFx

## 过场片单。游戏 F8 台和 preview/fx.html 共用这份清单。
## 新动画：这里加一条，Game._play_event_fx 接播放，HTML 补一段舞台。


static func clips() -> Array:
	return [
		{
			"id": "fired_victim",
			"title": "开除 · 本人",
			"group": "终局",
			"ready": true,
			"hint": "大红章砸下 · 震屏 · 印泥",
		},
		{
			"id": "fired_boss",
			"title": "开除 · 老板视角",
			"group": "终局",
			"ready": true,
			"hint": "缩小版印泥，不锁操作",
		},
		{
			"id": "kickoff_10",
			"title": "开局 · 10 分钟",
			"group": "开局",
			"ready": true,
			"hint": "时钟弹出，标准局",
		},
		{
			"id": "kickoff_3",
			"title": "开局 · 短局",
			"group": "开局",
			"ready": true,
			"hint": "3 分钟标题",
		},
		{
			"id": "blackout",
			"title": "停电了",
			"group": "事件",
			"ready": false,
			"hint": "未接入 · 灯灭是世界效果",
		},
		{
			"id": "tea",
			"title": "下午茶",
			"group": "事件",
			"ready": false,
			"hint": "未接入 · 轻提示，不要全屏砸",
		},
		{
			"id": "win",
			"title": "打卡下班",
			"group": "终局",
			"ready": false,
			"hint": "未接入 · 绿灯工卡，不是红章",
		},
		{
			"id": "escape",
			"title": "逃跑成功",
			"group": "终局",
			"ready": false,
			"hint": "未接入",
		},
	]
