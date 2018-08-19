/*
**
*/

#if defined _INCLUDE_included
 #endinput
#endif
#define _INCLUDE_included

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <smlib>
#define BUILDINGMAXHEALTH = 180
#define DISPENSER_MODEL = "models/props/de_mill/generatoronwheels.mdl"
#define SENTRY_MODEL = ""

bool DispenserBuilt[MAXPLAYERS + 1] = false;
bool SentryBuilt[MAXPLAYERS + 1] = false;
bool DispenserBeingBuilt[MAXPLAYERS + 1] = false;
Handle AutobuildTimer[(MAXPLAYERS * 2) + 1];

bool BuildDispenser(int client)
{
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
	
	if( TR_DidHit( INVALID_HANDLE ) ) {
		num_mines[client]--;


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
	
	int dispenser = CreateEntityByName("prop_physics_override");
	DispenserBeingBuilt[client] = true;
	AutobuildTimer[client] = CreateTimer(0.1, Autobuild, dispenser);
	char dispensername[64];
	char team[16];
	if (GetClientTeam(client) == CS_TEAM_CT)
	{
		team = "ct";
	} 
	else if (GetClientTeam(client) == CS_TEAM_T) 
	{
		team = "t";
	}
	
	//Entity_SetModel(dispenser, DISPENSER_MODEL);
	DispatchKeyValue( dispenser, "physdamagescale", "0.0");	// enable this to destroy via physics?
	DispatchKeyValue( dispenser, "health", "10" ); // use the set entity health function instead ?
	Entity_SetName(dispenser, dispensername);
	DispatchKeyValue( dispenser, "spawnflags", "256"); // set "usable" flag
	DispatchSpawn( dispenser );
	
	Format(dispensername, 64, "dispenser_%s", team);

	SetEntityMoveType(dispenser, MOVETYPE_NONE);
	SetEntProp(dispenser, Prop_Data, "m_takedamage", 2);
	SetEntPropEnt(dispenser, Prop_Data, "m_hOwnerEntity",client);
	SetEntityRenderColor( dispenser, 255, 255, 255, 255 );
	Entity_SetHealth(dispenser, 10)
	Entity_SetCollisionGroup(dispenser, DAMAGE_YES);
	TeleportEntity(dispenser, position, angles, NULL_VECTOR );
}

public Action Autobuild(Handle timer, any building)
{
	int health = Entity_GetHealth(building);
	if (health < 180)
	{
		Entity_AddHealth(building, 1);
		return Plugin_Continue;
	}
	else return Plugin_Stop;
}

stock BuildSentry(int client)
{

}