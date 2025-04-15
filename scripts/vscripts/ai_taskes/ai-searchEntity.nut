class ::AITaskSearchEntity extends AITaskSingle
{
	constructor(orderIn, tickIn, compatibleIn, forceIn)
    {
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
    }

	single = true;
	updating = {};
	playerTick = {};
	enumUpgradePack = {};
	enumWeaponSpawn = {};
	enumPills = {};
	enumBombSpawn = {};
	enumDefibrillator = {};

	items = {};
	searched = [];

	function singleUpdateChecker(player) {
		if(player.IsDominatedBySpecialInfected() || player.IsStaggering() || player.IsIncapacitated() || player.IsHangingFromLedge()) return;
		local invPlayer = BotAI.GetHeldItems(player);

		if("get" in BotAI.searchedEntity)
		foreach(entity in BotAI.searchedEntity.get(player, 1)) {
			if(!BotAI.IsEntityValid(entity) || entity.GetOwnerEntity() != null) continue;
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

			if(!BotAI.HasItem(player, "first_aid_kit") && name in enumDefibrillator) {
				items[player] <- entity;
				searched.append(entity);
				return true;
			}

			if(!BotAI.HasItem(player, "weapon_melee") && !BotAI.HasItem(player, "weapon_pistol_magnum") && name in enumWeaponSpawn) {
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

		if(entity.GetClassname() in enumBombSpawn && entity.GetClassname().find("spawn") != null) {
			if(NetProps.GetPropInt(entity, "m_spawnflags") >= 8) {
				DoEntFire("!self", "Use", "", 0, player, entity);
			} else if(BotAI.distanceof(player.EyePosition(), entity.GetOrigin()) < 100) {
				BotAI.SetTarget(player, entity);
				BotAI.lookAtEntity(player, entity, true, 3);
				BotAI.ForceButton(player, 32 , 0.5);
				local function setOwner() {
					local invPlayer = BotAI.GetHeldItems(player);
					if("slot2" in invPlayer) {
						NetProps.SetPropEntity(entity, "m_hOwnerEntity", player);
					}
				}
				BotAI.delayTimer(setOwner, 0.5);

				local function forceTake() {
					local invPlayer = BotAI.GetHeldItems(player);
					if(!("slot2" in invPlayer)) {
						DoEntFire("!self", "Use", "", 0, player, entity);
						NetProps.SetPropEntity(entity, "m_hOwnerEntity", player);
					}
				}
				BotAI.delayTimer(forceTake, 4.0);
			}
		} else
			DoEntFire("!self", "Use", "", 0, player, entity);

		updating[player] <- false;
	}

	function taskReset(player = null)
	{
		base.taskReset(player);
		items = {};
		searched = [];
	}
}