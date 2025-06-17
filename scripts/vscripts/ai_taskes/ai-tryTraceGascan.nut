class ::AITaskTryTraceGascan extends AITaskGroup {

	constructor(orderIn, tickIn, compatibleIn, forceIn) {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
    }

	updating = false;
	playerList = {};
	cabal_oil = {};

	function preCheck() {
		if (!BotAI.needOil) {
			return false;
		}

		if(BotAI.UseTarget == null || !BotAI.NeedGasFinding)
			return false;

		foreach(idx, gascan in cabal_oil) {
			if(!BotAI.IsEntityValid(gascan))
				delete cabal_oil[idx];
		}

		if(BotAI.playerFallDown > 0)
			return false;

		if(BotAI.SurvivorList.len() - BotAI.SurvivorBotList.len() >= BotAI.SurvivorBotList.len())
			return false;

		local gas = null;
		local hasGasCan = false;
		while (gas = Entities.FindByClassname(gas, BotAI.BotsNeedToFind)) {
			hasGasCan = true;
			break;
		}

		if(!hasGasCan)
			return false;

		return true;
	}

	function GroupUpdateChecker(player) {
		if(BotAI.HasItem(player, BotAI.BotsNeedToFind) || !BotAI.IsAlive(player)) {
			if(player.GetEntityIndex() in cabal_oil)
				delete cabal_oil[player.GetEntityIndex()];
			return false;
		}

		if(player.GetEntityIndex() in cabal_oil) {
			local gas_can = cabal_oil[player.GetEntityIndex()];
			if(BotAI.IsEntityValid(gas_can) && (gas_can.GetOwnerEntity() == null || gas_can.GetOwnerEntity() == player))
				return true;
			else
				cabal_oil[player.GetEntityIndex()] <- null;
		}

		local GasTryFind = null;
		while (GasTryFind = Entities.FindByClassnameWithin(GasTryFind, BotAI.BotsNeedToFind, player.GetOrigin(), 4000)) {
			local flag = true;
			foreach(idx, gascan in cabal_oil) {
				if(BotAI.IsEntityValid(gascan) && GasTryFind.GetEntityIndex() == gascan.GetEntityIndex())
					flag = false;
			}

			if(flag && GasTryFind.GetOwnerEntity() == null) {
				local bool = false;
				foreach(link in BotAI.BotLinkGasCan) {
					if(link == GasTryFind)
						bool = true;
				}
				if(!bool) {
					cabal_oil[player.GetEntityIndex()] <- GasTryFind;
					return true;
				}
			}
		}

		return false;
	}

	function playerUpdate(player) {
		if(player.GetEntityIndex() in cabal_oil) {
			local gas_can = cabal_oil[player.GetEntityIndex()];
			if(BotAI.IsEntityValid(gas_can) && gas_can.GetOwnerEntity() != player) {
				if(BotAI.distanceof(player.GetOrigin(), gas_can.GetOrigin()) < 100) {
					BotAI.BotTakeGasCan(player, gas_can);
					BotAI.setBotLockTheard(player, -1);
					updating = false;
				} else {
					local gas = gas_can;
					local oilTable = cabal_oil;
					local function needGasCan() {
						if (!BotAI.needOil) {
							return true;
						}

						foreach(link in BotAI.BotLinkGasCan) {
							if(link == gas) {
								if(player.GetEntityIndex() in oilTable) {
									delete oilTable[player.GetEntityIndex()];
								}

								return true;
							}
						}

						if (!BotAI.IsEntityValid(gas) || gas.GetOwnerEntity() != null) {
							if(player.GetEntityIndex() in oilTable) {
								delete oilTable[player.GetEntityIndex()];
							}

							return true;
						}

						return false;
					}

					if(BotAI.BotDebugMode) {
						printl("[Bot AI] Try Retake gas can " + gas_can);
					}

					BotAI.botRunPos(player, gas_can, "searchGascan+$", 2, needGasCan);
				}
			} else {
				updating = false;
			}
		} else {
			updating = false;
		}
	}

	function taskReset(player = null) {
		base.taskReset(player);
	}
}