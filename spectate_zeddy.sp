#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma newdecls required

public Plugin myinfo =
{
	name		= "Spectate",
	description	= "Adds a command to spectate specific players.",
	author		= "AntiTeal",
	version		= "1.0",
	url			= ""
}

public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	RegConsoleCmd("sm_spectate", Command_Spectate, "Spectate a player.");
	RegConsoleCmd("sm_spec", Command_Spectate, "Spectate a player.");

	AddCommandListener(Command_JoinTeam, "jointeam");
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

public Action Command_JoinTeam(int client, const char[] command, int argc) 
{ 
	if (!client)
	{
		return Plugin_Continue;
	}
	
	char szTeam[4]; 
	GetCmdArgString(szTeam, sizeof(szTeam)); 
	int iTeam = StringToInt(szTeam); 

	if (1 <= iTeam <= 3)
	{ 
		ChangeClientTeam(client, iTeam); 
		return Plugin_Handled; 
	} 
	
	return Plugin_Continue; 
}