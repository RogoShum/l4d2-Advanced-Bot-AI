class ::ChunkMap {
	map = {}
	dimension = 150

	constructor(dimensionIn) {
		map = {}
		dimension = dimensionIn;
	}

	function put(entity) {
		if(!BotAI.IsEntityValid(entity)) return;
		local key = createKey(entity);
		if(!(key in map)) {
			map[key] <- [];
		}
		if(map[key].find(entity) == null)
			map[key].append(entity);
	}

	function get(object, scale = 1) {
		if(scale <= 0) return [];

		local pos = null;
		if(typeof object == "Vector") {
			pos = object;
		} else if(BotAI.IsEntityValid(object)) {
			pos = object.GetOrigin();
		}

		if(typeof pos != "Vector") return [];

		local baseChunkX = int(pos.x) * dimension;
		local baseChunkY = int(pos.y) * dimension;
		local baseChunkZ = int(pos.z) * dimension;

		local chunk = [];

		for(local x = -scale; x <= scale; ++x) {
			for(local y = -scale; y <= scale; ++y) {
				for(local z = -scale; z <= scale; ++z) {
					local chunkPos = Vector(
						baseChunkX + x * dimension,
						baseChunkY + y * dimension,
						baseChunkZ + z * dimension
					);

					local key = createKey(chunkPos);
					if(key in map) {
						foreach(entity in map[key]) {
							chunk.append(entity);
						}
					}
				}
			}
		}

		return chunk;
	}

	function createKey(object) {
		local key = "";
		if(typeof object == "Vector") {
			key = "X" + int(object.x).tostring() + "Y" + int(object.y).tostring() + "Z" + int(object.z).tostring();
		} else if(BotAI.IsEntityValid(object)) {
			local pos = object.GetOrigin();
			key = "X" + int(pos.x).tostring() + "Y" + int(pos.y).tostring() + "Z" + int(pos.z).tostring();
		}
		return key;
	}

	function int(i, z = false) {
		local dim = dimension;
		return (i / dim).tointeger();
	}

	function all() {
		local list = [];
		foreach(idx, chunk in map) {
			foreach(entity in chunk) {
				if(BotAI.IsEntityValid(entity))
					list.append(entity);
			}
		}
	}
}

function BotAI::playerKey(player) {
	if(BotAI.IsEntityValid(player)) {
		local character = NetProps.GetPropInt(player, "m_survivorCharacter").tostring();
		local health = player.GetHealth().tostring();

		local inventory = BotAI.GetHeldItems(player);
		local weapon = "";
		for(local i = 0; i < 5; ++i) {
			local idx = "slot" + i.tostring();
			if(idx in inventory) {
				weapon += "&" + inventory[idx].GetClassname();
			}
		}

		return character + "&" + health + weapon;
	}
	return null;
}

function BotAI::saveBackpack() {
	foreach(bot, prop in BotAI.BotLinkGasCan) {
		if(BotAI.IsEntityValid(bot) && BotAI.IsEntityValid(prop)) {
			local key = BotAI.playerKey(bot);
			local value = {
				modelName = prop.GetModelName()
				clazz = prop.GetClassname()
			}
			SaveTable("botai_backpack_" + key, value);
			Msg("[Bot AI] Saving props " + value.clazz + " with model " + value.modelName + "\n");
			Msg("[Bot AI] key: " + key + "\n");
		}
	}
}

function BotAI::loadBackpack() {
	local map = {};
	RestoreTable("botai_backpack", map);
	if(typeof map == "table")
		BotAI.mapTransPack = map;
	//if(BotAI.)
	SaveTable("botai_backpack", map);
}

function BotAI::BotPerformanceCmd() {
	foreach(name, value in BotAI.debugCallCount) {
		printl("Method " + name + " use cache " + value + " times.");
	}
}

function BotAI::backpack(bot) {
	if(bot in BotAI.BotLinkGasCan) {
		if(!BotAI.IsEntityValid(BotAI.BotLinkGasCan[bot]) || BotAI.BotLinkGasCan[bot].GetOwnerEntity() != null)
			delete BotAI.BotLinkGasCan[bot];
		else
			return BotAI.BotLinkGasCan[bot];
	}

	return null;
}

function BotAI::BotTakeGasCan(bot, gascan) {
	if(!BotAI.IsEntityValid(bot) || !BotAI.IsEntityValid(gascan)) return false;
	if(BotAI.IsEntitySurvivor(gascan.GetOwnerEntity())) {
		local owner = gascan.GetOwnerEntity();
		if(!IsAlive(owner))
			NetProps.SetPropInt(gascan, "m_hOwnerEntity", -1);
		local hasOne = false;
		foreach(thing in BotAI.modelMap) {
			if(BotAI.HasItem(owner, thing)) {
				hasOne = true;
			}
		}
		if(!hasOne)
			NetProps.SetPropInt(gascan, "m_hOwnerEntity", -1);
	}

	foreach(thing in BotAI.BotLinkGasCan) {
		if(thing == gascan)
			return false;
	}

	if(gascan.GetOwnerEntity() == null && BotAI.backpack(bot) != gascan && (!(gascan in BotAI.waitingToPick) || BotAI.waitingToPick[gascan] < 0)) {
		DoEntFire("!self", "SetParent", "!activator", 0.0, bot, gascan);
		DoEntFire("!self", "SetParentAttachment", "medkit", 0.0, bot, gascan);
		BotAI.BotLinkGasCan[bot] <- gascan;
		if(!(gascan in BotAI.waitingToPick))
			BotAI.waitingToPick[gascan] <- -1;
		return true;
	}
	return false;
}

function BotAI::getMeleeSound(modelName) {
	local num = RandomInt(1, 2);
	local suffix = num.tostring() + ".wav";
	if(modelName.find("tonfa") != null)
		return "weapons/tonfa/melee_tonfa_0" + suffix;
	if(modelName.find("machete") != null)
		return "weapons/machete/machete_impact_flesh" + suffix;
	if(modelName.find("katana") != null)
		return "weapons/katana/melee_katana_0" + suffix;
	if(modelName.find("pan") != null)
		return "weapons/pan/melee_frying_pan_0" + suffix;
	if(modelName.find("fireaxe") != null)
		return "weapons/axe/axe_impact_flesh" + suffix;
	if(modelName.find("guitar") != null)
		return "weapons/guitar/melee_guitar_0" + suffix;
	if(modelName.find("crowbar") != null)
		return "weapons/crowbar/crowbar_impact_flesh" + suffix;
	if(modelName.find("bat") != null)
		return "weapons/bat/melee_cricket_bat_0" + suffix;
	if(modelName.find("golfclub") != null)
		return "weapons/golf_club/wpn_golf_club_melee_0" + suffix;
	if(modelName.find("knife") != null)
		return "weapons/knife/melee_knife_0" + suffix;
	if(modelName.find("chainsaw") != null)
		return "weapons/chainsaw/chainsaw_high_speed_lp_01.wav";

	return "weapons/machete/machete_impact_flesh" + suffix;
}

function BotAI::IsTriggerUsable(trigger) {
	if(BotAI.IsEntityValid(trigger)) {
		local m_usable = NetProps.GetPropInt(trigger, "m_usable");

		if(trigger.GetClassname() == "func_button") {
			local glowEntity = NetProps.GetPropEntity(trigger, "m_glowEntity");

			if (m_usable == 1 && BotAI.IsEntityValid(glowEntity))
				return true;
		}
		else if(trigger.GetClassname() == "func_button_timed") {
			if (m_usable == 1 && !BotAI.IsButtonPressed(trigger))
				return true;
		}
		else if(trigger.GetClassname() == "trigger_finale") {
			if(!BotAI.FinaleStart && !BotAI.IsButtonPressed(trigger))
				return true;
		}
	}

	return false;
}

function BotAI::debugCall(name) {
	/*
	if(name in BotAI.debugCallCount)
		debugCallCount[name] = debugCallCount[name] + 1;
	else
		debugCallCount[name] <- 1;
	*/
}

function BotAI::callCacheBoolean(tag, boolean, set = false, check = false) {
	if(set) {
		BotAI.callCache[tag] <- boolean;
		return true;
	}

	if(check)
		return tag in BotAI.callCache;

	return BotAI.callCache[tag];
}

function BotAI::playSound(entity, sound)
{
	if(sound == "") return;
	if(!IsSoundPrecached(sound)) {
		PrecacheSound(sound);
		entity.PrecacheScriptSound(sound);
	}
	if(BotAI.IsEntityValid(entity))
		EmitAmbientSoundOn(sound, 0.5, 350, 100, entity);
}

function BotAI::HasHoldButton(player, button )
{
	if (!BotAI.IsPlayerEntityValid(player))
	{
		return;
	}

	local buttons = NetProps.GetPropInt(player, "m_nButtons" );

	return buttons == ( buttons | button );
}

function BotAI::HoldButton(player, button, time = 999, force = false)
{
	if (!BotAI.IsPlayerEntityValid(player))
	{
		return;
	}

	local buttons = NetProps.GetPropInt(player, "m_nButtons" );

	if ( BotAI.HasHoldButton(player, button) )
		return;

	NetProps.SetPropInt(player, "m_nButtons", ( buttons | button ) );

	if(force)
		BotAI.holdButton[button] <- true;

	local function RemoveButtonHold(args)
	{
		local buttons = NetProps.GetPropInt(args.ent_, "m_nButtons" );
		local button = args.but;
		NetProps.SetPropInt(args.ent_, "m_nButtons", ( buttons & ~button ) );
		if(args.forc && button in BotAI.holdButton)
			BotAI.holdButton[button] <- false;
	}

	::BotAI.Timers.AddTimerByName("RemoveButtonHold" + player.GetEntityIndex() + button, time, false, RemoveButtonHold, {ent_ = player, but = button, forc = force});
}

function BotAI::HasForcedButton(player, button ) {
	if (!BotAI.IsPlayerEntityValid(player))
	{
		return;
	}

	local buttons = NetProps.GetPropInt(player, "m_afButtonForced" );

	return buttons == ( buttons | button );
}

function BotAI::setContext(entity, context, duration) {
	if(!BotAI.IsEntityValid(entity)) {
		return;
	}
	entity.SetContext(context, context, duration);

	local function deleteContext() {
		if(BotAI.IsEntityValid(entity))
			entity.SetContext(context, ">null<", -1);
	}

	if(duration > 0) {
		BotAI.delayTimer(deleteContext, duration);
	}
}

function BotAI::hasContext(entity, context) {
	if(!BotAI.IsEntityValid(entity)) {
		return false;
	}
	if(entity.GetContext(context) == null || entity.GetContext(context) == ">null<")
		return false;
	return true;
}

function BotAI::ForceButton(player, button, time = 999, force = false) {
	if (!BotAI.IsPlayerEntityValid(player) || BotAI.IsPlayerClimb(player) || BotAI.IsBotHealing(player))
		return;
	if (!BotAI.IsOnGround(player) && button == 2)
		return;

	local buttons = NetProps.GetPropInt(player, "m_afButtonForced" );
	if(button == 2) {
		BotAI.setContext(player, "BOTAI_JUMP", 1);
	}
	if ( BotAI.HasForcedButton(player, button) )
		return;

	NetProps.SetPropInt(player, "m_afButtonForced", ( buttons | button ) );

	if(force)
		BotAI.forceButton[button] <- true;

	local function RemoveButtonForece(args)
	{
		local buttons = NetProps.GetPropInt(args.ent_, "m_afButtonForced" );
		local button = args.but;
		NetProps.SetPropInt(args.ent_, "m_afButtonForced", ( buttons & ~button ) );
		if(args.forc && button in BotAI.forceButton)
			BotAI.forceButton[button] <- false;
	}

	::BotAI.Timers.AddTimerByName("RemoveButtonForece" + player.GetEntityIndex() + button, time, false, RemoveButtonForece, {ent_ = player, but = button, forc = force});
}

function BotAI::UnforceButton(player, button ) {
	if (!BotAI.IsPlayerEntityValid(player))
	{
		return;
	}

	local weapon = player.GetActiveWeapon();
	if(weapon && weapon.GetClassname() == "weapon_defibrillator" && button == 1)
		return;

	local buttons = NetProps.GetPropInt(player, "m_afButtonForced" );

	if ( !BotAI.HasForcedButton(player, button) )
		return;

	if(button in BotAI.forceButton && BotAI.forceButton[button])
		return;

	NetProps.SetPropInt(player, "m_afButtonForced", ( buttons & ~button ) );
}

function BotAI::HasDisabledButton(player, button ) {
	if (!BotAI.IsPlayerEntityValid(player))
	{
		return;
	}

	local buttons = NetProps.GetPropInt(player, "m_afButtonDisabled" );

	return buttons == ( buttons | button );
}

function BotAI::DisableButton(player, button, time = 999, force = false) {
	if (!BotAI.IsPlayerEntityValid(player)) {
		return;
	}

	local buttons = NetProps.GetPropInt(player, "m_afButtonDisabled" );

	if ( BotAI.HasDisabledButton(player, button) )
		return;

	NetProps.SetPropInt(player, "m_afButtonDisabled", ( buttons | button ) );

	if(force)
		BotAI.disableButton[button] <- true;

	local function RemoveButtonDisable(args) {
		local buttons = NetProps.GetPropInt(args.ent_, "m_afButtonDisabled" );
		local button = args.but;
		NetProps.SetPropInt(args.ent_, "m_afButtonDisabled", ( buttons & ~button ) );
		if(args.forc && button in BotAI.disableButton)
			BotAI.disableButton[button] <- false;
	}

	::BotAI.Timers.AddTimerByName("RemoveButtonDisable" + player.GetEntityIndex() + button, time, false, RemoveButtonDisable, {ent_ = player, but = button, forc = force});
}

function BotAI::EnableButton(player, button )
{
	if (!BotAI.IsPlayerEntityValid(player))
	{
		return;
	}

	local buttons = NetProps.GetPropInt(player, "m_afButtonDisabled" );

	if ( !BotAI.HasDisabledButton(player, button) )
		return;

	if(button in BotAI.disableButton && BotAI.disableButton[button])
		return;

	NetProps.SetPropInt(player, "m_afButtonDisabled", ( buttons & ~button ) );
}

function BotAI::ChangeItem(p, slot)
{
	if(BotAI.IsPlayerClimb(p)) return;

	local wep = p.GetActiveWeapon();
	local ename = " ";
	if(BotAI.IsEntityValid(wep))
		ename = wep.GetClassname();

	if(BotAI.IsBotHealing(p) || ename == "weapon_first_aid_kit" ||
	ename == "weapon_defibrillator" || ename == "weapon_pain_pills" || ename == "weapon_adrenaline") return;

	local t = BotAI.GetHeldItems(p);

	if (t && ("slot" + slot.tostring()) in t) {
		local weapon = t[("slot" + slot.tostring())];
		//NetProps.SetPropEntity(p, "m_hActiveWeapon", t[("slot" + slot.tostring())]);
		p.SwitchToItem(weapon.GetClassname());
		if(BotAI.BotDebugMode) {
			DebugDrawText(p.EyePosition(), BotAI.getPlayerBaseName(p) + " change " + weapon.GetClassname(), true, 0.2);
		}
		NetProps.SetPropFloat(weapon, "m_flNextPrimaryAttack", Time() - 1);
		NetProps.SetPropFloat(weapon, "m_flNextSecondaryAttack", Time() - 1);
	}
}

::BotAI.GetPrimaryClipAmmo <- function(p) {
	local t = BotAI.GetHeldItems(p);

	if (t && "slot0" in t)
	{
		return NetProps.GetPropInt(t["slot0"], "m_iClip1")
	}

	return 0;
}

::BotAI.ReloadPrimaryClip <- function(p) {
	local t = BotAI.GetHeldItems(p);

	if (t && "slot0" in t && t["slot0"]) {
		local wep = t["slot0"];
		local ammoAmount = wep.GetMaxClip1() * 0.3;
		if(ammoAmount < 1)
			ammoAmount = 1;
		wep.SetClip1(ammoAmount);
	}
}

function BotAI::versusWeaponCheck(wep) {
	if(wep.find("shotgun") != null || wep.find("smg") != null || wep.find("melee") != null || wep.find("weapon_pistol") != null)
		return true;
	return false;
}

function BotAI::getDamage(wep) {
	switch(wep)
	{
		case "weapon_pistol":
			return 36;
		case "weapon_pistol_magnum":
			return 80;
		case "weapon_smg":
			return 20;
		case "weapon_pumpshotgun":
			return 25;
		case "weapon_autoshotgun":
			return 23;
		case "weapon_rifle":
			return 33;
		case "weapon_hunting_rifle":
			return 90;
		case "weapon_smg_silenced":
			return 25;
		case "weapon_shotgun_chrome":
			return 31;
		case "weapon_sniper_military":
			return 90;
		case "weapon_shotgun_spas":
			return 28;
		case "weapon_rifle_desert":
			return 44;
		case "weapon_rifle_ak47":
			return 58;
		case "weapon_smg_mp5":
			return 24;
		case "weapon_rifle_sg552":
			return 33;
		case "weapon_sniper_awp":
			return 115;
		case "weapon_sniper_scout":
			return 90;
		case "weapon_rifle_m60":
			return 50;
		default :
			return 20;
	}
}

function BotAI::getNavigator(player) {
	if(!(player in BotAI.playerNavigator)) {
		BotAI.playerNavigator[player] <- Navigator(player);
		BotAI.createNavigatorTimer(player);
	}

	return BotAI.playerNavigator[player];
}

function BotAI::applyPushVelocity(player, target, force = 400) {
	local velocity = target.GetVelocity();
	local pushVec = BotAI.normalize(target.GetOrigin() - player.GetOrigin()).Scale(force);
	velocity = Vector(pushVec.x, pushVec.y, velocity.z);
	target.SetVelocity(velocity);
}

function BotAI::isDoorEntity(entity) {
	if(!BotAI.IsEntityValid(entity)) return false;
	return entity.GetClassname() == "func_door" || entity.GetClassname() == "prop_door_rotating_checkpoint" || entity.GetClassname() == "prop_door_rotating";
}

function BotAI::doorOpened(door) {
	return door in BotAI.DoorState && BotAI.DoorState[door];
}

function BotAI::botMove(player, vec) {
	vec = BotAI.fakeTwoD(vec);
	local inAir = !BotAI.IsOnGround(player);
	if(inAir) {
		return;
	}
	if(player in BotAI.botMoveMap) {
		local botVec = BotAI.botMoveMap[player];
		if(botVec.Length() >= 1)
			BotAI.botMoveMap[player] = botVec*0.25 + vec*0.75;
		else
			BotAI.botMoveMap[player] = vec;
	} else {
		BotAI.botMoveMap[player] <- vec;
	}
}

function BotAI::botRun(player, targetPos, speed = 220) {
	local onGround = BotAI.IsOnGround(player) && !BotAI.HasForcedButton(player, 2) && !BotAI.IsPressingJump(player);
	if(!onGround && speed > BOT_JUMP_SPEED_LIMIT)
		speed = BOT_JUMP_SPEED_LIMIT;
	local pushVec = BotAI.normalize(targetPos - player.GetOrigin()).Scale(speed);
	local velocity = Vector(pushVec.x, pushVec.y, player.GetVelocity().z);

	local dodgeVec = BotAI.getBotDedgeVector(player);
	if(BotAI.validVector(dodgeVec))
		velocity = velocity.Scale(0.7) + dodgeVec.Scale(0.3);

	/*
	if(onGround) {
		local angle = BotAI.checkObstacle(player, velocity);
		if(angle > 0)
			velocity = BotAI.rotateVector(velocity, angle);
	}
	*/

	if(BotAI.validVector(velocity))
		BotAI.botMove(player, velocity);

	if(BotAI.BotDebugMode) {
		DebugDrawCircle(targetPos, Vector(0, 255, 0), 1.0, 25, true, 0.2);
		DebugDrawText(targetPos, BotAI.getPlayerBaseName(player) + " navigate here", false, 0.2);
	}
}

function BotAI::EnableSight(arg)
{
	if("infect" in arg && BotAI.IsEntityValid(arg.infect) && "IsDead" in arg.infect && !arg.infect.IsDead())
		arg.infect.SetSenseFlags(arg.infect.GetSenseFlags() & ~BOT_CANT_SEE);
}

function BotAI::SetPlayerAtCheckPoint(player, boolean)
{
	BotAI.InSafeHouse[player.GetEntityIndex()] <- boolean;
}

function BotAI::IsPlayerAtCheckPoint(player)
{
	return player.GetEntityIndex() in BotAI.InSafeHouse && BotAI.InSafeHouse[player.GetEntityIndex()];
}

function BotAI::getLowOriginFromArea(area, dir) {
	local origins = BotAI.getDirectionOriginFromArea(area, dir);
	local origin0 = origins[0];
	local origin1 = origins[1];

	if(origin0.z > origin1.z)
		return origin1;
	else
		return origin0;
}

function BotAI::getHighOriginFromArea(area, dir) {
	local origins = BotAI.getDirectionOriginFromArea(area, dir);
	local origin0 = origins[0];
	local origin1 = origins[1];

	if(origin0.z < origin1.z)
		return origin1;
	else
		return origin0;
}

function BotAI::getDirectionOriginFromArea(area, dir) {
	local origin = [];
    switch(dir) {
		case 0:
			origin.append(area.GetCorner(0));
			origin.append(area.GetCorner(1));
			break;
		case 1:
			origin.append(area.GetCorner(1));
			origin.append(area.GetCorner(2));
			break;
		case 2:
			origin.append(area.GetCorner(2));
			origin.append(area.GetCorner(3));
			break;
		case 3:
			origin.append(area.GetCorner(3));
			origin.append(area.GetCorner(0));
			break;
	}
	return origin;
}

/**
 *healing others
 */
::BotAI.SetBotHealing <- function(player, boo){
	BotAI.healing[player.GetEntityIndex()] <- boo;
}

/**
 *Is healing others
 */
::BotAI.IsBotHealing <- function(player){
	if(!BotAI.IsAlive(player)) return false;
	return player.GetEntityIndex() in BotAI.healing && BotAI.healing[player.GetEntityIndex()];
}

::BotAI.setBotHealingTime <- function(player, boo){
	BotAI.healingTime[player.GetEntityIndex()] <- boo;
}

::BotAI.getBotHealingTime <- function(player){
	if(player.GetEntityIndex() in BotAI.healingTime)
		return BotAI.healingTime[player.GetEntityIndex()];

	return Time();
}

function BotAI::HasSpecialInfectedAlive()
{
	player <- null;
	while(player = Entities.FindByClassname(player, "player"))
	{
		if(!player.IsSurvivor() && BotAI.IsAlive(player))
			return true;
	}

	return false;
}

function BotAI::breakTongue(smoker) {
	if(BotAI.hasContext(smoker, "BOTAI_BREAK"))
		return;

	local victim = NetProps.GetPropEntity(smoker, "m_tongueVictim");
	if(BotAI.IsEntityValid(victim)) {
		victim.SetOrigin(victim.GetOrigin() + Vector(0, 0, 20));
		victim.Stagger(Vector(0, 0, -100));
	}
}

function BotAI::isDeathStillAlive(death) {
	local _type = NetProps.GetPropInt(death, "m_nCharacterType");
	foreach(player in BotAI.SurvivorList) {
		if(NetProps.GetPropInt(player, "m_survivorCharacter") == _type)
			return true;
	}
	return false;
}

function BotAI::getPlayerBaseName(player)
{
	//local name = NetProps.GetPropInt(player, "m_survivorCharacter");

	return g_MapScript.GetCharacterDisplayName(player);
}

function BotAI::GetPrimaryUpgrades(player) {
	if (!BotAI.IsPlayerEntityValid(player)) {
		return 0;
	}

	local t = BotAI.GetHeldItems(player);

	if (t && "slot0" in t) {
		if ( t["slot0"].GetClassname().find("weapon_") == null )
			return 0;

		return NetProps.GetPropInt(t["slot0"], "m_upgradeBitVec");
	}
	return 0;
}

function BotAI::setPrimaryUpgrades(player, upgrade) {
	if (!BotAI.IsPlayerEntityValid(player)) {
		return;
	}

	local t = BotAI.GetHeldItems(player);

	if (t && "slot0" in t) {
		if ( t["slot0"].GetClassname().find("weapon_") == null )
			return;

		return NetProps.SetPropInt(t["slot0"], "m_upgradeBitVec", upgrade);
	}
}

function BotAI::SpawnUpgrade( upgrade, count = 4, pos = Vector(0,0,0), ang = QAngle(0,0,0), keyvalues = {} )
{
	if ( typeof(upgrade) == "integer" )
	{
		if ( upgrade == 0 )
			upgrade = "upgrade_ammo_incendiary";
		else if ( upgrade == 1 )
			upgrade = "upgrade_ammo_explosive";
		else if ( upgrade == 2 )
			upgrade = "upgrade_laser_sight";
	}
	local t = { spawnflags = "2", };
	foreach (idx, val in t)
		keyvalues[idx] <- val;

	local ent = BotAI.CreateEntity(upgrade, pos, ang, keyvalues);
	if("__KeyValueFromInt" in ent)
		ent.__KeyValueFromInt("count", count);
	return ent;
}

::BotAI.doAmmoUpgrades <- function(p, func = false) {
	local amount = 4;
	if(BotAI.SurvivorList.len() > 4)
		amount = BotAI.SurvivorList.len();

	if(HasItem(p, "upgradepack_explosive")) {
		local inv = BotAI.GetHeldItems(p);
		if("slot3" in inv)
		{
			local it = inv["slot3"];
			it.Kill();
		}

		BotAI.SpawnUpgrade(1, amount, p.GetOrigin());
	}

	if(HasItem(p, "upgradepack_incendiary")) {
		local inv = BotAI.GetHeldItems(p);
		if("slot3" in inv)
		{
			local it = inv["slot3"];
			it.Kill();
		}

		BotAI.SpawnUpgrade(0, amount, p.GetOrigin());
	}
}

function BotAI::dropItem(p, str) {
	local wep = "";
	local dummyWep = "";
	local slot = "";
	local t = BotAI.GetHeldItems(p);

	if ( str != "" )
	{
		if ( (typeof str) == "integer" )
			slot = "slot" + str.tointeger();
		else
		{
			if ( str.find("weapon_") != null )
				wep = str;
			else
				wep = "weapon_" + str;
		}
	}
	else
	{
		if (p.GetActiveWeapon() != null )
			wep = p.GetActiveWeapon().GetClassname();
		else
			return false;
	}

	if ( slot != "" )
	{
		if (t && slot in t)
			wep = t[slot].GetClassname();
	}

	if ( wep == "weapon_pistol" || wep == "weapon_melee" || wep == "weapon_chainsaw" )
		dummyWep = "pistol_magnum";
	else if ( wep == "weapon_pistol_magnum" )
		dummyWep = "pistol";
	else if ( wep == "weapon_first_aid_kit" || wep == "weapon_upgradepack_incendiary" || wep == "weapon_upgradepack_explosive" )
		dummyWep = "defibrillator";
	else if ( wep == "weapon_defibrillator" )
		dummyWep = "first_aid_kit";
	else if ( wep == "weapon_pain_pills" )
		dummyWep = "adrenaline";
	else if ( wep == "weapon_adrenaline" )
		dummyWep = "pain_pills";
	else if ( wep == "weapon_pipe_bomb" || wep == "weapon_vomitjar" )
		dummyWep = "molotov";
	else if ( wep == "weapon_molotov" )
		dummyWep = "pipe_bomb";
	else if ( wep == "weapon_gascan" || wep == "weapon_propanetank" || wep == "weapon_oxygentank" || wep == "weapon_fireworkcrate" || wep == "weapon_cola_bottles" )
		dummyWep = "gnome";
	else if ( wep == "weapon_gnome" )
		dummyWep = "gascan";
	else if ( wep == "weapon_rifle" )
		dummyWep = "smg";
	else
		dummyWep = "rifle";

	if (t)
	{
		foreach (item in t)
		{
			if ( item.GetClassname() == wep )
			{
				p.GiveItem(dummyWep);
				BotAI.removeItem(p, dummyWep);
				DoEntFire("!self", "CancelCurrentScene", "", 0, null, p);
				item.Kill();
			}
		}
	}

	return true;
}

function BotAI::removeItem(p, itemname)
{
	local t = BotAI.GetHeldItems(p);

	if (t)
	{
		foreach (killitem in t)
		{
			if ( killitem.GetClassname() == itemname || killitem.GetClassname() == "weapon_" + itemname )
				killitem.Kill();
		}
	}
}

function BotAI::HasFlag(entity, flag )
{
	local flags = NetProps.GetPropInt(entity, "m_fFlags" );

	return flags == ( flags | flag );
}

/**
 * Adds the flag to the entity's current flags.
 */
function BotAI::AddFlag(entity, flag )
{
	local flags = NetProps.GetPropInt(entity, "m_fFlags" );

	if ( BotAI.HasFlag(entity, flag) )
		return;

	NetProps.SetPropInt(entity, "m_fFlags", ( flags | flag ) );
}

/**
 * Removes the flag from the entity's current flags.
 */
function BotAI::RemoveFlag(entity, flag )
{
	local flags = NetProps.GetPropInt(entity, "m_fFlags" );

	if ( !BotAI.HasFlag(entity, flag) )
		return;

	NetProps.SetPropInt(entity, "m_fFlags", ( flags & ~flag ) );
}

function BotAI::IsOnGround(entity) {
	return BotAI.HasFlag(entity, 1);
}

function BotAI::drawArrow(point0, point1, color, timeIn) {
	local dir = BotAI.normalize(point0 - point1);
	local finalPoint = point1 + dir.Scale(5);
	DebugDrawLine(point0 - dir.Scale(5), finalPoint, color.x, color.y, color.z, false, timeIn);
	local qDir = BotAI.CreateQAngle(dir.x, dir.y, dir.z);
	local lDir = QAngle(qDir.Pitch(), qDir.Yaw() + 30, 0);
	local rDir = QAngle(qDir.Pitch(), qDir.Yaw() - 30, 0);
	DebugDrawLine(finalPoint, finalPoint + lDir.Forward().Scale(15), color.x, color.y, color.z, false, timeIn);
	DebugDrawLine(finalPoint, finalPoint + rDir.Forward().Scale(15), color.x, color.y, color.z, false, timeIn);
}

function BotAI::printTable(table, valFunc = null, shouldPrint = null) {
	if(typeof table != "table") return;
	foreach(idx, val in table) {
		if(shouldPrint != null && (!shouldPrint(idx) || !shouldPrint(val)))
			continue;
		if(valFunc != null)
			printl("Idx: " + idx + " Val: " + valFunc(val));
		else
			printl("Idx: " + idx + " Val: " + val);
		BotAI.printTable(val, valFunc);
	}
}

function BotAI::printArray(arri, valFunc) {
	if(typeof arri != "array") return;
	foreach(idx, val in arri) {
		if(valFunc != null)
			printl("Idx: " + idx + " Val: " + valFunc(val));
		else
			printl("Idx: " + idx + " Val: " + val);
	}
}

function BotAI::hookViewEntity(ent_self, ent_b) {
	if(BotAI.IsEntityValid(ent_b)) {
		printl("player " + BotAI.getPlayerBaseName(ent_self) + " hook: " + ent_b);

		//NetProps.SetPropEntity(ent_self, "m_viewtarget", ent_b);
	} else {
		//NetProps.SetPropInt(ent_self, "m_viewtarget", -1);
	}
}

function BotAI::getViewEntity(ent_self) {
	return NetProps.GetPropEntity(ent_self, "m_viewtarget");
}

function BotAI::getEntityHeadPos(ent_b) {
	if(!BotAI.IsEntityValid(ent_b)) {
		printl("[Bot AI DEBUG] ent_b not valid: " + ent_b);
		return;
	}

	local x = 0;
	local y = 0;
	local z = 0;

	if(ent_b.GetClassname() == "survivor_death_model") {
		x = ent_b.GetOrigin().x;
		y = ent_b.GetOrigin().y;
		z = ent_b.GetOrigin().z;
	} else if("LookupAttachment" in ent_b) {
		local attachId = ent_b.LookupAttachment("forward");
		local position = ent_b.GetAttachmentOrigin(attachId);

		x = position.x;
		y = position.y;
		z = position.z;
	} else if("EyePosition" in ent_b ) {
		x = ent_b.EyePosition().x;
		y = ent_b.EyePosition().y;
		z = ent_b.EyePosition().z;
	} else if("GetBoneOrigin" in ent_b) {
		x = ent_b.GetBoneOrigin(14).x;
		y = ent_b.GetBoneOrigin(14).y;
		z = ent_b.GetBoneOrigin(14).z;
	} else {
		x = ent_b.GetCenter().x;
		y = ent_b.GetCenter().y;
		z = ent_b.GetCenter().z;
	}

	return Vector(x, y, z);
}

function BotAI::lookAtEntity(ent_self, ent_b, frozen = false, time = 1) {
	if(!BotAI.IsEntityValid(ent_b)) {
		printl("[Bot AI DEBUG] ent_b not valid: " + ent_b);
		return;
	}

	local headPos = BotAI.getEntityHeadPos(ent_b);

	if(BotAI.BotDebugMode) {
		DebugDrawBox(headPos, Vector(-10, -10, -10), Vector(10, 10, 10), 100, 255, 0, 0.2, 0.2);
		DebugDrawText(headPos, BotAI.getPlayerBaseName(ent_self) + " want me", false, 0.2);
	}

	if(ent_b == BotAI.getSmokerTarget(ent_self)) {
		local dirction = Vector(headPos.x - ent_self.EyePosition().x, headPos.y - ent_self.EyePosition().y, headPos.z - ent_self.EyePosition().z);
		local qAngleDirction = BotAI.CreateQAngle(dirction.x, dirction.y, dirction.z);
		ent_self.SnapEyeAngles(qAngleDirction);
		local eyeVec = QAngle(ent_self.EyeAngles().x + 55, ent_self.EyeAngles().y, 0);
		ent_self.SnapEyeAngles(eyeVec);

		BotAI.AddFlag( ent_self, FL_FROZEN );

		local function RemoveFlag(ent_) {
			if(BotAI.IsEntityValid(ent_))
				BotAI.RemoveFlag( ent_, FL_FROZEN );
		}

		::BotAI.Timers.AddTimerByName("hitTongue" + ent_self.GetEntityIndex(), 0.3, false, RemoveFlag, ent_self);
		return;
	}

	if((ent_b.GetClassname() == "infected" || ent_b.GetClassname() == "player") && "EyePosition" in ent_self) {
		if(frozen && BotAI.HasFlag(ent_self, FL_FROZEN))
			BotAI.RemoveFlag(ent_self, FL_FROZEN );

		local dirction = Vector(headPos.x - ent_self.EyePosition().x, headPos.y - ent_self.EyePosition().y, headPos.z - ent_self.EyePosition().z);
		local qAngleDirction = BotAI.CreateQAngle(dirction.x, dirction.y, dirction.z);

		if(BotAI.BotCombatSkill == 0) {
			local eyeAngle = ent_self.EyeAngles();
			local angle = (qAngleDirction.Yaw() - eyeAngle.Yaw()) / 4;
			if(angle <= 20 && angle >= -20)
				angle = qAngleDirction.Yaw();
			else
				angle = eyeAngle.Yaw() + angle;
			qAngleDirction = QAngle(qAngleDirction.Pitch(), angle, qAngleDirction.Roll());
		}

		ent_self.SnapEyeAngles(qAngleDirction);

		if(frozen) {
			BotAI.AddFlag(ent_self, FL_FROZEN );

			local function RemoveFlag(ent_) {
				if(ent_ != null)
					BotAI.RemoveFlag(ent_, FL_FROZEN );
			}

			::BotAI.Timers.AddTimerByName("RemoveFrozen" + ent_self.GetEntityIndex(), time, false, RemoveFlag, ent_self);
		}
	}
	else
		BotAI.lookAtPosition(ent_self, headPos, frozen, time);
}

function BotAI::lookAtPosition(player, vec, frozen = false, time = 1) {
	if(frozen && BotAI.HasFlag(player, FL_FROZEN))
		BotAI.RemoveFlag(player, FL_FROZEN );

	if("SnapEyeAngles" in player)
		player.SnapEyeAngles(BotAI.CreateQAngle(vec.x - player.EyePosition().x, vec.y - player.EyePosition().y, vec.z - player.EyePosition().z));

	if(frozen) {
		BotAI.AddFlag(player, FL_FROZEN );

		local function RemoveFlag(ent_) {
			if(ent_ != null)
				BotAI.RemoveFlag(ent_, FL_FROZEN );
		}

		::BotAI.Timers.AddTimerByName("RemoveFrozen" + player.GetEntityIndex(), time, false, RemoveFlag, player);
	}
}

::BotAI.CreateQAngle <- function(x, y, z) {
	local yaw = (atan2(y, x) * 180 / PI);
	if (yaw < 0)
		yaw += 360;

		local tmp = sqrt (x * x + y * y);
		local pitch = (atan2(-z, tmp) * 180 / PI);
		if (pitch < 0)
			pitch += 360;

	if(x == 0 && y == 0){
		if (z > 0)
				pitch = 270;
			else
				pitch = 90;
	}

	return QAngle(pitch, yaw, 0);
}

function BotAI::isTouchSolid(_ignore, _start, _end) {
	local traceTable = {
		start = _start
		end = _end
		ignore = _ignore
		mask = g_MapScript.TRACE_MASK_SHOT
	}
	TraceLine(traceTable);

	local result = 0;
	if(traceTable.hit) {
		if(BotAI.IsLivingEntity(traceTable.enthit))
			return 0;
		result+=1;
		if(BotAI.isDoorEntity(traceTable.enthit)) {
			result+=1;
			if(!BotAI.doorOpened(traceTable.enthit)) {
				result+=1;
				DoEntFire("!self", "Use", "", 0, _ignore, traceTable.enthit);
			}
		}
	}

	if(BotAI.BotDebugMode) {
		if(result > 0) {
			DebugDrawLine(_start, _end, 255, 0, 0, false, 2.2);
		} else {
			DebugDrawLine(_start, _end, 255, 255, 255, false, 0.2);
		}
	}

	return result;
}

function BotAI::checkObstacle(player, vec) {
	local centerPoint = player.GetOrigin() + Vector(0, 0, 20) + BotAI.normalize(vec).Scale(30);
	local point_0 = player.GetOrigin() + Vector(0, 0, 71);
	local point_1 = player.GetOrigin() + Vector(0, 0, 8) + BotAI.normalize(BotAI.rotateVector(vec, 90)).Scale(6);
	local point_2 = player.GetOrigin() + Vector(0, 0, 8) + BotAI.normalize(BotAI.rotateVector(vec, -90)).Scale(6);
	local point_3 = player.GetOrigin() + Vector(0, 0, 8);
	local point_4 = player.GetOrigin() + Vector(0, 0, 39) + BotAI.normalize(BotAI.rotateVector(vec, 90)).Scale(14);
	local point_5 = player.GetOrigin() + Vector(0, 0, 39) + BotAI.normalize(BotAI.rotateVector(vec, -90)).Scale(14);
	local dodgeVec = 0;
	local jump = 0;

	if(BotAI.isTouchSolid(player, point_1, centerPoint) > 0) {
		jump +=1;
		dodgeVec += -60;
	}

	if(BotAI.isTouchSolid(player, point_2, centerPoint) > 0) {
		jump +=1;
		dodgeVec += 60;
	}

	if(BotAI.isTouchSolid(player, point_4, centerPoint) > 0) {
		dodgeVec += -60;
	}

	if(BotAI.isTouchSolid(player, point_5, centerPoint) > 0) {
		dodgeVec += 60;
	}

	BotAI.isTouchSolid(player, point_0, centerPoint);

	local result_3 = BotAI.isTouchSolid(player, point_3, centerPoint);
	if(result_3 > 0) {
		jump +=1;
		if(result_3 >= 2) {
			jump -=1;
		}
	}

	if(jump > 2) {
		local navigator = BotAI.getNavigator(player);
		if(navigator.isPathFlat())
			BotAI.ForceButton(player, 2 , 0.2);
	}
	return dodgeVec;
}

function BotAI::tracePos(player, pos, onlyGround = false) {
	local traceTable = {
		start = player.EyePosition()
		end =  (pos - player.EyePosition()).Scale(100) + pos
		ignore = player
		mask = MASK_SOLID
	}
	TraceLine(traceTable);

	if(traceTable.hit) {
		if(onlyGround) return traceTable.pos;
		if(traceTable.enthit != null && (traceTable.pos - player.GetOrigin()).z < 57)
			return pos;

		return traceTable.pos;
	}
	return null;
}

function BotAI::GetHitPosition(player, distan, bol) {
	BotAI.debugCall("GetHitPosition");
	local m_trace = { start = player.EyePosition(), end = player.EyePosition() + player.EyeAngles().Forward().Scale(distan), ignore = player, mask = g_MapScript.TRACE_MASK_ALL};
	TraceLine(m_trace);

	if (!m_trace.hit || m_trace.enthit == null || m_trace.enthit == player)
		return null;

	if (m_trace.enthit.GetClassname() == "worldspawn" || !m_trace.enthit.IsValid())
		return null;

	if(bol)
	{
		if(m_trace.enthit.GetClassname() == "point_prop_use_target")
			return m_trace.pos;
		else
			return null;
	}

	return m_trace.pos;
}

function BotAI::IsEntityValid(_ent) {
	BotAI.debugCall("IsEntityValid");
	if (_ent == null)
		return false;

	if (!("IsValid" in _ent))
		return false;

	if (!_ent.IsValid())
		return false;

	return true;
}

function BotAI::spawnParticle(particleName, position, target = null) {
	local particle = g_ModeScript.CreateSingleSimpleEntityFromTable({ classname = "info_particle_system", targetname = "botai_tmp_" + UniqueString(), origin = position, angles = QAngle(0,0,0), start_active = true, effect_name = particleName });

	if (particle) {
		DoEntFire("!self", "Kill", "", 5, null, particle);
		DoEntFire("!self", "Start", "", 0, null, particle);
		particle.SetOrigin(position);
		if(target != null)
			DoEntFire("!self", "SetParent", "!activator", 0, particle, target);
	}
}

function BotAI::IsPlayerEntityValid(_ent)
{
	if(!BotAI.IsEntityValid(_ent))
		return false;

	if ("IsPlayer" in _ent)
		return _ent.IsPlayer();

	return false;
}

function BotAI::IsEntitySI(entity)
{
	if(BotAI.IsPlayerEntityValid(entity) && !entity.IsSurvivor() && BotAI.IsAlive(entity))
		return true;

	return false;
}

function BotAI::IsEntitySIBot(entity)
{
	if(BotAI.IsEntitySI(entity) && IsPlayerABot(entity))
		return true;

	return false;
}

function BotAI::IsEntitySurvivor(entity) {
	if(BotAI.IsPlayerEntityValid(entity) && entity.IsSurvivor() && BotAI.IsAlive(entity))
		return true;

	return false;
}

function BotAI::Laugh(player) {
	if(BotAI.IsEntitySurvivor(player)) {
		DoEntFire("!self", "SpeakResponseConcept", "PlayerLaugh", 0, null, player);
	}
}

function BotAI::IsEntitySurvivorBot(entity)
{
	if(BotAI.IsEntitySurvivor(entity) && IsPlayerABot(entity))
		return true;

	return false;
}

function BotAI::HasItem(player, str)
{
	if(player in BotAI.BotLinkGasCan) {
		local gas = BotLinkGasCan[player];
		if(BotAI.IsEntityValid(gas) && gas.GetOwnerEntity() == null && gas.GetClassname() == str)
			return true;
	}
	local t = BotAI.GetHeldItems(player);

	if (t)
	{
		foreach (item in t)
		{
			if ( item.GetClassname() == str || item.GetClassname() == "weapon_" + str )
				return true;
		}
	}

	return false;
}

//void GetInvTable(CTerrorPLayer player, table invTable)
//GetInvTable is a danger function, the first param if it's not CTerrorPLayer or it's null, game crashes
function BotAI::GetHeldItems(player) {
	local t = {};
	if(!BotAI.IsEntitySurvivor(player)) return t;
	local table = {};
	GetInvTable(player, table);

	foreach( slot, item in table )
		t[slot] <- item;

	return t;
}

function BotAI::isEntitySP(entity)
{
	if(BotAI.IsEntityValid(entity) && entity.GetClassname() == "player" && !entity.IsSurvivor())
		return true;

	if(BotAI.IsEntityValid(entity) && entity.GetClassname() == "witch" )
		return true;

	return false;
}

function BotAI::isEntityInfected(entity)
{
	if(BotAI.IsEntityValid(entity) && entity.GetClassname() == "infected")
		return true;

	return false;
}

::BotAI.IsAlive <- function(_ent) {
	if(!BotAI.IsEntityValid(_ent))
		return false;

	if("GetSequenceName" in _ent) {
		local sequenceName = _ent.GetSequenceName(_ent.GetSequence()).tolower();
		if(sequenceName.find("death") != null && !(BotAI.IsPlayerEntityValid(_ent) && _ent.IsSurvivor())) {
			return false;
		}
	}

	if ( _ent.GetClassname() == "infected" || _ent.GetClassname() == "witch" || _ent.GetClassname() == "player" ) {
		return NetProps.GetPropInt(_ent, "m_lifeState" ) == 0;
	} else {
		return _ent.GetHealth() > 0;
	}
}

::BotAI.IsLivingEntity <- function(_ent) {
	if(!BotAI.IsEntityValid(_ent))
		return false;

	return _ent.GetClassname() == "infected" || _ent.GetClassname() == "witch" || _ent.GetClassname() == "player";
}

function BotAI::CanHumanSeePlace(posIn) {
	foreach(sur in BotAI.SurvivorHumanList) {
		if(BotAI.IsAlive(sur) && BotAI.VectorDotProduct(BotAI.normalize(sur.EyeAngles().Forward()), BotAI.normalize(posIn - sur.GetOrigin())) > 0)
			return true;
	}
	return false;
}

function BotAI::applyDamage(owner, target, amount, damageType) {
	target.TakeDamageEx(owner, owner, owner.GetActiveWeapon(), BotAI.normalize(target.GetOrigin() - owner.GetOrigin())
					, BotAI.getEntityHeadPos(target), amount, damageType);
}

function BotAI::IsInCombat(player, lowCheck = false) {
	if(!BotAI.IsPlayerEntityValid(player)) return false;

	local target = BotAI.GetTarget(player);
	if(BotAI.IsEntityValid(target) && !lowCheck) {
		if(BotAI.isEntitySP(target) || BotAI.isEntityInfected(target)) {
			return true;
		}
	}

	target = BotAI.getBotTarget(player);
	if(BotAI.IsEntityValid(target) && !lowCheck) {
		return true;
	}

	local findInfected = null;
	while(findInfected = Entities.FindByClassnameWithin(findInfected, "infected", player.GetOrigin(), 200)) {
		if(BotAI.IsAlive(findInfected) && BotAI.IsTarget(player, findInfected)) {
			return true;
		}
	}

	local findSI = null;
	while(findSI = Entities.FindByClassnameWithin(findSI, "player", player.GetOrigin(), 500)) {
		if(!findSI.IsSurvivor() && BotAI.IsAlive(findSI) && BotAI.IsTarget(player, findSI)) {
			return true;
		}
	}

	return false;
}

function BotAI::IsNearStartingArea(player)
{
	if(BotAI.StartPos == null)
		return;
	local endVec = player.GetOrigin();

	return BotAI.distanceof(BotAI.StartPos, endVec) < 600;
}

function BotAI::IsPressingAttack(_ent)
{
	if(!BotAI.IsAlive(_ent)) return false;
	return (_ent.GetButtonMask() & (1 << 0)) > 0;
}

function BotAI::IsPressingJump(_ent)
{
	if(!BotAI.IsAlive(_ent)) return false;
	return (_ent.GetButtonMask() & (1 << 1)) > 0;
}

function BotAI::IsPressingDuck(_ent)
{
	if(!BotAI.IsAlive(_ent)) return false;
	return (_ent.GetButtonMask() & (1 << 2)) > 0;
}

function BotAI::IsPressingUse(_ent)
{
	if(!BotAI.IsAlive(_ent)) return false;
	return (_ent.GetButtonMask() & (1 << 5)) > 0;
}

function BotAI::IsPressingReload(_ent)
{
	if(!BotAI.IsAlive(_ent)) return false;
	return (_ent.GetButtonMask() & (1 << 13)) > 0;
}

function BotAI::IsPressingShove(_ent)
{
	if(!BotAI.IsAlive(_ent)) return false;
	return (_ent.GetButtonMask() & (1 << 11)) > 0;
}

function BotAI::isPressingAlt(ent) {
	if(!BotAI.IsAlive(ent)) return false;
	return (ent.GetButtonMask() & 0x8000) > 0;
}

function BotAI::IsPressingForward(_ent)
{
	if(!BotAI.IsAlive(_ent)) return false;
	return (_ent.GetButtonMask() & (1 << 3)) > 0;
}

function BotAI::IsPressingBackward(_ent)
{
	if(!BotAI.IsAlive(_ent)) return false;
	return (_ent.GetButtonMask() & (1 << 4)) > 0;
}

function BotAI::IsPressingLeft(_ent)
{
	if(!BotAI.IsAlive(_ent)) return false;
	return (_ent.GetButtonMask() & (1 << 9)) > 0;
}

function BotAI::IsPressingRight(ent) {
	if(!BotAI.IsAlive(ent)) return false;
	return (ent.GetButtonMask() & (1 << 10)) > 0;
}

function BotAI::VectorDotProduct(a, b)
{
	return (a.x * b.x) + (a.y * b.y) + (a.z * b.z);
}

function BotAI::VectorFromQAngle(angles, radius = 1.0)
{
	local function ToRad(angle)
	{
		return (angle * PI) / 180;
	}

	local yaw = ToRad(angles.Yaw());
	local pitch = ToRad(-angles.Pitch());

	local x = radius * cos(yaw) * cos(pitch);
	local y = radius * sin(yaw) * cos(pitch);
	local z = radius * sin(pitch);

	return Vector(x, y, z);
}

function BotAI::IsOnFire(_ent) {
	if (!BotAI.IsEntityValid(_ent)) {
		return false;
	}

	if ( _ent.GetClassname() == "infected" || _ent.GetClassname() == "witch" )
		return NetProps.GetPropInt(	_ent, "m_bIsBurning" ) > 0 ? true : false;
	else if ( _ent.GetClassname() == "player" )
		return _ent.IsOnFire();
	else
		return false;
}

function BotAI::IsSurvivorTrapped(_ent) {
	if (!BotAI.IsPlayerEntityValid(_ent)) {
		return false;
	}
	return _ent.IsDominatedBySpecialInfected();

	if(!(_ent.GetEntityIndex() in BotAI.SurvivorTrapped))
		return false;

	return BotAI.SurvivorTrapped[_ent.GetEntityIndex()] != null;
}

function BotAI::IsSurvivorTrappedTimed(_ent)
{
	if (!BotAI.IsEntityValid(_ent))
	{
		return false;
	}

	if(!(_ent.GetEntityIndex() in BotAI.SurvivorTrappedTimed))
		return false;

	return BotAI.SurvivorTrappedTimed[_ent.GetEntityIndex()] != null;
}

function BotAI::CreateEntity(_classname, pos = Vector(0,0,0), ang = QAngle(0,0,0), kvs = {})
{
	kvs.classname <- _classname;
	kvs.origin <- pos;
	kvs.angles <- ang;

	local ent = g_ModeScript.CreateSingleSimpleEntityFromTable(kvs);

	if (!ent)
		return null;

	ent.ValidateScriptScope();

	return ent;
}

function BotAI::SetBotGasFinding(player, level) {
	//BotAI.GasFinding[player.GetEntityIndex()] <- level;
}

function BotAI::IsBotGasFinding(player) {
	return false;
	if(!BotAI.IsEntityValid(player))
		return false;
	if(player in BotAI.moveDebug && BotAI.moveDebug[player])
		return true;
	if(player.GetEntityIndex() in BotAI.GasFinding && BotAI.GasFinding[player.GetEntityIndex()] > 0)
		return true;
	return false;
}

function BotAI::getBotGasFinding(player) {
	if(!BotAI.IsEntityValid(player))
		return 0;
	if(player.GetEntityIndex() in BotAI.GasFinding)
		return BotAI.GasFinding[player.GetEntityIndex()];
	return 0;
}

::BotAI.CanSeeLocation <- function(player, otherEntity, tolerance = 50) {
	if (!player.IsValid()) {
		return false;
	}

	local clientPos = player.GetOrigin();
	if("EyePosition" in player)
		clientPos = player.EyePosition();
	else
		clientPos += Vector(0, 0, 62);

	local clientToTargetVec = otherEntity - clientPos;
	local clientAimVector = Vector(0, 0, 0);
	if("EyeAngles" in player)
		clientAimVector = player.EyeAngles().Forward();
	else if("GetForwardVector" in player)
		clientAimVector = player.GetForwardVector();

	local angToFind = acos(BotAI.VectorDotProduct(clientAimVector, clientToTargetVec) / (clientAimVector.Length() * clientToTargetVec.Length())) * 360 / 2 / 3.14159265;

	if (angToFind >= tolerance)
		return false;
	else
		return true;
}

::BotAI.CanSeeOtherEntity <- function(player, otherEntity, tolerance = 50, seeBarrier = false)
{
	BotAI.debugCall("CanSeeOtherEntity");
	if (!player.IsValid() || !otherEntity.IsValid())
	{
		return false;
	}

	local clientPos = player.GetOrigin();
	if("EyePosition" in player)
		clientPos = player.EyePosition();
	else
		clientPos += Vector(0, 0, 62);

	local clientToTargetVec = otherEntity.GetOrigin() - clientPos;
	local clientAimVector = Vector(0, 0, 0);
	if("EyeAngles" in player)
		clientAimVector = player.EyeAngles().Forward();
	else if("GetForwardVector" in player)
		clientAimVector = player.GetForwardVector();

	local angToFind = acos(BotAI.VectorDotProduct(clientAimVector, clientToTargetVec) / (clientAimVector.Length() * clientToTargetVec.Length())) * 360 / 2 / 3.14159265;

	if (angToFind >= tolerance)
		return false;
	else if(!seeBarrier)
		return true;
	else
	{
		local endVec = otherEntity.GetOrigin();
		local startVec = player.GetOrigin();

		if("EyePosition" in otherEntity)
			endVec = otherEntity.EyePosition();
		if("EyePosition" in player)
			startVec = player.EyePosition();

		local m_trace = { start = startVec, end = endVec, ignore = player};
		TraceLine(m_trace);

		if (!m_trace.hit || m_trace.enthit == null || m_trace.enthit == player)
			return false;

		if (m_trace.enthit.GetClassname() == "worldspawn" || !m_trace.enthit.IsValid())
			return false;

		if (m_trace.enthit == otherEntity)
			return true;

		return false;
	}
}

function BotAI::CanSeeOtherEntityWithoutBarrier(player, otherEntity, tolerance = 50, MaskSet = null)
{
	BotAI.debugCall("CanSeeOtherEntityWithoutBarrier");
	local clientPos = player.EyePosition();
	local clientToTargetVec = otherEntity.GetOrigin() - clientPos;
	local clientAimVector = player.EyeAngles().Forward();

	local angToFind = acos(BotAI.VectorDotProduct(clientAimVector, clientToTargetVec) / (clientAimVector.Length() * clientToTargetVec.Length())) * 360 / 2 / 3.14159265;

	if (angToFind > tolerance)
		return false;

	if(MaskSet == null)
		MaskSet = MASK_UNTHROUGHABLE;

	// Next check to make sure it's not behind a wall or something
	local m_trace = { start = player.EyePosition(), end = otherEntity.GetOrigin(), ignore = player, mask = MaskSet};
	TraceLine(m_trace);

	local mT = true;

	if (!m_trace.hit || m_trace.enthit == null || m_trace.enthit == player)
		mT = false;

	if (mT && (m_trace.enthit.GetClassname() == "worldspawn" || !m_trace.enthit.IsValid()))
		mT = false;

	if (mT && m_trace.enthit == otherEntity)
		return true;

	if("EyePosition" in otherEntity)
	{
		local n_trace = { start = player.EyePosition(), end = otherEntity.EyePosition(), ignore = player, mask = MaskSet};
		TraceLine(n_trace);

		local nT = true;

		if (!n_trace.hit || n_trace.enthit == null || n_trace.enthit == player)
			nT = false;

		if (nT && (n_trace.enthit.GetClassname() == "worldspawn" || !n_trace.enthit.IsValid()))
			nT = false;

		if (nT && n_trace.enthit == otherEntity)
			return true;
	}

	if("GetBoneOrigins" in otherEntity)
	{
		local n_trace = { start = player.EyePosition(), end = otherEntity.GetBoneOrigin(14), ignore = player, mask = MaskSet};
		TraceLine(n_trace);

		local nT = true;

		if (!n_trace.hit || n_trace.enthit == null || n_trace.enthit == player)
			nT = false;

		if (nT && (n_trace.enthit.GetClassname() == "worldspawn" || !n_trace.enthit.IsValid()))
			nT = false;

		if (nT && n_trace.enthit == otherEntity)
			return true;
	}

	return false;
}

::BotAI.CanGetWithoutDanger <- function(player, otherEntity = null, certainVec = null)
{
	BotAI.debugCall("CanGetWithoutDanger");
	if((otherEntity == null && certainVec == null) || !BotAI.IsPlayerEntityValid(player))
		return false;

	local height = 0;

	if(otherEntity != null)
		height = player.GetOrigin().z - otherEntity.GetOrigin().z + 15

	if(certainVec != null)
		height = player.GetOrigin().z - certainVec.z;

	if(	height < 65)
		return true;

	local startVec = player.GetOrigin();
	local endVec = player.GetOrigin();
	local startPt = player.GetOrigin();

	if(otherEntity != null)
	{
		startVec = otherEntity.GetOrigin() + Vector(0, 0, height);
		endVec = otherEntity.GetOrigin() + Vector(0, 0, 60);
		startPt = otherEntity.GetOrigin() + Vector(0, 0, 64);
	}

	if(certainVec != null)
	{
		startVec = Vector(certainVec.x, certainVec.y, player.GetOrigin().z);
		endVec = certainVec;
		startPt = endVec;
	}

	/*local playerVec = player.GetOrigin() + Vector(0, 0, 20);
	local n_trace = { start = playerVec, end = endVec, ignore = player, mask = MASK_UNTHROUGHABLE};
	TraceLine(n_trace);
	if (n_trace.hit && n_trace.enthit != null)
		return true;
	*/
	local twoDEndVec = BotAI.fakeTwoD(endVec);
	local twoDStartVec = BotAI.fakeTwoD(startVec);
	if(otherEntity == null && BotAI.GetDistanceToWall(player, twoDEndVec) <= (twoDStartVec - twoDEndVec).Length())
		return true;

	local m_trace = { start = startVec, end = endVec, mask = MASK_UNTHROUGHABLE};
	TraceLine(m_trace);

	if (!m_trace.hit || m_trace.enthit == null)
		return false;

	//have floor
	if (m_trace.enthit.GetClassname() == "worldspawn" || m_trace.enthit.GetClassname() == "player")
	{
		if(height < 300)
			return true;
		else
		{
			local endPt = startPt + Vector(0, 0, 300);
			local b_trace = { start = startPt, end = endPt, mask = MASK_UNTHROUGHABLE};
			TraceLine(b_trace);
			if (b_trace.hit && b_trace.enthit != null)
			{
				if (b_trace.enthit.GetClassname() == "worldspawn" || b_trace.enthit.GetClassname() == "player")
					return true;
			}

			local w_trace = { start = startVec, end = endVec, mask = MASK_UNTHROUGHABLE_WATER};
			TraceLine(w_trace);
			if (w_trace.hit && w_trace.enthit != null)
			{
				if (w_trace.enthit.GetClassname() != "worldspawn")
					return true;

				if (w_trace.enthit.GetClassname() == "worldspawn" && height < 100)
					return true;
			}
		}
	}

	return false;
}

function BotAI::CanSeeOtherEntityWithoutLocation(player, otherEntity, height = 0, attack = false, _mask = g_MapScript.TRACE_MASK_SHOT)
{
	if (!BotAI.IsPlayerEntityValid(player)) return false;

	local eyevec = otherEntity.GetOrigin() + Vector(0, 0, 50);

	if("EyePosition" in otherEntity)
		eyevec = otherEntity.EyePosition();
	else if("GetBoneOrigin" in otherEntity)
		eyevec = otherEntity.GetBoneOrigin(14);

	local mpHit = true;

	local mp_trace = { start = player.EyePosition() + Vector(0, 0, height), end = eyevec, ignore = player, mask = _mask};
	TraceLine(mp_trace);

	if (!mp_trace.hit || mp_trace.enthit == null || mp_trace.enthit == player)
		mpHit = false;

	if(mpHit && mp_trace.enthit == otherEntity) {
		return true;
	}

	local npHit = true;

	local np_trace = { start = eyevec + Vector(0, 0, height), end = player.EyePosition(), ignore = otherEntity, mask = _mask};
	TraceLine(np_trace);

	if (!np_trace.hit || np_trace.enthit == null || np_trace.enthit == otherEntity)
		npHit = false;

	if(npHit && np_trace.enthit == player) {
		return true;
	}

	return false;
}

function BotAI::CanHitOtherEntity(molotov, tank, _mask = null)
{
	if(_mask == null)
		_mask = MASK_UNTHROUGHABLE;

	local m_trace = { start = molotov.GetOrigin(), end = tank.EyePosition(), ignore = molotov, mask = _mask};
	TraceLine(m_trace);

	if (!m_trace.hit || m_trace.enthit == null || m_trace.enthit == molotov)
		return false;

	if (m_trace.enthit == tank)
		return true;
	return false;
}

function BotAI::witchKilling(witch) {
	if(witch.GetSequenceName(witch.GetSequence()).tolower().find("killing") != null)
		return true;
	return false;
}

function BotAI::witchRetreat(witch) {
	if(witch.GetSequenceName(witch.GetSequence()).tolower().find("retreat") != null)
		return true;
	return false;
}

function BotAI::witchAngry(witch) {
	if(witch.GetSequenceName(witch.GetSequence()).tolower().find("agitated") != null)
		return true;
	return false;
}

function BotAI::witchRunning(witch) {
	if(witch.GetSequenceName(witch.GetSequence()).tolower().find("run") != null)
		return true;
	return false;
}

function BotAI::CanSeeOtherEntityPrintName(player, distan = 999999, pri = 1, trace_mask = g_MapScript.TRACE_MASK_SHOT)
{
	local m_trace = { start = player.EyePosition(), end = player.EyePosition() + player.EyeAngles().Forward().Scale(distan), ignore = player, mask = trace_mask};
	TraceLine(m_trace);

	if (!m_trace.hit || m_trace.enthit == null || m_trace.enthit == player) {
		if(pri == 1 && m_trace.enthit == player)
			printl("[Bot AI DEBUG] PLAYER_SELF ");
		return null;
	}

	if (m_trace.enthit.GetClassname() == "worldspawn" || !m_trace.enthit.IsValid())
		return null;

	if(pri == 1) {
		DumpObject(m_trace.enthit);
		printl("[Bot AI DEBUG] Name: " + m_trace.enthit.GetClassname());
		printl("[Bot AI DEBUG] ModelName: " + m_trace.enthit.GetModelName());
		printl("[Bot AI DEBUG] MoveType: " + BotAI.getMoveType(m_trace.enthit));
		printl("[Bot AI DEBUG] m_hOwnerEntity: " + NetProps.GetPropEntity(m_trace.enthit, "m_hOwnerEntity"));
		printl("[Bot AI DEBUG] m_hOwner: " + NetProps.GetPropEntity(m_trace.enthit, "m_hOwner"));

		if(m_trace.enthit.GetClassname() == "player") {
			if (m_trace.enthit.GetZombieType() == 1) {
				printl("[Bot AI DEBUG] m_duration: " + NetProps.GetPropFloat(NetProps.GetPropEntity(m_trace.enthit, "m_customAbility"), "m_nextActivationTimer.m_duration"));
				printl("[Bot AI DEBUG] m_timestamp: " + NetProps.GetPropFloat(NetProps.GetPropEntity(m_trace.enthit, "m_customAbility"), "m_nextActivationTimer.m_timestamp"));
				printl("[Bot AI DEBUG] m_tongueState: " + NetProps.GetPropInt(NetProps.GetPropEntity(m_trace.enthit, "m_customAbility"), "m_tongueState"));
				printl("[Bot AI DEBUG] m_tongueGrabStartingHealth: " + NetProps.GetPropInt(NetProps.GetPropEntity(m_trace.enthit, "m_customAbility"), "m_tongueGrabStartingHealth"));
				printl("[Bot AI DEBUG] Time(): " + Time());
			}

			printl("[Bot AI DEBUG] IsDominatedBySpecialInfected: " + m_trace.enthit.IsDominatedBySpecialInfected());
			printl("[Bot AI DEBUG] GetSpecialInfectedDominatingMe: " + m_trace.enthit.GetSpecialInfectedDominatingMe());
			printl("[Bot AI DEBUG] SI Victim: " + BotAI.getSiVictim(m_trace.enthit));
		}

		printl("[Bot AI DEBUG] Flags: " + NetProps.GetPropInt(m_trace.enthit, "m_spawnflags"));
		if("GetSequenceName" in m_trace.enthit) {
			local sequenceName = m_trace.enthit.GetSequenceName(m_trace.enthit.GetSequence()).tolower();
			printl("[Bot AI DEBUG] ActionState: " + m_trace.enthit.GetSequence() + " " + sequenceName);
		}
		local area = NavMesh.GetNavArea(m_trace.enthit.GetOrigin(), 100);
		if(area != null) {
			area.DebugDrawFilled(0, 0, 255, 15, 0.2, true);
		}
		printl("[Bot AI DEBUG] ViewEntity: " + NetProps.GetPropEntity(m_trace.enthit, "m_hViewEntity"));
		printl("[Bot AI DEBUG] LookatPlayer: " + NetProps.GetPropEntity(m_trace.enthit, "m_lookatPlayer"));

		printl("[Bot AI DEBUG] hit pos: " + m_trace.pos);
		printl("[Bot AI DEBUG] Position: " + m_trace.enthit.GetOrigin());
		printl("[Bot AI DEBUG] LocalVelocity: " + m_trace.enthit.GetLocalVelocity());
		printl("[Bot AI DEBUG] Velocity: " + m_trace.enthit.GetVelocity());
		printl("[Bot AI DEBUG] m_vecBaseVelocity: " + NetProps.GetPropVector(m_trace.enthit, "m_vecBaseVelocity"));
		printl("[Bot AI DEBUG] m_usable: " + NetProps.GetPropInt(m_trace.enthit, "m_usable"));
		local glowEntity = NetProps.GetPropEntity(m_trace.enthit, "m_glowEntity");
		if(glowEntity)
		printl("[Bot AI DEBUG] m_glowEntity: " + glowEntity.GetClassname() + "[" + glowEntity.GetEntityIndex() + "]" + " glow: " + NetProps.GetPropInt(glowEntity, "m_Glow.m_iGlowType") + " color: " + NetProps.GetPropInt(glowEntity, "m_Glow.m_glowColorOverride"));

		printl("[Bot AI DEBUG] Target: " + BotAI.GetTarget(m_trace.enthit));
		if(BotAI.IsEntitySurvivor(BotAI.GetTarget(m_trace.enthit))) {
			printl("[Bot AI DEBUG] me: " + BotAI.getPlayerBaseName(m_trace.enthit));
			printl("[Bot AI DEBUG] target: " + BotAI.getPlayerBaseName(BotAI.GetTarget(m_trace.enthit)));
		}
		if(m_trace.enthit in BotAI.botAim) {
			printl("[Bot AI DEBUG] BotAI.botAim: " + BotAI.botAim[m_trace.enthit]);
			printl("[Bot AI DEBUG] BotAI.botAim valid: " + BotAI.IsEntityValid(BotAI.botAim[m_trace.enthit]));
			if(BotAI.IsEntityValid(BotAI.botAim[m_trace.enthit])) {
				printl("[Bot AI DEBUG] BotAI.botAim classname: " + BotAI.botAim[m_trace.enthit].GetClassname());
				printl("[Bot AI DEBUG] BotAI.botAim alive: " + BotAI.IsAlive(BotAI.botAim[m_trace.enthit]));
			}
		}
		if("EyePosition" in m_trace.enthit)
			printl("[Bot AI DEBUG] Eye: " + m_trace.enthit.EyePosition());
		if(m_trace.enthit.GetClassname() == "weapon_spawn") {
			printl("[Bot AI DEBUG] WeaponID " + NetProps.GetPropInt(m_trace.enthit, "m_weaponID"));
		}

		local eyeAngle0 = NetProps.GetPropFloat(m_trace.enthit, "m_angEyeAngles[0]");
		local eyeAngle1 = NetProps.GetPropFloat(m_trace.enthit, "m_angEyeAngles[1]");

		printl("[Bot AI DEBUG] m_angEyeAngles: " + eyeAngle0 + ", " + eyeAngle1);
		printl("[Bot AI DEBUG]  GetAngles: " + m_trace.enthit.GetAngles());
		printl("[Bot AI DEBUG]  GetLocalAngles: " + m_trace.enthit.GetLocalAngles());

		if("EyeAngles" in m_trace.enthit)
			printl("[Bot AI DEBUG]  EyeAngles: " + m_trace.enthit.EyeAngles());

		local direcVec = NetProps.GetPropVector(m_trace.enthit, "m_angRotation");
		printl("[Bot AI DEBUG]  m_angRotation: " +BotAI.CreateQAngle(direcVec.x, direcVec.y, direcVec.z));
		printl("[Bot AI DEBUG]  GetForwardVector: " +BotAI.CreateQAngle(m_trace.enthit.GetForwardVector().x, m_trace.enthit.GetForwardVector().y, m_trace.enthit.GetForwardVector().z));
	}

	return m_trace.enthit;
}

::BotAI.GetEntitySpeedVector <- function(entity) {
	if(BotAI.IsEntityValid(entity)) {
		return entity.GetVelocity().Length();
	}
	return 0;
}

::BotAI.GetEntitySpeedLocalVector <- function(entity) {
	if(BotAI.IsEntityValid(entity)) {
		return GetPhysVelocity(entity).Length();
	}
	return 0;
}

function BotAI::getCross(p1, p2, p3) {
	local dx = p1.x - p2.x;
    local dy = p1.y - p2.y;

    local u = (p3.x - p1.x) * dx + (p3.y - p1.y) * dy;
    u /= dx * dx + dy * dy;

	return Vector((p1.x + u * dx), (p1.y + u * dy), 0);
}

function BotAI::xyCrossProduct(v1, v2) {
    return (v1.x*v2.y) - (v1.y*v2.x);
}

function BotAI::xyDotProduct(v1, v2) {
    return (v1.x*v2.x) + (v1.y*v2.y);
}

/**
 * Useless, ForceButton function can't control the movement of player entity.
 */
::BotAI.dodgeEntity <- function(player, infected)
{
	BotAI.debugCall("dodgeEntity");
	local living = "EyeAngles" in infected;
	local eyeVec = Vector(0, 0, 0);
	local dirction = Vector(0, 0, 0);

	if(BotAI.GetEntitySpeedVector(infected) > 10){
		eyeVec = infected.GetVelocity();
		dirction = player.GetOrigin() - infected.GetOrigin();
	}

	if(eyeVec.Length() <= 0){
		if(living)
			eyeVec = infected.EyeAngles().Forward();
		else{
			eyeVec = player.EyeAngles().Forward();
			dirction = infected.GetOrigin() - player.GetOrigin();
		}
	}

	local leftAndRight = BotAI.xyCrossProduct(eyeVec, dirction);
	local forwardAndBack = BotAI.xyDotProduct(eyeVec, dirction);
	local time = 1;

	if(leftAndRight > 0){
		BotAI.ForceButton(player, BUTTON_RIGHT , time);
		BotAI.DisableButton(player, BUTTON_LEFT , time);
		printl("[Bot AI] Dodge: Right.");
	}
	else if(leftAndRight < 0){
		BotAI.ForceButton(player, BUTTON_LEFT , time);
		BotAI.DisableButton(player, BUTTON_RIGHT , time);
		printl("[Bot AI] Dodge: Left.");
	}

	if(forwardAndBack > 0){
		BotAI.ForceButton(player, BUTTON_BACK , time);
		BotAI.DisableButton(player, BUTTON_FORWARD , time);
		printl("[Bot AI] Dodge: Back.");
	}
	else if(forwardAndBack < 0){
		BotAI.ForceButton(player, BUTTON_FORWARD , time);
		BotAI.DisableButton(player, BUTTON_BACK , time);
		printl("[Bot AI] Dodge: Forward.");
	}
}

::BotAI.validVector <- function(vector){
	return vector != null && "Vector" == typeof vector && vector.x.tostring().find("#") == null && vector.y.tostring().find("#") == null && vector.z.tostring().find("#") == null;
}

::BotAI.normalize <- function(vector){
	if(!validVector(vector)) return Vector(0, 0, 0);
	local length = vector.Length();

	return Vector(vector.x / length, vector.y / length, vector.z / length);
}

::BotAI.fakeTwoD <- function(vector){
	if(!validVector(vector)) return Vector(0, 0, 0);

	return Vector(vector.x, vector.y, 0);
}

::BotAI.rotateVector <- function(vector, angle){
	if(!validVector(vector)) return Vector(0, 0, 0);

	/*
	local radians = angle * PI / 180;
	local x = vector.x * cos(radians) - vector.y * sin(radians);
	local y = vector.x * sin(radians) - vector.y * cos(radians);
	*/
	local length = vector.Length();
	local qAngle = BotAI.CreateQAngle(vector.x, vector.y, vector.z);
	return QAngle(qAngle.Pitch(), qAngle.Yaw() + angle, 0).Forward().Scale(length);
	//return Vector(x, y, vector.z);
}

function BotAI::printCollision(entity){
	printl("[Bot AI DEBUG] m_vecMins " + NetProps.GetPropVector(entity, "m_vecMins"));
	printl("[Bot AI DEBUG] m_vecMaxs " + NetProps.GetPropVector(entity, "m_vecMaxs"));
	printl("[Bot AI DEBUG] vecScale " + (NetProps.GetPropVector(entity, "m_vecMaxs") - NetProps.GetPropVector(entity, "m_vecMins")).Length());
}

function BotAI::GetDistanceToTop(entity)
{
	if (!BotAI.IsEntityValid(entity))
		return 0;

	local startPt = entity.GetCenter();
	if("EyePosition" in entity)
		startPt = entity.EyePosition();

	local endPt = startPt + Vector(0, 0, 9999999);

	local m_trace = { start = startPt, end = endPt, ignore = entity, mask = MASK_UNTHROUGHABLE };
	TraceLine(m_trace);

	if (m_trace.enthit == entity || !m_trace.hit)
		return 0.0;

	return BotAI.distanceof(startPt, m_trace.pos);
}

function BotAI::enableGlowColor(entity, red, green, blue) {
	local desiredColor = red | (green << 8) | (blue << 16);
	if(BotAI.IsEntityValid(entity)){
		NetProps.SetPropInt(entity, "m_Glow.m_iGlowType", 3);
		NetProps.SetPropInt(entity, "m_Glow.m_glowColorOverride", desiredColor);
	}
}

function BotAI::disableGlowColor(entity) {
	if(BotAI.IsEntityValid(entity)){
		NetProps.SetPropInt(entity, "m_Glow.m_iGlowType", 0);
		NetProps.SetPropInt(entity, "m_Glow.m_glowColorOverride", 0);
	}
}

function BotAI::vomitTank(entity) {
	if(BotAI.IsEntitySI(entity)){
		foreach(test in BotAI.SpecialList) {
			if(test != entity && BotAI.IsAlive(test) && IsPlayerABot(test)) {
				BotAI.BotAttack(test, entity);
			}
		}
		entity.HitWithVomit();
		::BotAI.Timers.AddTimerByName("vomitTank" + entity.GetEntityIndex(), 2, false, BotAI.vomitTank, entity);
	}
}

::BotAI.getDodgeVec <- function(player, infected, force = 220, backForce = 220, limit = 220, maxDis = 600, doubleHorizontal = true, motion_ = false) {
	if(!BotAI.IsPlayerEntityValid(player)) {
		printl("[Bot AI] getDodgeVec function use for player entity.");
		return Vector(0, 0, 0);
	}

	if(player.IsDominatedBySpecialInfected() || player.IsIncapacitated() || player.IsHangingFromLedge() || player.IsStaggering())
		return player.GetVelocity();

	local distance = BotAI.nextTickDistance(player, infected, 1.0);
	local nextPlayer = BotAI.nextTickPostion(player, 1.0);
	local nextInfected = BotAI.nextTickPostion(infected, 1.0);

	if(distance > maxDis) {
		distance = maxDis;
	}

	local disScale = 1 - (distance / maxDis);
	force *= disScale;
	backForce *= disScale;

	if(BotAI.getIsMelee(player) && (!BotAI.IsEntitySI(infected) || infected.GetZombieType() != 8)) {
		if(BotAI.IsTargetStaggering(infected) || (BotAI.IsEntitySI(infected) && infected.IsStaggering())) {
			local attractVec = nextInfected - nextPlayer;
			return BotAI.fakeTwoD(BotAI.normalize(attractVec).Scale(limit));
		} else if(BotAI.IsLivingEntity(infected)) {
			backForce *= -1;
		}
	}

	local living = "EyeAngles" in infected;
	local motion = Vector(0, 0, 0);
	local dirction = nextInfected - nextPlayer;
	local justLeft = false;

	if(BotAI.GetEntitySpeedVector(infected) > 10) {
		motion = infected.GetVelocity();
	} else {
		if(living) {
			motion = BotAI.normalize(BotAI.fakeTwoD(infected.EyeAngles().Forward()));
		} else {
			//motion = nextPlayer - nextInfected;
			//dirction = BotAI.normalize(BotAI.fakeTwoD(player.EyeAngles().Forward()));
			justLeft = true;
		}
	}

	local foot = BotAI.getCross(nextInfected, nextInfected + motion, nextPlayer);

	if(BotAI.BotDebugMode) {
		DebugDrawLine(nextInfected + Vector(0, 0, 20), nextPlayer + Vector(0, 0, 20), 60, 120, 255, true, 0.2);
		DebugDrawLine(foot + Vector(0, 0, 20), nextPlayer + Vector(0, 0, 20), 60, 255, 60, true, 0.2);
	}

	local horizontalVector;
	local verticalVector = BotAI.normalize(BotAI.fakeTwoD(dirction));

	if (!justLeft) {
		horizontalVector = BotAI.normalize(BotAI.fakeTwoD(nextPlayer - foot));
		verticalVector = BotAI.normalize(BotAI.fakeTwoD(dirction));
	} else {
		horizontalVector = BotAI.normalize(BotAI.fakeTwoD(BotAI.rotateVector(dirction, 90)));
		verticalVector = BotAI.normalize(BotAI.fakeTwoD(dirction));
	}

	local playerEyeVec = BotAI.normalize(BotAI.fakeTwoD(player.EyeAngles().Forward()));
	local obstacleVec = Vector(0, 0, 0);
	local maxWallDist = 200;
	local minWallDist = 0;

	local function clamp(value, min, max) {
		if (value < min) return min;
		if (value > max) return max;
		return value;
	}

	local wallCount = 0;

	for(local i = 0; i < 8; ++i) {
		local angleVec = BotAI.rotateVector(playerEyeVec, i * 45);
		local dist = BotAI.GetDistanceToWall(player, angleVec);

		if(dist <= maxWallDist) {
			wallCount++;
			local t = clamp((dist - minWallDist) / (maxWallDist - minWallDist), 0, 1);
			local weight = 1.0 - (t * t) * RandomFloat(0.5, 1.0);
			obstacleVec += angleVec.Scale(-force * weight);
		}
	}

	if (wallCount >= 5) {
		horizontalVector = obstacleVec;
		verticalVector = obstacleVec;
	} else {
		if(obstacleVec.Length() > 0) {
			obstacleVec = BotAI.normalize(obstacleVec);
			local closestDist = BotAI.GetDistanceToWall(player, obstacleVec);
			local blendFactor = clamp(1.0 - (closestDist / maxWallDist), 0.3, 1.0);

			local function lerp(a, b, t) {
				return a + (b - a) * t;
			}

			horizontalVector = BotAI.normalize(
				Vector(
					lerp(horizontalVector.x, obstacleVec.x, blendFactor * 0.7),
					lerp(horizontalVector.y, obstacleVec.y, blendFactor * 0.7),
					0
				)
			);

			verticalVector = BotAI.normalize(
				Vector(
					lerp(verticalVector.x, obstacleVec.x, blendFactor * 0.3),
					lerp(verticalVector.y, obstacleVec.y, blendFactor * 0.3),
					0
				)
			);
		}
	}

	if(BotAI.isEdge(player, horizontalVector)) {
		horizontalVector = horizontalVector.Scale(-1);
		if(BotAI.isEdge(player, horizontalVector)) {
			horizontalVector = Vector(0, 0, 0);
		}
	}

	if(BotAI.isEdge(player, verticalVector)) {
		verticalVector = verticalVector.Scale(-1);
		if(BotAI.isEdge(player, verticalVector)) {
			verticalVector = Vector(0, 0, 0);
		}
	}

	local newVec = BotAI.fakeTwoD(horizontalVector.Scale(force) + verticalVector.Scale(backForce));

	if(newVec.Length() > limit) {
		newVec = BotAI.normalize(newVec).Scale(limit);
	}

	if(motion) {
		newVec += BotAI.normalize(BotAI.fakeTwoD(player.GetOrigin() - infected.GetOrigin())).Scale(limit);
	}

	if(obstacleVec.Length() > 0) {
		newVec = newVec.Scale(1.5);
	}

	return newVec;
}

function BotAI::botDeath(bot, pos = null) {
	local infoTarget = null;
    while(infoTarget = Entities.FindByName(infoTarget, "botai_target_timer_" + bot.GetEntityIndex()))
         infoTarget.Kill();
	infoTarget = null;
	while(infoTarget = Entities.FindByName(infoTarget, "botai_navigator_timer_" + bot.GetEntityIndex()))
        infoTarget.Kill();
	if(bot in BotAI.playerNavigator)
		delete BotAI.playerNavigator[bot];
	if(bot in BotAI.BotLinkGasCan) {
		DoEntFire("!self", "ClearParent", "", 0, null, BotAI.BotLinkGasCan[bot]);
		if(BotAI.validVector(pos))
			BotAI.BotLinkGasCan[bot].SetOrigin(pos);
		else if("GetOrigin" in pos) {
			local function setPos(args) {
				if(BotAI.IsEntityValid(args.entity) && BotAI.IsEntityValid(args.player)) {
					args.entity.SetOrigin(args.player.GetOrigin());
					DoEntFire("!self", "Use", "", 0, args.player, args.entity);
				}
			}
			local gas = BotAI.BotLinkGasCan[bot];
			::BotAI.Timers.AddTimerByName("setEntityPos" + BotAI.BotLinkGasCan[bot].GetEntityIndex(), 0.5, false, setPos, {entity = gas, player = pos});
		} else  {
			local gas = BotAI.BotLinkGasCan[bot];
			BotAI.RemoveFlag(gas, 1);
			BotAI.RemoveFlag(gas, 8);
			BotAI.RemoveFlag(gas, 512);
			BotAI.AddFlag(gas, 256);

			DoEntFire("!self", "DisableMotion", "", 0.1, null, gas);
			DoEntFire("!self", "EnableMotion", "", 0.5, null, gas);
			BotAI.somethingBad[gas] <- gas;
		}

		delete BotAI.BotLinkGasCan[bot];
	}
}

function BotAI::GetDistanceToWall(entity, vec) {
	if (!BotAI.IsEntityValid(entity)) return 0.0;
	local startPt = entity.GetOrigin();
	if("EyePosition" in entity)
		startPt = entity.EyePosition();

	local endPt = startPt + BotAI.normalize(vec).Scale(200);

	local m_trace = { start = startPt, end = endPt, ignore = entity, mask = MASK_UNTHROUGHABLE };
	TraceLine(m_trace);

	if (!m_trace.hit)
		return 200;

	return BotAI.CalculateDistance(startPt, m_trace.pos);
}

function BotAI::isEdge(entity, vec) {
	if (!BotAI.IsEntityValid(entity)) return 0.0;
	local startPt = entity.GetOrigin();
	if("GetCenter" in entity)
		startPt = entity.GetCenter();

	vec = BotAI.normalize(vec).Scale(150);
	startPt += vec;

	local endPt = startPt + Vector(0, 0, -200);

	local m_trace = { start = startPt, end = endPt, ignore = entity, mask = MASK_UNTHROUGHABLE };
	TraceLine(m_trace);

	if (!m_trace.hit)
		return true;

	return false;
}

function BotAI::IsHumanSpectating(entity) {
	return NetProps.GetPropInt(entity, "m_humanSpectatorUserID") > 0;
}

function BotAI::isVomited(entity) {
	if(!IsEntityValid(entity))
		return false;

	if(!(entity.GetEntityIndex() in BotAI.VomitList))
		return false;

	if(!BotAI.VomitList[entity.GetEntityIndex()])
		return false;

	return true;
}

function BotAI::vomitBomb(vomitjar) {
	local angvec = Vector( 0, 0, 0 );
	local infectedX =
	{
		classname = "info_goal_infected_chase"
		origin = vomitjar.GetOrigin()
		angles = angvec
	}
	local infected = g_ModeScript.CreateSingleSimpleEntityFromTable(infectedX);
	infected.ValidateScriptScope();
	local effectX =
	{
		classname = "info_particle_system"
		effect_name = "vomit_jar"
		start_active = "1"
		angles = angvec
		origin = vomitjar.GetOrigin()
	}
	local effect = g_ModeScript.CreateSingleSimpleEntityFromTable(effectX);
	effect.ValidateScriptScope();

	if(BotAI.IsEntityValid(infected) && BotAI.IsEntityValid(effect)) {
		BotAI.playSound(vomitjar, "weapons/ceda_jar/ceda_jar_explode.wav");
		DoEntFire("!self", "Enable", "", 0, null, infected);
		vomitjar.Kill();
		DoEntFire("!self", "Kill", "", 15, null, effect);
		DoEntFire("!self", "Kill", "", 15, null, infected);

		local infec = null;
		while (infec = Entities.FindByClassnameWithin(infec, "infected", infected.GetOrigin(), 250)) {
			if(!BotAI.IsAlive(infec)) continue;
			RushVictim(infec, 3000);
			NetProps.SetPropInt(infec, "m_Glow.m_iGlowType", 3);
			NetProps.SetPropInt(infec, "m_Glow.m_glowColorOverride", -4713783);
			::BotAI.Timers.AddTimer(60, false, BotAI.disableGlowColor, infec);
		}

		local playerI = null;
		while (playerI = Entities.FindByClassnameWithin(playerI, "player", infected.GetOrigin(), 300)) {
			if(BotAI.IsAlive(playerI) && !playerI.IsSurvivor()) {
				playerI.HitWithVomit();
				BotAI.continueVomit[playerI.GetEntityIndex()] <- true;
				BotAI.vomitTank(playerI);
			}
		}
	}
}

function BotAI::GetDistanceToGround(entity)
{
	BotAI.debugCall("GetDistanceToGround");
	local startPt = entity.GetOrigin();
	local endPt = startPt + Vector(0, 0, -9999999);

	local m_trace = { start = startPt, end = endPt, ignore = entity, mask = g_MapScript.TRACE_MASK_SHOT };
	TraceLine(m_trace);

	if (m_trace.enthit == entity || !m_trace.hit)
		return 0.0;

	return BotAI.CalculateDistance(startPt, m_trace.pos);
}

function BotAI::CalculateDistance(vec1, vec2) {
	if (!vec1 || !vec2)
		return -1.0;

	return (vec2 - vec1).Length();
}

function BotAI::centerHeight(entity) {
	if(!BotAI.IsEntityValid(entity)) return 0;
	local heightVec = entity.GetCenter() - entity.GetOrigin();
	return heightVec.z;
}

function BotAI::nextTickDistance(entity, entity1, tps = 10.0, xy = false) {
	local startPos = BotAI.nextTickPostion(entity, tps);
	local targetPos = BotAI.nextTickPostion(entity1, tps);
	if(xy) {
		startPos = BotAI.fakeTwoD(startPos);
		targetPos = BotAI.fakeTwoD(targetPos);
	}

	return BotAI.distanceof(startPos, targetPos);
}

function BotAI::nextTickPostion(entity, tps = 10.0) {
	if(!BotAI.IsEntityValid(entity)) return Vector(0, 0, 0);

	local scale = 1.0 / tps;
	local vel = entity.GetVelocity().Scale(scale);
	return entity.GetOrigin();
}

/**
 * break
 */
/*
function BotAI::nextTickDistance(entity, entity1, tps = 10.0, xy = false) {
	local startPos = BotAI.nextTickPostion(entity, tps);
	local targetPos = BotAI.nextTickPostion(entity1, tps);
	if(xy) {
		startPos = BotAI.fakeTwoD(startPos);
		targetPos = BotAI.fakeTwoD(targetPos);
	}

	return BotAI.distanceof(startPos, targetPos);
}

function BotAI::nextTickPostion(entity, tps = 10.0) {
	if(!BotAI.IsEntityValid(entity)) return Vector(0, 0, 0);

	local scale = 1.0 / tps;
	local vel = entity.GetVelocity().Scale(scale);
	return entity.GetOrigin() + vel;
}
*/

function BotAI::distanceof(vec1, vec2) {
	if(!vec1 || !vec2)
		return 9000;

	if(!("Length" in vec1))
		return 9000;

	if(!("Length" in vec2))
		return 9000;

	return (vec2 - vec1).Length();
}

function BotAI::IsLastStrike(player) {
	if(!BotAI.IsAlive(player))
		return false;
	if("maxIncap" in BotAI)
		return BotAI.maxIncap == NetProps.GetPropInt(player, "m_currentReviveCount");

	local maxIncap = Convars.GetFloat("survivor_max_incapacitated_count");
	maxIncap = maxIncap.tointeger();

	if (("GetDirectorOptions" in DirectorScript) && ("SurvivorMaxIncapacitatedCount" in DirectorScript.GetDirectorOptions()))
		maxIncap = DirectorScript.GetDirectorOptions().SurvivorMaxIncapacitatedCount;
	if(!("maxIncap" in BotAI))
		BotAI.maxIncap <- maxIncap;
	return maxIncap == NetProps.GetPropInt(player, "m_currentReviveCount");
}

function BotAI::getSiVictim(si) {
	local victim = null;

	if(si.GetZombieType() == 6) {
		victim = NetProps.GetPropEntity(si, "m_pummelVictim");
		if (victim == null) {
			victim = NetProps.GetPropEntity(si, "m_carryVictim");
		}
	} else if(si.GetZombieType() == 3) {
		victim = NetProps.GetPropEntity(si, "m_pounceVictim");
	} else if(si.GetZombieType() == 5) {
		victim = NetProps.GetPropEntity(si, "m_jockeyVictim");
	} else if(si.GetZombieType() == 1) {
		victim = NetProps.GetPropEntity(si, "m_tongueVictim");
	}

	return victim;
}

function BotAI::StringReplace(string, original, replacement) {
	local expression = regexp(original);
	local result = "";
	local position = 0;

	local captures = expression.capture(string);

	while (captures != null)
	{
		foreach (i, capture in captures)
		{
			result += string.slice(position, capture.begin);
			result += replacement;
			position = capture.end;
		}

		captures = expression.capture(string, position);
	}

	result += string.slice(position);

	return result;
}

function BotAI::setLastStrike(player) {
	if(!BotAI.IsAlive(player))
		return;

	if("maxIncap" in BotAI) {
		player.SetReviveCount(BotAI.maxIncap);
		return;
	}

	local maxIncap = Convars.GetFloat("survivor_max_incapacitated_count");
	maxIncap = maxIncap.tointeger();

	if (("GetDirectorOptions" in DirectorScript) && ("SurvivorMaxIncapacitatedCount" in DirectorScript.GetDirectorOptions()))
		maxIncap = DirectorScript.GetDirectorOptions().SurvivorMaxIncapacitatedCount;

	player.SetReviveCount(maxIncap);
}

function BotAI::getIsMelee(player)
{
	weaponN <- player.GetActiveWeapon();

	if(weaponN == null || !weaponN.IsValid())
		return false;

	wname <- weaponN.GetClassname();

	if(wname == "weapon_chainsaw" || wname == "weapon_melee")
		return true;
	return false;
}

function BotAI::SetTarget(_ent, _target) {
	if(!BotAI.IsEntityValid(_target)) return;
	_ent.__KeyValueFromString("target", _target.tostring());

	if(_ent.GetClassname() == "infected" || _ent.GetClassname() == "witch") {
		NetProps.SetPropEntity(_ent, "m_clientLookatTarget", _target);
	}

	if(_ent.GetClassname() == "player" && !IsPlayerABot(_ent))
		return;

	BotAI.hookViewEntity(_ent, _target);
	if(BotAI.BotDebugMode) {
		printl("[Attack] " + BotAI.getPlayerBaseName(_ent));
	}
	CommandABot( { cmd = 0, target = _target, bot = _ent } );

	BotAI.botAim[_ent] <- _target;
	BotAI.lookAtEntity(_ent, _target);
}

function BotAI::IsTarget(_ent, target)
{
	if(!BotAI.IsEntityValid(_ent)) return;
	if(BotAI.GetTarget(target) != null && BotAI.GetTarget(target).GetEntityIndex() == _ent.GetEntityIndex())
		return true;
	return false;
}

function BotAI::getBotLookAt(_ent) {
	if(_ent in BotAI.botLookAt)
		return BotAI.botLookAt[_ent];
	return null;
}

function BotAI::GetTarget(_ent) {
	if(!BotAI.IsEntityValid(_ent)) return;

	if(_ent in BotAI.botLookAt && BotAI.IsAlive(BotAI.botLookAt[_ent]))
		return BotAI.botLookAt[_ent];

	if(_ent in BotAI.botAim && BotAI.IsAlive(BotAI.botAim[_ent]))
		return BotAI.botAim[_ent];

	if(BotAI.IsPlayerEntityValid(_ent))
		return NetProps.GetPropEntity(_ent, "m_lookatPlayer");

	return NetProps.GetPropEntity(_ent, "m_clientLookatTarget");
}

::BotAI.IsTargetStaggering <- function(entity) {
	if(!BotAI.IsEntityValid(entity)) return false;
	local sequence = NetProps.GetPropInt(entity, "m_nSequence");

	return (IsEntitySI(entity) &&
	((entity.GetZombieType() == 5 && sequence >= 15 && sequence <= 18) ||
	(entity.GetZombieType() == 3 && sequence >= 45 && sequence <= 49) ||
	(entity.GetZombieType() == 1 && sequence == 39) ||
	(entity.GetZombieType() == 4 && sequence == 17) ||
	(entity.GetZombieType() == 6 && sequence >= 38 && sequence <= 42)
	)
	)
	|| BotAI.IsInfectedBeShoved(entity);
}

::BotAI.IsInfectedBeShoved <- function(infected) {
	return BotAI.IsEntityValid(infected) && BotAI.IsAlive(infected) && infected.GetClassname() == "infected" && infected.GetSequence() >= 120;
}

function BotAI::shoveCommon(infected) {
	if(!BotAI.IsAlive(infected)) return;
	if(infected.GetSequence() >= 122 && infected.GetSequence() <= 134)
		infected.ResetSequence(infected.GetSequence());
	else {
		local sequences = [
			122
			123
			124
			125
			126
			127
			128
			129
			130
			131
			132
			133
			134
		];

		infected.SetSequence(sequences[RandomInt(0, 12)]);
	}
}

function BotAI::isPlayerFall(player) {
	if(!BotAI.IsEntityValid(player) || !BotAI.IsAlive(player))
		return false;
	return player.IsDominatedBySpecialInfected() || player.IsStaggering() || player.IsIncapacitated() || player.IsHangingFromLedge();
}

::BotAI.IsPlayerClimb <- function(player) {
	if(!BotAI.IsEntityValid(player) || !BotAI.IsAlive(player))
		return false;

	local PlayerState = NetProps.GetPropInt(player, "m_nSequence");
	local onLadder = NetProps.GetPropInt(player, "movetype") == MOVETYPE_LADDER;
	return PlayerState == 610 || PlayerState == 611 || onLadder;
}

function BotAI::isPlayerNearLadder(player) {
	if(!BotAI.IsEntityValid(player) || !BotAI.IsAlive(player))
		return false;

	foreach(ladder in BotAI.ladders) {
		//if(ladder.IsInUse(player))
			//return true;
		if(BotAI.distanceof(player.GetOrigin(), ladder.GetBottomOrigin()) < 200)
			return true;
		if(BotAI.distanceof(player.GetOrigin(), ladder.GetTopOrigin()) < 200)
			return true;
	}

	return false;
}

function BotAI::BotAttack(boto, otherEntity) {
	if(!BotAI.IsEntityValid(boto)) return;
	if(!BotAI.IsEntityValid(otherEntity) || (!BotAI.IsAlive(otherEntity) && otherEntity.GetClassname() != "tank_rock") || !IsPlayerABot(boto))
		return;

	if(BotAI.IsPlayerClimb(boto) || BotAI.IsBotHealing(boto))
		return;

	if(BotAI.HasItem(boto, BotAI.BotsNeedToFind) && BotAI.UseTargetOri != null && BotAI.distanceof(boto.GetOrigin(), BotAI.UseTargetOri) < 150 && otherEntity.GetClassname() != "player")
		return;

	BotAI.setBotMoveCooldown(boto, Time());
	BotAI.SetTarget(boto, otherEntity);
	return true;
}

function BotAI::BotReset(boto) {
	if(!BotAI.IsEntityValid(boto)) return;
	if(!IsPlayerABot(boto))
		return;

	if(BotAI.BotDebugMode) {
		printl("[Reset] " + BotAI.getPlayerBaseName(boto));
	}

	NetProps.SetPropFloat(boto, "m_flLaggedMovementValue", 1.0);
	return CommandABot( { cmd = 3, bot = boto } );
}

function BotAI::BotRetreatFrom(boto, otherEntity) {
	if(!BotAI.IsEntityValid(boto) || !BotAI.IsEntityValid(otherEntity)) return;
	if(!IsPlayerABot(boto))
		return;

	if(BotAI.IsPlayerClimb(boto))
		return;

	if(BotAI.BotDebugMode) {
		printl("[Retreat] " + BotAI.getPlayerBaseName(boto));
	}
	return CommandABot( { cmd = 2, target = otherEntity, bot = boto } );
}

function BotAI::botCmdMove(boto, vector) {
	if(!BotAI.IsEntityValid(boto)) return;
	if(!IsPlayerABot(boto))
		return;

	if (Time() - BotAI.getBotMoveCooldown(boto) < 1.25) {
		if(BotAI.BotDebugMode) {
			printl("[Move Fail] " + BotAI.getPlayerBaseName(boto));
		}
		return;
	}

	if(BotAI.BotDebugMode) {
		printl("[Move] " + BotAI.getPlayerBaseName(boto));
	}

	return CommandABot({ cmd = 1, pos = vector, bot = boto});
}

function BotAI::setMoveType(player, moveType) {
	if(!BotAI.IsEntityValid(player)) return;
	NetProps.SetPropInt(player, "movetype", moveType);
}

function BotAI::getMoveType(player) {
	if(!BotAI.IsEntityValid(player)) return;
	return NetProps.GetPropInt(player, "movetype");
}

function BotAI::areaAdjacent(area, i) {
	local adjacentAreas = {};
	area.GetAdjacentAreas(i, adjacentAreas);
	//BotAI.areaCache[key] <- adjacentAreas;
	return adjacentAreas;

	local key = area.GetID().tostring() + ":" + i.tostring();
	if(key in BotAI.areaCache) {
		return BotAI.areaCache[key];
	} else {

	}
}

function BotAI::isEntityEqual(entity, _entity) {
	if(entity == _entity) return true;

	if(BotAI.validVector(entity) && BotAI.validVector(_entity)) {
		if(entity.x == _entity.x && entity.y == _entity.y && entity.z == _entity.z)
			return true;
	}

	return false;
}

function BotAI::botStayPos(player, pos, id, priority = 4, stayTime = 3, distance = 100) {
	local littleBot = player;
	local dis = distance;
	local idStay = id + "Stay#";
	local stay = stayTime;

		/*

	local position_ = Vector(0, 0, 0);
	if(typeof pos == "Vector")
		position_ = pos;
	else
		position_ = pos.GetOrigin();

	BotAI.botCmdMove(player, position_);
	DebugDrawCircle(position_, Vector(0, 0, 255), 1.0, 5, true, 15.0);
	DebugDrawText(position_, "goal_RunPos", false, 15.0);
	return;
		*/

	local function changeAndStay() {
		if(!BotAI.IsAlive(littleBot)) return true;
		if(typeof pos != "Vector" && !BotAI.IsAlive(pos)) return true;
		local navigator = BotAI.getNavigator(littleBot);
		local position = Vector(0, 0, 0);
		if(typeof pos == "Vector")
			position = pos;
		else
			position = pos.GetOrigin();
		if(BotAI.distanceof(position, littleBot.GetOrigin()) <= dis) {
			navigator.clearPath(id);
			local timeGet = Time();
			local function tryStay() {
				if(Time() - timeGet > stay)
					return true;
				return false;
			}
			BotAI.botRunPos(littleBot, pos, idStay, priority, tryStay);
		}
		return false;
	}

	if(BotAI.botRunPos(player, pos, id, priority, changeAndStay)) {
		local position = Vector(0, 0, 0);
		if(typeof pos == "Vector")
			position = pos;
		else
			position = pos.GetOrigin();
		DebugDrawCircle(position, Vector(255, 0, 255), 0.2, 20, false, 2);
		DebugDrawCircle(position, Vector(255, 0, 255), 0.4, 16, false, 2.5);
		DebugDrawCircle(position, Vector(255, 0, 255), 0.6, 13, false, 3);
		DebugDrawCircle(position, Vector(255, 0, 255), 0.8, 10, false, 3.5);
		DebugDrawCircle(position, Vector(255, 0, 255), 1.0, 7, false, 4);
		return true;
	}

	return false;
}

function BotAI::botRunPos(player, pos, id, priority = 0, discardFunc = BotAI.trueDude, distance = 7000, buildTest = false) {
	if(!buildTest && !IsPlayerABot(player))
		return false;

	if(BotAI.IsPlayerClimb(player) || BotAI.IsBotHealing(player))
		return false;

		/*

	local position_ = Vector(0, 0, 0);
	if(typeof pos == "Vector")
		position_ = pos;
	else
		position_ = pos.GetOrigin();

	BotAI.botCmdMove(player, position_);
	DebugDrawCircle(position_, Vector(0, 0, 255), 1.0, 5, true, 15.0);
	DebugDrawText(position_, "goal_RunPos", false, 15.0);
	return;
		*/

	local navigator = BotAI.getNavigator(player);
	foreach(idx, path in navigator.pathCache) {
		if(idx == id && BotAI.isEntityEqual(path.pos, pos)) {
			navigator.run(id);
			return true;
		}
	}

	foreach(idx, path in navigator.seachingPath) {
		if(idx == id && BotAI.isEntityEqual(path.dataGoal, pos)) {
			return false;
		}
	}

	if(discardFunc == "change") {
		local function change() {
			local navigator = BotAI.getNavigator(player);
			if(!navigator.isMoving(id))
				return true;
			return false;
		}
		discardFunc = change;
	}

	if(navigator.buildPath(pos, id, priority, discardFunc, null, false, distance)) {
		navigator.run(id);
		return true;
	}

	return false;
}

function BotAI::SetButtonPressed(button)
{
	if(button.GetEntityIndex() in BotAI.ButtonPressed)
		BotAI.ButtonPressed[button.GetEntityIndex()] <- BotAI.ButtonPressed[button.GetEntityIndex()] + 1;
	else
		BotAI.ButtonPressed[button.GetEntityIndex()] <- 1;
}

function BotAI::IsButtonPressed(button)
{
	if(button.GetEntityIndex() in BotAI.ButtonPressed)
	{
		if(button.GetClassname() == "func_button")
		{
			local count = BotAI.ButtonPressed[button.GetEntityIndex()];
			if(count < 1)
				count = 1;
			local num = RandomInt(0, count * 2);

			if(num == 0)
				return false;
			else
				return true;
		}
		else
		{
			local num = RandomInt(0, 3);

			if(num == 0)
				return false;
			else
				return true;
		}
	}
	else
		return false;
}

function BotAI::getPlayerTotalHealth(player) {
	return player.GetHealth() + player.GetHealthBuffer();
}

::BotAI.SetPlayerReviving <- function(player, boolean)
{
	if(!BotAI.IsEntityValid(player)) return;
	BotAI.NeedRevive[player.GetEntityIndex()] <- boolean;
}

::BotAI.IsPlayerReviving <- function (player)
{
	if(!BotAI.IsEntityValid(player)) return false;
	return player.GetEntityIndex() in BotAI.NeedRevive && BotAI.NeedRevive[player.GetEntityIndex()];
}

::BotAI.SetPlayerRevived <- function(player, another)
{
	BotAI.RevivedPlayer[player.GetEntityIndex()] <- another;
}

::BotAI.getPlayerRevived <- function (player)
{
	if(player.GetEntityIndex() in BotAI.RevivedPlayer)
		return BotAI.RevivedPlayer[player.GetEntityIndex()];
	return null;
}

function BotAI::SetPlayerTarget(player, target)
{
	BotAI.TargetFind[player.GetEntityIndex()] <- target;
}

function BotAI::GetPlayerTarget(player)
{
	if(player.GetEntityIndex() in BotAI.TargetFind && BotAI.TargetFind[player.GetEntityIndex()] != null && BotAI.IsAlive(BotAI.TargetFind[player.GetEntityIndex()]))
		return BotAI.TargetFind[player.GetEntityIndex()];
	return null;
}