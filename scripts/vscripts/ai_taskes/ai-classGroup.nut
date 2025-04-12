class ::AITaskGroup extends AITask
{
	constructor(orderIn, tickIn, compatibleIn, forceIn)
    {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
		playerList = {}
		updating = false;
    }
	
	playerList = {}
	
	function shouldTick(player)
	{
		return BotAI.tickExisted >= lastTickTime;
	}
	
	function setLastTickTime(player, tickTimeIn)
	{
		lastTickTime = tickTimeIn;
	}
	
	function getLastTickTime(player){ return lastTickTime;}
	
	function shouldUpdate(player = null)
	{
		local flag = false;
		
		if(preCheck()) {
			foreach(player in BotAI.SurvivorBotList) {
				if(!BotAI.IsPlayerEntityValid(player)) continue;
				if(BotAI.isBotTheardLocking(player, getOrder())) {
					printl("[BotAI] Can't check bot " + name + " update due to theard locking on " + BotAI.getBotPropertyMap(player).taskLock);
					continue;
				}
				if(GroupUpdateChecker(player))
				{
					playerList[player] <- true;
					flag = true;
					BotAI.setBotLockTheard(player, getOrder());
				}
				else
				{
					playerList[player] <- false;
					BotAI.expiredBotTheard(player, getOrder());
				}
			}
		}
		else {
			foreach(player in BotAI.SurvivorBotList) {
				BotAI.expiredBotTheard(player, getOrder());
			}
		}

		updating = flag;
		
		return flag;
	}
	
	//abstract
	function preCheck() {return false;}
	
	//abstract
	function GroupUpdateChecker(player) {}

	//abstract
	function playerUpdate(player) {}
	
	function taskUpdate(player = null) {
		foreach(player, bool in playerList) {
			if(bool && BotAI.IsPlayerEntityValid(player)) playerUpdate(player);
		}
	}
	
	function printList()
	{
		foreach(player, bool in playerList)
		{
			printl("name " + name + " bool " + bool + " player " + player);
		}
	}
}
