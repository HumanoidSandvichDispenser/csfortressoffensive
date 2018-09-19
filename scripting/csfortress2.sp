#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Humanoid Sandivch Dispenser"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdkhooks>
#include <smlib>
#include <botattackcontrol>
#include <csfo_rocketlauncher>
#include <csfo_stickybomb>
#include <csfo_engineer>
#include <csfo_downloads>
#include <csfo_gamemodes>
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
	spy = 9,
	saxtonhale = 10
};

EngineVersion g_Game;
classtype class[MAXPLAYERS + 1] = none;
int healthtype[MAXPLAYERS + 1] = 100;
bool clientIsBurning[MAXPLAYERS + 1] = false;
int damagedonetotal[MAXPLAYERS + 1] = 0;
Handle batchTimer[MAXPLAYERS + 1];
bool clientIsInBuyzone[MAXPLAYERS + 1] = false;
bool firingFlamethrower[MAXPLAYERS + 1] = false;
int PrimaryReserveAmmo[9] = {32, 20, 200, 16, 200, 32, 140, 30, 32};
int SecondaryReserveAmmo[9] = {90, 32, 32, 32, 32, 200, 0, 80, 0};

int SaxtonHaleClient = -1;
classtype:SaxtonHaleOldClass = classtype:0;
int SaxtonHaleRage = 0;
int BossType = 0;
bool RageActive = false;
/*
** 0 = Saxton Hale (Instakill when rage activated),
** 1 = Bonk Boy (Super Low Gravity when rage activated),
** 2 = BLU Heavy Weapons Guy (Minigun when rage activated)
*/

Handle sm_csf2_randomcrits; // Command for random crits
ConVar sm_csf2_gamemode;

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
	AddCommandListener(ChooseTeam, "jointeam");
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
	HookEvent("player_death", KillReward, EventHookMode_Pre);
	HookEvent("round_start", RoundStart);
	HookEvent("round_poststart", RoundPostStart);
	HookEvent("weapon_fire", WeaponFire);
	HookEvent("enter_buyzone", EnterBuyzone);
	HookEvent("exit_buyzone", ExitBuyzone);
	HookEvent("bomb_planted", BombPlanted);
	
	sm_pp_tripmines = CreateConVar( "sm_pp_tripmines", "99999", sm_pp_tripmines_desc);
	sm_pp_minedmg = CreateConVar( "sm_pp_minedmg", "100", "damage (magnitude) of the tripmines");
	sm_pp_minerad = CreateConVar( "sm_pp_minerad", "0", "override for explosion damage radius");
	sm_csf2_randomcrits = CreateConVar("sm_csf2_randomcrits", "0", "Enables/disables random critical hits");
	sm_csf2_gamemode = CreateConVar("sm_csf2_gamemode", "0", "0 = None, 1 = Deathmatch, 2 = Defusal");
	
	sm_csf2_gamemode.AddChangeHook(UpdateGamemode);
	
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
	PrecacheModel("models/props/coop_cementplant/coop_ammo_stash/coop_ammo_stash_full.mdl", true);
	PrecacheModel("models/player/custom_player/legacy/tm_p­hoenix_heavy.mdl");
	
	PrecacheModel("models/player/custom_player/kuristaja/tf2/scout/scout_bluv2.mdl", true);
	PrecacheModel("models/player/custom_player/kuristaja/tf2/scout/scout_redv2.mdl", true);
	PrecacheModel("models/player/custom_player/kuristaja/tf2/soldier/soldier_bluv2.mdl", true);
	PrecacheModel("models/player/custom_player/kuristaja/tf2/soldier/soldier_redv2.mdl", true);
	PrecacheModel("models/player/custom_player/kuristaja/tf2/pyro/pyro_bluv2.mdl", true);
	PrecacheModel("models/player/custom_player/kuristaja/tf2/pyro/pyro_redv2.mdl", true);
	PrecacheModel("models/player/custom_player/kuristaja/tf2/demoman/demoman_bluv2.mdl", true);
	PrecacheModel("models/player/custom_player/kuristaja/tf2/demoman/demoman_redv2.mdl", true);
	PrecacheModel("models/player/custom_player/kuristaja/tf2/heavy/heavy_bluv2.mdl", true);
	PrecacheModel("models/player/custom_player/kuristaja/tf2/heavy/heavy_redv2.mdl", true);
	PrecacheModel("models/player/custom_player/kuristaja/tf2/engineer/engineer_bluv2.mdl", true);
	PrecacheModel("models/player/custom_player/kuristaja/tf2/engineer/engineer_redv2.mdl", true);
	PrecacheModel("models/player/custom_player/kuristaja/tf2/medic/medic_bluv2.mdl", true);
	PrecacheModel("models/player/custom_player/kuristaja/tf2/medic/medic_redv2.mdl", true);
	PrecacheModel("models/player/custom_player/kuristaja/tf2/sniper/sniper_bluv2.mdl", true);
	PrecacheModel("models/player/custom_player/kuristaja/tf2/sniper/sniper_redv2.mdl", true);
	PrecacheModel("models/player/custom_player/kuristaja/tf2/spy/spy_bluv2.mdl", true);
	PrecacheModel("models/player/custom_player/kuristaja/tf2/spy/spy_redv2.mdl", true);
	
	DownloadFiles();
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
				if (armorValue + 50 > 150) armorValue = 100;
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

public Action OnPlayerRunCmd( client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon ) 
{
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

public Action SetupEnd(Handle timer, int gamemode)
{
	if (gamemode == 5)
	{
		int NewSaxtonHale = GetRandomPlayer(CS_TEAM_T);
		SaxtonHaleOldClass = class[NewSaxtonHale];
		SaxtonHaleClient = NewSaxtonHale;
		ChangeClientTeam(NewSaxtonHale, CS_TEAM_CT);
		
		class[NewSaxtonHale] = saxtonhale;
		CS_RespawnPlayer(NewSaxtonHale);
		
		Client_RemoveAllWeapons(NewSaxtonHale, "weapon_knife", true);
		char name[64];
		GetClientName(NewSaxtonHale, name, 64);
		
		for (int i = 1; i < MAXPLAYERS; i++)
		{
			if (IsClientConnected(i) && IsClientInGame(i))
			{
				if (GetClientTeam(i) == CS_TEAM_CT && i != NewSaxtonHale)
				{
					ChangeClientTeam(i, CS_TEAM_T);
					CS_RespawnPlayer(i);
				}
			}
			
		}
		
		int x = GetTeamClientCount(CS_TEAM_T);
		int HP = (x*5)+((x^4)/4) + 2000;

		char boss[32];
		if (BossType == 0)
		{
			boss = "Saxton Hale";
		}
		else if (BossType == 1)
		{
			boss = "Bonk Boy";
		}
		else if (BossType == 2)
		{
			boss = "BLU Heavy Weapons Guy";
		}

		PrintToChatAll("%s \x09became %s with %d HP!", name, boss, HP);
		
		CreateTimer(0.1, RespawnSaxtonHale, NewSaxtonHale);
	}
	
	for (int i = 1; i < MAXPLAYERS; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i))
		{
			if (GetClientTeam(i) == CS_TEAM_T) SetEntityMoveType(i, MOVETYPE_WALK);	
			else if (gamemode == 5) SetEntityMoveType(i, MOVETYPE_WALK);
		}
		
	}
	
	PrintToChatAll("[CS:FO] \x10Setup is now over.");
}

public Action RoundStart(Handle event,const String:name[],bool:dontBroadcast)
{
	if (sm_csf2_gamemode.IntValue == 2 || sm_csf2_gamemode.IntValue == 5)
	{
		for (int i = 1; i < MAXPLAYERS; i++)
		{
			if (IsClientConnected(i) && IsClientInGame(i))
			{
				if (GetClientTeam(i) == CS_TEAM_T || sm_csf2_gamemode.IntValue == 5) SetEntityMoveType(i, MOVETYPE_NONE);	
				
			}
		}
		
		CreateTimer(15.0, SetupEnd, sm_csf2_gamemode.IntValue);
	}
	
	if (SaxtonHaleOldClass != classtype:0) class[SaxtonHaleClient] = SaxtonHaleOldClass;
	SaxtonHaleClient = -1;
	
	ServerCommand("exec csfortress2_script");	
	ShowGamemodeMessage(sm_csf2_gamemode);
	
	CreateTimer(0.25, DecayOverheal, _, TIMER_REPEAT);
	
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

public Action RoundPostStart(Handle event,const String:name[],bool dontBroadcast)
{
	ServerCommand("mp_buytime 0");
	
	return Plugin_Continue;
}

public Action EnterBuyzone(Handle event,const String:name[],bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	clientIsInBuyzone[client] = true;
	return Plugin_Continue;
}

public Action ExitBuyzone(Handle event,const String:name[],bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	clientIsInBuyzone[client] = false;
	return Plugin_Continue;
}

public Action HurtTracker(Handle event,const String:name[],bool dontBroadcast)
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
	damagedonetotal[attacker] += damagedone;
	//clientIsShooting[attacker] = true;
	
	if (!IsClientConnected(attacker) && !IsClientInGame(attacker) && client > 0)
	{
		PrintToConsole(client, "DEBUG: Took damage by world.");
	}

	if (client > 0 && attacker > 0) // checks to see if the client and attacker id is valid
	{

		if (hitarea == 1) // checks the place where the user got shot (1 = hs)
		{
			SetHudTextParams(-1.0, 0.6, 2.0, 150, 220, 50, 205);
			ShowHudText(attacker, 2, "-%d (CRITICAL HIT!)", damagedonetotal[attacker]);
			if (IsPlayerAlive(client)) ClientCommand(attacker, "playgamesound training/bell_impact.wav");
		} else {
			SetHudTextParams(-1.0, 0.6, 2.0, 200, 50, 50, 205);
			ShowHudText(attacker, 2, "-%d", damagedonetotal[attacker]);
			if (IsPlayerAlive(client)) ClientCommand(attacker, "playgamesound training/bell_normal.wav");
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
	
	
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	int assister = GetClientOfUserId(GetEventInt(event, "assister"));
	
	ClientCommand(attacker, "playgamesound ui/xp_milestone_01.wav");
	
	AddPoints(GetClientTeam(attacker), 2, sm_csf2_gamemode);
	if (assister != 0 && IsClientConnected(assister) && IsClientInGame(assister) && GetClientTeam(assister) == GetClientTeam(attacker)) AddPoints(GetClientTeam(attacker), 1, sm_csf2_gamemode);
	
	if (class[attacker] == spy)
	{
		GivePlayerItem(attacker, "weapon_flashbang");
		GivePlayerItem(attacker, "weapon_smokegrenade");
		GivePlayerItem(attacker, "weapon_tagrenade");
		GivePlayerItem(attacker, "weapon_tagrenade");
	}
	
	isInDispenser[client] = 0;
	
	float pos[3];
	GetClientAbsOrigin(client, pos);
	DropAmmo(pos);
	
	return Plugin_Continue;
}

public Action DropAmmo(float pos[3])
{
	int ammobox = CreateEntityByName("prop_physics_override");
	Entity_SetName(ammobox, "item_ammo_drop"); // name this entity so it can be referred to outside of this scope.
	Entity_SetModel(ammobox, "models/props/coop_cementplant/coop_ammo_stash/coop_ammo_stash_full.mdl");
	if (DispatchSpawn(ammobox))
	{
		TeleportEntity(ammobox, pos, NULL_VECTOR, NULL_VECTOR);
	}
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
	bool changed = false;
	float distance = Entity_GetDistance(attacker, victim);
	decl String:sClassname[64];
	GetEdictClassname(inflictor, sClassname, sizeof(sClassname));
	
	if (sm_csf2_gamemode.IntValue == 5 && GetClientTeam(attacker) == CS_TEAM_CT)
	{
		fDamage = 100.0;
		changed = true;
	}
	
	if (damagetype == DMG_FALL) // Reduce Fall Damage
	{
		fDamage /= 4.0;
		if (fDamage < 4.0) fDamage = 0.0;
		changed = true;
	}
	
	// Weapon Damage Fall Off and Ramp Up
	if (IsValidEdict(bweapon))
	{
		char wClassname[64];
		GetEdictClassname(bweapon, wClassname, 64);
		if (StrEqual(wClassname, "weapon_nova") || StrEqual(wClassname, "weapon_p250"))
		{
			if (distance < 500)
			{
				fDamage *= 1.25;
			}
			else if (distance > 1500)
			{
				fDamage *= 0.8;
			}
			changed = true;
		}
		else if (StrEqual(wClassname, "weapon_ssg08"))
		{
			// do nothing
		}
		else if (StrEqual(wClassname, "weapon_negev"))
		{
			if (distance < 480)
			{
				fDamage *= 1.7;
			}
			else if (distance > 750)
			{
				fDamage *= 0.8;
			}
			else if (distance > 1250)
			{
				fDamage *= 0.5;
			}
			changed = true;
		}
		else if (StrEqual(wClassname, "weapon_p90"))
		{
			if (distance < 170)
			{
				fDamage *= 1.5;
			}
			else if (distance > 280)
			{
				fDamage *= 0.7;
			}
			changed = true;
		}
		else if (StrContains(wClassname, "weapon_"))
		{
			if (distance < 440)
			{
				fDamage *= 1.15;
			}
			else if (distance > 950)
			{
				fDamage *= 0.7;
			}
			changed = true;
		}
	}
	
	//-------

	if (victim > 0 && attacker > 0)	// make sure they are both valid entities
	{
		if (class[attacker] == soldier) 
		{
			if (GetClientTeam(attacker) != GetClientTeam(victim))
			{
				float ClientPos[3];
				GetClientEyePosition(victim, ClientPos);
				float dist = GetVectorDistance(damagePosition, ClientPos);

				RJ_Jump(victim, dist, damagePosition, ClientPos, 0.75);
			}
		}
		
		
		
		if(GetClientTeam(victim) == GetClientTeam(attacker) || GetClientTeam(victim) == 9)
		{
			if (class[attacker] == medic)
			{
				int iNewVal, iCurrentVal, MaxVal;
				iCurrentVal = GetEntProp(victim, Prop_Send, "m_iHealth");
				MaxVal = GetEntData(victim, FindDataMapInfo(victim, "m_iMaxHealth"), 4);
				iNewVal = RoundFloat(float(iCurrentVal) + 2);
				if(iNewVal > MaxVal)
				{
					iNewVal = MaxVal;
				}
				SetEntProp(victim, Prop_Send, "m_iHealth", iNewVal);
			}
			
			fDamage = 0.0;
		}
		if (class[attacker] == spy && (GetClientTeam(victim) != GetClientTeam(attacker)) && fDamage > 75.0)
		{
			fDamage = 1000.0;
		}
		changed = true;
	}
	
	if (GetConVarBool(sm_csf2_randomcrits))
	{
		fDamage *= 3;
		changed = true;
	}
	
	if (changed) return Plugin_Changed;
	
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
	
	if (StrEqual(entityname, "item_ammo_drop"))
	{
		ClientCommand(client, "playgamesound items/pickup_ammo_01.wav");
		RemoveEdict(entity);
		if (IsClientInGame(client))
		{
			int primaryWeapon = GetPlayerWeaponSlot(client, 0);
			int secondaryWeapon = GetPlayerWeaponSlot(client, 1);
			int armorValue = GetEntProp(client, Prop_Send, "m_ArmorValue");
			if (armorValue + 50 > 150) armorValue = 100;
			SetEntProp(client, Prop_Send, "m_ArmorValue", armorValue + 50);
			
			if (primaryWeapon != -1)
			{
				int primaryRes = GetEntProp(primaryWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount");
				SetEntProp(primaryWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount", primaryRes + (PrimaryReserveAmmo[class[client] - 1] / 2));
			}
			
			if (secondaryWeapon != -1)
			{
				int secondaryRes = GetEntProp(secondaryWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount");
				SetEntProp(secondaryWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount", secondaryRes + (SecondaryReserveAmmo[class[client] - 1] / 2));
			}
		}
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
	
		//if (StrEqual(weapon, "weapon_mag7")) PlaceMine(client);
		//if (StrEqual(weapon, "weapon_mag7")) ClientCommand(client, "sm_mine");
		if (StrEqual(weapon, "weapon_xm1014")) RocketStart(client);
	}
	
	if (class[client] == pyro)
	{
		GetEventString(event, "weapon", weapon, 128);
		
		if (StrEqual(weapon, "weapon_p90"))CreateFlames(client);
	}
	
	if (class[client] == medic)
	{
		int primaryWeapon = GetPlayerWeaponSlot(client, 0);
		SetEntProp(primaryWeapon, Prop_Send, "m_iPrimaryReserveAmmoCount", 1200);
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
	
	if (sm_csf2_gamemode.IntValue == 2)
	{
		if (GetClientTeam(client) == CS_TEAM_T) GivePlayerItem(client, "weapon_c4");
	}
	
	if (IsFakeClient(client))
	{
		if (ClassOnTeam(GetClientTeam(client), medic) < 1) class[client] = medic; // Medic is priority class
		else if (ClassOnTeam(GetClientTeam(client), medic) == 1 && class[client] == medic) class[client] = medic; // If they are the only medic, they wont switch off.
		else
		{
			int rndclass;

			if (ClassOnTeam(GetClientTeam(client), sniper) > 2) // Bots prefer not to have more than 2 snipers or spies on their team
			{
				do rndclass = GetRandomInt(1, 9); while (rndclass == 8);
				class[client] = classtype:rndclass;
			}
			else if (ClassOnTeam(GetClientTeam(client), spy) > 2)
			{
				rndclass = GetRandomInt(1, 8);
			}
			else rndclass = GetRandomInt(1, 9);
			
			class[client] = classtype:rndclass;
		}
		
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
			
			if (GetClientTeam(client) == CS_TEAM_CT) SetEntityModel(client, "models/player/custom_player/kuristaja/tf2/scout/scout_bluv2.mdl");
			else if (GetClientTeam(client) == CS_TEAM_T) SetEntityModel(client, "models/player/custom_player/kuristaja/tf2/scout/scout_redv2.mdl");
			
		}
		
		case soldier:
		{
			GivePlayerItem(client, "weapon_xm1014");
			CreateTimer(0.1, RespawnSoldier, client, TIMER_FLAG_NO_MAPCHANGE);
			//GivePlayerItem(client, "weapon_sawedoff");
			healthtype[client] = 200;
			
			if (GetClientTeam(client) == CS_TEAM_CT) SetEntityModel(client, "models/player/custom_player/kuristaja/tf2/soldier/soldier_bluv2.mdl");
			else if (GetClientTeam(client) == CS_TEAM_T) SetEntityModel(client, "models/player/custom_player/kuristaja/tf2/soldier/soldier_redv2.mdl");
		}
		
		case pyro:
		{
			GivePlayerItem(client, "weapon_p90");
			//GivePlayerItem(client, "weapon_sawedoff");
			GivePlayerItem(client, "weapon_taser");
			for (int i = 0; i < 16; i++)
			{
				GivePlayerItem(client, "weapon_incgrenade");
			}
			
			GivePlayerItem(client, "weapon_taser");
			GivePlayerItem(client, "item_assaultsuit");
			CreateTimer(0.1, RespawnNormal, client, TIMER_FLAG_NO_MAPCHANGE);
			healthtype[client] = 175;
			
			if (GetClientTeam(client) == CS_TEAM_CT) SetEntityModel(client, "models/player/custom_player/kuristaja/tf2/pyro/pyro_bluv2.mdl");
			else if (GetClientTeam(client) == CS_TEAM_T) SetEntityModel(client, "models/player/custom_player/kuristaja/tf2/pyro/pyro_redv2.mdl");
		}
		
		case demoman:
		{
			GivePlayerItem(client, "weapon_mag7");
			for (int i = 0; i < 16; i++)
			{
				GivePlayerItem(client, "weapon_hegrenade");
			}
			
			GivePlayerItem(client, "item_assaultsuit");
			CreateTimer(0.1, RespawnNormal, client, TIMER_FLAG_NO_MAPCHANGE);
			healthtype[client] = 175;
			
			if (GetClientTeam(client) == CS_TEAM_CT) SetEntityModel(client, "models/player/custom_player/kuristaja/tf2/demoman/demoman_bluv2.mdl");
			else if (GetClientTeam(client) == CS_TEAM_T) SetEntityModel(client, "models/player/custom_player/kuristaja/tf2/demoman/demoman_redv2.mdl");
		}
		
		
		case heavyweapons:
		{
			GivePlayerItem(client, "weapon_negev");
			GivePlayerItem(client, "weapon_tec9");
			GivePlayerItem(client, "item_assaultsuit");
			CreateTimer(0.1, RespawnHeavy, client, TIMER_FLAG_NO_MAPCHANGE);
			healthtype[client] = 300;
			
			if (GetClientTeam(client) == CS_TEAM_CT) SetEntityModel(client, "models/player/custom_player/kuristaja/tf2/heavy/heavy_bluv2.mdl");
			else if (GetClientTeam(client) == CS_TEAM_T) SetEntityModel(client, "models/player/custom_player/kuristaja/tf2/heavy/heavy_redv2.mdl");
		}
		
		case engineer:
		{
			GivePlayerItem(client, "weapon_nova");
			GivePlayerItem(client, "weapon_p250");
			GivePlayerItem(client, "item_assaultsuit");
			CreateTimer(0.1, RespawnLight, client, TIMER_FLAG_NO_MAPCHANGE);
			healthtype[client] = 125;
			
			if (GetClientTeam(client) == CS_TEAM_CT) SetEntityModel(client, "models/player/custom_player/kuristaja/tf2/engineer/engineer_bluv2.mdl");
			else if (GetClientTeam(client) == CS_TEAM_T) SetEntityModel(client, "models/player/custom_player/kuristaja/tf2/engineer/engineer_redv2.mdl");
		}
		
		case medic:
		{
			
			GivePlayerItem(client, "weapon_bizon");
			GivePlayerItem(client, "weapon_healthshot");
			for (int i = 0; i < 8; i++)
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
			
			if (GetClientTeam(client) == CS_TEAM_CT) SetEntityModel(client, "models/player/custom_player/kuristaja/tf2/medic/medic_bluv2.mdl");
			else if (GetClientTeam(client) == CS_TEAM_T) SetEntityModel(client, "models/player/custom_player/kuristaja/tf2/medic/medic_redv2.mdl");
		}
		
		case sniper:
		{
			
			
			GivePlayerItem(client, "weapon_ssg08");
			GivePlayerItem(client, "weapon_tec9");
			GivePlayerItem(client, "item_assaultsuit");
			CreateTimer(0.1, RespawnLight, client, TIMER_FLAG_NO_MAPCHANGE);
			healthtype[client] = 125;
			
			if (GetClientTeam(client) == CS_TEAM_CT) SetEntityModel(client, "models/player/custom_player/kuristaja/tf2/sniper/sniper_bluv2.mdl");
			else if (GetClientTeam(client) == CS_TEAM_T) SetEntityModel(client, "models/player/custom_player/kuristaja/tf2/sniper/sniper_redv2.mdl");
		}
		
		case spy:
		{
			
			for (int i = 0; i < 16; i++)
			{
				GivePlayerItem(client, "weapon_flashbang");
				GivePlayerItem(client, "weapon_smokegrenade");
			}
			
			for (int i = 0; i < 8; i++)
			{
				GivePlayerItem(client, "weapon_tagrenade");
			}
			
			GivePlayerItem(client, "item_assaultsuit");
			CreateTimer(0.1, RespawnLight, client, TIMER_FLAG_NO_MAPCHANGE);
			healthtype[client] = 125;
			
			if (GetClientTeam(client) == CS_TEAM_CT) SetEntityModel(client, "models/player/custom_player/kuristaja/tf2/spy/spy_bluv2.mdl");
			else if (GetClientTeam(client) == CS_TEAM_T) SetEntityModel(client, "models/player/custom_player/kuristaja/tf2/spy/spy_redv2.mdl");
		}
		
		case saxtonhale:
		{
			
		}
		
		default:
		{
			PrintToChat(client, "Please choose a class before respawning.");
		}
	}
}

public Action RespawnScout(Handle timer, any client)
{
	SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.7);
	SetEntityGravity(client, 0.55);
	SetEntData(client, FindDataMapInfo(client, "m_iMaxHealth"), 185, 4, true); // Overheal
	SetEntData(client, FindDataMapInfo(client, "m_iHealth"), 125, 4, true);	   // Normal Health
}

public Action RespawnLight(Handle timer, any client)
{
	SetEntityGravity(client, 1.0);
	SetEntData(client, FindDataMapInfo(client, "m_iMaxHealth"), 185, 4, true);
	SetEntData(client, FindDataMapInfo(client, "m_iHealth"), 125, 4, true);
}

public Action RespawnNormal(Handle timer, any client)
{
	SetEntityGravity(client, 1.0);
	SetEntData(client, FindDataMapInfo(client, "m_iMaxHealth"), 260, 4, true);
	SetEntData(client, FindDataMapInfo(client, "m_iHealth"), 175, 4, true);
}

public Action RespawnSoldier(Handle timer, any client)
{
	SetEntityGravity(client, 0.9);
	SetEntData(client, FindDataMapInfo(client, "m_iMaxHealth"), 300, 4, true);
	SetEntData(client, FindDataMapInfo(client, "m_iHealth"), 200, 4, true);
}

public Action RespawnHeavy(Handle timer, any client)
{
	SetEntityGravity(client, 1.0);
	SetEntData(client, FindDataMapInfo(client, "m_iMaxHealth"), 450, 4, true);
	SetEntData(client, FindDataMapInfo(client, "m_iHealth"), 300, 4, true);
}

public Action RespawnSaxtonHale(Handle timer, any client)
{
	healthtype[client] = GetTeamClientCount(CS_TEAM_CT) * 575;
	SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", 1.5);
	SetEntityGravity(client, 0.25);
	int x = GetTeamClientCount(CS_TEAM_T);
	int HP = (x*5)+((x^4)/4) + 2000;
	SetEntData(client, FindDataMapInfo(client, "m_iMaxHealth"), HP, 4, true);
	SetEntData(client, FindDataMapInfo(client, "m_iHealth"), HP, 4, true);
	SetEntityModel(client, "models/player/custom_player/kuristaja/tf2/heavy/heavy_bluv2.mdl");
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
	
	if (StrEqual(sArgs, "class scout", false))
	{
		ForcePlayerSuicide(client);
		PrintToChat(client, "You will respawn as Scout.");
		class[client] = scout;
	}
	
	if (StrEqual(sArgs, "class soldier", false))
	{
		ForcePlayerSuicide(client);
		PrintToChat(client, "You will respawn as Soldier.");
		class[client] = soldier;
	}
	
	if (StrEqual(sArgs, "class pyro", false))
	{
		ForcePlayerSuicide(client);
		PrintToChat(client, "You will respawn as Pyro.");
		class[client] = pyro;
	}
	
	if (StrEqual(sArgs, "class demoman", false))
	{
		ForcePlayerSuicide(client);
		PrintToChat(client, "You will respawn as Demoman.");
		class[client] = demoman;
	}
	
	if (StrEqual(sArgs, "class heavy", false) || StrEqual(sArgs, "class heavyweapons", false))
	{
		ForcePlayerSuicide(client);
		PrintToChat(client, "You will respawn as Heavy.");
		class[client] = heavyweapons;
	}
	
	if (StrEqual(sArgs, "class engineer", false))
	{
		ForcePlayerSuicide(client);
		PrintToChat(client, "You will respawn as Engineer.");
		class[client] = engineer;
	}
	
	if (StrEqual(sArgs, "class medic", false))
	{
		ForcePlayerSuicide(client);
		PrintToChat(client, "You will respawn as Medic.");
		class[client] = medic;
	}
	
	if (StrEqual(sArgs, "class sniper", false))
	{
		ForcePlayerSuicide(client);
		PrintToChat(client, "You will respawn as Sniper.");
		class[client] = sniper;
	}
	
	if (StrEqual(sArgs, "class spy", false))
	{
		ForcePlayerSuicide(client);
		PrintToChat(client, "You will respawn as Spy.");
		class[client] = spy;
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

public Action OnShouldBotAttackPlayer(bot, player, &bool:result)
{
	if (result) return Plugin_Continue;
	
	if (class[bot] == medic && GetClientHealth(player) < healthtype[player] * 1.25)
	{
		if (class[player] != medic) result = true;
		else if (GetClientHealth(player) > healthtype[player]) result = true;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public int ClassOnTeam(int team, classtype:targetclass)
{
	if (GetTeamClientCount(team) == 0) return 0;
	int count = 0;
	for (int i = 1; i < MAXPLAYERS; i++)
	{
		if (!IsClientConnected(i) || !IsClientInGame(i)) continue;
		if (GetClientTeam(i) == team && class[i] == targetclass)
		{
			count++;
		}
	}
	
	return count;
}

public Action DecayOverheal(Handle timer)
{
	for (int i = 1; i < MAXPLAYERS; i++)
	{
		if (!IsClientConnected(i) || !IsClientInGame(i)) continue;
		int health = GetClientHealth(i);
		if (health > healthtype[i]) SetEntData(i, FindDataMapInfo(i, "m_iHealth"), health - 1, 4, true);
	}
}

// Saxton Hale Code

public Action ChooseTeam(client, const String:command[], argc)
{ 
	if (sm_csf2_gamemode.IntValue != 5) return Plugin_Continue;
	if (client == 0) 
    { 
        return Plugin_Continue; 
    } 

	if (GetClientTeam(client) == CS_TEAM_T) 
    {
		if (SaxtonHaleClient != -1 && GetTeamClientCount(CS_TEAM_T) > 0 && SaxtonHaleClient != client)
		{
			PrintToChat(client, "There can only be 1 player on Terrorist side."); 
			ChangeClientTeam(client, CS_TEAM_CT);
			return Plugin_Handled;
		}
		if (SaxtonHaleClient == -1 && GetTeamClientCount(CS_TEAM_T) == 0)
		{
			ChangeClientTeam(client, CS_TEAM_CT); 
			return Plugin_Handled;
		}
	} 

	return Plugin_Continue; 
}

public Action ActivateRage()
{
	RageActive = true;
	SaxtonHaleRage = 0;
	switch(BossType)
	{
		case 0:
		{
			CreateTimer(10.0, DeactivateRage);
		}
		case 1:
		{
			CreateTimer(10.0, DeactivateRage);
		}
		case 2:
		{
			CreateTimer(10.0, DeactivateRage);
		}
	}
}

public Action DeactivateRage(Handle timer)
{
	RageActive = false;
}