class::AITaskAvoidDanger extends AITaskSingle {

	constructor(orderIn, tickIn, compatibleIn, forceIn) {
		base.constructor(orderIn, tickIn, compatibleIn, forceIn);
	}

	name = "avoidDanger";
	single = true;
	updating = {};
	playerTick = {};

	function singleUpdateChecker(player) {
		local dangerous = {};

		if (BotAI.IsPlayerClimb(player) || player.IsIncapacitated() || player.IsDominatedBySpecialInfected() || player.IsStaggering()) {
			BotAI.setBotDedgeVector(player, null);
			return false;
		}

		foreach(danger in BotAI.groundList) {
			if (BotAI.IsEntityValid(danger) && BotAI.distanceof(danger.GetOrigin(), player.GetOrigin()) < 270) {
				local dangerName = danger.GetClassname();
				local fireProtect = (dangerName == "env_entity_igniter" || dangerName == "entityflame" || dangerName == "inferno") && BotAI.FireProtect;
				local acidProtect = dangerName == "insect_swarm" && BotAI.AcidProtect;

				if (!fireProtect && !acidProtect) {
					dangerous[dangerous.len()] <- danger;
				}
			}
		}

		foreach(special in BotAI.SpecialList) {
			if (BotAI.IsAlive(special) && !special.IsGhost()) {
				local distance = BotAI.distanceof(special.GetOrigin(), player.GetOrigin());

				if (distance <= 600 && (special.GetZombieType() == 3 || special.GetZombieType() == 5 || special.GetZombieType() == 6 || special.GetZombieType() == 8) &&
					!BotAI.IsEntityValid(BotAI.getSiVictim(special)) && (BotAI.GetTarget(special) == player || (special.GetZombieType() == 8 && distance < 250)) &&
					BotAI.CanShotOtherEntityInSight(player, special, -1, MASK_UNTHROUGHABLE)) {
						dangerous[dangerous.len()] <- special;
				}
			}
		}

		foreach(entW in BotAI.WitchList) {
			if (BotAI.IsAlive(entW) && BotAI.distanceof(player.GetOrigin(), entW.GetOrigin()) < 600 && !BotAI.witchRetreat(entW) && BotAI.CanShotOtherEntityInSight(player, entW, -1, MASK_UNTHROUGHABLE))
				dangerous[dangerous.len()] <- entW;
		}

		BotAI.setBotAvoid(player, dangerous);

		if (dangerous.len() > 0) {
			return true;
		} else {
			BotAI.setBotDedgeVector(player, null);
			return false;
		}
	}

	function playerUpdate(player) {
		local dangerous = BotAI.getBotAvoid(player);

		if (dangerous.len() > 0) {
			local vec3d = Vector(0, 0, 0);
			local vecList = {};
			local length = 0;
			local height = 80;
			foreach(idx, danger in dangerous) {
				if (!BotAI.IsEntityValid(danger))
					continue;

				local name = danger.GetClassname();

				if (BotAI.BotDebugMode) {
					//DebugDrawText(player.EyePosition() + Vector(0, 0, height), "Avoid: " + name, false, 0.5);
					height += 10;
				}

				if (name in BotAI.enumGround) {
					local lastArea = player.GetLastKnownArea();
					local function feelSafe() {
						local area = player.GetLastKnownArea();
						local safe = !area.IsDamaging();
						if (safe) {
							BotAI.botStayPos(player, area.GetCenter(), "avoidDanger", 6, 2)
						}

						return safe;
					}

					if (lastArea && lastArea.IsDamaging()) {
						local doSomethingDangerous = BotAI.IsPlayerReviving(player);
						local follow = false;
						foreach(humanPlayer in BotAI.SurvivorHumanList) {
							if (!follow && BotAI.distanceof(player.GetOrigin(), humanPlayer.GetOrigin()) < 300) {
								BotAI.botRunPos(player, humanPlayer, "followPlayer", 4, feelSafe);
								follow = true;
							}
						}

						if (!follow || doSomethingDangerous) {
							local areas = {};
							NavMesh.GetNavAreasInRadius(player.GetOrigin(), 400, areas);
							local safeArea = null;
							foreach(area in areas) {
								if (!area.IsDamaging() && (safeArea == null || BotAI.distanceof(player.GetOrigin(), safeArea.GetCenter()) > BotAI.distanceof(player.GetOrigin(), area.GetCenter()))) {
									safeArea = area;
								}
							}

							if (safeArea != null) {
								if (doSomethingDangerous) {
									player.SetOrigin(safeArea.GetCenter());
								} else {
									BotAI.botRunPos(player, safeArea.GetCenter(), "avoidDanger#%", 5, feelSafe);
								}
							}
						}
					}
				}

				if (name == "player") {
					if (danger.GetZombieType() == 6) {
						if (BotAI.nextTickDistance(player, danger) > 300) {
							vecList[vecList.len()] <- BotAI.getDodgeVec(player, danger, 420, 50, 420);
						} else {
							vecList[vecList.len()] <- BotAI.getDodgeVec(player, danger, 420, 120, 420, 800);
						}
					} else if (danger.GetZombieType() == 8) {
						local nexDis = BotAI.nextTickDistance(player, danger);
						//local cansee = BotAI.VectorDotProduct(BotAI.normalize(danger.EyeAngles().Forward()), BotAI.normalize(player.GetOrigin() - danger.GetOrigin())) > 0.6
						local innerCircle = 300;
						if (BotAI.BotDebugMode) {
							DebugDrawCircle(player.GetCenter(), Vector(255, 25, 25), 0, innerCircle, true, 0.5);
						}

						local function isTankBetweenHeights(random) {
							if (BotAI.BotCombatSkill > 2) {
								return false;
							}

							local playerHeight = player.GetOrigin().z;
							local tankHeight = danger.GetOrigin().z;
							local randomHeight = random.z;

							local heightTolerance = 45;
							if (playerHeight < randomHeight) {
								return (tankHeight > (playerHeight + heightTolerance)) && (tankHeight < (randomHeight - heightTolerance));
							} else {
								return (tankHeight < (playerHeight - heightTolerance)) && (tankHeight > (randomHeight + heightTolerance));
							}
						}

						local function canHitTank(point) {
							if (BotAI.BotCombatSkill > 2) {
								return false;
							}

							if (!NavMesh.NavAreaBuildPath(player.GetLastKnownArea(), null, point, 500, 2, false)) {
								return true;
							}

							local playerPos = player.GetCenter();
							local tankPos = danger.GetCenter();
							local tankRadius = 50;
							local direction = BotAI.normalize(point - player.GetOrigin());

							if (BotAI.GetDistanceToWall(player, direction) < 30) {
								return true;
							}

							local playerToTank = tankPos - playerPos;
							local projection = playerToTank.Dot(direction);

							if (projection < 0) {
								return false;
							}

							local distanceSq = playerToTank.LengthSqr() - projection * projection;
							return distanceSq <= (tankRadius * tankRadius);
						}

						local isTarget = BotAI.IsTarget(player, danger);
						local navigator = BotAI.getNavigator(player);

						local closest = null;
						local closestDistance = 2000;
						foreach(humanPlayer in BotAI.SurvivorHumanList) {
							if (humanPlayer.IsIncapacitated() || humanPlayer.IsHangingFromLedge()) continue;
							local humanDis = BotAI.distanceof(player.GetOrigin(), humanPlayer.GetOrigin());
							if (closest == null || closestDistance > humanDis) {
								closest = humanPlayer;
								closestDistance = humanDis;
							}
						}

						if (BotAI.IsEntityValid(closest) && closestDistance <= 250 && isTarget) {
							local function changeOrDieOrRun() {
								if (!BotAI.IsEntityValid(danger) || !BotAI.IsAlive(danger)) return true;
								if (BotAI.distanceof(danger.GetOrigin(), player.GetOrigin()) < 100) return true;
								if (!navigator.isMoving("followPlayer"))
									return true;
								if (!BotAI.IsEntityValid(closest) || !BotAI.IsAlive(closest)) return true;
								if (BotAI.distanceof(closest.GetOrigin(), player.GetOrigin()) < 100) return true;

								return false;
							}

							BotAI.botRunPos(player, closest, "followPlayer", 4, changeOrDieOrRun);
						} else if (nexDis < innerCircle && isTarget) {
							navigator.clearPath("followPlayer");
							//player.UseAdrenaline(1.0);
							local tpRadius = 200;
							local hasObstacle = false;
							local tankToMe = BotAI.normalize(player.GetOrigin() - danger.GetOrigin());

							for(local i = -1; i < 1; ++i) {
								local angleVec = BotAI.rotateVector(tankToMe, i * 30);
								local dist = BotAI.GetDistanceToWall(player, angleVec);

								if(dist <= 50) {
									hasObstacle = true;
									tpRadius = 400;
									if (BotAI.BotDebugMode) {
										DebugDrawLine(player.EyePosition(), player.EyePosition() + BotAI.normalize(angleVec).Scale(dist), 25, 255, 25, true, 1.0);
										DebugDrawLine(player.EyePosition() + BotAI.normalize(angleVec).Scale(dist), player.EyePosition() + BotAI.normalize(angleVec).Scale(200), 255, 25, 25, true, 1.0);
									}
								}
							}

							local targetDirection = null;

							for (local count = 0; count < 5; ++count) {
								local randomSpot = player.TryGetPathableLocationWithin(tpRadius);
								local spotDirection = randomSpot - player.GetOrigin();
								local spotColor =  Vector(255, 25, 25);
								local failReason = "";

								if (BotAI.distanceof(danger.GetOrigin(), randomSpot) > 180 && (!isTankBetweenHeights(randomSpot) || (BotAI.BotCombatSkill >= 3 && BotAI.distanceof(danger.GetOrigin(), randomSpot) > 140))) {
									if (hasObstacle) {
										if (BotAI.VectorDotProduct(BotAI.normalize(tankToMe), BotAI.normalize(spotDirection)) < 0) {
											if (targetDirection == null) {
												targetDirection = spotDirection;
												spotColor = Vector(25, 255, 25);
												failReason = "right 1";
											} else {
												failReason = "skip 1";
											}
										} else {
											failReason = "wrong dir";
										}
									} else if (!canHitTank(randomSpot) && BotAI.VectorDotProduct(BotAI.normalize(tankToMe), BotAI.normalize(spotDirection)) > 0.2) {
										if (targetDirection == null) {
											targetDirection = spotDirection;
											spotColor = Vector(25, 255, 25);
											failReason = "right 2";
										} else {
											failReason = "skip 2";
										}
									} else {
										failReason = "can hit tank";
									}
								} else {
									failReason = "not far enough";
								}

								if (BotAI.BotDebugMode) {
									DebugDrawText(randomSpot + Vector(0, 0, 10), failReason, false, 1.0);
									DebugDrawCircle(randomSpot, spotColor, 0, 10, true, 1.0);
								}
							}

							if (targetDirection == null) {
								vecList[vecList.len()] <- BotAI.getDodgeVec(player, danger, 80, 80, 80, 80);
							} else {
								if (BotAI.BotCombatSkill == 3 && nexDis < 70) {
									player.SetOrigin(targetDirection + player.GetOrigin());
								} else if (BotAI.BotCombatSkill == 4 && nexDis < 100) {
									player.SetOrigin(targetDirection + player.GetOrigin());
								} else if (BotAI.BotCombatSkill >= 5 && nexDis < 120) {
									player.SetOrigin(targetDirection + player.GetOrigin());
								} else {
									vecList[vecList.len()] <- targetDirection;
								}
							}
						} else {
							local rock = null;
							local hasRock = false;
							while (rock = Entities.FindByClassname(rock, "tank_rock")) {
								if (BotAI.xyDotProduct(BotAI.normalize(rock.GetVelocity()), BotAI.normalize(player.GetOrigin() - rock.GetOrigin())) > 0.4) {
									hasRock = true;
								}
							}

							if (!hasRock && nexDis < innerCircle) {
								navigator.clearPath("followPlayer");
								//vecList[vecList.len()] <- BotAI.normalize(player.GetOrigin() - danger.GetOrigin()).Scale(30);
								local randomSpot = player.TryGetPathableLocationWithin(300);

								if (BotAI.distanceof(danger.GetOrigin(), randomSpot) > 500
								&& !canHitTank(randomSpot)
								&& !isTankBetweenHeights(randomSpot)) {
									vecList[vecList.len()] <- randomSpot - player.GetOrigin();
								} else {
									vecList[vecList.len()] <- BotAI.normalize(player.GetOrigin() - danger.GetOrigin()).Scale(30);
								}
							}
						}
					} else {
						if (BotAI.nextTickDistance(player, danger) > 300)
							vecList[vecList.len()] <- BotAI.getDodgeVec(player, danger, 150, 50, 300);
						else
							vecList[vecList.len()] <- BotAI.getDodgeVec(player, danger, 325, 50, 325);
					}
				}

				if (name == "infected") {
					if (BotAI.IsTarget(player, danger)) {
						vecList[vecList.len()] <- BotAI.getDodgeVec(player, danger, 50, 30, 300);
					} else {
						vecList[vecList.len()] <- BotAI.getDodgeVec(player, danger, 35, 55, 300);
					}
				}

				if (name == "witch") {
					local helper = null;
					foreach(human in BotAI.SurvivorHumanList) {
						if (helper == null || BotAI.distanceof(helper.GetOrigin(), player.GetOrigin()) > BotAI.distanceof(human.GetOrigin(), player.GetOrigin()))
							helper = human;
					}

					local function untilWitchDie() {
						if (!BotAI.IsEntityValid(danger) || !BotAI.IsAlive(danger)) return true;
						if (BotAI.witchRetreat(danger)) return true;
						if (BotAI.distanceof(danger.GetOrigin(), player.GetOrigin()) > 600) return true;
						if (!BotAI.IsEntityValid(helper) || !BotAI.IsAlive(helper)) return true;
						if (BotAI.distanceof(helper.GetOrigin(), player.GetOrigin()) < 100) return true;
						return false;
					}

					if (BotAI.IsEntityValid(helper) && BotAI.distanceof(helper.GetOrigin(), player.GetOrigin()) < 1000) {
						BotAI.botRunPos(player, helper, "farAwayWitch", 4, untilWitchDie);
					} else if (BotAI.witchKilling(danger) || BotAI.witchRunning(danger)) {
						local dirction = BotAI.normalize(BotAI.fakeTwoD(player.GetOrigin() - danger.GetOrigin()));
						local isTarget = BotAI.witchRunning(danger) && BotAI.xyDotProduct(dirction, BotAI.normalize(BotAI.fakeTwoD(danger.GetForwardVector()))) >= 0.85;
						player.UseAdrenaline(1.0);

						if (isTarget) {
							vecList[vecList.len()] <- BotAI.getDodgeVec(player, danger, 50, 220, 270);
						} else {
							local function changeOrDieOrRun() {
								if (!BotAI.IsEntityValid(danger) || !BotAI.IsAlive(danger)) return true;
								if (BotAI.witchRetreat(danger)) return true;
								return false;
							}

							BotAI.botRunPos(player, danger, "killWItch", 4, changeOrDieOrRun);
						}
					}
				}
			}

			foreach(vector in vecList) {
				vec3d += vector;
				if (length < vector.Length())
					length = vector.Length();
			}

			if (vecList.len() > 1)
				vec3d = vec3d.Scale(1 / vecList.len());

			local wep = player.GetActiveWeapon();
			local ename = " ";
			if (BotAI.IsEntityValid(wep))
				ename = wep.GetClassname();
			if (ename != "weapon_pipe_bomb" && ename != "weapon_molotov" && ename != "weapon_vomitjar")
				BotAI.RemoveFlag(player, FL_FROZEN);

			if (vecList.len() > 0 && (!BotAI.validVector(vec3d) || vec3d.Length() < 10)) {
				BotAI.setBotDedgeVector(player, null);
				return;
			}

			local finalVec = vec3d;

			if (BotAI.validVector(finalVec) && !BotAI.isPlayerNearLadder(player)) {
				BotAI.botRun(player, player.GetOrigin() + finalVec);
				//BotAI.setBotDedgeVector(player, finalVec);
				if (BotAI.BotDebugMode) {
					DebugDrawLine(player.GetOrigin() + Vector(0, 0, 20), player.GetOrigin() + finalVec + Vector(0, 0, 20), 255, 255, 255, true, 0.2);
				}
			} else
				BotAI.setBotDedgeVector(player, null);
		} else
			BotAI.setBotDedgeVector(player, null);

		updating[player] <- false;
	}

	function taskReset(player = null) {
		base.taskReset(player);
	}
}