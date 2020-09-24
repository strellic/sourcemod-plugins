#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <clientprefs>

#include <colors_csgo>
#include <zombiereloaded>

#define PLUGIN_VERSION "2.3a"

public Plugin myinfo = {
	name = "[sG] GunShop",
	author = "sG | AntiTeal",
	description = "GunShop for the ZE Server.",
	version = PLUGIN_VERSION,
	url = "www.joinsg.net"
};

Handle weaponTrie[MAXPLAYERS + 1];

//AutoBuy Cookies
Handle gH_ABPrimary, gH_ABPistol, gH_ABEquip1, gH_ABEquip2, gH_ABEquip3, gH_ABStatus, gH_QuickBuy;

bool g_IsSelectingPrimary[MAXPLAYERS + 1], g_IsSelectingPistol[MAXPLAYERS + 1], g_IsSelectingEquip1[MAXPLAYERS + 1], g_IsSelectingEquip2[MAXPLAYERS + 1], g_IsSelectingEquip3[MAXPLAYERS + 1];
bool buyZone[MAXPLAYERS+1], autoBuy[MAXPLAYERS+1], canBuyZone, cantBuy[MAXPLAYERS+1] = false;

ConVar g_cVBuyTime;

public OnPluginStart()
{
	g_cVBuyTime = FindConVar("mp_buytime");
	CreateConVar("sm_gunshop_version", PLUGIN_VERSION, "GunSHOP Version", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);

	LoadTranslations("common.phrases");
	LoadTranslations("core.phrases");

	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("round_start", Event_RoundStart);

	//Late Start Support
	for (new i = 1; i <= MAXPLAYERS + 1; i++)
	{
		if(IsValidClient(i))
		{
			CreatePlayerTrie(i);
		}
	}

	gH_ABPrimary = RegClientCookie("sm_gs_ab_primary", "The primary weapon the player wants to buy at spawn.", CookieAccess_Private);
	gH_ABPistol = RegClientCookie("sm_gs_ab_pistol", "The pistol that the player wants to buy at spawn.", CookieAccess_Private);
	gH_ABEquip1 = RegClientCookie("sm_gs_ab_nade1", "Equipment Slot #1, the player buys this at spawn.", CookieAccess_Private);
	gH_ABEquip2 = RegClientCookie("sm_gs_ab_nade2", "Equipment Slot #2, the player buys this at spawn.", CookieAccess_Private);
	gH_ABEquip3 = RegClientCookie("sm_gs_ab_nade3", "Equipment Slot #3, the player buys this at spawn.", CookieAccess_Private);
	gH_ABStatus = RegClientCookie("sm_gs_ab_status", "The status for the AutoBuy GunShop system.", CookieAccess_Private);

	gH_QuickBuy = RegClientCookie("sm_gs_quickbuy_status", "The status for the QuickBuy GunShop system.", CookieAccess_Private);

	//Oh boy, here it comes!
	//Grenades + Misc Items
	RegConsoleCmd("sm_decoy", Command_Decoy);
	RegConsoleCmd("sm_he", Command_HE);
	RegConsoleCmd("sm_molotov", Command_Molotov);
	RegConsoleCmd("sm_incendiary", Command_Incendiary);
	RegConsoleCmd("sm_kevlar", Command_Kevlar);
	RegConsoleCmd("sm_heavykevlar", Command_HeavyKevlar);
	RegConsoleCmd("sm_healthshot", Command_Healthshot);
	RegConsoleCmd("sm_knife", Command_Knife);
	RegConsoleCmd("sm_tactical", Command_Tactical);
	//Pistols
	RegConsoleCmd("sm_glock", Command_Glock);
	RegConsoleCmd("sm_glock18", Command_Glock);
	RegConsoleCmd("sm_cz75", Command_CZ75);
	RegConsoleCmd("sm_cz75a", Command_CZ75);
	RegConsoleCmd("sm_cz", Command_CZ75);
	RegConsoleCmd("sm_usps", Command_USP);
	RegConsoleCmd("sm_usp", Command_USP);
	RegConsoleCmd("sm_p2000", Command_P2000);
	RegConsoleCmd("sm_tec", Command_Tec9);
	RegConsoleCmd("sm_tec9", Command_Tec9);
	RegConsoleCmd("sm_p250", Command_P250);
	RegConsoleCmd("sm_deagle", Command_Deagle);
	RegConsoleCmd("sm_deag", Command_Deagle);
	RegConsoleCmd("sm_deserteagle", Command_Deagle);
	RegConsoleCmd("sm_elite", Command_Elite);
	RegConsoleCmd("sm_dual", Command_Elite);
	RegConsoleCmd("sm_berettas", Command_Elite);
	RegConsoleCmd("sm_dualberettas", Command_Elite);
	RegConsoleCmd("sm_fiveseven", Command_FiveSeven);
	RegConsoleCmd("sm_57", Command_FiveSeven);
	RegConsoleCmd("sm_revolver", Command_Revolver);
	RegConsoleCmd("sm_r8", Command_Revolver);
	//SMGs
	RegConsoleCmd("sm_mac", Command_Mac10);
	RegConsoleCmd("sm_mac10", Command_Mac10);
	RegConsoleCmd("sm_mp9", Command_MP9);
	RegConsoleCmd("sm_pp", Command_PPBizon);
	RegConsoleCmd("sm_bizon", Command_PPBizon);
	RegConsoleCmd("sm_ppbizon", Command_PPBizon);
	RegConsoleCmd("sm_mp7", Command_MP7);
	RegConsoleCmd("sm_ump", Command_UMP45);
	RegConsoleCmd("sm_ump45", Command_UMP45);
	RegConsoleCmd("sm_p90", Command_P90);
	//Rifles
	RegConsoleCmd("sm_galil", Command_GalilAR);
	RegConsoleCmd("sm_galilar", Command_GalilAR);
	RegConsoleCmd("sm_famas", Command_Famas);
	RegConsoleCmd("sm_ak", Command_AK47);
	RegConsoleCmd("sm_ak47", Command_AK47);
	RegConsoleCmd("sm_m4", Command_M4A4);
	RegConsoleCmd("sm_m4a4", Command_M4A4);
	RegConsoleCmd("sm_m4a1", Command_M4A1s);
	RegConsoleCmd("sm_m4a1s", Command_M4A1s);
	RegConsoleCmd("sm_scar", Command_Scar20);
	RegConsoleCmd("sm_scar20", Command_Scar20);
	RegConsoleCmd("sm_sg", Command_SG553);
	RegConsoleCmd("sm_sg553", Command_SG553);
	RegConsoleCmd("sm_aug", Command_AUG);
	RegConsoleCmd("sm_ssg", Command_SSG08);
	RegConsoleCmd("sm_ssg08", Command_SSG08);
	RegConsoleCmd("sm_g3sg1", Command_G3SG1);
	RegConsoleCmd("sm_awp", Command_AWP);
	//Heavy
	RegConsoleCmd("sm_negev", Command_Negev);
	RegConsoleCmd("sm_m249", Command_M249);
	RegConsoleCmd("sm_nova", Command_Nova);
	RegConsoleCmd("sm_xm", Command_XM1014);
	RegConsoleCmd("sm_xm1014", Command_XM1014);
	RegConsoleCmd("sm_sawed", Command_SawedOff);
	RegConsoleCmd("sm_sawedoff", Command_SawedOff);
	RegConsoleCmd("sm_mag", Command_Mag7);
	RegConsoleCmd("sm_mag7", Command_Mag7);

	RegConsoleCmd("sm_guns", GunMenu);

	HookEvent("enter_buyzone", Enter_BuyZone, EventHookMode_Post);
	HookEvent("exit_buyzone", Exit_BuyZone, EventHookMode_Post);

	RegAdminCmd("sm_guntype", Command_Test, ADMFLAG_GENERIC);

	AddCommandListener(sayHook, "say");

}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    if (IsValidClient(client) && ((buttons & IN_SPEED) == IN_SPEED))
    {
    	char sCookie[32];
    	GetClientCookie(client, gH_QuickBuy, sCookie, sizeof(sCookie));
    	if(IsPlayerAlive(client) && ZR_IsClientHuman(client) && !StrEqual(sCookie, "off", false))
		{
			QuickMenu(client);
		}
    }
    return Plugin_Continue;
}

public Action:QuickMenu(int client)
{
	Handle menu = CreateMenu(QuickMenuHandler);
	SetMenuTitle(menu, "GunSHOP QuickMenu\nMoney: $%i", getMoney(client));

	new bizonVal, mp9Val, negevVal;
	char bizon[64], mp9[64], negev[64];

	GetTrieValue(weaponTrie[client], "weapon_bizon", bizonVal);
	GetTrieValue(weaponTrie[client], "weapon_mp9", mp9Val);
	GetTrieValue(weaponTrie[client], "weapon_negev", negevVal);

	Format(bizon, sizeof(bizon), "PP-Bizon (%i/1)", bizonVal);
	Format(mp9, sizeof(mp9), "MP9 (%i/1)", mp9Val);
	Format(negev, sizeof(negev), "Negev (%i/1)", negevVal);

	AddMenuItem(menu, "sm_bizon",  bizon);
	AddMenuItem(menu, "sm_mp9", mp9);
	AddMenuItem(menu, "sm_negev", negev);
	if(buyZone[client])
	{
		AddMenuItem(menu, "sm_he",  "HEGrenade - $300");
		AddMenuItem(menu, "sm_molotov",  "Molotov - $400");
		AddMenuItem(menu, "sm_healthshot",  "Healthshot - $500");
	}
	else
	{
		AddMenuItem(menu, "sm_he",  "HEGrenade - $6500");
		AddMenuItem(menu, "sm_molotov",  "Molotov - $6500");
		AddMenuItem(menu, "sm_healthshot",  "Healthshot - $2500");
	}
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 2);

	return Plugin_Continue;
}

public int QuickMenuHandler(Handle:menu, MenuAction:action, client, position)
{
	if(action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, position, info, sizeof(info));

		FakeClientCommand(client, info);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action:sayHook(client, const String:command[], argc)
{
	if(IsValidClient(client))
	{
		char buffer[256];
		GetCmdArgString(buffer, sizeof(buffer));
		StripQuotes(buffer);

		if(StrEqual(buffer, "guns", false))
		{
			FakeClientCommand(client, "sm_guns");
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
} 

public Action:Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	canBuyZone = true;
	CreateTimer(g_cVBuyTime.FloatValue, DisableBuyZone);

	for(new i = 1; i <= MaxClients; i++)
	{
		if(IsValidClient(i))
		{
			cantBuy[i] = false;
		}
	}
}

public Action DisableBuyZone(Handle timer)
{
	canBuyZone = false;
}

public Action:Enter_BuyZone(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(canBuyZone)
	{
    	buyZone[GetClientOfUserId(GetEventInt(event, "userid"))] = true;
	}
}

public Action:Exit_BuyZone(Handle:event, const String:name[], bool:dontBroadcast)
{
    buyZone[GetClientOfUserId(GetEventInt(event, "userid"))] = false;
}  

stock bool:IsValidClient(client, bool:nobots = true)
{ 
    if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
    {
        return false; 
    }
    return IsClientInGame(client); 
}  

public Action:Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	CreatePlayerTrie(client);

	if (IsClientInGame(client) && IsPlayerAlive(client))
	{
		CreateTimer(1.0, ItemSpawn, GetClientSerial(client));
	}
}

public Action ItemSpawn(Handle timer, any serial)
{
	int client = GetClientFromSerial(serial);
	if (client == 0 || cantBuy[client])
	{
		return Plugin_Stop;
	}

	cantBuy[client] = true;
	char sCookie[64], sCookie2[64], sCookie3[64], sCookie4[64], sCookie5[64], Status[8];
	
	GetClientCookie(client, gH_ABStatus, Status, sizeof(Status));
	GetClientCookie(client, gH_ABPrimary, sCookie, sizeof(sCookie));
	GetClientCookie(client, gH_ABPistol, sCookie2, sizeof(sCookie2));
	GetClientCookie(client, gH_ABEquip1, sCookie3, sizeof(sCookie3));
	GetClientCookie(client, gH_ABEquip2, sCookie4, sizeof(sCookie4));
	GetClientCookie(client, gH_ABEquip3, sCookie5, sizeof(sCookie5));
	
	if(IsPlayerAlive(client) && ZR_IsClientHuman(client) && !StrEqual(Status, "off", false))
	{
		autoBuy[client] = true;

		FakeClientCommand(client, sCookie);
		FakeClientCommand(client, sCookie2);
		FakeClientCommand(client, sCookie3);
		FakeClientCommand(client, sCookie4);
		FakeClientCommand(client, sCookie5);
	}
	CreateTimer(2.5, ResetBuy, GetClientSerial(client));
	return Plugin_Handled;
}

public Action ResetBuy(Handle timer, any serial)
{
	int client = GetClientFromSerial(serial);
	autoBuy[client] = false;
	cantBuy[client] = false;
}

public OnClientConnected(client)
{
	CreatePlayerTrie(client);
}

stock CreatePlayerTrie(client)
{
	weaponTrie[client] = CreateTrie();
	ClearTrie(weaponTrie[client]);
}

public OnClientDisconnect(client)
{
	if(weaponTrie[client] != INVALID_HANDLE) {
		CloseHandle(weaponTrie[client]);
	}
}

public NotValidClient(client) 
{
	if (!IsValidClient(client) || !IsPlayerAlive(client) || GetClientTeam(client) < 2 || ZR_IsClientZombie(client))
		return true;
	else
		return false;
}

stock getMoney(client) {
	new money = GetEntProp(client, Prop_Send, "m_iAccount");
	return money;
}

stock setMoney(client, int amount) {
	SetEntProp(client, Prop_Send, "m_iAccount", amount);
}

stock resetSelecting(i)
{
	g_IsSelectingPrimary[i] = false;
	g_IsSelectingEquip1[i] = false;
	g_IsSelectingEquip2[i] = false;
	g_IsSelectingEquip3[i] = false;
	g_IsSelectingPistol[i] = false;
}

char miscGuns[][] = {
	"sm_decoy", "sm_he", "sm_incendiary", "sm_molotov", "sm_tactical", "sm_knife", "sm_healthshot", "sm_kevlar", "sm_heavykevlar"
};

char pistolGuns[][] = {
	"sm_glock", "sm_usp", "sm_usps", "sm_p2000", "sm_p250", "sm_deagle", "sm_elite", "sm_57", "sm_fiveseven", "sm_tec9", "sm_cz75", "sm_revolver"
};

stock GunShop(int client, char[] weapon, char[] shortName, int price, bool useTrie, int slot, char[] referenceCMD, int buyZonePrice, int times) 
{
	bool buyZoneUsed = false;
	if(g_IsSelectingPrimary[client] && gunType(referenceCMD) == 3)
	{
		g_IsSelectingPrimary[client] = false;
		SetClientCookie(client, gH_ABPrimary, referenceCMD);
		CPrintToChat(client, "{red}[GS]{lightblue} AutoBuy: Primary Weapon set.");
		AutoBuyMenu(client, 0);
	}
	else if(g_IsSelectingPistol[client] && gunType(referenceCMD) == 1)
	{
		g_IsSelectingPistol[client] = false;
		SetClientCookie(client, gH_ABPistol, referenceCMD);
		CPrintToChat(client, "{red}[GS]{lightblue} AutoBuy: Pistol set.");
		AutoBuyMenu(client, 0);
	}
	else if(g_IsSelectingEquip1[client] && gunType(referenceCMD) == 2)
	{
		g_IsSelectingEquip1[client] = false;
		SetClientCookie(client, gH_ABEquip1, referenceCMD);
		CPrintToChat(client, "{red}[GS]{lightblue} AutoBuy: Equipment #1 set.");
		AutoBuyMenu(client, 0);
	}
	else if(g_IsSelectingEquip2[client] && gunType(referenceCMD) == 2)
	{
		g_IsSelectingEquip2[client] = false;
		SetClientCookie(client, gH_ABEquip2, referenceCMD);
		CPrintToChat(client, "{red}[GS]{lightblue} AutoBuy: Equipment #2 set.");
		AutoBuyMenu(client, 0);
	}
	else if(g_IsSelectingEquip3[client] && gunType(referenceCMD) == 2)
	{
		g_IsSelectingEquip3[client] = false;
		SetClientCookie(client, gH_ABEquip3, referenceCMD);
		CPrintToChat(client, "{red}[GS]{lightblue} AutoBuy: Equipment #3 set.");
		AutoBuyMenu(client, 0);
	}
	else
	{
		resetSelecting(client);
		if(NotValidClient(client) && !StrEqual(referenceCMD, "sm_knife", false))
		{
			CPrintToChat(client, "{red}[GS]{lightblue} You can't buy a weapon!");
			return;
		}
		if(useTrie) 
		{
			if(!autoBuy[client])
			{
				int current;
				if (!GetTrieValue(weaponTrie[client], weapon, current))
				{
					current = 0;
				}
				if(times <= current)
				{
					CPrintToChat(client, "{red}[GS]{lightblue} You can only buy %i {green}%s{lightblue} per round!", times);
					return;
				}
				else
				{
					SetTrieValue(weaponTrie[client], weapon, ++current);
				}
			}
		}
		if(price != 0)
		{
			if(buyZone[client])
			{
				if(getMoney(client) < buyZonePrice)
				{
					CPrintToChat(client, "{red}[GS]{lightblue} You don't have enough money, you need {green}$%i{lightblue}.", buyZonePrice);
					return;
				}
				else
				{
					setMoney(client, (getMoney(client) - buyZonePrice));
					buyZoneUsed = true;
				}
			}
			else
			{
				if(getMoney(client) < price)
				{
					CPrintToChat(client, "{red}[GS]{lightblue} You don't have enough money, you need {green}$%i{lightblue}.", price);
					return;
				}
				else
				{
					setMoney(client, (getMoney(client) - price));
				}
			}
		}

		if(slot != -1)
		{
			new weaponEnt = GetPlayerWeaponSlot(client, slot);
			if (weaponEnt != -1)
			{
				CS_DropWeapon(client, weaponEnt, false, false);
			}
		}

		if(IsValidClient(client))
		{
			int wpn = GivePlayerItem(client, weapon);
			bool isSpecial;
			if(IsValidEntity(wpn) && !autoBuy[client]) 
			{
				for (int a = 0; a < sizeof(miscGuns); a++)
				{
					if(StrEqual(referenceCMD, miscGuns[a], false))
					{
						isSpecial = true;
					}
				}
				if(!isSpecial) {
					SetEntProp(wpn, Prop_Send, "m_iClip1", 0);
				}
			}
		}

		if(price != 0)
		{
			if(buyZoneUsed)
			{
				CPrintToChat(client, "{red}[GS]{lightblue} You have bought a {green}%s{lightblue} for {green}$%i{lightblue}.", shortName, buyZonePrice);
			}
			else
			{
				CPrintToChat(client, "{red}[GS]{lightblue} You have bought a {green}%s{lightblue} for {green}$%i{lightblue}.", shortName, price);
			}
		}
		else
		{
			CPrintToChat(client, "{red}[GS]{lightblue} You have bought a {green}%s{lightblue}.", shortName);
		}
	}
}

public Action:Command_Test(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_guntype <sm_gunname>");
		return Plugin_Handled;
	}

	char arg1[64];
	GetCmdArg(1, arg1, sizeof(arg1));

	ReplyToCommand(client, "%i", gunType(arg1));
	return Plugin_Handled;
}

stock gunType(char[] cmdString)
{
	for (int a = 0; a < sizeof(miscGuns); a++)
	{
		if(StrEqual(cmdString, miscGuns[a], false))
		{
			return 2;
		}
	}
	for (int a = 0; a < sizeof(pistolGuns); a++)
	{
		if(StrEqual(cmdString, pistolGuns[a], false))
		{
			return 1;
		}
	}
	return 3;
}

//Oh boy, here it comes (Part 2)

public Action:Command_Decoy(int client, int args)
{
	GunShop(client, "weapon_decoy", "Decoy", 6500, false, -1, "sm_decoy", 50, 1);
	return Plugin_Handled;
}
public Action:Command_HE(int client, int args)
{
	GunShop(client, "weapon_hegrenade", "HE", 6500, false, -1, "sm_he", 300, 1);
	return Plugin_Handled;
}
public Action:Command_Molotov(int client, int args)
{
	GunShop(client, "weapon_molotov", "Molotov", 6500, false, -1, "sm_molotov", 400, 1);
	return Plugin_Handled;
}
public Action:Command_Incendiary(int client, int args)
{
	GunShop(client, "weapon_incgrenade", "Incendiary", 6500, false, -1, "sm_incendiary", 400, 1);
	return Plugin_Handled;
}
public Action:Command_Kevlar(int client, int args)
{
	GunShop(client, "item_assaultsuit", "Kevlar", 3000, false, -1, "sm_kevlar", 1000, 1);
	return Plugin_Handled;
}
public Action:Command_HeavyKevlar(int client, int args)
{
	//Broke due to Operation Hydra Update
	//GunShop(client, "item_heavyassaultsuit", "Heavy-Kevlar", 6000, true, false, -1, "sm_heavykevlar", 2000);

	char[] shortName = "Heavy-Kevlar";
	int price = 6000, buyZonePrice = 2000;
	bool buyZoneUsed;

	if(NotValidClient(client))
	{
		CPrintToChat(client, "{red}[GS]{lightblue} You can't buy a weapon!");
		return Plugin_Handled;
	}

	if(buyZone[client])
	{
		if(getMoney(client) < buyZonePrice)
		{
			CPrintToChat(client, "{red}[GS]{lightblue} You don't have enough money, you need {green}$%i{lightblue}.", buyZonePrice);
			return Plugin_Handled;
		}
		else
		{
			setMoney(client, (getMoney(client) - buyZonePrice));
			buyZoneUsed = true;
		}
	}
	else
	{
		if(getMoney(client) < price)
		{
			CPrintToChat(client, "{red}[GS]{lightblue} You don't have enough money, you need {green}$%i{lightblue}.", price);
			return Plugin_Handled;
		}
		else
		{
			setMoney(client, (getMoney(client) - price));
		}
	}

	if(buyZoneUsed)
	{
		CPrintToChat(client, "{red}[GS]{lightblue} You have bought a {green}%s{lightblue} for {green}$%i{lightblue}.", shortName, buyZonePrice);
	}
	else
	{
		CPrintToChat(client, "{red}[GS]{lightblue} You have bought a {green}%s{lightblue} for {green}$%i{lightblue}.", shortName, price);
	}

	SetEntProp(client, Prop_Send, "m_ArmorValue", 200, 1);

	return Plugin_Handled;
}
public Action:Command_Healthshot(int client, int args)
{
	GunShop(client, "weapon_healthshot", "Healthshot", 2500, false, -1, "sm_healthshot", 500, 1);
	return Plugin_Handled;
}
public Action:Command_Knife(int client, int args)
{
	GunShop(client, "weapon_knife", "Knife", 0, true, 2, "sm_knife", 0, 1);
	return Plugin_Handled;
}
public Action:Command_Tactical(int client, int args)
{
	GunShop(client, "weapon_tagrenade", "Tactical", 2500, false, -1, "sm_tactical", 250, 1);
	return Plugin_Handled;
}
public Action:Command_Glock(int client, int args)
{
	GunShop(client, "weapon_glock", "Glock", 0, true, 1, "sm_glock", 0, 1);
	return Plugin_Handled;
}
public Action:Command_CZ75(int client, int args)
{
	GunShop(client, "weapon_cz75a", "CZ-75", 0, true, 1, "sm_cz75", 0, 1);
	return Plugin_Handled;
}
public Action:Command_USP(int client, int args)
{
	GunShop(client, "weapon_usp_silencer", "USP-S", 0, true, 1, "sm_usp", 0, 1);
	return Plugin_Handled;
}
public Action:Command_P2000(int client, int args)
{
	GunShop(client, "weapon_hkp2000", "P2000", 0, true, 1, "sm_p2000", 0, 1);
	return Plugin_Handled;
}
public Action:Command_Tec9(int client, int args)
{
	GunShop(client, "weapon_tec9", "TEC-9", 0, true, 1, "sm_tec9", 0, 1);
	return Plugin_Handled;
}
public Action:Command_P250(int client, int args)
{
	GunShop(client, "weapon_p250", "P250", 0, true, 1, "sm_p250", 0, 1);
	return Plugin_Handled;
}
public Action:Command_Deagle(int client, int args)
{
	GunShop(client, "weapon_deagle", "Desert-Eagle", 0, true, 1, "sm_deagle", 0, 1);
	return Plugin_Handled;
}
public Action:Command_Elite(int client, int args)
{
	GunShop(client, "weapon_elite", "Dual Berettas", 0, true, 1, "sm_elite", 0, 1);
	return Plugin_Handled;
}
public Action:Command_FiveSeven(int client, int args)
{
	GunShop(client, "weapon_fiveseven", "Five-SeveN", 0, true, 1, "sm_fiveseven", 0, 1);
	return Plugin_Handled;
}
public Action:Command_Revolver(int client, int args)
{
	GunShop(client, "weapon_revolver", "R8-Revolver", 0, true, 1, "sm_revolver", 0, 1);
	return Plugin_Handled;
}
public Action:Command_Mac10(int client, int args)
{
	GunShop(client, "weapon_mac10", "MAC-10", 0, true, 0, "sm_mac10", 0, 1);
	return Plugin_Handled;
}
public Action:Command_MP9(int client, int args)
{
	GunShop(client, "weapon_mp9", "MP9", 0, true, 0, "sm_mp9", 0, 1);
	return Plugin_Handled;
}
public Action:Command_PPBizon(int client, int args)
{
	GunShop(client, "weapon_bizon", "PP-Bizon", 0, true, 0, "sm_bizon", 0, 1);
	return Plugin_Handled;
}
public Action:Command_MP7(int client, int args)
{
	GunShop(client, "weapon_mp7", "MP7", 0, true, 0, "sm_mp7", 0, 1);
	return Plugin_Handled;
}
public Action:Command_UMP45(int client, int args)
{
	GunShop(client, "weapon_ump45", "UMP-45", 0, true, 0, "sm_ump45", 0, 1);
	return Plugin_Handled;
}
public Action:Command_P90(int client, int args)
{
	GunShop(client, "weapon_p90", "P90", 0, true, 0, "sm_p90", 0, 1);
	return Plugin_Handled;
}
public Action:Command_GalilAR(int client, int args)
{
	GunShop(client, "weapon_galilar", "Galil-AR", 0, true, 0, "sm_galilar", 0, 1);
	return Plugin_Handled;
}
public Action:Command_Famas(int client, int args)
{
	GunShop(client, "weapon_famas", "FAMAS", 0, true, 0, "sm_famas", 0, 1);
	return Plugin_Handled;
}
public Action:Command_AK47(int client, int args)
{
	GunShop(client, "weapon_ak47", "AK-47", 0, true, 0, "sm_ak47", 0, 1);
	return Plugin_Handled;
}
public Action:Command_M4A4(int client, int args)
{
	GunShop(client, "weapon_m4a1", "M4A4", 0, true, 0, "sm_m4a4", 0, 1);
	return Plugin_Handled;
}
public Action:Command_M4A1s(int client, int args)
{
	GunShop(client, "weapon_m4a1_silencer", "M4A1-S", 0, true, 0, "sm_m4a1s", 0, 1);
	return Plugin_Handled;
}
public Action:Command_Scar20(int client, int args)
{
	GunShop(client, "weapon_scar20", "SCAR-20", 0, true, 0, "sm_scar", 0, 1);
	return Plugin_Handled;
}
public Action:Command_SG553(int client, int args)
{
	GunShop(client, "weapon_sg556", "SG-553", 0, true, 0, "sm_sg553", 0, 1);
	return Plugin_Handled;
}
public Action:Command_AUG(int client, int args)
{
	GunShop(client, "weapon_aug", "AUG", 0, true, 0, "sm_aug", 0, 1);
	return Plugin_Handled;
}
public Action:Command_SSG08(int client, int args)
{
	GunShop(client, "weapon_ssg08", "SSG", 0, true, 0, "sm_ssg", 0, 1);
	return Plugin_Handled;
}
public Action:Command_G3SG1(int client, int args)
{
	GunShop(client, "weapon_g3sg1", "G3SG1", 0, true, 0, "sm_g3sg1", 0, 1);
	return Plugin_Handled;
}
public Action:Command_AWP(int client, int args)
{
	GunShop(client, "weapon_awp", "AWP", 0, true, 0, "sm_awp", 0, 1);
	return Plugin_Handled;
}
public Action:Command_Negev(int client, int args)
{
	GunShop(client, "weapon_negev", "Negev", 0, true, 0, "sm_negev", 0, 1);
	return Plugin_Handled;
}
public Action:Command_M249(int client, int args)
{
	GunShop(client, "weapon_m249", "M-249", 0, true, 0, "sm_m249", 0, 1);
	return Plugin_Handled;
}
public Action:Command_Nova(int client, int args)
{
	GunShop(client, "weapon_nova", "Nova", 0, true, 0, "sm_nova", 0, 1);
	return Plugin_Handled;
}
public Action:Command_XM1014(int client, int args)
{
	GunShop(client, "weapon_xm1014", "XM-1014", 0, true, 0, "sm_xm1014", 0, 1);
	return Plugin_Handled;
}
public Action:Command_SawedOff(int client, int args)
{
	GunShop(client, "weapon_sawedoff", "Sawed-Off", 0, true, 0, "sm_sawedoff", 0, 1);
	return Plugin_Handled;
}
public Action:Command_Mag7(int client, int args)
{
	GunShop(client, "weapon_mag7", "MAG-7", 0, true, 0, "sm_mag7", 0, 1);
	return Plugin_Handled;
}

//End of Buy Commands
//Start Menus
public Action GunMenu(int client, args)
{
	new Handle:menu = CreateMenu(GunMenuHandler);
	SetMenuTitle(menu, "GunSHOP Menu\nMoney: $%i", getMoney(client));
	AddMenuItem(menu, "autobuy",  "AutoBuy");

	char quickbuy[64], sCookie[32];
	GetClientCookie(client, gH_QuickBuy, sCookie, sizeof(sCookie));
	if(!StrEqual(sCookie, "off", false))
	{
		Format(quickbuy, sizeof(quickbuy), "Disable QuickBuy");
	}
	else
	{
		Format(quickbuy, sizeof(quickbuy), "Enable QuickBuy");
	}

	AddMenuItem(menu, "quickbuy", quickbuy);
	AddMenuItem(menu, "smgs",  "SMGS");
	AddMenuItem(menu, "heavy",  "Heavy");
	AddMenuItem(menu, "rifles",  "Rifles");
	AddMenuItem(menu, "pistols",  "Pistols");
	AddMenuItem(menu, "grenades",  "Grenades");
	AddMenuItem(menu, "equipment",  "Equipment");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int GunMenuHandler(Handle:menu, MenuAction:action, client, position)
{
	if(action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, position, info, sizeof(info));

		if(StrEqual(info, "autobuy"))
			AutoBuyMenu(client, 0);
		if(StrEqual(info, "smgs"))
			SMGMenu(client, 0);
		if(StrEqual(info, "heavy"))
			HeavyMenu(client, 0);
		if(StrEqual(info, "rifles"))
			RifleMenu(client, 0);
		if(StrEqual(info, "pistols"))
			PistolMenu(client, 0);
		if(StrEqual(info, "grenades"))
			GrenadeMenu(client, 0);
		if(StrEqual(info, "equipment"))
			EquipmentMenu(client, 0);

		if(StrEqual(info, "quickbuy"))
		{
			char sCookie[32];
			GetClientCookie(client, gH_QuickBuy, sCookie, sizeof(sCookie));
			if(!StrEqual(sCookie, "off", false))
			{
				SetClientCookie(client, gH_QuickBuy, "off");
				CPrintToChat(client, "{red}[GS]{lightblue} QuickBuy has been disabled.");
			}	
			else
			{
				SetClientCookie(client, gH_QuickBuy, "on");
				CPrintToChat(client, "{red}[GS]{lightblue} QuickBuy has been enabled.");
			}
		}
	}
	else if(action == MenuAction_End)
		CloseHandle(menu);
}

//AutoBuy Menu Section

public Action PrimaryMenu(int client, args)
{
	new Handle:menu = CreateMenu(PrimaryMenuHandler);
	SetMenuTitle(menu, "Primary Menu\nMoney: $%i", getMoney(client));
	AddMenuItem(menu, "clear",  "Clear");
	AddMenuItem(menu, "smgs",  "SMGS");
	AddMenuItem(menu, "heavy",  "Heavy");
	AddMenuItem(menu, "rifles",  "Rifles");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int PrimaryMenuHandler(Handle:menu, MenuAction:action, client, position)
{
	if(action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, position, info, sizeof(info));

		if(StrEqual(info, "smgs"))
			SMGMenu(client, 0);
		if(StrEqual(info, "heavy"))
			HeavyMenu(client, 0);
		if(StrEqual(info, "rifles"))
			RifleMenu(client, 0);
		if(StrEqual(info, "clear"))
		{
			SetClientCookie(client, gH_ABPrimary, "");
			g_IsSelectingPrimary[client] = false;
			AutoBuyMenu(client, 0);
		}
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action MiscMenu(int client, args)
{
	new Handle:menu = CreateMenu(MiscMenuHandler);
	SetMenuTitle(menu, "Misc Menu\nMoney: $%i", getMoney(client));
	AddMenuItem(menu, "clear",  "Clear");
	AddMenuItem(menu, "grenades",  "Grenades");
	AddMenuItem(menu, "equipment",  "Equipment");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int MiscMenuHandler(Handle:menu, MenuAction:action, client, position)
{
	if(action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, position, info, sizeof(info));

		if(StrEqual(info, "grenades"))
			GrenadeMenu(client, 0);
		if(StrEqual(info, "equipment"))
			EquipmentMenu(client, 0);
		if(StrEqual(info, "clear"))
		{
			if(g_IsSelectingEquip1[client])
			{
				g_IsSelectingEquip1[client] = false;
				SetClientCookie(client, gH_ABEquip1, "");
			}
			if(g_IsSelectingEquip2[client])
			{
				g_IsSelectingEquip2[client] = false;
				SetClientCookie(client, gH_ABEquip2, "");
			}
			if(g_IsSelectingEquip3[client])
			{
				g_IsSelectingEquip3[client] = false;
				SetClientCookie(client, gH_ABEquip3, "");
			}
			AutoBuyMenu(client, 0);
		}
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action AutoBuyMenu(int client, args)
{
	char sCookie[64], sCookie2[64], sCookie3[64], sCookie4[64], sCookie5[64], Status[64];
	
	GetClientCookie(client, gH_ABStatus, Status, sizeof(Status));
	GetClientCookie(client, gH_ABPrimary, sCookie, sizeof(sCookie));
	GetClientCookie(client, gH_ABPistol, sCookie2, sizeof(sCookie2));
	GetClientCookie(client, gH_ABEquip1, sCookie3, sizeof(sCookie3));
	GetClientCookie(client, gH_ABEquip2, sCookie4, sizeof(sCookie4));
	GetClientCookie(client, gH_ABEquip3, sCookie5, sizeof(sCookie5));

	char men1[32], men2[32], men3[32], men4[32], men5[32], men6[32];

	if(strlen(Status) == 0) {
		Format(Status, sizeof(Status), "on");
	}

	Format(men1, sizeof(men1), "Toggle: (Current Status: %s)", Status);
	//Removes the sm_ part of the string
	Format(men2, sizeof(men2), "Primary: %s", sCookie[3]);
	Format(men3, sizeof(men3), "Pistol: %s", sCookie2[3]);
	Format(men4, sizeof(men4), "Equipment 1: %s", sCookie3[3]);
	Format(men5, sizeof(men5), "Equipment 2: %s", sCookie4[3]);
	Format(men6, sizeof(men6), "Equipment 3: %s", sCookie5[3]);

	new Handle:menu = CreateMenu(AutoBuyMenuHandler);
	SetMenuTitle(menu, "AutoBuy Menu\nMoney: $%i", getMoney(client));
	AddMenuItem(menu, "toggleautobuy", men1);
	AddMenuItem(menu, "primary",  men2);
	AddMenuItem(menu, "pistol",  men3);
	AddMenuItem(menu, "equip1", men4);
	AddMenuItem(menu, "equip2",  men5);
	AddMenuItem(menu, "equip3",  men6);
	AddMenuItem(menu, "clearautobuy",  "Clear");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int AutoBuyMenuHandler(Handle:menu, MenuAction:action, client, position)
{
	if(action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, position, info, sizeof(info));

		if(StrEqual(info, "toggleautobuy"))
		{
			ToggleAutoBuy(client, 0);
		}
		if(StrEqual(info, "primary"))
		{
			g_IsSelectingPrimary[client] = true;
			PrimaryMenu(client, 0);
		}
		if(StrEqual(info, "pistol"))
		{
			g_IsSelectingPistol[client] = true;
			PistolMenu(client, 0);
		}
		if(StrEqual(info, "equip1"))
		{
			g_IsSelectingEquip1[client] = true;
			MiscMenu(client, 0);
		}
		if(StrEqual(info, "equip2"))
		{
			g_IsSelectingEquip2[client] = true;
			MiscMenu(client, 0);
		}
		if(StrEqual(info, "equip3"))
		{
			g_IsSelectingEquip3[client] = true;
			MiscMenu(client, 0);
		}
		if(StrEqual(info, "clearautobuy"))
		{
			ClearAutoBuy(client, 0);
		}
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action SMGMenu(int client, args)
{
	new Handle:menu = CreateMenu(SMGMenuHandler);
	SetMenuTitle(menu, "SMG Menu\nMoney: $%i", getMoney(client));
	AddMenuItem(menu, "sm_mac10",  "MAC-10");
	AddMenuItem(menu, "sm_mp9",  "MP9");
	AddMenuItem(menu, "sm_mp7",  "MP7");
	AddMenuItem(menu, "sm_ump45",  "UMP-45");
	AddMenuItem(menu, "sm_bizon",  "PP-Bizon");
	AddMenuItem(menu, "sm_p90",  "P90");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int SMGMenuHandler(Handle:menu, MenuAction:action, client, position)
{
	if(action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, position, info, sizeof(info));

		FakeClientCommand(client, info);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action HeavyMenu(int client, args)
{
	new Handle:menu = CreateMenu(HeavyMenuHandler);
	SetMenuTitle(menu, "Heavy Menu\nMoney: $%i", getMoney(client));
	AddMenuItem(menu, "sm_negev",  "Negev");
	AddMenuItem(menu, "sm_m249",  "M249");
	AddMenuItem(menu, "sm_nova",  "Nova");
	AddMenuItem(menu, "sm_xm1014",  "XM-1014");
	AddMenuItem(menu, "sm_sawedoff",  "Sawed-Off");
	AddMenuItem(menu, "sm_mag7",  "MAG-7");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int HeavyMenuHandler(Handle:menu, MenuAction:action, client, position)
{
	if(action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, position, info, sizeof(info));

		FakeClientCommand(client, info);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action RifleMenu(int client, args)
{
	new Handle:menu = CreateMenu(RifleMenuHandler);
	SetMenuTitle(menu, "Heavy Menu\nMoney: $%i", getMoney(client));
	AddMenuItem(menu, "sm_m4a4",  "M4A4");
	AddMenuItem(menu, "sm_m4a1",  "M4A1-S");
	AddMenuItem(menu, "sm_ak47",  "AK-47");
	AddMenuItem(menu, "sm_awp",  "AWP");
	AddMenuItem(menu, "sm_scar20",  "SCAR-20");
	AddMenuItem(menu, "sm_g3sg1",  "G3SG1");
	AddMenuItem(menu, "sm_ssg08",  "SSG-08");
	AddMenuItem(menu, "sm_famas",  "FAMAS");
	AddMenuItem(menu, "sm_galil",  "Galil-AR");
	AddMenuItem(menu, "sm_sg553",  "SG-553");
	AddMenuItem(menu, "sm_aug",  "AUG");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int RifleMenuHandler(Handle:menu, MenuAction:action, client, position)
{
	if(action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, position, info, sizeof(info));

		FakeClientCommand(client, info);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action PistolMenu(int client, args)
{
	new Handle:menu = CreateMenu(PistolMenuHandler);
	SetMenuTitle(menu, "Pistol Menu\nMoney: $%i", getMoney(client));
	if(g_IsSelectingPistol[client])
	{
		AddMenuItem(menu, "clear",  "Clear");
	}
	AddMenuItem(menu, "sm_glock",  "Glock-18");
	AddMenuItem(menu, "sm_usps",  "USP-S");
	AddMenuItem(menu, "sm_p2000",  "P2000");
	AddMenuItem(menu, "sm_p250",  "P250");
	AddMenuItem(menu, "sm_deagle",  "Desert Eagle");
	AddMenuItem(menu, "sm_elite",  "Dual Berettas");
	AddMenuItem(menu, "sm_57",  "Five-SeveN");
	AddMenuItem(menu, "sm_tec9",  "Tec-9");
	AddMenuItem(menu, "sm_cz75",  "CZ-75");
	AddMenuItem(menu, "sm_revolver",  "R8 Revolver");
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int PistolMenuHandler(Handle:menu, MenuAction:action, client, position)
{
	if(action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, position, info, sizeof(info));

		if(StrEqual(info, "clear"))
		{
			SetClientCookie(client, gH_ABPistol, "");
			g_IsSelectingPistol[client] = false;
			AutoBuyMenu(client, 0);
		}
		else
		{
			FakeClientCommand(client, info);
		}
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action GrenadeMenu(int client, args)
{
	new Handle:menu = CreateMenu(GrenadeMenuHandler);
	SetMenuTitle(menu, "Grenade Menu\nMoney: $%i", getMoney(client));
	if(buyZone[client])
	{
		AddMenuItem(menu, "sm_decoy",  "Decoy - $50");
		AddMenuItem(menu, "sm_he",  "HE - $300");
		AddMenuItem(menu, "sm_molotov",  "Molotov - $400");
		AddMenuItem(menu, "sm_incendiary",  "Incendiary - $400");
		AddMenuItem(menu, "sm_tactical",  "Tactical - $250");
	}
	else
	{
		AddMenuItem(menu, "sm_decoy",  "Decoy - $6500");
		AddMenuItem(menu, "sm_he",  "HE - $6500");
		AddMenuItem(menu, "sm_molotov",  "Molotov - $6500");
		AddMenuItem(menu, "sm_incendiary",  "Incendiary - $6500");
		AddMenuItem(menu, "sm_tactical",  "Tactical - $2500");
	}
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int GrenadeMenuHandler(Handle:menu, MenuAction:action, client, position)
{
	if(action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, position, info, sizeof(info));

		FakeClientCommand(client, info);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action EquipmentMenu(int client, args)
{
	new Handle:menu = CreateMenu(EquipmentMenuHandler);
	SetMenuTitle(menu, "Grenade Menu\nMoney: $%i", getMoney(client));
	AddMenuItem(menu, "sm_knife",  "Knife");
	if(buyZone[client])
	{
		AddMenuItem(menu, "sm_healthshot",  "Healthshot - $2500");
		AddMenuItem(menu, "sm_kevlar",  "Kevlar - $3000");
		AddMenuItem(menu, "sm_heavykevlar",  "HeavyKevlar - $6000");
	}
	else
	{
		AddMenuItem(menu, "sm_healthshot",  "Healthshot - $500");
		AddMenuItem(menu, "sm_kevlar",  "Kevlar - $1000");
		AddMenuItem(menu, "sm_heavykevlar",  "HeavyKevlar - $2000");
	}
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int EquipmentMenuHandler(Handle:menu, MenuAction:action, client, position)
{
	if(action == MenuAction_Select)
	{
		char info[32];
		GetMenuItem(menu, position, info, sizeof(info));

		FakeClientCommand(client, info);
	}
	else if(action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action:ToggleAutoBuy(client, args)
{
	char sCookie[64];
	GetClientCookie(client, gH_ABStatus, sCookie, 64);
	if(StrEqual(sCookie, "off", false))
	{
		SetClientCookie(client, gH_ABStatus, "on");
		CPrintToChat(client, "{red}[GS]{lightblue} AutoBuy has been enabled.");
	}
	else
	{
		SetClientCookie(client, gH_ABStatus, "off");
		CPrintToChat(client, "{red}[GS]{lightblue} AutoBuy has been disabled.");
	}
	
}

public Action:ClearAutoBuy(client, args)
{
	SetClientCookie(client, gH_ABPrimary, "");
	SetClientCookie(client, gH_ABPistol, "");
	SetClientCookie(client, gH_ABEquip1, "");
	SetClientCookie(client, gH_ABEquip2, "");
	SetClientCookie(client, gH_ABEquip3, "");
	CPrintToChat(client, "{red}[GS]{lightblue} Your AutoBuy setup has been cleared.");
}