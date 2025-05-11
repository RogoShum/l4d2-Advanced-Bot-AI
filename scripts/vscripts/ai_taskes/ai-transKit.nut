class ::AITaskTransKit extends AITaskSingle {
	constructor(orderIn, tickIn, compatibleIn, forceIn) {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
    }

	single = true;
	updating = {};
	playerTick = {};

	function singleUpdateChecker(player) {
		if(player.IsDead() || BotAI.IsLastStrike(player))
			return false;

		local survivor = null;
		while(survivor = Entities.FindByClassnameWithin(survivor, "player", player.GetOrigin(), 150)) {
			if(survivor != player && BotAI.IsPlayerEntityValid(survivor) && survivor.IsSurvivor() && BotAI.IsLastStrike(survivor) && BotAI.PassingItems) {
				local invPlayer = BotAI.GetHeldItems(player);
				local inv = BotAI.GetHeldItems(survivor);
				local weapon = player.GetActiveWeapon();

				if("slot3" in invPlayer && !("slot3" in inv)) {
					local it = invPlayer["slot3"];
					local name = it.GetClassname();
					if(name == "weapon_first_aid_kit" && weapon != null && weapon.GetClassname() != "weapon_first_aid_kit") {
						it.Kill();
						survivor.GiveItem("first_aid_kit");
						return true;
					}
				}
			}
		}

		return false;
	}

	function playerUpdate(player) {
		updating[player] <- false;
	}

	function taskReset(player = null) {
		base.taskReset(player);
	}
}