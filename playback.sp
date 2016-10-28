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
new Handle:botUserIds; //the user ids of the bots representing the original players. The indices match up between these 2 dynamic arrays
new Handle:playbackUsersNeedingBots; //playback users who are waiting on bots to represent them

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
}

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
	PrintToServer("Starting stv playback plugin");
	playbackUserIds = new ArrayList(4, 0);
	botUserIds = new ArrayList(4, 0);
	playbackUsersNeedingBots = new ArrayList(4, 0);
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
		PushArrayCell(botUserIds, botId); //store thhis bot id and also associate it with the player of the same index in playbackUserIds
		PrintToChatAll("bot id %d recorded", botId);
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
			//describe the upcoming frame
			new frameInfoArr[NextFrameInfo];
			frameInfoArr[nextFrame] = currFrame;
			frameInfoArr[frameType] = PLAYER_INFO;
			WriteFile(hedgeFile, frameInfoArr[0], _:NextFrameInfo, 4);

			//write the next frame
			new frameArr[Frame]; // an array big enough to hold the Frame struct
			int client_id = players_arr[i];
			new Float:threeVector[3];
			GetClientAbsOrigin(client_id, threeVector);
			Array_Copy(threeVector, frameArr[position], 3);
			GetClientEyeAngles(client_id, threeVector);
			Array_Copy(threeVector, frameArr[angle], 3);
			frameArr[userId] = GetClientUserId(client_id);
			ShowActivity(0, "recorded userid: %d", frameArr[userId]);	
			ShowActivity(0, "userid: %d pos: x: %f y: %f z: %f",
				GetClientUserId(client_id), frameArr[position][0], frameArr[position][1], frameArr[position][2]);
			ShowActivity(0, "userid: %d angle: x: %f, y: %f, z: %f",
				GetClientUserId(client_id), frameArr[angle][0], frameArr[angle][1], frameArr[angle][2]);
			ShowActivity(0, "size of struct: %d", _:Frame);
			WriteFile(hedgeFile, frameArr[0], _:Frame, 4);
		}
	}
	else //playback
	{
		new frameArr[Frame];
		new frameInfoArr[NextFrameInfo];
		new nextFrameRecord;
		new nextFrameTypeRecord;

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
					new botId = GetArrayCell(botUserIds, userIdRecordIndex);
					new Float:posRecord[3];
					Array_Copy(frameArr[position], posRecord, 3);
					new Float:angRecord[3];
					Array_Copy(frameArr[angle], angRecord, 3);
					/*PrintToChatAll("botId: %d pos: x: %f y: %f z: %f", 
						botId, frameArr[position][0],
						frameArr[position][1], frameArr[position][2]);*/
					TeleportEntity(botId, posRecord, angRecord, NULL_VECTOR);
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

public void Hook_Shoot(int client) 
{
	//SetEntProp(bot_id, Prop_Data, "m_nButtons", IN_ATTACK);
}

public void SpawnBotFor(int userIdRecord)
{
	PrintToChatAll("spawnbotfor called %d", userIdRecord);
	ServerCommand("sv_cheats 1; bot -name %s -team %s -class %s; sv_cheats 0", "testbot", "blue", "pyro");
	PushArrayCell(playbackUserIds, userIdRecord); //put this useridrecord and its associated bot id (of the bot acting it for this useridrecord) at the same indices in their respective arrays.
	PushArrayCell(playbackUsersNeedingBots, userIdRecord);
	numPlaybackBots++;
}
