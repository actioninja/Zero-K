if (not gadgetHandler:IsSyncedCode()) then return end

function gadget:GetInfo() return {
	name     = "Startbox handler",
	desc     = "Handles startboxes",
	author   = "Sprung",
	date     = "2015-05-19",
	license  = "PD",
	layer    = -1,
	enabled  = true,
} end

if VFS.FileExists("mission.lua") then return end

VFS.Include ("LuaRules/Utilities/startbox_utilities.lua")

--[[ expose a randomness seed
this is so that LuaUI can reproduce randomness in the box config as otherwise they use different seeds
afterwards, reseed with a secret seed to prevent LuaUI from reproducing the randomness used for shuffling ]]
local private_seed = math.random(2000000000) -- must be an integer
Spring.SetGameRulesParam("public_random_seed", math.random(2000000000))
local startboxConfig, manualStartposConfig = ParseBoxes()
math.randomseed(private_seed)

GG.startBoxConfig = startboxConfig
GG.manualStartposConfig = manualStartposConfig

function gadget:Initialize()

	Spring.SetGameRulesParam("startbox_max_n", #startboxConfig)
	Spring.SetGameRulesParam("startbox_custom_shapes", manualStartposConfig and 1 or 0)

	if manualStartposConfig then
		for box_id, startposes in pairs(manualStartposConfig) do
			Spring.SetGameRulesParam("startpos_n_" .. box_id, #startposes)
			for i = 1, #startposes do
				Spring.SetGameRulesParam("startpos_x_" .. box_id .. "_" .. i, startposes[i][1])
				Spring.SetGameRulesParam("startpos_z_" .. box_id .. "_" .. i, startposes[i][2])
			end
		end
	end

	local gaiaAllyTeamID = select(6, Spring.GetTeamInfo(Spring.GetGaiaTeamID()))

	-- filter out fake teams (empty or Gaia)
	local allyTeamList = Spring.GetAllyTeamList()
	local actualAllyTeamList = {}
	for i = 1, #allyTeamList do
		local teamList = Spring.GetTeamList(allyTeamList[i]) or {}
		if ((#teamList > 0) and (allyTeamList[i] ~= gaiaAllyTeamID)) then
			actualAllyTeamList[#actualAllyTeamList+1] = {allyTeamList[i], math.random()}
		end
	end

	local shuffleMode = Spring.GetModOptions().shuffle or "off"

	if (shuffleMode == "off") then

		for i = 1, #allyTeamList do
			local allyTeamID = allyTeamList[i]
			local boxID = allyTeamList[i]
			if startboxConfig[boxID] then
				local teamList = Spring.GetTeamList(allyTeamID) or {}
				for j = 1, #teamList do
					Spring.SetTeamRulesParam(teamList[j], "start_box_id", boxID)
				end
			end
		end

	elseif (shuffleMode == "shuffle") then

		local randomizedSequence = {}
		for i = 1, #actualAllyTeamList do
			randomizedSequence[#randomizedSequence + 1] = {actualAllyTeamList[i][1], math.random()}
		end
		table.sort(randomizedSequence, function(a, b) return (a[2] < b[2]) end)

		for i = 1, #actualAllyTeamList do
			local allyTeamID = actualAllyTeamList[i][1]
			local boxID = randomizedSequence[i][1]
			if startboxConfig[boxID] then
				local teamList = Spring.GetTeamList(allyTeamID) or {}
				for j = 1, #teamList do
					Spring.SetTeamRulesParam(teamList[j], "start_box_id", boxID)
				end
			end
		end

	elseif (shuffleMode == "allshuffle") then

		local randomizedSequence = {}
		for id in pairs(startboxConfig) do
			randomizedSequence[#randomizedSequence + 1] = {id, math.random()}
		end
		table.sort(randomizedSequence, function(a, b) return (a[2] < b[2]) end)
		table.sort(actualAllyTeamList, function(a, b) return (a[2] < b[2]) end)

		for i = 1, #actualAllyTeamList do
			local allyTeamID = actualAllyTeamList[i][1]
			local boxID = randomizedSequence[i] and randomizedSequence[i][1]
			if boxID and startboxConfig[boxID] then
				local teamList = Spring.GetTeamList(allyTeamID) or {}
				for j = 1, #teamList do
					Spring.SetTeamRulesParam(teamList[j], "start_box_id", boxID)
				end
			end
		end
	end
end

local function CheckStartbox (boxID, x, z)

	local box = startboxConfig[boxID]
	local valid = false

	for i = 1, #box do
		local x1, z1, x2, z2, x3, z3 = unpack(box[i])
		if (cross_product(x, z, x1, z1, x2, z2) < 0
		and cross_product(x, z, x2, z2, x3, z3) < 0
		and cross_product(x, z, x3, z3, x1, z1) < 0
		) then
			valid = true
		end
	end

	return valid
end

GG.CheckStartbox = CheckStartbox

function gadget:AllowStartPosition(x, y, z, playerID, readyState)
	if (playerID == 255) then
		return true -- custom AI, can't know which team it is on so allow it to place anywhere for now and filter invalid positions later
	end

	local teamID = select(4, Spring.GetPlayerInfo(playerID))
	local boxID = Spring.GetTeamRulesParam(teamID, "start_box_id")

	if (not boxID) or CheckStartbox(boxID, x, z) then
		Spring.SetTeamRulesParam (teamID, "valid_startpos", 1)
		return true
	else
		return false
	end
end
