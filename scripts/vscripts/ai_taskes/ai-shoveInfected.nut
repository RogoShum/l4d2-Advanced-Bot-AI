class ::AITaskShoveInfected extends AITaskSingle {
	constructor(orderIn, tickIn, compatibleIn, forceIn) {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
    }

	name = "shoveInfected";
	single = true;
	updating = {};
	playerTick = {};

	function singleUpdateChecker(player) {
		if(!player.IsDead() && !BotAI.isPlayerFall(player)) {
			local flag = false;
			if(BotAI.getBotShoveTarget(player) != null)
				flag = true;
			if(BotAI.getBotTarget(player) != null)
				flag = true;
			if(!flag)
				BotAI.UnforceButton(player, 2048);
			return flag;
		}

		return false;
	}

	function playerUpdate(player) {
		local target = BotAI.getBotShoveTarget(player);

		if(!BotAI.IsAlive(target)) {
			target = BotAI.getBotTarget(player);
		}

		if(BotAI.IsAlive(target)) {
			local shove = false;
			local maxDis = 90;

			if(target.GetClassname() == "player" && !target.IsGhost() && !target.IsSurvivor() && (target.GetZombieType() == 1 || target.GetZombieType() == 2 || target.GetZombieType() == 3 || target.GetZombieType() == 5)) {
				shove = true;
			}

			if(target.GetClassname() == "infected") {
				local infected = target;
				local gender = 0;
				local sequenceName = target.GetSequenceName(target.GetSequence()).tolower();
				local attacking = sequenceName.find("melee") != null || (sequenceName.find("run") != null && target.IsSequenceFinished());
				if(infected != null && infected.IsValid() && BotAI.IsAlive(infected) && attacking) {
					gender = NetProps.GetPropInt(infected, "m_Gender");
					shove = true;
				}

				if(gender == 15 && player != null && player.IsValid() && player.IsSurvivor() && IsPlayerABot(player))
					infected.SetForwardVector(infected.GetOrigin() - player.GetOrigin());
			}

			if(target != player && target.GetClassname() == "player" && target.IsSurvivor()) {
				if(BotAI.IsSurvivorTrapped(target)) {
					local shouldShove = NetProps.GetPropInt(target, "m_pummelAttacker");
					if(shouldShove <= 0)
						shove = true;
				}
			}

			if(target.GetClassname() == "func_button_timed") {
				shove = false;
			}

			local shoveDis = BotAI.nextTickDistance(player, target, 5.0, true);

			local shoveFlag = shoveDis <= maxDis;

			local needShove = shove && !player.IsIncapacitated() && shoveFlag && !BotAI.IsTargetStaggering(target);

			if(needShove) {
				BotAI.SetTarget(player, target);

				local chance = 2;
				chance -= BotAI.BotCombatSkill;

				if (BotAI.BotCombatSkill > 2) {
					chance = 0;
				}

				if(target.GetClassname() == "player" && !target.IsSurvivor() && (target.GetZombieType() == 1 || target.GetZombieType() == 3 || target.GetZombieType() == 5)) {
					if(RandomInt(0, chance) == 0) {
						target.Stagger(player.GetOrigin());
					}

					local function resetMoveType() {
						if(BotAI.getMoveType(target) == 2)
							return true;
						BotAI.setMoveType(target, 2);
						return false;
					}

					BotAI.conditionTimer(resetMoveType, 0.1);
				}

				if (target.GetClassname() == "infected") {
					if (BotAI.BotCombatSkill < 1) {
						chance += 1;
					}

					if (RandomInt(0, chance) == 0) {
						BotAI.shoveCommon(target);
					}
				}

				NetProps.SetPropInt(player, "m_iShovePenalty", 0);
				local wep = player.GetActiveWeapon();
				if (wep) {
					NetProps.SetPropFloat(wep, "m_flNextSecondaryAttack", Time() - 1);
				}

				BotAI.ForceButton(player, 2048 , 0.1);
				local playerIn = player;
				local function breakTongue() {
					if(BotAI.IsEntitySurvivor(target) && BotAI.CanSeeLocation(playerIn, target.GetOrigin(), 75) && target.IsDominatedBySpecialInfected()
					&& target.GetSpecialInfectedDominatingMe().GetZombieType() == 1) {
						BotAI.breakTongue(target.GetSpecialInfectedDominatingMe());
					}
				}

				BotAI.delayTimer(breakTongue, 1.2);
			} else
				BotAI.UnforceButton(player, 2048 );
		} else {
			BotAI.setBotTarget(player, null);
			BotAI.UnforceButton(player, 2048 );
			updating[player] <- false;
		}
	}

	function taskReset(player = null) {
		base.taskReset(player);

		if(player != null){
			BotAI.setBotTarget(player, null);
			BotAI.UnforceButton(player, 2048 );
		}
	}
}