#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#pragma newdecls required

#define PLUGIN_VERSION "1.0"

public Plugin myinfo = {
	name = "ParticleLog",
	author = "AntiTeal",
	description = "",
	version = PLUGIN_VERSION,
	url = ""
};

Handle logFile;
char particleFile[64], mapName[32];
Handle g_aParticleList;
Handle g_adtArray;

public void OnPluginStart()
{
	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");
}

public void OnMapStart()
{
	GetCurrentMap(mapName, sizeof(mapName));
	BuildPath(Path_SM, particleFile, PLATFORM_MAX_PATH, "particlelog/%s.log", mapName); 
	logFile = OpenFile(particleFile, "at+");
	CheckFile();
}
public void CheckFile()
{
	g_aParticleList = CreateArray(255);

	while (!IsEndOfFile(logFile))
	{
		char line[255];

		if(!ReadFileLine(logFile, line, sizeof(line)))
		{
			break;
		}	

		TrimString(line);

		if (!line[0])
		continue;			

		PushArrayString(g_aParticleList, line);
	}
	WriteParticles();
}

public void WriteParticles()
{
	g_adtArray = CreateArray(256);
	int index = -1;

	while ((index = FindEntityByClassname(index, "info_particle_system")) != -1) {
		char p[256];
		GetEntPropString(index, Prop_Data, "m_iszEffectName", p, sizeof(p));
		if(StrContains(p, "custom_particle_", false) == -1)
		{
			if(FindStringInArray(g_adtArray, p) == -1 && FindStringInArray(g_aParticleList, p) == -1)
			{
				PushArrayString(g_adtArray, p);
				WriteFileLine(logFile, p);
			}
		}
	}
	CloseHandle(logFile);
	CheckDelete();
}

public void CheckDelete()
{
	if(FileSize(particleFile) == 0)
	{
		DeleteFile(particleFile);
	}
}