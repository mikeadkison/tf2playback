//author = Pelipoika
//https://forums.alliedmods.net/showthread.php?t=241627

stock SpawnSentry(builder, Float:Position[3], Float:Angle[3], level, bool:mini=false, bool:disposable=false, bool:carried=false, flags=4)
{
	static const Float:m_vecMinsMini[3] = {-15.0, -15.0, 0.0}, Float:m_vecMaxsMini[3] = {15.0, 15.0, 49.5};
	static const Float:m_vecMinsDisp[3] = {-13.0, -13.0, 0.0}, Float:m_vecMaxsDisp[3] = {13.0, 13.0, 42.9};
	
	new sentry = CreateEntityByName("obj_sentrygun");
	
	if(IsValidEntity(sentry))
	{
		AcceptEntityInput(sentry, "SetBuilder", builder);

		DispatchKeyValueVector(sentry, "origin", Position);
		DispatchKeyValueVector(sentry, "angles", Angle);
		
		if(mini)
		{
			SetEntProp(sentry, Prop_Send, "m_bMiniBuilding", 1);
			SetEntProp(sentry, Prop_Send, "m_iUpgradeLevel", level);
			SetEntProp(sentry, Prop_Send, "m_iHighestUpgradeLevel", level);
			SetEntProp(sentry, Prop_Data, "m_spawnflags", flags);
			SetEntProp(sentry, Prop_Send, "m_bBuilding", 1);
			SetEntProp(sentry, Prop_Send, "m_nSkin", level == 1 ? GetClientTeam(builder) : GetClientTeam(builder) - 2);
			DispatchSpawn(sentry);
			
			SetVariantInt(100);
			AcceptEntityInput(sentry, "SetHealth");
			
			SetEntPropFloat(sentry, Prop_Send, "m_flModelScale", 0.75);
			SetEntPropVector(sentry, Prop_Send, "m_vecMins", m_vecMinsMini);
			SetEntPropVector(sentry, Prop_Send, "m_vecMaxs", m_vecMaxsMini);
		}
		else if(disposable)
		{
			SetEntProp(sentry, Prop_Send, "m_bMiniBuilding", 1);
			SetEntProp(sentry, Prop_Send, "m_bDisposableBuilding", 1);
			SetEntProp(sentry, Prop_Send, "m_iUpgradeLevel", level);
			SetEntProp(sentry, Prop_Send, "m_iHighestUpgradeLevel", level);
			SetEntProp(sentry, Prop_Data, "m_spawnflags", flags);
			SetEntProp(sentry, Prop_Send, "m_bBuilding", 1);
			SetEntProp(sentry, Prop_Send, "m_nSkin", level == 1 ? GetClientTeam(builder) : GetClientTeam(builder) - 2);
			DispatchSpawn(sentry);
			
			SetVariantInt(100);
			AcceptEntityInput(sentry, "SetHealth");
			
			SetEntPropFloat(sentry, Prop_Send, "m_flModelScale", 0.60);
			SetEntPropVector(sentry, Prop_Send, "m_vecMins", m_vecMinsDisp);
			SetEntPropVector(sentry, Prop_Send, "m_vecMaxs", m_vecMaxsDisp);
		}
		else
		{
			SetEntProp(sentry, Prop_Send, "m_iUpgradeLevel", level);
			SetEntProp(sentry, Prop_Send, "m_iHighestUpgradeLevel", level);
			SetEntProp(sentry, Prop_Data, "m_spawnflags", flags);
			SetEntProp(sentry, Prop_Send, "m_bBuilding", 1);
			SetEntProp(sentry, Prop_Send, "m_nSkin", GetClientTeam(builder) - 2);
			
			DispatchSpawn(sentry);
		}
		
		if(carried)	//Doesnt work... yet.
		{
			/*
			//Change clients build tools properties to match things.
			new buildtool = GetPlayerWeaponSlot(builder, TFWeaponSlot_PDA);
			
			if(IsValidEntity(buildtool))
			{
				SetEntPropEnt(buildtool, Prop_Send, "m_hObjectBeingBuilt", sentry);
				SetEntProp(buildtool, Prop_Send, "m_iBuildState", 2);
				SetEntProp(buildtool, Prop_Send, "m_iState", 2);
				SetEntProp(buildtool, Prop_Send, "m_fEffects", 129);
				SetEntProp(buildtool, Prop_Send, "m_nSequence", 34);
				
				SetEntPropEnt(builder, Prop_Send, "m_hActiveWeapon", buildtool);
				SetEntProp(builder, Prop_Send, "m_hCarriedObject", sentry);
				SetEntProp(builder, Prop_Send, "m_bCarryingObject", 1);
			
				SetEntProp(sentry, Prop_Send, "m_iAmmoShells", 0);
				SetEntProp(sentry, Prop_Send, "m_iAmmoRockets", 0);
				SetEntProp(sentry, Prop_Send, "m_nNewSequenceParity", 5);
				SetEntProp(sentry, Prop_Send, "m_nResetEventsParity", 5);
				SetEntProp(sentry, Prop_Send, "m_usSolidFlags", 4);
				SetEntProp(sentry, Prop_Send, "m_bBuilding", 0);
				SetEntProp(sentry, Prop_Send, "m_bCarried", 1);
				SetEntProp(sentry, Prop_Send, "m_bPlacing", 1);
				SetEntProp(sentry, Prop_Send, "m_iState", 0);	//When building 1, When done 2.
				SetEntProp(sentry, Prop_Send, "m_bCarryDeploy", 0);
			}
			else
			{
				PrintToChat(builder, "Invalid entity");
			}*/
		}
	}
}

stock SpawnDispenser(builder, Float:Position[3], Float:Angle[3], level, flags=4)
{
	new dispenser = CreateEntityByName("obj_dispenser");
	
	if(IsValidEntity(dispenser))
	{
		DispatchKeyValueVector(dispenser, "origin", Position);
		DispatchKeyValueVector(dispenser, "angles", Angle);
		SetEntProp(dispenser, Prop_Send, "m_iHighestUpgradeLevel", level);
		SetEntProp(dispenser, Prop_Data, "m_spawnflags", flags);
		SetEntProp(dispenser, Prop_Send, "m_bBuilding", 1);
		DispatchSpawn(dispenser);

		SetVariantInt(GetClientTeam(builder));
		AcceptEntityInput(dispenser, "SetTeam");
		SetEntProp(dispenser, Prop_Send, "m_nSkin", GetClientTeam(builder) - 2);
		
		ActivateEntity(dispenser);	//fixes screen
		
		AcceptEntityInput(dispenser, "SetBuilder", builder);	//Gotta do dis after activation.
	}
}

stock SpawnTeleporter(builder, Float:Position[3], Float:Angle[3], level, TFObjectMode:mode, flags=4)
{
	new teleporter = CreateEntityByName("obj_teleporter");
	
	if(IsValidEntity(teleporter))
	{
		DispatchKeyValueVector(teleporter, "origin", Position);
		DispatchKeyValueVector(teleporter, "angles", Angle);
		
		SetEntProp(teleporter, Prop_Send, "m_iHighestUpgradeLevel", level);
		SetEntProp(teleporter, Prop_Data, "m_spawnflags", flags);
		SetEntProp(teleporter, Prop_Send, "m_bBuilding", 1);
		SetEntProp(teleporter, Prop_Data, "m_iTeleportType", mode);
		SetEntProp(teleporter, Prop_Send, "m_iObjectMode", mode);
		SetEntProp(teleporter, Prop_Send, "m_nSkin", GetClientTeam(builder) - 2);
		DispatchSpawn(teleporter);
		
		AcceptEntityInput(teleporter, "SetBuilder", builder);
		
		SetVariantInt(GetClientTeam(builder));
		AcceptEntityInput(teleporter, "SetTeam");
	}
}