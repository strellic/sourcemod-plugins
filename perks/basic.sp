char g_sBodyColors[PERKS_MAX_ITEMS][16];

int g_aTracerColor[MAXPLAYERS + 1][3];
char g_sTracerColor[PERKS_MAX_ITEMS][16];
int g_iBeam = -1;
bool g_bRainbow[MAXPLAYERS+1] = {false, ...};
bool g_bDisableTracers[MAXPLAYERS+1] = {false, ...};
Handle gH_sTracers = INVALID_HANDLE;

char g_sGrenadeSkin[PERKS_MAX_ITEMS][PLATFORM_MAX_PATH];
char g_sGrenadePlayer[MAXPLAYERS+1][PLATFORM_MAX_PATH];

enum Model {
	String:modelArms[PLATFORM_MAX_PATH],
	String:modelModel[PLATFORM_MAX_PATH]
}
Model Models[PERKS_MAX_ITEMS][Model];
Model PlayerModels[MAXPLAYERS+1][Model];

char g_sServerCommands[PERKS_MAX_ITEMS][64];

Handle perks_bodycolor = INVALID_HANDLE;
Handle perks_tracer = INVALID_HANDLE;
Handle perks_grenskin = INVALID_HANDLE;
Handle perks_model = INVALID_HANDLE;

public void Basic_OnPluginStart()
{
	perks_bodycolor = RegClientCookie("perks_bodycolor", "", CookieAccess_Protected);
	perks_tracer = RegClientCookie("perks_tracer", "", CookieAccess_Protected);
	perks_grenskin = RegClientCookie("perks_grenskin", "", CookieAccess_Protected);
	perks_model = RegClientCookie("perks_model", "", CookieAccess_Protected);
	Perks_RegisterHandler("bcolor", perks_bodycolor, INVALID_FUNCTION, INVALID_FUNCTION, BodyColors_Config, BodyColors_Equip, BodyColors_Remove, true);
	Perks_RegisterHandler("tracer", perks_tracer, INVALID_FUNCTION, INVALID_FUNCTION, Tracer_Config, Tracer_Equip, Tracer_Remove, true);
	Perks_RegisterHandler("grenskin", perks_grenskin, INVALID_FUNCTION, INVALID_FUNCTION, GrenSkin_Config, GrenSkin_Equip, GrenSkin_Remove, true);
	Perks_RegisterHandler("model", perks_model, INVALID_FUNCTION, INVALID_FUNCTION, Model_Config, Model_Equip, Model_Remove, true);
	Perks_RegisterHandler("svcmd", INVALID_HANDLE, INVALID_FUNCTION, INVALID_FUNCTION, SVCMD_Config, SVCMD_Equip, INVALID_FUNCTION, false);

	gH_sTracers = RegClientCookie("sm_sbperks_tracerstatus", "", CookieAccess_Protected);
}

public void Basic_OnMapStart()
{
	g_iBeam = PrecacheModel("materials/sprites/laserbeam.vmt", true);
}

public void Basic_PlayerDeath(Handle event)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(1.0, SpawnDelay, GetClientSerial(client));
}

public void Basic_PlayerSpawn(Handle event)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(1.0, SpawnDelay, GetClientSerial(client));
	CreateTimer(2.0, Timer_SetClientModel, GetClientSerial(client));
}

public Action Timer_SetClientModel(Handle timer, any serial)
{
	int player = GetClientFromSerial(serial);
	if (player == 0)
	{
		return Plugin_Stop;
	}
	SetClientModel(player);
	return Plugin_Handled;
}

public void Basic_Disconnect(int client)
{
	for(int i = 0; i < 3; i++)
	{
		g_aTracerColor[client][i] = 0;
	}
	g_bRainbow[client] = false;
	g_bDisableTracers[client] = false;
	g_sGrenadePlayer[client][0] = '\0';
}

public void Basic_CookiesCached(int client)
{
	char status[8];
	GetClientCookie(client, gH_sTracers, status, sizeof(status));
	if(!StrEqual(status, "off", false))
	g_bDisableTracers[client] = true;
	else
	g_bDisableTracers[client] = false;
}

public void Basic_AskPluginLoad2()
{
	CreateNative("Perks_ToggleTracers", Native_ToggleTracers);
}

public Action SpawnDelay(Handle timer, any serial)
{
	int client = GetClientFromSerial(serial);
	if (client == 0)
	{
		return Plugin_Stop;
	}

	Perks_Reequip(client, "bcolor");
	Perks_Reequip(client, "tracer");
	Perks_Reequip(client, "grenskin");
	Perks_Reequip(client, "model");
	return Plugin_Handled;
}

//START SVCMD
public void SVCMD_Config(Handle &kv, int id)
{
	KvGetString(kv, "cmd", g_sServerCommands[id], sizeof(g_sServerCommands[]));
}

public void SVCMD_Equip(int client, int id)
{
	char clientname[64], clientid[8], command[64];
	GetClientName(client, clientname, sizeof(clientname));
	Format(clientname, sizeof(clientname), "\"%s\"", clientname);

	strcopy(command, sizeof(command), g_sServerCommands[id]);

	//Patches ServerCommand PlayerName exploit
	ReplaceString(clientname, sizeof(clientname), ";", "");
	ReplaceString(command, sizeof(command), "{playername}", clientname);

	Format(clientid, sizeof(clientid), "#%i", GetClientUserId(client));
	ReplaceString(command, sizeof(command), "{playerid}", clientid);

	ServerCommand(command);
}
//END SVCMD

//START MODEL
public void Model_Config(Handle &kv, int id)
{
	KvGetString(kv, "model", Models[id][modelModel], PLATFORM_MAX_PATH);
	KvGetString(kv, "arms", Models[id][modelArms], PLATFORM_MAX_PATH);
	if(FileExists(Models[id][modelModel])) {
		PrecacheModel2(Models[id][modelModel], true);
		Downloader_AddFileToDownloadsTable(Models[id][modelModel]);
	}
	if(FileExists(Models[id][modelArms])) {
		PrecacheModel2(Models[id][modelArms], true);
		Downloader_AddFileToDownloadsTable(Models[id][modelArms]);
	}
}

public void Model_Equip(int client, int id)
{
	PlayerModels[client] = Models[id];
	SetClientModel(client);
}

public void Model_Remove(int client, int id)
{
	PlayerModels[client][modelModel][0] = '\0';
	PlayerModels[client][modelArms][0] = '\0';
}

public void SetClientModel(int client)
{
	if(!IsPlayerAlive(client) || ZR_IsClientZombie(client))
	{
		return;
	}

	if(strlen(PlayerModels[client][modelModel]) != 0)
	{
		if(!IsModelPrecached(PlayerModels[client][modelModel]))
		{
			PrecacheModel(PlayerModels[client][modelModel]);
		}
		SetEntityModel(client, PlayerModels[client][modelModel]);
	}
	if(strlen(PlayerModels[client][modelArms]) != 0)
	{
		if(!IsModelPrecached(PlayerModels[client][modelArms]))
		{
			PrecacheModel(PlayerModels[client][modelArms]);
		}
		SetEntPropString(client, Prop_Send, "m_szArmsModel", PlayerModels[client][modelArms]);
	}
	return;
}
//END MODEL

//START GRENSKIN
public void GrenSkin_Config(Handle &kv, int id)
{
	KvGetString(kv, "model", g_sGrenadeSkin[id], sizeof(g_sGrenadeSkin[]));
	PrecacheModel(g_sGrenadeSkin[id]);
}

public void GrenSkin_Equip(int client, int id)
{
	strcopy(g_sGrenadePlayer[client], sizeof(g_sGrenadePlayer[]), g_sGrenadeSkin[id]);
}

public void GrenSkin_Remove(int client, int id)
{
	g_sGrenadePlayer[client][0] = '\0';
}

public void Basic_GrenSkin_OnEntitySpawnedPost(int entity)
{
	int player = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if(!IsClientInGame(player) || strlen(g_sGrenadePlayer[player]) == 0)
	{
		return;
	}
	if(!IsModelPrecached(g_sGrenadePlayer[player]))
	{
		PrecacheModel(g_sGrenadePlayer[player]);
	}

	SetEntityModel(entity, g_sGrenadePlayer[player]);
}
//END GRENSKIN
//START TRACER
public int Native_ToggleTracers(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	char status[8];
	GetClientCookie(client, gH_sTracers, status, sizeof(status));

	if(!StrEqual(status, "off", false))
	{
		SetClientCookie(client, gH_sTracers, "off");
		PrintChat(client, "You have turned off tracers.");
		g_bDisableTracers[client] = true;
	}
	else
	{
		SetClientCookie(client, gH_sTracers, "on");
		PrintChat(client, "You have turned on tracers.");
		g_bDisableTracers[client] = false;
	}
}
public void Basic_BulletImpact(Handle event)
{
	int player = GetClientOfUserId(GetEventInt(event, "userid"));

	if(!g_bRainbow[player] && (g_aTracerColor[player][0] == g_aTracerColor[player][1]) && (g_aTracerColor[player][1] == g_aTracerColor[player][2]))
	{
		if(g_aTracerColor[player][2] == 255 || g_aTracerColor[player][2] == 0)
		{
			return;
		}
	}

	float m_fOrigin[3], m_fImpact[3];

	GetClientEyePosition(player, m_fOrigin);
	m_fImpact[0] = GetEventFloat(event, "x");
	m_fImpact[1] = GetEventFloat(event, "y");
	m_fImpact[2] = GetEventFloat(event, "z");

	int colorArray[4];
	if(!g_bRainbow[player])
	{
		for(int i = 0; i < 3; i++)
		{
			colorArray[i] = g_aTracerColor[player][i];
		}
	}
	else
	{
		float i = GetGameTime();
		float Frequency = 2.5;

		colorArray[0] = RoundFloat(Sine(Frequency * i + 0.0) * 127.0 + 128.0);
		colorArray[1] = RoundFloat(Sine(Frequency * i + 2.0943951) * 127.0 + 128.0);
		colorArray[2] = RoundFloat(Sine(Frequency * i + 4.1887902) * 127.0 + 128.0);
	}

	colorArray[3] = 255;

	TE_SetupBeamPoints(m_fOrigin, m_fImpact, g_iBeam, 0, 0, 0, 0.1, 1.0, 1.0, 1, 0.0, colorArray, 0);

	int[] clients = new int[MaxClients];
	int client_count;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !g_bDisableTracers[i])
		{
			clients[client_count++] = i;
		}
	}

	TE_Send(clients, client_count);
}

public void Tracer_Config(Handle &kv, int id)
{
	KvGetString(kv, "color", g_sTracerColor[id], sizeof(g_sTracerColor[]));
}

public void Tracer_Equip(int client, int id)
{
	if(StrEqual(g_sTracerColor[id], "rainbow", false)) {
		g_bRainbow[client] = true;
	}
	else {
		ColorStringToArray(g_sTracerColor[id], g_aTracerColor[client]);
		g_bRainbow[client] = false;
	}
}

public void Tracer_Remove(int client, int id)
{
	for(int i = 0; i < 3; i++)
	{
		g_aTracerColor[client][i] = 0;
	}
	g_bRainbow[client] = false;
}
//END TRACER

//START BCOLOR
public void BodyColors_Config(Handle &kv, int id)
{
	KvGetString(kv, "color", g_sBodyColors[id], sizeof(g_sBodyColors[]));
}

public void BodyColors_Equip(int client, int id)
{
	ApplyGlowColor(client, g_sBodyColors[id]);
}

public void BodyColors_Remove(int client, int id)
{
	ApplyGlowColor(client, "");
}

public void ColorStringToArray(const char[] sColorString, int aColor[3])
{
	char asColors[4][4];
	ExplodeString(sColorString, " ", asColors, sizeof(asColors), sizeof(asColors[]));

	aColor[0] = StringToInt(asColors[0]);
	aColor[1] = StringToInt(asColors[1]);
	aColor[2] = StringToInt(asColors[2]);
}

public void ApplyGlowColor(int client, char[] color)
{
	int glowColor[3];
	if(StrEqual(color, ""))
	{
		ColorStringToArray("255 255 255", glowColor);
	}
	else
	{
		ColorStringToArray(color, glowColor);
	}

	if(IsClientInGame(client) && IsPlayerAlive(client))
	{
		SetEntityRenderColor(client, glowColor[0], glowColor[1], glowColor[2], GetClientTransparency(client));
	}
	if(StrEqual(color, "rainbow", false))
	{
		SDKHook(client, SDKHook_PostThinkPost, Rainbow);
	}
	else
	{
		SDKUnhook(client, SDKHook_PostThinkPost, Rainbow);
	}
	return;
}

public void Rainbow(int client)
{
	float i = GetGameTime();
	float Frequency = 2.5;

	int Red   = RoundFloat(Sine(Frequency * i + 0.0) * 127.0 + 128.0);
	int Green = RoundFloat(Sine(Frequency * i + 2.0943951) * 127.0 + 128.0);
	int Blue  = RoundFloat(Sine(Frequency * i + 4.1887902) * 127.0 + 128.0);

	SetEntityRenderColor(client, Red, Green, Blue, GetClientTransparency(client));
}

public int GetClientTransparency(int entity)
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
	return GetEntData(entity, Offset + 4, 1);
}
//END BCOLOR
