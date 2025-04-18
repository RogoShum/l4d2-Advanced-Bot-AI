::NavigatorPause <- {}

class ::Navigator {
    pathCache = {};
    seachingPath = {};
    player = null;
    movingID = null;
    lastArea = null;
    buildCoolDown = {};
    faildTimes = {};
    posCheck = null;
    checkTime = Time();
    timeOut = Time();
    pathFlat = true;
    SEARCH_LIMIT = 128;
    TIME_OUT_LIMIT = 5;
    JUMP_HIGHT = 50;

	constructor(playerIn) {
        player = playerIn;
        movingID = null;
        pathCache = {};
        seachingPath = {};
        lastArea = playerIn.GetLastKnownArea();
        buildCoolDown = {};
        faildTimes = {};
        posCheck = playerIn.GetOrigin();
        checkTime = Time();
        timeOut = Time();
    }

    function _typeof () {
        return "Navigator";
    }

	function buildPath(goal, id, priority = 0, discardFunc = BotAI.trueDude, previousPath = null, aStar = false, distance = 10000) {
        if(timeOut > Time())
            return false;
        local goalArea = null;
        local goalPos = null;
        if(typeof goal == "Vector") {
            goalPos = goal;
        } else if(BotAI.IsEntityValid(goal)) {
            if("GetLastKnownArea" in goal)
                goalArea = goal.GetLastKnownArea();
            goalPos = goal.GetOrigin();
        } else
            return false;

        if(goalArea == null) {
            goalArea = NavMesh.GetNavArea(goalPos, 150);
            if(goalArea == null && BotAI.IsTriggerUsable(goal)) {
                local direcVec = Vector(120, 0, 0);
                for(local i = 0; i < 8; ++i) {
					local angleVec = BotAI.rotateVector(direcVec, i * 45);
                    local targetPos = goalPos + angleVec;
					if(BotAI.BotDebugMode) {
						DebugDrawCircle(targetPos, Vector(0, 0, 255), 1.0, 5, true, 1.0);
						DebugDrawText(targetPos, "goal", false, 1.0);
					}

                    goalArea = NavMesh.GetNavArea(targetPos, 150);
                    if(goalArea != null) break;
				}
            }
        }

        if(typeof previousPath == "table") {
            local newPaths = [];
            for(local i = 0; i < previousPath.len(); ++i) {
                if(("area" + i.tostring()) in previousPath)
                	newPaths.append(previousPath["area" + i.tostring()]);
            }
            previousPath = newPaths;
        }

        local paths = {};
        local build = false;
        local buildAStar = false;
        local goalInCoolDown = goal in buildCoolDown;
        if(!goalInCoolDown)
        foreach(object, cooldown in buildCoolDown) {
            if(BotAI.isEntityEqual(object, goal))
                goalInCoolDown = true;
        }

        local pathSearch = null;
        local newPath = true;
        if(id in seachingPath) {
            newPath = false;
            pathSearch = seachingPath[id];
        } else {
            pathSearch = PathSearch(goal);
            pathSearch.allowDanger = id.find("%") != null;
            pathSearch.dataPaths = paths;
            pathSearch.dataGoal = goal;
            pathSearch.dataPriority = priority;
            pathSearch.dataDiscardFunc = discardFunc;
            pathSearch.dataDistance = distance;
            pathSearch.dataGoalPos = goalPos;
            pathSearch.dataGoalArea = goalArea;
        }

        if(newPath && !goalInCoolDown) {
            if(aStar) {
                try {
                    build = createPath(pathSearch, goalPos, goalArea, distance, paths, previousPath);
                } catch(e) {
                    timeOut = Time() + 1;
                    printl("[Navigator] Path build time out.");
                }
            } else {
                try {
                    build = createPath(pathSearch, goalPos, goalArea, distance, paths);
                } catch(e) {
                    timeOut = Time() + 1;
                    printl("[Navigator] Path build time out.");
                }
            }
        }

        if(!build) {
            if(!(id in seachingPath)) {
                seachingPath[id] <- pathSearch;
            }

            local faildBuild = false;
            //if(navAPI)
                //faildBuild = !createPath(goalPos, goalArea, paths);

            /*
            if(!faildBuild && navAPI) {
                paths = {};
                build = NavMesh.GetNavAreasFromBuildPath(player.GetLastKnownArea(), null, goalPos, 9999, 2, false, paths);
                printl("build: " + build);
            }
            */
        } else {
            if(BotAI.BotDebugMode)
                printl("A-Star build success.");

            buildAStar = true;
            if(goal in faildTimes)
                delete faildTimes[goal];
        }


        /*
        if(build && paths.len() > 0) {
            local firstArea = paths["area" + (paths.len() - 1)];
            if(firstArea.IsBlocked(2, true) || !firstArea.IsValid()) {
                return false;
            }
        }
        */
        if(build) {
            if(BotAI.BotDebugMode)
                printl(id + " build complete.");
            local data = PathData(paths, goal, priority, discardFunc, distance);

            if(buildAStar)
                data.aStar = true;
            pathCache[id] <- data;
        }

        return build;
    }

    function shouldDiscard() {
        if(!moving()) return;

        if(getRunningPathData().discardFunc()) {
            if(BotAI.BotDebugMode)
                printl("[Navigator] Discard: " + movingID);
            stop(true);
        }
    }

    function onUpdate() {
        if(BotAI.BotDebugMode) {
            local height = 20;
            if(moving()) {
                DebugDrawText(player.EyePosition() + Vector(0, 0, height), "running " + movingID + " priority: " + pathCache[movingID].priority, false, 0.2);
                height += 10;
            }

            foreach(name, pathGet in pathCache) {
                if(moving() && name == movingID) continue;
                DebugDrawText(player.EyePosition() + Vector(0, 0, height), name.tostring() + " priority: " + pathGet.priority + " wating", false, 0.2);
                height += 10;
            }
        }

        foreach(id, pathFinding in seachingPath) {
            if(Time() - pathFinding.timeOut >= TIME_OUT_LIMIT || pathFinding.fail) {
                local inCoolDown = pathFinding.dataGoal in buildCoolDown;
                if(!inCoolDown)
                foreach(object, cooldown in buildCoolDown) {
                    if(BotAI.isEntityEqual(object, pathFinding.dataGoal))
                        inCoolDown = true;
                    }
                if(!inCoolDown) {
                    local count = 200;
                    if(pathFinding.dataGoal in faildTimes) {
                        faildTimes[pathFinding.dataGoal] <- faildTimes[pathFinding.dataGoal] + 1;
                        count *= faildTimes[pathFinding.dataGoal];
                    } else
                    faildTimes[pathFinding.dataGoal] <- 1;

                    buildCoolDown[pathFinding.dataGoal] <- count;
                }
                if( BotAI.BotDebugMode) {
                    printl(id + " A-Star build faild." + " goal " + pathFinding.dataGoal);
                }
                delete seachingPath[id];
            } else {
                local success = createPath(pathFinding, pathFinding.dataGoalPos, pathFinding.dataGoalArea, pathFinding.dataDistance, pathFinding.paths);
                if(success) {
                    if(BotAI.BotDebugMode) {
                        DebugDrawBox(pathFinding.dataGoalPos, Vector(-10, -10, -10), Vector(10, 10, 10), 100, 255, 0, 0.2, 5);
                        DebugDrawText(pathFinding.dataGoalPos, id, true, 5);
                        printl(id + " build complete.");
                        if(id == "buildTest") {
                            foreach(idx, path in pathFinding.paths) {
                                path.DebugDrawFilled(0, 255, 0, 50, 5, true);
                                DebugDrawText(path.GetCenter(), idx.tostring(), true, 5);
                            }
                        }
                    }

                    local data = PathData(pathFinding.paths, pathFinding.dataGoal, pathFinding.dataPriority, pathFinding.dataDiscardFunc, pathFinding.dataDistance);
                    data.aStar = true;
                    if(BotAI.BotDebugMode)
                        printl("A-Star build success.");

                    if(pathFinding.dataGoal in faildTimes)
                        delete faildTimes[pathFinding.dataGoal];
                    pathCache[id] <- data;
                    run(id);
                    delete seachingPath[id];
                }
            }
        }

        foreach(idx, val in buildCoolDown) {
            buildCoolDown[idx] <- val - 1;
            if(val < 2)
                delete buildCoolDown[idx];
        }

        foreach(idx, func in NavigatorPause) {
            if(func(player)) {
                return;
            }
        }

        reRun();
        shouldDiscard();

        if(!moving()) {
            return;
        }

        if(BotAI.BotFullPower || BotAI.HasTank) {
            local friction = 1.2;

            foreach(danger in BotAI.SpecialList) {
                if (danger.GetClassname() == "player" && danger.GetZombieType() == 8 && BotAI.distanceof(danger.GetOrigin(), player.GetOrigin()) < 200) {
                    friction = 2.0;
                }
            }

            NetProps.SetPropFloat(player, "m_flLaggedMovementValue", friction);
            //player.OverrideFriction(0.5, friction);
        } else {
            NetProps.SetPropFloat(player, "m_flLaggedMovementValue", 1.0);
        }

        local offset = 15;

		if(BotAI.validVector(getRunningPathData().getPos(null))) {
			local goalPos = getRunningPathData().getPos(null);
            if(goalPos == null || goalPos.Length() == 0) {
                stop(true);
                return;
            }

			if(BotAI.BotDebugMode) {
			    DebugDrawCircle(goalPos, Vector(0, 0, 255), 1.0, 5, true, 0.2);
			    DebugDrawLine(player.EyePosition(), goalPos, 0, 0, 255, true, 0.2);
            }

            if(BotAI.distanceof(player.GetOrigin(), goalPos) > 10) {
                BotAI.botCmdMove(player, goalPos);
            } else if(movingID.find("#") != null) {
                player.OverrideFriction(0.5, 10);
            }

            if(movingID.find("#") == null && BotAI.distanceof(BotAI.fakeTwoD(player.GetOrigin()), BotAI.fakeTwoD(goalPos)) <= offset) {
                stop(true);
            }
		}
    }

    function clearPath(id) {
        if(id == movingID)
            stop(true);
        if(id in pathCache)
            delete pathCache[id];
    }

    function moving() {
        return movingID != null && movingID != "";
    }

    function isPathFlat() {
        return pathFlat;
    }

    function isMoving(id) {
        if(id == movingID)
            return true;
        return false;
    }

    function run(id) {
        if(!(id in pathCache)) { return; }
        if(moving()) {
            local runPath = pathCache[id];
            local runningPath = getRunningPathData();

            if(runPath.priority >= runningPath.priority)
                movingID = id;
        } else
             movingID = id;
    }

    function reRun() {
        if(moving() || pathCache.len() < 1) return;
        local pathID = "";
        local pathFound = null;
        foreach(id, path in pathCache) {
            if(pathFound == null || path.priority > pathFound.priority) {
                if(!path.discardFunc()) {
                    pathID = id;
                    pathFound = path;
                } else
                    clearPath(id);
            }
        }

        if(pathID != "")
            run(pathID);
    }

    function hasPath(id) {
        return getMovingPath(id) != null;
    }

    function stop(resetBot = false) {
        local id = movingID;
        movingID = null;
        if(id in pathCache)
            delete pathCache[id];

        if (resetBot) {
            BotAI.BotReset(player);
        }
    }

    function getMovingPath(id) {
        if(!(id in pathCache)) return null;
        return pathCache[id];
    }

    function getRunningPathData() {
        if(moving() && movingID in pathCache)
            return pathCache[movingID];
        return null;
    }

    function addLadder(ladderArea, adjacentAreas, dir) {
        if(ladderArea == null) return;
        local ladders = {};
        ladderArea.GetLadders(dir, ladders);
        foreach(ladder in ladders) {
            if(ladder.IsValid() && ladder.IsUsableByTeam(2)) {
                local areaIn = null;
                local areaOut = null;
                if("GetID" in ladder.GetBottomArea() && ladder.GetBottomArea().GetID() == ladderArea.GetID() && ladder.GetTopArea() != null && ladder.GetTopArea().IsValid()) {
                    adjacentAreas[ladder.GetTopArea().GetID()] <- ladder.GetTopArea();
                    areaIn = ladder.GetBottomArea();
                    areaOut = ladder.GetTopArea();
                } else if("GetID" in ladder.GetTopArea() && ladder.GetTopArea().GetID() == ladderArea.GetID() && ladder.GetBottomArea() != null && ladder.GetBottomArea().IsValid()) {
                    adjacentAreas[ladder.GetBottomArea().GetID()] <- ladder.GetBottomArea();
                    areaIn = ladder.GetTopArea();
                    areaOut = ladder.GetBottomArea();
                }
                if(BotAI.BotDebugMode) {
                    local height = ladder.GetLength()/2;
                    local width = ladder.GetWidth()/2;
                    DebugDrawBox(ladder.GetBottomOrigin() + Vector(0, 0, height), Vector(-width, -width, -height), Vector(width, width, height), 0, 255, 255, 0.2, 5);
                    DebugDrawText(ladder.GetBottomOrigin() + Vector(0, 0, height), "ladder", true, 5);
                    if(areaIn != null) {
                        if(areaIn == ladder.GetBottomArea()) {
                            BotAI.drawArrow(ladder.GetBottomArea().GetCenter(), ladder.GetBottomOrigin(), Vector(0, 255, 255), 5);
                        } else if(areaIn == ladder.GetTopArea()) {
                            BotAI.drawArrow(ladder.GetTopArea().GetCenter(), ladder.GetTopOrigin(), Vector(0, 255, 255), 5);
                        }
                    }
                    if(areaOut != null) {
                        if(areaOut == ladder.GetBottomArea()) {
                            BotAI.drawArrow(ladder.GetBottomOrigin(), ladder.GetBottomArea().GetCenter(), Vector(0, 255, 255), 5);
                        } else if(areaOut == ladder.GetTopArea()) {
                            BotAI.drawArrow(ladder.GetTopOrigin(), ladder.GetTopArea().GetCenter(), Vector(0, 255, 255), 5);
                        }
                    }
                }

                local had = false;
                foreach(idx, val in adjacentAreas) {
                    if(val == areaOut)
                        had = true;
                }

                if(!had && areaOut != null) {
                    for(local i = 0; i < 4; ++i) {
                        addLadder(areaOut, adjacentAreas, i);
                    }
                }
            }
        }
    }

    function createPath(pathSearch, pos, endArea, distance, paths, previousPath = null, startPos = null, startArea = null) {
        if(endArea == null)
            endArea = NavMesh.GetNavArea(pos + Vector(0, 0, 50), 200);
        if(endArea == null)
            endArea = NavMesh.GetNearestNavArea(pos + Vector(0, 0, 50), 200, true, true);

        if(endArea == null)
            return false;
        //endArea.DebugDrawFilled(0, 0, 255, 100, 10, true);
        local checked = pathSearch.checked;
        local needCheack = pathSearch.needCheack;
        if(startPos == null && startArea == null) {
            startPos = player.GetOrigin();
            startArea = player.GetLastKnownArea();
        }

        if(startArea == endArea) {
            return true;
        }

        if(startArea.IsConnected(endArea, -1)) {
            paths["area0"] <- endArea;
            return true;
        }

		local playerArea = AreaData(startArea, null, 0, BotAI.distanceof(startPos, pos));
        if(startArea != null)
            needCheack[startArea.GetID()] <- playerArea;

        local searchCount = 0;
        local reachLimit = false;
		while(needCheack.len() > 0) {
            local mostSuitable = null;
            foreach(idx, areaData in needCheack) {
			    if(mostSuitable == null || (areaData.exactCost + areaData.estimatedCost) < (mostSuitable.exactCost + mostSuitable.estimatedCost))
                    mostSuitable = areaData;
            }

			for(local i = 0; i < 4; ++i) {
                local adjacentAreas = BotAI.areaAdjacent(mostSuitable.area, i);
                local ladders = {};
                addLadder(mostSuitable.area, ladders, i);
                foreach(ladder in ladders) {
                    adjacentAreas["area" + adjacentAreas.len()] <- ladder;
                }

				foreach(adjacent in adjacentAreas) {
				    if(!adjacent.IsValid() || adjacent.IsBlocked(2, false) || (adjacent.IsDamaging() && !pathSearch.allowDanger)) continue;
                    local dir = 0;
                    if(i == 0)
                        dir = 2;
                    if(i == 1)
                        dir = 3;
                    if(i == 3)
                        dir = 1;
                    local lowCorner = BotAI.getLowOriginFromArea(adjacent, dir);
                    local highCorner = BotAI.getHighOriginFromArea(mostSuitable.area, i);
                    if(lowCorner.z - highCorner.z > JUMP_HIGHT && !(adjacent.GetID() in ladders)) {
                        continue;
                    }

                    local exactCost = mostSuitable.exactCost + BotAI.distanceof(adjacent.GetCenter(), mostSuitable.area.GetCenter());
                    if(exactCost > distance)
                        continue;

                    if(adjacent.GetID() in checked) {
                        if(mostSuitable.lastArea == null)
                            continue;
                        local checkedArea = checked[adjacent.GetID()];
                        if(checkedArea.exactCost < mostSuitable.lastArea.exactCost) {
                            local highLayer = BotAI.getHighOriginFromArea(checkedArea.area, dir);
                            local lowLayer = BotAI.getLowOriginFromArea(mostSuitable.area, i);
                            if(lowLayer.z - highLayer.z <= JUMP_HIGHT || adjacent in ladders) {
                                local updatePath = AreaData(mostSuitable.area, checkedArea, checkedArea.exactCost + BotAI.distanceof(mostSuitable.area.GetCenter(), checkedArea.area.GetCenter()), mostSuitable.estimatedCost);
                                mostSuitable = updatePath;
                                checked[mostSuitable.area.GetID()] <- updatePath;
                            }
                        }
                        continue;
                    }
                    if((endArea != null && adjacent.GetID() == endArea.GetID()) || adjacent.ContainsOrigin(pos)) {
                        local pathBack = adjacent;
                        local areaData = mostSuitable;
                        while(areaData != null && areaData.area != player.GetLastKnownArea()) {
                            paths["area" + paths.len()] <- pathBack;
                            pathBack = areaData.area;
                            areaData = areaData.lastArea;
                        }
                        if(BotAI.BotDebugMode) {
                            printl("[Navigator] search area: " + checked.len());
                            printl("[Navigator] search distance: " + mostSuitable.exactCost + mostSuitable.estimatedCost);
                        }
                        pathSearch.done = true;
                        pathSearch.paths = paths;
                        return true;
                    }
                    local area = AreaData(adjacent, mostSuitable, exactCost, BotAI.distanceof(adjacent.GetCenter(), pos));
					needCheack[adjacent.GetID()] <- area;
                    checked[adjacent.GetID()] <- area;
                    searchCount++;
                    if(searchCount >= SEARCH_LIMIT) {
                        reachLimit = true;
                    }
				}
			}

            if(mostSuitable != null) {
                delete needCheack[mostSuitable.area.GetID()];
                //mostSuitable.area.DebugDrawFilled(255, 0, 0, 30, 10, true);
            }

            if(reachLimit) {
                if(BotAI.BotDebugMode) {
                    printl("[Navigator] searching over " + SEARCH_LIMIT + " area, wait a tick...");
                    printl("[Navigator] searched area size: " + checked.len());
                    printl("[Navigator] searched distance: " + mostSuitable.exactCost + mostSuitable.estimatedCost);
                }
                return false;
            }
		}
        pathSearch.fail = true;
        return false;
    }
}

class ::PathData {
    paths = {};
    pos = Vector(0, 0, 0);
    priority = 0;
    discard = {};
    aStar = false;
    distance = 1500;

	constructor(pathsIn, posIn, priorityIn, discardFuncIn, distanceIn) {
        paths = pathsIn;
        pos = posIn;
        priority = priorityIn;
        discard = {};
        discard["func"] <- discardFuncIn;
        aStar = false;
        distance = distanceIn;
    }

    function getPos(originalPos) {
        if(BotAI.validVector(pos)) {
            return pos;
        }

        if(BotAI.IsEntityValid(pos) && "GetCenter" in pos) {
            return pos.GetCenter();
        }

        return originalPos;
    }

    function discardFunc() {
        if("func" in discard)
            return discard["func"]();
        return true;
    }

    function _typeof () {
        return "PathData";
    }
}

class ::PathSearch {
    paths = {};
    checked = {};
    needCheack = {};
    pos = Vector(0, 0, 0);
    timeOut = Time();
    allowDanger = false;
    done = false;
    fail = false;
    dataPaths = {};
    dataGoal = null;
    dataPriority = 0;
    dataDiscardFunc = null;
    dataDistance = 1000;
    dataGoalPos = null;
    dataGoalArea = null;

	constructor(posIn) {
        paths = {};
        checked = {};
        needCheack = {};
        pos = posIn;
        timeOut = Time();
        allowDanger = false;
        done = false;
        fail = false;
        dataPaths = {};
        dataGoal = null;
        dataPriority = 0;
        dataDiscardFunc = BotAI.trueDude;
        dataDistance = 1000;
        dataGoalPos = null;
        dataGoalArea = null;
    }

    function isSamePath(posIn) {
        if(posIn == pos) return true;

        local realPos = null;
        if(BotAI.validVector(pos))
            realPos = pos;
        if(BotAI.IsEntityValid(pos) && "GetOrigin" in pos)
            realPos = pos.GetOrigin();

        if(BotAI.validVector(posIn))
            return posIn == realPos;
        if(BotAI.IsEntityValid(posIn) && "GetOrigin" in posIn)
            return posIn.GetOrigin() == realPos;
        return false;
    }

    function _typeof () {
        return "PathSearch";
    }
}

class ::AreaData {
    area = null;
    lastArea = null;
    exactCost = 999999;
    estimatedCost = 999999;

	constructor(areaIn, lastAreaIn, exactCostIn, estimatedCostIn) {
        area = areaIn;
        lastArea = lastAreaIn;
        exactCost = exactCostIn;
        estimatedCost = estimatedCostIn;
    }

    function _typeof () {
        return "AreaData";
    }
}
