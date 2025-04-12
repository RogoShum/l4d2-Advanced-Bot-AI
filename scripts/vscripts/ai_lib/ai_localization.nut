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
	local language = Convars.GetStr("cl_language").tostring();
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
	local english = 
	{
		botai_fullpower_off = "Bot Full Power Mode off.",
		botai_fullpower_on = "Bot Full Power Mode on.",
		botai_gascan_finding_off = "Bot Find Gascan off.",
		botai_gascan_finding_on = "Bot Find Gascan on.",
		botai_throw_grenade_off = "Bot Throw Grenade off.",
		botai_throw_grenade_on = "Bot Throw Grenade on.",
		botai_immunity_off = "Bot Immunity player damage off.",
		botai_immunity_on = "Bot Immunity player damage on.",
		botai_balance_mode_off = "Bot Balance Mode off.",
		botai_balance_mode_on = "Bot Balance Mode on.",
		botai_bot_alive_on = "Bots will keep going even all players are dead.",
		botai_bot_alive_off = "Bots will not keep going when all players are dead.",
		botai_bot_carry_on = "Bots will carry some supplies.",
		botai_bot_carry_off = "Bots will not carry supplies anymore.",
		botai_path_finding_off = "Bot Path Finding off.",
		botai_path_finding_on = "Bot Path Finding on.",
		botai_unstick_off = "Disabled Bots teleport function.",
		botai_unstick_on = "Enabled Bots teleport function.",
		botai_melee_off = "Not allow Bots take melee.",
		botai_melee_on = "Allow Bots take melee.",
		botai_throw_check = "AI Task caught a exception at check task updating process: ",
		botai_throw_update = "AI Task caught a exception at try update task process: ",
		botai_throw_task = "Which is the task cause this problem: ",
		botai_report = "AI Task has an error occurred, the task errored has reset, please copy the red text in the console to report.",
		botai_hook_exception = "An error occurred when hook event，some function can't works，please try to disable some script addon or copy the red text in the console to report。",
		botai_hook_error = "Event hook is suspected to be overwritten by other script addon，some function may not works will.",
		botai_exception_here = "If red text below this line, copy that ：",
		botai_no_more_bot = "More bot function has removed, please subscribe Admin System if you want it.",
		botai_no_hud = "Menu need Admin System addon to support.",
		botai_admin_only = "This command is admin only.",

		menu_title = "Advanced Bot AI",
		menu_add_bot = "Add a bot",
		menu_find_gas = "Bot find gas can",
		menu_unstick = "Bot unstick",
		menu_take_melee = "Bot take melee",
		menu_throw = "Bot throw grenades",
		menu_follow = "Bot follow player",
		menu_immunity = "Bot immunity player-damage",
		menu_carry = "Bot carry supplies",
		menu_alive = "Bot keep going",
		menu_balance = "Balance Mode",
		menu_fullpower = "Full Power Mode",
		menu_exit = "Cancel"

		ping_menu = "Ping Menu"
		ping_move = "Move"
		ping_use = "Use"
		ping_attack = "Attack"
		ping_stay = "Stay"
		ping_follow = "Follow"
		ping_follow_me = "Follow Me"
	};
	
	addTranslationTable("english", english);
	
	local schinese = 
	{
		botai_fullpower_off = "AI Full Power模式关闭。",
		botai_fullpower_on = "AI Full Power模式开启。",
		botai_gascan_finding_off = "AI寻油功能关闭。",
		botai_gascan_finding_on = "AI寻油功能开启。",
		botai_throw_grenade_off = "AI丢投掷功能关闭。",
		botai_throw_grenade_on = "AI丢投掷功能开启。",
		botai_immunity_off = "AI免疫玩家伤害关闭。",
		botai_immunity_on = "AI免疫玩家伤害开启。",
		botai_balance_mode_off = "AI平衡模式关闭。",
		botai_balance_mode_on = "AI平衡模式开启。",
		botai_bot_alive_on = "AI将在玩家死后继续跑图。",
		botai_bot_alive_off = "AI将不再在玩家死后继续跑图。",
		botai_bot_carry_on = "AI携带物资功能开启。",
		botai_bot_carry_off = "AI携带物资功能关闭。",
		botai_path_finding_off = "AI跟随模式开启。",
		botai_path_finding_on = "AI跟随模式关闭。",
		botai_unstick_off = "关闭AI卡住时传送。",
		botai_unstick_on = "允许AI卡住时传送。",
		botai_melee_off = "阻止AI使用近战武器。",
		botai_melee_on = "允许AI使用近战武器。",
		botai_throw_check = "AI行为在检查行为更新时得到一个报错抛出：",
		botai_throw_update = "AI行为在试图更新行为时得到一个报错抛出：",
		botai_throw_task = "哪个任务导致了这个问题: ",
		botai_report = "AI行为在执行时出现错误，相关功能已重置，如方便请在评论区反馈控制台内红色报错。",
		botai_hook_exception = "尝试Hook事件时出现错误，部分功能无法正常加载，如有其他脚本模组请尝试禁用，或在控制台内检查是否有相关报错。",
		botai_hook_error = "事件Hook疑似被其他脚本模组覆盖，部分功能可能无法正常加载。",
		botai_exception_here = "如果下面几行有红色报错，请反馈：",
		botai_no_more_bot = "添加Bot功能已移除，可以使用创意工坊的Admin System来继续使用",
		botai_no_hud = "菜单需要安装Admin System模组来启用。",
		botai_admin_only = "该指令仅管理员可用。",
		
		menu_title = "进阶Bot AI模组",
		menu_add_bot = "添加Bot",
		menu_find_gas = "开关Bot寻油",
		menu_unstick = "Bot卡住传送",
		menu_take_melee = "允许Bot近战",
		menu_throw = "开关Bot丢投掷",
		menu_follow = "开关Bot跟随",
		menu_immunity = "开关Bot免疫黑枪",
		menu_carry = "开关Bot携带物资",
		menu_alive = "开关Bot死后跑图",
		menu_balance = "开关平衡模式",
		menu_fullpower = "开关Full Power",
		menu_exit = "取消"

		ping_menu = "标点菜单"
		ping_move = "移动"
		ping_use = "使用"
		ping_attack = "攻击"
		ping_stay = "等待"
		ping_follow = "跟随"
		ping_follow_me = "跟随我"
	};
	
	addTranslationTable("schinese", schinese);
	
	local tchinese = 
	{
		botai_fullpower_off = "AI Full Power模式關閉。",
		botai_fullpower_on = "AI Full Power模式開啟。",
		botai_gascan_finding_off = "AI尋油功能關閉。",
		botai_gascan_finding_on = "AI尋油功能開啟。",
		botai_throw_grenade_off = "AI丟投擲功能關閉。",
		botai_throw_grenade_on = "AI丟投擲功能開啟。",
		botai_immunity_off = "AI免疫玩家傷害關閉。",
		botai_immunity_on = "AI免疫玩家傷害開啟。",
		botai_balance_mode_off = "AI平衡模式關閉。",
		botai_balance_mode_on = "AI平衡模式開啟。",
		botai_bot_alive_on = "AI將在玩家死後繼續跑圖。",
		botai_bot_alive_off = "AI將不再在玩家死後繼續跑圖。",
		botai_bot_carry_on = "AI攜帶物資功能開啟。",
		botai_bot_carry_off = "AI攜帶物資功能關閉。",
		botai_path_finding_off = "AI跟隨模式開啟。",
		botai_path_finding_on = "AI跟隨模式關閉。",
		botai_unstick_off = "關閉AI卡住時傳送。",
		botai_unstick_on = "允許AI卡住時傳送。",
		botai_melee_off = "阻止AI使用近戰武器。",
		botai_melee_on = "允許AI使用近戰武器。",
		botai_throw_check = "AI行為在檢查行為更新時得到一個報錯拋出：",
		botai_throw_update = "AI行為在試圖更新行為時得到一個報錯拋出：",
		botai_throw_task = "哪個任務導致了這個問題: ",
		botai_report = "AI行為在執行時出現錯誤，相關功能已重置，如方便請在評論區反饋控製臺內紅色報錯。",
		botai_hook_exception = "嘗試Hook事件時出現錯誤，部分功能無法正常加載，如有其他腳本模組請嘗試禁用，或在控制台內檢查是否有相關報錯。",
		botai_hook_error = "事件Hook疑似被其他腳本模組覆蓋，部分功能可能無法正常加載。",
		botai_exception_here = "如果下面幾行有紅色報錯，請反饋：",
		botai_no_more_bot = "添加Bot功能已移除，可以使用創意工坊的Admin System來繼續使用",
		botai_no_hud = "菜單需要安裝Admin System模組來啟用。",
		botai_admin_only = "该指令仅管理员可用。",
		
		menu_title = "進階Bot AI模組",
		menu_add_bot = "添加Bot",
		menu_find_gas = "開關Bot尋油",
		menu_unstick = "Bot卡住傳送",
		menu_take_melee = "允許Bot近戰",
		menu_throw = "開關Bot丟投擲",
		menu_follow = "開關Bot跟隨",
		menu_immunity = "開關Bot免疫黑槍",
		menu_follow = "開關Bot跟隨",
		menu_carry = "開關Bot攜帶物資",
		menu_alive = "開關Bot死後跑圖",
		menu_fullpower = "開關Full Power",
		menu_exit = "取消"

		ping_menu = "標點菜單"
		ping_move = "移動"
		ping_use = "使用"
		ping_attack = "攻擊"
		ping_stay = "等待"
		ping_follow = "跟隨"
		ping_follow_me = "跟隨我"
	};
	
	addTranslationTable("tchinese", tchinese);
}

I18n.init();