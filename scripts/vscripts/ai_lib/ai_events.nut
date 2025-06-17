::BotAI.Events.OnGameEvent_item_pickup <- function(event) {
	local p = GetPlayerFromUserID(event.userid);
	local item = event.item;
	if((item == "first_aid_kit_spawn" || item == "first_aid_kit" || item == "weapon_first_aid_kit_spawn" || item == "weapon_first_aid_kit" )&& p.IsSurvivor() && IsPlayerABot(p))
		BotAI.doAmmoUpgrades(p);
}

::BotAI.Events.OnGameEvent_player_say <- function(event) {
	local player = GetPlayerFromUserID(event.userid);
	local text = event.text;
}

::BotAI.Events.OnGameEvent_player_transitioned <- function(event) {
	local player = GetPlayerFromUserID(event.userid);
	if(!BotAI.IsEntitySurvivor(player)) return;
	BotAI.itemPassingCooldown[player] <- 20;
}

::BotAI.Events.OnGameEvent_player_spawn <- function(event) {
	local player = GetPlayerFromUserID(event.userid);
	if(BotAI.IsEntitySurvivorBot(player)) {
		BotAI.createPlayerTargetTimer(player);
		BotAI.createSeacherTimer(player);
	}

	if(!BotAI.IsEntityValid(player)) return;

	local team = NetProps.GetPropInt(player, "m_iTeamNum");
	local l4d1Bot = false;
	if (team == 4 && (BotAI.MapName == "c6m1_riverbank" || BotAI.MapName == "c6m3_port"))
		l4d1Bot = true;

	if(BotAI.IsPlayerEntityValid(player) && player.IsSurvivor() && !l4d1Bot) {
		BotAI.SurvivorList[event.userid] <- player;
		if(IsPlayerABot(player))
			BotAI.SurvivorBotList[event.userid] <- player;
		else
			BotAI.SurvivorHumanList[event.userid] <- player;
	}

	if(BotAI.IsPlayerEntityValid(player) && !player.IsSurvivor()) {
		if(IsPlayerABot(player))
			BotAI.SpecialBotList[event.userid] <- player;
		BotAI.SpecialList[event.userid] <- player;
	}
}

::BotAI.Events.OnGameEvent_defibrillator_begin <- function(event) {
	local player = GetPlayerFromUserID(event.userid);
	BotAI.setBotHealingTime(player, Time());
	if(BotAI.IsPlayerEntityValid(player) && IsPlayerABot(player)) {
		player.UseAdrenaline(2);
		BotAI.UnforceButton(player, 1);
		BotAI.ForceButton(player, 1 , 4, true);
		BotAI.AddFlag(player, FL_FROZEN );
	}
}

::BotAI.Events.OnGameEvent_defibrillator_used <- function(event) {
	local player = GetPlayerFromUserID(event.userid);
	if(BotAI.IsPlayerEntityValid(player) && IsPlayerABot(player)) {
		BotAI.UnforceButton(player, 1);
		BotAI.RemoveFlag(player, FL_FROZEN );
	}
}

::BotAI.Events.OnGameEvent_defibrillator_used_fail <- function(event) {
	local player = GetPlayerFromUserID(event.userid);
	if(BotAI.IsPlayerEntityValid(player) && IsPlayerABot(player)) {
		BotAI.UnforceButton(player, 1);
		BotAI.RemoveFlag(player, FL_FROZEN );
	}
}

//Fix a problem when bot using defibrillator
::BotAI.Events.OnGameEvent_defibrillator_interrupted <- function(event) {
	local player = GetPlayerFromUserID(event.userid);
	local body = GetPlayerFromUserID(event.subject);

	if(BotAI.IsPlayerEntityValid(player) && IsPlayerABot(player)) {
		BotAI.UnforceButton(player, 1);
		BotAI.RemoveFlag(player, FL_FROZEN );

		if (BotAI.IsPlayerEntityValid(body)) {
			local lastTime = BotAI.getBotHealingTime(player);
			if(Time() - lastTime >= 2) {
				body.ReviveByDefib();
				BotAI.removeItem(player, "defibrillator");
			}
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

	BotAI.SetBotHealing(bot, null);
}

::BotAI.Events.OnGameEvent_player_jump <- function(event) {
	local bot = GetPlayerFromUserID(event.userid);

}

::BotAI.Events.OnGameEvent_player_jump_apex <- function(event) {
	local bot = GetPlayerFromUserID(event.userid);

}

::BotAI.Events.OnGameEvent_bullet_impact <- function(event) {
	if (BotAI.BotCombatSkill < 1) {
		return;
	}
	local bot = GetPlayerFromUserID(event.userid);
	local vec = Vector(event.x, event.y, event.z);
	if(BotAI.IsEntitySurvivorBot(bot)) {
		local target = BotAI.GetTarget(bot);
		local r = 255;
		local g = 0;
		local b = 0;
		if(BotAI.IsAlive(target)) {
			local TtoI = BotAI.distanceof(target.GetCenter(), vec);
			local TtoB = BotAI.distanceof(target.GetCenter(), bot.EyePosition());
			local ItoB = BotAI.distanceof(vec, bot.EyePosition());
			if(TtoI < 200 || TtoB + 200 > ItoB) {
				r = 0;
				g = 255;
			} else if (bot.GetActiveWeapon() != null) {
				local weaponName = bot.GetActiveWeapon().GetClassname();
				BotAI.applyDamageEx(bot, target, BotAI.getDamage(weaponName) * 0.1 * BotAI.BotCombatSkill, BotAI.headshotDmg);
			}

			if(BotAI.BotDebugMode) {
				DebugDrawBox(target.GetCenter(), Vector(-1, -1, -1), Vector(1, 1, 1), 0, 0, 255, 0.2, 1);
				DebugDrawLine(target.GetCenter(), vec, 255, 255, 255, false, 1);
				DebugDrawBox(vec, Vector(-2, -2, -2), Vector(2, 2, 2), r, g, b, 0.2, 1);
			}
		}
	}
}

::BotAI.Events.OnGameEvent_weapon_fire <- function(event) {
	local p = GetPlayerFromUserID(event.userid);
	local victim = BotAI.getBotLookAt(p);
	local weaponName = "weapon_" + event.weapon;

	/*
	if("weapon" in event && event.weapon.find("claw") != null && !p.IsSurvivor()) {
		foreach(bot in BotAI.SurvivorBotList) {
			if(BotAI.IsPlayerClimb(bot) || bot.IsIncapacitated() || bot.IsDominatedBySpecialInfected() || BotAI.isPlayerBeingRevived(bot))
				continue;
		}
		return;
	}
	*/

	if(p != null && p.IsSurvivor() && (IsPlayerABot(p) || BotAI.BotDebugMode)) {
		if(IsDedicatedServer() && (weaponName.find("pipe_bomb") != null || weaponName.find("molotov") != null || weaponName.find("vomitjar") != null)) {
			local invPlayer = BotAI.GetHeldItems(p);
			local hasBomb = ("slot2" in invPlayer);

			local function deleteBomb() {
				local _invPlayer = BotAI.GetHeldItems(p);
				local _hasBomb = ("slot2" in _invPlayer);
				if(_hasBomb) {
					printl("killed Bomb")
					_invPlayer["slot2"].Kill();
				}
			}

			BotAI.delayTimer(deleteBomb, 0.2);

			return;
		}
		local wep = p.GetActiveWeapon();
		local isSniper = weaponName.find("shotgun") != null || weaponName.find("sniper") != null || weaponName.find("pistol") != null;

		local pass = false;
		local function counterSpecial(target, sight) {
			if(BotAI.IsEntitySurvivor(target) && target.IsDominatedBySpecialInfected()) {
				local realTarget = target.GetSpecialInfectedDominatingMe();
				if(realTarget.GetZombieType() == 5) {
					realTarget.TakeDamage(BotAI.getDamage(weaponName)*0.7, BotAI.headshotDmg, p);
					pass = true;
				} else if(realTarget.GetZombieType() == 1 && RandomInt(0, abs(BotAI.BotCombatSkill - 4) * 1.8) == 0) {
					BotAI.breakTongue(realTarget);
				}
			}

			if(sight && RandomInt(0, abs(BotAI.BotCombatSkill - 4) * 1.5) == 0 && BotAI.IsEntitySI(target) && target.GetZombieType() == 1) {
				BotAI.breakTongue(target);
			}

			if(BotAI.IsEntityValid(target) && target.GetClassname() == "tank_rock") {
				if (weaponName.find("melee") == null || BotAI.distanceof(target.GetCenter(), p.EyePosition()) < 250) {
					target.TakeDamage(300, BotAI.headshotDmg, p);
					pass = true;
				}
			}
		}

		counterSpecial(victim, true);
		if(!pass && p in BotAI.botAim) {
			counterSpecial(BotAI.botAim[p], false);
		}

		local damaged = false;

		if((weaponName.find("melee") != null || weaponName.find("chainsaw") != null) && BotAI.BotCombatSkill > 0) {
			local target = null;
			local skillFactor = BotAI.BotCombatSkill * 10;
			local range = Convars.GetFloat("melee_range") + skillFactor;
			local TD = 300;
			local additionAngle = BotAI.BotCombatSkill * 0.2;
			if (additionAngle < 0.2) {
				additionAngle = 0.2;
			}

			local damagePos = BotAI.getEntityHeadPos(p);
			damagePos = Vector(damagePos.x, damagePos.y, p.EyePosition().z);
			if(weaponName.find("chainsaw") != null) {
				TD = 50;
			}

			while(target = Entities.FindByClassnameWithin(target, "infected", p.GetOrigin(), range)) {
				if(BotAI.IsEntityValid(target) && BotAI.VectorDotProduct(BotAI.normalize(p.EyeAngles().Forward()), BotAI.normalize(target.GetOrigin() - p.GetOrigin())) > (0.5 - additionAngle)) {
					damaged = true;
					BotAI.applyDamageEx(p, target, 5000, BotAI.meleeDmg, damagePos);
					BotAI.spawnParticle("blood_impact_infected_01", target.GetOrigin() + Vector(0, 0, 50), target);
					BotAI.spawnParticle("blood_melee_slash_TP_swing", target.GetOrigin() + Vector(0, 0, 50), target);
				}
			}

			target = null;
			while(target = Entities.FindByClassnameWithin(target, "player", p.GetOrigin(), range)) {
				if (BotAI.IsEntitySI(target) && target.GetZombieType() != 8 && BotAI.distanceof(p.GetOrigin(), target.GetOrigin()) > range - skillFactor
				&& BotAI.VectorDotProduct(BotAI.normalize(p.EyeAngles().Forward()), BotAI.normalize(target.GetOrigin() - p.GetOrigin())) > (0.7 - additionAngle)) {
					damaged = true;
					BotAI.applyDamageEx(p, target, TD, BotAI.meleeDmg, damagePos);
					BotAI.spawnParticle("blood_impact_infected_01", target.GetOrigin() + Vector(0, 0, 50), target);
					BotAI.spawnParticle("blood_melee_slash_TP_swing", target.GetOrigin() + Vector(0, 0, 50), target);
				}
			}

			target = null;
			while(target = Entities.FindByClassnameWithin(target, "witch", p.GetOrigin(), range)) {
				if (BotAI.distanceof(p.GetOrigin(), target.GetOrigin()) > range - skillFactor
				&& BotAI.VectorDotProduct(BotAI.normalize(p.EyeAngles().Forward()), BotAI.normalize(target.GetOrigin() - p.GetOrigin())) > (0.7 - additionAngle)) {
					damaged = true;
					BotAI.applyDamageEx(p, target, target.GetMaxHealth() * 0.15, BotAI.witchMeleeDmg, damagePos);
					if (NetProps.GetPropInt(target, "m_lifeState" ) == 1 && target.GetHealth() <= 0) {
						target.SetHealth(0);
					}
					BotAI.applyDamageEx(p, target, 0, BotAI.witchMeleeDmg, damagePos);
					BotAI.applyDamageEx(p, target, 0, BotAI.witchMeleeDmg, damagePos);
					BotAI.applyDamageEx(p, target, 0, BotAI.witchMeleeDmg, damagePos);
					BotAI.spawnParticle("blood_impact_infected_01", target.GetOrigin() + Vector(0, 0, 50), target);
					BotAI.spawnParticle("blood_melee_slash_TP_swing", target.GetOrigin() + Vector(0, 0, 50), target);
				}
			}

			if(damaged) {
				BotAI.playSound(p, BotAI.getMeleeSound(wep.GetModelName()));
			}
		}

		if(BotAI.IsEntityValid(wep) && (BotAI.getIsMelee(p) || isSniper)) {
			local mult = 0.7;
			if(isSniper) {
				mult = 0.3;
			}

			if(BotAI.BotCombatSkill > 3) {
				mult = 0.15;
			}

			local endTime = NetProps.GetPropFloat(wep, "m_flNextPrimaryAttack");
			local nowTime = Time();
			local duration = (endTime - nowTime) * mult;

			//seems not working
			NetProps.SetPropFloat(wep, "m_flNextPrimaryAttack", nowTime + duration);
		}

		if (damaged) {
			return;
		}
	}

	if(BotAI.BotCombatSkill < 2)
		return;

	if(BotAI.IsEntityValid(victim)
		&& (victim.GetClassname() == "witch" || victim.GetClassname() == "infected" || (victim.GetClassname() == "player" && !victim.IsSurvivor()))
		&& IsPlayerABot(p)
		&& p.IsSurvivor()) {
		local weapon = p.GetActiveWeapon();
		if(!weaponName.find("melee") != null && !weaponName.find("chainsaw") != null) {
			local count = 1;
			local mult = 0.35;
			if(weapon && weaponName.find("shotgun") != null) {
				mult = 0.1;
			}

			if("count" in event)
				count = event.count;

			if(count < 1)
				count = 1;

			if(BotAI.BotCombatSkill > 2) {
				local distance = BotAI.distanceof(p.GetOrigin(), victim.GetOrigin());
				if(distance < 150)
					mult *= 1.5;
				if(distance < 100)
					mult *= 2.0;
			}

			mult = mult * BotAI.BotCombatSkill * 0.7;

			local function hit(health) {
				BotAI.applyDamage(p, victim, health);
			}

			if(victim.GetClassname() == "witch") {
				if(BotAI.witchRunning(victim) || BotAI.witchRetreat(victim)) {
					hit(BotAI.getDamage(weaponName) * count * mult * 0.5);
				} else if (BotAI.witchKilling(victim)) {
					hit(BotAI.getDamage(weaponName) * count * mult * 1.4);
				}
			}

			if(victim.GetClassname() == "infected") {
				hit(BotAI.getDamage(weaponName) * count * mult);
			}

			if(victim.GetClassname() == "player") {
				if(victim.GetZombieType() != 8) {
					hit(BotAI.getDamage(weaponName) * count * mult * 0.9);
				}
			}
		}
	}

	if(BotAI.BotCombatSkill < 3)
		return;

	if(p != null && p.IsSurvivor() && IsPlayerABot(p)) {
		local weapon = p.GetActiveWeapon();
		local maxClip = weapon.GetMaxClip1();
		local clip = NetProps.GetPropInt(weapon, "m_iClip1") + 1;
		if (clip > maxClip) {
			clip = maxClip;
		}

		if (BotAI.BotCombatSkill > 2 || weapon.GetClassname() == "weapon_pistol" || weapon.GetClassname() == "weapon_pistol_magnum") {
			NetProps.SetPropInt(weapon, "m_iClip1", clip);
		} else if (victim != null
			&& ((victim.GetClassname() == "player" && !victim.IsSurvivor())
			|| victim.GetClassname() == "witch")) {
			NetProps.SetPropInt(weapon, "m_iClip1", clip);
		} else if (RandomInt(0, 2) == 0) {
			NetProps.SetPropInt(weapon, "m_iClip1", clip);
		}
	}
}

::BotAI.Events.OnGameEvent_revive_success <- function(event) {
	if(!("subject" in event) || event.subject == null || !("userid" in event) || event.userid == null )
		return;

	local reviving = GetPlayerFromUserID(event.userid);
	local revived = GetPlayerFromUserID(event.subject);

	BotAI.SetPlayerRevived(reviving, null);
	BotAI.SetPlayerReviving(reviving, false);
	BotAI.setPlayerBeingRevived(revived, false);
}

::BotAI.Events.OnGameEvent_player_disconnect <- function(event) {
	local player = GetPlayerFromUserID(event.userid);
	if(IsPlayerABot(player))
		BotAI.botDeath(player);
	if(event.userid in BotAI.SurvivorList)
		delete BotAI.SurvivorList[event.userid];
	if(event.userid in BotAI.SurvivorBotList)
		delete BotAI.SurvivorBotList[event.userid];
	if(event.userid in BotAI.SurvivorHumanList)
		delete BotAI.SurvivorHumanList[event.userid];
	if(event.userid in BotAI.SpecialBotList)
		delete BotAI.SpecialBotList[event.userid];
	if(event.userid in BotAI.SpecialList)
		delete BotAI.SpecialList[event.userid];
}

::BotAI.Events.OnGameEvent_player_death <- function(event) {
	local victim = null;

	if("userid" in event) {
		victim = GetPlayerFromUserID(event.userid);
		if(event.userid in BotAI.SurvivorList)
			delete BotAI.SurvivorList[event.userid];
		if(event.userid in BotAI.SurvivorBotList)
			delete BotAI.SurvivorBotList[event.userid];
		if(event.userid in BotAI.SurvivorHumanList)
			delete BotAI.SurvivorHumanList[event.userid];
		if(event.userid in BotAI.SpecialBotList)
			delete BotAI.SpecialBotList[event.userid];
		if(event.userid in BotAI.SpecialList)
			delete BotAI.SpecialList[event.userid];
	}

	if(victim != null && IsPlayerABot(victim) && victim.IsSurvivor()) {
		BotAI.botDeath(victim);
	}
}

::BotAI.Events.OnGameEvent_revive_begin <- function(event) {
	local reviving = GetPlayerFromUserID(event.userid);
	local revived = GetPlayerFromUserID(event.subject);

	BotAI.SetPlayerRevived(reviving, revived);
	BotAI.SetPlayerReviving(reviving, true);
	BotAI.setPlayerBeingRevived(revived, true);
	BotAI.setBotHealingTime(reviving, Time());
}

//Fix a problem when bot revive
::BotAI.Events.OnGameEvent_revive_end <- function(event) {
	local reviving = GetPlayerFromUserID(event.userid);
	local revived = GetPlayerFromUserID(event.subject);

	if(BotAI.IsPlayerEntityValid(reviving) && IsPlayerABot(reviving) && BotAI.IsPlayerEntityValid(revived)) {
		local lastTime = BotAI.getBotHealingTime(reviving);
		if(Time() - lastTime >= 3)
			revived.ReviveFromIncap();
	}

	BotAI.setPlayerBeingRevived(revived, false);
	BotAI.SetPlayerRevived(reviving, null);
	BotAI.SetPlayerReviving(reviving, false);
}

::BotAI.Events.OnGameEvent_heal_begin <- function(event) {
	BotAI.setBotHealingTime(GetPlayerFromUserID(event.userid), Time());
	BotAI.SetBotHealing(GetPlayerFromUserID(event.userid), GetPlayerFromUserID(event.subject));
}

::BotAI.Events.OnGameEvent_heal_end <- function(event) {
	BotAI.SetBotHealing(GetPlayerFromUserID(event.userid), null);
}

::BotAI.Events.OnGameEvent_witch_harasser_set <- function(event) {
	if(!("witchid" in event) || event.witchid == null || !("userid" in event) || event.userid == null )
		return;

	local attacker = GetPlayerFromUserID(event.userid);
	local victim = Ent(event.witchid);
	local mp_gamemode = Convars.GetStr("mp_gamemode");

	if(BotAI.BotDebugMode)
		printl(mp_gamemode);

	if(victim != null && BotAI.IsPlayerEntityValid(attacker) && IsPlayerABot(attacker) && attacker.IsSurvivor()) {
		if(mp_gamemode == "realism") {
			BotAI.applyDamage(attacker, victim, 75);
		}
	}
}

::BotAI.Events.OnGameEvent_charger_carry_start <- function(event) {
	if(!("victim" in event) || event.victim == null || !("userid" in event) || event.userid == null)
		return;

	if (BotAI.BotCombatSkill > 3) {
		local victim = GetPlayerFromUserID(event.victim);

		if (BotAI.IsEntitySurvivorBot(victim)) {
			local inventory = BotAI.GetHeldItems(victim);

			if ("slot1" in inventory) {
				local offhandItem = inventory["slot1"];
				if (offhandItem.GetClassname() == "weapon_melee") {
					local attacker = GetPlayerFromUserID(event.userid);
					local damagePos = BotAI.getEntityHeadPos(victim);
					damagePos = Vector(damagePos.x, damagePos.y, victim.EyePosition().z);
					BotAI.applyDamageEx(victim, attacker, 300, BotAI.meleeDmg, damagePos);
					BotAI.spawnParticle("blood_impact_infected_01", attacker.GetOrigin() + Vector(0, 0, 50), attacker);
					BotAI.spawnParticle("blood_melee_slash_TP_swing", attacker.GetOrigin() + Vector(0, 0, 50), attacker);
					BotAI.playSound(victim, BotAI.getMeleeSound(offhandItem.GetModelName()));
				}
			}
		}
	}
}

::BotAI.Events.OnGameEvent_charger_pummel_start <- function(event) {
	if(!("victim" in event) || event.victim == null || !("userid" in event) || event.userid == null)
		return;

	local victim = GetPlayerFromUserID(event.victim);
	if (BotAI.BotCombatSkill > 3 && BotAI.IsEntitySurvivorBot(victim)) {
		local inventory = BotAI.GetHeldItems(victim);

		if ("slot1" in inventory) {
			local offhandItem = inventory["slot1"];
			if (offhandItem.GetClassname() == "weapon_melee") {
				local attacker = GetPlayerFromUserID(event.userid);
				local damagePos = BotAI.getEntityHeadPos(victim);
				damagePos = Vector(damagePos.x, damagePos.y, victim.EyePosition().z);
				BotAI.applyDamageEx(victim, attacker, 300, BotAI.meleeDmg, damagePos);
				BotAI.spawnParticle("blood_impact_infected_01", attacker.GetOrigin() + Vector(0, 0, 50), attacker);
				BotAI.spawnParticle("blood_melee_slash_TP_swing", attacker.GetOrigin() + Vector(0, 0, 50), attacker);
				BotAI.playSound(victim, BotAI.getMeleeSound(offhandItem.GetModelName()));
			}
		}
	}

	BotAI.SurvivorTrapped[victim.GetEntityIndex()] <- victim;
	BotAI.SurvivorTrappedTimed[victim.GetEntityIndex()] <- victim;
}

::BotAI.Events.OnGameEvent_charger_pummel_end <- function(event) {
	if(!("victim" in event) || event.victim == null)
		return;
	local victim = GetPlayerFromUserID(event.victim);

	BotAI.SurvivorTrapped[victim.GetEntityIndex()] <- null;
	BotAI.SurvivorTrappedTimed[victim.GetEntityIndex()] <- null;
}

::BotAI.Events.OnGameEvent_choke_start <- function(event) {
	if(!("victim" in event) || event.victim == null)
		return;

	local victim = GetPlayerFromUserID(event.victim);

	BotAI.SurvivorTrapped[victim.GetEntityIndex()] <- victim;
	BotAI.SurvivorTrappedTimed[victim.GetEntityIndex()] <- victim;
}

::BotAI.Events.OnGameEvent_choke_stopped <- function(event) {
	if(!("victim" in event) || event.victim == null)
		return;
	local victim = GetPlayerFromUserID(event.victim);

	BotAI.SurvivorTrapped[victim.GetEntityIndex()] <- null;
	BotAI.SurvivorTrappedTimed[victim.GetEntityIndex()] <- null;
}

::BotAI.Events.OnGameEvent_choke_end <- function(event)
{
	if(!("victim" in event) || event.victim == null)
		return;
	local victim = GetPlayerFromUserID(event.victim);

	BotAI.SurvivorTrapped[victim.GetEntityIndex()] <- null;
	BotAI.SurvivorTrappedTimed[victim.GetEntityIndex()] <- null;
}

::BotAI.Events.OnGameEvent_tongue_grab <- function(event) {
	if(!("victim" in event) || !("userid" in event))
		return;
	local attacker = GetPlayerFromUserID(event.userid);
	local victim = GetPlayerFromUserID(event.victim);
	BotAI.setContext(attacker, "BOTAI_BREAK", 1.5);

	if (BotAI.BotCombatSkill > 2 && BotAI.IsEntitySurvivorBot(victim) && RandomInt(0, BotAI.BotCombatSkill - 1) > 0) {
		NetProps.SetPropEntity(attacker, "m_tongueVictim", -1);
		NetProps.SetPropEntity(victim, "m_tongueOwner", -1);
		return;
	}

	local shouldShove = false;
	local needShove = BotAI.needOil;
	local display = null;

	if(BotAI.IsEntitySurvivorBot(victim) && BotAI.UseTarget != null && BotAI.NeedGasFinding && needShove && RandomInt(0, 4) > 0) {
		shouldShove = true;
	}

	if (shouldShove) {
		NetProps.SetPropEntity(attacker, "m_tongueVictim", -1);
		NetProps.SetPropEntity(victim, "m_tongueOwner", -1);
		return;
	}

	if(attacker.GetEntityIndex() in BotAI.smokerTongue) {
		delete BotAI.smokerTongue[attacker.GetEntityIndex()];

		if(BotAI.IsEntitySurvivorBot(victim) && BotAI.IsPressingAttack(victim) && BotAI.IsTarget(attacker, victim) && BotAI.getIsMelee(victim)) {
			NetProps.SetPropEntity(attacker, "m_tongueVictim", -1);
			NetProps.SetPropEntity(victim, "m_tongueOwner", -1);
			return;
		}
	}

	if(IsPlayerABot(victim))
		BotAI.BotAttack(victim, attacker);

	BotAI.SurvivorTrapped[victim.GetEntityIndex()] <- victim;
	BotAI.SurvivorTrappedTimed[victim.GetEntityIndex()] <- victim;
	local function addTimed(vic) {
		BotAI.SurvivorTrappedTimed[vic.GetEntityIndex()] <- null;
	}

	BotAI.Timers.AddTimerByName("addTimed-" + victim.GetEntityIndex(), 0.5, false, addTimed, victim);
}

::BotAI.Events.OnGameEvent_tongue_release <- function(event) {
	local attacker = GetPlayerFromUserID(event.userid);
	if(attacker.GetEntityIndex() in BotAI.smokerTongue)
		delete BotAI.smokerTongue[attacker.GetEntityIndex()];
	if(!("victim" in event) || event.victim == null)
		return;
	local victim = GetPlayerFromUserID(event.victim);

	if(victim != null && "GetEntityIndex" in victim) {
		BotAI.SurvivorTrapped[victim.GetEntityIndex()] <- null;
		BotAI.SurvivorTrappedTimed[victim.GetEntityIndex()] <- null;
	}
}

::BotAI.Events.OnGameEvent_tongue_broke_bent <- function(event) {
	local attacker = GetPlayerFromUserID(event.userid);
	if(attacker.GetEntityIndex() in BotAI.smokerTongue)
		delete BotAI.smokerTongue[attacker.GetEntityIndex()];
}

::BotAI.Events.OnGameEvent_jockey_ride <- function(event) {
	if(!("victim" in event) || event.victim == null)
		return;

	local victim = GetPlayerFromUserID(event.victim);
	local attacker = GetPlayerFromUserID(event.userid);

	local shouldShove = BotAI.BotCombatSkill > 2 && BotAI.IsEntitySurvivorBot(victim) && RandomInt(0, BotAI.BotCombatSkill * BotAI.BotCombatSkill) > 0;
	local needShove = BotAI.needOil;

	if(BotAI.IsEntitySurvivorBot(victim) && BotAI.UseTarget != null && BotAI.NeedGasFinding && needShove && RandomInt(0, 4) > 0) {
		shouldShove = true;
	}

	if (shouldShove) {
		BotAI.shoveSpecialInfected(attacker, victim);
		return;
	}

	BotAI.SurvivorTrapped[victim.GetEntityIndex()] <- victim;
	BotAI.SurvivorTrappedTimed[victim.GetEntityIndex()] <- victim;
	local function addTimed(vic) {
		BotAI.SurvivorTrappedTimed[vic.GetEntityIndex()] <- null;
	}

	BotAI.Timers.AddTimerByName("addTimed-" + victim.GetEntityIndex(), 0.5, false, addTimed, victim);
}

::BotAI.Events.OnGameEvent_jockey_ride_end <- function(event) {
	if(!("victim" in event) || event.victim == null)
		return;
	local victim = GetPlayerFromUserID(event.victim);

	BotAI.SurvivorTrapped[victim.GetEntityIndex()] <- null;
	BotAI.SurvivorTrappedTimed[victim.GetEntityIndex()] <- null;
}

::BotAI.Events.OnGameEvent_lunge_pounce <- function(event) {
	if(!("victim" in event) || event.victim == null)
		return;

	local victim = GetPlayerFromUserID(event.victim);
	local attacker = GetPlayerFromUserID(event.userid);

	local shouldShove = BotAI.BotCombatSkill > 2 && BotAI.IsEntitySurvivorBot(victim) && RandomInt(0, BotAI.BotCombatSkill * BotAI.BotCombatSkill) > 0;
	local needShove = BotAI.needOil;

	if(BotAI.IsEntitySurvivorBot(victim) && BotAI.UseTarget != null && BotAI.NeedGasFinding && needShove && RandomInt(0, 4) > 0) {
		shouldShove = true;
	}

	if (shouldShove) {
		BotAI.shoveSpecialInfected(attacker, victim);
		return;
	}

	BotAI.SurvivorTrapped[victim.GetEntityIndex()] <- victim;
	BotAI.SurvivorTrappedTimed[victim.GetEntityIndex()] <- victim;
	local function addTimed(vic) {
		BotAI.SurvivorTrappedTimed[vic.GetEntityIndex()] <- null;
	}

	BotAI.Timers.AddTimerByName("addTimed-" + victim.GetEntityIndex(), 0.5, false, addTimed, victim);
}

::BotAI.Events.OnGameEvent_pounce_stopped <- function(event) {
	if(!("victim" in event) || event.victim == null)
		return;
	local victim = GetPlayerFromUserID(event.victim);

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
	local victim = GetPlayerFromUserID(event.victim);

	BotAI.SurvivorTrapped[victim.GetEntityIndex()] <- null;
	BotAI.SurvivorTrappedTimed[victim.GetEntityIndex()] <- null;
}

::BotAI.Events.OnGameEvent_player_now_it <- function(event)
{
	if(!("userid" in event) || event.userid == null)
		return;

	local victim = GetPlayerFromUserID(event.userid);
	if(BotAI.IsEntityValid(victim))
	{
		if(!(victim.GetEntityIndex() in BotAI.VomitList))
			BotAI.VomitList[victim.GetEntityIndex()] <- true;
		else
			BotAI.VomitList[victim.GetEntityIndex()] = true;
	}
}

::BotAI.Events.OnGameEvent_player_no_longer_it <- function(event) {
	if(!("userid" in event) || event.userid == null)
		return;

	local victim = GetPlayerFromUserID(event.userid);
	if(BotAI.IsEntityValid(victim) && victim.GetEntityIndex() in BotAI.VomitList)
		BotAI.VomitList[victim.GetEntityIndex()] = false;
}

::BotAI.Events.OnGameEvent_player_entered_checkpoint <- function(event) {
	if(!("userid" in event) || event.userid == null)
		return;
		local player = GetPlayerFromUserID(event.userid);
		if(player.IsSurvivor())
			BotAI.SetPlayerAtCheckPoint(player, true);
}

::BotAI.Events.OnGameEvent_player_left_checkpoint <- function(event) {
	if(!("userid" in event) || event.userid == null)
		return;
		local player = GetPlayerFromUserID(event.userid);
		if(player.IsSurvivor())
			BotAI.SetPlayerAtCheckPoint(player, false);
}

::BotAI.Events.OnGameEvent_player_shoved <- function(event) {
	local victim = GetPlayerFromUserID(event.userid);
	local attacker = GetPlayerFromUserID(event.attacker);

	if(BotAI.IsPlayerEntityValid(attacker) && attacker.IsSurvivor() && IsPlayerABot(attacker) && !attacker.IsDead() && BotAI.IsPlayerEntityValid(victim) && !victim.IsSurvivor() && IsPlayerABot(victim) && !victim.IsDead()) {
		if(BotAI.IsOnGround(victim)) {
			victim.SetSenseFlags(victim.GetSenseFlags() | BOT_CANT_SEE);
			::BotAI.Timers.AddTimer(1.4, false, BotAI.EnableSight {infect = victim});
		}
		BotAI.applyPushVelocity(attacker, victim);
	}

	if(BotAI.IsPlayerEntityValid(attacker) && attacker.IsSurvivor() && !IsPlayerABot(attacker) && !attacker.IsDead() && BotAI.IsPlayerEntityValid(victim) && victim.IsSurvivor() && IsPlayerABot(victim) && !victim.IsDead()) {
		local weapon = attacker.GetActiveWeapon();
		local ename = weapon.GetClassname();

		local function genStrGet(str) {
			if(str == "weapon_molotov")
				return "molotov";
			if(str == "weapon_vomitjar")
				return "vomitjar";
			if(str == "weapon_pipe_bomb")
				return "pipe_bomb";
			return " ";
		}

		if(BotAI.HasItem(victim, "pipe_bomb") && (ename == "weapon_molotov" || ename == "weapon_vomitjar")) {
			BotAI.removeItem(attacker, genStrGet(ename));
			BotAI.removeItem(victim, "pipe_bomb");
			attacker.GiveItem("pipe_bomb");
			victim.GiveItem(genStrGet(ename));
			return;
		}

		if(BotAI.HasItem(victim, "molotov") && (ename == "weapon_pipe_bomb" || ename == "weapon_vomitjar")) {
			BotAI.removeItem(attacker, genStrGet(ename));
			BotAI.removeItem(victim, "molotov");
			attacker.GiveItem("molotov");
			victim.GiveItem(genStrGet(ename));
			return;
		}

		if(BotAI.HasItem(victim, "vomitjar") && (ename == "weapon_molotov" || ename == "weapon_pipe_bomb")) {
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

::BotAI.Events.OnGameEvent_player_team <- function(event) {
	local player = GetPlayerFromUserID(event.userid);

	if(BotAI.IsEntityValid(player) && event.team == 2) {
		BotAI.hookViewEntity(player, null);
	}
}

::BotAI.Events.OnGameEvent_player_ledge_grab <- function(event) {
	local player = GetPlayerFromUserID(event.userid);
	if(IsPlayerABot(player) && !("causer" in event))
		player.ReviveFromIncap();
}

::BotAI.Events.OnGameEvent_player_bot_replace <- function(event) {
	local player = GetPlayerFromUserID(event.player);
	local bot = GetPlayerFromUserID(event.bot);

	if("bot" in event) {
		if(bot.IsSurvivor()) {
			BotAI.SurvivorList[event.bot] <- bot;
			BotAI.SurvivorBotList[event.bot] <- bot;
		} else {
			BotAI.SpecialBotList[event.bot] <- bot;
		}

		BotAI.itemPassingCooldown[bot] <- 20;
	}

	if("player" in event) {
		if(event.player in BotAI.SurvivorList)
			delete BotAI.SurvivorList[event.player];
		if(event.player in BotAI.SurvivorHumanList)
			delete BotAI.SurvivorHumanList[event.player];
		if(event.player in BotAI.SpecialList)
			delete BotAI.SpecialList[event.player];
	}

	BotAI.hookViewEntity(player, null);
	BotAI.hookViewEntity(bot, null);
}

::BotAI.Events.OnGameEvent_bot_player_replace <- function(event) {
	local player = GetPlayerFromUserID(event.player);
	local bot = GetPlayerFromUserID(event.bot);

	if(bot != null && IsPlayerABot(bot)) {
		BotAI.botDeath(bot, player);
	}

	if("bot" in event) {
		if(event.bot in BotAI.SurvivorList)
			delete BotAI.SurvivorList[event.bot];
		if(event.bot in BotAI.SurvivorBotList)
			delete BotAI.SurvivorBotList[event.bot];
		if(event.bot in BotAI.SpecialBotList)
			delete BotAI.SpecialBotList[event.bot];
	}

	if(BotAI.IsPlayerEntityValid(player)) {
		if(player.IsSurvivor()) {
			BotAI.SurvivorList[event.player] <- player;
			BotAI.SurvivorHumanList[event.player] <- player;
		} else {
			BotAI.SpecialList[event.player] <- player;
		}
	}

	BotAI.hookViewEntity(player, null);
	BotAI.hookViewEntity(bot, null);
}

::BotAI.Events.OnGameEvent_finale_start <- function(event)
{
	BotAI.FinaleStart = true;
}

::BotAI.Events.OnGameEvent_gauntlet_finale_start <- function(event)
{
	BotAI.FinaleStart = true;
}

::BotAI.Events.OnGameEvent_finale_radio_start <- function(event) {
	BotAI.FinaleStart = true;
}

::BotAI.Events.OnGameEvent_round_freeze_end <- function(event) {
	printl("[Bot AI] Add Timer " + BotAI.Timers.AddTimerByName("NoticeText", 12, false, BotAI.doNoticeText));
}

::BotAI.Events.OnGameEvent_round_end <- function(event) {
	BotAI.SaveSetting();
	BotAI.SaveUseTarget();
	BotAI.GiveUpPlayer(false);
}

::BotAI.Events.OnGameEvent_map_transition <- function(event) {
	BotAI.SaveSetting();
	BotAI.SaveUseTarget();
	BotAI.GiveUpPlayer(false);
	BotAI.saveBackpack();
}

::BotAI.Events.OnGameEvent_molotov_thrown <- function(event) {
	local attacker = GetPlayerFromUserID(event.userid);

	BotAI.debugParam1 = attacker.GetOrigin();
}

::BotAI.Events.OnGameEvent_ability_use <- function(event) {
	local attacker = GetPlayerFromUserID(event.userid);

	if(BotAI.GetTarget(attacker) != null)
		BotAI.BotAttack(BotAI.GetTarget(attacker), attacker);
	if(event.ability == "ability_tongue")
		BotAI.smokerTongue[attacker.GetEntityIndex()] <- 0;
	if(event.ability == "ability_throw")
		BotAI.createRockTargetTimer();
}

::BotAI.Events.OnGameEvent_entity_shoved <- function(event) {
	if(!("entityid" in event))
		return;

	local victim = Ent(event.entityid);
	local attacker = GetPlayerFromUserID(event.attacker);

	if(victim == null || (victim != null && victim.GetClassname() != "infected"))
		return;

	if(BotAI.IsPlayerEntityValid(attacker) && attacker.IsSurvivor() && !attacker.IsDead() && IsPlayerABot(attacker)) {
		BotAI.applyDamage(attacker, victim, 15);

		if(BotAI.IsAlive(victim)) {
			BotAI.applyPushVelocity(attacker, victim);
		}
	}
}

function EasyLogic::OnUserCommand::BotAICommands( player, args, text ) {
	if (typeof player == "VSLIB_PLAYER")
		player = player.GetBaseEntity();

	if(text.find("slot") != null) {
		foreach(menu in BotAI.MainMenu) {
			if(menu._player.GetBaseEntity() != player)
				continue;
			local slot = text.slice(4);
			slot = slot.tointeger();
			slot -= menu._skipOptions;
			local close = true;
			if(slot > 0 && menu._options.len() >= slot) {
				menu._curSel = slot;

				local t = { p = menu._player, idx = menu._curSel,
				val = menu._options[menu._curSel].text, callb = menu._options[menu._curSel].callback };
				if(menu._options[menu._curSel].callback == BotEmptyCmd)
					close = false;
				::BotAI.Timers.AddTimer(0.1, 0, @(tbl) tbl.callb(tbl.p, tbl.idx, tbl.val), t);

				if(close) {
					BotAI.playSound(player, "buttons/button14.wav");
					menu.CloseMenu();

					if (menu._autoDetach)
						menu.Detach();
				}
			}
		}
	}
}

function ChatTriggers::morebot( player, args, text ) {
	MoreBotCmd( player, args, text );
}

function ChatTriggers::botstop( player, args, text ) {
	BotStopCmd( player, args, text );
}

function ChatTriggers::botskill( player, args, text ) {
	BotAISkillCmd( player, args, text );
}

function ChatTriggers::botfindgas( player, args, text ) {
	BotGascanFindCmd( player, args, text );
}

function ChatTriggers::botthrowmolotov( player, args, text ) {
	BotThrowFireCmd( player, args, text );
}

function ChatTriggers::botthrowpipe( player, args, text ) {
	BotThrowPipeBombCmd( player, args, text );
}

function ChatTriggers::botimmunity( player, args, text ) {
	BotImmunityCmd( player, args, text );
}

function ChatTriggers::botpathfinding( player, args, text ) {
	BotPathFindingCmd( player, args, text );
}

function ChatTriggers::botunstick( player, args, text ) {
	BotUnstickCmd( player, args, text );
}

function ChatTriggers::botmelee( player, args, text ) {
	BotMeleeCmd( player, args, text );
}

function ChatTriggers::botprotect( player, args, text ) {
	BotFallProtectCmd( player, args, text );
}

function ChatTriggers::botfireprotect( player, args, text ) {
	BotFireProtectCmd( player, args, text );
}

function ChatTriggers::botacidprotect( player, args, text ) {
	BotAcidProtectCmd( player, args, text );
}

function ChatTriggers::botnonaliveprotect( player, args, text ) {
	BotNonAliveProtectCmd( player, args, text );
}

function ChatTriggers::botmenu( player, args, text ) {
	BotMenuCmd( player, args, text );
}

function ChatTriggers::botkeepalive( player, args, text ) {
	BotAliveCmd( player, args, text );
}

function ChatTriggers::botbackpack( player, args, text ) {
	BotBackPackCmd( player, args, text );
}

function ChatTriggers::botdefib( player, args, text ) {
	BotDefibrillatorCmd( player, args, text );
}

function ChatTriggers::botfollow( player, args, text ) {
	BotFollowDistanceCmd( player, args, text );
}

function ChatTriggers::botteleport( player, args, text ) {
	BotTeleportDistanceCmd( player, args, text );
}

function ChatTriggers::botsaveteleport( player, args, text ) {
	BotSaveTeleportCmd( player, args, text );
}

function ChatTriggers::botwitchdamage( player, args, text ) {
	BotWitchDamageCmd( player, args, text );
}

function ChatTriggers::botspecialdamage( player, args, text ) {
	BotSpecialDamageCmd( player, args, text );
}

function ChatTriggers::bottankdamage( player, args, text ) {
	BotTankDamageCmd( player, args, text );
}

function ChatTriggers::botcommondamage( player, args, text ) {
	BotCommonDamageCmd( player, args, text );
}

function ChatTriggers::botnonalivedamage( player, args, text ) {
	BotNonAliveDamageCmd( player, args, text );
}

function ChatTriggers::botdebug( player, args, text ) {
	local speaker = player;
	if (typeof player == "VSLIB_PLAYER")
        player = player.GetBaseEntity();

	if(!ABA_IsAdmin(speaker)) {
		BotAI.SendPlayer(player, "botai_admin_only");
		return;
	}

	if(BotAI.BotDebugMode) {
		BotAI.BotDebugMode = false;
	} else {
		BotAI.BotDebugMode = true;
	}

	BotAI.SaveSetting();
}

function ChatTriggers::botnotice( player, args, text ) {
	if (BotAI.NoticeConfig) {
        BotAI.NoticeConfig = false;
        BotAI.EasyPrint("botai_notice_off");
        BotAI.SaveSetting();
    } else {
        BotAI.NoticeConfig = true;
        BotAI.EasyPrint("botai_notice_on");
        BotAI.SaveSetting();
    }
}

/*
function ChatTriggers::botcrash( player, args, text ) {
	local function makeCrash(i) {
		i.tryMakeACrash();
	}

	BotAI.Timers.AddTimerByName("makeCrash-" + UniqueString(), 0.5, true, makeCrash, player);
}
*/

function ChatTriggers::botupgrades( player, args, text ) {
	BotUseUpgradesCmd( player, args, text );
}

/*
function ChatTriggers::bottask( player, args, text ) {
	if(args) {
		if(args[0] in BotAI.disabledTask)
			delete BotAI.disabledTask[args[0]];
		else
			BotAI.disabledTask[args[0]] <- 0;
	}
}
*/

function VSLib::EasyLogic::Notifications::CanPickupObject::BotAIPickUp(vEntity, className) {
	local entity = vEntity.GetBaseEntity();
	foreach(idx, thing in BotAI.BotLinkGasCan) {
		if(entity == thing) {
			delete BotAI.BotLinkGasCan[idx];
			return true;
		}
	}
}

function BotAI::printlModifyReason(reason, table) {
	if (!BotAI.BotDebugMode) {
		return;
	}
	printl(">--------Damage Modify-------<");
	printl("  >---  " + reason + "  ---<  ");
	__DumpScope(1, table);
	printl(">----------------------------<");
}

function VSLib::EasyLogic::OnTakeDamage::BotAITakeDamage(damageTable) {
	local attacker = damageTable.Attacker;
	local inflictor = damageTable.Inflictor;
	local victim = damageTable.Victim;

	if(BotAI.IsEntitySurvivorBot(attacker) && BotAI.IsEntityValid(BotAI.backpack(attacker))) {
		local thing = BotAI.backpack(attacker);
		if(thing.GetModelName().find("gnome") != null || thing.GetClassname() == "weapon_cola_bottles") {
			damageTable.DamageDone *= 0.75;
		}
	}

	if(victim != null && BotAI.IsPlayerEntityValid(attacker) && !attacker.IsSurvivor() && attacker.GetZombieType() == 8) {
		if("GetClassname" in victim && victim.GetClassname() == "prop_physics") {
			BotAI.ListAvoidCar[victim.GetEntityIndex()] <- CarAvoid(victim);
			return true;
		}

		if(BotAI.IsPlayerEntityValid(victim) && victim.IsSurvivor() && IsPlayerABot(victim)) {
			BotAI.setContext(victim, "BOTAI_KNOCK", 1.25);

			if (BotAI.BotCombatSkill > 4) {
				local damageReduction = (BotAI.BotCombatSkill - 4) / 4.0;
				damageTable.DamageDone *= (1.0 - damageReduction);

				if (damageTable.DamageDone <= 0) {
					BotAI.printlModifyReason("high skill", damageTable);
					return false;
				}
			}
		}
	}

	if(victim != null && BotAI.IsPlayerEntityValid(victim) && victim.IsSurvivor() && IsPlayerABot(victim) && !victim.IsDominatedBySpecialInfected()) {
		if (BotAI.IsEntityValid(inflictor) && inflictor.GetClassname() in BotAI.enumGround) {
			if (BotAI.distanceof(inflictor.GetCenter(), victim.GetOrigin()) > 175) {
				return false;
			}

			if (BotAI.AcidProtect && inflictor.GetClassname() == "insect_swarm") {
				return false;
			}

			if (NetProps.HasProp(inflictor, "m_fireCount")) {
				local fireCount = NetProps.GetPropInt(inflictor, "m_fireCount");
				local isSafeFromAllFires = true;

				for (local i = 0; i < fireCount; i++) {
					local firePos = inflictor.GetOrigin() + Vector(
						NetProps.GetPropIntArray(inflictor, "m_fireXDelta", i),
						NetProps.GetPropIntArray(inflictor, "m_fireYDelta", i),
						NetProps.GetPropIntArray(inflictor, "m_fireZDelta", i)
					);

					local delta = victim.GetOrigin() - firePos;

					local xyDist = sqrt(delta.x * delta.x + delta.y * delta.y);
					local zDist = abs(delta.z);

					if (xyDist <= 40 || zDist <= 30) {
						isSafeFromAllFires = false;
						break;
					}
				}

				if (isSafeFromAllFires) {
					return false;
				}
			}
		}

		if(BotAI.isPlayerNearLadder(victim)) {
			if(damageTable.DamageType & DMG_FALL) {
				BotAI.printlModifyReason("near ladder", damageTable);
				return false;
			}
		}

		if(BotAI.FallProtect && damageTable.DamageDone >= 100) {
			local noneAliveEntity = (attacker == null || (attacker.GetClassname() != "player" && attacker.GetClassname() != "infected" && attacker.GetClassname() != "witch"));

			if(noneAliveEntity) {
				local validPlayer = null;
				foreach(sur in BotAI.SurvivorList) {
					if(sur != victim && BotAI.IsPlayerEntityValid(sur) && sur.IsSurvivor() && BotAI.IsOnGround(sur) &&
					(validPlayer == null || BotAI.distanceof(validPlayer.GetOrigin(), victim.GetOrigin()) > BotAI.distanceof(sur.GetOrigin(), victim.GetOrigin())))
						validPlayer = sur;
				}

				if(validPlayer != null) {
					victim.SetOrigin(validPlayer.GetOrigin());
					BotAI.printlModifyReason("fall protect 1", damageTable);
					return false;
				} else {
					local area = NavMesh.GetNearestNavArea(victim.GetOrigin(), 500, true, true);

					if(area) {
						victim.SetOrigin(area.FindRandomSpot());
						BotAI.printlModifyReason("fall protect 2", damageTable);
						return false;
					}
				}
			}
		}
	}

	if(BotAI.IsPlayerEntityValid(victim) && victim.IsSurvivor() && IsPlayerABot(victim)) {
		if (BotAI.IsEntityValid(attacker)) {
			if (attacker.GetClassname() == "infected") {
				if(BotAI.IsPlayerReviving(victim)) {
					local falledPlayer = null;
					local player = BotAI.getPlayerRevived(victim);
					if(!player.IsIncapacitated() && !player.IsHangingFromLedge()) {
						local findPlayer = null;
						while(findPlayer = Entities.FindByClassnameWithin(findPlayer, "player", victim.GetOrigin(), 220)) {
							if(BotAI.IsAlive(findPlayer) && (findPlayer.IsIncapacitated() || findPlayer.IsHangingFromLedge()))
								falledPlayer = findPlayer;
						}
					} else {
						falledPlayer = player;
					}

					if(BotAI.IsPlayerEntityValid(falledPlayer)) {
						RushVictim(falledPlayer, 210);
						return false;
					}
				} else {
					BotAI.BotAttack(victim, attacker);
				}
			} else if (BotAI.FireProtect && (damageTable.DamageType & DMG_BURN)) {
				BotAI.printlModifyReason("fire protect 1", damageTable);
				damageTable.DamageDone = 0;
				return false;
			} else if (attacker.GetClassname() == "player" || attacker.GetClassname() == "witch") {

			} else if (BotAI.NonAliveProtect) {
				BotAI.printlModifyReason("non alive protect 1", damageTable);
				damageTable.DamageDone = 0;
				return false;
			}
		} else if (BotAI.NonAliveProtect) {
			BotAI.printlModifyReason("non alive protect 2", damageTable);
			damageTable.DamageDone = 0;
			return false;
		} else if (BotAI.FireProtect && (damageTable.DamageType & DMG_BURN)) {
			BotAI.printlModifyReason("fire protect 2", damageTable);
			damageTable.DamageDone = 0;
			return false;
		}
	}

	if(victim != null) {
		foreach(gas in BotAI.BotLinkGasCan) {
			if(gas == victim) {
				damageTable.DamageDone = 0;
				BotAI.printlModifyReason("hit gas can", damageTable);
				return false;
			}
		}
	}

	if(victim != null && BotAI.IsPlayerEntityValid(attacker) && attacker.IsSurvivor() && IsPlayerABot(attacker)) {
		if(BotAI.IsPlayerEntityValid(victim) && victim.IsSurvivor())
			return false;

		if("GetClassname" in victim && victim.GetClassname() == "weapon_oxygentank")
			return false;

		if("GetClassname" in victim && victim.GetClassname() == "weapon_propanetank")
			return false;

		if("GetClassname" in victim && victim.GetClassname() == "weapon_gascan")
			return false;

		if("GetClassname" in victim && victim.GetClassname() == "prop_fuel_barrel")
			return false;
	}

	if(BotAI.Immunity && BotAI.IsPlayerEntityValid(attacker) && !IsPlayerABot(attacker) && attacker.IsSurvivor() && BotAI.IsPlayerEntityValid(victim) && IsPlayerABot(victim) && victim.IsSurvivor()) {
		return false;
	}

	if(BotAI.IsEntitySI(victim) && victim.GetZombieType() == 8 && victim.GetLastKnownArea() != null && victim.GetLastKnownArea().IsUnderwater() && (damageTable.DamageType & DMG_BURN)) {
		damageTable.DamageDone *= 0.75;
	}

	if(victim != null && BotAI.IsPlayerEntityValid(attacker) && IsPlayerABot(attacker) && attacker.IsSurvivor()) {
		local className = victim.GetClassname();

		if(className == "player") {
			if (victim.GetZombieType() == 8) {
				damageTable.DamageDone *= BotAI.TankDamageMultiplier;

				if(damageTable.DamageType & DMG_BURN) {
					BotAI.dontYouWannaExtinguish[victim] <- victim;
				}
			} else {
				damageTable.DamageDone *= BotAI.SpecialDamageMultiplier;

				//nerf skill 1
				if (BotAI.BotCombatSkill <= 0 && !BotAI.IsEntityValid(BotAI.getSiVictim(victim))) {
					damageTable.DamageDone *= 0.8;
				}
			}

			if (BotAI.playerLive <= 2) {
				damageTable.DamageDone *= 1.5;
			}
		} else if(className == "infected") {
			damageTable.DamageDone *= BotAI.CommonDamageMultiplier;
		} else if(victim.IsValid() && className == "witch") {
			if (damageTable.DamageDone > 1) {
				damageTable.DamageDone *= BotAI.WitchDamageMultiplier;

				if(!BotAI.witchKilling(victim) && !BotAI.witchRetreat(victim) && !BotAI.witchRunning(victim)) {
					damageTable.DamageDone == 0;
					return false;
				}
			}
		} else {
			damageTable.DamageDone *= BotAI.NonAliveDamageMultiplier;
		}
	}

	return true;
}