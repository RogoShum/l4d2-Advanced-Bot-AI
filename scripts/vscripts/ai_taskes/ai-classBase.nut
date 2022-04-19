class ::AITask
{
	constructor(orderIn, tickIn, compatibleIn, forceIn)
    {
        order = orderIn;
        tick = tickIn;
		lastTickTime = 0;
		compatible = compatibleIn;
		force = forceIn;
    }
	
	order = 0;
	tick = 1;
	lastTickTime = 0;
	compatible = false;
	force = false;
	updating = null;
	single = false;
	name = "none";
	fillTick = false;
	reCheckUpdate = false;
	
	function setFillTick() {
		fillTick = true;
		return this;
	}
	
	function getOrder()
	{
		return order;
	}
	
	function shouldTick(player){}
	
	function getLastTickTime(player){}
	
	function setLastTickTime(player, tickTimeIn){}
	
	function isCompatible()
	{
		return compatible;
	}
	
	function isForce()
	{
		return force;
	}
	
	function isUpdating(player = null)
	{
		return updating;
	}
	
	//abstract
	function shouldUpdate(player = null) { return false; }
	
	//abstract
	function taskUpdate(player = null) {}
	
	//abstract
	function playerUpdate(player) {}
	
	//abstract
	function taskReset(player = null) { updating = false; }
}
