#pragma semicolon 1

#include <sourcemod>
#include <colors_csgo>
#include <skillbot>
#include <chat-processor>

#pragma newdecls required
#define PLUGIN_VERSION "CP1.0"

public Plugin myinfo =  {
	name = "SkillBot CP ChatTags", 
	author = "AntiTeal", 
	description = "Enables SkillBot chattags for servers with CP.", 
	version = PLUGIN_VERSION, 
	url = "antiteal.com"
};

public void OnPluginStart()
{
	CreateConVar("sm_skillbot_chattags_version", PLUGIN_VERSION, "Plugin Version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);
	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");
}

public Action CP_OnChatMessage(int& client, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool& processcolors, bool& removecolors)
{
	char rank[64], rank2[75];
	SB_GetChatRank(client, rank, sizeof(rank));
	if(strlen(rank) != 0)
	{
		Format(rank2, sizeof(rank2), "%s{teamcolor}", rank);
		CFormat(rank2, sizeof(rank2), client);

		Format(name, MAXLENGTH_NAME, "%s %s", rank2, name);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}