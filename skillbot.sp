#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <colors_csgo>
#include <cstrike>
#include <zombiereloaded>
#include <skillbot>
#undef REQUIRE_PLUGIN
#include <skillbot_perks>

#define PLUGIN_VERSION "2.3"
#pragma newdecls required

char titleName[] = "{purple}[SkillBot]";

Handle gH_sChatTag = INVALID_HANDLE, gH_TimerHandle = INVALID_HANDLE, gH_sTracers = INVALID_HANDLE;

int clientTarget[MAXPLAYERS + 1], damageGiven[MAXPLAYERS + 1], sessionPoints[MAXPLAYERS + 1];

bool playerCached[MAXPLAYERS + 1] = false;
int playerPoints[MAXPLAYERS + 1];

bool isHuman[MAXPLAYERS + 1];

enum Rank
{
    rankPoints,
    String:chatRank[64],
	String:menuRank[64],
	String:tagRank[64]
}
const MAX_RANKS = 32;
Rank Ranks[MAX_RANKS][Rank];
int maxRank = -1;

int placeCooldown[MAXPLAYERS + 1];

Handle EnableTimer_TimerHandle = INVALID_HANDLE;

public Plugin myinfo =  {
	name = "SkillBot",
	author = "AntiTeal",
	description = "Ranking system for sG ZE.",
	version = PLUGIN_VERSION,
	url = "antiteal.com"
};

bool pluginEnabled = false;
bool roundStarted = false;
bool roundEnded = false;

char sConfig[PLATFORM_MAX_PATH];
char currentMap[64], mapName[64];
KeyValues KV, KV2;
bool isHardMap, isHardRound;

ConVar g_cVMinPlayers = null, g_cVRanksFilePath = null, g_cVHardMapsPath = null, g_cVStatus = null, g_cVForceHard = null, g_cVPlayTimer = null, g_cVPlayTimePoints = null;
ConVar g_cVExtraRank = null, g_cVDMGAmount = null, g_cVDMGPoints = null, g_cVWinPoints = null, g_cVExtraWin = null, g_cVExtraDMG = null, g_cVHardMultiplier = null;
ConVar g_cVSuicidePoints = null, g_cVExtraSuicide = null;

ConVar g_cVEnableTimer = null;

Handle DB;

bool perks = false;

public void OnPluginStart()
{
	CreateConVar("sm_skillbot_version", PLUGIN_VERSION, "Plugin Version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);
	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");

	gH_sChatTag = RegClientCookie("skillbot_chattag", "", CookieAccess_Private);
	gH_sTracers = RegClientCookie("sm_sbperks_tracerstatus", "", CookieAccess_Private);

	RegConsoleCmd("sm_skillbot", SkillBotMenu);
	RegConsoleCmd("sm_sb", SkillBotMenu);
	RegConsoleCmd("sm_rank", SkillBotMenu);

	RegConsoleCmd("sm_place", Place);

	RegAdminCmd("sm_setpoints", SetPoints, ADMFLAG_ROOT);
	RegAdminCmd("sm_addpoints", AddPoints, ADMFLAG_ROOT);

	RegAdminCmd("sm_colorlist", ColorList, ADMFLAG_GENERIC);

	HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Pre);
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);

	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre);

	AddCommandListener(sayHook, "say");

	g_cVMinPlayers = CreateConVar("sm_skillbot_minplayers", "15", "How many players need to be connected to the server to enable SkillBot.");
	g_cVStatus = CreateConVar("sm_skillbot_status", "1", "Skillbot enable/disable status (0/1).");

	g_cVPlayTimer = CreateConVar("sm_skillbot_playtime_seconds", "120", "Playtime (in seconds) for players to get points. (0 to disable)");
	g_cVPlayTimePoints = CreateConVar("sm_skillbot_playtime_points", "5", "How many points a player gets for playtime.");

	g_cVDMGAmount = CreateConVar("sm_skillbot_damage_amount", "4000", "How much damage is needed to be inflicted to zombies to get points.");
	g_cVDMGPoints = CreateConVar("sm_skillbot_damage_points", "2", "Points given for inflicting damage.");

	g_cVWinPoints = CreateConVar("sm_skillbot_win_points", "25", "Points given for winning a map as human.");

	g_cVExtraRank = CreateConVar("sm_skillbot_extra_rank", "4", "At which rank gives people extra points (default: 5th rank)");
	g_cVExtraWin = CreateConVar("sm_skillbot_extra_points", "50", "Points given for winning a map as a human past the extra point rank.");
	g_cVExtraDMG = CreateConVar("sm_skillbot_extra_damage", "5", "Points given for inflicting damage past the extra point rank.");
	g_cVExtraSuicide = CreateConVar("sm_skillbot_extra_suicide", "20", "Points given for suiciding as a human past the extra point rank.");

	g_cVHardMapsPath = CreateConVar("sm_skillbot_hardmaps", "configs/skillbot/skillbot_hard.cfg", "The location of the hardmaps config.");
	g_cVForceHard = CreateConVar("sm_skillbot_forcehard", "0", "Forces all maps to be hard difficulty.");
	g_cVHardMultiplier = CreateConVar("sm_skillbot_hardmultiplier", "2", "Points given for winning a hard map will be multiplied by this value.");

	g_cVSuicidePoints = CreateConVar("sm_skillbot_suicide_points", "10", "Points subtracted from suiciding as a human.");

	g_cVEnableTimer = CreateConVar("sm_skillbot_enable_timer", "60", "How long in seconds until the plugin is enabled from round start. (0 disables)");

	g_cVRanksFilePath = CreateConVar("sm_skillbot_ranksfile", "configs/skillbot/skillbot_ranks.cfg", "The location of the ranks config.");

	g_cVMinPlayers.AddChangeHook(ConVarChange);
	g_cVHardMapsPath.AddChangeHook(ConVarChange);
	g_cVRanksFilePath.AddChangeHook(ConVarChange);
	g_cVStatus.AddChangeHook(ConVarChange);
	g_cVForceHard.AddChangeHook(ConVarChange);
	g_cVPlayTimer.AddChangeHook(PlayTimerChange);

	GetRanks();
	GetMaps();
	PlayerCheck();
	LoadDatabase();

	AutoExecConfig(true, "skillbot");

	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			OnClientPutInServer(i);
		}
	}

	if(gH_TimerHandle != INVALID_HANDLE)
	{
		KillTimer(gH_TimerHandle);
		gH_TimerHandle = INVALID_HANDLE;
	}
	if(g_cVPlayTimer.FloatValue > 0)
	{
		gH_TimerHandle = CreateTimer(g_cVPlayTimer.FloatValue, PlayTimer, _, TIMER_REPEAT);
	}

	perks = LibraryExists("skillbot_perks");
}

public void OnAllPluginsLoaded()
{
	perks = LibraryExists("skillbot_perks");
}

public void OnLibraryAdded(const char[] name)
{
	if(StrEqual(name, "skillbot_perks")) perks = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if(StrEqual(name, "skillbot_perks")) perks = false;
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && playerCached[i])
		{
			Function_DB_SetPoints(i, playerPoints[i]);
		}
	}
}

public void ConVarChange(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	LoadDatabase();
	PlayerCheck();
	GetRanks();
	GetMaps();
}

public void PlayTimerChange(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	if(gH_TimerHandle != INVALID_HANDLE)
	{
		KillTimer(gH_TimerHandle);
		gH_TimerHandle = INVALID_HANDLE;
	}
	if(g_cVPlayTimer.FloatValue > 0)
	{
		gH_TimerHandle = CreateTimer(g_cVPlayTimer.FloatValue, PlayTimer, _, TIMER_REPEAT);
	}
}

public Action PlayTimer(Handle timer, Handle hndl)
{
	if(pluginEnabled)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(IsValidClient(i) && GetClientTeam(i) != 1)
			{
				Function_PrintChat(i, "You have been given {green}%i points{default} for playing on the server!", g_cVPlayTimePoints.IntValue);
				Function_AddPoints(i, g_cVPlayTimePoints.IntValue);
			}
		}
	}
}

public void OnConfigsExecuted()
{
	GetMaps();
	GetRanks();
}

public void OnClientDisconnect(int client)
{
	if(playerCached[client])
	{
		Function_DB_SetPoints(client, playerPoints[client]);
	}
	playerCached[client] = false;
	damageGiven[client] = 0;
	sessionPoints[client] = 0;
	playerPoints[client] = 0;
}

public void OnClientConnected(int client)
{
	PlayerCheck();
}

public void OnClientPutInServer(int client)
{
	Function_DB_ReturnPoints(client);
}

public void Function_ListHardMaps(int client)
{
	PrintToConsole(client, "[Skillbot] List of hard maps and levels:");

	KvRewind(KV);
	KvGotoFirstSubKey(KV);

	int counter = 1;

	do
	{
		char sectionName[64];
		KvGetSectionName(KV, sectionName, sizeof(sectionName));

		ArrayList SectionNames;
		bool hasLevels;
		if(KvJumpToKey(KV, "Levels"))
		{
			char section[64];
			SectionNames = CreateArray(64);
			hasLevels = true;

			KvGotoFirstSubKey(KV);
			do
			{
				KvGetSectionName(KV, section, sizeof(section));
				PushArrayString(SectionNames, section);
			}
			while(KvGotoNextKey(KV));
			KvGoBack(KV);
			KvGoBack(KV);
		}
		else
		{
			hasLevels = false;
		}
		if(hasLevels)
		{
			PrintToConsole(client, "Map %i: %s - Levels:", counter, sectionName);
			Function_PrintChat(client, "Map %i: %s - Levels:", counter, sectionName);
			for (int i = 0; i < (GetArraySize(SectionNames)); i++)
			{
				char section[64];
				GetArrayString(SectionNames, i, section, sizeof(section));
				PrintToConsole(client, "	Level %s", section);
				Function_PrintChat(client, ">> Level %s", section);
			}
		}
		else
		{
			PrintToConsole(client, "Map %i: %s - All Levels", counter, sectionName);
			Function_PrintChat(client, "Map %i: %s - All Levels", counter, sectionName);
		}

		counter++;
	}
	while(KvGotoNextKey(KV));

	Function_PrintChat(client, "Check console to see the full list of hard maps and levels!");
}

public void LoadDatabase()
{
	char Error[256];
	DB = SQL_Connect("SkillBot", true, Error, sizeof(Error));

	if (DB == null)
	{
		LogError("Could not connect, %s", Error);
		return;
	}

	SQL_FastQuery(DB, "CREATE TABLE `SkillBot` (`SteamID` varchar(128), `Points` int, PRIMARY KEY (`SteamID`));");

}

public void GetMaps()
{
	char location[PLATFORM_MAX_PATH];
	g_cVHardMapsPath.GetString(location, sizeof(location));

	BuildPath(Path_SM, sConfig, PLATFORM_MAX_PATH, location);
	if(KV != INVALID_HANDLE)
	{
		CloseHandle(KV);
	}
	KV = CreateKeyValues("Maps");

	FileToKeyValues(KV, sConfig);

	KvRewind(KV);
	KvGotoFirstSubKey(KV);
	do
	{
		KvGetSectionName(KV, mapName, sizeof(mapName));
		if (StrContains(currentMap, mapName, false) != -1)
		{
			isHardMap = true;
			return;
		}
	}
	while(KvGotoNextKey(KV));
}

public void GetRanks()
{
	char location[PLATFORM_MAX_PATH];
	g_cVRanksFilePath.GetString(location, sizeof(location));

	BuildPath(Path_SM, sConfig, PLATFORM_MAX_PATH, location);
	if(KV2 != INVALID_HANDLE)
	{
		CloseHandle(KV2);
	}
	KV2 = CreateKeyValues("Ranks");

	FileToKeyValues(KV2, sConfig);

	KvRewind(KV2);
	KvGotoFirstSubKey(KV2);
	int index;
	do
	{
		char sec[8];
		KvGetSectionName(KV2, sec, sizeof(sec));
		index = StringToInt(sec);

		char chat[64], menu[64], tag[64];
		Ranks[index][rankPoints] = KvGetNum(KV2, "points");

		KvGetString(KV2, "chat", chat, sizeof(chat));
		KvGetString(KV2, "menu", menu, sizeof(menu));
		KvGetString(KV2, "tag", tag, sizeof(tag));

		strcopy(Ranks[index][chatRank], sizeof(chat), chat);
		strcopy(Ranks[index][menuRank], sizeof(menu), menu);
		strcopy(Ranks[index][tagRank], sizeof(tag), tag);
	}
	while(KvGotoNextKey(KV2));
	maxRank = index+1;
}

public Action sayHook(int client, const char[] command, int argc)
{
	if (IsValidClient(client))
	{
		char buffer[256];
		GetCmdArgString(buffer, sizeof(buffer));
		StripQuotes(buffer);

		if (StrEqual(buffer, "place", false))
		{
			FakeClientCommand(client, "sm_place");
			return Plugin_Handled;
		}
		else if (StrEqual(buffer, "rank", false) || StrEqual(buffer, "sb", false) || StrEqual(buffer, "skillbot", false))
		{
			FakeClientCommand(client, "sm_skillbot");
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

void PlayerCheck()
{
	int minPlayers = g_cVMinPlayers.IntValue;
	if (GetClientCount(false) >= minPlayers && g_cVStatus.IntValue == 1)
	{
		pluginEnabled = true;
	}
	else
	{
		pluginEnabled = false;
	}

	if (GetClientCount(false) < minPlayers && !pluginEnabled)
	{
		Function_PrintChatAll("SkillBot is not enabled, not enough players (%i/%i).", GetClientCount(false), minPlayers);
	}
	else if (g_cVStatus.IntValue == 0 && !pluginEnabled)
	{
		Function_PrintChatAll("SkillBot has been disabled by an admin.");
	}
}

public Action RoundStarted(Handle timer, any data)
{
	roundStarted = true;
	Function_PrintChatAll("Points are now enabled.");
	EnableTimer_TimerHandle = INVALID_HANDLE;
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	roundEnded = false;
	roundStarted = false;
	isHardMap = false;
	isHardRound = false;

	if (EnableTimer_TimerHandle != INVALID_HANDLE)
	{
		CloseHandle(EnableTimer_TimerHandle);
		EnableTimer_TimerHandle = INVALID_HANDLE;
	}

	float timer = g_cVEnableTimer.FloatValue;
	if(timer == 0.0)
	{
		roundStarted = true;
	}
	else
	{
		EnableTimer_TimerHandle = CreateTimer(timer, RoundStarted);
		Function_PrintChatAll("Points will be enabled in %.2f seconds.", timer);
	}

	GetCurrentMap(currentMap, sizeof(currentMap));

	GetMaps();
	GetRanks();
	PlayerCheck();
	for (int i = 1; i <= MAXPLAYERS + 1; i++)
	{
		if (IsValidClient(i))
		{
			isHuman[i] = false;
		}
	}

	if(isHardMap)
	{
		KvRewind(KV);

		if(!KvJumpToKey(KV, mapName))
		{
			isHardRound = false;
			return;
		}
		if(KvJumpToKey(KV, "Levels"))
		{
			KvGotoFirstSubKey(KV);
			do
			{
				int ent = -1;
				char kvName[32], entOutput[32];

				KvGetString(KV, "Output", entOutput, sizeof(entOutput));
				KvGetString(KV, "Name", kvName, sizeof(kvName));

				while ((ent = FindEntityByClassname(ent, "*")) != -1)
				{
					char entName[32];
					GetEntPropString(ent, Prop_Data, "m_iName", entName, sizeof(entName));

					if(StrEqual(kvName, entName, false))
					{
						HookSingleEntityOutput(ent, entOutput, EntityFired, true);
					}
				}
			}
			while(KvGotoNextKey(KV));
		}
		else
		{
			CreateTimer(5.0, MapHardChatTimer);
			isHardRound = true;
		}
	}
}

public void EntityFired(const char[] output, int caller, int activator, float Any)
{
	CreateTimer(5.0, LevelHardChatTimer);
	isHardRound = true;
}

public Action LevelHardChatTimer(Handle timer)
{
	char map[64];
	strcopy(map, sizeof(map), mapName);
	ReplaceString(map, sizeof(map), "_", " ");

	Function_PrintChatAll(">>> Hard level detected on %s! <<<", map);
	Function_PrintChatAll("The current level is hard, so you will get {green}%ix{default} points on {green}Human Win{default}!", g_cVHardMultiplier.IntValue);
	return Plugin_Handled;
}

public Action MapHardChatTimer(Handle timer)
{
	Function_PrintChatAll("The current map is hard, so you will get {green}%ix{default} points on {green}Human Win{default}!", g_cVHardMultiplier.IntValue);
	return Plugin_Handled;
}

public Action ColorList(int client, int args)
{
	CPrintToChat(client, "{default}default {darkred}darkred {pink}pink {green}green {lightgreen}lightgreen {lime}lime {red}red {grey}grey {olive}olive {a}a {lightblue}lightblue {blue}blue {d}d {purple}purple {darkorange}darkorange {orange}orange");
	return Plugin_Handled;
}

public Action Place(int client, int args)
{
	int time = GetTime() - placeCooldown[client];
	if (time >= 5)
	{
		placeCooldown[client] = GetTime();
		if (args == 0) {
			GetPlace(client);
		}
		if (args == 1) {
			char arg1[65];
			GetCmdArg(1, arg1, sizeof(arg1));
			int target = FindTarget(client, arg1, false, false);
			if (target == -1)
			{
				return Plugin_Handled;
			}

			GetPlace(target);
		}
	}
	return Plugin_Handled;
}

void GetPlace(int client)
{
	char rank[64], clan[64];
	CS_GetClientClanTag(client, clan, sizeof(clan));
	Function_GetRank(Function_GetRankNumber(client), rank, sizeof(rank));
	if (strlen(clan) != 0)
	{
		Function_PrintChatAll("Player %s %N is currently rank %s and has %i points.", clan, client, rank, Function_ReturnPoints(client));
	}
	else
	{
		Function_PrintChatAll("Player %N is currently rank %s and has %i points.", client, rank, Function_ReturnPoints(client));
	}
}
public Action Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(1.5, SetPlayerStatus, GetClientSerial(client));
}
public Action SetPlayerStatus(Handle timer, any serial)
{
	int client = GetClientFromSerial(serial);

	if (client == 0)
	{
		return Plugin_Stop;
	}

	if (IsPlayerAlive(client) && ZR_IsClientHuman(client))
	{
		isHuman[client] = true;
	}
	else
	{
		isHuman[client] = false;
	}

	return Plugin_Handled;
}
public int ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
	isHuman[client] = false;
}
public Action Event_PlayerHurt(Handle event, const char[] name, bool dontBroadcast)
{
	if (pluginEnabled && roundStarted)
	{
		int victim = GetClientOfUserId(GetEventInt(event, "userid"));
		int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

		if (IsValidClient(victim) && IsValidClient(attacker) && IsPlayerAlive(victim) && IsPlayerAlive(attacker) && ZR_IsClientZombie(victim) && ZR_IsClientHuman(attacker))
		{
			int dmg_health = GetEventInt(event, "dmg_health");
			damageGiven[attacker] = (damageGiven[attacker] + dmg_health);

			if (damageGiven[attacker] >= g_cVDMGAmount.IntValue)
			{
				damageGiven[attacker] = 0;
				if (Function_GetRankNumber(attacker) >= g_cVExtraRank.IntValue)
				{
					Function_PrintChat(attacker, "You have been given {green}%i points{default} for dealing {red}4000 damage{default}.", g_cVExtraDMG.IntValue);
					Function_AddPoints(attacker, g_cVExtraDMG.IntValue);
				}
				else
				{
					Function_PrintChat(attacker, "You have been given {green}%i points{default} for dealing {red}4000 damage{default}.", g_cVDMGPoints.IntValue);
					Function_AddPoints(attacker, g_cVDMGPoints.IntValue);
				}
			}
		}
	}
}

public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	if (pluginEnabled && roundStarted)
	{
		int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
		int client = GetClientOfUserId(GetEventInt(event, "userid"));

		if ((attacker == 0) && IsValidClient(client) && isHuman[client] && !roundEnded)
		{
			if (Function_GetRankNumber(client) >= g_cVExtraRank.IntValue)
			{
				Function_PrintChat(client, "You have lost {green}%i points{default} for {red}suiciding{default}.", g_cVExtraSuicide.IntValue);
				Function_SubPoints(client, g_cVExtraSuicide.IntValue);
			}
			else
			{
				Function_PrintChat(client, "You have lost {green}%i points{default} for {red}suiciding{default}.", g_cVSuicidePoints.IntValue);
				Function_SubPoints(client, g_cVSuicidePoints.IntValue);
			}
		}
	}
}

public bool isMapHard()
{
	if (isHardRound || g_cVForceHard.IntValue == 1)
	{
		return true;
	}
	else
	{
		return false;
	}
}

void checkMapHard(int client)
{
	Function_PrintChat(client, "Current map is %s, and current round is %s.", isHardMap ? "hard" : "not hard", isMapHard() ? "hard" : "not hard");
}

public int getMapPoints(int client)
{
	bool isMaster = false;

	if (Function_GetRankNumber(client) >= g_cVExtraRank.IntValue)
	isMaster = true;

	if (isMapHard())
	{
		if (isMaster)
		return g_cVExtraWin.IntValue * g_cVHardMultiplier.IntValue;
		else
		return g_cVWinPoints.IntValue * g_cVHardMultiplier.IntValue;
	}
	else
	{
		if (isMaster)
		return g_cVExtraWin.IntValue;
		else
		return g_cVWinPoints.IntValue;
	}
}

public void Event_RoundEnd(Handle event, const char[] name, bool silent)
{
	roundEnded = true;
	if (pluginEnabled && roundStarted)
	{
		int winner = GetEventInt(event, "winner");
		if (winner == 3)
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && (!IsFakeClient(i)) && IsPlayerAlive(i))
				{
					if (isMapHard())
					{
						int givePoints = getMapPoints(i);
						Function_PrintChat(i, "{green}You{default} have been given {green}%i points{default} for {green}Human Win{default} because the level is hard!", givePoints);
						Function_AddPoints(i, givePoints);
					}
					else
					{
						int givePoints = getMapPoints(i);
						Function_PrintChat(i, "{green}You{default} have been given {green}%i points{default} for {green}Human Win{default}.", givePoints);
						Function_AddPoints(i, givePoints);
					}
				}
			}
		}
	}
}

int IsValidClient(int client, bool nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}

public void Function_PrintChatAll(const char[] a, any:...) {
	char b[MAX_MESSAGE_LENGTH];
	VFormat(b, sizeof(b), a, 2);
	CPrintToChatAll("%s{default} %s", titleName, b);
}

public void Function_PrintChat(int client, const char[] a, any:...) {
	char b[MAX_MESSAGE_LENGTH];
	VFormat(b, sizeof(b), a, 3);
	CPrintToChat(client, "%s{default} %s", titleName, b);
}

public int Function_ReturnPoints(int client) {
	return playerPoints[client];
}

public void Function_SetPoints(int client, int a) {
	playerPoints[client] = a;
}

public int Function_DB_ReturnPoints(int client)
{
	char auth[64], statement[128];
	GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth), false);

	Format(statement, sizeof(statement), "SELECT * FROM `SkillBot` WHERE `SteamID`='%s'", auth);

	DataPack pack = new DataPack();
	pack.WriteString(auth);
	pack.WriteCell(client);

	SQL_TQuery(DB, SQL_ReturnPoints, statement, pack);

	/*
	DBResultSet query = SQL_Query(DB, statement);

	playerCached[client] = false;

	if(query == null)
	{
		char Error[255];
		SQL_GetError(DB, Error, sizeof(Error));
		LogError("Failed to query points from SteamID %s, (Error: %s)", auth, Error);
	}
	else
	{
		playerCached[client] = true;
		if(SQL_FetchRow(query))
		{
			points = SQL_FetchInt(query, 1);
		}
	}

	delete query;
	return points;
	*/
}

public void SQL_ReturnPoints(Handle hDriver, Handle query, const char[] sError, any data)
{
	DataPack pk = view_as<DataPack>(data);
	pk.Reset();

	char auth[64];
	pk.ReadString(auth, sizeof(auth));
	int client = pk.ReadCell();

	int points = 0;
	playerCached[client] = false;

	if(query == null)
	{
		LogError("Failed to query points from SteamID %s, (Error: %s)", auth, sError);
	}
	else
	{
		playerCached[client] = true;
		if(SQL_FetchRow(query))
		{
			points = SQL_FetchInt(query, 1);
		}
	}

	playerPoints[client] = points;
}

public void Function_DB_SetPoints(int client, int a)
{
	char auth[64], statement[128];
	GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth), false);

	Format(statement, sizeof(statement), "SELECT * FROM `SkillBot` WHERE `SteamID`='%s'", auth);

	DataPack pack = new DataPack();
	pack.WriteString(auth);
	pack.WriteCell(a);

	SQL_TQuery(DB, SQL_UpdatePoints, statement, pack);

	/*
	DBResultSet query = SQL_Query(DB, statement);

	if(query == null)
	{
		char Error[255];
		SQL_GetError(DB, Error, sizeof(Error));
		LogError("Failed to set points for SteamID %s, (Error: %s)", auth, Error);
	}
	else
	{
		if(SQL_FetchRow(query))
		{
			Format(statement2, sizeof(statement2), "UPDATE `SkillBot` SET `Points`='%i' WHERE `SteamID`='%s'", a, auth);

			if(!SQL_FastQuery(DB, statement2))
			{
				char Error[256];
				SQL_GetError(DB, Error, sizeof(Error));
				LogError("Could not set points, SteamID %s, Points %s, Error %s", auth, a, Error);
			}
		}
		else
		{
			Format(statement2, sizeof(statement2), "INSERT INTO `SkillBot` (`SteamID`, `Points`) VALUES ('%s', '%i')", auth, a);

			if(!SQL_FastQuery(DB, statement2))
			{
				char Error[256];
				SQL_GetError(DB, Error, sizeof(Error));
				LogError("Could not set points, SteamID %s, Points %s, Error %s", auth, a, Error);
			}
		}
	}
	*/
}

public void SQL_UpdatePoints(Handle hDriver, Handle query, const char[] sError, any data)
{
	DataPack pk = view_as<DataPack>(data);
	pk.Reset();

	char auth[64], statement2[128];
	pk.ReadString(auth, sizeof(auth));
	int a = pk.ReadCell();

	if(query == null)
	{
		LogError("Failed to set points for SteamID %s, (Error: %s)", auth, sError);
	}
	else
	{
		if(SQL_FetchRow(query))
		{
			Format(statement2, sizeof(statement2), "UPDATE `SkillBot` SET `Points`='%i' WHERE `SteamID`='%s'", a, auth);

			if(!SQL_FastQuery(DB, statement2))
			{
				LogError("Could not set points, SteamID %s, Points %s, Error %s", auth, a, sError);
			}
		}
		else
		{
			Format(statement2, sizeof(statement2), "INSERT INTO `SkillBot` (`SteamID`, `Points`) VALUES ('%s', '%i')", auth, a);

			if(!SQL_FastQuery(DB, statement2))
			{
				LogError("Could not set points, SteamID %s, Points %s, Error %s", auth, a, sError);
			}
		}
	}

	if (query != INVALID_HANDLE) {
		CloseHandle(query);
		query = INVALID_HANDLE;
	}
}

public void Function_AddPoints(int client, int a) {
	sessionPoints[client] = (sessionPoints[client] + a);
	Function_SetPoints(client, (Function_ReturnPoints(client) + a));
}

public void Function_SubPoints(int client, int a) {
	sessionPoints[client] = (sessionPoints[client] - a);
	Function_SetPoints(client, (Function_ReturnPoints(client) - a));
}

public void Function_GetRank(int rank, char[] string, int maxlength) {
	char sRank[64];
	Format(sRank, sizeof(sRank), "%s", Ranks[rank][chatRank]);
	strcopy(string, maxlength, sRank);
}

public void Function_GetRank2(int rank, char[] string, int maxlength) {
	char sRank[64];
	Format(sRank, sizeof(sRank), "%s", Ranks[rank][menuRank]);
	strcopy(string, maxlength, sRank);
}

public void Function_GetRank3(int rank, char[] string, int maxlength) {
	char sRank[64];
	Format(sRank, sizeof(sRank), "%s", Ranks[rank][tagRank]);
	strcopy(string, maxlength, sRank);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("SB_GetChatRank", Native_GetChatRank);
	CreateNative("SB_GetRank", Native_GetRank);
	CreateNative("SB_GetRank2", Native_GetRank2);

	CreateNative("SB_SetPoints", Native_SetPoints);
	CreateNative("SB_GetPoints", Native_GetPoints);
	CreateNative("SB_AddPoints", Native_AddPoints);
	CreateNative("SB_SubPoints", Native_SubPoints);

	RegPluginLibrary("skillbot");
	MarkNativeAsOptional("Perks_ToggleTracers");
	return APLRes_Success;
}

public int Native_SetPoints(Handle plugin, int numParams)
{
	Function_SetPoints(GetNativeCell(1), GetNativeCell(2));
}

public int Native_GetPoints(Handle plugin, int numParams)
{
	return Function_ReturnPoints(GetNativeCell(1));
}

public int Native_AddPoints(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	Function_SetPoints(client, Function_ReturnPoints(client) + GetNativeCell(2));
}

public int Native_SubPoints(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	Function_SetPoints(client, Function_ReturnPoints(client) - GetNativeCell(2));
}

public int Native_GetChatRank(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);

	char rank[64], status[8];
	GetClientCookie(client, gH_sChatTag, status, sizeof(status));
	if(!StrEqual(status, "off", false))
	{
		Function_GetRank3(Function_GetRankNumber(client), rank, sizeof(rank));
		SetNativeString(2, rank, GetNativeCell(3), false);
	}
	else
	{
		SetNativeString(2, "", GetNativeCell(3), false);
	}
}

public int Native_GetRank(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return Function_GetRankNumber(client);
}

public int Native_GetRank2(Handle plugin, int numParams)
{
	int rank = GetNativeCell(1);

	char sRank[64];
	Format(sRank, sizeof(sRank), "%s", Ranks[rank][menuRank]);

	SetNativeString(2, sRank, GetNativeCell(3), false);
}

stock int Function_GetRankNumber(int client)
{
	int points = Function_ReturnPoints(client);
	if(points <= Ranks[0][rankPoints]) return 0;
	if(points >= Ranks[maxRank-1][rankPoints]) return maxRank-1;
	for(int i = maxRank-2; i > 0; i--) {
		if(points >= Ranks[i][rankPoints]) return i;
	}
	return -1;
}

stock int Function_GetNextPoints(int client) {
	int rank = Function_GetRankNumber(client) + 1;
	return (Ranks[rank][rankPoints] - Function_ReturnPoints(client));
}

public void Function_RankList(int client) {
	for (int i = 0; i < maxRank; i++)
	{
		char rank[64];
		Function_GetRank(i, rank, sizeof(rank));
		int j = (i + 1);
		Function_PrintChat(client, "Rank %i: %s - %i Points", j, rank, Ranks[i][rankPoints]);
	}
}

public void Function_NextPoints(int reader, int client) {
	char rank[64], rank2[64];
	Function_GetRank(Function_GetRankNumber(client), rank, sizeof(rank));
	if (Function_GetRankNumber(client) == maxRank-1)
	{
		Function_PrintChat(reader, "%N is at rank %s, and has %i points. They are at the max rank.", client, rank, Function_ReturnPoints(client));
	}
	else
	{
		Function_GetRank(Function_GetRankNumber(client) + 1, rank2, sizeof(rank2));
		Function_PrintChat(reader, "%N is at rank %s, and has %i points. They need %i points to get to the next rank %s.", client, rank, Function_ReturnPoints(client), Function_GetNextPoints(client), rank2);
	}
}

public Action SetPoints(int client, int argc)
{
	if (argc < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_setpoints <client|#userid> [amount]");
		return Plugin_Handled;
	}

	char arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));

	int target = FindTarget(client, arg1);
	if (target == -1)
	{
		return Plugin_Handled;
	}

	char arg2[32];
	GetCmdArg(2, arg2, sizeof(arg2));
	int amount = StringToInt(arg2, 10);

	Function_SetPoints(target, amount);
	Function_PrintChat(client, "Player %N has been set to %i points.", target, amount);
	return Plugin_Handled;
}

public Action AddPoints(int client, int argc)
{
	if (argc < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_addpoints <client|#userid> [amount]");
		return Plugin_Handled;
	}

	char arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));

	int target = FindTarget(client, arg1);
	if (target == -1)
	{
		return Plugin_Handled;
	}

	char arg2[32];
	GetCmdArg(2, arg2, sizeof(arg2));
	int amount = StringToInt(arg2, 10);

	Function_AddPoints(target, amount);
	Function_PrintChat(client, "Player %N has been given %i points.", target, amount);
	return Plugin_Handled;
}

public Action SkillBotMenu(int client, int argc)
{
	if (argc == 0)
	{
		Handle menu = CreateMenu(SkillBot_Handler1);

		char rank[64];
		Function_GetRank2(Function_GetRankNumber(client), rank, sizeof(rank));

		SetMenuTitle(menu, "Player: %N\nPoints: %i\nRank: %s\nDamage: (%i/4000)\nSession: %i Points", client, Function_ReturnPoints(client), rank, damageGiven[client], sessionPoints[client]);
		AddMenuItem(menu, "-1", "List of Ranks");
		AddMenuItem(menu, "0", "Next Rank");
		AddMenuItem(menu, "1", "List of Hard Maps");
		AddMenuItem(menu, "2", "Is Current Map Hard?");
		AddMenuItem(menu, "3", "Skillbot Settings");
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
	if (argc == 1)
	{
		char arg1[65];
		GetCmdArg(1, arg1, sizeof(arg1));
		int target = FindTarget(client, arg1, false, false);

		if (target == -1)
		{
			return Plugin_Handled;
		}

		clientTarget[client] = target;

		Handle menu = CreateMenu(SkillBot_Handler2);

		char rank[64];
		Function_GetRank2(Function_GetRankNumber(target), rank, sizeof(rank));

		SetMenuTitle(menu, "Player: %N\nPoints: %i\nRank: %s\nDamage: (%i/4000)\nSession: %i Points", target, Function_ReturnPoints(target), rank, damageGiven[client], sessionPoints[client]);
		AddMenuItem(menu, "-1", "List of Ranks");
		AddMenuItem(menu, "0", "Next Rank");
		SetMenuExitButton(menu, true);
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}
public int SkillBot_Handler1(Handle menu, MenuAction action, int client, int position)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, position, info, sizeof(info));

		if (StrEqual(info, "-1"))
		{
			Function_RankList(client);
		}

		if (StrEqual(info, "0"))
		{
			Function_NextPoints(client, client);
		}

		if (StrEqual(info, "1"))
		{
			Function_ListHardMaps(client);
		}

		if (StrEqual(info, "2"))
		{
			checkMapHard(client);
		}

		if (StrEqual(info, "3"))
		{
			SettingsMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}
public int SkillBot_Handler2(Handle menu, MenuAction action, int client, int position)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, position, info, sizeof(info));

		if (StrEqual(info, "-1"))
		{
			Function_RankList(client);
		}

		if (StrEqual(info, "0"))
		{
			if (IsValidClient(clientTarget[client]))
			Function_NextPoints(client, clientTarget[client]);
		}

		if (StrEqual(info, "1"))
		{
			Function_ListHardMaps(client);
		}

		if (StrEqual(info, "2"))
		{
			checkMapHard(client);
		}

	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

void SettingsMenu(int client)
{
	Handle menu = CreateMenu(SettingsHandler);

	char status[8], chatTag[64];
	GetClientCookie(client, gH_sChatTag, status, sizeof(status));

	char status2[8], tracer[64];
	GetClientCookie(client, gH_sTracers, status2, sizeof(status2));

	if(!StrEqual(status, "off", false))
	{
		Format(chatTag, sizeof(chatTag), "Disable Chat Tags");
	}
	else
	{
		Format(chatTag, sizeof(chatTag), "Enable Chat Tags");
	}

	if(!StrEqual(status2, "off", false))
	{
		Format(tracer, sizeof(tracer), "Disable Tracers");
	}
	else
	{
		Format(tracer, sizeof(tracer), "Enable Tracers");
	}

	SetMenuTitle(menu, "Skillbot Settings");
	AddMenuItem(menu, "chattags", chatTag);
	AddMenuItem(menu, "tracers", tracer);

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int SettingsHandler(Handle menu, MenuAction action, int client, int position)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, position, info, sizeof(info));

		if(StrEqual(info, "chattags", false))
		{
			char status[8];
			GetClientCookie(client, gH_sChatTag, status, sizeof(status));

			if(!StrEqual(status, "off", false))
			{
				SetClientCookie(client, gH_sChatTag, "off");
				Function_PrintChat(client, "You have turned off chat tags.");
			}
			else
			{
				SetClientCookie(client, gH_sChatTag, "on");
				Function_PrintChat(client, "You have turned on chat tags.");
			}
		}

		if(StrEqual(info, "tracers", false) && perks)
		{
			Perks_ToggleTracers(client);
		}

	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}
