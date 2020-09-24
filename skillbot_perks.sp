#pragma semicolon 1
#define PLUGIN_VERSION "2.0"

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <colors_csgo>
#include <skillbot>
#include <zombiereloaded>
#include <skillbot_perks>
#include <zephstocks>

char titleName[] = "{purple}[SkillBot]";

public Plugin myinfo =  {
	name = "SkillBot Perks",
	author = "AntiTeal",
	description = "Perks system for SkillBot.",
	version = PLUGIN_VERSION,
	url = "https://antiteal.com"
};

ConVar g_cVPerksConfig = null;
char g_sHistory[MAXPLAYERS+1][512];
char sConfig[PLATFORM_MAX_PATH];
KeyValues KV;

Perk_Item Items[PERKS_MAX_ITEMS][Perk_Item];
Perk_Type Types[PERKS_MAX_HANDLERS][Perk_Type];
int g_iType = 0;
int g_iItems = 0;

#include "perks/basic.sp"

public void OnPluginStart()
{
	RegPluginLibrary("skillbot_perks");

	Basic_OnPluginStart();

	g_cVPerksConfig = CreateConVar("sm_skillbot_perks", "configs/skillbot/skillbot_perks.cfg", "The location of the perks config.");
	AutoExecConfig(true, "skillbot_perks");

	g_cVPerksConfig.AddChangeHook(ConVarChange);

	RegConsoleCmd("sm_perks", Command_Perks, "sm_perks");
	RegAdminCmd("sm_reloadperks", Command_ReloadPerks, ADMFLAG_CONFIG);

	LoadConfig();

	//Bunch of events for use
	HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Pre);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);
	HookEvent("bullet_impact", Event_BulletImpact, EventHookMode_Pre);
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
}

public Action Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
}

public Action Event_PlayerHurt(Handle event, const char[] name, bool dontBroadcast)
{
}

public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	Basic_PlayerDeath(event);
}

public Action Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	Basic_PlayerSpawn(event);
}

public Action Event_BulletImpact(Handle event, const char[] name, bool dontBroadcast)
{
	Basic_BulletImpact(event);
}

public void OnClientCookiesCached(int client)
{
	Basic_CookiesCached(client);
}

public void OnClientDisconnect(int client)
{
	g_sHistory[client][0] = '\0';
	Basic_Disconnect(client);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if(StrContains(classname, "_projectile" ) > 0)
	{
		SDKHook(entity, SDKHook_SpawnPost, Basic_GrenSkin_OnEntitySpawnedPost);
	}
}

public void OnMapStart()
{
	for(int i=0;i<g_iType;++i)
	{
		if(Types[i][fnMapStart] != INVALID_FUNCTION)
		{
			Call_StartFunction(Types[i][hPlugin], Types[i][fnMapStart]);
			Call_Finish();
		}
	}

	Basic_OnMapStart();
}

public Action Command_ReloadPerks(int client, int argc)
{
	LoadConfig();
	PrintChat(client, "Perks config reloaded!");
	return Plugin_Handled;
}

public void ConVarChange(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	LoadConfig();
}

public void PrintChat(int client, const char[] a, any:...) {
	char b[MAX_MESSAGE_LENGTH];
	VFormat(b, sizeof(b), a, 3);
	CPrintToChat(client, "%s{default} %s", titleName, b);
}

public void KvAddHistory(int client, int id)
{
	if(strlen(g_sHistory[client]) == 0)
	{
		Format(g_sHistory[client], sizeof(g_sHistory[]), "%i", id);
	}
	else
	{
		Format(g_sHistory[client], sizeof(g_sHistory[]), "%s%s%i", g_sHistory[client], SectionID, id);
	}
}

public void KvRemoveHistory(int client)
{
	if(FindCharInString(g_sHistory[client], SectionID[0], true) != -1)
	{
		strcopy(g_sHistory[client], FindCharInString(g_sHistory[client], SectionID[0], true) + 1, g_sHistory[client]);
	}
	else
	{
		g_sHistory[client][0] = '\0';
	}
}

public void KvWipeHistory(int client)
{
	g_sHistory[client][0] = '\0';
}

public void LoadConfig()
{
	char location[PLATFORM_MAX_PATH];
	g_cVPerksConfig.GetString(location, sizeof(location));

	BuildPath(Path_SM, sConfig, PLATFORM_MAX_PATH, location);
	if(KV != INVALID_HANDLE)
	{
		CloseHandle(KV);
	}
	KV = CreateKeyValues("SkillBot Perks");
	KV.ImportFromFile(sConfig);

	for(new i=0;i<g_iType;++i)
	{
		if(Types[i][fnReset] != INVALID_FUNCTION)
		{
			Call_StartFunction(Types[i][hPlugin], Types[i][fnReset]);
			Call_Finish();
		}
	}

	KvRewind(KV);
	Perks_WalkConfig(KV);
}

Perks_WalkConfig(&Handle:kv, parent=-1)
{
	decl String:m_szType[32];
	decl String:m_szFlags[64];
	decl m_iHandler;
	do
	{
		if(g_iItems == PERKS_MAX_ITEMS)
		continue;
		if (KvGetNum(kv, "enabled", 1) && KvGetNum(kv, "type", -1)==-1 && KvGotoFirstSubKey(kv))
		{
			KvGoBack(kv);
			KvGetSectionName(kv, Items[g_iItems][szName], ITEM_NAME_LENGTH);
			ReplaceString(Items[g_iItems][szName], ITEM_NAME_LENGTH, "\\n", "\n");
			KvGetString(kv, "flag", STRING(m_szFlags));
			Items[g_iItems][iFlagBits] = ReadFlagString(m_szFlags);
			KvGotoFirstSubKey(kv);

			Items[g_iItems][iParent] = parent;

			Perks_WalkConfig(kv, g_iItems++);
			KvGoBack(kv);
		}
		else
		{
			if(!KvGetNum(kv, "enabled", 1))
			continue;

			Items[g_iItems][iParent] = parent;

			KvGetSectionName(kv, Items[g_iItems][szName], ITEM_NAME_LENGTH);

			KvGetString(kv, "type", STRING(m_szType));
			m_iHandler = Perks_GetTypeHandler(m_szType);
			if(m_iHandler == -1)
			continue;

			Items[g_iItems][iType] = m_iHandler;

			KvGetString(kv, "flag", STRING(m_szFlags));
			Items[g_iItems][iFlagBits] = ReadFlagString(m_szFlags);

			KvGetSectionName(kv, Items[g_iItems][szName], ITEM_NAME_LENGTH);
			ReplaceString(Items[g_iItems][szName], ITEM_NAME_LENGTH, "\\n", "\n");

			if(Types[m_iHandler][fnConfig]!=INVALID_FUNCTION)
			{
				Call_StartFunction(Types[m_iHandler][hPlugin], Types[m_iHandler][fnConfig]);
				Call_PushCellRef(kv);
				Call_PushCell(g_iItems);
				Call_Finish();
			}

			++g_iItems;
		}
	}
	while (KvGotoNextKey(kv));
}

public Action Command_Perks(int ply, int argc)
{
	KvWipeHistory(ply);
	DrawMenu(ply).Display(ply, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public Menu DrawMenu(int client)
{
	Menu menu = new Menu(TheMenuHandler);
	KvRewind(KV);

	bool isEntry = false;
	menu.SetTitle("SkillBot Perks");

	if(strlen(g_sHistory[client]) != 0)	menu.ExitBackButton = true;

	char SectionArray[16][64];
	int actions = ExplodeString(g_sHistory[client], SectionID, SectionArray, sizeof(SectionArray), sizeof(SectionArray[]));

	for(int i = 0; i < actions; i++)
	{
		KvJumpToKeySymbol(KV, StringToInt(SectionArray[i]));

		if(KvGotoFirstSubKey(KV))
		{
			KvGoBack(KV);
		}
		else
		{
			isEntry = true;
		}

		if(strlen(g_sHistory[client]) != 0) {
			char name[64];
			KvGetSectionName(KV, name, sizeof(name));
			menu.SetTitle(name);
		}
	}

	KvGotoFirstSubKey(KV);

	if(!isEntry)
	{
		do
		{	char section[64], idstring[8];
			KvGetSectionName(KV, section, sizeof(section));
			int id;
			KvGetSectionSymbol(KV, id);
			IntToString(id, idstring, sizeof(idstring));
			menu.AddItem(idstring, section);
		}
		while(KvGotoNextKey(KV));
	}
	else
	{
		char itemname[64], itemrank[80], itemtype[64];
		KvGetSectionName(KV, itemname, sizeof(itemname));

		int rank = KvGetNum(KV, "rank");
		int id = Perks_GetItemID(itemname);

		SB_GetRank2(rank, itemrank, sizeof(itemrank));

		menu.SetTitle("%s\n%s", itemname, itemrank);
		if(SB_GetRank(client) >= rank)
		{
			KvGetString(KV, "type", itemtype, sizeof(itemtype));
			PerkStatus(client, id, menu);
		}
		else
		{
			menu.AddItem("sys_return", "Equip", ITEMDRAW_DISABLED);
		}
	}
	KvGoBack(KV);
	return menu;
}

public int TheMenuHandler(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select)
	{
		char szInfo[64];
		menu.GetItem(param, szInfo, sizeof(szInfo));
		if(StrEqual(szInfo, "sys_equip"))
		{
			PlayerEquip(client);
		}
		else if(StrEqual(szInfo, "sys_unequip"))
		{
			PlayerUnequip(client);
		}
		else if(StrEqual(szInfo, "sys_return"))
		{
			CloseHandle(menu);
		}
		else
		{
			KvAddHistory(client, StringToInt(szInfo));
			DrawMenu(client).Display(client, MENU_TIME_FOREVER);
		}
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel && param == MenuCancel_ExitBack)
	{
		KvRemoveHistory(client);
		DrawMenu(client).Display(client, MENU_TIME_FOREVER);
	}
}

public void PlayerEquip(int client)
{
	KvRewind(KV);

	char SectionArray[16][64];
	int actions = ExplodeString(g_sHistory[client], SectionID, SectionArray, sizeof(SectionArray), sizeof(SectionArray[]));

	for(int i = 0; i < actions; i++)
	{
		KvJumpToKeySymbol(KV, StringToInt(SectionArray[i]));
	}

	char itemtype[64];
	KvGetString(KV, "type", itemtype, sizeof(itemtype));

	char itemname[64];
	KvGetSectionName(KV, itemname, sizeof(itemname));

	PrintChat(client, "You have equipped {green}%s{default}.", itemname);

	PerkEquip(client, Perks_GetItemID(itemname));
	DrawMenu(client).Display(client, MENU_TIME_FOREVER);
}

public void PlayerUnequip(int client)
{
	KvRewind(KV);

	char SectionArray[16][64];
	int actions = ExplodeString(g_sHistory[client], SectionID, SectionArray, sizeof(SectionArray), sizeof(SectionArray[]));

	for(int i = 0; i < actions; i++)
	{
		KvJumpToKeySymbol(KV, StringToInt(SectionArray[i]));
	}

	char itemtype[64];
	KvGetString(KV, "type", itemtype, sizeof(itemtype));

	char itemname[64];
	KvGetSectionName(KV, itemname, sizeof(itemname));

	PrintChat(client, "You have unequipped {green}%s{default}.", itemname);

	PerkUnequip(client, Perks_GetItemID(itemname));
	DrawMenu(client).Display(client, MENU_TIME_FOREVER);
}

public int Perks_GetTypeHandler(char[] type)
{
	for(int i=0; i < g_iType; i++)
	{
		if(strcmp(Types[i][szType], type)==0)
		return i;
	}
	return -1;
}

public int Perks_GetItemID(char[] name)
{
	for(int i=0; i < g_iItems; i++)
	{
		if(strcmp(Items[i][szName], name)==0)
		return i;
	}
	return -1;
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	//char[] type, SBCallback_OnUse OnUse
	CreateNative("Perks_RegisterHandler", Native_RegisterHandler);
	CreateNative("Perks_Reequip", Native_Reequip);
	Basic_AskPluginLoad2();
	return APLRes_Success;
}

public int Native_Reequip(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	char stype[ITEM_HANDLER_LENGTH];
	GetNativeString(2, stype, sizeof(stype));

	int type = Perks_GetTypeHandler(stype);
	char szCurrent[ITEM_NAME_LENGTH];
	Handle cookie = Types[type][hCookie];
	if(cookie == INVALID_HANDLE) return;
	GetClientCookie(client, cookie, szCurrent, sizeof(szCurrent));
	int id = Perks_GetItemID(szCurrent);

	if(id != -1)
	{
		if(Types[Items[id][iType]][fnUse] != INVALID_FUNCTION)
		{
			Call_StartFunction(INVALID_HANDLE, Types[Items[id][iType]][fnUse]);
			Call_PushCell(client);
			Call_PushCell(id);
			Call_Finish();
		}
	}
}

public int Native_RegisterHandler(Handle plugin, int numParams)
{
	char type[ITEM_HANDLER_LENGTH];
	GetNativeString(1, type, sizeof(type));

	int id = g_iType;
	strcopy(Types[id][szType], ITEM_HANDLER_LENGTH, type);
	Types[id][hPlugin] = plugin;
	Types[id][hCookie] = GetNativeCell(2);
	Types[id][fnMapStart] = GetNativeCell(3);
	Types[id][fnReset] = GetNativeCell(4);
	Types[id][fnConfig] = GetNativeCell(5);
	Types[id][fnUse] = GetNativeCell(6);
	Types[id][fnRemove] = GetNativeCell(7);
	Types[id][useCookies] = GetNativeCell(8);

	g_iType++;
}

//Edit these sections to add more skins
public void PerkEquip(int client, int id)
{
	if(Types[Items[id][iType]][useCookies])
	{
		Handle cookie = Types[Items[id][iType]][hCookie];
		if(cookie == INVALID_HANDLE) return;

		SetClientCookie(client, cookie, Items[id][szName]);
		PrintToConsole(client, "Cookie set to %s.", Items[id][szName]);
	}

	if(Types[Items[id][iType]][fnUse] != INVALID_FUNCTION)
	{
		Call_StartFunction(INVALID_HANDLE, Types[Items[id][iType]][fnUse]);
		Call_PushCell(client);
		Call_PushCell(id);
		Call_Finish();
	}
}

public void PerkUnequip(int client, int id)
{
	if(Types[Items[id][iType]][useCookies])
	{
		Handle cookie = Types[Items[id][iType]][hCookie];
		if(cookie == INVALID_HANDLE) return;

		SetClientCookie(client, cookie, "");
		PrintToConsole(client, "Cookie set to blank.");
	}

	if(Types[Items[id][iType]][fnRemove] != INVALID_FUNCTION)
	{
		Call_StartFunction(INVALID_HANDLE, Types[Items[id][iType]][fnRemove]);
		Call_PushCell(client);
		Call_PushCell(id);
		Call_Finish();
	}
}

public void PerkStatus(int client, int id, Menu menu)
{
	if(Types[Items[id][iType]][useCookies])
	{
		char szCurrent[ITEM_NAME_LENGTH];
		if(Types[Items[id][iType]][hCookie] == INVALID_HANDLE) return;

		GetClientCookie(client, Types[Items[id][iType]][hCookie], szCurrent, sizeof(szCurrent));

		if(StrEqual(szCurrent, Items[id][szName]))
		menu.AddItem("sys_unequip", "Unequip", ITEMDRAW_DEFAULT);
		else menu.AddItem("sys_equip", "Equip", ITEMDRAW_DEFAULT);
	}
	else menu.AddItem("sys_equip", "Execute", ITEMDRAW_DEFAULT);
}
