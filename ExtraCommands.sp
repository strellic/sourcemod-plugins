#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <colors_csgo>

#pragma newdecls required

bool g_bInBuyZoneAll = false;
bool g_bInBuyZone[MAXPLAYERS + 1] = {false, ...};
bool g_bInfAmmoHooked = false;
bool g_bInfAmmoAll = false;
bool g_bInfAmmo[MAXPLAYERS + 1] = {false, ...};
bool g_bCommandSpy[MAXPLAYERS+1] = {false, ...};
bool g_bTimerServer = false;

int g_userSaveIndex[MAXPLAYERS+1];
float g_savePosition[300][3];
int g_locationIndex;
bool g_isLooping;

int lastCTNotMe = -1, lastTNotMe = -1, lastAllNotMe = -1, lastAliveNotMe = -1, lastDeadNotMe = -1, lastSpecNotMe = -1;

ConVar g_cVTimerServer = null;

public Plugin myinfo =
{
	name 		= "Extra Commands",
	author 		= "AntiTeal",
	description	= "Extra Commands",
	version 	= "2.0",
	url 		= "antiteal.com"
};

public void OnPluginStart()
{
	g_cVTimerServer = CreateConVar("ec_timer_server", "0", "Wether or not this is a timer server. This disables possibly abusive commands", _, true, 0.0, true, 1.0);
	g_cVTimerServer.AddChangeHook(OnConVarChange);

	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");

	RegAdminCmd("sm_god", Command_God, ADMFLAG_GENERIC, "Toggle players god mode");

	RegAdminCmd("sm_hp", Command_Health, ADMFLAG_GENERIC, "sm_hp <#userid|name> <value>");
	RegAdminCmd("sm_health", Command_Health, ADMFLAG_GENERIC, "sm_health <#userid|name> <value>");

	RegConsoleCmd("sm_authid", Command_AuthID, "sm_authid [#userid|name]");
	RegAdminCmd("sm_team", Command_Team, ADMFLAG_GENERIC, "sm_team <#userid|name> <team>");

	RegAdminCmd("sm_armor", Command_Armor, ADMFLAG_GENERIC, "sm_armor <#userid|name> <value>");
	RegAdminCmd("sm_kevlar", Command_Armor, ADMFLAG_GENERIC, "sm_kevlar <#userid|name> <value>");

	RegAdminCmd("sm_speed", Command_Speed, ADMFLAG_GENERIC, "sm_speed <#userid|name> <0|1>");

	RegAdminCmd("sm_cash", Command_Cash, ADMFLAG_GENERIC, "sm_cash <#userid|name> <value>");
	RegAdminCmd("sm_money", Command_Cash, ADMFLAG_GENERIC, "sm_money <#userid|name> <value>");

	RegAdminCmd("sm_modelscale", Command_ModelScale, ADMFLAG_GENERIC, "sm_modelscale <#userid|name> <scale>");
	RegAdminCmd("sm_resize", Command_ModelScale, ADMFLAG_GENERIC, "sm_resize <#userid|name> <scale>");

	RegAdminCmd("sm_getmodel", Command_WAILA, ADMFLAG_GENERIC, "sm_getmodel [#userid|name]");
	RegAdminCmd("sm_waila", Command_WAILA, ADMFLAG_GENERIC, "sm_waila [#userid|name]");

	RegAdminCmd("sm_clantag", Command_ClanTag, ADMFLAG_GENERIC, "sm_clantag <#userid|name> <clantag>");
	RegAdminCmd("sm_mvp", Command_MVP, ADMFLAG_GENERIC, "sm_mvp <#userid|name> <mvps>");
	RegAdminCmd("sm_score", Command_Score, ADMFLAG_GENERIC, "sm_score <#userid|name> <score>");
	RegAdminCmd("sm_assists", Command_Assists, ADMFLAG_GENERIC, "sm_assists <#userid|name> <assists>");
	RegAdminCmd("sm_frags", Command_Kills, ADMFLAG_GENERIC, "sm_frags <#userid|name> <frags>");
	RegAdminCmd("sm_kills", Command_Kills, ADMFLAG_GENERIC, "sm_kills <#userid|name> <kills>");
	RegAdminCmd("sm_deaths", Command_Deaths, ADMFLAG_GENERIC, "sm_deaths <#userid|name> <deaths>");

	RegAdminCmd("sm_hinttext", Command_HintText, ADMFLAG_GENERIC, "sm_hinttext <message>");
	RegAdminCmd("sm_consolesay", Command_ConsoleSay, ADMFLAG_GENERIC, "sm_consolesay <message>");
	RegAdminCmd("sm_consolesay2", Command_ConsoleSay2, ADMFLAG_GENERIC, "sm_consolesay2 <message>");
	RegAdminCmd("sm_targetname", Command_Targetname, ADMFLAG_GENERIC, "sm_targetname <#userid|name> <targetname>");
	RegAdminCmd("sm_worldtext", Command_WorldText, ADMFLAG_GENERIC, "sm_worldtext <message> <r g b> <size>");
	RegConsoleCmd("sm_createmenu", Command_CreateMenu, "sm_createmenu");

	RegAdminCmd("sm_forcerevive", Command_ForceRevive, ADMFLAG_GENERIC, "sm_forcerevive <#userid|name>");

	RegAdminCmd("sm_cspy", Command_CommandSpy, ADMFLAG_GENERIC, "sm_cspy");

	RegAdminCmd("sm_give", Command_Weapon, ADMFLAG_GENERIC, "sm_give <#userid|name> <weapon> [clip] [ammo]");
	RegAdminCmd("sm_strip", Command_Strip, ADMFLAG_GENERIC, "sm_strip <#userid|name>");
	RegAdminCmd("sm_disarm", Command_Strip, ADMFLAG_GENERIC, "sm_disarm <#userid|name>");
	RegAdminCmd("sm_melee", Command_Melee, ADMFLAG_GENERIC, "sm_melee <#userid|name>");
	RegAdminCmd("sm_respawn", Command_Respawn, ADMFLAG_GENERIC, "sm_respawn <#userid|name>");
	RegAdminCmd("sm_buyzone", Command_BuyZone, ADMFLAG_GENERIC, "sm_buyzone <#userid|name> <0|1>");
	RegAdminCmd("sm_iammo", Command_InfAmmo, ADMFLAG_GENERIC, "sm_iammo <#userid|name> <0|1>");
	RegAdminCmd("sm_ammo", Command_InfAmmo, ADMFLAG_GENERIC, "sm_ammo <#userid|name> <0|1>");

	RegAdminCmd("sm_extend", Command_Extend, ADMFLAG_GENERIC, "sm_extend <minutes>");
	RegAdminCmd("sm_rr", Command_RestartGame, ADMFLAG_GENERIC, "sm_rr");

	RegAdminCmd("sm_bury", Command_Bury, ADMFLAG_GENERIC, "sm_bury <#userid|name>");
	RegAdminCmd("sm_unbury", Command_Unbury, ADMFLAG_GENERIC, "sm_unbury <#userid|name>");

	RegAdminCmd("sm_saveloc", Command_SaveLoc, ADMFLAG_GENERIC, "sm_saveloc");
	RegAdminCmd("sm_teleport", Command_Teleport, ADMFLAG_GENERIC, "sm_teleport <#userid|name>");

	RegAdminCmd("sm_spec", Command_Spectate, ADMFLAG_GENERIC, "sm_spec <player>");
	RegAdminCmd("sm_spectate", Command_Spectate, ADMFLAG_GENERIC, "sm_spectate <player>");

	RegAdminCmd("sm_fexec", Command_Fexec, ADMFLAG_ROOT, "Fake-execute a command as if the target did it", "", 0);
	RegAdminCmd("sm_botsay", Command_BotSay, ADMFLAG_ROOT, "Fake-execute a command as if the target did it", "", 0);

	AutoExecConfig(true, "plugin.extracommands");

	AddMultiTargetFilter("@random", Filter_Random, "a Random Player", false);
	AddMultiTargetFilter("@randomct", Filter_RandomCT, "a Random CT", false);
	AddMultiTargetFilter("@randomt", Filter_RandomT, "a Random T", false);

	AddMultiTargetFilter("@ctnotme", Filter_CTNotMe, "all CTs besides Admin", false);
	AddMultiTargetFilter("@tnotme", Filter_TNotMe, "all Ts besides Admin", false);
	AddMultiTargetFilter("@allnotme", Filter_AllNotMe, "all players besides Admin", false);
	AddMultiTargetFilter("@alivenotme", Filter_AliveNotMe, "all players besides Admin", false);
	AddMultiTargetFilter("@deadnotme", Filter_DeadNotMe, "dead players besides Admin", false);
	AddMultiTargetFilter("@specnotme", Filter_SpecNotMe, "all SPECs besides Admin", false);

	AddCommandListener(HookPlayerChat, "say");

	RegAdminCmd("sm_cheat", Command_cheat_command, ADMFLAG_GENERIC);
}


public Action Command_cheat_command(int client, int args)
{
	char cmd[65];
	GetCmdArgString(cmd, sizeof(cmd));
	PerformCheatCommand(client, cmd);
	return Plugin_Handled;
}

public void PerformCheatCommand(int client, char[] cmd)
{
	Handle cvar = FindConVar("sv_cheats");
	bool enabled = GetConVarBool(cvar);
	int flags = GetConVarFlags(cvar);
	if(!enabled) {
		SetConVarFlags(cvar, flags^(FCVAR_NOTIFY|FCVAR_REPLICATED));
		SetConVarBool(cvar, true);
	}
	FakeClientCommand(client, cmd);
	if(!enabled) {
		SetConVarBool(cvar, false);
		SetConVarFlags(cvar, flags);
	}
}

public void OnPluginEnd()
{
	RemoveMultiTargetFilter("@random", Filter_Random);
	RemoveMultiTargetFilter("@randomct", Filter_RandomCT);
	RemoveMultiTargetFilter("@randomt", Filter_RandomT);

	RemoveMultiTargetFilter("@ctnotme", Filter_CTNotMe);
	RemoveMultiTargetFilter("@tnotme", Filter_TNotMe);
	RemoveMultiTargetFilter("@allnotme", Filter_AllNotMe);
	RemoveMultiTargetFilter("@alivenotme", Filter_AliveNotMe);
	RemoveMultiTargetFilter("@deadnotme", Filter_DeadNotMe);
	RemoveMultiTargetFilter("@specnotme", Filter_SpecNotMe);
}

public void OnConVarChange(ConVar convar, char[] oldV, char[] newV)
{
	g_bTimerServer = g_cVTimerServer.BoolValue;
}

public void OnConfigsExecuted()
{
	g_bTimerServer = g_cVTimerServer.BoolValue;
}

public Action Command_SaveLoc(int client, int argc)
{
	if(g_bTimerServer)
	{
		return Plugin_Handled;
	}

	PerformSaveLoc(client);
	PrintToChat(client, " [SM] \x01Location \x04#%i \x01(\x04%.1f, %.1f, %.1f\x01) saved.", g_userSaveIndex[client] + 1, g_savePosition[g_userSaveIndex[client]][0], g_savePosition[g_userSaveIndex[client]][1], g_savePosition[g_userSaveIndex[client]][2]);
	return Plugin_Handled;
}

public Action Command_Teleport(int client, int args)
{
	if (g_bTimerServer)
	{
		return Plugin_Handled;
	}
	if (args < 1 || args == 3 || args > 4)
	{
		ReplyToCommand(client, "[SM] Usage: sm_teleport <[#ID/x/client]>");
		return Plugin_Handled;
	}
	if (args == 1)
	{
		if (0 > g_userSaveIndex[client])
		{
			ReplyToCommand(client, "[SM] Save a location first, supply a teleport ID or coordinates");
			return Plugin_Handled;
		}
	}

	char pattern[64];
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;
	GetCmdArg(1, pattern, sizeof(pattern));

	if((target_count = ProcessTargetString(pattern, client, target_list, MAXPLAYERS, 1, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	int index = g_userSaveIndex[client];
	float vector[3];
	if (args == 2)
	{
		char arg2[8];
		GetCmdArg(2, arg2, sizeof(arg2));
		if (StrContains(arg2, "#", true))
		{
			char target_name_2[MAX_TARGET_LENGTH];
			int target_list_2[MAXPLAYERS];
			int target_count_2;
			bool tn_is_ml_2;

			if((target_count = ProcessTargetString(arg2, client, target_list_2, MAXPLAYERS, 16, target_name_2, sizeof(target_name_2), tn_is_ml_2)) <= 0)
			{
				ReplyToTargetError(client, target_count_2);
				return Plugin_Handled;
			}
			if (target_count_2 != 1)
			{
				ReplyToCommand(client, "[SM] Invalid target.");
			}
			GetClientAbsOrigin(target_list_2[0], vector);
			index = -1;
		}
		else
		{
			int iindex = StringToInt(arg2[1]);
			if (iindex > 300 || (iindex > g_locationIndex && !g_isLooping) || iindex <= 0)
			{
				ReplyToCommand(client, "[SM] Invalid saved location ID.");
				return Plugin_Handled;
			}
			g_userSaveIndex[client] = iindex + -1;
			index = iindex + -1;
		}
	}
	if (index != -1)
	{
		int i;
		while (i <= 2)
		{
			vector[i] = g_savePosition[index][i];
			i++;
		}
	}
	if (args == 4)
	{
		char x[16];
		char y[16];
		char z[16];
		GetCmdArg(2, x, 16);
		GetCmdArg(3, y, 16);
		GetCmdArg(4, z, 16);
		vector[0] = StringToFloat(x);
		vector[1] = StringToFloat(y);
		vector[2] = StringToFloat(z);
	}
	int i;
	while (i < target_count)
	{
		PerformTeleport(client, target_list[i], vector);
		i++;
	}
	if (tn_is_ml)
	{
		ShowActivity2(client, " [SM] \x04", "\x01Teleported \x04%t\x01 to \x04%.1f, %.1f, %.1f\x01.", target_name, vector, vector[1], vector[2]);
	}
	else
	{
		ShowActivity2(client, " [SM] \x04", "\x01Teleported \x04%s\x01 to \x04%.1f, %.1f, %.1f\x01.", target_name, vector, vector[1], vector[2]);
	}
	return Plugin_Handled;
}

public void PerformTeleport(int client, int target, float vector[3])
{
	TeleportEntity(target, vector, NULL_VECTOR, NULL_VECTOR);
	LogAction(client, target, "\"%L\" teleported \"%L\" to \"%.2f, %.2f, %2.f\"", client, target, vector, vector[1], vector[2]);
	return;
}

public void PerformSaveLoc(int client)
{
	if (g_locationIndex == 300)
	{
		g_isLooping = true;
		g_locationIndex = 0;
	}
	GetClientAbsOrigin(client, g_savePosition[g_locationIndex]);
	g_userSaveIndex[client] = g_locationIndex;
	g_locationIndex += 1;
}

public Action Command_Team(int client, int argc)
{
	if(argc < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_team <#userid|name> <team>");
		return Plugin_Handled;
	}

	int iTeam;
	char sArgs[64];
	char sArgs2[32];
	char sTargetName[MAX_TARGET_LENGTH];
	int iTargets[MAXPLAYERS];
	int iTargetCount;
	bool bIsML;

	GetCmdArg(1, sArgs, sizeof(sArgs));
	GetCmdArg(2, sArgs2, sizeof(sArgs2));

	iTeam = CheckTeamName(sArgs2, sizeof(sArgs2));

	if(!iTeam)
	{
		ReplyToCommand(client, "[SM] Invalid team.");
		return Plugin_Handled;
	}

	if((iTargetCount = ProcessTargetString(sArgs, client, iTargets, MAXPLAYERS, 0, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}

	for(int i = 0; i < iTargetCount; i++)
	{
		if (iTeam == 1)
		{
			ChangeClientTeam(iTargets[i], iTeam);
		}
		else
		{
			CS_SwitchTeam(iTargets[i], iTeam);
			if (IsPlayerAlive(iTargets[i]))
			{
				CS_RespawnPlayer(iTargets[i]);
			}
		}
	}

	ShowActivity2(client, "\x01[SM] \x04", "\x01Set \x04%s\x01's team to \x04%i", sTargetName, iTeam);
	LogAction(client, -1, "Set %s's team to %i", sTargetName, iTeam);

	return Plugin_Handled;
}

public int CheckTeamName(char[] team, int maxlength)
{
	int buffer = StringToInt(team);
	if (StrEqual(team, "spec", false) || StrEqual(team, "spectators", false) || buffer == 1)
	{
		Format(team, maxlength, "Spectators");
		return 1;
	}
	if (StrEqual(team, "t", false) || StrEqual(team, "terrorists", false) || buffer == 2)
	{
		Format(team, maxlength, "Terrorists");
		return 2;
	}
	if (StrEqual(team, "ct", false) || StrEqual(team, "counterterrorists", false) || buffer == 3)
	{
		Format(team, maxlength, "Counter-Terrorists");
		return 3;
	}
	return 0;
}

public Action Command_Bury(int client, int argc)
{
	if(argc < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_bury <#userid|name>");
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;

	if((target_count = ProcessTargetString(arg, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for(int i = 0; i < target_count; i++)
	{
		//target_list[i]
		float vec[3];
		GetClientAbsOrigin(target_list[i], vec);
		vec[2] -= 30.0;
		TeleportEntity(target_list[i], vec, NULL_VECTOR, NULL_VECTOR);
	}

	ShowActivity2(client, "\x01[SM] \x04", "\x01Buried target \x04%s", target_name);
	LogAction(client, -1, "Buried target %s", target_name);

	return Plugin_Handled;
}


public Action Command_Unbury(int client, int argc)
{
	if(argc < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_unbury <#userid|name>");
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;

	if((target_count = ProcessTargetString(arg, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for(int i = 0; i < target_count; i++)
	{
		//target_list[i]
		float vec[3];
		GetClientAbsOrigin(target_list[i], vec);
		vec[2] += 30.0;
		TeleportEntity(target_list[i], vec, NULL_VECTOR, NULL_VECTOR);
	}

	ShowActivity2(client, "\x01[SM] \x04", "\x01Unburied target \x04%s", target_name);
	LogAction(client, -1, "Unburied target %s", target_name);

	return Plugin_Handled;
}

public Action Command_RestartGame(int client, int args)
{
	ServerCommand("mp_restartgame 2");

	ShowActivity2(client, "\x01[SM] \x04", "\x01Restarted the game.");
	LogAction(client, -1, "Restarted the game.");

	return Plugin_Handled;
}

public Action Command_CommandSpy(int client, int args)
{
	g_bCommandSpy[client] = !g_bCommandSpy[client];
	ReplyToCommand(client, "[SM] Command spy has been %s.", g_bCommandSpy[client] ? "enabled" : "disabled");

	return Plugin_Handled;
}

public Action Command_Extend(int client, int argc)
{
	if(argc < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_extend <minutes>");
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	int minutes = StringToInt(arg);

	ExtendMapTimeLimit(minutes * 60);

	ShowActivity2(client, "\x01[SM] \x04", "\x01Extended map timelimit by \x04%i\x01 minutes.", minutes);
	LogAction(client, -1, "Extended map timelimit by %i minutes.", minutes);

	return Plugin_Handled;
}

public Action Command_AuthID(int client, int args)
{
	if(args == 0)
	{
		char auth[64];
		GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth), false);
		PrintToChat(client, "[SM] %N's AuthID: %s.", client, auth);
	}
	else
	{
		char arg1[65];
		GetCmdArg(1, arg1, sizeof(arg1));
		int target = FindTarget(client, arg1, false, false);
		if (target == -1)
		{
			return Plugin_Handled;
		}

		char auth[64];
		GetClientAuthId(target, AuthId_Steam2, auth, sizeof(auth), false);
		PrintToChat(client, "[SM] %N's AuthID: %s.", target, auth);
	}
	return Plugin_Handled;
}

public Action OnClientCommand(int client, int args)
{
	char ClientText[256];
	GetCmdArg(0, ClientText, sizeof(ClientText));

	if(StrContains(ClientText, "@ctnotme", true))
	lastCTNotMe = client;
	if(StrContains(ClientText, "@tnotme", true))
	lastTNotMe = client;
	if(StrContains(ClientText, "@allnotme", true))
	lastAllNotMe = client;
	if(StrContains(ClientText, "@alivenotme", true))
	lastAliveNotMe = client;
	if(StrContains(ClientText, "@deadnotme", true))
	lastDeadNotMe = client;
	if(StrContains(ClientText, "@specnotme", true))
	lastSpecNotMe = client;

	char arguments[256];
	GetCmdArgString(arguments, sizeof(arguments));
	StripQuotes(arguments);

	for(int i = 1; i <= MaxClients; i++)
	{
		if (StrContains(ClientText, "sm_", false) == 0)
		{
			if(IsValidClient(i) && CanUserTarget(i, client) && g_bCommandSpy[i] && ClientText[0] != '+' && ClientText[0] != '-')
			{
				PrintToChat(i, "[CSPY] %N: %s %s", client, ClientText, arguments);
			}
		}
	}
}

public Action HookPlayerChat(int client, const char[] command, int args)
{
	char ClientText[256];
	GetCmdArgString(ClientText, sizeof(ClientText));
	StripQuotes(ClientText);

	if(StrContains(ClientText, "@ctnotme", true))
	lastCTNotMe = client;
	if(StrContains(ClientText, "@tnotme", true))
	lastTNotMe = client;
	if(StrContains(ClientText, "@allnotme", true))
	lastAllNotMe = client;
	if(StrContains(ClientText, "@alivenotme", true))
	lastAliveNotMe = client;
	if(StrContains(ClientText, "@deadnotme", true))
	lastDeadNotMe = client;
	if(StrContains(ClientText, "@specnotme", true))
	lastSpecNotMe = client;

	for(int i = 1; i <= MaxClients; i++)
	{
		if (StrContains(ClientText, "@", false) == 0)
		{
			if(IsValidClient(i) && CanUserTarget(i, client) && g_bCommandSpy[i] && ClientText[0] != '+' && ClientText[0] != '-')
			{
				PrintToChat(i, "[CSPY] %N: %s", client, ClientText);
			}
		}
	}
}

bool IsValidClient(int client, bool nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}


public bool Filter_CTNotMe(const char[] sPattern, Handle hClients, int client)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsValidClient(lastCTNotMe) && GetClientTeam(i) == 3 && IsPlayerAlive(i) && i != lastCTNotMe)
		PushArrayCell(hClients, i);
	}
	return true;
}

public bool Filter_TNotMe(const char[] sPattern, Handle hClients, int client)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsValidClient(lastTNotMe) && GetClientTeam(i) == 2 && IsPlayerAlive(i) && i != lastTNotMe)
		PushArrayCell(hClients, i);
	}
	return true;
}

public bool Filter_AllNotMe(const char[] sPattern, Handle hClients, int client)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsValidClient(lastAllNotMe) && i != lastAllNotMe)
		PushArrayCell(hClients, i);
	}
	return true;
}

public bool Filter_SpecNotMe(const char[] sPattern, Handle hClients, int client)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsValidClient(lastSpecNotMe) && GetClientTeam(i) == 1 && !IsClientSourceTV(i) && !IsClientReplay(i) && i != lastSpecNotMe)
		PushArrayCell(hClients, i);
	}
	return true;
}

public bool Filter_DeadNotMe(const char[] sPattern, Handle hClients, int client)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsValidClient(lastDeadNotMe) && !IsPlayerAlive(i) && i != lastDeadNotMe)
		PushArrayCell(hClients, i);
	}
	return true;
}

public bool Filter_AliveNotMe(const char[] sPattern, Handle hClients, int client)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i) && IsValidClient(lastAliveNotMe) && IsPlayerAlive(i) && i != lastAliveNotMe)
		PushArrayCell(hClients, i);
	}
	return true;
}

public bool Filter_Random(const char[] sPattern, Handle hClients, int client)
{
	int iRand = GetRandomInt(1, MaxClients);

	if(IsClientInGame(iRand) && IsPlayerAlive(iRand))
	PushArrayCell(hClients, iRand);
	else
	Filter_Random(sPattern, hClients, client);

	return true;
}

public bool Filter_RandomCT(const char[] sPattern, Handle hClients, int client)
{
	int iCTCount = GetTeamClientCount(CS_TEAM_CT);

	if(!iCTCount)
	return false;

	int[] iCTs = new int[iCTCount];

	int iCurIndex;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || GetClientTeam(i) != CS_TEAM_CT)
		continue;

		if(!IsPlayerAlive(i))
		{
			iCTCount--;
			continue;
		}

		iCTs[iCurIndex] = i;
		iCurIndex++;
	}

	PushArrayCell(hClients, iCTs[GetRandomInt(0, iCTCount-1)]);

	return true;
}

public bool Filter_RandomT(const char[] sPattern, Handle hClients, int client)
{
	int iTCount = GetTeamClientCount(CS_TEAM_T);

	if(!iTCount)
	return false;

	int[] iTs = new int[iTCount];

	int iCurIndex;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || GetClientTeam(i) != CS_TEAM_T)
		continue;

		if(!IsPlayerAlive(i))
		{
			iTCount--;
			continue;
		}

		iTs[iCurIndex] = i;
		iCurIndex++;
	}

	PushArrayCell(hClients, iTs[GetRandomInt(0, iTCount-1)]);

	return true;
}

public Action Command_WorldText(int client, int args)
{
	float fPos[3], fAngles[3];
	char text[128], colors[32], size[8], colorBuf[3][4];
	int iSize, color[3];

	GetClientAbsOrigin(client, fPos);
	GetClientAbsAngles(client, fAngles);

	if(args != 3)
	{
		ReplyToCommand(client, "[SM] Usage: sm_worldtext [string] [r g b] <size>");
		return Plugin_Handled;
	}

	GetCmdArg(1, text, sizeof(text));
	GetCmdArg(2, colors, sizeof(colors));
	GetCmdArg(3, size, sizeof(size));

	iSize = StringToInt(size);

	ExplodeString(colors, " ", colorBuf, sizeof(colorBuf), sizeof(colorBuf[]));

	for (int i = 0; i < 3; i++)
	{
		color[i] = StringToInt(colorBuf[i]);
	}
	Point_WorldText(fPos, fAngles, text, iSize, color[0], color[1], color[2]);
	return Plugin_Handled;
}

int Point_WorldText(float fPos[3], float fAngles[3], char[] sText = "Source 2 Engine?", int iSize = 10, int r = 255, int g = 255, int b = 255, any ...)
{
	int iEntity = CreateEntityByName("point_worldtext");

	if(iEntity == -1)
	return iEntity;

	char sBuffer[512];
	VFormat(sBuffer, sizeof(sBuffer), sText, 8);
	DispatchKeyValue(iEntity,     "message", sBuffer);

	char sSize[4];
	IntToString(iSize, sSize, sizeof(sSize));
	DispatchKeyValue(iEntity,     "textsize", sSize);

	char sColor[16];
	Format(sColor, sizeof(sColor), "%d %d %d", r, g, b);
	DispatchKeyValue(iEntity,     "color", sColor);

	TeleportEntity(iEntity, fPos, fAngles, NULL_VECTOR);

	return iEntity;
}

public void OnMapStart()
{
	g_bInBuyZoneAll = false;
	g_bInfAmmoAll = false;
	g_locationIndex = 0;
	g_isLooping = false;

	if(g_bInfAmmoHooked)
	{
		UnhookEvent("weapon_fire", Event_WeaponFire);
		g_bInfAmmoHooked = false;
	}

	/* Handle late load */
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && IsClientInGame(i))
		{
			g_bInfAmmo[i] = false;
			g_bInBuyZone[i] = false;
			g_bCommandSpy[i] = false;
			SDKHook(i, SDKHook_PostThinkPost, OnPostThinkPost);
		}
	}
}

public void OnClientPutInServer(int client)
{
	g_bInBuyZone[client] = false;
	g_bInfAmmo[client] = false;
	g_bCommandSpy[client] = false;
	SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);
}

public void OnClientPostAdminCheck(int client)
{
	g_userSaveIndex[client] = -1;
}

public void Event_WeaponFire(Handle hEvent, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	if(!g_bInfAmmoAll && !g_bInfAmmo[client])
	return;

	int weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon", 0);
	if(IsValidEntity(weapon))
	{
		if(weapon == GetPlayerWeaponSlot(client, 0) || weapon == GetPlayerWeaponSlot(client, 1))
		{
			if(GetEntProp(weapon, Prop_Send, "m_iState", 4, 0) == 2 && GetEntProp(weapon, Prop_Send, "m_iClip1", 4, 0))
			{
				int toAdd = 1;
				char weaponClassname[128];
				GetEntityClassname(weapon, weaponClassname, sizeof(weaponClassname));

				if(StrEqual(weaponClassname, "weapon_glock", true) || StrEqual(weaponClassname, "weapon_famas", true))
				{
					if(GetEntProp(weapon, Prop_Send, "m_bBurstMode"))
					{
						switch (GetEntProp(weapon, Prop_Send, "m_iClip1"))
						{
							case 1:
							{
								toAdd = 1;
							}
							case 2:
							{
								toAdd = 2;
							}
							default:
							{
								toAdd = 3;
							}
						}
					}
				}
				SetEntProp(weapon, Prop_Send, "m_iClip1", GetEntProp(weapon, Prop_Send, "m_iClip1", 4, 0) + toAdd, 4, 0);
			}
		}
	}

	return;
}

public Action Command_Health(int client, int argc)
{
	if(argc < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_hp <#userid|name> <value>");
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	int amount = 0;
	char arg2[20];
	GetCmdArg(2, arg2, sizeof(arg2));

	if(StringToIntEx(arg2, amount) == 0 || amount <= 0)
	{
		ReplyToCommand(client, "[SM] Invalid Value");
		return Plugin_Handled;
	}

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;

	if((target_count = ProcessTargetString(arg, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for(int i = 0; i < target_count; i++)
	{
		SetEntProp(target_list[i], Prop_Send, "m_iHealth", amount, 1);
	}

	ShowActivity2(client, "\x01[SM] \x04", "\x01Set health to \x04%d\x01 on target \x04%s", amount, target_name);

	return Plugin_Handled;
}

public int TheMenuHandler(Handle menu, MenuAction action, int client, int position)
{
	if(action == MenuAction_Select)
	{
		char info[64];
		GetMenuItem(menu, position, info, sizeof(info));

		if(StrContains(info, "*", false) != -1)
		{
			char StringArray2[4][64];
			int n = ExplodeString(info, "*", StringArray2, sizeof(StringArray2), sizeof(StringArray2[]));
			for(int i = 0; i <= n - 1; i++)
			{
				FakeClientCommand(client, StringArray2[i]);
				PrintToConsole(client, "Executed command: %s", StringArray2[i]);
			}
		}
		else
		{
			FakeClientCommand(client, info);
			PrintToConsole(client, "Executed command: %s", info);
		}
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action Command_ForceRevive(int client, int argc)
{
	if(argc < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_forcerevive <#userid|name>");
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;

	if((target_count = ProcessTargetString(arg, client, target_list, MAXPLAYERS, 0, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for(int i = 0; i < target_count; i++)
	{
		ForcePlayerSuicide(target_list[i]);
		CS_RespawnPlayer(target_list[i]);
	}

	ShowActivity2(client, "\x01[SM] \x04", "\x01Revived target \x04%s", target_name);

	return Plugin_Handled;
}

public Action Command_Armor(int client, int argc)
{
	if(argc < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_armor <#userid|name> <value>");
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	int amount = 0;
	char arg2[20];
	GetCmdArg(2, arg2, sizeof(arg2));

	if(StringToIntEx(arg2, amount) == 0 || amount < 0)
	{
		ReplyToCommand(client, "[SM] Invalid Value");
		return Plugin_Handled;
	}

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;

	if((target_count = ProcessTargetString(arg, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for(int i = 0; i < target_count; i++)
	{
		SetEntProp(target_list[i], Prop_Send, "m_ArmorValue", amount, 1);
	}

	ShowActivity2(client, "\x01[SM] \x04", "\x01Set kevlar to \x04%d\x01 on target \x04%s", amount, target_name);
	LogAction(client, -1, "Set kevlar to %d on target %s", amount, target_name);

	return Plugin_Handled;
}

public Action Command_Weapon(int client, int argc)
{
	if(argc < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_give <#userid|name> <weapon> [clip] [ammo]");
		return Plugin_Handled;
	}

	int ammo = 2500;
	int clip = -1;

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	char arg2[65];
	GetCmdArg(2, arg2, sizeof(arg2));

	char weapon[65];

	if(strncmp(arg2, "weapon_", 7) != 0 && strncmp(arg2, "item_", 5) != 0 && !StrEqual(arg2, "nvg", false))
	Format(weapon, sizeof(weapon), "weapon_%s", arg2);
	else
	strcopy(weapon, sizeof(weapon), arg2);

	if(StrEqual(weapon, "he"))
	StrCat(weapon, sizeof(weapon), "grenade");

	if(StrContains(weapon, "grenade", false) != -1 || StrContains(weapon, "flashbang", false) != -1 || strncmp(arg2, "item_", 5) == 0)
	ammo = -1;

	if(argc >= 3)
	{
		char arg3[20];
		GetCmdArg(3, arg3, sizeof(arg3));

		if(StringToIntEx(arg3, clip) == 0)
		{
			ReplyToCommand(client, "[SM] Invalid Clip Value");
			return Plugin_Handled;
		}
	}

	if(argc >= 4)
	{
		char arg4[20];
		GetCmdArg(4, arg4, sizeof(arg4));

		if(StringToIntEx(arg4, ammo) == 0)
		{
			ReplyToCommand(client, "[SM] Invalid Ammo Value");
			return Plugin_Handled;
		}
	}

	if(StrContains(weapon, "grenade", false) != -1 || StrContains(weapon, "flashbang", false) != -1)
	{
		int tmp = ammo;
		ammo = clip;
		clip = tmp;
	}

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;

	if((target_count = ProcessTargetString(arg, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	if(StrEqual(weapon, "nvg", false))
	{
		for(int i = 0; i < target_count; i++)
		SetEntProp(target_list[i], Prop_Send, "m_bHasNightVision", 1, 1);
	}
	else if(StrEqual(weapon, "item_defuser", false))
	{
		for(int i = 0; i < target_count; i++)
		SetEntProp(target_list[i], Prop_Send, "m_bHasDefuser", 1);
	}
	else
	{
		for(int i = 0; i < target_count; i++)
		{
			int ent = GivePlayerItem(target_list[i], weapon);

			if(ent == -1) {
				ReplyToCommand(client, "[SM] Invalid Weapon");
				return Plugin_Handled;
			}

			if(clip != -1)
			SetEntProp(ent, Prop_Send, "m_iClip1", clip);

			if(ammo != -1)
			{
				int PrimaryAmmoType = GetEntProp(ent, Prop_Data, "m_iPrimaryAmmoType");

				if(PrimaryAmmoType != -1)
				SetEntProp(target_list[i], Prop_Send, "m_iAmmo", ammo, _, PrimaryAmmoType);
			}

			if(strncmp(arg2, "item_", 5) != 0 && !StrEqual(weapon, "weapon_hegrenade", false))
			EquipPlayerWeapon(target_list[i], ent);

			if(ammo != -1)
			{
				int PrimaryAmmoType = GetEntProp(ent, Prop_Data, "m_iPrimaryAmmoType");

				if(PrimaryAmmoType != -1)
				SetEntProp(target_list[i], Prop_Send, "m_iAmmo", ammo, _, PrimaryAmmoType);
			}
		}
	}

	ShowActivity2(client, "\x01[SM] \x04", "\x01Gave \x04%s\x01 to target \x04%s", weapon, target_name);
	LogAction(client, -1, "Gave %s to target %s", weapon, target_name);

	return Plugin_Handled;
}

public Action Command_Strip(int client, int argc)
{
	if(argc < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_strip <#userid|name>");
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;

	if((target_count = ProcessTargetString(arg, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for(int i = 0; i < target_count; i++)
	{
		for(int j = 0; j < 5; j++)
		{
			int w = -1;

			while ((w = GetPlayerWeaponSlot(target_list[i], j)) != -1)
			{
				if(IsValidEntity(w))
				RemovePlayerItem(target_list[i], w);
			}
		}
	}

	ShowActivity2(client, "\x01[SM] \x04", "\x01Stripped all weapons on target \x04%s", target_name);
	LogAction(client, -1, "Stripped all weapons on target %s", target_name);

	return Plugin_Handled;
}

public Action Command_Melee(int client, int argc)
{
	if(argc < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_melee <#userid|name>");
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;

	if((target_count = ProcessTargetString(arg, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for(int i = 0; i < target_count; i++)
	{
		for(int j = 0; j < 5; j++)
		{
			int w = -1;

			while ((w = GetPlayerWeaponSlot(target_list[i], j)) != -1)
			{
				if(IsValidEntity(w))
				RemovePlayerItem(target_list[i], w);
			}
		}
		GivePlayerItem(target_list[i], "weapon_knife");
	}

	ShowActivity2(client, "\x01[SM] \x04", "\x01Forced melee on target \x04%s", target_name);
	LogAction(client, -1, "Forced melee on target %s", target_name);

	return Plugin_Handled;
}

public Action Command_BuyZone(int client, int argc)
{
	if(argc < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_buyzone <#userid|name> <0|1>");
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	int value = -1;
	char arg2[20];
	GetCmdArg(2, arg2, sizeof(arg2));

	if(StringToIntEx(arg2, value) == 0)
	{
		ReplyToCommand(client, "[SM] Invalid Value");
		return Plugin_Handled;
	}

	char target_name[MAX_TARGET_LENGTH];

	if(StrEqual(arg, "@all", false))
	{
		target_name = "all players";
		g_bInBuyZoneAll = value ? true : false;
	}
	else
	{
		int target_list[MAXPLAYERS];
		int target_count;
		bool tn_is_ml;

		if((target_count = ProcessTargetString(arg, client,	target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
		{
			ReplyToTargetError(client, target_count);
			return Plugin_Handled;
		}

		for(int i = 0; i < target_count; i++)
		{
			g_bInBuyZone[target_list[i]] = value ? true : false;
		}
	}

	ShowActivity2(client, "\x01[SM] \x04", "%s\x01 permanent buyzone on target \x04%s", (value ? "Enabled" : "Disabled"), target_name);
	LogAction(client, -1, "%s permanent buyzone on target %s", (value ? "Enabled" : "Disabled"), target_name);

	return Plugin_Handled;
}

public void OnPostThinkPost(int client)
{
	if(IsClientInGame(client) && IsPlayerAlive(client))
	{
		if(g_bInBuyZoneAll || g_bInBuyZone[client])
		SetEntProp(client, Prop_Send, "m_bInBuyZone", 1);
	}
}


public Action Command_InfAmmo(int client, int argc)
{
	if(argc < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_iammo <#userid|name> <0|1>");
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	int value = -1;
	char arg2[20];
	GetCmdArg(2, arg2, sizeof(arg2));

	if(StringToIntEx(arg2, value) == 0)
	{
		ReplyToCommand(client, "[SM] Invalid Value");
		return Plugin_Handled;
	}

	char target_name[MAX_TARGET_LENGTH];

	if(StrEqual(arg, "@all", false))
	{
		target_name = "all players";
		g_bInfAmmoAll = value ? true : false;

		if(!g_bInfAmmoAll)
		{
			for(int i = 0; i < MAXPLAYERS; i++)
			g_bInfAmmo[i] = false;
		}
	}
	else
	{
		int target_list[MAXPLAYERS];
		int target_count;
		bool tn_is_ml;

		if((target_count = ProcessTargetString(arg, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
		{
			ReplyToTargetError(client, target_count);
			return Plugin_Handled;
		}

		for(int i = 0; i < target_count; i++)
		{
			g_bInfAmmo[target_list[i]] = value ? true : false;
		}
	}

	ShowActivity2(client, "\x01[SM] \x04", "%s\x01 infinite ammo on target \x04%s", (value ? "Enabled" : "Disabled"), target_name);
	LogAction(client, -1, "%s infinite ammo on target %s", (value ? "Enabled" : "Disabled"), target_name);

	if(g_bInfAmmoAll)
	{
		if(!g_bInfAmmoHooked)
		{
			HookEvent("weapon_fire", Event_WeaponFire);
			g_bInfAmmoHooked = true;
		}

		return Plugin_Handled;
	}

	for(int i = 0; i < MAXPLAYERS; i++)
	{
		if(g_bInfAmmo[i])
		{
			if(!g_bInfAmmoHooked)
			{
				HookEvent("weapon_fire", Event_WeaponFire);
				g_bInfAmmoHooked = true;
			}

			return Plugin_Handled;
		}
	}

	if(g_bInfAmmoHooked)
	{
		UnhookEvent("weapon_fire", Event_WeaponFire);
		g_bInfAmmoHooked = false;
	}

	return Plugin_Handled;
}

public Action Command_Speed(int client, int argc)
{
	if(argc < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_speed <#userid|name> <value>");
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	float speed = 0.0;
	char arg2[20];
	GetCmdArg(2, arg2, sizeof(arg2));

	if(StringToFloatEx(arg2, speed) < 0.0)
	{
		ReplyToCommand(client, "[SM] Invalid Value");
		return Plugin_Handled;
	}

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;

	if((target_count = ProcessTargetString(arg, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for(int i = 0; i < target_count; i++)
	{
		SetEntPropFloat(target_list[i], Prop_Data, "m_flLaggedMovementValue", speed);
	}

	ShowActivity2(client, "\x01[SM] \x04", "\x01Set speed to \x04%.2f\x01 on target \x04%s", speed, target_name);
	LogAction(client, -1, "Set speed to %.2f on target %s", speed, target_name);

	return Plugin_Handled;
}

public Action Command_Respawn(int client, int argc)
{
	if(argc < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_respawn <#userid|name>");
		return Plugin_Handled;
	}

	char sArgs[64];
	char sTargetName[MAX_TARGET_LENGTH];
	int iTargets[MAXPLAYERS];
	int iTargetCount;
	bool bIsML;
	bool bDidRespawn;

	GetCmdArg(1, sArgs, sizeof(sArgs));

	if((iTargetCount = ProcessTargetString(sArgs, client, iTargets, MAXPLAYERS, COMMAND_FILTER_DEAD, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}

	for(int i = 0; i < iTargetCount; i++)
	{
		if(GetClientTeam(iTargets[i]) == CS_TEAM_SPECTATOR || GetClientTeam(iTargets[i]) == CS_TEAM_NONE)
		continue;

		bDidRespawn = true;
		CS_RespawnPlayer(iTargets[i]);
	}

	if(bDidRespawn)
	{
		ShowActivity2(client, "\x01[SM] \x04", "\x01Respawned \x04%s", sTargetName);
		LogAction(client, -1, "Respawned %s", sTargetName);
	}

	return Plugin_Handled;
}

public Action Command_Cash(int client, int argc)
{
	if(argc < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_cash <#userid|name> <value>");
		return Plugin_Handled;
	}

	int iCash;
	char sArgs[64];
	char sArgs2[32];
	char sTargetName[MAX_TARGET_LENGTH];
	int iTargets[MAXPLAYERS];
	int iTargetCount;
	bool bIsML;

	GetCmdArg(1, sArgs, sizeof(sArgs));
	GetCmdArg(2, sArgs2, sizeof(sArgs2));

	iCash = StringToInt(sArgs2);

	if((iTargetCount = ProcessTargetString(sArgs, client, iTargets, MAXPLAYERS, COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}

	for(int i = 0; i < iTargetCount; i++)
	{
		SetEntProp(iTargets[i], Prop_Send, "m_iAccount", iCash);
	}

	ShowActivity2(client, "\x01[SM] \x04", "\x01Set \x04%s\x01's cash to \x04%i", sTargetName, StringToInt(sArgs2));
	LogAction(client, -1, "Set %s's cash to %i", sTargetName, StringToInt(sArgs2));

	return Plugin_Handled;
}

public Action Command_ClanTag(int client, int argc)
{
	if(argc < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_clantag <#userid|name> <clantag>");
		return Plugin_Handled;
	}

	char sArgs[64];
	char sArgs2[32];
	char sTargetName[MAX_TARGET_LENGTH];
	int iTargets[MAXPLAYERS];
	int iTargetCount;
	bool bIsML;

	GetCmdArg(1, sArgs, sizeof(sArgs));
	GetCmdArg(2, sArgs2, sizeof(sArgs2));

	if((iTargetCount = ProcessTargetString(sArgs, client, iTargets, MAXPLAYERS, 0, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}

	for(int i = 0; i < iTargetCount; i++)
	{
		CS_SetClientClanTag(iTargets[i], sArgs2);
	}

	ShowActivity2(client, "\x01[SM] \x04", "\x01Set \x04%s\x01's clantag to \x04%s", sTargetName, sArgs2);
	LogAction(client, -1, "Set %s's clantag to %s", sTargetName, sArgs2);

	return Plugin_Handled;
}

public Action Command_CreateMenu(int client, int argc)
{
	Handle menu = CreateMenu(TheMenuHandler);

	char buffer[512];
	GetCmdArgString(buffer, sizeof(buffer));

	StripQuotes(buffer);

	char StringArray[18][64];

	int n = ExplodeString(buffer, "|", StringArray, sizeof(StringArray), sizeof(StringArray[]));

	if(n == 3 || n == 5 || n == 7 || n == 9 || n == 11 || n == 13 || n == 15 || n == 17)
	{
		SetMenuTitle(menu, StringArray[0]);

		if(n >= 3)
		{
			AddMenuItem(menu, StringArray[1], StringArray[2]);
		}
		if(n >= 5)
		{
			AddMenuItem(menu, StringArray[3], StringArray[4]);
		}
		if(n >= 7)
		{
			AddMenuItem(menu, StringArray[5], StringArray[6]);
		}
		if(n >= 9)
		{
			AddMenuItem(menu, StringArray[7], StringArray[8]);
		}
		if(n >= 11)
		{
			AddMenuItem(menu, StringArray[9], StringArray[10]);
		}
		if(n >= 13)
		{
			AddMenuItem(menu, StringArray[11], StringArray[12]);
		}
		if(n >= 15)
		{
			AddMenuItem(menu, StringArray[13], StringArray[14]);
		}
		if(n >= 17)
		{
			AddMenuItem(menu, StringArray[15], StringArray[16]);
		}

		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME_FOREVER);

		return Plugin_Handled;
	}
	else
	{
		ReplyToCommand(client, "[SM] Invalid number of arguments, valid arguments are 3, 5, 7, 9, 11, 13, 15, or 17. Format: Arg1 - Title, Repeat: Arg2 - Execute / Arg3 - Title. The | character separates arguments, and * can be used to run multiple commands.");
		return Plugin_Handled;
	}
}

public Action Command_Targetname(int client, int argc)
{
	if(argc < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_targetname <#userid|name> <targetname>");
		return Plugin_Handled;
	}

	char sArgs[64];
	char sArgs2[32];
	char sTargetName[MAX_TARGET_LENGTH];
	int iTargets[MAXPLAYERS];
	int iTargetCount;
	bool bIsML;

	GetCmdArg(1, sArgs, sizeof(sArgs));
	GetCmdArg(2, sArgs2, sizeof(sArgs2));

	if((iTargetCount = ProcessTargetString(sArgs, client, iTargets, MAXPLAYERS, 0, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}

	for(int i = 0; i < iTargetCount; i++)
	{
		DispatchKeyValue(iTargets[i], "targetname", sArgs2);
	}

	ShowActivity2(client, "\x01[SM] \x04", "\x01Set \x04%s\x01's targetname to \x04%s", sTargetName, sArgs2);
	LogAction(client, -1, "Set %s's targetname to %s", sTargetName, sArgs2);

	return Plugin_Handled;
}

public Action Command_MVP(int client, int argc)
{
	if(argc < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_mvp <#userid|name> <value>");
		return Plugin_Handled;
	}

	int iCash;
	char sArgs[64];
	char sArgs2[32];
	char sTargetName[MAX_TARGET_LENGTH];
	int iTargets[MAXPLAYERS];
	int iTargetCount;
	bool bIsML;

	GetCmdArg(1, sArgs, sizeof(sArgs));
	GetCmdArg(2, sArgs2, sizeof(sArgs2));

	iCash = StringToInt(sArgs2);

	if((iTargetCount = ProcessTargetString(sArgs, client, iTargets, MAXPLAYERS, 0, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}

	for(int i = 0; i < iTargetCount; i++)
	{
		CS_SetMVPCount(iTargets[i], iCash);
	}

	ShowActivity2(client, "\x01[SM] \x04", "\x01Set \x04%s\x01's MVPs to \x04%i", sTargetName, StringToInt(sArgs2));
	LogAction(client, -1, "Set %s's MVPs to %i", sTargetName, StringToInt(sArgs2));

	return Plugin_Handled;
}

public Action Command_Kills(int client, int argc)
{
	if(argc < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_kills <#userid|name> <value>");
		return Plugin_Handled;
	}

	int iCash;
	char sArgs[64];
	char sArgs2[32];
	char sTargetName[MAX_TARGET_LENGTH];
	int iTargets[MAXPLAYERS];
	int iTargetCount;
	bool bIsML;

	GetCmdArg(1, sArgs, sizeof(sArgs));
	GetCmdArg(2, sArgs2, sizeof(sArgs2));

	iCash = StringToInt(sArgs2);

	if((iTargetCount = ProcessTargetString(sArgs, client, iTargets, MAXPLAYERS, 0, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}

	for(int i = 0; i < iTargetCount; i++)
	{
		SetEntProp(iTargets[i], Prop_Data, "m_iFrags", iCash);
	}

	ShowActivity2(client, "\x01[SM] \x04", "\x01Set \x04%s\x01's kills to \x04%i", sTargetName, StringToInt(sArgs2));
	LogAction(client, -1, "Set %s's kills to %i", sTargetName, StringToInt(sArgs2));

	return Plugin_Handled;
}

public Action Command_Deaths(int client, int argc)
{
	if(argc < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_deaths <#userid|name> <value>");
		return Plugin_Handled;
	}

	int iCash;
	char sArgs[64];
	char sArgs2[32];
	char sTargetName[MAX_TARGET_LENGTH];
	int iTargets[MAXPLAYERS];
	int iTargetCount;
	bool bIsML;

	GetCmdArg(1, sArgs, sizeof(sArgs));
	GetCmdArg(2, sArgs2, sizeof(sArgs2));

	iCash = StringToInt(sArgs2);

	if((iTargetCount = ProcessTargetString(sArgs, client, iTargets, MAXPLAYERS, 0, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}

	for(int i = 0; i < iTargetCount; i++)
	{
		SetEntProp(iTargets[i], Prop_Data, "m_iDeaths", iCash);
	}

	ShowActivity2(client, "\x01[SM] \x04", "\x01Set \x04%s\x01's deaths to \x04%i", sTargetName, StringToInt(sArgs2));
	LogAction(client, -1, "Set %s's deaths to %i", sTargetName, StringToInt(sArgs2));

	return Plugin_Handled;
}

public Action Command_Score(int client, int argc)
{
	if(argc < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_score <#userid|name> <value>");
		return Plugin_Handled;
	}

	int iCash;
	char sArgs[64];
	char sArgs2[32];
	char sTargetName[MAX_TARGET_LENGTH];
	int iTargets[MAXPLAYERS];
	int iTargetCount;
	bool bIsML;

	GetCmdArg(1, sArgs, sizeof(sArgs));
	GetCmdArg(2, sArgs2, sizeof(sArgs2));

	iCash = StringToInt(sArgs2);

	if((iTargetCount = ProcessTargetString(sArgs, client, iTargets, MAXPLAYERS, 0, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}

	for(int i = 0; i < iTargetCount; i++)
	{
		CS_SetClientContributionScore(iTargets[i], iCash);
	}

	ShowActivity2(client, "\x01[SM] \x04", "\x01Set \x04%s\x01's score to \x04%i", sTargetName, StringToInt(sArgs2));
	LogAction(client, -1, "Set %s's score to %i", sTargetName, StringToInt(sArgs2));

	return Plugin_Handled;
}

public Action Command_Assists(int client, int argc)
{
	if(argc < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_assists <#userid|name> <value>");
		return Plugin_Handled;
	}

	int iCash;
	char sArgs[64];
	char sArgs2[32];
	char sTargetName[MAX_TARGET_LENGTH];
	int iTargets[MAXPLAYERS];
	int iTargetCount;
	bool bIsML;

	GetCmdArg(1, sArgs, sizeof(sArgs));
	GetCmdArg(2, sArgs2, sizeof(sArgs2));

	iCash = StringToInt(sArgs2);

	if((iTargetCount = ProcessTargetString(sArgs, client, iTargets, MAXPLAYERS, 0, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}

	for(int i = 0; i < iTargetCount; i++)
	{
		CS_SetClientAssists(iTargets[i], iCash);
	}

	ShowActivity2(client, "\x01[SM] \x04", "\x01Set \x04%s\x01's assists to \x04%i", sTargetName, StringToInt(sArgs2));
	LogAction(client, -1, "Set %s's assists to %i", sTargetName, StringToInt(sArgs2));

	return Plugin_Handled;
}

public Action Command_HintText(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_hinttext <message>.");
		return Plugin_Handled;
	}

	char arg[511];
	GetCmdArg(1, arg, sizeof(arg));

	PrintHintTextToAll(arg);

	return Plugin_Handled;
}
public Action Command_ConsoleSay(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_consolesay <message>.");
		return Plugin_Handled;
	}

	char arg[2048];
	GetCmdArg(1, arg, sizeof(arg));

	CPrintToChatAll(arg);

	return Plugin_Handled;
}
public Action Command_ConsoleSay2(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_consolesay2 <message>.");
		return Plugin_Handled;
	}

	char arg[2048];
	GetCmdArg(1, arg, sizeof(arg));

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			PrintToConsole(i, arg);
		}
	}
	return Plugin_Handled;
}

public Action Command_ModelScale(int client, int argc)
{
	if(argc < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_resize/sm_modelscale <#userid|name> <scale>");
		return Plugin_Handled;
	}

	float fScale;
	char sArgs[64];
	char sArgs2[32];
	char sTargetName[MAX_TARGET_LENGTH];
	int iTargets[MAXPLAYERS];
	int iTargetCount;
	bool bIsML;

	GetCmdArg(1, sArgs, sizeof(sArgs));
	GetCmdArg(2, sArgs2, sizeof(sArgs2));

	fScale = StringToFloat(sArgs2);

	if((iTargetCount = ProcessTargetString(sArgs, client, iTargets, MAXPLAYERS, COMMAND_FILTER_ALIVE, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}

	for(int i = 0; i < iTargetCount; i++)
	{
		SetEntPropFloat(iTargets[i], Prop_Send, "m_flModelScale", fScale);
	}

	ShowActivity2(client, "\x01[SM] \x04", "\x01Set \x04%s\x01's model scale to \x04%.2f", sTargetName, fScale);
	LogAction(client, -1, "Set %s's model scale to %.2f", sTargetName, fScale);

	return Plugin_Handled;
}

stock bool TraceEntityFilter_FilterCaller(int entity, int contentsMask, int client)
{
	return entity != client;
}

public Action Command_WAILA(int client, int argc)
{
	if(!client)
	{
		PrintToServer("[SM] Cannot use command from server console.");
		return Plugin_Handled;
	}

	if(argc == 0)
	{
		float vecEyeAngles[3];
		float vecEyeOrigin[3];

		GetClientEyeAngles(client, vecEyeAngles);
		GetClientEyePosition(client, vecEyeOrigin);

		Handle hTraceRay = TR_TraceRayFilterEx(vecEyeOrigin, vecEyeAngles, MASK_ALL, RayType_Infinite, TraceEntityFilter_FilterCaller, client);

		if(TR_DidHit(hTraceRay))
		{
			float vecEndPos[3];
			char sModelPath[PLATFORM_MAX_PATH];
			char sClsName[64];
			char sNetClsName[64];
			char sTargetname[64];
			int iEntity;
			int iEntityModelIdx;

			TR_GetEndPosition(vecEndPos, hTraceRay);

			if((iEntity = TR_GetEntityIndex(hTraceRay)) <= 0)
			{
				PrintToChat(client, "[SM] Trace hit the world.");

				delete hTraceRay;

				return Plugin_Handled;
			}

			GetEntPropString(iEntity, Prop_Data, "m_ModelName", sModelPath, sizeof(sModelPath));
			GetEntityClassname(iEntity, sClsName, sizeof(sClsName));
			GetEntityNetClass(iEntity, sNetClsName, sizeof(sNetClsName));
			GetEntPropString(iEntity, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));
			iEntityModelIdx = GetEntProp(iEntity, Prop_Send, "m_nModelIndex");

			PrintToConsole(client, "Entity Index: %i\nTarget name: %s\nModel Path: %s\nModel Index: %i\nClass Name: %s\nNet Class Name: %s", iEntity, sTargetname, sModelPath, iEntityModelIdx, sClsName, sNetClsName);

			PrintToChat(client, "[SM] Trace hit something, check your console for more information.");

			delete hTraceRay;

			return Plugin_Handled;
		}

		delete hTraceRay;

		PrintToChat(client, "[SM] Couldn't find anything under your crosshair.");
	}
	else
	{
		if(argc != 1)
		{
			ReplyToCommand(client, "[SM] Usage: sm_waila <#userid|name>");
			return Plugin_Handled;
		}

		char arg[64];
		GetCmdArg(1, arg, sizeof(arg));

		int iEntity = FindTarget(client, arg, true, false);
		if (iEntity == -1)
		{
			return Plugin_Handled;
		}

		char sModelPath[PLATFORM_MAX_PATH];
		char sClsName[64];
		char sNetClsName[64];
		char sTargetname[64];
		int iEntityModelIdx;

		GetEntPropString(iEntity, Prop_Data, "m_ModelName", sModelPath, sizeof(sModelPath));
		GetEntityClassname(iEntity, sClsName, sizeof(sClsName));
		GetEntityNetClass(iEntity, sNetClsName, sizeof(sNetClsName));
		GetEntPropString(iEntity, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));
		iEntityModelIdx = GetEntProp(iEntity, Prop_Send, "m_nModelIndex");

		PrintToChat(client, "[SM] Player found, check your console for more information.");
		PrintToConsole(client, "Entity Index: %i\nTarget name: %s\nModel Path: %s\nModel Index: %i\nClass Name: %s\nNet Class Name: %s", iEntity, sTargetname, sModelPath, iEntityModelIdx, sClsName, sNetClsName);
	}
	return Plugin_Handled;
}

public Action Command_Spectate(int client, int argc)
{
	if (!client)
	{
		PrintToServer("[SM] Cannot use command from server console.");
		return Plugin_Handled;
	}

	if (!argc)
	{
		if (GetClientTeam(client) != CS_TEAM_SPECTATOR)
		{
			ForcePlayerSuicide(client);
			ChangeClientTeam(client, CS_TEAM_SPECTATOR);
		}

		return Plugin_Handled;
	}

	char sTarget[MAX_TARGET_LENGTH];
	GetCmdArg(1, sTarget, sizeof(sTarget));

	int iTarget;
	if ((iTarget = FindTarget(client, sTarget, false, false)) <= 0)
	return Plugin_Handled;

	if (!IsPlayerAlive(iTarget))
	{
		ReplyToCommand(client, "[SM] %t", "Target must be alive");
		return Plugin_Handled;
	}

	if (GetClientTeam(client) != CS_TEAM_SPECTATOR)
	{
		ForcePlayerSuicide(client);
		ChangeClientTeam(client, CS_TEAM_SPECTATOR);
	}

	SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", iTarget);
	PrintToChat(client, "\x01[SM] Spectating \x04%N\x01.", iTarget);

	return Plugin_Handled;
}

public Action Command_Fexec(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_fexec <client|#id> <command>");
		return Plugin_Handled;
	}

	char pattern[64];
	char sTargetName[MAX_TARGET_LENGTH];
	int iTargets[MAXPLAYERS];
	int iTargetCount;
	bool bIsML;

	GetCmdArg(1, pattern, sizeof(pattern));

	if((iTargetCount = ProcessTargetString(pattern, client, iTargets, MAXPLAYERS, 0, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}
	char command[64];
	GetCmdArg(2, command, sizeof(command));
	int i;
	while (i < iTargetCount)
	{
		PerformFexec(client, iTargets[i], command);
		i++;
	}
	return Plugin_Handled;
}

public Action Command_BotSay(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_botsay <client|#id> <message>");
		return Plugin_Handled;
	}

	char pattern[64];
	char sTargetName[MAX_TARGET_LENGTH];
	int iTargets[MAXPLAYERS];
	int iTargetCount;
	bool bIsML;

	GetCmdArg(1, pattern, sizeof(pattern));

	if((iTargetCount = ProcessTargetString(pattern, client, iTargets, MAXPLAYERS, 0, sTargetName, sizeof(sTargetName), bIsML)) <= 0)
	{
		ReplyToTargetError(client, iTargetCount);
		return Plugin_Handled;
	}
	char message[128+16];
	GetCmdArg(2, message, sizeof(message));
	Format(message, sizeof(message), "say %s", message);
	int i;
	while (i < iTargetCount)
	{
		PerformFexec(client, iTargets[i], message);
		i++;
	}
	return Plugin_Handled;
}

public void PerformFexec(int client, int target, char[] command)
{
	FakeClientCommandEx(target, command);
	LogAction(client, target, "\"%L\" fake-executed the command \"%s\" on \"%L\"", client, command, target);
	return;
}

public Action Command_God(int client, int argc)
{
	if(argc < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_god <#userid|name> <0|1>");
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	int value = -1;
	char arg2[20];
	GetCmdArg(2, arg2, sizeof(arg2));

	if(StringToIntEx(arg2, value) == 0)
	{
		ReplyToCommand(client, "[SM] Invalid Value");
		return Plugin_Handled;
	}

	char target_name[MAX_TARGET_LENGTH];

	if(StrEqual(arg, "@all", false))
	{
		target_name = "all players";
	}
	else
	{
		int target_list[MAXPLAYERS];
		int target_count;
		bool tn_is_ml;

		if((target_count = ProcessTargetString(arg, client,	target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
		{
			ReplyToTargetError(client, target_count);
			return Plugin_Handled;
		}

		for(int i = 0; i < target_count; i++)
		{
			PerformGod(client, target_list[i], value ? true : false);
		}
	}

	ShowActivity2(client, "\x01[SM] \x04", "%s\x01 godmode on target \x04%s", (value ? "Enabled" : "Disabled"), target_name);
	LogAction(client, -1, "%s godmode on target %s", (value ? "Enabled" : "Disabled"), target_name);

	return Plugin_Handled;
}

public void PerformGod(int client, int target, bool god)
{
	SetEntProp(target, Prop_Data, "m_takedamage", god ? 0 : 2, 1, 0);
	LogAction(client, target, "\"%L\" set \"%L\" godmode state to \"%i\"", client, target, god);
	return;
}
