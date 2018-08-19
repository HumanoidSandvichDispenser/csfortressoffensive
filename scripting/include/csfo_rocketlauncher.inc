/*
**
*/

#if defined _csfo_rocketlauncher_included
 #endinput
#endif
#define _csfo_rocketlauncher_included



#include <smlib>
#define ROCKET_MODEL "models/props/de_inferno/hr_i/missile/missile_02.mdl"
#define ADD_OUTPUT "OnUser1 !self:Kill::1.5:1"

/*
//Creates a rocket.
//@param client				Player's index.
*/
/*
stock CreateRocket(int client)
{
	static float fPos[3];
	static float fAng[3];
	static float fVel[3];
	GetClientEyePosition(client, fPos);
	
	int rocket = CreateEntityByName("prop_physics_override");
	

	SetEntityModel(rocket, ROCKET_MODEL);
	if ((rocket != -1) && DispatchSpawn(rocket))
	{
		PrintToConsole(client, "DEBUG: Rocket creation successful.");
		SetEntPropEnt(rocket, Prop_Send, "m_hOwnerEntity", client);
		//SetVariantString(ADD_OUTPUT);
		//AcceptEntityInput(rocket, "AddOutput");
		GetClientEyeAngles(client, fAng);
		GetAngleVectors(fAng, fVel, NULL_VECTOR, NULL_VECTOR);
		ScaleVector(fVel, g_fVelocity);
		fAng[1] -= 90;
		SetEntityGravity(rocket, 0.001);
		TeleportEntity(rocket, fPos, fAng, fVel);
		
	} else {
		PrintToConsole(client, "DEBUG: Rocket creation failure.");

	}
	
	
	SDKHook(rocket, SDKHook_StartTouch, rocketCollision);
	HookSingleEntityOutput(rocket, "break", RocketBreak);
}


public rocketCollision(int rocket, int entity)
{
	if((GetEntProp(entity, Prop_Data, "m_nSolidType") != SOLID_NONE) && (!(GetEntProp(entity, Prop_Data, "m_usSolidFlags") & FSOLID_NOT_SOLID)))
	{
		DetonateRocket(rocket);
	}
	
	PrintToServer("DEBUG: Rocket has collided with a brush or entity.");
	SDKUnhook(rocket, SDKHook_StartTouch, rocketCollision);
}



//Detonates a rocket.
//@param owner				Owner's index.
//@param rocket				Rocket entity index.


stock DetonateRocket(int rocket)
{
	AcceptEntityInput(rocket, "break");
}

public CreateRocketExplosion( Float:vec[3], owner ) {
	int ent = CreateEntityByName("env_explosion");	
	DispatchKeyValue(ent, "classname", "env_explosion");
	SetEntPropEnt(ent, Prop_Data, "m_hOwnerEntity",owner); //Set the owner of the explosion

	int mag = 90;
	int rad = 280;
	SetEntProp(ent, Prop_Data, "m_iMagnitude",mag); 
	if( rad != 0 ) 
	{
		SetEntProp(ent, Prop_Data, "m_iRadiusOverride",rad); 
	}

	DispatchSpawn(ent);
	ActivateEntity(ent);

	decl String:exp_sample[64];

	Format( exp_sample, 64, "weapons/hegrenade/explode%d.wav", GetRandomInt( 3, 5 ) );

	if( explosion_sound_enable ) {
		explosion_sound_enable = false;
		EmitAmbientSound( exp_sample, vec, _, SNDLEVEL_GUNFIRE  );
		CreateTimer( 0.1, EnableExplosionSound );
	} 

	TeleportEntity(ent, vec, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(ent, "explode");
	AcceptEntityInput(ent, "kill");
}

public RocketBreak (const String:output[], caller, activator, Float:delay)
{ 
	new Float:pos[3];
	GetEntPropVector(caller, Prop_Send, "m_vecOrigin", pos);

	// create explosion
	CreateRocketExplosionDelayed( pos, GetEntPropEnt( caller, Prop_Data, "m_hOwnerEntity" ) );

}

public CreateRocketExplosionDelayed( Float:vec[3], owner ) 
{

	new Handle:data;
	CreateDataTimer( 0.1, CreateRocketExplosionDelayedTimer, data );
	
	WritePackCell(data,owner);
	WritePackFloat(data,vec[0]);
	WritePackFloat(data,vec[1]);
	WritePackFloat(data,vec[2]);

}

public Action CreateRocketExplosionDelayedTimer( Handle:timer, Handle:data ) 
{

	ResetPack(data);
	new owner = ReadPackCell(data);

	new Float:vec[3];
	vec[0] = ReadPackFloat(data);
	vec[1] = ReadPackFloat(data);
	vec[2] = ReadPackFloat(data);

	CreateRocketExplosion( vec, owner );
	
	return Plugin_Handled;
}
*/

//The above code does not work so i had to borrow from https://forums.alliedmods.net/showthread.php?t=284699

public Action:RocketStart(client)
{
	new ent = CreateEntityByName("hegrenade_projectile");
	if(ent == -1)
		return;
	new Float:OwnerAng[3];
	new Float:OwnerPos[3];
	new Float:InitialPos[3];
	new Float:InitialVec[3];
	new Float:InitialAng[3];
	SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", client);
	SetEntPropFloat(ent, Prop_Send, "m_flModelScale", 0.4);
	GetClientEyeAngles(client, OwnerAng);
	GetClientEyePosition(client, OwnerPos);	
	TR_TraceRayFilter(OwnerPos, OwnerAng, MASK_SOLID, RayType_Infinite, FireEnt, ent);
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
	SetEntityModel(ent, ROCKET_MODEL);
	SetEntityMoveType(ent, MOVETYPE_FLY);
	
	TeleportEntity(ent, OwnerPos, InitialAng, InitialVec);
	SDKHook(ent, SDKHook_StartTouchPost, RocketTouch);
}
public Action:RocketTouch(ent, other)
{
	if(GetEntProp(other, Prop_Data, "m_nSolidType") && !(GetEntProp(other, Prop_Data, "m_usSolidFlags") & 0x0004))
	{
		new MissileOwner = GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity");
		if(IsClientInGame(MissileOwner))
		{
			new Float:MissilePos[3];
			new MissileOwnerTeam = GetEntProp(MissileOwner, Prop_Send, "m_iTeamNum");
			new ExplosionIndex = CreateEntityByName("env_explosion");
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", MissilePos);
			SetEntProp(ent, Prop_Send, "m_iTeamNum", MissileOwnerTeam);
			DispatchKeyValue(ExplosionIndex,"classname","hegrenade_projectile");
			SetEntProp(ExplosionIndex, Prop_Data, "m_spawnflags", 6146);
			SetEntProp(ExplosionIndex, Prop_Data, "m_iMagnitude", 240);
			SetEntProp(ExplosionIndex, Prop_Data, "m_iRadiusOverride", 200);
			DispatchSpawn(ExplosionIndex);
			ActivateEntity(ExplosionIndex);
			TeleportEntity(ExplosionIndex, MissilePos, NULL_VECTOR, NULL_VECTOR);
			SetEntPropEnt(ExplosionIndex, Prop_Send, "m_hOwnerEntity", MissileOwner);
			SetEntProp(ExplosionIndex, Prop_Send, "m_iTeamNum", MissileOwnerTeam);
			EmitSoundToAll("weapons/hegrenade/explode5.wav", ExplosionIndex, 1, 90);
			AcceptEntityInput(ExplosionIndex, "Explode");
			DispatchKeyValue(ExplosionIndex,"classname","env_explosion");
			AcceptEntityInput(ExplosionIndex, "Kill");
			AcceptEntityInput(ent, "Kill");
		}
		else
			AcceptEntityInput(ent, "Kill");
	}
}
public bool:FireEnt(ent, contentsMask, any:data)
{
	return false;
}

public Action:GrenadeStart(client)
{
	new ent = CreateEntityByName("hegrenade_projectile");
	if(ent == -1)
		return;
	new Float:OwnerAng[3];
	new Float:OwnerPos[3];
	new Float:InitialPos[3];
	new Float:InitialVec[3];
	new Float:InitialAng[3];
	SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", client);
	SetEntPropFloat(ent, Prop_Send, "m_flModelScale", 0.4);
	GetClientEyeAngles(client, OwnerAng);
	GetClientEyePosition(client, OwnerPos);	
	TR_TraceRayFilter(OwnerPos, OwnerAng, MASK_SOLID, RayType_Infinite, FireEnt, ent);
	TR_GetEndPosition(InitialPos);
	MakeVectorFromPoints(OwnerPos, InitialPos, InitialVec);
	NormalizeVector(InitialVec, InitialVec);
	ScaleVector(InitialVec, 800.0);
	GetVectorAngles(InitialVec, InitialAng);
	InitialAng[1] -= 90;
	
	char angleskv[16];
	Format(angleskv, 16, "%s %s %s", InitialAng[0], InitialAng[1], InitialAng[2]);
	DispatchKeyValue(ent, "angles", angleskv);
	DispatchSpawn(ent);
	ActivateEntity(ent);
	SetEntityModel(ent, ROCKET_MODEL);
	SetEntityMoveType(ent, MOVETYPE_FLYGRAVITY);
	
	TeleportEntity(ent, OwnerPos, NULL_VECTOR, InitialVec);
	SDKHook(ent, SDKHook_StartTouchPost, RocketTouch);
}
public Action:GrenadeTouch(ent, other)
{
	if(GetEntProp(other, Prop_Data, "m_nSolidType") && !(GetEntProp(other, Prop_Data, "m_usSolidFlags") & 0x0004))
	{
		new MissileOwner = GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity");
		if(IsClientInGame(MissileOwner))
		{
			new Float:MissilePos[3];
			new MissileOwnerTeam = GetEntProp(MissileOwner, Prop_Send, "m_iTeamNum");
			new ExplosionIndex = CreateEntityByName("env_explosion");
			GetEntPropVector(ent, Prop_Send, "m_vecOrigin", MissilePos);
			SetEntProp(ent, Prop_Send, "m_iTeamNum", MissileOwnerTeam);
			DispatchKeyValue(ExplosionIndex,"classname","hegrenade_projectile");
			SetEntProp(ExplosionIndex, Prop_Data, "m_spawnflags", 6146);
			SetEntProp(ExplosionIndex, Prop_Data, "m_iMagnitude", 240);
			SetEntProp(ExplosionIndex, Prop_Data, "m_iRadiusOverride", 200);
			DispatchSpawn(ExplosionIndex);
			ActivateEntity(ExplosionIndex);
			TeleportEntity(ExplosionIndex, MissilePos, NULL_VECTOR, NULL_VECTOR);
			SetEntPropEnt(ExplosionIndex, Prop_Send, "m_hOwnerEntity", MissileOwner);
			SetEntProp(ExplosionIndex, Prop_Send, "m_iTeamNum", MissileOwnerTeam);
			EmitSoundToAll("weapons/hegrenade/explode5.wav", ExplosionIndex, 1, 90);
			AcceptEntityInput(ExplosionIndex, "Explode");
			DispatchKeyValue(ExplosionIndex,"classname","env_explosion");
			AcceptEntityInput(ExplosionIndex, "Kill");
			AcceptEntityInput(ent, "Kill");
		}
		else
			AcceptEntityInput(ent, "Kill");
	}
}