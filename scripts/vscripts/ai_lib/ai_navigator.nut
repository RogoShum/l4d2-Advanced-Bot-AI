::NavigatorPause <- {}

class ::Navigator {
    pathCache = {};
    player = null;
    movingID = null;
    lastArea = null;
    buildCoolDown = {};
    faildTimes = {};

	constructor(playerIn) {
        player = playerIn;
        movingID = null;
        pathCache = {};
        lastArea = playerIn.GetLastKnownArea();
        buildCoolDown = {};
        faildTimes = {};
    }
	
    function _typeof () {
        return "Navigator";
    }

	function buildPath(goal, id, priority = 0, discardFunc = BotAI.trueDude, previousPath = null, aStar = false) {
        local goalArea = null;
        local goalPos = null;
        if(typeof goal == "Vector") {
            goalPos = goal;
        } else if(BotAI.IsEntityValid(goal)){
            if("GetLastKnownArea" in goal)
                goalArea = goal.GetLastKnownArea();
            goalPos = goal.GetOrigin();
        } else 
            return false;
        
        if(goalArea == null)
            goalArea = NavMesh.GetNavArea(goalPos, 200);
        
        if(typeof previousPath == "table") {
            local newPaths = [];
            for(local i = 0; i < previousPath.len(); ++i) {
               	newPaths.append(previousPath["area" + i.tostring()]);
            }
            previousPath = newPaths;
        }

        local paths = {};
        local build = false;
        local buildAStar = false;
        if(!(goal in buildCoolDown)) {
            if(aStar) {
                try {
                    build = createPath(goalPos, goalArea, paths, previousPath);
                }
                catch(e) {

                }
            }
            else {
                try {
                    build = createPath(goalPos, goalArea, paths);
                }
                catch(e) {

                }
            }
        }

        if(!build) {
            if(!(goal in buildCoolDown)) {
                local count = 100;
                if(goal in faildTimes) {
                    faildTimes[goal] <- faildTimes[goal] + 1;
                    count *= faildTimes[goal];
                }
                else
                    faildTimes[goal] <- 1;
                buildCoolDown[goal] <- count;
            }
               
            
            if(BotAI.BOT_AI_TEST_MOD == 1) {
                printl(id + " build faild." + " goal " + goal);
            }
            build = NavMesh.GetNavAreasFromBuildPath(player.GetLastKnownArea(), goalArea, goalPos, 999999, 2, false, paths);
        } else {
            if(BotAI.BOT_AI_TEST_MOD == 1)
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
            if(BotAI.BOT_AI_TEST_MOD == 1)
                printl(id + " build complete.");
            local data = PathData(paths, goal, priority, discardFunc);
            if(buildAStar)
                data.aStar = true;
            pathCache[id] <- data;
        } else if(id.find("ping") != null) {
            player.SetOrigin(goalPos);
        }

        return build;
    }

    function shouldDiscard() {
        if(!moving()) return;
        if(getRunningPathData().discardFunc())
            stop();
    }

    function onUpdate() {
        if(BotAI.BOT_AI_TEST_MOD == 1) {
            if(buildCoolDown.len() > 0)
                printl("===buildCoolDown===");
            BotAI.printTable(buildCoolDown);
        }

        foreach(idx, val in buildCoolDown) {
            buildCoolDown[idx] <- val - 1;
            if(val < 2)
                delete buildCoolDown[idx];
        }

        foreach(func in NavigatorPause) {
            if(func(player)) {
                return;
            } 
        }
        if(pathCache.len() < 1) {
            return;
        }
        
        reRun();
        if(BotAI.BOT_AI_TEST_MOD == 1) {
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
        
        shouldDiscard();
        if(!moving()) {
            return;
        }
        if(BotAI.BOT_AI_TEST_MOD != 2 && !BotAI.HasTank)
            player.OverrideFriction(0.5, 0.8);
		recordLastArea();
		local paths = getRunningPathData().paths;
        local offset = 25;
		if(paths != null && BotAI.validVector(getRunningPathData().getPos())) {
			if(BotAI.IsOnGround(player)) {
                BotAI.DisableButton(player, BUTTON_WALK, 1.0);
            }
			local goalPos = getRunningPathData().getPos();
			local xyGoalPos = goalPos;
			local xyTracePos = BotAI.tracePos(player, goalPos, true);
			 if(BotAI.BOT_AI_TEST_MOD == 1) {
			    DebugDrawCircle(xyGoalPos, Vector(0, 255, 255), 1.0, 5, true, 0.2);
			    DebugDrawLine(player.EyePosition(), xyGoalPos, 0, 255, 255, true, 0.2);
            }
            
			if(BotAI.distanceof(xyGoalPos, xyTracePos)<= offset) {
                if(BotAI.distanceof(player.GetOrigin(), goalPos) > 10)
				    BotAI.botRun(player, goalPos, 400);
                else if(movingID.find("#") != null) {
                    player.OverrideFriction(0.5, 10);
                    player.SetVelocity(Vector(0, 0, player.GetVelocity().z));
                }
                    
				if(movingID.find("#") == null && BotAI.distanceof(BotAI.fakeTwoD(player.GetOrigin()), BotAI.fakeTwoD(goalPos)) <= offset) {
					stop();
				}
				return;
			}

			if(paths.len() <= 0){
                if((goalPos.z - player.GetOrigin().z) >= 56)
				    player.SetOrigin(goalPos);
                return;
            }

			if(BotAI.BOT_AI_TEST_MOD == 1) {
			    for(local i = 0; i < paths.len(); ++i) {
            	    local path = paths["area" + i];
            	    path.DebugDrawFilled(0, 255, 0, 15, 0.2, true);
            	    DebugDrawText(path.GetCenter(), i.tostring(), false, 0.2);
        	    }
            }
            
            try {
                paths["area0"]
            }
            catch(e) {
                BotAI.printArray(paths)
            }

			local firstArea = paths["area" + (paths.len() - 1)];
			
			if(firstArea.IsDamaging()) {
                return;
            }
			if(BotAI.BOT_AI_TEST_MOD == 1 && BotAI.validVector(xyTracePos)) {
				DebugDrawCircle(xyTracePos, Vector(255, 0, 255), 1.0, 5, true, 0.2);
				DebugDrawLine(player.EyePosition(), xyTracePos, 255, 0, 255, true, 0.2);
			}

			if(firstArea != player.GetLastKnownArea()) {
				local xyCenter = firstArea.GetCenter();
				local xyAreaPos = BotAI.tracePos(player, firstArea.GetCenter());
                if(BotAI.BOT_AI_TEST_MOD == 1) {
				    DebugDrawCircle(xyCenter, Vector(0, 255, 255), 1.0, 5, true, 0.2);
				    DebugDrawLine(player.EyePosition(), xyCenter, 0, 255, 255, true, 0.2);
				    if(BotAI.validVector(xyAreaPos)) {
					    DebugDrawCircle(xyAreaPos, Vector(255, 0, 255), 1.0, 5, true, 0.2);
					    DebugDrawLine(player.EyePosition(), xyAreaPos, 255, 0, 255, true, 0.2);
				    }
                }

                if(firstArea.IsBottleneck() && BotAI.IsOnGround(player)) {
		            BotAI.ForceButton(player, 2 , 0.2);
                }

                if(firstArea.GetCenter().z - player.GetOrigin().z >= 56)
					player.SetOrigin(firstArea.GetCenter());
                if(player.GetLastKnownArea().IsBottleneck() || player.GetOrigin().z - firstArea.GetCenter().z >= 100) {
                    player.SetOrigin(firstArea.GetCenter());
                }

				local traceFirst = BotAI.distanceof(xyCenter, xyAreaPos) <= offset;
				if(traceFirst)
					BotAI.botRun(player, firstArea.GetCenter(), 400);
				else
					BotAI.botRun(player, player.GetLastKnownArea().GetCenter(), 400);
			}
		}
    }

    function clearPath(id) {
        if(id == movingID)
            stop();
        if(id in pathCache)
            delete pathCache[id];
    }

    function moving() {
        return movingID != null && movingID != "";
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

    function stop() {
        local id = movingID;
        movingID = null;
        if(id in pathCache)
            delete pathCache[id];
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

    function recordLastArea() {
        if(lastArea != player.GetLastKnownArea()) {
            lastArea = player.GetLastKnownArea();
            if(moving()) {
                local data = getRunningPathData();
                local discard = data.discard;

                if("func" in discard)
                    buildPath(data.pos, movingID, data.priority, discard["func"], data.paths, data.aStar);
                else
                    buildPath(data.pos, movingID, data.priority, BotAI.trueDude, data.paths, data.aStar);
            }
        }
    }

    function createPath(pos, endArea, paths, previousPath = null, startPos = null, startArea = null) {
        if(endArea == null)
            endArea = NavMesh.GetNavArea(pos + Vector(0, 0, 50), 200);
        if(endArea == null)
            endArea = NavMesh.GetNearestNavArea(pos + Vector(0, 0, 50), 200, true, true);

        if(endArea == null)
            return false;
        //endArea.DebugDrawFilled(0, 0, 255, 100, 10, true);
        local re = false;
        local checked = {};
        local needCheack = {};
        local deleteFirstArea = false;
        if(startPos == null && startArea == null) {
            startPos = player.GetOrigin();
            startArea = player.GetLastKnownArea();
            deleteFirstArea = true;
        } else
            re = true;

		local playerArea = AreaData(startArea, null, 0, BotAI.distanceof(startPos, pos));
        if(startArea != null)
            needCheack[startArea.GetID()] <- playerArea;

		while(needCheack.len() > 0) {
            local mostSuitable = null;
            foreach(idx, areaData in needCheack) {
			    if(mostSuitable == null || (areaData.exactCost + areaData.estimatedCost) < (mostSuitable.exactCost + mostSuitable.estimatedCost))
                    mostSuitable = areaData;
            }

            if(typeof previousPath == "array" && previousPath.find(mostSuitable.area)) {
                local idx = previousPath.find(mostSuitable.area);
                local cachePaths = [];
                local newPaths = [];
                local function filter(index, val) {
                    return index < idx;
                }
                previousPath = previousPath.filter(filter);
                local areaData = mostSuitable;
                while(areaData != null) {
                    cachePaths.append(areaData.area);
                    areaData = areaData.lastArea;
                }

                local len = cachePaths.len() + previousPath.len();

                newPaths.extend(previousPath);
                newPaths.extend(cachePaths);

                if(re) {
                    newPaths.reverse();
                    foreach(idx, path in newPaths) {
                        if(path != player.GetLastKnownArea())
                            paths["area" + idx] <- path;
                    }
                    return true;
                }
                else {
                    newPaths.reverse();
                    local build = createPath(player.GetOrigin(), player.GetLastKnownArea(), paths, newPaths, pos, endArea);
                    if(build)
                        return true;
                }
            }
            
			for(local i = 0; i < 4; ++i) {
                local adjacentAreas = {};
				mostSuitable.area.GetAdjacentAreas(i, adjacentAreas);
                //if( i < 2 ) {
                local ladders = {};
                mostSuitable.area.GetLadders(i, ladders);
                foreach(ladder in ladders) {
                    if(ladder.IsValid() && ladder.IsUsableByTeam(2)) {
                        if("GetID" in ladder.GetBottomArea() && ladder.GetBottomArea().GetID() == mostSuitable.area.GetID())
                            adjacentAreas["area" + adjacentAreas.len()] <- ladder.GetTopArea();
                        else if("GetID" in ladder.GetTopArea() && ladder.GetTopArea().GetID() == mostSuitable.area.GetID())
                            adjacentAreas["area" + adjacentAreas.len()] <- ladder.GetBottomArea();
                    }
                }

                //}
				foreach(adjacent in adjacentAreas) {
				    if(!adjacent.IsValid() || adjacent.IsBlocked(2, false) || adjacent.IsDamaging()) continue;
                    if(adjacent.GetID() in checked) {
                        if(mostSuitable.lastArea == null)
                            continue;
                        local checkedArea = checked[adjacent.GetID()];
                        if(checkedArea.exactCost < mostSuitable.lastArea.exactCost) {
                            local updatePath = AreaData(mostSuitable.area, checkedArea, checkedArea.exactCost + BotAI.distanceof(mostSuitable.area.GetCenter(), checkedArea.area.GetCenter()), mostSuitable.estimatedCost);
                            mostSuitable = updatePath;
                            checked[mostSuitable.area.GetID()] <- updatePath;
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
                        return true;
                    }
                    local area = AreaData(adjacent, mostSuitable, mostSuitable.exactCost + BotAI.distanceof(adjacent.GetCenter(), mostSuitable.area.GetCenter()), BotAI.distanceof(adjacent.GetCenter(), pos));
                    //local area = AreaData(adjacent, BotAI.distanceof(adjacent.GetCenter(), pos), mostSuitable);
					needCheack[adjacent.GetID()] <- area;
                    checked[adjacent.GetID()] <- area;
                    //adjacent.DebugDrawFilled(0, 0, 255, 30, 10, true);
				}
			}

            if(mostSuitable != null) {
                delete needCheack[mostSuitable.area.GetID()];
                //mostSuitable.area.DebugDrawFilled(255, 0, 0, 30, 10, true);
            }
		}

        return false;
    }
}

class ::PathData {
    paths = {};
    pos = Vector(0, 0, 0);
    priority = 0;
    discard = {};
    aStar = false;

	constructor(pathsIn, posIn, priorityIn, discardFuncIn) {
        paths = pathsIn;
        pos = posIn;
        priority = priorityIn;
        discard = {};
        discard["func"] <- discardFuncIn;
        aStar = false;
    }

    function getPos() {
        if(BotAI.validVector(pos))
            return pos;
        if(BotAI.IsEntityValid(pos) && "GetOrigin" in pos)
            return pos.GetOrigin();
        return Vector(0, 0, 0);
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
