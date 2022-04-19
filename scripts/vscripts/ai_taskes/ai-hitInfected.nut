class ::AITaskHitInfected extends AITaskSingle
{
	constructor(orderIn, tickIn, compatibleIn, forceIn)
    {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
    }
	
	name = "hitinfected";
	single = true;
	updating = {};
	playerTick = {};
	infectedList = {}
	danger = false;
	
	function singleUpdateChecker(player)
	{
		danger = false;
		
		local dist = 800;
		
		local rock = null;
		local nearestRock = null;
		local RockDis = 800;
		
		while(rock = Entities.FindByClassnameWithin(rock, "tank_rock", player.GetOrigin(), dist)) {
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
		
		if (playerNeedSave != null) {
			danger = true;
			infectedList[player] <- playerNeedSave;
			return true;
		}

		local gasFinding = BotAI.getBotGasFinding(player);
		local selected = null;
		if(player in BotAI.dangerInfected && (gasFinding > 0 || playerFallingDown != null))
			selected = BotAI.dangerInfected[player];
		
		local playerReviving = BotAI.IsPlayerReviving(player);

		if(!playerReviving && !BotAI.IsAlive(selected) && gasFinding < 2 && playerFallingDown == null) {
			local closestCom = Entities.FindByClassnameNearest("infected", player.GetOrigin(), 1500);
			if(BotAI.IsAlive(closestCom) && !BotAI.IsEntitySI(BotAI.GetTarget(closestCom))) {
				if(BotAI.CanSeeOtherEntityWithoutLocation(player, closestCom))
					selected = closestCom;
				else if(BotAI.BOT_AI_TEST_MOD == 1) {
					DebugDrawBox(closestCom.GetBoneOrigin(14), Vector(-10, -10, -10), Vector(10, 10, 10), 0, 100, 255, 0.2, 0.2);
					DebugDrawText(closestCom.GetBoneOrigin(14), BotAI.getPlayerBaseName(player) + " need aim", false, 0.2);
				}
			}
		}
		
		dist = 1000;
		local entS = null;
		foreach(infected in BotAI.SpecialList) {
			if (BotAI.IsAlive(infected) && !infected.IsGhost() && !BotAI.IsEntitySI(BotAI.GetTarget(infected)) && infected.GetZombieType() != 8 && (BotAI.CanSeeOtherEntityWithoutLocation(player, infected, 0, true))) {
				local infecDis = BotAI.nextTickDistance(player, infected, 5.0, true);
				if (infected.GetZombieType() == 1 || infecDis < dist) {
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

			if(siDistance < 350) {
				if(siDistance < 90)
					danger = true;
				finalEntity = entS;
			}
			else {
				finalEntity = selected;
				if(coDistance < 90)
					danger = true;
			}
	
			infectedList[player] <- finalEntity;
			return true;
		}

		if (entS != null) {
			infectedList[player] <- entS;
			local siDistance = BotAI.nextTickDistance(player, entS, 5.0);
			if(siDistance < 90)
				danger = true;
			return true;
		}

		if (selected != null) {
			infectedList[player] <- selected;
			local coDistance = BotAI.nextTickDistance(player, selected, 5.0);
			if(coDistance < 90) {
				danger = true;
			}
			return true;
		}
		
		dist = 700;
		local witch = null;
		foreach(infected in BotAI.WitchList) {
			if (BotAI.IsAlive(infected) && (BotAI.CanSeeOtherEntityWithoutLocation(player, infected, 0, true))) {
				if (BotAI.distanceof(player.GetOrigin(), infected.GetOrigin()) < dist) {
					dist = BotAI.distanceof(player.GetOrigin(), infected.GetOrigin());
					witch = infected;
				}
			}
		}
		
		if (witch != null) {
			local WitchState = NetProps.GetPropInt(witch, "m_nSequence");
			if(WitchState != ANIM_WITCH_LOSE_TARGET && WitchState != ANIM_WITCH_RUN_AWAY && WitchState != ANIM_SITTING_CRY && WitchState != ANIM_SITTING_STARTLED && WitchState != ANIM_SITTING_AGGRO && WitchState != ANIM_WALK && WitchState != ANIM_WANDER_WALK) {
				infectedList[player] <- witch;
				return true;
			}
		}
		
		NetProps.SetPropInt(player, "m_hViewEntity", -1);
		return false;
	}
	
	function playerUpdate(player) {
		if(player in infectedList && infectedList[player] != null) {
			local val = infectedList[player];
			if(BotAI.IsAlive(val)) {
				if(danger) {
					//if(BotAI.IsBotGasFinding(player))
						//BotAI.BotReset(player);
					//BotAI.lookAtEntity(player, val, true, 0.3);
					BotAI.setBotShoveTarget(player, val);
					//BotAI.dodgeEntity(player, val);
				}
				BotAI.BotAttack(player, val);
				if(BotAI.IsEntityValid(val) && !IsPlayerABot(player))
					BotAI.lookAtEntity(player, val);
			}
			else
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