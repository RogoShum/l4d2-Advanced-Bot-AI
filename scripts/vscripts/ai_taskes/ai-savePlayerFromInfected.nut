class ::AITaskSavePlayer extends AITaskGroup
{
	constructor(orderIn, tickIn, compatibleIn, forceIn) {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
    }

	updating = false;
	playerList = {};
	dominated = {};
	falled = {};
	rescuers = {};

	function preCheck() {
		dominated = {};
		falled = {};
		rescuers = {};

		if(BotAI.playerFallDown < 1 && BotAI.playerDominated < 1) {
			return false;
		}

		foreach(victim in BotAI.SurvivorList) {
			if(victim != null && BotAI.IsEntityValid(victim) && BotAI.IsAlive(victim)) {
				if(victim.IsDominatedBySpecialInfected())
					dominated[dominated.len()] <- victim;
				else if(!BotAI.HasTank && (victim.IsIncapacitated() || victim.IsHangingFromLedge()))
					falled[falled.len()] <- victim;
			}
		}

		if(dominated.len() > 0 || falled.len() > 0) {
			return true;
		}

		return false;
	}

	function GroupUpdateChecker(player) {
		if(!BotAI.IsAlive(player) || BotAI.IsPlayerClimb(player) || player.IsDominatedBySpecialInfected() || player.IsStaggering() || player.IsIncapacitated() || player.IsHangingFromLedge()) return false;

		local navigator = BotAI.getNavigator(player);
		if(navigator.isMoving("savePlayer"))
			return false;

		if(player in rescuers) {
			return true;
		}

		local maxDis = 9999;
		if (Director.IsAnySurvivorInExitCheckpoint() || Director.IsFinaleVehicleReady()) {
			maxDis = 500;
		}

		if(selectRescuer(player, dominated, maxDis)) {
			return true;
		}

		if(selectRescuer(player, falled, maxDis)) {
			return true;
		}

		return false;
	}

	function selectRescuer(player, table, maxDistance = 9999) {
		foreach(idx, victim in table) {
			if(victim == null || !BotAI.IsAlive(victim))
				continue;
			local distance = maxDistance;

			local _hero = null;
			foreach(hero in BotAI.SurvivorBotList) {
				if(hero in rescuers || BotAI.IsPlayerClimb(hero) || hero.IsDominatedBySpecialInfected() || hero.IsStaggering() || hero.IsIncapacitated() || hero.IsHangingFromLedge()) continue;
				local dis = BotAI.distanceof(hero.GetOrigin(), victim.GetOrigin());
				if(_hero == null || dis < distance) {
					_hero = hero;
					distance = dis;
				}
			}

			if(_hero == player) {
				rescuers[player] <- victim;
				delete table[idx];
				return true;
			}
		}
		return false;
	}

	function playerUpdate(player) {
		if(!BotAI.IsAlive(player)) {
			updating = false;
			return;
		}
		local smoker = null;
		local victim = null;
		if(player in rescuers)
			victim = rescuers[player];
		if(!BotAI.IsAlive(victim)) {
			updating = false;
			return;
		}

		if(NetProps.GetPropInt(victim, "m_tongueOwner") > 0)
			smoker = NetProps.GetPropEntity(victim, "m_tongueOwner");

		if(NetProps.GetPropInt(victim, "m_carryAttacker") > 0)
			smoker = NetProps.GetPropEntity(victim, "m_carryAttacker");

		if(NetProps.GetPropInt(victim, "m_pummelAttacker") > 0)
			smoker = NetProps.GetPropEntity(victim, "m_pummelAttacker");

		if(NetProps.GetPropInt(victim, "m_pounceAttacker") > 0)
			smoker = NetProps.GetPropEntity(victim, "m_pounceAttacker");

		if(NetProps.GetPropInt(victim, "m_jockeyAttacker") > 0)
			smoker = NetProps.GetPropEntity(victim, "m_jockeyAttacker");

		local function teleport() {
			if(!BotAI.UnStick) {
				return;
			}

			if(!BotAI.IsAlive(player) || player.IsDominatedBySpecialInfected() || player.IsIncapacitated() || player.IsHangingFromLedge()) {
				return;
			}

			if(!BotAI.IsAlive(victim) || BotAI.isPlayerBeingRevived(victim)) {
				return;
			}

			if (BotAI.distanceof(player.GetOrigin(), victim.GetOrigin()) < 200) {
				return;
			}

			if (victim.IsDominatedBySpecialInfected() || victim.IsIncapacitated() || victim.IsHangingFromLedge()) {
				local lastArea = victim.GetLastKnownArea();
				if (lastArea != null && !lastArea.IsDamaging() && !lastArea.IsBlocked(2, false) && !lastArea.IsBlocked(2, true)) {
					for(local i = 0; i < 5; ++i) {
						local findPos = lastArea.FindRandomSpot();
						if (BotAI.distanceof(findPos, victim.GetOrigin()) < 200) {
							player.SetOrigin(findPos);
							return;
						}
					}
				}
			}
		}

		if(BotAI.IsEntityValid(smoker) && BotAI.CanSeeOtherEntityWithoutBarrier(player, smoker, 180)) {
			local function needSave() {
				if(!BotAI.IsAlive(smoker)) return true;

				return false;
			}

			BotAI.botRunPos(player, smoker, "savePlayer", 5, needSave);
			
			if (BotAI.SaveTeleport <= 99) {
				BotAI.delayTimer(teleport, BotAI.SaveTeleport);
			}
		} else if (BotAI.distanceof(player.GetOrigin(), victim.GetOrigin()) > 125) {
			local function needSave() {
				if(!BotAI.IsAlive(victim) || BotAI.isPlayerBeingRevived(victim)) return true;

				return !victim.IsDominatedBySpecialInfected() && !victim.IsIncapacitated() && !victim.IsHangingFromLedge();
			}

			BotAI.botRunPos(player, victim, "savePlayer", 5, needSave);

			if (BotAI.SaveTeleport <= 99) {
				BotAI.delayTimer(teleport, BotAI.SaveTeleport);
			}
		}
		updating = false;
	}

	function taskReset(player = null) {
		base.taskReset(player);
	}
}