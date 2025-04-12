Msg("[Bot AI]	Loading BotAI\n");

if (!("VSLib" in getroottable()))
{
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
	::BotAI <-
	{
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

		callCache = {}

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

		SurvivorList = {}
		SurvivorHumanList = {}
		SurvivorBotList = {}
		SpecialList = {}
		commonInfectedMap = {}
		SpecialBotList = {}
		humanBot = {}
		dangerInfected = {}
		projectileList = {}
		groundList = {}
		pingPoint = {}
		pingEntity = {}
		needOil = false

		BotPosition = {}
		healing = {}
		healingTime = {}
		botAim = {}
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

		GasFinding = {}
		BotLinkGasCan = {}
		ButtonPressed = {}

		NeedRevive = {}
		RevivedPlayer = {}

		BOT_AI_TEST_MOD = 0
		NeedGasFinding = true
		NeedThrowGrenade = true
		Immunity = true
		ESCORT = true
		UNSTICK = true
		MELEE = true
		Versus_Mode = false
		Server_Mode = false
		ABA_Admins = {}
		Notice_Text = true
		NeedBotAlive = true
		BackPack = true
	}

	::BotAI.AITaskList <-
	{
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
	"BOT_AI_TEST_MOD = " + BotAI.BOT_AI_TEST_MOD.tostring() +
	"\nNeedGasFinding = " + BotAI.NeedGasFinding.tostring() +
	"\nNeedThrowGrenade = " + BotAI.NeedThrowGrenade.tostring() +
	"\nImmunity = " + BotAI.Immunity.tostring() + "\nESCORT = " +
	BotAI.ESCORT.tostring() + "\nUNSTICK = " + BotAI.UNSTICK.tostring() +
	"\nVersus_Mode = " + BotAI.Versus_Mode.tostring() +
	"\nServer_Mode = " + BotAI.Server_Mode.tostring() +
	"\nMELEE = " + BotAI.MELEE.tostring() +
	"\nNotice_Text = " + BotAI.Notice_Text.tostring() +
	"\nNeedBotAlive = " + BotAI.NeedBotAlive.tostring() +
	"\nBackPack = " + BotAI.BackPack.tostring();

	printl("[Bot AI] Save settings...");
	StringToFile("advanced bot ai/settings.txt", settingList);
}

::BotAI.LoadSettings <- function ()
{
	local fileContents = FileToString("advanced bot ai/settings.txt");
	local settings = split(fileContents, "\r\n");

	foreach (setting in settings)
	{
		if ( setting.find("//") != null )
		{
			setting = BotAI.StringReplace(setting, "//" + ".*", "");
			setting = rstrip(setting);
		}
		if ( setting != "" )
		{
			setting = BotAI.StringReplace(setting, "=", "<-");
			local compiledscript = compilestring("BotAI." + setting);
			compiledscript();
		}
	}

	local admins_fileContents = FileToString("advanced bot ai/admins.txt");
	local admins = split(admins_fileContents, "\r\n");

	foreach (admin in admins)
	{
		if ( admin.find("//") != null )
		{
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
	if(fileContents != null)
	{
		local usetargetsOri = split(fileContents, "\r\n");

	foreach (usetarget in usetargetsOri)
	{
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
	if(fileContents != null)
	{
	local usetargetsVec = split(fileContents, "\r\n");

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

::ABA_IsAdmin <- function ( player )
{
	if (typeof player == "VSLIB_PLAYER")
		player = player.GetBaseEntity();

	if (Director.IsSinglePlayerGame() || GetListenServerHost() == player || !BotAI.Server_Mode)
		return true;

	local steamid = player.GetNetworkIDString();

	if (!steamid) return false;

	if ( !(steamid in BotAI.ABA_Admins) )
	{
		BotAI.EasyPrint("botai_admin_only");
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

class ::BotProperty
{
	constructor()
    {
    }

	target = null;
	shove_target = null;
	hand_held = null;
	dedgeVector = null;
	smokerTarget = null;
	avoidList = {};
	taskLock = 0;
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
	}
	else {
		BotAI.AITaskList.groupTasks[name] <- task;

		if(!(task.getOrder() in BotAI.TaskOrderListGroup))
			BotAI.TaskOrderListGroup[BotAI.TaskOrderListGroup.len()] <- task.getOrder();
	}
}

function BotAI::updateAITasks() {
	BotAI.taskThinkTimerTick++;
	if(!BotAI.doTaskUpdate)
		return;
	if(BotAI.taskThinkTimerTick % 2 == 0) {
		return;
	} else {
		BotAI.tickExisted++;
		BotAI.AdjustBotsUpdateRate(1);
	}
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

function BotAI::taskHandler(player, tasks, order, orderTable)
{
	local AITaskUpdateList = {};
	local queueOver = true;

	foreach(idx, task in tasks) {
		local shouldTick = task.shouldTick(player) && !(idx in BotAI.disabledTask);
		if(shouldTick)
			task.setLastTickTime(player, BotAI.tickExisted + task.tick);

		if((task.getOrder() == order || task.isForce())) {
			if(shouldTick && (task.isUpdating(player) || task.shouldUpdate(player)) && (queueOver || task.isCompatible())) {
				if(task.getOrder() == order && !task.isForce())
					queueOver = false;
				AITaskUpdateList[idx] <- task;
			}
		}
		else
			task.taskReset(player);
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
		}
		else {
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
		local nearestDis = 800;

		while (entT = Entities.FindByModel(entT, "models/infected/hulk.mdl")) {
			if(!entT.IsValid() || !BotAI.IsAlive(entT) || BotAI.IsOnFire(entT) || !BotAI.CanHitOtherEntity(molotov, entT)) continue;

			local distance = BotAI.distanceof(molotov.GetOrigin(), entT.GetOrigin());
			if (distance < nearestDis) {
				nearestDis = distance;
				nearest = entT;
			}
		}

		if(BotAI.IsEntitySI(nearest)){
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

		if(throwable)
			throwable.ValidateScriptScope();
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
		if(BotAI.IsEntitySI(nearest)){
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

			if(BotAI.BOT_AI_TEST_MOD >= 2 && IsPlayerABot(playerSet) && (playerSet.GetHealth() + playerSet.GetHealthBuffer()) < 40 && !playerSet.IsAdrenalineActive())
				playerSet.UseAdrenaline(20);

			if(IsPlayerABot(playerSet) || playerSet in BotAI.humanBot) {
				local area = playerSet.GetLastKnownArea();
				if(BotAI.BOT_AI_TEST_MOD == 1 && area) {
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
					} else if (area.IsDegenerate()) {
						r = 0;
						g = 0;
						b = 0;
					}
					area.DebugDrawFilled(r, g, b, 15, 0.2, true);
				}
				if(BotAI.IsHumanSpectating(playerSet))
					NetProps.SetPropInt(playerSet, "m_hViewEntity", -1);

				if(BotAI.BOT_AI_TEST_MOD == 2 || HasTank)
					playerSet.OverrideFriction(1, 0.6);

				//bug Fix
				//1.
				local weapon = playerSet.GetActiveWeapon();
				if(weapon && weapon.GetClassname() == "weapon_first_aid_kit") {
					if(BotAI.IsPressingAttack(playerSet))
						BotAI.ForceButton(playerSet, 1, 1);
					if(BotAI.IsBotHealing(playerSet))
						BotAI.ForceButton(playerSet, 2048, 1);
				}

				//2.
				local t = BotAI.getBotTarget(playerSet);
				//printl("[Bot AI] " + BotAI.getPlayerBaseName(playerSet) + " " + t);
				if(weapon && BotAI.IsEntitySurvivor(t) && (weapon.GetClassname() != "weapon_first_aid_kit" && weapon.GetClassname() != "weapon_pain_pills" && weapon.GetClassname() != "weapon_adrenaline")) {
					BotAI.DisableButton(playerSet, 2048, 1);
				}
			}
		}
	}

	foreach(smoker in BotAI.SpecialList) {
		if(BotAI.IsPlayerEntityValid(smoker) && smoker.GetEntityIndex() in BotAI.smokerTongue) {
			BotAI.smokerTongue[smoker.GetEntityIndex()] <- BotAI.smokerTongue[smoker.GetEntityIndex()] + 1;
		}
	}

	foreach(idx, pro in BotAI.projectileList) {
		if(!BotAI.IsEntityValid(pro))
			delete BotAI.projectileList[idx];
		else if(BotAI.GetEntitySpeedVector(pro) <= 10 && BotAI.GetEntitySpeedLocalVector(pro) <= 10 && !(pro.GetEntityIndex() in BotAI.ListAvoidCar))
			delete BotAI.projectileList[idx];
	}

	foreach(idx, pro in BotAI.groundList) {
		if(!BotAI.IsEntityValid(pro))
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

	if(Director.IsAnySurvivorInStartArea()) {
		local function leave() {
			return !Director.IsAnySurvivorInStartArea();
		}
		foreach(human in BotAI.SurvivorHumanList) {
			if(BotAI.IsAlive(human)) {
				foreach(bot in BotAI.SurvivorBotList) {
					BotAI.botRunPos(bot, human, "staySafeRoom", 3, leave);
				}
			}
		}
	}
}

function BotAI::printTables(table) {
	foreach(key, value in table) {
		if(typeof value == "table")
			BotAI.printTables(value);
		else
			printl("[Debug Print] " + key + " : " + value);
	}
}

::BotAI.GiveUpPlayer <- function(flag)
{
	/*if(BotAI.HasTank && BotAI.playerFallDown > 0 && flag && BotAI.sb_battlestation_give_up_range_from_human == 0){
		local i = Convars.GetFloat("sb_battlestation_give_up_range_from_human");
		i = i.tointeger();

		BotAI.sb_battlestation_give_up_range_from_human = i;
		Convars.SetValue( "sb_battlestation_give_up_range_from_human", 350 );

		i = Convars.GetFloat("sb_max_battlestation_range_from_human");
		i = i.tointeger();

		BotAI.sb_max_battlestation_range_from_human = i;
		Convars.SetValue( "sb_max_battlestation_range_from_human", 200 );
	}
	else if(BotAI.sb_battlestation_give_up_range_from_human > 0){
		Convars.SetValue( "sb_battlestation_give_up_range_from_human", BotAI.sb_battlestation_give_up_range_from_human );
		BotAI.sb_battlestation_give_up_range_from_human = 0;

		Convars.SetValue( "sb_max_battlestation_range_from_human", BotAI.sb_max_battlestation_range_from_human );
		BotAI.sb_max_battlestation_range_from_human = 0;
	}*/
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

		if(notBotPlayerBoolean)
		{
			playerSet <- null;

			while(playerSet = Entities.FindByClassname(playerSet, "player"))
			{
				if(BotAI.IsPlayerEntityValid(playerSet) && playerSet.IsSurvivor() && IsPlayerABot(playerSet))
				{
					target <- null;
					while (target = Entities.FindByClassnameWithin(target, "point_prop_use_target", playerSet.GetOrigin() + Vector(0, 0, 40), 300)) {
						if(NetProps.GetPropInt(target, "m_spawnflags") == 1)
						{
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

::BotFractureRayCmd <- function ( speaker, args , args1)
{
	if(!ABA_IsAdmin(speaker))
		return;

	if(BotAI.BOT_AI_TEST_MOD >= 1)
	{
		BotAI.BOT_AI_TEST_MOD = 0;
		BotAI.EasyPrint("botai_fullpower_off");
		BotAI.ResetBotFireRate();
	}
	else
	{
		BotAI.BOT_AI_TEST_MOD = 2;
		BotAI.EasyPrint("botai_fullpower_on");
		BotAI.ResetBotFireRate();
	}
}

::MoreBotCmd <- function ( player, args , args1)
{
	BotAI.EasyPrint("botai_no_more_bot");
}

::BotStopCmd <- function ( speaker, args , args1)
{
	notBotPlayer <- null;
	while(notBotPlayer = Entities.FindByClassname(notBotPlayer, "player"))
	{
		if(BotAI.IsPlayerEntityValid(notBotPlayer) && notBotPlayer.IsSurvivor() && !IsPlayerABot(notBotPlayer) && NetProps.GetPropInt(notBotPlayer, "m_iTeamNum") != 1 && !notBotPlayer.IsDead())
		{
			return;
		}
	}

	player <- null;
	while(player = Entities.FindByClassname(player, "player")) {
		if(BotAI.IsPlayerEntityValid(player) && player.IsSurvivor() && IsPlayerABot(player)) {
			BotAI.setLastStrike(player);
			player.SetHealth(-100);
			player.TakeDamage(100, 0, player);
			DropSpit(player.GetOrigin());
		}
	}
}

::BotAITestCmd <- function ( speaker, args , args1)
{
	if(!ABA_IsAdmin(speaker))
		return;

	if(args.len() >= 1 && args[0] != null && args[0] != "")
	{
		local arg = args[0].tointeger();
		if(arg >='0' && arg<='9')
		{
			BotAI.BOT_AI_TEST_MOD = arg;
		}
	} else {
		if(BotAI.BOT_AI_TEST_MOD > 0)
			BotAI.BOT_AI_TEST_MOD = 0;
		else
			BotAI.BOT_AI_TEST_MOD = 1;
	}
}

::BotGascanFindCmd <- function ( speaker, args  , args1)
{
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
}

::BotThrowGrenadeCmd <- function ( speaker, args  , args1)
{
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
}

::BotImmunityCmd <- function ( speaker, args  , args1)
{
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
}

::BotVersusModCmd <- function ( speaker, args  , args1)
{
	if(!ABA_IsAdmin(speaker))
		return;

	if(BotAI.Versus_Mode)
	{
		BotAI.Versus_Mode = false;
		BotAI.EasyPrint("botai_balance_mode_off");
		BotAI.ResetBotFireRate();
	}
	else
	{
		BotAI.Versus_Mode = true;
		BotAI.EasyPrint("botai_balance_mode_on");
		BotAI.ResetBotFireRate();
	}
}

::BotBackPackCmd <- function ( speaker, args  , args1) {
	if(BotAI.BackPack) {
		BotAI.BackPack = false;
		BotAI.EasyPrint("botai_bot_carry_off");
	}
	else {
		BotAI.BackPack = true;
		BotAI.EasyPrint("botai_bot_carry_on");
	}
}

::BotAliveCmd <- function ( speaker, args  , args1) {
	if(BotAI.NeedBotAlive) {
		BotAI.NeedBotAlive = false;
		Convars.SetValue( "sb_all_bot_game", 0);
		Convars.SetValue( "allow_all_bot_survivor_team", 0 );
		BotAI.EasyPrint("botai_bot_alive_off");
	}
	else {
		BotAI.NeedBotAlive = true;
		Convars.SetValue( "sb_all_bot_game", 1);
		Convars.SetValue( "allow_all_bot_survivor_team", 1 );
		BotAI.EasyPrint("botai_bot_alive_on");
	}
}

::BotPathFindingCmd <- function ( speaker, args , args1)
{
	if(BotAI.ESCORT)
	{
		BotAI.ESCORT = false;
		Convars.SetValue( "sb_separation_range", 1000 );
		Convars.SetValue( "sb_separation_danger_min_range", 1000 );
		Convars.SetValue( "sb_separation_danger_max_range", 1500 );
		Convars.SetValue( "sb_allow_leading", 1 );
		BotAI.EasyPrint("botai_path_finding_on");
	}
	else
	{
		BotAI.ESCORT = true;
		Convars.SetValue( "sb_allow_leading", 0 );
		Convars.SetValue( "sb_separation_range", 100 );
		Convars.SetValue( "sb_separation_danger_min_range", 100 );
		Convars.SetValue( "sb_separation_danger_max_range", 300 );
		BotAI.EasyPrint("botai_path_finding_off");
	}
}

::BotUnstickCmd <- function ( speaker, args , args1)
{
	if(BotAI.UNSTICK)
	{
		BotAI.UNSTICK = false;
		Convars.SetValue( "sb_unstick", 0 );
		BotAI.EasyPrint("botai_unstick_off");
	}
	else
	{
		BotAI.UNSTICK = true;
		Convars.SetValue( "sb_unstick", 1 );
		BotAI.EasyPrint("botai_unstick_on");
	}
}

::BotMeleeCmd <- function ( speaker, args , args1)
{
	if(BotAI.MELEE)
	{
		BotAI.MELEE = false;
		Convars.SetValue( "sb_max_team_melee_weapons", 0 );
		BotAI.EasyPrint("botai_melee_off");
	}
	else
	{
		BotAI.MELEE = true;
		BotAI.resetBotMeleeAction();
		BotAI.EasyPrint("botai_melee_on");
	}
}

::BotAI.EasyPrint <- function (str, time = 0.2) {
	local function cPrint(s) {
		ClientPrint(null, 5, "Advanced Bot AI: " + "\x01" + I18n.getTranslationKey(s));
	}

	::BotAI.Timers.AddTimer(time, false, cPrint, str);
}

::BotABCDECmd <- function ( speaker, args  , args1)
{
}

function BotAI::registerMenu() {
	local botMenu = ::HoloMenu.Menu("menu_title", BUTTON_GRENADE1);
	local function showMenu(player) {
		if(botMenu.showing(player))
			botMenu.close(player);
		else
			botMenu.show(player);
	}
	local function findGas(player) {
		BotGascanFindCmd(player, null, null);
		botMenu.close(player);
	}
	local function grenade(player) {
		BotThrowGrenadeCmd(player, null, null);
		botMenu.close(player);
	}
	local function melee(player) {
		BotMeleeCmd(player, null, null);
		botMenu.close(player);
	}
	local function immunity(player) {
		BotImmunityCmd(player, null, null);
		botMenu.close(player);
	}
	local function path(player) {
		BotPathFindingCmd(player, null, null);
		botMenu.close(player);
	}
	local function unstick(player) {
		BotUnstickCmd(player, null, null);
		botMenu.close(player);
	}
	local function versus(player) {
		BotVersusModCmd(player, null, null);
		botMenu.close(player);
	}
	local function fractureRay(player) {
		BotFractureRayCmd(player, null, null);
		botMenu.close(player);
	}
	local function backPack(player) {
		BotBackPackCmd(player, null, null);
		botMenu.close(player);
	}
	local function botAlive(player) {
		BotAliveCmd(player, null, null);
		botMenu.close(player);
	}

	botMenu.registerPressEvent(showMenu);
	botMenu.registerFunction("menu_find_gas", findGas);
	botMenu.registerFunction("menu_throw", grenade);
	botMenu.registerFunction("menu_take_melee", melee);
	botMenu.registerFunction("menu_immunity", immunity);
	botMenu.registerFunction("menu_follow", path);
	botMenu.registerFunction("menu_unstick", unstick);
	botMenu.registerFunction("menu_follow", path);
	botMenu.registerFunction("menu_carry", backPack);
	botMenu.registerFunction("menu_alive", botAlive);
	botMenu.registerFunction("menu_balance", versus);
	botMenu.registerFunction("menu_fullpower", fractureRay);

	local pingMenu = ::HoloMenu.Menu("ping_menu", BUTTON_ALT2);
	local function openMenu(player) {
		pingMenu.close(player);
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
		pingMenu.show(player);
	}
	local function ping(player) {
		if(pingMenu.showing(player)) return;
		local point = BotAI.CanSeeOtherEntityPrintName(player, 9999, 0, g_MapScript.TRACE_MASK_ALL);
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

		local traceTable = {
			start = player.EyePosition()
			end =  player.EyePosition() + player.EyeAngles().Forward().Scale(9999)
			ignore = player
			mask = g_MapScript.TRACE_MASK_ALL
		}
		TraceLine(traceTable);

		if(traceTable.hit) {
			if(traceTable.enthit != null && traceTable.enthit.GetClassname() != "worldspawn" && traceTable.enthit.IsValid()) {
				local entity = traceTable.enthit;
				local name = entity.GetClassname();
				if(name == "player") {
					if(entity.IsSurvivor()) {
						if(BotAI.botStayPos(BotAI.pingPoint[player], traceTable.pos, "ping", 4, 9999))
							delete BotAI.pingPoint[player];
					} else {
						BotAI.targetLocked[BotAI.pingPoint[player]] <- entity;
						delete BotAI.pingPoint[player];
					}
				}

				if(name.find("weapon") || name.find("button") || name.find("trigger")) {
					local bot = BotAI.pingPoint[player];
					local function changeAndUse() {
						if(!BotAI.IsAlive(bot)) return true;
						local navigator = BotAI.getNavigator(bot);
						if(!navigator.isMoving("ping"))
							return true;
						if(BotAI.distanceof(entity.GetOrigin(), bot.GetOrigin()) <= 100) {
							DoEntFire("!self", "Use", "", 0, bot, entity);
							return true;
						}
						return false;
					}
					if(BotAI.botRunPos(BotAI.pingPoint[player], entity, "ping", 4, changeAndUse))
						delete BotAI.pingPoint[player];
				}

				if(name == "infected" || name == "witch") {
					BotAI.targetLocked[BotAI.pingPoint[player]] <- entity;
					delete BotAI.pingPoint[player];
				}
			} else {
				printl(traceTable.pos);
				if(BotAI.botStayPos(BotAI.pingPoint[player], traceTable.pos, "ping", 4, 3))
					delete BotAI.pingPoint[player];
			}
		}
	}
	local function filterIcon(player, functionsIn) {
		local entity = BotAI.pingEntity[player];
		local functions = {}

		if(typeof entity == "Vector") {
			foreach(idx, func in functionsIn) {
				if(idx == "ping_move" || idx == "ping_stay" || idx == "ping_follow_me")
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
		functions["menu_exit"] <- functionsIn["menu_exit"]

		return functions;
	}
	pingMenu.registerTickEvent(30, openMenu);
	pingMenu.registerPressEvent(ping);
	HoloMenu.IconHook("ping_menu", filterIcon);
	local function exit(player) {
		pingMenu.close(player);
	}
	local function move(player) {
		local entity  = BotAI.pingEntity[player];
		if(BotAI.botStayPos(BotAI.pingPoint[player], entity, "ping", 4, 3))
			delete BotAI.pingPoint[player];
		pingMenu.close(player);
	}
	local function use(player) {
		local entity  = BotAI.pingEntity[player];
		local bot = BotAI.pingPoint[player];
		local function changeAndUse() {
			if(!BotAI.IsAlive(bot)) return true;
			local navigator = BotAI.getNavigator(bot);
			if(!navigator.isMoving("ping"))
				return true;
			if(BotAI.distanceof(entity.GetOrigin(), bot.GetOrigin()) <= 100) {
				DoEntFire("!self", "Use", "", 0, bot, entity);
				return true;
			}
			return false;
		}
		if(BotAI.botRunPos(BotAI.pingPoint[player], entity, "ping", 4, changeAndUse))
			delete BotAI.pingPoint[player];
		pingMenu.close(player);
	}
	local function attack(player) {
		local entity = BotAI.pingEntity[player];
		local old = null;
		if(BotAI.pingPoint[player] in BotAI.targetLocked)
			old = BotAI.targetLocked[BotAI.pingPoint[player]];
		if(old == entity)
			delete BotAI.targetLocked[BotAI.pingPoint[player]];
		else
			BotAI.targetLocked[BotAI.pingPoint[player]] <- entity;
		delete BotAI.pingPoint[player];
		pingMenu.close(player);
	}
	local function stay(player) {
		local entity  = BotAI.pingEntity[player];
		if(BotAI.botStayPos(BotAI.pingPoint[player], entity, "ping", 4, 9999))
			delete BotAI.pingPoint[player];
		pingMenu.close(player);
	}
	local function follow(player) {
		if(BotAI.botStayPos(BotAI.pingPoint[player], player, "ping", 4, 9999))
			delete BotAI.pingPoint[player];
		pingMenu.close(player);
	}
	local function exchange(player) {

		pingMenu.close(player);
	}
	pingMenu.registerFunction("menu_exit", exit);
	pingMenu.registerFunction("ping_move", move);
	pingMenu.registerFunction("ping_use", use);
	pingMenu.registerFunction("ping_attack", attack);
	pingMenu.registerFunction("ping_stay", stay);
	pingMenu.registerFunction("ping_follow", stay);
	pingMenu.registerFunction("ping_follow_me", follow);
	//pingMenu.registerFunction("ping_exchange", exchange);

	local testMenu = ::HoloMenu.Menu("menu_test", BUTTON_GRENADE2);
	local function test(player) {
		local traceTable = {
			start = player.EyePosition()
			end =  player.EyePosition() + player.EyeAngles().Forward().Scale(9999)
			ignore = player
			mask = g_MapScript.TRACE_MASK_SHOT
		}
		TraceLine(traceTable);

		if(traceTable.hit) {
			DebugDrawCircle(traceTable.pos, Vector(0, 255, 0), 1.0, 50, true, 10);
			local navigator = BotAI.getNavigator(player);
			local paths = {};
			if(!("testPath" in BotAI))
				navigator.createPath(traceTable.pos, null, paths);
			else if(typeof BotAI.testPath == "table") {
            	local newPaths = [];
            	for(local i = 0; i < BotAI.testPath.len(); ++i) {
               		newPaths.append(BotAI.testPath["area" + i.tostring()]);
            	}
            	navigator.createPath(traceTable.pos, null, paths, newPaths);
				foreach(idx, path in paths) {
					path.DebugDrawFilled(0, 255, 0, 50, 10, true);
					DebugDrawText(path.GetCenter(), idx.tostring(), true, 10);
				}
        	}

			BotAI.testPath <- paths;
		}
	}
	testMenu.registerPressEvent(test);
}

::BotMenuCmd <- function ( speaker, args  , args1)
{
	if (!("VSLib" in getroottable() && "HUD" in ::VSLib)) {
		BotAI.EasyPrint("botai_no_hud");
		return;
	}

	if (typeof speaker == "VSLIB_PLAYER")
		speaker = speaker.GetBaseEntity();

	local isdead = NetProps.GetPropInt(speaker, "m_iTeamNum") == 1;
	if(isdead || !BotAI.IsAlive(speaker)) return;
	local menu = ::HoloMenu.menu["menu_title"];
	if(menu.showing(speaker))
		menu.close(speaker);
	else
		menu.show(speaker);
	/*
	local lang = BotAI.language;
	local menu = ::VSLib.HUD.MenuScrollable();

	menu.SetTitle(I18n.getTranslationKeyByLang(lang, "menu_title"));
	menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_find_gas"), BotGascanFindCmd);
	menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_throw"), BotThrowGrenadeCmd);
	menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_take_melee"), BotMeleeCmd);
	menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_immunity"), BotImmunityCmd);
	menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_follow"), BotPathFindingCmd);
	menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_unstick"), BotUnstickCmd);
	menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_balance"), BotVersusModCmd);
	menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_fullpower"), BotFractureRayCmd);
	menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_exit"), BotABCDECmd);
	menu.DisplayMenu(VSLib.Player(speaker), 0);
	*/
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
	if(BotAI.BOT_AI_TEST_MOD >= 2) {
		if(BotAI.Versus_Mode) {
			Convars.SetValue( "sb_combat_saccade_speed", 3000 );
			Convars.SetValue( "sb_normal_saccade_speed", 750 );
		}
		else {
			Convars.SetValue( "sb_combat_saccade_speed", 9999 );
			Convars.SetValue( "sb_normal_saccade_speed", 9999 );
		}
	}
	else {
		//Convars.SetValue( "think_limit", 10 );
		if(BotAI.Versus_Mode) {
			Convars.SetValue( "sb_combat_saccade_speed", 1000 );
			Convars.SetValue( "sb_normal_saccade_speed", 350 );
		}
		else {
			Convars.SetValue( "sb_combat_saccade_speed", 5000 );
			Convars.SetValue( "sb_normal_saccade_speed", 2000 );
		}
	}
}

::NavigatorPause.fall <- function(player) {
	if(!BotAI.IsEntityValid(player)) return true;
	if(player.IsDominatedBySpecialInfected() || player.IsGettingUp() || player.IsStaggering() || player.IsIncapacitated() || player.IsHangingFromLedge()) {
		return true;
	}

	return false;
}

::NavigatorPause.frozen <- function(player) {
	if(!BotAI.IsEntityValid(player)) return true;
	if(BotAI.HasFlag(player, FL_FROZEN)) return true;

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

::NavigatorPause.avoidDanger <- function(player) {
	if(!BotAI.IsEntityValid(player)) return true;
	local target = BotAI.GetTarget(player);
	if(BotAI.IsEntitySI(target)) {
		if(target.GetZombieType() != 8)
			return true;
		else if(BotAI.nextTickDistance(player, target) <= 250)
			return true;
	}
	local dangerous = BotAI.getBotAvoid(player);
	foreach(danger in dangerous) {
		if(BotAI.IsEntitySI(danger)) {
			if(BotAI.BOT_AI_TEST_MOD != 2 && !BotAI.HasTank)
            	player.OverrideFriction(1, 0.7);
			return true;
		}
	}

	return false;
}

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
	if(BotAI.BOT_AI_TEST_MOD == 1) {
		foreach(bot, pos in BotAI.moveDebug) {
			if(pos) {
				DebugDrawCircle(pos, Vector(255, 255, 0), 0.2, 50, true, 0.2);
				DebugDrawText(pos, BotAI.getPlayerBaseName(bot) + " is gonna to here", false, 0.2);
			}
		}
	}

	foreach(player in BotAI.SurvivorList) {
		if(!BotAI.IsPlayerEntityValid(player)) continue;

		if(!IsPlayerABot(player)) {
			if(BotAI.BOT_AI_TEST_MOD == 1) {
				BotAI.CanSeeOtherEntityPrintName(player, 9999, 1, g_MapScript.TRACE_MASK_ALL);
			}
		}

		/*
		if(player.IsSurvivor() && !IsPlayerABot(player) && !player.IsDead())
		{
			bot <- BotAI.CanSeeOtherEntityPrintName(player, 9999, 0);

			if(BotAI.IsPlayerEntityValid(bot) && bot.IsSurvivor() && IsPlayerABot(bot) && !bot.IsDead()) {
				if(BotAI.distanceof(bot.GetOrigin(), player.GetOrigin()) < 175 && BotAI.IsPressingDuck(player) && BotAI.IsPressingJump(player) && BotAI.IsPressingShove(player)) {
					bot.SetOrigin(player.GetOrigin());
					if(!bot.IsIncapacitated() && !bot.IsHangingFromLedge()) {
						heal <- bot.GetHealth();
						temp <- bot.GetHealthBuffer();
						count <- NetProps.GetPropInt(bot, "m_currentReviveCount");
						bot.SetHealth(-100);
						bot.TakeDamage(100, 0, null);
						bot.ReviveFromIncap();
						bot.SetHealth(heal);
						bot.SetHealthBuffer(temp);
						NetProps.SetPropInt(bot, "m_currentReviveCount", count);
						DoEntFire("!self", "CancelCurrentScene", "", 0, null, bot);
					}
					BotAI.BotReset(bot);
					Msg("[Bot AI] Reset " + BotAI.getPlayerBaseName(bot) + "\n");
				}
				else if(BotAI.distanceof(bot.GetOrigin(), player.GetOrigin()) < 175 && BotAI.IsPressingShove(player)) {
					BotAI.BotReset(bot);
					Msg("[Bot AI] Reset " + BotAI.getPlayerBaseName(bot) + "\n");
				}
			}
		}
		*/
	}
}

function BotAI::AdjustBotState(args) {
	if(BotAI.MELEE)
		BotAI.resetBotMeleeAction();

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

	foreach(player in BotAI.SurvivorBotList) {
		if(!BotAI.IsPlayerEntityValid(player)) continue;
		/*if(BotAI.IsBotGasFinding(player)) {
			if(player in BotAI.BotPosition && BotAI.distanceof(BotAI.BotPosition[player], player.GetOrigin()) <= 10
			&& !BotAI.IsPressingAttack(player) && !BotAI.IsPressingUse(player) && !BotAI.IsPressingShove(player) && !BotAI.IsPressingReload(player)
			&& !BotAI.IsPlayerClimb(player) && !BotAI.IsBotHealing(player))
					BotAI.BotReset(player);
		}*/

		BotAI.BotPosition[player] <- player.GetOrigin();
		/*
		local navigator = BotAI.getNavigator(player);
		local botLastArea = player.GetLastKnownArea();

		if(botLastArea != null && !navigator.moving() && !botLastArea.IsValidForWanderingPopulation() && !(botLastArea in BotAI.validArea)) {
			local areas = {};
			NavMesh.GetNavAreasInRadius(player.GetOrigin(), 500, areas);
			local safeArea = null;
			foreach(area in areas) {
				if(!area.IsDamaging() && area.IsValidForWanderingPopulation() && (safeArea == null || BotAI.distanceof(player.GetOrigin(), safeArea.GetCenter()) > BotAI.distanceof(player.GetOrigin(), area.GetCenter()))) {
					safeArea = area;
				}
			}
			if(safeArea != null)
				player.SetOrigin(safeArea.GetCenter());
        }
		*/
	}
	local maxFlowPlayer = null;
	local maxFlow = 0;

	foreach(player in BotAI.SurvivorList) {
		if(BotAI.IsPlayerEntityValid(player) && !IsPlayerABot(player)) {
			local lastArea = player.GetLastKnownArea();
			if(lastArea != null && !lastArea.IsValidForWanderingPopulation())
				BotAI.validArea[lastArea] <- lastArea;
			local elevator = Entities.FindByClassnameNearest("func_elevator", player.GetOrigin(), 300);
			if(BotAI.IsEntityValid(elevator)) {
				local flow = GetCurrentFlowDistanceForPlayer(player);
				foreach(bot in BotAI.SurvivorBotList) {
					local botFlow = GetCurrentFlowDistanceForPlayer(bot);
					if(BotAI.distanceof(bot.GetOrigin(), player.GetOrigin()) > 300 && botFlow > flow || (player in BotAI.BotPosition && BotAI.distanceof(BotAI.BotPosition[player], player.GetOrigin()) < 10)) {
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

	if(maxFlowPlayer && needRecall)
	foreach(bot in BotAI.SurvivorBotList) {
		if(!BotAI.IsPlayerEntityValid(bot) || bot.IsIncapacitated() || bot.IsHangingFromLedge() || bot.IsDominatedBySpecialInfected()) continue;
		local navigator = BotAI.getNavigator(bot);
		if(typeof navigator.movingID == "string" && navigator.moving()) continue;
		local lastPlayer = null;
		local lastFlow = maxFlow;
		local myFlow = GetCurrentFlowDistanceForPlayer(bot);

		/*
		if(!BotAI.ESCORT && myFlow < maxFlow && !IsPlayerABot(maxFlowPlayer)) {
			local function condition() {
				if(!BotAI.IsEntitySurvivor(bot) || !BotAI.IsEntitySurvivor(maxFlowPlayer)) return true;
				return GetCurrentFlowDistanceForPlayer(bot) > GetCurrentFlowDistanceForPlayer(maxFlowPlayer);
			}
			BotAI.getNavigator(bot).clearPath("leader");
			BotAI.botRunPos(bot, maxFlowPlayer, "leader", 0, condition);
		}
		*/
		if(myFlow < maxFlow && BotAI.distanceof(bot.GetOrigin(), maxFlowPlayer.GetOrigin()) >= 2500) {
			foreach(player in BotAI.SurvivorList) {
				local flow = GetCurrentFlowDistanceForPlayer(player);
				if(flow > myFlow && flow <= lastFlow) {
					lastPlayer = player;
					lastFlow = flow;
				}
			}

			if(BotAI.IsPlayerEntityValid(lastPlayer))
				bot.SetOrigin(lastPlayer.GetOrigin());
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

function BotAI::NoticeText(args) {
	if(!BotAI.Notice_Text) return;
	local lang = BotAI.language;
	if(lang == "schinese" || lang == "tchinese")
		BotAI.EasyPrint("通告： 希望每位朋友都能认真看一遍创意工坊的使用说明，学习一番开启或关闭某项功能的指令的用！这条通告可以使用指令!botnotice来关闭。");
}

/*
function Update() {
	foreach(name, value in BotAI.debugCallCount) {
		printl("Method " + name + " called " + value + " times.");
		if(name in BotAI.debugCallCountTotal)
			BotAI.debugCallCountTotal[name] = BotAI.debugCallCountTotal[name] + value;
		else
			BotAI.debugCallCountTotal[name] <- value;
	}

	BotAI.debugCallCount = {};
}
*/

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
	BotAI.addTask("searchEntity", AITaskSearchEntity(0, 2, false, false));
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
	enumProjectile["tank_rock"] <- "tank_rock";
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

	//printl("[Bot AI] Add Timer " + BotAI.Timers.AddTimerByName("AdjustBotsUpdateRate", 0.1, true, BotAI.AdjustBotsUpdateRate));
	printl("[Bot AI] Add Timer " + BotAI.Timers.AddTimerByName("AdjustBotState", 1.5, true, BotAI.AdjustBotState));
	printl("[Bot AI] Add Timer " + BotAI.Timers.AddTimerByName("TriggerHandler", 20, true, BotAI.TriggerHandler));
	//printl("[Bot AI] Add Timer " + BotAI.Timers.AddTimerByName("AITaskSystem", 0.1, true, BotAI.updateAITasks));
	printl("[Bot AI] Add Timer " + BotAI.Timers.AddTimerByName("ModifyMolotovVector", 0.1, true, BotAI.ModifyMolotovVector));
	printl("[Bot AI] Add Timer " + BotAI.Timers.AddTimerByName("DebugFunction", 0.1, true, BotAI.DebugFunction));
	BotAI.ResetBotFireRate();
	printl("[Bot AI] Add Timer " + BotAI.Timers.AddTimerByName("locateUseTarget", 0.1, true, BotAI.locateUseTarget));

	printl("[Bot AI] Add Timer " + BotAI.Timers.AddTimerByName("NoticeText", 30, false, BotAI.NoticeText));

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

	if(BotAI.ESCORT) {
		Convars.SetValue( "sb_separation_range", 100 );
		Convars.SetValue( "sb_separation_danger_min_range", 100 );
		Convars.SetValue( "sb_separation_danger_max_range", 300 );
		Convars.SetValue( "sb_allow_leading", 0 );
	}
	else {
		Convars.SetValue( "sb_allow_leading", 1 );
		Convars.SetValue( "sb_separation_range", 1000 );
		Convars.SetValue( "sb_separation_danger_min_range", 1000 );
		Convars.SetValue( "sb_separation_danger_max_range", 1500 );
	}

	if(BotAI.UNSTICK)
		Convars.SetValue( "sb_unstick", 1 );
	else
		Convars.SetValue( "sb_unstick", 0 );

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
	BotAI.language <- Convars.GetStr("cl_language");
	Convars.SetValue( "sv_consistency", 0 );
	Convars.SetValue( "sb_melee_approach_victim", 0 );
	Convars.SetValue( "sb_allow_shoot_through_survivors", 0 );
	Convars.SetValue( "allow_all_bot_survivor_team", 1 );
	Convars.SetValue( "sb_toughness_buffer", 25 );
	Convars.SetValue( "sb_temp_health_consider_factor", 0.90 );
	//Convars.SetValue( "think_limit", 10 );

	Convars.SetValue( "sb_friend_immobilized_reaction_time_normal", 0.5 );
	Convars.SetValue( "sb_friend_immobilized_reaction_time_hard", 0.2 );
	Convars.SetValue( "sb_friend_immobilized_reaction_time_expert", 0.001 );
	Convars.SetValue( "sb_friend_immobilized_reaction_time_vs", 0.2 );

	//Convars.SetValue( "survivor_calm_damage_delay", 0 );
	//Convars.SetValue( "survivor_calm_deploy_delay", 0 );
	//Convars.SetValue( "survivor_calm_no_flashlight", 0 );
	//Convars.SetValue( "survivor_calm_recent_enemy_delay", 0 );
	//Convars.SetValue( "survivor_calm_weapon_delay", 0 );

	//Convars.SetValue( "sb_transition", 0 );
	Convars.SetValue( "sb_battlestation_human_hold_time", 0 );
	Convars.SetValue( "sb_sidestep_for_horde", 0 );
	Convars.SetValue( "sb_close_checkpoint_door_interval", 0.15 );
	Convars.SetValue( "sb_max_battlestation_range_from_human", 0 );

	//Convars.SetValue( "sb_threat_very_close_range", 75 );
	//Convars.SetValue( "sb_close_threat_range", 120 );
	//Convars.SetValue( "sb_threat_exposure_stop", 0 );
	//Convars.SetValue( "sb_threat_exposure_walk", 220000 );
	//Convars.SetValue( "sb_threat_close_range", 120 );
	//Convars.SetValue( "sb_threat_medium_range", 600 );
	//Convars.SetValue( "sb_threat_far_range", 1200 );
	//Convars.SetValue( "sb_threat_very_far_range", 2200 );
	//Convars.SetValue( "sb_neighbor_range", 120 );
	Convars.SetValue( "sb_follow_stress_factor", 1 );
	Convars.SetValue( "sb_locomotion_wait_threshold", 0 );
	Convars.SetValue( "sb_path_lookahead_range", 2500 );
	Convars.SetValue( "sb_near_hearing_range", 2500 );
	Convars.SetValue( "sb_far_hearing_range", 4000 );

	Convars.SetValue( "sb_pushscale", 4 );
	Convars.SetValue( "sb_use_button_range", 1000 );
	//Convars.SetValue( "sb_max_scavenge_separation", 1500 );
	//Convars.SetValue( "sb_min_attention_notice_time", 0 );
	//Convars.SetValue( "sb_reachability_cache_lifetime", 0 );
	//Convars.SetValue( "sb_rescue_vehicle_loading_range", 300 );
	Convars.SetValue( "sb_revive_friend_distance", 200 );
	Convars.SetValue( "sb_vomit_blind_time", 0 );

	resetAllBots();
	//BotAI.loadBackpack();

	printl("[Bot AI]	Bot AI loaded.");
}

__CollectEventCallbacks(::BotAI.Events, "OnGameEvent_", "GameEventCallbacks", RegisterScriptGameEventListener);
__CollectEventCallbacks(::BotAI.Events, "OnScriptEvent_", "ScriptEventCallbacks", RegisterScriptGameEventListener);