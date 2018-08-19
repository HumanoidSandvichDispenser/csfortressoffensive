#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Humanoid Sandivch Dispenser"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <smlib>
//#include <botattackcontrol>
#include <csfo_rocketlauncher>
#include <csfo_stickybomb>
#include <csfo_engineer>
#include <colors>

enum classtype
{
	none = 0,
	scout = 1,
	soldier = 2,
	pyro = 3,
	demoman = 4,
	heavyweapons = 5,
	engineer = 6,
	medic = 7,
	sniper = 8,
	spy = 9
};

EngineVersion g_Game;
classtype class[MAXPLAYERS + 1] = none;
int healthtype[MAXPLAYERS + 1] = 0;
bool clientIsBurning[MAXPLAYERS + 1] = false;
int damagedonetotal[MAXPLAYERS + 1] = 0;
Handle batchTimer[MAXPLAYERS + 1];
bool clientIsInBuyzone[MAXPLAYERS + 1] = false;
bool firingFlamethrower[MAXPLAYERS + 1] = false;

Handle sm_csf2_randomcrits; // Command for random crits

// do not remove below pls
//Removed trigger_hurt(trigger_resupply_blue_2)
//trigger_multiple(prop_ammopack_large_1)
//trigger_hurt(prop_medkit_med_1)

#define HEGrenadeOffset 11	// (11 * 4)
#define FlashbangOffset 12	// (12 * 4)
#define SmokegrenadeOffset	13	// (13 * 4)
#define IncenderyGrenadesOffset	14	// (14 * 4) Also Molotovs

#define class_scout "Scout"
#define class_soldier "Soldier"
#define class_pyro "Pyro"
#define class_demoman "Demoman"
#define class_heavyweapons "Heavy"
#define class_engineer "Engineer"
#define class_medic "Medic"
#define class_sniper "Sniper"
#define class_spy "Spy"

public Plugin myinfo =
{
	name = "Counter-Strike: Fortress Offensive",
	author = PLUGIN_AUTHOR,
	description = "The Famous & EXTREMELY BALANCED 2007 FPS Team Fortress 2, now in CS:GO!",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	
	//heavyhealth = CreateConVar("sm_heavyhealth_amount", "300", "Heavy Weapons Guy's Health.", FCVAR_PLUGIN, true, 1.0, false, _);
	g_Game = GetEngineVersion();
	if(g_Game != Engine_CSGO)
	{
		SetFailState("This plugin is for CSGO only.");	
	}
	
	
	RegAdminCmd("sm_forceclass", Command_forceclass, ADMFLAG_SLAY, "Forces class to other players.");
	
	//ServerCommand("mp_ct_default_secondary  "); //Sets the default secondary for both teams to " ", which is blank.
	//ServerCommand("mp_t_default_secondary  ");
	ServerCommand("mp_death_drop_grenade 0");
	ServerCommand("mp_death_drop_gun 0");
	ServerCommand("mp_weapons_allow_map_placed 0");
	ServerCommand("ammo_grenade_limit_total 160");
	ServerCommand("ammo_grenade_limit_default 16"); 
	ServerCommand("ammo_grenade_limit_flashbang 16"); 
	ServerCommand("ammo_item_limit_healthshot 100");
	
	HookEvent("player_spawn", SpawnEvent);
	HookEvent("player_hurt", HurtTracker);
	HookEvent("player_death", KillReward);
	HookEvent("round_start", RoundStart);
	HookEvent("round_poststart", RoundPostStart);
	HookEvent("weapon_fire", WeaponFire);
	HookEvent("enter_buyzone", EnterBuyzone);
	HookEvent("exit_buyzone", ExitBuyzone);
	
	
	sm_pp_tripmines = CreateConVar( "sm_pp_tripmines", "99999", sm_pp_tripmines_desc);
	sm_pp_minedmg = CreateConVar( "sm_pp_minedmg", "100", "damage (magnitude) of the tripmines");
	sm_pp_minerad = CreateConVar( "sm_pp_minerad", "0", "override for explosion damage radius");
	sm_csf2_randomcrits = CreateConVar("sm_csf2_randomcrits", "0", "Enables/disables random critical hits");
	
	sm_pp_minefilter = CreateConVar( "sm_pp_minefilter", "2", "0 = detonate when laser touches anyone, 1 = enemies and owner only, 2 = enemies only");
	HookEvent( "player_use", Event_PlayerUse );

	HookConVarChange( sm_pp_tripmines, CVarChanged_tripmines );
	HookConVarChange( sm_pp_minefilter, CVarChanged_minefilter );
	

	minefilter = GetConVarInt( sm_pp_minefilter );
	
	PrecacheModel(ROCKET_MODEL);
	
	CreateTimer(1.0, dispense, _, TIMER_REPEAT);
}

public OnMapStart() 
{

	// PRECACHE SOUNDS
	PrecacheSound(SOUND_PLACE, true);
	PrecacheSound(SOUND_ARMING, true);
	PrecacheSound(SOUND_ARMED, true);
	PrecacheSound(SOUND_DEFUSE, true);
	PrecacheSound(SOUND_BUILD, true);

	// PRECACHE MODELS
	PrecacheModel(MODEL_MINE);
	PrecacheModel(MODEL_BEAM, true);

	//AddFileToDownloadsTable( "models/tripmine/tripmine.dx90.vtx" );
	//AddFileToDownloadsTable( "models/tripmine/tripmine.mdl" );
	//AddFileToDownloadsTable( "models/tripmine/tripmine.phy" );
	//AddFileToDownloadsTable( "models/tripmine/tripmine.vvd" );

	//AddFileToDownloadsTable( "materials/models/tripmine/minetexture.vmt" );
	//AddFileToDownloadsTable( "materials/models/tripmine/minetexture.vtf" );

	PrecacheSound("weapons/hegrenade/explode3.wav");
	PrecacheSound("weapons/hegrenade/explode4.wav");
	PrecacheSound("weapons/hegrenade/explode5.wav");
	
	PrecacheModel(ROCKET_MODEL, true);
	PrecacheModel("models/props/de_mill/generatoronwheels.mdl", true);
	PrecacheModel("models/props/cs_office/vending_machine.mdl", true);
}

public Action dispense(Handle timer)
{
	int client;
	for (client = 1; client < MAXPLAYERS; client++)
	{
		if (isInDispenser[client] > 0)
		{
			if (IsClientInGame(client))
			{
				int primaryWeapon = GetPlayerWeaponSlot(client, 0);
				int secondaryWeapon = GetPlayerWeaponSlot(client, 1);
				int armorValue = GetEntProp(client, Prop_Send, "m_ArmorValue");
				SetEntProp(client, Prop_Send, "m_ArmorValue", armorValue + (isInDispenser[client] * 5));
				
				if (primaryWeapon != -1)
				{
					int primaryRes = GetEntProp(primaryWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount");
					SetEntProp(primaryWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount", primaryRes + (isInDispenser[client] * 5));
				}
				
				if (secondaryWeapon != -1)
				{
					int secondaryRes = GetEntProp(secondaryWeapon, Prop_Send, "m_iSecondaryReserveAmmoCount");
					SetEntProp(secondaryWeapon, Prop_Send, "m_iSecondaryReserveAmmoCount", secondaryRes + (isInDispenser[client] * 5));
				}
			}
		}
		
	}
}

public Action OnPlayerRunCmd( client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon ) {

	if( !IsValidClient(client) ) return Plugin_Continue;

	if( (buttons & IN_USE) == 0 ) {
	
		if( defuse_userid[client] && !defuse_cancelled[client] ) { // is defuse in progress?
			defuse_cancelled[client] = true;
			PrintHintText( client, "Defusal Cancelled." );
		}
	}
	
	if ((buttons & IN_ATTACK) == 0)
	{
		if (class[client] == pyro)
		{
			DestroyFlames(client);
		}
	}
	
	return Plugin_Continue;
}

public Action RoundStart(Handle:event,const String:name[],bool:dontBroadcast)
{
	ServerCommand("mp_buytime 0");
	
	for (int client = 1; client < MAXPLAYERS; client++)
	{
		isInDispenser[client] = 0;
	}
	dispenserIndex = 0;
	mine_counter = 0;
	explosion_sound_enable=true;
	return Plugin_Continue;
}

public Action RoundPostStart(Handle:event,const String:name[],bool:dontBroadcast)
{
	ServerCommand("mp_buytime 0");
	
	return Plugin_Continue;
}

public Action EnterBuyzone(Handle:event,const String:name[],bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	clientIsInBuyzone[client] = true;
	return Plugin_Continue;
}

public Action ExitBuyzone(Handle:event,const String:name[],bool:dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	clientIsInBuyzone[client] = false;
	return Plugin_Continue;
}

public Action HurtTracker(Handle:event,const String:name[],bool:dontBroadcast)
{
	int damagedone = GetEventInt(event, "dmg_health");
	/*
	new health = GetEventInt(event, "health");
	new armor = GetEventInt(event, "armor");
    new damagedonearmor = GetEventInt(event, "dmg_armor");
    */
	
	int hitarea = GetEventInt(event, "hitgroup");
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	
	//Medic healing (NOT WORKING)
	/*
	new clientteam = GetClientTeam(client);
	new attackerteam = GetClientTeam(attacker);
	decl String:weapon[32]; 
	GetEventString(event, "weapon", weapon, sizeof(weapon));
	if (clientteam == attackerteam)
	{
		if (StrEqual(weapon, "bizon"))
		{
			SetEntProp(client, Prop_Send, "m_iHealth", (health + (damagedone * 2)), 4);
			SetEntProp(client, Prop_Send, "m_ArmorValue", (armor + damagedonearmor), 4);
			
		}
		SetEntProp(client, Prop_Send, "m_iHealth", (health + damagedone), 4);
		SetEntProp(client, Prop_Send, "m_ArmorValue", (armor + damagedonearmor), 4);
		
	}
	*/
	damagedonetotal[attacker] += damagedone;
	//clientIsShooting[attacker] = true;
	
	if (!IsClientConnected(attacker) && !IsClientInGame(attacker) && client > 0)
	{
		PrintToConsole(client, "DEBUG: Took damage by world.");
	}

	if (client > 0 && attacker > 0) //checks to see if the client and attacker id is valid
	{

		if (hitarea == 1) //checks the place where the user got shot (1 = hs)
		{
			SetHudTextParams(-1.0, 0.6, 2.0, 150, 220, 50, 205);
			ShowHudText(attacker, 2, "-%d (CRITICAL HIT!)", damagedonetotal[attacker]);
			//PrintHintText(client, "<< %d (CRITICAL HIT!)", damagedone);
			//PrintHintText(attacker, ">> %d (CRITICAL HIT!)", damagedone);
			if (IsPlayerAlive(client)) ClientCommand(attacker, "playgamesound training/bell_impact.wav");
			//return Plugin_Handled;
		} else {
			SetHudTextParams(-1.0, 0.6, 2.0, 200, 50, 50, 205);
			ShowHudText(attacker, 2, "-%d", damagedonetotal[attacker]);
			//PrintHintText(client, "<< %d", damagedone);
			//PrintHintText(attacker, ">> %d", damagedone);
			if (IsPlayerAlive(client)) ClientCommand(attacker, "playgamesound training/bell_normal.wav");
			//return Plugin_Handled;
		}
	}
	
	if (class[attacker] == pyro && class[client] != pyro)
	{
		if (clientIsBurning[client]) return;
		else
		{
			clientIsBurning[client] == true;
			CreateTimer(5.0, burnDuration, client);
		}
	}
	

	if (batchTimer[attacker] != INVALID_HANDLE && attacker > 0)
	{
		//KillTimer(batchTimer[attacker], true);
		delete batchTimer[attacker];
	}
	
	if (attacker > 0) batchTimer[attacker] = CreateTimer(1.5, resetTimer, attacker);

	
		
	
		
}
	
public Action resetTimer(Handle timer, any attacker)
{
	damagedonetotal[attacker] = 0;
	batchTimer[attacker] = null;
}


public Action damageTextBatch(Handle timer, any client)
{
	/*
	if (clientIsShooting[client])
	{
		damagedonetotal[client] = 0;
		//clientIsShooting[client] = false;
	}
	*/
}

public Action burnDuration(Handle timer, any client)
{
	clientIsBurning[client] == false;
}

public Action afterburn(Handle timer)
{
	for (int client = 0; client < MAXPLAYERS; client++)
	{
		if (clientIsBurning[client] == true)
		{
			
		}
	}
}

public Action KillReward(Handle:event,const String:name[],bool:dontBroadcast)
{
	
	
	int client_id = GetEventInt(event, "userid");
	int client = GetClientOfUserId(client_id);
	int attacker_id = GetEventInt(event, "attacker");
	int attacker = GetClientOfUserId(attacker_id);
	
	ClientCommand(attacker, "playgamesound ui/xp_milestone_01.wav");
	
	
	if (class[attacker] == spy)
	{
		GivePlayerItem(attacker, "weapon_flashbang");
		GivePlayerItem(attacker, "weapon_smokegrenade");
		GivePlayerItem(attacker, "weapon_tagrenade");
		GivePlayerItem(attacker, "weapon_tagrenade");
	}
	
	isInDispenser[client] = 0;
	
	return Plugin_Continue;
}

public OnClientPutInServer(client)
{
    SDKHook(client, SDKHook_StartTouchPost, StartTouch);
    SDKHook(client, SDKHook_EndTouch, EndTouch);
    SDKHook(client, SDKHook_OnTakeDamage, Event_OnTakeDamage);
    //SDKHook(client, SDKHook_FireBulletsPost, FireBulletsHook);
}

public Action Event_OnTakeDamage(victim, &attacker, &inflictor, &Float:fDamage, &damagetype, &bweapon, Float:damageForce[3], Float:damagePosition[3]) 
{
	decl String:sClassname[64];
	GetEdictClassname(inflictor, sClassname, sizeof(sClassname));
	
	if (fDamage == -2.0)
	{
		PrintToChatAll("DEBUG: trigger_hurt");
	}

	if(victim && attacker)	// make sure they are both valid entities
	{
		if(GetClientTeam(victim) == GetClientTeam(attacker) || GetClientTeam(victim) == 9)
		{
			if (class[attacker] == medic)
			{
				new iNewVal, iCurrentVal;
				iCurrentVal = GetEntProp(victim, Prop_Send, "m_iHealth");
				iNewVal = RoundFloat(float(iCurrentVal) + fDamage);
				if(iNewVal > healthtype[victim])
				{
					iNewVal = healthtype[victim];
				}
				SetEntProp(victim, Prop_Send, "m_iHealth", iNewVal);
			}
			
			
			/*iCurrentVal = GetEntProp(victim, Prop_Send, "m_ArmorValue");
			iNewVal = RoundFloat(float(iCurrentVal) + fDamage);
			if(iNewVal > 100)
			{
				iNewVal = 100;
			}
			iNewVal = RoundFloat(float(iCurrentVal + fDamage));
			SetEntProp(victim, Prop_Send, "m_ArmorValue", iNewVal);*/
			
			fDamage = 0.0;
			return Plugin_Changed;
			
		}
		if (class[attacker] == spy && (GetClientTeam(victim) != GetClientTeam(attacker)) && fDamage > 75.0)
		{
			fDamage = 1000.0;
			return Plugin_Changed;
		}
	}
	
	if (GetConVarBool(sm_csf2_randomcrits))
	{
		fDamage *= 3;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public StartTouch(int client, int entity)
{	
	char entityclass[32];
	char entityname[32];
	GetEntityClassname(entity, entityclass, sizeof(entityclass));
	Entity_GetName(entity, entityname, sizeof(entityname));

	if (StrEqual(entityname, "dispenser_2") || StrEqual(entityname, "dispenser_3"))
	{
		//isInDispenser[client] = true;
		//PrintToConsole(client, "DEBUG: You touched a dispenser.");
	}

	if (StrEqual(entityclass, "prop_dynamic"))
	{
		
		//PrintToChat(client, "DEBUG: resupplied"); 

		switch(class[client])
		{
			case pyro:
			{
				new nadesupply = (16 - GetClientIncendaryGrenades(client));
				new i;
				for (i = 1; i < nadesupply; i++)
				{
					GivePlayerItem(client, "weapon_incgrenade");
				}
			}
			
			case demoman:
			{
				new nadesupply = (16 - GetClientHEGrenades(client));
				new i;
				for (i = 1; i < nadesupply; i++)
				{
					GivePlayerItem(client, "weapon_hegrenade");
				}
			}
			
			case spy:
			{
				new nadesupply = (16 - GetClientSmokeGrenades(client));
				new nadesupply2 = (16 - GetClientFlashbang(client));
				new i;
				new i2;
				for (i = 1; i < nadesupply; i++)
				{
					GivePlayerItem(client, "weapon_smokegrenade");
				}
				for (i2 = 1; i2 < nadesupply2; i2++)
				{
					GivePlayerItem(client, "weapon_flashbang");
				}
			}


		}
	}
	
	//1886351984
	
}

public EndTouch(int client, int entity)
{
	
}

public Action WeaponFire(Handle:event,const String:name[],bool:dontBroadcast)
{
	
	int client_id = GetEventInt(event, "userid");
	int client = GetClientOfUserId(client_id);
	char weapon[128]; 
	
	if (class[client] == demoman || class[client] == soldier)
	{
		GetEventString(event, "weapon", weapon, 128);
	
		if (StrEqual(weapon, "weapon_mag7")) PlaceMine(client);
		//if (StrEqual(weapon, "weapon_mag7")) ClientCommand(client, "sm_mine");
		if (StrEqual(weapon, "weapon_xm1014")) RocketStart(client);
	}
	
	if (class[client] == pyro)
	{
		GetEventString(event, "weapon", weapon, 128);
		
		if (StrEqual(weapon, "weapon_p90"))CreateFlames(client);
	}
	
}

public Action CreateFlames(int client)
{

}

public Action DestroyFlames(int client)
{
	
}

public Action Command_forceclass(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_forceclass <#userid|name> <classindex(1-9)>");
		return Plugin_Handled;
	}
	
	char arg[65];
	GetCmdArg(1, arg, sizeof(arg));
	

	decl String:arg2[9];
	GetCmdArg(2, arg2, sizeof(arg2));

	
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	
	if ((target_count = ProcessTargetString(
	arg,
	client,
	target_list,
	MAXPLAYERS,
	COMMAND_FILTER_ALIVE,
	target_name,
	sizeof(target_name),
	tn_is_ml)) <= 0)
	{
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
	
}

public Action SpawnEvent(Handle:event,const String:name[],bool:dontBroadcast)
{
	int client_id = GetEventInt(event, "userid");
	int client = GetClientOfUserId(client_id);
	
	ServerCommand("mp_buytime 0");
	
	if (IsFakeClient(client))
	{
		int rndclass = GetRandomInt(1, 9);
		class[client] = classtype:rndclass;
		
		if (class[client] == none)
		{
			ForcePlayerSuicide(client);

		}
	}
	
	Client_RemoveAllWeapons(client, "weapon_knife", true);

	switch(class[client])
	{
		
		case scout:
		{
			
			
			GivePlayerItem(client, "weapon_nova");
			GivePlayerItem(client, "weapon_p250");
			GivePlayerItem(client, "item_assaultsuit");
			CreateTimer(0.1, RespawnScout, client, TIMER_FLAG_NO_MAPCHANGE);
			healthtype[client] = 125;
		}
		
		case soldier:
		{
			GivePlayerItem(client, "weapon_xm1014");
			CreateTimer(0.1, RespawnNormal, client, TIMER_FLAG_NO_MAPCHANGE);
			//GivePlayerItem(client, "weapon_sawedoff");
			healthtype[client] = 175;
		}
		
		case pyro:
		{
			GivePlayerItem(client, "weapon_p90");
			//GivePlayerItem(client, "weapon_sawedoff");
			GivePlayerItem(client, "weapon_taser");
			for (i = 0; i < 16; i++)
			{
				GivePlayerItem(client, "weapon_incgrenade");
			}
			
			GivePlayerItem(client, "weapon_taser");
			GivePlayerItem(client, "item_assaultsuit");
			CreateTimer(0.1, RespawnNormal, client, TIMER_FLAG_NO_MAPCHANGE);
			healthtype[client] = 175;
		}
		
		case demoman:
		{
			GivePlayerItem(client, "weapon_mag7");
			for (i = 0; i < 16; i++)
			{
				GivePlayerItem(client, "weapon_hegrenade");
			}
			
			GivePlayerItem(client, "item_assaultsuit");
			CreateTimer(0.1, RespawnNormal, client, TIMER_FLAG_NO_MAPCHANGE);
			healthtype[client] = 175;
		}
		
		
		case heavyweapons:
		{
			GivePlayerItem(client, "weapon_negev");
			GivePlayerItem(client, "weapon_tec9");
			GivePlayerItem(client, "item_assaultsuit");
			CreateTimer(0.1, RespawnHeavy, client, TIMER_FLAG_NO_MAPCHANGE);
			healthtype[client] = 300;
		}
		
		case engineer:
		{
			GivePlayerItem(client, "weapon_nova");
			GivePlayerItem(client, "weapon_p250");
			GivePlayerItem(client, "item_assaultsuit");
			CreateTimer(0.1, RespawnLight, client, TIMER_FLAG_NO_MAPCHANGE);
			healthtype[client] = 125;
		}
		
		case medic:
		{
			
			GivePlayerItem(client, "weapon_bizon");
			GivePlayerItem(client, "weapon_healthshot");
			for (i = 0; i < 8; i++)
			{
				GivePlayerItem(client, "weapon_hegrenade");
				GivePlayerItem(client, "weapon_hegrenade");
				GivePlayerItem(client, "weapon_hegrenade");
				GivePlayerItem(client, "weapon_hegrenade");
				GivePlayerItem(client, "weapon_hegrenade");
				GivePlayerItem(client, "weapon_hegrenade");
				GivePlayerItem(client, "weapon_hegrenade");
				GivePlayerItem(client, "weapon_hegrenade");
			}
			
			GivePlayerItem(client, "item_assaultsuit");
			CreateTimer(0.1, RespawnNormal, client, TIMER_FLAG_NO_MAPCHANGE);
			healthtype[client] = 175;
		}
		
		case sniper:
		{
			
			
			GivePlayerItem(client, "weapon_ssg08");
			GivePlayerItem(client, "weapon_tec9");
			GivePlayerItem(client, "item_assaultsuit");
			CreateTimer(0.1, RespawnLight, client, TIMER_FLAG_NO_MAPCHANGE);
			healthtype[client] = 125;
		}
		
		case spy:
		{
			
			for (i = 0; i < 16; i++)
			{
				GivePlayerItem(client, "weapon_flashbang");
				GivePlayerItem(client, "weapon_smokegrenade");
			}
			
			for (i = 0; i < 8; i++)
			{
				GivePlayerItem(client, "weapon_tagrenade");
			}
			
			GivePlayerItem(client, "item_assaultsuit");
			CreateTimer(0.1, RespawnLight, client, TIMER_FLAG_NO_MAPCHANGE);
			healthtype[client] = 125;
		}
		
		default:
		{
			PrintToChat(client, "Please choose a class before respawning.");
		}
	}
}

public Action RespawnScout(Handle timer, any client)
{
	SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.75);
	SetEntData(client, FindDataMapInfo(client, "m_iMaxHealth"), 125, 4, true);
	SetEntData(client, FindDataMapInfo(client, "m_iHealth"), 125, 4, true);
}

public Action RespawnLight(Handle timer, any client)
{
    SetEntData(client, FindDataMapInfo(client, "m_iMaxHealth"), 125, 4, true);
    SetEntData(client, FindDataMapInfo(client, "m_iHealth"), 125, 4, true);
}

public Action RespawnNormal(Handle timer, any client)
{
    SetEntData(client, FindDataMapInfo(client, "m_iMaxHealth"), 175, 4, true);
    SetEntData(client, FindDataMapInfo(client, "m_iHealth"), 175, 4, true);
}

public Action RespawnHeavy(Handle timer, any client)
{
	SetEntData(client, FindDataMapInfo(client, "m_iMaxHealth"), 300, 4, true);
	SetEntData(client, FindDataMapInfo(client, "m_iHealth"), 300, 4, true);
}

public Action OnClientCommand(int client, int args)
{
	char cmd[16];
	GetCmdArg(0, cmd, sizeof(cmd));
 
	if (StrEqual(cmd, "sm_class"))
	{
		Command_class(client, args);
		return Plugin_Handled;
	}
	
	if (StrEqual(cmd, "sm_changeclass"))
	{
		Command_class(client, args);
		return Plugin_Handled;
	}
 
 	if (StrEqual(cmd, "sm_csfo_about"))
	{
		about(client, args);
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

public void about(int client, int args)
{
	CPrintToChat(client, "{lightgreen}Counter-Strike: Fortress Offensive 1.00 by {default}Humanoid Sandvich Dispenser");
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
	//char cmd[16];
	//GetCmdArg(0, cmd, sizeof(cmd));
	int args = 2;
	if (strcmp(sArgs, "changeclass", false) == 0)
	{
		Command_class(client, args);
	}
	
	if (strcmp(sArgs, "class", false) == 0)
	{
		Command_class(client, args);
	}
	
	if (strcmp(sArgs, "build", false) == 0)
	{
		CreateBuildMenu(client);
	}
}

public void Command_class(int client, int args)
{
	SetClass(client, args);
}

public void SetClass(client, args)
{
	Handle menu = CreateMenu(menuhandler, MenuAction_Select | MenuAction_End | MenuAction_DisplayItem);
	SetMenuTitle(menu, "Class Selection Menu");

	AddMenuItem(menu, "class_scout", "Scout");
	AddMenuItem(menu, "class_soldier", "Soldier");
	AddMenuItem(menu, "class_pyro", "Pyro");
	AddMenuItem(menu, "class_demoman", "Demoman");
	AddMenuItem(menu, "class_heavyweapons", "Heavy");
	AddMenuItem(menu, "class_engineer", "Engineer");
	AddMenuItem(menu, "class_medic", "Medic");
	AddMenuItem(menu, "class_sniper", "Sniper");
	AddMenuItem(menu, "class_spy", "Spy");

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

//thanks to menucreator or whatever
public menuhandler(Handle:menu, MenuAction:action, param1, param2)
{
	
	switch (action)
	{
		case MenuAction_Select:
		{
			//param1 is client, param2 is item

			char item[64];
			GetMenuItem(menu, param2, item, sizeof(item));

			if (StrEqual(item, "class_scout"))
			{
				ForcePlayerSuicide(param1);
				PrintToChat(param1, "You will respawn as Scout.");
				class[param1] = scout; //*param1 is the client id. class is an array of integers containing the unique client ids of every player in the server
			}
			else if (StrEqual(item, "class_soldier"))
			{
				ForcePlayerSuicide(param1);
				PrintToChat(param1, "You will respawn as Soldier.");
				class[param1] = soldier;
			}
			else if (StrEqual(item, "class_pyro"))
			{
				ForcePlayerSuicide(param1);
				class[param1] = pyro;
				PrintToChat(param1, "You will respawn as Pyro.");
			}
			else if (StrEqual(item, "class_demoman"))
			{
				ForcePlayerSuicide(param1);
				class[param1] = demoman;
				PrintToChat(param1, "You will respawn as Demoman.");
			}
			else if (StrEqual(item, "class_heavyweapons"))
			{
				ForcePlayerSuicide(param1);
				class[param1] = heavyweapons;
				PrintToChat(param1, "You will respawn as Heavy.");
			}
			else if (StrEqual(item, "class_engineer"))
			{
				ForcePlayerSuicide(param1);
				class[param1] = engineer;
				PrintToChat(param1, "You will respawn as Engineer.");
			}
			else if (StrEqual(item, "class_medic"))
			{
				ForcePlayerSuicide(param1);
				class[param1] = medic;
				PrintToChat(param1, "You will respawn as Medic.");
			}
			else if (StrEqual(item, "class_sniper"))
			{
				ForcePlayerSuicide(param1);
				class[param1] = sniper;
				PrintToChat(param1, "You will respawn as Sniper.");
			}
			else if (StrEqual(item, "class_spy"))
			{
				ForcePlayerSuicide(param1);
				class[param1] = spy;
				PrintToChat(param1, "You will respawn as Spy.");
			}
		}

		case MenuAction_End:
		{
			//param1 is MenuEnd reason, if canceled param2 is MenuCancel reason
			CloseHandle(menu);

		}

		case MenuAction_DisplayItem:
		{
			
			//param1 is client, param2 is item
			/*
			new String:item[64];
			GetMenuItem(menu, param2, item, sizeof(item));

			if (StrEqual(item, "class_scout"))
			{
				new String:translation[128];
				Format(translation, sizeof(translation), "%T", "class_scout", param1);
				return RedrawMenuItem(translation);
			}
			else if (StrEqual(item, "class_pyro"))
			{
				new String:translation[128];
				Format(translation, sizeof(translation), "%T", "class_pyro", param1);
				return RedrawMenuItem(translation);
			}
			else if (StrEqual(item, "class_heavyweapons"))
			{
				new String:translation[128];
				Format(translation, sizeof(translation), "%T", "class_heavyweapons", param1);
				return RedrawMenuItem(translation);
			}
			else if (StrEqual(item, "class_sniper"))
			{
				new String:translation[128];
				Format(translation, sizeof(translation), "%T", "class_sniper", param1);
				return RedrawMenuItem(translation);
			}
			else if (StrEqual(item, "class_spy"))
			{
				new String:translation[128];
				Format(translation, sizeof(translation), "%T", "class_spy", param1);
				return RedrawMenuItem(translation);
			}
			*/
		}

	}
	return 0;
}

public CreateBuildMenu(client)
{
	new Handle:menu = CreateMenu(buildmenu, MenuAction_Select | MenuAction_End | MenuAction_DisplayItem);
	SetMenuTitle(menu, "Build Menu");

	AddMenuItem(menu, "item_sentrygun", "Sentry Gun", ITEMDRAW_DISABLED);
	AddMenuItem(menu, "item_dispenser", "Dispenser");

	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public buildmenu(Handle menu, MenuAction action, param1, param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			//param1 is client, param2 is item

			new String:item[64];
			GetMenuItem(menu, param2, item, sizeof(item));

			if (StrEqual(item, "item_dispenser") && class[param1] == engineer)
			{
				BuildDispenser(param1);
			}
		}

		case MenuAction_End:
		{
			//param1 is MenuEnd reason, if canceled param2 is MenuCancel reason
			CloseHandle(menu);

		}

	}
}


//public GetClientButtons()

public GetClientHEGrenades(client)
{
	return GetEntProp(client, Prop_Data, "m_iAmmo", _, HEGrenadeOffset);
}

public GetClientIncendaryGrenades(client)
{
	return GetEntProp(client, Prop_Data, "m_iAmmo", _, IncenderyGrenadesOffset);
}

public GetClientSmokeGrenades(client)
{
	return GetEntProp(client, Prop_Data, "m_iAmmo", _, SmokegrenadeOffset);
}

public GetClientFlashbang(client)
{
	return GetEntProp(client, Prop_Data, "m_iAmmo", _, FlashbangOffset);
}


public OnClientDisconnect(client)
{
	class[client] = none;
	DeletePlacedMines( client );
	SDKUnhook(client, SDKHook_StartTouchPost, StartTouch);
	SDKUnhook(client, SDKHook_EndTouch, EndTouch);
	SDKUnhook(client, SDKHook_OnTakeDamage, Event_OnTakeDamage);
}