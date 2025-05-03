class ::AITaskHealInSaferoom extends AITaskGroup
{
	constructor(orderIn, tickIn, compatibleIn, forceIn)
    {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
    }

	updating = false;
	playerList = {};

	function preCheck() {
		if(Director.HasAnySurvivorLeftSafeArea())
			return false;

		local weakCount = 0;
		local additionKit = 0;
		local origin = null;
		foreach(sur in BotAI.SurvivorList) {
			if(BotAI.getPlayerTotalHealth(sur) < 80) {
				weakCount += 1;
				if(origin == null)
					origin = sur.GetOrigin();
			}
		}

		if(origin != null) {
			local aidKit = null;
			while (aidKit = Entities.FindByClassnameWithin(aidKit, "weapon_first_aid_kit", origin, 500)) {
				if(aidKit.GetOwnerEntity() == null)
					additionKit += 1;
			}
		}

		if(additionKit >= weakCount)
			return true;
		else
			return false;
	}

	function GroupUpdateChecker(player) {
		if(BotAI.getPlayerTotalHealth(player) >= 80 || !BotAI.HasItem(player, "first_aid_kit"))
			return false;

		return true;
	}

	function playerUpdate(player) {
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
		else
			BotAI.ChangeItem(player, 3);

		updating = false;
	}

	function taskReset(player = null) {
		base.taskReset(player);
	}
}