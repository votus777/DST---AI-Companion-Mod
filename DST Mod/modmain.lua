-- Debug Helpers
GLOBAL.CHEATS_ENABLED = true
GLOBAL.DEBUG_MENU_ENABLED = true
GLOBAL.require 'debugkeys' 
GLOBAL.require 'debughelpers'

io = GLOBAL.io
local io =  GLOBAL.require "io"
local os = GLOBAL.require "os"
graph_data = MODROOT.."graph_data.csv"

local graph_switch = GetModConfigData("Enable Showing Graph") -- 0 for OFF, 1 for ON 
local header = ""
local dt = nil

local ArtificalWalterEnabled = false

local function SetSelfAI()
	local brain = GLOBAL.require "brains/fatimabrain"
	GLOBAL.ThePlayer:SetBrain(brain)
	GLOBAL.ThePlayer:RestartBrain()
	ArtificalWalterEnabled = true
end

local function SetSelfNormal()
	local brain = GLOBAL.require "brains/wilsonbrain"
	GLOBAL.ThePlayer:SetBrain(brain)
	GLOBAL.ThePlayer:RestartBrain()
	ArtificalWalterEnabled = false
end

local function MakeClickableBrain(self, owner)
	local BrainBadge = self
	
    BrainBadge:SetClickable(true)

    -- Make the brain pulse for a cool effect
	local x = 0
	local darker = true
	local function BrainPulse(self)
		if not darker then
			x = x+.1
			if x >=1 then
				darker = true
				x = 1
			end
		else 
			x = x-.1
			if x <=.5 then
				darker = false
				x = .5
			end
		end

		BrainBadge.anim:GetAnimState():SetMultColour(x,x,x,1)
		self.BrainPulse = self:DoTaskInTime(.15, BrainPulse)
	end
	
	BrainBadge.OnMouseButton = function(self,button,down,x,y)	
		if down == true and GLOBAL.TheWorld.ismastersim then
			if ArtificalWalterEnabled then
				self.owner.BrainPulse:Cancel()
				BrainBadge.anim:GetAnimState():SetMultColour(1,1,1,1)
				SetSelfNormal()
			else
				BrainPulse(self.owner)
				SetSelfAI()
			end
		end
	end
end

local function GetPerceptionData() 
	local brain = GLOBAL.require "brains/fatimabrain"
	dt = brain.ReturnPerceptionData()
end

local function ReturnHeaderlist() 
	local str = ""
	local num = 0 
	if dt ~= nil then
		for i, _ in pairs(dt) do 
			str = str .. "\n".. tostring(num) .. " : " .. tostring(i) 
			num = num + 1
		end
	end
	return str
end 

local function WriteCSVHeader()

	if header == "" and dt ~= nil then
    	for k, v in pairs(dt) do  
			if type(v) ~= "table" then 
				if header == "" then header = tostring(k) else header = header..",".. tostring(k) end
			end
		end
		file:write(header) 
		file:write("\n") 

		-- print(ReturnHeaderlist())
		GLOBAL.TheNet:SystemMessage("Header has been written")
	end
end 

local function WriteGraphData()

	local row = ""
	local h = {}
	for w in (header .. ","):gmatch("([^,]*),") do -- split header string into each cols ("," split)
		table.insert(h, w) 
	end

	if header ~= "" and dt ~= nil then 
		for k, v in pairs(h) do 

			if dt[v] ~= nil and type(dt[v]) ~= 'table' then 
				if row == "" then row = tostring(dt[v]) else row = row..",".. tostring(dt[v]) end
			else
				if row == "" then row = "None" else row = row..",".. "None" end
			end
		end

		file:write(row) 
		file:write("\n") 
	end
end


AddClassPostConstruct("widgets/sanitybadge", MakeClickableBrain)

local function FindPortal()
	local ents = GLOBAL.TheSim:FindEntities(0, 0, 0, 10000, {"antlion_sinkhole_blocker"}) 
    for i, v in ipairs(ents) do
        if v.entity:IsVisible() and v.prefab == "multiplayer_portal" then
            return v
        end
    end
end

AddSimPostInit(function ()

	if GLOBAL.TheWorld.ismastersim and GetModConfigData('fatima-character-num') > 0 then 

		-- Find the Portal
		local portal = FindPortal()

		-- Spawn the characters required in the mod config
		local i = 0
		while i < GetModConfigData("fatima-character-num") do
			local char = GLOBAL.SpawnPrefab("wx78") -- change wilson to wx78 

			char:AddTag("FAtiMA-Brain")
		
			-- Move Spawned characters near the portal
			char.Transform:SetPosition(portal.Transform:GetWorldPosition())

			local brain = GLOBAL.require "brains/fatimabrain"
			char:SetBrain(brain)
			char:RestartBrain()
			i = i + 1
		end

	end
		
end)

AddGamePostInit(function() -- just called the func once 

    --Clear Old Data		
	local _f = io.open(graph_data, "w") _f:close()
	file = io.open(graph_data, "w")

end
)

AddPlayerPostInit(function()
	if graph_switch == 1 then 
	GLOBAL.TheWorld:DoPeriodicTask(1, GetPerceptionData)
	GLOBAL.TheWorld:DoPeriodicTask(1, WriteCSVHeader)
	GLOBAL.TheWorld:DoPeriodicTask(1, WriteGraphData)
	end
end
)