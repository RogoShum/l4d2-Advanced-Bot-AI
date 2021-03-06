class ::AITaskAvoidDanger extends AITaskSingle
{
	constructor(orderIn, tickIn, compatibleIn, forceIn)
    {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
		enumGround["env_entity_igniter"] <- "env_entity_igniter"
		enumGround["entityflame"] <- "entityflame"
		enumGround["inferno"] <- "inferno"
		enumGround["insect_swarm"] <- "insect_swarm"

		enumProjectile["spitter_projectile"] <- "spitter_projectile"
		enumProjectile["tank_rock"] <- "tank_rock"
		enumProjectile["prop_car_alarm"] <- "prop_car_alarm"
		enumProjectile["prop_physics"] <- "prop_physics"
		enumProjectile["prop_physics_multiplayer"] <- "prop_physics_multiplayer"
    }
	
	name = "avoidDanger";
	single = true;
	updating = {};
	playerTick = {};
	enumGround = {};
	enumProjectile = {};
	
	function singleUpdateChecker(player)
	{
		local dangerous = {};
		
		if(BotAI.IsPlayerClimb(player) || player.IsIncapacitated() || player.IsDominatedBySpecialInfected() || player.IsStaggering()) {
			BotAI.setBotAvoid(player, dangerous);
			BotAI.setBotDedgeVector(player, null);
			return false;
		}
		
		if(!BotAI.IsOnGround(player)) {//
			BotAI.setBotAvoid(player, dangerous);
			local dodgeVec = BotAI.getBotDedgeVector(player);
			if(BotAI.validVector(dodgeVec)) {
				dodgeVec = dodgeVec.Scale(0.01);
				//if(dodgeVec.Length() < 180)
					//dodgeVec = BotAI.fakeTwoD(BotAI.normalize(dodgeVec).Scale(220));
				//if(BotAI.CanGetWithoutDanger(player, null, player.GetOrigin() + dodgeVec + Vector(0, 0, -300)))
					player.ApplyAbsVelocityImpulse(dodgeVec);
				//BotAI.setBotDedgeVector(player, null);
				return false;
			} 
		}
		local isHealing = BotAI.IsBotHealing(player);
		/*
		foreach(enumName in enumGround) {
			local ent_ = null;
			while(ent_ = Entities.FindByClassnameWithin(ent_, enumName, player.GetOrigin(), 250)) {
				dangerous[dangerous.len()] <- ent_;
			}
		}
		*/

		foreach(danger in BotAI.groundList) {
			if(BotAI.IsEntityValid(danger) && BotAI.distanceof(danger.GetOrigin(), player.GetOrigin()) < 250)
				dangerous[dangerous.len()] <- danger;
		}

		foreach(danger in BotAI.projectileList) {
			if(BotAI.IsEntityValid(danger) && BotAI.distanceof(danger.GetOrigin(), player.GetOrigin()) < 800)
				dangerous[dangerous.len()] <- danger;
		}
		
		local attackTarget = BotAI.getBotTarget(player);
		if(BotAI.isEntityInfected(attackTarget)){
			if(!isHealing && BotAI.IsAlive(attackTarget) && BotAI.distanceof(attackTarget.GetOrigin(), player.GetOrigin()) < 150 && BotAI.CanSeeOtherEntityWithoutLocation(player, attackTarget, 0, false, MASK_UNTHROUGHABLE))
				dangerous[dangerous.len()] <- attackTarget;
		}

		foreach(special in BotAI.SpecialList) {
			if(BotAI.IsAlive(special) && !special.IsGhost() && BotAI.distanceof(special.GetOrigin(), player.GetOrigin()) <= 600 
			&& (special.GetZombieType() == 3 || special.GetZombieType() == 5 || special.GetZombieType() == 6 || special.GetZombieType() == 8)
			&& !BotAI.IsEntityValid(special.GetSpecialInfectedDominatingMe())
			&& BotAI.CanSeeOtherEntityWithoutLocation(player, special, 0, false, MASK_UNTHROUGHABLE))
					dangerous[dangerous.len()] <- special;
		}

		foreach(entW in BotAI.WitchList) {
			local WitchState = NetProps.GetPropInt(entW, "m_nSequence");
			if (BotAI.IsAlive(entW) && BotAI.distanceof(player.GetOrigin(), entW.GetOrigin()) < 600 && (WitchState == ANIM_WITCH_WANDER_ACQUIRE || WitchState == ANIM_WITCH_KILLING_BLOW || WitchState == ANIM_WITCH_KILLING_BLOW_TWO))
				dangerous[dangerous.len()] <- entW;
		}
		
		BotAI.setBotAvoid(player, dangerous);
		local lastArea = player.GetLastKnownArea();
		if(lastArea && lastArea.IsDamaging()) {
			local areas = {};
			NavMesh.GetNavAreasInRadius(player.GetOrigin(), 300, areas);
			local moving = false;
			foreach(area in areas) {
				if(moving)
					continue;
				if(!area.IsDamaging() && !BotAI.IsBotGasFinding(player)) {
					BotAI.botMovePos(player, area.FindRandomSpot());
					moving = true;
				}
			}
		}
		if(dangerous.len() > 0)
			return true;
		else {
			BotAI.setBotDedgeVector(player, null);
			return false;
		}
	}
	
	function playerUpdate(player)
	{
		local dangerous = BotAI.getBotAvoid(player);
		if(dangerous.len() > 0) {
			local vec3d = Vector(0, 0, 0);
			local vecList = {};
			local tankTest = false;
			local length = 0;
			foreach(danger in dangerous) {
				if(!BotAI.IsEntityValid(danger))
					continue;

				local name = danger.GetClassname();
				
				//if(BotAI.BOT_AI_TEST_MOD == 1)
					//printl("[Bot AI] Avoid " + name);
				if(name in enumGround)
					vecList[vecList.len()] <- BotAI.fakeTwoD(BotAI.normalize(player.GetOrigin() - danger.GetOrigin()).Scale(251));

				if(name in enumProjectile){
					//250 100 400
					/*
					if(BotAI.distanceof(player.GetOrigin(), danger.GetOrigin()) <= 450 && BotAI.GetEntitySpeedVector(danger) > 100)
						tankTest = true;
					*/
					if(BotAI.xyDotProduct(BotAI.normalize(danger.GetVelocity()), BotAI.normalize(player.GetOrigin() - danger.GetOrigin())) > 0.5) {
						local di = BotAI.distanceof(player.GetOrigin(), danger.GetOrigin());
						local factor = 1 - (di / 800);
						if(di <= 450) {
							tankTest = true;
							vecList[vecList.len()] <- BotAI.getDodgeVec(player, danger, 250, 100, 250, 5000, false);
						}
						else
							vecList[vecList.len()] <- BotAI.getDodgeVec(player, danger, 500, 150, 500, 5000, false);
							
						factor = 80 * factor;
						local motion = BotAI.normalize(BotAI.fakeTwoD(danger.GetOrigin() - player.GetOrigin())).Scale(factor);
						danger.ApplyAbsVelocityImpulse(motion);
					}
				}
				
				if(name == "player") {
					if(danger.GetZombieType() == 6){
						/*if(BotAI.GetEntitySpeedVector(danger) > 230 && BotAI.distanceof(player.GetOrigin(), danger.GetOrigin()) < 400 && !BotAI.IsTargetStaggering(danger))
							tankTest = true;
						*/
						if(BotAI.nextTickDistance(player, danger) > 120)
							vecList[vecList.len()] <- BotAI.getDodgeVec(player, danger, 240, 50, 240);
						else
							vecList[vecList.len()] <- BotAI.getDodgeVec(player, danger, 220, 220, 220, 800);
					}
					else if(danger.GetZombieType() == 8) {
						if(BotAI.nextTickDistance(player, danger) > 100)
							vecList[vecList.len()] <- BotAI.getDodgeVec(player, danger, 230, 230, 230);
						else {
							tankTest = true;
							if(BotAI.HasTank && BotAI.playerFallDown > 0)
								vecList[vecList.len()] <- BotAI.getDodgeVec(player, danger, 350, 350, 350, 600, false);
							else
								vecList[vecList.len()] <- BotAI.getDodgeVec(player, danger, 350, 250, 350, 600, false);
						}
					}
					else {
						if(BotAI.nextTickDistance(player, danger) < 260)
							vecList[vecList.len()] <- BotAI.getDodgeVec(player, danger, 150, 100, 300);
						else
							vecList[vecList.len()] <- BotAI.getDodgeVec(player, danger, 125, 50, 300);
					}
					
					//BotAttack(player, danger);
					//ent_.ApplyAbsVelocityImpulse(Vector(ent_.GetOrigin().x - player.GetOrigin().x, (ent_.GetOrigin().y - player.GetOrigin().y) * 2, 0).Scale(0.01));
				}
				
				if(name == "infected"){
					if(BotAI.IsTarget(player, danger))
						vecList[vecList.len()] <- BotAI.getDodgeVec(player, danger, 75, 245, 300, 150);
					else
						vecList[vecList.len()] <- BotAI.getDodgeVec(player, danger, 35, 145, 300, 150);
				}
				
				if(name == "witch") {
						player.SetFriction(1.9);
						if(!BotAI.CanSeeOtherEntityWithoutLocation(player, danger, 0, false, MASK_UNTHROUGHABLE)){
							if(!BotAI.IsInCombat(player))
								BotAI.BotMove(player, danger);
						}
						else {
							BotAI.BotAttack(player, danger);
							if(BotAI.IsTarget(danger, player)) {
								if(BotAI.distanceof(player.GetOrigin(), danger.GetOrigin()) <= 350)
									tankTest = true;
								
								vecList[vecList.len()] <- BotAI.getDodgeVec(player, danger, 270, 220, 270);
							}
							else
								vecList[vecList.len()] <- BotAI.getDodgeVec(player, danger, -200, -200, 220);
						}
				}
				
				if(BotAI.getIsMelee(player) && (BotAI.IsTargetStaggering(danger) || (BotAI.IsEntitySI(danger) && danger.IsStaggering())) && BotAI.distanceof(player.GetOrigin(), danger.GetOrigin()) >= 200)
					tankTest = true;
			}

			foreach(vector in vecList) {
				vec3d += vector;
				if(length < vector.Length())
					length = vector.Length();
			}	

			if(vecList.len() > 1)
				vec3d = vec3d.Scale(1 / vecList.len());

			if(vec3d.Length() < 10) {
				vec3d = player.EyeAngles().Forward().Scale(-500);
			}
			
			local wep = player.GetActiveWeapon();
			local ename = " ";
			if(BotAI.IsEntityValid(wep))
				ename = wep.GetClassname();
			if(ename != "weapon_pipe_bomb" && ename != "weapon_molotov" && ename != "weapon_vomitjar")
				BotAI.RemoveFlag(player, FL_FROZEN );
			
			local velocity = player.GetVelocity();
			local vecScale = 0.75;
			if(tankTest || BotAI.getIsMelee(player))
				vecScale = 1;
			if(tankTest && BotAI.IsOnGround(player))
				BotAI.ForceButton(player, 2 , 0.2);
				
			local velocityScale = 1 - vecScale;

			local finalVec = Vector(vec3d.x * vecScale + velocity.x * velocityScale, vec3d.y * vecScale + velocity.y * velocityScale, velocity.z);
			if(finalVec.Length() < length)
				finalVec = BotAI.fakeTwoD(BotAI.normalize(finalVec).Scale(length));
			// && BotAI.CanGetWithoutDanger(player, null, player.GetOrigin() + finalVec + Vector(0, 0, -300))
			if(!BotAI.isPlayerNearLadder(player)){
				player.SetVelocity(finalVec);
				BotAI.setBotDedgeVector(player, finalVec);
				if(BotAI.BOT_AI_TEST_MOD == 1)
					DebugDrawLine(player.GetOrigin() + Vector(0, 0, 20), player.GetOrigin() + finalVec + Vector(0, 0, 20), 255, 255, 255, true, 0.2);
			}
			else
				BotAI.setBotDedgeVector(player, null);
		}
		else
			BotAI.setBotDedgeVector(player, null);
		
		updating[player] <- false;
	}
	
	function taskReset(player = null) 
	{
		base.taskReset(player);
	}
}
