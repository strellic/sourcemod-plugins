#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>

#pragma newdecls required
#define PLUGIN_VERSION "1.0"

public Plugin myinfo = 
{
	name = "Deadmute",
	author = "AntiTeal",
	description = "Allows dead players to speak for a set period of time after they die.",
	version = PLUGIN_VERSION,
	url = "https://steam-gamers.net"
};

ConVar g_cVMuteDelay = null;
Handle g_hMuteTimers[MAXPLAYERS+1];
bool g_bDeadMuted[MAXPLAYERS+1] = {false, ...};

public void OnPluginStart()
{
	CreateConVar("sm_deadmute_version", PLUGIN_VERSION, "Plugin Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);

	g_cVMuteDelay = CreateConVar("sm_deadmute_mutedelay", "10", "How long after a person dies until they are muted.", _, true, 0.0, false, _);
}

public int GetAlivePlayersCount(int iTeam) 
{ 
	int iCount, i; iCount = 0; 
	for(i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == iTeam)
		{
			iCount++; 
		}
	}
	return iCount; 
}

public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int team = GetClientTeam(client);
	float muteDelay = g_cVMuteDelay.FloatValue;

	if(GetAlivePlayersCount(team) > 0)
	{
		PrintToChat(client, "[SM] You have %.2f seconds before you are muted.", muteDelay);
		g_hMuteTimers[client] = CreateTimer(muteDelay, MutePlayer, client);
	}
}

public Action MutePlayer(Handle timer, any client)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) != 1)
		{
			SetListenOverride(i, client, Listen_No);
			g_bDeadMuted[client] = true;
		}
	}
	PrintToChat(client, "[SM] You are now muted!");
	g_hMuteTimers[client] = null;
}

public void OnClientDisconnect(int client)
{
	if (g_hMuteTimers[client] != null)
	{
		KillTimer(g_hMuteTimers[client]);
		g_hMuteTimers[client] = null;
	}
	g_bDeadMuted[client] = false;
}

public void OnPluginEnd()
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && g_bDeadMuted[client])
		{
			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i))
				{
					SetListenOverride(i, client, Listen_Default);
				}
			}
		}
	}
}

public Action Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (g_hMuteTimers[client] != null)
	{
		KillTimer(g_hMuteTimers[client]);
		g_hMuteTimers[client] = null;
	}

	if(g_bDeadMuted[client])
	{
		g_bDeadMuted[client] = false;
		for(int i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				SetListenOverride(i, client, Listen_Default);
			}
		}
	}
}
