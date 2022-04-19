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
			
			if(IsTriggerUsable(trigger))
				triggerChecked[triggerChecked.len()] <- trigger;
		}
		
		triggerEnabled = triggerChecked;
		
		if(triggerEnabled.len() > 0)
			return true;
		
		return false;
	}
	
	function IsTriggerUsable(trigger) {
		if(BotAI.IsEntityValid(trigger)) {
			local m_usable = NetProps.GetPropInt(trigger, "m_usable");
				
			if(trigger.GetClassname() == "func_button")
			{
				local glowEntity = NetProps.GetPropEntity(trigger, "m_glowEntity");

				if (m_usable == 1 && BotAI.IsEntityValid(glowEntity))
					return true;
			}
			else if(trigger.GetClassname() == "func_button_timed")
			{
				if (m_usable == 1 && !BotAI.IsButtonPressed(trigger))
					return true;
			}
			else if(trigger.GetClassname() == "trigger_finale")
			{
				if(!BotAI.FinaleStart && !BotAI.IsButtonPressed(trigger))
					return true;
			}
		}
		
		return false;
	}
	
	function GroupUpdateChecker(player)
	{
		if(BotAI.IsInCombat(player) || BotAI.IsPressingAttack(player) || BotAI.IsPressingUse(player) || BotAI.IsPressingShove(player) || BotAI.IsBotGasFinding(player))
			return false;
		
		local dis = 3500;
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
	
	function playerUpdate(player)
	{
		if(!BotAI.IsPlayerEntityValid(player)) return;
		
		if(BotAI.IsInCombat(player) && BotAI.IsBotGasFinding(player))
		{
			BotAI.BotReset(player);
			return;
		}
		
		if(BotAI.IsInCombat(player) || BotAI.IsPressingAttack(player) || BotAI.IsPressingShove(player))
			return;
		
		foreach(trigger, link in triggerLinks)
		{
			if(!BotAI.IsEntityValid(link))
			{
				delete triggerLinks[trigger];
				continue;
			}
			
			if(!IsTriggerUsable(trigger))
			{
				delete triggerLinks[trigger];
				BotAI.setBotLockTheard(link, -1);
				continue;
			}
			
			if(link != player) continue;

			if(BotAI.distanceof(player.GetOrigin(), trigger.GetOrigin()) > 100)
			{
				if(!BotAI.IsBotGasFinding(player)) {
					BotAI.BotMove(player, trigger, 2);
					if(BotAI.BOT_AI_TEST_MOD == 1)
						printl("[Bot AI] Trying go to " + trigger.GetClassname() + " named: " + trigger.GetName() + "[" + trigger.GetEntityIndex() + "]");
				}
			}
			else if(!BotAI.IsPressingUse(player))
			{
				if(trigger.GetClassname() == "func_button_timed")
					trigger.__KeyValueFromInt("use_time", -1);

				BotAI.lookAtEntity(player, trigger);
				BotAI.hookViewEntity(player, trigger);
				DoEntFire("!self", "Use", "", 0, player, trigger);
				BotAI.ForceButton(player, 32 , 1);
				BotAI.SetButtonPressed(trigger);
				
				printl("[Bot AI] Try Trigger  " + trigger.GetName());				
				if(BotAI.IsBotGasFinding(player))
					BotAI.BotReset(player);
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