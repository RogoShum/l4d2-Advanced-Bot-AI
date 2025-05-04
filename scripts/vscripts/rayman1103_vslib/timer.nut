/*
 * Copyright (c) 2013 LuKeM aka Neil - 119 and Rayman1103
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy of this software
 * and associated documentation files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all copies or
 * substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING
 * BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
 * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 */


/**
 * \brief A timer system to call a function after a certain amount of time.
 *
 *  The Timer table allows the developer to easily add synchronized callbacks.
 */
	::BotAI.Timers <-
	{
		TimersList = {}
		TimersID = {}
		ClockList = {}
		count = 0
	}

/*
 * Constants
 */

// Passable constants
getconsttable()["NO_TIMER_PARAMS"] <- null; /** No timer params */

// Flags
getconsttable()["TIMER_FLAG_KEEPALIVE"] <- (1 << 1); /** Keep timer alive even after RoundEnd is called */
getconsttable()["TIMER_FLAG_COUNTDOWN"] <- (1 << 2); /** Fire the timer the specified number of times before the timer removes itself */
getconsttable()["TIMER_FLAG_DURATION"] <- (1 << 3); /** Fire the timer each interval for the specified duration */
getconsttable()["TIMER_FLAG_DURATION_VARIANT"] <- (1 << 4); /** Fire the timer each interval for the specified duration, regardless of internal function call time loss */


/**
 * Creates a named timer that will be added to the timers list. If a named timer already exists,
 * it will be replaced.
 *
 * @return Name of the created timer
 */
function BotAI::Timers::AddTimerByName(strName, delay, repeat, func, paramTable = null, flags = 0, value = {})
{
	::BotAI.Timers.RemoveTimerByName(strName);
	::BotAI.Timers.TimersID[strName] <- ::BotAI.Timers.AddTimer(delay, repeat, func, paramTable, flags, value);
	return strName;
}

/**
 * Deletes a named timer.
 */
function BotAI::Timers::RemoveTimerByName(strName) {
	if (strName in ::BotAI.Timers.TimersID) {
		::BotAI.Timers.RemoveTimer(::BotAI.Timers.TimersID[strName]);
		delete ::BotAI.Timers.TimersID[strName];
	}
}

/**
 * Calls a function and passes the specified table to the callback after the specified delay.
 */
function BotAI::Timers::AddTimer(delay, repeat, func, paramTable = null, flags = 0, value = {})
{
	local TIMER_FLAG_COUNTDOWN = (1 << 2);
	local TIMER_FLAG_DURATION = (1 << 3);
	local TIMER_FLAG_DURATION_VARIANT = (1 << 4);

	delay = delay.tofloat();
	repeat = repeat.tointeger();

	local rep = (repeat > 0) ? true : false;

	if (delay < 0)
	{
		printl("BotAI Warning: Timer delay cannot be less than 0 second(s). Delay has been reset to 0.");
		delay = 0;
	}

	if (paramTable == null)
		paramTable = {};

	if (typeof value != "table")
	{
		printl("BotAI Timer Error: Illegal parameter: 'value' parameter needs to be a table.");
		return -1;
	}
	else if (flags & TIMER_FLAG_COUNTDOWN && !("count" in value))
	{
		printl("BotAI Timer Error: Could not create the countdown timer because the 'count' field is missing from 'value'.");
		return -1;
	}
	else if ((flags & TIMER_FLAG_DURATION || flags & TIMER_FLAG_DURATION_VARIANT) && !("duration" in value))
	{
		printl("BotAI Timer Error: Could not create the duration timer because the 'duration' field is missing from 'value'.");
		return -1;
	}

	// Convert the flag into countdown
	if (flags & TIMER_FLAG_DURATION)
	{
		flags = flags & ~TIMER_FLAG_DURATION;
		flags = flags | TIMER_FLAG_COUNTDOWN;

		value["count"] <- floor(value["duration"].tofloat() / delay);
	}

	++count;
	TimersList[count] <-
	{
		_delay = delay
		_func = func
		_params = paramTable
		_startTime = Time()
		_baseTime = Time()
		_repeat = rep
		_flags = flags
		_opval = value
	}

	return count;
}

/**
 * Removes the specified timer.
 */
function BotAI::Timers::RemoveTimer(idx)
{
	if (idx in TimersList)
		delete ::BotAI.Timers.TimersList[idx];
}

/**
 * Manages BotAI timers.
 */
function BotAI::Timers::ManageTimer(idx, command, value = null, allowNegTimer = false)
{
	if ( idx in ::BotAI.Timers.ClockList && value == null )
	{
		::BotAI.Timers.ClockList[idx]._command <- command;
		::BotAI.Timers.ClockList[idx]._allowNegTimer <- allowNegTimer;
	}
	else
	{
		if ( value == null )
			value = 0;

		::BotAI.Timers.ClockList[idx] <-
		{
			_value = value
			_startTime = Time()
			_lastUpdateTime = Time()
			_command = command
			_allowNegTimer = allowNegTimer
		}
	}
}

/**
 * Returns the value of a BotAI timer.
 */
function BotAI::Timers::ReadTimer(idx)
{
	if ( idx in ::BotAI.Timers.ClockList )
		return ::BotAI.Timers.ClockList[idx]._value;

	return null;
}

/**
 * Returns a BotAI timer as a displayable string --:--.
 */
function BotAI::Timers::DisplayTime(idx)
{
	return ::BotAI.Utils.GetDisplayTime(::BotAI.Timers.ReadTimer(idx));
}

/**
 * Manages all timers and provides interface for custom updates.
 */
::BotAI.Timers._thinkFunc <- function()
{
	if (!("BotAI" in getroottable()))
		return;

	local TIMER_FLAG_COUNTDOWN = (1 << 2);
	local TIMER_FLAG_DURATION_VARIANT = (1 << 4);

	// current time
	local curtime = Time();
	// Execute timers as needed

	// crashed

	foreach (idx, timer in ::BotAI.Timers.TimersList) {
		if ((curtime - timer._startTime) >= timer._delay) {
			if (timer._flags & TIMER_FLAG_COUNTDOWN) {
				timer._params["TimerCount"] <- timer._opval["count"];

				if ((--timer._opval["count"]) <= 0)
					timer._repeat = false;
			}

			if (timer._flags & TIMER_FLAG_DURATION_VARIANT && (curtime - timer._baseTime) > timer._opval["duration"]) {
				delete ::BotAI.Timers.TimersList[idx];
				continue;
			}

			if (timer._func(timer._params) == false)
				timer._repeat = false;
			try {

			}
			catch (id) {
				//if(BotAI.BOT_AI_TEST_MOD != 1) {
					//BotAI.EasyPrint("botai_report", 0.1);
					//BotAI.EasyPrint(id.tostring(), 0.2);

					//reAdd timer
					/*
					foreach(name, index in ::BotAI.Timers.TimersID) {
						if(index == idx) {
							local function reAddTimer(args) {
								if(args._name == "AITaskSystem")
									BotAI.resetAITask();

								BotAI.Timers.AddTimerByName(args._name, args._delay, args._repeat, args._func);
							}
							BotAI.Timers.AddTimerByName("reAddTimer " + UniqueString(), 1.0, false, reAddTimer,
							{_name = name, _delay = timer._delay, _repeat = timer._repeat, _func = timer._func});
						}
					}
					*/
				//}
				local deadFunc = timer._func;
				local params = timer._params;
				deadFunc(params); // this will most likely throw
				//BotAI.Timers.throwError(deadFunc, params);
				continue;
			}

			if (timer._repeat)
				timer._startTime = curtime;
			else
				if (idx in ::BotAI.Timers.TimersList) // recheck-- timer may have been removed by timer callback
					delete ::BotAI.Timers.TimersList[idx];
		}
	}
	foreach (idx, timer in ::BotAI.Timers.ClockList)
	{
		if ( Time() > timer._lastUpdateTime )
		{
			local newTime = Time() - timer._lastUpdateTime;

			if ( timer._command == 1 )
				timer._value += newTime;
			else if ( timer._command == 2 )
			{
				if ( timer._allowNegTimer )
					timer._value -= newTime;
				else
				{
					if ( timer._value > 0 )
						timer._value -= newTime;
				}
			}

			timer._lastUpdateTime <- Time();
		}
	}
}

function BotAI::Timers::throwError(func, params) {
	local errorThinker = SpawnEntityFromTable("info_target", { targetname = "botai_timer_throw" + UniqueString() });
	if (errorThinker != null) {
		errorThinker.ValidateScriptScope();
		local scrScope = errorThinker.GetScriptScope();
		local function thrower() {
			Msg(I18n.getTranslationKey("botai_exception_here"));
			Msg("\n");
			func(params);
		}
		scrScope["botai_think"] <- thrower;
		AddThinkToEnt(errorThinker, "botai_think");
		DoEntFire("!self", "Kill", "", 1, null, errorThinker);
	}
}

/*
 * Create a think timer
 */

 local infoTarget = null;
 while(infoTarget = Entities.FindByName(infoTarget, "botai_timer")) {
	infoTarget.Kill();
 }

 ::BotAI.Timers._thinkTimer <- SpawnEntityFromTable("info_target", { targetname = "botai_timer" });
 if (::BotAI.Timers._thinkTimer != null) {
	 ::BotAI.Timers._thinkTimer.ValidateScriptScope();
	 local scrScope = ::BotAI.Timers._thinkTimer.GetScriptScope();
	 scrScope["botai_think"] <- ::BotAI.Timers._thinkFunc;
	 AddThinkToEnt(::BotAI.Timers._thinkTimer, "botai_think");
 }
 else
	 throw "BotAI Error: Timer system could not be created; Could not create dummy entity";