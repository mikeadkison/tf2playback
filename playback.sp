#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>

int bot_id = -1;
new players_arr[MAXPLAYERS];
new numPlayers = 0;
new Handle:hedgeFile;
new Handle:playerFrameArr;
bool recording = false;
enum Frame
{
	playerButtons = 0,
	Float:position[3],
	Float:angle[3]
};

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
	if (recording)
	{
		hedgeFile = OpenFile("test.hedge", "wb");
	}
	else {
		hedgeFile = OpenFile("test.hedge", "rb");
	}
	playerFrameArr = CreateArray(_:Frame);
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
	if (recording)
	{
		// get all the currently connected clients
		int maxplayers = GetMaxClients();
		numPlayers = 0;
		for (int j = 1; j < maxplayers + 1; j++)
		{
			if (IsClientInGame(j) && !IsFakeClient(j) && IsPlayerAlive(j))
			{
				players_arr[numPlayers] = j;
				numPlayers++;
			}
		}

		// save all their positions
		for (new i = 0; i < numPlayers; i++)
		{
			new frameArr[Frame]; // an array big enough to hold the Frame struct
			int client_id = players_arr[i];
			new Float:threeVector[3];
			GetClientAbsOrigin(client_id, threeVector);
			Array_Copy(threeVector, frameArr[position], 3);
			GetClientEyeAngles(client_id, threeVector);
			Array_Copy(threeVector, frameArr[angle], 3);
			PrintToChatAll("userid: %d pos: x: %f y: %f z: %f", GetClientUserId(client_id), frameArr[position][0], frameArr[position][1], frameArr[position][2]);
			PrintToChatAll("userid: %d angle: x: %f, y: %f, z: %f", GetClientUserId(client_id), frameArr[angle][0], frameArr[angle][1], frameArr[angle][2]);
			PrintToChatAll("size of struct: %d", _:Frame);
			WriteFile(hedgeFile, frameArr[0], _:Frame, 4);
		}
	}
	else //playback
	{
		new frameArr[Frame];
		if (ReadFile(hedgeFile, frameArr[0], _:Frame, 4))
		{

			new Float:posRecord[3];
			Array_Copy(frameArr[position], posRecord, 3);
			new Float:angRecord[3];
			Array_Copy(frameArr[angle], angRecord, 3);
			PrintToChatAll("userid: %d pos: x: %f y: %f z: %f", GetClientUserId(bot_id), frameArr[position][0], frameArr[position][1], frameArr[position][2]);
			TeleportEntity(bot_id, posRecord, angRecord, NULL_VECTOR);
		}	
	}
} 

public void Hook_Shoot(int client) 
{
	//SetEntProp(bot_id, Prop_Data, "m_nButtons", IN_ATTACK);
}
