#pragma semicolon 1

#include <sourcemod>
#include <colors_csgo>
#include <skillbot>
#include <togschattags>

#pragma newdecls required
#define PLUGIN_VERSION "TOG1.0"

public Plugin myinfo =  {
	name = "SkillBot TOG ChatTags", 
	author = "AntiTeal", 
	description = "Enables SkillBot chattags for servers with TOG.", 
	version = PLUGIN_VERSION, 
	url = "antiteal.com"
};

public void OnPluginStart()
{
	CreateConVar("sm_skillbot_chattags_version", PLUGIN_VERSION, "Plugin Version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);
	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");

	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
}

public Action Command_Say(int client, const char[] cmd, int argc)
{
	char rank[64], name[75];
	SB_GetChatRank(client, rank, sizeof(rank));
	if(strlen(rank) != 0)
	{
		Format(name, sizeof(name), "%s{teamcolor}", rank);
		CFormat(name, sizeof(name), client);

		tct_SetExtTag(client, name, "");
	}
}