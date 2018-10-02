/*
**
*/
#if defined _csfo_tools_included
 #endinput
#endif
#define _csfo_tools_included

#include <kvizzle>

static char KVPath[PLATFORM_MAX_PATH];

public void ToolsInit()
{
	CreateDirectory("addons/sourcemod/data/csfortress2/", 3);
	BuildPath(Path_SM, KVPath, PLATFORM_MAX_PATH, "data/csfortress2/mapinfo.txt");
}

public Action Command_placeitemspawn(int client, int args)
{
	if (args == 1)
	{
		float vec[3];
		GetClientAbsOrigin(client, vec);
		
		char type[4];
		GetCmdArg(1, type, sizeof(type));
		
		int type_int = StringToInt(type);
		
		CreateHealthAmmoPackSpawn(client, vec, type_int);
		return Plugin_Continue;
	}
	
	if (args < 4)
	{
		ReplyToCommand(client, "[SM] Usage: sm_placeitemspawn <x> <y> <z> <type(0-5)>");
		ReplyToCommand(client, "[SM] or sm_placeitemspawn <type(0-5)>");
		return Plugin_Handled;
	}
	
	char x[64];
	GetCmdArg(1, x, sizeof(x));
	
	char y[64];
	GetCmdArg(2, y, sizeof(y));
	
	char z[64];
	GetCmdArg(3, z, sizeof(z));
	
	char type[4];
	GetCmdArg(4, type, sizeof(type));
	
	float vec[3];
	vec[0] = StringToFloat(x),
		vec[1] = StringToFloat(y),
		vec[2] = StringToFloat(z);
	
	int type_int = StringToInt(type);
	
	CreateHealthAmmoPackSpawn(client, vec, type_int);
	return Plugin_Continue;
}

/*
** Used to create health/ammo pack spots in the map.
** @param pos			position of the health/ammo pack spawn
** @param type			type of health pack (0-2 for ammo, 3-5 for health)
*/
public Action CreateHealthAmmoPackSpawn(int client, float pos[3], int type) // type: 0-2 ammo, 3-5 health
{
	SaveSpawn(client, pos, type);
}

public Action SaveSpawn(int client, float pos[3], int type)
{
	Handle kv_file = CreateKeyValues("mapinfo");
	if (!FileToKeyValues(kv_file, KVPath)) KeyValuesToFile(kv_file, KVPath);
	CloseHandle(kv_file);
	
	Handle kv = KvizCreateFromFile("mapinfo", KVPath);
	
	char mapname[64];
	GetCurrentMap(mapname, 64);
	
	
	if (KvizJumpToKey(kv, true, mapname))
	{
		for (int i = 0; i < 129; i++)
		{
			if (!KvizExists(kv, "%d", i))
			{
				if (KvizJumpToKey(kv, true, "%d", i))
				{
					KvizSetVector(kv, pos, "vec");
					KvizSetNum(kv, type, "type");
					KvizRewind(kv);
					KvizToFile(kv, KVPath);
					PrintToChat(client, "Created item spawn at %f, %f, %f with type %d", pos[0], pos[1], pos[2], type);
				}
				
				break;
			}
		}
	}

	KvizClose(kv);
}

public Action RemoveSpawn(int index)
{
	Handle kv = KvizCreateFromFile("mapinfo", KVPath);
	
	char mapname[64];
	GetCurrentMap(mapname, 64);
	
	KvizDelete(kv, "%s.%d", mapname, index);
	
	KvizClose(kv);
}

public Action LoadItemSpawns()
{
	Handle kv_file = CreateKeyValues("mapinfo");
	if (!FileToKeyValues(kv_file, KVPath)) KeyValuesToFile(kv_file, KVPath);
	CloseHandle(kv_file);
	
	Handle kv = KvizCreateFromFile("mapinfo", KVPath);
	
	char mapname[64];
	GetCurrentMap(mapname, 64);
	
	
	if (KvizJumpToKey(kv, false, mapname))
	{
		for (int i = 0; i < 129; i++)
		{
			if (KvizExists(kv, "%d", i))
			{
				if (KvizJumpToKey(kv, false, "%d", i))
				{
					float pos[3];
					KvizGetVector(kv, pos, Float:{0.0, 0.0, 0.0}, "vec");
					int type = KvizGetNum(kv, 0, "type");
					if (type < 3) CreateAmmo(pos, type);
					else if (type > 2) CreateHealth(pos, type);
					KvizGoBack(kv);
				}
			}
		}
	}

	KvizClose(kv);
}

public Action RespawnItem(Handle timer, int entity)
{
	/*
	float vec0, vec1, vec2;
	int type;
	
	ResetPack(h_Pack);
	vec0 = ReadPackFloat(h_Pack);
	vec1 = ReadPackFloat(h_Pack);
	vec2 = ReadPackFloat(h_Pack);
	type = ReadPackCell(h_Pack);
	
	float vec[3];
	vec[0] = vec0;
	vec[1] = vec1;
	vec[2] = vec2;
	*/
	//PrintToChatAll("%f %f %f %d", vec[0], vec[1], vec[2], type);
	
	SetEntityRenderColor(entity);
	SetEntityRenderMode(entity, RENDER_NORMAL);
	Entity_SetCollisionGroup(entity, COLLISION_GROUP_INTERACTIVE);
	
	return Plugin_Continue;
}

public Action RespawnAmmo(Handle timer, any vec[3])
{
	CreateAmmo(vec, 2);
}

public Action RespawnHealth(Handle timer, any vec[3])
{
	CreateHealth(vec, 5);
}

public Action CreateAmmo(float pos[3], int type)
{
	int ammobox = CreateEntityByName("prop_physics_override");
	char type_str[2];
	IntToString(type, type_str, 2);
	DispatchKeyValue(ammobox, "skin", type_str);
	Entity_SetName(ammobox, "item_ammo"); // name this entity so it can be referred to outside of this scope.
	Entity_SetModel(ammobox, "models/props/coop_cementplant/coop_ammo_stash/coop_ammo_stash_full.mdl");
	Entity_SetCollisionGroup(ammobox, COLLISION_GROUP_INTERACTIVE);
	if (DispatchSpawn(ammobox))
	{
		int Rotator = CreateEntityByName("func_rotating");
		DispatchKeyValue(Rotator, "targetname", "item_drop_rotator");
		DispatchKeyValue(Rotator, "maxspeed", "75");
		DispatchKeyValue(Rotator, "friction", "0");
		DispatchKeyValue(Rotator, "dmg", "0");
		DispatchKeyValue(Rotator, "solid", "0");
		DispatchKeyValue(Rotator, "spawnflags", "64");
		DispatchSpawn(Rotator);
		
		Entity_SetMinMaxSize(Rotator, Float:{-8.0, -8.0, -8.0}, Float:{8.0, 8.0, 8.0});
		
		SetVariantString("!activator");
		AcceptEntityInput(Rotator, "Start");
		
		SetEntPropEnt(ammobox, Prop_Send, "m_hEffectEntity", Rotator);
		
		Entity_SetParent(ammobox, Rotator);
		
		Entity_SetAbsOrigin(Rotator, pos);
		//Entity_SetAbsOrigin(ammobox, pos);
	}
}

public Action CreateHealth(float pos[3], int type)
{
	int healthpack = CreateEntityByName("prop_physics_override");
	char type_str[2];
	IntToString(type, type_str, 2);
	DispatchKeyValue(healthpack, "skin", type_str); // models don't have any other skins, so this will be used as a 
	Entity_SetName(healthpack, "item_health"); // name this entity so it can be referred to outside of this scope.
	Entity_SetModel(healthpack, "models/props/de_inferno/hr_i/inferno_wine_crate/inferno_wine_crate_01.mdl");
	Entity_SetCollisionGroup(healthpack, COLLISION_GROUP_INTERACTIVE);
	if (DispatchSpawn(healthpack))
	{
		int Rotator = CreateEntityByName("func_rotating");
		DispatchKeyValue(Rotator, "targetname", "item_drop_rotator");
		DispatchKeyValue(Rotator, "maxspeed", "75");
		DispatchKeyValue(Rotator, "friction", "0");
		DispatchKeyValue(Rotator, "dmg", "0");
		DispatchKeyValue(Rotator, "solid", "0");
		DispatchKeyValue(Rotator, "spawnflags", "64");
		DispatchSpawn(Rotator);
		
		Entity_SetMinMaxSize(Rotator, Float:{-8.0, -8.0, -8.0}, Float:{8.0, 8.0, 8.0});
		
		SetVariantString("!activator");
		AcceptEntityInput(Rotator, "Start");
		
		SetEntPropEnt(healthpack, Prop_Send, "m_hEffectEntity", Rotator);
		
		Entity_SetParent(healthpack, Rotator);
		
		Entity_SetAbsOrigin(Rotator, pos);
		//Entity_SetAbsOrigin(healthpack, pos);
	}
}