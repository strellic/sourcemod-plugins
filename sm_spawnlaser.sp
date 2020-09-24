#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>

#define PLUGIN_VERSION "1.0"

#pragma newdecls required

int clientOptions[MAXPLAYERS+1][4];
float clientDelay[MAXPLAYERS+1];
float clientOrigin[MAXPLAYERS+1][3];
float clientAngles[MAXPLAYERS+1][3];
bool stopTouch[MAXPLAYERS+1];

public Plugin myinfo =
{
	name = "[sG] Spawn Laser",
	description = "Spawn Laser",
	author = "sG | AntiTeal",
	version = PLUGIN_VERSION,
	url = "http://www.joinsg.net"
};

public void OnPluginStart()
{
	CreateConVar("sm_spawnlaser_version", PLUGIN_VERSION, "SpawnLaser Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	RegAdminCmd("sm_spawnlaser", Command_SpawnLaser, ADMFLAG_GENERIC);
	RegAdminCmd("sm_customlaser", Command_CustomLaser, ADMFLAG_GENERIC);
}

public void OnMapStart()
{
	PrecacheSound("sound/music/antiteal/laser.mp3");
	PrecacheModel("models/AntiTeal/Laser.mdl");
	PrecacheModel("models/props/cs_militia/silo_01.mdl");
}

public Action Command_SpawnLaser(int client, int argc)
{
	Menu menu = new Menu(MenuHandler1);

	menu.SetTitle("SpawnLaser Menu:");
	menu.AddItem("0", "Jump Laser");
	menu.AddItem("1", "Crouch Laser");
	menu.AddItem("2", "Random Laser");
	if(clientOptions[client][2] != 0)
	{
		char type[16], previous[64];

		if(clientOptions[client][0] == 0)
		{
			Format(type, sizeof(type), "Jump");
		}
		else if(clientOptions[client][0] == 1)
		{
			Format(type, sizeof(type), "Crouch");
		}
		else if(clientOptions[client][0] == 2)
		{
			Format(type, sizeof(type), "Random");
		}

		Format(previous, sizeof(previous), "Previous: %s | %i units/s | %i Lasers | %.2fs Delay", type, clientOptions[client][1], clientOptions[client][2], clientDelay[client]);
		menu.AddItem("3", previous);
	}

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);

	return Plugin_Handled;
}

public int MenuHandler1(Handle menu, MenuAction action, int client, int position)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, position, info, sizeof(info));
		
		if(StrEqual(info, "3"))
		{
			LaserInitiate(client);
		}
		else
		{
			clientOptions[client][0] = StringToInt(info);
			SpawnLaser2(client);
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action SpawnLaser2(int client)
{
	Menu menu = new Menu(MenuHandler2);

	menu.SetTitle("LaserSpeed Menu:");
	menu.AddItem("500", "500 units/s");
	menu.AddItem("1000", "1000 units/s");
	menu.AddItem("1500", "1500 units/s");
	menu.AddItem("2000", "2000 units/s");
	menu.AddItem("4000", "4000 units/s");

	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler2(Handle menu, MenuAction action, int client, int position)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, position, info, sizeof(info));

		clientOptions[client][1] = StringToInt(info);

		SpawnLaser3(client);
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action SpawnLaser3(int client)
{
	Menu menu = new Menu(MenuHandler3);

	menu.SetTitle("LaserAmount Menu:");
	menu.AddItem("1", "1 Laser");
	menu.AddItem("5", "5 Lasers");
	menu.AddItem("10", "10 Lasers");
	menu.AddItem("15", "15 Lasers");
	menu.AddItem("30", "30 Lasers");
	menu.AddItem("60", "60 Lasers");

	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler3(Handle menu, MenuAction action, int client, int position)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, position, info, sizeof(info));
		
		int num = StringToInt(info);

		clientOptions[client][2] = num;

		if(num != 1)
		{
			SpawnLaser4(client);
		}
		else
		{
			clientOptions[client][3] = 0;
			LaserInitiate(client);
		}
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action SpawnLaser4(int client)
{
	Menu menu = new Menu(MenuHandler4);

	menu.SetTitle("LaserDelay Menu:");
	menu.AddItem("2", "2 Seconds");
	menu.AddItem("1.5", "1.5 Seconds");
	menu.AddItem("1", "1 Second");
	menu.AddItem(".75", ".75 Seconds");
	menu.AddItem(".5", ".5 Seconds");
	menu.AddItem(".25", ".25 Seconds");

	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler4(Handle menu, MenuAction action, int client, int position)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, position, info, sizeof(info));
		
		float num = StringToFloat(info);

		clientDelay[client] = num;

		LaserInitiate(client);
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action LaserInitiate(int client)
{
	GetClientAbsOrigin(client, clientOrigin[client]);
	GetClientEyeAngles(client, clientAngles[client]);

	clientOptions[client][3] = clientOptions[client][2];

	PrintToChat(client, "[SM] Spawning lasers in 5 seconds.....");

	CreateTimer(5.0, StartLaser, GetClientSerial(client));
}

public Action StartLaser(Handle timer, any serial)
{
	int client = GetClientFromSerial(serial);
 
	if (client == 0) 
	{
		return Plugin_Stop;
	}

	CreateLaser(client);

	return Plugin_Handled;
}

public void OnStartTouch(int entity, int client)
{
	if(!IsValidClient(client))
	{
		return;
	}    
   	
	if(!stopTouch[client])
	{
		stopTouch[client] = true;
		CreateTimer(0.4, ResetTouch, GetClientSerial(client));
		PrintToChat(client, "[SM] You were hit by a laser!");
		ClientCommand(client, "playgamesound Buttons.snd18");
	}
}  

public Action StopTouch(Handle timer, any serial)
{
	int client = GetClientFromSerial(serial);

	if (client == 0) 
	{
		return Plugin_Stop;
	}

	stopTouch[client] = false;

	return Plugin_Handled;
}


public Action CreateLaser(int client)
{
	float fPos[3], fAng[3]; 
	char sAng[32];

	for (int i = 0; i < 3; i++)
	{
		fPos[i] = clientOrigin[client][i];
		fAng[i] = clientAngles[client][i];
	}

	Format(sAng, sizeof(sAng), "0 %i 0", RoundToNearest(fAng[1]));
	int lineEnt = SpawnMoveLinear(fPos, sAng, clientOptions[client][1]);

	fAng[0] = 0.0;
	fAng[2] = 0.0;

	if(clientOptions[client][0] == 0)
	{
		fPos[2] += 15.0;
	}
	else if(clientOptions[client][0] == 1)
	{
		fPos[2] += 60.0;
	}
	else
	{
		int num = GetRandomInt(0, 1);
		if(num == 0)
		{
			fPos[2] += 15.0;
		}
		else if(num == 1)
		{
			fPos[2] += 60.0;
		}
	}

	fAng[1] -= 90.0;

	int laserEnt = SpawnLaser(fPos, fAng);

	ParentToEntity(laserEnt, lineEnt);

	SDKHook(laserEnt, SDKHook_StartTouch, OnStartTouch); 
	AcceptEntityInput(lineEnt, "Open", -1, -1);
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			ClientCommand(i, "playgamesound music/antiteal/laser.mp3");
		}
	}

	clientOptions[client][3]--;

	if(clientOptions[client][3] > 0)
	{
		CreateTimer(clientDelay[client], StartLaser, GetClientSerial(client));
	}
	else
	{
		PrintToChat(client, "[SM] Laser sequence over!");
	}

	HookSingleEntityOutput(lineEnt, "OnFullyOpen", OnFullyOpen, true);

	return Plugin_Handled;
}

public int SpawnLaser(float position[3], float angles[3])
{
	char targetname[32];
	Format(targetname, sizeof(targetname), "Laser_PropDynamic&%i", GetRandomInt(0, 999));

	int g_iEnt = CreateEntityByName("prop_dynamic");
	DispatchKeyValue(g_iEnt, "targetname", targetname);
	DispatchKeyValue(g_iEnt, "model", "models/AntiTeal/Laser.mdl");
	SetEntProp(g_iEnt, Prop_Send, "m_usSolidFlags", 0x0008);
	SetEntProp(g_iEnt, Prop_Data, "m_nSolidType", 2);
	SetEntProp(g_iEnt, Prop_Send, "m_CollisionGroup", 2);
	DispatchSpawn(g_iEnt);

	TeleportEntity(g_iEnt, position, angles, NULL_VECTOR);

	return g_iEnt;
}  

public int SpawnMoveLinear(float position[3], char[] angles, int spd)
{
	char targetname[32], speed[8];
	Format(targetname, sizeof(targetname), "Laser_MoveLinear&%i", GetRandomInt(0, 999));

	IntToString(spd, speed, sizeof(speed));

	int g_iEnt = CreateEntityByName("func_movelinear");
	DispatchKeyValue(g_iEnt, "targetname", targetname);
	DispatchKeyValue(g_iEnt, "startposition", "0");
	DispatchKeyValue(g_iEnt, "speed", speed);
	DispatchKeyValue(g_iEnt, "spawnflags", "8");
	DispatchKeyValue(g_iEnt, "movedistance", "4000");
	DispatchKeyValue(g_iEnt, "movedir", angles);
	DispatchSpawn(g_iEnt);

	return g_iEnt;
}
public void OnFullyOpen(const char[] output, int caller, int activator, float Any)
{
	AcceptEntityInput(caller, "KillHierarchy", -1, -1);
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

public bool ParentToEntity(int ent, int target)
{
	SetVariantEntity(target);
	return AcceptEntityInput(ent, "SetParent");
} 

int IsValidClient(int client, bool nobots = true)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false;
	}
	return IsClientInGame(client);
}

public Action Command_CustomLaser(int client, int argc)
{
	if(argc < 4)
	{
		ReplyToCommand(client, "[SM] Usage: sm_customlaser [jump|crouch|random] <speed (u/s)> <amount> <delay (s)>");
		return Plugin_Handled;
	}
	char arg1[32], arg2[8], arg3[8], arg4[8];

	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	GetCmdArg(3, arg3, sizeof(arg3));
	GetCmdArg(4, arg4, sizeof(arg4));

	if(StrEqual(arg1, "jump"))
	{
		clientOptions[client][0] = 0;
	}
	else if(StrEqual(arg1, "crouch"))
	{
		clientOptions[client][0] = 1;
	}
	else
	{
		clientOptions[client][0] = 2;
	}

	clientOptions[client][1] = StringToInt(arg2);
	clientOptions[client][2] = StringToInt(arg3);
	clientDelay[client] = StringToFloat(arg4);

	ReplyToCommand(client, "[SM] Custom settings initated. Check the previous option in the SpawnLaser menu.");

	return Plugin_Handled;
}