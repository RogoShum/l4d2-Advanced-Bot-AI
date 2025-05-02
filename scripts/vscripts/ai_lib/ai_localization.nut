/**
	This file is used to store a K-V tables about localized languages.
*/
::BotAI.I18n <- {};

::I18n <- BotAI.I18n.weakref();

function I18n::addTranslationTable(language, table) {
	if(!(language in ::I18n))
		::I18n[language] <- table;
	else
		printl("[Bot AI] try add a exist translation table.");
}

function I18n::addTranslationKey(language, transKey, translation) {
	if(!containLanguage(language))
		::I18n[language] <- {};
	if(!(transKey in ::I18n[language]))
		::I18n[language][transKey] <- translation;
	else
		printl("[Bot AI] try add a exist translation key.");
}

function I18n::setTranslationKey(language, transKey, translation) {
	if(!containLanguage(language))
		::I18n[language] <- {};

	::I18n[language][transKey] <- translation;
}

function I18n::containLanguage(language) {
	return language in ::I18n;
}

function I18n::getTranslationKeyByLang(language, transKey) {
	if(containLanguage(language) && transKey in getLanguage(language))
		return getLanguage(language)[transKey];
	if(existTranslationKey(transKey))
		return ::I18n["english"][transKey];
	return transKey;
}

function I18n::getTranslationKey(transKey) {
	local language = BotAI.getSeverLanguage();
	if(containLanguage(language) && transKey in getLanguage(language))
		return getLanguage(language)[transKey];
	if(existTranslationKey(transKey))
		return ::I18n["english"][transKey];
	return transKey;
}

function I18n::existTranslationKey(transKey) {
	return transKey in ::I18n["english"];
}

function I18n::getLanguage(language) {
	return I18n[language];
}

function I18n::init() {
	local english =  {
		botai_gascan_finding_off = "Bot Find Gascan off.",
		botai_gascan_finding_on = "Bot Find Gascan on.",
		botai_throw_grenade_off = "Bot Throw Grenade off.",
		botai_throw_grenade_on = "Bot Throw Grenade on.",
		botai_immunity_off = "Bot Immunity to player damage off.",
		botai_immunity_on = "Bot Immunity to player damage on.",
		botai_bot_alive_on = "Bots will keep going even when all players are dead.",
		botai_bot_alive_off = "Bots will not keep going when all players are dead.",
		botai_defibrillator_off = "Bots will not use defibrillator.",
		botai_defibrillator_on = "Bots will use defibrillator.",
		botai_bot_carry_on = "Bots will now carry supplies on their backs.",
		botai_bot_carry_off = "Bots will no longer carry supplies on their backs.",
		botai_path_finding_off = "Bot Path Finding off.",
		botai_path_finding_on = "Bot Path Finding on.",
		botai_unstick_off = "Disabled Bot unstick function.",
		botai_unstick_on = "Enabled Bot unstick function.",
		botai_unstick_pathfinding = "Enabling unstick when pathfinding is enabled may cause bots to teleport to strange places.",
		botai_melee_off = "Bots not allowed to take melee weapons.",
		botai_melee_on = "Bots allowed to take melee weapons.",
		botai_use_upgrades_on = "Bots will now carry ammo upgrade packs.",
		botai_use_upgrades_off = "Bots will no longer carry ammo upgrade packs.",
		botai_fall_protect_on = "Bot lethal damage protection enabled (teleport when receiving fatal damage)",
		botai_fall_protect_off = "Bot lethal damage protection disabled (teleport when receiving fatal damage)",
		botai_throw_check = "Bot Task caught an exception at check task updating process: ",
		botai_throw_update = "Bot Task caught an exception at try update task process: ",
		botai_throw_task = "Which task caused this problem: ",
		botai_report = "Bot Task encountered an error, the task has been reset. Please copy the red text in the console to report.",
		botai_hook_exception = "An error occurred when hooking event. Some functions may not work. Please try disabling some script addons or copy the red text in the console to report.",
		botai_hook_error = "Event hook is suspected to be overwritten by other script addon. Some functions may not work properly.",
		botai_exception_here = "If there's red text below this line, please copy it:",
		botai_no_more_bot = "Additional bot function has been removed. Please subscribe to Admin System if you want this feature.",
		botai_no_hud = "Menu requires Admin System addon for support.",
		botai_no_holomenu = "Holo Menu is only available to host.",
		botai_admin_only = "This command is for admin only.",
		botai_bot_combat_skill = "Bot Combat Skill set to: ",
		botai_witch_damage = "Bot's damage multiplier to Witch set to: ",
		botai_special_damage = "Bot's damage multiplier to Special Infected set to: ",
		botai_common_damage = "Bot's damage multiplier to Common Infected set to: ",
		botai_tank_damage = "Bot's damage multiplier to Tank set to: ",
		botai_bot_follow_distance = "Bot max follow/teleport distance set to: ",
		botai_use_command_notice = "Use command !botnotice to disable config notifications.",
		botai_current_settings = "Current Settings:",
		botai_notice_on = "Configuration notifications enabled.",
    	botai_notice_off = "Configuration notifications disabled.",

		menu_title = "Advanced Bot Settings",
		menu_add_bot = "Add a bot",
		menu_bot_skill = "Combat Skill",
		menu_find_gas = "Find gas can",
		menu_unstick = "Unstick bots",
		menu_take_melee = "Allow melee",
		menu_throw = "Throw grenades",
		menu_pathfinding = "Pathfinding",
		menu_immunity = "Immunity to player damage",
		menu_carry = "Carry Backpack",
		menu_witch_damage = "Witch Dmg Mult",
		menu_special_damage = "SI Dmg Mult",
		menu_common_damage = "CI Damage",
		menu_tank_damage = "Tank Dmg Mult",
		menu_alive = "Continue after player death",
		menu_upgrads = "Use Ammo Upgrades",
		menu_follow = "Bot Teleport Range",
		menu_fall_protect = "Lethal Damage Protection",
		menu_defibrillator = "Use Defibrillator",
		menu_next = "Next page",
		menu_pre = "Previous page",
		menu_enable = "√ ",
		menu_disable = "✕ ",
		menu_exit = "Cancel",

		ping_menu = "Ping Menu",
		ping_move = "Move",
		ping_use = "Use",
		ping_attack = "Attack",
		ping_stay = "Stay",
		ping_teleport = "Teleport",
		ping_follow = "Follow",
		ping_follow_me = "Follow Me"
	};

	addTranslationTable("english", english);

	local schinese =  {
		botai_gascan_finding_off = "Bot寻油功能关闭。",
		botai_gascan_finding_on = "Bot寻油功能开启。",
		botai_throw_grenade_off = "Bot丢投掷功能关闭。",
		botai_throw_grenade_on = "Bot丢投掷功能开启。",
		botai_immunity_off = "Bot免疫玩家伤害关闭。",
		botai_immunity_on = "Bot免疫玩家伤害开启。",
		botai_defibrillator_off = "关闭Bot使用电击器。",
		botai_defibrillator_on = "开启Bot使用电击器。",
		botai_bot_alive_on = "Bot将在玩家死后继续跑图。",
		botai_bot_alive_off = "Bot将不再在玩家死后继续跑图。",
		botai_bot_carry_on = "Bot将背负物资背包功能已开启。",
		botai_bot_carry_off = "Bot将背负物资背包功能已关闭。",
		botai_path_finding_off = "Bot寻路模式关闭。",
		botai_path_finding_on = "Bot寻路模式开启。",
		botai_use_upgrades_off = "Bot携带弹药升级包关闭。",
		botai_use_upgrades_on = "Bot携带弹药升级包开启。",
		botai_unstick_off = "关闭Bot卡住时传送。",
		botai_unstick_on = "允许Bot卡住时传送。",
		botai_unstick_pathfinding = "启用寻路时开启防卡住可能导致Bot传送到奇怪的地方。",
		botai_melee_off = "阻止Bot使用近战武器。",
		botai_melee_on = "允许Bot使用近战武器。",
		botai_fall_protect_on = "Bot即死保护已开启（受到致命伤害时传送）",
		botai_fall_protect_off = "Bot即死保护已关闭（受到致命伤害时传送）",
		botai_throw_check = "Bot行为在检查行为更新时得到一个报错抛出：",
		botai_throw_update = "Bot行为在试图更新行为时得到一个报错抛出：",
		botai_witch_damage = "Bot对女巫伤害倍率已设置为：",
		botai_special_damage = "Bot对特感伤害倍率已设置为：",
		botai_tank_damage = "Bot对Tank伤害倍率已设置为：",
		botai_common_damage = "Bot对普通感染者伤害倍率已设置为：",
		botai_throw_task = "哪个任务导致了这个问题: ",
		botai_report = "Bot行为在执行时出现错误，相关功能已重置，如方便请在评论区反馈控制台内红色报错。",
		botai_hook_exception = "尝试Hook事件时出现错误，部分功能无法正常加载，如有其他脚本模组请尝试禁用，或在控制台内检查是否有相关报错。",
		botai_hook_error = "事件Hook疑似被其他脚本模组覆盖，部分功能可能无法正常加载。",
		botai_exception_here = "如果下面几行有红色报错，请反馈：",
		botai_no_more_bot = "添加Bot功能已移除，可以使用创意工坊的Admin System来继续使用",
		botai_no_hud = "菜单需要安装Admin System模组来启用。",
		botai_no_holomenu = "全息菜单仅限客户端使用。",
		botai_admin_only = "该指令仅管理员可用。",
		botai_bot_combat_skill = "Bot战斗能力设置为: ",
		botai_bot_follow_distance = "Bot最大跟随、传送距离设置为："
		botai_use_command_notice = "使用指令!botnotice关闭配置提示",
		botai_current_settings = "当前配置:",
		botai_notice_on = "已开启配置提示",
		botai_notice_off = "已关闭配置提示",

		menu_title = "进阶Bot设置模组",
		menu_bot_skill = "Bot战斗能力",
		menu_add_bot = "添加Bot",
		menu_find_gas = "Bot寻油",
		menu_unstick = "Bot卡住传送",
		menu_take_melee = "Bot近战",
		menu_throw = "Bot丢投掷",
		menu_fall_protect = "即死保护",
		menu_pathfinding = "Bot寻路",
		menu_immunity = "Bot免疫黑枪",
		menu_carry = "Bot物资背包",
		menu_witch_damage = "女巫伤害倍率",
		menu_special_damage = "特感伤害倍率",
		menu_tank_damage = "Tank伤害倍率",
		menu_common_damage = "小僵尸伤害倍率",
		menu_alive = "Bot死后跑图",
		menu_upgrads = "Bot弹药升级",
		menu_follow = "Bot传送距离",
		menu_defibrillator = "使用电击器",
		menu_enable = "√ ",
		menu_disable = "✕ ",
		menu_next = "下一页",
		menu_pre = "上一页",
		menu_exit = "取消",

		ping_menu = "标点菜单",
		ping_move = "移动",
		ping_use = "使用",
		ping_attack = "攻击",
		ping_stay = "等待",
		ping_teleport = "传送",
		ping_follow = "跟随",
		ping_follow_me = "跟随我"
	};

	addTranslationTable("schinese", schinese);

	local tchinese =  {
		botai_gascan_finding_off = "Bot尋找油罐功能已關閉。",
		botai_gascan_finding_on = "Bot尋找油罐功能已開啟。",
		botai_throw_grenade_off = "Bot投擲手榴彈功能已關閉。",
		botai_throw_grenade_on = "Bot投擲手榴彈功能已開啟。",
		botai_immunity_off = "Bot免疫玩家傷害已關閉。",
		botai_immunity_on = "Bot免疫玩家傷害已開啟。",
		botai_bot_alive_on = "Bot會在玩家全滅後繼續行動。",
		botai_bot_alive_off = "Bot不會在玩家全滅後繼續行動。",
		botai_bot_carry_on = "Bot將背負物資背包功能已開啟。",
		botai_bot_carry_off = "Bot將背負物資背包功能已關閉。",
		botai_defibrillator_off = "Bot使用電擊器功能已關閉。",
		botai_defibrillator_on = "Bot使用電擊器功能已開啟。",
		botai_path_finding_off = "Bot路徑尋找功能已關閉。",
		botai_path_finding_on = "Bot路徑尋找功能已開啟。",
		botai_unstick_off = "Bot卡住傳送功能已關閉。",
		botai_unstick_on = "Bot卡住傳送功能已開啟。",
		botai_fall_protect_on = "Bot即死保護已開啟（受到致命傷害時傳送）",
		botai_fall_protect_off = "Bot即死保護已關閉（受到致命傷害時傳送）",
		botai_unstick_pathfinding = "啟用路徑尋找時同時開啟防卡住功能，可能導致Bot傳送到奇怪的位置。",
		botai_melee_off = "Bot使用近戰武器功能已關閉。",
		botai_melee_on = "Bot使用近戰武器功能已開啟。",
		botai_use_upgrades_on = "Bot將攜帶彈藥升級包功能已開啟",
    	botai_use_upgrades_off = "Bot將攜帶彈藥升級包功能已關閉",
		botai_throw_check = "Bot任務在檢查更新時發生錯誤：",
		botai_throw_update = "Bot任務在嘗試更新時發生錯誤：",
		botai_throw_task = "導致問題的任務：",
		botai_report = "Bot任務執行時發生錯誤，相關功能已重置，請複製控制台中的紅色錯誤訊息並回報。",
		botai_hook_exception = "掛鉤事件時發生錯誤，部分功能可能無法正常運作，請嘗試停用其他腳本模組或複製控制台中的紅色錯誤訊息並回報。",
		botai_hook_error = "事件掛鉤可能被其他腳本模組覆蓋，部分功能可能無法正常運作。",
		botai_exception_here = "若下方出現紅色錯誤訊息，請複製並回報：",
		botai_no_more_bot = "新增Bot功能已移除，如需此功能請訂閱Admin System模組。",
		botai_no_hud = "此選單需要安裝Admin System模組才能使用。",
		botai_no_holomenu = "全息選單僅限主機使用。",
		botai_admin_only = "此指令僅限管理員使用。",
		botai_bot_combat_skill = "Bot战斗能力设置为: ",
		botai_bot_follow_distance = "Bot最大跟隨、傳送距離設置為：",
		botai_witch_damage = "Bot對女巫傷害倍率已設置為: ",
		botai_special_damage = "Bot對特感傷害倍率已設置為: ",
		botai_tank_damage = "Bot對Tank傷害倍率已設置為: ",
		botai_common_damage = "Bot對普通感染者傷害倍率已設置為: ",
		botai_use_command_notice = "使用指令!botnotice關閉配置提示",
		botai_current_settings = "當前配置:",
		botai_notice_on = "已開啟配置提示",
		botai_notice_off = "已關閉配置提示",

		menu_title = "進階Bot設定模組",
		menu_add_bot = "新增Bot",
		menu_bot_skill = "Bot战斗能力",
		menu_find_gas = "Bot尋找油罐",
		menu_unstick = "Bot卡住傳送",
		menu_take_melee = "Bot使用近戰",
		menu_throw = "Bot投擲手榴彈",
		menu_pathfinding = "Bot路徑尋找",
		menu_upgrads = "彈藥升級包",
		menu_fall_protect = "即死保護",
		menu_immunity = "Bot免疫友傷",
		menu_carry = "Bot物資背包",
		menu_witch_damage = "女巫傷害倍率",
		menu_special_damage = "特感傷害倍率",
		menu_tank_damage = "Tank傷害倍率",
		menu_special_damage = "特感傷害倍率",
		menu_common_damage = "普感傷害倍率",
		menu_follow = "Bot傳送距離",
		menu_alive = "Bot玩家全滅後繼續",
		menu_defibrillator = "使用電擊器",
		menu_enable = "√ ",
		menu_disable = "✕ ",
		menu_next = "下一頁",
		menu_pre = "上一頁",
		menu_exit = "取消",

		ping_menu = "標記選單",
		ping_move = "移動",
		ping_use = "使用",
		ping_attack = "攻擊",
		ping_stay = "等待",
		ping_teleport = "傳送",
		ping_follow = "跟隨",
		ping_follow_me = "跟隨我"
	};

	addTranslationTable("tchinese", tchinese);
}

I18n.init();