::BotAI.Events.OnGameEvent_item_pickup <- function(event)
{
	local p = GetPlayerFromUserID(event.userid);
	local item = event.item;
	if((item == "first_aid_kit_spawn" || item == "first_aid_kit" || item == "weapon_first_aid_kit_spawn" || item == "weapon_first_aid_kit" )&& p.IsSurvivor() && IsPlayerABot(p))
		BotAI.doAmmoUpgrades(p);
}

::BotAI.Events.OnGameEvent_player_spawn <- function(event) {
	local player = GetPlayerFromUserID(event.userid);
	if(BotAI.IsEntitySurvivorBot(player))
		BotAI.createPlayerTargetTimer(player);
}

::BotAI.Events.OnGameEvent_player_death <- function(event) {
	local player = GetPlayerFromUserID(event.userid);
	if(BotAI.IsEntitySurvivorBot(player)) {
		local infoTarget = null;
        while(infoTarget = Entities.FindByName(infoTarget, "botai_target_timer_" + player.GetEntityIndex()))
            infoTarget.Kill();
	}
}

::BotAI.Events.OnGameEvent_defibrillator_begin <- function(event) {
	BotAI.setBotHealingTime(GetPlayerFromUserID(event.userid), Time());
}

//Fix a problem when bot using defibrillator
::BotAI.Events.OnGameEvent_defibrillator_interrupted <- function(event) {
	local player = GetPlayerFromUserID(event.userid);
	local body = GetPlayerFromUserID(event.subject);

	if(BotAI.IsPlayerEntityValid(player) && IsPlayerABot(player) && BotAI.IsPlayerEntityValid(body)) {
		local lastTime = BotAI.getBotHealingTime(player);
		if(Time() - lastTime >= 2) {
			body.ReviveByDefib();
			BotAI.removeItem(player, "defibrillator");
		}
	}
}

//Fix a problem when bot using first aid kit
::BotAI.Events.OnGameEvent_heal_interrupted <- function(event) {
	local bot = GetPlayerFromUserID(event.userid);
	local player = GetPlayerFromUserID(event.subject);

	if(BotAI.IsPlayerEntityValid(bot) && IsPlayerABot(bot) && BotAI.IsPlayerEntityValid(player)) {
		local lastTime = BotAI.getBotHealingTime(bot);
		if(Time() - lastTime >= 2.5) {
			local percent = Convars.GetFloat("first_aid_heal_percent");
			local health = 100 * percent;
			local added = player.GetHealth() * (1.0 - percent);
			player.SetHealth(health + added);
			player.SetHealthBuffer(0);
			player.SetReviveCount(0);
			BotAI.removeItem(bot, "first_aid_kit");
		}
	}
	
	BotAI.SetBotHealing(bot, false);
}

::BotAI.Events.OnGameEvent_weapon_fire <- function(event) {
	local p = GetPlayerFromUserID(event.userid);
	local victim = BotAI.CanSeeOtherEntityPrintName(p, 999999, 0);
	
	if(p != null && p.IsSurvivor() && IsPlayerABot(p))
	{
		local wep = p.GetActiveWeapon();
		local ename = " ";
				
		if(BotAI.IsEntityValid(wep))
			ename = wep.GetClassname();
		
		local isSniper = ename == "weapon_sniper_awp" || ename == "weapon_sniper_scout" || ename == "weapon_pumpshotgun" || ename == "weapon_shotgun_chrome";
		
		local target = null;
		local damaged = false;
		local TD = 300;
		if(ename == "weapon_chainsaw")
			TD = 50;
		while(target = Entities.FindByClassnameWithin(target, "infected", p.GetOrigin(), 120)) {
			if(BotAI.IsEntityValid(target) && BotAI.VectorDotProduct(BotAI.normalize(p.EyeAngles().Forward()), BotAI.normalize(target.GetOrigin() - p.GetOrigin())) > -0.2
			&& (ename == "weapon_melee" || ename == "weapon_chainsaw")) {
				damaged = true;
				//BotAI.applyDamage(p, target, target.GetHealth(), DMG_BULLET);
				target.TakeDamageEx(null, p, p.GetActiveWeapon(), target.GetOrigin() - p.GetOrigin()
				, p.GetOrigin(), target.GetHealth(), DMG_BLAST);
				BotAI.spawnParticle("blood_impact_infected_01", target.GetOrigin() + Vector(0, 0, 50), target);
				//BotAI.spawnParticle("blood_atomized", target.GetOrigin() + Vector(0, 0, 50), target);
				BotAI.spawnParticle("blood_melee_slash_TP_swing", target.GetOrigin() + Vector(0, 0, 50), target);
			}
		}
		local range = Convars.GetFloat("melee_range");
		target = null;
		while(target = Entities.FindByClassnameWithin(target, "player", p.GetOrigin(), 120)) {
			if(BotAI.IsEntitySI(target) && BotAI.distanceof(p.GetOrigin(), target.GetOrigin()) > range 
			&& BotAI.VectorDotProduct(BotAI.normalize(p.EyeAngles().Forward()), BotAI.normalize(target.GetOrigin() - p.GetOrigin())) > 0.8
			&& (ename == "weapon_melee" || ename == "weapon_chainsaw")) {
				damaged = true;
				BotAI.applyDamage(p, target, TD, DMG_MELEE);
				BotAI.spawnParticle("blood_impact_infected_01", target.GetOrigin() + Vector(0, 0, 50), target);
				//BotAI.spawnParticle("blood_atomized_c", target.GetOrigin() + Vector(0, 0, 50), target);
				BotAI.spawnParticle("blood_melee_slash_TP_swing", target.GetOrigin() + Vector(0, 0, 50), target);
			}
		}

		target = null;
		while(target = Entities.FindByClassnameWithin(target, "witch", p.GetOrigin(), 120)) {
			if(BotAI.distanceof(p.GetOrigin(), target.GetOrigin()) > range 
			&& BotAI.VectorDotProduct(BotAI.normalize(p.EyeAngles().Forward()), BotAI.normalize(target.GetOrigin() - p.GetOrigin())) > 0.8
			&& (ename == "weapon_melee" || ename == "weapon_chainsaw")) {
				damaged = true;
				BotAI.applyDamage(p, target, TD, DMG_MELEE);
				BotAI.spawnParticle("blood_impact_infected_01", target.GetOrigin() + Vector(0, 0, 50), target);
				//BotAI.spawnParticle("blood_atomized_c", target.GetOrigin() + Vector(0, 0, 50), target);
				BotAI.spawnParticle("blood_melee_slash_TP_swing", target.GetOrigin() + Vector(0, 0, 50), target);
			}
		}

		if(damaged)
			BotAI.playSound(p, BotAI.getMeleeSound(wep.GetModelName()));
		
		if(BotAI.IsEntityValid(wep) && (BotAI.getIsMelee(p) || isSniper)) {
			local mult = 0.7;
			if(isSniper)
				mult = 0.7;
			local endTime = NetProps.GetPropFloat(wep, "m_flNextPrimaryAttack");
			local nowTime = Time();
			local duration = (endTime - nowTime) * mult;
			NetProps.SetPropFloat(wep, "m_flNextPrimaryAttack", nowTime + duration);
		}
	}
	
	if(BotAI.Versus_Mode)
		return;

	if(victim != null && victim.GetClassname() == "tank_rock") {
		victim.TakeDamage(300, DMG_BULLET, p);
	}

	if(victim != null && (victim.GetClassname() == "witch" || victim.GetClassname() == "infected" || (victim.GetClassname() == "player" && BotAI.IsPlayerEntityValid(victim) && !victim.IsSurvivor())) && p.IsSurvivor() && IsPlayerABot(p))
	{
		weapon <- p.GetActiveWeapon();
		local count = 1;
		local mult = 0.5;
		if("count" in event)
			count = event.count;
		
		if(count < 1)
			count = 1;
		if(BotAI.BOT_AI_TEST_MOD >= 2) {
			mult = 1.0;
			local distance = BotAI.distanceof(p.GetOrigin(), victim.GetOrigin());
			if(distance < 150)
				mult = 1.5;
			if(distance < 100)
				mult *= 2.0;
		}
		
		local mp_gamemode = Convars.GetStr("mp_gamemode");
		
		if(victim.GetClassname() == "witch")
		{
			WitchState <- NetProps.GetPropInt(victim, "m_nSequence");
			if(WitchState == ANIM_SITTING_CRY || WitchState == ANIM_SITTING_STARTLED || WitchState == ANIM_SITTING_AGGRO || WitchState == ANIM_WALK || WitchState == ANIM_WANDER_WALK)
			{
			}
			else
			{
				if(mp_gamemode == "realism")
				 	BotAI.applyDamage(p, victim, BotAI.getDamage(weapon.GetClassname()) * count * mult, DMG_HEADSHOT);
				else
					BotAI.applyDamage(p, victim, BotAI.getDamage(weapon.GetClassname()) * count * mult * 2.75, DMG_HEADSHOT);
			}
		}

		if(victim.GetClassname() == "infected")
			BotAI.applyDamage(p, victim, BotAI.getDamage(weapon.GetClassname()) * count * mult, DMG_HEADSHOT);
		
		if(victim.GetClassname() == "player")
		{
			if(victim.GetZombieType() != 8)
				BotAI.applyDamage(p, victim, BotAI.getDamage(weapon.GetClassname()) * count * mult * 0.9, DMG_BULLET);
		}
	}

	if(BotAI.BOT_AI_TEST_MOD < 2 && RandomInt(0, 3) != 0)
		return;

	if(p != null && p.IsSurvivor() && IsPlayerABot(p))
	{
		weapon <- p.GetActiveWeapon();
		if(BotAI.BOT_AI_TEST_MOD >= 2 || weapon.GetClassname() == "weapon_pistol" || weapon.GetClassname() == "weapon_pistol_magnum")
		{
			NetProps.SetPropInt(weapon, "m_iClip1", NetProps.GetPropInt(weapon, "m_iClip1") + 1);
		}
		else if(victim != null && ((victim.GetClassname() == "player" && !victim.IsSurvivor()) || victim.GetClassname() == "witch"))
			NetProps.SetPropInt(weapon, "m_iClip1", NetProps.GetPropInt(weapon, "m_iClip1") + 1);
		else if(RandomInt(0, 2) == 0)
		{
			NetProps.SetPropInt(weapon, "m_iClip1", NetProps.GetPropInt(weapon, "m_iClip1") + 1);
		}
	}
}

::BotAI.Events.OnGameEvent_revive_success <- function(event)
{
	if(!("subject" in event) || event.subject == null || !("userid" in event) || event.userid == null )
		return;
	
	reviving <- GetPlayerFromUserID(event.userid);
	
	BotAI.SetPlayerRevived(reviving, null);
	BotAI.SetPlayerReviving(reviving, false);
}

::BotAI.Events.OnGameEvent_player_death <- function(event)
{
	if(!("userid" in event) || event.userid == null || !("attacker" in event) || event.attacker == null )
		return;

	attacker <- GetPlayerFromUserID(event.attacker);
	victim <- GetPlayerFromUserID(event.userid);
	
	local attack = EntIndexToHScript(event.attacker);
	
	if(!BotAI.IsPlayerEntityValid(victim) || !BotAI.IsPlayerEntityValid(attacker))
		return;
	
	if(victim.IsSurvivor()) {
		if(attack == "trigger_hurt" && ((event.type & DMG_DROWN) != 0) || ((event.type & DMG_CRUSH) != 0)) {
			BotAI.UnreachableDeath[victim] <- 1;
		}
		else if(victim in BotAI.UnreachableDeath) {
			delete BotAI.UnreachableDeath.victim;
		}
	}
	
	if(victim.IsSurvivor() || !attacker.IsSurvivor())
		return;
	
	if(BotAI.IsAlive(attacker) && BotAI.IsEntitySurvivorBot(attacker))
	{
		if(victim.GetZombieType() == 8)
		{
			if(BotAI.BOT_AI_TEST_MOD >= 2 && RandomInt(0, 1) == 0)
			{
				foreach(sur in BotAI.SurvivorBotList)
				{
					if(!BotAI.IsSurvivorTrapped(sur))
						BotAI.Laugh(sur);
				}
			}
			else if(RandomInt(0, 4) == 0)
			{
				foreach(sur in BotAI.SurvivorBotList)
				{
					if(!BotAI.IsSurvivorTrapped(sur))
						BotAI.Laugh(sur);
				}
			}
		}
		else
		{
			if(BotAI.BOT_AI_TEST_MOD >= 2)
			{
				if(BotAI.HasSpecialInfectedAlive())
				{
					if(RandomInt(0, 2) == 0)
					{
						if(!BotAI.IsSurvivorTrapped(attacker))
							BotAI.Laugh(attacker);
					}
				}
				else if(RandomInt(0, 2) == 0)
				{
					foreach(sur in BotAI.SurvivorBotList)
					{
						if(!BotAI.IsSurvivorTrapped(sur))
							BotAI.Laugh(sur);
					}
				}
			}
			else if(!BotAI.Versus_Mode)
			{
				if(BotAI.HasSpecialInfectedAlive())
				{
					if(RandomInt(0, 5) == 0)
					{
						if(!BotAI.IsSurvivorTrapped(attacker))
							BotAI.Laugh(attacker);
					}
				}
				else if(RandomInt(0, 3) == 0)
				{
					foreach(sur in BotAI.SurvivorBotList)
					{
						if(!BotAI.IsSurvivorTrapped(sur))
							BotAI.Laugh(sur);
					}
				}
			}
			else
			{
				if(RandomInt(0, 14) == 0)
				{
					if(!BotAI.IsSurvivorTrapped(attacker))
						BotAI.Laugh(attacker);
				}
			}
		}
	}
}

::BotAI.Events.OnGameEvent_revive_begin <- function(event) {
	reviving <- GetPlayerFromUserID(event.userid);
	revived <- GetPlayerFromUserID(event.subject);

	BotAI.SetPlayerRevived(reviving, revived);
	BotAI.SetPlayerReviving(reviving, true);
	BotAI.setBotHealingTime(reviving, Time());
}

//Fix a problem when bot revive
::BotAI.Events.OnGameEvent_revive_end <- function(event) {
	reviving <- GetPlayerFromUserID(event.userid);
	revived <- GetPlayerFromUserID(event.subject);

	if(BotAI.IsPlayerEntityValid(reviving) && IsPlayerABot(reviving) && BotAI.IsPlayerEntityValid(revived)) {
		local lastTime = BotAI.getBotHealingTime(reviving);
		if(Time() - lastTime >= 3)
			revived.ReviveFromIncap();
	}

	BotAI.SetPlayerRevived(reviving, null);
	BotAI.SetPlayerReviving(reviving, false);
}

::BotAI.Events.OnGameEvent_heal_begin <- function(event) {
	BotAI.setBotHealingTime(GetPlayerFromUserID(event.userid), Time());
	if(event.userid == event.subject)
		return;
	
	BotAI.SetBotHealing(GetPlayerFromUserID(event.userid), true);
}

::BotAI.Events.OnGameEvent_heal_end <- function(event) {
	if(event.userid == event.subject)
		return;
	
	BotAI.SetBotHealing(GetPlayerFromUserID(event.userid), false);
}

::BotAI.Events.OnGameEvent_witch_harasser_set <- function(event)
{
	if(!("witchid" in event) || event.witchid == null || !("userid" in event) || event.userid == null )
		return;
	
	attacker <- GetPlayerFromUserID(event.userid);
	victim <- Ent(event.witchid);
	local mp_gamemode = Convars.GetStr("mp_gamemode");
	
	if(BotAI.BOT_AI_TEST_MOD == 1)
		printl(mp_gamemode);

	if(victim != null && BotAI.IsPlayerEntityValid(attacker) && IsPlayerABot(attacker) && attacker.IsSurvivor())
	{
		if(mp_gamemode == "realism")
			BotAI.applyDamage(attacker, victim, 75, DMG_BULLET);
		else
			BotAI.applyDamage(attacker, victim, 225, DMG_BULLET);
	}
}

::BotAI.Events.OnGameEvent_charger_pummel_start <- function(event)
{
	if(!("victim" in event) || event.victim == null)
		return;

	victim <- GetPlayerFromUserID(event.victim);

	BotAI.SurvivorTrapped[victim.GetEntityIndex()] <- victim;
	BotAI.SurvivorTrappedTimed[victim.GetEntityIndex()] <- victim;
}

::BotAI.Events.OnGameEvent_charger_pummel_end <- function(event)
{
	if(!("victim" in event) || event.victim == null)
		return;
	victim <- GetPlayerFromUserID(event.victim);
	
	BotAI.SurvivorTrapped[victim.GetEntityIndex()] <- null;
	BotAI.SurvivorTrappedTimed[victim.GetEntityIndex()] <- null;
}

::BotAI.Events.OnGameEvent_choke_start <- function(event)
{
	if(!("victim" in event) || event.victim == null)
		return;

	victim <- GetPlayerFromUserID(event.victim);

	BotAI.SurvivorTrapped[victim.GetEntityIndex()] <- victim;
	BotAI.SurvivorTrappedTimed[victim.GetEntityIndex()] <- victim;
}

::BotAI.Events.OnGameEvent_choke_stopped <- function(event)
{
	if(!("victim" in event) || event.victim == null)
		return;
	victim <- GetPlayerFromUserID(event.victim);
	
	BotAI.SurvivorTrapped[victim.GetEntityIndex()] <- null;
	BotAI.SurvivorTrappedTimed[victim.GetEntityIndex()] <- null;
}

::BotAI.Events.OnGameEvent_choke_end <- function(event)
{
	if(!("victim" in event) || event.victim == null)
		return;
	victim <- GetPlayerFromUserID(event.victim);
	
	BotAI.SurvivorTrapped[victim.GetEntityIndex()] <- null;
	BotAI.SurvivorTrappedTimed[victim.GetEntityIndex()] <- null;
}

::BotAI.Events.OnGameEvent_tongue_grab <- function(event)
{
	if(!("victim" in event) || !("userid" in event))
		return;
	local attacker = GetPlayerFromUserID(event.userid);
	local victim = GetPlayerFromUserID(event.victim);
	
	if(attacker.GetEntityIndex() in BotAI.smokerTongue) {
		delete BotAI.smokerTongue[attacker.GetEntityIndex()];
		
		if(BotAI.IsEntitySurvivorBot(victim) && BotAI.IsPressingAttack(victim) && BotAI.IsTarget(attacker, victim) && BotAI.getIsMelee(victim)){
			NetProps.SetPropEntity(attacker, "m_tongueVictim", -1);
			NetProps.SetPropEntity(victim, "m_tongueOwner", -1);
		}
	}

	if(IsPlayerABot(victim))
		BotAI.BotAttack(victim, attacker);

	BotAI.SurvivorTrapped[victim.GetEntityIndex()] <- victim;
	BotAI.SurvivorTrappedTimed[victim.GetEntityIndex()] <- victim;
	local function addTimed(vic)
	{
		BotAI.SurvivorTrappedTimed[vic.GetEntityIndex()] <- null;
	}
	
	BotAI.Timers.AddTimerByName("addTimed-" + victim.GetEntityIndex(), 0.5, false, addTimed, victim);
}

::BotAI.Events.OnGameEvent_tongue_release <- function(event)
{
	local attacker = GetPlayerFromUserID(event.userid);
	if(attacker.GetEntityIndex() in BotAI.smokerTongue)
		delete BotAI.smokerTongue[attacker.GetEntityIndex()];
	if(!("victim" in event) || event.victim == null)
		return;
	victim <- GetPlayerFromUserID(event.victim);

	if(victim != null && "GetEntityIndex" in victim) {
		BotAI.SurvivorTrapped[victim.GetEntityIndex()] <- null;
		BotAI.SurvivorTrappedTimed[victim.GetEntityIndex()] <- null;
	}
}

::BotAI.Events.OnGameEvent_tongue_broke_bent <- function(event)
{
	local attacker = GetPlayerFromUserID(event.userid);
	if(attacker.GetEntityIndex() in BotAI.smokerTongue)
		delete BotAI.smokerTongue[attacker.GetEntityIndex()];
}

::BotAI.Events.OnGameEvent_jockey_ride <- function(event)
{
	if(!("victim" in event) || event.victim == null)
		return;

	local victim = GetPlayerFromUserID(event.victim);
	local attacker = GetPlayerFromUserID(event.userid);
	
	if(BotAI.IsEntitySurvivorBot(victim) && BotAI.BOT_AI_TEST_MOD >= 2 && RandomInt(0, 3) > 0) {
		NetProps.SetPropInt(victim, "m_jockeyAttacker", -1);
		NetProps.SetPropInt(attacker, "m_jockeyVictim", 1);
		return;
	}

	BotAI.SurvivorTrapped[victim.GetEntityIndex()] <- victim;
	BotAI.SurvivorTrappedTimed[victim.GetEntityIndex()] <- victim;
	local function addTimed(vic)
	{
		BotAI.SurvivorTrappedTimed[vic.GetEntityIndex()] <- null;
	}
	
	BotAI.Timers.AddTimerByName("addTimed-" + victim.GetEntityIndex(), 0.5, false, addTimed, victim);
}

::BotAI.Events.OnGameEvent_jockey_ride_end <- function(event)
{
	if(!("victim" in event) || event.victim == null)
		return;
	victim <- GetPlayerFromUserID(event.victim);
	
	BotAI.SurvivorTrapped[victim.GetEntityIndex()] <- null;
	BotAI.SurvivorTrappedTimed[victim.GetEntityIndex()] <- null;
}

::BotAI.Events.OnGameEvent_lunge_pounce <- function(event)
{
	if(!("victim" in event) || event.victim == null)
		return;

	local victim = GetPlayerFromUserID(event.victim);
	local attacker = GetPlayerFromUserID(event.userid);

	if(BotAI.IsEntitySurvivorBot(victim) && BotAI.BOT_AI_TEST_MOD >= 2 && RandomInt(0, 3) > 0) {
		NetProps.SetPropInt(victim, "m_pounceAttacker", -1);
		NetProps.SetPropInt(attacker, "m_pounceVictim", 1);
		return;
	}
	
	BotAI.SurvivorTrapped[victim.GetEntityIndex()] <- victim;
	BotAI.SurvivorTrappedTimed[victim.GetEntityIndex()] <- victim;
	local function addTimed(vic)
	{
		BotAI.SurvivorTrappedTimed[vic.GetEntityIndex()] <- null;
	}
	
	BotAI.Timers.AddTimerByName("addTimed-" + victim.GetEntityIndex(), 0.5, false, addTimed, victim);
}

::BotAI.Events.OnGameEvent_pounce_stopped <- function(event)
{
	if(!("victim" in event) || event.victim == null)
		return;
	victim <- GetPlayerFromUserID(event.victim);
	
	if("GetEntityIndex" in victim)
	{
		BotAI.SurvivorTrapped[victim.GetEntityIndex()] <- null;
		BotAI.SurvivorTrappedTimed[victim.GetEntityIndex()] <- null;
	}
}

::BotAI.Events.OnGameEvent_pounce_end <- function(event)
{
	if(!("victim" in event) || event.victim == null)
		return;
	victim <- GetPlayerFromUserID(event.victim);
	
	BotAI.SurvivorTrapped[victim.GetEntityIndex()] <- null;
	BotAI.SurvivorTrappedTimed[victim.GetEntityIndex()] <- null;
}

::BotAI.Events.OnGameEvent_player_now_it <- function(event)
{
	if(!("userid" in event) || event.userid == null)
		return;
		
	victim <- GetPlayerFromUserID(event.userid);
	if(BotAI.IsEntityValid(victim))
	{
		if(!(victim.GetEntityIndex() in BotAI.VomitList))
			BotAI.VomitList[victim.GetEntityIndex()] <- true;
		else
			BotAI.VomitList[victim.GetEntityIndex()] = true;
	}
}

::BotAI.Events.OnGameEvent_player_no_longer_it <- function(event)
{
	if(!("userid" in event) || event.userid == null)
		return;
		
	victim <- GetPlayerFromUserID(event.userid);
	if(BotAI.IsEntityValid(victim) && victim.GetEntityIndex() in BotAI.VomitList)
		BotAI.VomitList[victim.GetEntityIndex()] = false;
	/*
	if(victim.GetEntityIndex() in BotAI.continueVomit && BotAI.continueVomit[victim.GetEntityIndex()]) {
		if(BotAI.BOT_AI_TEST_MOD == 1) {
			printl("[Bot AI] re-vomit target");
		victim.HitWithVomit();
	}
	*/
}

::BotAI.Events.OnGameEvent_player_hurt <- function(event)
{
	if(!("userid" in event) || event.userid == null)
		return;

	local player = GetPlayerFromUserID(event.userid);
	local attacker = GetPlayerFromUserID(event.attacker);
	
	if(IsPlayerABot(player) && BotAI.UseTarget != null && BotAI.IsBotGasFinding(player))
	{
		if("GetClassname" in attacker && (attacker.GetClassname() == "infected" || (attacker.GetClassname() == "player" && attacker.GetZombieType() != 9)))
			BotAI.BotAttack(player, attacker);
	}
}

::BotAI.Events.OnGameEvent_player_entered_checkpoint <- function(event)
{
	if(!("userid" in event) || event.userid == null)
		return;
		local player = GetPlayerFromUserID(event.userid);
		if(player.IsSurvivor() && IsPlayerABot(player))
			BotAI.SetPlayerAtCheckPoint(player, true);
}

::BotAI.Events.OnGameEvent_player_left_checkpoint <- function(event)
{
	if(!("userid" in event) || event.userid == null)
		return;
		local player = GetPlayerFromUserID(event.userid);
		if(player.IsSurvivor() && IsPlayerABot(player))
			BotAI.SetPlayerAtCheckPoint(player, false);
}

::BotAI.Events.OnGameEvent_player_shoved <- function(event)
{
	victim <- GetPlayerFromUserID(event.userid);
	attacker <- GetPlayerFromUserID(event.attacker);

	if(BotAI.IsPlayerEntityValid(attacker) && attacker.IsSurvivor() && IsPlayerABot(attacker) && !attacker.IsDead() && BotAI.IsPlayerEntityValid(victim) && !victim.IsSurvivor() && IsPlayerABot(victim) && !victim.IsDead())
	{
		if(BotAI.IsOnGround(victim))
		{
			victim.SetSenseFlags(victim.GetSenseFlags() | BOT_CANT_SEE);
			::BotAI.Timers.AddTimer(1.4, false, BotAI.EnableSight {infect = victim});
		}
		BotAI.applyPushVelocity(attacker, victim);
	}

	if(BotAI.IsPlayerEntityValid(attacker) && attacker.IsSurvivor() && !IsPlayerABot(attacker) && !attacker.IsDead() && BotAI.IsPlayerEntityValid(victim) && victim.IsSurvivor() && IsPlayerABot(victim) && !victim.IsDead())
	{
		weapon <- attacker.GetActiveWeapon();
		ename <- weapon.GetClassname();
		
		local function genStrGet(str)
		{
			if(str == "weapon_molotov")
				return "molotov";
			if(str == "weapon_vomitjar")
				return "vomitjar";
			if(str == "weapon_pipe_bomb")
				return "pipe_bomb";
			return " ";
		}
		
		if(BotAI.HasItem(victim, "pipe_bomb") && (ename == "weapon_molotov" || ename == "weapon_vomitjar"))
		{
			BotAI.removeItem(attacker, genStrGet(ename));
			BotAI.removeItem(victim, "pipe_bomb");
			attacker.GiveItem("pipe_bomb");
			victim.GiveItem(genStrGet(ename));
			return;
		}
		
		if(BotAI.HasItem(victim, "molotov") && (ename == "weapon_pipe_bomb" || ename == "weapon_vomitjar"))
		{
			BotAI.removeItem(attacker, genStrGet(ename));
			BotAI.removeItem(victim, "molotov");
			attacker.GiveItem("molotov");
			victim.GiveItem(genStrGet(ename));
			return;
		}
		
		if(BotAI.HasItem(victim, "vomitjar") && (ename == "weapon_molotov" || ename == "weapon_pipe_bomb"))
		{
			BotAI.removeItem(attacker, genStrGet(ename));
			BotAI.removeItem(victim, "vomitjar");
			attacker.GiveItem("vomitjar");
			victim.GiveItem(genStrGet(ename));
			return;
		}
	}
}

::BotAI.Events.OnGameEvent_explain_scavenge_goal <- function (event) {
	BotAI.scavenge_start = true;
}

::BotAI.Events.OnGameEvent_bot_player_replace <- function(event) {
	local player = GetPlayerFromUserID(event.player);
	NetProps.SetPropInt(player, "m_hViewEntity", -1);
}

::BotAI.Events.OnGameEvent_weapon_drop <- function(event) {
	local player = GetPlayerFromUserID(event.userid);
	
	if("item" in event)
	{
		local item = event.item;
		if(item != null && (item == "weapon_gascan" || item == "gascan"))
		{
			if(BotAI.IsPlayerEntityValid(player) && player.IsSurvivor() && IsPlayerABot(player) && BotAI.IsBotGasFinding(player))
			{
				BotAI.SetBotGasFinding(player, 0);
			}
		}
	}
}

::BotAI.Events.OnGameEvent_finale_start <- function(event)
{
	BotAI.FinaleStart = true;
}

::BotAI.Events.OnGameEvent_gauntlet_finale_start <- function(event)
{
	BotAI.FinaleStart = true;
}

::BotAI.Events.OnGameEvent_finale_radio_start <- function(event)
{
	BotAI.FinaleStart = true;
}

::BotAI.Events.OnGameEvent_round_end <- function(event)
{
	BotAI.SaveSetting();
	BotAI.SaveUseTarget();
	BotAI.GiveUpPlayer(false);
}

::BotAI.Events.OnGameEvent_map_transition <- function(event)
{
	BotAI.SaveSetting();
	BotAI.SaveUseTarget();
	BotAI.GiveUpPlayer(false);
}

::BotAI.Events.OnGameEvent_molotov_thrown <- function(event)
{
	local attacker = GetPlayerFromUserID(event.userid);
	
	BotAI.debugParam1 = attacker.GetOrigin();
}

::BotAI.Events.OnGameEvent_ability_use <- function(event)
{
	local attacker = GetPlayerFromUserID(event.userid);
	
	if(BotAI.GetTarget(attacker) != null)
		BotAI.BotAttack(BotAI.GetTarget(attacker), attacker);
	if(event.ability == "ability_tongue")
		BotAI.smokerTongue[attacker.GetEntityIndex()] <- 0;
}

::BotAI.Events.OnGameEvent_entity_shoved <- function(event)
{
	if(!("entityid" in event))
		return;
	
	victim <- Ent(event.entityid);
	attacker <- GetPlayerFromUserID(event.attacker);
	
	if(victim == null || (victim != null && victim.GetClassname() != "infected"))
		return;

	if(BotAI.IsPlayerEntityValid(attacker) && attacker.IsSurvivor() && IsPlayerABot(attacker) && !attacker.IsDead()) {
			BotAI.applyDamage(attacker, victim, 15, DMG_HEADSHOT);
		if(BotAI.IsAlive(victim)) 
		BotAI.applyPushVelocity(attacker, victim);
	}
}

function ChatTriggers::morebot( player, args, text )
{
	MoreBotCmd( player, args, text );
}

function ChatTriggers::botstop( player, args, text )
{
	BotStopCmd( player, args, text );
}

function ChatTriggers::botaitest( player, args, text )
{
	BotAITestCmd( player, args, text );
	BotAI.SaveSetting();
}

function ChatTriggers::botfindgas( player, args, text )
{
	BotGascanFindCmd( player, args, text );
	BotAI.SaveSetting();
}

function ChatTriggers::botthrow( player, args, text )
{
	BotThrowGrenadeCmd( player, args, text );
	BotAI.SaveSetting();
}

function ChatTriggers::botimmunity( player, args, text )
{
	BotImmunityCmd( player, args, text );
	BotAI.SaveSetting();
}

function ChatTriggers::botescort( player, args, text )
{
	BotPathFindingCmd( player, args, text );
	BotAI.SaveSetting();
}

function ChatTriggers::botunstick( player, args, text )
{
	BotUnstickCmd( player, args, text );
	BotAI.SaveSetting();
}

function ChatTriggers::botmelee( player, args, text )
{
	BotMeleeCmd( player, args, text );
	BotAI.SaveSetting();
}

function ChatTriggers::botversus( player, args, text )
{
	BotVersusModCmd( player, args, text );
	BotAI.SaveSetting();
}

function ChatTriggers::botmenu( player, args, text )
{
	BotMenuCmd( player, args, text );
}

function ChatTriggers::FractureRay( player, args, text )
{
	BotFractureRayCmd( player, args, text );
	BotAI.SaveSetting();
}

function ChatTriggers::imbot( player, args, text ) {
	if (typeof player == "VSLIB_PLAYER")
		player = player.GetBaseEntity();
		
	if(player in BotAI.humanBot)
		delete BotAI.humanBot[player];
	else 
		BotAI.humanBot[player] <- player;
}

function ChatTriggers::botnotice( player, args, text )
{
	BotAI.Notice_Text = false;
	BotAI.EasyPrint("通告已关闭.");
	BotAI.SaveSetting();
}

function ChatTriggers::botper( player, args, text ) {
	BotAI.BotPerformanceCmd();
}

function ChatTriggers::botcrash( player, args, text ) {
	local function makeCrash(i) {
		i.tryMakeACrash();
	}
	
	BotAI.Timers.AddTimerByName("makeCrash-" + UniqueString(), 0.5, true, makeCrash, player);
}

function ChatTriggers::bothooktest( player, args, text ) {
	BotAI.hookTest = true;
	printl("[Bot AI] chat&damage hooked.");
}

function ChatTriggers::bottask( player, args, text ) {
	if(args) {
		if(args[0] in BotAI.disabledTask)
			delete BotAI.disabledTask[args[0]];
		else
			BotAI.disabledTask[args[0]] <- 0;
	}
}

function VSLib::EasyLogic::OnTakeDamage::BotAITakeDamage(damageTable)
{
	attacker <- damageTable.Attacker;
	victim <- damageTable.Victim;
	if(victim != null && BotAI.IsPlayerEntityValid(attacker) && !attacker.IsSurvivor() && attacker.GetZombieType() == 8) {
		if("GetClassname" in victim && victim.GetClassname() == "prop_physics") {
			BotAI.ListAvoidCar[victim.GetEntityIndex()] <- CarAvoid(victim);
			return true;
		}
	}

	if(victim != null && BotAI.IsPlayerEntityValid(victim) && victim.IsSurvivor() && IsPlayerABot(victim) && !victim.IsDominatedBySpecialInfected()) {
		if(BotAI.isPlayerNearLadder(victim)) {
			if(damageTable.DamageType == DMG_FALL)
				return false;
		}
		
		if(damageTable.DamageDone >= 100) {
			local noneAliveEntity = damageTable.Attacker == null || 
			(damageTable.Attacker.GetClassname() != "player" && damageTable.Attacker.GetClassname() != "infected" && damageTable.Attacker.GetClassname() != "witch")

			if(noneAliveEntity) {
				printl("damage " + damageTable.DamageDone + " attacker " + damageTable.Attacker);
				local validPlayer = null;
				foreach(sur in BotAI.SurvivorList) {
					if(sur != victim && BotAI.IsPlayerEntityValid(sur) && sur.IsSurvivor() && BotAI.IsOnGround(sur) && 
					(validPlayer == null || BotAI.distanceof(validPlayer.GetOrigin(), victim.GetOrigin()) > BotAI.distanceof(sur.GetOrigin(), victim.GetOrigin())))
						validPlayer = sur;
				}

				if(validPlayer != null) {
					victim.SetOrigin(validPlayer.GetOrigin());
					return false;
				} else {
					local area = NavMesh.GetNearestNavArea(victim.GetOrigin(), 500, true, true);
					if(area) {
						victim.SetOrigin(area.FindRandomSpot());
						return false;
					}
				}
			}
		}
	}

	if(BotAI.IsPlayerEntityValid(victim) && victim.IsSurvivor() && IsPlayerABot(victim) && BotAI.IsEntityValid(attacker) && attacker.GetClassname() == "infected") {
		if(BotAI.IsPlayerReviving(victim)) {
			local player = BotAI.getPlayerRevived(victim);
			if(BotAI.IsPlayerEntityValid(player)) {
				player.TakeDamageEx(damageTable.Inflictor, damageTable.Attacker, damageTable.Weapon, player.GetOrigin() - damageTable.Location, damageTable.Location, damageTable.DamageDone, damageTable.DamageType);
				return false;
			}
		}
		
		local factor = (1 + BotAI.xyDotProduct(victim.EyeAngles().Forward(), BotAI.normalize(victim.GetOrigin() - attacker.GetOrigin()))) / 2;
		local minDamage = damageTable.DamageDone / 4;
		damageTable.DamageDone = factor * damageTable.DamageDone;
		if(damageTable.DamageDone < minDamage)
			damageTable.DamageDone = minDamage;
	}
	
	if(victim != null && BotAI.IsPlayerEntityValid(attacker) && attacker.IsSurvivor() && IsPlayerABot(attacker))
	{
		if(BotAI.IsPlayerEntityValid(victim) && victim.IsSurvivor())
		{
			damageTable.DamageDone = 0;
			return false;
		}
		
		if("GetClassname" in victim && victim.GetClassname() == "weapon_oxygentank")
		{
			damageTable.DamageDone = 0;
			return false;
		}
		
		if("GetClassname" in victim && victim.GetClassname() == "weapon_propanetank")
		{
			damageTable.DamageDone = 0;
			return false;
		}
		
		if("GetClassname" in victim && victim.GetClassname() == "weapon_gascan")
		{
			damageTable.DamageDone = 0;
			return false;
		}
		
		if("GetClassname" in victim && victim.GetClassname() == "prop_fuel_barrel")
		{
			damageTable.DamageDone = 0;
			return false;
		}
	}
	
	if(BotAI.Immunity && BotAI.IsPlayerEntityValid(attacker) && !IsPlayerABot(attacker) && attacker.IsSurvivor() && BotAI.IsPlayerEntityValid(victim) && IsPlayerABot(victim) && victim.IsSurvivor())
	{
		return false;
	}

	if(victim != null && BotAI.IsPlayerEntityValid(attacker) && IsPlayerABot(attacker) && attacker.IsSurvivor())
	{
		if(damageTable.DamageDone > 1 && victim.IsValid() && victim.GetClassname() == "witch")
		{
			WitchState <- NetProps.GetPropInt(victim, "m_nSequence");
			if(WitchState == ANIM_SITTING_CRY || WitchState == ANIM_SITTING_STARTLED || WitchState == ANIM_SITTING_AGGRO || WitchState == ANIM_WALK || WitchState == ANIM_WANDER_WALK) {
					damageTable.DamageDone == 0;
					return false;
			}
		}

		if(victim.IsValid() && victim.GetClassname() == "infected") {
			local infecTarget = BotAI.GetTarget(victim);
			if(BotAI.IsEntitySI(infecTarget)) {
				infecTarget.TakeDamageEx(victim, damageTable.Attacker, damageTable.Weapon, infecTarget.GetOrigin() - attacker.GetOrigin(), damageTable.Location, damageTable.DamageDone, damageTable.DamageType);
				if(infecTarget.GetZombieType() == 8)
					damageTable.DamageDone = damageTable.DamageDone / 5;
			}
		}
	}
	
	return true;
}
