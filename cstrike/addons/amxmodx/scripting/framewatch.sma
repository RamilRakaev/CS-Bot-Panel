#include <amxmodx>
#include <fakemeta>
#include <reapi>

new Float:g_Last
new Float:g_Max
new Float:g_Next
new g_Frames

public plugin_init() {
	register_plugin("Frame Watch", "1.0", "debug")
	register_forward(FM_StartFrame, "OnFrame")
	new msgid = get_user_msgid("TextMsg")
	if (msgid)
		register_message(msgid, "OnText")
	msgid = get_user_msgid("HudText")
	if (msgid)
		register_message(msgid, "OnHud")
	new Float:now = get_gametime()
	g_Last = now
	g_Next = now + 1.0
	LogFrame("init")
}

public OnFrame() {
	new Float:now = get_gametime()
	new Float:dt = now - g_Last
	g_Last = now
	if (dt > g_Max)
		g_Max = dt
	g_Frames++
	if (now < g_Next)
		return FMRES_IGNORED
	LogFrame("sec")
	g_Max = 0.0
	g_Frames = 0
	g_Next = now + 1.0
	return FMRES_IGNORED
}

public OnText(msgid, dest, id) {
	#pragma unused msgid, dest, id
	LogMsg(2)
	return PLUGIN_CONTINUE
}

public OnHud(msgid, dest, id) {
	#pragma unused msgid, dest, id
	LogMsg(1)
	return PLUGIN_CONTINUE
}

LogMsg(arg) {
	if (arg > get_msg_args())
		return
	new text[192]
	get_msg_arg_string(arg, text, charsmax(text))
	if (containi(text, "analy") == -1 && containi(text, "vistable") == -1 && containi(text, "graph") == -1 && containi(text, "Floyd") == -1 && containi(text, "sanity") == -1)
		return
	new map[32], data[256]
	get_mapname(map, charsmax(map))
	formatex(data, charsmax(data), "{^"map^":^"%s^",^"text^":^"%s^"}", map, text)
	// #region agent log
	WriteLog("B", "notice", data)
	// #endregion
}

LogFrame(const kind[]) {
	new map[32], data[360], cls[32]
	new gibs, boxes, guns, alive, nvg
	new ents = engfunc(EngFunc_NumberOfEntities)
	get_mapname(map, charsmax(map))
	for (new i = 1; i <= MaxClients; i++) {
		if (is_user_alive(i))
			alive++
		if (is_user_connected(i) && get_member(i, m_bNightVisionOn))
			nvg++
	}
	for (new e = MaxClients + 1; e < ents; e++) {
		if (!pev_valid(e))
			continue
		pev(e, pev_classname, cls, charsmax(cls))
		if (containi(cls, "gib") != -1)
			gibs++
		else if (equal(cls, "func_breakable"))
			boxes++
		else if (containi(cls, "weapon") != -1)
			guns++
	}
	formatex(data, charsmax(data), "{^"map^":^"%s^",^"kind^":^"%s^",^"t^":%d,^"maxMs^":%d,^"frames^":%d,^"players^":%d,^"alive^":%d,^"ents^":%d,^"gibs^":%d,^"boxes^":%d,^"guns^":%d,^"nvg^":%d}", map, kind, floatround(get_gametime()), floatround(g_Max * 1000.0), g_Frames, get_playersnum(), alive, ents, gibs, boxes, guns, nvg)
	// #region agent log
	WriteLog("A", "frame", data)
	// #endregion
}

WriteLog(const hid[], const message[], const data[]) {
	new line[512]
	formatex(line, charsmax(line), "{^"sessionId^":^"2d5647^",^"hypothesisId^":^"%s^",^"location^":^"framewatch.sma^",^"message^":^"%s^",^"data^":%s,^"timestamp^":%d}", hid, message, data, get_systime())
	WriteFile("addons/amxmodx/logs/debug-2d5647.log", line)
	WriteFile("../.cursor/debug-2d5647.log", line)
}

WriteFile(const path[], const line[]) {
	new file = fopen(path, "a")
	if (!file)
		return
	fprintf(file, "%s^n", line)
	fclose(file)
}
