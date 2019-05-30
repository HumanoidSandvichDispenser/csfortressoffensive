/*
**
*/

#if defined _csfo_engineer_included
#endinput
#endif
#define _csfo_engineer_included

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <smlib>
#include <colors>
#define BUILDINGMAXHEALTH 180
#define DISPENSER_MODEL "models/props/de_mill/generatoronwheels.mdl"
#define SENTRY_MODEL ""
#define BARRIER1_MODEL "models/props_fortifications/concrete_block001_128_reference.mdl"
#define BARRIER2_MODEL "models/props/gg_vietnam/sandbags_line2.mdl"

#define SOUND_BUILD "physics/metal/metal_computer_impact_soft1.wav"
#define SOUND_IMPACT "physics/metal/metal_box_impact_hard1.wav"
#define SOUND_REPAIR "physics/metal/metal_barrel_sand_impact_bullet1.wav"

int isInDispenser[MAXPLAYERS + 1] = 0;
bool DispenserBuilt[MAXPLAYERS + 1] = false;
bool SentryBuilt[MAXPLAYERS + 1] = false;
bool DispenserBeingBuilt[MAXPLAYERS + 1] = false;
Handle AutobuildTimer[(MAXPLAYERS * 2) + 1]; // should one timer that loops through all clients be used instead?
int dispenserIndex = 0;

bool BuildDispenser(int client)
{
	char dispenserName[16];
	Format(dispenserName, 16, "dispenser_%d", client);
	PrintToConsole(client, "[CSF2:DEBUG] Checking if %s already exists...", dispenserName);
	
	if (Entity_FindByName(dispenserName) != INVALID_ENT_REFERENCE)
	{
		PrintToChat(client, "\x05You've already built a \x01Dispenser!");
		return false;
	}
	
	//PrintToChat(client, "%d", Entity_FindByName(dispenserName, "prop_physics_override"));
	
	decl Float:trace_start[3], Float:trace_angle[3], Float:trace_end[3], Float:trace_normal[3];
	GetClientEyePosition(client, trace_start);
	GetClientEyeAngles(client, trace_angle);
	GetAngleVectors(trace_angle, trace_end, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(trace_end, trace_end); // end = normal
	
	// offset start by near point
	for (new i = 0; i < 3; i++)
	trace_start[i] += trace_end[i] * TRACE_START;
	
	for (new i = 0; i < 3; i++)
	trace_end[i] = trace_start[i] + trace_end[i] * TRACE_LENGTH;
	
	TR_TraceRayFilter(trace_start, trace_end, CONTENTS_SOLID | CONTENTS_WINDOW, RayType_EndPoint, TraceFilter_All, 0);
	
	if (TR_DidHit(INVALID_HANDLE))
	{
		TR_GetEndPosition(trace_end, INVALID_HANDLE);
		TR_GetPlaneNormal(INVALID_HANDLE, trace_normal);
		
		CreateDispenser(client, trace_end, trace_normal);
		return true;
		
	} else {
		PrintCenterText(client, "Invalid dispenser position.");
		return false;
	}
	
}

bool BuildBarrier(int client, int type)
{
	char dispenserName[32];
	Format(dispenserName, 32, "barrier_%d_%d", type, client);
	PrintToConsole(client, "[CSF2:DEBUG] Checking if %s already exists...", dispenserName);
	
	if (Entity_FindByName(dispenserName) != INVALID_ENT_REFERENCE)
	{
		PrintToChat(client, "You've already built this building!");
		return false;
	}
	
	//PrintToChat(client, "%d", Entity_FindByName(dispenserName, "prop_physics_override"));
	
	decl Float:trace_start[3], Float:trace_angle[3], Float:trace_end[3], Float:trace_normal[3];
	GetClientEyePosition(client, trace_start);
	GetClientEyeAngles(client, trace_angle);
	GetAngleVectors(trace_angle, trace_end, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(trace_end, trace_end); // end = normal
	
	// offset start by near point
	for (new i = 0; i < 3; i++)
	trace_start[i] += trace_end[i] * TRACE_START;
	
	for (new i = 0; i < 3; i++)
	trace_end[i] = trace_start[i] + trace_end[i] * TRACE_LENGTH;
	
	TR_TraceRayFilter(trace_start, trace_end, CONTENTS_SOLID | CONTENTS_WINDOW, RayType_EndPoint, TraceFilter_All, 0);
	
	if (TR_DidHit(INVALID_HANDLE))
	{
		TR_GetEndPosition(trace_end, INVALID_HANDLE);
		TR_GetPlaneNormal(INVALID_HANDLE, trace_normal);
		
		CreateBarrier(client, trace_end, trace_normal, type);
		return true;
		
	} else {
		PrintCenterText(client, "Invalid building position.");
		return false;
	}
	
}

bool DestroyDispenser(int client)
{
	char dispenserName[16];
	Format(dispenserName, 16, "dispenser_%d", client);
	int ent = Entity_FindByName(dispenserName);
	if (ent != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(ent, "Break");
		return true;
	}
	
	return false;
}

bool DestroyBarrier(int client, int type)
{
	char dispenserName[32];
	Format(dispenserName, 32, "barrier_%d_%d", type, client);
	int ent = Entity_FindByName(dispenserName);
	if (ent != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(ent, "Break");
		return true;
	}
	
	return false;
}

public Action CreateDispenser(int client, float position[3], float normal[3])
{
	
	
	float angles[3];
	GetVectorAngles(normal, angles);
	
	
	// Create Dispenser
	int dispenser = CreateEntityByName("prop_physics_override");
	if (dispenser != INVALID_ENT_REFERENCE)
	{
		DispenserBeingBuilt[client] = true;
	
		char dispensername[32];
		char triggername[32];
		
		char dispenseroutput[64];
		
		Format(dispensername, 64, "dispenser_%d", client);
		Format(triggername, 32, "dispenserTrigger_%d", client);
		
		Entity_SetModel(dispenser, "models/props/de_mill/generatoronwheels.mdl");
		DispatchKeyValue(dispenser, "physdamagescale", "0.0"); // enable this to destroy via physics?
		DispatchKeyValue(dispenser, "targetname", dispensername);
		DispatchKeyValue(dispenser, "spawnflags", "258"); // set "usable" flag (256) and don't take physics damage (2)
		DispatchKeyValue(dispenser, "health", "400"); // set "usable" flag (256) and don't take physics damage (2)
		DispatchSpawn(dispenser);
		
		//Entity_SetHealth(dispenser, 400);
		//SetEntityMoveType(dispenser, MOVETYPE_FLY); // Stay still but with collision
		SetEntProp(dispenser, Prop_Data, "m_takedamage", 1);
		SetEntProp(dispenser, Prop_Send, "m_nSkin", client);
		SetEntPropFloat(dispenser, Prop_Send, "m_flElasticity", 400.0); // Elasticity prop is used so it can replace health, since health does not work for this entity.
		SetEntityMoveType(dispenser, MOVETYPE_FLY);
		SetEntityRenderColor(dispenser, 255, 255, 255, 255);
		//Entity_SetHealth(dispenser, 10);
		Entity_SetCollisionGroup(dispenser, COLLISION_GROUP_PUSHAWAY);
		angles[0] += 90;
		TeleportEntity(dispenser, position, angles, NULL_VECTOR);
		
		PrintHintText(client, "Repairing dispenser HP: %d / 400", RoundToNearest(GetEntPropFloat(dispenser, Prop_Send, "m_flElasticity")));
		
		Format(dispenseroutput, sizeof(dispenseroutput), "%s,Kill,,0,-1", triggername);
		DispatchKeyValue(dispenser, "OnBreak", dispenseroutput);
		
		int trigger = CreateTrigger(position, triggername);
		HookSingleEntityOutput(trigger, "OnStartTouch", dispenseammo, false);
		HookSingleEntityOutput(trigger, "OnEndTouch", dispenseammo, false);
		HookSingleEntityOutput(dispenser, "OnBreak", UnhookDispenser, false);
		SetEntPropEnt(trigger, Prop_Data, "m_hOwnerEntity", client);
		
		EmitSoundToAll(SOUND_BUILD, dispenser);
		
		SDKHook(dispenser, SDKHook_OnTakeDamage, Event_EntOnTakeDamage);
	}
	
	/*
	dispenserIndex++;
	
	char realDispenserName[16];
	Entity_GetName(dispenser, realDispenserName, 16);
	PrintToConsole(client, "[CSF2:DEBUG] Creating dispenser %s", realDispenserName);
	//AutobuildTimer[client] = CreateTimer(0.1, Autobuild, dispenser);
	
	int health = Entity_GetHealth(dispenser);
	if (GetClientTeam(client) == CS_TEAM_T)SetHudTextParams(0.7, 0.1, 0.0, 95, 151, 239, 235);
	if (GetClientTeam(client) == CS_TEAM_CT)SetHudTextParams(0.7, 0.1, 0.0, 239, 197, 95, 235);
	ShowHudText(client, 4, "Dispenser: %d HP", health);
	*/
}

public Action CreateBarrier(int client, float position[3], float angs[3], int type)
{
	
	
	float angles[3];
	GetVectorAngles(angs, angles);
	
	
	// Create Dispenser
	int dispenser = CreateEntityByName("prop_physics_override");
	if (dispenser != INVALID_ENT_REFERENCE)
	{
		char dispensername[32];

		Format(dispensername, 64, "barrier_%d_%d", type, client);
		
		if (type == 0) 
			Entity_SetModel(dispenser, BARRIER1_MODEL);
		else
			Entity_SetModel(dispenser, BARRIER2_MODEL);
		DispatchKeyValue(dispenser, "physdamagescale", "0.0"); // enable this to destroy via physics?
		DispatchKeyValue(dispenser, "targetname", dispensername);
		DispatchKeyValue(dispenser, "spawnflags", "258"); // set "usable" flag (256) and don't take physics damage (2)
		DispatchKeyValue(dispenser, "health", "400"); // set "usable" flag (256) and don't take physics damage (2)
		DispatchSpawn(dispenser);
		
		SetEntProp(dispenser, Prop_Data, "m_takedamage", 1);
		SetEntProp(dispenser, Prop_Send, "m_nSkin", client);
		SetEntPropFloat(dispenser, Prop_Send, "m_flElasticity", 700.0); // Elasticity prop is used so it can replace health, since health does not work for this entity.
		SetEntityMoveType(dispenser, MOVETYPE_FLY);
		SetEntityRenderColor(dispenser, 255, 255, 255, 255);
		//Entity_SetHealth(dispenser, 10);
		Entity_SetCollisionGroup(dispenser, COLLISION_GROUP_PUSHAWAY);
		angles[0] += 90;
		TeleportEntity(dispenser, position, angles, NULL_VECTOR);
		
		PrintHintText(client, "Repairing dispenser HP: %d / 700", RoundToNearest(GetEntPropFloat(dispenser, Prop_Send, "m_flElasticity")));
		
		HookSingleEntityOutput(dispenser, "OnBreak", UnhookDispenser, false);
		
		EmitSoundToAll(SOUND_BUILD, dispenser);
		
		SDKHook(dispenser, SDKHook_OnTakeDamage, Event_EntOnTakeDamage);
	}
}

// 
public UnhookDispenser(const char[] output, any caller, any activator, float delay)
{
	char buildingName[64];
	Entity_GetName(caller, buildingName, 64);
	int owner = GetEntProp(caller, Prop_Data, "m_nSkin");
	if (String_StartsWith(buildingName, "dispenser_")) PrintToChat(owner, "Your dispenser \x0Fhas been destroyed!");
	if (String_StartsWith(buildingName, "barrier_0_")) PrintToChat(owner, "Your barricade \x0Fhas been destroyed!");
	if (String_StartsWith(buildingName, "barrier_1_")) PrintToChat(owner, "Your sandbags \x0Fhave been destroyed!");
	
	SDKUnhook(caller, SDKHook_OnTakeDamage, Event_EntOnTakeDamage);
}

//from https://forums.alliedmods.net/showthread.php?t=129597
public int CreateTrigger(float position[3], char triggername[32])
{
	int trigger = CreateEntityByName("trigger_hurt");
	if (trigger != -1)
	{
		DispatchKeyValue(trigger, "targetname", triggername);
		DispatchKeyValue(trigger, "damage", "-20");
		DispatchKeyValue(trigger, "nodmgforce", "1");
		DispatchKeyValue(trigger, "spawnflags", "4097");
	}

	DispatchSpawn(trigger);
	ActivateEntity(trigger);
	
	TeleportEntity(trigger, position, NULL_VECTOR, NULL_VECTOR);
	
	SetEntityModel(trigger, "models/props/cs_office/vending_machine.mdl");
	
	float minbounds[3] =  { -128.0, -128.0, 0.0 };
	float maxbounds[3] =  { 128.0, 128.0, 96.0 };
	SetEntPropVector(trigger, Prop_Send, "m_vecMins", minbounds);
	SetEntPropVector(trigger, Prop_Send, "m_vecMaxs", maxbounds);
	
	SetEntProp(trigger, Prop_Send, "m_nSolidType", 2);
	
	new enteffects = GetEntProp(trigger, Prop_Send, "m_fEffects");
	enteffects |= 32;
	SetEntProp(trigger, Prop_Send, "m_fEffects", enteffects);
	
	
	
	return trigger;
}

public dispenseammo(const String:output[], caller, activator, float delay)
{
	int client = activator;
	
	
	if (client < 1 || !IsClientConnected(client))
	{
		return;
	}
	
	if (StrEqual(output, "OnStartTouch", false))
	{
		isInDispenser[client]++;
	}
	else if (StrEqual(output, "OnEndTouch", false))
	{
		isInDispenser[client]--;
	}
}

public Action Autobuild(Handle timer, any building)
{
	int health = Entity_GetHealth(building);
	if (health < BUILDINGMAXHEALTH)
	{
		Entity_AddHealth(building, 1);
		return Plugin_Continue;
	}
	else return Plugin_Stop;
}

stock BuildSentry(int client)
{
	
} 

public Action Event_EntOnTakeDamage(entity, &attacker, &inflictor, &Float:fDamage, &damagetype, &bweapon, Float:damageForce[3], Float:damagePosition[3])
{
	if (attacker > 0 && attacker < MAXPLAYERS && IsClientConnected(attacker))
	{
		char buildingName[64];
		Entity_GetName(entity, buildingName, 64);
		int owner = GetEntProp(entity, Prop_Data, "m_nSkin");
		float HP = GetEntPropFloat(entity, Prop_Send, "m_flElasticity");
		if (GetClientTeam(attacker) == GetClientTeam(owner))
		{
			if (owner == attacker)
			{
				HP += 80;
				if (String_StartsWith(buildingName, "dispenser_")) 
				{
					if (HP > 400) HP = 400.0;
					SetEntPropFloat(entity, Prop_Send, "m_flElasticity", HP);
					PrintHintText(owner, "Repairing dispenser HP: %d / 400", RoundToNearest(HP));
				}
				if (String_StartsWith(buildingName, "barrier_")) 
				{
					if (HP > 700) HP = 700.0;
					SetEntPropFloat(entity, Prop_Send, "m_flElasticity", HP);
					PrintHintText(owner, "Repairing dispenser HP: %d / 700", RoundToNearest(HP));
				}
			}
		}
		else
		{
			HP -= fDamage;
			SetEntPropFloat(entity, Prop_Send, "m_flElasticity", HP);
			if (HP <= 0) AcceptEntityInput(entity, "Break");
		}
	}
	return Plugin_Continue;
}