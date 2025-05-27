class ::AITaskCheckToThrowBomb extends AITaskGroup {

	constructor(orderIn, tickIn, compatibleIn, forceIn) {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
    }

	updating = false;
	zombieCleaner = null;

	function preCheck() {
		if(!BotAI.NeedThrowPipeBomb) {
			return false;
		}

		if(BotAI.playerFallDown <= 0) {
			return false;
		}

		local humanFactor = false;
		local aliveCount = 0;

		foreach (human in BotAI.SurvivorHumanList) {
			if (!BotAI.IsPlayerEntityValid(human)) {
				continue;
			}

			if (human.IsIncapacitated() || human.IsHangingFromLedge()) {
				//falled human
			} else {
				aliveCount++;
			}

			humanFactor = true;
		}

		if (humanFactor) {
			return false;
		}

		foreach (bot in BotAI.SurvivorBotList) {
			if (!BotAI.IsPlayerEntityValid(bot)) {
				continue;
			}

			if (bot.IsIncapacitated() || bot.IsHangingFromLedge()) {
				
			} else {
				aliveCount++;
			}
		}

		if (Director.GetCommonInfectedCount() < 25 || aliveCount > 2) {
			return false;
		}

		local hasPipeBomb = false;
		zombieCleaner = null;

		foreach(player in BotAI.SurvivorList) {
			if(hasPipeBomb || !BotAI.IsAlive(player) || player.IsIncapacitated() || player.IsHangingFromLedge() || player.IsDominatedBySpecialInfected()) {
				continue;
			}

			if(BotAI.HasItem(player, "weapon_pipe_bomb") && BotAI.IsInCombat(player)) {
				zombieCleaner = player;
				hasPipeBomb = true;
			}
		}

		return (zombieCleaner != null);
	}

	function GroupUpdateChecker(player) {
		if(player == zombieCleaner) {
			return true;
		}

		return false;
	}

	function playerUpdate(player) {
		if(player == zombieCleaner && BotAI.HasItem(player, "weapon_pipe_bomb")) {
			local angle = player.EyeAngles();
			angle = QAngle(-30, angle.Yaw(), angle.Roll());
			player.SnapEyeAngles(angle);
			BotAI.AddFlag(player, FL_FROZEN );

			local function RemoveFlag(ent_) {
				if(BotAI.IsEntityValid(ent_))
					BotAI.RemoveFlag(ent_, FL_FROZEN );
			}

			::BotAI.Timers.AddTimerByName("CheckToThrowGen" + player.GetEntityIndex(), 1.0, false, RemoveFlag, player);

			local weapon = player.GetActiveWeapon();
			if(weapon && weapon.GetClassname() == "weapon_pipe_bomb" && NetProps.GetPropFloat(weapon, "m_flNextPrimaryAttack") <= Time()) {
				BotAI.ForceButton(player, 1 , 0.5, true);
				BotAI.setBotLockTheard(player, -1);
			} else {
				BotAI.ChangeItem(player, 2);
			}
		} else {
			BotAI.setBotLockTheard(player, -1);
		}

		updating = false;
	}

	function taskReset(player = null) {
		base.taskReset(player);
	}
}