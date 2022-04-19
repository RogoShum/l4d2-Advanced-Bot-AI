class ::AITaskSearchEntity extends AITaskSingle
{
	constructor(orderIn, tickIn, compatibleIn, forceIn)
    {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
		
		fakeEnumUpgradePack["weapon_upgradepack_incendiary_spawn"] <- 1;
		fakeEnumUpgradePack["weapon_upgradepack_explosive_spawn"] <- 1;
		fakeEnumUpgradePack["weapon_upgradepack_incendiary"] <- 1;
		fakeEnumUpgradePack["weapon_upgradepack_explosive"] <- 1;

		fakeEnumWeaponSpawn["weapon_pistol_magnum_spawn"] <- 1;
		fakeEnumWeaponSpawn["weapon_pistol_magnum"] <- 1;
		
		fakeEnumPills["weapon_pain_pills_spawn"] <- 1;
		fakeEnumPills["weapon_adrenaline_spawn"] <- 1;
		fakeEnumPills["weapon_pain_pills"] <- 1;
		fakeEnumPills["weapon_adrenaline"] <- 1;
		
		fakeEnumBombSpawn["weapon_pipe_bomb_spawn"] <- 1;
		fakeEnumBombSpawn["weapon_molotov_spawn"] <- 1;
		fakeEnumBombSpawn["weapon_vomitjar_spawn"] <- 1;
		fakeEnumBombSpawn["weapon_pipe_bomb"] <- 1;
		fakeEnumBombSpawn["weapon_molotov"] <- 1;
		fakeEnumBombSpawn["weapon_vomitjar"] <- 1;
		
		fakeEnumWeaponSpawn["weapon_defibrillator_spawn"] <- 1;
		fakeEnumWeaponSpawn["weapon_defibrillator"] <- 1;
    }

	single = true;
	updating = {};
	playerTick = {};
	fakeEnumUpgradePack = {};
	fakeEnumWeaponSpawn = {};
	fakeEnumPills = {};
	fakeEnumBombSpawn = {};
	fakeEnumDefibrillator = {};

	items = {};
	
	function singleUpdateChecker(player)
	{
		local entityList = {};
		local invPlayer = BotAI.GetHeldItems(player);
		local item = null;
		while (Entities.FindInSphere(item, player.GetOrigin(), 150) != null) 
		{
			item = Entities.FindInSphere(item, player.GetOrigin(), 150);
			local ename = item.GetClassname();
			
			if(BotAI.IsEntityValid(item) && item.GetOwnerEntity() == null)
			{
				if(!("slot3" in invPlayer)) {
					if (ename in fakeEnumUpgradePack) {
						entityList[ename] <- item;
						continue;
					}
					
					if (ename in fakeEnumWeaponSpawn || (ename == "weapon_spawn" && NetProps.GetPropInt(item, "m_weaponID") == 32)) {
						entityList[ename] <- item;
						continue;
					}
				}

				if (ename in fakeEnumPills && !("slot4" in invPlayer)) {
					entityList[ename] <- item;
					continue;
				}

				if (!("slot2" in invPlayer) && ename in fakeEnumBombSpawn) {
					entityList[ename] <- item;
					continue;
				}
					
				if (!BotAI.HasItem(player, "first_aid_kit") && ename in fakeEnumDefibrillator) {
					entityList[ename] <- item;
					continue;
				}
			}
		}

		if(entityList.len() > 0)
		{
			items = entityList;
			return true;
		}
		
		items = {};
		return false;
	}
	
	function playerUpdate(player)
	{
		foreach(item in items)
		{
			if(!BotAI.IsEntityValid(item) || item.GetOwnerEntity() != null || item.GetHealth() == 12450)
				continue;
				
			local name = item.GetClassname();

			if(name in fakeEnumBombSpawn)
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
			else if(name in fakeEnumDefibrillator)
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

		updating[player] <- false;
	}
	
	function taskReset(player = null) 
	{
		base.taskReset(player);
		items = {};
	}
}