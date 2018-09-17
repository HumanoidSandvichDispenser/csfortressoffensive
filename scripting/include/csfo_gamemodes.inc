/*
**
*/
#if defined _csfo_gamemodes_included
 #endinput
#endif
#define _csfo_gamemodes_included

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <smlib>
#include <colors>

public void UpdateGamemode(ConVar convar, char[] oldValue, char[] newValue)
{
	ConVar ignorewinconditions = FindConVar("mp_ignore_round_win_conditions");
	ConVar time_defuse = FindConVar("mp_roundtime_defuse");
	ConVar time_hostage = FindConVar("mp_roundtime_hostage");
	ConVar time_generic = FindConVar("mp_roundtime");
	
	ConVar halftime = FindConVar("mp_halftime");
	ConVar maxrounds = FindConVar("mp_maxrounds");
	ConVar UseRespawnWaves = FindConVar("mp_use_respawn_waves");
	ConVar TRespawnWaveTime = FindConVar("mp_respawnwavetime_t");
	ConVar CTRespawnWaveTime = FindConVar("mp_respawnwavetime_ct");
	
	halftime.BoolValue = true;
	maxrounds.IntValue = 1;
	UseRespawnWaves.BoolValue = true;
	TRespawnWaveTime.FloatValue = 10.0;
	CTRespawnWaveTime.FloatValue = 10.0;
	
	int gamemode = StringToInt(newValue);
	switch(gamemode)
	{
		case 0:
		{
			ignorewinconditions.BoolValue = true;
			time_defuse.FloatValue = 0.0;
			time_hostage.FloatValue = 0.0;
			time_generic.FloatValue = 60.0;
		}
		case 1:
		{
			ignorewinconditions.BoolValue = true;
			time_defuse.FloatValue = 0.0;
			time_hostage.FloatValue = 0.0;
			time_generic.FloatValue = 60.0;
		}
		case 2:
		{
			ignorewinconditions.BoolValue = false;
			time_defuse.FloatValue = 4.5;
			time_hostage.FloatValue = 0.0;
			time_generic.FloatValue = 0.0;
			maxrounds.IntValue = 3;
		}
		case 5:
		{
			maxrounds.IntValue = 4;
			ignorewinconditions.BoolValue = false;
			UseRespawnWaves.BoolValue = false;
			time_defuse.FloatValue = 0.0;
			time_hostage.FloatValue = 0.0;
			time_generic.FloatValue = 8.0;
		}
	}
}

public Action AddPoints(int team, int points, ConVar GMConVar)
{
	if (GMConVar.IntValue != 1) return Plugin_Handled;
	
	SetTeamScore(team, GetTeamScore(team) + points);
	//char teamname[32];
	//GetTeamName(team, teamname, 32);
	//PrintToChatAll("%s %d %d", teamname, GetTeamScore(team), points);
	
	UpdatePoints(GMConVar);
	
	return Plugin_Continue;
}

public Action UpdatePoints(ConVar GMConVar)
{
	if (GMConVar.IntValue == 1)
	{
		if (GetTeamScore(CS_TEAM_CT) >= 55)
		{
			CS_TerminateRound(10.0, CSRoundEnd_CTWin);
			Game_End();
		}
		
		if (GetTeamScore(CS_TEAM_T) >= 55)
		{
			CS_TerminateRound(10.0, CSRoundEnd_TerroristWin);
			Game_End();
		}
	}
	
	return Plugin_Continue;
}

public Action ShowGamemodeMessage(ConVar GMConVar)
{
	if (GMConVar.IntValue == 1)
	{
		PrintToChatAll("\x05Deathmatch: \x07First team to 55 points win. Even in this gamemode, teamwork is essential to victory.");
	}
	if (GMConVar.IntValue == 2)
	{
		for (int i = 1; i < MAXPLAYERS; i++)
		{
			if (!IsClientInGame(i)) continue;
			if (GetClientTeam(i) == CS_TEAM_CT)
			{
				PrintToChat(i, "\x05CS Payload - BLU TEAM (Defending): \x07Prevent the bomb from being planted.");
			}
			if (GetClientTeam(i) == CS_TEAM_T)
			{
				PrintToChat(i, "\x05CS Payload - RED TEAM (Attacking): \x077Plant the bomb at the bombsite.");
			}
		}
	}
	if (GMConVar.IntValue == 5)
	{
		PrintToChatAll("\x05Saxton Hale: \x07Kill Saxton Hale. Kill Everyone as Saxton Hale.");
	}
	
	return Plugin_Continue;
}

public Action BombPlanted(Handle event, const String:name[], bool dontBroadcast)
{
	CS_TerminateRound(10.0, CSRoundEnd_TerroristsPlanted);
	SetTeamScore(CS_TEAM_T, GetTeamScore(CS_TEAM_T) + 1);
	return Plugin_Continue;
}

int GetRandomPlayer(team) 
{ 

    int clients[MAXPLAYERS + 1], clientCount;
    for (new i = 1; i <= MaxClients; i++) 
        if (IsClientInGame(i) && (GetClientTeam(i) == team)) 
            clients[clientCount++] = i;
    return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount-1)]; 
}