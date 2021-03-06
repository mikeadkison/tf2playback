#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <smlib>
#include <tf2_stocks>
#include <tf2items_giveweapon>
#include <tf2>
#include <remote>
#include <BuildingSpawnerExtreme>

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
#define PLAYER_INFO 	0 // frame with position and angle info
#define WEAPON_SWITCH 	1 // frame with info about a weapon switch
#define TEAM_CHANGE 	2 // when the player changes teams (or selects a team for the first time or the recording starts and they're on a team)
#define CLASS_CHANGE 	3 // when the player changes class (or selects a class for the first time or the recording starts and they have a class)
#define PLAYER_DEATH 	4 // when a player dies ::D
#define PLAYER_SPAWN 	5
#define BUILD 			6

enum NextInfo //gives information in the savefile about the upcoming frame/event
{
	frameType = 0,
	nextFrame,
}

enum Frame //
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

enum ClassChange
{
	classChangeUserId = 0,
	newClass,
}

enum TeamChange
{
	teamChangeUserId = 0,
	newTeam,
}

enum PlayerDeath
{
	playerDeathUserId = 0,
}

enum PlayerSpawn
{
	playerSpawnUserId,
	playerSpawnClass,
	playerSpawnTeam,
}

enum Build
{
	buildUserId,
	buildArg0,
	buildArg1,
}

//playback and recording vars
new Float:posRecord[3];
new Float:angRecord[3];
new Float:velRecord[3];
new Float:predVelRecord[3]; //record of predicted velocity

new frameArr[Frame];
new frameInfoArr[NextInfo];
new nextFrameRecord;
new nextFrameTypeRecord;

new Float:currBotOrigin[3];


new Float:threeVector[3];
new botButtons;
new botIndex;

const BUFF_SIZE = 100000;
new eventBuffer[BUFF_SIZE]; //holds everything that happens and is written to file occasionally
new buffIndex = 0;

new weaponSwitchArr[_:WeaponSwitch];
new teamChangeArr[_:TeamChange];
new classChangeArr[_:ClassChange];
new playerDeathArr[_:PlayerDeath];
new playerSpawnArr[_:PlayerSpawn];
new buildArr[_:Build];

new Handle:botClassQueue; //when a bot initially spawns (enters the game) it should take a class off the front of this queue and become it.
new Handle:botTeamQueue; //when a bot initially spawns it should take the team off the front of this queue and become it.
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
	ServerCommand("sv_cheats 1; bot -name %s -team %s -class %s; sv_cheats 0", "testbot", "blue", "engineer");
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

	botClassQueue = new ArrayList(1, 0);
	botTeamQueue = new ArrayList(1, 0);

	int maxplayers = GetMaxClients();
	for (int client = 1; client < maxplayers + 1; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client))
		{
			SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch); //need this to detect weapon switches when recording
			numPlayers++;
		}
	}
	AddCommandListener(CommandJoinTeam, "jointeam"); //listen for team switch events
	AddCommandListener(CommandBuild, "build");
	HookEvent("player_changeclass", EventClassChange); //listen for class change events
	HookEvent("player_death", EventPlayerDeath); //listen for player death events
	HookEvent("player_spawn", EventPlayerSpawn, EventHookMode_Pre);
}

public Action:EventPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (recording)
	{
		playerSpawnArr[playerSpawnUserId] = event.GetInt("userId");
		playerSpawnArr[playerSpawnClass] = event.GetInt("class");
		playerSpawnArr[playerSpawnTeam] = event.GetInt("team");
		frameInfoArr[nextFrame] = currFrame - 1;
		frameInfoArr[frameType] = PLAYER_SPAWN;
		if ((buffIndex + sizeof(frameInfoArr) + sizeof(playerSpawnArr)) > BUFF_SIZE)
		{
			WriteBufferToFile();
		}
		WriteToBuffer(frameInfoArr[0], sizeof(frameInfoArr));
		WriteToBuffer(playerSpawnArr[0], sizeof(playerSpawnArr));
	}
	else if (playing && IsFakeClient(GetClientOfUserId(event.GetInt("userId"))))
	{
		TF2_SetPlayerClass(GetClientOfUserId(event.GetInt("userId")), GetArrayCell(botClassQueue, 0));
		RemoveFromArray(botClassQueue, 0);
		TF2_ChangeClientTeam(GetClientOfUserId(event.GetInt("userId")), GetArrayCell(botTeamQueue, 0));
		RemoveFromArray(botTeamQueue, 0);
		return Plugin_Continue;
	}
	return Plugin_Continue;
}
public Action:EventPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (recording)
	{
		playerDeathArr[playerDeathUserId] = event.GetInt("userid");
		frameInfoArr[nextFrame] = currFrame - 1;
		frameInfoArr[frameType] = PLAYER_DEATH;
		if ((buffIndex + sizeof(frameInfoArr) + sizeof(playerDeathArr)) > BUFF_SIZE)
		{
			WriteBufferToFile();
		}
		WriteToBuffer(frameInfoArr[0], sizeof(frameInfoArr));
		WriteToBuffer(playerDeathArr[0], sizeof(playerDeathArr));
	}
}

public Action:EventClassChange(Event event, const char[] name, bool dontBroadcast)
{
	if (recording)
	{
		classChangeArr[classChangeUserId] = event.GetInt("userid");
		classChangeArr[newClass] = event.GetInt("class");
		frameInfoArr[nextFrame] = currFrame - 1;
		frameInfoArr[frameType] = CLASS_CHANGE;
		if ((buffIndex + sizeof(frameInfoArr) + sizeof(classChangeArr)) > BUFF_SIZE)
		{
			WriteBufferToFile();
		}
		WriteToBuffer(frameInfoArr[0], sizeof(frameInfoArr));
		WriteToBuffer(classChangeArr[0], sizeof(classChangeArr));
	}
	return Plugin_Continue;
}

public Action:CommandBuild(client, const String:command[], args)
{
	if (recording)
	{
		new String:arg0Str[2];
		new String:arg1Str[2];


		GetCmdArg(1, arg0Str, sizeof(arg0Str));
		GetCmdArg(2, arg1Str, sizeof(arg1Str));

		buildArr[buildUserId] = GetClientUserId(client);
		buildArr[buildArg0] = StringToInt(arg0Str);
		buildArr[buildArg1] = StringToInt(arg1Str);

		if ((buffIndex + sizeof(frameInfoArr) + sizeof(buildArr)) > BUFF_SIZE)
		{
			WriteBufferToFile();
		}
		frameInfoArr[nextFrame] = currFrame - 1;
		frameInfoArr[frameType] = BUILD;
		WriteToBuffer(frameInfoArr[0], sizeof(frameInfoArr));
		WriteToBuffer(buildArr[0], sizeof(buildArr));

		PrintToConsole(FindTarget(0, "Hedgehog Hero"), "wrote a build command: %d %d",
			buildArr[buildArg0], buildArr[buildArg1]);
	}
	else
	{
		new String:arg0Str[2];
		new String:arg1Str[2];


		GetCmdArg(1, arg0Str, sizeof(arg0Str));
		GetCmdArg(2, arg1Str, sizeof(arg1Str));
		PrintToConsole(FindTarget(0, "Hedgehog Hero"), "build command has been hooked on playback %d %s %s", GetClientUserId(client), arg0Str, arg1Str);
	}
	return Plugin_Continue;
	/*char buildCmdStr[10];
	StrCat(buildCmdStr, sizeof(buildCmdStr), "build");
	StrCat(buildCmdStr, sizeof(buildCmdStr), " ");
	StrCat(buildCmdStr, sizeof(buildCmdStr), arg0Str);
	StrCat(buildCmdStr, sizeof(buildCmdStr), arg1Str);*/
}

public Action:CommandJoinTeam(client, const String:command[], args)
{
	new String:teamArgStr[5];
	GetCmdArg(1, teamArgStr, sizeof(teamArgStr));
	PrintToConsole(FindTarget(0, "Hedgehog Hero"), "jointeam command detected %d", teamArgStr);
	if (recording /*&& !IsFakeClient(client)*/) //record the team change into the buffer
	{
		teamChangeArr[teamChangeUserId] = GetClientUserId(client);
		if (StrEqual(teamArgStr, "blue"))
		{
			teamChangeArr[newTeam] = TFTeam_Blue;
		} else if (StrEqual(teamArgStr, "red", false))
		{
			teamChangeArr[newTeam] = TFTeam_Red;
		} else if (StrEqual(teamArgStr, "spec", false))
		{
			teamChangeArr[newTeam] = TFTeam_Spectator;
		}
		frameInfoArr[nextFrame] = currFrame - 1; //TODO check if this needs to be currFrame  or currFrame - 1
		frameInfoArr[frameType] = TEAM_CHANGE;
		if ((buffIndex + sizeof(frameInfoArr) + sizeof(teamChangeArr)) > BUFF_SIZE) //make sure there's space in buffer for next 2 things to be put there in order
		{
			WriteBufferToFile();
		}
		WriteToBuffer(frameInfoArr[0], sizeof(frameInfoArr));
		WriteToBuffer(teamChangeArr[0], sizeof(teamChangeArr));
	}
}

public void WriteToBuffer(const array[], int size)
{
	Array_Copy(array, eventBuffer[buffIndex], size);
	buffIndex = buffIndex + size;
}

// capture bot ids so we know which bot is representing what player!
public void OnClientPutInServer(int client)
{
	if (IsFakeClient(client) && playing) //if a userid still needs a bot paired with it for replay
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
	else if (!IsFakeClient(client))
	{
		SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitch); //need this to detect weapon switches when recording
	}
}

public void OnGameFrame()
{
	
	if (recording)
	{

	}
	else if (playing)//playback
	{

		//PrintToChatAll("Playing");
		bool hitNextFrame = false;
		//PrintToChatAll("success: %d", success);
		while (!hitNextFrame && ReadFile(hedgeFile, frameInfoArr[0], _:NextInfo, 4))
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
						//SpawnBotFor(userIdRecord);
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
					new weaponSwitchUserIdRecord = weaponSwitchArr[weaponSwitcherUserId];
					PrintToConsole(FindTarget(0, "Hedgehog Hero"), "index of recorded userid %d is %d with wep %s",
						weaponSwitchUserIdRecord, FindValueInArray(playbackUserIds, weaponSwitchUserIdRecord), weaponSwitchArr[weaponId]);
					new clientId = GetArrayCell(botClientIds, FindValueInArray(playbackUserIds, weaponSwitchUserIdRecord));
					PrintToConsole(FindTarget(0, "Hedgehog Hero"), "switched to wep %s on bot %d", weaponSwitchArr[weaponId], GetClientUserId(clientId));

					TF2Items_GiveWeapon(clientId, weaponSwitchArr[weaponId]);
					//force a switch to new weapon
					new weapon = GetPlayerWeaponSlot(clientId, weaponSwitchArr[weaponSlot]);
					SetEntPropEnt(clientId, Prop_Send, "m_hActiveWeapon", weapon); 
					//EquipPlayerWeapon(clientId, weaponIdRecord);
				}
				else if (TEAM_CHANGE == nextFrameTypeRecord)
				{
					PrintToConsole(FindTarget(0, "Hedgehog Hero"), "team change found xD");
					ReadFile(hedgeFile, teamChangeArr[0], _:TeamChange, 4);
					new teamChangeUserIdRecord = teamChangeArr[teamChangeUserId];
					new clientId = GetArrayCell(botClientIds, FindValueInArray(playbackUserIds, teamChangeUserIdRecord));

					//force the bot to switch teams
					TF2_ChangeClientTeam(clientId, teamChangeArr[newTeam]);
				}
				else if (CLASS_CHANGE == nextFrameTypeRecord)
				{
					PrintToConsole(FindTarget(0, "Hedgehog Hero"), "class change found xp");
					ReadFile(hedgeFile, classChangeArr[0], _:ClassChange, 4);
					new clientId = GetArrayCell(botClientIds, FindValueInArray(playbackUserIds, classChangeArr[classChangeUserId]));
					TF2_SetPlayerClass(clientId, classChangeArr[newClass], false, true);
				}
				else if (PLAYER_DEATH == nextFrameTypeRecord)
				{
					PrintToConsole(FindTarget(0, "Hedgehog Hero"), "player death read xd");
					ReadFile(hedgeFile, playerDeathArr[0], _:PlayerDeath, 4);
					new clientId = GetArrayCell(botClientIds, FindValueInArray(playbackUserIds, playerDeathArr[playerDeathUserId]));
					ForcePlayerSuicide(clientId); //kill the player!
				}
				else if (PLAYER_SPAWN == nextFrameTypeRecord)
				{
					PrintToConsole(FindTarget(0, "Hedgehog Hero"), "player spawn read xd:");
					ReadFile(hedgeFile, playerSpawnArr[0], _:PlayerSpawn, 4);
					new userIdRecord = playerSpawnArr[playerSpawnUserId];
					new userIdRecordIndex = FindValueInArray(playbackUserIds, userIdRecord);
					if (userIdRecordIndex == -1)
					{
						PushArrayCell(botClassQueue, playerSpawnArr[playerSpawnClass]);
						PushArrayCell(botTeamQueue, playerSpawnArr[playerSpawnTeam]);
						SpawnBotFor(userIdRecord);
						PrintToConsole(FindTarget(0, "Hedgehog Hero"), "spawning bot initially");
					}
					else
					{
						new clientId = GetArrayCell(botClientIds, FindValueInArray(playbackUserIds, playerSpawnArr[playerSpawnUserId]));
						TF2_ChangeClientTeam(clientId, playerSpawnArr[playerSpawnTeam]);
						TF2_SetPlayerClass(clientId, playerSpawnArr[playerSpawnClass], false, true);
					}
				}
				else if (BUILD == nextFrameTypeRecord)
				{
					PrintToConsole(FindTarget(0, "Hedgehog Hero"), "build command read :p");
					ReadFile(hedgeFile, buildArr[0], _:Build, 4);
					new clientId = GetArrayCell(botClientIds,
						FindValueInArray(playbackUserIds, buildArr[buildUserId]));
					PrintToConsole(FindTarget(0, "Hedgehog Hero"), "build command for bot user id %d params %d %d", GetClientUserId(clientId), buildArr[buildArg0], buildArr[buildArg1]);
					FakeClientCommand(clientId, "build %d %d", buildArr[buildArg0], buildArr[buildArg1]);
				}
			}
			else //hit the next frame, so stop reading for now and put the file pointer back at the beginning of the NextInfo
			{
				hitNextFrame = true;
				FileSeek(hedgeFile, -_:NextInfo * 4, SEEK_CUR);
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
	if (recording /*&& !IsFakeClient(client)*/)
	{
		//describe the upcoming frame
		frameInfoArr[nextFrame] = currFrame - 1; //currframe is incremented in ongameframe but it's not actually the next frame yet because onplayercmd is called after ongameframe
		frameInfoArr[frameType] = PLAYER_INFO;
		//WriteFile(hedgeFile, frameInfoArr[0], _:NextInfo, 4);
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

		if ((buffIndex + _:NextInfo + _:Frame) > BUFF_SIZE) //if the buffer is full clear it out first
		{
			WriteBufferToFile();
		}
		Array_Copy(frameInfoArr[0], eventBuffer[buffIndex], _:NextInfo);
		buffIndex = buffIndex + _:NextInfo;
		Array_Copy(frameArr[0], eventBuffer[buffIndex], _:Frame);
		buffIndex = buffIndex + _:Frame;
		
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
	ServerCommand("sv_cheats 1; bot -name %s -team %s -class %s; sv_cheats 0", "testbot", "blue", "pyro");
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

		
		if ((buffIndex + _:WeaponSwitch + _:NextInfo) > BUFF_SIZE) //if the buffer is full clear it out first
		{
			WriteBufferToFile();
		}
		
		

		PrintToConsole(FindTarget(0, "Hedgehog Hero"), "user id %d switched to weapon %d called %s",
			GetClientUserId(client), weapon, weaponSwitchArr[weaponSwitcherUserId]);

		frameInfoArr[frameType] = WEAPON_SWITCH;
		frameInfoArr[nextFrame] = currFrame - 1;
		Array_Copy(frameInfoArr[0],  eventBuffer[buffIndex], _:NextInfo);
		buffIndex = buffIndex + _:NextInfo;
		Array_Copy(weaponSwitchArr[0], eventBuffer[buffIndex], _:WeaponSwitch);
		buffIndex = buffIndex + _:WeaponSwitch;
	}
	return Plugin_Continue;
}

public void WriteBufferToFile()
{
	PrintToConsole(FindTarget(0, "Hedgehog Hero"), "writing buffer to file");
	new currIndex = 0; //where in the buffer we will read from next

	while(currIndex < buffIndex)
	{
		//see what the type of the next event is so we know how much to write to file from the buffer
		Array_Copy(eventBuffer[currIndex], frameInfoArr[0], _:NextInfo);
		WriteFile(hedgeFile, frameInfoArr[0], _:NextInfo, 4); //write a descriptor of the upcoming event
		currIndex = currIndex + _:NextInfo;
		//PrintToConsole(FindTarget(0, "Hedgehog Hero"), "writing frame info for frame %d", frameInfoArr[nextFrame]);
		new amtToWrite; //for the next event not including the frame info
		if (PLAYER_INFO == frameInfoArr[frameType])
		{
			amtToWrite = _:Frame;
		}
		else if (WEAPON_SWITCH == frameInfoArr[frameType])
		{
			amtToWrite = _:WeaponSwitch;
		}
		WriteFile(hedgeFile, eventBuffer[currIndex], amtToWrite, 4);
		//PrintToConsole(FindTarget(0, "Hedgehog Hero"), "amt written: %d", amtToWrite);
		currIndex = currIndex + amtToWrite;
	}
	buffIndex = 0; //start overwriting buffer from beginning with new events
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
 	else if (StrEqual(sArgs, "/buildsentry", false))
 	{
 		new Float:origin[3];
 		GetClientAbsOrigin(client, origin);
 		new Float:angles[3];
 		GetClientEyeAngles(client, angles);
 		BuildSentry(client, origin, angles, 1, false, false, false, -1, -1, -1, -1, 0.0);
 		PrintToChatAll("built sentry");
 	}
	/* Let say continue normally */
	return Plugin_Continue;
}


public void StartRecording()
{
	//KickBots();
	SpawnBots();
	currFrame = 0;
	recording = true;
	hedgeFile = OpenFile("test.hedge", "wb");
	RecordInitialSpawnInfo();
	//RecordInitialTeams();
}

// write the events to record everyone's initial classes
public void RecordInitialSpawnInfo()
{
	for (new i = 1; i <= MaxClients; i++)
	{
	    if (IsClientInGame(i)) //TODO check that not spectator
	    {
	        // Only trigger for client indexes actually in the game
	        playerSpawnArr[playerSpawnUserId] = GetClientUserId(i);
	        playerSpawnArr[playerSpawnClass] = TF2_GetPlayerClass(i);
	        playerSpawnArr[playerSpawnTeam] = TF2_GetClientTeam(i);

	        frameInfoArr[nextFrame] = currFrame;
	        frameInfoArr[frameType] = PLAYER_SPAWN;
	        if ((buffIndex + sizeof(frameInfoArr) + sizeof(playerSpawnArr)) > BUFF_SIZE)
	        {
	        	WriteBufferToFile();
	        }
	        WriteToBuffer(frameInfoArr[0], sizeof(frameInfoArr));
	        WriteToBuffer(playerSpawnArr[0], sizeof(playerSpawnArr));
	        PrintToConsole(FindTarget(0, "Hedgehog Hero"), "recorded initial player spawne for id %d", GetClientUserId(i));
	    }
	    //PrintToConsole(FindTarget(0, "Hedgehog Hero"), "looped for i value of %d", i);
	}
}


public void StopRecording()
{
	recording = false;
	WriteBufferToFile();
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


public void SpawnBots()
{

/*	ServerCommand("sv_cheats 1; bot -name %s -team %s -class %s; sv_cheats 0", "testbot", "blue", "engineer");
	ServerCommand("sv_cheats 1; bot -name %s -team %s -class %s; sv_cheats 0", "testbot", "blue", "engineer");
	ServerCommand("sv_cheats 1; bot -name %s -team %s -class %s; sv_cheats 0", "testbot", "blue", "engineer");
	ServerCommand("sv_cheats 1; bot -name %s -team %s -class %s; sv_cheats 0", "testbot", "blue", "engineer");
	ServerCommand("sv_cheats 1; bot -name %s -team %s -class %s; sv_cheats 0", "testbot", "blue", "engineer");
	ServerCommand("sv_cheats 1; bot -name %s -team %s -class %s; sv_cheats 0", "testbot", "blue", "engineer");
	ServerCommand("sv_cheats 1; bot -name %s -team %s -class %s; sv_cheats 0", "testbot", "blue", "engineer");
	ServerCommand("sv_cheats 1; bot -name %s -team %s -class %s; sv_cheats 0", "testbot", "blue", "engineer");
	ServerCommand("sv_cheats 1; bot -name %s -team %s -class %s; sv_cheats 0", "testbot", "blue", "engineer");
	ServerCommand("sv_cheats 1; bot -name %s -team %s -class %s; sv_cheats 0", "testbot", "blue", "engineer");
	ServerCommand("sv_cheats 1; bot -name %s -team %s -class %s; sv_cheats 0", "testbot", "blue", "engineer");
	PrintToConsole(FindTarget(0, "Hedgehog Hero"), "spawned bots");*/
}

/**
help from / thanks to

happs
sizzlingcalamari
tragicservers
nite
iggynacio
charis
tepi
papiyisus
botmimic

*/