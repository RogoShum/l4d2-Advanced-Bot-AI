class ::AITaskSearchTrigger extends AITaskGroup {
	constructor(orderIn, tickIn, compatibleIn, forceIn) {
        base.constructor(orderIn, tickIn, compatibleIn, forceIn);
    }

	updating = false;
	playerList = {};
	triggerLinks = {};
	triggerEnabled = {};

	function preCheck() {
		if(BotAI.SurvivorList.len() > BotAI.SurvivorBotList.len())
			return false;

		local triggerChecked = {};

		foreach(idx, value in BotAI.TriggerList) {
			local trigger = EntIndexToHScript(idx);

			if(BotAI.IsTriggerUsable(trigger))
				triggerChecked[triggerChecked.len()] <- trigger;
		}

		triggerEnabled = triggerChecked;

		if(triggerEnabled.len() > 0)
			return true;

		return false;
	}

	function GroupUpdateChecker(player) {
		local dis = 8000;
		local cloest = null;

		foreach(trigger in triggerEnabled)
		{
			if(trigger in triggerLinks)
				continue;

			local disToTrigger = BotAI.distanceof(player.GetOrigin(), trigger.GetOrigin());

			if(disToTrigger < dis)
			{
				dis = disToTrigger;
				cloest = trigger;
			}
		}

		if(cloest != null)
		{
			triggerLinks[cloest] <- player
			printl("[Bot AI] Found " + cloest.GetClassname() + " named: " + cloest.GetName() + "[" + cloest.GetEntityIndex() + "]");
			return true;
		}

		return false;
	}

	function playerUpdate(player) {
		if(!BotAI.IsPlayerEntityValid(player)) return;

		foreach(trigger, link in triggerLinks)
		{
			if(!BotAI.IsEntityValid(link))
			{
				delete triggerLinks[trigger];
				continue;
			}

			if(!BotAI.IsTriggerUsable(trigger))
			{
				delete triggerLinks[trigger];
				BotAI.setBotLockTheard(link, -1);
				continue;
			}

			if(link != player) continue;
			local needFind = trigger;
			local hasGlow = false;
			local glow = NetProps.GetPropEntity(trigger, "m_glowEntity");
			if(BotAI.IsEntityValid(glow)) {
				hasGlow = true;
				needFind = glow;
			}
			if(BotAI.distanceof(player.GetOrigin(), needFind.GetOrigin()) > 150) {
				local navigator = BotAI.getNavigator(player);
				if(!navigator.hasPath("searchTrigger")) {
					local tr = trigger
					local function needTrigger() {
						return !BotAI.IsTriggerUsable(tr);
					}
					local glow = NetProps.GetPropEntity(trigger, "m_glowEntity");
					if(BotAI.IsEntityValid(glow))
						BotAI.botRunPos(player, glow, "searchTrigger", 1, needTrigger);
					else
						BotAI.botRunPos(player, trigger, "searchTrigger", 1, needTrigger);
				}

				if(BotAI.BotDebugMode)
					printl("[Bot AI] Trying go to " + trigger.GetClassname() + " named: " + trigger.GetName() + "[" + trigger.GetEntityIndex() + "]");
			} else if(!BotAI.IsPressingUse(player)) {
				if(trigger.GetClassname() == "func_button_timed")
					trigger.__KeyValueFromInt("use_time", -1);

				BotAI.SetTarget(player, needFind);
				BotAI.lookAtEntity(player, needFind);

				DoEntFire("!self", "Use", "", 0, player, needFind);
				BotAI.ForceButton(player, 32 , 1);
				BotAI.SetButtonPressed(trigger);

				printl("[Bot AI] Try Trigger  " + trigger.GetName());
				BotAI.setBotLockTheard(player, -1);
			}
		}

		if(triggerLinks.len() <= 0)
			updating = false;
	}

	function taskReset(player = null)
	{
		base.taskReset(player);
	}
}