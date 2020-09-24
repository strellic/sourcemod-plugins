#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

bool g_bDeadMuted[MAXPLAYERS+1];

public Plugin myinfo =
{
	name = "Mute Dead",
	description = "It mutes dead players",
	author = "R3TROATTACK + AntiTeal",
	version = "1.00",
	url = "www.steam-gamers.net/forum/forum.php"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_md", Command_MuteDead);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
}

public void OnClientPostAdminCheck(int client)
{
	g_bDeadMuted[client] = false;
}

public Action Command_MuteDead(int client, int args)
{
	if (client <= 0 || client > MaxClients)
	{
		return Plugin_Handled;
	}

	g_bDeadMuted[client] = !g_bDeadMuted[client];
	if (g_bDeadMuted[client])
	{
		PrintToChat(client, " [Mute-Dead] \x01Dead players are now muted!");
		MuteDeadPlayers(client);
	}
	else
	{
		PrintToChat(client, " [Mute-Dead] \x01Dead players are now not muted!");
		UnmuteDeadPlayers(client);
	}
	return Plugin_Handled;
}

public void Event_PlayerDeath(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	for(int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (!IsPlayerAlive(i) && g_bDeadMuted[client])
			{
				SetListenOverride(client, i, Listen_No);
				SetListenOverride(i, client, Listen_No);
			}
			SetListenOverride(client, i, Listen_Default);
			SetListenOverride(i, client, Listen_Default);
		}
	}
}

public void Event_RoundEnd(Event event, char[] name, bool dontBroadcast)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			UnmuteDeadPlayers(i);
		}
	}
}

public void MuteDeadPlayers(int client)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			if (!IsPlayerAlive(i))
			{
				SetListenOverride(client, i, Listen_No);
				SetListenOverride(i, client, Listen_No);
			}
			SetListenOverride(client, i, Listen_Default);
			SetListenOverride(i, client, Listen_Default);
		}
	}
}

public void UnmuteDeadPlayers(int client)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			SetListenOverride(client, i, Listen_Default);
			SetListenOverride(i, client, Listen_Default);
		}
	}
}