class ::AITaskHeal extends AITaskSingle
{
	constructor(orderIn, tickIn, compatibleIn, forceIn)
    {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
    }

	single = true;
	updating = {};
	playerTick = {};

	function singleUpdateChecker(player)
	{
		if(BotAI.playerDominated > 0) return false;
		local needHealing = BotAI.getPlayerTotalHealth(player) <= 35 || player.IsOnThirdStrike();
		local hasTreatmentItems = BotAI.HasItem(player, "weapon_first_aid_kit");
		local safeCheck = !BotAI.IsInCombat(player) && !BotAI.validVector(BotAI.getBotDedgeVector(player)) && !BotAI.IsPlayerClimb(player);

		if(needHealing && safeCheck && hasTreatmentItems)
			return true;

		return false;
	}

	function playerUpdate(player)
	{
		BotAI.AddFlag(player, FL_FROZEN );
		local duration = Convars.GetFloat("first_aid_kit_use_duration") + 0.1;
		local function RemoveFlag(ent_) {
			if(BotAI.IsEntityValid(ent_))
				BotAI.RemoveFlag(ent_, FL_FROZEN );
		}

		::BotAI.Timers.AddTimerByName("[BotAI]Heal" + player.GetEntityIndex(), duration, false, RemoveFlag, player);

		local weapon = player.GetActiveWeapon();
		if(weapon && weapon.GetClassname() == "weapon_first_aid_kit" && NetProps.GetPropFloat(weapon, "m_flNextPrimaryAttack") <= Time())
			BotAI.ForceButton(player, 1 , duration, true);
		else {
			BotAI.ChangeItem(player, 3);
			BotAI.ForceButton(player, 1 , duration, true);
		}

		updating[player] <- false;
	}

	function taskReset(player = null) {
		base.taskReset(player);

		if(BotAI.HasFlag(player, FL_FROZEN) && BotAI.IsBotHealing(player)) {
			BotAI.RemoveFlag(player, FL_FROZEN );
			BotAI.UnforceButton(player, 1 );
			BotAI.ChangeItem(player, 1);
			BotAI.BotReset(player);
		}
	}
}