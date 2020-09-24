//====================================================================================================
//
// Name: ForceInput
// Author: zaCade
// Description: Allows admins to force inputs on entities. (ent_fire)
//
//====================================================================================================
#include <sourcemod>
#include <sdktools>

#pragma newdecls required

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Plugin myinfo =
{
	name 			= "ForceInput",
	author 			= "AntiTeal + zaCade + BotoX",
	description 	= "Allows admins to force inputs on entities. (ent_fire)",
	version 		= "1.3",
	url 			= ""
};

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public void OnPluginStart()
{
	LoadTranslations("common.phrases");

	RegAdminCmd("sm_forceinput", Command_ForceInput, ADMFLAG_ROOT);
	RegAdminCmd("sm_forceinputplayer", Command_ForceInputPlayer, ADMFLAG_ROOT);
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action Command_ForceInputPlayer(int client, int args)
{
	if (GetCmdArgs() < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_forceinputplayer <target> <input> [parameter]");
		return Plugin_Handled;
	}

	char sArguments[3][256];
	GetCmdArg(1, sArguments[0], sizeof(sArguments[]));
	GetCmdArg(2, sArguments[1], sizeof(sArguments[]));
	GetCmdArg(3, sArguments[2], sizeof(sArguments[]));

	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;

	if((target_count = ProcessTargetString(
			sArguments[0],
			client,
			target_list,
			MAXPLAYERS,
			0,
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}

	for(int i = 0; i < target_count; i++)
	{
		if (sArguments[2][0])
			SetVariantString(sArguments[2]);

		AcceptEntityInput(target_list[i], sArguments[1], target_list[i], target_list[i]);
		ReplyToCommand(client, "[SM] Input succesfull.");
	}

	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public Action Command_ForceInput(int client, int args)
{
	if (GetCmdArgs() < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_forceinput <classname/targetname> <input> [parameter]");
		return Plugin_Handled;
	}

	char sArguments[3][256];
	GetCmdArg(1, sArguments[0], sizeof(sArguments[]));
	GetCmdArg(2, sArguments[1], sizeof(sArguments[]));
	GetCmdArg(3, sArguments[2], sizeof(sArguments[]));

	if (StrEqual(sArguments[0], "!self"))
	{
		if (sArguments[2][0])
			SetVariantString(sArguments[2]);

		AcceptEntityInput(client, sArguments[1], client, client);
		ReplyToCommand(client, "[SM] Input succesfull.");
	}
	else if (StrEqual(sArguments[0], "!target") || StrEqual(sArguments[0], "!picker"))
	{
		int entity = INVALID_ENT_REFERENCE;

		float fPosition[3], fAngles[3];
		GetClientEyePosition(client, fPosition);
		GetClientEyeAngles(client, fAngles);

		Handle hTrace = TR_TraceRayFilterEx(fPosition, fAngles, MASK_SOLID, RayType_Infinite, TraceRayFilter, client);

		if (TR_DidHit(hTrace) && ((entity = TR_GetEntityIndex(hTrace)) >= 1))
		{
			if (IsValidEntity(entity) || IsValidEdict(entity))
			{
				if (sArguments[2][0])
					SetVariantString(sArguments[2]);

				AcceptEntityInput(entity, sArguments[1], client, client);
				ReplyToCommand(client, "[SM] Input succesfull.");
			}
		}
	}
	else
	{
		int entity = INVALID_ENT_REFERENCE;

		while ((entity = FindEntityByClassname(entity, "*")) != INVALID_ENT_REFERENCE)
		{
			if (IsValidEntity(entity) || IsValidEdict(entity))
			{
				char sClassname[64], sTargetname[64];
				GetEntPropString(entity, Prop_Data, "m_iClassname", sClassname, sizeof(sClassname));
				GetEntPropString(entity, Prop_Data, "m_iName", sTargetname, sizeof(sTargetname));

				if (StrEqual(sClassname, sArguments[0], false) || StrEqual(sTargetname, sArguments[0], false))
				{
					if (sArguments[2][0])
						SetVariantString(sArguments[2]);

					AcceptEntityInput(entity, sArguments[1], client, client);
					ReplyToCommand(client, "[SM] Input succesfull.");
				}
			}
		}
	}
	return Plugin_Handled;
}

//----------------------------------------------------------------------------------------------------
// Purpose:
//----------------------------------------------------------------------------------------------------
public bool TraceRayFilter(int entity, int mask, any client)
{
	if (entity == client)
		return false;

	return true;
}
