class ::AITaskHitInfected extends AITaskSingle
{
	constructor(orderIn, tickIn, compatibleIn, forceIn)
    {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
		name = "hitinfected";
		single = true;
		updating = {};
		playerTick = {};
		infectedList = {}
		danger = {};
    }
	
	name = "hitinfected";
	single = true;
	updating = {};
	playerTick = {};
	infectedList = {}
	danger = {};
	
	function singleUpdateChecker(player) {
		danger[player] <- false;
		
		if(player in BotAI.targetLocked && BotAI.IsAlive(BotAI.targetLocked[player])) {
			infectedList[player] <- BotAI.targetLocked[player];
			return true;
		}

		local dist = 800;
		
		local rock = null;
		local nearestRock = null;
		local RockDis = 800;
		
		foreach(idx, pro in BotAI.projectileList) {
			local rock = null;
			if(BotAI.IsEntityValid(pro) && pro.GetClassname() == "tank_rock")
				rock = pro;
			if (BotAI.IsEntityValid(rock) && BotAI.CanHitOtherEntity(rock, player, g_MapScript.TRACE_MASK_SHOT) && BotAI.distanceof(player.GetOrigin(), rock.GetOrigin()) < RockDis) {
				RockDis = BotAI.distanceof(player.GetOrigin(), rock.GetOrigin());
				nearestRock = rock;
			}
		}
		
		if(nearestRock != null){
			infectedList[player] <- nearestRock;
			BotAI.setBotTarget(player, nearestRock);
			return true;
		}

		dist = 700;
		local witch = null;
		foreach(infected in BotAI.WitchList) {
			if (BotAI.IsAlive(infected) && (BotAI.witchKilling(infected) || (BotAI.witchRunning(infected) && !BotAI.witchRetreat(infected))) && BotAI.CanSeeOtherEntityWithoutLocation(player, infected, 0, true)) {
				if (BotAI.distanceof(player.GetOrigin(), infected.GetOrigin()) < dist) {
					dist = BotAI.distanceof(player.GetOrigin(), infected.GetOrigin());
					witch = infected;
				}
			}
		}
		
		if (witch != null) {
			infectedList[player] <- witch;
			return true;
		}

		local playerNeedSave = null;
		local playerFallingDown = null;
		dist = 120;
		foreach(savePlayer in BotAI.SurvivorList) {
			if(BotAI.IsAlive(savePlayer) && savePlayer != player) {
				local dis = BotAI.nextTickDistance(player, savePlayer) < dist;
				if (savePlayer.IsDominatedBySpecialInfected() && dis)
					playerNeedSave = savePlayer;
				else if ((savePlayer.IsIncapacitated() || savePlayer.IsHangingFromLedge()) && !savePlayer.IsGettingUp() && dis)
					playerFallingDown = savePlayer;
			}
		}
		
		if (playerNeedSave != null && !BotAI.HasTank) {
			danger[player] = true;
			infectedList[player] <- playerNeedSave;
			return true;
		}

		local selected = null;
		if(player in BotAI.dangerInfected && playerFallingDown == null)
			selected = BotAI.dangerInfected[player];
		
		dist = BotAI.tongueRange*1.2;
		if(dist < 600)
			dist = 600;
		local entS = null;
		foreach(infected in BotAI.SpecialList) {
			if (BotAI.IsAlive(infected) && !infected.IsGhost() && !BotAI.IsEntitySI(BotAI.GetTarget(infected)) && infected.GetZombieType() != 8 && (BotAI.CanSeeOtherEntityWithoutLocation(player, infected, 0, true))) {
				local infecDis = BotAI.nextTickDistance(player, infected, 5.0, true);
				local smoker = false;

				if(infected.GetZombieType() == 1 && NetProps.GetPropFloat(NetProps.GetPropEntity(infected, "m_customAbility"), "m_nextActivationTimer.m_timestamp") <= Time())
					smoker = true;
				if (infecDis < dist || BotAI.IsSurvivorTrapped(BotAI.GetTarget(infected)) || smoker) {
					dist = infecDis;
					entS = infected;
				}
			}
		}
		
		if(!BotAI.HasTank && entS == null && playerFallingDown != null) {
			infectedList[player] <- playerFallingDown;
			return true;
		}

		if (entS != null && selected != null) {
			local finalEntity = null;
			local siDistance = BotAI.nextTickDistance(player, entS, 5.0);
			local coDistance = BotAI.nextTickDistance(player, selected, 5.0);

			if(siDistance < 270) {
				if(siDistance < 90)
					danger[player] = true;
				finalEntity = entS;
			} else {
				finalEntity = selected;
				if(coDistance < 90)
					danger[player] = true;
			}
	
			infectedList[player] <- finalEntity;
			return true;
		}

		if (entS != null) {
			infectedList[player] <- entS;
			local siDistance = BotAI.nextTickDistance(player, entS, 5.0);
			if(siDistance < 90)
				danger[player] = true;
			return true;
		}

		if (selected != null) {
			infectedList[player] <- selected;
			local coDistance = BotAI.nextTickDistance(player, selected, 5.0);
			if(coDistance < 90) {
				danger[player] = true;
			}
			return true;
		}
		
		NetProps.SetPropInt(player, "m_hViewEntity", -1);
		return false;
	}
	
	function playerUpdate(player) {
		if(player in infectedList && infectedList[player] != null) {
			local val = infectedList[player];
			if(BotAI.IsAlive(val) && BotAI.CanSeeOtherEntityWithoutLocation(player, val, 0)) {
				if(danger[player]) {
					BotAI.setBotShoveTarget(player, val);
				}
				BotAI.BotAttack(player, val);
				if(BotAI.IsEntityValid(val) && !IsPlayerABot(player))
					BotAI.lookAtEntity(player, val);
			} else
				infectedList[player] <- null;
		}
		
		updating[player] <- false;
	}
	
	function taskReset(player = null) 
	{
		base.taskReset(player);
		
		if(player != null)
			infectedList[player] <- null;
		danger = false;
	}
}