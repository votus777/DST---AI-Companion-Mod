# DST-AICompanion
Play "Don't Starve Together" with an interactive AI agent

Mod for the Steam game [Don't Starve Together](https://store.steampowered.com/app/322330/Dont_Starve_Together/)
, based on [FAtiMA-Toolkit](https://github.com/GAIPS/FAtiMA-Toolkit) to add an AI Agent to play and cooperate with players in the DST game world. This source code makes the agent able to move and do various actions autonomously. The agent can pick up resources, chop down trees, and even fight enemies with you.

The skeleton of the original mod is 'FAtiMA DST', built by [Hineios](https://github.com/hineios/FAtiMA-DST). However, while DST is updated, that mod is no longer updated by the developer. So this mod added advanced features and fixed major issues. In particular, the AI was given a personality, allowing it to display different characteristics.

## Requirements
-   Window OS 
-   Steam version of ‘Don’t Starve Together’


## Installation 

To run this mode, it needs mainly two components.   
One is the *FAtiMA Server file*, and the other is the *DST mod file* that applies in the Steam game folder. 

- FatiMA Server: This is the brain of the Agent. It will determine what the agent should do based on perception data and send orders to the mod file. It's a C# console application (**FAtiMA-Server.exe**) and will be run from outside of the game independently. 

- DST mod: This is a body of agents. It will transfer the data that the Agent perceived in the DST game environments to the FAtiMA server. Also when it receives orders, the mod file proceeds so the Agent can perform actual actions. 

1. The DST mod should be pasted into the game folder. (C:\\Program Files (x86)\\Steam\\steamapps\\common\\Don't Starve Together\\mods)

2. Start DST vis Steam and create a new world. 
	2-1. Click ‘Host Game’ from the main screen. 
	2-2. Create New World 
	2-3. Select ‘Survival’  
	2-4. Check ‘Friends Only’
	2-5. If you look at the tab above, you can see that there is ‘Mod (0)’
	2-6. Check the boxes of ‘HRI_Gamemod’ & ‘The AI Companion’ to enable the mods. 
	2-7. Select ‘The AI Companion’ mod and click to check mod options.
	2-8. Click ‘Generate World’ on the right below side. 
	2-9. MUST SELECT ‘Wilson’ character from the select window. 

 In the mod setting, Agents and personalities can be adjusted.   

3. At the starting point, you can find the robot(WX-78) which AI will control. However, you have to turn on FAtiMA-Server to make it move.
 
4. So switch the screen to the Desktop from the game. Go to the ‘FAtiMA-Server’ folder in the pre-test folder that you downloaded. 
   
5. Double-click ‘FAtiMA-Server.exe’ to launch the program. A prompt will come out. But you don’t need to type anything. 

6. After a while, the program will recognize the current Don’t Starve Together game session and the AI will start to move. 
   
7. Turn back to DST and now you can play with the AI companion. 

## Play Tips

When errors occur or meet unexpected situations like AI stuck somewhere, 

1. Press **Ctrl + R**. Then the game will instantly restart without quitting the game.

2. If AI stocks in the same position and keep saying ‘I can’t do that’ 
   : Try to remove all files in ‘Saved Characters’ in FatiMA-Server folder.**

## Description 

The process is performed at every interval.  
(Mod)perception - transmit - (FAtiMA)receive - decide - transmit - (Mod)execute - perception 

 Each correspondence uses an HTTP transaction.

## Application 

For my master thesis, 'Speech System' has been also applied. 
With this system, players can interact with Agents using verbal communication while playing DST together. 

DST mod <-> FAtiMA Server <-> Speech System 

Agent not only replies to player's utterances, it can perform proper actions up to the utterance. For instance, when the player asks an agent for help, the agent will go close to the player.  

## Limitations 

- The codes were hard-coded. Be careful when making changes.  
- Mod files depend on the game version.



   
