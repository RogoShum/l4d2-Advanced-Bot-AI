class ::AITaskDoUpgrades extends AITaskGroup
{
	constructor(orderIn, tickIn, compatibleIn, forceIn)
    {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
    }
	
	updating = false;
	playerList = {};
	hasPlayer = false;
	humanPlayer = {};
	
	function preCheck()
	{
		local hasUpgradeAmmo = false;
		local amount = 0;
		local humanTab = {};
		
		hasPlayer = false;
		
		foreach(player in BotAI.SurvivorList)
		{
			if(BotAI.IsPlayerEntityValid(player) && player.IsSurvivor() && BotAI.IsAlive(player))
			{
				if(BotAI.GetPrimaryUpgrades(player) == 1 || BotAI.GetPrimaryUpgrades(player) == 2)
					++amount;
					
				if(!IsPlayerABot(player))
				{
					hasPlayer = true;
					humanTab[humanTab.len()] <- player;
				}

				if(IsPlayerABot(player) && (BotAI.HasItem(player, "upgradepack_incendiary") || BotAI.HasItem(player, "upgradepack_explosive")))
					hasUpgradeAmmo = true;
			}
		}
		
		humanPlayer = humanTab;
		
		if(hasUpgradeAmmo && amount < 2)
			return true;
		
		return false;
	}
	
	function GroupUpdateChecker(player)
	{
		if(!BotAI.IsInCombat(player) && (BotAI.HasItem(player, "upgradepack_incendiary") || BotAI.HasItem(player, "upgradepack_explosive")))
		{
			return true;
		}
		
		return false;
	}
	
	function playerUpdate(player)
	{
		if(!hasPlayer)
			BotAI.doAmmoUpgrades(player, true);
		else
		
		foreach(playerB in humanPlayer)
		{
			if(BotAI.IsPlayerEntityValid(playerB) && BotAI.IsAlive(playerB) && !BotAI.IsBotGasFinding(player))
			{
				if(BotAI.distanceof(player.GetOrigin(), playerB.GetOrigin()) > 150)
				{
					BotAI.BotMove(player, playerB);
					return;
				}
				else
				{
					BotAI.doAmmoUpgrades(player, true);
					if(BotAI.IsBotGasFinding(player))
						BotAI.BotReset(player);
					BotAI.setBotLockTheard(player, -1);
					return;
				}
			}
		}
		
		updating = false;
	}
	
	function taskReset(player = null) 
	{
		base.taskReset(player);
	}
}