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

		if (needOil) {
			if(BotAI.UseTarget == null || !BotAI.NeedGasFinding) {
				needOil = false;
			} else {
				needOil = true;
			}
		}

		BotAI.needOil = needOil;
		return true;
	}

	function GroupUpdateChecker(player) {
		return BotAI.HasItem(player, BotAI.BotsNeedToFind) && needOil;
	}

	function playerUpdate(player) {
		updating = false;

		local Posi = BotAI.UseTarget.GetOrigin();
		if(BotAI.UseTargetOri != null)
			Posi = BotAI.UseTargetOri;

		if(BotAI.distanceof(player.GetOrigin(), Posi) < 150 && !BotAI.IsInCombat(player) && !BotAI.useTargetUsing) {
			if(BotAI.UseTargetVec != null) {
				player.SetOrigin(BotAI.UseTargetOri);
				BotAI.lookAtPosition(player, BotAI.UseTargetVec + player.EyePosition(), true);
				NetProps.SetPropVector(player, "m_angRotation", BotAI.UseTargetVec);
				NetProps.SetPropEntity(player, "m_lookatPlayer", BotAI.UseTarget);
				if(player in BotAI.BotLinkGasCan) {
					local gas = BotAI.BotLinkGasCan[player];
					if(BotAI.IsEntityValid(gas) && gas.GetOwnerEntity() == null)
						DoEntFire("!self", "Use", "", 0, player, gas);
				}
				DoEntFire("!self", "Use", "", 0, player, BotAI.UseTarget);
				if(BotAI.FullPress[player] <= -5)
					BotAI.FullPress[player] = 10;
				BotAI.ForceButton(player, 32 , 1);
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
					BotAI.FullPress[player] = 10;
				BotAI.ForceButton(player, 32 , 1);
			}
			BotAI.setBotLockTheard(player, -1);
		} else {
			local function changeOrNoNeed() {
				if (!BotAI.needOil) {
					return true;
				}

				local navigator = BotAI.getNavigator(player);
				if(!navigator.isMoving("useTarget+"))
					return true;

				return false;
			}

			BotAI.botRunPos(player, Posi, "useTarget+", 2, changeOrNoNeed);
		}
	}

	function taskReset(player = null) {
		base.taskReset(player);
	}
}