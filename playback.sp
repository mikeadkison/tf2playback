#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>
#include <tf2_stocks>
#include <tf2items_giveweapon>

//new players_arr[MAXPLAYERS + 1];
new numPlayers = 0;
new Handle:hedgeFile;
bool recording = false;
bool playing = false;
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
new Handle:botHealths; //recorded health (rocket jumping does inconsistent damage on replay)



//frame types
#define PLAYER_INFO 0 // frame with position and angle info
#define WEAPON_SWITCH 1 // frame with info about a weapon switch

enum NextFrameInfo
{
	frameType = 0,
	nextFrame,
}

enum Frame
{
	userId = 0,
	playerButtons,
	Float:position[3],
	Float:angle[3],
	Float:velocity[3],
	Float:predictedVelocity[3],
	health,
}

enum WeaponSwitch
{
	weaponSwitcherUserId = 0,
	weaponId, //the index of the weapon (https://wiki.alliedmods.net/Team_Fortress_2_Item_Definition_Indexes)
	weaponSlot,
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


new Float:threeVector[3];
new botButtons;
new botIndex;

const BUFF_SIZE = 100;
new frameInfoBuff[BUFF_SIZE][NextFrameInfo]; //buffer recorded nonsparse frames and write them at the same time.
new frameBuff[BUFF_SIZE][Frame];
new frameBuffIndex = 0;

new Handle:weaponSwitchesBuff; // dynamic array of weapon switch events
new Handle:weaponSwitchesFrameInfoBuff; //buffer NextFrameInfos for weapon switches also
new weaponSwitchArr[WeaponSwitch];
//new nextWeaponSwitchArr[WeaponSwitch]; //used to interleave weapon switch events with nonsparse events like movement
///////

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

	KickBots();

	numPlayers = 0;

	playbackUserIds = new ArrayList(1, 0);
	botClientIds = new ArrayList(1, 0);
	playbackUsersNeedingBots = new ArrayList(1, 0);
	botClientsInitiallyTeleported = new ArrayList(1, 0);
	botsButtons = new ArrayList(1, 0);
	botVels = new ArrayList(3, 0);
	botAngs = new ArrayList(3, 0);
	botPosits = new ArrayList(3, 0);
	botPredVels = new ArrayList(3, 0);
	botHealths = new ArrayList(1, 0);

	weaponSwitchesBuff = new ArrayList(_:WeaponSwitch, 0);
	weaponSwitchesFrameInfoBuff = new ArrayList(_:NextFrameInfo, 0);

	int maxplayers = GetMaxClients();
	for (int client = 1; client < maxplayers + 1; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client))
		{
			SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch); //need this to detect weapon switches when recording
			numPlayers++;
		}
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
		PushArrayCell(botHealths, -1);
		PrintToChatAll("bot id %d recorded", botId);
		//SDKHook(client, SDKHook_PostThink, Hook_PostActions);
	}
	else //need this to detect weapon switches when recording
	{
		SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch);
	}
}

public void OnGameFrame()
{
	if (recording)
	{
		if (frameBuffIndex == 100) //time to write to file!
		{
			//PrintToConsole(FindTarget(0, "Hedgehog Hero"), "saving! %d", nextFrameRecord);

			for (new i = 0; i < BUFF_SIZE; i++)
			{
				WriteFile(hedgeFile, frameInfoBuff[i][0], _:NextFrameInfo, 4);
				WriteFile(hedgeFile, frameBuff[i][0], _:Frame, 4);

				new frameNum = frameInfoBuff[i][nextFrame];
				bool foundAllSparseEventsForFrame = false;
				//PrintToConsole(FindTarget(0, "Hedgehog Hero"), "weaponswitchesbuff size %d", GetArraySize(weaponSwitchesBuff));
				while (GetArraySize(weaponSwitchesBuff) > 0 && !foundAllSparseEventsForFrame)
				{
					GetArrayArray(weaponSwitchesBuff, 0, weaponSwitchArr[0]);
					GetArrayArray(weaponSwitchesFrameInfoBuff, 0, frameInfoArr[0]);
					//PrintToConsole(FindTarget(0, "Hedgehog Hero"), "weaponswitchframe %d currentframe %d", nextWeaponSwitchArr[nextFrame], frameNum);
					if (frameInfoArr[nextFrame] == frameNum) //if this weapon switch event occurs on the same frame as the nonsparse events (angle and velocity updates contained in Frame)
					{
						PrintToConsole(FindTarget(0, "Hedgehog Hero"), "writing weapon switch to wep %d", weaponSwitchArr[weaponId]);
						WriteFile(hedgeFile, frameInfoArr[0], _:NextFrameInfo, 4); //write a description of the upcoming sparse event
						WriteFile(hedgeFile, weaponSwitchArr[0], _:WeaponSwitch, 4); //write the sparse weapon switch event;
						//remove from buffer
						RemoveFromArray(weaponSwitchesBuff, 0);
						RemoveFromArray(weaponSwitchesFrameInfoBuff, 0);
					} else
					{
						foundAllSparseEventsForFrame = true; //done interleaving sparse events for this framez
					}
				}


				FlushFile(hedgeFile);
			}
			frameBuffIndex = 0;
		}
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
	}
	else if (playing)//playback
	{
		//PrintToChatAll("Playing");
		bool hitNextFrame = false;
		//PrintToChatAll("success: %d", success);
		while (!hitNextFrame && ReadFile(hedgeFile, frameInfoArr[0], _:NextFrameInfo, 4))
		{
			//get info of next frame
			nextFrameRecord = frameInfoArr[nextFrame];
			//PrintToConsole(FindTarget(0, "Hedgehog Hero"), "reading frame info! %d", nextFrameRecord);
			nextFrameTypeRecord = frameInfoArr[frameType];
			if (nextFrameRecord == currFrame)
			{
				if (PLAYER_INFO == nextFrameTypeRecord) //nonsparse event - player rotation and location and button info
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

						GetClientAbsOrigin(botId, currBotOrigin);
						//PrintToChatAll("ongameframe %d pos %f %f", currFrame, currBotOrigin[0], currBotOrigin[1]);
						//float maxDiff = 10.0;
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
						SetArrayCell(botHealths, userIdRecordIndex, frameArr[health]);
						// Entity_SetAbsVelocity(botId, velRecord);
						// Entity_SetAbsAngles(botId, angRecord);

						//TeleportEntity(botId, NULL_VECTOR, NULL_VECTOR, velRecord);
					}
				}
				else if (WEAPON_SWITCH == nextFrameTypeRecord) // sparse event -- weapon switch
				{
					PrintToConsole(FindTarget(0, "Hedgehog Hero"), "weapon switch read");
					//get next weapon switch info
					ReadFile(hedgeFile, weaponSwitchArr[0], _:WeaponSwitch, 4);
					PrintToConsole(FindTarget(0, "Hedgehog Hero"), "read file for weapon switch");
					new userIdRecord = weaponSwitchArr[weaponSwitcherUserId];
					PrintToConsole(FindTarget(0, "Hedgehog Hero"), "index of recorded userid %d is %d with wep %s",
						userIdRecord, FindValueInArray(playbackUserIds, userIdRecord), weaponSwitchArr[weaponId]);
					new clientId = GetArrayCell(botClientIds, FindValueInArray(playbackUserIds, userIdRecord));
					PrintToConsole(FindTarget(0, "Hedgehog Hero"), "switched to wep %s on bot %d", weaponSwitchArr[weaponId], GetClientUserId(clientId));

					TF2Items_GiveWeapon(clientId, weaponSwitchArr[weaponId]);
					//force a switch to new weapon
					new weapon = GetPlayerWeaponSlot(clientId, weaponSwitchArr[weaponSlot]);
					SetEntPropEnt(clientId, Prop_Send, "m_hActiveWeapon", weapon); 
					//EquipPlayerWeapon(clientId, weaponIdRecord);
				}
			}
			else //hit the next frame, so stop reading for now and put the file pointer back at the beginning of the nextframeinfo
			{
				hitNextFrame = true;
				FileSeek(hedgeFile, -_:NextFrameInfo * 4, SEEK_CUR);
				//PrintToConsole(FindTarget(0, "Hedgehog Hero"), "seeking backwards %d", currFrame);
			}
		}
		if (IsEndOfFile(hedgeFile))
		{
			playing = false;
			PrintToChatAll("Playback finished.");
		}
	}
	currFrame++;
} 


public Action:OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (recording && !IsFakeClient(client))
	{
		//describe the upcoming frame
		frameInfoArr[nextFrame] = currFrame - 1; //currframe is incremented in ongameframe but it's not actually the next frame yet because onplayercmd is called after ongameframe
		frameInfoArr[frameType] = PLAYER_INFO;
		//WriteFile(hedgeFile, frameInfoArr[0], _:NextFrameInfo, 4);
		//write the next frame
		int clientId = client;
		GetClientAbsOrigin(clientId, threeVector);
		Array_Copy(threeVector, frameArr[position], 3);
		GetClientEyeAngles(clientId, threeVector);
		Array_Copy(threeVector, frameArr[angle], 3);
		Entity_GetAbsVelocity(clientId, threeVector);
		Array_Copy(threeVector, frameArr[velocity], 3);
		Array_Copy(vel, frameArr[predictedVelocity], 3);
		frameArr[userId] = GetClientUserId(clientId);
		frameArr[playerButtons] = Client_GetButtons(clientId);
		frameArr[health] = GetClientHealth(client);

		// ShowActivity(0, "recorded userid: %d", frameArr[userId]);	
		// ShowActivity(0, "userid: %d pos: x: %f y: %f z: %f",
		// 	GetClientUserId(clientId), frameArr[position][0], frameArr[position][1], frameArr[position][2]);
		// ShowActivity(0, "userid: %d angle: x: %f, y: %f, z: %f",
		// 	GetClientUserId(clientId), frameArr[angle][0], frameArr[angle][1], frameArr[angle][2]);
		// ShowActivity(0, "userid: %d vel: x: %f, y: %f, z: %f",
		// 	GetClientUserId(clientId), frameArr[velocity][0], frameArr[velocity][1], frameArr[velocity][2]);
		// ShowActivity(0, "size of struct: %d", _:Frame);

		Array_Copy(frameArr[0], frameBuff[frameBuffIndex][0], _:Frame);
		Array_Copy(frameInfoArr[0], frameInfoBuff[frameBuffIndex][0], _:NextFrameInfo);
		frameBuffIndex++;
		//WriteFile(hedgeFile, frameArr[0], _:Frame, 4);
		//FlushFile(hedgeFile);
		//PrintToConsole(FindTarget(0, "Hedgehog Hero"), "wrote frame %d / pos %f", currFrame, frameArr[position][0]);
	}
	else if (playing && IsFakeClient(client))
	{
		GetClientAbsOrigin(client, currBotOrigin);

		//PrintToChatAll("onplayerruncmd frame %d client %d pos %f %f vel %f %f", currFrame, client, threeVector[0], threeVector[1], vel[0], vel[1]);
		


		botIndex = FindValueInArray(botClientIds, client);
		if (botIndex >= 0) //make sure it's not sourcetv or some other bot/fake client not assoicated with plugin
		{
			GetArrayArray(botVels, botIndex, velRecord);
			GetArrayArray(botAngs, botIndex, angRecord);
			GetArrayArray(botPosits, botIndex, posRecord);
			GetArrayArray(botPredVels, botIndex, predVelRecord);
			SetEntityHealth(client, GetArrayCell(botHealths, botIndex));

			vel = predVelRecord;

			float maxDiff = 10.0;
			if (Entity_GetDistanceOrigin(client, posRecord) > maxDiff)
			{
					PrintToConsole(FindTarget(0, "Hedgehog Hero"), "desync on %d by %f: teleporting curr: %f record: %f vel %f", currFrame,
						Entity_GetDistanceOrigin(client, posRecord), currBotOrigin[0], posRecord[0], velRecord[0]);
					TeleportEntity(client, posRecord, NULL_VECTOR, NULL_VECTOR);
			}

			Entity_SetAbsVelocity(client, velRecord);
			//PrintToChatAll("client %d abs vel %f %f", client, velRecord[0], velRecord[1]);
			Entity_SetAbsAngles(client, angRecord);
			botButtons = GetArrayCell(botsButtons, botIndex);
			buttons = botButtons;
			return Plugin_Changed;
		}
	}

	return Plugin_Continue;
}

public void SpawnBotFor(int userIdRecord)
{
	PrintToConsole(FindTarget(0, "Hedgehog Hero"), "spawnbotfor called for player %d", userIdRecord);
	ServerCommand("sv_cheats 1; bot -name %s -team %s -class %s; sv_cheats 0", "testbot", "blue", "engineer");
	PushArrayCell(playbackUserIds, userIdRecord); //put this useridrecord and its associated bot id (of the bot acting it for this useridrecord) at the same indices in their respective arrays.
	PushArrayCell(playbackUsersNeedingBots, userIdRecord);
	PushArrayCell(botClientsInitiallyTeleported, false);
	numPlaybackBots++;
}

public Action OnWeaponSwitch(int client, int weapon)
{
	//int iItemDefinitionIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex"); //given the entity index of weapon, find the item definition index of weapon

	//record the weapon switch to a buffer to be written to file later
	if (recording)
	{
		//GetClientWeapon(client, weaponSwitchArr[weaponId], sizeof(weaponSwitchArr[weaponId]));
		weaponSwitchArr[weaponSwitcherUserId] = GetClientUserId(client);
		int iItemDefinitionIndex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
		weaponSwitchArr[weaponId] = iItemDefinitionIndex;

		//figure out what slot the player is currently in
		new slotWeapon = -1;
		bool cont = true;
		for (int i = 0; i < 7 && cont; i++) //pretend there are 7 slots just in case lol .. pretty sure there are only 3 - 5 per class
		{
			slotWeapon = GetPlayerWeaponSlot(client, i);
			if (slotWeapon == weapon)
			{
				weaponSwitchArr[weaponSlot] = i;
				cont = false;
			}
		}

		
		PushArrayArray(weaponSwitchesBuff, weaponSwitchArr[0]);

		

		PrintToConsole(FindTarget(0, "Hedgehog Hero"), "user id %d switched to weapon %d called %s",
			GetClientUserId(client), weapon, weaponSwitchArr[weaponSwitcherUserId]);

		frameInfoArr[frameType] = WEAPON_SWITCH;
		frameInfoArr[nextFrame] = currFrame - 1;
		PushArrayArray(weaponSwitchesFrameInfoBuff, frameInfoArr[0]);
	}
	return Plugin_Continue;
}

//hook into say command to allow plugin control
public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	if (StrEqual(sArgs, "/r", false))
	{
		if (recording)
		{
			PrintToChatAll("Already recording");
			return Plugin_Handled;
		}
		else if (playing)
		{
			PrintToChatAll("Currently playing something");
			return Plugin_Handled;
		}
		PrintToChatAll("Beginning recording");
		StartRecording();
		/* Block the client's messsage from broadcasting */
 		return Plugin_Handled;
	}
	else if (StrEqual(sArgs, "/s", false))
	{
		if (!recording)
		{
			PrintToChatAll("No recording to stop");
			return Plugin_Handled;
		}
		else if (playing)
		{
			PrintToChatAll("Currently playing something");
			return Plugin_Handled;
		}

		PrintToChatAll("Ending recording");
		StopRecording();
		/* Block the client's messsage from broadcasting */
 		return Plugin_Handled;
	}
	else if (StrEqual(sArgs, "/p", false))
 	{
 		if (recording)
 		{
 			PrintToChatAll("Already recording -- can't playback until done recording -- type /stoprecording to stop");
			return Plugin_Handled;
 		}
 		PrintToChatAll("Playing recording");
 		PlayRecording();
 		return Plugin_Handled;
 	}
	/* Let say continue normally */
	return Plugin_Continue;
}


public void StartRecording()
{
	KickBots();
	currFrame = 0;
	recording = true;
	hedgeFile = OpenFile("test.hedge", "wb");
}

public void StopRecording()
{
	recording = false;
	//CloseHandle(hedgeFile);
}

public void PlayRecording()
{
	KickBots();
	currFrame = 0;
	ClearArrays();
	playing = true;
	hedgeFile = OpenFile("test.hedge", "rb");
	PrintToChatAll("hedgefile = null %d", hedgeFile == null);
	//PrintToConsole(FindTarget(0, "Hedgehog Hero"), "hedgeifle position %d", FilePosition(hedgeFile));
}

public void KickBots()
{
	int maxplayers = GetMaxClients();
	for (int j = 1; j < maxplayers + 1; j++)
	{
		if (IsClientInGame(j) && IsFakeClient(j))
		{
			KickClient(j);
		}
	}
}

// use this when switching betweeen recording and playback modes
public void ClearArrays()
{
	ClearArray(playbackUserIds); //the user ids of the players who originally played the game
	ClearArray(botClientIds); //the user ids of the bots representing the original players. The indices match up between these 2 dynamic arrays
	ClearArray(playbackUsersNeedingBots); //playback users who are waiting on bots to represent them
	ClearArray(botClientsInitiallyTeleported); //have the bots corresponding to these indices been teleported to their start location yet?
	ClearArray(botsButtons); //if the bots for these corresponding indices should jump
	ClearArray(botVels);
	ClearArray(botAngs);
	ClearArray(botPosits);
	ClearArray(botPredVels);
}