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

		if(selectRescuer(player, dominated)) {
			return true;
		}

		if(selectRescuer(player, falled)) {
			return true;
		}

		return false;
	}

	function selectRescuer(player, table) {
		foreach(idx, victim in table) {
			if(victim == null || !BotAI.IsAlive(victim))
				continue;
			local distance = 9999;
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
			
		if(BotAI.IsEntityValid(smoker) && BotAI.CanSeeOtherEntityWithoutLocation(player, smoker)) {
			local function needSave() {
				if(!BotAI.IsAlive(smoker)) return true;
				
				return false;
			}
			BotAI.botRunPos(player, smoker, "savePlayer", 5, needSave);
		} else {
			local function needSave() {
				if(!BotAI.IsAlive(victim) || victim.IsGettingUp()) return true;
				
				return !victim.IsDominatedBySpecialInfected() && !victim.IsIncapacitated() && !victim.IsHangingFromLedge();
			}
			BotAI.botRunPos(player, victim, "savePlayer", 5, needSave);
		}
		updating = false;
	}
	
	function taskReset(player = null) {
		base.taskReset(player);
	}
}