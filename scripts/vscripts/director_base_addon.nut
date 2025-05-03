// Include the Advanced Bot AI
if ("AdvancedBotAI" in getroottable()) {
    ::AdvancedBotAI = 1;
} else {
    ::AdvancedBotAI <- 0;
}

IncludeScript( "AIUpdateHandler" );