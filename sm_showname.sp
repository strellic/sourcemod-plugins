#pragma semicolon 1
#include <sourcemod>
#include <clientprefs>
#include <sdktools>
#include <cstrike>
#include <zombiereloaded>

new bool:g_bShowName[MAXPLAYERS+1];
new Handle:ShowName_Cookie = INVALID_HANDLE;

char humanFormat[256], zombieFormat[256], zombieFormat2[256];

#define PLUGIN_VERSION "1.5"

public Plugin:myinfo =
{
	name = "ShowNames",
	author = "AntiTeal",
	description = "Shows the name of the Player you are currently aiming at.",
	version = PLUGIN_VERSION,
	url = "www.joinsg.net"
};

public OnPluginStart()
{
	CreateConVar("sm_shownames_version", PLUGIN_VERSION, "Plugin Version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);

	humanFormat = "<font color='#0066FF' size='20'>Human: <font color='#FFFFFF'>%s</font><br><font color='#0066FF'>Health: </font><font color='#FFFFFF'>%i HP</font><br><font color='#0066FF'>ID: </font><font color='#FFFFFF'>#%i</font>";
	zombieFormat = "<font color='#FF0000' size='20'>Zombie: <font color='#FFFFFF'>%s</font><br><font color='#FF0000'>Health: </font><font color='#FFFFFF'>%i HP (-%i DMG)</font><br><font color='#FF0000'>ID: </font><font color='#FFFFFF'>#%i</font>";
	zombieFormat2 = "<font color='#FF0000' size='20'>Zombie: <font color='#FFFFFF'>%s</font><br><font color='#FF0000'>Health: </font><font color='#FFFFFF'>%i HP</font><br><font color='#FF0000'>ID: </font><font color='#FFFFFF'>#%i</font>";

	RegConsoleCmd("sm_showname", Command_ShowNames);
	RegConsoleCmd("sm_shownames", Command_ShowNames);

	RegConsoleCmd("sm_showdamage", Command_ShowNames);
	RegConsoleCmd("sm_sd", Command_ShowNames);

	CreateTimer(0.0, AimName, _, TIMER_REPEAT);
	ShowName_Cookie = RegClientCookie("showname_cookie", "Toggle seeing PlayerNames in HUD.", CookieAccess_Protected);
	for (new i = 1; i <= MaxClients; ++i)
	{
		if (!AreClientCookiesCached(i))
		{
			continue;
		}
		
		OnClientCookiesCached(i);
	}

	HookEvent("player_hurt", Event_PlayerHurt);
}

public OnClientCookiesCached(i)
{
	new String:sValue[8];
	GetClientCookie(i, ShowName_Cookie, sValue, sizeof(sValue));
	g_bShowName[i] = (sValue[0] != '\0' && StringToInt(sValue));
}

public Action:Command_ShowNames(client, args)
{	
	if (!g_bShowName[client])
	{
		PrintToChat(client, "[SM] ShowNames enabled.");
		g_bShowName[client] = true;
		SetClientCookie(client, ShowName_Cookie, "1");
		return Plugin_Handled;
	}
	if (g_bShowName[client])
	{
		PrintToChat(client, "[SM] ShowNames disabled.");
		g_bShowName[client] = false;
		SetClientCookie(client, ShowName_Cookie, "0");
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

stock TraceClientViewEntity(client)
{
	new Float:m_vecOrigin[3];
	new Float:m_angRotation[3];

	GetClientEyePosition(client, m_vecOrigin);
	GetClientEyeAngles(client, m_angRotation);

	new Handle:tr = TR_TraceRayFilterEx(m_vecOrigin, m_angRotation, MASK_VISIBLE, RayType_Infinite, TRDontHitSelf, client);
	new pEntity = -1;

	if (TR_DidHit(tr))
	{
		pEntity = TR_GetEntityIndex(tr);
		CloseHandle(tr);
		return pEntity;
	}

	if(tr != INVALID_HANDLE)
	{
		CloseHandle(tr);
	}
	
	return -1;
}

public bool:TRDontHitSelf(entity, mask, any:data)
{
	return (1 <= entity <= MaxClients && entity != data); 
}

public Action:AimName(Handle:AimName, any Client)
{
	for(new i = 1; i <= MaxClients; i++)
	{
		if (g_bShowName[i])
		{
			if (IsClientInGame(i))
			{
				new target = TraceClientViewEntity(i);
				if(target > 0 && target <= MaxClients && IsClientInGame(target) && IsPlayerAlive(target))
				{
					new health = GetClientHealth(target);
					new id = GetClientUserId(target);
					char name[MAX_NAME_LENGTH];

					GetClientName(target, name, sizeof(name));
					ReplaceString(name, sizeof(name), "<", "&lt;", false);
					ReplaceString(name, sizeof(name), ">", "&gt;", false);

					if(IsPlayerAlive(i) && ZR_IsClientHuman(i))
					{
						if(ZR_IsClientHuman(target))
						{
							PrintHintText(i, humanFormat, name, health, id);
						}
					}
					else
					{
						if (ZR_IsClientHuman(target))
						{
							PrintHintText(i, humanFormat, name, health, id);
						}
						if (ZR_IsClientZombie(target))
						{
							PrintHintText(i, zombieFormat2, name, health, id);
						}
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action:Event_PlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{	
	new client = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(client && IsClientInGame(client) && g_bShowName[client])
	{
		new victim = GetClientOfUserId(GetEventInt(event, "userid"));
		new health = GetClientHealth(victim);
		char playerName[MAX_NAME_LENGTH];

		GetClientName(victim, playerName, sizeof(playerName));
		ReplaceString(playerName, sizeof(playerName), "<", "&lt;", false);
		ReplaceString(playerName, sizeof(playerName), ">", "&gt;", false);

		if(IsPlayerAlive(client) && health > 0 && ZR_IsClientHuman(client) && ZR_IsClientZombie(victim))
		{
			new id = GetClientUserId(victim);
			new damage = GetEventInt(event, "dmg_health");
			PrintHintText(client, zombieFormat, playerName, health, damage, id);
		}
	}
}
