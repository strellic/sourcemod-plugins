//====================================================================================================
//
// Name: entWatch
// Author: Prometheum & zaCade
// Description: Monitor entity interactions.
//
//====================================================================================================
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <clientprefs>
#include <colors_csgo>
#include <cstrike>
#include <entWatch>
#include <protobuf>

#define PLUGIN_VERSION "3.0.4"

//----------------------------------------------------------------------------------------------------
// Purpose: Entity Data
//----------------------------------------------------------------------------------------------------
enum entities
{
	String:ent_name[32],
	String:ent_shortname[32],
	String:ent_color[32],
	String:ent_buttonclass[32],
	String:ent_filtername[32],
	bool:ent_hasfiltername,
	bool:ent_blockpickup,
	bool:ent_allowtransfer,
	bool:ent_forcedrop,
	bool:ent_chat,
	bool:ent_hud,
	ent_hammerid,
	ent_weaponid,
	ent_buttonid,
	ent_ownerid,
	ent_mode, // 0 = No button, 1 = Spam protection only, 2 = Cooldowns, 3 = Limited uses, 4 = Limited uses with cooldowns, 5 = Cooldowns after multiple uses.
	ent_uses,
	ent_maxuses,
	ent_cooldown,
	ent_cooldowntime,
	ent_dummy_weapon
};

new entArray[512][entities];
new entArraySize = 512;

//----------------------------------------------------------------------------------------------------
// Purpose: Tag Settings
//----------------------------------------------------------------------------------------------------
new String:g_LastTag[MAXPLAYERS+1][MAX_NAME_LENGTH];
new Handle:HudSync = INVALID_HANDLE;

//----------------------------------------------------------------------------------------------------
// Purpose: Color Settings
//----------------------------------------------------------------------------------------------------
new String:color_tag[16]         = "E01B5D";
new String:color_name[16]        = "EDEDED";
new String:color_steamid[16]     = "B2B2B2";
new String:color_use[16]         = "67ADDF";
new String:color_pickup[16]      = "C9EF66";
new String:color_drop[16]        = "E562BA";
new String:color_disconnect[16]  = "F1B567";
new String:color_death[16]       = "F1B567";
new String:color_warning[16]     = "F16767";

//----------------------------------------------------------------------------------------------------
// Purpose: Client Settings
//----------------------------------------------------------------------------------------------------
new Handle:G_hCookie_Display     = INVALID_HANDLE;
new Handle:G_hCookie_Restricted  = INVALID_HANDLE;

new bool:G_bDisplay[MAXPLAYERS + 1]     = false;
new bool:G_bRestricted[MAXPLAYERS + 1]  = false;

new g_iAdminMenuTarget[MAXPLAYERS + 1];

//----------------------------------------------------------------------------------------------------
// Purpose: Plugin Settings
//----------------------------------------------------------------------------------------------------
new Handle:G_hCvar_DisplayEnabled    = INVALID_HANDLE;
new Handle:G_hCvar_DisplayCooldowns  = INVALID_HANDLE;
new Handle:G_hCvar_ModeTeamOnly      = INVALID_HANDLE;
new Handle:G_hCvar_ConfigColor       = INVALID_HANDLE;

new bool:G_bRoundTransition  = false;
new bool:G_bConfigLoaded     = false;

ConVar g_cVGlowEnable;
ConVar g_cVGlowColor;

ConVar g_cVHudChannel;

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Plugin:myinfo =
{
	name         = "entWatch",
	author       = "Prometheum & zaCade - edits by AntiTeal",
	description  = "Notify players about entity interactions.",
	version      = PLUGIN_VERSION,
	url          = "www.joinsg.net"
};

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public OnPluginStart()
{
	HudSync = CreateHudSynchronizer();

	CreateConVar("entwatch_version", PLUGIN_VERSION, "Current version of entWatch", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	G_hCvar_DisplayEnabled    = CreateConVar("entwatch_display_enable", "1", "Enable/Disable the display.", _, true, 0.0, true, 1.0);
	G_hCvar_DisplayCooldowns  = CreateConVar("entwatch_display_cooldowns", "1", "Show/Hide the cooldowns on the display.", _, true, 0.0, true, 1.0);
	G_hCvar_ModeTeamOnly      = CreateConVar("entwatch_mode_teamonly", "1", "Enable/Disable team only mode.", _, true, 0.0, true, 1.0);
	G_hCvar_ConfigColor       = CreateConVar("entwatch_config_color", "color_classic", "The name of the color config.", _);

	G_hCookie_Display     = RegClientCookie("entwatch_display", "", CookieAccess_Private);
	G_hCookie_Restricted  = RegClientCookie("entwatch_restricted", "", CookieAccess_Private);

	g_cVGlowEnable = CreateConVar("entwatch_glow_enable", "1", "Enable/Disable the glow weapon when dropped.", _, true, 0.0, true, 1.0);
	g_cVGlowColor = CreateConVar("entwatch_glow_color", "255 50 150", "Color of the glow (R G B).", _);

	RegConsoleCmd("sm_hud", Command_ToggleHUD);
	RegConsoleCmd("sm_status", Command_Status);

	RegAdminCmd("sm_eban", Command_Restrict, ADMFLAG_BAN);
	RegAdminCmd("sm_eunban", Command_Unrestrict, ADMFLAG_BAN);
	RegAdminCmd("sm_etransfer", Command_Transfer, ADMFLAG_BAN);

	RegAdminCmd("sm_ewdebugarray", Command_DebugArray, ADMFLAG_CONFIG);
	RegAdminCmd("sm_debugarray", Command_DebugArray, ADMFLAG_CONFIG);
	RegAdminCmd("sm_array", Command_DebugArray, ADMFLAG_CONFIG);

	HookEvent("round_start", Event_RoundStart, EventHookMode_Pre);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Pre);
	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Pre)
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);

	CreateTimer(1.0, Timer_DisplayHUD, _, TIMER_REPEAT);
	CreateTimer(1.0, Timer_Cooldowns, _, TIMER_REPEAT);

	LoadTranslations("entWatch.phrases");
	LoadTranslations("common.phrases");

	AutoExecConfig(true, "plugin.entWatch");

	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			ResetStatus(i);
			TagCheck(i);
		}
	}
}

public Action:Command_DebugArray(client, args)
{
	if (G_bConfigLoaded && !G_bRoundTransition)
	{
		for (new i = 0; i < entArraySize; i++)
		{
			CPrintToChat(client, "%sIndex %s%i: %s%s%s | hID: %s%i%s | oID: %s%i%s | wID: %s%i", color_warning, color_pickup, i, entArray[i][ent_color], entArray[i][ent_shortname], color_warning, color_pickup, entArray[i][ent_hammerid], color_warning, color_pickup, entArray[i][ent_ownerid], color_warning, color_pickup, entArray[i][ent_weaponid]);
		}
	}
	else
	{
		CPrintToChat(client, "\x07%s[entWatch] \x07%sConfig file has not yet loaded or the round is transitioning.", color_tag, color_warning);
	}

	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public OnMapStart()
{
	for (new index = 0; index < entArraySize; index++)
	{
		Format(entArray[index][ent_name],         32, "");
		Format(entArray[index][ent_shortname],    32, "");
		Format(entArray[index][ent_color],        32, "");
		Format(entArray[index][ent_buttonclass],  32, "");
		Format(entArray[index][ent_filtername],   32, "");
		entArray[index][ent_hasfiltername]  = false;
		entArray[index][ent_blockpickup]    = false;
		entArray[index][ent_allowtransfer]  = false;
		entArray[index][ent_forcedrop]      = false;
		entArray[index][ent_chat]           = false;
		entArray[index][ent_hud]            = false;
		entArray[index][ent_hammerid]       = -1;
		entArray[index][ent_weaponid]       = -1;
		entArray[index][ent_buttonid]       = -1;
		entArray[index][ent_ownerid]        = -1;
		entArray[index][ent_mode]           = 0;
		entArray[index][ent_uses]           = 0;
		entArray[index][ent_maxuses]        = 0;
		entArray[index][ent_cooldown]       = 0;
		entArray[index][ent_cooldowntime]   = -1;
		entArray[index][ent_dummy_weapon]   = -1;
	}

	LoadColors();
	LoadConfig();
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (G_bConfigLoaded && G_bRoundTransition)
	{
		CreateTimer(2.5, Start_MSG);
		for (new i = 1; i <= MaxClients; i++)
		{
			if(IsClientInGame(i))
			{
				ResetStatus(i);
				TagCheck(i);
			}
		}
	}

	for (new index = 0; index < entArraySize; index++)
	{
		if(IsValidEntity(entArray[index][ent_dummy_weapon]))
		{
			AcceptEntityInput(entArray[index][ent_dummy_weapon], "Kill");
		}
		entArray[index][ent_dummy_weapon]   = -1;
	}

	G_bRoundTransition = false;
}

public Action:Start_MSG(Handle:timer)
{
	if (G_bConfigLoaded)
	{
		CPrintToChatAll("\x07%s[entWatch] \x07%s%t", color_tag, color_warning, "welcome");
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action:Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (G_bConfigLoaded && !G_bRoundTransition)
	{
		for (new index = 0; index < entArraySize; index++)
		{
			SDKUnhook(entArray[index][ent_buttonid], SDKHook_Use, OnButtonUse);
			entArray[index][ent_weaponid]       = -1;
			entArray[index][ent_buttonid]       = -1;
			entArray[index][ent_ownerid]        = -1;
			entArray[index][ent_cooldowntime]   = -1;
			entArray[index][ent_uses]           = 0;
			if(IsValidEntity(entArray[index][ent_dummy_weapon]))
			{
				AcceptEntityInput(entArray[index][ent_dummy_weapon], "Kill");
			}
			entArray[index][ent_dummy_weapon]   = -1;
		}
	}

	G_bRoundTransition = true;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public OnClientCookiesCached(client)
{
	new String:buffer_cookie[32];
	GetClientCookie(client, G_hCookie_Display, buffer_cookie, sizeof(buffer_cookie));
	G_bDisplay[client] = bool:StringToInt(buffer_cookie);

	GetClientCookie(client, G_hCookie_Restricted, buffer_cookie, sizeof(buffer_cookie));
	G_bRestricted[client] = bool:StringToInt(buffer_cookie);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_WeaponDropPost, OnWeaponDrop);
	SDKHook(client, SDKHook_WeaponEquipPost, OnWeaponEquip);
	SDKHook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);

	if (!AreClientCookiesCached(client))
	{
		G_bDisplay[client] = false;
		G_bRestricted[client] = false;
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public OnClientDisconnect(client)
{
	Format(g_LastTag[client], sizeof(g_LastTag[]), "");
	g_LastTag[client][0] = '\0';

	if (G_bConfigLoaded && !G_bRoundTransition)
	{
		for (new index = 0; index < entArraySize; index++)
		{
			if (entArray[index][ent_ownerid] != -1 && entArray[index][ent_ownerid] == client)
			{
				entArray[index][ent_ownerid] = -1;

				if (entArray[index][ent_forcedrop] && IsValidEdict(entArray[index][ent_weaponid]))
				{
					SDKHooks_DropWeapon(client, entArray[index][ent_weaponid]);
					SpawnDummyModel(index);
				}

				if (entArray[index][ent_chat])
				{
					new String:buffer_steamid[32];
					//GetClientAuthString(client, buffer_steamid, sizeof(buffer_steamid));
					GetClientAuthId(client, AuthId_Steam2, buffer_steamid, sizeof(buffer_steamid), false);
					ReplaceString(buffer_steamid, sizeof(buffer_steamid), "STEAM_", "", true);

					for (new ply = 1; ply <= MaxClients; ply++)
					{
						if (IsClientConnected(ply) && IsClientInGame(ply))
						{
							if (!GetConVarBool(G_hCvar_ModeTeamOnly) || (GetConVarBool(G_hCvar_ModeTeamOnly) && GetClientTeam(ply) == GetClientTeam(client) || !IsPlayerAlive(ply) || CheckCommandAccess(ply, "entWatch_chat", ADMFLAG_CHAT)))
							{
								CPrintToChat(ply, "\x07%s[entWatch] \x07%s%N \x07%s(\x07%s%s\x07%s) \x07%s%t \x07%s%s", color_tag, color_name, client, color_disconnect, color_steamid, buffer_steamid, color_disconnect, color_disconnect, "disconnect", entArray[index][ent_color], entArray[index][ent_name]);
							}
						}
					}
				}
			}
		}
	}

	SDKUnhook(client, SDKHook_WeaponDropPost, OnWeaponDrop);
	SDKUnhook(client, SDKHook_WeaponEquipPost, OnWeaponEquip);
	SDKUnhook(client, SDKHook_WeaponCanUse, OnWeaponCanUse);

	G_bDisplay[client] = false;
	G_bRestricted[client] = false;
}
stock ResetStatus(int client)
{
	if(IsClientInGame(client) && G_bConfigLoaded)
	{
		new death = GetEntProp(client, Prop_Data, "m_iDeaths");
		new frags = GetEntProp(client, Prop_Data, "m_iFrags");
		new scores = frags - death;
		CS_SetClientContributionScore(client, scores);
		CS_SetClientClanTag(client, g_LastTag[client]);
	}
}
stock TagCheck(int i)
{
	if(IsClientInGame(i) && G_bConfigLoaded && !G_bRoundTransition)
	{
		char playerTag[MAX_NAME_LENGTH];
		CS_GetClientClanTag(i, playerTag, sizeof(playerTag));

		if((strncmp(playerTag, "[0", 2) == 0) || (strncmp(playerTag, "[1", 2) == 0) || (strncmp(playerTag, "[2", 2) == 0) || (strncmp(playerTag, "[3", 2) == 0) || (strncmp(playerTag, "[4", 2) == 0) || (strncmp(playerTag, "[5", 2) == 0) || (strncmp(playerTag, "[6", 2) == 0) || (strncmp(playerTag, "[7", 2) == 0) || (strncmp(playerTag, "[8", 2) == 0) || (strncmp(playerTag, "[9", 2) == 0) || (strncmp(playerTag, "[D]", 3) == 0) || (strncmp(playerTag, "[R]", 3) == 0) || (strncmp(playerTag, "[N/A]", 5) == 0))
		{
			Format(g_LastTag[i], sizeof(g_LastTag[]), "");
		}
		else
		{
			Format(g_LastTag[i], sizeof(g_LastTag[]), playerTag);
		}
	}
}
public OnClientSettingsChanged(client)
{
	if(IsClientInGame(client))
	{
		TagCheck(client);
	}
}
SpawnDummyModel(index)
{
	if(!g_cVGlowEnable.IntValue)
	{
		return;
	}
	if (IsValidEntity(entArray[index][ent_dummy_weapon]))
	{
		AcceptEntityInput(entArray[index][ent_dummy_weapon], "Kill");
	}

	float origin[3], angles[3];
	GetEntPropVector(entArray[index][ent_weaponid], Prop_Send, "m_vecOrigin", origin);
	GetEntPropVector(entArray[index][ent_weaponid], Prop_Send, "m_angRotation", angles);

	entArray[index][ent_dummy_weapon] = CreateEntityByName("prop_dynamic_glow");
	if (entArray[index][ent_dummy_weapon] == -1)
	{
		return;
	}

	DispatchKeyValue(entArray[index][ent_dummy_weapon], "model", GetDummyModelName(entArray[index][ent_weaponid]));
	DispatchKeyValue(entArray[index][ent_dummy_weapon], "disablereceiveshadows", "1");
	DispatchKeyValue(entArray[index][ent_dummy_weapon], "disableshadows", "1");
	DispatchKeyValue(entArray[index][ent_dummy_weapon], "solid", "0");
	DispatchKeyValue(entArray[index][ent_dummy_weapon], "spawnflags", "256");
	SetEntProp(entArray[index][ent_dummy_weapon], Prop_Send, "m_CollisionGroup", 11);
	DispatchSpawn(entArray[index][ent_dummy_weapon]);

	TeleportEntity(entArray[index][ent_dummy_weapon], origin, angles, NULL_VECTOR);

	SetEntProp(entArray[index][ent_dummy_weapon], Prop_Send, "m_bShouldGlow", true, true);
	SetEntPropFloat(entArray[index][ent_dummy_weapon], Prop_Send, "m_flGlowMaxDist", 10000000.0);

	char buffer[64];
	g_cVGlowColor.GetString(buffer, sizeof(buffer));

	SetGlowColor(entArray[index][ent_dummy_weapon], buffer);
	SetVariantString("!activator");
	AcceptEntityInput(entArray[index][ent_dummy_weapon], "SetParent", entArray[index][ent_weaponid]);
}
stock void SetGlowColor(int entity, const char[] color)
{
	char colorbuffers[3][4];
	ExplodeString(color, " ", colorbuffers, sizeof(colorbuffers), sizeof(colorbuffers[]));
	int colors[4];
	for (int i = 0; i < 3; i++)
	{
		colors[i] = StringToInt(colorbuffers[i]);
	}
	colors[3] = 255; // Set alpha
	SetVariantColor(colors);
	AcceptEntityInput(entity, "SetGlowColor");
}
String:GetDummyModelName(entity)
{
	char dummy_classname[64];
	char dummy_modelname[PLATFORM_MAX_PATH];
	GetEdictClassname(entity, dummy_classname, sizeof(dummy_classname));

	if (StrEqual(dummy_classname, "weapon_glock", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_pist_glock18.mdl");
	else if (StrEqual(dummy_classname, "weapon_hkp2000", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_pist_hkp2000.mdl");
	else if (StrEqual(dummy_classname, "weapon_usp_silencer", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_pist_223.mdl");
	else if (StrEqual(dummy_classname, "weapon_deagle", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_pist_deagle.mdl");
	else if (StrEqual(dummy_classname, "weapon_revolver", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_pist_revolver.mdl");
	else if (StrEqual(dummy_classname, "weapon_p250", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_pist_p250.mdl");
	else if (StrEqual(dummy_classname, "weapon_elite", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_pist_elite.mdl");
	else if (StrEqual(dummy_classname, "weapon_tec9", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_pist_tec9.mdl");
	else if (StrEqual(dummy_classname, "weapon_fiveseven", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_pist_fiveseven.mdl");
	else if (StrEqual(dummy_classname, "weapon_cz75a", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_pist_cz_75.mdl");
	else if (StrEqual(dummy_classname, "weapon_famas", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_rif_famas.mdl");
	else if (StrEqual(dummy_classname, "weapon_g3sg1", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_snip_g3sg1.mdl");
	else if (StrEqual(dummy_classname, "weapon_galilar", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_rif_galilar.mdl");
	else if (StrEqual(dummy_classname, "weapon_ak47", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_rif_ak47.mdl");
	else if (StrEqual(dummy_classname, "weapon_aug", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_rif_aug.mdl");
	else if (StrEqual(dummy_classname, "weapon_m249", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_mach_m249.mdl");
	else if (StrEqual(dummy_classname, "weapon_m4a1", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_rif_m4a1.mdl");
	else if (StrEqual(dummy_classname, "weapon_m4a1_silencer", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_rif_m4a1_s.mdl");
	else if (StrEqual(dummy_classname, "weapon_mac10", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_smg_mac10.mdl");
	else if (StrEqual(dummy_classname, "weapon_mag7", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_shot_mag7.mdl");
	else if (StrEqual(dummy_classname, "weapon_mp7", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_smg_mp7.mdl");
	else if (StrEqual(dummy_classname, "weapon_mp9", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_smg_mp9.mdl");
	else if (StrEqual(dummy_classname, "weapon_negev", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_mach_negev.mdl");
	else if (StrEqual(dummy_classname, "weapon_nova", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_shot_nova.mdl");
	else if (StrEqual(dummy_classname, "weapon_bizon", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_smg_bizon.mdl");
	else if (StrEqual(dummy_classname, "weapon_p90", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_smg_p90.mdl");
	else if (StrEqual(dummy_classname, "weapon_sawedoff", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_shot_sawedoff.mdl");
	else if (StrEqual(dummy_classname, "weapon_scar20", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_snip_scar20.mdl");
	else if (StrEqual(dummy_classname, "weapon_sg556", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_rif_sg556.mdl");
	else if (StrEqual(dummy_classname, "weapon_smokegrenade", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_eq_smokegrenade.mdl");
	else if (StrEqual(dummy_classname, "weapon_ssg08", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_snip_ssg08.mdl");
	else if (StrEqual(dummy_classname, "weapon_ump45", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_smg_ump45.mdl");
	else if (StrEqual(dummy_classname, "weapon_xm1014", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_shot_xm1014.mdl");
	else if (StrEqual(dummy_classname, "weapon_awp", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_snip_awp.mdl");
	else if (StrEqual(dummy_classname, "weapon_taser", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_eq_taser.mdl");
	else if (StrEqual(dummy_classname, "weapon_hegrenade", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_eq_fraggrenade.mdl");
	else if (StrEqual(dummy_classname, "weapon_decoy", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_eq_decoy.mdl");
	else if (StrEqual(dummy_classname, "weapon_flashbang", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_eq_flashbang.mdl");
	else if (StrEqual(dummy_classname, "weapon_incgrenade", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_eq_incendiarygrenade.mdl");
	else if (StrEqual(dummy_classname, "weapon_molotov", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_eq_molotov.mdl");
	else if (StrEqual(dummy_classname, "weapon_knife", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_knife_default_ct.mdl");
	else if (StrEqual(dummy_classname, "weapon_healthshot", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_eq_healthshot.mdl");
	else if (StrEqual(dummy_classname, "weapon_tagrenade", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_eq_sensorgrenade.mdl");
	else if (StrEqual(dummy_classname, "weapon_c4", false))
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_c4_planted.mdl");
	else
	FormatEx(dummy_modelname, sizeof(dummy_modelname), "models/weapons/w_pist_elite.mdl");

	return dummy_modelname;
}
//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (G_bConfigLoaded && !G_bRoundTransition)
	{
		new client = GetClientOfUserId(GetEventInt(event, "userid"));
		ResetStatus(client);
		TagCheck(client);
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action:Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	ResetStatus(client);
	if (G_bConfigLoaded && !G_bRoundTransition)
	{
		for (new index = 0; index < entArraySize; index++)
		{
			if (entArray[index][ent_ownerid] != -1 && entArray[index][ent_ownerid] == client)
			{
				entArray[index][ent_ownerid] = -1;

				if (entArray[index][ent_forcedrop] && IsValidEdict(entArray[index][ent_weaponid]))
				{
					char sClsName[64];
					GetEntityClassname(entArray[index][ent_weaponid], sClsName, sizeof(sClsName));
					if(StrContains(sClsName, "weapon_", false) != -1)
					{
						bool isOwner = false;
						for (new slot = 0; slot < 5; slot++)
						{
							int weapon = GetPlayerWeaponSlot(client, slot);
							if(weapon == entArray[index][ent_weaponid])
							{
								isOwner = true;
								break;
							}
						}
						if(isOwner)
						{
							SDKHooks_DropWeapon(client, entArray[index][ent_weaponid]);
							SpawnDummyModel(index);
						}
					}
				}

				if (entArray[index][ent_chat])
				{
					new String:buffer_steamid[32];
					//GetClientAuthString(client, buffer_steamid, sizeof(buffer_steamid));
					GetClientAuthId(client, AuthId_Steam2, buffer_steamid, sizeof(buffer_steamid), false);
					ReplaceString(buffer_steamid, sizeof(buffer_steamid), "STEAM_", "", true);

					for (new ply = 1; ply <= MaxClients; ply++)
					{
						if (IsClientConnected(ply) && IsClientInGame(ply))
						{
							if (!GetConVarBool(G_hCvar_ModeTeamOnly) || (GetConVarBool(G_hCvar_ModeTeamOnly) && GetClientTeam(ply) == GetClientTeam(client) || !IsPlayerAlive(ply) || CheckCommandAccess(ply, "entWatch_chat", ADMFLAG_CHAT)))
							{
								CPrintToChat(ply, "\x07%s[entWatch] \x07%s%N \x07%s(\x07%s%s\x07%s) \x07%s%t \x07%s%s", color_tag, color_name, client, color_death, color_steamid, buffer_steamid, color_death, color_death, "death", entArray[index][ent_color], entArray[index][ent_name]);
							}
						}
					}
				}
			}
		}
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action:OnWeaponEquip(client, weapon)
{
	if (G_bConfigLoaded && !G_bRoundTransition && IsValidEdict(weapon))
	{
		for (new index = 0; index < entArraySize; index++)
		{
			if (entArray[index][ent_hammerid] == Entity_GetHammerID(weapon))
			{
				if (entArray[index][ent_weaponid] != -1 && entArray[index][ent_weaponid] == weapon)
				{
					entArray[index][ent_ownerid] = client;

					if (entArray[index][ent_chat])
					{
						new String:buffer_steamid[32];
						//GetClientAuthString(client, buffer_steamid, sizeof(buffer_steamid));
						GetClientAuthId(client, AuthId_Steam2, buffer_steamid, sizeof(buffer_steamid), false);
						ReplaceString(buffer_steamid, sizeof(buffer_steamid), "STEAM_", "", true);

						if(IsValidEntity(entArray[index][ent_dummy_weapon]))
						{
							AcceptEntityInput(entArray[index][ent_dummy_weapon], "Kill");
						}

						for (new ply = 1; ply <= MaxClients; ply++)
						{
							if (IsClientConnected(ply) && IsClientInGame(ply))
							{
								if (!GetConVarBool(G_hCvar_ModeTeamOnly) || (GetConVarBool(G_hCvar_ModeTeamOnly) && GetClientTeam(ply) == GetClientTeam(client) || !IsPlayerAlive(ply) || CheckCommandAccess(ply, "entWatch_chat", ADMFLAG_CHAT)))
								{
									CPrintToChat(ply, "\x07%s[entWatch] \x07%s%N \x07%s(\x07%s%s\x07%s) \x07%s%t \x07%s%s", color_tag, color_name, client, color_pickup, color_steamid, buffer_steamid, color_pickup, color_pickup, "pickup", entArray[index][ent_color], entArray[index][ent_name]);
								}
							}
						}
					}

					break;
				}
			}
		}
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action:OnWeaponDrop(client, weapon)
{
	if (G_bConfigLoaded && !G_bRoundTransition && IsValidEdict(weapon))
	{
		for (new index = 0; index < entArraySize; index++)
		{
			if (entArray[index][ent_hammerid] == Entity_GetHammerID(weapon))
			{
				if (entArray[index][ent_weaponid] != -1 && entArray[index][ent_weaponid] == weapon)
				{
					entArray[index][ent_ownerid] = -1;

					if (entArray[index][ent_chat])
					{
						new String:buffer_steamid[32];
						//GetClientAuthString(client, buffer_steamid, sizeof(buffer_steamid));
						GetClientAuthId(client, AuthId_Steam2, buffer_steamid, sizeof(buffer_steamid), false);
						ReplaceString(buffer_steamid, sizeof(buffer_steamid), "STEAM_", "", true);

						ResetStatus(client);
						SpawnDummyModel(index);

						for (new ply = 1; ply <= MaxClients; ply++)
						{
							if (IsClientConnected(ply) && IsClientInGame(ply))
							{
								if (!GetConVarBool(G_hCvar_ModeTeamOnly) || (GetConVarBool(G_hCvar_ModeTeamOnly) && GetClientTeam(ply) == GetClientTeam(client) || !IsPlayerAlive(ply) || CheckCommandAccess(ply, "entWatch_chat", ADMFLAG_CHAT)))
								{
									CPrintToChat(ply, "\x07%s[entWatch] \x07%s%N \x07%s(\x07%s%s\x07%s) \x07%s%t \x07%s%s", color_tag, color_name, client, color_drop, color_steamid, buffer_steamid, color_drop, color_drop, "drop", entArray[index][ent_color], entArray[index][ent_name]);
								}
							}
						}
					}

					break;
				}
			}
		}
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action:OnWeaponCanUse(client, weapon)
{
	if (G_bConfigLoaded && !G_bRoundTransition && IsValidEdict(weapon))
	{
		for (new index = 0; index < entArraySize; index++)
		{
			if (entArray[index][ent_hammerid] == Entity_GetHammerID(weapon))
			{
				if (entArray[index][ent_weaponid] == -1)
				{
					entArray[index][ent_weaponid] = weapon;

					if (entArray[index][ent_buttonid] == -1 && entArray[index][ent_mode] != 0)
					{
						new String:buffer_targetname[32];
						Entity_GetTargetName(weapon, buffer_targetname, sizeof(buffer_targetname));

						new button = -1;
						while ((button = FindEntityByClassname(button, entArray[index][ent_buttonclass])) != -1)
						{
							if (IsValidEdict(button))
							{
								new String:buffer_parentname[32];
								Entity_GetParentName(button, buffer_parentname, sizeof(buffer_parentname));

								if (StrEqual(buffer_targetname, buffer_parentname))
								{
									SDKHook(button, SDKHook_Use, OnButtonUse);
									entArray[index][ent_buttonid] = button;
									break;
								}
							}
						}
					}
				}

				if (entArray[index][ent_weaponid] == weapon)
				{
					if (entArray[index][ent_blockpickup])
						return Plugin_Handled;

					if (G_bRestricted[client])
						return Plugin_Handled;

					return Plugin_Continue;
				}
			}
		}
	}

	return Plugin_Continue;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action:OnButtonUse(button, activator, caller, UseType:type, Float:value)
{
	if (G_bConfigLoaded && !G_bRoundTransition && IsValidEdict(button))
	{
		for (new index = 0; index < entArraySize; index++)
		{
			if (entArray[index][ent_buttonid] != -1 && entArray[index][ent_buttonid] == button)
			{
				if (entArray[index][ent_ownerid] != activator && entArray[index][ent_ownerid] != caller)
					return Plugin_Handled;

				if (entArray[index][ent_hasfiltername])
					DispatchKeyValue(activator, "targetname", entArray[index][ent_filtername]);

				new String:buffer_steamid[32];
				//GetClientAuthString(activator, buffer_steamid, sizeof(buffer_steamid));
				GetClientAuthId(activator, AuthId_Steam2, buffer_steamid, sizeof(buffer_steamid), false);
				ReplaceString(buffer_steamid, sizeof(buffer_steamid), "STEAM_", "", true);

				if (entArray[index][ent_mode] == 1)
				{
					return Plugin_Changed;
				}
				else if (entArray[index][ent_mode] == 2 && entArray[index][ent_cooldowntime] <= -1)
				{
					for (new ply = 1; ply <= MaxClients; ply++)
					{
						if (IsClientConnected(ply) && IsClientInGame(ply))
						{
							if (!GetConVarBool(G_hCvar_ModeTeamOnly) || (GetConVarBool(G_hCvar_ModeTeamOnly) && GetClientTeam(ply) == GetClientTeam(activator) || !IsPlayerAlive(ply) || CheckCommandAccess(ply, "entWatch_chat", ADMFLAG_CHAT)))
							{
								CPrintToChat(ply, "\x07%s[entWatch] \x07%s%N \x07%s(\x07%s%s\x07%s) \x07%s%t \x07%s%s", color_tag, color_name, activator, color_use, color_steamid, buffer_steamid, color_use, color_use, "use", entArray[index][ent_color], entArray[index][ent_name]);
							}
						}
					}

					entArray[index][ent_cooldowntime] = entArray[index][ent_cooldown];
					return Plugin_Changed;
				}
				else if (entArray[index][ent_mode] == 3 && entArray[index][ent_uses] < entArray[index][ent_maxuses])
				{
					for (new ply = 1; ply <= MaxClients; ply++)
					{
						if (IsClientConnected(ply) && IsClientInGame(ply))
						{
							if (!GetConVarBool(G_hCvar_ModeTeamOnly) || (GetConVarBool(G_hCvar_ModeTeamOnly) && GetClientTeam(ply) == GetClientTeam(activator) || !IsPlayerAlive(ply) || CheckCommandAccess(ply, "entWatch_chat", ADMFLAG_CHAT)))
							{
								CPrintToChat(ply, "\x07%s[entWatch] \x07%s%N \x07%s(\x07%s%s\x07%s) \x07%s%t \x07%s%s", color_tag, color_name, activator, color_use, color_steamid, buffer_steamid, color_use, color_use, "use", entArray[index][ent_color], entArray[index][ent_name]);
							}
						}
					}

					entArray[index][ent_uses]++;
					return Plugin_Changed;
				}
				else if (entArray[index][ent_mode] == 4 && entArray[index][ent_uses] < entArray[index][ent_maxuses] && entArray[index][ent_cooldowntime] <= -1)
				{
					for (new ply = 1; ply <= MaxClients; ply++)
					{
						if (IsClientConnected(ply) && IsClientInGame(ply))
						{
							if (!GetConVarBool(G_hCvar_ModeTeamOnly) || (GetConVarBool(G_hCvar_ModeTeamOnly) && GetClientTeam(ply) == GetClientTeam(activator) || !IsPlayerAlive(ply) || CheckCommandAccess(ply, "entWatch_chat", ADMFLAG_CHAT)))
							{
								CPrintToChat(ply, "\x07%s[entWatch] \x07%s%N \x07%s(\x07%s%s\x07%s) \x07%s%t \x07%s%s", color_tag, color_name, activator, color_use, color_steamid, buffer_steamid, color_use, color_use, "use", entArray[index][ent_color], entArray[index][ent_name]);
							}
						}
					}

					entArray[index][ent_cooldowntime] = entArray[index][ent_cooldown];
					entArray[index][ent_uses]++;
					return Plugin_Changed;
				}
				else if (entArray[index][ent_mode] == 5 && entArray[index][ent_cooldowntime] <= -1)
				{
					for (new ply = 1; ply <= MaxClients; ply++)
					{
						if (IsClientConnected(ply) && IsClientInGame(ply))
						{
							if (!GetConVarBool(G_hCvar_ModeTeamOnly) || (GetConVarBool(G_hCvar_ModeTeamOnly) && GetClientTeam(ply) == GetClientTeam(activator) || !IsPlayerAlive(ply) || CheckCommandAccess(ply, "entWatch_chat", ADMFLAG_CHAT)))
							{
								CPrintToChat(ply, "\x07%s[entWatch] \x07%s%N \x07%s(\x07%s%s\x07%s) \x07%s%t \x07%s%s", color_tag, color_name, activator, color_use, color_steamid, buffer_steamid, color_use, color_use, "use", entArray[index][ent_color], entArray[index][ent_name]);
							}
						}
					}

					entArray[index][ent_uses]++;
					if (entArray[index][ent_uses] >= entArray[index][ent_maxuses])
					{
						entArray[index][ent_cooldowntime] = entArray[index][ent_cooldown];
						entArray[index][ent_uses] = 0;
					}

					return Plugin_Changed;
				}

				return Plugin_Handled;
			}
		}
	}

	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action:Timer_DisplayHUD(Handle:timer)
{
	if (GetConVarBool(G_hCvar_DisplayEnabled))
	{
		if (G_bConfigLoaded && !G_bRoundTransition)
		{
			new String:buffer_teamtext[5][250];
			new String:buffer_teamtext2[5][250];

			for (new index = 0; index < entArraySize; index++)
			{
				if (entArray[index][ent_hud] && entArray[index][ent_ownerid] != -1)
				{
					char buffer_temp[128], buffer_clan[128], buffer_hud2[128];

					if (GetConVarBool(G_hCvar_DisplayCooldowns))
					{
						if (entArray[index][ent_mode] == 2)
						{
							if (entArray[index][ent_cooldowntime] > 0)
							{
								Format(buffer_temp, sizeof(buffer_temp), "%s[%d]: %N", entArray[index][ent_shortname], entArray[index][ent_cooldowntime], entArray[index][ent_ownerid]);
								Format(buffer_clan, sizeof(buffer_clan), "[%d]%s:", entArray[index][ent_cooldowntime], entArray[index][ent_shortname]);
								Format(buffer_hud2, sizeof(buffer_hud2), "%s[%d]: %N", entArray[index][ent_shortname], entArray[index][ent_cooldowntime], entArray[index][ent_ownerid]);
							}
							else
							{
								Format(buffer_temp, sizeof(buffer_temp), "%s[%s]: %N", entArray[index][ent_shortname], "R", entArray[index][ent_ownerid]);
								Format(buffer_hud2, sizeof(buffer_hud2), "%s[%s]: %N", entArray[index][ent_shortname], "R", entArray[index][ent_ownerid]);
								Format(buffer_clan, sizeof(buffer_clan), "[%s]%s:", "R", entArray[index][ent_shortname]);
							}
						}
						else if (entArray[index][ent_mode] == 3)
						{
							if (entArray[index][ent_uses] < entArray[index][ent_maxuses])
							{
								Format(buffer_temp, sizeof(buffer_temp), "%s[%d/%d]: %N", entArray[index][ent_shortname], entArray[index][ent_uses], entArray[index][ent_maxuses], entArray[index][ent_ownerid]);
								Format(buffer_hud2, sizeof(buffer_hud2), "%s[%d/%d]: %N", entArray[index][ent_shortname], entArray[index][ent_uses], entArray[index][ent_maxuses], entArray[index][ent_ownerid]);
								Format(buffer_clan, sizeof(buffer_clan), "[%d/%d]%s:", entArray[index][ent_uses], entArray[index][ent_maxuses], entArray[index][ent_shortname]);
							}
							else
							{
								Format(buffer_temp, sizeof(buffer_temp), "%s[%s]: %N", entArray[index][ent_shortname], "D", entArray[index][ent_ownerid]);
								Format(buffer_hud2, sizeof(buffer_hud2), "%s[%s]: %N", entArray[index][ent_shortname], "D", entArray[index][ent_ownerid]);
								Format(buffer_clan, sizeof(buffer_clan), "[%s]%s:", "D", entArray[index][ent_shortname]);
							}
						}
						else if (entArray[index][ent_mode] == 4)
						{
							if (entArray[index][ent_cooldowntime] > 0)
							{
								Format(buffer_temp, sizeof(buffer_temp), "%s[%d]: %N", entArray[index][ent_shortname], entArray[index][ent_cooldowntime], entArray[index][ent_ownerid]);
								Format(buffer_hud2, sizeof(buffer_hud2), "%s[%d]: %N", entArray[index][ent_shortname], entArray[index][ent_cooldowntime], entArray[index][ent_ownerid]);
								Format(buffer_clan, sizeof(buffer_clan), "[%d]%s:", entArray[index][ent_cooldowntime], entArray[index][ent_shortname]);
							}
							else
							{
								if (entArray[index][ent_uses] < entArray[index][ent_maxuses])
								{
									Format(buffer_temp, sizeof(buffer_temp), "%s[%d/%d]: %N", entArray[index][ent_shortname], entArray[index][ent_uses], entArray[index][ent_maxuses], entArray[index][ent_ownerid]);
									Format(buffer_hud2, sizeof(buffer_hud2), "%s[%d/%d]: %N", entArray[index][ent_shortname], entArray[index][ent_uses], entArray[index][ent_maxuses], entArray[index][ent_ownerid]);
									Format(buffer_clan, sizeof(buffer_clan), "[%d/%d]%s:", entArray[index][ent_uses], entArray[index][ent_maxuses], entArray[index][ent_shortname]);
								}
								else
								{
									Format(buffer_temp, sizeof(buffer_temp), "%s[%s]: %N", entArray[index][ent_shortname], "D", entArray[index][ent_ownerid]);
									Format(buffer_hud2, sizeof(buffer_temp), "%s[%s]: %N", entArray[index][ent_shortname], "D", entArray[index][ent_ownerid]);
									Format(buffer_clan, sizeof(buffer_clan), "[%s]%s:", "D", entArray[index][ent_shortname]);
								}
							}
						}
						else if (entArray[index][ent_mode] == 5)
						{
							if (entArray[index][ent_cooldowntime] > 0)
							{
								Format(buffer_temp, sizeof(buffer_temp), "%s[%d]: %N", entArray[index][ent_shortname], entArray[index][ent_cooldowntime], entArray[index][ent_ownerid]);
								Format(buffer_hud2, sizeof(buffer_temp), "%s[%d]: %N", entArray[index][ent_shortname], entArray[index][ent_cooldowntime], entArray[index][ent_ownerid]);
								Format(buffer_clan, sizeof(buffer_clan), "[%d]%s:", entArray[index][ent_cooldowntime], entArray[index][ent_shortname]);
							}
							else
							{
								Format(buffer_temp, sizeof(buffer_temp), "%s[%d/%d]: %N", entArray[index][ent_shortname], entArray[index][ent_uses], entArray[index][ent_maxuses], entArray[index][ent_ownerid]);
								Format(buffer_hud2, sizeof(buffer_temp), "%s[%d/%d]: %N", entArray[index][ent_shortname], entArray[index][ent_uses], entArray[index][ent_maxuses], entArray[index][ent_ownerid]);
								Format(buffer_clan, sizeof(buffer_clan), "[%d/%d]%s:", entArray[index][ent_uses], entArray[index][ent_maxuses], entArray[index][ent_shortname]);
							}
						}
						else
						{
							Format(buffer_temp, sizeof(buffer_temp), "%s[%s]: %N", entArray[index][ent_shortname], "N/A", entArray[index][ent_ownerid]);
							Format(buffer_hud2, sizeof(buffer_temp), "%s[%s]: %N", entArray[index][ent_shortname], "N/A", entArray[index][ent_ownerid]);
							Format(buffer_clan, sizeof(buffer_clan), "[%s]%s:", "N/A", entArray[index][ent_shortname]);
						}
					}
					else
					{
						Format(buffer_temp, sizeof(buffer_temp), "%s: %N", entArray[index][ent_shortname], entArray[index][ent_ownerid]);
						Format(buffer_hud2, sizeof(buffer_temp), "%s: %N", entArray[index][ent_shortname], entArray[index][ent_ownerid]);
						Format(buffer_clan, sizeof(buffer_clan), "%s:", entArray[index][ent_shortname]);
					}

					if (strlen(buffer_temp) + strlen(buffer_teamtext[GetClientTeam(entArray[index][ent_ownerid])]) <= sizeof(buffer_teamtext[]))
					{
						FormatEx(buffer_temp, sizeof(buffer_temp), "%s | ", buffer_temp);
						StrCat(buffer_teamtext[GetClientTeam(entArray[index][ent_ownerid])], sizeof(buffer_teamtext[]), buffer_temp);
					}
					if (strlen(buffer_hud2) + strlen(buffer_teamtext2[GetClientTeam(entArray[index][ent_ownerid])]) <= sizeof(buffer_teamtext2[]))
					{
						FormatEx(buffer_hud2, sizeof(buffer_hud2), "%s\n", buffer_hud2)
						StrCat(buffer_teamtext2[GetClientTeam(entArray[index][ent_ownerid])], sizeof(buffer_teamtext2[]), buffer_hud2);
					}
					if(strlen(buffer_clan) != 0)
					{
						CS_SetClientContributionScore(entArray[index][ent_ownerid], 9999);
						CS_SetClientClanTag(entArray[index][ent_ownerid], buffer_clan);
					}
				}
			}

			for (new ply = 1; ply <= MaxClients; ply++)
			{
				if (IsClientConnected(ply) && IsClientInGame(ply))
				{
					if (G_bDisplay[ply])
					{
						new String:buffer_text[250];

						for (new teamid = 0; teamid < sizeof(buffer_teamtext); teamid++)
						{
							if (!GetConVarBool(G_hCvar_ModeTeamOnly) || (GetConVarBool(G_hCvar_ModeTeamOnly) && GetClientTeam(ply) == teamid || !IsPlayerAlive(ply) || CheckCommandAccess(ply, "entWatch_chat", ADMFLAG_CHAT)))
							{
								if (strlen(buffer_teamtext[teamid]) + strlen(buffer_text) <= sizeof(buffer_text))
								{
									StrCat(buffer_text, sizeof(buffer_text), buffer_teamtext[teamid]);
								}
							}
						}

						new String:buffer_text2[250];

						for (new teamid = 0; teamid < sizeof(buffer_teamtext2); teamid++)
						{
							if (!GetConVarBool(G_hCvar_ModeTeamOnly) || (GetConVarBool(G_hCvar_ModeTeamOnly) && GetClientTeam(ply) == teamid || !IsPlayerAlive(ply) || CheckCommandAccess(ply, "entWatch_chat", ADMFLAG_CHAT)))
							{
								if (strlen(buffer_teamtext2[teamid]) + strlen(buffer_text2) <= sizeof(buffer_text2))
								{
									StrCat(buffer_text2, sizeof(buffer_text2), buffer_teamtext2[teamid]);
								}
							}
						}

						SendHudMsg(ply, buffer_text2);

						if(strlen(buffer_text) != 0)
						{
							char buffer_output[254];
							FormatEx(buffer_output, sizeof(buffer_output), "<font size='13' color='#0066FF'>%s</font>", buffer_text);

							Handle hBuffer = StartMessageOne("KeyHintText", ply);
							if (hBuffer != INVALID_HANDLE) {
								PbAddString(hBuffer, "hints", buffer_output);
							}
							EndMessage();
						}
					}
				}
			}
		}
	}
}

public void SendHudMsg(int client, char[] szMessage)
{
	SetHudTextParams(0.01, 0.35, 1.0, 255, 255, 255, 255, 0, 0.0, 0.0, 0.0);
	ShowSyncHudText(client, HudSync, szMessage);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action:Timer_Cooldowns(Handle:timer)
{
	if (G_bConfigLoaded && !G_bRoundTransition)
	{
		for (new index = 0; index < entArraySize; index++)
		{
			if (entArray[index][ent_cooldowntime] >= 0)
			{
				entArray[index][ent_cooldowntime]--;
			}
		}
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action:Command_ToggleHUD(client, args)
{
	if (AreClientCookiesCached(client))
	{
		if (G_bDisplay[client])
		{
			CReplyToCommand(client, "\x07%s[entWatch] \x07%s%t", color_tag, color_warning, "display disabled");
			SetClientCookie(client, G_hCookie_Display, "0");
			G_bDisplay[client] = false;
		}
		else
		{
			CReplyToCommand(client, "\x07%s[entWatch] \x07%s%t", color_tag, color_warning, "display enabled");
			SetClientCookie(client, G_hCookie_Display, "1");
			G_bDisplay[client] = true;
		}
	}
	else
	{
		CReplyToCommand(client, "\x07%s[entWatch] \x07%s%t", color_tag, color_warning, "cookies loading");
	}

	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action:Command_Status(client, args)
{
	if (AreClientCookiesCached(client))
	{
		if (G_bRestricted[client])
		{
			CReplyToCommand(client, "\x07%s[entWatch] \x07%s%t", color_tag, color_warning, "status restricted");
		}
		else
		{
			CReplyToCommand(client, "\x07%s[entWatch] \x07%s%t", color_tag, color_warning, "status unrestricted");
		}
	}
	else
	{
		CReplyToCommand(client, "\x07%s[entWatch] \x07%s%t", color_tag, color_warning, "cookies loading");
	}

	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action:Command_Restrict(client, args)
{
	if (GetCmdArgs() < 1)
	{
		CReplyToCommand(client, "\x07%s[entWatch] \x07%sUsage: sm_eban <target>", color_tag, color_warning);
		return Plugin_Handled;
	}

	new String:target_argument[64];
	GetCmdArg(1, target_argument, sizeof(target_argument));

	new target = -1;
	if ((target = FindTarget(client, target_argument, true)) == -1)
		return Plugin_Handled;

	G_bRestricted[target] = true;
	SetClientCookie(target, G_hCookie_Restricted, "1");

	CPrintToChatAll("\x07%s[entWatch] \x07%s%N \x07%srestricted \x07%s%N", color_tag, color_name, client, color_warning, color_name, target);
	LogAction(client, -1, "%L restricted %L", client, target);

	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action:Command_Unrestrict(client, args)
{
	if (GetCmdArgs() < 1)
	{
		CReplyToCommand(client, "\x07%s[entWatch] \x07%sUsage: sm_eunban <target>", color_tag, color_warning);
		return Plugin_Handled;
	}

	new String:target_argument[64];
	GetCmdArg(1, target_argument, sizeof(target_argument));

	new target = -1;
	if ((target = FindTarget(client, target_argument, true)) == -1)
		return Plugin_Handled;

	G_bRestricted[target] = false;
	SetClientCookie(target, G_hCookie_Restricted, "0");

	CPrintToChatAll("\x07%s[entWatch] \x07%s%N \x07%sunrestricted \x07%s%N", color_tag, color_name, client, color_warning, color_name, target);
	LogAction(client, -1, "%L unrestricted %L", client, target);

	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action:Command_Transfer(client, args)
{
	if (GetCmdArgs() < 2)
	{
		CReplyToCommand(client, "\x07%s[entWatch] \x07%sUsage: sm_etransfer <owner> <receiver>", color_tag, color_warning);

		return Plugin_Handled;
	}

	new bool:bFoundWeapon = false;
	new iEntityIndex = -1
	new iWeaponCount = 0;
	new target = -1;
	new receiver = -1;

	new String:target_argument[64];
	GetCmdArg(1, target_argument, sizeof(target_argument));

	new String:receiver_argument[64];
	GetCmdArg(2, receiver_argument, sizeof(receiver_argument));

	if ((receiver = FindTarget(client, receiver_argument, false)) == -1)
	return Plugin_Handled;

	if (G_bConfigLoaded && !G_bRoundTransition)
	{
		if (target_argument[0] == '$')
		{
			strcopy(target_argument, sizeof(target_argument), target_argument[1]);

			for (new i = 0; i < entArraySize; i++)
			{
				if (StrEqual(target_argument, entArray[i][ent_name], false) || StrEqual(target_argument, entArray[i][ent_shortname], false))
				{
					iWeaponCount++;
					bFoundWeapon = true;
					iEntityIndex = i;
				}
			}
		}
		else
		{
			target = FindTarget(client, target_argument, false)

			if (target != -1)
			{
				if (GetClientTeam(target) != GetClientTeam(receiver))
				{
					CPrintToChat(client, "\x07%s[entWatch] \x07%sThe receivers team differs from the targets team.", color_tag, color_warning);
					return Plugin_Handled;
				}

				for (new index = 0; index < entArraySize; index++)
				{
					if (entArray[index][ent_ownerid] != -1)
					{
						if (entArray[index][ent_ownerid] == target)
						{
							if (entArray[index][ent_allowtransfer])
							{
								if (IsValidEdict(entArray[index][ent_weaponid]))
								{
									new String:buffer_classname[64];
									GetEdictClassname(entArray[index][ent_weaponid], buffer_classname, sizeof(buffer_classname));

									CS_DropWeapon(target, entArray[index][ent_weaponid], false);
									GivePlayerItem(target, buffer_classname);
									ResetStatus(target);

									if (entArray[index][ent_chat])
									{
										entArray[index][ent_chat] = false;
										EquipPlayerWeapon(receiver, entArray[index][ent_weaponid]);
										CS_SetClientContributionScore(receiver, 9999);
										entArray[index][ent_chat] = true;
									}
									else
									{
										EquipPlayerWeapon(receiver, entArray[index][ent_weaponid]);
										CS_SetClientContributionScore(receiver, 9999);
									}

									if(IsValidEntity(entArray[index][ent_dummy_weapon]))
									{
										AcceptEntityInput(entArray[index][ent_dummy_weapon], "Kill");
									}

									CPrintToChatAll("\x07%s[entWatch] \x07%s%N \x07%stransferred all items from \x07%s%N \x07%sto \x07%s%N. Make sure to drop and pick up your powerup to enable it.", color_tag, color_name, client, color_warning, color_name, target, color_warning, color_name, receiver);

									LogAction(client, target, "\"%L\" transfered all items from \"%L\" to \"%L\"", client, target, receiver);

									return Plugin_Handled;
								}
							}
						}
					}
				}
			}
			else
			{
				return Plugin_Handled;
			}
		}
	}

	if (iWeaponCount > 1)
	{
		new Handle:hEdictMenu = CreateMenu(EdictMenu_Handler);
		new String:sMenuTemp[64];
		new String:sIndexTemp[16];
		new iHeldCount = 0;
		SetMenuTitle(hEdictMenu, "[entWatch] Edict targets:");

		for (new i = 0; i < entArraySize; i++)
		{
			if (StrEqual(target_argument, entArray[i][ent_name], false) || StrEqual(target_argument, entArray[i][ent_shortname], false))
			{
				if (entArray[i][ent_allowtransfer])
				{
					if (entArray[i][ent_ownerid] != -1)
					{
						IntToString(i, sIndexTemp, sizeof(sIndexTemp));
						Format(sMenuTemp, sizeof(sMenuTemp), "%s | %N (#%i)", entArray[i][ent_name], entArray[i][ent_ownerid], GetClientUserId(entArray[i][ent_ownerid]));
						AddMenuItem(hEdictMenu, sIndexTemp, sMenuTemp, ITEMDRAW_DEFAULT);
						iHeldCount++;
					}
					/*else //not a good idea
					{
						IntToString(i, sIndexTemp, sizeof(sIndexTemp));
						Format(sMenuTemp, sizeof(sMenuTemp), "%s", entArray[i][ent_name]);
						AddMenuItem(hEdictMenu, sIndexTemp, sMenuTemp, ITEMDRAW_DEFAULT);
					}*/
				}
			}
		}

		if (iHeldCount == 1)
		{
			iEntityIndex = StringToInt(sIndexTemp);

			if (entArray[iEntityIndex][ent_allowtransfer])
			{
				if (entArray[iEntityIndex][ent_ownerid] != -1)
				{
					if (IsValidEdict(entArray[iEntityIndex][ent_weaponid]))
					{
						new iCurOwner = entArray[iEntityIndex][ent_ownerid];

						if (GetClientTeam(receiver) != GetClientTeam(iCurOwner))
						{
							CPrintToChat(client, "\x07%s[entWatch] \x07%sThe receivers team differs from the targets team.", color_tag, color_warning);
							CloseHandle(hEdictMenu);
							return Plugin_Handled;
						}

						new String:buffer_classname[64];
						GetEdictClassname(entArray[iEntityIndex][ent_weaponid], buffer_classname, sizeof(buffer_classname))

						CS_DropWeapon(iCurOwner, entArray[iEntityIndex][ent_weaponid], false);
						GivePlayerItem(iCurOwner, buffer_classname);
						ResetStatus(iCurOwner);

						if (entArray[iEntityIndex][ent_chat])
						{
							entArray[iEntityIndex][ent_chat] = false;
							EquipPlayerWeapon(receiver, entArray[iEntityIndex][ent_weaponid]);
							CS_SetClientContributionScore(receiver, 9999);
							entArray[iEntityIndex][ent_chat] = true;
						}
						else
						{
							EquipPlayerWeapon(receiver, entArray[iEntityIndex][ent_weaponid]);
							CS_SetClientContributionScore(receiver, 9999);
						}

						if(IsValidEntity(entArray[iEntityIndex][ent_dummy_weapon]))
						{
							AcceptEntityInput(entArray[iEntityIndex][ent_dummy_weapon], "Kill");
						}
						CPrintToChatAll("\x07%s[entWatch] \x07%s%N \x07%stransferred all items from \x07%s%N \x07%sto \x07%s%N. Make sure to drop and pick your powerup to enable it.", color_tag, color_name, client, color_warning, color_name, target, color_warning, color_name, receiver);

						LogAction(client, iCurOwner, "\"%L\" transfered all items from \"%L\" to \"%L\"", client, iCurOwner, receiver);
					}
				}
				else
				{
					CPrintToChat(client, "\x07%s[entWatch] \x07%sTarget is not valid.", color_tag, color_warning);
				}
			}

			CloseHandle(hEdictMenu);
		}
		else if (iHeldCount >= 2)
		{
			g_iAdminMenuTarget[client] = receiver;
			DisplayMenu(hEdictMenu, client, MENU_TIME_FOREVER);
		}
		else
		{
			CPrintToChat(client, "\x07%s[entWatch] \x07%sNo one is currently holding that item.", color_tag, color_warning);
			CloseHandle(hEdictMenu);
		}
	}
	else
	{
		if (entArray[iEntityIndex][ent_allowtransfer])
		{
			if (entArray[iEntityIndex][ent_ownerid] != -1)
			{
				if (IsValidEdict(entArray[iEntityIndex][ent_weaponid]))
				{
					new iCurOwner = entArray[iEntityIndex][ent_ownerid];

					new String:buffer_classname[64];
					GetEdictClassname(entArray[iEntityIndex][ent_weaponid], buffer_classname, sizeof(buffer_classname))

					CS_DropWeapon(iCurOwner, entArray[iEntityIndex][ent_weaponid], false);
					GivePlayerItem(iCurOwner, buffer_classname);
					ResetStatus(iCurOwner);

					if (entArray[iEntityIndex][ent_chat])
					{
						entArray[iEntityIndex][ent_chat] = false;
						EquipPlayerWeapon(receiver, entArray[iEntityIndex][ent_weaponid]);
						CS_SetClientContributionScore(receiver, 9999);
						entArray[iEntityIndex][ent_chat] = true;
					}
					else
					{
						EquipPlayerWeapon(receiver, entArray[iEntityIndex][ent_weaponid]);
						CS_SetClientContributionScore(receiver, 9999);
					}

					bFoundWeapon = true;

					if(IsValidEntity(entArray[iEntityIndex][ent_dummy_weapon]))
					{
						AcceptEntityInput(entArray[iEntityIndex][ent_dummy_weapon], "Kill");
					}
					CPrintToChatAll("\x07%s[entWatch] \x07%s%N \x07%stransferred all items from \x07%s%N \x07%sto \x07%s%N. Make sure to drop and pick up your powerup to enable it.", color_tag, color_name, client, color_warning, color_name, target, color_warning, color_name, receiver);

					LogAction(client, iCurOwner, "\"%L\" transfered all items from \"%L\" to \"%L\"", client, iCurOwner, receiver);
				}
			}
			else
			{
				new entity = Entity_GetEntityFromHammerID(entArray[iEntityIndex][ent_hammerid]);

				if (entArray[iEntityIndex][ent_chat])
				{
					entArray[iEntityIndex][ent_chat] = false;
					EquipPlayerWeapon(receiver, entity);
					//CS_DropWeapon(receiver, entity, false);
					//EquipPlayerWeapon(receiver, entity);
					CS_SetClientContributionScore(receiver, 9999);
					entArray[iEntityIndex][ent_chat] = true;
				}
				else
				{
					EquipPlayerWeapon(receiver, entity);
					//CS_DropWeapon(receiver, entity, false);
					//EquipPlayerWeapon(receiver, entity);
					CS_SetClientContributionScore(receiver, 9999);
				}

				bFoundWeapon = true;

				if(IsValidEntity(entArray[iEntityIndex][ent_dummy_weapon]))
				{
					AcceptEntityInput(entArray[iEntityIndex][ent_dummy_weapon], "Kill");
				}
				CPrintToChatAll("\x07%s[entWatch] \x07%s%N \x07%stransfered \x07%s%s \x07%sto \x07%s%N. Make sure to drop and pick up your powerup to enable it.", color_tag, color_name, client, color_warning, entArray[iEntityIndex][ent_color], entArray[iEntityIndex][ent_name], color_warning, color_name, receiver);

				LogAction(client, -1, "\"%L\" transfered \"%s\" to \"%L\"", client, entArray[iEntityIndex][ent_name], receiver);
			}
		}
	}

	if (!bFoundWeapon)
	CPrintToChat(client, "\x07%s[entWatch] \x07%sInvalid item name.", color_tag, color_warning);

	return Plugin_Handled;
}

public EdictMenu_Handler(Handle:hEdictMenu, MenuAction:hAction, iParam1, iParam2)
{
	switch (hAction)
	{
	case MenuAction_End:
		CloseHandle(hEdictMenu);

	case MenuAction_Select:
		{
			new String:sSelected[32];
			GetMenuItem(hEdictMenu, iParam2, sSelected, sizeof(sSelected));
			new iEntityIndex = StringToInt(sSelected);
			new receiver = g_iAdminMenuTarget[iParam1];

			if (receiver == 0)
			{
				CPrintToChat(iParam1, "\x07%s[entWatch] \x07%sReceiver is not valid anymore.", color_tag, color_warning);
				return;
			}

			if (entArray[iEntityIndex][ent_allowtransfer])
			{
				if (entArray[iEntityIndex][ent_ownerid] != -1)
				{
					if (IsValidEdict(entArray[iEntityIndex][ent_weaponid]))
					{
						new iCurOwner = entArray[iEntityIndex][ent_ownerid];

						if (GetClientTeam(receiver) != GetClientTeam(iCurOwner))
						{
							CPrintToChat(iParam1, "\x07%s[entWatch] \x07%sThe receivers team differs from the targets team.", color_tag, color_warning);
							return;
						}

						new String:buffer_classname[64];
						GetEdictClassname(entArray[iEntityIndex][ent_weaponid], buffer_classname, sizeof(buffer_classname))

						CS_DropWeapon(iCurOwner, entArray[iEntityIndex][ent_weaponid], false);
						GivePlayerItem(iCurOwner, buffer_classname);
						ResetStatus(iCurOwner);

						if (entArray[iEntityIndex][ent_chat])
						{
							entArray[iEntityIndex][ent_chat] = false;
							EquipPlayerWeapon(receiver, entArray[iEntityIndex][ent_weaponid]);
							CS_SetClientContributionScore(receiver, 9999);
							entArray[iEntityIndex][ent_chat] = true;
						}
						else
						{
							EquipPlayerWeapon(receiver, entArray[iEntityIndex][ent_weaponid]);
							CS_SetClientContributionScore(receiver, 9999);
						}

						CPrintToChatAll("\x07%s[entWatch] \x07%s%N \x07%stransferred all items from \x07%s%N \x07%sto \x07%s%N. Make sure to drop and pick up your powerup to enable it.", color_tag, color_name, iParam1, color_warning, color_name, iCurOwner, color_warning, color_name, receiver);

						LogAction(iParam1, iCurOwner, "\"%L\" transfered all items from \"%L\" to \"%L\"", iParam1, iCurOwner, receiver);
					}
				}
				else
				{
					CPrintToChat(iParam1, "\x07%s[entWatch] \x07%sItem is not valid anymore.", color_tag, color_warning);
				}
			}
		}
	}
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock LoadColors()
{
	new Handle:hKeyValues = CreateKeyValues("colors");
	new String:buffer_config[128];
	new String:buffer_path[PLATFORM_MAX_PATH];
	new String:buffer_temp[16];

	GetConVarString(G_hCvar_ConfigColor, buffer_config, sizeof(buffer_config));
	Format(buffer_path, sizeof(buffer_path), "cfg/sourcemod/entwatch/colors/%s.cfg", buffer_config);
	FileToKeyValues(hKeyValues, buffer_path);

	KvRewind(hKeyValues);

	KvGetString(hKeyValues, "color_tag", buffer_temp, sizeof(buffer_temp));
	Format(color_tag, sizeof(color_tag), "%s", buffer_temp);

	KvGetString(hKeyValues, "color_name", buffer_temp, sizeof(buffer_temp));
	Format(color_name, sizeof(color_name), "%s", buffer_temp);

	KvGetString(hKeyValues, "color_steamid", buffer_temp, sizeof(buffer_temp));
	Format(color_steamid, sizeof(color_steamid), "%s", buffer_temp);

	KvGetString(hKeyValues, "color_use", buffer_temp, sizeof(buffer_temp));
	Format(color_use, sizeof(color_use), "%s", buffer_temp);

	KvGetString(hKeyValues, "color_pickup", buffer_temp, sizeof(buffer_temp));
	Format(color_pickup, sizeof(color_pickup), "%s", buffer_temp);

	KvGetString(hKeyValues, "color_drop", buffer_temp, sizeof(buffer_temp));
	Format(color_drop, sizeof(color_drop), "%s", buffer_temp);

	KvGetString(hKeyValues, "color_disconnect", buffer_temp, sizeof(buffer_temp));
	Format(color_disconnect, sizeof(color_disconnect), "%s", buffer_temp);

	KvGetString(hKeyValues, "color_death", buffer_temp, sizeof(buffer_temp));
	Format(color_death, sizeof(color_death), "%s", buffer_temp);

	KvGetString(hKeyValues, "color_warning", buffer_temp, sizeof(buffer_temp));
	Format(color_warning, sizeof(color_warning), "%s", buffer_temp);

	CloseHandle(hKeyValues);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
stock LoadConfig()
{
	new Handle:hKeyValues = CreateKeyValues("entities");
	new String:buffer_map[128];
	new String:buffer_path[PLATFORM_MAX_PATH];
	new String:buffer_temp[32];
	new buffer_amount;

	GetCurrentMap(buffer_map, sizeof(buffer_map));
	Format(buffer_path, sizeof(buffer_path), "cfg/sourcemod/entwatch/maps/%s.cfg", buffer_map);
	FileToKeyValues(hKeyValues, buffer_path);

	LogMessage("Loading %s", buffer_path);

	KvRewind(hKeyValues);
	if (KvGotoFirstSubKey(hKeyValues))
	{
		G_bConfigLoaded = true;
		entArraySize = 0;

		do
		{
			KvGetString(hKeyValues, "maxamount", buffer_temp, sizeof(buffer_temp));
			buffer_amount = StringToInt(buffer_temp);

			for (new i = 0; i < buffer_amount; i++)
			{
				KvGetString(hKeyValues, "name", buffer_temp, sizeof(buffer_temp));
				Format(entArray[entArraySize][ent_name], 32, "%s", buffer_temp);

				KvGetString(hKeyValues, "shortname", buffer_temp, sizeof(buffer_temp));
				Format(entArray[entArraySize][ent_shortname], 32, "%s", buffer_temp);

				KvGetString(hKeyValues, "color", buffer_temp, sizeof(buffer_temp));
				Format(entArray[entArraySize][ent_color], 32, "%s", buffer_temp);

				KvGetString(hKeyValues, "buttonclass", buffer_temp, sizeof(buffer_temp));
				Format(entArray[entArraySize][ent_buttonclass], 32, "%s", buffer_temp);

				KvGetString(hKeyValues, "filtername", buffer_temp, sizeof(buffer_temp));
				Format(entArray[entArraySize][ent_filtername], 32, "%s", buffer_temp);

				KvGetString(hKeyValues, "hasfiltername", buffer_temp, sizeof(buffer_temp));
				entArray[entArraySize][ent_hasfiltername] = StrEqual(buffer_temp, "true", false);

				KvGetString(hKeyValues, "blockpickup", buffer_temp, sizeof(buffer_temp));
				entArray[entArraySize][ent_blockpickup] = StrEqual(buffer_temp, "true", false);

				KvGetString(hKeyValues, "allowtransfer", buffer_temp, sizeof(buffer_temp));
				entArray[entArraySize][ent_allowtransfer] = StrEqual(buffer_temp, "true", false);

				KvGetString(hKeyValues, "forcedrop", buffer_temp, sizeof(buffer_temp));
				entArray[entArraySize][ent_forcedrop] = StrEqual(buffer_temp, "true", false);

				KvGetString(hKeyValues, "chat", buffer_temp, sizeof(buffer_temp));
				entArray[entArraySize][ent_chat] = StrEqual(buffer_temp, "true", false);

				KvGetString(hKeyValues, "hud", buffer_temp, sizeof(buffer_temp));
				entArray[entArraySize][ent_hud] = StrEqual(buffer_temp, "true", false);

				KvGetString(hKeyValues, "hammerid", buffer_temp, sizeof(buffer_temp));
				entArray[entArraySize][ent_hammerid] = StringToInt(buffer_temp);

				KvGetString(hKeyValues, "mode", buffer_temp, sizeof(buffer_temp));
				entArray[entArraySize][ent_mode] = StringToInt(buffer_temp);

				KvGetString(hKeyValues, "maxuses", buffer_temp, sizeof(buffer_temp));
				entArray[entArraySize][ent_maxuses] = StringToInt(buffer_temp);

				KvGetString(hKeyValues, "cooldown", buffer_temp, sizeof(buffer_temp));
				entArray[entArraySize][ent_cooldown] = StringToInt(buffer_temp);

				entArraySize++;
			}
		}
		while (KvGotoNextKey(hKeyValues));
	}
	else
	{
		G_bConfigLoaded = false;

		LogMessage("Could not load %s", buffer_path);
	}

	CloseHandle(hKeyValues);
}
