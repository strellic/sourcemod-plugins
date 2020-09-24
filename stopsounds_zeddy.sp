#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <colors_csgo>

new g_iStopSound[MAXPLAYERS+1], bool:g_bHooked, bool:g_bSilenceSound[MAXPLAYERS+1];
new Handle:g_hClientCookie = INVALID_HANDLE;
ConVar gcV_Volume;
float fVolume = 1.0;

public Plugin:myinfo =
{
	name = "Stop Weapon Sounds",
	author = "GoD-Tony",
	description = "Allows clients to modify hearing weapon sounds",
	version = "1.0",
	url = ""
};

public OnPluginStart()
{
	g_hClientCookie = RegClientCookie("stopsound", "Toggle hearing weapon sounds", CookieAccess_Private);
	SetCookieMenuItem(StopSoundCookieHandler, g_hClientCookie, "Stop Weapon Sounds");

	AddTempEntHook("Shotgun Shot", CSS_Hook_ShotgunShot);
	AddNormalSoundHook(Hook_NormalSound);
	
	RegConsoleCmd("sm_stopsound", Command_StopSound, "Toggle hearing weapon sounds");
	RegConsoleCmd("sm_stopsounds", Command_StopSound, "Toggle hearing weapon sounds");

	gcV_Volume = CreateConVar("sm_stopsounds_silencer_volume", "0.5", "", _, true, 0.0, true, 1.0);
	fVolume = gcV_Volume.FloatValue;
	gcV_Volume.AddChangeHook(OnConVarChange);

	for (new i = 1; i <= MaxClients; ++i)
	{
		if (!AreClientCookiesCached(i))
		{
			continue;
		}
		
		OnClientCookiesCached(i);
	}
}

public void OnConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (convar == gcV_Volume) {
		fVolume = convar.FloatValue;
	}
}

public OnMapStart()
{
	PrecacheSound("~)weapons/usp/usp1.wav", true);
}

public StopSoundCookieHandler(client, CookieMenuAction:action, any:info, String:buffer[], maxlen)
{
	switch (action)
	{
		case CookieMenuAction_DisplayOption:
		{
		}
		
		case CookieMenuAction_SelectOption:
		{
			if(CheckCommandAccess(client, "sm_stopsound", 0))
			{
				PrepareMenu(client);
			}
			else
			{
				ReplyToCommand(client, "[SM] You have no access!");
			}
		}
	}
}

PrepareMenu(client)
{
	new Handle:menu = CreateMenu(YesNoMenu, MENU_ACTIONS_DEFAULT|MenuAction_DrawItem|MenuAction_DisplayItem|MenuAction_Display);
	SetMenuTitle(menu, "Stop Weapon Sounds Menu");
	AddMenuItem(menu, "0", "Disable");
	AddMenuItem(menu, "1", "Stop Sound");
	AddMenuItem(menu, "2", "Silencer Sound");
	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, 20);
}

public YesNoMenu(Handle:menu, MenuAction:action, param1, param2)
{
	switch(action)
	{
		case MenuAction_DrawItem:
		{
			if(_:g_iStopSound[param1] == param2)
			{
				return ITEMDRAW_DISABLED;
			}
		}
		case MenuAction_DisplayItem:
		{
			new String:dispBuf[50];
			GetMenuItem(menu, param2, "", 0, _, dispBuf, sizeof(dispBuf));
			Format(dispBuf, sizeof(dispBuf), "%T", dispBuf, param1);
			return RedrawMenuItem(dispBuf);
		}
		case MenuAction_Display:
		{
			new String:buffer[256];
			new String:title[][] = {
				"1",
				"2",
				"3"
			};
			GetMenuTitle(menu, buffer, sizeof(buffer));
			Format(buffer, sizeof(buffer), "%s\n%T", buffer, title[g_iStopSound[param1]], param1);
			SetMenuTitle(menu, buffer);
		}
		case MenuAction_Select:
		{
			new String:info[50];
			if(GetMenuItem(menu, param2, info, sizeof(info)))
			{
				SetClientCookie(param1, g_hClientCookie, info);
				g_iStopSound[param1] = StringToInt(info);
				if(StringToInt(info) == 2) {
					g_bSilenceSound[param1] = true;
					CReplyToCommand(param1, "\x04[StopSound]\x01 Stop weapon sounds:\x04 Silenced Sounds\x01.");
				}
				else {
					g_bSilenceSound[param1] = false;
					CReplyToCommand(param1, "\x04[StopSound]\x01 Stop weapon sounds: \x04%s\x01.", g_iStopSound[param1] != 0 ? "Enabled" : "Disabled");
				}
				CheckHooks();
				PrepareMenu(param1);
			}
		}
		case MenuAction_Cancel:
		{
			if( param2 == MenuCancel_ExitBack )
			{
				ShowCookieMenu(param1);
			}
		}
		case MenuAction_End:
		{
			CloseHandle(menu);
		}
	}

	return 0;
}

public OnClientCookiesCached(client)
{
	new String:sValue[8];
	GetClientCookie(client, g_hClientCookie, sValue, sizeof(sValue));
	if (sValue[0] == '\0') {
		SetClientCookie(client, g_hClientCookie, "2");
		strcopy(sValue, sizeof(sValue), "2");
	}
	g_iStopSound[client] = (StringToInt(sValue));
	g_bSilenceSound[client] = StringToInt(sValue) > 1;
	CheckHooks();
}

public Action:Command_StopSound(client, args)
{
	if(AreClientCookiesCached(client))
	{
		PrepareMenu(client);
	}
	else
	{
		ReplyToCommand(client, "[SM] Error: Cookies not cached yet.");
	}
	
	return Plugin_Handled;
}

public OnClientDisconnect_Post(client)
{
	g_iStopSound[client] = 0;
	g_bSilenceSound[client] = false;
	CheckHooks();
}

CheckHooks()
{
	new bool:bShouldHook = false;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (g_iStopSound[i] > 0)
		{
			bShouldHook = true;
			break;
		}
	}
	
	// Fake (un)hook because toggling actual hooks will cause server instability.
	g_bHooked = bShouldHook;
}

public Action:Hook_NormalSound(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags)
{
	// Ignore non-weapon or Re-broadcasted sounds.
	if (!g_bHooked || StrEqual(sample, "~)weapons/usp/usp1.wav", false) || !(strncmp(sample, "weapons", 7, false) == 0 || strncmp(sample[1], "weapons", 7, false) == 0 || strncmp(sample[2], "weapons", 7, false) == 0))
	return Plugin_Continue;
	
	decl i, j;
	
	for (i = 0; i < numClients; i++)
	{
		if (g_iStopSound[clients[i]] > 0)
		{
			// Remove the client from the array.
			for (j = i; j < numClients-1; j++)
			{
				clients[j] = clients[j+1];
			}
			
			numClients--;
			i--;
		}
	}
	
	return (numClients > 0) ? Plugin_Changed : Plugin_Stop;
}

public Action:CSS_Hook_ShotgunShot(const String:te_name[], const Players[], numClients, Float:delay)
{
	if (!g_bHooked)
	return Plugin_Continue;
	
	// Check which clients need to be excluded.
	decl newClients[MaxClients], client, i;
	new newTotal = 0;

	int clientlist[MAXPLAYERS+1];
	int clientcount = 0;

	for (i = 0; i < numClients; i++)
	{
		client = Players[i];
		
		if (g_iStopSound[client] <= 0)
		{
			newClients[newTotal++] = client;
		}
		if(g_bSilenceSound[client])
		{
			clientlist[clientcount++] = client;
		}
	}
	
	// No clients were excluded.
	if (newTotal == numClients)
	return Plugin_Continue;

	new player = TE_ReadNum("m_iPlayer");
	new entity = player + 1;
	for (new j = 0; j < clientcount; j++)
	{
		if (entity == clientlist[j])
		{
			for (new k = j; k < clientcount-1; k++)
			{
				clientlist[k] = clientlist[k+1];
			}
			
			clientcount--;
			j--;
		}
	}
	EmitSound(clientlist, clientcount, "~)weapons/usp/usp1.wav", entity, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, fVolume);
	
	// All clients were excluded and there is no need to broadcast.
	if (newTotal == 0)
	return Plugin_Stop;
	
	// Re-broadcast to clients that still need it.
	decl Float:vTemp[3];
	TE_Start("Shotgun Shot");
	TE_ReadVector("m_vecOrigin", vTemp);
	TE_WriteVector("m_vecOrigin", vTemp);
	TE_WriteFloat("m_vecAngles[0]", TE_ReadFloat("m_vecAngles[0]"));
	TE_WriteFloat("m_vecAngles[1]", TE_ReadFloat("m_vecAngles[1]"));
	TE_WriteNum("m_weapon", TE_ReadNum("m_weapon"));
	TE_WriteNum("m_iMode", TE_ReadNum("m_iMode"));
	TE_WriteNum("m_iSeed", TE_ReadNum("m_iSeed"));
	TE_WriteNum("m_iPlayer", player);
	TE_WriteFloat("m_fInaccuracy", TE_ReadFloat("m_fInaccuracy"));
	TE_WriteFloat("m_fSpread", TE_ReadFloat("m_fSpread"));
	TE_Send(newClients, newTotal, delay);
	
	return Plugin_Stop;
}