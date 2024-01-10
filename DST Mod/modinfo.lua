-- This information tells other players more about the mod
name = "The AI Companion"
description = "Play the game with AI\nDon't forget you need to run the companion console application!, orgin by Hineios \n\nGet it from:\n https://github.com/hineios/FAtiMA-DST/releases"
author = "Han"
version = "1.6"
--version_compatible = "1.7"

-- This is the URL name of the mod's thread on the forum; the part after the index.php? and before the first & in the URL
-- Example:
-- http://forums.kleientertainment.com/index.php?/files/file/202-sample-mods/
-- becomes
-- /files/file/202-sample-mods/
forumthread = "topic/86495-fatima-dst-an-ai-framework/"

-- This lets other players know if your mod is out of date, update it to match the current version in the game
api_version = 10

---- Can specify a custom icon for this mod!
icon_atlas = "modicon.xml"
icon = "modicon.tex"

--This lets the clients know that they need to download the mod before they can join a server that is using it.
all_clients_require_mod = true

--This let's the game know that this mod doesn't need to be listed in the server's mod listing
client_only_mod = false

--Let the mod system know that this mod is functional with Don't Starve Together
dst_compatible = true

--These tags allow the server running this mod to be found with filters from the server listing screen
server_filter_tags = {"ai"}



 configuration_options =
 {
     {
         name = 'fatima-character-num',
         label = 'Number of characters',
		 hover = 'The number of characters that will be added to the game.',
         options = 
         {
             {description = "0 characters", data = 0},
			 {description = "1 character", data = 1},
			 {description = "2 characters", data = 2},
             
         },
         default = 1,
     },
	 {
         name = 'speak-chance',
         label = 'Speak Chance',
		 hover = 'The probability of the character making random remarks about the world.',
         options = 
         {
             {description = "30%", data = 30},
			 {description = "40%", data = 40},
			 {description = "50%", data = 50},
			 {description = "60%", data = 60},
             {description = "70%", data = 70},
         },
         default = 40,
     },
     {
        name = 'personality',
        label = 'Personality',
        hover = 'AI Personality',
        options = 
        {
            {description = "No Personality", data = "None"},
            {description = "Adventurer", data = "Adventurer"},
            {description = "Camper", data = "Camper"},
            {description = "Supporter", data = "Supporter"},
        },
        default = "None",
    },
    {
        name = "Enable Showing Graph",
        label = "Enable Showing Graph",
        hover = "Enable Showing Graph",
        options = 
        {
            {description = "ON", data = 1},
            {description = "OFF", data = 0}
            
        },
        default = 0,
    },
    {
        name = 'OPE',
        label = 'OPE',
        hover = 'Openness to experience, from cautious/consistent to curious/inventive ',
        options = 
        {
            {description = "0", data = 0},
            {description = "1", data = 1},
            {description = "2", data = 2},
            {description = "3", data = 3},
            {description = "4", data = 4},
            {description = "5", data = 5},
            {description = "6", data = 6},
            {description = "7", data = 7},
            {description = "8", data = 8},
            {description = "9", data = 9},
            {description = "10", data = 10}
        },
        default = "5",
    },    
    {
        name = 'COS',
        label = 'COS',
        hover = 'Conscientiousness, from unorganized/easy-going to organized/efficient',
        options = 
        {
            {description = "0", data = 0},
            {description = "1", data = 1},
            {description = "2", data = 2},
            {description = "3", data = 3},
            {description = "4", data = 4},
            {description = "5", data = 5},
            {description = "6", data = 6},
            {description = "7", data = 7},
            {description = "8", data = 8},
            {description = "9", data = 9},
            {description = "10", data = 10}
        },
        default = "5",
    },    
    {
        name = 'EXT',
        label = 'EXT',
        hover = 'Extraversion, from solitary/reserved to outgoing/energetic ',
        options = 
        {
            {description = "0", data = 0},
            {description = "1", data = 1},
            {description = "2", data = 2},
            {description = "3", data = 3},
            {description = "4", data = 4},
            {description = "5", data = 5},
            {description = "6", data = 6},
            {description = "7", data = 7},
            {description = "8", data = 8},
            {description = "9", data = 9},
            {description = "10", data = 10}
        },
        default = "5",
    },
    {
        name = 'AGR',
        label = 'AGR',
        hover = 'Agreeableness, from cold/unkind to friendly/compassionate',
        options = 
        {
            {description = "0", data = 0},
            {description = "1", data = 1},
            {description = "2", data = 2},
            {description = "3", data = 3},
            {description = "4", data = 4},
            {description = "5", data = 5},
            {description = "6", data = 6},
            {description = "7", data = 7},
            {description = "8", data = 8},
            {description = "9", data = 9},
            {description = "10", data = 10}
        },
        default = "5",
    },
    {
        name = 'NEU',
        label = 'NEU',
        hover = 'Neuroticism, from secure/calm to unconfident/nervous',
        options = 
        {
            {description = "0", data = 0},
            {description = "1", data = 1},
            {description = "2", data = 2},
            {description = "3", data = 3},
            {description = "4", data = 4},
            {description = "5", data = 5},
            {description = "6", data = 6},
            {description = "7", data = 7},
            {description = "8", data = 8},
            {description = "9", data = 9},
            {description = "10", data = 10}
        },
        default = "5",
    },
    
}