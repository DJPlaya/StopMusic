/* Design

The ability to disable map music

Action:
0	Stop all Ambient_generics which contains .mp3
1	Stop all Ambient_generics which contains .wav & .mp3
2	Stop all Ambient_generics
	
Method:
0	Both
1	Music.StopAllMusic
2	Music.StopAllExceptMusic

*/
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <dhooks>
#include <clientprefs>

#define PLUGIN_NAME 	"Stop Map Music"
#define PLUGIN_VERSION 	"1.2.0"

new Float:g_fCmdTime[MAXPLAYERS+1];

new Handle:cDisableSounds = INVALID_HANDLE;
new Handle:cDisableSoundAction = INVALID_HANDLE;
new Handle:cDisableSoundMethod = INVALID_HANDLE;
new Handle:cDisableSoundSave = INVALID_HANDLE;

new bool:disabled[MAXPLAYERS + 1] = {false,...};
new bool:save[MAXPLAYERS + 1] = {false,...};
new action[MAXPLAYERS + 1] = {0,...};
new method[MAXPLAYERS + 1] = {0,...};

new Handle:hAcceptInput;

public Plugin:myinfo = {
	name = PLUGIN_NAME,
	author = "Mitch",
	description = "Allows clients to stop ambient sounds played by the map",
	version = PLUGIN_VERSION,
	url = "http://www.sourcemod.net/"
};

public OnPluginStart() {
	CreateConVar("sm_stopmusic_version", PLUGIN_VERSION, "Stop Map Music", FCVAR_PLUGIN|FCVAR_NOTIFY|FCVAR_DONTRECORD);

	RegConsoleCmd("sm_stopmusic", Command_StopMusic, "Toggles map music");
	RegConsoleCmd("sm_music", Command_Music, "Brings up the music menu");
	RegConsoleCmd("sm_startmusic", Command_StartMusic, "Toggles map music");
	RegConsoleCmd("sm_playmusic", Command_StartMusic, "Toggles map music");

	new Handle:temp = LoadGameConfigFile("stopmusic.games");

	if(temp == INVALID_HANDLE) {
		SetFailState("Why you no has gamedata?");
	}

	new offset = GameConfGetOffset(temp, "AcceptInput");
	hAcceptInput = DHookCreate(offset, HookType_Entity, ReturnType_Bool, ThisPointer_CBaseEntity, AcceptInput);
	DHookAddParam(hAcceptInput, HookParamType_CharPtr);
	DHookAddParam(hAcceptInput, HookParamType_CBaseEntity);
	DHookAddParam(hAcceptInput, HookParamType_CBaseEntity);
	DHookAddParam(hAcceptInput, HookParamType_Object, 20);
	DHookAddParam(hAcceptInput, HookParamType_Int);

	cDisableSounds = RegClientCookie("disable_map_music_2", "Disable Map Music", CookieAccess_Private);
	cDisableSoundAction = RegClientCookie("disable_map_music_action", "Disable Map Music Action", CookieAccess_Private);
	cDisableSoundMethod = RegClientCookie("disable_map_music_method", "Disable Map Music Method", CookieAccess_Private);
	cDisableSoundSave = RegClientCookie("disable_map_music_save", "Disable Map Music Save", CookieAccess_Private);
	SetCookieMenuItem(PrefMenu, 0, "Map Music");

	for(new i = 1; i <= MaxClients; i++) {
		disabled[i] = false;
		save[i] = false;
		action[i] = 0;
		method[i] = 0;
		if(IsClientInGame(i) && AreClientCookiesCached(i)) {
			OnClientCookiesCached(i);
		}
	}
}

public PrefMenu(client, CookieMenuAction:actions, any:info, String:buffer[], maxlen){
	if (actions == CookieMenuAction_SelectOption) {
		DisplaySettingsMenu(client);
	}
}

public PrefMenuHandler(Handle:prefmenu, MenuAction:actions, client, item){
	if (actions == MenuAction_Select) {
		decl String:preference[8];
		
		GetMenuItem(prefmenu, item, preference, sizeof(preference));
		
		if(StrEqual(preference, "disable")) {
			disabled[client] = true;
			PrintToChat(client, "[SM] Map music Disabled.");
			SetClientCookie(client, cDisableSounds, "1");
			stopClientsMusic(client);
		} else if(StrEqual(preference, "enable")) {
			disabled[client] = false;
			PrintToChat(client, "[SM] Map music Enabled.");
			SetClientCookie(client, cDisableSounds, "0");
		}
		
		if(StrContains(preference, "mthd") >= 0) {
			method[client] = StringToInt(preference[5]);
			SetClientCookie(client, cDisableSoundMethod, preference[5]);
		}
		if(StrContains(preference, "actn") >= 0) {
			action[client] = StringToInt(preference[5]);
			SetClientCookie(client, cDisableSoundAction, preference[5]);
		}
		if(StrContains(preference, "save") >= 0) {
			save[client] = bool:StringToInt(preference[5]);
			SetClientCookie(client, cDisableSoundSave, preference[5]);
			PrintToChat(client, "[SM] Saving music settings %s.", save[client] ? "enabled" : "disabled");
			
		}
		DisplaySettingsMenu(client);
	}
	else if (actions == MenuAction_End) {
		CloseHandle(prefmenu);
	}
}

DisplaySettingsMenu(client) {
	new Handle:prefmenu = CreateMenu(PrefMenuHandler, MENU_ACTIONS_DEFAULT);

	SetMenuTitle(prefmenu, "Map Music: ");

	AddMenuItem(prefmenu, disabled[client] ? "enable" : "disable", disabled[client] ? "Enable Music" : "Disable Music");
	
	AddMenuItem(prefmenu, save[client] ? "save_0" : "save_1", save[client] ? "Disable Saving" : "Enable Saving");
	
	switch(action[client]) {
		case 0: {
			AddMenuItem(prefmenu, "actn_1", "Action: mp3");
		}
		case 1: {
			AddMenuItem(prefmenu, "actn_2", "Action: wav & mp3");
		}
		case 2: {
			AddMenuItem(prefmenu, "actn_0", "Action: Stop All");
		}
	}
	
	switch(method[client]) {
		case 0: {
			AddMenuItem(prefmenu, "mthd_1", "Method: Both");
		}
		case 1: {
			AddMenuItem(prefmenu, "mthd_2", "Method: StopAllMusic");
		}
		case 2: {
			AddMenuItem(prefmenu, "mthd_0", "Method: StopAllExceptMusic");
		}
	}

	DisplayMenu(prefmenu, client, MENU_TIME_FOREVER);
}

public OnClientCookiesCached(client) {
	decl String:sValue[8];
	GetClientCookie(client, cDisableSoundSave, sValue, sizeof(sValue));
	save[client] = bool:StringToInt(sValue);
	if(save[client]) {
		GetClientCookie(client, cDisableSounds, sValue, sizeof(sValue));
		disabled[client] = bool:StringToInt(sValue);
	}
	GetClientCookie(client, cDisableSoundAction, sValue, sizeof(sValue));
	action[client] = StringToInt(sValue);
	GetClientCookie(client, cDisableSoundMethod, sValue, sizeof(sValue));
	method[client] = StringToInt(sValue);
}

public OnClientDisconnect_Post(client) {
	g_fCmdTime[client] = 0.0;
	disabled[client] = false;
	action[client] = 0;
	method[client] = 0;
}

public MRESReturn:AcceptInput(pThis, Handle:hReturn, Handle:hParams) {
	new String:command[PLATFORM_MAX_PATH];
	DHookGetParamString(hParams, 1, command, sizeof(command));
	if(StrEqual(command, "PlaySound", false) && IsValidEntity(pThis)) {
		new actionType = 2;
		decl String:soundFile[PLATFORM_MAX_PATH];
		GetEntPropString(pThis, Prop_Data, "m_iszSound", soundFile, sizeof(soundFile));
		if(StrContains(soundFile, ".mp3", false) >= 0) {
			actionType = 0;
		}
		if(StrContains(soundFile, ".wav", false) >= 0) {
			actionType = 1;
		}
		SetEntProp(pThis, Prop_Data, "m_fLooping", false);
		for(new i = 1; i <= MaxClients;i++) {
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

public Action:Timer_StopMusic(Handle:timer, any:userid)  {
	new client = GetClientOfUserId(userid);
	if(client && IsClientInGame(client)) {
		stopClientsMusic(client);
	}
}

public OnEntityCreated(entity, const String:classname[]) {
	if(StrEqual(classname, "ambient_generic", false)){
		SetEntProp(entity, Prop_Data, "m_spawnflags", GetEntProp(entity, Prop_Data, "m_spawnflags")|32);
		DHookEntity(hAcceptInput, true, entity);
	}
}

public Action:Command_StopMusic(client, args) {
	// Prevent this command from being spammed.
	if (!client || g_fCmdTime[client] > GetGameTime())
		return Plugin_Handled;
	g_fCmdTime[client] = GetGameTime() + 2.0;

	if(args >= 1) {
		new String:arg1[6];
		GetCmdArg(1, arg1, sizeof(arg1));
		if(StrEqual(arg1, "0", false) || StrEqual(arg1, "allow", false)) { //Allow map music
			disabled[client] = true;
		} else {
			disabled[client] = false;
		}
	}

	if(disabled[client]){
		disabled[client] = false;
		PrintToChat(client, "[SM] Map music Enabled.");
		return Plugin_Handled;
	}

	PrintToChat(client, "[SM] Map music Disabled.");
	SetClientCookie(client, cDisableSounds, (!disabled[client]) ? "1" : "0");
	stopClientsMusic(client);
	disabled[client] = true;
	return Plugin_Handled;
}

public Action:Command_StartMusic(client, args) {
	// Prevent this command from being spammed.
	if (!client || g_fCmdTime[client] > GetGameTime())
		return Plugin_Handled;
	g_fCmdTime[client] = GetGameTime() + 2.0;

	disabled[client] = false;
	PrintToChat(client, "[SM] Map music Enabled.");
	return Plugin_Handled;
}

public Action:Command_Music(client, args) {
	// Prevent this command from being spammed.
	if (!client || g_fCmdTime[client] > GetGameTime())
		return Plugin_Handled;
	g_fCmdTime[client] = GetGameTime() + 2.0;

	DisplaySettingsMenu(client);
	return Plugin_Handled;
}

stock stopClientsMusic(client) {
	if(method[client] == 0 || method[client] == 1) {
		ClientCommand(client, "playgamesound Music.StopAllExceptMusic");
	}
	if(method[client] == 0 || method[client] == 2) {
		ClientCommand(client, "playgamesound Music.StopAllMusic");
	}
}
