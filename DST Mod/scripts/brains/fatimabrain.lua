require "behaviours/chaseandattack"
require "behaviours/runaway"
require "behaviours/approach"
require "behaviours/chattynode"
require "behaviours/panic"

local SEE_DIST = 21 --21
local SEE_RANGE_HELPER = false
local PERCEPTION_UPDATE_INTERVAL = .5
local DSTACTION_INTERVAL = 1.5
local SPEAKACTION_INTERVAL = 3
local SPEAKACTION_PROB = 40
local NUM_SEGS = 16

local old_pos = nil
local old_target = nil
local pos_cnt = 0
local target_cnt = 0

local target = nil

local MAX_CHASE_TIME = 10
local MAX_CHASE_DIST = 30
local RUN_AWAY_DIST = 15
local STOP_RUN_AWAY_DIST = 10

local CurrentSearchDistance = 20
local past_x, past_y, past_z = nil, nil, nil

local Player_character = nil
local p_dist = 0
local max_p_dist = 400
local max_w_dist = 800
local min_p_dist = 200
local CHECK_DISTANCE_INTERVAL = 5

local map_nodes = TheWorld.topology.nodes
local visited_nodes = {}
local node_cnt = 0
local wanderdirection = nil

local Encyclopedia = {}
local entity_cnt = 0

local given_food = nil

local Home = nil
local PLAYERNEARBY = false

local AI_Personality = nil -- "Adventurer", "Camper", "Supporter"
local Goal = "None"

local perception_data = nil

local Goal_list = {
	Adventurer = {
				Objective = "Maximize_Vison_Score",
				Goals = {
							{goal = "Gather_resource",
								condition = {"IsAbundance"},
								state = false},

							{goal = "Build_weapon",
								condition = {"HasSpear"},
								state = false},

							{goal = "Go_travel",
								condition = {"Maximize_Vison_Score"},
								state = false}
						},
				Vision_Score = node_cnt
				},
	Camper = {
				Objective = "Maximize_Development_Score",
				Goals = {
							{goal = "Gather_resource",
								condition = {"IsAbundance"}},
							{goal = "Build_tools",
								condition = {"HasPickaxe", "HasAxe"}},
							{goal = "Build_firepit",
								condition = {}}
						},
				Development_Score = 0
			},
	Supporter = {
				Obejective = "Maximize_Companion_Score",
				Goals = {
							{goal = "Imitate_player",
								condition = {}}
						},
				Companion_Score = 0
				}
}


local assets =
{
    Asset("ANIM", "anim/firefighter_placement.zip"),
}


local function tprint (tbl, indent)
	if not indent then indent = 0 end
	for k, v in pairs(tbl) do
	  local formatting = string.rep("  ", indent) .. k .. ": "
	  if type(v) == "table" then
		print(formatting)
		tprint(v, indent+1)
	  elseif type(v) == 'boolean' then
		print(formatting .. tostring(v))
	  else
		print(formatting .. v)
	  end
	end
  end

local function AddSeeRangeHelper(inst)
    if SEE_RANGE_HELPER and inst.seerangehelper == nil then
        inst.seerangehelper = CreateEntity()

        --[[Non-networked entity]]
        inst.seerangehelper.entity:SetCanSleep(false)
        inst.seerangehelper.persists = false

        inst.seerangehelper.entity:AddTransform()
        inst.seerangehelper.entity:AddAnimState()

        inst.seerangehelper:AddTag("CLASSIFIED")
        inst.seerangehelper:AddTag("NOCLICK")
        inst.seerangehelper:AddTag("placer")

        inst.seerangehelper.Transform:SetScale(SEE_DIST/11, SEE_DIST/11, SEE_DIST/11)

        inst.seerangehelper.AnimState:SetBank("firefighter_placement")
        inst.seerangehelper.AnimState:SetBuild("firefighter_placement")
        inst.seerangehelper.AnimState:PlayAnimation("idle")
        inst.seerangehelper.AnimState:SetLightOverride(1)
        inst.seerangehelper.AnimState:SetOrientation(ANIM_ORIENTATION.OnGround)
        inst.seerangehelper.AnimState:SetLayer(LAYER_BACKGROUND)
        inst.seerangehelper.AnimState:SetSortOrder(1)
        inst.seerangehelper.AnimState:SetAddColour(0, .2, .5, 0)

        inst.seerangehelper.entity:SetParent(inst.entity)
    end
end

local function Entity(inst, v)
	local d = {}

	d.GUID = v.GUID
	d.Prefab = v.prefab or nil
	d.Quantity = v.components.stackable ~= nil and v.components.stackable:StackSize() or 1

	d.Collectable = v:HasTag("pickable") -- PICK
	d.Cooker = v:HasTag("cooker")
	d.Cookable = v:HasTag("cookable")
	d.Edible = inst.components.eater:CanEat(v)
	d.Equippable = v:HasTag("_equippable")
	d.Fuel = v:HasTag("BURNABLE_fuel")
	d.Fueled = v:HasTag("BURNABLE_fueled")
	d.Grower = v:HasTag("grower")
	d.Harvestable = v:HasTag("readyforharvest") or (v.components.stewer and v.components.stewer:IsDone())
	d.Pickable = v.components.inventoryitem and v.components.inventoryitem.canbepickedup and not v:HasTag("heavy") -- PICKUP
	d.Stewer= v:HasTag("stewer")

	d.Choppable = v:HasTag("CHOP_workable")
	d.Diggable = v:HasTag("DIG_workable")
	d.Hammerable = v:HasTag("HAMMER_workable")
	d.Mineable = v:HasTag("MINE_workable")

	d.X, d.Y, d.Z = v.Transform:GetWorldPosition()

	-- Added
	-- d.Attackable = inst.replica.combat:IsValidTarget(v)
	d.Attackable = inst.components.combat:CanAttack(v)
	d.Closest = v:HasTag("Closest")
	d.OnWater = v:IsOnWater()
	d.IsEquipped = d.Equippable and v.replica.equippable:IsEquipped() or false

	-- TheNet:SystemMessage(v.prefab .. " / " .. d.Distance)

	-- if v.prefab == "wx78_scanner_item" or v.prefab == "wx78_moduleremover" then
	-- 	TheNet:SystemMessage("Found")

	-- if v.GUID == 117528 then
	-- 	for k, kk in pairs(v.components) do
	-- 		print(k, kk)
	-- 	end
	-- 	print(v:GetDebugString())
	-- end
	-- print("  ")

	return d
end

-- here for testing purposes...
local function Event(name, value, brain)
	print(name, value)
	if (type(value) == "table") then
		for k, v in pairs(value) do
			print(k, v)
		end
	end

end

local function KeepWorking(inst, action, target)
	local t = Ents[tonumber(target)]
	--TheNet:SystemMessage("Keep Working")
	return (action == "CHOP" and t ~= nil and t:HasTag("CHOP_workable")) or (action == "HAMMER" and t ~= nil and t:HasTag("HAMMER_workable")) or (action == "DIG" and t ~= nil and t:HasTag("DIG_workable")) or (action == "MINE" and t ~= nil and t:HasTag("MINE_workable") or (action == "ATTACK" and t ~= nil and inst.replica.combat:IsValidTarget(t)) )
end

local function IsWorkAction(action)
	return action == "CHOP" or action == "MINE" or action == "HAMMER" or action == "DIG" or action == "ATTACK"
end


local FAtiMABrain = Class(Brain, function(self, inst, server)
    Brain._ctor(self, inst)
    self.inst = inst

    ------------------------------
    ---- FAtiMA Communication ----
    ------------------------------
    self.FAtiMAServer = server or "http://localhost:8080"

    ------------------------------
    -- HTTP Callbacks Functions --
    ------------------------------
	self.OnPerceptions = function() self:Perceptions() end
    self.PerceptionsCallback = function(result, isSuccessful , http_code)
        -- Intentionally left blank
    end

	self.OnEventCallback = function(result, isSuccessful , http_code)
        if isSuccessful then
			local action = result and (result ~= "") and json.decode(result) end
	end

	self.OnSpeakActionDecide = function() self:Speech() end
	self.SpeechCallback = function (result, isSuccessful, http_code)

		if isSuccessful then
			local speak = result and (result ~= "") and json.decode(result)
			if speak then
				TheNet:SystemMessage("Speech Recieved : " .. tostring(speak.Style))
				self.Utterance = speak.Utterance
				self.Keyword = speak.Style
				self.Text = speak.Meaning

				if #AllPlayers >= 2 and self.Text ~= nil then
					Player_character.components.talker:Say(self.Text)
				end

				if self.Utterance then
					self.inst.components.talker:Say(self.Utterance)
				end

			else
				self.Utterance = nil
				self.keyword = nil
				self.Text = nil
				self.UttAction = nil
				--self.inst.components.talker:Say(tostring(speak) .. " / " .. tostring(json.decode(result)))
				self.inst.components.talker:Say("No Speech")
			end
		else
			self.Utterance = nil
			self.UttAction = nil
			TheNet:SystemMessage("Speech Failed : " .. tostring(http_code))
		end
	end

	self.OnDSTActionDecide = function() self:Decide("Behaviour") end
    self.DecideCallback = function(result, isSuccessful , http_code)
        if isSuccessful then
			local action = result and (result ~= "") and json.decode(result)
			if action and action.Type then
				if action.Type == "Action" then
					if self.CurrentAction == nil or (self.CurrentAction.WFN ~= action.WFN or self.CurrentAction.Target ~= action.Target) then

						--self.inst:InterruptBufferedAction() -- ClearBufferedAction
						self.inst:ClearBufferedAction()
						self.inst.components.locomotor:Clear()
						self.CurrentAction = action
					end
					--Otherwise the action is the same as the one being executed, so there is no need to override it
				elseif action.Type == "Speak" then
					-- Speak Action are made the moment they are received. They only occur every SPEAKACTION_INTERVAL seconds with a percentage of SPEAKACTION_PROB
					-- Speak([cs],[ns],[m],[sty]) = [t]
					if math.random(100) < GetModConfigData("speak-chance", KnownModIndex:GetModActualName("FAtiMA-DST")) then
						self.inst.components.talker:Say(action.Utterance)
						-- Tell FAtiMA that the action has ended
						self:OnActionEndEvent(action.Name, action.Target)
					end
				end
			end
		end
    end

	self.UpdateVisionScore = function() self:VisionScore() end

	------------------------------
    -- Event Listener Functions --
    ------------------------------
	-- I need to keep references to these functions to remove the listeners later
	self.OnKilled = function(inst, data) self:OnActionEndEvent("Killed", function() return (self.CurrentAction ~= nil and self.CurrentAction.Target or "-") end ) end
	-- self.OnAttacked = function(inst, data) self:OnActionEndEvent("Attacked", self.inst.components.combat.lastattacker and self.inst.components.combat.lastattacker.GUID or "darkness") end
	self.OnAttacked = function(inst, data)
		if inst.no_targeting then
			return
		end
		-- inst.defensive = false
		inst.components.combat:SetTarget(data.attacker)
		self:OnActionEndEvent("Attacked", function() return (self.inst.components.combat.lastattacker ~= nil and self.inst.components.combat.lastattacker.GUID or "darkness") end )
	end
	self.OnDeath = function(inst, data) self:OnActionEndEvent("Death", function() return (self.inst.components.combat.lastattacker ~= nil and self.inst.components.combat.lastattacker.GUID or "darkness") end ) end
	self.OnMissOther = function(inst, data) self:OnActionEndEvent("MissOther", function() return (self.CurrentAction ~= nil and self.CurrentAction.Target or "-") end ) end
	self.OnHitOther = function(inst, data) self:OnActionEndEvent("HitOther", function() return (self.CurrentAction ~= nil and self.CurrentAction.Target or "-") end) end

	------------------------------
    ------ Watch World State -----
    ------------------------------
	self.OnClockTick = function (inst, data)
		if self.time ~= nil then
			local prevseg = math.floor(self.time * NUM_SEGS)
			local nextseg = math.floor(data.time * NUM_SEGS)
			if prevseg ~= nextseg then
				self:OnPropertyChangedEvent("World(CurrentSegment)", nextseg)
			end
		else
			-- The first time we need to tell FAtiMA what is the current segment
			self:OnPropertyChangedEvent("World(CurrentSegment)", math.floor(data.time * NUM_SEGS))
		end
		self.time = data.time
	end
	self.OnClockSegsChanged = function(inst, data)
		self:OnPropertyChangedEvent("World(PhaseLenght, day)", data.day)
		self:OnPropertyChangedEvent("World(PhaseLenght, dusk)", data.dusk)
		self:OnPropertyChangedEvent("World(PhaseLenght, night)", data.night)
	end
	self.OnEnterDark = function(inst, data) self:OnPropertyChangedEvent("InLight(Walter)", "False") end
	self.OnEnterLight = function(inst, data) self:OnPropertyChangedEvent("InLight(Walter)", "True") end
	self.OnCycles = function(inst, cycles) if cycles ~= nil then self:OnPropertyChangedEvent("World(Cycle)", cycles + 1) end end
	self.OnPhase = function(inst, phase) self:OnPropertyChangedEvent("World(Phase)", phase) end
	self.OnMoonPhase = function(inst, moonphase) self:OnPropertyChangedEvent("World(MoonPhase)", moonphase) end
	self.OnSeason = function(inst, season) self:OnPropertyChangedEvent("World(Season)", season) end
	self.OnSeasonProgress = function(inst, seasonprogress) self:OnPropertyChangedEvent("World(SeasonProgress)", seasonprogress) end
	self.OnElapsedDaysInSeason = function(inst, elapseddaysinseason) self:OnPropertyChangedEvent("World(ElapsedDaysInSeason)", elapseddaysinseason) end
	self.OnRemainingDaysInSeason = function(inst, remainingdaysinseason) self:OnPropertyChangedEvent("World(RemainingDaysInSeason)", remainingdaysinseason) end
	self.OnSpringLength = function(inst, springlength) self:OnPropertyChangedEvent("World(SpringLength)", springlength) end
	self.OnSummerLength = function(inst, summerlength) self:OnPropertyChangedEvent("World(SummerLength)", summerlength) end
	self.OnAutumnLength = function(inst, autumnlength) self:OnPropertyChangedEvent("World(AutumnLenght)", autumnlength) end
	self.OnWinterLength = function(inst, winterlength) self:OnPropertyChangedEvent("World(WinterLenght)", winterlength) end
	self.OnIsSnowing = function(inst, issnowing) self:OnPropertyChangedEvent("World(IsSnowing)", issnowing) end
	self.OnIsRaining = function(inst, israining) self:OnPropertyChangedEvent("World(IsRaining)", israining) end
end)

function FAtiMABrain:GetPersonality()

	if GetModConfigData("personality", KnownModIndex:GetModActualName("The AI Companion")) ~= "None" then
		return GetModConfigData("personality", KnownModIndex:GetModActualName("The AI Companion"))
	else
		return "None"
	end
end

function FAtiMABrain:GetPersonalityTraits() -- Currently Not used 
	--Personality (OCEAN model)
	local OPE = GetModConfigData("OPE", KnownModIndex:GetModActualName("The AI Companion"))
	local COS = GetModConfigData("COS", KnownModIndex:GetModActualName("The AI Companion"))
	local EXT = GetModConfigData("EXT", KnownModIndex:GetModActualName("The AI Companion"))
	local AGR = GetModConfigData("AGR", KnownModIndex:GetModActualName("The AI Companion"))
	local NEU = GetModConfigData("NEU", KnownModIndex:GetModActualName("The AI Companion"))

	-- OPE : Outgoing (Travel)
	-- COS : APM ( Action Per minutes )
	-- EXT : Keep approaching to the Player
	-- AGR : Interaction Frequency
	-- NEU : Avoidance of danger

	return OPE, COS, EXT, AGR, NEU
end

function FAtiMABrain:UnlockRecipe(item)
	if not self.inst.components.builder:KnowsRecipe(item) then
		 self.inst.components.builder:UnlockRecipe(item)
	 end
end

function FAtiMABrain:GetGoalList(personality)
	return Goal_list[tostring(personality)]
end

function FAtiMABrain:ChangeState(personality, goal)
	local g_lst = self:GetGoalList(personality)
	for i=1, #g_lst["Goals"] do
		if g_lst["Goals"][i]["goal"] == goal then
			g_lst["Goals"][i]["state"] = true
		end
	end
end

function FAtiMABrain:CheckCondition(condition, data)

	if condition == "IsAbundance" and data.IsAbundance and not data.HasSpear then
			return true

	elseif condition == "HasSpear" and data.HasSpear then
			return true

	elseif condition == "HasPickaxe" and data.HasPickaxe then
			return true

	elseif condition == "HasAxe" and data.HasAxe then
			return true

	elseif condition == "Has_firepit" and
		self:FindNearbyEntity(10000, "firepit") ~= false then  -- TODO: Have to change the function later
			return true

	elseif condition == "Imitate_player" then
		return true

	elseif condition == "Maximize_Vison_Score" then
		return false

	else
		return false
	end
end

function FAtiMABrain:GetCurrentGoal(personality, data)
	local current_goal = nil

	if personality ~= "None" then
		local g_lst = self:GetGoalList(personality)
		for i=1, #g_lst["Goals"] do
			for g, c in pairs(g_lst["Goals"][i]["condition"]) do
				if not self:CheckCondition(c, data) and not g_lst["Goals"][i]["state"] then
					current_goal = g_lst["Goals"][i]["goal"]
					break
				end
			end

			if current_goal ~= nil then
				break
			end
		end
	else
		return "None"
	end

	return current_goal
end

function FAtiMABrain:SetPersonalityParms(p)
	-- Distance etc..
	if p == "Adventurer" then
		max_p_dist = 450
		max_w_dist = 800

	elseif p == "Camper" then
		max_p_dist = 600

	elseif p == "Supporter" then
		max_p_dist = 200

	elseif p == "None" then
		max_p_dist = 400
	end
end
	-- Condition 1-1: When the AI go too far away from the player, go back to the player
	-- Condition 1-2 : When the AI go too far away from home, go back to home
	-- Condition 2 : Fight with encounter any enenmies

function FAtiMABrain:FindNearbyEntity(seek_distance, entity)
	local x, y, z = self.inst.Transform:GetWorldPosition()
	local ents = TheSim:FindEntities(x, y, z, seek_distance)
	if ents ~= nil then
		for i, v in ipairs(ents) do
			if v.entity:IsVisible() and v.prefab == tostring(entity) then
				return v
			end
		end
	else
		return false
	end
end

function FAtiMABrain:IsEntityNearby(seek_distance, entity)
	if self:FindNearbyEntity(seek_distance, entity) ~= nil then
		return true
	else
		return false
	end
end

function FAtiMABrain:HasHome()
	if self.inst.components.homeseeker == nil then
        self.inst:AddComponent("homeseeker")
    end
	return self.inst.components.homeseeker.home
end

function FAtiMABrain:FindValidHome()

	if not self:HasHome() then
		-- TheNet:SystemMessage('Lets find home!')

		-- Reuse a nearby multiplayer portal as a home.
		local portal = self:FindNearbyEntity(10000, "multiplayer_portal")
		if portal then
			-- TheNet:SystemMessage("Found our home!")
			Home = portal
		end
	else
		return false
	end
end

function FAtiMABrain:SetHome()
	if not self:HasHome() then
		self.inst.components.homeseeker:SetHome(Home)
	end
end

function FAtiMABrain:IsHomeOnFire()
    return self.inst.components.homeseeker
        and self.inst.components.homeseeker.home
        and self.inst.components.homeseeker.home.components.burnable
        and self.inst.components.homeseeker.home.components.burnable:IsBurning()
        and self.inst:GetDistanceSqToInst(self.inst.components.homeseeker.home) < 20*20 -- SEE_BURNING_HOME_DIST_SQ
end

function FAtiMABrain:GetNextNodePosition()
	local x,y,z = nil, nil, nil

	if self:IsOtherPlayer() then
		if Player_character == nil then
			self:SetPlayerCharacter()
		end
		x,y,z = Player_character.Transform:GetWorldPosition()
	else
		x,y,z = self.inst.Transform:GetWorldPosition()
	end

	local node = GetClosestNode(x,z)

	return node.x, node.y
end

-- function FAtiMABrain:GetAngletoNextNode()
-- 	local pos = Vector3(self:GetNextNodePosition())
-- 	wanderdirection = self.inst:GetAngleToPoint(pos.x, 0, pos.z)
-- 	return wanderdirection
-- end

-- function FAtiMABrain:SetWanderDirection(angle)
--     --print("Got wander direction", angle)
--     wanderdirection = angle
-- end

local function GetWanderDirection(inst)
	local pos = Vector3(FAtiMABrain:GetNextNodePosition())
	inst.wanderdirection = inst:GetAngleToPoint(pos.x, 0, pos.z)
	TheNet:SystemMessage(tostring(inst.wanderdirection * DEGREES))
	return inst.wanderdirection * DEGREES
end

local function SetWanderDirection(inst, angle)
    inst.wanderdirection = angle
end

function FAtiMABrain:Distance_sum()
	local dist_sq = self.inst:GetDistanceSqToPoint(past_x, past_y, past_z)
	return dist_sq
end

local function GetFaceTargetFn(inst)
    return Player_character
end

local function KeepFaceTargetFn(inst, target)
	return target ~= nil
		 and target.components.combat ~= nil
		 and target.components.health ~= nil
		 and not target.components.health:IsDead()
		 and not (inst.components.follower ~= nil
		 and inst.components.follower:IsLeaderSame(target)
		)
end

local function keeptargetfn(inst, target)
	return Player_character == target
end

function FAtiMABrain:ClassifyUtterance()
	local keywords = {
        ["come"] = "Follow",
        ["go.*away"] = "Goaway",
        ["wait"] = "Stop",
        ["oh my god"] = "Approach",
        ["where.*go"] = "Follow",
        ["\battack\b "] = "Attack" ,
        ["attacked"] = "Attack",
        ["^((?!i|I).).*(can|please)?.*give.*grass.*(please)?"] = "Give_cutgrass",
        ["^((?!i|I).).*(can|please)?.*give.*rock.*(please)?"] = "Give_rock",
        ["^((?!i|I).).*(can|please)?.*give.*flint.*(please)?"] = "Give_flint",
        ["^((?!i|I).).*(can|please)?.*give.*log.*(please)?"] = "Give_log",
        ["^((?!i|I).).*(can|please)?.*give.*twigs.*(please)?"] = "Give_twigs",
        ["^((?!i|I).).*(can|please)?.*give.*food.*(please)?"] = "Give_food",
	    ["let.*kill"] = "Attack",
	    ["let.*go"] = "Follow",
	    ["let.*find"] = "Wander",
	    ["need.*(fire|light)"] = "Build",
	    ["(?!.*(you)).*need.*help.*(me|please)?"] = "Approach",
	    ["help.*me"] = "Approach",
	    ["come.*(back|here)"] = "Follow",
	    ["go.*find"] = "Wander",
	    ["build.*fire"] = "Build",
	    ["go.*(back|home|sleep|camp)"] = "GoHome",
	    ["make.*(torch|fire|campfire)"] = "Build",
	    ["help"] = "Approach"
    }

    if self.Utterance ~= nil then
        self.UttAction = keywords[self.Keyword]
        if self.UttAction ~= nil then
            TheNet:SystemMessage("UttAction : " .. self.UttAction)
        end
    else
        self.UttAction = nil
    end
    return self.UttAction
end

function FAtiMABrain:IsGiveAction()
	return self.UttAction ~= nil and string.sub(tostring(self.UttAction), 1, 4) == "Give"
end

function FAtiMABrain:CheckItemToGive()
    local item_type = nil
    local item_name = nil

	if self:IsGiveAction() then
		item_type = string.sub(self.UttAction, 6, -1)
		if item_type == "food" then
			item_type = self.inst.components.inventory:FindItem(function(food) return self.inst.components.eater:CanEat(food) end) or nil
		end
		item_name = item_type

    elseif self.CurrentAction ~= nil and self.CurrentAction.Action == "GIVETOPLAYER" then
        item_name = tostring(string.sub(self.CurrentAction.WFN, 22, -11))
    end

    local item_GUID = nil
	local flag = false

	if self.inst.components.inventory:Has(item_name, 1) then
	    local item = self.inst.components.inventory:GetItemByName(item_name, 1)
    	if item then
            flag = true
    	    for i, v in pairs(item) do
                item_GUID = Ents[tonumber(string.sub(tostring(i), 1, 6))] or nil
            end
        end
    end
    TheNet:SystemMessage("Flag : " .. tostring(flag) .. " / " .. "GUID :  " .. tostring(item_GUID))
    return flag, item_GUID
end

function FAtiMABrain:Perceptions()

    local data = {}

	-- Vision
	local x, y, z = self.inst.Transform:GetWorldPosition()
    local TAGS = nil
    local EXCLUDE_TAGS = {"INLIMBO", "NOCLICK", "CLASSIFIED", "FX"}
    local ONE_OF_TAGS = nil
    local ents = TheSim:FindEntities(x, y, z, SEE_DIST, TAGS, EXCLUDE_TAGS, ONE_OF_TAGS)

	-- if past_x ~= nil and past_y ~= nil and past_z ~= nil then
	-- 	local move_dist = math.floor(self:Distance_sum() * 1000) / 1000
	-- 	TheNet:SystemMessage("Dist : " .. move_dist)
	-- end
	-- past_x, past_y, past_z = x, y, z


    -- Go over all the objects that the agent can see and take what information we need
    local vision = {}
	local j = 1

	--Closeness
	local distance = nil
	local proximate_entity = nil

	-- init player nearby
	PLAYERNEARBY = false

    for i, v in pairs(ents) do
		if v.GUID ~= self.inst.GUID and v:HasTag("pickable") or v.GUID ~= self.inst.GUID and v.components.stackable ~= nil then
			local v_dist = tonumber(self.inst:GetDistanceSqToInst(v))

			if distance == nil or v_dist < distance then
				distance = v_dist
				proximate_entity = v.GUID
			end
		-- else
		-- 	for k, kk in pairs(v.components.combat) do
		-- 		print(k, kk)
		-- 	end
		-- 	print(v:GetDebugString())
		-- 	print("  ")
		end
    end

    for i, v in pairs(ents) do
		if v.GUID ~= self.inst.GUID then
			if v.GUID == proximate_entity then
				-- TheNet:SystemMessage(v.prefab)
				v:AddTag("Closest")
			end

			if Encyclopedia[v.prefab] ~= true and v.prefab ~= nil then
				entity_cnt = entity_cnt + 1
				Encyclopedia[v.prefab] = true
				-- TheNet:SystemMessage("Entity score : " .. tostring(entity_cnt))
			end

			if v.prefab == 'wilson' then
				PLAYERNEARBY = true
			end

			vision[j] = Entity(self.inst, v)
			j = j+1
		end
    end

    data.Vision = vision
	data.Proximate = proximate_entity

	-- Inventory
	local equipslots = {}
    local itemslots = {}

    -- Go over all items in the inventory and take what information we need
    for k, v in pairs(self.inst.components.inventory.itemslots) do
        itemslots[k] = Entity(self.inst, v)

		if v.components.stackable ~= nil then
			--Write resouces status
			if string.find(tostring(v), "twigs") ~= nil then
				data.twigs = v.components.stackable:StackSize()
			elseif string.find(tostring(v), "cutgrass") ~= nil then
				data.grass = v.components.stackable:StackSize()
			elseif string.find(tostring(v), "log") ~= nil then
				data.logs = v.components.stackable:StackSize()
			elseif string.find(tostring(v), "rock") ~= nil then
				data.rock = v.components.stackable:StackSize()
			elseif string.find(tostring(v), "flint") ~= nil then
				data.flints = v.components.stackable:StackSize()
			end
		end
    end

	-- to build backpack & spears for adventurer
	if data.twigs ~= nil and data.twigs > 2 and
		data.grass ~= nil and data.grass > 7 and
				data.flints ~= nil and data.flints > 1 then
		data.IsAbundance = true
	else
		data.IsAbundance = false
	end

    -- Go over equipped items and put them in an array
    -- I chose to use an array not to limit which equip slots the agent has.
    -- This way I do not need to change any code, should any new slot appear.
    local i = 1
    for k, v in pairs(self.inst.components.inventory.equipslots) do
        equipslots[i] = Entity(self.inst, v)
        i = i + 1
    end
    data.EquipSlots, data.ItemSlots = equipslots, itemslots

    data.Health = self.inst.components.health.currenthealth
    data.Hunger = self.inst.components.hunger.current
    data.Sanity = self.inst.components.sanity.current
    data.Temperature = self.inst:GetTemperature()
    data.IsFreezing = self.inst:IsFreezing()
    data.IsOverHeating = self.inst:IsOverheating()
    data.Moisture = self.inst:GetMoisture()
	if (self.CurrentAction ~= nil and self.CurrentAction.Type == "Action" and self.CurrentAction.Action == "WANDER") or
		(self.CurrentAction == nil) then
		data.IsBusy = false
		--TheNet:SystemMessage("I'm not Busy")
	else
		data.IsBusy = true
		if self.CurrentAction ~= nil then
			--TheNet:SystemMessage(TheSim:GetRealTime()/1000 .." / "..self.CurrentAction.Action .. " / " .. self.CurrentAction.Target .. " / ".. self.CurrentAction.WFN)

			--TheNet:SystemMessage(TheSim:GetRealTime()/1000  .. " / ".. self.CurrentAction.Action .." / " .. self.CurrentAction.Target .. " / ".. self.inst.GUID .. " / " .. Goal)
			data.CurrentAction = self.CurrentAction.Action
			self:AddStuckCount()

		end
		-- 3114 / PICK / 105883 / Action(PICK, -, -, -, -)

		-- print(data.Vision[1].GUID)
		--tprint(data.Vision[1]) -- 1 tbl,2 tbl ,3 tbl , ...
		--self.CurrentAction.Target : String

		-- print(TheSim:GetRealTime()/1000 .." / "..self.CurrentAction.Action .. " / " .. self.CurrentAction.Target .. " / ".. self.CurrentAction.Name .. " / " .. self.inst.GUID )

	end

	-- Added
	if (self.CurrentAction ~= nil and self.CurrentAction.Target ~= nil) then
		data.Target = tostring(self.CurrentAction.Target)

	else
		data.Target = "None"
	end

	if self.inst.components.combat.lastattacker ~= nil then
		data.Attacker = self.inst.components.combat.lastattacker.GUID
		data.IsAttacked = true
	else
		data.Attacker = "None"
		data.IsAttacked = false
	end

	data.IsInventoryFull = self.inst.components.inventory:IsFull()

	local equip_hand = self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
	local current_tool = (equip_hand ~= nil) and equip_hand.prefab or nil

	data.HasAxe = self.inst.components.inventory:Has("axe", 1) or current_tool == "axe"
	data.HasPickaxe = self.inst.components.inventory:Has("pickaxe", 1) or current_tool == "pickaxe"
	data.HasSpear = self.inst.components.inventory:Has("spear", 1) or current_tool == "spear"

	data.IsTreeNearby = self:TreeNearby() ~= nil and true or false

	data.Personality = self:GetPersonality()

	data.VisionScore = self:GetVisionScore()
	data.EntityScore = self:GetEntityScore()

	data.IsPlayerNearby = self:IsPlayerNearby()

	data.PosX, data.PosY, data.PosZ = self.inst.Transform:GetWorldPosition()

	data.Node_x, data.Node_y, data.Node_z = nil, nil, nil

	data.Time = tonumber(TheSim:GetRealTime()/1000)

	if Player_character == nil then
		self:SetPlayerCharacter()
	end

	if Player_character ~= nil then
		if self.inst.components.trader:IsTryingToTradeWithMe(Player_character) then
			local p_a = Player_character:GetBufferedAction()
			given_food = p_a.invobject
			--TheNet:SystemMessage(tostring(given_food))
		end
		-- -- 	TheNet:SystemMessage(TheSim:GetRealTime()/1000 .." / "..tostring(p_a.action) .. " / " .. tostring(p_a.target.GUID) .. " / " .. tostring(p_a.inv_obj))
		-- 	TheNet:SystemMessage(tostring(Player_character:GetBufferedAction().invobject.GUID))
		-- 	TheNet:SystemMessage(tostring(self.inst.components.eater:CanEat(Player_character:GetBufferedAction().invobject)))
		-- end

		data.Node_x, data.Node_y, data.Node_z = Player_character.Transform:GetWorldPosition()
		data.Distance = tonumber(self:GetDistance(self.inst, Player_character))
		-- TheNet:SystemMessage("Dist : " .. tostring(data.Distance))

		-- Player's resources
		data.P_HasGrass, data.P_Grass = Player_character.components.inventory:Has("cutgrass", 1)
		data.P_HasTwigs, data.P_Twigs = Player_character.components.inventory:Has("twigs", 1)
		data.P_HasFlint, data.P_Flint = Player_character.components.inventory:Has("flint", 1)
		data.P_HasLog, data.P_Log = Player_character.components.inventory:Has("log", 1)
		data.P_HasRock, data.P_Rock = Player_character.components.inventory:Has("rock", 1)

		-- Collect resources that do not match the resources that players have ( less than 10 )
		local t = {data.P_Log, data.P_Rock, data.P_Flint, data.P_Grass, data.P_Twigs}
		local pt = {}
		local key = next(t)

		for k, v in next, t, nil do
			if v <= 10 then pt[k] = true else pt[k] = false	end
		end

		data.PickLog, data.PickRock, data.PickFlint, data.PickGrass, data.PickTwigs = pt[1], pt[2], pt[3], pt[4], pt[5]
		-- TheNet:SystemMessage("PickTwigs" .. " : " ..  tostring(pt[5]))

		data.Utterance = self.Utterance or "None"
		data.UttAction = self:ClassifyUtterance() or "None"
		TheNet:SystemMessage("UttAction" .. " : " ..  tostring(data.UttAction))


	end

	if Home == nil then
		self:FindValidHome()
	end

	if self.inst.components.follower == nil then
		self:SetLeader()
		self.inst.components.combat:SetKeepTargetFunction(keeptargetfn)
	end

	-- TheNet:SystemMessage("Is Home on Fire : " .. tostring(self:IsHomeOnFire()))

	data.Home = Home.GUID

	if self.inst.components.follower.leader ~= nil then
		data.Leader = self.inst.components.follower.leader.GUID or "None"
	end

	local current_goal = self:GetCurrentGoal(data.Personality, data)

	if Goal ~= current_goal and current_goal ~= nil then
		TheNet:SystemMessage("Goal has been changed : ".. Goal .. " -> " .. current_goal)
		self:ChangeState(data.Personality, Goal)
		Goal = current_goal
		data.Goal = Goal
	else
		data.Goal = Goal
	end

	--local t_angle = math.floor(self.inst.Transform:GetRotation() * 1000) / 1000
	--TheNet:SystemMessage("Angle : " .. t_angle)

	perception_data = data
	-- TheNet:SystemMessage("IsNearDanger : ".. tostring(self.inst.IsNearDanger)) -- function

	-- local note = next(self.inst.components.inventory:GetItemByName("cutgrass", 1))
	-- if note ~= nil then
	-- 	TheNet:SystemMessage(note)
	-- end

    TheSim:QueryServer(
        self.FAtiMAServer .. "/" .. tostring(self.inst.GUID) .. "/perceptions",
        self.PerceptionsCallback,
        "POST",
        json.encode(data))

end

function FAtiMABrain.ReturnPerceptionData()
	return perception_data
end

function FAtiMABrain:Decide(layer)
    TheSim:QueryServer(
        self.FAtiMAServer .. "/" .. tostring(self.inst.GUID) .. "/decide/" ,
        self.DecideCallback,
        "GET")
end

function FAtiMABrain:Speech(layer)
    TheSim:QueryServer(
        self.FAtiMAServer .. "/" .. tostring(self.inst.GUID) .. "/speak" ,
        self.SpeechCallback,
        "GET")
end

function FAtiMABrain:OnActionEndEvent(name, value)

	local d = {}
	d.Type= "Action-End"
	d.Name = name
	d.Value = value
	d.Subject = "Walter"
	TheSim:QueryServer(
        self.FAtiMAServer .. "/" .. tostring(self.inst.GUID) .. "/events",
        self.OnEventCallback,
        "POST",
        json.encode(d))
end

function FAtiMABrain:OnPropertyChangedEvent(name, value)
	local d = {}
	d.Type= "Property-Change"
	d.Name = name
	d.Value = value
	d.Subject = "Walter"
	TheSim:QueryServer(
        self.FAtiMAServer .. "/" .. tostring(self.inst.GUID) .. "/events",
        self.OnEventCallback,
        "POST",
        json.encode(d))
end

function FAtiMABrain:OnDeleteEntity(GUID)
	local d = {}
	d.Type = "Delete-Entity"
	d.Name = ""
	d.Value = GUID
	d.Subject = "Walter"
	TheSim:QueryServer(
        self.FAtiMAServer .. "/" .. tostring(self.inst.GUID) .. "/events",
        self.OnEventCallback,
        "POST",
        json.encode(d))
end

function FAtiMABrain:AddStuckCount()

		if self.CurrentAction ~= nil and not IsWorkAction(self.CurrentAction.Action) then

			if old_pos == Point(self.inst.Transform:GetWorldPosition()) then
				--TheNet:SystemMessage("Same position")
				pos_cnt = pos_cnt + 1
			end

			if self.CurrentAction.Target ~= nil and old_target == self.CurrentAction.Target then
				-- TheNet:SystemMessage("Same target")
				target_cnt = target_cnt + 1
			end

		end

		if self.CurrentAction == nil and old_pos == Point(self.inst.Transform:GetWorldPosition()) then
			-- TheNet:SystemMessage("Sleeping")
			pos_cnt = pos_cnt + 1
		end

		if self.CurrentAction ~= nil and self.CurrentAction.Action == "ATTACK" and not self.inst:IsNear(Ents[tonumber(self.CurrentAction.Target)], 5) then
			--TheNet:SystemMessage("Sleeping")
			pos_cnt = pos_cnt + 1
		end

		if pos_cnt > 15 or target_cnt > 15 then
			-- TheNet:SystemMessage("I'm Stucked")
			self:FixStuckAI()

			self.inst:DoTaskInTime(0.5, function() self:Decide("Behaviour") end)

			pos_cnt = 0
			target_cnt = 0
		end

	--TheNet:SystemMessage("pos_cnt : " .. pos_cnt .. " target_cnt : " .. target_cnt)

	old_pos = Point(self.inst.Transform:GetWorldPosition())
	old_target = self.CurrentAction ~= nil and self.CurrentAction.Target or "-"
end

function FAtiMABrain:CleanStuckCount()
	pos_cnt = 0
	target_cnt = 0
end

function FAtiMABrain:FixStuckAI()
	-- Just reset the whole behaviour tree...that will get us unstuck
	-- inst.brain.bt:Reset()
	--TheNet:SystemMessage("Brain Restart")
	if self.inst.components.locomotor.isrunning then
		self.inst.components.locomotor:StopMoving()
	end

	if self.CurrentAction ~= nil then
		self:OnActionEndEvent(self.CurrentAction.WFN, self.CurrentAction.Target)
	end
	self:OnDeleteEntity(old_target)
	self.CurrentAction = nil

	self:OnStop()
	self:OnStart()

	--TheNet:SystemMessage("Target del : " .. old_target)

end

function FAtiMABrain:Speak(text)
	-- TheNet:SystemMessage(self.inst:GetDebugString())
	TheNet:SystemMessage(text)

end

function FAtiMABrain:ClearAction()
	if self.CurrentAction ~= nil then
		TheNet:SystemMessage("Here" )
		self:OnActionEndEvent(self.CurrentAction.WFN, self.CurrentAction.Target)
		self.CurrentAction = nil
	end
	--TheNet:SystemMessage("Here2")
end

function FAtiMABrain:ItemsNearby()
	local PICKUP_RANGE = 5
	local _x, _y, _z = self.inst.Transform:GetWorldPosition()
    local TAGS = nil
    local EXCLUDE_TAGS = {"INLIMBO", "NOCLICK", "CLASSIFIED", "FX"}
    local ONE_OF_TAGS = nil

	local _ents = TheSim:FindEntities(_x, _y, _z, PICKUP_RANGE, TAGS, EXCLUDE_TAGS, ONE_OF_TAGS)
	local nearby_items = {}

	local j = 1
	for k, v in pairs(_ents) do
		if v:HasTag("pickable") or v.components.stackable ~= nil then
			nearby_items[j] = v
		end
		j = j + 1
	end

	return nearby_items
end

function FAtiMABrain:TreeNearby()
	local tree_see_RANGE = 15
	local _x, _y, _z = self.inst.Transform:GetWorldPosition()
    local TAGS = nil
    local EXCLUDE_TAGS = {"INLIMBO", "NOCLICK", "CLASSIFIED", "FX"}
    local ONE_OF_TAGS = nil

	local _ents = TheSim:FindEntities(_x, _y, _z, tree_see_RANGE, TAGS, EXCLUDE_TAGS, ONE_OF_TAGS)
	local nearby_tree = nil

	local j = 1
	for k, v in pairs(_ents) do
		if v:HasTag("CHOP_workable") then
			nearby_tree = v
		end
		j = j + 1
	end

	return nearby_tree
end

function FAtiMABrain:DoPincers()
	if Player_character.components.combat.target ~= nil then
		Player_character.components.combat.target = self.inst.components.combat.target
	end
end

function FAtiMABrain:Attack(target)
	-- TheNet:SystemMessage('Attack!')
	self:CleanStuckCount()
	if self.inst.components.combat.target == nil then
		return
	end

	if self.CurrentAction == nil or self.CurrentAction.Action ~= "ATTACK" then
		self.CurrentAction = {}
		self.CurrentAction.Type = "Action"
		self.CurrentAction.Action = "ATTACK"
		self.CurrentAction.Target = self.inst.components.combat.target.GUID
		self.CurrentAction.Name = "Action(ATTACK, -, -, -, -)"
		self.CurrentAction.WFN = "Action(ATTACK, -, -, -, -)"
		self.CurrentAction.InvObject = "-"
		self.CurrentAction.Recipe = "-"
		self.CurrentAction.PosX = "-"
		self.CurrentAction.PosZ = "-"
	end

	if target == nil then
		target = self.inst.components.combat.target.GUID
	end

	local t = BufferedAction(
		self.inst,
		Ents[tonumber(target)],
		ACTIONS.ATTACK)

		t:AddFailAction(function()
			-- TheNet:SystemMessage('fail?')

			if self.inst.components.combat.target ~= nil then
				if self.inst.components.combat:CanAttack(self.inst.components.combat.target) then
					return
				else
					self:CleanStuckCount()
					self.inst.components.combat:DropTarget()
					self:OnDeleteEntity(self.CurrentAction.Target)
					self.inst.components.combat.lastattacker = nil
					self.CurrentAction = nil
				end
			end
		end)

		t:AddSuccessAction(function()
			-- TheNet:SystemMessage('Succ?')

			--if not self.inst.replica.combat:IsValidTarget(attack_target) then
			if self.inst.components.combat.target == nil then
				-- Target no longer exists
				-- TheNet:SystemMessage("Target no longer exists")
				self:CleanStuckCount()
				self.inst.components.combat:DropTarget()
				self:OnDeleteEntity(self.CurrentAction.Target)
				self:OnActionEndEvent(self.CurrentAction.WFN, self.CurrentAction.Target)
				self.inst.components.combat.lastattacker = nil
				self.CurrentAction = nil
			end
		end)
	return t
end

function FAtiMABrain:UnEquip()
	local equipped =  self.inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
	local inv = Ents[tonumber(self.CurrentAction.InvObject)]

	if equipped == inv then
		--TheNet:SystemMessage('UnEquip tool')
		local e = BufferedAction(
			self.inst,
			Ents[tonumber(self.CurrentAction.Target)],
			ACTIONS.UNEQUIP,
			inv)

			e:AddSuccessAction(function()
				--TheNet:SystemMessage('Success to UnEquip')
				self.CurrentAction = nil
			end)

		return e
	end
end

function FAtiMABrain:Build()
	-- Avoid to bulid duplicate tools
	local recipe = self.CurrentAction.Recipe

    local num_found = 0
    for k, v in pairs(self.inst.components.inventory.itemslots) do
        if v and v.prefab == recipe then
                num_found = num_found + 1
        end
    end

	for k, v in pairs(self.inst.components.inventory.equipslots) do
        if v and v.prefab == recipe then
                num_found = num_found + 1
        end
    end

	--TheNet:SystemMessage('num_found : ' .. " / ".. num_found)

	if num_found < 1 then

		local b = BufferedAction(
			self.inst,
			Ents[tonumber(self.CurrentAction.Target)],
			ACTIONS.BUILD,
			Ents[tonumber(self.CurrentAction.InvObject)],
			nil,
			recipe
		)

			b:AddSuccessAction(function()
				--TheNet:SystemMessage('Success to Build')
				self.CurrentAction = nil
			end)

		return b
	else
		self.CurrentAction = nil
	end
end

function FAtiMABrain:Pick()
	local _ents = self:ItemsNearby()
	if _ents == nil then
		return nil
	end
	-- It's available to change best target from here to use built-in function

	for k, v in pairs(_ents) do
		if v:IsValid() then
			local act = v:HasTag("pickable") and "PICK" or "PICKUP"

			if not self.inst.components.inventory:IsFull() then
				--TheNet:SystemMessage('HAVE TO PICKUP'.. " / " .. tostring(act) .. " / ".. tostring(v.prefab))

				local p = BufferedAction(
					self.inst,
					Ents[tonumber(v.GUID)],
					ACTIONS[act]
					)

					p:AddSuccessAction(function()
						self:OnDeleteEntity(tonumber(v.GUID))

						if self:ItemsNearby() == nil then
							self.CurrentAction = nil
						end
					end)

					p:AddFailAction(function()
						self:OnDeleteEntity(tonumber(v.GUID))
						self.CurrentAction = nil

					end)

				return p
			else
				-- TheNet:SystemMessage('Inventory is full')
				self.CurrentAction = nil
			end
		end
	end
end

function FAtiMABrain:Chop()
	--TheNet:SystemMessage('Chop Chop')
	-- local SEE_TREE_DIST = 10
	-- local CHOP_MUST_TAGS = { "CHOP_workable" }
	-- local chop_target = FindEntity(self.inst, SEE_TREE_DIST, nil, CHOP_MUST_TAGS)

	local c = BufferedAction(
		self.inst,
		Ents[tonumber(self.CurrentAction.Target)],
		ACTIONS.CHOP)

		c:AddSuccessAction(function()
			--TheNet:SystemMessage('Chop Suss')
			if self.CurrentAction and self.CurrentAction.Target ~= "-" and Ents[tonumber(self.CurrentAction.Target)] == nil then
				-- Target no longer exists
				self:OnDeleteEntity(self.CurrentAction.Target)
			end

			if not KeepWorking(self.inst, self.CurrentAction.Action, self.CurrentAction.Target) then
				self:OnActionEndEvent(self.CurrentAction.WFN, self.CurrentAction.Target)
				self.CurrentAction = nil
				-- TheNet:SystemMessage('Chop Done')
			end
		end)

		c:AddFailAction(function()
			--TheNet:SystemMessage('Chop fail')

			if KeepWorking(self.inst, self.CurrentAction.Action, self.CurrentAction.Target) then
				return
			end
		end)
	return c
end

function FAtiMABrain:Give()
	if self.inst.components.follower.leader ~= nil then
		local flag, item_GUID = self:CheckItemToGive()

		if flag then
			local c = BufferedAction(
				self.inst,
				self.inst.components.follower.leader,
				ACTIONS.DROP,
				item_GUID
			)
			c:AddSuccessAction(function()
				self.CurrentAction = nil
				self.Utterance = nil
				
			end)
			c:AddFailAction(function()
				self.CurrentAction = nil
			end)
			return c
		else
			self.inst.components.talker:Say("Sorry, I don't have enough items.")
		end
		self.CurrentAction = nil
	end
end


function FAtiMABrain:GetCurrentSearchDistance()
	return CurrentSearchDistance
end

function FAtiMABrain:IsOtherPlayer()
	local res = true
	if #AllPlayers ~= 2 then
		res = false
	end
	return res
end

function FAtiMABrain:SetPlayerCharacter()

	if self:IsOtherPlayer() == true and Player_character == nil then
		local x, y, z = self.inst.Transform:GetWorldPosition()
		local players = FindPlayersInRange(x, y, z, 10000, true)

		for i, v in pairs(AllPlayers) do
			if v.GUID ~= self.inst.GUID then
				Player_character = v
				--TheNet:SystemMessage(tostring(Player_character))
			end
		end
		return true
	else
		return false
	end
end

function FAtiMABrain:GetDistance(p1, p2)
	if p2 ~= nil then
		return tonumber(p1:GetDistanceSqToInst(p2))
	end
end

function FAtiMABrain:IsPlayerNearby()
	return PLAYERNEARBY
end

function FAtiMABrain:SetLeader()
	if self.inst.components.follower == nil then
		self.inst:AddComponent("follower")
	end

	if Player_character ~= nil then
		self.inst.components.follower:SetLeader(Player_character)
		--TheNet:SystemMessage('You are the LEADER!')
	end
end

function FAtiMABrain:PlayerBufferedAction()
	local p = Player_character
	if p ~= nil then
		if p:GetBufferedAction() ~= nil then
			local p_action = p:GetBufferedAction()
			return p_action
		end
	end
end

function FAtiMABrain:IsPlayerHasResource(item, amount)
	local p = Player_character
	if p ~= nil then
		return p.components.inventory:Has(item, amount)
	end
end


function FAtiMABrain:VisionScore()
	local px, py, pz = self.inst.Transform:GetWorldPosition()
	local c_node = GetClosestNode(px, pz)

	local node_dist = distsq(px, pz, c_node.x, c_node.y)

	if node_dist < 100 and visited_nodes[c_node] ~= true then
		node_cnt = node_cnt + 1
		visited_nodes[c_node] = true
		-- TheNet:SystemMessage("Vision score : " .. tostring(node_cnt))
	end
end

function FAtiMABrain:GetVisionScore()
	return node_cnt
end

function FAtiMABrain:GetEntityScore()
 	return entity_cnt
end

function FAtiMABrain:SetWanderPoint()
	if Player_character then
		-- TheNet:SystemMessage("SET wander point")
		return Player_character:GetPosition()
	else
		return nil
	end
end

function FAtiMABrain:TeleportToPlayer()
	if Player_character then
		--TheNet:SystemMessage('Too far away!')
		self.inst.Physics:Teleport(Player_character.Transform:GetWorldPosition())
		--TheNet:SystemMessage('I\'m Here!')
	else
		return nil
	end
end

local function GetTraderFn(inst)
	if Player_character then
		return Player_character
	end
end

local function KeepTraderFn(inst, target)
    return inst.components.trader:IsTryingToTradeWithMe(target)
end


local function ShouldAcceptItem(inst, item)
    if item.components.equippable ~= nil and item.components.equippable.equipslot == EQUIPSLOTS.HANDS then
        return true
    elseif inst.components.eater:CanEat(item) then
        return true
	elseif item.components.stackable ~= nil then
		return true
    end
end

local function OnGetItemFromPlayer(inst, giver, item)
    --Eat given food
    if item.components.edible ~= nil then
		if inst.components.eater:CanEat(item) then
			inst.components.eater:Eat(item)
		end
    --     --meat makes us friends (unless I'm a guard)
    --     if (    item.components.edible.foodtype == FOODTYPE.MEAT ) and
    --         item.components.inventoryitem ~= nil and
    --         (   --make sure it didn't drop due to pockets full
    --             item.components.inventoryitem:GetGrandOwner() == inst or
    --             --could be merged into a stack
    --             (   not item:IsValid() and
    --                 inst.components.inventory:FindItem(function(obj)
    --                     return obj.prefab == item.prefab
    --                         and obj.components.stackable ~= nil
    --                         and obj.components.stackable:IsStack()
    --                 end) ~= nil)
    --         ) then
    --         if inst.components.combat:TargetIs(giver) then
    --             inst.components.combat:SetTarget(nil)
    --         elseif giver.components.leader ~= nil then
    --             inst.components.follower:AddLoyaltyTime(item.components.edible:GetHunger())
    --         end
    --     end
    end

    -- Equip given tools
    if item.components.equippable ~= nil and item.components.equippable.equipslot == EQUIPSLOTS.HANDS then
        local current = inst.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS)
        if current ~= nil then
            --inst.components.inventory:DropItem(current)
			inst.components.inventory:Unequip(current)
        end
        inst.components.inventory:Equip(item)
        inst.AnimState:Show("hat")
    end
end

function FAtiMABrain:EatFoodAction()
	-- local food = self.inst.components.inventory:FindItem(function(item) return self.inst.components.eater:CanEat(item) end)
	TheNet:SystemMessage(tostring(given_food))
	local food = given_food

	if food ~= nil then
		TheNet:SystemMessage(tostring(food.GUID))

		local e = BufferedAction(
			self.inst,
			Ents[tonumber(food.GUID)],
			ACTIONS.EAT)

			e:AddSuccessAction(function()
				self:OnActionEndEvent('Action(EAT, -, -, -, -)', tonumber(food.GUID))
				self.CurrentAction = nil
			end)

			e:AddFailAction(function()
				self.CurrentAction = nil
			end)

		given_food = nil
		return e
	end
end

function FAtiMABrain:Isfood()
	if given_food then
		-- TheNet:SystemMessage(tostring(given_food.GUID))
		-- TheNet:SystemMessage(tostring(self.inst.components.eater:CanEat(given_food)))
		return self.inst.components.eater:CanEat(given_food)
	end
end


function FAtiMABrain:PlayerWatcher()
	-- when player give item to AI, AI response with that
	if Player_character then
		local p_action = Player_character:GetBufferedAction()
	end
end

function FAtiMABrain:GoHomeAction()
    if self:HasHome() then
        return BufferedAction(self.inst, self.inst.components.homeseeker.home, ACTIONS.GOHOME)
    end
end

function FAtiMABrain:OnStart()

	print('Brain Start!')
	--TheNet:SystemMessage('Brain Start!')

	self:CleanStuckCount()

	self.inst.entity:SetCanSleep(false)

	-----------------------
    -------- Trader -------
    -----------------------
	self.inst.components.trader:Enable()
	self.inst.components.trader:SetAcceptTest(ShouldAcceptItem)
	self.inst.components.trader.onaccept = OnGetItemFromPlayer
	self.inst.components.trader.deleteitemonaccept = false


    -----------------------
    ----- Deliberator -----
    -----------------------
    --self.CurrentAction = nil
	self.inst.components.combat.lastattacker = nil

    -----------------------
    ----- Range Helper ----
    -----------------------
    AddSeeRangeHelper(self.inst)

    -----------------------
    ---- Player Checker ---
    -----------------------
	if Player_character == nil then
		self:SetPlayerCharacter()
	end

	if self:IsOtherPlayer() then
		--TheNet:SystemMessage('New Player!')

		-- check player's position on period (20 ~ 30sec)?
		-- and cal current distance between AI - player
		self:SetPlayerCharacter()

		if self.TrackingPlayerTask ~= nil then
			self.TrackingPlayerTask:Cancel()
		end

		self.TrackingPlayerTask = self.inst:DoPeriodicTask(CHECK_DISTANCE_INTERVAL, self.UpdatePlayerDist, 0)
	end

    -----------------------
    ----- Personality -----
    -----------------------
	self:SetPersonalityParms(self:GetPersonality())

    -----------------------
    ----- Perceptions -----
    -----------------------
    if self.PerceptionsTask ~= nil then
        self.PerceptionsTask:Cancel()
    end
    -- DoPeriodicTask(interval, fn, initialdelay, ...) the extra parameters are passed to fn
    self.PerceptionsTask = self.inst:DoPeriodicTask(PERCEPTION_UPDATE_INTERVAL, self.OnPerceptions, 0)

    -----------------------
    -------- Decide -------
    -----------------------
	if self.DSTActionTask ~= nil then
        self.DSTActionTask:Cancel()
    end
    self.DSTActionTask = self.inst:DoPeriodicTask(DSTACTION_INTERVAL, self.OnDSTActionDecide, 0)
	-- print(self.DSTActionTask) -- PERIODIC 114951: 1.500000

	if self.SpeakActionTask ~= nil then
		self.SpeakActionTask:Cancel()
	end

	if GetModConfigData("Enable Speech", KnownModIndex:GetModActualName("The AI Companion"))  == 1 then -- 0 for OFF, 1 for ON
		self.SpeakActionTask = self.inst:DoPeriodicTask(SPEAKACTION_INTERVAL, self.OnSpeakActionDecide, 0)
	end

	if self.visiontask ~= nil then
		self.visiontask:Cancel()
	end
	self.visiontask = self.inst:DoPeriodicTask(1, self.UpdateVisionScore, 0)

	-- print(self.inst:GetBasicDisplayName())
	-- print(self.inst:GetDebugString())

    -----------------------
    --- Event Listeners ---
    -----------------------
	-- EntityScript:ListenForEvent(event, fn, source)
	self.inst:ListenForEvent("killed", self.OnKilled)
	self.inst:ListenForEvent("attacked", self.OnAttacked)
	self.inst:ListenForEvent("death", self.OnDeath)
	self.inst:ListenForEvent("onmissother", self.OnMissOther)
	self.inst:ListenForEvent("onhitother", self.OnHitOther)

    -----------------------
    ---- World Watchers ---
    -----------------------
	-- EntityScript:ListenForEvent(event, fn, source)
	self.inst:ListenForEvent("enterdark", self.OnEnterDark)
	self.inst:ListenForEvent("enterlight", self.OnEnterLight)
	self.inst:ListenForEvent("clocksegschanged", self.OnClockSegsChanged, TheWorld)
	self.inst:ListenForEvent("clocktick", self.OnClockTick, TheWorld) -- this is called so often there is no need to initialize
	-- EntityScript:WatchWorldState(var, fn)
	self.inst:WatchWorldState("cycles", self.OnCycles)
	self.inst:WatchWorldState("phase", self.OnPhase)
	self.inst:WatchWorldState("moonphase", self.OnMoonPhase)
	self.inst:WatchWorldState("season", self.OnSeason)
	self.inst:WatchWorldState("seasonprogress", self.OnSeasonProgress)
	self.inst:WatchWorldState("elapseddaysinseason", self.OnElapsedDaysInSeason)
	self.inst:WatchWorldState("remainingdaysinseason", self.OnRemainingDaysInSeason)
	self.inst:WatchWorldState("springlength", self.OnSpringLenght)
	self.inst:WatchWorldState("summerlength", self.OnSummerLength)
	self.inst:WatchWorldState("autumnlength", self.OnAutumnLenght)
	self.inst:WatchWorldState("winterlength", self.OnWinterLenght)
	self.inst:WatchWorldState("issnowing", self.OnIsSnowing)
	self.inst:WatchWorldState("israining", self.OnIsRaining)

	-- Registered listeners to tell FAtiMA about changes, now let's tell FAtiMA the initial values
	self.OnClockSegsChanged(self.inst, TheWorld.net.components.clock:OnSave().segs)
		if self.inst.LightWatcher:IsInLight() then
			self.OnEnterLight(self.inst, nil)
		else
			self.OnEnterDark(self.inst, nil)
	end
	self.OnCycles(self.inst, TheWorld.state.cycles)
	self.OnPhase(self.inst, TheWorld.state.phase)
	self.OnMoonPhase(self.inst, TheWorld.state.moonphase)
	self.OnSeason(self.inst, TheWorld.state.season)
	self.OnSeasonProgress(self.inst, TheWorld.state.seasonprogress)
	self.OnElapsedDaysInSeason(self.inst, TheWorld.state.elapseddaysinseason)
	self.OnRemainingDaysInSeason(self.inst, TheWorld.state.remainingdaysinseason)
	self.OnSpringLength(self.inst, TheWorld.state.springlength)
	self.OnSummerLength(self.inst, TheWorld.state.summerlength)
	self.OnAutumnLength(self.inst, TheWorld.state.autumnlength)
	self.OnWinterLength(self.inst, TheWorld.state.winterlength)
	self.OnIsSnowing(self.inst, TheWorld.state.issnowing)
	self.OnIsRaining(self.inst, TheWorld.state.israining)

    -----------------------
    -------- Brain --------
    -----------------------
	-- BufferedAction(doer, target, action, invobject, pos, recipe, distance, forced, rotation)



	local ClearAction_node = PriorityNode({
				IfNode(function() return(self.CurrentAction ~= nil) end, "Clear",
					DoAction(self.inst, function() return self:ClearAction() end, "Clear", true))})

	local Attacked_node = PriorityNode(
		{

		IfNode(function() return (Player_character.components.combat.target ~= nil) end,  "attack",
			DoAction(self.inst, function() return self:Attack() end, "DoAction", true)),

		-- WhileNode( function() return self.inst.components.combat.target and self.inst.components.combat:InCooldown() end, "Dodge",
		-- 	RunAway(self.inst, function() return self.inst.components.combat.target end, 3, 5)),

		WhileNode(function() return (self.inst.components.combat.target ~= nil and self.inst:IsNear(self.inst.components.combat.target, 5)) end, "Dodge",
			RunAway(self.inst, function() return self.inst.components.combat.target end, 6, 10)),

		IfNode(function() return (self.inst.components.combat.target ~= nil) end,  "attack",
							DoAction(self.inst, function() return self:Attack() end, "DoAction", true))
							-- ChaseAndAttack(self.inst, 30))
		}
	)

	local Runaway_node = PriorityNode(
		{
		WhileNode(function() return (self.inst.components.combat.lastattacker ~= nil
			and self.inst:IsNear(Ents[tonumber(self.inst.components.combat.lastattacker.GUID)], 5)
					and self.inst.components.health.currenthealth < 50) end, "IfAction",
		RunAway(self.inst, "hostile", RUN_AWAY_DIST, STOP_RUN_AWAY_DIST)),

		}
	)

	local Unequip_node = PriorityNode(
		{
			IfNode(function() return (self.CurrentAction ~= nil and self.CurrentAction.Action == "UNEQUIP") end, "UnEquip",
				DoAction(self.inst, function() return self:UnEquip() end, "DoAction", true))
		}
	)

	local Build_node = PriorityNode(
		{
			IfNode(function() return (self.CurrentAction ~= nil and self.CurrentAction.Action == "BUILD") end, "Build",
				DoAction(self.inst, function() return self:Build() end, "DoAction", true))
		}
	)

	local Pickup_node =
		-- This node currently not used
		PriorityNode(
		{
			IfNode(function() return (self.CurrentAction ~= nil and self.CurrentAction.Action == "PICK" or self.CurrentAction.Action == "PICKUP") end, "PICK",
			DoAction(self.inst, function() return self:Pick() end, "DoAction", true))
		}
	)

	local Chop_node =
		PriorityNode({

			IfNode(function() return (self:ItemsNearby() ~= nil) end, "pick",
				DoAction(self.inst, function() return self:Pick() end, "DoAction", true)),

			IfNode(function() return (self.CurrentAction ~= nil and self.CurrentAction.Action == "CHOP") end, "CHOP",
				DoAction(self.inst, function() return self:Chop() end, "DoAction", true))
		})

	local Give_node =
		PriorityNode({
			IfNode(function() return (self.CurrentAction ~= nil and self.CurrentAction.Action == "GIVETOPLAYER") end, "GIVE",
				DoAction(self.inst, function() return self:Give() end, "DoAction", true))
		})

	local stuck_node = DoAction(self.inst, function() self:AddStuckCount() end, "CountStuck", true)

	local Tracking_node = WhileNode(function() return (Player_character ~= nil and
									tonumber(self:GetDistance(self.inst, Player_character)) > tonumber(max_p_dist)) end, 'Tracking',
							PriorityNode({
									DoAction(self.inst, function() return self:ClearAction() end, "DoAction", true),
									Approach(self.inst, Player_character, 10, true)})
								)

	local Travel_node = WhileNode(function() return (self.CurrentAction ~= nil and self.CurrentAction.Type == "Action" and self.CurrentAction.Action == "TRAVEL") end, 'Travel',
	--local Travel_node = WhileNode(function() return ( self.Goal == 3) end, 'Travel',

		Wander(self.inst,
		self:SetWanderPoint(), -- If nil, the entity won't be leashed to their home
		max_w_dist, -- maximum distance to go away from home (if there is a home)
		{ --  if the walk time is too long, the entity will merely stand still after reaching their target point
			minwalktime = 1,
			randwalktime = .5,
			minwaittime = 1,
			randwaittime = .5,
		},
		GetWanderDirection -- instead of picking a random direction, try to use the one returned by this function
		--SetWanderDirection -- use this to store the direction that was randomly chosen
				)
		)

	local OnFire_node = PriorityNode(
		{
			WhileNode(function() return self.inst.components.health.takingfiredamage end, "OnFire",
			ChattyNode(self.inst, "PIG_TALK_PANICFIRE",
				Panic(self.inst)))
		}
	)

	local Follow_node = PriorityNode({
		--DoAction(self.inst, function() return self:Speak("000") end, "DoAction", true),

		IfNode(function() return (self.inst:IsNear(self.inst.components.follower.leader, 20) == false and self.CurrentAction == nil) end, "ClearAction",
			SequenceNode{
				Follow(self.inst, function() return self.inst.components.follower.leader end, 2, 1, 20),
				WaitNode(math.random(1,6)),
				StandStill(self.inst),
				IfNode(function() return self.inst:IsNear(self.inst.components.follower.leader, 3) end, "ClearAction",
						DoAction(self.inst, function() return self:ClearAction() end, "DoAction", true))}),

		-- TO give item, AI should come close to the player. This line allow to keep giving item
		WhileNode(function() return (self.inst:IsNear(self.inst.components.follower.leader, 2) and self.CurrentAction ~= nil and self.CurrentAction.Action == "DROP") end, "FaceLeader",
			SequenceNode{
				FaceEntity(self.inst, GetFaceTargetFn, KeepFaceTargetFn),
				IfNode(function() return(self.CurrentAction ~= nil and not self.inst:IsNear(self.CurrentAction.Target, 4) ) end, "Clear",
					DoAction(self.inst, function() return self:ClearAction() end, "Clear", true))
				})
			}
		)

	local Teleport_node = PriorityNode({
		IfNode(function() return (Player_character ~= nil and tonumber(self:GetDistance(self.inst, Player_character)) > tonumber(1500)) end, "Wormhole",
			SequenceNode{
				DoAction(self.inst, function() return self:ClearAction() end, "Clear", true),
				DoAction(self.inst, function() return self:TeleportToPlayer() end, "Teleport", true),
				StandStill(self.inst),
				WaitNode(5)
				}
			)
	})

	local Trade_node = PriorityNode({
		IfNode(function() return (Player_character ~= nil and KeepTraderFn(self.inst, Player_character)) end, "Trade",
		SequenceNode{
			Follow(self.inst, function() return self.inst.components.follower.leader end, 0, 1, 3),
			--FaceEntity(self.inst, GetTraderFn, KeepTraderFn),
			WaitNode(0.5)
			-- IfNode(function() return self:Isfood() end, "Eat",
			-- 	DoAction(self.inst, function() return self:EatFoodAction() end, "DoAction", true))
		})
	})

	local Speak_node =  PriorityNode({

		IfNode(function() return (self.UttAction ~= nil and self.UttAction == "Follow") end, 'Follow',
					SequenceNode{
						Follow(self.inst, function() return self.inst.components.follower.leader end, 0, 1, 3),
						DoAction(self.inst, function() return self:ClearAction() end, "Clear", true),
						StandStill(self.inst)
						}
					),
		IfNode(function() return (self.UttAction ~= nil and self.UttAction == "Goaway") end, 'Moveback',
					SequenceNode{
						DoAction(self.inst, function() return self:ClearAction() end, "Clear", true),
						RunAway(self.inst, Player_character, RUN_AWAY_DIST, STOP_RUN_AWAY_DIST)
						}
					),
		IfNode(function() return (self.UttAction ~= nil and self.UttAction == "Stop" ) end, 'Stop',
					WhileNode(function() return self.UttAction ~= nil and self.UttAction == "Stop" end, "Stop",
						SequenceNode{
							DoAction(self.inst, function() return self:ClearAction() end, "Clear", true),
							StandStill(self.inst)
							}
						)
					),
		IfNode(function() return (self.UttAction ~= nil and self.UttAction == "Approach") end, 'Approach',
					SequenceNode{
						Approach(self.inst, Player_character, 10, true),
						StandStill(self.inst)
						}
					),
		IfNode(function() return (self:HasHome() and self.UttAction ~= nil and self.UttAction == "GoHome") end, 'GoHome',
					WhileNode(function() return self.inst:GetDistanceSqToInst(self.inst.components.homeseeker.home) < 50 end, "GoHome",
						DoAction(self.inst, function() return self:GoHomeAction() end, "go home", true)
						)
					),
		IfNode(function() return (self.UttAction ~= nil and self.UttAction == "Wander") end, 'Wander',
					WhileNode(function() return self.UttAction ~= nil and self.UttAction == "Wander" end, "Wander",
						Wander(self.inst, nil, nil, { minwalktime = 20, randwalktime = 40, minwaittime = 1,	randwaittime = 2})
						)
					),
		IfNode(function() return (self.UttAction ~= nil and self:IsGiveAction()) end, 'Give',
					WhileNode(function() return self:CheckItemToGive() end, "Give",
					    DoAction(self.inst, function() return self:Give() end, "DoAction", true)
					    )
					),
		IfNode(function() return (self.UttAction ~= nil and self.UttAction == "Attack") end, 'Attack',
					IfNode(function() return (Player_character.components.combat.target ~= nil) end,  "attack",
						DoAction(self.inst, function() return self:Attack(Player_character.components.combat.target.GUID) end, "DoAction", true)
					)
				)
			})


	local root = 
		-- PriorityNode 
		-- -> Class in behaviortree.lua
        PriorityNode(
        {
			Speak_node,
			Teleport_node,
			Follow_node,		
			Travel_node,
			Attacked_node,
			-- Runaway_node,
			OnFire_node,
			Trade_node, 
			

			-- IfNode(function() return (self:ItemsNearby() ~= nil) end, "pick",
			-- DoAction(self.inst, function() return self:Pick() end, "DoAction", true)),

			IfNode(function() return (self.CurrentAction ~= nil and self.CurrentAction.Action == "CHOP") end, "CHOP",
			Chop_node),

			IfNode(function() return (self.CurrentAction ~= nil and self.CurrentAction.Action == "GIVETOPLAYER") end, "GIVE",
			Give_node),

            IfNode(function() return (self.CurrentAction ~= nil and self.CurrentAction.Type == "Action" and self.CurrentAction.Action ~= "WANDER") end, "IfAction",
                DoAction(self.inst, 
					-- BufferedAction(Doer, Target, Action, InvObject, Pos, Recipe)
					-- -> bufferedaction.lua 
					function() 
						local b = BufferedAction(
							self.inst, -- doer
							Ents[tonumber(self.CurrentAction.Target)], -- target
							ACTIONS[self.CurrentAction.Action], -- action
							Ents[tonumber(self.CurrentAction.InvObject)], -- Invobject
							(self.CurrentAction.PosX ~= "-" and Vector3(tonumber(self.CurrentAction.PosX), tonumber(self.CurrentAction.PosY), tonumber(self.CurrentAction.PosZ)) or nil),
							(self.CurrentAction.Recipe ~= "-") and self.CurrentAction.Recipe or nil)

						-- function BufferedAction:AddFailAction(fn)
						-- 			table.insert(self.onfail, fn)	
						b:AddFailAction(function() 
							-- TheNet:SystemMessage("F" .. self.CurrentAction.Target)
							if self.CurrentAction and IsWorkAction(self.CurrentAction.Action) then

								if KeepWorking(self.inst, self.CurrentAction.Action, self.CurrentAction.Target) then
									self:CleanStuckCount()
									-- if chop, dig etc,, return True else False 
									return
								end
							end

							if self.CurrentAction then 
								self:OnActionEndEvent(self.CurrentAction.WFN, self.CurrentAction.Target)
							end

							self.CurrentAction = nil 
							self.Utterance = nil 
						end)

						-- function BufferedAction:AddSuccessAction(fn)
    					-- 			table.insert(self.onsuccess, fn)
						b:AddSuccessAction(function() 
							--TheNet:SystemMessage("S B Act " .. b:__tostring().. " // " .. "S C Act " .. self.CurrentAction.Action)
							--TheNet:SystemMessage("S")

							-- If the target of the action ceases to exist, we need to inform FAtiMA
							-- applyable for both working actions and not working actions
							if self.CurrentAction and self.CurrentAction.Target ~= "-" and Ents[tonumber(self.CurrentAction.Target)] == nil then
								-- Target no longer exists
								self:OnDeleteEntity(self.CurrentAction.Target)
							end

							-- Working actions we want to keep executing until the target is not workable anymore
							if self.CurrentAction and IsWorkAction(self.CurrentAction.Action) then

								if not KeepWorking(self.inst, self.CurrentAction.Action, self.CurrentAction.Target) then
									self:OnActionEndEvent(self.CurrentAction.WFN, self.CurrentAction.Target)
									self.CurrentAction = nil
									self.Utterance = nil 
								end
								self:AddStuckCount()

							else
								if self.CurrentAction then
									self:OnActionEndEvent(self.CurrentAction.WFN, self.CurrentAction.Target)
									self:OnDeleteEntity(self.CurrentAction.Target)
								end

								self.CurrentAction = nil
								self.Utterance = nil 
								self:CleanStuckCount()
							end
							
						end)
						return b
					end, 
					"DoAction", 
					true)
				-- Close DoAction
			),
			stuck_node,

			WhileNode(function() return (self.CurrentAction ~= nil and self.CurrentAction.Type == "Action" and self.CurrentAction.Action == "WANDER")  end, "Wander",
			Wander(self.inst, nil, nil, { minwalktime = 20, randwalktime = 40, minwaittime = 1,	randwaittime = 2})				
			)

        }, 1)
    self.bt = BT(self.inst, root)
end

function FAtiMABrain:OnStop()
    -----------------------
    ----- Range Helper ----
    -----------------------
    if SEE_RANGE_HELPER then
        self.inst.seerangehelper:Remove()
        self.inst.seerangehelper = nil
    end
    -----------------------
    ----- Perceptions -----
    -----------------------
    if self.PerceptionsTask ~= nil then
        self.PerceptionsTask:Cancel()
        self.PerceptionsTask = nil
    end
    -----------------------
    -------- Decide -------
    -----------------------
	if self.DSTActionTask ~= nil then
        self.DSTActionTask:Cancel()
		self.DSTActionTask= nil
    end
	
	if self.SpeakActionTask ~= nil then
		self.SpeakActionTask:Cancel()
		self.SpeakActionTask = nil
	end

	if self.visiontask ~= nil then
		self.visiontask:Cancel()
		self.visiontask = nil
	end

    -----------------------
    --- Event Listeners ---
    -----------------------
	self.inst:RemoveEventCallback("killed", self.OnKilled)
	self.inst:RemoveEventCallback("attacked", self.OnAttacked)
	self.inst:RemoveEventCallback("death", self.OnDeath)
	self.inst:RemoveEventCallback("onmissother", self.OnMissOther)
	self.inst:RemoveEventCallback("onhitother", self.OnHitOther)

	-----------------------
    ---- World Watchers ---
    -----------------------
	self.inst:RemoveEventCallback("enterdark", self.OnEnterDark)
	self.inst:RemoveEventCallback("enterlight", self.OnEnterLight)
	self.inst:RemoveEventCallback("clocksegschanged", self.OnClockSegsChanged, TheWorld)
	self.inst:RemoveEventCallback("clocktick", self.OnClockTick, TheWorld)
	self.inst:StopWatchingWorldState("cycles", self.OnCycles)
	self.inst:StopWatchingWorldState("phase", self.OnPhase)
	self.inst:StopWatchingWorldState("moonphase", self.OnMoonPhase)
	self.inst:StopWatchingWorldState("season", self.OnSeason)
	self.inst:StopWatchingWorldState("seasonprogress", self.OnSeasonProgress)
	self.inst:StopWatchingWorldState("elapseddaysinseason", self.OnElapsedDaysInSeason)
	self.inst:StopWatchingWorldState("remainingdaysinseason", self.OnRemainingDaysInSeason)
	self.inst:StopWatchingWorldState("springlength", self.OnSpringLenght)
	self.inst:StopWatchingWorldState("summerlength", self.OnSummerLength)	
	self.inst:StopWatchingWorldState("autumnlength", self.OnAutumnLenght)
	self.inst:StopWatchingWorldState("winterlength", self.OnWinterLenght)
	self.inst:StopWatchingWorldState("issnowing", self.OnIsSnowing)
	self.inst:StopWatchingWorldState("israining", self.OnIsRaining)

	self.inst.entity:SetCanSleep(true)
end

return FAtiMABrain