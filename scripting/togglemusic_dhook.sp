#pragma semicolon 1
//#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <dhooks>
#include <emitsoundany>
//#include <clientprefs> //Maybe use this later on

#define PLUGIN_NAME 	"Toggle Music"
#define PLUGIN_VERSION 	"3.0"

//Global Handles & Variables
float g_fCmdTime[MAXPLAYERS+1];
float g_fClientVol[MAXPLAYERS+1];
bool g_bDisabled[MAXPLAYERS + 1];
bool g_bMapAmbient;
bool g_bDebug;
bool precached;

Handle hAcceptInput;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "Mitch & Agent Wesker",
	description = "Allows clients to toggle ambient sounds played by the map",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
};

public void OnPluginStart()
{
	CreateConVar("sm_stopmusic_version", PLUGIN_VERSION, "Toggle Map Music", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	RegConsoleCmd("sm_music", Command_StopMusic, "Toggles map music");
	RegConsoleCmd("sm_stopmusic", Command_StopMusic, "Toggles map music");
	RegConsoleCmd("sm_volume", Command_Volume, "Brings volume menu");

	Handle temp = LoadGameConfigFile("sdktools.games\\engine.csgo");

	if(temp == null) {
		SetFailState("Why you no has gamedata?");
	}

	HookEvent("round_start", Event_RoundStart);
	
	int offset = GameConfGetOffset(temp, "AcceptInput");
	hAcceptInput = DHookCreate(offset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity, AcceptInput);
	DHookAddParam(hAcceptInput, HookParamType_CharPtr);
	DHookAddParam(hAcceptInput, HookParamType_CBaseEntity);
	DHookAddParam(hAcceptInput, HookParamType_CBaseEntity);
	DHookAddParam(hAcceptInput, HookParamType_Object, 20);
	DHookAddParam(hAcceptInput, HookParamType_Int);
	
	//Set volume level to default (late load)
	for (int j = 1; j <= MaxClients; j++) {
		OnClientPostAdminCheck(j);
	}
}

public void OnClientPostAdminCheck(int client)
{
	g_fClientVol[client] = 1.0;
}

public OnClientDisconnect_Post(client) {
	g_fCmdTime[client] = 0.0;
	disabled[client] = false;
}

//Return types
//https://wiki.alliedmods.net/Sourcehook_Development#Hook_Functions
//
public MRESReturn AcceptInput(int entity, Handle hReturn, Handle hParams)
{
	char eCommand[128];
	DHookGetParamString(hParams, 1, eCommand, sizeof(eCommand));
	char eParam[128];
	DHookGetParamObjectPtrString(hParams, 4, 0, ObjectValueType_String, eParam, sizeof(eParam));
	char soundFile[PLATFORM_MAX_PATH], eName[48];
	GetEntPropString(entity, Prop_Data, "m_iszSound", soundFile, sizeof(soundFile));
	GetEntPropString(entity, Prop_Data, "m_iName", eName, sizeof(eName));
	int hID = GetEntProp(entity, Prop_Data, "m_iHammerID");
	PrintToServer("Cmd %s Name %s hID %i Param %s Song %s", eCommand, eName, hID, eParam, soundFile);

	if(StrEqual(eCommand, "PlaySound", false) && IsValidEntity(entity))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!g_bDisabled[i] && IsValidClient(i))
			{
				ClientSendSound(i, soundFile, g_fClientVol[i])
			}
		}
	} else if (StrEqual(eCommand, "StopSound", false) || (StrEqual(eCommand, "Volume", false) && StrEqual(eParam, "0", false)))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsValidClient(i)) {
				ClientStopSound(i, name);
			}
		}
	} else if (StrContains(eCommand, "FireUser", false) != -1 || (StrEqual(eCommand, "Volume", false) && eParam[0] && !StrEqual(eParam, "0", false))) {
		return MRES_Ignored;
	}
	
	DHookSetReturn(hReturn, false);
	return MRES_Supercede;
}
/*
public MRESReturn AcceptInput(int entity, Handle hReturn, Handle hParams) {
	char command[PLATFORM_MAX_PATH];
	DHookGetParamString(hParams, 1, command, sizeof(command));
	if(StrEqual(command, "PlaySound", false) && IsValidEntity(entity)) {
		actionType = 2;
		decl String:soundFile[PLATFORM_MAX_PATH];
		GetEntPropString(entity, Prop_Data, "m_iszSound", soundFile, sizeof(soundFile));
		if(StrContains(soundFile, ".mp3", false) >= 0) {
			actionType = 0;
		}
		if(StrContains(soundFile, ".wav", false) >= 0) {
			actionType = 1;
		}
		SetEntProp(entity, Prop_Data, "m_fLooping", false);
		for(i = 1; i <= MaxClients;i++) {
			if(!disabled[i] || !IsClientInGame(i)) { 
				continue;
			}
			if(action[i] == 2 || \
				(actionType == 0 && (action[i] == 0 || action[i] == 1)) || \
				(actionType == 1 && action[i] == 1)) {
				stopClientsMusic(i);
				CreateTimer(1.5, Timer_StopMusic, GetClientUserId(i), TIMER_FLAG_NO_MAPCHANGE);
				CreateTimer(2.1, Timer_StopMusic, GetClientUserId(i), TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
	return MRES_Ignored;
}
*/

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{    
    char sSound[PLATFORM_MAX_PATH];
    int entity = INVALID_ENT_REFERENCE;
    
    while ((entity = FindEntityByClassname(entity, "ambient_generic")) != INVALID_ENT_REFERENCE)
    {
		DHookEntity(hAcceptInput, false, entity);
        GetEntPropString(entity, Prop_Data, "m_iszSound", sSound, sizeof(sSound));
		
		if (!precached)
		{
			int len = strlen(sSound);
			if (len > 4 && !StrEqual(sSound[0], "#") && (StrEqual(sSound[len-3], "mp3") || StrEqual(sSound[len-3], "wav")))
			{
				PrecacheSoundAny(sSound);
				//Format(sSound, sizeof(sSound), "#%s", sSound);
				//SetEntPropString(entity, Prop_Data, "m_iszSound", sSound, sizeof(sSound));
				if (g_bDebug) {
					PrintToServer("[ToggleMusic] Updated: (%s)", sSound);
				}
			}
		}
    }
	precached = true;
}

public Action Command_StopMusic(int client, any args)
{
	// Prevent this command from being spammed.
	if (!client || g_fCmdTime[client] > GetGameTime())
		return Plugin_Handled;

	makeMusicMenu(client);

	g_fCmdTime[client] = GetGameTime() + 3.0;
 
	return Plugin_Handled;
}

public Action Command_Volume(int client, any args)
{
	// Prevent this command from being spammed.
	if (!client || g_fCmdTime[client] > GetGameTime())
		return Plugin_Handled;

	makeVolumeMenu(client);

	g_fCmdTime[client] = GetGameTime() + 3.0;
 
	return Plugin_Handled;
}

public int Music_Menu(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select && IsValidClient(client))
	{
		if (param == 0) {
			g_bDisabled[client] = true;
		} else if (param == 1) {
			g_bDisabled[client] = false;
		} else if (param == 3) {
			makeVolumeMenu(client);
			return;
		}
		
		char info[32];
		menu.GetItem(param, info, sizeof(info));
		PrintCenterText(client, "Map Music set to: %s", info);
		
		if (g_bDisabled[client]) {
			ClientStopSound(client);
		}
	} else if (action == MenuAction_End) {
		delete(menu);
	}
}

public int Volume_Menu(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select && IsValidClient(client))
	{
		if (param == 0) {
			g_fClientVol[client] = 1.0;
		} else if (param == 1) {
			g_fClientVol[client] = 0.75;
		} else if (param == 2) {
			g_fClientVol[client] = 0.5;
		} else if (param == 3) {
			g_fClientVol[client] = 0.25;
		} else if (param == 4) {
			g_fClientVol[client] = 0.1;
		} else if (param == 5) {
			g_fClientVol[client] = 0.05;
		}
		
		//Client_SetVolume(client, g_fClientVol[client]);
		/*char sCookieValue[12];
		FloatToString(g_fClientVol[client], sCookieValue, sizeof(sCookieValue));
		SetClientCookie(client, g_hClientVolCookie, sCookieValue);*/
		
		char info[32];
		menu.GetItem(param, info, sizeof(info));
		PrintCenterText(client, "Volume set to: %i%", RoundFloat(g_fClientVol[client]*100));

	} else if (action == MenuAction_Cancel && param == MenuCancel_ExitBack && IsValidClient(client)) {
		makeMusicMenu(client);
	} else if (action == MenuAction_End) {
		delete(menu);
	}
}

static void makeMusicMenu(int client)
{
	Menu musicMenu = CreateMenu(Music_Menu);
	
	char toggleSelection[32];
	if (g_bDisabled[client]) {
		toggleSelection = "Off";
	} else {
		toggleSelection = "On";
	}
	
	musicMenu.SetTitle("Map Music: %s Volume: %i%", toggleSelection, RoundFloat(g_fClientVol[client]*100));
	musicMenu.AddItem("off", "Off");
	musicMenu.AddItem("on", "On");
	musicMenu.AddItem("spacer1", "spacer1", ITEMDRAW_SPACER);
	musicMenu.AddItem("vol", "Volume");
	musicMenu.ExitButton = true;
	musicMenu.Display(client, 30);
}

static void makeVolumeMenu(int client)
{
	Menu volumeMenu = CreateMenu(Volume_Menu);
	volumeMenu.SetTitle("Volume: %i%", RoundFloat(g_fClientVol[client]*100));
	volumeMenu.AddItem("100", "100%");
	volumeMenu.AddItem("75", "75%");
	volumeMenu.AddItem("50", "50%");
	volumeMenu.AddItem("25", "25%");
	volumeMenu.AddItem("10", "10%");
	volumeMenu.AddItem("5", "5%");
	volumeMenu.ExitButton = true;
	volumeMenu.ExitBackButton = true;
	volumeMenu.Display(client, 30);
}

stock void ClientSendSound(int client, char[] name, float volume = 1.0)
{
	EmitSoundToClient(client, FakePrecacheSound(name), client, SNDCHAN_STATIC, SNDLEVEL_NORMAL, SND_NOFLAGS, volume, SNDPITCH_NORMAL, -1, _, _, true);
}

stock void ClientStopSound(int client, char[] name = "")
{
	if (name[0]) {
		StopSound(client, SNDCHAN_AUTO, FakePrecacheSound(name));
	} else {
		ClientCommand(client, "playgamesound Music.StopAllExceptMusic");
		ClientCommand(client, "playgamesound Music.StopAllMusic");
	}
}

stock static char FakePrecacheSound(const char[] sample)
{
	if (!StrEqual(sample[0], "*") && !StrEqual(sample[0], "#"))
	{
		char szSound[PLATFORM_MAX_PATH];
		Format(szSound, sizeof(szSound), "#%s", sample);
		return szSound;
	}
	return sample;
}

stock static bool IsValidClient(int client) {
	if (!IsClientInGame(client)) {
		return false;
	}
	return true;
}  
