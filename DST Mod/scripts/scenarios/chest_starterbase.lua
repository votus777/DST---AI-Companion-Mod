chestfunctions = require("scenarios/chestfunctions")


local function OnCreate(inst, scenariorunner)

	local items = 
	{
		{
			item = "cutgrass",
			count = 10,
			chance = 1,
		},
		{
			item = "twigs",
			count = 10,
			chance = 1,
		},
		{
			item = "flint",
			count = 15,
			chance = 1,
		},
	}	
	chestfunctions.AddChestItems(inst, items)
end

return 
{
	OnCreate = OnCreate
}
