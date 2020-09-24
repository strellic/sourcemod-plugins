#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <zombiereloaded>
#include <sdkhooks>

#define PLUGIN_VERSION "2.9f"
#pragma newdecls required

int leaderMVP, leaderScore, currentSprite = -1, spriteEntity, markerEntity, leaderClient = -1;
bool markerActive = false, beaconActive = false;

ConVar g_cVDefendVTF = null;
ConVar g_cVDefendVMT = null;
ConVar g_cVFollowVTF = null;
ConVar g_cVFollowVMT = null;

char DefendVMT[PLATFORM_MAX_PATH];
char DefendVTF[PLATFORM_MAX_PATH];
char FollowVMT[PLATFORM_MAX_PATH];
char FollowVTF[PLATFORM_MAX_PATH];

//Beacon stuff
int g_BeamSprite = -1; 
int g_HaloSprite = -1; 
int g_BeaconSerial[MAXPLAYERS+1] = { 0, ... }; 
int g_Serial_Gen = 0; 

public Plugin myinfo = {
	name = "Leader",
	author = "AntiTeal",
	description = "Allows for a player to be a leader, and give them special functions with it.",
	version = PLUGIN_VERSION,
	url = "https://antiteal.com"
};

public void OnPluginStart()
{
	CreateConVar("sm_leader_verion", PLUGIN_VERSION, "Plugin Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");

	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_death", Event_PlayerDeath);
	AddCommandListener(HookPlayerChat, "say");

	RegConsoleCmd("sm_leader", Leader);
	RegConsoleCmd("sm_currentleader", CurrentLeader);
	RegAdminCmd("sm_removeleader", RemoveTheLeader, ADMFLAG_GENERIC);

	RegAdminCmd("sm_sbperks_leader", SBPerks_Leader, ADMFLAG_GENERIC);

	g_cVDefendVMT = CreateConVar("sm_leader_defend_vmt", "materials/sg/sgdefend.vmt", "The defend here .vmt file");
	g_cVDefendVTF = CreateConVar("sm_leader_defend_vtf", "materials/sg/sgdefend.vtf", "The defend here .vtf file");
	g_cVFollowVMT = CreateConVar("sm_leader_follow_vmt", "materials/sg/sgfollow.vmt", "The follow me .vmt file");
	g_cVFollowVTF = CreateConVar("sm_leader_follow_vtf", "materials/sg/sgfollow.vtf", "The follow me .vtf file");

	AutoExecConfig(true);

	g_cVDefendVMT.AddChangeHook(ConVarChange);
	g_cVDefendVTF.AddChangeHook(ConVarChange);
	g_cVFollowVMT.AddChangeHook(ConVarChange);
	g_cVFollowVTF.AddChangeHook(ConVarChange);
}

public void ConVarChange(ConVar CVar, const char[] oldVal, const char[] newVal)
{
	g_cVDefendVTF.GetString(DefendVTF, sizeof(DefendVTF));
	g_cVDefendVMT.GetString(DefendVMT, sizeof(DefendVMT));
	g_cVFollowVTF.GetString(FollowVTF, sizeof(FollowVTF));
	g_cVFollowVMT.GetString(FollowVMT, sizeof(FollowVMT));

	AddFileToDownloadsTable(DefendVTF);
	AddFileToDownloadsTable(DefendVMT);
	AddFileToDownloadsTable(FollowVTF);
	AddFileToDownloadsTable(FollowVMT);

	PrecacheGeneric(DefendVTF, true);
	PrecacheGeneric(DefendVMT, true);
	PrecacheGeneric(FollowVTF, true);
	PrecacheGeneric(FollowVMT, true);
}

public void OnConfigsExecuted()
{
	g_cVDefendVTF.GetString(DefendVTF, sizeof(DefendVTF));
	g_cVDefendVMT.GetString(DefendVMT, sizeof(DefendVMT));
	g_cVFollowVTF.GetString(FollowVTF, sizeof(FollowVTF));
	g_cVFollowVMT.GetString(FollowVMT, sizeof(FollowVMT));

	AddFileToDownloadsTable(DefendVTF);
	AddFileToDownloadsTable(DefendVMT);
	AddFileToDownloadsTable(FollowVTF);
	AddFileToDownloadsTable(FollowVMT);

	PrecacheGeneric(DefendVTF, true);
	PrecacheGeneric(DefendVMT, true);
	PrecacheGeneric(FollowVTF, true);
	PrecacheGeneric(FollowVMT, true);
}

public void OnMapStart()
{
	Handle gameConfig = LoadGameConfigFile("funcommands.games");
	if (gameConfig == null)
	{
		SetFailState("Unable to load game config funcommands.games");
		return;
	}

	char buffer[PLATFORM_MAX_PATH];
	if (GameConfGetKeyValue(gameConfig, "SpriteBeam", buffer, sizeof(buffer)) && buffer[0])
	{
		g_BeamSprite = PrecacheModel(buffer);
	}
	if (GameConfGetKeyValue(gameConfig, "SpriteHalo", buffer, sizeof(buffer)) && buffer[0])
	{
		g_HaloSprite = PrecacheModel(buffer);
	}
}

public void CreateBeacon(int client) 
{ 
	g_BeaconSerial[client] = ++g_Serial_Gen; 
	CreateTimer(1.0, Timer_Beacon, client | (g_Serial_Gen << 7), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);     
} 

public void KillBeacon(int client) 
{ 
	g_BeaconSerial[client] = 0; 

	if (IsClientInGame(client)) 
	{ 
		SetEntityRenderColor(client, 255, 255, 255, 255); 
	} 
} 

public void KillAllBeacons() 
{ 
	for (int i = 1; i <= MaxClients; i++) 
	{ 
		KillBeacon(i); 
	} 
} 

public void PerformBeacon(int client) 
{ 
	if (g_BeaconSerial[client] == 0) 
	{ 
		CreateBeacon(client); 
		LogAction(client, client, "\"%L\" set a beacon on himself", client); 
	} 
	else 
	{ 
		KillBeacon(client); 
		LogAction(client, client, "\"%L\" removed a beacon on himself", client); 
	} 
} 

public Action Timer_Beacon(Handle timer, any value) 
{ 
	int client = value & 0x7f; 
	int serial = value >> 7; 

	if (!IsClientInGame(client) || !IsPlayerAlive(client) || g_BeaconSerial[client] != serial) 
	{ 
		KillBeacon(client); 
		return Plugin_Stop; 
	}

	float vec[3]; 
	GetClientAbsOrigin(client, vec); 
	vec[2] += 10; 

	TE_SetupBeamRingPoint(vec, 10.0, 375.0, g_BeamSprite, g_HaloSprite, 0, 15, 0.5, 5.0, 0.0, {128, 128, 128, 255}, 10, 0); 
	TE_SendToAll(); 
	
	int rainbow[3], rainbow_fix[4];
	Rainbow(rainbow);
	rainbow_fix[0] = rainbow[0];
	rainbow_fix[1] = rainbow[1];
	rainbow_fix[2] = rainbow[2];
	rainbow_fix[3] = 255;
	TE_SetupBeamRingPoint(vec, 10.0, 375.0, g_BeamSprite, g_HaloSprite, 0, 10, 0.6, 10.0, 0.5, rainbow_fix, 10, 0); 
	
	TE_SendToAll(); 
	
	GetClientEyePosition(client, vec); 
	
	return Plugin_Continue; 
} 

public int AttachSprite(int client, char[] sprite) //https://forums.alliedmods.net/showpost.php?p=1880207&postcount=5
{
	if(!IsPlayerAlive(client)) 
	{
		return -1;
	}

	char iTarget[16], sTargetname[64];
	//Fix to avoid breaking targetname detection on maps
	GetEntPropString(client, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));

	Format(iTarget, sizeof(iTarget), "Client%d", client);
	DispatchKeyValue(client, "targetname", iTarget);

	float Origin[3];
	GetClientEyePosition(client, Origin);
	Origin[2] += 45.0;

	int Ent = CreateEntityByName("env_sprite");
	if(!Ent) return -1;

	DispatchKeyValue(Ent, "model", sprite);
	DispatchKeyValue(Ent, "classname", "env_sprite");
	DispatchKeyValue(Ent, "spawnflags", "1");
	DispatchKeyValue(Ent, "scale", "0.1");
	DispatchKeyValue(Ent, "rendermode", "1");
	DispatchKeyValue(Ent, "rendercolor", "255 255 255");
	DispatchSpawn(Ent);
	TeleportEntity(Ent, Origin, NULL_VECTOR, NULL_VECTOR);
	SetVariantString(iTarget);
	AcceptEntityInput(Ent, "SetParent", Ent, Ent, 0);

	DispatchKeyValue(client, "targetname", sTargetname);

	return Ent;
}

public void RemoveSprite()
{
	if (spriteEntity != -1 && spriteEntity)
	{
		char m_szClassname[64];
		GetEdictClassname(spriteEntity, m_szClassname, sizeof(m_szClassname));
		if(strcmp("env_sprite", m_szClassname)==0)
		AcceptEntityInput(spriteEntity, "Kill");
	}
	spriteEntity = -1;
}

public void RemoveMarker()
{
	if (markerEntity != -1 && IsValidEdict(markerEntity))
	{
		char m_szClassname[64];
		GetEdictClassname(markerEntity, m_szClassname, sizeof(m_szClassname));
		if(strcmp("env_sprite", m_szClassname)==0)
		AcceptEntityInput(markerEntity, "Kill");
	}
	markerEntity = -1;
}

public void SetLeader(int client) 
{
	if(IsValidClient(leaderClient))
	{
		RemoveLeader(leaderClient);
		PrintToChatAll("[SM] The current leader has been removed!");
	}

	if(IsValidClient(client)) 
	{
		leaderClient = client;
		leaderMVP = CS_GetMVPCount(client);
		leaderScore = CS_GetClientContributionScore(client);
		CS_SetMVPCount(client, 99);
		CS_SetClientContributionScore(client, 9999);
		currentSprite = -1;

		RainbowClient(client);
		SDKHook(client, SDKHook_PostThinkPost, RainbowClient);
	}
}

public void RemoveLeader(int client)
{
	RemoveSprite();
	RemoveMarker();
	currentSprite = -1;
	leaderClient = -1;
	markerActive = false;
	beaconActive = false;
	KillBeacon(client);
	
	if(IsValidClient(client))
	{
		CS_SetMVPCount(client, leaderMVP);
		CS_SetClientContributionScore(client, leaderScore);
		SDKUnhook(client, SDKHook_PostThinkPost, RainbowClient);
	}
}

public int SpawnMarker(int client, char[] sprite)
{
	if(!IsPlayerAlive(client)) 
	{
		return -1;
	}

	float Origin[3];
	GetClientEyePosition(client, Origin);
	Origin[2] += 25.0;

	int Ent = CreateEntityByName("env_sprite");
	if(!Ent) return -1;

	DispatchKeyValue(Ent, "model", sprite);
	DispatchKeyValue(Ent, "classname", "env_sprite");
	DispatchKeyValue(Ent, "spawnflags", "1");
	DispatchKeyValue(Ent, "scale", "0.1");
	DispatchKeyValue(Ent, "rendermode", "1");
	DispatchKeyValue(Ent, "rendercolor", "255 255 255");
	DispatchSpawn(Ent);
	TeleportEntity(Ent, Origin, NULL_VECTOR, NULL_VECTOR);

	return Ent;
}

public Action CurrentLeader(int client, int args)
{
	if(IsValidClient(leaderClient))
	{
		PrintToChat(client, "[SM] The current leader is %N!", leaderClient);
		return Plugin_Handled;
	}
	else
	{
		PrintToChat(client, "[SM] There is no current leader!");
		return Plugin_Handled;
	}
}

public Action RemoveTheLeader(int client, int args)
{
	if(IsValidClient(leaderClient))
	{
		PrintToChatAll("[SM] The current leader has been removed!");
		RemoveLeader(leaderClient);
		return Plugin_Handled;
	}
	else
	{
		PrintToChat(client, "[SM] There is no current leader!");
		return Plugin_Handled;
	}
}

public Action SBPerks_Leader(int client, int args)
{
	if(args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_sbperks_leader <#userid|name>");
		return Plugin_Handled;
	}

	char arg1[65];
	GetCmdArg(1, arg1, sizeof(arg1));
	int target = FindTarget(client, arg1, false, false);

	if(target == leaderClient)
	{
		LeaderMenu(target);
		return Plugin_Handled;
	}
	if(IsValidClient(leaderClient))
	{
		PrintToChat(target, "[SM] Sorry, but there is already a leader!");
		return Plugin_Handled;
	}
	if(!IsPlayerAlive(target))
	{
		PrintToChat(target, "[SM] Sorry, but you need to be alive to be a leader!");
		return Plugin_Handled;
	}
	if(ZR_IsClientZombie(target))
	{
		PrintToChat(target, "[SM] Sorry, but you have to be human to be a leader!");
		return Plugin_Handled;
	}

	SetLeader(target);
	PrintToChatAll("[SM] %N is the new leader!", target);
	PrintToChat(target, "[SM] You are now the leader! Type !leader to open up the leader menu.");
	LeaderMenu(target);

	return Plugin_Handled;
}

public Action Leader(int client, int args)
{
	if(CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC, false))
	{
		if(args == 1)
		{
			char arg1[65];
			GetCmdArg(1, arg1, sizeof(arg1));
			int target = FindTarget(client, arg1, false, false);
			if (target == -1)
			{
				return Plugin_Handled;
			}

			if(target == leaderClient)
			{
				LeaderMenu(target);
			}
			else
			{
				if(IsPlayerAlive(target))
				{
					SetLeader(target);
					PrintToChatAll("[SM] %N is the new leader!", target);
					PrintToChat(target, "[SM] You are now the leader! Type !leader to open up the leader menu.");
					LeaderMenu(target);
				}
				else
				{
					ReplyToCommand(client, "[SM] The target has to be alive!");
				}
			}	
		}
		else if(args == 0)
		{
			if(client == leaderClient)
			{
				LeaderMenu(client);
				return Plugin_Handled;
			}
			if(IsPlayerAlive(client))
			{
				SetLeader(client);
				PrintToChatAll("[SM] %N is the new leader!", client);
				PrintToChat(client, "[SM] You are now the leader! Type !leader to open up the leader menu.");
				LeaderMenu(client);
			}
			else
			{
				ReplyToCommand(client, "[SM] The target has to be alive!");
			}
		}
		else
		{
			ReplyToCommand(client, "[SM] Usage: sm_leader <optional: client|#userid>");
		}
	}
	if(client == leaderClient)
	{
		LeaderMenu(client);
	}
	return Plugin_Handled;
}

public void LeaderMenu(int client)
{
	Handle menu = CreateMenu(LeaderMenu_Handler);

	char sprite[64], marker[64], beacon[64];

	switch (currentSprite)
	{
		case 0:
		sprite = "Defend";
		case 1:
		sprite = "Follow";
		default:
		sprite = "None";
	}

	if(markerActive)
	marker = "Yes";
	else
	marker = "No";

	if(beaconActive)
	beacon = "Yes";
	else
	beacon = "No";

	SetMenuTitle(menu, "Leader Menu\nSprite: %s\nMarker: %s\nBeacon: %s", sprite, marker, beacon);
	AddMenuItem(menu, "resign", "Resign from Leader");
	AddMenuItem(menu, "sprite", "Sprite Menu");
	AddMenuItem(menu, "marker", "Marker Menu");
	AddMenuItem(menu, "beacon", "Toggle Beacon");

	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int LeaderMenu_Handler(Handle menu, MenuAction action, int client, int position)
{
	if(leaderClient == client && IsValidClient(client))
	{
		if(action == MenuAction_Select)
		{
			char info[32];
			GetMenuItem(menu, position, info, sizeof(info));

			if(StrEqual(info, "resign"))
			{
				RemoveLeader(client);
				PrintToChatAll("[SM] %N has resigned from being leader!", client);
			}
			if(StrEqual(info, "sprite"))
			{
				SpriteMenu(client);
			}
			if(StrEqual(info, "marker"))
			{
				MarkerMenu(client);
			}
			if(StrEqual(info, "beacon"))
			{
				ToggleBeacon(client);
				LeaderMenu(client);
			}
		}
		else if(action == MenuAction_End)
		{
			CloseHandle(menu);
		}
	}

}

public void ToggleBeacon(int client)
{
	if(beaconActive)
	beaconActive = false;
	else
	beaconActive = true;
	
	PerformBeacon(client);
}

public void SpriteMenu(int client)
{
	Handle menu = CreateMenu(SpriteMenu_Handler);

	char sprite[64], marker[64], beacon[64];

	switch (currentSprite)
	{
		case 0:
		sprite = "Defend";
		case 1:
		sprite = "Follow";
		default:
		sprite = "None";
	}

	if(markerActive)
	marker = "Yes";
	else
	marker = "No";

	if(beaconActive)
	beacon = "Yes";
	else
	beacon = "No";

	SetMenuTitle(menu, "Leader Menu\nSprite: %s\nMarker: %s\nBeacon: %s", sprite, marker, beacon);
	AddMenuItem(menu, "none", "No Sprite");
	AddMenuItem(menu, "defend", "Defend Here");
	AddMenuItem(menu, "follow", "Follow Me");

	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int SpriteMenu_Handler(Handle menu, MenuAction action, int client, int position)
{
	if(leaderClient == client && IsValidClient(client)) 
	{
		if(action == MenuAction_Select)
		{
			char info[32];
			GetMenuItem(menu, position, info, sizeof(info));

			if(StrEqual(info, "none"))
			{
				RemoveSprite();
				PrintToChat(client, "[SM] Sprite removed.");
				currentSprite = -1;
				LeaderMenu(client);
			}
			if(StrEqual(info, "defend"))
			{
				RemoveSprite();
				spriteEntity = AttachSprite(client, DefendVMT);
				PrintToChat(client, "[SM] Sprite changed to 'Defend Here'.");
				currentSprite = 0;
				LeaderMenu(client);
			}
			if(StrEqual(info, "follow"))
			{
				RemoveSprite();
				spriteEntity = AttachSprite(client, FollowVMT);
				PrintToChat(client, "[SM] Sprite changed to 'Follow Me'.");
				currentSprite = 1;
				LeaderMenu(client);
			}
		}
		else if(action == MenuAction_End)
		{
			CloseHandle(menu);
		}
		else if (action == MenuAction_Cancel && position == MenuCancel_ExitBack) 
		{ 
			LeaderMenu(client);
		}
	}
}

public void MarkerMenu(int client)
{
	Handle menu = CreateMenu(MarkerMenu_Handler);

	char sprite[64], marker[64], beacon[64];

	switch (currentSprite)
	{
		case 0:
		sprite = "Defend";
		case 1:
		sprite = "Follow";
		default:
		sprite = "None";
	}

	if(markerActive)
	marker = "Yes";
	else
	marker = "No";

	if(beaconActive)
	beacon = "Yes";
	else
	beacon = "No";

	SetMenuTitle(menu, "Leader Menu\nSprite: %s\nMarker: %s\nBeacon: %s", sprite, marker, beacon);
	AddMenuItem(menu, "removemarker", "Remove Marker");
	AddMenuItem(menu, "defendmarker", "Defend Marker");

	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MarkerMenu_Handler(Handle menu, MenuAction action, int client, int position)
{
	if(leaderClient == client && IsValidClient(client)) 
	{
		if(action == MenuAction_Select)
		{
			char info[32];
			GetMenuItem(menu, position, info, sizeof(info));

			if(StrEqual(info, "removemarker"))
			{
				RemoveMarker();
				PrintToChat(client, "[SM] Marker removed.");
				markerActive = false;
				LeaderMenu(client);
			}
			if(StrEqual(info, "defendmarker"))
			{
				RemoveMarker();
				markerEntity = SpawnMarker(client, DefendVMT);
				PrintToChat(client, "[SM] 'Defend Here' marker placed.");
				markerActive = true;
				LeaderMenu(client);
			}
		}
		else if(action == MenuAction_End)
		{
			CloseHandle(menu);
		}
		else if (action == MenuAction_Cancel && position == MenuCancel_ExitBack) 
		{ 
			LeaderMenu(client);
		}
	}
}
public void OnClientDisconnect(int client)
{
	if(client == leaderClient)
	{
		PrintToChatAll("[SM] The leader has disconnected!");
		RemoveLeader(client);
	}
}

public Action Event_PlayerDeath(Handle event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(client == leaderClient)
	{
		PrintToChatAll("[SM] The leader has died!");
		RemoveLeader(client);
	}
}

public int ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
	if(client == leaderClient)
	{
		PrintToChatAll("[SM] The leader has been infected!");
		RemoveLeader(client);
	}
}

public void OnMapEnd()
{
	if(IsValidClient(leaderClient))
	{
		RemoveLeader(leaderClient);
	}
	leaderClient = -1;
	KillAllBeacons(); 
}

bool IsValidClient(int client, bool nobots = true)
{ 
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false; 
	}
	return IsClientInGame(client); 
}  

public Action Event_RoundEnd(Handle event, char[] name, bool dontBroadcast)
{
	if(IsValidClient(leaderClient))
	{
		RemoveLeader(leaderClient);
	}
	KillAllBeacons();
}

public Action HookPlayerChat(int client, char[] command, int args)
{
	if(IsValidClient(client) && leaderClient == client)
	{
		char LeaderText[256];
		GetCmdArgString(LeaderText, sizeof(LeaderText));
		StripQuotes(LeaderText);		
		if(LeaderText[0] == '/' || LeaderText[0] == '@' || strlen(LeaderText) == 0 || IsChatTrigger())
		{
			return Plugin_Handled;
		}
		if(IsClientInGame(client) && IsPlayerAlive(client))
		{
			PrintToChatAll("\x01[Leader] \x0C%N:\x02 %s", client, LeaderText);
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public void Rainbow(int array[3])
{
	float i = GetGameTime();
	float Frequency = 2.5;

	int Red   = RoundFloat(Sine(Frequency * i + 0.0) * 127.0 + 128.0);
	int Green = RoundFloat(Sine(Frequency * i + 2.0943951) * 127.0 + 128.0);
	int Blue  = RoundFloat(Sine(Frequency * i + 4.1887902) * 127.0 + 128.0);

	array[0] = Red, array[1] = Green, array[2] = Blue;
}

public void RainbowClient(int client)
{
	int rainbow[3];
	Rainbow(rainbow);
	SetEntityRenderColor(client, rainbow[0], rainbow[1], rainbow[2], 255);
}