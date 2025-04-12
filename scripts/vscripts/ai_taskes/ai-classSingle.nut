class ::AITaskSingle extends AITask
{
	constructor(orderIn, tickIn, compatibleIn, forceIn) {
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

	//abstract
	function singleUpdateChecker(player = null) {}

	function shouldUpdate(player = null) {
		if(BotAI.IsPlayerEntityValid(player)) {
			local needUpdate = false;
			needUpdate = singleUpdateChecker(player);
			try{
				
			} catch(excaption) {
				BotAI.EasyPrint("botai_report", 0.1);
				BotAI.EasyPrint(excaption.tostring(), 0.2);
				local deadTask = singleUpdateChecker;
                local deadPlayer = player;
				BotAI.throwTask(this, player, true);
			}
			if(needUpdate) {
				updating[player] <- true;
				return true;
			}
			else {
				updating[player] <- false;
				return false;
			}
		}
		
		return false;
	}

	//abstract
	function playerUpdate(player = null) {}
	
	function isUpdating(player = null) {
		return BotAI.IsPlayerEntityValid(player) && player in updating && updating[player];
	}
	
	function taskUpdate(player = null) {
		if(BotAI.IsPlayerEntityValid(player)) {
			playerUpdate(player);
			try{
				
			} catch(excaption) {
				BotAI.EasyPrint("botai_report", 0.1);
				BotAI.EasyPrint(excaption.tostring(), 0.2);
				local deadTask = playerUpdate;
                local deadPlayer = player;
                BotAI.throwTask(this, player, false);
			}
		}
	}
	
	function taskReset(player = null) {
		if(BotAI.IsPlayerEntityValid(player)) {
			updating[player] <- false;
		}
	}
}
