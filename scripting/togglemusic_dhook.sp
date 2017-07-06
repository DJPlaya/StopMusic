#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <clientprefs>
//#include <emitsoundany>

#pragma newdecls required

#define PLUGIN_NAME 	"Toggle Music"
#define PLUGIN_VERSION 	"3.6"

//Create ConVar handles
Handle g_hClientVolCookie;
Handle g_hClientMusicCookie;
Handle hAcceptInput;

//Global Handles & Variables
float g_fCmdTime[MAXPLAYERS+1];
float g_fClientVol[MAXPLAYERS+1];
bool g_bDisabled[MAXPLAYERS + 1];
StringMap g_smSourceEnts;
StringMap g_smCommon;
StringMap g_smRecent;

public Plugin myinfo =
{
	name = PLUGIN_NAME,
	author = "Mitch & Agent Wesker",
	description = "Allows clients to toggle ambient sounds played by the map",
	version = PLUGIN_VERSION,
	url = "https://www.steam-gamers.net/"
};

public void OnPluginStart()
{
	CreateConVar("sm_togglemusic_version", PLUGIN_VERSION, "Toggle Map Music", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	RegConsoleCmd("sm_music", Command_Music, "Toggles map music");
	RegConsoleCmd("sm_stopmusic", Command_StopMusic, "Toggles map music");
	RegConsoleCmd("sm_volume", Command_Volume, "Brings volume menu");

	if (g_smSourceEnts == null)
		g_smSourceEnts = new StringMap();
	
	if (g_smCommon == null)
		g_smCommon = new StringMap();
	
	if (g_smRecent == null)
		g_smRecent = new StringMap();
	
	if (g_hClientVolCookie == null)
		g_hClientVolCookie = RegClientCookie("togglemusic_volume", "ToggleMusic Volume Pref", CookieAccess_Protected);
		
	if (g_hClientMusicCookie == null)
		g_hClientMusicCookie = RegClientCookie("togglemusic_music", "ToggleMusic Music Pref", CookieAccess_Protected);
	
	if (hAcceptInput == null)
	{
	
		Handle temp = LoadGameConfigFile("sdktools.games\\engine.csgo");
	
		if(temp == null) {
			SetFailState("Why you no has gamedata?");
		}
	
		//HookEvent("round_start", Event_RoundStart);
		
		int offset = GameConfGetOffset(temp, "AcceptInput");
		hAcceptInput = DHookCreate(offset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity, AcceptInput);
		DHookAddParam(hAcceptInput, HookParamType_CharPtr);
		DHookAddParam(hAcceptInput, HookParamType_CBaseEntity);
		DHookAddParam(hAcceptInput, HookParamType_CBaseEntity);
		DHookAddParam(hAcceptInput, HookParamType_Object, 20);
		DHookAddParam(hAcceptInput, HookParamType_Int);
		
		delete temp;
	}
	
	//Set volume level to default (late load)
	for (int j = 1; j <= MaxClients; j++) {
		OnClientPostAdminCheck(j);
	}
}

public void OnMapStart()
{	
	g_smSourceEnts.Clear();
	g_smCommon.Clear();
	g_smRecent.Clear();
}

public void OnClientCookiesCached(int client)
{
	OnClientPostAdminCheck(client);
	if (g_bDisabled[client])
		CreateTimer(7.0, ClientMusicNotice, client);
}

public void OnClientPostAdminCheck(int client)
{
	if (AreClientCookiesCached(client))
	{
		char sCookieValue[12];
		GetClientCookie(client, g_hClientVolCookie, sCookieValue, sizeof(sCookieValue));
		if (sCookieValue[0])
		{
			g_fClientVol[client] = StringToFloat(sCookieValue);
		} else {
			g_fClientVol[client] = 1.0;
		}
		sCookieValue = "";
		GetClientCookie(client, g_hClientMusicCookie, sCookieValue, sizeof(sCookieValue));
		if (sCookieValue[0])
		{
			if (StringToInt(sCookieValue) > 0)
			{
				g_bDisabled[client] = true;
				
			} else {
				g_bDisabled[client] = false;
			}
		} else {
			g_bDisabled[client] = false;
		}
		return;
	}
	g_fClientVol[client] = 1.0;
	g_bDisabled[client] = false;
}

public Action ClientMusicNotice(Handle timer, int client)
{
	PrintToChat(client, "[ToggleMusic] Music is currently disabled, type !music for options");
}

public void OnClientDisconnect_Post(int client)
{
	g_fCmdTime[client] = 0.0;
}

//Return types
//https://wiki.alliedmods.net/Sourcehook_Development#Hook_Functions
//
public MRESReturn AcceptInput(int entity, Handle hReturn, Handle hParams)
{
	char eCommand[128], eParam[128], soundFile[PLATFORM_MAX_PATH];
	DHookGetParamString(hParams, 1, eCommand, sizeof(eCommand));
	DHookGetParamObjectPtrString(hParams, 4, 0, ObjectValueType_String, eParam, sizeof(eParam));
	GetEntPropString(entity, Prop_Data, "m_iszSound", soundFile, sizeof(soundFile));
	//Debug
	//PrintToServer("Cmd %s Name %s Param %s Song %s", eCommand, eName, eParam, soundFile);

	if (StrEqual(eCommand, "PlaySound", false) && IsValidEntity(entity))
	{
		int temp;
		if (g_smRecent.GetValue(soundFile, temp))
		{
			g_smRecent.Remove(soundFile);
			g_smCommon.SetValue(soundFile, 1, true);
			AddToStringTable( FindStringTable( "soundprecache" ), FakePrecacheSound(soundFile, true) );
			PrecacheSound(FakePrecacheSound(soundFile, true), false);
			//Debug
			//PrintToServer("COMMON SOUND DETECTED %s", soundFile);
		}
		bool common = g_smCommon.GetValue(soundFile, temp);
		SendSoundAll(soundFile, entity, common);

		if (!common)
		{
			g_smRecent.SetValue(soundFile, 1, true);
			DataPack dataPack;
			CreateDataTimer(1.5, CheckCommonSounds, dataPack);
			dataPack.WriteString(soundFile);
			dataPack.WriteCell(entity);
		}
		DHookSetReturn(hReturn, false);
		return MRES_Supercede;
	} 
	else if (StrEqual(eCommand, "StopSound", false) || (StrEqual(eCommand, "Volume", false) && StrEqual(eParam, "0", false)))
	{
		int temp;
		bool common = g_smCommon.GetValue(soundFile, temp);	
		StopSoundAll(soundFile, entity, common);
		return MRES_Ignored;
	}
	
	return MRES_Ignored;
}

public int GetSourceEntity(int entity)
{
	char seName[64];
	GetEntPropString(entity, Prop_Data, "m_sSourceEntName", seName, sizeof(seName));
	if (seName[0])
	{
		int entRef;
		if (g_smSourceEnts.GetValue(seName, entRef))
		{
			int sourceEnt = EntRefToEntIndex(entRef);
			if (IsValidEntity(sourceEnt))
			{
				return sourceEnt;
			}
		}
	}
	return entity;
}

public Action CheckCommonSounds(Handle timer, DataPack dataPack)
{
	dataPack.Reset();
	char soundFile[PLATFORM_MAX_PATH];
	dataPack.ReadString(soundFile, sizeof(soundFile));
	g_smRecent.Remove(soundFile);
	int temp;
	if (g_smCommon.GetValue(soundFile, temp))
	{
		temp = dataPack.ReadCell();			
		StopSoundAll(soundFile, temp, false);
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "ambient_generic", false))
	{
		//Is this a valid entity?
		if (IsValidEdict(entity))
		{
				DHookEntity(hAcceptInput, false, entity);
				//Hook the entity, we must wait until post spawn
				SDKHook(entity, SDKHook_SpawnPost, OnEntitySpawned);
		}
	}
}

public void OnEntitySpawned(int entity)
{
	char sSound[PLATFORM_MAX_PATH], seName[64], eName[64];
	GetEntPropString(entity, Prop_Data, "m_iszSound", sSound, sizeof(sSound));
	GetEntPropString(entity, Prop_Data, "m_sSourceEntName", seName, sizeof(seName));
	int eFlags = GetEntProp(entity, Prop_Data, "m_spawnflags");
	int len = strlen(sSound);
	
	if (len > 4 && (StrEqual(sSound[len-3], "mp3") || StrEqual(sSound[len-3], "wav")))
	{
		int temp;
		bool common = g_smCommon.GetValue(sSound, temp);
		AddToStringTable( FindStringTable( "soundprecache" ), FakePrecacheSound(sSound, common) );
		PrecacheSound(FakePrecacheSound(sSound, common), false);
	}
	
	if (!(eFlags & 1) && seName[0])
	{
		for (int i = 0; i <= GetEntityCount(); i++)
		{
			if (IsValidEntity(i))
			{
				GetEntPropString(i, Prop_Data, "m_iName", eName, sizeof(eName));
				if (StrEqual(seName, eName, false))
				{
					g_smSourceEnts.SetValue(seName, EntIndexToEntRef(i), true);
					return;
				}
			}
		}
	}
}

public Action Command_Music(int client, any args)
{
	// Prevent this command from being spammed.
	if (!client || g_fCmdTime[client] > GetGameTime())
		return Plugin_Handled;

	makeMusicMenu(client);

	g_fCmdTime[client] = GetGameTime() + 1.5;
 
	return Plugin_Handled;
}

public Action Command_StopMusic(int client, any args)
{
	// Prevent this command from being spammed.
	if (!client || g_fCmdTime[client] > GetGameTime())
		return Plugin_Handled;

	ClientStopSound(client);
	PrintToChat(client, "[ToggleMusic] Stopped Music ~ Type !music or !volume for more options");

	g_fCmdTime[client] = GetGameTime() + 1.5;
 
	return Plugin_Handled;
}

public Action Command_Volume(int client, any args)
{
	// Prevent this command from being spammed.
	if (!client || g_fCmdTime[client] > GetGameTime())
		return Plugin_Handled;

	makeVolumeMenu(client);

	g_fCmdTime[client] = GetGameTime() + 1.5;
 
	return Plugin_Handled;
}

public int Music_Menu(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select && IsValidClient(client))
	{
		if (param == 0) {
			g_bDisabled[client] = true;
			char sCookieValue[12];
			IntToString(1, sCookieValue, sizeof(sCookieValue));
			SetClientCookie(client, g_hClientMusicCookie, sCookieValue);
		} else if (param == 1) {
			g_bDisabled[client] = false;
			char sCookieValue[12];
			IntToString(0, sCookieValue, sizeof(sCookieValue));
			SetClientCookie(client, g_hClientMusicCookie, sCookieValue);
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
		
		char sCookieValue[12];
		FloatToString(g_fClientVol[client], sCookieValue, sizeof(sCookieValue));
		SetClientCookie(client, g_hClientVolCookie, sCookieValue);
		
		char info[32];
		menu.GetItem(param, info, sizeof(info));
		PrintCenterText(client, "Volume set to: %i%", RoundFloat(g_fClientVol[client]*100));
		PrintToChat(client, "[ToggleMusic] Volume will be updated on the next song");

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

stock void SendSoundAll(char[] name, int entity, bool common = false)
{
	if (IsValidEntity(entity))
	{
		int eFlags = GetEntProp(entity, Prop_Data, "m_spawnflags");
		if (eFlags & 1)
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!g_bDisabled[i] && IsValidClient(i))
				{
					EmitSoundToClient(i, FakePrecacheSound(name, common), i, SNDCHAN_USER_BASE, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fClientVol[i], SNDPITCH_NORMAL, -1, _, _, true);
				}
			}
		} else {
			int sourceEnt = GetSourceEntity(entity);			
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!g_bDisabled[i] && IsValidClient(i))
				{
					EmitSoundToClient(i, FakePrecacheSound(name, common), sourceEnt, SNDCHAN_USER_BASE, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fClientVol[i], SNDPITCH_NORMAL, -1, _, _, true);
				}
			}
		}
	}
}

stock void ClientStopSound(int client, char[] name = "", bool common = false)
{
	if (name[0]) {
		StopSound(client, SNDCHAN_USER_BASE, FakePrecacheSound(name, common));
	} else {
		ClientCommand(client, "playgamesound Music.StopAllExceptMusic");
		ClientCommand(client, "playgamesound Music.StopAllMusic");
	}
}

stock static void StopSoundAll(char[] name, int entity, bool common = false)
{
	if (IsValidEntity(entity))
	{
		int eFlags = GetEntProp(entity, Prop_Data, "m_spawnflags");
		if (eFlags & 1)
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!g_bDisabled[i] && IsValidClient(i)) {
					ClientStopSound(i, name, common);
				}
			}
		}
		else
		{
			int sourceEnt = GetSourceEntity(entity);
			StopSound(sourceEnt, SNDCHAN_USER_BASE, FakePrecacheSound(name, common));
		}
	}
}

stock static char[] FakePrecacheSound(const char[] sample, const bool common = false)
{
	char szSound[PLATFORM_MAX_PATH];
	strcopy(szSound, sizeof(szSound), sample);
	if (szSound[0] != '*' && szSound[0] != '#')
	{
		if (!common)
		{
			Format(szSound, sizeof(szSound), "#%s", szSound);
		}
		else 
		{
			Format(szSound, sizeof(szSound), "*%s", szSound);
		}
	}
	return szSound;
}

stock static bool IsValidClient(int client) {
	if (!IsClientInGame(client)) {
		return false;
	}
	return true;
}  
