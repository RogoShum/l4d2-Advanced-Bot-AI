class ::AITaskSingle extends AITask
{
	constructor(orderIn, tickIn, compatibleIn, forceIn)
    {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
    }

	single = true;
	updating = {};
	playerTick = {};

	function shouldTick(player)
	{
		if(!BotAI.IsPlayerEntityValid(player)) return false;
		if(!(player in playerTick))
			playerTick[player] <- BotAI.tickExisted;
		
		return BotAI.tickExisted >= playerTick[player];
	}
	
	function getLastTickTime(player) {
		if(!BotAI.IsPlayerEntityValid(player)) return 0;
		
		if(!(player in playerTick))
			playerTick[player] <- BotAI.tickExisted; 
		return playerTick[player];
	}
	
	function setLastTickTime(player, tickTimeIn)
	{
		if(BotAI.IsPlayerEntityValid(player))
			playerTick[player] <- tickTimeIn;
	}

	function shouldUpdate(player = null)
	{
		if(BotAI.IsPlayerEntityValid(player))
		{
			if(singleUpdateChecker(player))
			{
				updating[player] <- true;
				return true;
			}
			else
			{
				updating[player] <- false;
				return false;
			}
		}
		
		return false;
	}
	
	//abstract
	function singleUpdateChecker(player) {}

	//abstract
	function playerUpdate(player) {}
	
	function isUpdating(player = null)
	{
		return BotAI.IsPlayerEntityValid(player) && player in updating && updating[player];
	}
	
	function taskUpdate(player = null) {
		if(BotAI.IsPlayerEntityValid(player)) {
			playerUpdate(player);
		}
	}
	
	function taskReset(player = null) 
	{
		if(BotAI.IsPlayerEntityValid(player))
		{
			updating[player] <- false;
		}
	}
}
