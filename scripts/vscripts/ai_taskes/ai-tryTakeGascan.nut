class ::AITaskTryTakeGascan extends AITaskGroup
{
	constructor(orderIn, tickIn, compatibleIn, forceIn)
    {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
    }

	updating = false;
	playerList = {};
	needOil = false;

	function preCheck() {
		local display = null;
		while(display = Entities.FindByClassname(display, "terror_gamerules")) {
			if(BotAI.IsEntityValid(display) && NetProps.GetPropInt(display, "terror_gamerules_data.m_iScavengeTeamScore") >= NetProps.GetPropInt(display, "terror_gamerules_data.m_nScavengeItemsGoal"))
				needOil = false;
			else
				needOil = true;
		}

		if(BotAI.UseTarget == null || BotAI.HasTank || !BotAI.NeedGasFinding)
			needOil = false;
		else
			needOil = true;

		BotAI.needOil = needOil;
		return true;
	}

	function GroupUpdateChecker(player) {
		return BotAI.HasItem(player, BotAI.BotsNeedToFind) && needOil;
	}

	function playerUpdate(player)
	{
		updating = false;

		local Posi = BotAI.UseTarget.GetOrigin();
		if(BotAI.UseTargetOri != null)
			Posi = BotAI.UseTargetOri;

		if(BotAI.distanceof(player.GetOrigin(), Posi) < 150 && !BotAI.useTargetUsing) {
			if(BotAI.UseTargetVec != null) {
				player.SetOrigin(BotAI.UseTargetOri);
				BotAI.lookAtPosition(player, BotAI.UseTargetVec, true);
				NetProps.SetPropVector(player, "m_angRotation", Vector(BotAI.UseTargetVec.x - player.EyePosition().x, BotAI.UseTargetVec.y - player.EyePosition().y, BotAI.UseTargetVec.z - player.EyePosition().z));
				NetProps.SetPropEntity(player, "m_lookatPlayer", BotAI.UseTarget);
				if(player in BotAI.BotLinkGasCan) {
					local gas = BotAI.BotLinkGasCan[player];
					if(BotAI.IsEntityValid(gas) && gas.GetOwnerEntity() == null)
						DoEntFire("!self", "Use", "", 0, player, gas);
				}
				DoEntFire("!self", "Use", "", 0, player, BotAI.UseTarget);
				if(BotAI.FullPress[player] <= -5)
					BotAI.FullPress[player] = 80;
				BotAI.ForceButton(player, 32 , 8);
			} else {
				player.SetOrigin(BotAI.UseTargetOri);
				NetProps.SetPropEntity(player, "m_lookatPlayer", BotAI.UseTarget);
				BotAI.lookAtPosition(player, BotAI.UseTarget.GetOrigin(), true);
				if(player in BotAI.BotLinkGasCan) {
					local gas = BotAI.BotLinkGasCan[player];
					if(BotAI.IsEntityValid(gas) && gas.GetOwnerEntity() == null)
						DoEntFire("!self", "Use", "", 0, player, gas);
				}
				DoEntFire("!self", "Use", "", 0, player, BotAI.UseTarget);
				if(BotAI.FullPress[player] <= -5)
					BotAI.FullPress[player] = 80;
				BotAI.ForceButton(player, 32 , 8);
			}
			BotAI.setBotLockTheard(player, -1);
		} else {
			BotAI.botRunPos(player, Posi, "useTarget", 2, "change");
		}
	}

	function taskReset(player = null) {
		base.taskReset(player);
	}
}