function BotAI::bestAim() {
	if(BotAI.Versus_Mode) return 1.0;
	foreach(player in BotAI.SurvivorBotList) {
		local target = null;
		if(player in BotAI.botAim)
			target = BotAI.botAim[player];
		if(BotAI.IsAlive(target))
			BotAI.lookAtEntity(player, target);
	}
	return 0.01;
}

function BotAI::taskTimer::hitinfected() {
	local name = "hitinfected";
	local task = BotAI.timerTask.hitinfected;
	
	foreach(player in BotAI.SurvivorBotList) {
		if(!BotAI.IsPlayerEntityValid(player)) continue;

		local shouldTick = task.shouldTick(player) && !(name in BotAI.disabledTask);

		if(shouldTick) {
			task.setLastTickTime(player, BotAI.tickExisted + task.tick);
			local shouldUpdate = false;
			shouldUpdate = task.shouldUpdate(player);

			if(shouldUpdate) {
				task.taskUpdate(player);
			}
		}
	}
}

function BotAI::taskTimer::updateFireState() {
	local name = "updateFireState";
	local task = BotAI.timerTask.updateFireState;
	foreach(player in BotAI.SurvivorBotList) {
		if(!BotAI.IsPlayerEntityValid(player)) continue;

		local shouldTick = task.shouldTick(player) && !(name in BotAI.disabledTask);

		if(shouldTick) {
			task.setLastTickTime(player, BotAI.tickExisted + task.tick);
			local shouldUpdate = false;
			shouldUpdate = task.shouldUpdate(player);

			if(shouldUpdate) {
				task.taskUpdate(player);
			}
		}
	}
}

function BotAI::taskTimer::shoveInfected() {
	local name = "shoveInfected";
	local task = BotAI.timerTask.shoveInfected;
	foreach(player in BotAI.SurvivorBotList) {
		if(!BotAI.IsPlayerEntityValid(player)) continue;

		local shouldTick = task.shouldTick(player) && !(name in BotAI.disabledTask);

		if(shouldTick) {
			task.setLastTickTime(player, BotAI.tickExisted + task.tick);
			local shouldUpdate = false;
			shouldUpdate = task.shouldUpdate(player);

			if(shouldUpdate) {
				task.taskUpdate(player);
			}
		}
	}
}

function BotAI::taskTimer::avoidDanger() {
	local name = "avoidDanger";
	local task = BotAI.timerTask.avoidDanger;
	foreach(player in BotAI.SurvivorBotList) {
		if(!BotAI.IsPlayerEntityValid(player)) continue;

		local shouldTick = task.shouldTick(player) && !(name in BotAI.disabledTask);

		if(shouldTick) {
			task.setLastTickTime(player, BotAI.tickExisted + task.tick);
			local shouldUpdate = false;
			shouldUpdate = task.shouldUpdate(player);

			if(shouldUpdate) {
				task.taskUpdate(player);
			}
		}
	}
}

function BotAI::resetTaskTimers() {
	BotAI.timerTask <- {};
	BotAI.timerTask.hitinfected <- AITaskHitInfected(0, 1, true, true);
	BotAI.timerTask.updateFireState <- AITaskUpdateBotFireState(0, 1, true, true);
	BotAI.timerTask.shoveInfected <- AITaskShoveInfected(0, 1, true, true);
	BotAI.timerTask.avoidDanger <- AITaskAvoidDanger(0, 2, true, true);

	local _hitinfectedTaskTimer = SpawnEntityFromTable("info_target", { targetname = "botai_task_timer_hitinfected"});

	if (_hitinfectedTaskTimer != null) {
		_hitinfectedTaskTimer.ValidateScriptScope();
		local scrScope = _hitinfectedTaskTimer.GetScriptScope();
		scrScope["ThinkTimer"] <- BotAI.taskTimer.hitinfected;
		AddThinkToEnt(_hitinfectedTaskTimer, "ThinkTimer");
	}

	local _updateFireStateTaskTimer = SpawnEntityFromTable("info_target", { targetname = "botai_task_timer_updateFireState"});

	if (_updateFireStateTaskTimer != null) {
		_updateFireStateTaskTimer.ValidateScriptScope();
		local scrScope = _updateFireStateTaskTimer.GetScriptScope();
		scrScope["ThinkTimer"] <- BotAI.taskTimer.updateFireState;
		AddThinkToEnt(_updateFireStateTaskTimer, "ThinkTimer");
	}

	local _shoveInfectedTaskTimer = SpawnEntityFromTable("info_target", { targetname = "botai_task_timer_shoveInfected"});

	if (_shoveInfectedTaskTimer != null) {
		_shoveInfectedTaskTimer.ValidateScriptScope();
		local scrScope = _shoveInfectedTaskTimer.GetScriptScope();
		scrScope["ThinkTimer"] <- BotAI.taskTimer.shoveInfected;
		AddThinkToEnt(_shoveInfectedTaskTimer, "ThinkTimer");
	}

	local _avoidDangerTaskTimer = SpawnEntityFromTable("info_target", { targetname = "botai_task_timer_avoidDanger"});

	if (_avoidDangerTaskTimer != null) {
		_avoidDangerTaskTimer.ValidateScriptScope();
		local scrScope = _avoidDangerTaskTimer.GetScriptScope();
		scrScope["ThinkTimer"] <- BotAI.taskTimer.avoidDanger;
		AddThinkToEnt(_avoidDangerTaskTimer, "ThinkTimer");
	}
}

function BotAI::createGroundTargetTimer(ground) {
    local _targetTimer = SpawnEntityFromTable("info_target", { targetname = "botai_projectile_timer_" + ground});
    local function findGoundTarget() {
        local danger = null;
	    while(danger = Entities.FindByClassname(danger, ground)) {
		    BotAI.groundList[danger.GetEntityIndex()] <- danger;
	    }
		return 0.5;
    }
    if (_targetTimer != null) {
		_targetTimer.ValidateScriptScope();
		local scrScope = _targetTimer.GetScriptScope();
		scrScope["ThinkTimer"] <- findGoundTarget;
		AddThinkToEnt(_targetTimer, "ThinkTimer");
	}
}

function BotAI::createProjectileTargetTimer(projectile) {
    local _targetTimer = SpawnEntityFromTable("info_target", { targetname = "botai_projectile_timer_" + projectile});
    local function findProjectileTarget() {
        local danger = null;
	    while(danger = Entities.FindByClassname(danger, projectile)) {
			if(projectile == "prop_physics") {
				local needContinue;
				foreach(thing in BotAI.takeElse) {
					if(danger.GetModelName().find(thing) != null)
						needContinue = true;
				}
				if(needContinue)
					continue;
			}
			if(danger.GetModelName().find("car") == null && danger.GetModelName().find("rock") == null) continue;
		    if(BotAI.GetEntitySpeedVector(danger) > 10 || BotAI.GetEntitySpeedLocalVector(danger) > 10)
			    BotAI.projectileList[danger.GetEntityIndex()] <- danger;
		    else if(danger.GetEntityIndex() in BotAI.ListAvoidCar) {
			    local time = BotAI.ListAvoidCar[danger.GetEntityIndex()].GetTime();
			    if(time > 0) {
				    if(BotAI.IsOnGround(danger) || BotAI.GetDistanceToGround(danger) < 50)
				    	BotAI.ListAvoidCar[danger.GetEntityIndex()].SetTime(time - 1);

				    BotAI.projectileList[danger.GetEntityIndex()] <- danger;
			    }
		    }
	    }

		return 0.5;
    }
    if (_targetTimer != null) {
		_targetTimer.ValidateScriptScope();
		local scrScope = _targetTimer.GetScriptScope();
		scrScope["ThinkTimer"] <- findProjectileTarget;
		AddThinkToEnt(_targetTimer, "ThinkTimer");
	}
}

function BotAI::createPlayerTargetTimer(player) {
    local index = player.GetEntityIndex();
    local _targetTimer = SpawnEntityFromTable("info_target", { targetname = "botai_target_timer_" + index});
    local function findTarget() {
        if(!BotAI.IsAlive(player)) {
            local infoTarget = null;
            while(infoTarget = Entities.FindByName(infoTarget, "botai_target_timer_" + index))
                infoTarget.Kill();
        }

		//local com = null;
		local selected = null;
		local closestCom = null; 
		local selectedDis = 120;
		local closestDis = 600;
		
		local isShove = BotAI.IsPressingShove(player);
		local isHealing = BotAI.IsBotHealing(player);

		if("get" in BotAI.commonInfectedMap)
		foreach(com in BotAI.commonInfectedMap.get(player)){
			if(!BotAI.IsAlive(com) || (BotAI.IsInfectedBeShoved(com) && isShove && !isHealing) || BotAI.IsEntitySI(BotAI.GetTarget(com))) continue;
			local dis = BotAI.nextTickDistance(player, com);
			local isTarget = BotAI.IsTarget(player, com);

			if(selected != null && selectedDis < dis) continue;
			
			if(dis <= 120 && isTarget) {
				selected = com;
				selectedDis = dis;
			} else if(!BotAI.HasTank && BotAI.CanSeeOtherEntityWithoutLocation(player, com) && dis < closestDis) {
				closestCom = com;
				closestDis = dis;
			}
		}
		
		if(selected != null)
        	BotAI.dangerInfected[player] <- selected;
		else if(closestCom != null)
			BotAI.dangerInfected[player] <- closestCom;
		else
			BotAI.dangerInfected[player] <- null;
		//printl(BotAI.getPlayerBaseName(player) + " " + BotAI.dangerInfected[player]);

		return 0.1;
    }

	if (_targetTimer != null) {
		_targetTimer.ValidateScriptScope();
		local scrScope = _targetTimer.GetScriptScope();
		scrScope["ThinkTimer"] <- findTarget;
		AddThinkToEnt(_targetTimer, "ThinkTimer");
	}
}

function BotAI::createNavigatorTimer(player) {
    local index = player.GetEntityIndex();
    local _targetTimer = SpawnEntityFromTable("info_target", { targetname = "botai_navigator_timer_" + index});
    local function navigator() {
        if(!BotAI.IsAlive(player)) {
            local infoTarget = null;
            while(infoTarget = Entities.FindByName(infoTarget, "botai_navigator_timer_" + index))
                infoTarget.Kill();
        }
		local navigator = BotAI.getNavigator(player);
		navigator.onUpdate();
    }

	if (_targetTimer != null) {
		_targetTimer.ValidateScriptScope();
		local scrScope = _targetTimer.GetScriptScope();
		scrScope["ThinkTimer"] <- navigator;
		AddThinkToEnt(_targetTimer, "ThinkTimer");
	}
}

function BotAI::conditionTimer(func, delay) {
    local _targetTimer = SpawnEntityFromTable("info_target", { targetname = "botai_condition_timer_" + UniqueString()});
    local function doFunction() {
        if(func()) {
			self.Kill();
		}

		return delay
    }

	if (_targetTimer != null) {
		_targetTimer.ValidateScriptScope();
		local scrScope = _targetTimer.GetScriptScope();
		scrScope["ThinkTimer"] <- doFunction;
		AddThinkToEnt(_targetTimer, "ThinkTimer");
	}
}

function BotAI::delayTimer(func, delay) {
    local _targetTimer = SpawnEntityFromTable("info_target", { targetname = "botai_delay_timer_" + UniqueString()});
	local _time = Time() + delay;
    local function doFunction() {
        if(Time() >= _time) {
			func();
			self.Kill();
		}
    }

	if (_targetTimer != null) {
		_targetTimer.ValidateScriptScope();
		local scrScope = _targetTimer.GetScriptScope();
		scrScope["ThinkTimer"] <- doFunction;
		AddThinkToEnt(_targetTimer, "ThinkTimer");
	}
}

function BotAI::throwTask(task, player, check) {
	local errorThinker = SpawnEntityFromTable("info_target", { targetname = "botai_task_throw" + UniqueString() });
	if (errorThinker != null) {
		errorThinker.ValidateScriptScope();
		local scrScope = errorThinker.GetScriptScope();
		local function thrower() {
			if(check)
                task.singleUpdateChecker(player);
            else
                task.taskUpdate(player);
		}
		scrScope["ThinkTimer"] <- thrower;
		AddThinkToEnt(errorThinker, "ThinkTimer");
		DoEntFire("!self", "Kill", "", 1, null, errorThinker);
	}
}

function BotAI::pingSystem() {
	foreach(player in BotAI.SurvivorList) {
		if(BotAI.IsPressingUse(player)) {
			local dot = 0.90;
			local dotThing = null;
			foreach(thing in BotAI.somethingBad) {
				if(!BotAI.IsEntityValid(thing) || BotAI.distanceof(player.GetOrigin(), thing.GetCenter()) > 200) continue;
				local dirction = BotAI.normalize(thing.GetCenter() - player.EyePosition());
				local dotValue = dirction.Dot(player.EyeAngles().Forward());
				if(dotValue >= dot) {
					dotThing = thing;
					dot = dotValue;
				}
			}

			if(BotAI.IsEntityValid(dotThing)) {
				DoEntFire("!self", "Use", "", 0, player, dotThing);
				return 0.5;
			}
		}
		/* 
		else if(BotAI.IsPressingShove(player)) {
			local point = BotAI.CanSeeOtherEntityPrintName(player, 250, 0);
			local ename = "";
			if(player.GetActiveWeapon() != null)
				ename = player.GetActiveWeapon().GetClassname();
			printl(ename + " " + point + " " + BotAI.HasItem(point, "pain_pills"));

			if(BotAI.IsEntitySurvivorBot(point) && BotAI.HasItem(point, "pain_pills") && ename == "weapon_adrenaline")
			{
				BotAI.removeItem(player, "adrenaline");
				BotAI.removeItem(point, "pain_pills");
				player.GiveItem("pain_pills");
				point.GiveItem("adrenaline");
				return 1;
			}

			if(BotAI.IsEntitySurvivorBot(point) && BotAI.HasItem(point, "adrenaline") && ename == "weapon_pain_pills")
			{
				BotAI.removeItem(player, "pain_pills");
				BotAI.removeItem(point, "adrenaline");
				player.GiveItem("adrenaline");
				point.GiveItem("pain_pills");
				return 1;
			}
		}
		*/
	}

	return 0.01;
}

	function BotAI::pingShow() {
		foreach(human in BotAI.SurvivorHumanList) {
			if(human in BotAI.pingPoint) {
				local bot = BotAI.pingPoint[human];
				if(BotAI.IsEntityValid(bot)) {
					DebugDrawText(bot.EyePosition() + Vector(0, 0, 20), "♦", false, 0.1);
					DebugDrawCircle(bot.GetOrigin(), Vector(255, 0, 255), 0.15, 17, false, 0.1);
					DebugDrawCircle(bot.GetOrigin(), Vector(255, 0, 255), 0.2, 12.5, false, 0.1);
					DebugDrawCircle(bot.GetOrigin(), Vector(255, 0, 255), 0.25, 9, false, 0.1);
					DebugDrawCircle(bot.GetOrigin(), Vector(255, 0, 255), 0.3, 7, false, 0.1);
				} else {
					delete BotAI.pingPoint[human];
				}
			}
		}
		return 0.05;
	}

	function BotAI::takeThing() {
		if(!BotAI.BackPack && BotAI.needOil) {
			foreach(player in BotAI.SurvivorBotList) {
				if(!BotAI.IsAlive(player)) continue;
				local thing = null;
				if(BotAI.backpack(player) == null)
				while(thing = Entities.FindInSphere(thing, player.GetOrigin(), 100)) {
					if(thing.GetClassname() == BotAI.BotsNeedToFind)
						if(BotAI.BotTakeGasCan(player, thing))
							return 0.01;
				}
			}
			return 1;
		}
		if(!BotAI.BackPack) {
			return 3;
		}
		foreach(player in BotAI.SurvivorBotList) {
			if(!BotAI.IsAlive(player)) continue;
			local thing = null;
			local needGascan = BotAI.needOil && (BotAI.backpack(player) == null || BotAI.backpack(player).GetClassname() != BotAI.BotsNeedToFind);
			if(BotAI.backpack(player) == null || needGascan)
			while(thing = Entities.FindInSphere(thing, player.GetOrigin(), 100)) {
				if(needGascan) {
					if(thing.GetClassname() == BotAI.BotsNeedToFind)
						if(BotAI.BotTakeGasCan(player, thing))
							return 0.01;
				} else {
					if(thing.GetClassname() == BotAI.BotsNeedToFind || thing.GetClassname() == BotAI.ColaBottles) {
						if(BotAI.BotTakeGasCan(player, thing))
							return 0.01;
					} else if(thing.GetClassname() == "prop_physics") {
						foreach(modelName in BotAI.takeElse) {
							if(thing.GetModelName().find(modelName) != null) {
								if(BotAI.BotTakeGasCan(player, thing))
									return 0.01;
							}
						}
					} else {
						foreach(modelName in BotAI.modelMap) {
							if(thing.GetClassname() == modelName) {
								if(BotAI.BotTakeGasCan(player, thing))
									return 0.01;
							}
						}
					}
				}
			}
		}
		return 1;
	}

	function BotAI::updateCommonInfected() {
		local infec = null;
		local map = ChunkMap(400);
		while(infec = Entities.FindByClassname(infec, "infected")) {
			if(BotAI.IsAlive(infec))
				map.put(infec);
		}
		BotAI.commonInfectedMap = map;
		return 1.0;
	}

	function BotAI::pickCoolDown() {
		foreach(prop, cooldown in BotAI.waitingToPick) {
			if(!BotAI.IsEntityValid(prop)) {
				delete BotAI.waitingToPick[prop];
				continue;
			}

			if(prop.GetOwnerEntity() != null) {
				if(BotAI.needOil && prop.GetClassname() == BotAI.BotsNeedToFind)
					BotAI.waitingToPick[prop] <- 2;
				else
					BotAI.waitingToPick[prop] <- 4;
			}
			else if(cooldown >= 0)
				BotAI.waitingToPick[prop] <- cooldown - 1;
		}
		return 1.0;
	}

function BotAI::loadTimers() {
	::BotAI._taskTimer <- SpawnEntityFromTable("info_target", { targetname = "botai_task_timer" });
if (::BotAI._taskTimer != null) {
		::BotAI._taskTimer.ValidateScriptScope();
		local scrScope = ::BotAI._taskTimer.GetScriptScope();
		scrScope["ThinkTimer"] <- ::BotAI.updateAITasks;
		AddThinkToEnt(::BotAI._taskTimer, "ThinkTimer");
}

local _singleTaskTimer = SpawnEntityFromTable("info_target", { targetname = "botai_single_task_timer" });
if (_singleTaskTimer != null) {
		_singleTaskTimer.ValidateScriptScope();
		local scrScope = _singleTaskTimer.GetScriptScope();
		scrScope["ThinkTimer"] <- ::BotAI.updateSingleAITasks;
		AddThinkToEnt(_singleTaskTimer, "ThinkTimer");
}

local _groupTaskTimer = SpawnEntityFromTable("info_target", { targetname = "botai_group_task_timer" });
if (_groupTaskTimer != null) {
		_groupTaskTimer.ValidateScriptScope();
		local scrScope = _groupTaskTimer.GetScriptScope();
		scrScope["ThinkTimer"] <- ::BotAI.updateGroupAITasks;
		AddThinkToEnt(_groupTaskTimer, "ThinkTimer");
}

local _aimTimer = SpawnEntityFromTable("info_target", { targetname = "botai_aim_timer" });
if (_aimTimer != null) {
	_aimTimer.ValidateScriptScope();
	local scrScope = _aimTimer.GetScriptScope();
	scrScope["ThinkTimer"] <- BotAI.bestAim;
	AddThinkToEnt(_aimTimer, "ThinkTimer");
}

	local pingThinker = SpawnEntityFromTable("info_target", { targetname = "botai_ping_system"});
	if (pingThinker != null) {
		pingThinker.ValidateScriptScope();
		local scrScope = pingThinker.GetScriptScope();
		scrScope["ThinkTimer"] <- BotAI.pingSystem;
		AddThinkToEnt(pingThinker, "ThinkTimer");
	}

	pingThinker = SpawnEntityFromTable("info_target", { targetname = "botai_ping_show"});
	if (pingThinker != null) {
		pingThinker.ValidateScriptScope();
		local scrScope = pingThinker.GetScriptScope();
		scrScope["ThinkTimer"] <- BotAI.pingShow;
		AddThinkToEnt(pingThinker, "ThinkTimer");
	}

	local takeThinker = SpawnEntityFromTable("info_target", { targetname = "botai_take"});
	if (takeThinker != null) {
		takeThinker.ValidateScriptScope();
		local scrScope = takeThinker.GetScriptScope();
		scrScope["ThinkTimer"] <- BotAI.takeThing;
		AddThinkToEnt(takeThinker, "ThinkTimer");
	}

	takeThinker = SpawnEntityFromTable("info_target", { targetname = "botai_commonInfected"});
	if (takeThinker != null) {
		takeThinker.ValidateScriptScope();
		local scrScope = takeThinker.GetScriptScope();
		scrScope["ThinkTimer"] <- BotAI.updateCommonInfected;
		AddThinkToEnt(takeThinker, "ThinkTimer");
	}

	takeThinker = SpawnEntityFromTable("info_target", { targetname = "botai_pick_cooldown"});
	if (takeThinker != null) {
		takeThinker.ValidateScriptScope();
		local scrScope = takeThinker.GetScriptScope();
		scrScope["ThinkTimer"] <- BotAI.pickCoolDown;
		AddThinkToEnt(takeThinker, "ThinkTimer");
	}
}
