#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <zrtest>

int g_iLaserMaterial = -1;
#include <tealent>

#pragma newdecls required

#define PLUGIN_VERSION "1.0"

bool isIcecap = false;
bool isExtreme = false;
bool hasRun = false;

Handle NukeButton_TimerHandle = INVALID_HANDLE;
Handle PlayerHeight_TimerHandle = INVALID_HANDLE;
Handle Seph1Laser_TimerHandle = INVALID_HANDLE;
Handle Seph2Laser_TimerHandle = INVALID_HANDLE;
Handle MeteorTimer_TimerHandle = INVALID_HANDLE;
Handle SephCounter_TimerHandle = INVALID_HANDLE;
Handle SephLaserPart2_TimerHandle = INVALID_HANDLE;

int speedmod = -1;

float ZTeleOrigin[2][3];
float ZTeleAngles[2][3];

bool g_bIsBulletOrigin[MAXPLAYERS+1];
int bossTarget = -1;
int laserDamage = 9999;
bool stopTouch[MAXPLAYERS+1];
bool isMeteor;
bool isTargeting;
bool oneDone;

int counter = 0;
int counter2 = 0;

bool createTimer = false;

//Word indicates what you need to do to dodge.
enum LaserType {
	RANDOM,
	CROUCH,
	JUMP,
	LEFT,
	RIGHT,
}

public Plugin myinfo = 
{
	name = "Icecap EXTREME",
	author = "AntiTeal",
	description = "#MakeIcecapGreatAgain",
	version = PLUGIN_VERSION,
	url = "http://antiteal.com"
};

public void OnPluginStart()
{
	RegAdminCmd("sm_icecap_extreme", Command_ForceExtreme, ADMFLAG_GENERIC);
	//RegAdminCmd("sm_lasertest", LaserTest, ADMFLAG_GENERIC);

	//RegAdminCmd("sm_bosstest", BossTest, ADMFLAG_GENERIC);

	//RegAdminCmd("sm_bulletorigin", BulletOrigin, ADMFLAG_GENERIC);
	//HookEvent("bullet_impact", Event_BulletImpact);
}

public Action BulletOrigin(int client, int argc)
{
	g_bIsBulletOrigin[client] = !g_bIsBulletOrigin[client];
	return Plugin_Handled;
}

public Action Event_BulletImpact(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(g_bIsBulletOrigin[client])
	{
		float m_fImpact[3];
		m_fImpact[0] = GetEventFloat(event, "x");
		m_fImpact[1] = GetEventFloat(event, "y");
		m_fImpact[2] = GetEventFloat(event, "z");

		PrintToChat(client, "Origin: %.2f %.2f %.2f", m_fImpact[0], m_fImpact[1], m_fImpact[2]);
	}
}

public Action Command_ForceExtreme(int client, int argc)
{
	if(isIcecap)
	{
		ServerSay("Com", ">> ?!?!? <<", 0.0);
		isExtreme = true;
	}
	return Plugin_Handled;
}

public void OnMapStart()
{
	char map[128];
	GetCurrentMap(map, sizeof(map));
	if(StrContains(map, "ze_icecap_escape", false) != -1)
	{
		isIcecap = true;

		PrecacheAndDownload();

		ZTeleOrigin[0][0] = 417.0, ZTeleOrigin[0][1] = 690.0, ZTeleOrigin[0][2] = 37.0;
		ZTeleAngles[0][0] = 0.0, ZTeleAngles[0][1] = 90.0, ZTeleAngles[0][2] = 0.0;

		ZTeleOrigin[1][0] = 417.0, ZTeleOrigin[1][1] = 690.0, ZTeleOrigin[1][2] = 37.0;
		ZTeleAngles[1][0] = 0.0, ZTeleAngles[1][1] = 90.0, ZTeleAngles[1][2] = 0.0;

		HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	}
}

public void PrecacheAndDownloadMaterial(char[] path)
{
	char szBuffer[PLATFORM_MAX_PATH], szBuffer2[PLATFORM_MAX_PATH];
	Format(szBuffer, sizeof(szBuffer), "%s.vmt", path);
	Format(szBuffer2, sizeof(szBuffer2), "%s.vtf", path);

	AddFileToDownloadsTable(szBuffer);
	AddFileToDownloadsTable(szBuffer2);
	PrecacheGeneric(szBuffer, true);
	PrecacheGeneric(szBuffer2, true);
}

public void PrecacheAndDownload()
{
	PrecacheModel("models/props/cs_militia/silo_01.mdl", true);

	//Color Correction
	AddFileToDownloadsTable("materials/correction/cc_grey.raw");
	PrecacheGeneric("materials/correction/cc_grey.raw", true);
	AddFileToDownloadsTable("materials/correction/cc_red.raw");
	PrecacheGeneric("materials/correction/cc_red.raw", true);

	//Sephiroth
	AddFileToDownloadsTable("models/antiteal/icecap/sephiroth.dx90.vtx");
	AddFileToDownloadsTable("models/antiteal/icecap/sephiroth.mdl");
	AddFileToDownloadsTable("models/antiteal/icecap/sephiroth.vvd");
	PrecacheModel("models/antiteal/icecap/sephiroth.mdl", true);
	PrecacheAndDownloadMaterial("materials/models/antiteal/icecap/sephiroth/diss_00");
	PrecacheAndDownloadMaterial("materials/models/antiteal/icecap/sephiroth/diss_01");

	//Pendulum Crush
	AddFileToDownloadsTable("sound/music/antiteal/crush.mp3");
	PrecacheSound("sound/music/antiteal/crush.mp3", true);

	//Laser Sound
	AddFileToDownloadsTable("sound/music/antiteal/laser.mp3");
	PrecacheSound("sound/music/antiteal/laser.mp3", true);

	//Sephiroth Sounds
	AddFileToDownloadsTable("sound/music/antiteal/seph_saygoodbye.mp3");
	PrecacheSound("sound/music/antiteal/seph_saygoodbye.mp3", true);
	AddFileToDownloadsTable("sound/music/antiteal/seph_seeyouagain.mp3");
	PrecacheSound("sound/music/antiteal/seph_seeyouagain.mp3", true);
	AddFileToDownloadsTable("sound/music/antiteal/seph_dodgethis.mp3");
	PrecacheSound("sound/music/antiteal/seph_dodgethis.mp3", true);
	AddFileToDownloadsTable("sound/music/antiteal/seph_impressive.mp3");
	PrecacheSound("sound/music/antiteal/seph_impressive.mp3", true);
	AddFileToDownloadsTable("sound/music/antiteal/seph_seems.mp3");
	PrecacheSound("sound/music/antiteal/seph_seems.mp3", true);
	AddFileToDownloadsTable("sound/music/antiteal/seph_defeated.mp3");
	PrecacheSound("sound/music/antiteal/seph_defeated.mp3", true);

	//Laser
	PrecacheAndDownloadMaterial("materials/antiteal/customlaser/laser1");
	PrecacheAndDownloadMaterial("materials/antiteal/customlaser/laser2");
	PrecacheAndDownloadMaterial("materials/antiteal/customlaser/white");

	AddFileToDownloadsTable("models/antiteal/thelaser/icecap_laser.dx90.vtx");
	AddFileToDownloadsTable("models/antiteal/thelaser/icecap_laser.mdl");
	AddFileToDownloadsTable("models/antiteal/thelaser/icecap_laser.phy");
	AddFileToDownloadsTable("models/antiteal/thelaser/icecap_laser.vvd");
	PrecacheModel("models/antiteal/thelaser/icecap_laser.mdl", true);

	//Particles
	AddFileToDownloadsTable("particles/antiteal_icecap_v2.pcf");
	PrecacheGeneric("particles/antiteal_icecap_v2.pcf", true);

	//Rock Wall
	PrecacheModel("models/props/cs_militia/rockwall.mdl", true);

	//Crate Wall
	PrecacheModel("models/props/de_nuke/hr_nuke/metal_crate_001/metal_crate_001_128x112x256.mdl", true);

	//Arena
	AddFileToDownloadsTable("models/antiteal/icecap/arena_2.dx90.vtx");
	AddFileToDownloadsTable("models/antiteal/icecap/arena_2.mdl");
	AddFileToDownloadsTable("models/antiteal/icecap/arena_2.phy");
	AddFileToDownloadsTable("models/antiteal/icecap/arena_2.vvd");
	PrecacheAndDownloadMaterial("materials/models/antiteal/icecap/arena/main0");
	PrecacheAndDownloadMaterial("materials/models/antiteal/icecap/arena/main1");
	PrecacheAndDownloadMaterial("materials/models/antiteal/icecap/arena/main2");
	PrecacheAndDownloadMaterial("materials/models/antiteal/icecap/arena/main3");
	PrecacheModel("models/antiteal/icecap/arena_2.mdl", true);

	//Boss Theme (That Person's Name Is)
	AddFileToDownloadsTable("sound/music/antiteal/thatpersonsnameis_v2.mp3");
	PrecacheSound("sound/music/antiteal/thatpersonsnameis_v2.mp3", true);

	//Ending Theme (Providence Phase 2)
	AddFileToDownloadsTable("sound/music/antiteal/providence2.mp3");
	PrecacheSound("sound/music/antiteal/providence2.mp3", true);

	//Ending Tiz Theme (Tiz's Theme Bravely Second)
	AddFileToDownloadsTable("sound/music/antiteal/tiz2_v2.mp3");
	PrecacheSound("sound/music/antiteal/tiz2_v2.mp3", true);

	//Victory Theme
	AddFileToDownloadsTable("sound/music/antiteal/ffvii_victory.mp3");
	PrecacheSound("sound/music/antiteal/ffvii_victory.mp3", true);
}

int IsValidClient(int client, bool nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}

public int HumanCount()
{
	int count = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && ZR_IsClientHuman(i))
		{
			count++;
		}
	}
	return count;
}

public int ZombieCount()
{
	int count = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && ZR_IsClientZombie(i))
		{
			count++;
		}
	}
	return count;
}

public void CheckPlayerHeight()
{
	PlayerHeight_TimerHandle = CreateTimer(0.25, CheckHeight, _, TIMER_REPEAT);
}

public Action CheckHeight(Handle timer, any data)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			float pos[3];
			GetClientAbsOrigin(i, pos);

			if(pos[2] <= -75.0)
			{
				if(ZR_IsClientHuman(i))
				{
					ForcePlayerSuicide(i);
				}
				else
				{
					ZMTeleport(i);
				}
			}
		}
	} 

	ForceEntityInput("ztele6_trigger", "Toggle");
	ForceEntityInput("ztele1_trigger", "Toggle");
	ForceEntityInput("ztele2_trigger", "Toggle");
	ForceEntityInput("ztele2_trigger_2", "Toggle");
	ForceEntityInput("ztele3_trigger_teleport", "Toggle");
	ForceEntityInput("ztele4_trigger", "Toggle");
	ForceEntityInput("ztele5_trigger_teleport", "Toggle");
	ForceEntityInput("spawn_ztele_trigger", "Toggle");
	ForceEntityInput("headback_teleport", "Toggle");
	ForceEntityInput("island_ztele", "Toggle");
	ForceEntityInput("zm_ztele_back", "Toggle");

	ForceEntityInput("level_text", "Display");
}

public void TimerKill(Handle &timer)
{
	if (timer != INVALID_HANDLE)
	{
		CloseHandle(timer);
	}
	timer = INVALID_HANDLE;
} 

public void ZMTeleport(int client)
{
	if(!IsValidClient(client))
	{
		return;
	}

	if(GetRandomInt(0, 1) == 0)
	{
		TeleportEntity(client, ZTeleOrigin[0], ZTeleAngles[0], NULL_VECTOR);
	}
	else
	{
		TeleportEntity(client, ZTeleOrigin[1], ZTeleAngles[1], NULL_VECTOR);
	}
}

public Action NukeButton_OnPressed(const char[] output, int caller, int activator, float delay)
{
	if(isExtreme)
	{
		return Plugin_Stop;
	}
	else
	{
		NukeButton_TimerHandle = CreateTimer(10.0, NukeButton_Timer);
	}
	return Plugin_Continue;
}

public Action NukeButton_Timer(Handle timer, any data)
{
	ServerSay("Com", ">> ?!?!? <<", 1.0);
	isExtreme = true;
	NukeButton_TimerHandle = INVALID_HANDLE;
}

public Action NewRound_Timer(Handle timer, any data)
{
	hasRun = false;
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	KillAllTimers();
	if(isIcecap && !hasRun)
	{
		SetupExtreme();
		ForceEntityInput("env_shake", "StopShake");
	}
}

public void SetupExtreme()
{
	oneDone = false;
	isMeteor = false;
	isTargeting = false;
	createTimer = false;

	hasRun = true;
	CreateTimer(2.0, NewRound_Timer);
	ZTeleOrigin[0][0] = 417.0, ZTeleOrigin[0][1] = 690.0, ZTeleOrigin[0][2] = 37.0;
	ZTeleAngles[0][0] = 0.0, ZTeleAngles[0][1] = 90.0, ZTeleAngles[0][2] = 0.0;

	ZTeleOrigin[1][0] = 417.0, ZTeleOrigin[1][1] = 690.0, ZTeleOrigin[1][2] = 37.0;
	ZTeleAngles[1][0] = 0.0, ZTeleAngles[1][1] = 90.0, ZTeleAngles[1][2] = 0.0;
	bossTarget = -1;

	ServerCommand("sv_skyname sky_cs15_daylight01_hdr");

	HookSingleEntityOutput(GetEntityFromHammerID(132437), "OnPressed", NukeButton_OnPressed, false);

	if(isExtreme)
	{
		ServerCommand("zr_infect_mzombie_respawn 0");
		ServerCommand("zr_infect_spawntime_min 9");
		ServerCommand("zr_infect_spawntime_max 10");
		MeteorTimer_TimerHandle = CreateTimer(8.0, Meteor_Timer, _, TIMER_REPEAT);
		ServerSay("Com", ">> EXTREME <<", 2.5);
		CreateExtreme();
		ForceEntityInput("extreme_relay", "Trigger");
	}
}

public void KillAllTimers()
{
	TimerKill(NukeButton_TimerHandle);
	TimerKill(PlayerHeight_TimerHandle);
	TimerKill(Seph1Laser_TimerHandle);
	TimerKill(Seph2Laser_TimerHandle);
	TimerKill(MeteorTimer_TimerHandle);
	TimerKill(SephCounter_TimerHandle);
	TimerKill(SephLaserPart2_TimerHandle);
}

public void CreateExtreme()
{
	CreateExtremeRelay();
	CreateAndModifyEntities();
	DestroyEntities();

	SetupDoorSystems();
	CheckPlayerHeight();

	CreateSounds();
	CreateParticles();

	SpawnWalls();
	BurnBridges();

	Sephiroth_Part1();
	Create_IceHold();
	ZMInit();
}

public void CreateExtremeRelay()
{
	SpawnEntityByName("logic_relay", "extreme_relay");
	GiveEntityOutput("extreme_relay", "OnTrigger", "extreme_cc", "Enable");
	GiveEntityOutput("extreme_relay", "OnTrigger", "extreme_cc", "Disable", "", "11.5");
	GiveEntityOutput("extreme_relay", "OnTrigger", "extreme_relay2", "Trigger", "", "11.5");
	GiveEntityOutput("extreme_relay", "OnTrigger", "extreme_cc2", "Enable", "", "11.5");
	GiveEntityOutput("extreme_relay", "OnTrigger", "extreme_fade1", "fade", "", "11");

	GiveEntityOutput("extreme_relay", "OnTrigger", "particle_001", "Start", "", "11");
	GiveEntityOutput("extreme_relay", "OnTrigger", "particle_002", "Start", "", "11");

	GiveEntityOutput("extreme_relay", "OnTrigger", "Boat5", "StartForward", "", "0.5");
	GiveEntityOutput("extreme_relay", "OnTrigger", "WashTub2", "StartForward", "", "0.5");

	GiveEntityOutput("extreme_relay", "OnTrigger", "crush", "PlaySound", "", "0.0");

	int relay = SpawnEntityByName("logic_relay", "extreme_relay2");
	HookSingleEntityOutput(relay, "OnTrigger", Extreme_Relay2_OnTrigger, false);
}

public Action Extreme_Relay2_OnTrigger(const char[] output, int caller, int activator, float delay)
{
	ServerCommand("sv_skyname sky_csgo_night02b");
	isMeteor = true;
}

public void CreateZTeleRelay()
{
	int ent = SpawnEntityByName("logic_relay", "ztele_relay");
	HookSingleEntityOutput(ent, "OnTrigger", ZTele_Relay_OnTrigger, false);
}

public Action ZTele_Relay_OnTrigger(const char[] output, int caller, int activator, float delay)
{
	if(IsValidClient(activator))
	{
		ZMTeleport(activator);
	}
}

public Action DisableOutput(const char[] output, int caller, int activator, float delay)
{
	return Plugin_Stop;
}

public void CreateAndModifyEntities()
{
	SpawnEntityByName("color_correction", "extreme_cc");
	DispatchKeyValue(GetEntityFromTargetname("extreme_cc"), "StartDisabled", "1");
	DispatchKeyValue(GetEntityFromTargetname("extreme_cc"), "spawnflags", "0");
	DispatchKeyValue(GetEntityFromTargetname("extreme_cc"), "minfalloff", "-1");
	DispatchKeyValue(GetEntityFromTargetname("extreme_cc"), "maxweight", "1.0");
	DispatchKeyValue(GetEntityFromTargetname("extreme_cc"), "maxfalloff", "-1");
	DispatchKeyValue(GetEntityFromTargetname("extreme_cc"), "filename", "materials/correction/cc_grey.raw");
	DispatchKeyValue(GetEntityFromTargetname("extreme_cc"), "fadeOutDuration", "0.0");
	DispatchKeyValue(GetEntityFromTargetname("extreme_cc"), "fadeInDuration", "0.0");
	DispatchSpawn(GetEntityFromTargetname("extreme_cc"));
	ActivateEntity(GetEntityFromTargetname("extreme_cc"));

	SpawnEntityByName("color_correction", "extreme_cc2");
	DispatchKeyValue(GetEntityFromTargetname("extreme_cc2"), "StartDisabled", "1");
	DispatchKeyValue(GetEntityFromTargetname("extreme_cc2"), "spawnflags", "0");
	DispatchKeyValue(GetEntityFromTargetname("extreme_cc2"), "minfalloff", "-1");
	DispatchKeyValue(GetEntityFromTargetname("extreme_cc2"), "maxweight", "1.0");
	DispatchKeyValue(GetEntityFromTargetname("extreme_cc2"), "maxfalloff", "-1");
	DispatchKeyValue(GetEntityFromTargetname("extreme_cc2"), "filename", "materials/correction/cc_red.raw");
	DispatchKeyValue(GetEntityFromTargetname("extreme_cc2"), "fadeOutDuration", "0.0");
	DispatchKeyValue(GetEntityFromTargetname("extreme_cc2"), "fadeInDuration", "0.0");
	DispatchSpawn(GetEntityFromTargetname("extreme_cc2"));
	ActivateEntity(GetEntityFromTargetname("extreme_cc2"));

	int fade = SpawnEntityByName("env_fade", "extreme_fade1");
	DispatchKeyValue(fade, "spawnflags", "0");
	DispatchKeyValue(fade, "rendercolor", "255 255 255");
	DispatchKeyValue(fade, "renderamt", "255");
	DispatchKeyValue(fade, "duration", "0.5");
	DispatchKeyValue(fade, "holdtime", "0");
	DispatchKeyValue(fade, "reversefadeduration", "0.5");

	int shake = SpawnEntityByName("env_shake", "extreme_shake1");
	DispatchKeyValue(shake, "spawnflags", "5");
	DispatchKeyValue(shake, "radius", "1250");
	DispatchKeyValue(shake, "frequency", "125");
	DispatchKeyValue(shake, "duration", "4");
	DispatchKeyValue(shake, "amplitude", "4");

	int shake2 = SpawnEntityByName("env_shake", "extreme_shake2");
	DispatchKeyValue(shake2, "spawnflags", "5");
	DispatchKeyValue(shake2, "radius", "1250");
	DispatchKeyValue(shake2, "frequency", "180");
	DispatchKeyValue(shake2, "duration", "60");
	DispatchKeyValue(shake2, "amplitude", "4");

	int ent = SpawnEntityByName("logic_relay", "ztele_relay");
	HookSingleEntityOutput(ent, "OnTrigger", ZTele_Relay_OnTrigger, false);

	speedmod = SpawnEntityByName("player_speedmod", "speed");

	GiveHammerIDTargetname(200706, "ztele3_trigger");
	int ztele3 = GetEntityFromTargetname("ztele3_trigger");
	HookSingleEntityOutput(ztele3, "OnStartTouch", ztele3_trigger_OnStartTouch, false);

	GiveHammerIDTargetname(200755, "ztele5_trigger");
	int ztele5 = GetEntityFromTargetname("ztele5_trigger");
	HookSingleEntityOutput(ztele5, "OnStartTouch", ztele5_trigger_OnStartTouch, false);

	ForceEntityInput("Boat5", "AddOutput", "angles 0 180 0");

	float origin[3] = {9247.5, -2761.5, 30.0};
	float min[3] = {-569.5, -345.5, 0.0};
	float max[3] = {569.5, 345.5, 848.0};

	int trigger = CreateBrushEntity("trigger_once", origin, min, max);
	HookSingleEntityOutput(trigger, "OnStartTouch", Island_OnTrigger, true);

	HookSingleEntityOutput(GetEntityFromHammerID(154100), "OnPressed", HelicopterButton_OnPressed, false);

	int text1 = SpawnEntityByName("game_text", "level_text");
	int text2 = SpawnEntityByName("game_text", "thanks_text");

	DispatchKeyValue(text1, "y", "0.065");
	DispatchKeyValue(text1, "x", "-1");
	DispatchKeyValue(text1, "spawnflags", "1");
	DispatchKeyValue(text1, "message", ">> EXTREME <<");
	DispatchKeyValue(text1, "holdtime", "10");
	DispatchKeyValue(text1, "fxtime", "0.25");
	DispatchKeyValue(text1, "fadeout", "0");
	DispatchKeyValue(text1, "fadein", "0");
	DispatchKeyValue(text1, "color", "255 0 0");
	DispatchKeyValue(text1, "color2", "255 128 0");
	DispatchKeyValue(text1, "channel", "1");

	DispatchKeyValue(text2, "y", "0.3");
	DispatchKeyValue(text2, "x", "0.025");
	DispatchKeyValue(text2, "spawnflags", "1");
	DispatchKeyValue(text2, "message", "Special Thanks:\n------------\nAntiTeal (Map Creator)\nKaemon (Sephiroth Model)\n\nTesters:\n------------\nDashe\nAkumu");
	DispatchKeyValue(text2, "holdtime", "10");
	DispatchKeyValue(text2, "fxtime", "0.25");
	DispatchKeyValue(text2, "fadeout", "0");
	DispatchKeyValue(text2, "fadein", "0");
	DispatchKeyValue(text2, "color", "0 255 0");
	DispatchKeyValue(text2, "color2", "158 70 12");
	DispatchKeyValue(text2, "channel", "2");
}

public void DestroyEntities()
{
	GiveHammerIDTargetname(117831, "tram_trigger");
	GiveHammerIDTargetname(117804, "boat1_trigger");
	GiveHammerIDTargetname(117796, "boat2_trigger");
	GiveHammerIDTargetname(117890, "boat3_trigger");
	GiveHammerIDTargetname(117878, "boat4_trigger");
	GiveHammerIDTargetname(117865, "bobsled_trigger");

	GiveEntityOutput("tram_trigger", "OnStartTouch", "Tram", "Kill", "", "10");
	GiveEntityOutput("boat1_trigger", "OnStartTouch", "Boat", "Kill", "", "10");
	GiveEntityOutput("boat2_trigger", "OnStartTouch", "Boat2", "Kill", "", "5");
	GiveEntityOutput("boat3_trigger", "OnStartTouch", "Boat3", "Kill", "", "10");
	GiveEntityOutput("boat4_trigger", "OnStartTouch", "Boat4", "Kill", "", "10");
	GiveEntityOutput("bobsled_trigger", "OnStartTouch", "BobSled", "Kill", "", "5");

	GiveEntityOutput("tram_trigger", "OnStartTouch", "tram_explosion", "Explode", "", "10");
	GiveEntityOutput("boat1_trigger", "OnStartTouch", "boat1_explosion", "Explode", "", "10");
	GiveEntityOutput("boat2_trigger", "OnStartTouch", "boat2_explosion", "Explode", "", "5");
	GiveEntityOutput("boat3_trigger", "OnStartTouch", "boat3_explosion", "Explode", "", "10");
	GiveEntityOutput("boat4_trigger", "OnStartTouch", "boat4_explosion", "Explode", "", "10");
	GiveEntityOutput("bobsled_trigger", "OnStartTouch", "bobsled_explosion", "Explode", "", "5");

	SpawnEntityByName("env_explosion", "tram_explosion");
	SpawnEntityByName("env_explosion", "boat1_explosion");
	SpawnEntityByName("env_explosion", "boat2_explosion");
	SpawnEntityByName("env_explosion", "boat3_explosion");
	SpawnEntityByName("env_explosion", "boat4_explosion");
	SpawnEntityByName("env_explosion", "bobsled_explosion");

	DispatchKeyValue(GetEntityFromTargetname("tram_explosion"), "spawnflags", "16384");
	DispatchKeyValue(GetEntityFromTargetname("tram_explosion"), "rendermode", "5");
	DispatchKeyValue(GetEntityFromTargetname("tram_explosion"), "iRadiusOverride", "500");
	DispatchKeyValue(GetEntityFromTargetname("tram_explosion"), "iMagnitude", "1000");
	DispatchKeyValue(GetEntityFromTargetname("tram_explosion"), "fireballsprite", "sprites/zerogxplode.spr");
	DispatchKeyValue(GetEntityFromTargetname("tram_explosion"), "origin", "-256 416 352");

	DispatchKeyValue(GetEntityFromTargetname("boat1_explosion"), "spawnflags", "16384");
	DispatchKeyValue(GetEntityFromTargetname("boat1_explosion"), "rendermode", "5");
	DispatchKeyValue(GetEntityFromTargetname("boat1_explosion"), "iRadiusOverride", "500");
	DispatchKeyValue(GetEntityFromTargetname("boat1_explosion"), "iMagnitude", "1000");
	DispatchKeyValue(GetEntityFromTargetname("boat1_explosion"), "fireballsprite", "sprites/zerogxplode.spr");
	DispatchKeyValue(GetEntityFromTargetname("boat1_explosion"), "origin", "-512 1440 -32");

	DispatchKeyValue(GetEntityFromTargetname("boat2_explosion"), "spawnflags", "16384");
	DispatchKeyValue(GetEntityFromTargetname("boat2_explosion"), "rendermode", "5");
	DispatchKeyValue(GetEntityFromTargetname("boat2_explosion"), "iRadiusOverride", "500");
	DispatchKeyValue(GetEntityFromTargetname("boat2_explosion"), "iMagnitude", "1000");
	DispatchKeyValue(GetEntityFromTargetname("boat2_explosion"), "fireballsprite", "sprites/zerogxplode.spr");
	DispatchKeyValue(GetEntityFromTargetname("boat2_explosion"), "origin", "0 1440 -32");

	DispatchKeyValue(GetEntityFromTargetname("boat3_explosion"), "spawnflags", "16384");
	DispatchKeyValue(GetEntityFromTargetname("boat3_explosion"), "rendermode", "5");
	DispatchKeyValue(GetEntityFromTargetname("boat3_explosion"), "iRadiusOverride", "500");
	DispatchKeyValue(GetEntityFromTargetname("boat3_explosion"), "iMagnitude", "1000");
	DispatchKeyValue(GetEntityFromTargetname("boat3_explosion"), "fireballsprite", "sprites/zerogxplode.spr");
	DispatchKeyValue(GetEntityFromTargetname("boat3_explosion"), "origin", "3840 6656 -32");

	DispatchKeyValue(GetEntityFromTargetname("boat4_explosion"), "spawnflags", "16384");
	DispatchKeyValue(GetEntityFromTargetname("boat4_explosion"), "rendermode", "5");
	DispatchKeyValue(GetEntityFromTargetname("boat4_explosion"), "iRadiusOverride", "500");
	DispatchKeyValue(GetEntityFromTargetname("boat4_explosion"), "iMagnitude", "1000");
	DispatchKeyValue(GetEntityFromTargetname("boat4_explosion"), "fireballsprite", "sprites/zerogxplode.spr");
	DispatchKeyValue(GetEntityFromTargetname("boat4_explosion"), "origin", "3840 7168 -32");

	DispatchKeyValue(GetEntityFromTargetname("bobsled_explosion"), "spawnflags", "16384");
	DispatchKeyValue(GetEntityFromTargetname("bobsled_explosion"), "rendermode", "5");
	DispatchKeyValue(GetEntityFromTargetname("bobsled_explosion"), "iRadiusOverride", "500");
	DispatchKeyValue(GetEntityFromTargetname("bobsled_explosion"), "iMagnitude", "1000");
	DispatchKeyValue(GetEntityFromTargetname("bobsled_explosion"), "fireballsprite", "sprites/zerogxplode.spr");
	DispatchKeyValue(GetEntityFromTargetname("bobsled_explosion"), "origin", "5888 2688 173");

	GiveHammerIDTargetname(39385, "extreme_bridge1_button");
	ForceEntityInput("extreme_bridge1_button", "Press");

	int hammerIDs[] = {172246, 172581, 237929, 237905, 172559, 238134, 117989, 65561, 153982, 168446};
	for(int i = 0; i < sizeof(hammerIDs); i++)
	{
		int ent = GetEntityFromHammerID(hammerIDs[i]);
		if(ent != -1 && IsValidEntity(ent))
		{
			AcceptEntityInput(ent, "Kill", -1, -1);
		}
	}

	int hammerIDs2[] = {
		49954, 50847, 50865, 50883, 50973, 50991, 51009, 51027, 56222, 60789, 60807, 60825, 60843,
		60861, 60933, 60951, 60969, 61131, 61149, 61167, 61185, 61203, 61221, 61239, 61257, 61275,
		61718, 61825, 61843
	};

	for(int i = 0; i < sizeof(hammerIDs2); i++)
	{
		char szBuffer[64];
		Format(szBuffer, sizeof(szBuffer), "IcePlat&%i", hammerIDs2[i]);
		GiveHammerIDTargetname(hammerIDs2[i], szBuffer);
		ForceEntityInput(szBuffer, "AddOutput", "speed 6");
	}
}

public void SetupDoorSystems()
{
	ForceEntityInput("Block", "Open");
	ForceEntityInput("Block2", "Open");

	int wall1 = SpawnEntityByName("prop_dynamic", "left_cratewall_1");
	DispatchKeyValue(wall1, "angles", "0 0 0");
	DispatchKeyValue(wall1, "origin", "2181 1399 126");
	DispatchKeyValue(wall1, "model", "models/props/de_nuke/hr_nuke/metal_crate_001/metal_crate_001_128x112x256.mdl");
	DispatchKeyValue(wall1, "solid", "6");
	DispatchSpawn(wall1);

	int wall2 = SpawnEntityByName("prop_dynamic", "right_cratewall_1");
	DispatchKeyValue(wall2, "angles", "0 0 0");
	DispatchKeyValue(wall2, "origin", "3451 2998 135");
	DispatchKeyValue(wall2, "model", "models/props/de_nuke/hr_nuke/metal_crate_001/metal_crate_001_128x112x256.mdl");
	DispatchKeyValue(wall2, "solid", "6");
	DispatchSpawn(wall2);

	int prop = SpawnEntityByName("prop_dynamic", "left_cratewall_2");
	DispatchKeyValue(prop, "angles", "0 270 0");
	DispatchKeyValue(prop, "origin", "-1834.0 6277.0 130.0");
	DispatchKeyValue(prop, "model", "models/props/de_nuke/hr_nuke/metal_crate_001/metal_crate_001_128x112x256.mdl");
	DispatchKeyValue(prop, "solid", "6");
	DispatchSpawn(prop);

	int prop2 = SpawnEntityByName("prop_dynamic", "right_cratewall_2");
	DispatchKeyValue(prop2, "angles", "0 270 0");
	DispatchKeyValue(prop2, "origin", "-1849 7547 0");
	DispatchKeyValue(prop2, "model", "models/props/de_nuke/hr_nuke/metal_crate_001/metal_crate_001_128x112x256.mdl");
	DispatchKeyValue(prop2, "solid", "6");
	DispatchSpawn(prop2);

	float origin[3] = {-1519.0, 7577.0, 3.0};
	float min[3] = {-96.0, -88.0, 0.0};
	float max[3] = {96.0, 88.0, 122.0};

	int ent = CreateBrushEntity("trigger_once", origin, min, max);

	HookSingleEntityOutput(ent, "OnStartTouch", Left_CrateWall_Trigger_OnStartTouch, true);
	HookSingleEntityOutput(GetEntityFromHammerID(39399), "OnPressed", Right_CrateWall_Button_OnPressed, false);

	int hammerIDS[] = {38950, 39055, 39073, 39109};
	for(int i = 0; i < sizeof(hammerIDS); i++)
	{
		DispatchKeyValue(GetEntityFromHammerID(hammerIDS[i]), "spawnflags", "0"); 
	}
}

public Action HelicopterButton_OnPressed(const char[] output, int caller, int activator, float delay)
{
	FireEntityInput("Helicopter", "AddOutput", "speed 5000", 5.1);
}

public Action Island_OnTrigger(const char[] output, int caller, int activator, float delay)
{
	ServerSay("Com", ">> Zombies teleporting in 5 seconds.... <<");
	FireEntityInput("ztele6_relay", "Trigger", "", 5.0);
	int relay = SpawnEntityByName("logic_relay", "ztele6_relay");
	int relay2 = SpawnEntityByName("logic_relay", "startboss_relay");

	GiveEntityOutput("ztele6_relay", "OnTrigger", "Com", "Command", "say >> Defend for 30 seconds... <<", "0.0");
	GiveEntityOutput("ztele6_relay", "OnTrigger", "Com", "Command", "say >> Defend for 15 seconds... <<", "15.0");
	GiveEntityOutput("ztele6_relay", "OnTrigger", "Com", "Command", "say >> Defend for 5 seconds... <<", "25.0");
	GiveEntityOutput("ztele6_relay", "OnTrigger", "startboss_relay", "Trigger", "", "30.0");

	HookSingleEntityOutput(relay, "OnTrigger", ZTele6_OnTrigger, false);
	HookSingleEntityOutput(relay2, "OnTrigger", StartBoss_OnTrigger, false);
}

public Action ZTele6_OnTrigger(const char[] output, int caller, int activator, float delay)
{
	ZTeleOrigin[0][0] =	8968.0; 
	ZTeleOrigin[0][1] =	-4112.0; 
	ZTeleOrigin[0][2] =	64.0;

	ZTeleAngles[0][0] = 0.0;
	ZTeleAngles[0][1] =	90.0;
	ZTeleAngles[0][2] =	0.0;

	ZTeleOrigin[1][0] =	9456.0; 
	ZTeleOrigin[1][1] =	-4057.0; 
	ZTeleOrigin[1][2] =	64.0;

	ZTeleAngles[1][0] = 0.0;
	ZTeleAngles[1][1] =	90.0;
	ZTeleAngles[1][2] =	0.0;

	float origin[3] = {-1758.5, -3160.0, -77.5};
	float min[3] = {-3306.5, -2167.0, 0.0};
	float max[3] = {3306.5, 2167.0, 1517.0};

	int ent = CreateBrushEntity("trigger_teleport", origin, min, max);
	GiveIDTargetname(ent, "ztele6_trigger");
	GiveEntityOutput("ztele6_trigger", "OnStartTouch", "ztele_relay", "Trigger");

	ForceEntityInput("Helicopter", "Kill");

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			if(ZR_IsClientZombie(i))
			{
				ZMTeleport(i);
			}
		}
	}
}

public Action StartBoss_OnTrigger(const char[] output, int caller, int activator, float delay)
{
	CreateBossSystems();
}

public Action Left_CrateWall_Trigger_OnStartTouch(const char[] output, int caller, int activator, float delay)
{
	ServerSay("Com", ">> The left crate wall has been disabled. <<");
	ForceEntityInput("left_cratewall_2", "Kill");
	if(oneDone != true)
	{
		oneDone = true;
	}
	else
	{
		ForceEntityInput("zm_relay", "Trigger");
	}
	return Plugin_Stop;
}

public Action Right_CrateWall_Button_OnPressed(const char[] output, int caller, int activator, float delay)
{
	ServerSay("Com", ">> The right crate wall has been disabled. <<");
	ForceEntityInput("right_cratewall_2", "Kill");
	if(oneDone != true)
	{
		oneDone = true;
	}
	else
	{
		ForceEntityInput("zm_relay", "Trigger");
	}
	return Plugin_Stop;
}

public void CreateSounds()
{
	CreateAmbientGeneric("sephiroth_goodbye", "music/antiteal/seph_saygoodbye.mp3");
	CreateAmbientGeneric("sephiroth_seeyouagain", "music/antiteal/seph_seeyouagain.mp3");
	CreateAmbientGeneric("sephiroth_dodgethis", "music/antiteal/seph_dodgethis.mp3");
	CreateAmbientGeneric("sephiroth_impressive", "music/antiteal/seph_impressive.mp3");
	CreateAmbientGeneric("sephiroth_seems", "music/antiteal/seph_seems.mp3");
	CreateAmbientGeneric("sephiroth_defeated", "music/antiteal/seph_defeated.mp3");

	CreateAmbientGeneric("blade_out", "music/antiteal/laser.mp3");
	CreateAmbientGeneric("victory", "music/antiteal/ffvii_victory.mp3");

	CreateAmbientGeneric("crush", "music/antiteal/crush.mp3");
	CreateAmbientGeneric("thatperson", "music/antiteal/thatpersonsnameis_v2.mp3");
	CreateAmbientGeneric("providence", "music/antiteal/providence2.mp3");
	CreateAmbientGeneric("tiz", "music/antiteal/tiz2_v2.mp3");
}

public void CreateParticles()
{
	//CreateParticle("particle_001", "custom_particle_001", "-10286 12138 5700");
	//CreateParticle("particle_001", "custom_particle_001", "-10286 12138 5700");
	//CreateParticle("particle_001", "custom_particle_001", "-10286 12138 5700");
	//CreateParticle("particle_001", "custom_particle_001", "-10286 12138 5700");

	CreateParticle("particle_002", "custom_particle_002", "-10286 12138 5700");
	CreateParticle("seph_fireparticle_1", "custom_particle_003", "3487 -2873 17");
	CreateParticle("seph_fireparticle_2", "custom_particle_003", "4543 -2873 17");
	CreateParticle("seph_fireparticle_3", "custom_particle_003", "3487 -3923 17");
	CreateParticle("seph_fireparticle_4", "custom_particle_003", "4543 -3923 17");
}

public void SpawnWalls()
{
	int prop = SpawnEntityByName("prop_dynamic", "extreme_rockwall_1");
	DispatchKeyValue(prop, "angles", "0 270 0");
	DispatchKeyValue(prop, "origin", "5296 3294 124");
	DispatchKeyValue(prop, "model", "models/props/cs_militia/rockwall.mdl");
	DispatchKeyValue(prop, "solid", "6");
	DispatchSpawn(prop);

	int prop2 = SpawnEntityByName("prop_dynamic", "extreme_rockwall_2_1");
	DispatchKeyValue(prop2, "angles", "0 90 0");
	DispatchKeyValue(prop2, "origin", "5698 6110 240");
	DispatchKeyValue(prop2, "model", "models/props/cs_militia/rockwall.mdl");
	DispatchKeyValue(prop2, "solid", "6");
	DispatchSpawn(prop2);

	int prop3 = SpawnEntityByName("prop_dynamic", "extreme_rockwall_2_2");
	DispatchKeyValue(prop3, "angles", "0 270 0");
	DispatchKeyValue(prop3, "origin", "6077 6110 240");
	DispatchKeyValue(prop3, "model", "models/props/cs_militia/rockwall.mdl");
	DispatchKeyValue(prop3, "solid", "6");
	DispatchSpawn(prop3);

	int prop4 = SpawnEntityByName("prop_dynamic", "icehold_rockwall");
	DispatchKeyValue(prop4, "angles", "0 0 0");
	DispatchKeyValue(prop4, "origin", "5666 4260 160");
	DispatchKeyValue(prop4, "model", "models/props/cs_militia/rockwall.mdl");
	DispatchKeyValue(prop4, "solid", "6");
	DispatchSpawn(prop4);
}

public void BurnBridges()
{
	int HammerIDs[] = {
		8467, 8470, 8473, 8476, 8479, 8482, 8485, 8488, 8491, 8494, 8497, 8500, 8503, 8506, 8509, 8512, 8515, 8518, 8521, 8524, 8527, 8530, 8533, 8536, 8539, 8542, 8545, 8548, 8551, 8554, 8557, 8560, 8563, 8566,
		25842, 25845, 25848, 25851, 25854, 25857, 25860, 25863, 25866, 25869, 25872, 25875, 25878, 25881, 25884, 25887, 25890, 25893, 25896, 25899, 25902, 25905, 25908, 25911, 25914, 25917, 25920, 25923, 25926, 25929, 25932, 25935, 25938, 25941
	};
	for(int i = 0; i < sizeof(HammerIDs); i++)
	{
		int ent = GetEntityFromHammerID(HammerIDs[i]);
		if(ent != -1 && IsValidEntity(ent))
		{
			char szBuffer[64];
			Format(szBuffer, sizeof(szBuffer), "extreme_bridge&%i", HammerIDs[i]);
			GiveIDTargetname(ent, szBuffer);
			ForceEntityInput(szBuffer, "AddHealth", "99999");
			int igniter = SpawnEntityByName("env_entity_igniter", "extreme_bridge_igniter");
			DispatchKeyValue(igniter, "target", szBuffer);
			DispatchKeyValue(igniter, "lifetime", "9999");
			DispatchSpawn(igniter);
		}
	}

	ForceEntityInput("extreme_bridge_igniter", "Ignite");

	float origin[3] = {4351.5, 768.0, 181.5};
	float min[3] = {-79.5, -480.0, 0.0};
	float max[3] = {79.5, 480.0, 171.0};

	int hurt = CreateBrushEntity("trigger_hurt", origin, min, max);
	DispatchKeyValue(hurt, "spawnflags", "1");
	DispatchKeyValue(hurt, "damage", "100000");

	float origin2[3] = {5216.0, 6912.0, 166.5};
	float min2[3] = {-80.0, -480.0, 0.0};
	float max2[3] = {80.0, 480.0, 141.0};

	int hurt2 = CreateBrushEntity("trigger_hurt", origin2, min2, max2);
	DispatchKeyValue(hurt2, "spawnflags", "1");
	DispatchKeyValue(hurt2, "damage", "100000");
}
/*
public void CreateHeal1()
{
	int heal = SpawnEntityByName("weapon_deagle", "Heal1_Deagle");
	DispatchKeyValue(heal, "origin", "416 3173 176");
	DispatchKeyValue(heal, "spawnflags", "1");
	DispatchKeyValue(heal, "ammo", "6969");

	float origin[3] = {435.0, 3173.0, 187.0};
	float min[3] = {-2.0, -21.0, 0.0};
	float max[3] = {2.0, 21.0, 52.0};
	int button = CreateBrushEntity("func_button", origin, min, max);

	GiveIDTargetname(button, "Heal1_Button");
	DispatchKeyValue(button, "spawnflags", "1025");

	DispatchSpawn(heal);
	DispatchSpawn(button);

	ActivateEntity(heal);
	ActivateEntity(button);

	ParentToEntity(button, heal);

	HookSingleEntityOutput(heal, "OnPlayerPickup", Heal1_Deagle_OnPlayerPickup, false);
	HookSingleEntityOutput(button, "OnPressed", Heal1_Button_OnPressed, false);
}

public Action Heal1_Deagle_OnPlayerPickup(const char[] output, int caller, int activator, float delay)
{
	if(!IsValidClient(activator) && Player_Heal1 != activator)
	{
		return Plugin_Handled;
	}

	Player_Heal1 = activator;
	char szBuffer[256];
	char szName[64];
	GetClientName(activator, szName, sizeof(szName));
	ReplaceString(szName, sizeof(szName), ";", "", false);
	Format(szBuffer, sizeof(szBuffer), "say >> Player %s has picked up Heal #1.", szName);
	ServerCommand(szBuffer);

	int weapon = GetPlayerWeaponSlot(activator, 1);
	if (IsValidEntity(weapon))
	{
		int ammoType = GetEntProp(weapon, Prop_Send, "m_iPrimaryAmmoType");
		if (ammoType != -1)
		{
			SetEntProp(activator, Prop_Send, "m_iAmmo", 6969, _, ammoType);
		}
	} 

	return Plugin_Handled;
}

public Action Heal1_Button_OnPressed(const char[] output, int caller, int activator, float delay)
{
	if(!IsValidClient(activator))
	{
		return Plugin_Handled;
	}

	if(Player_Heal1 == activator)
	{
		ServerCommand("say >> Heal #1 has been used!");
	}

	return Plugin_Handled;
}
*/
public Action LaserTest(int client, int argc)
{
	float origin[3], angles[3];
	GetClientAbsOrigin(client, origin);
	GetClientAbsAngles(client, angles);
	PrintToChat(client, "origin: %f %f %f | angles: %f %f %f", origin[0], origin[1], origin[2], angles[0], angles[1], angles[2]);
	SpawnLaser(origin, angles, RANDOM, "1500", "4000", 1);
	return Plugin_Handled;
}

public Action BossTest(int client, int argc)
{
	Create_SephPart2();
	return Plugin_Handled;
}

public void SpawnLaser(float origin[3], float angles[3], LaserType type, const char[] speed, const char[] movedistance, int dmg)
{
	laserDamage = dmg;
	angles[0] += 180.0;
	angles[1] += 180.0;
	angles[2] = 0.0;

	if(type == CROUCH)
	{
		origin[2] += 60.0;
	}
	else if(type == JUMP)
	{
		origin[2] += 30.0;
	}
	else if(type == LEFT)
	{
		origin[2] += 30.0;
		angles[2] = -15.0;
	}
	else if(type == RIGHT)
	{
		origin[2] += 30.0;
		angles[2] = 15.0;
	}
	else if(type == RANDOM)
	{
		int r = GetRandomInt(0, 3);
		if(r == 0){origin[2] += 60.0;}
		if(r == 1){origin[2] += 30.0;}
		if(r == 2){origin[2] += 30.0;angles[2] = -15.0;}
		if(r == 3){origin[2] += 30.0;angles[2] = 15.0;}
	}

	int num = GetRandomInt(0, 999);
	char szOrigin[64];
	Format(szOrigin, sizeof(szOrigin), "%.2f %.2f %.2f", origin[0], origin[1], origin[2]);

	char szAngles[64];
	Format(szAngles, sizeof(szAngles), "%.2f %.2f %.2f", angles[0], angles[1], angles[2]);

	char laserTargetname[64];
	Format(laserTargetname, sizeof(laserTargetname), "Laser_PropDynamic&%i", num);
	char moveTargetname[64];
	Format(moveTargetname, sizeof(moveTargetname), "Laser_MoveLinear&%i", num);

	int prop = SpawnEntityByName("prop_dynamic", laserTargetname);
	DispatchKeyValue(prop, "angles", szAngles);
	DispatchKeyValue(prop, "origin", szOrigin);
	DispatchKeyValue(prop, "renderfx", "5");
	DispatchKeyValue(prop, "rendercolor", "0 150 255");
	SetEntProp(prop, Prop_Send, "m_usSolidFlags", 0x0008);
	SetEntProp(prop, Prop_Data, "m_nSolidType", 6);
	SetEntProp(prop, Prop_Send, "m_CollisionGroup", 2);
	DispatchKeyValue(prop, "model", "models/antiteal/thelaser/icecap_laser.mdl");
	DispatchSpawn(prop);

	int move = CreateEntityByName("func_movelinear");
	DispatchKeyValue(move, "targetname", moveTargetname);
	DispatchKeyValue(move, "startposition", "0");
	DispatchKeyValue(move, "speed", speed);
	DispatchKeyValue(move, "spawnflags", "8");
	DispatchKeyValue(move, "movedistance", movedistance);
	DispatchKeyValue(move, "movedir", szAngles);

	GiveEntityOutput(moveTargetname, "OnFullyOpen", "!self", "Kill");
	DispatchSpawn(move);
	ParentToEntity(prop, move);
	SDKHook(prop, SDKHook_StartTouch, OnLaserTouch); 
	ForceEntityInput(moveTargetname, "Open");
}

public void OnLaserTouch(int entity, int client)
{
	if(!IsValidClient(client) || !IsPlayerAlive(client))
	{
		return;
	}    

	if(ZR_IsClientHuman(client) && !stopTouch[client])
	{
		stopTouch[client] = true;
		CreateTimer(0.4, ResetTouch, GetClientSerial(client));

		int health = GetClientHealth(client) - laserDamage;
		if(health <= 0)
		{
			ForcePlayerSuicide(client);
		}
		else
		{
			SetEntityHealth(client, health);
		}
	}
}

public Action ResetTouch(Handle timer, any serial)
{
	int client = GetClientFromSerial(serial);

	if (client == 0) 
	{
		return Plugin_Stop;
	}

	stopTouch[client] = false;

	return Plugin_Handled;
}

public void Sephiroth_Part1()
{
	int relay = SpawnEntityByName("logic_relay", "sephiroth_part1_relay");
	int prop = SpawnEntityByName("prop_dynamic", "sephiroth_part1_model");

	DispatchKeyValue(prop, "angles", "90 270 0");
	DispatchKeyValue(prop, "origin", "350 3030 130");
	DispatchKeyValue(prop, "spawnflags", "0");
	DispatchKeyValue(prop, "solid", "0");
	DispatchKeyValue(prop, "disableshadows", "1");
	DispatchKeyValue(prop, "disablereceiveshadows", "1");
	DispatchKeyValue(prop, "DisableBoneFollowers", "1");

	ForceEntityInput("sephiroth_part1_model", "DisableCollision");
	ForceEntityInput("sephiroth_part1_model", "Disable");
	ForceEntityInput("sephiroth_part1_model", "SetAnimation", "idle");
	ForceEntityInput("sephiroth_part1_model", "SetDefaultAnimation", "idle");
	DispatchKeyValue(prop, "model", "models/antiteal/icecap/sephiroth.mdl");
	DispatchSpawn(prop);

	float origin[3] = {376.0, 1688.0, 131.0};
	float min[3] = {-136.0, -24.0, 0.0};
	float max[3] = {136.0, 24.0, 102.0};

	int ent = CreateBrushEntity("trigger_once", origin, min, max);

	GiveIDTargetname(ent, "sephiroth_part1_trigger");
	GiveEntityOutput("sephiroth_part1_trigger", "OnStartTouch", "sephiroth_part1_relay", "Trigger");

	GiveEntityOutput("sephiroth_part1_relay", "OnTrigger", "sephiroth_part1_model", "Enable");

	GiveEntityOutput("sephiroth_part1_relay", "OnTrigger", "sephiroth_part1_model", "SetAnimation", "attack1", "1");
	GiveEntityOutput("sephiroth_part1_relay", "OnTrigger", "sephiroth_goodbye", "PlaySound", "", "1");
	GiveEntityOutput("sephiroth_part1_relay", "OnTrigger", "Com", "Command", "say >> Say goodbye!", "1");
	GiveEntityOutput("sephiroth_part1_relay", "OnTrigger", "blade_out", "PlaySound", "", "1");

	HookSingleEntityOutput(relay, "OnTrigger", Seph1Relay_OnTrigger, false);

	GiveEntityOutput("sephiroth_part1_relay", "OnTrigger", "Com", "Command", "say >> I'll see you again.", "4");
	GiveEntityOutput("sephiroth_part1_relay", "OnTrigger", "extreme_fade1", "fade", "", "4");
	GiveEntityOutput("sephiroth_part1_relay", "OnTrigger", "sephiroth_part1_model", "Disable", "", "4.5");
	GiveEntityOutput("sephiroth_part1_relay", "OnTrigger", "sephiroth_seeyouagain", "PlaySound", "", "4.5");

	GiveEntityOutput("sephiroth_part1_relay", "OnTrigger", "cratewall_relay", "Trigger", "", "5.0");

	SpawnEntityByName("logic_relay", "cratewall_relay");
	int ztele = SpawnEntityByName("logic_relay", "ztele1_relay");

	GiveEntityOutput("cratewall_relay", "OnTrigger", "Com", "Command", "say >> Pathways will open in 30 seconds... <<");
	GiveEntityOutput("cratewall_relay", "OnTrigger", "Com", "Command", "say >> Zombies teleporting to crystals in 15 seconds... <<", "2.5");
	GiveEntityOutput("cratewall_relay", "OnTrigger", "ztele1_relay", "Trigger", "", "17.5");
	GiveEntityOutput("cratewall_relay", "OnTrigger", "Com", "Command", "say >> Pathways will open in 15 seconds... <<", "15.0");
	GiveEntityOutput("cratewall_relay", "OnTrigger", "Com", "Command", "say >> Pathways will open in 5 seconds... <<", "25.0");

	GiveEntityOutput("cratewall_relay", "OnTrigger", "extreme_fade1", "fade", "", "30");
	GiveEntityOutput("cratewall_relay", "OnTrigger", "left_cratewall_1", "Kill", "", "30.5");
	GiveEntityOutput("cratewall_relay", "OnTrigger", "right_cratewall_1", "Kill", "", "30.5");

	HookSingleEntityOutput(ztele, "OnTrigger", ztele1_relay_OnTrigger, false);
}

public void ztele1_relay_OnTrigger(const char[] output, int caller, int activator, float delay)
{
	ZTeleOrigin[0][0] =	1265.0; 
	ZTeleOrigin[0][1] =	3153.0; 
	ZTeleOrigin[0][2] =	192.0;

	ZTeleAngles[0][0] = 0.0;
	ZTeleAngles[0][1] =	0.0;
	ZTeleAngles[0][2] =	0.0;

	ZTeleOrigin[1][0] =	1271.0; 
	ZTeleOrigin[1][1] =	4513.0; 
	ZTeleOrigin[1][2] =	192.0;

	ZTeleAngles[1][0] = 0.0;
	ZTeleAngles[1][1] =	0.0;
	ZTeleAngles[1][2] =	0.0;

	float origin[3] = {-256.0, 2312.0, 0.0};
	float min[3] = {-895.0, -2435.0, 0.0};
	float max[3] = {895.0, 2435.0, 751.0};

	int ent = CreateBrushEntity("trigger_teleport", origin, min, max);
	GiveIDTargetname(ent, "ztele1_trigger");
	GiveEntityOutput("ztele1_trigger", "OnStartTouch", "ztele_relay", "Trigger");
}

public void Seph1Relay_OnTrigger(const char[] output, int caller, int activator, float delay)
{
	Seph1Laser_TimerHandle = CreateTimer(1.0, SephLasers_Part1);
}

public Action SephLasers_Part1(Handle timer, any data)
{
	char szHP[8];
	int baseHP = 250;
	int HP = baseHP * HumanCount();

	IntToString(HP, szHP, sizeof(szHP));

	DispatchKeyValue(GetEntityFromTargetname("Block"), "health", szHP);
	DispatchKeyValue(GetEntityFromTargetname("Block2"), "health", szHP);

	GiveHammerIDTargetname(114641, "Block_Breakable");
	GiveHammerIDTargetname(115874, "Block2_Breakable");

	DispatchKeyValue(GetEntityFromTargetname("Block_Breakable"), "health", szHP);
	DispatchKeyValue(GetEntityFromTargetname("Block2_Breakable"), "health", szHP);

	float origin[3] = {418.0, 3065.0, 140.0};
	float angles[3] = {180.0, 90.0, 0.0};
	SpawnLaser(origin, angles, RANDOM, "1500", "4000", 9999);
	Seph1Laser_TimerHandle = INVALID_HANDLE;
}

public void Create_IceHold()
{
	float origin[3] = {5681.0, 3054.0, 200.0};
	float min[3] = {-15.0, -285.0, 0.0};
	float max[3] = {15.0, 285.0, 256.0};

	int ent = CreateBrushEntity("trigger_once", origin, min, max);
	GiveIDTargetname(ent, "icehold_trigger");

	int relay = SpawnEntityByName("logic_relay", "ztele2_relay");

	GiveEntityOutput("icehold_trigger", "OnStartTouch", "Com", "Command", "say >> Defend here for 30 seconds... <<");
	GiveEntityOutput("icehold_trigger", "OnStartTouch", "Com", "Command", "say >> Zombies teleporting in 5 seconds... <<", "10.0");
	GiveEntityOutput("icehold_trigger", "OnStartTouch", "ztele2_relay", "Trigger", "", "15.0");
	GiveEntityOutput("icehold_trigger", "OnStartTouch", "Com", "Command", "say >> Defend here for 10 seconds... <<", "20.0");
	GiveEntityOutput("icehold_trigger", "OnStartTouch", "Com", "Command", "say >> Defend here for 5 seconds... <<", "25.0");
	GiveEntityOutput("icehold_trigger", "OnStartTouch", "extreme_fade1", "Fade", "", "30.0");
	GiveEntityOutput("icehold_trigger", "OnStartTouch", "icehold_rockwall", "Kill", "", "30.5");

	HookSingleEntityOutput(relay, "OnTrigger", ztele2_relay_OnTrigger, false);
}

public void ztele2_relay_OnTrigger(const char[] output, int caller, int activator, float delay)
{
	ZTeleOrigin[0][0] =	5216.0; 
	ZTeleOrigin[0][1] =	2226.0; 
	ZTeleOrigin[0][2] =	192.0;

	ZTeleAngles[0][0] = 0.0;
	ZTeleAngles[0][1] =	90.0;
	ZTeleAngles[0][2] =	0.0;

	ZTeleOrigin[1][0] =	6556.0; 
	ZTeleOrigin[1][1] =	2237.0; 
	ZTeleOrigin[1][2] =	192.0;

	ZTeleAngles[1][0] = 0.0;
	ZTeleAngles[1][1] =	90.0;
	ZTeleAngles[1][2] =	0.0;

	float origin[3] = {2736.5, 2447.0, 117.5};
	float min[3] = {-2204.5, -2580.0, 0.0};
	float max[3] = {2204.5, 2580.0, 773.0};

	int ent = CreateBrushEntity("trigger_teleport", origin, min, max);
	GiveIDTargetname(ent, "ztele2_trigger");
	GiveEntityOutput("ztele2_trigger", "OnStartTouch", "ztele_relay", "Trigger");

	float origin2[3] = {5901.0, 698.5, 117.5};
	float min2[3] = {-1089.0, -831.5, 0.0};
	float max2[3] = {1089.0, 831.5, 773.0};

	int ent2 = CreateBrushEntity("trigger_teleport", origin2, min2, max2);
	GiveIDTargetname(ent2, "ztele2_trigger_2");
	GiveEntityOutput("ztele2_trigger_2", "OnStartTouch", "ztele_relay", "Trigger");
}

public Action ztele3_trigger_OnStartTouch(const char[] output, int caller, int activator, float delay)
{
	SpawnEntityByName("logic_relay", "ztele3_relay");
	int relay2 = SpawnEntityByName("logic_relay", "ztele3_relay_2");
	HookSingleEntityOutput(relay2, "OnTrigger", ztele3_relay_2_OnTrigger, false);
	GiveEntityOutput("ztele3_relay", "OnTrigger", "Com", "Command", "say >> Zombies teleporting in 15 seconds... <<");
	GiveEntityOutput("ztele3_relay", "OnTrigger", "Com", "Command", "say >> Zombies teleporting in 5 seconds... <<", "10.0");
	GiveEntityOutput("ztele3_relay", "OnTrigger", "ztele3_relay_2", "Trigger", "", "15.0");
	ForceEntityInput("ztele3_relay", "Trigger");
	return Plugin_Stop;
}

public void ztele3_relay_2_OnTrigger(const char[] output, int caller, int activator, float delay)
{
	ZTeleOrigin[0][0] =	5226.0; 
	ZTeleOrigin[0][1] =	6240.0; 
	ZTeleOrigin[0][2] =	192.0;

	ZTeleAngles[0][0] = 0.0;
	ZTeleAngles[0][1] =	180.0;
	ZTeleAngles[0][2] =	0.0;

	ZTeleOrigin[1][0] =	5227.0; 
	ZTeleOrigin[1][1] =	7590.0; 
	ZTeleOrigin[1][2] =	192.0;

	ZTeleAngles[1][0] = 0.0;
	ZTeleAngles[1][1] =	180.0;
	ZTeleAngles[1][2] =	0.0;

	float origin[3] = {5943.0, 2891.0, 128.0};
	float min[3] = {-1205.0, -3040.0, 0.0};
	float max[3] = {1205.0, 3040.0, 768.0};

	int ent = CreateBrushEntity("trigger_teleport", origin, min, max);
	GiveIDTargetname(ent, "ztele3_trigger_teleport");
	GiveEntityOutput("ztele3_trigger_teleport", "OnStartTouch", "ztele_relay", "Trigger");
}

public void ZMInit()
{
	int HammerIDs[] = {
		49954, 50847, 50865, 50883,
		51027, 51009, 50991, 50973
	};
	for(int i = 0; i < sizeof(HammerIDs); i++)
	{
		int platform = GetEntityFromHammerID(HammerIDs[i]);
		if(platform != -1 && IsValidEntity(platform))
		{
			AcceptEntityInput(platform, "Kill");
		}
	}

	int breakable = GetEntityFromHammerID(53009);
	GiveIDTargetname(breakable, "ZMBreakable");
	ForceEntityInput("ZMBreakable", "SetHealth", "999999999");

	int relay = SpawnEntityByName("logic_relay", "ztele4_relay");
	int relay2 = SpawnEntityByName("logic_relay", "freeze_relay");
	int relay3 = SpawnEntityByName("logic_relay", "freezeoff_relay");

	SpawnEntityByName("logic_relay", "zm_relay");
	GiveEntityOutput("zm_relay", "OnTrigger", "Com", "Command", "say >> Defend this area for 45 seconds... <<");
	GiveEntityOutput("zm_relay", "OnTrigger", "Com", "Command", "say >> Zombies teleporting in 5 seconds... <<", "5.0");
	GiveEntityOutput("zm_relay", "OnTrigger", "ztele4_relay", "Trigger", "", "10.0");

	GiveEntityOutput("zm_relay", "OnTrigger", "Com", "Command", "say >> Defend for 30 seconds... <<", "15.0");
	GiveEntityOutput("zm_relay", "OnTrigger", "Com", "Command", "say >> Defend for 15 seconds... <<", "30.0");
	GiveEntityOutput("zm_relay", "OnTrigger", "Com", "Command", "say >> Defend for 5 seconds... <<", "40.0");

	GiveEntityOutput("zm_relay", "OnTrigger", "extreme_fade1", "Fade", "", "45.0");
	GiveEntityOutput("zm_relay", "OnTrigger", "Com", "Command", "say >> Zombies are frozen for 10 seconds! <<", "45.0");

	char szHP[8];
	int baseHP = 750;
	int HP = baseHP * HumanCount();

	IntToString(HP, szHP, sizeof(szHP));

	GiveEntityOutput("zm_relay", "OnTrigger", "ZMBreakable", "SetHealth", szHP, "45.0");
	GiveEntityOutput("zm_relay", "OnTrigger", "freeze_relay", "Trigger", "", "45.0");

	GiveEntityOutput("zm_relay", "OnTrigger", "freezeoff_relay", "Trigger", "", "65.0");

	HookSingleEntityOutput(relay, "OnTrigger", ztele4_relay_OnTrigger, false);
	HookSingleEntityOutput(relay2, "OnTrigger", freeze_relay_OnTrigger, false);
	HookSingleEntityOutput(relay3, "OnTrigger", freezeoff_relay_OnTrigger, false);
	HookSingleEntityOutput(breakable, "OnBreak", ZMBreakable_OnBreak, false);
}

public void ztele4_relay_OnTrigger(const char[] output, int caller, int activator, float delay)
{
	ZTeleOrigin[0][0] =	-2099.0; 
	ZTeleOrigin[0][1] =	7568.0; 
	ZTeleOrigin[0][2] =	64.0;

	ZTeleAngles[0][0] = 0.0;
	ZTeleAngles[0][1] =	180.0;
	ZTeleAngles[0][2] =	0.0;

	ZTeleOrigin[1][0] =	-2065.0; 
	ZTeleOrigin[1][1] =	6234.0; 
	ZTeleOrigin[1][2] =	127.0;

	ZTeleAngles[1][0] = 0.0;
	ZTeleAngles[1][1] =	180.0;
	ZTeleAngles[1][2] =	0.0;

	float origin[3] = {2727.0, 6875.0, 64.0};
	float min[3] = {-4396.0, -1105.0, 0.0};
	float max[3] = {4396.0, 1105.0, 768.0};

	int ent = CreateBrushEntity("trigger_teleport", origin, min, max);
	GiveIDTargetname(ent, "ztele4_trigger");
	GiveEntityOutput("ztele4_trigger", "OnStartTouch", "ztele_relay", "Trigger");
}

public void freeze_relay_OnTrigger(const char[] output, int caller, int activator, float delay)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			if(ZR_IsClientZombie(i))
			{
				SetVariantFloat(0.0);
				AcceptEntityInput(speedmod, "ModifySpeed", i, i);
				ZMTeleport(i);
			}
		}
	}
}

public void freezeoff_relay_OnTrigger(const char[] output, int caller, int activator, float delay)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			if(ZR_IsClientZombie(i))
			{
				SetVariantFloat(1.0);
				AcceptEntityInput(speedmod, "ModifySpeed", i, i);
			}
		}
	}
}

public void ZMBreakable_OnBreak(const char[] output, int caller, int activator, float delay)
{
	int relay = SpawnEntityByName("logic_relay", "sephiroth_part2_relay");
	int prop = SpawnEntityByName("prop_dynamic", "sephiroth_part2_model");

	DispatchKeyValue(prop, "angles", "90 90 0");
	DispatchKeyValue(prop, "origin", "-3314 3921 0");
	DispatchKeyValue(prop, "spawnflags", "0");
	DispatchKeyValue(prop, "solid", "0");
	DispatchKeyValue(prop, "disableshadows", "1");
	DispatchKeyValue(prop, "disablereceiveshadows", "1");
	DispatchKeyValue(prop, "DisableBoneFollowers", "1");

	ForceEntityInput("sephiroth_part2_model", "DisableCollision");
	ForceEntityInput("sephiroth_part2_model", "Enable");
	ForceEntityInput("sephiroth_part2_model", "SetAnimation", "idle");
	ForceEntityInput("sephiroth_part2_model", "SetDefaultAnimation", "idle");
	DispatchKeyValue(prop, "model", "models/antiteal/icecap/sephiroth.mdl");
	DispatchSpawn(prop);

	GiveEntityOutput("sephiroth_part2_relay", "OnTrigger", "sephiroth_part2_model", "Enable");

	GiveEntityOutput("sephiroth_part2_relay", "OnTrigger", "sephiroth_part2_model", "SetAnimation", "attack1", "1");
	GiveEntityOutput("sephiroth_part2_relay", "OnTrigger", "sephiroth_dodgethis", "PlaySound", "", "1");
	GiveEntityOutput("sephiroth_part2_relay", "OnTrigger", "Com", "Command", "say >> Dodge this!", "1");
	GiveEntityOutput("sephiroth_part2_relay", "OnTrigger", "blade_out", "PlaySound", "", "1");

	HookSingleEntityOutput(relay, "OnTrigger", Seph2Relay_OnTrigger, false);

	GiveEntityOutput("sephiroth_part2_relay", "OnTrigger", "Com", "Command", "say >> Impressive...", "4");
	GiveEntityOutput("sephiroth_part2_relay", "OnTrigger", "extreme_fade1", "fade", "", "4");
	GiveEntityOutput("sephiroth_part2_relay", "OnTrigger", "sephiroth_part2_model", "Disable", "", "4.5");
	GiveEntityOutput("sephiroth_part2_relay", "OnTrigger", "sephiroth_impressive", "PlaySound", "", "4.5");

	ForceEntityInput("sephiroth_part2_relay", "Trigger");
}

public void Seph2Relay_OnTrigger(const char[] output, int caller, int activator, float delay)
{
	Seph2Laser_TimerHandle = CreateTimer(1.0, SephLasers_Part2);
}

public Action SephLasers_Part2(Handle timer, any data)
{
	float origin[3] = {-3327.0, 3887.0, 0.0};
	float angles[3] = {0.0, 90.0, 0.0};
	SpawnLaser(origin, angles, CROUCH, "2000", "4000", 9999);
	Seph2Laser_TimerHandle = INVALID_HANDLE;
}

public Action ztele5_trigger_OnStartTouch(const char[] output, int caller, int activator, float delay)
{
	SpawnEntityByName("logic_relay", "ztele5_relay");
	int relay2 = SpawnEntityByName("logic_relay", "ztele5_relay_2");
	HookSingleEntityOutput(relay2, "OnTrigger", ztele5_relay_2_OnTrigger, false);
	GiveEntityOutput("ztele5_relay", "OnTrigger", "Com", "Command", "say >> Zombies teleporting in 15 seconds... <<");
	GiveEntityOutput("ztele5_relay", "OnTrigger", "Com", "Command", "say >> Zombies teleporting in 5 seconds... <<", "10.0");
	GiveEntityOutput("ztele5_relay", "OnTrigger", "ztele5_relay_2", "Trigger", "", "15.0");
	ForceEntityInput("ztele5_relay", "Trigger");
	return Plugin_Stop;
}

public Action ztele5_relay_2_OnTrigger(const char[] output, int caller, int activator, float delay)
{
	ZTeleOrigin[0][0] =	-3340.0; 
	ZTeleOrigin[0][1] =	-1985.0; 
	ZTeleOrigin[0][2] =	252.0;

	ZTeleAngles[0][0] = 10.0;
	ZTeleAngles[0][1] =	0.0;
	ZTeleAngles[0][2] =	0.0;

	ZTeleOrigin[1][0] =	-2465.0; 
	ZTeleOrigin[1][1] =	-2788.0; 
	ZTeleOrigin[1][2] =	192.0;

	ZTeleAngles[1][0] = 7.0;
	ZTeleAngles[1][1] =	70.0;
	ZTeleAngles[1][2] =	0.0;

	float origin[3] = {-2969.0, 3487.5, 0.0};
	float min[3] = {-1302.0, -4495.5, 0.0};
	float max[3] = {1302.0, 4495.5, 704.0};

	int ent = CreateBrushEntity("trigger_teleport", origin, min, max);
	GiveIDTargetname(ent, "ztele5_trigger_teleport");
	GiveEntityOutput("ztele5_trigger_teleport", "OnStartTouch", "ztele_relay", "Trigger");
}

public int GetRandomAlivePlayer(int team) {
	int[] clients = new int[MaxClients+1];
	int clientCount;
	for (int i = 1; i <= MaxClients; i++)
	if (IsClientInGame(i) && (GetClientTeam(i) == team) && IsPlayerAlive(i))
	clients[clientCount++] = i;
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)];
}  

public void CreateBossSystems() 
{
	ForceEntityInput("crush", "FadeOut", "1");
	ForceEntityInput("thatperson", "PlaySound");

	isMeteor = false;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && IsPlayerAlive(i))
		{
			if(ZR_IsClientHuman(i))
			{
				SetEntityHealth(i, 150);
			}
		}
	}

	counter = 0;
	counter2 = 0;

	createTimer = true;

	int arena = SpawnEntityByName("prop_dynamic", "extreme_arena");
	DispatchKeyValue(arena, "angles", "0 0 0");
	DispatchKeyValue(arena, "origin", "4015 -3398 -45");
	DispatchKeyValue(arena, "model", "models/antiteal/icecap/arena_2.mdl");
	DispatchKeyValue(arena, "solid", "6");
	DispatchSpawn(arena);

	int seph = SpawnEntityByName("prop_dynamic", "sephiroth_boss");
	DispatchKeyValue(seph, "angles", "90 0 0");
	DispatchKeyValue(seph, "origin", "4015 -3397 10");
	DispatchKeyValue(seph, "spawnflags", "0");
	SetEntProp(seph, Prop_Send, "m_usSolidFlags", 0x0008);
	SetEntProp(seph, Prop_Data, "m_nSolidType", 2);
	SetEntProp(seph, Prop_Send, "m_CollisionGroup", 2);
	ForceEntityInput("sephiroth_boss", "DisableCollision");
	ForceEntityInput("sephiroth_boss", "SetAnimation", "idle");
	ForceEntityInput("sephiroth_boss", "SetDefaultAnimation", "idle");
	DispatchKeyValue(seph, "model", "models/antiteal/icecap/sephiroth.mdl");
	DispatchSpawn(seph);

	int block1 = SpawnEntityByName("prop_dynamic", "zm_block1");
	DispatchKeyValue(block1, "angles", "0 90 0");
	DispatchKeyValue(block1, "origin", "5653 -3415 20");
	DispatchKeyValue(block1, "model", "models/props/de_nuke/hr_nuke/metal_crate_001/metal_crate_001_128x112x256.mdl");
	DispatchKeyValue(block1, "solid", "6");
	DispatchSpawn(block1);

	int block2 = SpawnEntityByName("prop_dynamic", "zm_block2");
	DispatchKeyValue(block2, "angles", "0 90 0");
	DispatchKeyValue(block2, "origin", "2377 -3415 20");
	DispatchKeyValue(block2, "model", "models/props/de_nuke/hr_nuke/metal_crate_001/metal_crate_001_128x112x256.mdl");
	DispatchKeyValue(block2, "solid", "6");
	DispatchSpawn(block2);

	int block3 = SpawnEntityByName("prop_dynamic", "human_block1");
	DispatchKeyValue(block3, "angles", "0 0 0");
	DispatchKeyValue(block3, "origin", "4015 -2219 -120");
	DispatchKeyValue(block3, "model", "models/props/de_nuke/hr_nuke/metal_crate_001/metal_crate_001_128x112x256.mdl");
	DispatchKeyValue(block3, "solid", "6");
	DispatchSpawn(block3);

	int block4 = SpawnEntityByName("prop_dynamic", "human_block2");
	DispatchKeyValue(block4, "angles", "0 0 0");
	DispatchKeyValue(block4, "origin", "4015 -4559 -120");
	DispatchKeyValue(block4, "model", "models/props/de_nuke/hr_nuke/metal_crate_001/metal_crate_001_128x112x256.mdl");
	DispatchKeyValue(block4, "solid", "6");
	DispatchSpawn(block4);

	ForceEntityInput("human_block1", "Disable");
	ForceEntityInput("human_block1", "DisableCollision");
	ForceEntityInput("human_block2", "Disable");
	ForceEntityInput("human_block2", "DisableCollision");

	int tesla = SpawnEntityByName("point_tesla", "seph_tesla");
	DispatchKeyValue(tesla, "thick_min", "70");
	DispatchKeyValue(tesla, "thick_max", "100");
	DispatchKeyValue(tesla, "texture", "sprites/physbeam.vmt");
	DispatchKeyValue(tesla, "m_SoundName", "DoSpark");
	DispatchKeyValue(tesla, "m_flRadius", "300");
	DispatchKeyValue(tesla, "m_Color", "0 0 255");
	DispatchKeyValue(tesla, "lifetime_min", "1");
	DispatchKeyValue(tesla, "lifetime_max", "1");
	DispatchKeyValue(tesla, "beamcount_min", "50");
	DispatchKeyValue(tesla, "beamcount_max", "50");
	DispatchKeyValue(tesla, "origin", "4015 -3397 45");

	ParentToEntity(tesla, seph);

	SpawnEntityByName("logic_relay", "boss_intro");
	int start = SpawnEntityByName("logic_relay", "boss_start");
	SpawnEntityByName("logic_relay", "boss_timer");
	int end = SpawnEntityByName("logic_relay", "boss_end");

	GiveEntityOutput("boss_intro", "OnTrigger", "extreme_fade1", "Fade");

	GiveEntityOutput("boss_intro", "OnTrigger", "seph_tesla", "DoSpark", "", "2");
	GiveEntityOutput("boss_intro", "OnTrigger", "seph_tesla", "AddOutput", "m_Color 0 255 0", "3");
	GiveEntityOutput("boss_intro", "OnTrigger", "seph_tesla", "DoSpark", "", "6");
	GiveEntityOutput("boss_intro", "OnTrigger", "seph_tesla", "AddOutput", "m_Color 255 0 0", "7");
	GiveEntityOutput("boss_intro", "OnTrigger", "seph_tesla", "DoSpark", "", "10");

	GiveEntityOutput("boss_intro", "OnTrigger", "extreme_fade1", "Fade", "", "12.5");
	GiveEntityOutput("boss_intro", "OnTrigger", "boss_start", "Trigger", "", "13");
	GiveEntityOutput("boss_intro", "OnTrigger", "boss_timer", "Trigger", "", "17");

	GiveEntityOutput("boss_timer", "OnTrigger", "Com", "Command", "say >> Survive for 150 seconds... <<", "0");
	GiveEntityOutput("boss_timer", "OnTrigger", "Com", "Command", "say >> Survive for 120 seconds... <<", "30");
	GiveEntityOutput("boss_timer", "OnTrigger", "Com", "Command", "say >> Survive for 90 seconds... <<", "60");
	GiveEntityOutput("boss_timer", "OnTrigger", "Com", "Command", "say >> Survive for 60 seconds... <<", "90");
	GiveEntityOutput("boss_timer", "OnTrigger", "Com", "Command", "say >> Survive for 30 seconds... <<", "120");
	GiveEntityOutput("boss_timer", "OnTrigger", "Com", "Command", "say >> Survive for 15 seconds... <<", "135");
	GiveEntityOutput("boss_timer", "OnTrigger", "Com", "Command", "say >> Survive for 5 seconds... <<", "145");

	GiveEntityOutput("boss_timer", "OnTrigger", "boss_end", "Trigger", "", "150");

	ForceEntityInput("boss_intro", "Trigger");

	isTargeting = false;
	SDKHook(seph, SDKHook_StartTouch, Seph_OnStartTouch);

	float humanPos[3] = {4841.0, -3399.0, 72.0}, humanAng[3] = {0.0, -180.0, 0.0};

	ZTeleOrigin[0][0] = 2371.0, ZTeleOrigin[0][1] = -3402.0, ZTeleOrigin[0][2] = 213.0;
	ZTeleAngles[0][0] = 0.0, ZTeleAngles[0][1] = 0.0, ZTeleAngles[0][2] = 0.0;
	ZTeleOrigin[1][0] = 5672.0, ZTeleOrigin[1][1] = -3408.0, ZTeleOrigin[1][2] = 212.0;
	ZTeleAngles[1][0] = 0.0, ZTeleAngles[1][1] = 180.0, ZTeleAngles[1][2] = 0.0;

	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i) && IsPlayerAlive(i))
		{
			if(ZR_IsClientHuman(i))
			{
				TeleportEntity(i, humanPos, humanAng, NULL_VECTOR);
			}
			else
			{
				ZMTeleport(i);
			}
		}
	}

	int ztelestart = SpawnEntityByName("logic_relay", "sephattack_ztele_start");
	int zteleend = SpawnEntityByName("logic_relay", "sephattack_ztele_end");

	float origin[3] = {3487.0, -2873.0, 17.0};
	float min[3] = {-528.0, -525.0, 0.0};
	float max[3] = {528.0, 525.0, 152.0};

	int hurt = CreateBrushEntity("trigger_hurt", origin, min, max);
	DispatchKeyValue(hurt, "spawnflags", "1");
	DispatchKeyValue(hurt, "damage", "40");
	DispatchKeyValue(hurt, "targetname", "seph_firehurt_1");
	DispatchKeyValue(hurt, "StartDisabled", "1");

	float origin2[3] = {4543.0, -2873.0, 17.0};
	int hurt2 = CreateBrushEntity("trigger_hurt", origin2, min, max);
	DispatchKeyValue(hurt2, "spawnflags", "1");
	DispatchKeyValue(hurt2, "damage", "40");
	DispatchKeyValue(hurt2, "targetname", "seph_firehurt_2");
	DispatchKeyValue(hurt2, "StartDisabled", "1");

	float origin3[3] = {3487.0, -3923.0, 17.0};
	int hurt3 = CreateBrushEntity("trigger_hurt", origin3, min, max);
	DispatchKeyValue(hurt3, "spawnflags", "1");
	DispatchKeyValue(hurt3, "damage", "40");
	DispatchKeyValue(hurt3, "targetname", "seph_firehurt_3");
	DispatchKeyValue(hurt3, "StartDisabled", "1");

	float origin4[3] = {4543.0, -3923.0, 17.0};
	int hurt4 = CreateBrushEntity("trigger_hurt", origin4, min, max);
	DispatchKeyValue(hurt4, "spawnflags", "1");
	DispatchKeyValue(hurt4, "damage", "40");
	DispatchKeyValue(hurt4, "targetname", "seph_firehurt_4");
	DispatchKeyValue(hurt4, "StartDisabled", "1");

	ForceEntityInput("seph_firehurt_1", "Disable");
	ForceEntityInput("seph_firehurt_2", "Disable");
	ForceEntityInput("seph_firehurt_3", "Disable");
	ForceEntityInput("seph_firehurt_4", "Disable");

	SpawnEntityByName("logic_relay", "attack_quake_relay");
	GiveEntityOutput("attack_quake_relay", "OnTrigger", "human_block1", "Enable");
	GiveEntityOutput("attack_quake_relay", "OnTrigger", "human_block2", "Enable");
	GiveEntityOutput("attack_quake_relay", "OnTrigger", "human_block1", "EnableCollision");
	GiveEntityOutput("attack_quake_relay", "OnTrigger", "human_block2", "EnableCollision");

	GiveEntityOutput("attack_quake_relay", "OnTrigger", "extreme_arena", "Disable", "", "6.0");
	GiveEntityOutput("attack_quake_relay", "OnTrigger", "extreme_arena", "DisableCollision", "", "6.0");
	GiveEntityOutput("attack_quake_relay", "OnTrigger", "extreme_shake1", "StartShake", "", "6.0");

	GiveEntityOutput("attack_quake_relay", "OnTrigger", "extreme_arena", "Enable", "", "10.0");
	GiveEntityOutput("attack_quake_relay", "OnTrigger", "extreme_arena", "EnableCollision", "", "10.0");

	GiveEntityOutput("attack_quake_relay", "OnTrigger", "human_block1", "Disable", "", "12.5");
	GiveEntityOutput("attack_quake_relay", "OnTrigger", "human_block2", "Disable", "", "12.5");
	GiveEntityOutput("attack_quake_relay", "OnTrigger", "human_block1", "DisableCollision", "", "12.5");
	GiveEntityOutput("attack_quake_relay", "OnTrigger", "human_block2", "DisableCollision", "", "12.5");
	GiveEntityOutput("attack_quake_relay", "OnTrigger", "boss_start", "Trigger", "", "12.5");

	HookSingleEntityOutput(start, "OnTrigger", StartBoss, false);
	HookSingleEntityOutput(end, "OnTrigger", EndBoss, false);
	HookSingleEntityOutput(ztelestart, "OnTrigger", SephAttack_ZTeleStart, false);
	HookSingleEntityOutput(zteleend, "OnTrigger", SephAttack_ZTeleEnd, false);

	bossTarget = GetRandomAlivePlayer(3);
}

public Action SephTimer(Handle timer, any data)
{
	if(isTargeting)
	{
		counter++;
		if(counter == 2)
		{
			counter = 0;
			counter2++;
			bossTarget = GetRandomAlivePlayer(3);
		}

		char szNum[32];
		int num = GetRandomInt(1, 6);
		Format(szNum, sizeof(szNum), "attack%i", num);
		ForceEntityInput("sephiroth_boss", "SetAnimation", szNum);
		int seph = GetEntityFromTargetname("sephiroth_boss");
		float origin[3], angles[3];
		GetEntPropVector(seph, Prop_Send, "m_vecOrigin", origin);
		GetEntPropVector(seph, Prop_Send, "m_angRotation", angles);
		ForceEntityInput("blade_out", "PlaySound");
		angles[0] = 0.0;
		SpawnLaser(origin, angles, JUMP, "1000", "4000", 30);

		if(counter2 == 2)
		{
			SephirothAttack();
			isTargeting = false;
			counter = 0;
			counter2 = 0;
		}
	}
	return Plugin_Continue;
}

public Action StartBoss(const char[] output, int caller, int activator, float delay)
{
	if(createTimer)
	{
		SephCounter_TimerHandle = CreateTimer(2.0, SephTimer, _, TIMER_REPEAT);
		TriggerTimer(SephCounter_TimerHandle, true);
	}
	bossTarget = GetRandomAlivePlayer(3);
	isTargeting = true;
	isMeteor = false;
	createTimer = false;
	float vector[3] = {4015.0, -3397.0, 10.0};
	TeleportEntity(GetEntityFromTargetname("sephiroth_boss"), vector, NULL_VECTOR, NULL_VECTOR);
	ForceEntityInput("sephiroth_boss", "SetAnimation", "run");
	ForceEntityInput("sephiroth_boss", "SetDefaultAnimation", "run");
}

public Action EndBoss(const char[] output, int caller, int activator, float delay)
{
	isTargeting = false;
	ForceEntityInput("sephiroth_boss", "Kill");
	ForceEntityInput("extreme_fade1", "Fade");
	ServerSay("Com", ">> I'll see you again.");
	ForceEntityInput("sephiroth_seeyouagain", "PlaySound");
	ForceEntityInput("thatperson", "FadeOut", "1");
	ForceEntityInput("providence", "PlaySound");

	ForceEntityInput("boss_start", "Kill");

	ForceEntityInput("sephattack_ztele_start", "CancelPending");
	ForceEntityInput("sephattack_ztele_end", "Trigger");

	ForceEntityInput("sephattack_ztele_start", "Kill");
	ForceEntityInput("sephattack_ztele_end", "Kill");
	ForceEntityInput("seph_fireparticle_1", "Stop");
	ForceEntityInput("seph_fireparticle_2", "Stop");
	ForceEntityInput("seph_fireparticle_3", "Stop");
	ForceEntityInput("seph_fireparticle_4", "Stop");
	ForceEntityInput("seph_firehurt_1", "Disable");
	ForceEntityInput("seph_firehurt_2", "Disable");
	ForceEntityInput("seph_firehurt_3", "Disable");
	ForceEntityInput("seph_firehurt_4", "Disable");
	ForceEntityInput("seph_firehurt_1", "Kill");
	ForceEntityInput("seph_firehurt_2", "Kill");
	ForceEntityInput("seph_firehurt_3", "Kill");
	ForceEntityInput("seph_firehurt_4", "Kill");

	ForceEntityInput("attack_quake_relay", "CancelPending");
	ForceEntityInput("attack_quake_relay", "Kill");
	ForceEntityInput("extreme_arena", "Enable");
	ForceEntityInput("extreme_arena", "EnableCollision");

	FireEntityInput("human_block1", "Disable", "", 4.0);
	FireEntityInput("human_block2", "Disable", "", 4.0);
	FireEntityInput("human_block1", "DisableCollision", "", 4.0);
	FireEntityInput("human_block2", "DisableCollision", "", 4.0);
	FireEntityInput("human_block1", "Kill", "", 4.5);
	FireEntityInput("human_block2", "Kill", "", 4.5);

	int relay = SpawnEntityByName("logic_relay", "endboss_relay");

	FireEntityInput("endboss_relay", "Trigger", "", 14.0);

	HookSingleEntityOutput(relay, "OnTrigger", EndBoss_Relay_OnTrigger, false);
}

public void OnGameFrame()
{
	if(isTargeting)
	{
		int seph = GetEntityFromTargetname("sephiroth_boss");
		float vector[3], angles[3], sephPos[3], targetPos[3];
		if(IsValidClient(bossTarget) && IsPlayerAlive(bossTarget) && seph != -1 && IsValidEntity(seph))
		{
			GetEntPropVector(seph, Prop_Send, "m_vecOrigin", sephPos);
			GetClientAbsOrigin(bossTarget, targetPos);
			MakeVectorFromPoints(sephPos, targetPos, vector); 
			NormalizeVector(vector, vector); 
			GetVectorAngles(vector, angles);
			angles[0] = 90.0;
			vector[2] = 0.0;
			ScaleVector(vector, 3.35);
			for(int i = 0; i < 3; i++)
			{
				sephPos[i] += vector[i];
			}
			TeleportEntity(seph, sephPos, angles, NULL_VECTOR);
			
			/*
			float origin[3], angles[3];
			GetClientAbsOrigin(bossTarget, origin);
			GetClientAbsAngles(bossTarget, angles);
			angles[0] = 90.0;
			TeleportEntity(seph, origin, angles, NULL_VECTOR);
			*/
		}
	}
}

public void Seph_OnStartTouch(int entity, int client)
{
	if(!IsValidClient(client) || !IsPlayerAlive(client))
	{
		return;
	}
	if(ZR_IsClientHuman(client) && !stopTouch[client])
	{
		stopTouch[client] = true;
		CreateTimer(0.4, ResetTouch, GetClientSerial(client));

		int health = GetClientHealth(client) - 10;
		if(health <= 0)
		{
			ForcePlayerSuicide(client);
		}
		else
		{
			SetEntityHealth(client, health);
		}
	}
}

public void SephirothAttack()
{
	bossTarget = -1;
	float vector[3] = {4015.0, -3397.0, 10.0};
	TeleportEntity(GetEntityFromTargetname("sephiroth_boss"), vector, NULL_VECTOR, NULL_VECTOR);
	ForceEntityInput("sephiroth_boss", "SetDefaultAnimation", "cast");
	ForceEntityInput("sephiroth_boss", "SetAnimation", "cast");

	counter = 0;
	counter2 = 0;
	isTargeting = false;

	int random = GetRandomInt(0, 3);

	switch (random)
	{
		case 0:
		{
			ServerSay("Com", ">> Meteo <<");
			for(int i = 1; i <= MaxClients; i++)
			{
				if(IsClientInGame(i) && IsPlayerAlive(i) && ZR_IsClientHuman(i))
				{
					SpawnMeteor(i, true);
					SpawnMeteor(i, true);
				}
			}
			FireEntityInput("boss_start", "Trigger", "", 5.0);
		}
		case 1:
		{
			ServerSay("Com", ">> Zombies <<");
			FireEntityInput("sephattack_ztele_start", "Trigger", "", 3.0);
			FireEntityInput("sephattack_ztele_end", "Trigger", "", 8.0);
			FireEntityInput("boss_start", "Trigger", "", 8.0);
		}
		case 2:
		{
			ServerSay("Com", ">> Fire <<");
			int random2 = GetRandomInt(0, 1);
			switch(random2)
			{
				case 0:
				{
					ForceEntityInput("seph_fireparticle_1", "Start");
					ForceEntityInput("seph_fireparticle_4", "Start");
					FireEntityInput("seph_firehurt_1", "Enable", "", 0.0);
					FireEntityInput("seph_firehurt_4", "Enable", "", 0.0);
					FireEntityInput("seph_firehurt_1", "Disable", "", 8.0);
					FireEntityInput("seph_firehurt_4", "Disable", "", 8.0);
					FireEntityInput("seph_fireparticle_1", "Stop", "", 8.0);
					FireEntityInput("seph_fireparticle_4", "Stop", "", 8.0);
				}
				case 1:
				{
					ForceEntityInput("seph_fireparticle_2", "Start");
					ForceEntityInput("seph_fireparticle_3", "Start");
					FireEntityInput("seph_firehurt_2", "Enable", "", 0.0);
					FireEntityInput("seph_firehurt_3", "Enable", "", 0.0);
					FireEntityInput("seph_firehurt_2", "Disable", "", 8.0);
					FireEntityInput("seph_firehurt_3", "Disable", "", 8.0);
					FireEntityInput("seph_fireparticle_2", "Stop", "", 8.0);
					FireEntityInput("seph_fireparticle_3", "Stop", "", 8.0);
				}
			}
			FireEntityInput("boss_start", "Trigger", "", 10.0);
		}
		case 3:
		{
			ServerSay("Com", ">> Quake <<");
			ForceEntityInput("attack_quake_relay", "Trigger");
		}
	}
}

public Action SephAttack_ZTeleStart(const char[] output, int caller, int activator, float delay)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			if(ZR_IsClientZombie(i))
			{
				float telePos[3] = {4015.0, -3397.0, 100.0};
				TeleportEntity(i, telePos, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
}

public Action SephAttack_ZTeleEnd(const char[] output, int caller, int activator, float delay)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i))
		{
			if(ZR_IsClientZombie(i))
			{
				ZMTeleport(i);
			}
		}
	}
}

public Action Meteor_Timer(Handle timer, any data)
{
	SpawnMeteor(GetRandomAlivePlayer(3));
	return Plugin_Continue;
}

void SpawnMeteor(int client, bool force = false)
{
	if(!IsValidClient(client) || (!isMeteor && !force))
	{
		return;
	}

	float origin[3];
	GetClientAbsOrigin(client, origin);

	char szTargetname[64], szOrigin[64];
	Format(szTargetname, sizeof(szTargetname), "TeslaPoint&%i", GetRandomInt(0, 99999));
	Format(szOrigin, sizeof(szOrigin), "%.2f %.2f %.2f", origin[0], origin[1], origin[2]);
	int tesla = SpawnEntityByName("point_tesla", szTargetname);
	DispatchKeyValue(tesla, "thick_min", "40");
	DispatchKeyValue(tesla, "thick_max", "50");
	DispatchKeyValue(tesla, "texture", "sprites/physbeam.vmt");
	DispatchKeyValue(tesla, "m_SoundName", "DoSpark");
	DispatchKeyValue(tesla, "m_flRadius", "300");
	DispatchKeyValue(tesla, "m_Color", "0 0 255");
	DispatchKeyValue(tesla, "lifetime_min", "2");
	DispatchKeyValue(tesla, "lifetime_max", "2");
	DispatchKeyValue(tesla, "beamcount_min", "50");
	DispatchKeyValue(tesla, "beamcount_max", "50");
	DispatchKeyValue(tesla, "origin", szOrigin);

	DispatchSpawn(tesla);
	ActivateEntity(tesla);
	ForceEntityInput(szTargetname, "DoSpark");
	
	int explosion = SpawnEntityByName("env_explosion", "");

	DispatchKeyValue(explosion, "rendermode", "5");
	DispatchKeyValue(explosion, "iRadiusOverride", "500");
	DispatchKeyValue(explosion, "iMagnitude", "25");
	DispatchKeyValue(explosion, "fireballsprite", "sprites/zerogxplode.spr");
	DispatchKeyValue(explosion, "origin", szOrigin);

	DataPack pack;
	CreateDataTimer(2.0, ExplodeMeteor, pack);
	pack.WriteCell(EntIndexToEntRef(tesla));
	pack.WriteCell(EntIndexToEntRef(explosion));
}

public Action ExplodeMeteor(Handle timer, Handle pack)
{
	int tesla, explosion;
	ResetPack(pack);
	tesla = EntRefToEntIndex(ReadPackCell(pack));
	explosion = EntRefToEntIndex(ReadPackCell(pack));
	if(tesla != INVALID_ENT_REFERENCE && explosion != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(explosion, "Explode");
		AcceptEntityInput(tesla, "Kill");
		AcceptEntityInput(explosion, "Kill");
	}
}

public Action EndBoss_Relay_OnTrigger(const char[] output, int caller, int activator, float delay)
{
	ServerSay("Com", ">> Zombies teleporting in 5 seconds... <<");
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && ZR_IsClientHuman(i))
		{
			float origin[3] = {9220.0, -2895.0, 64.0};
			float angles[3] = {0.0, -90.0, 0.0};

			TeleportEntity(i, origin, angles, NULL_VECTOR);
		}
	}

	int relay = SpawnEntityByName("logic_relay", "ztele7_relay");
	HookSingleEntityOutput(relay, "OnTrigger", ZTele7_OnTrigger, false);

	FireEntityInput("ztele7_relay", "Trigger", "", 5.0);
}

public Action ZTele7_OnTrigger(const char[] output, int caller, int activator, float delay)
{
	ZTeleOrigin[0][0] = 8986.0, ZTeleOrigin[0][1] = -2524.0, ZTeleOrigin[0][2] = 64.0;
	ZTeleAngles[0][0] = 0.0, ZTeleAngles[0][1] = -90.0, ZTeleAngles[0][2] = 0.0;

	ZTeleOrigin[1][0] = 9475.0, ZTeleOrigin[1][1] = -2524.0, ZTeleOrigin[1][2] = 64.0;
	ZTeleAngles[1][0] = 0.0, ZTeleAngles[1][1] = -90.0, ZTeleAngles[1][2] = 0.0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && ZR_IsClientZombie(i))
		{
			float origin[3] = {9220.0, -2895.0, 64.0};
			float angles[3] = {0.0, -90.0, 0.0};

			TeleportEntity(i, origin, angles, NULL_VECTOR);
		}
	}

	SpawnEntityByName("logic_relay", "vehicles_relay");
	GiveEntityOutput("vehicles_relay", "OnTrigger", "Com", "Command", "say >> Vehicles leaving in 25 seconds... <<");
	GiveEntityOutput("vehicles_relay", "OnTrigger", "Com", "Command", "say >> Vehicles leaving in 15 seconds... <<", "10");
	GiveEntityOutput("vehicles_relay", "OnTrigger", "Com", "Command", "say >> Vehicles leaving in 5 seconds... <<", "20");

	int setspeed = SpawnEntityByName("logic_relay", "setspeed2_relay");

	GiveEntityOutput("vehicles_relay", "OnTrigger", "WashTub2", "StartBackward", "", "25");
	GiveEntityOutput("vehicles_relay", "OnTrigger", "Boat5", "StartBackward", "", "25");
	GiveEntityOutput("vehicles_relay", "OnTrigger", "setspeed2_relay", "Trigger", "", "25.1");

	ForceEntityInput("vehicles_relay", "Trigger");
	ForceEntityInput("extreme_arena", "Kill");
	ForceEntityInput("zm_block1", "Kill");
	ForceEntityInput("zm_block2", "Kill");

	ForceEntityInput("ztele1_trigger", "Kill");
	ForceEntityInput("ztele2_trigger", "Kill");
	ForceEntityInput("ztele2_trigger_2", "Kill");
	ForceEntityInput("ztele3_trigger_teleport", "Kill");
	ForceEntityInput("ztele4_trigger", "Kill");
	ForceEntityInput("ztele5_trigger_teleport", "Kill");
	ForceEntityInput("ztele6_trigger", "Kill");

	float origin[3] = {-255.0, 386.0, 0.0};
	float min[3] = {-494.0, -111.0, 0.0};
	float max[3] = {494.0, 111.0, 76.0};

	int ent = CreateBrushEntity("trigger_teleport", origin, min, max);
	GiveIDTargetname(ent, "spawn_ztele_trigger");
	GiveEntityOutput("spawn_ztele_trigger", "OnStartTouch", "ztele_relay", "Trigger");

	float origin2[3] = {3688.5, 6240.0, 32.0};
	float min2[3] = {-120.5, -97.0, 0.0};
	float max2[3] = {120.5, 97.0, 304.0};

	int ent2 = CreateBrushEntity("trigger_teleport", origin2, min2, max2);
	GiveIDTargetname(ent2, "headback_teleport");
	
	HookSingleEntityOutput(ent2, "OnStartTouch", HeadBack_Teleport_OnStartTouch, false);
	HookSingleEntityOutput(setspeed, "OnTrigger", SetSpeed2_Relay_OnTrigger, false);

	Create_SephPart2();
}

public Action SetSpeed2_Relay_OnTrigger(const char[] output, int caller, int activator, float delay)
{
	ForceEntityInput("WashTub2", "AddOutput", "speed -5000");
	ForceEntityInput("Boat5", "AddOutput", "speed -5000");
}

public Action HeadBack_Teleport_OnStartTouch(const char[] output, int caller, int activator, float delay)
{
	float origin[3] = {5215.0, 5936.0, 256.0}, angles[3] = {0.0, -90.0, 0.0};
	TeleportEntity(activator, origin, angles, NULL_VECTOR);
}

bool part2dead = false;

public void Create_SephPart2()
{
	part2dead = false;
	float origin[3] = {607.5, 4512.0, 120.0};
	float min[3] = {-96.5, -96.0, 0.0};
	float max[3] = {96.5, 96.0, 106.0};

	int ent = CreateBrushEntity("trigger_once", origin, min, max);
	GiveIDTargetname(ent, "seph_part2_trigger");
	GiveEntityOutput("seph_part2_trigger", "OnStartTouch", "seph_part2_relay", "Trigger");

	int model = SpawnEntityByName("prop_dynamic", "seph_part2_model");
	DispatchKeyValue(model, "angles", "90 90 0");
	DispatchKeyValue(model, "origin", "413 1706 131");
	DispatchKeyValue(model, "model", "models/antiteal/icecap/sephiroth.mdl");
	DispatchKeyValue(model, "solid", "6");
	DispatchSpawn(model);

	ForceEntityInput("seph_part2_model", "Disable");

	int relay = SpawnEntityByName("logic_relay", "seph_part2_relay");
	GiveEntityOutput("seph_part2_relay", "OnTrigger", "extreme_fade1", "Fade");
	GiveEntityOutput("seph_part2_relay", "OnTrigger", "seph_part2_model", "Enable", "", "0.5");
	GiveEntityOutput("seph_part2_relay", "OnTrigger", "Com", "Command", "say >> Seems I do not have to hold back...", "0.5");
	GiveEntityOutput("seph_part2_relay", "OnTrigger", "sephiroth_seems", "PlaySound", "", "0.5");

	HookSingleEntityOutput(relay, "OnTrigger", SephPart2_Relay_OnTrigger, false);

	int relay2 = SpawnEntityByName("logic_relay", "seph_part2_relay_end");
	HookSingleEntityOutput(relay2, "OnTrigger", SephPart2_Relay_End_OnTrigger, false);

	//start ztele systems
	float origin2[3] = {-3329.5, -3103.0, 32.85};
	float max2[3] = {236.5, 30.0, 258.0};
	float min2[3] = {-236.5, -30.0, 0.0};
	int backtele1 = CreateBrushEntity("trigger_once", origin2, min2, max2);
	GiveIDTargetname(backtele1, "back_ztele1_trigger");
	GiveEntityOutput("back_ztele1_trigger", "OnStartTouch", "Com", "Command", "say >> Zombies teleporting in 10 seconds! <<<");
	GiveEntityOutput("back_ztele1_trigger", "OnStartTouch", "back_ztele1_relay", "Trigger", "", "10.0");
	int backtele_relay1 = SpawnEntityByName("logic_relay", "back_ztele1_relay");

	HookSingleEntityOutput(backtele_relay1, "OnTrigger", BackTele_Relay1_OnTrigger, false);

	float origin3[3] = {-2330.5, 7044.5, 16.0};
	float max3[3] = {98.5, 898.5, 658.0};
	float min3[3] = {-98.5, -898.5, 0.0};
	int backtele2 = CreateBrushEntity("trigger_once", origin3, min3, max3);
	GiveIDTargetname(backtele2, "back_ztele2_trigger");
	GiveEntityOutput("back_ztele2_trigger", "OnStartTouch", "Com", "Command", "say >> Zombies teleporting in 10 seconds! <<<");
	GiveEntityOutput("back_ztele2_trigger", "OnStartTouch", "back_ztele2_relay", "Trigger", "", "10.0");
	int backtele_relay2 = SpawnEntityByName("logic_relay", "back_ztele2_relay");

	HookSingleEntityOutput(backtele_relay2, "OnTrigger", BackTele_Relay2_OnTrigger, false);

	float origin4[3] = {5282.0, 5650.0, 100.0};
	float max4[3] = {160.0, 64.0, 658.0};
	float min4[3] = {-160.0, -64.0, 0.0};
	int backtele3 = CreateBrushEntity("trigger_once", origin4, min4, max4);
	GiveIDTargetname(backtele3, "back_ztele3_trigger");
	GiveEntityOutput("back_ztele3_trigger", "OnStartTouch", "Com", "Command", "say >> Zombies teleporting in 10 seconds! <<<");
	GiveEntityOutput("back_ztele3_trigger", "OnStartTouch", "back_ztele3_relay", "Trigger", "", "10.0");
	int backtele_relay3 = SpawnEntityByName("logic_relay", "back_ztele3_relay");

	HookSingleEntityOutput(backtele_relay3, "OnTrigger", BackTele_Relay3_OnTrigger, false);

	float origin5[3] = {3412.0, 4483.5, 100.0};
	float max5[3] = {72.0, 269.5, 658.0};
	float min5[3] = {-72.0, -269.5, 0.0};
	int musictrigger = CreateBrushEntity("trigger_once", origin5, min5, max5);
	GiveIDTargetname(musictrigger, "final_music_trigger");
	GiveEntityOutput("final_music_trigger", "OnStartTouch", "providence", "fadeout", "1");
	GiveEntityOutput("final_music_trigger", "OnStartTouch", "tiz", "playsound");
	GiveEntityOutput("final_music_trigger", "OnStartTouch", "extreme_shake2", "StartShake");

	int wall1 = SpawnEntityByName("prop_dynamic", "seph_part2_blocker1");
	DispatchKeyValue(wall1, "angles", "0 90 0");
	DispatchKeyValue(wall1, "origin", "569 3204 126");
	DispatchKeyValue(wall1, "model", "models/props/de_nuke/hr_nuke/metal_crate_001/metal_crate_001_128x112x256.mdl");
	DispatchKeyValue(wall1, "solid", "6");
	DispatchSpawn(wall1);

	int wall2 = SpawnEntityByName("prop_dynamic", "seph_part2_blocker2");
	DispatchKeyValue(wall2, "angles", "0 0 0");
	DispatchKeyValue(wall2, "origin", "758 3280 126");
	DispatchKeyValue(wall2, "model", "models/props/de_nuke/hr_nuke/metal_crate_001/metal_crate_001_128x112x256.mdl");
	DispatchKeyValue(wall2, "solid", "6");
	DispatchSpawn(wall2);
}

public Action BackTele_Relay1_OnTrigger(const char[] output, int caller, int activator, float delay)
{
	ZTeleOrigin[0][0] =	-3340.0; 
	ZTeleOrigin[0][1] =	-1985.0; 
	ZTeleOrigin[0][2] =	252.0;

	ZTeleAngles[0][0] = 10.0;
	ZTeleAngles[0][1] =	0.0;
	ZTeleAngles[0][2] =	0.0;

	ZTeleOrigin[1][0] =	-2465.0; 
	ZTeleOrigin[1][1] =	-2788.0; 
	ZTeleOrigin[1][2] =	192.0;

	ZTeleAngles[1][0] = 7.0;
	ZTeleAngles[1][1] =	70.0;
	ZTeleAngles[1][2] =	0.0;

	//island ztele
	float ztele_origin[3] = {6823.5, -3283.0, -40.5};
	float ztele_min[3] = {-3911.5, -2272.0, 0.0};
	float ztele_max[3] = {3911.5, 2272.0, 587.0};

	int island_ztele = CreateBrushEntity("trigger_teleport", ztele_origin, ztele_min, ztele_max);
	GiveIDTargetname(island_ztele, "island_ztele");
	GiveEntityOutput("island_ztele", "OnStartTouch", "ztele_relay", "Trigger");
}

public Action BackTele_Relay2_OnTrigger(const char[] output, int caller, int activator, float delay)
{
	ZTeleOrigin[0][0] =	-1507.0; 
	ZTeleOrigin[0][1] =	6247.0; 
	ZTeleOrigin[0][2] =	191.0;

	ZTeleAngles[0][0] = 0.0;
	ZTeleAngles[0][1] =	0.0;
	ZTeleAngles[0][2] =	0.0;

	ZTeleOrigin[1][0] =	-1507.0; 
	ZTeleOrigin[1][1] =	6247.0; 
	ZTeleOrigin[1][2] =	191.0;

	ZTeleAngles[1][0] = 0.0;
	ZTeleAngles[1][1] =	0.0;
	ZTeleAngles[1][2] =	0.0;

	float origin[3] = {-1758.5, -3160.0, -77.5};
	float min[3] = {-3306.5, -2167.0, 0.0};
	float max[3] = {3306.5, 2167.0, 1517.0};

	int ent = CreateBrushEntity("trigger_teleport", origin, min, max);
	GiveIDTargetname(ent, "ztele6_trigger");
	GiveEntityOutput("ztele6_trigger", "OnStartTouch", "ztele_relay", "Trigger");

	float origin2[3] = {-2969.0, 3487.5, 0.0};
	float min2[3] = {-1302.0, -4495.5, 0.0};
	float max2[3] = {1302.0, 4495.5, 704.0};

	int ent2 = CreateBrushEntity("trigger_teleport", origin2, min2, max2);
	GiveIDTargetname(ent2, "ztele5_trigger_teleport");
	GiveEntityOutput("ztele5_trigger_teleport", "OnStartTouch", "ztele_relay", "Trigger");

	float origin3[3] = {-3785.0, 3343.5, 50.0};
	float min3[3] = {-1325.0, -4730.5, 0.0};
	float max3[3] = {1325.0, 4730.5, 949.0};

	int ent3 = CreateBrushEntity("trigger_teleport", origin3, min3, max3);
	GiveIDTargetname(ent3, "zm_ztele_back");
	GiveEntityOutput("zm_ztele_back", "OnStartTouch", "ztele_relay", "Trigger");
}

public Action BackTele_Relay3_OnTrigger(const char[] output, int caller, int activator, float delay)
{
	ZTeleOrigin[0][0] =	5561.0; 
	ZTeleOrigin[0][1] =	5631.0; 
	ZTeleOrigin[0][2] =	192.0;

	ZTeleAngles[0][0] = 0.0;
	ZTeleAngles[0][1] =	-90.0;
	ZTeleAngles[0][2] =	0.0;

	ZTeleOrigin[1][0] =	5561.0; 
	ZTeleOrigin[1][1] =	5631.0; 
	ZTeleOrigin[1][2] =	192.0;

	ZTeleAngles[1][0] = 0.0;
	ZTeleAngles[1][1] =	-90.0;
	ZTeleAngles[1][2] =	0.0;

	float origin[3] = {2727.0, 6875.0, 64.0};
	float min[3] = {-4396.0, -1105.0, 0.0};
	float max[3] = {4396.0, 1105.0, 768.0};

	int ent = CreateBrushEntity("trigger_teleport", origin, min, max);
	GiveIDTargetname(ent, "ztele4_trigger");
	GiveEntityOutput("ztele4_trigger", "OnStartTouch", "ztele_relay", "Trigger");
}

public Action SephPart2_Relay_OnTrigger(const char[] output, int caller, int activator, float delay)
{
	//3412.0, 4483.5, 100.0

	ZTeleOrigin[0][0] =	3412.0; 
	ZTeleOrigin[0][1] =	4483.0; 
	ZTeleOrigin[0][2] =	192.0;

	ZTeleAngles[0][0] = 0.0;
	ZTeleAngles[0][1] =	-180.0;
	ZTeleAngles[0][2] =	0.0;

	ZTeleOrigin[1][0] =	3412.0; 
	ZTeleOrigin[1][1] =	4483.0; 
	ZTeleOrigin[1][2] =	192.0;

	ZTeleAngles[1][0] = 0.0;
	ZTeleAngles[1][1] =	-180.0;
	ZTeleAngles[1][2] =	0.0;

	float origin3[3] = {5943.0, 2891.0, 128.0};
	float min3[3] = {-1205.0, -3040.0, 0.0};
	float max3[3] = {1205.0, 3040.0, 768.0};

	int ent3 = CreateBrushEntity("trigger_teleport", origin3, min3, max3);
	GiveIDTargetname(ent3, "ztele3_trigger_teleport");
	GiveEntityOutput("ztele3_trigger_teleport", "OnStartTouch", "ztele_relay", "Trigger");

	float origin2[3] = {5901.0, 698.5, 117.5};
	float min2[3] = {-1089.0, -831.5, 0.0};
	float max2[3] = {1089.0, 831.5, 773.0};

	int ent2 = CreateBrushEntity("trigger_teleport", origin2, min2, max2);
	GiveIDTargetname(ent2, "ztele2_trigger_2");
	GiveEntityOutput("ztele2_trigger_2", "OnStartTouch", "ztele_relay", "Trigger");

	SephLaserPart2_TimerHandle = CreateTimer(1.0, SephPart2_SpawnLaser, _, TIMER_REPEAT);

	float origin4[3] = {343.0, 1783.5, 120.7};
	float min4[3] = {-169.0, -35.5, 0.0};
	float max4[3] = {169.0, 35.5, 106.0};

	int breakable = CreateBrushEntity("func_breakable", origin4, min4, max4);
	GiveIDTargetname(breakable, "seph_part2_breakable");

	char szHP[8];
	int baseHP = 150;
	int HP = baseHP * HumanCount();
	IntToString(HP, szHP, sizeof(szHP));

	DispatchKeyValue(breakable, "health", szHP);
	DispatchKeyValue(breakable, "spawnflags", "0");
	DispatchKeyValue(breakable, "solid", "6");

	SetEntProp(breakable, Prop_Data, "m_takedamage", 2, 1);
	SetEntProp(breakable, Prop_Data, "m_iHealth", HP);  

	GiveEntityOutput("seph_part2_breakable", "OnBreak", "seph_part2_relay_end", "Trigger");
}

public Action SephPart2_SpawnLaser(Handle timer, any data)
{
	if(part2dead)
	{
		SephLaserPart2_TimerHandle = INVALID_HANDLE;
		return Plugin_Stop;
	}
	float origin[3] = {412.0, 1710.0, 140.0};
	float angles[3] = {0.0, 90.0, 0.0};
	char szNum[32];
	int num = GetRandomInt(1, 6);
	Format(szNum, sizeof(szNum), "attack%i", num);
	ForceEntityInput("seph_part2_model", "SetAnimation", szNum);
	SpawnLaser(origin, angles, RANDOM, "1500", "4000", 9999);
	ForceEntityInput("blade_out", "PlaySound");
	return Plugin_Continue;
}

public Action SephPart2_2ndTrigger_OnStartTouch(const char[] output, int caller, int activator, float delay)
{
	float origin[3] = {418.0, 3065.0, 140.0};
	float angles[3] = {180.0, 90.0, 0.0};
	SpawnLaser(origin, angles, RANDOM, "2000", "4000", 9999);
	ForceEntityInput("blade_out", "PlaySound");
}

public Action SephPart2_Relay_End_OnTrigger(const char[] output, int caller, int activator, float delay)
{
	ForceEntityInput("extreme_fade1", "Fade");
	ForceEntityInput("seph_part2_model", "Kill");
	part2dead = true;

	float origin[3] = {376.0, 1800.0, 131.0};
	float min[3] = {-136.0, -24.0, 0.0};
	float max[3] = {136.0, 24.0, 102.0};

	int ent = CreateBrushEntity("trigger_once", origin, min, max);

	GiveIDTargetname(ent, "sephiroth_part2_2ndtrigger");
	GiveEntityOutput("sephiroth_part2_2ndtrigger", "OnStartTouch", "sephiroth_part1_model", "Enable");
	GiveEntityOutput("sephiroth_part2_2ndtrigger", "OnStartTouch", "sephiroth_part1_model", "SetAnimation", "attack1");

	HookSingleEntityOutput(ent, "OnStartTouch", SephPart2_2ndTrigger_OnStartTouch, true);

	GiveEntityOutput("sephiroth_part2_2ndtrigger", "OnStartTouch", "sephiroth_part1_model", "SetAnimation", "defeat", "1.5");
	GiveEntityOutput("sephiroth_part2_2ndtrigger", "OnStartTouch", "sephiroth_part1_model", "SetDefaultAnimation", "defeat2", "1.8");
	GiveEntityOutput("sephiroth_part2_2ndtrigger", "OnStartTouch", "sephiroth_defeated", "PlaySound", "", "1.5");
	GiveEntityOutput("sephiroth_part2_2ndtrigger", "OnStartTouch", "Com", "Command", "say >> I've been... defeated?", "1.5");
	GiveEntityOutput("sephiroth_part2_2ndtrigger", "OnStartTouch", "final_relay_part1", "Trigger", "", "2.5");

	SpawnEntityByName("logic_relay", "final_relay_part1");
	GiveEntityOutput("final_relay_part1", "OnTrigger", "Com", "Command", "say >> Survive for 25 seconds! <<");
	GiveEntityOutput("final_relay_part1", "OnTrigger", "Com", "Command", "say >> Zombies teleporting in 4 seconds! <<", "4.0");

	GiveEntityOutput("final_relay_part1", "OnTrigger", "final_ztele", "Trigger", "", "8.0");	

	GiveEntityOutput("final_relay_part1", "OnTrigger", "Com", "Command", "say >> Survive for 10 seconds! <<", "15.0");
	GiveEntityOutput("final_relay_part1", "OnTrigger", "Com", "Command", "say >> 9 <<", "16.0");
	GiveEntityOutput("final_relay_part1", "OnTrigger", "Com", "Command", "say >> 8 <<", "17.0");
	GiveEntityOutput("final_relay_part1", "OnTrigger", "Com", "Command", "say >> 7 <<", "18.0");
	GiveEntityOutput("final_relay_part1", "OnTrigger", "Com", "Command", "say >> 6 <<", "19.0");
	GiveEntityOutput("final_relay_part1", "OnTrigger", "Com", "Command", "say >> 5 <<", "20.0");
	GiveEntityOutput("final_relay_part1", "OnTrigger", "Com", "Command", "say >> 4 <<", "21.0");
	GiveEntityOutput("final_relay_part1", "OnTrigger", "Com", "Command", "say >> 3 <<", "22.0");
	GiveEntityOutput("final_relay_part1", "OnTrigger", "Com", "Command", "say >> 2 <<", "23.0");
	GiveEntityOutput("final_relay_part1", "OnTrigger", "Com", "Command", "say >> 1 <<", "24.0");

	GiveEntityOutput("final_relay_part1", "OnTrigger", "final_relay_part2", "Trigger", "", "25.0");

	int final = SpawnEntityByName("logic_relay", "final_relay_part2");
	HookSingleEntityOutput(final, "OnTrigger", Final_Relay_Part2_OnTrigger, false);

	int final_ztele = SpawnEntityByName("logic_relay", "final_ztele");
	HookSingleEntityOutput(final_ztele, "OnTrigger", Final_ZTele_OnTrigger, false);
}

public Action Final_ZTele_OnTrigger(const char[] output, int caller, int activator, float delay)
{
	ZTeleOrigin[0][0] =	420.0; 
	ZTeleOrigin[0][1] =	2562.0; 
	ZTeleOrigin[0][2] =	192.0;

	ZTeleAngles[0][0] = 0.0;
	ZTeleAngles[0][1] =	-90.0;
	ZTeleAngles[0][2] =	0.0;

	ZTeleOrigin[1][0] =	420.0; 
	ZTeleOrigin[1][1] =	2562.0; 
	ZTeleOrigin[1][2] =	192.0;

	ZTeleAngles[1][0] = 0.0;
	ZTeleAngles[1][1] =	-90.0;
	ZTeleAngles[1][2] =	0.0;

	float origin2[3] = {2736.5, 2447.0, 117.5};
	float min2[3] = {-2204.5, -2580.0, 0.0};
	float max2[3] = {2204.5, 2580.0, 773.0};

	int ent2 = CreateBrushEntity("trigger_teleport", origin2, min2, max2);
	GiveIDTargetname(ent2, "ztele2_trigger");
	GiveEntityOutput("ztele2_trigger", "OnStartTouch", "ztele_relay", "Trigger");
}

public Action Final_Relay_Part2_OnTrigger(const char[] output, int caller, int activator, float delay)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && IsPlayerAlive(i) && ZR_IsClientZombie(i))
		{
			ForcePlayerSuicide(i);
		}
	}

	if(HumanCount() == 1)
	{
		ServerSay("Com", "SOLOOOOOOOOOOOOOOOOOO");
		ServerSay("Com", "SOLOOOOOOOOOOOOOOOOOO");
		ServerSay("Com", "SOLOOOOOOOOOOOOOOOOOO");
		ServerSay("Com", "SOLOOOOOOOOOOOOOOOOOO");
		ServerSay("Com", "SOLOOOOOOOOOOOOOOOOOO");
	}
	else if(HumanCount() == 2)
	{
		ServerSay("Com", "DUOOOOOOOOOOOOOOOOOOO");
		ServerSay("Com", "DUOOOOOOOOOOOOOOOOOOO");
		ServerSay("Com", "DUOOOOOOOOOOOOOOOOOOO");
		ServerSay("Com", "DUOOOOOOOOOOOOOOOOOOO");
		ServerSay("Com", "DUOOOOOOOOOOOOOOOOOOO");
		ServerSay("Com", "DUOOOOOOOOOOOOOOOOOOO");
	}
	else if(HumanCount() == 3)
	{
		ServerSay("Com", "TRIOOOOOOOOOOOOOOOOOO");
		ServerSay("Com", "TRIOOOOOOOOOOOOOOOOOO");
		ServerSay("Com", "TRIOOOOOOOOOOOOOOOOOO");
		ServerSay("Com", "TRIOOOOOOOOOOOOOOOOOO");
		ServerSay("Com", "TRIOOOOOOOOOOOOOOOOOO");
	}
	else
	{
		ServerSay("Com", "YOU ARE THE MASTERS OF ICECAP!");
		ServerSay("Com", "YOU ARE THE MASTERS OF ICECAP!");
		ServerSay("Com", "YOU ARE THE MASTERS OF ICECAP!");
		ServerSay("Com", "YOU ARE THE MASTERS OF ICECAP!");
		ServerSay("Com", "YOU ARE THE MASTERS OF ICECAP!");
		ServerSay("Com", "YOU ARE THE MASTERS OF ICECAP!");
		ServerSay("Com", "YOU ARE THE MASTERS OF ICECAP!");
		ServerSay("Com", "YOU ARE THE MASTERS OF ICECAP!");
		ServerSay("Com", "YOU ARE THE MASTERS OF ICECAP!");
	}

	ServerSay("Com", "CUSTOM LEVEL CREATED BY ANTITEAL", 1.5);
	ServerSay("Com", "CUSTOM LEVEL CREATED BY ANTITEAL", 1.6);

	ForceEntityInput("victory", "PlaySound");
	ForceEntityInput("thanks_text", "Display");
	ForceEntityInput("thanks_text", "Display");
	ForceEntityInput("thanks_text", "Display");
	FireEntityInput("thanks_text", "Display", "", 1.0);
	FireEntityInput("thanks_text", "Display", "", 1.0);
	FireEntityInput("thanks_text", "Display", "", 1.0);
	FireEntityInput("thanks_text", "Display", "", 2.0);
	FireEntityInput("thanks_text", "Display", "", 2.0);
	FireEntityInput("thanks_text", "Display", "", 2.0);
}