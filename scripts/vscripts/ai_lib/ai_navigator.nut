::NavigatorPause <- {}

class::Navigator {
	pathCache = {};
	player = null;
	movingID = null;
	lastArea = null;
	buildCoolDown = {};
	posCheck = null;
	pathFlat = true;
	SEARCH_LIMIT = 128;
	TIME_OUT_LIMIT = 5;
	JUMP_HIGHT = 50;

	constructor(playerIn) {
		player = playerIn;
		movingID = null;
		pathCache = {};
		lastArea = playerIn.GetLastKnownArea();
		buildCoolDown = {};
		posCheck = playerIn.GetOrigin();
	}

	function _typeof() {
		return "Navigator";
	}

	function buildPath(goal, id, priority = 0, discardFunc = BotAI.trueDude, distance = 10000) {
		local goalArea = null;
		local goalPos = null;
		if (typeof goal == "Vector") {
			goalPos = goal;
		} else if (BotAI.IsEntityValid(goal)) {
			if ("GetLastKnownArea" in goal)
				goalArea = goal.GetLastKnownArea();
			goalPos = goal.GetOrigin();
		} else {
			navPrint("invalid goal: " + goal);
			return false;
		}

		if (goalArea == null) {
			goalArea = NavMesh.GetNavArea(goalPos, 150);
			if (goalArea == null && BotAI.IsTriggerUsable(goal)) {
				local direcVec = Vector(120, 0, 0);
				for (local i = 0; i < 8; ++i) {
					local angleVec = BotAI.rotateVector(direcVec, i * 45);
					local targetPos = goalPos + angleVec;
					if (BotAI.BotDebugMode) {
						DebugDrawCircle(targetPos, Vector(0, 0, 255), 1.0, 5, true, 1.0);
						DebugDrawText(targetPos, "goal", false, 1.0);
					}

					goalArea = NavMesh.GetNavArea(targetPos, 150);
					if (goalArea != null) break;
				}
			}
		}

		local build = false;
		local goalInCoolDown = goal in buildCoolDown;
		if (!goalInCoolDown) {
			foreach(object, cooldown in buildCoolDown) {
				if (BotAI.isEntityEqual(object, goal))
					goalInCoolDown = true;
			}
		}

		if (!goalInCoolDown) {
			try {
				build = createPath(id, goalPos, goalArea, distance);
			} catch (e) {
				navPrint("Path build time out.");
			}
		}

		if (!build) {
			if (BotAI.BotDebugMode) {
				DebugDrawBox(goalPos, Vector(-5, -5, -5), Vector(5, 5, 5), 255, 0, 255, 0.2, 1.0);
			}

			return false;
		} else {
			if (BotAI.BotDebugMode) {
				navPrint(id + " build complete.");
			}

			local data = PathData(goal, priority, discardFunc, distance);

			pathCache[id] <- data;
		}

		return build;
	}

	function shouldDiscard() {
		if (!moving()) return;

		if (getRunningPathData().discardFunc()) {
			if (BotAI.BotDebugMode) {
				navPrint("Discard: " + movingID);
			}

			stop(true);
		}
	}

	function onUpdate() {
		if (BotAI.BotDebugMode) {
			local height = 20;
			if (moving()) {
				DebugDrawText(player.EyePosition() + Vector(0, 0, height), "running " + movingID + " priority: " + pathCache[movingID].priority, false, 0.2);
				height += 10;
			}

			foreach(name, pathGet in pathCache) {
				if (moving() && name == movingID) continue;
				DebugDrawText(player.EyePosition() + Vector(0, 0, height), name.tostring() + " priority: " + pathGet.priority + " wating", false, 0.2);
				height += 10;
			}
		}

		foreach(idx, val in buildCoolDown) {
			buildCoolDown[idx] <- val - 1;
			if (val < 2)
				delete buildCoolDown[idx];
		}

		foreach(idx, func in NavigatorPause) {
			if (func(player)) {
				return;
			}
		}

		reRun();
		shouldDiscard();

		if (!moving()) {
			return;
		}

		local friction = 1.0;

		if (BotAI.BotCombatSkill > 2 || BotAI.HasTank) {
			friction += 0.2;

			foreach(danger in BotAI.SpecialList) {
				if (danger.GetClassname() == "player" && danger.GetZombieType() == 8) {
					if (BotAI.distanceof(danger.GetOrigin(), player.GetOrigin()) < 310) {
						player.OverrideFriction(0.5, 0.9);
					}

					if (BotAI.distanceof(danger.GetOrigin(), player.GetOrigin()) < 200) {
						friction += 0.5 + BotAI.BotCombatSkill * 0.2;
					}
				}
			}
		}

		if (movingID.find("$") != null) {
			friction += 0.2;
		}

		NetProps.SetPropFloat(player, "m_flLaggedMovementValue", friction);

		local offset = 15;

		if (BotAI.validVector(getRunningPathData().getPos(null))) {
			local goalPos = getRunningPathData().getPos(null);
			if (goalPos == null || goalPos.Length() == 0) {
				stop(true);
				return;
			}

			if (BotAI.BotDebugMode) {
				DebugDrawCircle(goalPos, Vector(0, 0, 255), 1.0, 5, true, 0.2);
				DebugDrawLine(player.EyePosition(), goalPos, 0, 0, 255, true, 0.2);
			}

			if (BotAI.distanceof(player.GetOrigin(), goalPos) > 10) {
				BotAI.botCmdMove(player, goalPos, movingID.find("^") != null);
			} else if (movingID.find("#") != null) {
				player.OverrideFriction(0.5, 10);
			}

			if (movingID.find("#") == null && BotAI.distanceof(BotAI.fakeTwoD(player.GetOrigin()), BotAI.fakeTwoD(goalPos)) <= offset) {
				stop(true);
			}
		}
	}

	function clearPath(id) {
		if (id == movingID)
			stop(true);
		if (id in pathCache)
			delete pathCache[id];
	}

	function moving() {
		return movingID != null && movingID != "";
	}

	function isPathFlat() {
		return pathFlat;
	}

	function isMoving(id) {
		if (id == movingID)
			return true;
		return false;
	}

	function run(id) {
		if (!(id in pathCache)) {
			return;
		}
		if (moving()) {
			local runPath = pathCache[id];
			local runningPath = getRunningPathData();

			if (runPath.priority >= runningPath.priority)
				movingID = id;
		} else
			movingID = id;
	}

	function reRun() {
		if (moving() || pathCache.len() < 1) return;
		local pathID = "";
		local pathFound = null;
		foreach(id, path in pathCache) {
			if (pathFound == null || path.priority > pathFound.priority) {
				if (!path.discardFunc()) {
					pathID = id;
					pathFound = path;
				} else
					clearPath(id);
			}
		}

		if (pathID != "")
			run(pathID);
	}

	function hasPath(id) {
		return getMovingPath(id) != null;
	}

	function stop(resetBot = false) {
		local id = movingID;
		movingID = null;
		if (id in pathCache)
			delete pathCache[id];

		if (resetBot) {
			BotAI.BotReset(player);
		}
	}

	function getMovingPath(id) {
		if (!(id in pathCache)) return null;
		return pathCache[id];
	}

	function getRunningPathData() {
		if (moving() && movingID in pathCache)
			return pathCache[movingID];
		return null;
	}

	function createPath(id, pos, endArea, distance) {
		if (id.find("+") != null) {
			return true;
		}

		local startPos = null;
		local startArea = null;

		if (endArea == null)
			endArea = NavMesh.GetNavArea(pos + Vector(0, 0, 50), 200);
		if (endArea == null)
			endArea = NavMesh.GetNearestNavArea(pos + Vector(0, 0, 50), 200, true, true);

		if (startPos == null && startArea == null) {
			startPos = player.GetOrigin();
			startArea = player.GetLastKnownArea();
		}


		if (startArea == null) {
			navPrint("invalid startArea!");
			return false;
		}

		if (startArea == endArea) {
			return true;
		}

		local build = NavMesh.NavAreaBuildPath(startArea, endArea, pos, distance, 2, false);

		if (!build) {
			navPrint("NavMesh build failed!");
		}

		return build;
	}

	function navPrint(str) {
		if (BotAI.BotDebugMode) {
			printl("[Navigator - " + BotAI.getPlayerBaseName(player) + "] " + str);
		}
	}
}

class::PathData {
	pos = Vector(0, 0, 0);
	priority = 0;
	discard = {};
	distance = 1500;

	constructor(posIn, priorityIn, discardFuncIn, distanceIn) {
		pos = posIn;
		priority = priorityIn;
		discard = {};
		discard["func"] <- discardFuncIn;
		distance = distanceIn;
	}

	function getPos(originalPos) {
		if (BotAI.validVector(pos)) {
			return pos;
		}

		if (BotAI.IsEntityValid(pos) && "GetCenter" in pos) {
			return pos.GetCenter();
		}

		return originalPos;
	}

	function discardFunc() {
		if ("func" in discard)
			return discard["func"]();
		return true;
	}

	function _typeof() {
		return "PathData";
	}
}