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
	
function BotAI::taskTimer::hitinfected() {
	local name = "hitinfected";
	local task = BotAI.timerTask.hitinfected;
	
	foreach(player in BotAI.SurvivorBotList) {
		if(!BotAI.IsPlayerEntityValid(player)) continue;

		local shouldTick = task.shouldTick(player) && !(name in BotAI.disabledTask);

		if(shouldTick) {
			task.setLastTickTime(player, BotAI.tickExisted + task.tick);
			local shouldUpdate = false;
			try{
				shouldUpdate = task.shouldUpdate(player);
			}
			catch(excaption) {
				BotAI.EasyPrint("botai_report", 0.1);
				BotAI.EasyPrint(excaption.tostring(), 0.2);
				local deadTask = task.shouldUpdate;
                local deadPlayer = player;
                BotAI.Timers.throwError(deadTask, deadPlayer);
				BotAI.timerTask.hitinfected <- AITaskHitInfected(0, 1, true, true);
			}

			if(shouldUpdate) {
				try{
					task.taskUpdate(player);
				}
				catch(excaption) {
					BotAI.EasyPrint("botai_report", 0.1);
					BotAI.EasyPrint(excaption.tostring(), 0.2);
					local deadTask = task.taskUpdate;
                    local deadPlayer = player;
                    BotAI.Timers.throwError(deadTask, deadPlayer);
					BotAI.timerTask.hitinfected <- AITaskHitInfected(0, 1, true, true);
				}
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
			try{
				shouldUpdate = task.shouldUpdate(player);
			}
			catch(excaption) {
				BotAI.EasyPrint("botai_report", 0.1);
				BotAI.EasyPrint(excaption.tostring(), 0.2);
				local deadTask = task.shouldUpdate;
                local deadPlayer = player;
                BotAI.Timers.throwError(deadTask, deadPlayer);
				BotAI.timerTask.updateFireState <- AITaskUpdateBotFireState(0, 1, true, true);
			}

			if(shouldUpdate) {
				try{
					task.taskUpdate(player);
				}
				catch(excaption) {
					BotAI.EasyPrint("botai_report", 0.1);
					BotAI.EasyPrint(excaption.tostring(), 0.2);
					local deadTask = task.taskUpdate;
                    local deadPlayer = player;
                    BotAI.Timers.throwError(deadTask, deadPlayer);
					BotAI.timerTask.updateFireState <- AITaskUpdateBotFireState(0, 1, true, true);
				}
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
			try{
				shouldUpdate = task.shouldUpdate(player);
			}
			catch(excaption) {
				BotAI.EasyPrint("botai_report", 0.1);
				BotAI.EasyPrint(excaption.tostring(), 0.2);
				local deadTask = task.shouldUpdate;
                local deadPlayer = player;
                BotAI.Timers.throwError(deadTask, deadPlayer);
				BotAI.timerTask.shoveInfected <- AITaskShoveInfected(0, 1, true, true);
			}

			if(shouldUpdate) {
				try{
					task.taskUpdate(player);
				}
				catch(excaption) {
					BotAI.EasyPrint("botai_report", 0.1);
					BotAI.EasyPrint(excaption.tostring(), 0.2);
					local deadTask = task.taskUpdate;
                    local deadPlayer = player;
                    BotAI.Timers.throwError(deadTask, deadPlayer);
					BotAI.timerTask.shoveInfected <- AITaskShoveInfected(0, 1, true, true);
				}
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
			try{
				shouldUpdate = task.shouldUpdate(player);
			}
			catch(excaption) {
				BotAI.EasyPrint("botai_report", 0.1);
				BotAI.EasyPrint(excaption.tostring(), 0.2);
				local deadTask = task.shouldUpdate;
                local deadPlayer = player;
                BotAI.Timers.throwError(deadTask, deadPlayer);
				BotAI.timerTask.avoidDanger <- AITaskAvoidDanger(0, 2, true, true);
			}

			if(shouldUpdate) {
				try{
					task.taskUpdate(player);
				}
				catch(excaption) {
					BotAI.EasyPrint("botai_report", 0.1);
					BotAI.EasyPrint(excaption.tostring(), 0.2);
					local deadTask = task.taskUpdate;
                    local deadPlayer = player;
                    BotAI.Timers.throwError(deadTask, deadPlayer);
					BotAI.timerTask.avoidDanger <- AITaskAvoidDanger(0, 2, true, true);
				}
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
    local function findTarget() {
        local danger = null;
	    while(danger = Entities.FindByClassname(danger, ground)) {
		    BotAI.projectileList[danger.GetEntityIndex()] <- danger;
	    }
    }
    if (_targetTimer != null) {
		_targetTimer.ValidateScriptScope();
		local scrScope = _targetTimer.GetScriptScope();
		scrScope["ThinkTimer"] <- findTarget;
		AddThinkToEnt(_targetTimer, "ThinkTimer");
	}
}

function BotAI::createProjectileTargetTimer(projectile) {
    local _targetTimer = SpawnEntityFromTable("info_target", { targetname = "botai_projectile_timer_" + projectile});
    local function findTarget() {
        local danger = null;
	    while(danger = Entities.FindByClassname(danger, projectile)) {
		    if(BotAI.GetEntitySpeedVector(danger) > 0 || BotAI.GetEntitySpeedLocalVector(danger) > 0)
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
    }
    if (_targetTimer != null) {
		_targetTimer.ValidateScriptScope();
		local scrScope = _targetTimer.GetScriptScope();
		scrScope["ThinkTimer"] <- findTarget;
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
        local playerReviving = BotAI.IsPlayerReviving(player);
        if(playerReviving) return;

		local com = null;
		local selected = null;
		local selectedDis = 0;
		
		local dist = 150;
	
		local gasFinding = BotAI.getBotGasFinding(player);
		
		local isShove = BotAI.IsPressingShove(player);
		local isHealing = BotAI.IsBotHealing(player);

		while(com = Entities.FindByClassnameWithin(com, "infected", player.GetOrigin(), dist)) {
			if(!BotAI.IsAlive(com) || (BotAI.IsInfectedBeShoved(com) && isShove && !isHealing) || BotAI.IsEntitySI(BotAI.GetTarget(com))) continue;
			local dis = BotAI.nextTickDistance(player, com);
			local isTarget = BotAI.IsTarget(player, com);

			if(selected != null && selectedDis < dis) continue;
			
			if(dis <= 120 && isTarget) {
				selected = com;
			}
				
			if(selected != null)
				selectedDis = dis;
		}

        BotAI.dangerInfected[player] <- selected;
    }

	if (_targetTimer != null) {
		_targetTimer.ValidateScriptScope();
		local scrScope = _targetTimer.GetScriptScope();
		scrScope["ThinkTimer"] <- findTarget;
		AddThinkToEnt(_targetTimer, "ThinkTimer");
	}
}

function BotAI::throwTask(task, player, check) {
	local errorThinker = SpawnEntityFromTable("info_target", { targetname = "botai_task_throw" + UniqueString() });
	if (errorThinker != null) {
		errorThinker.ValidateScriptScope();
		local scrScope = errorThinker.GetScriptScope();
		local function thrower() {
            printl(task.name);
			Msg(I18n.getTranslationKey("botai_exception_here"));
			Msg("\n");
			if(check)
                task.shouldUpdate(player);
            else
                task.taskUpdate(player);
		}
		scrScope["ThinkTimer"] <- thrower;
		AddThinkToEnt(errorThinker, "ThinkTimer");
		DoEntFire("!self", "Kill", "", 1, null, errorThinker);
	}
}