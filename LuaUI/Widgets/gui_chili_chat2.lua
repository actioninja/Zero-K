--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- TODO : test replay message formats (and change pattern matcher/parseCommand() to remove duplication in message definitions)
-- TODO : check that private (whisper) messages work as expected
-- TODO : check that simpleColors work as expected
-- TODO FIXME : when some messages are hidden... make sure we dont destroy too many stack_console control children
-- TODO : add message highlight options (never, only ally, all messages) + highlight format (currently surrounds message with #### in highlight color)
-- FIXME : fix (probable) bug while shrinking max_lines option

function widget:GetInfo()
  return {
    name      = "Chili Chat 2",
    desc      = "v0.808 Alternate Chili Chat Console.",
    author    = "CarRepairer, Licho, Shaun",
    date      = "2012-05-26",
    license   = "GNU GPL, v2 or later",
    layer     = 50,
    experimental = false,
    enabled   = false,
	detailsDefault = 1
  }
end

include("keysym.h.lua")

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--[[
each message definition can have:
	- either 1 format
	- either name + output, output containing pairs of { name = '', format = '' }
all the names are used when displaying the options

pattern syntax:
	see http://www.lua.org/manual/5.1/manual.html#5.4.1
	pattern must contain at least 1 capture group; its content will end up in msg.argument after parseMessage()
	PLAYERNAME will match anything that looks like a playername (see code for definition of PLAYERNAME_PATTERN); it is a capture group
	if message does not contain a PLAYERNAME, add 'noplayername = true' to definition
	it should be possible to add definitions to help debug widgets or whatever... (no guarantee)

format syntax:
- #x : switch to color 'x' where 'x' can be:
	- a : ally (option)
	- e : everyone (option)
	- o : other (option)
	- s : spec (option)
	- h : highlight (option)
	- p : color of the player who sent message (dynamic)
- $var : gets replaced by msg['var'] ; interesting vars:
	- playername
	- argument	for messages, this is only the message part; for labels, this is the caption
	- msgtype	type of message as identified by parseMessage()
	- priority	as received by widget:AddConsoleLine()
	- text		full message, as received by widget:AddConsoleLine()
--]]
local MESSAGE_DEFINITIONS = {
	{ msgtype = 'player_to_allies', pattern = '^<PLAYERNAME> Allies: (.*)', -- format = '#p<$playername> #a$argument',
		name = "Player to allies message",
		output = {
			{
				name = "Only bracket in player's color, message in 'ally' color",
				format = '#p<#e$playername#p> #a$argument'
			},
			{
				name = "Playername in his color, message in 'ally' color",
				format = '#p<$playername> #a$argument',
				default = true
			},
			{
				name = "Playername and message in player's color",
				format = '#p<$playername> $argument'
			},
		}
	},
	{ msgtype = 'player_to_player_received', pattern = '^<PLAYERNAME> Private: (.*)', format = '#p*$playername* $argument' }, -- TODO test!
	{ msgtype = 'player_to_player_sent', pattern = '^You whispered PLAYERNAME: (.*)', format = '#p -> *$playername* $argument' }, -- TODO test! NOTE: #p will be color of destination player!
	{ msgtype = 'player_to_specs', pattern = '^<PLAYERNAME> Spectators: (.*)', format = '#p<$playername> #s$argument' },
	{ msgtype = 'player_to_everyone', pattern = '^<PLAYERNAME> (.*)', format = '#p<$playername> #e$argument' },

	{ msgtype = 'spec_to_specs', pattern = '^%[PLAYERNAME%] Spectators: (.*)', format = '#s[$playername] $argument' },
	{ msgtype = 'spec_to_allies', pattern = '^%[PLAYERNAME%] Allies: (.*)', format = '#s[$playername] $argument' }, -- TODO is there a reason to differentiate spec_to_specs and spec_to_allies??
	{ msgtype = 'spec_to_everyone', pattern = '^%[PLAYERNAME%] (.*)', format = '#s[$playername] #e$argument' },

	-- shameful copy-paste -- TODO rewrite pattern matcher to remove this duplication
	{ msgtype = 'replay_spec_to_specs', pattern = '^%[PLAYERNAME %(replay%)%] Spectators: (.*)', format = '#s[$playername (replay)] $argument' },
	{ msgtype = 'replay_spec_to_allies', pattern = '^%[PLAYERNAME %(replay%)%] Allies: (.*)', format = '#s[$playername (replay)] $argument' }, -- TODO is there a reason to differentiate spec_to_specs and spec_to_allies??
	{ msgtype = 'replay_spec_to_everyone', pattern = '^%[PLAYERNAME %(replay%)%] (.*)', format = '#s[$playername (replay)] #e$argument' },

	{ msgtype = 'label', pattern = '^PLAYERNAME added point: (.+)', format = '#p *** $playername added label \'$argument\'' }, -- NOTE : these messages are ignored -- points and labels are provided through MapDrawCmd() callin
	{ msgtype = 'point', pattern = '^PLAYERNAME added point: ', format = '#p *** $playername added point' },
	{ msgtype = 'autohost', pattern = '^> (.+)', format = '#o> $argument', noplayername = true },
	{ msgtype = 'other', format = '#o$text' } -- no pattern... will match anything else
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local screen0
local myName -- my console name

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local MIN_HEIGHT = 150
local MIN_WIDTH = 300

local stack_console
local window_console
local scrollpanel1
local inputspace
WG.enteringText = false
WG.chat = WG.chat or {}

-- redefined in Initialize()
local function showConsole() end
local function hideConsole() end
WG.chat.hideConsole = hideConsole
WG.chat.showConsole = showConsole

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local incolor_dup
local incolor_highlight
local incolors = {} -- incolors indexed by playername + special #a/#e/#o/#s/#h colors based on config

local messages = {} -- message buffer
local highlightPattern -- currently based on player name -- TODO add configurable list of highlight patterns

local visible = true
local firstEnter = true --used to activate ally-chat at game start. To run once
local noAlly = false	--used to skip the ally-chat above. eg: if 1vs1 skip ally-chat

local wasSimpleColor = nil -- variable: indicate if simple color was toggled on or off. Used to trigger refresh.

----

options_path = "Settings/Interface/Chat/Console"
options_order = {
	'mousewheel', 'clickable_points', 'hideSpec', 'hideAlly', 'hidePoint', 'hideLabel', 'defaultAllyChat',
	'text_height', 'highlighted_text_height', 'max_lines',
	'color_background', 'color_chat', 'color_ally', 'color_other', 'color_spec', 'color_dup',
	'highlight_surround', 'highlight_sound', 'color_highlight'
}
		
options = {
--[[
	highlight_filter = {
		name = 'Highlight filter',
		type = 'list',
		OnChange = onOptionsChanged,
		value = 'allies',
		items = {
			{ key = 'disabled', name = "Disabled" },
			{ key = 'allies', name = "Highlight only allies messages" },
			{ key = 'all', name = "Highlight all messages" },
		},
		advanced = true,
	},
--]]
	text_height = {
		name = 'Text Size',
		type = 'number',
		value = 14,
		min = 8, max = 30, step = 1,
		OnChange = onOptionsChanged,
	},
	highlighted_text_height = {
		name = 'Highlighted Text Size',
		type = 'number',
		value = 18,
		min = 8, max = 30, step = 1,
		OnChange = onOptionsChanged,
	},
	clickable_points = {
		name = "Clickable points and labels",
		type = 'bool',
		value = true,
		OnChange = onOptionsChanged,
		advanced = true,
	},
	highlight_surround = {
		name = "Surround highlighted messages",
		type = 'bool',
		value = true,
		OnChange = onOptionsChanged,
		advanced = true,
	},
	highlight_sound = {
		name = "Sound highlight on your name",
		type = 'bool',
		value = true,
		OnChange = onOptionsChanged,
		advanced = true,
	},
	hideSpec = {
		name = "Hide Spectator Chat",
		type = 'bool',
		value = false,
		OnChange = onOptionsChanged,
		advanced = true,
	},
	hideAlly = {
		name = "Hide Ally Chat",
		type = 'bool',
		value = false,
		OnChange = onOptionsChanged,
		advanced = true,
	},
	hidePoint = {
		name = "Hide Points",
		type = 'bool',
		value = false,
		OnChange = onOptionsChanged,
		advanced = true,
	},
	hideLabel = {
		name = "Hide Labels",
		type = 'bool',
		value = false,
		OnChange = onOptionsChanged,
		advanced = true,
	},
	max_lines = {
		name = 'Maximum Lines (20-300)',
		type = 'number',
		value = 150,
		min = 20, max = 300, step = 1, 
		OnChange = onOptionsChanged,
	},
	
	color_chat = {
		name = 'Everyone chat text',
		type = 'colors',
		value = { 1, 1, 1, 1 },
		OnChange = onOptionsChanged,
	},
	color_ally = {
		name = 'Ally text',
		type = 'colors',
		value = { 0.2, 1, 0.2, 1 },
		OnChange = onOptionsChanged,
	},
	color_other = {
		name = 'Other text',
		type = 'colors',
		value = { 0.6, 0.6, 0.6, 1 },
		OnChange = onOptionsChanged,
	},
	color_spec = {
		name = 'Spectator text',
		type = 'colors',
		value = { 0.8, 0.8, 0.8, 1 },
		OnChange = onOptionsChanged,
	},
	color_dup = {
		name = 'Duplicate message mark',
		type = 'colors',
		value = { 1, 0.2, 0.2, 1 },
		OnChange = onOptionsChanged,
	},
	color_highlight = {
		name = 'Highlight mark',
		type = 'colors',
		value = { 1, 0.2, 0.2, 1 },
		OnChange = onOptionsChanged,
	},
	color_background = {
		name = "Background color",
		type = "colors",
		value = { 0, 0, 0, 0},
		OnChange = function(self) 
			scrollpanel1.backgroundColor = self.value
			scrollpanel1:Invalidate()
			inputspace.backgroundColor = self.value
			inputspace:Invalidate()
		end,
	},
	mousewheel = {
		name = "Scroll with mousewheel",
		type = 'bool',
		value = false,
		OnChange = function(self) scrollpanel1.noMouseWheel = not self.value; end,
	},
	defaultAllyChat = {
		name = "Default ally chat",
		desc = "Sets default chat mode to allies at game start",
		type = 'bool',
		value = true,
	},	
	
}

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function onOptionsChanged()
	RemakeConsole()
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- TODO : should these be moved to some shared file/library?

local function nocase(s)
  return string.gsub(s, "%a", function (c)
		return string.format("[%s%s]", string.lower(c), string.upper(c))
	  end
  )
end

local function escapePatternMatchChars(s)
  return string.gsub(s, "(%W)", "%%%1")
end

local function escapePatternReplacementChars(s)
  return string.gsub(s, "%%", "%%%%")
end

local function caseInsensitivePattern(s)
  return nocase(escapePatternMatchChars(s))
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- local PLAYERNAME_PATTERN = '[%%w%%[%%]_]+' -- doubled % as escape for gsub usage...
local PLAYERNAME_PATTERN = escapePatternReplacementChars('([%w%[%]_]+)')

function getMessageDefinitionOptionName(def, suboption)
  return def.msgtype .. "_" .. suboption
end

-- TODO move this to setup()?
local MESSAGE_DEFINITIONS_BY_TYPE = {} -- message definitions indexed by msgtype
for _,def in ipairs(MESSAGE_DEFINITIONS) do
	MESSAGE_DEFINITIONS_BY_TYPE[def.msgtype] = def
	if def.pattern then
		def.pattern = def.pattern:gsub('PLAYERNAME', PLAYERNAME_PATTERN) -- patch definition pattern so it is an actual lua pattern string
	end

	if def.output and def.name then -- if definition has multiple output formats, make associated config option
		local option_name = getMessageDefinitionOptionName(def, "output_format")
		options_order[#options_order + 1] = option_name
		local o = {
			name = "Message format for " .. def.name,
			type = 'list',
			OnChange = function (self)
				Spring.Echo('Selected: ' .. self.value)
				onOptionsChanged()
			end,
			value = '1', -- may be overriden
			items = {},
			advanced = true,
		}
		
		for i, output in ipairs(def.output) do
			o.items[i] = { key = i, name = output.name }
			if output.default then
				o.value = i
			end
		end
		options[option_name] = o
    end
end

local function getOutputFormat(msgtype)
  local def = MESSAGE_DEFINITIONS_BY_TYPE[msgtype]
  if def.output then
    local option_name = getMessageDefinitionOptionName(def, "output_format")
    local value = options[option_name].value
    return def.output[value].format
  else -- msgtype has only 1 format
	return def.format
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function setup()
	incolor_dup			= WG.Chili.color2incolor(options.color_dup.value)
	incolor_highlight	= WG.Chili.color2incolor(options.color_highlight.value)
	incolors['#h']		= incolor_highlight
	incolors['#a'] 		= WG.Chili.color2incolor(options.color_ally.value)
	incolors['#e'] 		= WG.Chili.color2incolor(options.color_chat.value)
	incolors['#o'] 		= WG.Chili.color2incolor(options.color_other.value)
	incolors['#s'] 		= WG.Chili.color2incolor(options.color_spec.value)
	
--	local myallyteamid = Spring.GetMyAllyTeamID()

	local playerroster = Spring.GetPlayerList()
	
	for i = 1, #playerroster do -- FIXME ipairs!?
		local name, _, spec, teamID = Spring.GetPlayerInfo(playerroster[i])
		incolors[name] = spec and incolors['#s'] or WG.Chili.color2incolor(Spring.GetTeamColor(teamID))
	end

	myName = Spring.GetPlayerInfo(Spring.GetMyPlayerID())
	highlightPattern = caseInsensitivePattern(myName)
end

-- update msg members msgtype, argument, playername (when relevant)
local function parseMessage(msg)
  for _, candidate in ipairs(MESSAGE_DEFINITIONS) do
    if candidate.pattern == nil then -- for fallback/other messages
      msg.msgtype = candidate.msgtype
      msg.argument = msg.text
      return
    end
    local capture1, capture2 = msg.text:match(candidate.pattern)
    if capture1 then
      msg.msgtype = candidate.msgtype
      if candidate.noplayername then
        msg.argument = capture1
		return
      elseif incolors[capture1] then -- check that a color is defined for this player in order to check that user exists... to avoid pitfalls such as <autoquit>
        msg.playername = capture1
        msg.argument = capture2
        return
      end
    end
  end
end

local function detectHighlight(msg)
	if (msg.argument and msg.argument:find(highlightPattern)) then
		msg.highlight = true
	end
end

local function formatMessage(msg)
--	local def = MESSAGE_DEFINITIONS_BY_TYPE[msg.msgtype]
--	local format = def.format
	local format = getOutputFormat(msg.msgtype)
	local formatted, _ = format:gsub('([#%$]%w+)', function(parameter) -- FIXME pattern too broad for 1-char color specifiers
			if parameter:sub(1,1) == '$' then
				return msg[parameter:sub(2,parameter:len())]
			elseif parameter == '#p' then
				if msg.playername and incolors[msg.playername] then
					return incolors[msg.playername]
				else
					return incolors['#o'] -- should not happen...
				end
			else
				return incolors[parameter]
			end
		end)
--[[
	-- FIXME ensure no "injection" is possible -- do it in one pass...
	local formatted, _ = format:gsub('%$(%w+)', msg)
	formatted, _ = formatted:gsub('#(%w)', function(color)
			if color == 'p' then
				return incolors[msg.playername]
			else
				return incolors['$'..color]
			end
		end)
--]]
	msg.formatted = formatted
end

local function displayMessage(msg, remake)
	if (msg.msgtype == "spec_to_everyone" and options.hideSpec.value) -- can only hide spec when playing
		or (msg.msgtype == "player_to_allies" and options.hideAlly.value)
		or (msg.msgtype == "point" and options.hidePoint.value)
		or (msg.msgtype == "label" and options.hideLabel.value)
	then
		return
	end

	-- TODO betterify this / make configurable
	local highlight_sequence = (msg.highlight and options.highlight_surround.value and (incolor_highlight .. ' #### ') or '')
	local text = (msg.dup > 1 and (incolor_dup .. msg.dup .. 'x ') or '') .. highlight_sequence .. msg.formatted .. highlight_sequence
	
	if (msg.dup > 1 and not remake) then
		local last = stack_console.children[#(stack_console.children)]
		if last then
			last:SetText(text)
			last:UpdateClientArea()
		end
	else
		local textbox = WG.Chili.TextBox:New{
			width = '100%',
			align = "left",
			fontsize = (msg.highlight and options.highlighted_text_height.value or options.text_height.value),
			valign = "ascender",
			lineSpacing = 0,
			padding = { 0, 0, 0, 0 },
			text = text,
			--fontShadow = true,
			--[[
			autoHeight=true,
			autoObeyLineHeight=true,
			--]]
		
			font = {
				outlineWidth = 3,
				outlineWeight = 10,
				outline = true
			}
		}
		
		if msg.point and options.clickable_points.value then
			textbox.OnMouseDown = {function()
				Spring.SetCameraTarget(msg.point.x, msg.point.y, msg.point.z, 1)
			end}
			function textbox:HitTest(x, y)  -- copied this hack from chili bubbles
				return self
			end
		end

		stack_console:AddChild(textbox, false)
		stack_console:UpdateClientArea()
	end 
end 


function PopulateConsole()
	stack_console:ClearChildren()
	for i = 1, #messages do -- FIXME : messages collection changing while iterating (if max_lines option has been shrinked)
		local msg = messages[i]
		displayMessage(msg, true)
	end	
end

function RemakeConsole()
	setup()
	PopulateConsole()
end

local function processMessage(msg)
	if #messages > 0 and messages[#messages].text == msg.text then -- TODO toggle option for duplicates + do we want to dedupe clickable points?
		messages[#messages].dup = messages[#messages].dup + 1
		displayMessage(messages[#messages])
		return
	end
	
	msg.dup = 1
	
	if msg.point then
--		Spring.Echo('')
	else
		parseMessage(msg)
		
		if msg.msgtype == 'point' or msg.msgtype == 'label' then
			-- ignore all console messages about points... those come in through the MapDrawCmd callin
			return
		end
	end
	detectHighlight(msg)
	formatMessage(msg) -- does not handle dedupe or highlight
	
	messages[#messages + 1] = msg
	displayMessage(msg)
	
	if (msg.msgtype == "player_to_allies" or msg.msgtype == "label") then  -- if ally message make sound
		Spring.PlaySoundFile('sounds/talk.wav', 1, 'ui')
	end

	if msg.highlight and options.highlight_sound.value then
		Spring.PlaySoundFile('LuaUI/Sounds/communism/cash-register-01.wav', 1, 'ui') -- TODO find a better sound :)
	end
	
	-- TODO differentiate between children and messages (because some messages may be hidden, thus no associated children/TextBox)
	while #messages > options.max_lines.value do
		stack_console:RemoveChild(stack_console.children[1])
		table.remove(messages, 1)
		--stack_console:UpdateLayout()
	end
	
	if playername == myName then
		if WG.enteringText then
			WG.enteringText = false
			hideConsole()
		end 		
	end
end

-----------------------------------------------------------------------

function widget:KeyPress(key, modifier, isRepeat)
	
	if (key == KEYSYMS.RETURN) then
		if not WG.enteringText then 
			if noAlly then
				firstEnter = false --skip the default-ally-chat initialization if there's no ally. eg: 1vs1
			end
			if firstEnter then
				if (not (modifier.Shift or modifier.Ctrl)) and options.defaultAllyChat.value then
					Spring.SendCommands("chatally")
				end
				firstEnter = false
			end
			WG.enteringText = true
			if window_console.hidden and not visible then 
				screen0:AddChild(window_console)
				visible = true
			end 
		end
	else
		if WG.enteringText then
			WG.enteringText = false
            return hideConsole()
		end
	end 
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:MapDrawCmd(playerId, cmdType, px, py, pz, caption)
--	Spring.Echo("########### MapDrawCmd " .. playerId .. " " .. cmdType .. " coo="..px..","..py..","..pz .. (caption and (" caption " .. caption) or ''))
	if (cmdType == 'point') then
		widget:AddMapPoint(playerId, px, py, pz, caption) -- caption may be an empty string
	end
end

function widget:AddMapPoint(playerId, px, py, pz, caption)
	local playerName, active, isSpec, teamId = Spring.GetPlayerInfo(playerId)

	processMessage({
		msgtype = ((caption:len() > 0) and 'label' or 'point'),
		playername = playerName,
		text = 'MapDrawCmd '..caption,
		argument = caption,
		priority = 0, -- just in case ... probably useless
		point = { x = px, y = py, z = pz }
	})
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:AddConsoleLine(text, priority)
	processMessage({text = text, priority = priority})
end


-----------------------------------------------------------------------

local timer = 0

local function CheckColorScheme() --//toggle between color scheme
	local currentColorScheme = wasSimpleColor 
	if WG.LocalColor then
		currentColorScheme = WG.LocalColor.usingSimpleTeamColors	
	end
	if wasSimpleColor ~= currentColorScheme then
		onOptionsChanged()
		wasSimpleColor = currentColorScheme
	end
end

-----------------------------------------------------------------------

function widget:Update(s)
	timer = timer + s
	if timer > 2 then
		timer = 0
		Spring.SendCommands({string.format("inputtextgeo %f %f 0.02 %f", 
			window_console.x / screen0.width + 0.004, 
			1 - (window_console.y + window_console.height) / screen0.height + 0.005, 
			window_console.width / screen0.width)})
		CheckColorScheme()
	end
end

-----------------------------------------------------------------------

function widget:PlayerAdded(playerID)
	setup()
end

-----------------------------------------------------------------------

function widget:Initialize()
	if (not WG.Chili) then
		widgetHandler:RemoveWidget()
		return
	end
	local spectating = Spring.GetSpectatingState()
	local myAllyTeamID = Spring.GetMyAllyTeamID() -- get my alliance ID
	local teams = Spring.GetTeamList(myAllyTeamID) -- get list of teams in my alliance
	if #teams == 1 and (not spectating) then -- if I'm alone and playing (no ally), then no need to set default-ally-chat during gamestart . eg: 1vs1
		noAlly = true
	end

	screen0 = WG.Chili.Screen0

	hideConsole = function()
		if window_console.hidden and visible then
			screen0:RemoveChild(window_console)
			visible = false
			return true
		end
		return false
	end

	-- only used by Crude
	showConsole = function()
		if not visible then
			screen0:AddChild(window_console)
			visible = true
		end
	end
	WG.chat.hideConsole = hideConsole
	WG.chat.showConsole = showConsole

	Spring.SendCommands("bind Any+enter  chat")
	
	local inputsize = 33
	
	local screenWidth, screenHeight = Spring.GetWindowGeometry()
	
	stack_console = WG.Chili.StackPanel:New{
		margin = { 0, 0, 0, 0 },
		padding = { 0, 0, 0, 0 },
		x = 0,
		y = 0,
		width = '100%',
		height = 10,
		resizeItems = false,
		itemPadding  = { 1, 1, 1, 1 },
		itemMargin  = { 1, 1, 1, 1 },
		autosize = true,
		preserveChildrenOrder = true,
	}
	inputspace = WG.Chili.ScrollPanel:New{
		x = 0,
		bottom = 0,
		right = 5,
		height = inputsize,
		backgroundColor = options.color_background.value,
		--backgroundColor = {1,1,1,1},
	}
	
	scrollpanel1 = WG.Chili.ScrollPanel:New{
		--margin = {5,5,5,5},
		padding = { 5, 5, 5, 5 },
		x = 0,
		y = 0,
		width = '100%',
		bottom = inputsize + 2, -- This line is temporary until chili is fixed so that ReshapeConsole() works both times! -- TODO is it still required??
		verticalSmartScroll = true,
-- DISABLED FOR CLICKABLE TextBox		disableChildrenHitTest = true,
		backgroundColor = options.color_background.value,
		noMouseWheel = not options.mousewheel.value,
		children = {
			stack_console,
		},
	}
	
	window_console = WG.Chili.Window:New{  
		margin = { 0, 0, 0, 0 },
		padding = { 0, 0, 0, 0 },
		dockable = true,
		name = "Chat",
		y = 0,
		right = 425, -- epic/resbar width
		width  = screenWidth * 0.30,
		height = screenHeight * 0.20,
		--parent = screen0,
		--visible = false,
		--backgroundColor = settings.col_bg,
		draggable = false,
		resizable = false,
		tweakDraggable = true,
		tweakResizable = true,
		minimizable = true,
        selfImplementedMinimizable = 
            function (show)
                if show then
                    showConsole()
                else
                    hideConsole()
                end
            end,
		minWidth = MIN_WIDTH,
		minHeight = MIN_HEIGHT,
		color = { 0, 0, 0, 0 },
		children = {
			scrollpanel1,
			inputspace,
		},
		OnMouseDown = {
			function(self) --//click on scroll bar shortcut to "Settings/Interface/Chat/Console".
				local _,_, meta,_ = Spring.GetModKeyState()
				if not meta then return false end
				WG.crude.OpenPath(options_path)
				WG.crude.ShowMenu() --make epic Chili menu appear.
				return true
			end
		},
	}
	
	RemakeConsole()

	local bufferMessages = Spring.GetConsoleBuffer(options.max_lines.value)
	for i = 1,#bufferMessages do
		processMessage(bufferMessages[i])
	end
	
	Spring.SendCommands({"console 0"})
	
	screen0:AddChild(window_console)
    visible = true
end

-----------------------------------------------------------------------

function widget:Shutdown()
	if (window_console) then
		window_console:Dispose()
	end
	Spring.SendCommands({"console 1"}, {"inputtextgeo default"}) -- not saved to spring's config file on exit
	Spring.SetConfigString("InputTextGeo", "0.26 0.73 0.02 0.028") -- spring default values
end