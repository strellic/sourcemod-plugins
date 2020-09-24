# sourcemod-plugins
a repository of all of my sourcemod plugins, especially those for the ZE (Zombie Escape) gamemode

please let me know if you're gonna use them, DM me on Discord @ Strellic#2507

## SkillBot
SkillBot was one of my larger plugins, it was an attempt at a custom ranking system specifically for the Zombie Escape gamemode.

### Features
* Storage in MySQL / SQLite database
* "Hard Map" functionality, hooks into active maps to determine whether the current map / level should give a higher multiplier
* Custom point algorithm that incentivizes shooting zombies
* Custom and extensible perks implementation that allows for fun items like tracers or skins based on ranks / points

### Usage
Compile `skillbot.sp`, `skillbot_perks.sp`, and the specific skillbot chats plugin for the chat processor your server uses.
Move the `skillbot/configs/skillbot/` folder into the `addons/sourcemod/config/` folder, and modify the configs as necessary.

## Leader
A plugin that allows humans to vote for and become leaders, leading the team through the map with a custom rainbow beacon, markers, and overlays above their head.

## Countdown HUD
[Alliedmodders Link](https://www.google.com/search?q=countdownhud&oq=countdownhud&aqs=chrome..69i57j0l6.3487j0j7&sourceid=chrome&ie=UTF-8)
Detects whenever the map says a message that contains a timer, and counts down the exact message on a game_text hud. Has support for most phrases (feel free to tell me which ones don't work), and changes the exact message given from the map. The plugin is made for ZR servers to tell people when things are happening, but it should work on non-ZR servers.

## Boss HUD (version 2)
Displays the health / value of any func_breakable or math_counter that you activate. Plugin is meant for the ZE gamemode, as it displays the current HP of any boss or breakable that you are shooting, but it can be used in other gamemodes as well.

## Boss HUD (version 3)
An updated version of Boss HUD that uses GFL's boss config system to have custom implementation for certain bosses.