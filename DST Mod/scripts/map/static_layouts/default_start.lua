local x_pos = 200
local y_pos = 200

return {
  version = "1.1",
  luaversion = "5.1",
  orientation = "orthogonal",
  width = 7,
  height = 7,
  tilewidth = 64,
  tileheight = 64,
  properties = {},
  tilesets = {
    {
      name = "ground",
      firstgid = 1,
      filename = "../../../../../../Don't Starve Mod Tools/tileset/ground.tsx",
      tilewidth = 64,
      tileheight = 64,
      spacing = 0,
      margin = 0,
      image = "../../../../../../Don't Starve Mod Tools/tileset/tiles.png",
      imagewidth = 512,
      imageheight = 128,
      properties = {},
      tiles = {}
    }
  },
  layers = {
    {
      type = "tilelayer",
      name = "BG_TILES",
      x = 0,
      y = 0,
      width = 7,
      height = 7,
      visible = true,
      opacity = 1,
      properties = {},
      encoding = "lua",
      data = {
        6, 7, 7, 7, 7, 6, 6,
        6, 7, 7, 7, 6, 7, 7,
        7, 7, 6, 6, 6, 7, 7,
        7, 7, 6, 7, 7, 7, 7,
        7, 7, 6, 6, 6, 7, 7,
        6, 6, 7, 7, 6, 6, 6,
        7, 6, 7, 7, 7, 7, 6
      }
    },
    {
      type = "objectgroup",
      name = "FG_OBJECTS",
      visible = true,
      opacity = 1,
      properties = {},
      objects = {
        {
          name = "",
          type = "multiplayer_portal",
          shape = "rectangle",
          x = x_pos,
          y = y_pos,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "spawnpoint_master",
          shape = "rectangle",
          x = x_pos+1,
          y = y_pos,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "researchlab",
          shape = "rectangle",
          x = x_pos+50,
          y = y_pos,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "cookpot",
          shape = "rectangle",
          x = x_pos+50,
          y = y_pos+50,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "tent",
          shape = "rectangle",
          x = x_pos+50,
          y = y_pos-50,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "grass",
          shape = "rectangle",
          x = x_pos-50,
          y = y_pos,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "grass",
          shape = "rectangle",
          x = x_pos-50,
          y = y_pos+50,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "grass",
          shape = "rectangle",
          x = x_pos-50,
          y = y_pos+100,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "grass",
          shape = "rectangle",
          x = x_pos-50,
          y = y_pos+150,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
		{
          name = "",
          type = "grass",
          shape = "rectangle",
          x = x_pos-50,
          y = y_pos+200,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "grass",
          shape = "rectangle",
          x = x_pos-50,
          y = y_pos-50,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
		{
          name = "",
          type = "grass",
          shape = "rectangle",
          x = x_pos-50,
          y = y_pos-100,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
		{
          name = "",
          type = "grass",
          shape = "rectangle",
          x = x_pos-50,
          y = y_pos-150,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
		{
          name = "",
          type = "grass",
          shape = "rectangle",
          x = x_pos-50,
          y = y_pos-200,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "sapling",
          shape = "rectangle",
          x = x_pos-100,
          y = y_pos,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
		{
          name = "",
          type = "sapling",
          shape = "rectangle",
          x = x_pos-100,
          y = y_pos+50,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
		{
          name = "",
          type = "sapling",
          shape = "rectangle",
          x = x_pos-100,
          y = y_pos+100,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
		{
          name = "",
          type = "sapling",
          shape = "rectangle",
          x = x_pos-100,
          y = y_pos+150,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
		{
          name = "",
          type = "sapling",
          shape = "rectangle",
          x = x_pos-100,
          y = y_pos+200,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
		{
          name = "",
          type = "sapling",
          shape = "rectangle",
          x = x_pos-100,
          y = y_pos-50,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
		{
          name = "",
          type = "sapling",
          shape = "rectangle",
          x = x_pos-100,
          y = y_pos-100,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
		{
          name = "",
          type = "sapling",
          shape = "rectangle",
          x = x_pos-100,
          y = y_pos-150,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
		{
          name = "",
          type = "sapling",
          shape = "rectangle",
          x = x_pos-100,
          y = y_pos-200,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "treasurechest",
          shape = "rectangle",
          x = x_pos,
          y = y_pos+100,
          width = 0,
          height = 0,
          visible = true,
          properties = {["scenario"] = "chest_starterbase"}
        },
        {
          name = "",
          type = "berrybush",
          shape = "rectangle",
          x = x_pos-150,
          y = y_pos,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "berrybush",
          shape = "rectangle",
          x = x_pos-150,
          y = y_pos+50,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "berrybush",
          shape = "rectangle",
          x = x_pos-150,
          y = y_pos-50,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "berrybush",
          shape = "rectangle",
          x = x_pos-150,
          y = y_pos+100,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        },
        {
          name = "",
          type = "berrybush",
          shape = "rectangle",
          x = x_pos-150,
          y = y_pos-100,
          width = 0,
          height = 0,
          visible = true,
          properties = {}
        }
      }
    }
  }
}
