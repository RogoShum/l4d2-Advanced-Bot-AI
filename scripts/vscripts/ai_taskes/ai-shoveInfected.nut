class ::AITaskShoveInfected extends AITaskSingle {
	constructor(orderIn, tickIn, compatibleIn, forceIn) {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
    }
	
	name = "shoveInfected";
	single = true;
	updating = {};
	playerTick = {};
	
	function singleUpdateChecker(player) {
		if(!player.IsDead()) {
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
		if(!BotAI.IsAlive(target))
			target = BotAI.getBotTarget(player);
		
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

			if(target.GetClassname() == "func_button_timed")
				shove = false;
			local shoveDis = BotAI.nextTickDistance(player, target, 5.0, true);

			local shoveFlag = shoveDis <= maxDis;

			local needShove = shove && !player.IsIncapacitated() && shoveFlag && !BotAI.IsTargetStaggering(target);

			if(needShove) {
				BotAI.SetTarget(player, target);

				/*if(!BotAI.Versus_Mode && target.GetClassname() == "player" && !target.IsSurvivor() && (target.GetZombieType() == 1 || target.GetZombieType() == 3 || target.GetZombieType() == 5) && !player.IsDominatedBySpecialInfected()) {
					//target.Stagger(player.GetOrigin());
					BotAI.applyPushVelocity(player, target, 251);
				}*/

				if(target.GetClassname() == "infected" && BotAI.IsPressingShove(player))
					BotAI.applyPushVelocity(player, target);
				
				NetProps.SetPropInt(player, "m_iShovePenalty", 0);
				local wep = player.GetActiveWeapon();
				if (wep)
					NetProps.SetPropFloat(wep, "m_flNextSecondaryAttack", Time() - 1);
				BotAI.ForceButton(player, 2048 , 0.1);
			}
			else
				BotAI.UnforceButton(player, 2048 );
		}
		else {
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