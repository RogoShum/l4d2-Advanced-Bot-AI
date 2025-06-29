class ::AITaskSearchEntity extends AITaskSingle {

	constructor(orderIn, tickIn, compatibleIn, forceIn) {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);

		enumUpgradePack["weapon_upgradepack_incendiary_spawn"] <- 1;
		enumUpgradePack["weapon_upgradepack_explosive_spawn"] <- 1;
		enumUpgradePack["weapon_upgradepack_incendiary"] <- 1;
		enumUpgradePack["weapon_upgradepack_explosive"] <- 1;

		enumWeaponSpawn["weapon_pistol_magnum_spawn"] <- 1;
		enumWeaponSpawn["weapon_pistol_magnum"] <- 1;

		enumPills["weapon_pain_pills_spawn"] <- 1;
		enumPills["weapon_adrenaline_spawn"] <- 1;
		enumPills["weapon_pain_pills"] <- 1;
		enumPills["weapon_adrenaline"] <- 1;

		enumBombSpawn["weapon_pipe_bomb_spawn"] <- 1;
		enumBombSpawn["weapon_molotov_spawn"] <- 1;
		enumBombSpawn["weapon_vomitjar_spawn"] <- 1;
		enumBombSpawn["weapon_pipe_bomb"] <- 1;
		enumBombSpawn["weapon_molotov"] <- 1;
		enumBombSpawn["weapon_vomitjar"] <- 1;

		enumDefibrillator["weapon_defibrillator_spawn"] <- 1;
		enumDefibrillator["weapon_defibrillator"] <- 1;

		enumAidKit["weapon_first_aid_kit_spawn"] <- 1;
		enumAidKit["weapon_first_aid_kit"] <- 1;
    }

	single = true;
	updating = {};
	playerTick = {};
	enumUpgradePack = {};
	enumWeaponSpawn = {};
	enumPills = {};
	enumBombSpawn = {};
	enumDefibrillator = {};
	enumAidKit = {};

	items = {};
	searched = [];

	function singleUpdateChecker(player) {
		if(player.IsDominatedBySpecialInfected() || BotAI.IsInCombat(player) || player.IsStaggering() || player.IsIncapacitated() || player.IsHangingFromLedge()) return;
		local invPlayer = BotAI.GetHeldItems(player);

		if(player.GetEntityIndex() in BotAI.searchedEntity) {
			foreach(entity in BotAI.searchedEntity[player.GetEntityIndex()]) {
				if(!BotAI.IsEntityValid(entity) || entity.GetOwnerEntity() != null) continue;
				local navigator = BotAI.getNavigator(player);
				local searchBody = navigator.isMoving("searchBody$") || navigator.justDone("searchBody$");
				local name = entity.GetClassname();

				if(name in enumBombSpawn && !("slot2" in invPlayer)) {
					items[player] <- entity;
					searched.append(entity);
					return true;
				}

				if(name in enumUpgradePack && !("slot3" in invPlayer)) {
					items[player] <- entity;
					searched.append(entity);
					return true;
				}

				if(name in enumPills && !("slot4" in invPlayer)) {
					items[player] <- entity;
					searched.append(entity);
					return true;
				}

				if(!BotAI.HasItem(player, "first_aid_kit", invPlayer) && !BotAI.HasItem(player, "defibrillator", invPlayer) && name in enumDefibrillator) {
					items[player] <- entity;
					searched.append(entity);
					return true;
				}

				if(!searchBody && name in enumAidKit) {
					items[player] <- entity;
					searched.append(entity);
					return true;
				}

				if(!BotAI.HasItem(player, "weapon_melee", invPlayer) && !BotAI.HasItem(player, "weapon_pistol_magnum", invPlayer) && name in enumWeaponSpawn) {
					items[player] <- entity;
					searched.append(entity);
					return true;
				}
			}
		}

		foreach(entity in BotAI.humanSearchedEntity) {
			if(!BotAI.IsEntityValid(entity) || entity.GetOwnerEntity() != null) continue;
			local navigator = BotAI.getNavigator(player);
			local searchBody = navigator.isMoving("searchBody$") || navigator.justDone("searchBody$");
			local name = entity.GetClassname();
			if(name in enumBombSpawn && !("slot2" in invPlayer)) {
				items[player] <- entity;
				searched.append(entity);
				return true;
			}

			if(name in enumUpgradePack && !("slot3" in invPlayer)) {
				items[player] <- entity;
				searched.append(entity);
				return true;
			}

			if(name in enumPills && !("slot4" in invPlayer)) {
				items[player] <- entity;
				searched.append(entity);
				return true;
			}

			if(!BotAI.HasItem(player, "first_aid_kit", invPlayer) && !BotAI.HasItem(player, "defibrillator", invPlayer) && name in enumDefibrillator) {
				items[player] <- entity;
				searched.append(entity);
				return true;
			}

			if(!searchBody && name in enumAidKit) {
				items[player] <- entity;
				searched.append(entity);
				return true;
			}

			if(!BotAI.HasItem(player, "weapon_melee", invPlayer) && !BotAI.HasItem(player, "weapon_pistol_magnum", invPlayer) && name in enumWeaponSpawn) {
				items[player] <- entity;
				searched.append(entity);
				return true;
			}
		}

		items[player] <- null;
		return false;
	}

	function playerUpdate(player) {
		local entity = items[player];
		if(!BotAI.IsEntityValid(entity) || entity.GetOwnerEntity() != null || NetProps.GetPropEntity(entity, "m_hOwnerEntity") != null) return;
		local distance = BotAI.distanceof(player.EyePosition(), entity.GetOrigin());

		local function changeAndUse() {
			if(!BotAI.IsAlive(player)) return true;
			if(!BotAI.IsEntityValid(entity)) return true;
			local currentDistance = BotAI.distanceof(entity.GetOrigin(), player.GetOrigin());
			if(currentDistance <= 80 || currentDistance > 400) {
				return true;
			}

			return false;
		}

		if (distance > 150 && distance < 400) {
			BotAI.botRunPos(player, entity, "findResource", 0, changeAndUse)

			local function forceTake() {
				if(!BotAI.IsEntityValid(entity) || entity.GetMoveParent() != null) return;

				DoEntFire("!self", "Use", "", 0, player, entity);
				NetProps.SetPropEntity(entity, "m_hOwnerEntity", player);

				if (BotAI.BotDebugMode) {
					printl("try force take")
				}
			}

			BotAI.delayTimer(forceTake, 6.0, player.tostring() + "delayForceTake");
		} else if (distance < 150) {
			if(entity.GetClassname() in enumBombSpawn && entity.GetClassname().find("spawn") != null) {
				if(NetProps.GetPropInt(entity, "m_spawnflags") >= 8) {
					DoEntFire("!self", "Use", "", 0, player, entity);
				} else if(distance < 100) {
					if (BotAI.BotDebugMode) {
						printl("try sightseeing take")
					}

					BotAI.SetTarget(player, entity);
					BotAI.lookAtEntity(player, entity, true, 3);
					BotAI.ForceButton(player, 32 , 0.5);
					local function setOwner() {
						local invPlayer = BotAI.GetHeldItems(player);
						if("slot2" in invPlayer) {
							NetProps.SetPropEntity(entity, "m_hOwnerEntity", player);
						}
					}
					BotAI.delayTimer(setOwner, 0.5, player.tostring() + "setOwner");

					local function forceTake() {
						local invPlayer = BotAI.GetHeldItems(player);
						if(!("slot2" in invPlayer)) {
							DoEntFire("!self", "Use", "", 0, player, entity);
							NetProps.SetPropEntity(entity, "m_hOwnerEntity", player);
						}

						if (BotAI.BotDebugMode) {
							printl("try force take")
						}
					}

					BotAI.delayTimer(forceTake, 4.0, player.tostring() + "forceTake");
				}
			} else {
				DoEntFire("!self", "Use", "", 0, player, entity);
			}
		}

		updating[player] <- false;
	}

	function taskReset(player = null) {
		base.taskReset(player);
		items = {};
		searched = [];
	}
}