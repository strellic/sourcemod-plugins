#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <regex>
#undef REQUIRE_PLUGIN
#include <zombiereloaded>
#define REQUIRE_PLUGIN

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "GlowColors",
	author = "BotoX + AntiTeal",
	description = "Change your clients colors.",
	version = "1.0",
	url = ""
}

Menu g_GlowColorsMenu;
Handle g_hClientCookie = INVALID_HANDLE;

int g_aGlowColor[MAXPLAYERS + 1][3];
float g_aRainbowFrequency[MAXPLAYERS + 1];

public void OnPluginStart()
{
	g_hClientCookie = RegClientCookie("glowcolor", "", CookieAccess_Protected);

	RegConsoleCmd("sm_glow", Command_GlowColors, "Change your players glowcolor. sm_glow <RRGGBB HEX | 0-255 0-255 0-255 RGB CODE>");
	RegConsoleCmd("sm_color", Command_GlowColors, "Change your players glowcolor. sm_glow <RRGGBB HEX | 0-255 0-255 0-255 RGB CODE>");

	RegAdminCmd("sm_rainbow", Command_Rainbow, ADMFLAG_GENERIC, "Enable rainbow glowcolors. sm_rainbow [frequency]");

	HookEvent("player_spawn", Event_ApplyGlowcolor, EventHookMode_Post);
	HookEvent("player_team", Event_ApplyGlowcolor, EventHookMode_Post);
	HookEvent("player_hurt", Event_ApplyGlowcolor_NoDelay, EventHookMode_Post);

	LoadConfig();

	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client) && AreClientCookiesCached(client))
		{
			OnClientCookiesCached(client);
			ApplyGlowColor(client);
		}
	}
}

public void OnPluginEnd()
{
	for(int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client) && AreClientCookiesCached(client))
		{
			OnClientDisconnect(client);
			ApplyGlowColor(client);
		}
	}

	delete g_GlowColorsMenu;
	CloseHandle(g_hClientCookie);
}

void LoadConfig()
{
	char sConfigFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sConfigFile, sizeof(sConfigFile), "configs/GlowColors.cfg");
	if(!FileExists(sConfigFile))
	{
		SetFailState("Could not find config: \"%s\"", sConfigFile);
	}

	KeyValues Config = new KeyValues("GlowColors");
	if(!Config.ImportFromFile(sConfigFile))
	{
		delete Config;
		SetFailState("ImportFromFile() failed!");
	}
	if(!Config.GotoFirstSubKey(false))
	{
		delete Config;
		SetFailState("GotoFirstSubKey() failed!");
	}

	g_GlowColorsMenu = new Menu(MenuHandler_GlowColorsMenu, MenuAction_Select);
	g_GlowColorsMenu.SetTitle("GlowColors");
	g_GlowColorsMenu.ExitButton = true;

	g_GlowColorsMenu.AddItem("255 255 255", "None");

	char sKey[32];
	char sValue[16];
	do
	{
		Config.GetSectionName(sKey, sizeof(sKey));
		Config.GetString(NULL_STRING, sValue, sizeof(sValue));

		g_GlowColorsMenu.AddItem(sValue, sKey);
	}
	while(Config.GotoNextKey(false));
}

public void OnClientConnected(int client)
{
	g_aGlowColor[client][0] = 255;
	g_aGlowColor[client][1] = 255;
	g_aGlowColor[client][2] = 255;
	g_aRainbowFrequency[client] = 0.0;
}

public void OnClientCookiesCached(int client)
{
	if(IsClientAuthorized(client))
		ReadClientCookies(client);
}

public void OnClientPostAdminCheck(int client)
{
	if(AreClientCookiesCached(client))
		ReadClientCookies(client);
}

void ReadClientCookies(int client)
{
	char sCookie[16];
	if(CheckCommandAccess(client, "sm_glowcolors", ADMFLAG_CUSTOM5))
		GetClientCookie(client, g_hClientCookie, sCookie, sizeof(sCookie));

	if(StrEqual(sCookie, ""))
	{
		g_aGlowColor[client][0] = 255;
		g_aGlowColor[client][1] = 255;
		g_aGlowColor[client][2] = 255;
	}
	else
		ColorStringToArray(sCookie, g_aGlowColor[client]);
}

public void OnClientDisconnect(int client)
{
	if(CheckCommandAccess(client, "sm_glowcolors", ADMFLAG_CUSTOM5))
	{
		if(g_aGlowColor[client][0] == 255 &&
			g_aGlowColor[client][1] == 255 &&
			g_aGlowColor[client][2] == 255)
		{
			SetClientCookie(client, g_hClientCookie, "");
		}
		else
		{
			char sCookie[16];
			FormatEx(sCookie, sizeof(sCookie), "%d %d %d",
				g_aGlowColor[client][0],
				g_aGlowColor[client][1],
				g_aGlowColor[client][2]);

			SetClientCookie(client, g_hClientCookie, sCookie);
		}
	}

	g_aGlowColor[client][0] = 255;
	g_aGlowColor[client][1] = 255;
	g_aGlowColor[client][2] = 255;

	if(g_aRainbowFrequency[client])
		SDKUnhook(client, SDKHook_PostThinkPost, OnPostThinkPost);
	g_aRainbowFrequency[client] = 0.0;
}

public void OnPostThinkPost(int client)
{
	float i = GetGameTime();
	float Frequency = g_aRainbowFrequency[client];

	int Red   = RoundFloat(Sine(Frequency * i + 0.0) * 127.0 + 128.0);
	int Green = RoundFloat(Sine(Frequency * i + 2.0943951) * 127.0 + 128.0);
	int Blue  = RoundFloat(Sine(Frequency * i + 4.1887902) * 127.0 + 128.0);

	ToolsSetEntityColor(client, Red, Green, Blue);
}

public Action Command_GlowColors(int client, int args)
{
	if(args < 1)
	{
		DisplayGlowColorMenu(client);
	}
	else if(args == 1)
	{
		char sColorString[32];
		GetCmdArgString(sColorString, sizeof(sColorString));

		if(!IsValidHex(sColorString))
		{
			PrintToChat(client, "Invalid HEX color code supplied.");
			return Plugin_Handled;
		}

		int Color = StringToInt(sColorString, 16);

		g_aGlowColor[client][0] = (Color >> 16) & 0xFF;
		g_aGlowColor[client][1] = (Color >> 8) & 0xFF;
		g_aGlowColor[client][2] = (Color >> 0) & 0xFF;
		ApplyGlowColor(client);

		if(GetCmdReplySource() == SM_REPLY_TO_CHAT)
			PrintToChat(client, "\x01[SM] Set color to: \x07%06X%06X\x01", Color, Color);
	}
	else if(args == 3)
	{
		char sColorString[32];
		GetCmdArgString(sColorString, sizeof(sColorString));

		if(!IsValidRGBNum(sColorString))
		{
			PrintToChat(client, "Invalid RGB color code supplied.");
			return Plugin_Handled;
		}

		ColorStringToArray(sColorString, g_aGlowColor[client]);
		ApplyGlowColor(client);

		int Color = (g_aGlowColor[client][0] << 16) +
					(g_aGlowColor[client][1] << 8) +
					(g_aGlowColor[client][2] << 0);

		if(GetCmdReplySource() == SM_REPLY_TO_CHAT)
			PrintToChat(client, "\x01[SM] Set color to: \x07%06X%06X\x01", Color, Color);
	}
	else
	{
		char sCommand[32];
		GetCmdArg(0, sCommand, sizeof(sCommand));
		PrintToChat(client, "[SM] Usage: %s <RRGGBB HEX | 0-255 0-255 0-255 RGB CODE>", sCommand);
	}

	return Plugin_Handled;
}

public Action Command_Rainbow(int client, int args)
{
	float Frequency = 1.0;
	if(args >= 1)
	{
		char sArg[32];
		GetCmdArg(1, sArg, sizeof(sArg));
		Frequency = StringToFloat(sArg);
	}

	if(!Frequency || (args < 1 && g_aRainbowFrequency[client]))
	{
		if(g_aRainbowFrequency[client])
			SDKUnhook(client, SDKHook_PostThinkPost, OnPostThinkPost);

		g_aRainbowFrequency[client] = 0.0;
		PrintToChat(client, "[SM] Disabled rainbow glowcolors.");

		ApplyGlowColor(client);
	}
	else
	{
		if(Frequency > 15.0)
		{
			PrintToChat(client, "[SM] Please don't put a rainbow speed over 15!");
			return Plugin_Handled;
		}

		if(!g_aRainbowFrequency[client])
			SDKHook(client, SDKHook_PostThinkPost, OnPostThinkPost);

		g_aRainbowFrequency[client] = Frequency;
		PrintToChat(client, "[SM] Enabled rainbow glowcolors. (Frequency = %f)", Frequency);
	}
	return Plugin_Handled;
}

void DisplayGlowColorMenu(int client)
{
	g_GlowColorsMenu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_GlowColorsMenu(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char aItem[16];
			menu.GetItem(param2, aItem, sizeof(aItem));

			ColorStringToArray(aItem, g_aGlowColor[param1]);
			ApplyGlowColor(param1);
		}
	}
}

public void Event_ApplyGlowcolor(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!client)
		return;

	CreateTimer(1.0, DelayColors, GetClientSerial(client));
}

public void Event_ApplyGlowcolor_NoDelay(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!client)
		return;

	RequestFrame(ApplyGlowColor, client);
}

public Action DelayColors(Handle timer, any serial)
{
	int client = GetClientFromSerial(serial);
	if (client == 0)
		return Plugin_Stop;

	ApplyGlowColor(client);
	return Plugin_Handled;
}

public int ZR_OnClientHumanPost(int client, bool respawn, bool protect)
{
	ApplyGlowColor(client);
}

void ApplyGlowColor(int client)
{
	if(IsClientInGame(client) && IsPlayerAlive(client) && ZR_IsClientHuman(client))
		ToolsSetEntityColor(client, g_aGlowColor[client][0], g_aGlowColor[client][1], g_aGlowColor[client][2]);
}

stock void ToolsGetEntityColor(int entity, int aColor[4])
{
	static bool s_GotConfig = false;
	static char s_sProp[32];

	if(!s_GotConfig)
	{
		Handle GameConf = LoadGameConfigFile("core.games");
		bool Exists = GameConfGetKeyValue(GameConf, "m_clrRender", s_sProp, sizeof(s_sProp));
		CloseHandle(GameConf);

		if(!Exists)
			strcopy(s_sProp, sizeof(s_sProp), "m_clrRender");

		s_GotConfig = true;
	}

	int Offset = GetEntSendPropOffs(entity, s_sProp);

	for(int i = 0; i < 4; i++)
		aColor[i] = GetEntData(entity, Offset + i, 1);
}

stock void ToolsSetEntityColor(int client, int Red, int Green, int Blue)
{
	int aColor[4];
	ToolsGetEntityColor(client, aColor);

	SetEntityRenderColor(client, Red, Green, Blue, aColor[3]);
}

stock void ColorStringToArray(const char[] sColorString, int aColor[3])
{
	char asColors[4][4];
	ExplodeString(sColorString, " ", asColors, sizeof(asColors), sizeof(asColors[]));

	aColor[0] = StringToInt(asColors[0]) & 0xFF;
	aColor[1] = StringToInt(asColors[1]) & 0xFF;
	aColor[2] = StringToInt(asColors[2]) & 0xFF;
}

stock bool IsValidRGBNum(char[] sString)
{
	if(SimpleRegexMatch(sString, "^([01]?[0-9]?[0-9]|2[0-4][0-9]|25[0-5])$") == 2)
		return true;
	return false;
}

stock bool IsValidHex(char[] sString)
{
	if(SimpleRegexMatch(sString, "^(#?)([A-Fa-f0-9]{6})$") == 0)
		return false;
	return true;
}
