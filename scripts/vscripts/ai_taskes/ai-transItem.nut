class ::AITaskTransItem extends AITaskSingle {
	constructor(orderIn, tickIn, compatibleIn, forceIn) {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
    }

	single = true;
	updating = {};
	playerTick = {};

	function singleUpdateChecker(player) {
		local survivor = null;

		while(survivor = Entities.FindByClassnameWithin(survivor, "player", player.GetOrigin(), 150)) {
			if(BotAI.IsPlayerEntityValid(survivor) && survivor.IsSurvivor() && !IsPlayerABot(survivor) && BotAI.IsAlive(survivor) && BotAI.PassingItems && !(player in BotAI.itemPassingCooldown)) {
				local invPlayer = BotAI.GetHeldItems(player);
				local inv = BotAI.GetHeldItems(survivor);
				local weapon = player.GetActiveWeapon();

				if("slot3" in invPlayer && !("slot3" in inv)) {
					local it = invPlayer["slot3"];
					local name = it.GetClassname();

					if(name == "weapon_first_aid_kit") {
						if(BotAI.getPlayerTotalHealth(player) >= BotAI.survivorLimpHealth && !("slot3" in inv) && weapon != null && weapon.GetClassname() != "weapon_first_aid_kit") {
							it.Kill();
							local item = name.slice(7);
							survivor.GiveItem(item);
							return true;
						}
					} else {
						it.Kill();
						local item = name.slice(7);
						survivor.GiveItem(item);
						return true;
					}
				}

				if(!("slot4" in inv) && "slot4" in invPlayer && BotAI.getPlayerTotalHealth(player) >= BotAI.survivorLimpHealth) {
					local it = invPlayer["slot4"];
					local name = it.GetClassname();
					it.Kill();
					local item = name.slice(7);
					survivor.GiveItem(item);
					return true;
				}

				if("slot2" in invPlayer && !("slot2" in inv)) {
					local it = invPlayer["slot2"];
					local name = it.GetClassname();
					it.Kill();
					local item = name.slice(7);
					survivor.GiveItem(item);
					return true;
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