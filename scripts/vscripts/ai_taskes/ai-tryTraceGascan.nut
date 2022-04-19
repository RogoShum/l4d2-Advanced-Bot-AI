class ::AITaskTryTraceGascan extends AITaskGroup
{
	constructor(orderIn, tickIn, compatibleIn, forceIn)
    {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
    }
	
	updating = false;
	playerList = {};
	cabal_oil = {};
	
	function preCheck()
	{

		local display = null;
		while(display = Entities.FindByClassname(display, "terror_gamerules"))
		{
			if(BotAI.IsEntityValid(display) && NetProps.GetPropInt(display, "terror_gamerules_data.m_iScavengeTeamScore") >= NetProps.GetPropInt(display, "terror_gamerules_data.m_nScavengeItemsGoal"))
				return false;
		}

		if(BotAI.UseTarget == null || BotAI.HasTank || !BotAI.NeedGasFinding)
			return false;
			
		foreach(idx, gascan in cabal_oil)
		{
			if(!BotAI.IsEntityValid(gascan))
				delete cabal_oil[idx];
		}

		if(BotAI.playerFallDown > 0)
			return false;

		if(BotAI.SurvivorList.len() - BotAI.SurvivorBotList.len() >= BotAI.SurvivorBotList.len())
			return false;

		local gas = null;
		local hasGasCan = false;
		while (gas = Entities.FindByClassname(gas, BotAI.BotsNeedToFind))
		{
			hasGasCan = true;
			break;
		}

		if(!hasGasCan)
			return false;

		return true;
	}

	function GroupUpdateChecker(player)
	{
		//if(BotAI.IsInCombat(player) || BotAI.IsPressingAttack(player) || BotAI.IsPressingUse(player) || BotAI.IsPressingShove(player))
			//return false;

		if(BotAI.HasItem(player, BotAI.BotsNeedToFind)) {
			if(player.GetEntityIndex() in cabal_oil)
				delete cabal_oil[player.GetEntityIndex()];
			return false;
		}

		if(BotAI.IsBotGasFinding(player))
			return false;
		
		if(player.GetEntityIndex() in cabal_oil)
		{
			local gas_can = cabal_oil[player.GetEntityIndex()];
			if(BotAI.IsEntityValid(gas_can) && (gas_can.GetOwnerEntity() == null || gas_can.GetOwnerEntity() == player))
				return true;
			else
				cabal_oil[player.GetEntityIndex()] <- null;
		}
		
		local GasTryFind = null;
		while (GasTryFind = Entities.FindByClassnameWithin(GasTryFind, BotAI.BotsNeedToFind, player.GetOrigin(), 4000))
		{
			local flag = true;
			foreach(idx, gascan in cabal_oil)
			{
				if(BotAI.IsEntityValid(gascan) && GasTryFind.GetEntityIndex() == gascan.GetEntityIndex())
					flag = false;
			}
			
			if(flag && GasTryFind.GetOwnerEntity() == null)
			{
				cabal_oil[player.GetEntityIndex()] <- GasTryFind; 
				return true;
			}
		}

		return false;
	}
	
	function playerUpdate(player)
	{
		if(player.GetEntityIndex() in cabal_oil)
		{
			local gas_can = cabal_oil[player.GetEntityIndex()];
			if(BotAI.IsEntityValid(gas_can) && gas_can.GetOwnerEntity() != player)
			{
				if(BotAI.distanceof(player.GetOrigin(), gas_can.GetOrigin()) < 100) {
					BotAI.BotTakeGasCan(player, gas_can);
					BotAI.setBotLockTheard(player, -1);
					updating = false;
				}
				else if(!BotAI.IsBotGasFinding(player))
				{
					if(BotAI.BOT_AI_TEST_MOD == 1)
						printl("[Bot AI] Try Retake gas can " + gas_can);
					BotAI.BotMove(player, gas_can, 2);
				}
			}
			else
				updating = false;
		}
		else
			updating = false;
	}
	
	function taskReset(player = null) 
	{
		base.taskReset(player);
	}
}