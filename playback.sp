#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>

new players_arr[MAXPLAYERS + 1];
new numPlayers = 0;
new Handle:hedgeFile;
bool recording = false;
new numPlaybackBots = 0;
int currFrame = 0;
new Handle:playbackUserIds; //the user ids of the players who originally played the game
new Handle:botClientIds; //the user ids of the bots representing the original players. The indices match up between these 2 dynamic arrays
new Handle:playbackUsersNeedingBots; //playback users who are waiting on bots to represent them
new Handle:botClientsInitiallyTeleported; //have the bots corresponding to these indices been teleported to their start location yet?
new Handle:botsButtons; //if the bots for these corresponding indices should jump
new Handle:botVels;
new Handle:botAngs;
new Handle:botPosits;
new Handle:botPredVels;



//frame types
#define PLAYER_INFO 0 // frame with position and angle info

enum NextFrameInfo
{
	frameType = 0,
	nextFrame 
}

enum Frame
{
	userId = 0,
	playerButtons,
	Float:position[3],
	Float:angle[3],
	Float:velocity[3],
	Float:predictedVelocity[3],
}

//playback and recording vars
new Float:posRecord[3];
new Float:angRecord[3];
new Float:velRecord[3];
new Float:predVelRecord[3]; //record of predicted velocity

new frameArr[Frame];
new frameInfoArr[NextFrameInfo];
new nextFrameRecord;
new nextFrameTypeRecord;

new Float:currBotOrigin[3];

public Plugin myinfo =
{
	name = "Playback",
	author = "Mike",
	description = "play back your games server side with bots",
	version = "1.0",
	url = "mikeadkison.net"
};

public void OnPluginStart()
{
	PrintToServer("Starting playback plugin");
	// kick all the existing bots
	// get all the currently connected clients
	int maxplayers = GetMaxClients();
	numPlayers = 0;

	//kick old bots
	for (int j = 1; j < maxplayers + 1; j++)
	{
		if (IsClientInGame(j) && IsFakeClient(j))
		{
			KickClient(j);
		}
	}

	playbackUserIds = new ArrayList(4, 0);
	botClientIds = new ArrayList(4, 0);
	playbackUsersNeedingBots = new ArrayList(4, 0);
	botClientsInitiallyTeleported = new ArrayList(4, 0);
	botsButtons = new ArrayList(4, 0);
	botVels = new ArrayList(3, 0);
	botAngs = new ArrayList(3, 0);
	botPosits = new ArrayList(3, 0);
	botPredVels = new ArrayList(3, 0);
	if (recording)
	{
		hedgeFile = OpenFile("test.hedge", "wb");
	}
	else {
		hedgeFile = OpenFile("test.hedge", "rb");
	}
}

// capture bot ids so we know which bot is representing what player!
public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client)) //if a userid still needs a bot paired with it for replay
	{
		new userIdRequiringABot = GetArrayCell(playbackUsersNeedingBots, 0);
		RemoveFromArray(playbackUsersNeedingBots, 0);
		PrintToChatAll("clieint in server %d %d", userIdRequiringABot, IsFakeClient(client));
		new botId = client;
		PushArrayCell(botClientIds, botId); //store thhis bot id and also associate it with the player of the same index in playbackUserIds
		PushArrayCell(botsButtons, 0);
		new Float:threeVector0[3];
		PushArrayArray(botVels, Float:threeVector0);
		new Float:threeVector1[3];
		PushArrayArray(botAngs, Float:threeVector1);
		new Float:threeVector2[3];
		PushArrayArray(botPosits, Float:threeVector2);
		new Float:threeVector3[3];
		PushArrayArray(botPredVels, Float:threeVector3);
		PrintToChatAll("bot id %d recorded", botId);
		SDKHook(client, SDKHook_PostThink, Hook_PostActions);
	}
	//SDKHook(client, SDKHook_PreThink, Hook_Buttons);
}

public void OnGameFrame()
{
	if (recording)
	{
		// // get all the currently connected clients
		// int maxplayers = GetMaxClients();
		// numPlayers = 0;
		// for (int j = 1; j < maxplayers + 1; j++)
		// {
		// 	if (IsClientInGame(j) && !IsFakeClient(j) && IsPlayerAlive(j))
		// 	{
		// 		players_arr[numPlayers] = j;
		// 		numPlayers++;
		// 	}
		// }

		// // save all their positions
		// for (new i = 0; i < numPlayers; i++)
		// {
		// 	//describe the upcoming frame
		// 	new frameInfoArr[NextFrameInfo];
		// 	frameInfoArr[nextFrame] = currFrame;
		// 	frameInfoArr[frameType] = PLAYER_INFO;
		// 	WriteFile(hedgeFile, frameInfoArr[0], _:NextFrameInfo, 4);

		// 	//write the next frame
		// 	new frameArr[Frame]; // an array big enough to hold the Frame struct
		// 	int clientId = players_arr[i];
		// 	new Float:threeVector[3];
		// 	GetClientAbsOrigin(clientId, threeVector);
		// 	Array_Copy(threeVector, frameArr[position], 3);
		// 	GetClientEyeAngles(clientId, threeVector);
		// 	Array_Copy(threeVector, frameArr[angle], 3);
		// 	Entity_GetAbsVelocity(clientId, threeVector);
		// 	Array_Copy(threeVector, frameArr[velocity], 3);
		// 	frameArr[userId] = GetClientUserId(clientId);
		// 	frameArr[playerButtons] = Client_GetButtons(clientId);

		// 	ShowActivity(0, "recorded userid: %d", frameArr[userId]);	
		// 	ShowActivity(0, "userid: %d pos: x: %f y: %f z: %f",
		// 		GetClientUserId(clientId), frameArr[position][0], frameArr[position][1], frameArr[position][2]);
		// 	ShowActivity(0, "userid: %d angle: x: %f, y: %f, z: %f",
		// 		GetClientUserId(clientId), frameArr[angle][0], frameArr[angle][1], frameArr[angle][2]);
		// 	ShowActivity(0, "size of struct: %d", _:Frame);
		// 	WriteFile(hedgeFile, frameArr[0], _:Frame, 4);
		// }
	}
	else //playback
	{


		bool hitNextFrame = false;
		while (!hitNextFrame && ReadFile(hedgeFile, frameInfoArr[0], _:NextFrameInfo, 4))
		{
			//get info of next frame
			nextFrameRecord = frameInfoArr[nextFrame];
			nextFrameTypeRecord = frameInfoArr[frameType];
			if (nextFrameRecord == currFrame)
			{
				//get next frame
				ReadFile(hedgeFile, frameArr[0], _:Frame, 4);
				new userIdRecord = frameArr[userId];
				new userIdRecordIndex = FindValueInArray(playbackUserIds, userIdRecord);
				if (userIdRecordIndex == -1) //if thhis user id has not been encountered before (no bot created for it)
				{
					SpawnBotFor(userIdRecord);
				}
				else //there is already a bot representing this useridrecord ! It will be at the same index in the botid array
				{
					new botId = GetArrayCell(botClientIds, userIdRecordIndex);
					Array_Copy(frameArr[position], posRecord, 3);
					Array_Copy(frameArr[angle], angRecord, 3);
					Array_Copy(frameArr[velocity], velRecord, 3);
					Array_Copy(frameArr[predictedVelocity], predVelRecord, 3);
					//PrintToChatAll("setting buttons:  %d for index %d", frameArr[playerButtons], userIdRecordIndex);
					if (IsPlayerAlive(botId))
					{
						SetArrayCell(botsButtons, userIdRecordIndex, frameArr[playerButtons]);
					}
					/*PrintToChatAll("botId: %d pos: x: %f y: %f z: %f", 
						botId, frameArr[position][0],
						frameArr[position][1], frameArr[position][2]);*/
					//TeleportEntity(botId, posRecord, angRecord, velRecord);	
					if (!GetArrayCell(botClientsInitiallyTeleported, userIdRecordIndex) && IsPlayerAlive(botId))
					{
						Entity_SetAbsOrigin(botId, posRecord);
						SetArrayCell(botClientsInitiallyTeleported, userIdRecordIndex, true);
					}

					new Float:currBotOrigin[3];
					GetClientAbsOrigin(botId, currBotOrigin);
					//PrintToChatAll("ongameframe %d pos %f %f", currFrame, currBotOrigin[0], currBotOrigin[1]);
					float maxDiff = 10.0;
					// if (Entity_GetDistanceOrigin(botId, posRecord) > maxDiff)
					// {
					// 		PrintToChatAll("desync by %f: teleporting curr: %f record: %f",
					// 			Entity_GetDistanceOrigin(botId, posRecord), currBotOrigin[0], posRecord[0]);
					// 		TeleportEntity(botId, posRecord, NULL_VECTOR, NULL_VECTOR);
					// }
					SetArrayArray(botVels, userIdRecordIndex, velRecord);
					SetArrayArray(botAngs, userIdRecordIndex, angRecord);
					SetArrayArray(botPosits, userIdRecordIndex, posRecord);
					SetArrayArray(botPredVels, userIdRecordIndex, predVelRecord);
					// Entity_SetAbsVelocity(botId, velRecord);
					// Entity_SetAbsAngles(botId, angRecord);

					//TeleportEntity(botId, NULL_VECTOR, NULL_VECTOR, velRecord);
				}
			}
			else //hit the next frame, so stop reading for now and put the file pointer back at the beginning of the nextframeinfo
			{
				hitNextFrame = true;
				FileSeek(hedgeFile, -_:NextFrameInfo * 4, SEEK_CUR);
			}
		}
	}
	currFrame++;
} 

public void Hook_PostActions(int client) 
{
	FindValueInArray(botClientIds, client);
	//Client_AddButtons(client, IN_JUMP);
	//SetEntProp(client, Prop_Data, "m_nButtons", IN_JUMP);
}


public Action:OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	
	// //Entity_AddFlags(client, FL_DUCKING);
	// if (buttons & IN_JUMP)
	// {
	// 	//PrintToChatAll("jumping");
	// 	//Entity_AddFlags(client, FL_DUCKING);
	// }
	// else
	// {
	// 	//PrintToChatAll("not jumping");
	// 	//Entity_RemoveFlags(client, FL_DUCKING);
	// }
	// //Entity_AddFlags(client, FL_DUCKING);
	// if (GetClientUserId(client) == 3)
	// {
	// 	//PrintToChatAll("runcmd");
	// }
	if (recording)
	{
		//describe the upcoming frame
		frameInfoArr[nextFrame] = currFrame - 1; //currframe is incremented in ongameframe but it's not actually the next frame yet because onplayercmd is called after ongameframe
		frameInfoArr[frameType] = PLAYER_INFO;
		WriteFile(hedgeFile, frameInfoArr[0], _:NextFrameInfo, 4);

		//write the next frame
		int clientId = client;
		new Float:threeVector[3];
		GetClientAbsOrigin(clientId, threeVector);
		Array_Copy(threeVector, frameArr[position], 3);
		GetClientEyeAngles(clientId, threeVector);
		Array_Copy(threeVector, frameArr[angle], 3);
		Entity_GetAbsVelocity(clientId, threeVector);
		Array_Copy(threeVector, frameArr[velocity], 3);
		Array_Copy(vel, frameArr[predictedVelocity], 3);
		frameArr[userId] = GetClientUserId(clientId);
		frameArr[playerButtons] = Client_GetButtons(clientId);

		ShowActivity(0, "recorded userid: %d", frameArr[userId]);	
		ShowActivity(0, "userid: %d pos: x: %f y: %f z: %f",
			GetClientUserId(clientId), frameArr[position][0], frameArr[position][1], frameArr[position][2]);
		ShowActivity(0, "userid: %d angle: x: %f, y: %f, z: %f",
			GetClientUserId(clientId), frameArr[angle][0], frameArr[angle][1], frameArr[angle][2]);
		ShowActivity(0, "userid: %d vel: x: %f, y: %f, z: %f",
			GetClientUserId(clientId), frameArr[velocity][0], frameArr[velocity][1], frameArr[velocity][2]);
		ShowActivity(0, "size of struct: %d", _:Frame);
		WriteFile(hedgeFile, frameArr[0], _:Frame, 4);
	}
	else if (!recording && IsFakeClient(client))
	{
		GetClientAbsOrigin(client, currBotOrigin);

		//PrintToChatAll("onplayerruncmd frame %d client %d pos %f %f vel %f %f", currFrame, client, threeVector[0], threeVector[1], vel[0], vel[1]);
		


		new botIndex = FindValueInArray(botClientIds, client);
		GetArrayArray(botVels, botIndex, velRecord);
		GetArrayArray(botAngs, botIndex, angRecord);
		GetArrayArray(botPosits, botIndex, posRecord);
		GetArrayArray(botPredVels, botIndex, predVelRecord);

		vel = predVelRecord;

		float maxDiff = 10.0;
		if (Entity_GetDistanceOrigin(client, posRecord) > maxDiff)
		{
				PrintToChatAll("desync on %d by %f: teleporting curr: %f record: %f vel %f", currFrame,
					Entity_GetDistanceOrigin(client, posRecord), currBotOrigin[0], posRecord[0], velRecord[0]);
				TeleportEntity(client, posRecord, NULL_VECTOR, NULL_VECTOR);
		}

		Entity_SetAbsVelocity(client, velRecord);
		//PrintToChatAll("client %d abs vel %f %f", client, velRecord[0], velRecord[1]);
		Entity_SetAbsAngles(client, angRecord);
		new botButtons = GetArrayCell(botsButtons, botIndex);
		buttons = botButtons;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public void SpawnBotFor(int userIdRecord)
{
	PrintToChatAll("spawnbotfor called %d", userIdRecord);
	ServerCommand("sv_cheats 1; bot -name %s -team %s -class %s; sv_cheats 0", "testbot", "blue", "soldier");
	PushArrayCell(playbackUserIds, userIdRecord); //put this useridrecord and its associated bot id (of the bot acting it for this useridrecord) at the same indices in their respective arrays.
	PushArrayCell(playbackUsersNeedingBots, userIdRecord);
	PushArrayCell(botClientsInitiallyTeleported, false);
	numPlaybackBots++;
}
