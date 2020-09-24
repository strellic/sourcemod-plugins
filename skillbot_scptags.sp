#pragma semicolon 1

#include <sourcemod>
#include <colors_csgo>
#include <scp>
#include <skillbot>

#pragma newdecls required
#define PLUGIN_VERSION "SCP1.0"

public Plugin myinfo =  {
	name = "SkillBot SCP ChatTags", 
	author = "AntiTeal", 
	description = "Enables SkillBot chattags for servers with SCP.", 
	version = PLUGIN_VERSION, 
	url = "antiteal.com"
};

public void OnPluginStart()
{
	CreateConVar("sm_skillbot_chattags_version", PLUGIN_VERSION, "Plugin Version", FCVAR_SPONLY | FCVAR_REPLICATED | FCVAR_NOTIFY);
	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");
}

public Action OnChatMessage(int &client, Handle recipients, char[] sName, char[] sMessage)
{
	char rank[64];
	SB_GetChatRank(client, rank, sizeof(rank));

	if(strlen(rank) != 0)
	{
		CFormat(rank, sizeof(rank), client);
		Format(sName, MAXLENGTH_INPUT, "%s%s", rank, sName);
	}
}