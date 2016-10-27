#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
//#include <smlib>

int bot_id = -1;
new players_arr[MAXPLAYERS];
new numPlayers = 0;
enum Frame
{
	playerButtons = 0,
	Float:position[3],
	Float:angle[3]
}

public Plugin myinfo =
{
	name = "STV Playback",
	author = "Mike",
	description = "play back your stvs server side",
	version = "1.0",
	url = "mikeadkison.net"
};

public void OnPluginStart()
{
	PrintToServer("Starting stv playback plugin");
	ServerCommand("sv_cheats 1; bot -name %s -team %s -class %s; sv_cheats 0", "testbot", "blue", "pyro");
}

public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client))
	{
		bot_id = client;
		PrintToChatAll("bot id %d recorded", bot_id);
		int bot_user_id = GetClientUserId(bot_id);
		PrintToChatAll("bot user id: %d", bot_user_id);
	}
	SDKHook(client, SDKHook_PreThink, Hook_Shoot);
}


public void OnGameFrame()
{
	// get all the currently connected clients
	int maxplayers = GetMaxClients();
	numPlayers = 0;
	for (int j = 1; j < maxplayers + 1; j++)
	{
		if (IsClientInGame(j) && !IsFakeClient(j))
		{
			players_arr[numPlayers] = j;
			numPlayers++;
		}
	}

	// save all their positions
	for (new i = 0; i < numPlayers; i++)
	{
		int client_id = players_arr[i];
		new Float:absOrigin[3];
		GetClientAbsOrigin(client_id, absOrigin);
		new Float:absAngle[3];
		GetClientAbsAngles(client_id, absAngle);
		PrintToChatAll("userid: %d pos: x: %f y: %f z: %f", GetClientUserId(client_id), absOrigin[0], absOrigin[1], absOrigin[2]);
		PrintToChatAll("userid: %d angle: x: %f, y: %f, z: %f", GetClientUserId(client_id), absAngle[0], absAngle[1], absAngle[2]);
	}
} 

public void Hook_Shoot(int client) 
{
	//SetEntProp(bot_id, Prop_Data, "m_nButtons", IN_ATTACK);
}
