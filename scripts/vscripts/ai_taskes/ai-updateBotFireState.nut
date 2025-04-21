class ::AITaskUpdateBotFireState extends AITaskSingle
{
	constructor(orderIn, tickIn, compatibleIn, forceIn)
    {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
    }

	name = "updateFireState";
	single = true;
	updating = {};
	playerTick = {};

	function singleUpdateChecker(player) {
		if(!player.IsDead()) {
			local startPt = player.EyePosition();
			local endPt = startPt + player.EyeAngles().Forward().Scale(2000);
			local m_trace = { start = startPt, end = endPt, ignore = player, mask = g_MapScript.TRACE_MASK_SHOT };
			TraceLine(m_trace);

			if (m_trace.hit && BotAI.IsAlive(m_trace.enthit)) {
				BotAI.botLookAt[player] <- m_trace.enthit;
			} else
				BotAI.botLookAt[player] <- null;

			local wep = player.GetActiveWeapon();
			local ename = " ";

			if(BotAI.IsEntityValid(wep))
				ename = wep.GetClassname();

			if(ename == "weapon_pipe_bomb" || ename == "weapon_molotov" || ename == "weapon_vomitjar") {
				if(!BotAI.HasFlag(player, FL_FROZEN)) {
					BotAI.ChangeItem(player, 1);
					BotAI.DisableButton(player, 1, 0.5);
				} else {
					NetProps.SetPropFloat(wep, "m_flNextPrimaryAttack", Time() - 1);
					BotAI.ForceButton(player, 1 , 0.5);
				}
			}

			if(ename == "weapon_pain_pills" || ename == "weapon_adrenaline" || ename == "weapon_first_aid_kit") {
				NetProps.SetPropFloat(wep, "m_flNextPrimaryAttack", Time() - 1);
			}

			if(player in BotAI.targetLocked && BotAI.IsAlive(BotAI.targetLocked[player])) {
				BotAI.setBotTarget(player, BotAI.targetLocked[player]);
				return true;
			}

			local target = BotAI.getBotTarget(player);
			if(BotAI.IsEntityValid(target) && target.GetClassname() == "tank_rock")
				return true;

			target = BotAI.getSmokerTarget(player);
			if(BotAI.IsEntityValid(target) && BotAI.IsAlive(target) && target.GetEntityIndex() in BotAI.smokerTongue)
				return true;
			else
				BotAI.setSmokerTarget(player, null);

			if (!m_trace.hit || m_trace.enthit == null || m_trace.enthit == player) {
				BotAI.UnforceButton(player, 1 );
				BotAI.UnforceButton(player, 2048 );
				BotAI.setBotTarget(player, null);
				return false;
			}

			if (m_trace.enthit.GetClassname() == "worldspawn" || !m_trace.enthit.IsValid()) {
				BotAI.UnforceButton(player, 1 );
				BotAI.UnforceButton(player, 2048 );
				BotAI.setBotTarget(player, null);
				return false;
			}

			BotAI.setBotTarget(player, m_trace.enthit);
			return true;
		}

		BotAI.setBotTarget(player, null);
		return false;
	}

	function playerUpdate(player) {
		local target = BotAI.getBotTarget(player);
		if(!BotAI.IsEntityValid(target))
			target = BotAI.getSmokerTarget(player);

		if(!(player in BotAI.FullPress))
			BotAI.FullPress[player] <- 0;

		if(BotAI.FullPress[player] > -10)
			BotAI.FullPress[player]--;

		if(BotAI.IsEntityValid(target)) {
			local HasWitch = false;
			local HasPlayer = false;
			local Shot = false;
			local shotDis = 1800;
			local distance = BotAI.nextTickDistance(target, player);
			local targetName = target.GetClassname();
			local isTank = targetName == "player" && target.GetZombieType() == 8;
			local skillFactor = BotAI.BotCombatSkill * 10;
			local meleeRange = Convars.GetFloat("melee_range") + skillFactor;

			if(targetName == "player" && target.IsSurvivor() && target != player) {
				if((target.IsIncapacitated() || target.IsHangingFromLedge()) && !target.IsGettingUp() && !target.IsDominatedBySpecialInfected() && distance < 150 && !BotAI.HasTank) {
					DoEntFire("!self", "Use", "", 0, player, target);
					BotAI.ForceButton(player, 32 , 5);
				}
			}

			if(distance <= meleeRange && BotAI.HasItem(player, "melee") && !BotAI.HasFlag(player, FL_FROZEN) && !isTank) {
				BotAI.ChangeItem(player, 1);
			}

			local wep = player.GetActiveWeapon();

			local ename = " ";

			if(BotAI.IsEntityValid(wep))
				ename = wep.GetClassname();

			local notWeapon = ename == "weapon_defibrillator" || ename == "weapon_first_aid_kit";

			if(notWeapon) {
				shotDis = 0;
			}

			local isShotGun = ename == "weapon_pumpshotgun" || ename == "weapon_shotgun_chrome" || ename == "weapon_autoshotgun" || ename == "weapon_shotgun_spas";

			if(isShotGun) {
				shotDis = 600;
			}

			local isSniper = ename == "weapon_hunting_rifle" || ename == "weapon_sniper_military" || ename == "weapon_sniper_awp" || ename == "weapon_sniper_scout";

			if(isSniper) {
				shotDis = 5000;
			}

			local isMelee = ename == "weapon_melee" || ename == "weapon_chainsaw";
			local mel = isMelee && (distance > meleeRange || isTank);

			if(!player.IsIncapacitated() && !BotAI.IsSurvivorTrapped(player) && !BotAI.HasFlag(player, FL_FROZEN) && (BotAI.GetPrimaryClipAmmo(player) > 0 || isTank) && mel) {
				BotAI.ChangeItem(player, 0);
			}

			local modelName = " ";
			if(BotAI.IsEntityValid(wep)) {
				modelName = wep.GetModelName();
			}

			local isKnife = isMelee && (modelName == "models/v_models/v_knife_t.mdl" || modelName == "models/weapons/melee/v_machete.mdl" ||
				modelName == "models/weapons/melee/v_katana.mdl" || modelName == "models/weapons/melee/v_fireaxe.mdl" ||
				modelName == "models/weapons/melee/v_crowbar.mdl" || modelName == "models/v_models/v_pitchfork.mdl");

			if(isMelee || BotAI.IsSurvivorTrapped(player)) {
				shotDis = meleeRange;
			}

			if(isKnife && targetName == "player" && target.GetZombieType() == 1 && target.GetEntityIndex() in BotAI.smokerTongue) {
				local tongueLength = BotAI.tongueSpeed / 9 * BotAI.smokerTongue[target.GetEntityIndex()];
				local hitFactor = 420;
				local tongueRange = BotAI.tongueRange;

				if(distance - tongueLength <= hitFactor){
					BotAI.setSmokerTarget(player, target);
					BotAI.setBotTarget(player, null);
					shotDis = tongueRange + 100;
				}
			}

			if(isMelee && BotAI.GetPrimaryClipAmmo(player) <= 0) {
				BotAI.ReloadPrimaryClip(player);
			}

			if(player in BotAI.targetLocked && BotAI.targetLocked[player] == target)
				Shot = true;

			if(targetName == "infected" && BotAI.IsAlive(target) && distance < shotDis)
				Shot = true;

			if((targetName == "player" && !target.IsGhost() && !target.IsSurvivor() && target.GetZombieType() != 7) && BotAI.IsAlive(target) && distance < shotDis) {
				if(target.GetZombieType() != 2) {
					Shot = true;
				} else {
					local rangePlayer = null;
					local playerInside = false;
					while(rangePlayer = Entities.FindByClassnameWithin(rangePlayer, "player", target.GetOrigin(), BotAI.splatRange)) {
						if(BotAI.IsEntitySurvivor(rangePlayer))
							playerInside = true;
					}

					if(!playerInside)
						Shot = true;
				}
			}

			if(targetName == "tank_rock" || isTank) {
				if(BotAI.IsEntityValid(wep) && !isMelee && wep.Clip1() <= 0) {
					local ammoAmount = wep.GetMaxClip1() * 0.3;
					if(ammoAmount < 1)
						ammoAmount = 1;
					wep.SetClip1(ammoAmount);
				}
				Shot = true;
			}

			if(target != player && targetName == "player" && target.IsSurvivor()) {
				if(target.IsIncapacitated())
					HasPlayer = true;
				if(BotAI.IsSurvivorTrapped(target))
					Shot = true;
			}

			if(BotAI.IsPlayerReviving(player))
				HasPlayer = true;

			if(BotAI.IsAlive(target) && targetName == "witch") {
				local WitchState = NetProps.GetPropInt(target, "m_nSequence");
				if(WitchState != ANIM_WITCH_LOSE_TARGET && WitchState != ANIM_WITCH_RUN_AWAY && WitchState != ANIM_SITTING_CRY && WitchState != ANIM_SITTING_STARTLED && WitchState != ANIM_SITTING_AGGRO && WitchState != ANIM_WALK && WitchState != ANIM_WANDER_WALK)
					Shot = true;
				else
					HasWitch = true;
			}

			if(targetName == "func_button_timed") {
				if(BotAI.FullPress[player] <= -5)
					BotAI.FullPress[player] = 50;
			}

			if(BotAI.FullPress[player] > 0)
				Shot = false;

			local isPistol = ename == "weapon_pistol" || ename == "weapon_pistol_magnum" || ename == "weapon_pumpshotgun" || ename == "weapon_shotgun_chrome" || ename == "weapon_hunting_rifle" || ename == "weapon_sniper_military" || ename == "weapon_grenade_launcher" || ename == "weapon_sniper_awp" || ename == "weapon_sniper_scout";

			if(ename == BotAI.BotsNeedToFind || ("IsGhost" in target && target.IsGhost()))
				Shot = false;

			if(Shot && !HasPlayer) {
				if(BotAI.IsEntityValid(wep) && NetProps.GetPropInt(wep, "m_iClip1") <= 0 && !isMelee && player.GetContext("BOTAI_RELOAD") == null) {
					BotAI.ForceButton(player, 8192, 0.5);
					player.SetContext("BOTAI_RELOAD", "reload", 3);
				} else
					BotAI.UnforceButton(player, 8192 );
			}

			if(((BotAI.IsEntityValid(wep) && NetProps.GetPropInt(wep, "m_iClip1") > 0) || isMelee) && (!HasPlayer || player.IsIncapacitated()) && (Shot && !HasWitch)) {
				if(isPistol || isMelee) {
					if(BotAI.HasForcedButton(player, 1 ))
						BotAI.UnforceButton(player, 1 );
					else
						BotAI.ForceButton(player, 1 , 0.1);
				}
				else
					BotAI.ForceButton(player, 1 );
			} else
				BotAI.UnforceButton(player, 1 );

			updating[player] <- false;
		}
		else {
			BotAI.setBotTarget(player, null);
			updating[player] <- false;
		}
	}

	function taskReset(player = null) {
		base.taskReset(player);

		if(player != null)
			BotAI.setBotTarget(player, null);
	}
}