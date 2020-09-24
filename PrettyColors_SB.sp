#pragma semicolon 1

#define PLUGIN_AUTHOR "R3TROATTACK (fat) + AntiTeal"
#define PLUGIN_VERSION "SB1.2"

#define TAG " \x0B[Chat Colors]\x01"

#include <sourcemod>
#include <scp>
//#include <chatcolors>
#include <colors_csgo>
#include <skillbot>

#pragma newdecls required

char g_sColorCode[16][4] = {
	"\x01", "\x02", "\x03", "\x04", "\x05", "\x06", "\x07", "\x08", 
	"\x09", "\x0A", "\x0B", "\x0C", "\x0D", "\x0E", "\x0F", "\x10"
};

char g_sColorName[16][16] = {
	"White/None", "Dark Red", "Team Color", "Green", "Light Green", "Lime", "Red", "Gray",
	"Yellow", "Clear Blue", "Light Blue", "Blue", "Clear Gray", "Purple", "Dark Orange", "Orange"
};

char g_sColorTagText[16][16] = {
	"{white}", "{darkred}", "{teamcolor}", "{green}", "{lightgreen}", "{lime}", "{red}", "{gray}",
	"{yellow}", "{clearblue}", "{lightblue}", "{blue}", "{cleargray}", "{purple}", "{darkorange}", "{orange}"
};

char g_sPlayerTag[MAXPLAYERS + 1][20];
int g_iPlayerChatColor[MAXPLAYERS + 1];
int g_iPlayerNameColor[MAXPLAYERS + 1] =  { 2, ... };
bool g_bCustomChatColor[MAXPLAYERS + 1];
bool g_bCustomNameColor[MAXPLAYERS + 1];
bool g_bCustomTag[MAXPLAYERS + 1];

Handle g_hDatabase = null;
Handle g_ChatColorsForward;

#include "chatcolors/db.sp"

public Plugin myinfo = 
{
	name = "Chat Colors",
	author = PLUGIN_AUTHOR,
	description = "Makes chat be pretty",
	version = PLUGIN_VERSION,
	url = "http://steamcommunity.com/id/R3TROATTACK/"
};

public void OnPluginStart()
{
	ConnectDatabase();
	
	RegAdminCmd("sm_colors", Command_Colors, ADMFLAG_RESERVATION, "Chat Colors command");
	RegAdminCmd("sm_namecolor", Command_NameColor, ADMFLAG_CUSTOM3, "Name Colors command");
	RegAdminCmd("sm_settag", Command_SetTag, ADMFLAG_CUSTOM6, "Custom Tag command");
	
	g_ChatColorsForward = CreateGlobalForward("OnChatColors", ET_Ignore, Param_CellByRef, Param_Cell, Param_String, Param_String);
}

public void OnClientPostAdminCheck(int client)
{
	Format(g_sPlayerTag[client], 20, "");
	g_bCustomChatColor[client] = false;
	g_bCustomTag[client] = false;
	g_bCustomNameColor[client] = false;
	g_iPlayerChatColor[client] = 0;
	g_iPlayerNameColor[client] = 2;
	CreateTimer(3.0, Timer_GetMemes, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_GetMemes(Handle timer, any data)
{
	int client = data;
	if(IsValidClient(client))
	{
		if (IsClientAuthorized(client))
		{
			GetPlayersColors(client);
		}
	}
	return Plugin_Stop;
}

public void OnClientDisconnect(int client)
{
	Format(g_sPlayerTag[client], 20, "");
	g_bCustomChatColor[client] = false;
	g_bCustomTag[client] = false;
	g_bCustomNameColor[client] = false;
	g_iPlayerChatColor[client] = 0;
	g_iPlayerNameColor[client] = 2;
}

public Action Command_Colors(int client, int args)
{
	CreateColorsMenu(client);
	return Plugin_Handled;
}

public Action Command_NameColor(int client, int args)
{
	CreateNameColorsMenu(client);
	return Plugin_Handled;
}

public void CreateColorsMenu(int client)
{
	Menu menu = new Menu(ColorsMenuHandler);
	menu.SetTitle("Colors Menu");
	if(GetAdminFlag(GetUserAdmin(client), Admin_Custom6, Access_Effective))
	{
		for (int i = 0; i < 16; i++)
		{
			menu.AddItem("", g_sColorName[i]);
		}
	}
	else
	{
		menu.AddItem("", g_sColorName[0]);
		menu.AddItem("", g_sColorName[2]);
	}
	menu.ExitButton = true;
	menu.Display(client, 30);
}

public void CreateNameColorsMenu(int client)
{
	Menu menu = new Menu(NameColorsMenuHandler);
	menu.SetTitle("Name Colors Menu");
	for (int i = 0; i < 16; i++)
	{
		menu.AddItem("", g_sColorName[i]);
	}
	menu.ExitButton = true;
	menu.Display(client, 30);
}

public int ColorsMenuHandler(Menu menu, MenuAction action, int client, int choice)
{
	if(action == MenuAction_Select)
	{
		if(GetAdminFlag(GetUserAdmin(client), Admin_Custom6, Access_Effective))
		{
			g_iPlayerChatColor[client] = choice;
		}
		else
		{
			if(choice == 1)
				g_iPlayerChatColor[client] = 2;
			else if(choice == 0)
				g_iPlayerChatColor[client] = 0;
		}
		UpdatePlayerColors(client);
		PrintToChat(client, "%s Your color is now %s%s\x01.", TAG, g_sColorCode[g_iPlayerChatColor[client]], g_sColorName[g_iPlayerChatColor[client]]);
		
		if(choice != 0)
			g_bCustomChatColor[client] = true;
		else
			g_bCustomChatColor[client] = false;
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
	
	return 0;
}

public int NameColorsMenuHandler(Menu menu, MenuAction action, int client, int choice)
{
	if(action == MenuAction_Select)
	{
		g_iPlayerNameColor[client] = choice;
		UpdatePlayerColors(client);
		
		if(choice != 0)
			g_bCustomNameColor[client] = true;
		else
			g_bCustomNameColor[client] = false;
	}
	else if(action == MenuAction_End)
	{
		delete menu;
	}
	
	return 0;
}

public Action Command_SetTag(int client, int args)
{
	if(args == 0)
	{
		char sBuffer[512];
		Format(sBuffer, 512, " ");
		for (int i = 0; i < 16; i++)
		{
			Format(sBuffer, sizeof(sBuffer), "%s%s%s ", sBuffer, g_sColorCode[i], g_sColorTagText[i]);
		}
		PrintToChat(client, "%s", sBuffer);
		return Plugin_Handled;
	}
	
	char sArg[128];
	GetCmdArg(1, sArg, sizeof(sArg));
	if(StrEqual(sArg, "none", false))
	{
		Format(g_sPlayerTag[client], 20, "");
		UpdatePlayerColors(client);
		PrintToChat(client, "%s Your tag has been removed!", TAG);
		g_bCustomTag[client] = false;
		return Plugin_Handled;
	}
	
	char sBuffer[512];
	GetCmdArgString(sBuffer, 512);
	if(StrContains(sBuffer, "%", false) != -1)
	{
		PrintToChat(client, "%s Your tag cannot contain %s", TAG, "%");
		return Plugin_Handled;
	}
	
	for (int i = 0; i < 16; i++)
	{
		ReplaceString(sBuffer, sizeof(sBuffer), g_sColorTagText[i], g_sColorCode[i], false);
	}
	Format(g_sPlayerTag[client], 20, "%s", sBuffer);
	UpdatePlayerColors(client);
	PrintToChat(client, "%s Your new custom tag is: %s", TAG, g_sPlayerTag[client]);
	g_bCustomTag[client] = true;
	return Plugin_Handled;
}

public Action OnChatMessage(int &author, Handle recipients, char[] name, char[] message)
{
	if(author == 0 || message[0] == '@')
		return Plugin_Continue;
	
	char rank[64];
	SB_GetChatRank(author, rank, sizeof(rank));

	if(strlen(rank) != 0)
	{
		CFormat(rank, sizeof(rank), author);
		Format(name, MAXLENGTH_NAME, "%s %s%s%s", rank, g_sPlayerTag[author], g_sColorCode[g_iPlayerNameColor[author]], name);
	}
	else
	{
		Format(name, MAXLENGTH_NAME, " %s%s%s", g_sPlayerTag[author], g_sColorCode[g_iPlayerNameColor[author]], name);
	}
	Format(message, MAXLENGTH_INPUT, "%s%s", g_sColorCode[g_iPlayerChatColor[author]], message);
	
	Call_StartForward(g_ChatColorsForward);
	Call_PushCellRef(author);
	Call_PushCell(recipients);
	Call_PushStringEx(name, MAXLENGTH_NAME, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushStringEx(message, MAXLENGTH_INPUT, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_Finish();
	
	return Plugin_Changed;
}

bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients)
		return false;
	else if (!IsClientInGame(client))
		return false;
	else if (IsFakeClient(client))
		return false;
	
	return true;
}