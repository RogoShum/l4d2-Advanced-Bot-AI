class ::AITaskSavePlayer extends AITaskGroup
{
	constructor(orderIn, tickIn, compatibleIn, forceIn) {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
    }
	
	updating = false;
	playerList = {};
	victims = {};
	whoSaveMe = {};
	
	function preCheck() {
		local victimList = {};
		whoSaveMe = {};
		BotAI.HasTank
		foreach(victim in BotAI.SurvivorList) {
			if(victim != null && BotAI.IsEntityValid(victim) && BotAI.IsAlive(victim)) {
				if(victim.IsDominatedBySpecialInfected())
					victimList[victimList.len()] <- victim
				else if(!BotAI.HasTank && (victim.IsIncapacitated() || victim.IsHangingFromLedge()))
					victimList[victimList.len()] <- victim
			}
		}
		
		if(victimList.len() > 0) {
			victims = victimList;
			return true;
		}
		
		victims = {};
		return false;
	}
	
	function GroupUpdateChecker(player) {
		if(!BotAI.IsAlive(player) || BotAI.IsPlayerClimb(player) || player.IsDominatedBySpecialInfected() || player.IsStaggering() || player.IsIncapacitated() || player.IsHangingFromLedge()) return false;

		local iWantSaveHim = null;
		local distance = 1200;

		foreach(victim in victims) {
			if(victim == null || !BotAI.IsAlive(victim))
				continue;
			local signed = false;
			foreach(cache in whoSaveMe) {
				if(cache == victim)
					signed = true;
			}

			if(signed)
				continue;
			
			local dis = BotAI.distanceof(player.GetOrigin(), victim.GetOrigin());
			if(iWantSaveHim == null || dis < distance) {
				iWantSaveHim = victim;
				distance = dis;
			}
		}

		if(iWantSaveHim != null) {
			whoSaveMe[player.GetEntityIndex()] <- iWantSaveHim;
			return true;
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
		if(player.GetEntityIndex() in whoSaveMe)
			victim = whoSaveMe[player.GetEntityIndex()];
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
			local vec = BotAI.normalize(smoker.GetOrigin() - player.GetOrigin()).Scale(350);
			if(BotAI.IsBotGasFinding(player))
				BotAI.BotReset(player);
				
			if(!BotAI.isPlayerNearLadder(player) && !BotAI.IsOnGround(player))
				player.SetVelocity(BotAI.fakeTwoD(Vector(vec.x, vec.y, 0)));
		} else if(BotAI.CanSeeOtherEntityWithoutLocation(player, victim)) {
			local vec = BotAI.normalize(victim.GetOrigin() - player.GetOrigin()).Scale(350);
			if(BotAI.IsBotGasFinding(player))
				BotAI.BotReset(player);
			if(!BotAI.isPlayerNearLadder(player) && !BotAI.IsOnGround(player))
				player.SetVelocity(BotAI.fakeTwoD(Vector(vec.x, vec.y, 0)));
		} else if(!BotAI.IsInCombat(player) && !BotAI.IsBotGasFinding(player)) {
			BotAI.BotMove(player, victim);
			player.SetFriction(0.5);
		}
		
		updating = false;
	}
	
	function taskReset(player = null) {
		base.taskReset(player);
	}
}