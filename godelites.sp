#pragma semicolon 1
#include <sourcemod>
#include <colors_csgo>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <zombiereloaded>

#define PLUGIN_VERSION "1.0"
#define FreezeColor	{75,75,255,255}
#define BOOMSOUND "weapons/hegrenade/explode4.wav"
#define FREEZESOUND "physics/glass/glass_impact_bullet4.wav"

#pragma newdecls required

int g_beamsprite, g_ExplosionSprite;
ConVar g_cVRange, g_cVDamage, g_cVTime;
ArrayList GodEliteList;

public Plugin myinfo =
{
	name = "[sG] GodElites",
	description = "Overpowered Elites based off of NatalyaAF's plugin.",
	author = "sG | AntiTeal",
	version = PLUGIN_VERSION,
	url = "http://www.joinsg.net"
};

public void OnPluginStart()
{
	CreateConVar("sm_godelites_version", PLUGIN_VERSION, "Plugin Version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);

	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");

	RegAdminCmd("sm_godelites", GiveElites, ADMFLAG_GENERIC);

	HookEvent("bullet_impact", Event_BulletImpact);

	HookEvent("round_start", Event_RoundStart);

	g_cVRange = CreateConVar("sm_godelites_range", "250", "Range (in units) for each effect.");
	g_cVDamage = CreateConVar("sm_godelites_damage", "1000", "Base damage for zombies hit by the explosion.");
	g_cVTime = CreateConVar("sm_godelites_time", "1.5", "Time for zombie freeze to last.");

	GodEliteList = CreateArray(8);
}

public void OnMapStart() 
{
	PrecacheSound(BOOMSOUND, true);
	PrecacheSound(FREEZESOUND, true);

	g_beamsprite = PrecacheModel("materials/sprites/laserbeam.vmt");

	Handle gameConfig = LoadGameConfigFile("funcommands.games");

	char buffer[PLATFORM_MAX_PATH];
	if (GameConfGetKeyValue(gameConfig, "SpriteExplosion", buffer, sizeof(buffer)) && buffer[0])
	{
		g_ExplosionSprite = PrecacheModel(buffer);
	}
}

public Action GiveElites(int client, int argc)
{
	if(argc < 1)
	{
		CPrintToChat(client, "{green}[SM]{red} Usage: sm_godelites <#userid|name>");
		return Plugin_Handled;
	}

	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS];
	int target_count;
	bool tn_is_ml;

	if((target_count = ProcessTargetString(arg, client, target_list, MAXPLAYERS, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for(int i = 0; i < target_count; i++)
	{
		SpawnElites(target_list[i]);
	}

	ShowActivity2(client, "\x01[SM] \x04", "\x01Gave \x04%s\x01 to target \x04%s", "GodElites", target_name);
	LogAction(client, -1, "Gave %s to target %s", "GodElites", target_name);

	return Plugin_Handled;
}

public void SpawnElites(int client)
{
	int elite, weaponEnt = GetPlayerWeaponSlot(client, 1);
	if (weaponEnt != -1)
	{
		CS_DropWeapon(client, weaponEnt, false, false);
	}

	elite = GivePlayerItem(client, "weapon_elite");
	PushArrayCell(GodEliteList, elite);
	SetEntityRenderColor(elite, 255, 0, 0, 255);

	CPrintToChat(client, "{green}[SM]{red} You have been given the {blue}God-Elites{red}. Use them wisely.");
}

public Action Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	ClearArray(GodEliteList);
}

public Action Event_BulletImpact(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	char weap[32];
	GetClientWeapon(client, weap, sizeof(weap));
	if(StrContains(weap, "elite", false) != -1)
	{
		int weapon = GetPlayerWeaponSlot(client, 1);

		if(FindValueInArray(GodEliteList, weapon) != -1)
		{
			float m_fImpact[3], m_fOrigin[3];

			GetClientEyePosition(client, m_fOrigin);

			m_fImpact[0] = GetEventFloat(event, "x");
			m_fImpact[1] = GetEventFloat(event, "y");
			m_fImpact[2] = GetEventFloat(event, "z");

			//Rainbow Tracer
			int rainbowArray[4];
			rainbowArray[0] = GetRandomInt(0, 255);
			rainbowArray[1] = GetRandomInt(0, 255);
			rainbowArray[2] = GetRandomInt(0, 255);
			rainbowArray[3] = 255;
			TE_SetupBeamPoints(m_fOrigin, m_fImpact, g_beamsprite, 0, 0, 0, 0.5, 1.0, 1.0, 1, 0.0, rainbowArray, 0);
			TE_SendToAll();

			if(GetRandomInt(0, 1) == 0)
			{
				CreateExplosion(client, m_fImpact);
			}
			else
			{
				CreateFreeze(client, m_fImpact);
			}
		}
	}
}

public void CreateExplosion(int client, float impact[3])
{
	EmitAmbientSound(BOOMSOUND, impact, client, 50);
	TE_SetupExplosion(impact, g_ExplosionSprite, 5.0, 1, 0, g_cVRange.IntValue, 5000);
	TE_SendToAll();
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && ZR_IsClientZombie(i) && client != i)
		{
			float pos[3];
			GetClientAbsOrigin(i, pos);
			float distance = GetVectorDistance(impact, pos);

			if (distance > g_cVRange.FloatValue)
			{
				continue;
			}

			int damage = g_cVDamage.IntValue;
			damage = RoundToFloor(damage * ((g_cVRange.FloatValue - distance) / g_cVRange.FloatValue));

			SDKHooks_TakeDamage(i, i, i, float(damage));
		}
	}
}

public void CreateFreeze(int client, float impact[3])
{
	EmitAmbientSound(FREEZESOUND, impact, client, SNDLEVEL_NORMAL);
	float beaconVec[3];
	beaconVec[0] = impact[0];
	beaconVec[1] = impact[1];
	beaconVec[2] = (impact[2] + 10.0);
	TE_SetupBeamRingPoint(beaconVec, 10.0, g_cVRange.FloatValue, g_beamsprite, g_beamsprite, 0, 15, 0.25, 5.0, 0.0, FreezeColor, 10, 0); 
	TE_SendToAll();
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && ZR_IsClientZombie(i) && client != i)
		{
			float pos[3];
			GetClientAbsOrigin(i, pos);
			float distance = GetVectorDistance(impact, pos);

			if (distance > g_cVRange.FloatValue)
			{
				continue;
			}

			SetEntityMoveType(i, MOVETYPE_NONE);
			SetEntityRenderColor(i, 0, 128, 255, 192);

			PrintHintText(i, "You are frozen for %.3f seconds...", g_cVTime.FloatValue);
			CreateTimer(g_cVTime.FloatValue, UnfreezePlayer, GetClientSerial(i));
		}
	}
}

public Action UnfreezePlayer(Handle timer, any serial)
{
	int client = GetClientFromSerial(serial); 

	if (client == 0 || !IsClientInGame(client) || !IsPlayerAlive(client))
	{
		return Plugin_Stop;
	}

	float vec[3];
	GetClientAbsOrigin(client, vec);
	vec[2] += 10;	

	EmitAmbientSound(FREEZESOUND, vec, client, SNDLEVEL_RAIDSIREN);

	SetEntityMoveType(client, MOVETYPE_WALK);
	SetEntityRenderColor(client, 255, 255, 255, 255);

	return Plugin_Handled;
}