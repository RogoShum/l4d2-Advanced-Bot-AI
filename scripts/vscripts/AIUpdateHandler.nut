Msg("[Bot AI]	Loading BotAI\n");

if (!("VSLib" in getroottable())) {
	::VSLib <-
	{
		GlobalCache = {}
		GlobalCacheSession = {}
	}
}

//if (!("BotAIHook" in getroottable()))
{
	::BotAIHook <- {}
}

//if (!("BotAI" in getroottable()))
{
	::BotAI <- {
		timerTick = 0
		timerTick_2 = 0
		debugTick = 0
		updateTick = 0
		debugCallCount = {}
		debugCallCountTotal = {}
		hookTest = false
		moveDebug = {}
		taskTimer = {}
		usingMenu = {}
		usingPing = {}
		damageList = []

		callCache = {}
		areaCache = {}

		tickExisted = 0
		taskThinkTimerTick = 0
		disabledTask = {}
		debugPerformance = {}

		debugParam1 = null
		debugParam1_2 = 0
		doTaskUpdate = true
		BotPropertyMap = {}
		TaskUpdateOrderSingle = {}
		TaskUpdateOrderGroup = 0
		TaskOrderListSingle = {}
		TaskOrderListGroup = {}
		TaskSingleOrderMax = 0
		TaskGroupOrderMax = 0
		task_fill_tick = {}
		useTargetUsing = false
		useTargetHooks = false
		UseTarget = null
		UseTargetOri = null
		UseTargetVec = null
		UseTargetList = {}
		UseTargetOriList = {}
		UseTargetVecList = {}

		UnreachableDeath = {}
		holdButton = {}
		forceButton = {}
		disableButton = {}
		ladders = {}
		obstacles = {}

		searchedEntity = {}
		targetLocked = {}
		somethingBad = {}
		waitingToPick = {}
		preTake = {}
		BotsNeedToFind = "weapon_gascan"
		ColaBottles = "weapon_cola_bottles"
		takeElse = {
			gascan001a = "gascan001a"
			gnome = "gnome.mdl"
			oxygentank01 = "oxygentank01"
			propanecanister001a = "propanecanister001a"
			explosive_box001 = "explosive_box001"
		}
		modelMap = {
			gascan001a = "weapon_gascan"
			gnome = "weapon_gnome"
			oxygentank01 = "weapon_oxygentank"
			propanecanister001a = "weapon_propanetank"
			explosive_box001 = "weapon_fireworkcrate"
		}
		mapTransPack = {}
		scavenge_start = false
		HasTank = false
		MapName = " "
		sb_battlestation_give_up_range_from_human = 0
		sb_max_battlestation_range_from_human = 0

		TriggerList = {}
		FinaleStart = false

		TargetFindTargetFind = {}

		FullPress = {}

		vomitjarThrowed = false
		playerFallDown = 0
		playerDominated = 0
		playerLive = 0

		LeaderSurvivorBot = null
		SurvivorList = {}
		SurvivorHumanList = {}
		SurvivorBotList = {}
		SpecialList = {}
		SpecialBotList = {}
		humanBot = {}
		dangerInfected = {}
		projectileList = {}
		groundList = {}
		pingPoint = {}
		pingEntity = {}
		dangerPlace = {}
		needOil = false

		BotPosition = {}
		BotPositionCycle = 0
		BotStuckCount = {}
		FlashbackPosition = {}
		healing = {}
		healingTime = {}
		botAim = {}
		botLookAt = {}
		botMoveMap = {}
		botMove = true
		playerNavigator = {}
		playerJumpState = {}

		WitchList = {}

		StartPos = null
		InSafeHouse = {}

		PrecachedSounds = {}
		PrecachedModels = {}
		Events = {}
		Chats = {}
		Damage = {}

		VomitList = {}
		continueVomit = {}
		dontYouWannaExtinguish = {}

		SurvivorTrapped = {}
		SurvivorTrappedTimed = {}
		smokerTongue = {}
		tankThrow = {}
		ListAvoidCar = {}

		SafeTransfer = {}
		BotLinkGasCan = {}
		ButtonPressed = {}

		NeedRevive = {}
		RevivedPlayer = {}

		MainMenu = {}

		BotDebugMode = false
		BotCombatSkill = 1
		NeedGasFinding = true
		NeedThrowGrenade = true
		Immunity = false
		PathFinding = false
		Unstick = true
		Melee = true
		Defibrillator = true
		BackPack = true
		ServerMode = false
		ServerLanguage = "english"
		ABA_Admins = {}
		NoticeConfig = true
		NeedBotAlive = true
	}

	::BotAI.AITaskList <- {
		singleTasks = {}
		groupTasks = {}
	}
}
::BotAI.MapName = SessionState.MapName.tolower();

function BotAI::trueDude() {
	return true;
}

function BotAI::falseDude() {
	return false;
}

class ::TaskPerformance
{
	constructor(nameIn)
    {
        name = nameIn;
    }

	name = "";
	updateTime = 0.0;
	updateList = {}

	checkTime = 0.0;
	checkList = {}

	function preUpdate() {
		updateTime = Time() - 1;
	}

	function postUpdate() {
		local duration = Time() - 1 - updateTime;
		updateList[updateList.len()] <- duration;
		return "Task " + name + " consuming " + duration + "ms to update.";
	}

	function preCheck() {
		checkTime = Time() - 1;
	}

	function postCheck() {
		local duration = Time() - 1 - checkTime;
		checkList[checkList.len()] <- duration;
		return "Task " + name + " consuming " + duration + "ms to check.";
	}

	function print() {
		local checkAverage = 0.0;
		local updateAverage = 0.0;
		local totalCheck = 0.0;
		local totalUpdate = 0.0;
		foreach(checkT in checkList) {
			totalCheck += checkT;
		}

		if(checkList.len() > 0)
			checkAverage = totalCheck / checkList.len();

		foreach(updateT in updateList) {
			totalUpdate += updateT;
		}

		if(updateList.len() > 0)
			updateAverage = totalUpdate / updateList.len();

		local che = "Task " + name + " takes an average of " + checkAverage.tostring() + "ms to check.";
		local upd = "Task " + name + " takes an average of " + updateAverage.tostring() + "ms to update.";
		local pri = {};
		pri[0] <- che;
		pri[1] <- upd;
		return pri;
	}
}

IncludeScript("rayman1103_vslib/timer.nut");
IncludeScript("rayman1103_vslib/timer_vslib.nut");
IncludeScript("rayman1103_vslib/utils.nut");
IncludeScript("rayman1103_vslib/entity.nut");
IncludeScript("rayman1103_vslib/player.nut");
IncludeScript("rayman1103_vslib/easyLogic.nut");
IncludeScript("rayman1103_vslib/responserules.nut");
IncludeScript("rayman1103_vslib/fileio.nut");
IncludeScript("rayman1103_vslib/hud.nut");

IncludeScript("ai_lib/ai_events.nut");
IncludeScript("ai_lib/ai_utils.nut");
IncludeScript("ai_lib/ai_localization.nut");
IncludeScript("ai_lib/ai_navigator.nut");
IncludeScript("ai_lib/ai_timers.nut");
IncludeScript("ai_lib/ai_menu.nut");

IncludeScript("ai_taskes/ai-classBase.nut");
IncludeScript("ai_taskes/ai-classSingle.nut");
IncludeScript("ai_taskes/ai-classGroup.nut");
IncludeScript("ai_taskes/ai-hitInfected.nut");
IncludeScript("ai_taskes/ai-heal.nut");
IncludeScript("ai_taskes/ai-healInSafeRoom.nut");
IncludeScript("ai_taskes/ai-updateBotFireState.nut");
IncludeScript("ai_taskes/ai-shoveInfected.nut");
IncludeScript("ai_taskes/ai-avoidDanger.nut");
IncludeScript("ai_taskes/ai-savePlayerFromInfected.nut");
IncludeScript("ai_taskes/ai-searchEntity.nut");
IncludeScript("ai_taskes/ai-transItem.nut");
IncludeScript("ai_taskes/ai-transKit.nut");
IncludeScript("ai_taskes/ai-searchBody.nut");
IncludeScript("ai_taskes/ai-checkToThrowGen.nut");
IncludeScript("ai_taskes/ai-doUpgrades.nut");
IncludeScript("ai_taskes/ai-searchTrigger.nut");
IncludeScript("ai_taskes/ai-tryTraceGascan.nut");
IncludeScript("ai_taskes/ai-tryTakeGascan.nut");

::ANIM_WITCH_RUN_INTENSE <-    6
::ANIM_STANDING_CRYING <-      2

::ANIM_WITCH_LOSE_TARGET <-    5
::ANIM_WITCH_RUN_AWAY <-    8

//Witch Ducking
::ANIM_SITTING_CRY <-          4
::ANIM_SITTING_STARTLED <-     27
::ANIM_SITTING_AGGRO <-        29

//Witch Walking
::ANIM_WALK <-                 10
::ANIM_WANDER_WALK <-    11

//Witch Killing
::ANIM_WITCH_WANDER_ACQUIRE <- 30
::ANIM_WITCH_KILLING_BLOW <-   31
::ANIM_WITCH_KILLING_BLOW_TWO <-   32

::ANIM_WITCH_RUN_ONFIRE <-     39

getconsttable()["CONTENTS_SOLID"] <-			0x1;		/**< an eye is never valid in a solid . */
getconsttable()["CONTENTS_WINDOW"] <-			0x2;		/**< translucent, but not watery (glass). */
getconsttable()["CONTENTS_GRATE"] <-			0x8;		/**< alpha-tested "grate" textures.  Bullets/sight pass through, but solids don't. */
getconsttable()["CONTENTS_SLIME"] <-			0x10;
getconsttable()["CONTENTS_WATER"] <-			0x20;
getconsttable()["CONTENTS_OPAQUE"] <-			0x80;		/**< things that cannot be seen through (may be non-solid though). */
getconsttable()["CONTENTS_MOVEABLE"] <-		0x4000;		/**< hits entities which are MOVETYPE_PUSH (doors, plats, etc) */
getconsttable()["CONTENTS_MONSTER"] <-		0x2000000;	/**< should never be on a brush, only in game. */

getconsttable()["MASK_UNTHROUGHABLE"] <-(getconsttable()["CONTENTS_SOLID"]|getconsttable()["CONTENTS_GRATE"]|getconsttable()["CONTENTS_MONSTER"])
getconsttable()["MASK_SOLID_BRUSHONLY"] <-(getconsttable()["MASK_UNTHROUGHABLE"]|getconsttable()["CONTENTS_MOVEABLE"]|getconsttable()["CONTENTS_WINDOW"])
getconsttable()["MASK_UNTHROUGHABLE_WATER"] <-(getconsttable()["CONTENTS_WATER"]|getconsttable()["CONTENTS_SLIME"])
getconsttable()["MASK_SOLID"] <-(getconsttable()["CONTENTS_SOLID"]|getconsttable()["CONTENTS_GRATE"]|getconsttable()["CONTENTS_MOVEABLE"]|getconsttable()["CONTENTS_WINDOW"])

getconsttable()["FL_FROZEN"] <- (1 << 5);
getconsttable()["MOVETYPE_LADDER"] <- 9;

getconsttable()["DMG_MELEE"] <- (1 << 21);
getconsttable()["DMG_HEADSHOT"] <- (1 << 30);
getconsttable()["DMG_CRUSH"] <- (1 << 0);
getconsttable()["DMG_BULLET"] <- (1 << 1);
getconsttable()["DMG_BLAST"] <- (1 << 6);
getconsttable()["DMG_DROWN"] <- (1 << 14);

getconsttable()["BOT_CANT_SEE"] <- (1 << 0);

getconsttable()["BOT_JUMP_SPEED_LIMIT"] <- 60;

::BotAI.SaveUseTarget <- function()
{
	local UseTargetList = "";
	foreach (idx, val in BotAI.UseTargetList)
	{
		if(val != null)
		{
			local sidx = idx.tostring();
			local sval = val.tostring();

			local newString = sidx + "=" + sval + "\n";
			UseTargetList += newString;
		}
	}
	StringToFile("advanced bot ai/usetarget/UseTargetList.txt", UseTargetList);

	local UseTargetOriList = "";
	foreach (idx, val in BotAI.UseTargetOriList)
	{
		if(val != null)
		{
			local sidx = idx.tostring();
			local sval = val.tostring();
			sval = sval.slice(1);
			sval = BotAI.StringReplace(sval, "vector : ", "Vector");

			local newString = sidx + "=" + sval + "\n";
			UseTargetOriList += newString;
		}
	}
	StringToFile("advanced bot ai/usetarget/UseTargetOriList.txt", UseTargetOriList);

	local UseTargetVecList = "";
	foreach (idx, val in BotAI.UseTargetVecList)
	{
		if(val != null)
		{
			local sidx = idx.tostring();
			local sval = val.tostring();
			sval = sval.slice(1);
			sval = BotAI.StringReplace(sval, "vector : ", "Vector");

			local newString = sidx + "=" + sval + "\n";
			UseTargetVecList += newString;
		}
	}
	StringToFile("advanced bot ai/usetarget/UseTargetVecList.txt", UseTargetVecList);

	printl("[Bot AI] Save UseTarget...");
}

::BotAI.SaveSetting <- function() {

    local settingList =
        "BotCombatSkill = " + BotAI.BotCombatSkill.tostring() +
        "\nBotDebugMode = " + BotAI.BotDebugMode.tostring() +
        "\nNeedGasFinding = " + BotAI.NeedGasFinding.tostring() +
        "\nNeedThrowGrenade = " + BotAI.NeedThrowGrenade.tostring() +
        "\nImmunity = " + BotAI.Immunity.tostring() +
        "\nPathFinding = " + BotAI.PathFinding.tostring() +
        "\nUnstick = " + BotAI.Unstick.tostring() +
        "\nDefibrillator = " + BotAI.Defibrillator.tostring() +
        "\nServerMode = " + BotAI.ServerMode.tostring() +
		"\nServerLanguage = \"" + BotAI.ServerLanguage.tostring() + "\"" +
        "\nMelee = " + BotAI.Melee.tostring() +
        "\nNoticeConfig = " + BotAI.NoticeConfig.tostring() +
        "\nNeedBotAlive = " + BotAI.NeedBotAlive.tostring() +
        "\nBackPack = " + BotAI.BackPack.tostring();

    printl("[Bot AI] Save settings...");
    StringToFile("advanced bot ai/settings.txt", settingList);
}

function BotAI::removeNullString(array) {
	if (array.len() > 0) {
        local lastIndex = array.len() - 1;
        local lastElement = array[lastIndex];

        if (lastElement.len() >= 2 && lastElement.slice(lastElement.len() - 2) == "00") {
            array[lastIndex] = lastElement.slice(0, lastElement.len() - 3);
        }
    }
}

::BotAI.LoadSettings <- function () {
	local fileContents = FileToString("advanced bot ai/settings.txt");
	local settings = split(fileContents, "\r\n");
	BotAI.removeNullString(settings);

	if (settings.len() > 0) {
        local lastIndex = settings.len() - 1;
        local lastElement = settings[lastIndex];

        if (lastElement.len() >= 2 && lastElement.slice(lastElement.len() - 2) == "00") {
            settings[lastIndex] = lastElement.slice(0, lastElement.len() - 3);
        }
    }

	foreach (setting in settings) {
		if ( setting.find("//") != null ) {
			setting = BotAI.StringReplace(setting, "//" + ".*", "");
			setting = rstrip(setting);
		}

		if ( setting != "" ) {
			setting = BotAI.StringReplace(setting, "=", "<-");
			local compiledscript = compilestring("BotAI." + setting);
			compiledscript();
		}
	}

	local admins_fileContents = FileToString("advanced bot ai/admins.txt");
	local admins = split(admins_fileContents, "\r\n");
	BotAI.removeNullString(admins);

	foreach (admin in admins) {
		if ( admin.find("//") != null ) {
			admin = BotAI.StringReplace(admin, "//" + ".*", "");
			admin = rstrip(admin);
		}
		if ( admin.find("STEAM_0") != null )
			admin = BotAI.StringReplace(admin, "STEAM_0", "STEAM_1");
		if ( admin != "" )
			BotAI.ABA_Admins[admin] <- true;
	}

	BotAI.LoadUseTargets();
}

::BotAI.LoadUseTargets <- function ()
{
	printl("[Bot AI] Loading useTargets...");
	local fileContents = FileToString("advanced bot ai/usetarget/UseTargetList.txt");
	if(fileContents != null)
	{
		local usetargets = split(fileContents, "\r\n");
		BotAI.removeNullString(usetargets);

		foreach (usetarget in usetargets)
		{
			if ( usetarget.find("//") != null )
			{
				usetarget = BotAI.StringReplace(usetarget, "//" + ".*", "");
				usetarget = rstrip(usetarget);
			}

			if ( usetarget != "" && usetarget.find("=") != null)
			{
				local index = usetarget.find("=");
				local newString = "BotAI.UseTargetList[\"" + usetarget.slice(0, index) + "\"] <- \"" + usetarget.slice(index + 1) + "\"";
				local compiledscript = compilestring(newString);
				compiledscript();
			}
		}
	}


	fileContents = FileToString("advanced bot ai/usetarget/UseTargetOriList.txt");
	if(fileContents != null) {
		local usetargetsOri = split(fileContents, "\r\n");
		BotAI.removeNullString(usetargetsOri);

		foreach (usetarget in usetargetsOri) {
			if ( usetarget.find("//") != null )
			{
				usetarget = BotAI.StringReplace(usetarget, "//" + ".*", "");
				usetarget = rstrip(usetarget);
			}

			if ( usetarget != "" && usetarget.find("=") != null)
			{
				local index = usetarget.find("=");
				local newString = "BotAI.UseTargetOriList[\"" + usetarget.slice(0, index) + "\"] <- " + usetarget.slice(index + 1);
				local compiledscript = compilestring(newString);
				compiledscript();
			}
		}
	}

	fileContents = FileToString("advanced bot ai/usetarget/UseTargetVecList.txt");
	if(fileContents != null) {
		local usetargetsVec = split(fileContents, "\r\n");
		BotAI.removeNullString(usetargetsVec);

		foreach (usetarget in usetargetsVec)
		{
			if ( usetarget.find("//") != null )
			{
				usetarget = BotAI.StringReplace(usetarget, "//" + ".*", "");
				usetarget = rstrip(usetarget);
			}

			if ( usetarget != "" && usetarget.find("=") != null)
			{
				local index = usetarget.find("=");
				local newString = "BotAI.UseTargetVecList[\"" + usetarget.slice(0, index) + "\"] <- " + usetarget.slice(index + 1);
				local compiledscript = compilestring(newString);
				compiledscript();
			}
		}
	}
}

::ABA_IsAdmin <- function ( player ) {
	if (typeof player == "VSLIB_PLAYER")
		player = player.GetBaseEntity();

	if (IsDedicatedServer()) {
		printl("IsDedicatedServer")
	} else if (Director.IsSinglePlayerGame() || GetListenServerHost() == player || !BotAI.ServerMode) {
		printl("IsSinglePlayerGame")
		return true;
	}

	local steamid = player.GetNetworkIDString();

	if (!steamid) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return false;
	}

	if ( !(steamid in BotAI.ABA_Admins) ) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return false;
	}

	return true;
}

::BotAI.getBotPropertyMap <- function(player)
{
	if(player != null)
	{
		if(player in BotAI.BotPropertyMap)
			return BotAI.BotPropertyMap[player];
		else
		{
			BotAI.BotPropertyMap[player] <- BotProperty();
			return BotAI.BotPropertyMap[player];
		}
	}
	else
		return null;
}

::BotAI.getBotMoveCooldown <- function(player) {
	local map = BotAI.getBotPropertyMap(player);
	if(map != null)
		return map.moveCooldown;

	return 0;
}

::BotAI.setBotMoveCooldown <- function(player, cooldown) {
	local map = BotAI.getBotPropertyMap(player);
	if(map != null)
		map.moveCooldown = cooldown;
}

::BotAI.getBotTarget <- function(player)
{
	local map = BotAI.getBotPropertyMap(player);
	if(map != null)
		return map.target;

	return null;
}

::BotAI.setBotTarget <- function(player, target)
{
	local map = BotAI.getBotPropertyMap(player);
	if(map != null)
		map.target = target;
}

::BotAI.getBotShoveTarget <- function(player)
{
	local map = BotAI.getBotPropertyMap(player);
	if(map != null)
		return map.shove_target;

	return null;
}

::BotAI.setBotShoveTarget <- function(player, shove_target)
{
	local map = BotAI.getBotPropertyMap(player);
	if(map != null)
		map.shove_target = shove_target;
}

::BotAI.getBotAvoid <- function(player)
{
	local map = BotAI.getBotPropertyMap(player);
	if(map != null)
		return map.avoidList;

	return null;
}

::BotAI.setBotAvoid <- function(player, list)
{
	local map = BotAI.getBotPropertyMap(player);
	if(map != null)
		map.avoidList = list;
}

::BotAI.getBotDedgeVector <- function(player)
{
	local map = BotAI.getBotPropertyMap(player);
	if(map != null)
		return map.dedgeVector;

	return null;
}

::BotAI.setBotDedgeVector <- function(player, vector)
{
	local map = BotAI.getBotPropertyMap(player);
	if(map != null)
		map.dedgeVector = vector;
}

::BotAI.getSmokerTarget <- function(player)
{
	local map = BotAI.getBotPropertyMap(player);
	if(map != null)
		return map.smokerTarget;

	return null;
}

::BotAI.setSmokerTarget <- function(player, smoker)
{
	local map = BotAI.getBotPropertyMap(player);
	if(map != null)
		map.smokerTarget = smoker;
}

::BotAI.isBotTheardLocking <- function(player, order)
{
	local map = BotAI.getBotPropertyMap(player);
	if(map != null)
		return map.taskLock > -1 && map.taskLock < order;

	return false;
}

::BotAI.setBotLockTheard <- function(player, lock)
{
	local map = BotAI.getBotPropertyMap(player);
	if(map != null)
		map.taskLock = lock;
}

::BotAI.expiredBotTheard <- function(player, lock)
{
	local map = BotAI.getBotPropertyMap(player);
	if(map != null && lock == map.taskLock)
		map.taskLock = -1;
}

class ::BotProperty {
	constructor() {
    }

	target = null;
	shove_target = null;
	hand_held = null;
	dedgeVector = null;
	smokerTarget = null;
	avoidList = {};
	taskLock = 0;
	moveCooldown = Time();
}

class ::BotLinkedGas
{
	constructor(botIn, gascanIn)
    {
        bot = botIn;
        gascan = gascanIn;
    }

	bot = null;
	gascan = null;
	gascanDead = false;

	function GetBot()
	{
		return bot;
	}

	function Clear()
	{
		bot = null;
		gascan = null;
	}

	function GetGasCan()
	{
		return gascan;
	}

	function IsGasDead()
	{
		return gascanDead;
	}
}

class ::CarAvoid
{
	constructor(carIn)
    {
        car = carIn;
    }

	car = null;
	time = 50;

	function GetTime()
	{
		return time;
	}

	function SetTime(timeIn)
	{
		time = timeIn;
	}
}

function BotAI::addTask(name, task) {
	task.name = name;
	if(task.fillTick)
		BotAI.task_fill_tick[name] <- task;

	if(task.single) {
		BotAI.AITaskList.singleTasks[name] <- task;

		if(!(task.getOrder() in BotAI.TaskOrderListSingle))
			BotAI.TaskOrderListSingle[BotAI.TaskOrderListSingle.len()] <- task.getOrder();
	} else {
		BotAI.AITaskList.groupTasks[name] <- task;

		if(!(task.getOrder() in BotAI.TaskOrderListGroup))
			BotAI.TaskOrderListGroup[BotAI.TaskOrderListGroup.len()] <- task.getOrder();
	}
}

function BotAI::updateAITasks() {
	BotAI.taskThinkTimerTick++;
	if(!BotAI.doTaskUpdate)
		return 0.0331;

	if(BotAI.taskThinkTimerTick % 2 == 0) {
		return 0.0331;
	} else {
		BotAI.tickExisted++;
		BotAI.AdjustBotsUpdateRate(1);
	}

	return 0.0331;
}

function BotAI::updateSingleAITasks() {
	foreach(player in BotAI.SurvivorBotList) {
		if(!BotAI.IsPlayerEntityValid(player)) continue;

		if(!(player in BotAI.TaskUpdateOrderSingle))
			BotAI.TaskUpdateOrderSingle[player] <- 0;
		BotAI.taskHandler(player, BotAI.AITaskList.singleTasks, BotAI.TaskUpdateOrderSingle[player], BotAI.TaskOrderListSingle);
	}
}

function BotAI::updateGroupAITasks() {
	BotAI.taskHandler(null, BotAI.AITaskList.groupTasks, BotAI.TaskUpdateOrderGroup, BotAI.TaskOrderListGroup);
}

function BotAI::taskHandler(player, tasks, order, orderTable) {
	local AITaskUpdateList = {};
	local queueOver = true;

	foreach(idx, task in tasks) {
		local shouldTick = task.shouldTick(player) && !(idx in BotAI.disabledTask);

		if(shouldTick) {
			task.setLastTickTime(player, BotAI.tickExisted + task.tick);
		}

		if((task.getOrder() == order || task.isForce())) {
			if(shouldTick && (task.isUpdating(player) || task.shouldUpdate(player)) && (queueOver || task.isCompatible())) {
				if(task.getOrder() == order && !task.isForce())
					queueOver = false;
				AITaskUpdateList[idx] <- task;
			}
		} else {
			task.taskReset(player);
		}
	}

	foreach(idx, task in AITaskUpdateList) {
		task.taskUpdate(player);
	}

	if(queueOver) {
		local i = order + 1;

		if(BotAI.IsPlayerEntityValid(player)) {
			if(i > BotAI.TaskSingleOrderMax)
				i = 0;
			BotAI.TaskUpdateOrderSingle[player] = i;
		} else {
			if(i > BotAI.TaskGroupOrderMax)
				i = 0;
			BotAI.TaskUpdateOrderGroup = i;
		}
	}
}

function BotAI::ModifyMolotovVector(args) {
	/*local view = null;
	while(view = Entities.FindByClassname(view, "predicted_viewmodel")) {
		printl("view " + NetProps.GetPropEntity(view, "m_hOwner"));
	}*/

	foreach(idx, infinityFire in BotAI.dontYouWannaExtinguish) {
		if(!BotAI.IsAlive(infinityFire)) {
			delete BotAI.dontYouWannaExtinguish[idx];
			continue;
		} else if(!BotAI.IsOnFire(infinityFire)) {
			DoEntFire("!self", "Ignite", "0", 0, null, infinityFire);
		}
	}

	local molotov = null;
	while(molotov = Entities.FindByClassname(molotov, "molotov_projectile")) {
		local thrower = NetProps.GetPropEntity(molotov, "m_hThrower");
		if(!BotAI.IsEntitySurvivorBot(thrower)) continue;

		local entT = null;
		local nearest = null;
		local nearestDis = 700;

		while (entT = Entities.FindByModel(entT, "models/infected/hulk.mdl")) {
			if(!entT.IsValid() || !BotAI.IsAlive(entT) || BotAI.IsOnFire(entT) || !BotAI.CanHitOtherEntity(molotov, entT)) continue;

			local distance = BotAI.distanceof(molotov.GetOrigin(), entT.GetOrigin());
			if (distance < nearestDis) {
				nearestDis = distance;
				nearest = entT;
			}
		}

		if(BotAI.IsEntitySI(nearest)) {
			local originVec = molotov.GetVelocity();
			local traceVec = BotAI.normalize(nearest.GetOrigin() - molotov.GetOrigin()).Scale(originVec.Length());
			if(traceVec.z > 0)
				traceVec = BotAI.fakeTwoD(traceVec);

			molotov.SetVelocity(traceVec.Scale(0.5) + originVec.Scale(0.5));
		}
	}

	local vomitjar = null;
	while(vomitjar = Entities.FindByClassname(vomitjar, "vomitjar_projectile")) {
		local thrower = NetProps.GetPropEntity(vomitjar, "m_hThrower");
		if(!BotAI.IsEntitySurvivorBot(thrower)) continue;

		local throwable = g_ModeScript.CreateSingleSimpleEntityFromTable({classname = "weapon_vomitjar"});

		if(throwable) {
			throwable.ValidateScriptScope();
		}

		if(BotAI.IsEntityValid(throwable)) {
			local eyevec = thrower.EyeAngles().Forward();
			throwable.SetOrigin(Vector(thrower.EyePosition().x + eyevec.x * 70, thrower.EyePosition().y + eyevec.y * 70, thrower.EyePosition().z + eyevec.z * 70));
			throwable.SetAngles(vomitjar.GetAngles());
			throwable.__KeyValueFromString("targetname", "botaivomitjar");
			throwable.SetVelocity(vomitjar.GetVelocity());
			throwable.ApplyAbsVelocityImpulse(vomitjar.GetVelocity());
			vomitjar.Kill();
		}
	}

	vomitjar = null;
	while(vomitjar = Entities.FindByClassname(vomitjar, "weapon_vomitjar")) {
		local name = vomitjar.GetName();
		if(name != "botaivomitjar") continue;

		local entT = null;
		local nearest = null;
		local nearestDis = 1000;

		while (entT = Entities.FindByModel(entT, "models/infected/hulk.mdl")) {
			if(!entT.IsValid() || !BotAI.IsAlive(entT) || BotAI.IsOnFire(entT) || !BotAI.CanHitOtherEntity(vomitjar, entT)) continue;

			local distance = BotAI.distanceof(vomitjar.GetOrigin(), entT.GetOrigin());
			if (distance < nearestDis) {
				nearestDis = distance;
				nearest = entT;
			}
		}

		local bomb = false;
		if(BotAI.IsEntitySI(nearest)) {
			local traceVec = BotAI.normalize(nearest.GetOrigin() - vomitjar.GetOrigin()).Scale(700);
			vomitjar.SetVelocity(traceVec);
			vomitjar.ApplyAbsVelocityImpulse(traceVec);
			if(BotAI.distanceof(nearest.GetOrigin(), vomitjar.GetOrigin()) < 200) {
				bomb = true;
			}
		}

		if(!BotAI.IsEntitySI(nearest)) {
			if(BotAI.GetDistanceToGround(vomitjar) <= 10)
				BotAI.vomitBomb(vomitjar);
		}
		else if(bomb)
			BotAI.vomitBomb(vomitjar);
	}
}

function BotAI::AdjustBotsUpdateRate(args) {
	if (BotAI.BotCombatSkill > 4) {
		BotAI.BotCombatSkill = 4;
	}

	local FalledPlayer = 0;
	local LivedPlayer = 0;
	BotAI.playerDominated = 0;
	foreach(playerSet in BotAI.SurvivorList) {
		if(BotAI.IsPlayerEntityValid(playerSet)) {
			if(!BotAI.IsAlive(playerSet) || playerSet.IsIncapacitated() || playerSet.IsHangingFromLedge() || playerSet.IsDominatedBySpecialInfected() || (playerSet.GetHealth() + (playerSet.GetHealthBuffer() * 0.7)) < 15)
				FalledPlayer++;
			else
				LivedPlayer++;

			if(!BotAI.IsAlive(playerSet)) continue;

			if(playerSet.IsDominatedBySpecialInfected())
				BotAI.playerDominated++;

			if(BotAI.BotCombatSkill > 2 && IsPlayerABot(playerSet) && (playerSet.GetHealth() + playerSet.GetHealthBuffer()) < 40 && !playerSet.IsAdrenalineActive()) {
				playerSet.UseAdrenaline(20);
			}

			if(IsPlayerABot(playerSet) || playerSet in BotAI.humanBot) {
				local area = playerSet.GetLastKnownArea();
				if(BotAI.BotDebugMode && area) {
					local r = 255;
					local g = 255;
					local b = 0;
					if(area.IsDamaging()) {
						r = 255;
						g = 0;
						b = 0;
					} else if (area.IsUnderwater()) {
						r = 50;
						g = 50;
						b = 255;
					} else if (area.IsBlocked(2, false)) {
						r = 255;
						g = 0;
						b = 255;
					}
					//area.DebugDrawFilled(r, g, b, 15, 0.2, true);
					//DebugDrawText(playerSet.GetOrigin(), GetFlowDistanceForPosition(playerSet.GetOrigin()).tostring(), false, 0.2);
				}

				//bug Fix
				//1.
				local weapon = playerSet.GetActiveWeapon();
				if (weapon && weapon.GetClassname() == "weapon_first_aid_kit") {
					if (BotAI.IsPressingAttack(playerSet)) {
						BotAI.ForceButton(playerSet, 1, 2);
					}

					if (BotAI.IsBotHealing(playerSet)) {
						BotAI.ForceButton(playerSet, 2048, 2);
					}
				}

				//not working
				//2.
				local t = BotAI.getBotTarget(playerSet);
				//printl("[Bot AI] " + BotAI.getPlayerBaseName(playerSet) + " " + t);
				if (weapon && BotAI.IsEntitySurvivor(t) && (weapon.GetClassname() != "weapon_first_aid_kit" && weapon.GetClassname() != "weapon_pain_pills" && weapon.GetClassname() != "weapon_adrenaline")) {
					BotAI.DisableButton(playerSet, 2048, 2);
				}
			}
		}
	}

	foreach(smoker in BotAI.SpecialList) {
		if(BotAI.IsPlayerEntityValid(smoker) && smoker.GetEntityIndex() in BotAI.smokerTongue) {
			BotAI.smokerTongue[smoker.GetEntityIndex()] <- BotAI.smokerTongue[smoker.GetEntityIndex()] + 1;
		}

		if(BotAI.GetTarget(smoker) in BotAI.SafeTransfer) {
			foreach(sur in BotAI.SurvivorList) {
				if(!BotAI.IsAlive(sur) || sur in BotAI.SafeTransfer) continue;
				BotAI.SetTarget(smoker, sur);
			}
		}
	}

	foreach(idx, pro in BotAI.projectileList) {
		if(!BotAI.IsEntityValid(pro)) {
			delete BotAI.projectileList[idx];
		} else if(BotAI.GetEntitySpeedVector(pro) <= 10 && BotAI.GetEntitySpeedLocalVector(pro) <= 10 && !(pro.GetEntityIndex() in BotAI.ListAvoidCar)) {
			delete BotAI.projectileList[idx];
		}
	}

	foreach(idx, pro in BotAI.groundList) {
		if (!BotAI.IsEntityValid(pro))
			delete BotAI.groundList[idx];
	}

	foreach(idx, gas in BotAI.BotLinkGasCan) {
		if(!BotAI.IsEntityValid(gas))
			delete BotAI.BotLinkGasCan[idx];
		else if(gas.GetOwnerEntity() != null) {
			delete BotAI.BotLinkGasCan[idx];
		} else {
			if(NetProps.HasProp(gas, "m_CollisionGroup"))
				NetProps.SetPropInt(gas, "m_CollisionGroup", 2);
		}
	}

	foreach(idx, thing in BotAI.somethingBad) {
		if(!BotAI.IsEntityValid(thing))
			delete BotAI.somethingBad[idx];
		else if(thing.GetOwnerEntity() != null) {
			delete BotAI.somethingBad[idx];
		}
	}

	foreach(idx, thing in BotAI.targetLocked) {
		if(!BotAI.IsEntityValid(thing))
			delete BotAI.targetLocked[idx];
	}

	BotAI.playerFallDown = FalledPlayer;
	BotAI.playerLive = LivedPlayer;

	local witchList = {};
	local witch = null;
	while(witch = Entities.FindByClassname(witch, "witch")) {
		if(witch.IsValid() && BotAI.IsAlive(witch))
			witchList[witchList.len()] <- witch;
	}

	BotAI.WitchList = witchList;

	BotAI.GiveUpPlayer(true);
}

::BotAI.GiveUpPlayer <- function(flag) {
	if(BotAI.HasTank && BotAI.playerFallDown > 0 && flag) {
		foreach(player in BotAI.SurvivorList) {
			if(player.IsIncapacitated() || player.IsHangingFromLedge()) {
				local danger = false;
				local area = player.GetLastKnownArea();
				foreach(sp in SpecialList) {
					if(BotAI.IsEntitySI(sp) && sp.GetZombieType() == 8 && BotAI.distanceof(sp.GetOrigin(), player.GetOrigin()) < 650) {
						danger = true;
					}
				}

				if(danger) {
					if(!area.IsBlocked(2, false) && !area.IsBlocked(2, true)) {
						area.MarkAsBlocked(2);
						BotAI.dangerPlace[area.GetID()] <- area;
					}

					Convars.SetValue( "sb_revive_friend_distance", 20 );
				} else if(area.GetID() in BotAI.dangerPlace) {
					area.UnblockArea();
					Convars.SetValue( "sb_revive_friend_distance", BotAI.reviveDistance );
				}
			}
		}
	} else if(BotAI.dangerPlace.len() > 0) {
		foreach(area in BotAI.dangerPlace) {
			area.UnblockArea();
		}
		BotAI.dangerPlace = {};

		Convars.SetValue( "sb_revive_friend_distance", BotAI.reviveDistance );
	}
}

function BotAI::TriggerHandler(args)
{
	local usableTrigger = {};

	local Target = null;

	if(!BotAI.FinaleStart)
	while(Target = Entities.FindByClassname(Target, "trigger_finale"))
	{
		usableTrigger[Target.GetEntityIndex()] <- false;
	}

	local item = null;
	while(item = Entities.FindByClassname(item, "func_button"))
	{
		local m_usable = NetProps.GetPropInt(item, "m_usable");

		if (m_usable == 1)
			usableTrigger[item.GetEntityIndex()] <- false;
	}

	item = null;
	while(item = Entities.FindByClassname(item, "func_button_timed"))
	{
		local m_usable = NetProps.GetPropInt(item, "m_usable");
		if (m_usable == 1)
			usableTrigger[item.GetEntityIndex()] <- false;
	}

	BotAI.TriggerList = usableTrigger;
}

function BotAI::locateUseTarget(args)
{
	if(!BotAI.NeedGasFinding)
		return;

	notBotPlayerBoolean <- true;

	if(BotAI.UseTarget == null && BotAI.MapName in BotAI.UseTargetList && BotAI.MapName in BotAI.UseTargetOriList && BotAI.MapName in BotAI.UseTargetVecList)
	{
		if(Entities.FindByName( null, BotAI.UseTargetList[BotAI.MapName]))
		{
			local UseTarget = Entities.FindByName( null, BotAI.UseTargetList[BotAI.MapName] );
			local UseTargetOri = BotAI.UseTargetOriList[BotAI.MapName];
			local UseTargetVec = BotAI.UseTargetVecList[BotAI.MapName];

			playerSet <- null;

			while(playerSet = Entities.FindByClassname(playerSet, "player"))
			{
				if(BotAI.IsEntityValid(UseTarget) && BotAI.IsPlayerEntityValid(playerSet) && playerSet.IsSurvivor() && (BotAI.distanceof(playerSet.GetOrigin(), UseTargetOri) < 301 || BotAI.scavenge_start))
				{
					BotAI.UseTarget = UseTarget;
					BotAI.UseTargetOri = UseTargetOri;
					BotAI.UseTargetVec = UseTargetVec;
					printl("[Bot AI] Loaded UseTarget...");
					return;
				}
			}
		}
	}

	if(BotAI.UseTarget == null)
	{
		notBotPlayer <- null;
		while(notBotPlayer = Entities.FindByClassname(notBotPlayer, "player"))
		{
			if(BotAI.IsPlayerEntityValid(notBotPlayer) && notBotPlayer.IsSurvivor() && !IsPlayerABot(notBotPlayer) && NetProps.GetPropInt(notBotPlayer, "m_iTeamNum") != 1 && !notBotPlayer.IsDead())
			{
				notBotPlayerBoolean = false;
				if((BotAI.IsPressingUse(notBotPlayer) || BotAI.IsPressingAttack(notBotPlayer)) && BotAI.HasItem(notBotPlayer, BotAI.BotsNeedToFind))
				{
					target <- null;
					while (target = Entities.FindByClassnameWithin(target, "point_prop_use_target", notBotPlayer.GetOrigin() + Vector(0, 0, 40), 150))
					{
						if(NetProps.GetPropInt(target, "m_spawnflags") == 1)
						{
							if(BotAI.GetHitPosition(notBotPlayer, 9999, true) != null)
							{
								BotAI.UseTarget = target;
								BotAI.UseTargetList[BotAI.MapName] <- target.GetName();
								BotAI.UseTargetVec = BotAI.GetHitPosition(notBotPlayer, 9999, true);
								BotAI.UseTargetVecList[BotAI.MapName] <- BotAI.UseTargetVec;
								BotAI.UseTargetOri = notBotPlayer.GetOrigin();
								BotAI.UseTargetOriList[BotAI.MapName] <- notBotPlayer.GetOrigin();
								printl("[Bot AI] Located target at " + BotAI.UseTarget.GetOrigin());
							}
							else
							{
								local m_trace = { start = target.GetOrigin(), end = notBotPlayer.EyePosition(), ignore = target, mask = g_MapScript.TRACE_MASK_ALL};
								TraceLine(m_trace);

								if (m_trace.hit && m_trace.enthit != null && m_trace.enthit == notBotPlayer)
								{
									BotAI.UseTarget = target;
									BotAI.UseTargetList[BotAI.MapName] <- target.GetName();
									BotAI.UseTargetVec = target.GetOrigin();
									BotAI.UseTargetVecList[BotAI.MapName] <- BotAI.UseTargetVec;
									BotAI.UseTargetOri = notBotPlayer.GetOrigin();
									BotAI.UseTargetOriList[BotAI.MapName] <- notBotPlayer.GetOrigin();
									printl("[Bot AI] Located target at " + BotAI.UseTarget.GetOrigin());
								}
							}

							if(BotAI.UseTargetVec == null && BotAI.GetHitPosition(notBotPlayer, 9999, false) != null)
							{
								BotAI.UseTarget = target;
								BotAI.UseTargetList[BotAI.MapName] <- target.GetName();
								BotAI.UseTargetVec = BotAI.GetHitPosition(notBotPlayer, 9999, false);
								BotAI.UseTargetVecList[BotAI.MapName] <- BotAI.UseTargetVec;
								BotAI.UseTargetOri = notBotPlayer.GetOrigin();
								BotAI.UseTargetOriList[BotAI.MapName] <- notBotPlayer.GetOrigin();
								printl("[Bot AI] Located target at " + BotAI.UseTarget.GetOrigin());
							}
						}
					}
				}
			}
		}

		if(notBotPlayerBoolean) {
			playerSet <- null;

			while(playerSet = Entities.FindByClassname(playerSet, "player")) {
				if(BotAI.IsPlayerEntityValid(playerSet) && playerSet.IsSurvivor() && IsPlayerABot(playerSet)) {
					target <- null;
					while (target = Entities.FindByClassnameWithin(target, "point_prop_use_target", playerSet.GetOrigin() + Vector(0, 0, 40), 300)) {
						if(NetProps.GetPropInt(target, "m_spawnflags") == 1) {
							if(!(BotAI.MapName in BotAI.UseTargetList))
								BotAI.UseTarget = target;
							if(!(BotAI.MapName in BotAI.UseTargetOriList))
								BotAI.UseTargetOri = target.GetOrigin();
							printl("[Bot AI]Located target at " + target.GetOrigin());
							return;
						}
					}
				}
			}
		}
	}
}

::MoreBotCmd <- function ( player, args , args1) {
	BotAI.EasyPrint("botai_no_more_bot");
}

::BotStopCmd <- function ( speaker, args , args1) {
	notBotPlayer <- null;
	while(notBotPlayer = Entities.FindByClassname(notBotPlayer, "player")) {
		if(BotAI.IsPlayerEntityValid(notBotPlayer) && notBotPlayer.IsSurvivor() && !IsPlayerABot(notBotPlayer) && NetProps.GetPropInt(notBotPlayer, "m_iTeamNum") != 1 && !notBotPlayer.IsDead()) {
			return;
		}
	}

	player <- null;
	while(player = Entities.FindByClassname(player, "player")) {
		if(BotAI.IsPlayerEntityValid(player) && player.IsSurvivor() && IsPlayerABot(player)) {
			BotAI.setLastStrike(player);
			player.SetHealth(-100);
			player.TakeDamage(100, 0, player);
			VSLib.Entity(player).Ignite(100);
		}
	}
}

::BotAISkillCmd <- function ( speaker, args , args1) {
	if(!ABA_IsAdmin(speaker)) {
		return;
	}

	if(args.len() >= 1 && args[0] != null && args[0] != "") {
		local arg = args[0].tointeger();

		if(arg > 5) {
			arg = 5;
		}

		if(arg < 1) {
			arg = 1;
		}

		BotAI.BotCombatSkill = arg - 1;
		BotAI.EasyPrint("botai_bot_combat_skill", 0.2, arg);
	} else {
		if(BotAI.BotCombatSkill > 0) {
			BotAI.BotCombatSkill = 0;
			BotAI.EasyPrint("botai_bot_combat_skill", 0.2, 0);
		} else {
			BotAI.BotCombatSkill = 2;
			BotAI.EasyPrint("botai_bot_combat_skill", 0.2, 2);
		}
	}

	BotExitMenuCmd(speaker, args, args1);
	BotAI.SaveSetting();
}

::BotGascanFindCmd <- function ( speaker, args  , args1) {
	if(BotAI.NeedGasFinding)
	{
		BotAI.NeedGasFinding = false;
		BotAI.EasyPrint("botai_gascan_finding_off");
	}
	else
	{
		BotAI.NeedGasFinding = true;
		BotAI.EasyPrint("botai_gascan_finding_on");
	}
	BotAI.SaveSetting();
	BotExitMenuCmd(speaker, args, args1);
}

::BotThrowGrenadeCmd <- function ( speaker, args  , args1) {
	if(BotAI.NeedThrowGrenade)
	{
		BotAI.NeedThrowGrenade = false;
		BotAI.EasyPrint("botai_throw_grenade_off");
	}
	else
	{
		BotAI.NeedThrowGrenade = true;
		BotAI.EasyPrint("botai_throw_grenade_on");
	}
	BotAI.SaveSetting();
	BotExitMenuCmd(speaker, args, args1);
}

::BotImmunityCmd <- function ( speaker, args  , args1)
{
	BotExitMenuCmd(speaker, args, args1);
	if(!ABA_IsAdmin(speaker))
		return;

	if(BotAI.Immunity)
	{
		BotAI.Immunity = false;
		BotAI.EasyPrint("botai_immunity_off");
	}
	else
	{
		BotAI.Immunity = true;
		BotAI.EasyPrint("botai_immunity_on");
	}
	BotAI.SaveSetting();
}

::BotDefibrillatorCmd <- function ( speaker, args, args1) {
	BotExitMenuCmd(speaker, args, args1);

	if(BotAI.Defibrillator) {
		BotAI.Defibrillator = false;
		BotAI.EasyPrint("botai_defibrillator_off");
	} else {
		BotAI.Defibrillator = true;
		BotAI.EasyPrint("botai_defibrillator_on");
	}
	BotAI.SaveSetting();
}

::BotBackPackCmd <- function ( speaker, args  , args1) {
	BotExitMenuCmd(speaker, args, args1);
	if(BotAI.BackPack) {
		BotAI.BackPack = false;
		BotAI.EasyPrint("botai_bot_carry_off");
	}
	else {
		BotAI.BackPack = true;
		BotAI.EasyPrint("botai_bot_carry_on");
	}
	BotAI.SaveSetting();
}

::BotAliveCmd <- function ( speaker, args  , args1) {
	BotExitMenuCmd(speaker, args, args1);
	if(BotAI.NeedBotAlive) {
		BotAI.NeedBotAlive = false;
		Convars.SetValue( "sb_all_bot_game", 0);
		Convars.SetValue( "allow_all_bot_survivor_team", 0 );
		BotStopCmd(speaker, args, args1);
		BotAI.EasyPrint("botai_bot_alive_off");
	} else {
		BotAI.NeedBotAlive = true;
		Convars.SetValue( "sb_all_bot_game", 1);
		Convars.SetValue( "allow_all_bot_survivor_team", 1 );
		BotAI.EasyPrint("botai_bot_alive_on");
	}
	BotAI.SaveSetting();
}

::BotPathFindingCmd <- function ( speaker, args , args1)
{
	BotExitMenuCmd(speaker, args, args1);

	if(BotAI.PathFinding) {
		BotAI.PathFinding = false;
		Convars.SetValue( "sb_separation_range", 100 );
		Convars.SetValue( "sb_separation_danger_min_range", 100 );
		Convars.SetValue( "sb_separation_danger_max_range", 300 );
		Convars.SetValue( "sb_allow_leading", 0 );
		Convars.SetValue( "sb_neighbor_range", 120 );
		//Convars.SetValue( "sb_escort", 1 );
		BotAI.EasyPrint("botai_path_finding_off");
	} else {
		BotAI.PathFinding = true;
		Convars.SetValue( "sb_allow_leading", 1 );
		Convars.SetValue( "sb_separation_range", 2000 );
		Convars.SetValue( "sb_separation_danger_min_range", 500 );
		Convars.SetValue( "sb_separation_danger_max_range", 2000 );
		Convars.SetValue( "sb_neighbor_range", 1000 );
		//Convars.SetValue( "sb_escort", 0 );
		BotAI.EasyPrint("botai_path_finding_on");
		if(BotAI.PathFinding) {
			BotAI.EasyPrint("botai_unstick_pathfinding");
		}
	}
	BotAI.SaveSetting();
}

::BotUnstickCmd <- function ( speaker, args , args1) {
	BotExitMenuCmd(speaker, args, args1);
	if(BotAI.Unstick) {
		BotAI.Unstick = false;
		Convars.SetValue( "sb_unstick", 0 );
		BotAI.EasyPrint("botai_unstick_off");
	} else {
		BotAI.Unstick = true;
		Convars.SetValue( "sb_unstick", 1 );
		BotAI.EasyPrint("botai_unstick_on");
		if(BotAI.PathFinding) {
			BotAI.EasyPrint("botai_unstick_pathfinding");
		}
	}
	BotAI.SaveSetting();
}

::BotMeleeCmd <- function ( speaker, args , args1) {
	if(BotAI.Melee) {
		BotAI.Melee = false;
		Convars.SetValue( "sb_max_team_melee_weapons", 0 );
		BotAI.EasyPrint("botai_melee_off");
	} else {
		BotAI.Melee = true;
		BotAI.resetBotMeleeAction();
		BotAI.EasyPrint("botai_melee_on");
	}
	BotAI.SaveSetting();
	BotExitMenuCmd(speaker, args, args1);
}

::BotAI.EasyPrint <- function (str, time = 0.2, args = "") {
	local function cPrint(s) {
		if (BotAI.BotDebugMode) {
			printl(s);
		}
		ClientPrint(null, 5, "[Advanced Bot AI]: " + "\x01" + I18n.getTranslationKey(s) + args);
	}

	::BotAI.Timers.AddTimer(time, false, cPrint, str);
}

::BotAI.SendPlayer <- function (player, str) {

	local function cPrint(s) {
		if (BotAI.BotDebugMode) {
			printl(str);
		}
		ClientPrint(player, 5, "[Advanced Bot AI]: " + "\x01" + I18n.getTranslationKey(str));
	}

	::BotAI.Timers.AddTimer(0.2, false, cPrint, str);
}

function BotAI::registerMenu() {
	local botMenu = ::HoloMenu.Menu("menu_title", BUTTON_GRENADE1);
	local function showMenu(player) {
		BotMenuCmd(player, "", "");
	}
	botMenu.registerPressEvent(showMenu);

	local pingMenu = ::HoloMenu.Menu("ping_menu", BUTTON_ALT2);
	local function openMenu(player) {
		if(BotAI.MainMenu.len()>0)
			BotExitMenuCmd(player, "", "");
		if(!(player in BotAI.pingPoint) || !BotAI.IsAlive(BotAI.pingPoint[player])) return;
		local traceTable = {
			start = player.EyePosition()
			end =  player.EyePosition() + player.EyeAngles().Forward().Scale(9999)
			ignore = player
			mask = g_MapScript.TRACE_MASK_ALL
		}
		TraceLine(traceTable);

		if(traceTable.hit) {
			if(traceTable.enthit != null && traceTable.enthit.GetClassname() != "worldspawn" && traceTable.enthit.IsValid())
				BotAI.pingEntity[player] <- traceTable.enthit;
			else
				BotAI.pingEntity[player] <- traceTable.pos;
		}
		local lang = BotAI.language;
		local functions = pingMenu.getFilteredFunction(player);
		local function top(menu) {
			foreach(idx, func in functions) {
				menu.AddOption(I18n.getTranslationKeyByLang(lang, idx), func);
			}
		}

		local function bot(menu) {
			menu.AddOption("emp_3", BotEmptyCmd);
			menu.AddOption("emp_2", BotEmptyCmd);
			menu.AddOption("emp_0", BotEmptyCmd);
			menu.AddOption("emp_1", BotEmptyCmd);
			menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_exit"), BotExitMenuCmd);
		}

		BotAI.buildMenu(player, top, bot);
	}

	local function ping(player) {
		local point = BotAI.CanSeeOtherEntityPrintName(player, 2000, 0, g_MapScript.TRACE_MASK_ALL);
		if(!BotAI.IsEntitySurvivorBot(point)) {
			local dot = 0.98;
			foreach(bot in BotAI.SurvivorBotList) {
				local dirction = BotAI.normalize(bot.GetCenter() - player.EyePosition());
				local dotValue = dirction.Dot(player.EyeAngles().Forward());
				if(dotValue >= dot) {
					point = bot;
					dot = dotValue;
				}
			}
		}

		if(BotAI.IsEntitySurvivorBot(point)) {
			if(player in BotAI.pingPoint && BotAI.pingPoint[player] == point)
				delete BotAI.pingPoint[player];
			else
				BotAI.pingPoint[player] <- point;
			return;
		}

		if(!(player in BotAI.pingPoint) || !BotAI.IsEntityValid(BotAI.pingPoint[player])) return;

		openMenu(player);
	}
	local function filterIcon(player, functionsIn) {
		local entity = BotAI.pingEntity[player];
		local functions = {}

		if(typeof entity == "Vector") {
			foreach(idx, func in functionsIn) {
				if(idx == "ping_move" || idx == "ping_stay" || idx == "ping_follow_me" || idx == "ping_teleport")
					functions[idx] <- func;
			}
		} else if(BotAI.IsEntityValid(entity)) {
			local name = entity.GetClassname();
			if(name == "player" || name == "infected" || name == "witch") {
				foreach(idx, func in functionsIn) {
					if(idx == "ping_move" || idx == "ping_attack" || idx == "ping_follow")
						functions[idx] <- func;
				}
			} else {
				foreach(idx, func in functionsIn) {
					if(idx == "ping_move" || idx == "ping_use" || idx == "ping_stay" || idx == "ping_attack")
						functions[idx] <- func;
				}
			}
		}
		//functions["menu_exit"] <- functionsIn["menu_exit"]

		return functions;
	}
	pingMenu.registerTickEvent(30, openMenu);
	pingMenu.registerPressEvent(ping);
	HoloMenu.IconHook("ping_menu", filterIcon);
	local function convertPlayer(p) {
		if (!("VSLib" in getroottable() && "HUD" in ::VSLib)) {
			BotAI.EasyPrint("botai_no_hud");
		}

		if (typeof p == "VSLIB_PLAYER") {
			p = p.GetBaseEntity();
		}
		return p;
	}

	local function move(player, args = "", args1 = "") {
		BotExitMenuCmd(player, args, args1);
		player = convertPlayer(player);
		local entity  = BotAI.pingEntity[player];
		if(player in BotAI.pingPoint && BotAI.botStayPos(BotAI.pingPoint[player], entity, "ping", 4, 3))
			delete BotAI.pingPoint[player];
	}

	local function use(player, args = "", args1 = "") {
		BotExitMenuCmd(player, args, args1);
		player = convertPlayer(player);
		local entity  = BotAI.pingEntity[player];
		local bot = BotAI.pingPoint[player];
		local function changeAndUse() {
			if(!BotAI.IsAlive(bot)) return true;
			local navigator = BotAI.getNavigator(bot);
			if(BotAI.distanceof(entity.GetOrigin(), bot.GetOrigin()) <= 100) {
				DoEntFire("!self", "Use", "", 0, bot, entity);
				return true;
			}
			return false;
		}
		if(player in BotAI.pingPoint && BotAI.botRunPos(BotAI.pingPoint[player], entity, "ping", 4, changeAndUse))
			delete BotAI.pingPoint[player];
	}

	local function attack(player, args = "", args1 = "") {
		BotExitMenuCmd(player, args, args1);
		player = convertPlayer(player);
		local entity = BotAI.pingEntity[player];
		local old = null;
		if(BotAI.pingPoint[player] in BotAI.targetLocked)
			old = BotAI.targetLocked[BotAI.pingPoint[player]];
		if(old == entity)
			delete BotAI.targetLocked[BotAI.pingPoint[player]];
		else
			BotAI.targetLocked[BotAI.pingPoint[player]] <- entity;
		delete BotAI.pingPoint[player];
	}

	local function stay(player, args = "", args1 = "") {
		BotExitMenuCmd(player, args, args1);
		player = convertPlayer(player);
		local entity  = BotAI.pingEntity[player];
		if(player in BotAI.pingPoint && BotAI.botStayPos(BotAI.pingPoint[player], entity, "ping", 4, 9999))
			delete BotAI.pingPoint[player];
	}

	local function follow(player, args = "", args1 = "") {
		BotExitMenuCmd(player, args, args1);
		player = convertPlayer(player);
		if(player in BotAI.pingPoint && BotAI.botStayPos(BotAI.pingPoint[player], player, "ping", 4, 9999))
			delete BotAI.pingPoint[player];
	}

	local function teleport(player, args = "", args1 = "") {
		BotExitMenuCmd(player, args, args1);
		player = convertPlayer(player);
		local pos = BotAI.pingEntity[player];
		if(player in BotAI.pingPoint && typeof pos == "Vector") {
			BotAI.pingPoint[player].SetOrigin(pos);
			delete BotAI.pingPoint[player];
		}
	}

	//pingMenu.registerFunction("menu_exit", exit);
	pingMenu.registerFunction("ping_move", move);
	pingMenu.registerFunction("ping_use", use);
	pingMenu.registerFunction("ping_attack", attack);
	pingMenu.registerFunction("ping_stay", stay);
	pingMenu.registerFunction("ping_teleport", teleport);
	pingMenu.registerFunction("ping_follow", stay);
	pingMenu.registerFunction("ping_follow_me", follow);
	//pingMenu.registerFunction("ping_exchange", exchange);

	local testMenu = ::HoloMenu.Menu("menu_test", BUTTON_GRENADE2);
	local function test(player) {
		local navigator = BotAI.getNavigator(player);
		if(navigator.isMoving("buildTest")) {
			navigator.stop();
			return;
		}
		local traceTable = {
			start = player.EyePosition()
			end =  player.EyePosition() + player.EyeAngles().Forward().Scale(9999)
			ignore = player
			mask = g_MapScript.TRACE_MASK_SHOT
		}
		TraceLine(traceTable);

		if(traceTable.hit) {
			local function build() {
				return false;
			}

			if(BotAI.botRunPos(player, traceTable.pos, "buildTest", 0, build, 9999, true))
				DebugDrawCircle(traceTable.pos, Vector(0, 255, 0), 1.0, 50, true, 5);
		}
	}
	testMenu.registerPressEvent(test);
}

::BotMenuCmd <- function ( speaker, args  , args1) {
	if (!("VSLib" in getroottable() && "HUD" in ::VSLib)) {
		BotAI.EasyPrint("botai_no_hud");
		return;
	}

	if (typeof speaker == "VSLIB_PLAYER")
		speaker = speaker.GetBaseEntity();

	if(BotAI.MainMenu.len()>0)
		BotExitMenuCmd(speaker, "", "");
	else
		BotAI.displayOptionMenu(speaker, args, args1);
}

::BotEmptyCmd <- function ( speaker, args  , args1) {}

function BotAI::buildMenu(player, topOptions, bottomOptions) {
	// 为什么在这里要再SetLayout一次呢? 因为旧时代遗老mod Vscript Loader已经没有存在的必要了, 它的加载顺序滞后导致其他依赖Vslib的模组无法正常加载HUD, 需要有人来制裁
	HUDSetLayout( ::VSLib.HUD._hud );
	printl("bind key");
	SendToConsole("bind \"1\" \"slot1; scripted_user_func slot1\"");
	SendToConsole("bind \"2\" \"slot2; scripted_user_func slot2\"");
	SendToConsole("bind \"3\" \"slot3; scripted_user_func slot3\"");
	SendToConsole("bind \"4\" \"slot4; scripted_user_func slot4\"");
	SendToConsole("bind \"5\" \"slot5; scripted_user_func slot5\"");
	SendToConsole("bind \"6\" \"slot6; scripted_user_func slot6\"");
	SendToConsole("bind \"7\" \"slot7; scripted_user_func slot7\"");
	SendToConsole("bind \"8\" \"slot8; scripted_user_func slot8\"");
	SendToConsole("bind \"9\" \"slot9; scripted_user_func slot9\"");
	SendToConsole("bind \"0\" \"slot10; scripted_user_func slot10\"");

	BotAI.playSound(player, "buttons/button14.wav");
	BotExitMenuCmd(player, "", "");
	local menu = ::HoloMenu.KeyBindMenu();
	menu.DisplayMenu(VSLib.Player(player), g_ModeScript.HUD_MID_BOX);
	menu.SetHeight(0.33);
	local lang = BotAI.language;
	if(lang == "schinese" || lang == "tchinese")
		menu.SetWidth(0.16);
	menu.SetWidth(0.24);
	menu.SetPositionY(0.36);
	BotAI.MainMenu[BotAI.MainMenu.len()] <- menu;

	menu = ::HoloMenu.KeyBindMenu("{options}");
	topOptions(menu);
	menu.AddFlag(HUD_FLAG_NOBG);
	menu.DisplayMenu(VSLib.Player(player), g_ModeScript.HUD_LEFT_TOP);
	BotAI.MainMenu[BotAI.MainMenu.len()] <- menu;

	menu = ::HoloMenu.KeyBindMenu("\n\n\n[ {name} ]\n\n{options}", 5);
	bottomOptions(menu);
	menu.AddFlag(HUD_FLAG_NOBG);
	menu.DisplayMenu(VSLib.Player(player), g_ModeScript.HUD_LEFT_BOT);
	BotAI.MainMenu[BotAI.MainMenu.len()] <- menu;
}

function BotAI::fromParams(params, lang) {
	if(params) {
		return I18n.getTranslationKeyByLang(lang, "menu_enable");
	} else
		return I18n.getTranslationKeyByLang(lang, "menu_disable");
}

function BotAI::displayOptionMenu(player, args, args1) {
	local lang = BotAI.language;
	local function top(menu) {
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_bot_skill") + ": " + (1 + BotAI.BotCombatSkill).tostring(), BotAI.displayOptionMenuBotCombat);
		menu.AddOption(BotAI.fromParams(BotAI.NeedThrowGrenade, lang)+I18n.getTranslationKeyByLang(lang, "menu_throw"), BotThrowGrenadeCmd);
		menu.AddOption(BotAI.fromParams(BotAI.Melee, lang)+I18n.getTranslationKeyByLang(lang, "menu_take_melee"), BotMeleeCmd);
		menu.AddOption(BotAI.fromParams(BotAI.Immunity, lang)+I18n.getTranslationKeyByLang(lang, "menu_immunity"), BotImmunityCmd);
		menu.AddOption(BotAI.fromParams(BotAI.PathFinding, lang)+I18n.getTranslationKeyByLang(lang, "menu_pathfinding"), BotPathFindingCmd);
	}

	local function bot(menu) {
		menu.AddOption(BotAI.fromParams(BotAI.Unstick, lang)+I18n.getTranslationKeyByLang(lang, "menu_unstick"), BotUnstickCmd);
		menu.AddOption(BotAI.fromParams(BotAI.BackPack, lang)+I18n.getTranslationKeyByLang(lang, "menu_carry"), BotBackPackCmd);
		menu.AddOption("emp_0", BotEmptyCmd);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_next"), BotAI.displayOptionMenuNext);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_exit"), BotExitMenuCmd);
	}

	BotAI.buildMenu(player, top, bot);
}

function BotAI::displayOptionMenuNext(player, args, args1) {
	local lang = BotAI.language;
	local function top(menu) {
		menu.AddOption(BotAI.fromParams(BotAI.NeedBotAlive, lang)+I18n.getTranslationKeyByLang(lang, "menu_alive"), BotAliveCmd);
		menu.AddOption(BotAI.fromParams(BotAI.Defibrillator, lang)+I18n.getTranslationKeyByLang(lang, "menu_defibrillator"), BotDefibrillatorCmd);
		menu.AddOption(BotAI.fromParams(BotAI.NeedGasFinding, lang)+I18n.getTranslationKeyByLang(lang, "menu_find_gas"), BotGascanFindCmd);
	}

	local function bot(menu) {
		menu.AddOption("emp_=", BotEmptyCmd);
		menu.AddOption("emp_", BotEmptyCmd);
		menu.AddOption("emp_0", BotEmptyCmd);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_pre"), BotAI.displayOptionMenu);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_exit"), BotExitMenuCmd);
	}

	BotAI.buildMenu(player, top, bot);
}

function BotAI::displayOptionMenuBotCombat(player, args, args1) {
	local lang = BotAI.language;
	local function combatSkill(value) {
		local ability = [];
		ability.append(value.tostring());
		BotAISkillCmd(player, ability, "");
	}
	local function normal(player, args, args1) {
		combatSkill(1);
	}
	local function high(player, args, args1) {
		combatSkill(2);
	}
	local function ultra(player, args, args1) {
		combatSkill(3);
	}
	local function extreme(player, args, args1) {
		combatSkill(4);
	}
	local function pro(player, args, args1) {
		combatSkill(5);
	}

	local function top(menu) {
		menu.AddOption("1", normal);
		menu.AddOption("2", high);
		menu.AddOption("3", ultra);
		menu.AddOption("4", extreme);
		menu.AddOption("5", pro);
	}

	local function bot(menu) {
		menu.AddOption("emp_=", BotEmptyCmd);
		menu.AddOption("emp_", BotEmptyCmd);
		menu.AddOption("emp_0", BotEmptyCmd);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_pre"), BotAI.displayOptionMenu);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_exit"), BotExitMenuCmd);
	}

	BotAI.buildMenu(player, top, bot);
}

::BotExitMenuCmd <- function(speaker, args, args1) {
	foreach(menu in BotAI.MainMenu) {
		menu.CloseMenu();
		if (menu._autoDetach)
				menu.Detach();
	}
	BotAI.MainMenu = {};
}

function BotAI::resetBotMeleeAction() {
	local humanAmount = BotAI.SurvivorList.len() - BotAI.SurvivorBotList.len();
	local meleeAmount = humanAmount + 2;
	if(meleeAmount > BotAI.SurvivorList.len())
		meleeAmount = BotAI.SurvivorList.len();

	Convars.SetValue( "sb_max_team_melee_weapons", meleeAmount);
}

function BotAI::ResetBotFireRate() {
	BotAI.AdjustBotsUpdateRate(1);

	local combatSpeed = 500;
	local normalSpeed = 350;

	combatSpeed += BotAI.BotCombatSkill * 1000;
	normalSpeed += BotAI.BotCombatSkill * 50;

	Convars.SetValue( "sb_combat_saccade_speed", combatSpeed );
	Convars.SetValue( "sb_normal_saccade_speed", normalSpeed );
}

::NavigatorPause.fall <- function(player) {
	if(!BotAI.IsEntityValid(player)) return true;
	if(player.IsDominatedBySpecialInfected() || player.IsGettingUp() || player.IsStaggering() || player.IsIncapacitated() || player.IsHangingFromLedge()) {
		return true;
	}

	return false;
}

::NavigatorPause.useAidItem <- function(player) {
	if(!BotAI.IsEntityValid(player)) return true;
	if(player.GetActiveWeapon()) {
		local name = player.GetActiveWeapon().GetClassname();
		if(name == "weapon_first_aid_kit" || name == "weapon_defibrillator" || name == "weapon_upgradepack_explosive" || name == "weapon_upgradepack_incendiary")
			return true;
	}

	return false;
}

/*
::NavigatorPause.avoidDanger <- function(player) {
	if(!BotAI.IsEntityValid(player)) return true;
	local target = BotAI.GetTarget(player);
	if(BotAI.IsEntitySI(target) && BotAI.GetTarget(target) == player) {
		if(target.GetZombieType() != 8) {
			return true;
		} else if(BotAI.nextTickDistance(player, target) <= 200) {
			return true;
		}
	}
	local dangerous = BotAI.getBotAvoid(player);
	foreach(danger in dangerous) {
		if(BotAI.IsEntitySI(danger) && BotAI.GetTarget(danger) == player) {
			if(!BotAI.HasTank)
            	player.OverrideFriction(1, 0.7);
			if(danger.GetZombieType() != 8) {
				return true;
			} else if(BotAI.nextTickDistance(player, danger) <= 200) {
				return true;
			}
		}
	}

	return false;
}
*/

::BotAI.Sort <- function(List) {
    for (local i = 0; i < List.len(); i++) {
        local minIndex = i;
        for (local j = i; j < List.len(); j++) {
            if (List[j] < List[minIndex])
                minIndex = j;
        }
        local temp = List[minIndex];
        List[minIndex] = List[i];
        List[i] = temp;
    }

    return List;
}

function BotAI::DebugFunction( args ) {
	local leader = null;
	foreach(player in BotAI.SurvivorList) {
		if(!BotAI.IsPlayerEntityValid(player)) continue;

		if(!IsPlayerABot(player)) {
			/*
			BotAI.hookViewEntity(player, null);
			printl("player hook: " + BotAI.getViewEntity(player));
			printl("player owner: " + NetProps.GetPropEntity(player, "m_hOwnerEntity"));
			printl("player m_viewtarget: " + NetProps.GetPropEntity(player, "m_viewtarget"));
			printl("player observer: " + NetProps.GetPropEntity(player, "m_hObserverTarget"));
			*/

			if(BotAI.BotDebugMode) {
				local target = BotAI.CanSeeOtherEntityPrintName(player, 9999, 1, g_MapScript.TRACE_MASK_ALL);

				/*
								local function kill(mob) {
					local wep = player.GetActiveWeapon();
					local ename = " ";
					local dama = 300;

					if(BotAI.IsEntityValid(wep)) {
						ename = wep.GetClassname();
					}

					local isMelee = ename == "weapon_melee" || ename == "weapon_chainsaw";

					if (!isMelee) {
						BotAI.applyDamage(player, mob, dama, DMG_HEADSHOT);
					} else {
						local damagePos = BotAI.getEntityHeadPos(player);
						damagePos = Vector(damagePos.x, damagePos.y, player.EyePosition().z);
						BotAI.applyDamage(player, mob, dama, DMG_HEADSHOT, damagePos);
						//BotAI.spawnParticle("blood_impact_infected_01", mob.GetOrigin() + Vector(0, 0, 50), mob);
						//BotAI.spawnParticle("blood_melee_slash_TP_swing", mob.GetOrigin() + Vector(0, 0, 50), mob);
					}
				}
				local infected = null;
				while(infected = Entities.FindByClassnameWithin(infected, "infected", player.GetCenter(), 300)) {
					kill(infected);
				}

				local sp = null;
				while(sp = Entities.FindByClassnameWithin(sp, "player", player.GetCenter(), 300)) {
					if (BotAI.IsEntitySI(sp)) {
						kill(sp);
					}
				}

				local witch = null;
				while(witch = Entities.FindByClassnameWithin(witch, "witch", player.GetCenter(), 300)) {
					kill(witch);
				}
				*/
			}
		} else if (leader == null || GetFlowDistanceForPosition(player.GetOrigin()) > GetFlowDistanceForPosition(leader.GetOrigin())) {
			leader = player;
		}
	}

	BotAI.LeaderSurvivorBot = leader;
}

function BotAI::CheckBotPosition(args) {
	foreach(bot in BotAI.SurvivorBotList) {
		if(!(bot in BotAI.BotPosition)) {
			local pos = {};
			BotAI.BotPosition[bot] <- pos;
		}

		BotAI.BotPosition[bot][BotAI.BotPositionCycle] <- bot.GetOrigin();
	}

	if(BotAI.BotPositionCycle++ > 9)
		BotAI.BotPositionCycle = 0;
}

function BotAI::PossibleBotStuck(bot) {
	if(!(bot in BotAI.BotPosition) || BotAI.BotPosition[bot].len() < 10)
		return false;

	local total = 0;
	local pos = bot.GetOrigin();
	foreach(vec in BotAI.BotPosition[bot]) {
		total += BotAI.distanceof(vec, pos);
	}
	total = total * 0.1;

	if(total <= 70) {
		return true;
	}

	return false;
}

function BotAI::AdjustBotState(args) {
	if(BotAI.Melee) {
		BotAI.resetBotMeleeAction();
	}

	if(BotAI.Unstick) {
		Convars.SetValue( "sb_unstick", 1 );
	} else {
		Convars.SetValue( "sb_unstick", 0 );
	}

	/*
		local obstacles = {};
		NavMesh.GetObstructingEntities(obstacles);
		local areaObstacle = {};
		foreach(obstacle in obstacles) {
			local pos = obstacle.GetOrigin();
			local areaString = (pos.x / 500).tostring() + (pos.y / 500).tostring() + (pos.z / 500).tostring();
			if(!(areaString in areaObstacle))
				areaObstacle[areaString] <- {};

			local area = areaObstacle[areaString];
			area[area.len()] <- obstacle;
			areaObstacle[areaString] = area;
		}

		BotAI.obstacles = areaObstacle;
	*/

	if(!("DoorList" in BotAI))
		BotAI.DoorList <- {}
	if(!("DoorState" in BotAI))
		BotAI.DoorState <- {}

	local function addDoor(door) {
		door.ValidateScriptScope();
		local scope = door.GetScriptScope();
		local function close() {
			BotAI.DoorState[self] <- false;
		}
		local function open() {
			BotAI.DoorState[self] <- true;
		}
		scope["BotAI_Close"] <- close;
		scope["BotAI_Open"] <- open;

		door.ConnectOutput("OnClose", "BotAI_Close");
		door.ConnectOutput("OnOpen", "BotAI_Open");

		BotAI.DoorList[door] <- 0;
	}

	local door = null;
	while(door = Entities.FindByClassname(door, "func_door")) {
		if(door in BotAI.DoorList)
			continue;
		addDoor(door);
	}

	door = null;
	while(door = Entities.FindByClassname(door, "prop_door_rotating_checkpoint")) {
		if(door in BotAI.DoorList)
			continue;
		addDoor(door);
	}

	door = null;
	while(door = Entities.FindByClassname(door, "prop_door_rotating")) {
		if(door in BotAI.DoorList)
			continue;
		addDoor(door);
	}
	if(!("validArea" in BotAI)) {
		BotAI.validArea <- {};
	}
	local searchBody = false;
	foreach(player in BotAI.SurvivorBotList) {
		if(!BotAI.IsPlayerEntityValid(player)) continue;
		local navigator = BotAI.getNavigator(player);
		if(navigator.isMoving("searchBody")) {
			searchBody = true;
		}
	}

	if(searchBody) {
		Convars.SetValue( "sb_allow_leading", 0 );
	} else if (BotAI.PathFinding) {
		Convars.SetValue( "sb_allow_leading", 1 );
	}

	local maxFlowPlayer = null;
	local minFlowHuman = null;
	local maxFlow = 0;
	local minFlow = 0;

	foreach(player in BotAI.SurvivorHumanList) {
		if(BotAI.IsPlayerEntityValid(player)) {
			local lastArea = player.GetLastKnownArea();
			if(lastArea != null && !lastArea.IsValidForWanderingPopulation())
				BotAI.validArea[lastArea] <- lastArea;
			local elevator = Entities.FindByClassnameNearest("func_elevator", player.GetOrigin(), 300);
			if(BotAI.IsEntityValid(elevator)) {
				local flow = GetCurrentFlowDistanceForPlayer(player);
				foreach(bot in BotAI.SurvivorBotList) {
					local botFlow = GetCurrentFlowDistanceForPlayer(bot);
					if(BotAI.distanceof(bot.GetOrigin(), player.GetOrigin()) > 100 && (botFlow > flow || BotAI.getNavigator(bot).moving())) {
						bot.SetOrigin(player.GetOrigin());
					}
				}
			}
		}

		if(BotAI.IsPlayerEntityValid(player)) {
			local flow = GetCurrentFlowDistanceForPlayer(player);
			if(flow > maxFlow) {
				maxFlow = flow;
				maxFlowPlayer = player;
			}
			if(minFlowHuman == null || flow < minFlow) {
				minFlow = flow;
				minFlowHuman = player;
			}
		}
	}

	local needRecall = true;
	local display = null;
	while(display = Entities.FindByClassname(display, "terror_gamerules")) {
		if(BotAI.IsEntityValid(display) && NetProps.GetPropInt(display, "terror_gamerules_data.m_iScavengeTeamScore") < NetProps.GetPropInt(display, "terror_gamerules_data.m_nScavengeItemsGoal"))
			needRecall = false;
	}

	if(BotAI.UseTarget != null && BotAI.NeedGasFinding)
		needRecall = false;

	if(minFlowHuman == null) {
		minFlowHuman = BotAI.LeaderSurvivorBot;
		if(BotAI.LeaderSurvivorBot != null)
			minFlow = GetCurrentFlowDistanceForPlayer(BotAI.LeaderSurvivorBot);
	}

	if(needRecall) {
		foreach(bot in BotAI.SurvivorBotList) {
			if(!BotAI.IsPlayerEntityValid(bot) || bot.IsIncapacitated() || bot.IsHangingFromLedge() || bot.IsDominatedBySpecialInfected()) continue;
			if(BotAI.IsOnGround(bot)) {
				BotAI.DisableButton(bot, BUTTON_WALK, 2.0);
			}

			local navigator = BotAI.getNavigator(bot);
			local stuck = false;
			local idle = bot.GetSequenceName(bot.GetSequence()).tolower().find("idle") != null;

			if(BotAI.PossibleBotStuck(bot) && !idle) {
				if(!(bot in BotAI.BotStuckCount)) {
					BotAI.BotStuckCount[bot] <- 0;
				}

				BotAI.BotStuckCount[bot] = BotAI.BotStuckCount[bot] + 1;
			} else {
				BotAI.BotStuckCount[bot] <- 0;
			}

			if(!navigator.moving() || !navigator.isMoving("ping")) {
				if(BotAI.BotStuckCount[bot] >= 4) {
					stuck = true;
					navigator.stop();
				}
			}

			if (stuck) {
				BotAI.BotReset(bot);
			}
		}
	}

	if(BotAI.IsEntityValid(BotAI.UseTarget) && !BotAI.useTargetHooks) {
		BotAI.UseTarget.ValidateScriptScope();
		local scope = BotAI.UseTarget.GetScriptScope();

		local function using() {
			BotAI.useTargetUsing = true;
		}

		local function finish() {
			BotAI.useTargetUsing = false;
		}

		scope["BotAI_UseStart"] <- using;
		scope["BotAI_UseCanceled"] <- finish;
		scope["BotAI_UseFinished"] <- finish;

		BotAI.UseTarget.ConnectOutput("OnUseStarted", "BotAI_UseStart");
		BotAI.UseTarget.ConnectOutput("OnUseCanceled", "BotAI_UseCanceled");
		BotAI.UseTarget.ConnectOutput("OnUseFinished", "BotAI_UseFinished");

		BotAI.useTargetHooks = true;
	}
}

function BotAI::doNoticeText(args) {
	if(!BotAI.NoticeConfig) return;

	local settings = [
        { key = "menu_bot_skill", value = ::BotAI.BotCombatSkill + 1, enabled = true, isValue = true },
        { key = "menu_find_gas", value = "", enabled = ::BotAI.NeedGasFinding, isValue = false },
        { key = "menu_throw", value = "", enabled = ::BotAI.NeedThrowGrenade, isValue = false },
        { key = "menu_immunity", value = "", enabled = ::BotAI.Immunity, isValue = false },
        { key = "menu_pathfinding", value = "", enabled = ::BotAI.PathFinding, isValue = false },
        { key = "menu_unstick", value = "", enabled = ::BotAI.Unstick, isValue = false },
        { key = "menu_take_melee", value = "", enabled = ::BotAI.Melee, isValue = false },
        { key = "menu_defibrillator", value = "", enabled = ::BotAI.Defibrillator, isValue = false },
        { key = "menu_carry", value = "", enabled = ::BotAI.BackPack, isValue = false }
    ];

	::BotAI.EasyPrint("botai_current_settings", 0.1);

	local output = "";

    foreach (setting in settings) {
        local settingName = I18n.getTranslationKey(setting.key);

        output += "\x04[";

        if (setting.isValue) {
            output += format("\x01%s: \x05%d", settingName, setting.value);
        } else {
            if (setting.enabled) {
                output += "\x05" + I18n.getTranslationKey("menu_enable");
            } else {
                output += "\x01" + I18n.getTranslationKey("menu_disable");
            }
            output += "\x01" + settingName;
        }

        output += "\x04] ";
    }

    //output += "\n\x01" + I18n.getTranslationKey("botai_use_command_notice");

    ::BotAI.EasyPrint(output, 0.3);
	::BotAI.EasyPrint("botai_use_command_notice", 0.5);
}

function BotAI::preAITask() {
	BotAI.TaskUpdateOrderSingle = {}
	BotAI.TaskUpdateOrderGroup = 0
	BotAI.TaskOrderListSingle = {}
	BotAI.TaskOrderListGroup = {}
	BotAI.TaskSingleOrderMax = 0
	BotAI.TaskGroupOrderMax = 0

	::BotAI.AITaskList <-  {
		singleTasks = {}
		groupTasks = {}
	}
}

function BotAI::loadAITask() {
	BotAI.addTask("searchEntity", AITaskSearchEntity(0, 1.5, false, false));
	BotAI.addTask("transItem", AITaskTransItem(1, 10, false, false));
	BotAI.addTask("transKit", AITaskTransKit(1, 10, true, false));
	BotAI.addTask("heal", AITaskHeal(2, 20, false, false));
	BotAI.addTask("checkToThrowGen", AITaskCheckToThrowGen(0, 10, true, true));
	BotAI.addTask("savePlayer", AITaskSavePlayer(1, 5, true, true));
	BotAI.addTask("searchBody", AITaskSearchBody(2, 10, true, true));
	BotAI.addTask("doUpgrades", AITaskDoUpgrades(3, 10, true, true));
	BotAI.addTask("healInSafeRoom", AITaskHealInSaferoom(3, 10, true, true));
	BotAI.addTask("searchTrigger", AITaskSearchTrigger(4, 10, true, true));
	BotAI.addTask("tryTraceGascan", AITaskTryTraceGascan(5, 10, true, true));
	BotAI.addTask("tryTakeGascan", AITaskTryTakeGascan(5, 10, true, true));
}

function BotAI::postAITask() {
	BotAI.TaskOrderListSingle = BotAI.Sort(BotAI.TaskOrderListSingle);
	BotAI.TaskOrderListGroup = BotAI.Sort(BotAI.TaskOrderListGroup);

	local i = BotAI.TaskOrderListSingle.len() - 1;
	if(i in BotAI.TaskOrderListSingle)
		BotAI.TaskSingleOrderMax = BotAI.TaskOrderListSingle[i];
	i = BotAI.TaskOrderListGroup.len() - 1;
	if(i in BotAI.TaskOrderListGroup)
		BotAI.TaskGroupOrderMax = BotAI.TaskOrderListGroup[i];
}

function BotAI::resetAITask() {
	BotAI.preAITask();
	BotAI.loadAITask();
	BotAI.postAITask();
}

function resetAllBots() {
	playerSet <- null;

	while(playerSet = Entities.FindByClassname(playerSet, "player")) {
		if(BotAI.IsPlayerEntityValid(playerSet) && playerSet.IsSurvivor() && IsPlayerABot(playerSet)) {
			BotAI.BotReset(playerSet);
			printl("[Bot AI] Reset " + BotAI.getPlayerBaseName(playerSet));
		}

		if(BotAI.IsPlayerEntityValid(playerSet) && playerSet.IsSurvivor()) {
			if(BotAI.StartPos == null)
				BotAI.StartPos = playerSet.GetOrigin();
			else {
				BotAI.StartPos = BotAI.StartPos.Scale(0.5) + playerSet.GetOrigin().Scale(0.5);
			}
		}
	}

	local enumProjectile = {};
	local enumGround = {};

	enumProjectile["spitter_projectile"] <- "spitter_projectile";
	enumProjectile["prop_car_alarm"] <- "prop_car_alarm";
	enumProjectile["prop_physics"] <- "prop_physics";
	enumProjectile["prop_physics_multiplayer"] <- "prop_physics_multiplayer";

	enumGround["env_entity_igniter"] <- "env_entity_igniter"
	enumGround["entityflame"] <- "entityflame"
	enumGround["inferno"] <- "inferno"
	enumGround["insect_swarm"] <- "insect_swarm"

	foreach(projectile in enumProjectile) {
		BotAI.createProjectileTargetTimer(projectile);
	}

	foreach(ground in enumGround) {
		BotAI.createGroundTargetTimer(ground);
	}

	BotAI.loadTimers();
	BotAI.resetTaskTimers();
	BotAI.resetAITask();
	BotAI.registerMenu();
	local ladders = {};
	NavMesh.GetAllLadders(ladders);
	foreach(ladder in ladders) {
		if(ladder.IsUsableByTeam(2)) {
			BotAI.ladders[BotAI.ladders.len()] <- ladder;
			printl("[Bot AI] Found ladder at " +ladder.GetBottomOrigin());
		}
	}

	printl("[Bot AI] Loading timers...");

	printl("[Bot AI] Add Timer " + BotAI.Timers.AddTimerByName("CheckBotPosition", 0.5, true, BotAI.CheckBotPosition));
	printl("[Bot AI] Add Timer " + BotAI.Timers.AddTimerByName("AdjustBotState", 1.5, true, BotAI.AdjustBotState));
	printl("[Bot AI] Add Timer " + BotAI.Timers.AddTimerByName("TriggerHandler", 20, true, BotAI.TriggerHandler));
	printl("[Bot AI] Add Timer " + BotAI.Timers.AddTimerByName("ModifyMolotovVector", 0.1, true, BotAI.ModifyMolotovVector));
	printl("[Bot AI] Add Timer " + BotAI.Timers.AddTimerByName("DebugFunction", 0.1, true, BotAI.DebugFunction));
	BotAI.ResetBotFireRate();
	printl("[Bot AI] Add Timer " + BotAI.Timers.AddTimerByName("locateUseTarget", 0.1, true, BotAI.locateUseTarget));

	printl("[Bot AI] Timers loaded.");
}
::resetAllBots <- resetAllBots;

::BotAI.Events.OnGameEvent_round_start_post_nav <- function(event) {
	Msg("[Bot AI]	Activated\n");
	local settingList = FileToString("advanced bot ai/settings.txt");

	if ( settingList != null ) {
		printl("[Bot AI] Loading settings...");
		BotAI.LoadSettings();
	}

	if(BotAI.PathFinding) {
		Convars.SetValue( "sb_allow_leading", 1 );
		Convars.SetValue( "sb_separation_range", 2000 );
		Convars.SetValue( "sb_separation_danger_min_range", 500 );
		Convars.SetValue( "sb_separation_danger_max_range", 2000 );
		Convars.SetValue( "sb_neighbor_range", 1000 );
	} else {
		Convars.SetValue( "sb_separation_range", 100 );
		Convars.SetValue( "sb_separation_danger_min_range", 100 );
		Convars.SetValue( "sb_separation_danger_max_range", 300 );
		Convars.SetValue( "sb_allow_leading", 0 );
		Convars.SetValue( "sb_neighbor_range", 120 );
	}

	Convars.SetValue( "sb_max_team_melee_weapons", 0 );

	local function allBot(arg){
		if(BotAI.NeedBotAlive) {
			Convars.SetValue( "sb_all_bot_game", 1);
			printl("sb_all_bot_game on.");
		}
	}

	printl("[Bot AI] Add Timer " + BotAI.Timers.AddTimerByName("allBot", 2, false, allBot, {value = 1}));

	BotAI.survivorLimpHealth <- Convars.GetFloat("survivor_limp_health");
	BotAI.splatRange <- Convars.GetFloat("z_exploding_splat_radius") + 10;
	BotAI.tongueSpeed <- Convars.GetFloat("tongue_fly_speed");
	BotAI.tongueRange <- Convars.GetFloat("tongue_range");
	BotAI.language <- BotAI.getSeverLanguage();
	BotAI.reviveDistance <- Convars.GetFloat("sb_revive_friend_distance");

	Convars.SetValue( "sv_consistency", 0 );
	Convars.SetValue( "sb_melee_approach_victim", 0 );
	Convars.SetValue( "sb_allow_shoot_through_survivors", 0 );
	Convars.SetValue( "allow_all_bot_survivor_team", 1 );
	Convars.SetValue( "sb_toughness_buffer", 25 );
	Convars.SetValue( "sb_temp_health_consider_factor", 0.85 );

	Convars.SetValue( "sb_enforce_proximity_lookat_timeout", 1 );
	Convars.SetValue( "sb_enforce_proximity_range", 1000 );
	Convars.SetValue( "sb_battlestation_human_hold_time", 0.1 );
	Convars.SetValue( "sb_sidestep_for_horde", 1 );
	Convars.SetValue( "sb_close_checkpoint_door_interval", 0.15 );
	Convars.SetValue( "sb_max_battlestation_range_from_human", 150 );
	Convars.SetValue( "sb_follow_stress_factor", 0 );
	Convars.SetValue( "sb_locomotion_wait_threshold", 0.1 );
	Convars.SetValue( "sb_path_lookahead_range", 2500 );

	Convars.SetValue( "sb_use_button_range", 1000 );
	Convars.SetValue( "sb_vomit_blind_time", 0 );

	resetAllBots();

	printl("[Bot AI]	Bot AI loaded.");
}

__CollectEventCallbacks(::BotAI.Events, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);
__CollectEventCallbacks(::BotAI.Events, "OnScriptEvent_", "ScriptEventCallbacks", RegisterScriptGameEventListener);