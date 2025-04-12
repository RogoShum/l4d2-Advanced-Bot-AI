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
		local entityList = {};
		local invPlayer = BotAI.GetHeldItems(player);
		local navigator = BotAI.getNavigator(player);
		local runningPath = navigator.getRunningPathData();
		if(typeof runningPath == "PathData" && runningPath.priority > 0)
			return false;

		if(navigator.isMoving("findEntity"))
			return false;
		local function search(enumTable) {
			foreach(idx, val in enumTable) {
				local item = null;
				while (item = Entities.FindByClassnameWithin(item, idx, player.GetOrigin(), 500)) {
					if(BotAI.IsEntityValid(item) && item.GetOwnerEntity() == null && searched.find(item) == null) {
						items[player] <- item;
						searched.append(item);
						return true;
					}
				}
			}
		}

		if(!BotAI.HasItem(player, "weapon_melee") && !BotAI.HasItem(player, "weapon_pistol_magnum")) {
			local item = null;
			while (item = Entities.FindByClassnameWithin(item, "weapon_spawn", player.GetOrigin(), 500)) {
				if(BotAI.IsEntityValid(item) && item.GetOwnerEntity() == null && searched.find(item) == null && NetProps.GetPropInt(item, "m_weaponID") == 32){
					items[player] <- item;
					searched.append(item);
					return true;
				}
			}
			if(search(enumWeaponSpawn))
				return true;
		}

		if(!("slot2" in invPlayer) && search(enumBombSpawn))
			return true;

		if(!("slot3" in invPlayer) && search(enumUpgradePack))
			return true;

		if(!("slot4" in invPlayer) && search(enumPills))
			return true;

		if(!BotAI.HasItem(player, "first_aid_kit") && search(enumDefibrillator))
			return true;
		
		items[player] <- null;
		return false;
	}
	
	function playerUpdate(player)
	{
		local entity = items[player];
		if(!BotAI.IsEntityValid(entity) || entity.GetOwnerEntity() != null) return;

		local function changeAndUse() {
			if(!BotAI.IsEntityValid(entity) || entity.GetOwnerEntity() != null) return true;
			if(!BotAI.IsAlive(player)) return true;
			local navigator = BotAI.getNavigator(player);
			if(!navigator.isMoving("findEntity"))
				return true;
			local data = navigator.getRunningPathData();
			if(data.paths.len() < 1)
				DoEntFire("!self", "Use", "", 0, player, entity);
			if(BotAI.distanceof(entity.GetOrigin(), player.GetOrigin()) <= 100) {
				DoEntFire("!self", "Use", "", 0, player, entity);
				return true;
			}
			return false;
		}
		BotAI.botRunPos(player, entity, "findEntity", 0, changeAndUse);

		/*
		foreach(item in items)
		{
			if(!BotAI.IsEntityValid(item) || item.GetOwnerEntity() != null || item.GetHealth() == 12450)
				continue;
				
			local name = item.GetClassname();

			if(name in enumBombSpawn)
			{
				if(NetProps.GetPropInt(item, "m_spawnflags") >= 8)
				{
					DoEntFire("!self", "Use", "", 0, player, item);
				}
				else
				{
					if((name == "weapon_pipe_bomb_spawn" || name == "weapon_pipe_bomb"))
					{
						item.Kill();
						player.GiveItem("pipe_bomb");
					}
					else if((name == "weapon_molotov_spawn" || name == "weapon_molotov"))
					{
						item.Kill();
						player.GiveItem("molotov");
					}
					else if((name == "weapon_vomitjar_spawn" || name == "weapon_vomitjar"))
					{
						item.Kill();
						player.GiveItem("vomitjar");
					}
				}
			}
			else if(name in enumDefibrillator)
			{
				BotAI.doAmmoUpgrades(player);
				DoEntFire("!self", "Use", "", 0, player, item);
				item.SetHealth(12450);
			}
			else {
				DoEntFire("!self", "Use", "", 0, player, item);
				item.SetHealth(12450);
			}
		}
		*/

		updating[player] <- false;
	}
	
	function taskReset(player = null) 
	{
		base.taskReset(player);
		items = {};
		searched = [];
	}
}