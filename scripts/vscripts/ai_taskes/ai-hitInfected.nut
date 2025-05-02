class ::AITaskHitInfected extends AITaskSingle {

	constructor(orderIn, tickIn, compatibleIn, forceIn) {
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
		this.tick = 8 - BotAI.BotCombatSkill * 3;
		if (this.tick < 2) {
			this.tick = 2;
		}

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

		local playerNeedSave = null;
		local playerFallingDown = null;
		dist = 80;

		foreach(savePlayer in BotAI.SurvivorList) {
			if(BotAI.IsAlive(savePlayer) && savePlayer != player) {
				local dis = BotAI.nextTickDistance(player, savePlayer) < dist;
				if (savePlayer.IsDominatedBySpecialInfected() && dis) {
					local bad = savePlayer.GetSpecialInfectedDominatingMe();
					if (BotAI.IsEntitySI(bad) && (bad.GetZombieType() == 1 || bad.GetZombieType() == 2 || bad.GetZombieType() == 3 || bad.GetZombieType() == 5)) {
						playerNeedSave = savePlayer;
					}

				} else if (!BotAI.HasTank && (savePlayer.IsIncapacitated() || savePlayer.IsHangingFromLedge()) && !savePlayer.IsDominatedBySpecialInfected() && !BotAI.isPlayerBeingRevived(savePlayer) && dis) {
					playerFallingDown = savePlayer;
				}
			}
		}

		if (playerNeedSave != null) {
			danger[player] = true;
			infectedList[player] <- playerNeedSave;
			return true;
		}

		local selected = null;
		if(player in BotAI.dangerInfected) {// && playerFallingDown == null
			selected = BotAI.dangerInfected[player];
		}

		local dist = 300 + BotAI.BotCombatSkill * 120;
		local entS = null;
		local highestPriority = -1;
		local awareAngle = 0.9397;

		if (BotAI.BotCombatSkill == 1) {
			awareAngle = 0.707;
		} else if (BotAI.BotCombatSkill == 2) {
			awareAngle = 0.0;
		} else if (BotAI.BotCombatSkill >= 3) {
			awareAngle = -2.0;
		}

		local navigator = BotAI.getNavigator(player);
		if (navigator.moving()) {
			awareAngle -= 0.5;
		}

		foreach(infected in BotAI.SpecialList) {
			if (BotAI.IsAlive(infected) && !infected.IsGhost() && !BotAI.IsEntitySI(BotAI.GetTarget(infected)) && (infected.GetZombieType() != 8 || entS == null) && (BotAI.CanShotOtherEntityInSight(player, infected, awareAngle) || BotAI.IsEntityValid(BotAI.getSiVictim(infected)))) {
				if (infected.GetZombieType() == 1) {
					dist = BotAI.tongueRange*1.2;
				} else if (infected.GetZombieType() == 8) {
					dist = 800;
				} else {
					dist = 300 + BotAI.BotCombatSkill * 120;
				}

				local currentPriority = 0;
				local target = BotAI.GetTarget(infected);

				if (target == player) {
					currentPriority = 3;
				} else if (BotAI.IsEntityValid(BotAI.getSiVictim(infected))) {
					currentPriority = 2;
				} else {
					currentPriority = 1;
				}

				local infecDis = BotAI.nextTickDistance(player, infected, 5.0);
				local smoker = false;

				if(infected.GetZombieType() == 1 && NetProps.GetPropFloat(NetProps.GetPropEntity(infected, "m_customAbility"), "m_nextActivationTimer.m_timestamp") <= Time()) {
					smoker = true;
				}

				if (currentPriority > highestPriority ||(currentPriority == highestPriority && (infecDis < dist || BotAI.IsSurvivorTrapped(target) || smoker))) {
					dist = infecDis;
					entS = infected;
					highestPriority = currentPriority;
				}
			}
		}

		local dangerTarget = null;

		if (entS != null && BotAI.nextTickDistance(player, entS, 5.0) < 400 && BotAI.GetTarget(entS) == player) {
			dangerTarget = entS;
		} else if (selected != null && BotAI.GetTarget(selected) == player && BotAI.nextTickDistance(player, selected, 5.0) < 200) {
			dangerTarget = selected;
		}

		BotAI.setBotCombatTarget(player, dangerTarget);


		if(!BotAI.HasTank && entS == null && playerFallingDown != null) {
			infectedList[player] <- playerFallingDown;
			return true;
		}

		if (entS != null && selected != null) {
			local finalEntity = null;
			local siDistance = BotAI.nextTickDistance(player, entS, 5.0);
			local coDistance = BotAI.nextTickDistance(player, selected, 5.0);

			if (entS.GetZombieType() == 8) {
				finalEntity = selected;
				if(coDistance < 90) {
					danger[player] = true;
				}
			} else {
				if(siDistance < 270) {
					if(siDistance < 90) {
						danger[player] = true;
					}
					finalEntity = entS;
				} else {
					finalEntity = selected;
					if(coDistance < 90) {
						danger[player] = true;
					}
				}
			}

			infectedList[player] <- finalEntity;
			return true;
		}

		if (entS != null && entS.GetZombieType() != 8) {
			infectedList[player] <- entS;
			local siDistance = BotAI.nextTickDistance(player, entS, 5.0);
			if(siDistance < 90) {
				danger[player] = true;
			}

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

		dist = 700;
		local witch = null;
		foreach(infected in BotAI.WitchList) {
			if (BotAI.IsAlive(infected) && (BotAI.witchKilling(infected) || (BotAI.witchRunning(infected) && !BotAI.witchRetreat(infected))) && BotAI.CanShotOtherEntityInSight(player, infected)) {
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

		return false;
	}

	function playerUpdate(player) {
		if(player in infectedList && infectedList[player] != null) {
			local val = infectedList[player];
			if(BotAI.IsAlive(val)) {// && BotAI.CanShotOtherEntityInSight(player, val)

				if(danger[player]) {
					BotAI.setBotShoveTarget(player, val);
				}
				BotAI.BotAttack(player, val);
				if(BotAI.IsEntityValid(val) && !IsPlayerABot(player)) {
					BotAI.lookAtEntity(player, val);
				}
			} else {
				infectedList[player] <- null;
				BotAI.botAim[player] <- null;
			}
		}

		updating[player] <- false;
	}

	function taskReset(player = null) {
		base.taskReset(player);

		if(player != null)
			infectedList[player] <- null;
		danger = false;
	}
}