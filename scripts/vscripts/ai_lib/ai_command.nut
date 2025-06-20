::MoreBotCmd <- function ( player, args , args1) {
	BotAI.EasyPrint("botai_no_more_bot");
}

::BotStopCmd <- function ( speaker, args , args1) {
	local notBotPlayer = null;
	while(notBotPlayer = Entities.FindByClassname(notBotPlayer, "player")) {
		if(BotAI.IsPlayerEntityValid(notBotPlayer) && notBotPlayer.IsSurvivor() && !IsPlayerABot(notBotPlayer) && NetProps.GetPropInt(notBotPlayer, "m_iTeamNum") != 1 && !notBotPlayer.IsDead()) {
			return;
		}
	}

	local player = null;
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
	local player = speaker;
	if (typeof player == "VSLIB_PLAYER")
		player = player.GetBaseEntity();

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}

	if(args.len() >= 1 && args[0] != null && args[0] != "") {
		local arg = args[0].tointeger();

		if(arg > 99) {
			arg = 99;
		}

		if(arg < 1) {
			arg = 1;
		}

		BotAI.BotCombatSkill = arg - 1;
		BotAI.SendPlayer(player, "botai_bot_combat_skill", 0.2, arg);
	} else {
		if(BotAI.BotCombatSkill > 0) {
			BotAI.BotCombatSkill = 0;
			BotAI.SendPlayer(player, "botai_bot_combat_skill", 0.2, 0);
		} else {
			BotAI.BotCombatSkill = 2;
			BotAI.SendPlayer(player, "botai_bot_combat_skill", 0.2, 2);
		}
	}

	BotExitMenuCmd(speaker, args, args1);
	BotAI.SaveSetting();
}

::BotFollowDistanceCmd <- function (speaker, args, args1) {
    local player = speaker;
    if (typeof player == "VSLIB_PLAYER") {
		player = player.GetBaseEntity();
	}

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}
    local input = "";
    foreach (idx, val in args) {
        input += val + " ";
    }

    input = strip(input);

    local distance = null;
    try {
        distance = input.tointeger();
    } catch (ex) {
        distance = 1500;
    }

    if (distance < 100) distance = 100;
    if (distance > 999999) distance = 999999;

    BotAI.FollowRange = distance;

	BotAI.resetFollowRange();

	BotAI.SendPlayer(player, "botai_bot_follow_distance", 0.2, distance);

    BotExitMenuCmd(speaker, args, args1);
    BotAI.SaveSetting();
}

::BotTeleportDistanceCmd <- function (speaker, args, args1) {
    local player = speaker;
    if (typeof player == "VSLIB_PLAYER") {
		player = player.GetBaseEntity();
	}

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}
    local input = "";
    foreach (idx, val in args) {
        input += val + " ";
    }

    input = strip(input);

    local distance = null;
    try {
        distance = input.tointeger();
    } catch (ex) {
        distance = 1500;
    }

    if (distance < 100) distance = 100;
    if (distance > 999999) distance = 999999;

	Convars.SetValue( "sb_enforce_proximity_range", distance );
    BotAI.TeleportDistance = distance;

	if (distance > 999990) {
		BotAI.SendPlayer(player, "botai_bot_teleport_distance_off", 0.2);
	} else {
		BotAI.SendPlayer(player, "botai_bot_teleport_distance", 0.2, distance);
	}

    BotExitMenuCmd(speaker, args, args1);
    BotAI.SaveSetting();
}

::BotSaveTeleportCmd <- function (speaker, args, args1) {
    local player = speaker;
    if (typeof player == "VSLIB_PLAYER") {
		player = player.GetBaseEntity();
	}

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}
    local input = "";
    foreach (idx, val in args) {
        input += val + " ";
    }

    input = strip(input);

    local time = null;
    try {
        time = input.tointeger();
    } catch (ex) {
        time = 9;
    }

    if (time < 0) time = 0;
    if (time > 999) time = 999;

    BotAI.SaveTeleport = time;
	if (time > 99) {
		BotAI.SendPlayer(player, "botai_bot_save_teleport_off", 0.2);
	} else {
		BotAI.SendPlayer(player, "botai_bot_save_teleport", 0.2, time);
	}

    BotExitMenuCmd(speaker, args, args1);
    BotAI.SaveSetting();
}

::BotGascanFindCmd <- function ( speaker, args  , args1) {
	local player = speaker;
	if (typeof player == "VSLIB_PLAYER")
		player = player.GetBaseEntity();

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}
	if(BotAI.NeedGasFinding) {
		BotAI.NeedGasFinding = false;
		BotAI.SendPlayer(player, "botai_gascan_finding_off");
	} else {
		BotAI.NeedGasFinding = true;
		BotAI.SendPlayer(player, "botai_gascan_finding_on");
	}
	BotAI.SaveSetting();
	BotExitMenuCmd(speaker, args, args1);
}

::BotThrowFireCmd <- function ( speaker, args , args1) {
	local player = speaker;
	if (typeof player == "VSLIB_PLAYER")
		player = player.GetBaseEntity();

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}
	if(BotAI.NeedThrowMolotov) {
		BotAI.NeedThrowMolotov = false;
		BotAI.SendPlayer(player, "botai_throw_fire_off");
	} else {
		BotAI.NeedThrowMolotov = true;
		BotAI.SendPlayer(player, "botai_throw_fire_on");
	}

	BotAI.SaveSetting();
	BotExitMenuCmd(speaker, args, args1);
}

::BotThrowPipeBombCmd <- function ( speaker, args , args1) {
	local player = speaker;
	if (typeof player == "VSLIB_PLAYER")
		player = player.GetBaseEntity();

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}
	if(BotAI.NeedThrowPipeBomb) {
		BotAI.NeedThrowPipeBomb = false;
		BotAI.SendPlayer(player, "botai_throw_pipe_off");
	} else {
		BotAI.NeedThrowPipeBomb = true;
		BotAI.SendPlayer(player, "botai_throw_pipe_on");
	}

	BotAI.SaveSetting();
	BotExitMenuCmd(speaker, args, args1);
}

::BotUseUpgradesCmd <- function ( speaker, args , args1) {
	local player = speaker;
	if (typeof player == "VSLIB_PLAYER") {
		player = player.GetBaseEntity();
	}

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}
	if (BotAI.UseUpgrades) {
		BotAI.UseUpgrades = false;
		BotAI.SendPlayer(player, "botai_use_upgrades_off");
	} else {
		BotAI.UseUpgrades = true;
		BotAI.SendPlayer(player, "botai_use_upgrades_on");
	}

	BotAI.SaveSetting();
	BotExitMenuCmd(speaker, args, args1);
}

::BotImmunityCmd <- function ( speaker, args , args1) {
	BotExitMenuCmd(speaker, args, args1);
	local player = speaker;
	if (typeof player == "VSLIB_PLAYER") {
		player = player.GetBaseEntity();
	}

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}

	if(BotAI.Immunity) {
		BotAI.Immunity = false;
		BotAI.SendPlayer(player, "botai_immunity_off");
	} else {
		BotAI.Immunity = true;
		BotAI.SendPlayer(player, "botai_immunity_on");
	}
	BotAI.SaveSetting();
}

::BotDefibrillatorCmd <- function ( speaker, args, args1) {
	BotExitMenuCmd(speaker, args, args1);
	local player = speaker;
	if (typeof player == "VSLIB_PLAYER") {
		player = player.GetBaseEntity();
	}

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}
	if(BotAI.Defibrillator) {
		BotAI.Defibrillator = false;
		BotAI.SendPlayer(player, "botai_defibrillator_off");
	} else {
		BotAI.Defibrillator = true;
		BotAI.SendPlayer(player, "botai_defibrillator_on");
	}
	BotAI.SaveSetting();
}

::BotPassingItemsCmd <- function ( speaker, args, args1) {
	BotExitMenuCmd(speaker, args, args1);
	local player = speaker;
	if (typeof player == "VSLIB_PLAYER") {
		player = player.GetBaseEntity();
	}

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}

	if(BotAI.PassingItems) {
		BotAI.PassingItems = false;
		BotAI.SendPlayer(player, "botai_passing_item_off");
	} else {
		BotAI.PassingItems = true;
		BotAI.SendPlayer(player, "botai_passing_item_on");
	}

	BotAI.SaveSetting();
}

::BotCloseSaferoomDoorCmd <- function ( speaker, args, args1) {
	BotExitMenuCmd(speaker, args, args1);
	local player = speaker;
	if (typeof player == "VSLIB_PLAYER") {
		player = player.GetBaseEntity();
	}

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}
	if(BotAI.CloseSaferoomDoor) {
		BotAI.CloseSaferoomDoor = false;
		Convars.SetValue( "sb_close_checkpoint_door_interval", 999 );
		BotAI.SendPlayer(player, "botai_close_door_off");
	} else {
		BotAI.CloseSaferoomDoor = true;
		Convars.SetValue( "sb_close_checkpoint_door_interval", 0.15 );
		BotAI.SendPlayer(player, "botai_close_door_on");
	}

	BotAI.SaveSetting();
}

::BotBackPackCmd <- function ( speaker, args  , args1) {
	BotExitMenuCmd(speaker, args, args1);
	local player = speaker;
	if (typeof player == "VSLIB_PLAYER") {
		player = player.GetBaseEntity();
	}

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}

	if(BotAI.BackPack) {
		BotAI.BackPack = false;
		BotAI.SendPlayer(player, "botai_bot_carry_off");
	} else {
		BotAI.BackPack = true;
		BotAI.SendPlayer(player, "botai_bot_carry_on");
	}
	BotAI.SaveSetting();
}

::BotAliveCmd <- function ( speaker, args  , args1) {
	BotExitMenuCmd(speaker, args, args1);
	local player = speaker;
	if (typeof player == "VSLIB_PLAYER") {
		player = player.GetBaseEntity();
	}

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}

	if(BotAI.NeedBotAlive) {
		BotAI.NeedBotAlive = false;
		Convars.SetValue( "sb_all_bot_game", 0);
		Convars.SetValue( "allow_all_bot_survivor_team", 0 );
		BotStopCmd(speaker, args, args1);
		BotAI.SendPlayer(player, "botai_bot_alive_off");
	} else {
		BotAI.NeedBotAlive = true;
		Convars.SetValue( "sb_all_bot_game", 1);
		Convars.SetValue( "allow_all_bot_survivor_team", 1 );
		BotAI.SendPlayer(player, "botai_bot_alive_on");
	}
	BotAI.SaveSetting();
}

::BotTeleportToSaferoomCmd <- function ( speaker, args  , args1) {
	BotExitMenuCmd(speaker, args, args1);
	local player = speaker;
	if (typeof player == "VSLIB_PLAYER") {
		player = player.GetBaseEntity();
	}

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}

	if(BotAI.TeleportToSaferoom) {
		BotAI.TeleportToSaferoom = false;
		BotAI.SendPlayer(player, "botai_bot_teleport_to_saferoom_off");
	} else {
		BotAI.TeleportToSaferoom = true;
		BotAI.SendPlayer(player, "botai_bot_teleport_to_saferoom_on");
	}

	BotAI.SaveSetting();
}

::BotSpreadCompensationCmd <- function ( speaker, args  , args1) {
	BotExitMenuCmd(speaker, args, args1);
	local player = speaker;
	if (typeof player == "VSLIB_PLAYER") {
		player = player.GetBaseEntity();
	}

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}

	if(BotAI.SpreadCompensation) {
		BotAI.SpreadCompensation = false;
		BotAI.SendPlayer(player, "botai_spread_compensation_off");
	} else {
		BotAI.SpreadCompensation = true;
		BotAI.SendPlayer(player, "botai_spread_compensation_on");
	}

	BotAI.SaveSetting();
}

::BotPathFindingCmd <- function ( speaker, args , args1) {
	BotExitMenuCmd(speaker, args, args1);
	local player = speaker;
	if (typeof player == "VSLIB_PLAYER")
		player = player.GetBaseEntity();

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}

	if(BotAI.PathFinding) {
		BotAI.PathFinding = false;
		Convars.SetValue( "sb_allow_leading", 0 );
		BotAI.SendPlayer(player, "botai_path_finding_off");
	} else {
		BotAI.PathFinding = true;
		Convars.SetValue( "sb_allow_leading", 1 );
		BotAI.SendPlayer(player, "botai_path_finding_on");
		if(BotAI.PathFinding) {
			BotAI.SendPlayer(player, "botai_unstick_pathfinding");
		}
	}

	BotAI.resetFollowRange();
	BotAI.SaveSetting();
}

::BotUnstickCmd <- function ( speaker, args , args1) {
	BotExitMenuCmd(speaker, args, args1);
	local player = speaker;
	if (typeof player == "VSLIB_PLAYER")
		player = player.GetBaseEntity();

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}

	if(BotAI.UnStick) {
		BotAI.UnStick = false;
		Convars.SetValue( "sb_unstick", 0 );
		BotAI.SendPlayer(player, "botai_unstick_off");
	} else {
		BotAI.UnStick = true;
		Convars.SetValue( "sb_unstick", 1 );
		BotAI.SendPlayer(player, "botai_unstick_on");
		if(BotAI.PathFinding) {
			BotAI.SendPlayer(player, "botai_unstick_pathfinding");
		}
	}

	BotAI.SaveSetting();
}

::BotFireProtectCmd <- function ( speaker, args , args1) {
	BotExitMenuCmd(speaker, args, args1);
	local player = speaker;
	if (typeof player == "VSLIB_PLAYER")
		player = player.GetBaseEntity();

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}

	if(BotAI.FireProtect) {
		BotAI.FireProtect = false;
		BotAI.SendPlayer(player, "botai_fire_protect_off");
	} else {
		BotAI.FireProtect = true;
		BotAI.SendPlayer(player, "botai_fire_protect_on");
	}

	BotAI.SaveSetting();
}

::BotAcidProtectCmd <- function ( speaker, args , args1) {
	BotExitMenuCmd(speaker, args, args1);
	local player = speaker;
	if (typeof player == "VSLIB_PLAYER")
		player = player.GetBaseEntity();

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}

	if(BotAI.AcidProtect) {
		BotAI.AcidProtect = false;
		BotAI.SendPlayer(player, "botai_acid_protect_off");
	} else {
		BotAI.AcidProtect = true;
		BotAI.SendPlayer(player, "botai_acid_protect_on");
	}

	BotAI.SaveSetting();
}

::BotNonAliveProtectCmd <- function ( speaker, args , args1) {
	BotExitMenuCmd(speaker, args, args1);
	local player = speaker;
	if (typeof player == "VSLIB_PLAYER")
		player = player.GetBaseEntity();

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}

	if(BotAI.NonAliveProtect) {
		BotAI.NonAliveProtect = false;
		BotAI.SendPlayer(player, "botai_non_alive_protect_off");
	} else {
		BotAI.NonAliveProtect = true;
		BotAI.SendPlayer(player, "botai_non_alive_protect_on");
	}

	BotAI.SaveSetting();
}

::BotFallProtectCmd <- function ( speaker, args , args1) {
	BotExitMenuCmd(speaker, args, args1);
	local player = speaker;
	if (typeof player == "VSLIB_PLAYER")
		player = player.GetBaseEntity();

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}

	if(BotAI.FallProtect) {
		BotAI.FallProtect = false;
		BotAI.SendPlayer(player, "botai_fall_protect_off");
	} else {
		BotAI.FallProtect = true;
		BotAI.SendPlayer(player, "botai_fall_protect_on");
	}

	BotAI.SaveSetting();
}

function BotAI::getDamageMultiplier(args, minValue = -16.0, maxValue = 999.0) {
	local defaultMultiplier = 1.0;

    local input = "";
    foreach (idx, val in args) {
        input += val + " ";
    }
    input = strip(input);

    local multiplier = null;
    try {
        multiplier = input.tofloat();
    } catch (ex) {
        multiplier = defaultMultiplier;
    }

    if (multiplier < minValue) multiplier = minValue;
    if (multiplier > maxValue) multiplier = maxValue;

	return multiplier;
}

::BotWitchDamageCmd <- function ( speaker, args , args1) {
	BotExitMenuCmd(speaker, args, args1);
	local player = speaker;
    if (typeof player == "VSLIB_PLAYER")
        player = player.GetBaseEntity();

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}

    BotAI.WitchDamageMultiplier = BotAI.getDamageMultiplier(args);

    BotAI.SaveSetting();
    BotAI.SendPlayer(player, "botai_witch_damage", 0.2, BotAI.WitchDamageMultiplier);
}

::BotSpecialDamageCmd <- function ( speaker, args , args1) {
	BotExitMenuCmd(speaker, args, args1);
	local player = speaker;
    if (typeof player == "VSLIB_PLAYER")
        player = player.GetBaseEntity();

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}

    BotAI.SpecialDamageMultiplier = BotAI.getDamageMultiplier(args);

    BotAI.SaveSetting();
    BotAI.SendPlayer(player, "botai_special_damage", 0.2, BotAI.SpecialDamageMultiplier);
}

::BotTankDamageCmd <- function ( speaker, args , args1) {
	BotExitMenuCmd(speaker, args, args1);
	local player = speaker;
    if (typeof player == "VSLIB_PLAYER")
        player = player.GetBaseEntity();

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}

    BotAI.TankDamageMultiplier = BotAI.getDamageMultiplier(args);

    BotAI.SaveSetting();
    BotAI.SendPlayer(player, "botai_tank_damage", 0.2, BotAI.TankDamageMultiplier);
}

::BotCommonDamageCmd <- function ( speaker, args , args1) {
	BotExitMenuCmd(speaker, args, args1);
	local player = speaker;
    if (typeof player == "VSLIB_PLAYER")
        player = player.GetBaseEntity();

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}

    BotAI.CommonDamageMultiplier = BotAI.getDamageMultiplier(args);

    BotAI.SaveSetting();
    BotAI.SendPlayer(player, "botai_common_damage", 0.2, BotAI.CommonDamageMultiplier);
}

::BotNonAliveDamageCmd <- function ( speaker, args , args1) {
	BotExitMenuCmd(speaker, args, args1);
	local player = speaker;
    if (typeof player == "VSLIB_PLAYER")
        player = player.GetBaseEntity();

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}

    BotAI.NonAliveDamageMultiplier = BotAI.getDamageMultiplier(args);

    BotAI.SaveSetting();
    BotAI.SendPlayer(player, "botai_non_alive_damage", 0.2, BotAI.NonAliveDamageMultiplier);
}

::BotMeleeCmd <- function ( speaker, args , args1) {
	local player = speaker;
	if (typeof player == "VSLIB_PLAYER")
		player = player.GetBaseEntity();

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}

	if(BotAI.Melee) {
		BotAI.Melee = false;
		Convars.SetValue( "sb_max_team_melee_weapons", 0 );
		BotAI.SendPlayer(player, "botai_melee_off");
	} else {
		BotAI.Melee = true;
		BotAI.resetBotMeleeAction();
		BotAI.SendPlayer(player, "botai_melee_on");
	}

	BotAI.SaveSetting();
	BotExitMenuCmd(speaker, args, args1);
}
function BotAI::registerMenu() {
	local botMenu = ::HoloMenu.Menu("menu_title", BUTTON_GRENADE1);
	local function showMenu(player) {
		BotMenuCmd(player, "", "");
	}
	botMenu.registerPressEvent(showMenu);

	local pingMenu = ::HoloMenu.Menu("ping_menu", BUTTON_ALT2);
	local function openMenu(player) {
		if(BotAI.MainMenu.len() > 0)
			BotExitMenuCmd(player, "", "");
		if(!(player in BotAI.pingPoint) || !BotAI.IsAlive(BotAI.pingPoint[player])) return;
		if(!ABA_IsAdmin(player)) {
			BotAI.SendPlayer(player, "botai_admin_only");
			return;
		}
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
		if(!ABA_IsAdmin(player)) {
			BotAI.SendPlayer(player, "botai_admin_only");
			return;
		}
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
			if(!BotAI.IsAlive(bot)) {
				return true;
			}

			if(!BotAI.IsEntityValid(entity) || entity.GetOwnerEntity() != null) {
				return true;
			}

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

			if(BotAI.botRunPos(player, traceTable.pos, "buildTest", 0, build, 9999, true)) {
				DebugDrawCircle(traceTable.pos, Vector(0, 255, 0), 1.0, 50, true, 5);
			}
		}
	}
	testMenu.registerPressEvent(test);
}

::BotMenuCmd <- function ( speaker, args  , args1) {
	if (!("VSLib" in getroottable() && "HUD" in ::VSLib)) {
		BotAI.EasyPrint("botai_no_hud");
		return;
	}

	local player = speaker;
	if (typeof player == "VSLIB_PLAYER")
		player = player.GetBaseEntity();

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}

	if(BotAI.MainMenu.len()>0)
		BotExitMenuCmd(player, "", "");
	else
		BotAI.displayOptionMenu(player, args, args1);
}

::BotEmptyCmd <- function ( speaker, args  , args1) {}

function BotAI::buildMenu(player, topOptions, bottomOptions) {
	// 为什么在这里要再SetLayout一次呢? 因为旧时代遗老mod Vscript Loader已经没有存在的必要了, 它的加载顺序滞后导致其他依赖Vslib的模组无法正常加载HUD, 需要有人来制裁
	HUDSetLayout( ::VSLib.HUD._hud );
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
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_follow") + ": " + (BotAI.FollowRange).tostring(), BotAI.displayOptionMenuBotDistance);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_teleport") + ": " + (BotAI.TeleportDistance).tostring(), BotAI.displayOptionMenuBotFollowTeleport);
		menu.AddOption(BotAI.fromParams(BotAI.Melee, lang)+I18n.getTranslationKeyByLang(lang, "menu_take_melee"), BotMeleeCmd);
		menu.AddOption(BotAI.fromParams(BotAI.Immunity, lang)+I18n.getTranslationKeyByLang(lang, "menu_immunity"), BotImmunityCmd);
	}

	local function bot(menu) {
		menu.AddOption(BotAI.fromParams(BotAI.PathFinding, lang)+I18n.getTranslationKeyByLang(lang, "menu_pathfinding"), BotPathFindingCmd);
		menu.AddOption(BotAI.fromParams(BotAI.UnStick, lang)+I18n.getTranslationKeyByLang(lang, "menu_unstick"), BotUnstickCmd);
		menu.AddOption("emp_0", BotEmptyCmd);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_next"), BotAI.displayOptionMenuNext);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_exit"), BotExitMenuCmd);
	}

	BotAI.buildMenu(player, top, bot);
}

function BotAI::displayOptionMenuNext(player, args, args1) {
	local lang = BotAI.language;
	local function top(menu) {
		menu.AddOption(BotAI.fromParams(BotAI.NeedGasFinding, lang)+I18n.getTranslationKeyByLang(lang, "menu_find_gas"), BotGascanFindCmd);
		menu.AddOption(BotAI.fromParams(BotAI.NeedBotAlive, lang)+I18n.getTranslationKeyByLang(lang, "menu_alive"), BotAliveCmd);
		menu.AddOption(BotAI.fromParams(BotAI.Defibrillator, lang)+I18n.getTranslationKeyByLang(lang, "menu_defibrillator"), BotDefibrillatorCmd);
		menu.AddOption(BotAI.fromParams(BotAI.UseUpgrades, lang)+I18n.getTranslationKeyByLang(lang, "menu_upgrads"), BotUseUpgradesCmd);
		menu.AddOption(BotAI.fromParams(BotAI.BackPack, lang)+I18n.getTranslationKeyByLang(lang, "menu_carry"), BotBackPackCmd);
	}

	local function bot(menu) {
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_witch_damage") + ": " + (BotAI.WitchDamageMultiplier).tostring(), BotAI.displayOptionMenuBotWitchDamage);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_special_damage") + ": " + (BotAI.SpecialDamageMultiplier).tostring(), BotAI.displayOptionMenuBotSpecialDamage);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_pre"), BotAI.displayOptionMenu);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_next"), BotAI.displayOptionMenuNextNext);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_exit"), BotExitMenuCmd);
	}

	BotAI.buildMenu(player, top, bot);
}

function BotAI::displayOptionMenuNextNext(player, args, args1) {
	local lang = BotAI.language;
	local function top(menu) {
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_tank_damage") + ": " + (BotAI.TankDamageMultiplier).tostring(), BotAI.displayOptionMenuBotTankDamage);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_common_damage") + ": " + (BotAI.CommonDamageMultiplier).tostring(), BotAI.displayOptionMenuBotCommonDamage);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_non_alive_damage") + ": " + (BotAI.NonAliveDamageMultiplier).tostring(), BotAI.displayOptionMenuBotNonAliveDamage);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_save_teleport") + ": " + (BotAI.SaveTeleport).tostring(), BotAI.displayOptionMenuBotTeleport);
		menu.AddOption(BotAI.fromParams(BotAI.FallProtect, lang)+I18n.getTranslationKeyByLang(lang, "menu_fall_protect"), BotFallProtectCmd);
	}

	local function bot(menu) {
		menu.AddOption(BotAI.fromParams(BotAI.FireProtect, lang)+I18n.getTranslationKeyByLang(lang, "menu_fire_protect"), BotFireProtectCmd);
		menu.AddOption(BotAI.fromParams(BotAI.AcidProtect, lang)+I18n.getTranslationKeyByLang(lang, "menu_acid_protect"), BotAcidProtectCmd);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_pre"), BotAI.displayOptionMenuNext);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_next"), BotAI.displayOptionMenuNextNextNext);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_exit"), BotExitMenuCmd);
	}

	BotAI.buildMenu(player, top, bot);
}

function BotAI::displayOptionMenuNextNextNext(player, args, args1) {
	local lang = BotAI.language;
	local function top(menu) {
		menu.AddOption(BotAI.fromParams(BotAI.NonAliveProtect, lang)+I18n.getTranslationKeyByLang(lang, "menu_non_alive_protect"), BotNonAliveProtectCmd);
		menu.AddOption(BotAI.fromParams(BotAI.PassingItems, lang)+I18n.getTranslationKeyByLang(lang, "menu_passing_item"), BotPassingItemsCmd);
		menu.AddOption(BotAI.fromParams(BotAI.CloseSaferoomDoor, lang)+I18n.getTranslationKeyByLang(lang, "menu_close_door"), BotCloseSaferoomDoorCmd);
		menu.AddOption(BotAI.fromParams(BotAI.NeedThrowPipeBomb, lang)+I18n.getTranslationKeyByLang(lang, "menu_throw_pipe"), BotThrowPipeBombCmd);
		menu.AddOption(BotAI.fromParams(BotAI.NeedThrowMolotov, lang)+I18n.getTranslationKeyByLang(lang, "menu_throw_fire"), BotThrowFireCmd);
	}

	local function bot(menu) {
		menu.AddOption(BotAI.fromParams(BotAI.TeleportToSaferoom, lang)+I18n.getTranslationKeyByLang(lang, "menu_teleport_to_saferoom"), BotTeleportToSaferoomCmd);
		menu.AddOption(BotAI.fromParams(BotAI.SpreadCompensation, lang)+I18n.getTranslationKeyByLang(lang, "menu_spread_compensation"), BotSpreadCompensationCmd);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_pre"), BotAI.displayOptionMenuNextNext);
		menu.AddOption("emp_0", BotEmptyCmd);
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
	local function promax(player, args, args1) {
		combatSkill(7);
	}
	local function promaxplus(player, args, args1) {
		combatSkill(10);
	}

	local function top(menu) {
		menu.AddOption("1", normal);
		menu.AddOption("2", high);
		menu.AddOption("3", ultra);
		menu.AddOption("4", extreme);
		menu.AddOption("5", pro);
	}

	local function bot(menu) {
		menu.AddOption("7", promax);
		menu.AddOption("10", promaxplus);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_pre"), BotAI.displayOptionMenu);
		menu.AddOption("emp_0", BotEmptyCmd);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_exit"), BotExitMenuCmd);
	}

	BotAI.buildMenu(player, top, bot);
}

function BotAI::displayOptionMenuBotDistance(player, args, args1) {
	local lang = BotAI.language;
	local function followDistance(value) {
		local ability = [];
		ability.append(value.tostring());
		BotFollowDistanceCmd(player, ability, "");
	}
	local function normal(player, args, args1) {
		followDistance(100);
	}
	local function high(player, args, args1) {
		followDistance(200);
	}
	local function ultra(player, args, args1) {
		followDistance(350);
	}
	local function extreme(player, args, args1) {
		followDistance(500);
	}
	local function pro(player, args, args1) {
		followDistance(700);
	}
	local function pro_(player, args, args1) {
		followDistance(1000);
	}
	local function pro__(player, args, args1) {
		followDistance(999999);
	}

	local function top(menu) {
		menu.AddOption("100hu(1.9m)", normal);
		menu.AddOption("200hu(3.8m)", high);
		menu.AddOption("350hu(6.7m)", ultra);
		menu.AddOption("500hu(9.5m)", extreme);
		menu.AddOption("700hu(13.3m)", pro);
	}

	local function bot(menu) {
		menu.AddOption("1000hu(19.1m)", pro_);
		menu.AddOption("999999hu(~19050m)", pro__);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_pre"), BotAI.displayOptionMenu);
		menu.AddOption("emp_0", BotEmptyCmd);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_exit"), BotExitMenuCmd);
	}

	BotAI.buildMenu(player, top, bot);
}

function BotAI::displayOptionMenuBotFollowTeleport(player, args, args1) {
	local lang = BotAI.language;
	local function followDistance(value) {
		local ability = [];
		ability.append(value.tostring());
		BotTeleportDistanceCmd(player, ability, "");
	}
	local function normal(player, args, args1) {
		followDistance(100);
	}
	local function high(player, args, args1) {
		followDistance(350);
	}
	local function ultra(player, args, args1) {
		followDistance(500);
	}
	local function extreme(player, args, args1) {
		followDistance(700);
	}
	local function pro(player, args, args1) {
		followDistance(1000);
	}
	local function pro_(player, args, args1) {
		followDistance(1250);
	}
	local function pro__(player, args, args1) {
		followDistance(999999);
	}

	local function top(menu) {
		menu.AddOption("100hu(1.9m)", normal);
		menu.AddOption("350hu(6.7m)", high);
		menu.AddOption("500hu(9.5m)", ultra);
		menu.AddOption("700hu(13.3m)", extreme);
		menu.AddOption("1000hu(19.1m)", pro);
	}

	local function bot(menu) {
		menu.AddOption("1250hu(23.8m)", pro_);
		menu.AddOption("999999hu(~19050m)", pro__);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_pre"), BotAI.displayOptionMenu);
		menu.AddOption("emp_0", BotEmptyCmd);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_exit"), BotExitMenuCmd);
	}

	BotAI.buildMenu(player, top, bot);
}

function BotAI::displayOptionMenuBotTeleport(player, args, args1) {
	local lang = BotAI.language;
	local function teleportDistance(value) {
		local ability = [];
		ability.append(value.tostring());
		BotSaveTeleportCmd(player, ability, "");
	}
	local function normal(player, args, args1) {
		teleportDistance(0);
	}
	local function high(player, args, args1) {
		teleportDistance(5);
	}
	local function ultra(player, args, args1) {
		teleportDistance(9);
	}
	local function extreme(player, args, args1) {
		teleportDistance(12);
	}
	local function pro(player, args, args1) {
		teleportDistance(17);
	}
	local function pro_(player, args, args1) {
		teleportDistance(999);
	}

	local function top(menu) {
		menu.AddOption("0(s)", normal);
		menu.AddOption("5(s)", high);
		menu.AddOption("9(s)", ultra);
		menu.AddOption("12(s)", extreme);
		menu.AddOption("17(s)", pro);
	}

	local function bot(menu) {
		menu.AddOption("999(s)", pro_);
		menu.AddOption("emp_1", BotEmptyCmd);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_pre"), BotAI.displayOptionMenuNextNext);
		menu.AddOption("emp_0", BotEmptyCmd);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_exit"), BotExitMenuCmd);
	}

	BotAI.buildMenu(player, top, bot);
}

function BotAI::displayOptionMenuBotWitchDamage(player, args, args1) {
	local lang = BotAI.language;
	local function damageMultiplier(value) {
		local ability = [];
		ability.append(value.tostring());
		BotWitchDamageCmd(player, ability, "");
	}

	local function normal(player, args, args1) {
		damageMultiplier(0.2);
	}
	local function high(player, args, args1) {
		damageMultiplier(0.4);
	}
	local function ultra(player, args, args1) {
		damageMultiplier(0.6);
	}
	local function extreme(player, args, args1) {
		damageMultiplier(0.8);
	}
	local function pro(player, args, args1) {
		damageMultiplier(1.0);
	}
	local function pro_(player, args, args1) {
		damageMultiplier(1.5);
	}
	local function pro__(player, args, args1) {
		damageMultiplier(2.0);
	}

	local function top(menu) {
		menu.AddOption("0.2", normal);
		menu.AddOption("0.4", high);
		menu.AddOption("0.6", ultra);
		menu.AddOption("0.8", extreme);
		menu.AddOption("1.0", pro);
	}

	local function bot(menu) {
		menu.AddOption("1.5", pro_);
		menu.AddOption("2.0", pro__);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_pre"), BotAI.displayOptionMenuNext);
		menu.AddOption("emp_0", BotEmptyCmd);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_exit"), BotExitMenuCmd);
	}

	BotAI.buildMenu(player, top, bot);
}

function BotAI::displayOptionMenuBotSpecialDamage(player, args, args1) {
	local lang = BotAI.language;
	local function damageMultiplier(value) {
		local ability = [];
		ability.append(value.tostring());
		BotSpecialDamageCmd(player, ability, "");
	}

	local function normal(player, args, args1) {
		damageMultiplier(0.2);
	}
	local function high(player, args, args1) {
		damageMultiplier(0.4);
	}
	local function ultra(player, args, args1) {
		damageMultiplier(0.6);
	}
	local function extreme(player, args, args1) {
		damageMultiplier(0.8);
	}
	local function pro(player, args, args1) {
		damageMultiplier(1.0);
	}
	local function pro_(player, args, args1) {
		damageMultiplier(1.5);
	}
	local function pro__(player, args, args1) {
		damageMultiplier(2.0);
	}

	local function top(menu) {
		menu.AddOption("0.2", normal);
		menu.AddOption("0.4", high);
		menu.AddOption("0.6", ultra);
		menu.AddOption("0.8", extreme);
		menu.AddOption("1.0", pro);
	}

	local function bot(menu) {
		menu.AddOption("1.5", pro_);
		menu.AddOption("2.0", pro__);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_pre"), BotAI.displayOptionMenuNext);
		menu.AddOption("emp_0", BotEmptyCmd);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_exit"), BotExitMenuCmd);
	}

	BotAI.buildMenu(player, top, bot);
}

function BotAI::displayOptionMenuBotTankDamage(player, args, args1) {
	local lang = BotAI.language;
	local function damageMultiplier(value) {
		local ability = [];
		ability.append(value.tostring());
		BotTankDamageCmd(player, ability, "");
	}

	local function normal(player, args, args1) {
		damageMultiplier(0.2);
	}
	local function high(player, args, args1) {
		damageMultiplier(0.4);
	}
	local function ultra(player, args, args1) {
		damageMultiplier(0.6);
	}
	local function extreme(player, args, args1) {
		damageMultiplier(0.8);
	}
	local function pro(player, args, args1) {
		damageMultiplier(1.0);
	}
	local function pro_(player, args, args1) {
		damageMultiplier(1.5);
	}
	local function pro__(player, args, args1) {
		damageMultiplier(2.0);
	}

	local function top(menu) {
		menu.AddOption("0.2", normal);
		menu.AddOption("0.4", high);
		menu.AddOption("0.6", ultra);
		menu.AddOption("0.8", extreme);
		menu.AddOption("1.0", pro);
	}

	local function bot(menu) {
		menu.AddOption("1.5", pro_);
		menu.AddOption("2.0", pro__);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_pre"), BotAI.displayOptionMenuNextNext);
		menu.AddOption("emp_0", BotEmptyCmd);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_exit"), BotExitMenuCmd);
	}

	BotAI.buildMenu(player, top, bot);
}

function BotAI::displayOptionMenuBotCommonDamage(player, args, args1) {
	local lang = BotAI.language;
	local function damageMultiplier(value) {
		local ability = [];
		ability.append(value.tostring());
		BotCommonDamageCmd(player, ability, "");
	}

	local function normal(player, args, args1) {
		damageMultiplier(0.2);
	}
	local function high(player, args, args1) {
		damageMultiplier(0.4);
	}
	local function ultra(player, args, args1) {
		damageMultiplier(0.6);
	}
	local function extreme(player, args, args1) {
		damageMultiplier(0.8);
	}
	local function pro(player, args, args1) {
		damageMultiplier(1.0);
	}
	local function pro_(player, args, args1) {
		damageMultiplier(1.5);
	}
	local function pro__(player, args, args1) {
		damageMultiplier(2.0);
	}

	local function top(menu) {
		menu.AddOption("0.2", normal);
		menu.AddOption("0.4", high);
		menu.AddOption("0.6", ultra);
		menu.AddOption("0.8", extreme);
		menu.AddOption("1.0", pro);
	}

	local function bot(menu) {
		menu.AddOption("1.5", pro_);
		menu.AddOption("2.0", pro__);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_pre"), BotAI.displayOptionMenuNextNext);
		menu.AddOption("emp_0", BotEmptyCmd);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_exit"), BotExitMenuCmd);
	}

	BotAI.buildMenu(player, top, bot);
}

function BotAI::displayOptionMenuBotNonAliveDamage(player, args, args1) {
	local lang = BotAI.language;
	local function damageMultiplier(value) {
		local ability = [];
		ability.append(value.tostring());
		BotNonAliveDamageCmd(player, ability, "");
	}

	local function normal(player, args, args1) {
		damageMultiplier(0.2);
	}
	local function high(player, args, args1) {
		damageMultiplier(0.4);
	}
	local function ultra(player, args, args1) {
		damageMultiplier(0.6);
	}
	local function extreme(player, args, args1) {
		damageMultiplier(0.8);
	}
	local function pro(player, args, args1) {
		damageMultiplier(1.0);
	}
	local function pro_(player, args, args1) {
		damageMultiplier(1.5);
	}
	local function pro__(player, args, args1) {
		damageMultiplier(2.0);
	}

	local function top(menu) {
		menu.AddOption("0.2", normal);
		menu.AddOption("0.4", high);
		menu.AddOption("0.6", ultra);
		menu.AddOption("0.8", extreme);
		menu.AddOption("1.0", pro);
	}

	local function bot(menu) {
		menu.AddOption("1.5", pro_);
		menu.AddOption("2.0", pro__);
		menu.AddOption(I18n.getTranslationKeyByLang(lang, "menu_pre"), BotAI.displayOptionMenuNextNext);
		menu.AddOption("emp_0", BotEmptyCmd);
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