/*
**
*/

#if defined _csfo_grenadelauncher_included
#endinput
#endif
#define _csfo_grenadelauncher_included

/*
#define BULLET_SPEED			1000.0
#define MAX_DISTANCE			160.0
#define JUMP_FORCE_UP			8.0
#define JUMP_FORCE_FORW			1.20
#define JUMP_FORCE_BACK			1.25
#define JUMP_FORCE_MAIN			270.0
#define RUN_FORCE_MAIN			0.8
*/


#include <smlib>
#define PIPE_MODEL "models/props_junk/popcan01a.mdl"
#define STICKY_MODEL "models/props_junk/popcan01a.mdl"
#define ADD_OUTPUT "OnUser1 !self:Kill::1.5:1"

int PipeIndex[64] = 0;
//bool PipeBombTouch[64];

public Action:PipeStart(client)
{
	int ent = CreateEntityByName("hegrenade_projectile");
	if (ent == -1)
		return;
	new Float:OwnerAng[3];
	new Float:OwnerPos[3];
	new Float:InitialPos[3];
	new Float:InitialVec[3];
	new Float:InitialAng[3];
	SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", client);
	SetEntPropFloat(ent, Prop_Send, "m_flModelScale", 2.0);
	GetClientEyeAngles(client, OwnerAng);
	GetClientEyePosition(client, OwnerPos);
	TR_TraceRayFilter(OwnerPos, OwnerAng, MASK_SOLID, RayType_Infinite, FireEntPipe, ent);
	TR_GetEndPosition(InitialPos);
	MakeVectorFromPoints(OwnerPos, InitialPos, InitialVec);
	NormalizeVector(InitialVec, InitialVec);
	ScaleVector(InitialVec, 1100.0);
	GetVectorAngles(InitialVec, InitialAng);
	InitialAng[1] -= 90;
	
	char angleskv[16];
	Format(angleskv, 16, "%s %s %s", InitialAng[0], InitialAng[1], InitialAng[2]);
	DispatchKeyValue(ent, "angles", angleskv);
	DispatchSpawn(ent);
	ActivateEntity(ent);
	SetEntityModel(ent, PIPE_MODEL);
	SetEntityMoveType(ent, MOVETYPE_FLYGRAVITY);
	SetEntPropFloat(ent, Prop_Send, "m_flElasticity", 0.45);
	SetEntityGravity(ent, 0.35);
	
	Entity_SetMinMaxSize(ent, Float: { -16.0, -16.0, -16.0 }, Float: { 16.0, 16.0, 16.0 } );
	
	//SetPipeIndex(ent, false);
	
	TeleportEntity(ent, OwnerPos, InitialAng, InitialVec);
	SDKHook(ent, SDKHook_StartTouchPost, PipeTouch);
}

public Action:PipeTouch(ent, other)
{
	SDKUnhook(ent, SDKHook_StartTouch, PipeTouch);
	if (other > 0 && other < MAXPLAYERS)
	{
		DetonatePipe(ent);
		//PipeBombTouch[GetPipeIndex(ent)] = true;
	}
	else
		if (GetEntProp(other, Prop_Data, "m_nSolidType") && !(GetEntProp(other, Prop_Data, "m_usSolidFlags") & 0x0004))
	{
		//PipeBombTouch[GetPipeIndex(ent)] = true;
		SetEntityGravity(ent, 1.0);
		CreateTimer(2.0, DetonateTimedPipe, ent);
	}
}

public Action DetonateTimedPipe(Handle timer, ent)
{
	if (!Entity_IsValid(ent))return Plugin_Continue;
	new MissileOwner = GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity");
	if (IsClientInGame(MissileOwner))
	{
		if (IsPlayerAlive(MissileOwner))
		{
			float OwnerPos[3], RocketPos[3];
			GetClientEyePosition(MissileOwner, OwnerPos);
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", RocketPos);
			float distance = GetVectorDistance(RocketPos, OwnerPos);
			
			RJ_Jump(MissileOwner, distance, RocketPos, OwnerPos, 0.5, false);
		}
		new Float:MissilePos[3];
		new MissileOwnerTeam = GetEntProp(MissileOwner, Prop_Send, "m_iTeamNum");
		new ExplosionIndex = CreateEntityByName("env_explosion");
		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", MissilePos);
		SetEntProp(ent, Prop_Send, "m_iTeamNum", MissileOwnerTeam);
		DispatchKeyValue(ExplosionIndex, "classname", "hegrenade_projectile");
		SetEntProp(ExplosionIndex, Prop_Data, "m_spawnflags", 6146);
		SetEntProp(ExplosionIndex, Prop_Data, "m_iMagnitude", 120);
		SetEntProp(ExplosionIndex, Prop_Data, "m_iRadiusOverride", 280);
		DispatchSpawn(ExplosionIndex);
		ActivateEntity(ExplosionIndex);
		TeleportEntity(ExplosionIndex, MissilePos, NULL_VECTOR, NULL_VECTOR);
		SetEntPropEnt(ExplosionIndex, Prop_Send, "m_hOwnerEntity", MissileOwner);
		SetEntProp(ExplosionIndex, Prop_Send, "m_iTeamNum", MissileOwnerTeam);
		//EmitSoundToAll("weapons/hegrenade/explode5.wav", ExplosionIndex, 1, 90);
		AcceptEntityInput(ExplosionIndex, "Explode");
		DispatchKeyValue(ExplosionIndex, "classname", "env_explosion");
		AcceptEntityInput(ExplosionIndex, "Kill");
		AcceptEntityInput(ent, "Kill");
	}
	else
		AcceptEntityInput(ent, "Kill");
	
	SetPipeIndex(ent, true);
	return Plugin_Continue;
}

public Action DetonatePipe(ent) // Direct Hit
{
	if (!Entity_IsValid(ent))return Plugin_Continue;
	new MissileOwner = GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity");
	if (IsClientInGame(MissileOwner))
	{
		if (IsPlayerAlive(MissileOwner))
		{
			float OwnerPos[3], RocketPos[3];
			GetClientEyePosition(MissileOwner, OwnerPos);
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", RocketPos);
			float distance = GetVectorDistance(RocketPos, OwnerPos);
			
			RJ_Jump(MissileOwner, distance, RocketPos, OwnerPos, 0.7, true);
		}
		new Float:MissilePos[3];
		new MissileOwnerTeam = GetEntProp(MissileOwner, Prop_Send, "m_iTeamNum");
		new ExplosionIndex = CreateEntityByName("env_explosion");
		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", MissilePos);
		SetEntProp(ent, Prop_Send, "m_iTeamNum", MissileOwnerTeam);
		DispatchKeyValue(ExplosionIndex, "classname", "hegrenade_projectile");
		SetEntProp(ExplosionIndex, Prop_Data, "m_spawnflags", 6146);
		SetEntProp(ExplosionIndex, Prop_Data, "m_iMagnitude", 255);
		SetEntProp(ExplosionIndex, Prop_Data, "m_iRadiusOverride", 220);
		DispatchSpawn(ExplosionIndex);
		ActivateEntity(ExplosionIndex);
		TeleportEntity(ExplosionIndex, MissilePos, NULL_VECTOR, NULL_VECTOR);
		SetEntPropEnt(ExplosionIndex, Prop_Send, "m_hOwnerEntity", MissileOwner);
		SetEntProp(ExplosionIndex, Prop_Send, "m_iTeamNum", MissileOwnerTeam);
		//EmitSoundToAll("weapons/hegrenade/explode5.wav", ExplosionIndex, 1, 90);
		AcceptEntityInput(ExplosionIndex, "Explode");
		DispatchKeyValue(ExplosionIndex, "classname", "env_explosion");
		AcceptEntityInput(ExplosionIndex, "Kill");
		AcceptEntityInput(ent, "Kill");
	}
	else
		AcceptEntityInput(ent, "Kill");
	
	SetPipeIndex(ent, true);
	return Plugin_Continue;
}


public bool:FireEntPipe(ent, contentsMask, any:data)
{
	return false;
}

public int GetPipeIndex(pipe)
{
	for (int i = 0; i < 64; i++)
	{
		if (PipeIndex[i] == pipe)return i;
	}
	
	return -1;
}

public void SetPipeIndex(pipe, remove)
{
	for (int i = 0; i < 64; i++)
	{
		if (remove && PipeIndex[i] != 0)
		{
			PipeIndex[i] = 0;
			break;
		}
		else if (!remove && PipeIndex[i] == 0)
		{
			PipeIndex[i] = pipe;
			break;
		}
		
	}
}

//Stickybomb Code

public Action:StickyStart(client)
{
	int ent = CreateEntityByName("hegrenade_projectile");
	if (ent == -1)
		return;
	new Float:OwnerAng[3];
	new Float:OwnerPos[3];
	new Float:InitialPos[3];
	new Float:InitialVec[3];
	new Float:InitialAng[3];
	SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", client);
	//SetEntPropFloat(ent, Prop_Send, "m_flModelScale", 1.0);
	GetClientEyeAngles(client, OwnerAng);
	GetClientEyePosition(client, OwnerPos);
	TR_TraceRayFilter(OwnerPos, OwnerAng, MASK_SOLID, RayType_Infinite, FireEntPipe, ent);
	TR_GetEndPosition(InitialPos);
	MakeVectorFromPoints(OwnerPos, InitialPos, InitialVec);
	NormalizeVector(InitialVec, InitialVec);
	ScaleVector(InitialVec, 500.0);
	GetVectorAngles(InitialVec, InitialAng);
	InitialAng[1] -= 90;
	
	char angleskv[16];
	Format(angleskv, 16, "%s %s %s", InitialAng[0], InitialAng[1], InitialAng[2]);
	DispatchKeyValue(ent, "angles", angleskv);
	DispatchSpawn(ent);
	ActivateEntity(ent);
	SetEntityModel(ent, STICKY_MODEL);
	//SetEntityMoveType(ent, MOVETYPE_FLYGRAVITY);
	SetEntPropFloat(ent, Prop_Send, "m_flElasticity", 0.25);
	SetEntityGravity(ent, 0.75);
	Entity_SetName(ent, "stickybomb");
	
	SetPipeIndex(ent, false);
	
	TeleportEntity(ent, OwnerPos, InitialAng, InitialVec);
	SDKHook(ent, SDKHook_StartTouchPost, StickyTouch);
}

public StickyTouch(ent, other)
{
	SDKUnhook(ent, SDKHook_StartTouch, StickyTouch);
	
	if (other > 0 && other < MAXPLAYERS)
	{
		DetonateSticky(ent);
		return;
	}
	SetEntProp(ent, Prop_Send, "m_CollisionGroup", 2);
	SetEntityMoveType(ent, MOVETYPE_NONE);
}

public Action DetonateStickies(int MissileOwner)
{
	if (!Entity_IsValid(MissileOwner))return Plugin_Continue;
	int realMaxEntities = GetMaxEntities() * 2;
	for (int ent = MAXPLAYERS + 1; ent < realMaxEntities; ent++) // original from smlib
	{
		if (!IsValidEntity(ent))
			continue;
		
		char entityname[64];
		Entity_GetName(ent, entityname, 64);
		if (Entity_GetOwner(ent) == MissileOwner && StrEqual(entityname, "stickybomb"))
		{
			DetonateSticky(ent);
			//PrintToChatAll("%d", ent);
		}
		
	}
	
	return Plugin_Continue;
}

public Action RemoveAllStickies(int MissileOwner)
{
	if (!Entity_IsValid(MissileOwner))return Plugin_Continue;
	int realMaxEntities = GetMaxEntities() * 2;
	for (int ent = MAXPLAYERS + 1; ent < realMaxEntities; ent++) // original from smlib
	{
		if (!IsValidEntity(ent))
			continue;
		
		char entityname[64];
		Entity_GetName(ent, entityname, 64);
		if (Entity_GetOwner(ent) == MissileOwner && StrEqual(entityname, "stickybomb"))
		{
			AcceptEntityInput(ent, "Kill");
		}
		
	}
	
	return Plugin_Continue;
}

public Action DetonateSticky(ent) // Direct Hit
{
	int MissileOwner = GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity");
	if (IsClientInGame(MissileOwner))
	{
		if (IsPlayerAlive(MissileOwner))
		{
			float OwnerPos[3], RocketPos[3];
			GetClientEyePosition(MissileOwner, OwnerPos);
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", RocketPos);
			float distance = GetVectorDistance(RocketPos, OwnerPos);
			
			RJ_Jump(MissileOwner, distance, RocketPos, OwnerPos, 1.0, true);
		}
		new Float:MissilePos[3];
		new MissileOwnerTeam = GetEntProp(MissileOwner, Prop_Send, "m_iTeamNum");
		new ExplosionIndex = CreateEntityByName("env_explosion");
		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", MissilePos);
		SetEntProp(ent, Prop_Send, "m_iTeamNum", MissileOwnerTeam);
		DispatchKeyValue(ExplosionIndex, "classname", "hegrenade_projectile");
		SetEntProp(ExplosionIndex, Prop_Data, "m_spawnflags", 6146);
		SetEntProp(ExplosionIndex, Prop_Data, "m_iMagnitude", 155);
		SetEntProp(ExplosionIndex, Prop_Data, "m_iRadiusOverride", 320);
		DispatchSpawn(ExplosionIndex);
		ActivateEntity(ExplosionIndex);
		TeleportEntity(ExplosionIndex, MissilePos, NULL_VECTOR, NULL_VECTOR);
		SetEntPropEnt(ExplosionIndex, Prop_Send, "m_hOwnerEntity", MissileOwner);
		SetEntProp(ExplosionIndex, Prop_Send, "m_iTeamNum", MissileOwnerTeam);
		//EmitSoundToAll("weapons/hegrenade/explode5.wav", ExplosionIndex, 1, 90);
		AcceptEntityInput(ExplosionIndex, "Explode");
		DispatchKeyValue(ExplosionIndex, "classname", "env_explosion");
		AcceptEntityInput(ExplosionIndex, "Kill");
		AcceptEntityInput(ent, "Kill");
	}
	else
		AcceptEntityInput(ent, "Kill");
	
	return Plugin_Continue;
} 