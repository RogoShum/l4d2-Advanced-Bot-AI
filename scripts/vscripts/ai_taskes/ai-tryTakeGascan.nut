class ::AITaskTryTakeGascan extends AITaskGroup
{
	constructor(orderIn, tickIn, compatibleIn, forceIn)
    {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
    }
	
	updating = false;
	playerList = {};
	
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

		return true;
	}

	function GroupUpdateChecker(player)
	{
		if(BotAI.IsInCombat(player) || BotAI.IsPressingAttack(player) || BotAI.IsPressingUse(player) || BotAI.IsPressingShove(player))
			return false;

		local GasTryFind = null;
		while (GasTryFind = Entities.FindByClassnameWithin(GasTryFind, BotAI.BotsNeedToFind, player.GetOrigin(), 100))
		{
			if(GasTryFind.GetOwnerEntity() == null)
				BotAI.BotTakeGasCan(player, GasTryFind);
		}
		
		if(!BotAI.HasItem(player, BotAI.BotsNeedToFind))
			return false;

		return true;
	}
	
	function playerUpdate(player)
	{
		updating = false;
		if(BotAI.IsInCombat(player) && BotAI.IsBotGasFinding(player))
		{
			BotAI.BotReset(player);
			return;
		}

		if(BotAI.IsInCombat(player) || BotAI.IsPressingAttack(player) || BotAI.IsPressingShove(player))
			return;
		
		local Posi = BotAI.UseTarget.GetOrigin();
		if(BotAI.UseTargetOri != null)
			Posi = BotAI.UseTargetOri;
						
		if(BotAI.distanceof(player.GetOrigin(), Posi) < 150) {
			if(BotAI.UseTargetVec != null) {
				player.SetOrigin(BotAI.UseTargetOri);
				BotAI.lookAtPosition(player, BotAI.UseTargetVec, true);
				NetProps.SetPropVector(player, "m_angRotation", Vector(BotAI.UseTargetVec.x - player.EyePosition().x, BotAI.UseTargetVec.y - player.EyePosition().y, BotAI.UseTargetVec.z - player.EyePosition().z));
				NetProps.SetPropEntity(player, "m_lookatPlayer", BotAI.UseTarget);
				//BotAI.hookViewEntity(player, BotAI.UseTarget);
				DoEntFire("!self", "Use", "", 0, player, BotAI.UseTarget);
				if(BotAI.FullPress[player] <= -5)
					BotAI.FullPress[player] = 50;
				BotAI.ForceButton(player, 32 , 5);
			}
			else {
				player.SetOrigin(BotAI.UseTargetOri);
				NetProps.SetPropEntity(player, "m_lookatPlayer", BotAI.UseTarget);
				BotAI.lookAtPosition(player, BotAI.UseTarget.GetOrigin(), true);
				//BotAI.hookViewEntity(player, BotAI.UseTarget);
				DoEntFire("!self", "Use", "", 0, player, BotAI.UseTarget);
				if(BotAI.FullPress[player] <= -5)
					BotAI.FullPress[player] = 50;
				BotAI.ForceButton(player, 32 , 5);
			}
			BotAI.setBotLockTheard(player, -1);
		}
		else if(!BotAI.IsBotGasFinding(player)) {
			CommandABot( { cmd = 1, bot = player, pos = Posi} );
			BotAI.SetBotGasFinding(player, 2);
		}
	}
	
	function taskReset(player = null) 
	{
		base.taskReset(player);
	}
}