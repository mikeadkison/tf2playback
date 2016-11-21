/**
 * vim: set ai et ts=4 sw=4 syntax=sourcepawn :
 * File: remote.inc
 * Description: Native Interface to remote (control)
 * Author(s): -=|JFH|=-Naris (Murray Wilson)
 */

#if defined _remote_included
 #endinput
#endif
#define _remote_included

#include <tf2_objects>

// These define the permissions
#define HAS_REMOTE 		            (1 << 0)
#define REMOTE_CAN_ZOMBIE		    (1 << 1)
#define REMOTE_CAN_STEAL		    (1 << 2)
#define REMOTE_CAN_BUILD_INSTANTLY	(1 << 3)
#define REMOTE_CAN_BUILD_FLOATING 	(1 << 4)
#define REMOTE_CAN_BUILD_MINI       (1 << 5)
#define REMOTE_CAN_BUILD_LEVEL_1    (1 << 6)
#define REMOTE_CAN_BUILD_LEVEL_2    (1 << 7)
#define REMOTE_CAN_BUILD_LEVEL_3    (1 << 8)
#define REMOTE_CAN_BUILD_AMPLIFIER  (1 << 9)
#define REMOTE_CAN_BUILD_REPAIR     (1 << 10)

#define REMOTE_CAN_BUILD            (REMOTE_CAN_BUILD_MINI|REMOTE_CAN_BUILD_LEVEL_1|REMOTE_CAN_BUILD_LEVEL_2|REMOTE_CAN_BUILD_LEVEL_3)
#define REMOTE_CAN_BUILD_UPGRADED   (CAN_BUILD_LEVEL_2|CAN_BUILD_LEVEL_3)
#define CAN_BUILD_ACTIVATED         REMOTE_CAN_BUILD_INSTANTLY

/**
 * Assume control of the remote plugin
 *
 * @param plugin_only 	Set to 1 to assume complete control of remotesentries.
 * @return		    	none
 */
native ControlRemote(bool:plugin_only=true);

/**
 * Give a remote control to the player
 *
 * @param index 	    Client index
 * @param permissions   Permissions to use, set 0 to disable (default=-1 to use ConVars)
 * @param speed         Speed that Remote Controlled object move.
 * @param fall_speed    Speed used when Remote Controlled objects fall.
 * @param jump_speed    Speed used when Remote Controlled objects jump.
 * @return		    	none
 */
native SetRemoteControl(client, permissions=-1, Float:speed=-1.0, Float:fall_speed=-1.0, Float:jump_speed=-1.0);

/**
 * Remote Control an object
 *
 * @param index 	Client index
 * @param type:     Type of object to control
 * @return			none
 */
native RemoteControlObject(client, TFExtObjectType:type=TFExtObject_Unknown);

/**
 * Stop Remote Controlling an object (if any)
 *
 * @param index 	Client index
 * @return			none
 */
native StopControllingObject(client);

/**
 * Gets called when controlling a building
 *
 * @param client:   The index of the client that used the remote control.
 * @param builder:  The index of the builder of the building that got controlled
 * @param ent:      The index of the building that got grabbed
 */
forward Action:OnControlObject(client,builder,ent);

/**
 * Gets called when building a building
 *
 * @param client:   The index of the client that want to build a building.
 * @param ent:      The index of the building that got grabbed
 */
forward Action:OnBuildObject(client,TFExtObjectType:type);

/**
 * Description: Native Interface to build
 */

/**
 * Build a Sentry
 *
 * @param iBuilder 	        Client index of builder
 * @param fOrigin           Position fotr new Sentry
 * @param fAngle            Angles for new Sentry
 * @param iLevel            Level for new Sentry
 * @param bDisabled         Disabled flag
 * @param bMini             Mini Sentry flag (causes the flashing light to be attached, and make them un-repairable or upgradable)
 * @param bShielded         Shielded flag (causes the sentry to have a shield)
 * @param iHealth           Health of the Sentry
 * @param iMaxHealth        Max Health of Sentry
 * @param iShells           Number of shells Sentry spawns with
 * @param iRockets          Number of rockets Sentry spawns with
 * @param flPercentage      Value to use for flPercentageConstructed
 * @return			        entity index of new Sentry
 */
native BuildSentry(iBuilder, const Float:fOrigin[3], const Float:fAngle[3], iLevel=1,
                   bool:bDisabled=false, bool:bMini=false, bool:bShielded=false,
                   iHealth=-1, iMaxHealth=-1, iShells=-1, iRockets=-1,
                   Float:flPercentage=1.0);

/**
 * Build a Dispenser
 *
 * @param iBuilder 	        Client index of builder
 * @param fOrigin           Position fotr new Dispenser
 * @param fAngle            Angles for new Dispenser
 * @param iLevel            Level for new Dispenser
 * @param iDisabled         Disabled flag
 * @param iHealth           Health of the Dispenser
 * @param iMaxHealth        Max Health of Dispenser
 * @param iMetal            Amount of metal Dispenser spawns with
 * @param flPercentage      Value to use for flPercentageConstructed
 * @param type              Type of dispenser to build (which model to use - Dispenser, Amplifier or Repair Node)
 * @return			        entity index of new Dispenser
 */

native BuildDispenser(iBuilder, const Float:fOrigin[3], const Float:fAngle[3], iLevel=1,
                      bool:iDisabled=false, iHealth=-1, iMaxHealth=-1, iMetal=-1,
                      Float:flPercentage=1.0, TFExtObjectType:type=TFExtObject_Dispenser);

/**
 * Build a Teleporter Entry
 *
 * @param iBuilder 	        Client index of builder
 * @param fOrigin           Position fotr new Teleporter Entry
 * @param fAngle            Angles for new Teleporter Entry
 * @param iLevel            Level for new Teleporter Entry
 * @param iDisabled         Disabled flag
 * @param iHealth           Health of the Teleporter Entry
 * @param iMaxHealth        Max Health of Teleporter Entry
 * @param flPercentage      Value to use for flPercentageConstructed
 * @return			        entity index of new Teleporter Entry
 */
native BuildTeleporterEntry(iBuilder, const Float:fOrigin[3], const Float:fAngle[3],
                            iLevel=1, bool:iDisabled=false, iHealth=-1, iMaxHealth=-1,
                            Float:flPercentage=1.0);

/**
 * Build a Teleporter Exit
 *
 * @param iBuilder 	        Client index of builder
 * @param fOrigin           Position fotr new Teleporter Exit
 * @param fAngle            Angles for new Teleporter Exit
 * @param iLevel            Level for new Teleporter Exit
 * @param iDisabled         Disabled flag
 * @param iHealth           Health of the Teleporter Exit
 * @param iMaxHealth        Max Health of Teleporter Exit
 * @param flPercentage      Value to use for flPercentageConstructed
 * @return			        entity index of new Teleporter Exit
 */
native BuildTeleporterExit(iBuilder, const Float:fOrigin[3], const Float:fAngle[3],
                           iLevel=1, bool:iDisabled=false, iHealth=-1, iMaxHealth=-1,
                           Float:flPercentage=1.0);

/**
 * Build an object where the client is standing
 *
 * @param client 	        Client index of builder
 * @param type              Type of object to build
 * @param iLevel            Level for new Building
 * @param bMini             Mini Sentry flag (causes the flashing light to be attached, and make them un-repairable or upgradable)
 * @param bShielded         Shielded flag (causes the sentry to have a shield)
 * @param bDisabled         Disable the building temporarily after building.
 * @param check             Check the build limit before bulding.
 * @param iHealth           Health of the Teleporter Exit
 * @param iMaxHealth        Max Health of Teleporter Exit
 * @param remote            Remote control the building after building it.
 * @param drop              Drop the building after building (to ensure it's on the ground) - requires ztf2grab plugin to work.
 * @param pos               Returns the position the object was built at.
 * @return			        entity index of new Object
 */
native BuildObject(client, TFExtObjectType:type, iLevel=1, bool:bMini=false,
                   bool:bShielded=false, bool:bDisabled=true, iHealth=-1,
                   iMaxHealth=-1, Float:flPercentage=1.0, bool:remote=false,
                   bool:drop=true, bool:check=true, Float:pos[3]={0.0});

/**
 * Counts buildings of all classes owned by client
 *
 * @param client 	        Client index of builder
 * @param counts            Array to hold the counts of all buildings by type.
 * @return			        count of all buildings.
 */
native CountBuildings(client, counts[TFExtObjectType]={0});

/**
 * Counts objects of the given class owned by client
 *
 * @param client 	        Client index of builder
 * @param class             Classname of entities to count.
 * @param mode              m_iObjectMode of entities to count (-1=any)
 * @return			        count of all buildings.
 */
native CountObjects(client, const String:class[], mode=-1);

/**
 * Adds buildings owned by client to a menu.
 *  (The SelectionInfo of each menu item will be set to the stringized value of an EntRef for the building)
 *
 * @param menu              Menu to add buildings to
 * @param client 	        Client index of builder
 * @param all               Include unfinished buildings in the menu
 * @param counts            Array to hold the building counts by type.
 * @param target            Entity ID of last object added to the menu
 * @return			        count of buildings added
 */
native AddBuildingsToMenu(Handle:menu, client, bool:all=false,
                          counts[TFExtObjectType]={0}, &target=0);

/**
 * Destroys buildings
 *
 * @param client 	        Client index of builder, -1 for all builders.
 * @param all    	        Set to false to only destroy buildings that have been spawned by this plugin
 * @return			        count of buildings destroyed
 */
native DestroyBuildings(client=-1, bool:all=true);

/**
 * Presents a menu of buildings for client to pick one to destroy.
 *
 * @param client 	        Client index of builder
 * @return			        true if there were buildings to destroy
 */
native bool:DestroyBuildingMenu(client);

/**
 * Destroys the specified building.
 *
 * @param object 	        Entity (building object) to destroy.
 * @return			        none
 */
native DestroyBuilding(ent);

/**
 * Description: Native Interface to buildlimit
 */

/**
 * Assume control of the buildlimit plugin
 *
 * @param plugin_only 	Set to 1 to assume complete control of the Firemines plugin.
 * @return		    	none
 */
native ControlBuild(bool:plugin_only=true);

/**
 * Sets the number of buildings the payer can build.
 *
 * @param index 	        Client index
 * @param sentry            Set to number of sentries the player can build. (-1 is unlimited)
 * @param dispenser         Set to number of dispensers the player can build. (-1 is unlimited)
 * @param teleport_entry    Set to number of teleport_entrys the player can build. (-1 is unlimited)
 * @param teleport_exit     Set to number of teleport_exits player can build. (-1 is unlimited)
 * @return			        none
 */
native GiveBuild(client,sentry=1,dispenser=1,teleport_entry=1,teleport_exit=1);

/**
 * Reset the build restriction back to 1 of each type of building.
 *
 * @param index 	Client index
 * @return			none
 */
native ResetBuild(client);

/**
 * Check if the client is allowed to build the building.
 *
 * @param index 	Client index
 * @param type      Type of object to check
 * @param mode:     Mode of object to check (-1=don't check mode)
 * @param count     Reference that returns the number of existing buildings
 * @return			true if the building can be built.
 */
native bool:CheckBuild(client,TFObjectType:type,mode=-1,&count=0);

/**
 * Gets called when the build command is issued to build a building
 *
 * @param client:   The index of the client that is building
 * @param type:     The type of building being built
 * @param mode:     The mode of building being built (0=Teleporter Entrance, 1=Exit, -1=N/A)
 * @param count:    The number of that type of building already built by client
 * @return          Plugin_Handled will block building.
 */
forward Action:OnBuildCommand(client,TFObjectType:type,mode,count);

/* DO NOT EDIT BELOW THIS LINE */

public SharedPlugin:__pl_remote = 
{
	name = "remote",
	file = "remote.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_remote_SetNTVOptional()
{
	MarkNativeAsOptional("ControlRemote");
	MarkNativeAsOptional("SetRemoteControl");
	MarkNativeAsOptional("RemoteControlObject");
	MarkNativeAsOptional("StopControllingObject");

	MarkNativeAsOptional("BuildObject");
	MarkNativeAsOptional("BuildSentry");
	MarkNativeAsOptional("BuildDispenser");
	MarkNativeAsOptional("BuildTeleporterExit");
	MarkNativeAsOptional("BuildTeleporterEntry");
	MarkNativeAsOptional("DestroyBuildingMenu");
	MarkNativeAsOptional("AddBuildingsToMenu");
	MarkNativeAsOptional("DestroyBuildings");
	MarkNativeAsOptional("DestroyBuilding");
	MarkNativeAsOptional("CountBuildings");
	MarkNativeAsOptional("CountObjects");

	MarkNativeAsOptional("ControlBuild");
	MarkNativeAsOptional("ResetBuild");
	MarkNativeAsOptional("CheckBuild");
	MarkNativeAsOptional("GiveBuild");
}
#endif

