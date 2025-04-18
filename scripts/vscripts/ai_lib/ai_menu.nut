::HoloMenu <- {
    menu = {}
    pressButton = {}
    iconHook = {}
}

//func(player, functionTable) return table
function HoloMenu::IconHook(menu, func) {
    iconHook[menu] <- func;
}

function HoloMenu::press(player, button) {
    if(!(button in HoloMenu.pressButton[player]))
        HoloMenu.pressButton[player][button] <- 0;
    local tick = HoloMenu.pressButton[player][button];
    HoloMenu.pressButton[player][button] <- tick + 1;
}

function HoloMenu::unPress(player, button) {
    HoloMenu.pressButton[player][button] <- -1;
}

function HoloMenu::getPressingTick(player, button) {
    if(button in HoloMenu.pressButton[player])
        return HoloMenu.pressButton[player][button];
   return -1;
}

function HoloMenu::update(player) {
    if(!(player in HoloMenu.pressButton))
        HoloMenu.pressButton[player] <- {};
    local doFunc = false;

    if((player.GetButtonMask() & 1) > 0)
        HoloMenu.press(player, 1);
    else {
        if(HoloMenu.getPressingTick(player, 1) > 0)
            doFunc = true;
        HoloMenu.unPress(player, 1);
    }

    foreach(menu in HoloMenu.menu) {
        if(menu.button != null) {
            if((player.GetButtonMask() & (menu.button)) > 0) {
                HoloMenu.press(player, menu.button);
                menu.tick(HoloMenu.getPressingTick(player, menu.button), player);
            } else {
                if(HoloMenu.getPressingTick(player, menu.button) > 0)
                    menu.press(player);
                HoloMenu.unPress(player, menu.button);
            }
        }

        menu.update(player);
        if(doFunc)
            menu.doFunction(player);
    }
}

function HoloMenu::TickMenu() {
    foreach(player in BotAI.SurvivorHumanList) {
            HoloMenu.update(player);
    }
    return 0.01;
}

local menuThinker = SpawnEntityFromTable("info_target", { targetname = "botai_menu"});
if (menuThinker != null) {
	menuThinker.ValidateScriptScope();
	local scrScope = menuThinker.GetScriptScope();
	scrScope["ThinkTimer"] <- HoloMenu.TickMenu;
	AddThinkToEnt(menuThinker, "ThinkTimer");
}

class ::HoloMenu.Menu {
	button = null;
    menuName = "none";
	pressEvent = []
    tickEvent = {}
    display = {}
    functions = {}
    icons = {}
    menuCenter = {}
    impact = {}

	constructor(nameIn, buttonIn) {
		button = buttonIn;
        menuName = nameIn;
        HoloMenu.menu[menuName] <- this;
        pressEvent = []
        tickEvent = {}
        display = {}
        functions = {}
        icons = {}
        menuCenter = {}
        impact = {}
	}

    function _typeof() {
		return "holoMenu";
	}

    //func(player)
    function registerFunction(name, func) {
        functions[name] <- func;
    }

    function doFunction(player) {
        if(player in impact)
            functions[impact[player]](player);
    }

    function registerPressEvent(func) {
        pressEvent.append(func);
    }

    function registerTickEvent(tick, func) {
        tickEvent[tick] <- func;
    }

    function press(player) {
        foreach(func in pressEvent) {
            func(player);
        }
    }

    function tick(tick, player) {
        if(tick in tickEvent) {
            tickEvent[tick](player);
        }
    }

    function getFilteredFunction(player) {
        local functionTable = functions;
        if(menuName in HoloMenu.iconHook) {
            functionTable = HoloMenu.iconHook[menuName](player, functions);
        }
        return functionTable;
    }

    function show(player) {
        if(!Director.IsSinglePlayerGame() && GetListenServerHost() != player) {
            BotAI.SendPlayer(player, "botai_no_holomenu");
        }
        display[player] <- true;
        local _icons = [];
        local forward = player.EyeAngles().Forward();
        local center = player.EyePosition() + forward.Scale(60);
        menuCenter[player] <- center;
        local functionTable = getFilteredFunction(player);
        local size = functionTable.len();
        local angleValue = 360.0 / size;
        local count = 0;
        local yawAngle = player.EyeAngles().Yaw() + 90;
        local scale = size * 1.2;
        if(scale < 8)
            scale = 8;
        //local offset = (player.EyePosition() + forward) - center;
        foreach(name, func in functionTable) {
            local pos = center + QAngle(-90 - angleValue * count, yawAngle).Forward().Scale(scale);
            //local rollOffset = offset.Scale((pos - center).Length() / scale);
            //pos += rollOffset;
            _icons.append(HoloMenu.Icon(name, pos, forward));
            count++;
        }
        icons = _icons;
    }

    function showing(player) {
        if(!(player in display)) return false;
        return display[player];
    }

    function close(player) {
        display[player] <- false;
        if(player in icons)
            delete icons[player];
        if(player in impact)
            delete impact[player];
    }

    function update(player) {
        if(!(player in display) || !display[player]) return;
        local impactIcon = null;
        local dot = -1;
        foreach(name, icon in icons) {
            local iconDot = player.EyeAngles().Forward().Dot(BotAI.normalize(icon.pos - player.EyePosition()));

            if(iconDot > 0.995 && iconDot > dot) {
                dot = iconDot;
                impactIcon = icon;
            }
        }

        if(typeof impactIcon == "holoIcon")
            impact[player] <- impactIcon.name;
        else if(player in impact)
            delete impact[player];

        local left = player.EyeAngles().Left().Scale(-1);
        local title = I18n.getTranslationKeyByLang(BotAI.language, menuName);
        local center = null;
        foreach(icon in icons) {
            local scale = 2.5;
            local rgb = Vector(0, 150, 0);
            local string = I18n.getTranslationKeyByLang(BotAI.language, icon.name);
            local leftFactor = string.len() / 7;
            if(icon == impactIcon) {
                rgb = Vector(100, 255, 0);
                scale = 3.2;
            }

            DebugDrawBoxDirection(icon.pos, Vector(-scale, -scale, -scale), Vector(scale, scale, scale), icon.forward, rgb, 1.0, 0.1);
            DebugDrawText(icon.pos + left.Scale(leftFactor), string, true, 0.1);
            if(center == null)
                center = icon.pos;
            else {
                center = (center + icon.pos).Scale(0.5);
            }
        }

        DebugDrawText(menuCenter[player] + left.Scale(title.len() / 7), title, true, 0.1);
    }
}

class ::HoloMenu.Icon {

    pos = Vector(0, 0, 0)
    forward = Vector(0, 0, 0)
    name = "";

    constructor(nameIn, posIn, forwardIn) {
        name = nameIn
        pos = posIn
        forward = forwardIn
    }

    function _typeof() {
		return "holoIcon";
	}
}

local _vguiBaseRes = { width = 640, height = 480 };

/*
remove title
*/
class ::HoloMenu.KeyBindMenu extends ::VSLib.HUD.Menu {
    _skipOptions = 0;
	///////////////////////////////////////////////////////////////////
	// Meta stuff
	///////////////////////////////////////////////////////////////////
	constructor(formatStr = "[ {name} ]\n\n{options}", skipOptions = 0, optionFormatStr = "{num}. {option}", highlightStrPre = "", highlightStrPost = "", sticky = false) {
		SetFormatString(formatStr);
		_oformat = optionFormatStr;
		_hpre = highlightStrPre;
        _skipOptions = skipOptions;
		_hpost = highlightStrPost;
		_title = "";
		_options = {};
		_numop = 0;
		_curSel = 0;
		_sticky = false; // #shotgunefx

		::VSLib.Timers.RemoveTimer(_optimer);
		_optimer = -1;
        _manual = true
	}

	function GetString() {
		if (_player == null || _numop <= 0)
			return "";

		// Build the options list
		local optionsList = "";
        for(local i = 0; i < _skipOptions; ++i) {
            optionsList += "\n";
        }

		foreach (idx, row in _options)
		{
			local disp = "";
			if (idx == _curSel)
				disp += _hpre;
			disp += _oformat;
            if(row.text.find("emp_") == null) {
                local num = idx+_skipOptions;
                if(num == 10)
                    num = 0;
                disp = ::VSLib.Utils.StringReplace(disp, "{num}", num.tostring());
                disp = ::VSLib.Utils.StringReplace(disp, "{option}", row.text);
            } else {
                disp = ::VSLib.Utils.StringReplace(disp, "{num}.", "");
                disp = ::VSLib.Utils.StringReplace(disp, "{option}", "");
            }

			disp = ParseString(disp);
			if (idx == _curSel)
				disp += _hpost;
			optionsList += disp + "\n";
		}

		// Build return string
		if (_modded || _dynrefcount > 0)
		{
			_modded = false;
			_cachestr = _formatstr;
			_cachestr = ParseString(_cachestr);
		}
        local temp = _cachestr;
		temp = ::VSLib.Utils.StringReplace(temp, "{name}", _player.GetName());
		temp = ::VSLib.Utils.StringReplace(temp, "{title}", _title);
		temp = ::VSLib.Utils.StringReplace(temp, "{options}", optionsList);

		return temp;
    }

    function ResizeHeightByLines() {
		local lines = split(GetString(), "\n").len() + 1;
		local baseh = _vguiBaseRes.height.tofloat();

		SetHeight( ((28 * lines)/(480/baseh))/baseh);
	}
}