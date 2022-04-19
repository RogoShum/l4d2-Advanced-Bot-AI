class ::AITaskCheckToThrowGen extends AITaskGroup
{
	constructor(orderIn, tickIn, compatibleIn, forceIn)
    {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
    }
	
	updating = false;
	playerList = {};
	ahamkara = {};
	lament = {};
	cooldown = 0;
	
	function preCheck()
	{
		if(cooldown > 0)
			cooldown--;
		
		local aliveFactor = BotAI.playerLive * 500;
		local stasis = {};
		local gettank = false;
		local hasMolotov = false;
		local needVomitjar = Director.GetCommonInfectedCount() > 15;
		local function searchGen(entT, genType) {
			foreach(player in BotAI.SurvivorList) {
				if(hasMolotov)
					continue;

				if(BotAI.HasItem(player, genType)) {
					stasis[entT] <- genType;
					hasMolotov = true;
				}
			}
		}

		foreach(entT in BotAI.SpecialList) {
			if(BotAI.IsAlive(entT) && entT.GetZombieType() == 8) {
				gettank = true;
				if(entT.GetHealth() > aliveFactor && cooldown < 1) {
					if(!BotAI.IsOnFire(entT))
						searchGen(entT, "weapon_molotov");
					
					if(needVomitjar && !hasMolotov && !BotAI.isVomited(entT))
						searchGen(entT, "weapon_vomitjar");
				}
			}
		}
		
		BotAI.HasTank = gettank && Director.IsTankInPlay();
		
		if(!BotAI.NeedThrowGrenade)
			return false;
		
		local infectedJudge = 0 + stasis.len() * 6;
		local checlAmount = 25 - (BotAI.playerFallDown * 3);
		if(Director.GetCommonInfectedCount() > checlAmount) {
			local infec = null;
			while(infec = Entities.FindByClassname(infec, "infected")) {
				if(infec.IsValid() && BotAI.IsAlive(infec)) {
					if(BotAI.IsEntitySurvivor(BotAI.GetTarget(infec)))
						infectedJudge+=1.15;
					else
						infectedJudge+=0.3;
				}
			}
		}
		
		
		infectedJudge += BotAI.playerFallDown * 3;
		//infectedJudge += BotAI.SpecialList.len() * 1;
		local hasPipe = false;

		if(infectedJudge >= BotAI.playerLive * 4) {
			foreach(player in BotAI.SurvivorList) {
				if(hasPipe)
					continue;

				if(BotAI.HasItem(player, "weapon_pipe_bomb")) {
					local inf = Entities.FindByClassnameNearest("infected", player.GetOrigin(), 1000);
					if(inf != null) {
						hasPipe = true;
						stasis[inf] <- "weapon_pipe_bomb";
					}
				} else if (BotAI.HasItem(player, "weapon_vomitjar")) {
					local inf = Entities.FindByClassnameNearest("infected", player.GetOrigin(), 1000);
					if(inf != null) {
						hasPipe = true;
						stasis[inf] <- "weapon_vomitjar";
					}
				}
			}
		}
		
		local bungie = {};
		foreach(bungie_mama, val in stasis) {
			if(val == "weapon_molotov")
			foreach(player in BotAI.SurvivorList) {
				if(BotAI.distanceof(player.GetOrigin(), bungie_mama.GetOrigin()) < 200)
					stasis[bungie_mama] = null;
			}
			
			if(stasis[bungie_mama] != null)
				bungie[bungie_mama] <- stasis[bungie_mama];
		}
		
		ahamkara = bungie;
		if(bungie.len() > 0)
			return true;
		else
			return false;
	}
	
	function GroupUpdateChecker(player)
	{
		foreach(riven, val in ahamkara) {
			if(riven in lament) {
				if(lament[riven] == player) 
				{
					if(BotAI.HasItem(player, ahamkara[riven]))
						return true;
					else
						delete lament[riven];
				}
				continue;
			}
			if(BotAI.HasItem(player, ahamkara[riven]) && BotAI.CanSeeOtherEntityWithoutBarrier(player, riven, 75) && !BotAI.IsPlayerClimb(player) &&
				!player.IsIncapacitated() && !player.IsDominatedBySpecialInfected() && !player.IsStaggering() && BotAI.distanceof(player.GetOrigin(), riven.GetOrigin()) < 1000) {
				lament[riven] <- player;
				return true;
			}
		}
		
		return false;
	}
	
	function playerUpdate(player)
	{
		foreach(riven, val in lament) {
			if(lament[riven] == player && riven in ahamkara && ahamkara[riven] != null && BotAI.HasItem(player, ahamkara[riven])) {
				local angle = BotAI.CreateQAngle(riven.GetOrigin().x - player.GetOrigin().x, riven.GetOrigin().y - player.GetOrigin().y, riven.GetOrigin().z - player.GetOrigin().z).Forward();
				local distance = BotAI.distanceof(riven.GetOrigin(), player.GetOrigin());
				angle = BotAI.CreateQAngle(angle.x, angle.y, (distance - 500) * 0.0005 + angle.z);
				
				if(!BotAI.IsHumanSpectating(player) && !BotAI.IsEntitySurvivor(riven))
					NetProps.SetPropEntity(player, "m_hViewEntity", riven);
				player.SnapEyeAngles(angle);
				//NetProps.SetPropVector(player, "m_angRotation", angle);
				
				BotAI.AddFlag(player, FL_FROZEN );
		
				local function RemoveFlag(ent_) {
					if(BotAI.IsEntityValid(ent_))
						BotAI.RemoveFlag(ent_, FL_FROZEN );
				}
		
				::BotAI.Timers.AddTimerByName("CheckToThrowGen" + player.GetEntityIndex(), 1.0, false, RemoveFlag, player);
				
				local weapon = player.GetActiveWeapon();
				if(weapon && weapon.GetClassname() == ahamkara[riven] && NetProps.GetPropFloat(weapon, "m_flNextPrimaryAttack") <= Time()) {
					BotAI.ForceButton(player, 1 , 0.5, true);
					BotAI.setBotLockTheard(player, -1);
					cooldown = 3;
				}
				else
					BotAI.ChangeItem(player, 2);
			}
			else
				BotAI.setBotLockTheard(player, -1);
		}
		
		updating = false;
	}
	
	function taskReset(player = null) 
	{
		base.taskReset(player);
		lament.clear();
	}
}