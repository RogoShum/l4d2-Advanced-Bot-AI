class::AITaskAvoidDanger extends AITaskSingle {

	constructor(orderIn, tickIn, compatibleIn, forceIn) {
		base.constructor(orderIn, tickIn, compatibleIn, forceIn);
		enumGround["env_entity_igniter"] <- "env_entity_igniter"
		enumGround["entityflame"] <- "entityflame"
		enumGround["inferno"] <- "inferno"
		enumGround["insect_swarm"] <- "insect_swarm"
	}

	name = "avoidDanger";
	single = true;
	updating = {};
	playerTick = {};
	enumGround = {};

	function singleUpdateChecker(player) {
		local dangerous = {};

		if (BotAI.IsPlayerClimb(player) || player.IsIncapacitated() || player.IsDominatedBySpecialInfected() || player.IsStaggering()) {
			BotAI.setBotDedgeVector(player, null);
			return false;
		}

		local isHealing = BotAI.IsBotHealing(player);

		foreach(danger in BotAI.groundList) {
			if (BotAI.IsEntityValid(danger) && BotAI.distanceof(danger.GetOrigin(), player.GetOrigin()) < 250)
				dangerous[dangerous.len()] <- danger;
		}

		foreach(special in BotAI.SpecialList) {
			if (BotAI.IsAlive(special) && !special.IsGhost() && BotAI.distanceof(special.GetOrigin(), player.GetOrigin()) <= 600 &&
				(special.GetZombieType() == 3 || special.GetZombieType() == 5 || special.GetZombieType() == 6 || special.GetZombieType() == 8) &&
				!BotAI.IsEntityValid(BotAI.getSiVictim(special)) &&
				BotAI.GetTarget(special) == player &&
				BotAI.CanShotOtherEntityInSight(player, special, -1, MASK_UNTHROUGHABLE)) {
				dangerous[dangerous.len()] <- special;
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

				if (name in enumGround) {
					local lastArea = player.GetLastKnownArea();
					local function feelSafe() {
						return !player.GetLastKnownArea().IsDamaging();
					}

					if (lastArea && lastArea.IsDamaging()) {
						local follow = false;
						foreach(humanPlayer in BotAI.SurvivorHumanList) {
							if (!follow && BotAI.distanceof(player.GetOrigin(), humanPlayer.GetOrigin()) < 300) {
								BotAI.botRunPos(player, humanPlayer, "followPlayer", 4, feelSafe);
								follow = true;
							}
						}

						if (!follow) {
							local areas = {};
							NavMesh.GetNavAreasInRadius(player.GetOrigin(), 400, areas);
							local safeArea = null;
							foreach(area in areas) {
								if (!area.IsDamaging() && (safeArea == null || BotAI.distanceof(player.GetOrigin(), safeArea.GetCenter()) > BotAI.distanceof(player.GetOrigin(), area.GetCenter()))) {
									safeArea = area;
								}
							}

							if (safeArea != null) {
								BotAI.botRunPos(player, safeArea.GetCenter(), "avoidDanger#%", 5, feelSafe);
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
						BotAI.BotRetreatFrom(player, danger);

						local nexDis = BotAI.nextTickDistance(player, danger);
						local cansee = BotAI.VectorDotProduct(BotAI.normalize(danger.EyeAngles().Forward()), BotAI.normalize(player.GetOrigin() - danger.GetOrigin())) > 0.6
						local innerCircle = 400;
						if (BotAI.BotDebugMode) {
							DebugDrawCircle(player.GetCenter(), Vector(255, 25, 25), 0, innerCircle, true, 0.5);
						}

						local function isTankBetweenHeights(random) {
							local playerHeight = player.GetOrigin().z;
							local tankHeight = danger.GetOrigin().z;
							local randomHeight = random.z;

							local heightTolerance = 50;
							if (playerHeight < randomHeight) {
								return (tankHeight > (playerHeight - heightTolerance)) && (tankHeight < (randomHeight + heightTolerance));
							} else {
								return (tankHeight < (playerHeight + heightTolerance)) && (tankHeight > (randomHeight - heightTolerance));
							}
						}

						local function canHitTank(point) {
							local playerPos = player.GetCenter();
							local tankPos = danger.GetCenter();
							local tankRadius = 50;
							local direction = BotAI.normalize(point - player.GetOrigin());

							local playerToTank = tankPos - playerPos;
							local projection = playerToTank.Dot(direction);

							if (projection < 0) {
								return false;
							}

							local distanceSq = playerToTank.LengthSqr() - projection * projection;
							return distanceSq <= (tankRadius * tankRadius);
						}

						local isTarget = BotAI.IsTarget(player, danger);

						if (nexDis < innerCircle && isTarget) {
							local navigator = BotAI.getNavigator(player);
							navigator.clearPath("followPlayer");
							player.UseAdrenaline(1.0);

							local targetSpot = null;
							for (local count = 0; count < 5; ++count) {
								local randomSpot = player.TryGetPathableLocationWithin(270);

								if (targetSpot == null && BotAI.distanceof(danger.GetOrigin(), randomSpot) > 170
								&& !canHitTank(randomSpot)
								&& !isTankBetweenHeights(randomSpot)) {
									targetSpot = randomSpot - player.GetOrigin();
								}
							}

							if (targetSpot == null) {
								vecList[vecList.len()] <- BotAI.getDodgeVec(player, danger, 80, 80, 80, 80);
							} else {
								vecList[vecList.len()] <- targetSpot;
							}
						} else {
							local rock = null;
							local hasRock = false;
							while (rock = Entities.FindByClassname(rock, "tank_rock")) {
								if (BotAI.xyDotProduct(BotAI.normalize(rock.GetVelocity()), BotAI.normalize(player.GetOrigin() - rock.GetOrigin())) > 0.4) {
									hasRock = true;
								}
							}

							local closest = null;
							foreach(humanPlayer in BotAI.SurvivorHumanList) {
								if (humanPlayer.IsIncapacitated() || humanPlayer.IsHangingFromLedge()) continue;
								if (closest == null || BotAI.distanceof(player.GetOrigin(), closest.GetOrigin()) > BotAI.distanceof(player.GetOrigin(), humanPlayer.GetOrigin()))
									closest = humanPlayer;
							}

							if (BotAI.IsEntityValid(closest)) {
								local function changeOrDieOrRun() {
									if (!BotAI.IsEntityValid(danger) || !BotAI.IsAlive(danger)) return true;
									local navigator = BotAI.getNavigator(player);
									if (!navigator.isMoving("followPlayer"))
										return true;

									return false;
								}

								BotAI.botRunPos(player, closest, "followPlayer", 4, changeOrDieOrRun);
							} else if (!hasRock) {
								local navigator = BotAI.getNavigator(player);
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

			if (vecList.len() > 0 && (!BotAI.validVector(vec3d) || vec3d.Length() < 10)) {
				vec3d = player.EyeAngles().Forward().Scale(-500);
			}

			local wep = player.GetActiveWeapon();
			local ename = " ";
			if (BotAI.IsEntityValid(wep))
				ename = wep.GetClassname();
			if (ename != "weapon_pipe_bomb" && ename != "weapon_molotov" && ename != "weapon_vomitjar")
				BotAI.RemoveFlag(player, FL_FROZEN);

			local velocity = player.GetVelocity();
			local vecScale = 0.75;
			if (BotAI.HasTank || BotAI.getIsMelee(player))
				vecScale = 1;

			local velocityScale = 1 - vecScale;

			local finalVec = Vector(vec3d.x * vecScale + velocity.x * velocityScale, vec3d.y * vecScale + velocity.y * velocityScale, velocity.z);
			if (finalVec.Length() < length)
				finalVec = BotAI.fakeTwoD(BotAI.normalize(finalVec).Scale(length));
			if (vecList.len() > 0 && (!BotAI.validVector(finalVec) || finalVec.Length() < 10)) {
				finalVec = player.EyeAngles().Forward().Scale(-500);
			}

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