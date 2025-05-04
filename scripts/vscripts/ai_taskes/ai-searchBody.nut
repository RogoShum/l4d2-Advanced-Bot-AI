class ::AITaskSearchBody extends AITaskGroup
{
	constructor(orderIn, tickIn, compatibleIn, forceIn)
    {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
    }

	updating = false;
	playerList = {};
	GUY = null;
	ironBanner = null;
	fallen = {};

	function preCheck() {
		if(!BotAI.Defibrillator)
			return false;
		if(BotAI.IsEntityValid(GUY)) {
			if(!BotAI.IsAlive(GUY) || GUY.IsIncapacitated() || BotAI.IsInCombat(GUY)) {
				GUY = null;
				BotAI.setBotLockTheard(GUY, -1);
			}
		}

		if(BotAI.IsEntityValid(ironBanner) && ironBanner.GetClassname() == "survivor_death_model") {
			if(BotAI.isDeathStillAlive(ironBanner)) {
				ironBanner = null;
			} else
				return true;
		} else
			ironBanner = null;

		local deathBody = null;
		local bodys = {};
		local unreachable = {};
		foreach(idx, val in BotAI.UnreachableDeath) {
			if(BotAI.IsEntityValid(idx))
				unreachable[NetProps.GetPropInt(idx, "m_survivorCharacter")] <- 1;
		}

		while(deathBody = Entities.FindByClassname(deathBody, "survivor_death_model")) {
			if(BotAI.IsEntityValid(deathBody) && !BotAI.isDeathStillAlive(deathBody) && !(NetProps.GetPropInt(deathBody, "m_nCharacterType") in unreachable))
				bodys[bodys.len()] <- deathBody;
		}

		if(bodys.len() < 1) {
			taskReset(1);
			local store = {};
			foreach(player in BotAI.SurvivorBotList)
			{
				if(!BotAI.IsEntityValid(player)) continue;

				local item = null;
				while (Entities.FindInSphere(item, player.GetOrigin(), 150) != null)
				{
					item = Entities.FindInSphere(item, player.GetOrigin(), 150);
					local name = item.GetClassname();

					if(BotAI.IsEntityValid(item) && item.GetOwnerEntity() == null && !(item in store))
					{
						if (name == "first_aid_kit_spawn" || name == "first_aid_kit" || name == "weapon_first_aid_kit_spawn" || name == "weapon_first_aid_kit" )
						{
							store[item] <- 1;
							BotAI.doAmmoUpgrades(player);
							DoEntFire("!self", "Use", "", 0, player, item);
						}
					}
				}
			}

			return false;
		}
		else
		{
			fallen = bodys;
			return true;
		}
	}

	function GroupUpdateChecker(player) {
		if(BotAI.IsInCombat(player) || player.IsIncapacitated())
			return false;

		if(BotAI.IsEntitySurvivor(GUY) && GUY != player)
			return false;

		local distance = 2000;
		local findBody = null;
		foreach(body in fallen) {
			if(!BotAI.IsEntityValid(body) || BotAI.distanceof(player.GetOrigin(), body.GetOrigin()) > distance)
				continue;
			distance = BotAI.distanceof(player.GetOrigin(), body.GetOrigin());
			findBody = body;
		}

		if(findBody != null)
		{
			ironBanner = findBody;
		} else if(ironBanner == null)
			return false;

		if(BotAI.HasItem(player, "defibrillator")) {
			if(BotAI.BotDebugMode)
				printl("[Bot AI] Has defib.");
			GUY = player;
			return true;
		} else {
			local item = null;
			local findDef = null
			local defDis = 2000;
			while (Entities.FindInSphere(item, player.GetOrigin(), 2000) != null) {
				item = Entities.FindInSphere(item, player.GetOrigin(), 2000);
				local name = item.GetClassname();
				local idistance = BotAI.distanceof(player.GetOrigin(), item.GetOrigin());
				if ((name == "weapon_defibrillator" || name == "weapon_defibrillator_spawn") && item.GetOwnerEntity() == null) {
					if(findDef == null || idistance < defDis) {
						findDef = item;
						defDis = idistance;
					}
				}
			}

			if(findDef != null) {
				if (defDis > 150) {
					if(!BotAI.IsInCombat(player)) {
						if(BotAI.BotDebugMode) {
							printl("[Bot AI] Found defib");
						}
						local bo = ironBanner;
						local function needSearch() {
							return !BotAI.Defibrillator || !BotAI.IsEntityValid(bo) || !BotAI.IsEntityValid(findDef) || findDef.GetOwnerEntity() != null || BotAI.HasItem(player, "defibrillator");
						}

						BotAI.botRunPos(player, findDef, "searchBody", 3, needSearch, 8000);
						return false;
					}
				} else {
					BotAI.doAmmoUpgrades(player);
					DoEntFire("!self", "Use", "", 0, player, findDef);
					BotAI.setBotLockTheard(player, -1);
					return false;
				}
			}
			else
				return false;
		}

		return false;
	}

	function playerUpdate(player) {
		if(ironBanner != null && player != null) {
			local distance = BotAI.distanceof(ironBanner.GetOrigin(), player.GetOrigin());
			if (distance > 8000) {
				ironBanner = null;
				GUY = null;
				BotAI.setBotLockTheard(player, -1);
				return;
			}

			if (distance > 50) {
				local bo = ironBanner;
				local function needSearch() {
					return !BotAI.Defibrillator || !BotAI.IsEntityValid(bo) || BotAI.isDeathStillAlive(bo);
				}

				BotAI.botRunPos(player, ironBanner, "searchBody", 3, needSearch, 15000);
			} else if (distance <= 50) {
				BotAI.getNavigator(player).stop();
				BotAI.botMoveMap[player] <- Vector(0, 0, 0);
				NetProps.SetPropVector(player, "m_vecBaseVelocity", Vector(0, 0, 0));
				BotAI.SetTarget(player, ironBanner);
				BotAI.lookAtEntity(player, ironBanner, true, 4);
				local weapon = player.GetActiveWeapon();
				if(weapon && weapon.GetClassname() != "weapon_defibrillator") {
					BotAI.ChangeItem(player, 3);
				} else if(NetProps.GetPropFloat(weapon, "m_flNextPrimaryAttack") <= Time() && !BotAI.HasForcedButton(player, 1 )) {
					BotAI.ForceButton(player, 1 , 4, true);
					BotAI.setBotLockTheard(player, -1);
				}
			}
		}

		updating = false;
	}

	function taskReset(player = null) {
		base.taskReset(player);
		ironBanner = null;
		GUY = null;
	}
}