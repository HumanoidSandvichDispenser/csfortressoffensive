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
	if (DispenserBuilt[client])
	{
		CPrintToChat(client, "{lightgreen}You've already built a {white}Dispenser!");
		return false;
	}
	
	decl Float:trace_start[3], Float:trace_angle[3], Float:trace_end[3], Float:trace_normal[3];
	GetClientEyePosition( client, trace_start );
	GetClientEyeAngles( client, trace_angle );
	GetAngleVectors( trace_angle, trace_end, NULL_VECTOR, NULL_VECTOR );
	NormalizeVector( trace_end, trace_end ); // end = normal

	// offset start by near point
	for( new i = 0; i < 3; i++ )
		trace_start[i] += trace_end[i] * TRACE_START;
	
	for( new i = 0; i < 3; i++ )
		trace_end[i] = trace_start[i] + trace_end[i] * TRACE_LENGTH;
	
	TR_TraceRayFilter( trace_start, trace_end, CONTENTS_SOLID|CONTENTS_WINDOW, RayType_EndPoint, TraceFilter_All, 0 );
	
	if( TR_DidHit( INVALID_HANDLE ) ) 
	{
		TR_GetEndPosition( trace_end, INVALID_HANDLE );
		TR_GetPlaneNormal(INVALID_HANDLE, trace_normal);
		 
		CreateDispenser( client, trace_end, trace_normal );
		return true;

	} else {
		PrintCenterText( client, "Invalid dispenser position." );
		return false;
	}
	
}

public Action CreateDispenser(int client, float position[3], float normal[3])
{
	
	
	float angles[3];
	GetVectorAngles( normal, angles );
	
	
	// Create Dispenser
	int dispenser = CreateEntityByName("prop_physics_override");
	DispenserBeingBuilt[client] = true;
	
	char dispensername[32];
	char triggername[32];
	
	char dispenseroutput[64];
	
	Format(dispensername, 64, "dispenser%d", dispenserIndex);
	Format(triggername, 64, "trigger%d_%d", dispenserIndex, dispenser);
	
	Entity_SetModel(dispenser, "models/props/de_mill/generatoronwheels.mdl");
	DispatchKeyValue( dispenser, "physdamagescale", "0.0");	// enable this to destroy via physics?
	DispatchKeyValue( dispenser, "targetname", dispensername);
	DispatchKeyValue( dispenser, "spawnflags", "256"); // set "usable" flag
	DispatchSpawn( dispenser );
	
	Entity_SetHealth(dispenser, 10);
	SetEntityMoveType(dispenser, MOVETYPE_NONE);
	SetEntProp(dispenser, Prop_Data, "m_takedamage", 2);
	SetEntPropEnt(dispenser, Prop_Data, "m_hOwnerEntity",client);
	SetEntityRenderColor( dispenser, 255, 255, 255, 255 );
	Entity_SetHealth(dispenser, 10);
	Entity_SetCollisionGroup(dispenser, COLLISION_GROUP_DEBRIS);
	angles[0] += 90;
	TeleportEntity(dispenser, position, angles, NULL_VECTOR );
	
	
	Format(dispenseroutput, sizeof(dispenseroutput), "%s,Kill,,0,-1", triggername);
	DispatchKeyValue(dispenser, "OnBreak", dispenseroutput);
	
	int trigger = CreateTrigger(position, triggername);
	HookSingleEntityOutput(trigger, "OnStartTouch", dispenseammo, false);
	HookSingleEntityOutput(trigger, "OnEndTouch", dispenseammo, false);
	SetEntPropEnt(trigger, Prop_Data, "m_hOwnerEntity", client);
	
	EmitSoundToAll(SOUND_BUILD, dispenser);
	
	dispenserIndex++;
	
	AutobuildTimer[client] = CreateTimer(0.1, Autobuild, dispenser);
	
	int health = Entity_GetHealth(dispenser);
	if (GetClientTeam(client) == CS_TEAM_T) SetHudTextParams(0.2, 0.1, 0, 95, 151, 239, 235);
	if (GetClientTeam(client) == CS_TEAM_CT) SetHudTextParams(0.2, 0.1, 0, 239, 197, 95, 235);
	ShowHudText(client, 2, "Dispenser: %d HP", health);
	
	DispenserBuilt[client] = true;
}

//from https://forums.alliedmods.net/showthread.php?t=129597
public int CreateTrigger(float position[3], char triggername[32])
{
	int trigger = CreateEntityByName("trigger_hurt");
	if (trigger != -1)
	{
		DispatchKeyValue(trigger, "targetname", triggername);
		DispatchKeyValue(trigger, "damage", "-10");
		DispatchKeyValue(trigger, "nodmgforce", "1");
		DispatchKeyValue(trigger, "spawnflags", "4097");
	}
	
	DispatchSpawn(trigger);
	ActivateEntity(trigger);
	
	TeleportEntity(trigger, position, NULL_VECTOR, NULL_VECTOR);
	
	SetEntityModel(trigger, "models/props/cs_office/vending_machine.mdl");
	
	float minbounds[3] = {-32.0, -32.0, 0.0};
	float maxbounds[3] = {32.0, 32.0, 64.0};
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