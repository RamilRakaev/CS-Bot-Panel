#include <amxmodx>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>

#define PLUGIN_NAME "Deathmatch"
#define MODE_OFF 0
#define MODE_DM 1
#define MODE_TDM 2
#define TASK_EQUIP 5000
#define MAX_SPAWNS 128
#define SPAWN_GAP 400.0

enum _:CvarId {
	C_FFA = 0,
	C_FORCE,
	C_RESPAWN,
	C_INFINITE,
	C_BOT,
	C_YAPB,
	C_POD,
	C_BUYTIME,
	C_BUYANY,
	C_FF,
	C_NUM
}

new g_Mode
new g_Cvar
new g_Zombie
new bool:g_Lock
new bool:g_Keep
new bool:g_HasCvar[C_NUM]
new g_Old[C_NUM][32]
new Float:g_Origin[MAX_SPAWNS][3]
new Float:g_Angles[MAX_SPAWNS][3]
new g_Spawns

new const g_CvarName[C_NUM][] = {
	"mp_freeforall",
	"mp_forcerespawn",
	"mp_roundrespawn_time",
	"mp_round_infinite",
	"bot_deathmatch",
	"yb_csdm_mode",
	"pb_ffa",
	"mp_buytime",
	"mp_buy_anywhere",
	"mp_friendlyfire"
}

new const g_Primary[][] = {
	"weapon_ak47",
	"weapon_m4a1",
	"weapon_aug",
	"weapon_sg552",
	"weapon_galil",
	"weapon_famas",
	"weapon_awp",
	"weapon_scout",
	"weapon_sg550",
	"weapon_g3sg1",
	"weapon_m249",
	"weapon_p90",
	"weapon_mp5navy",
	"weapon_ump45",
	"weapon_tmp",
	"weapon_mac10",
	"weapon_m3",
	"weapon_xm1014"
}

new const g_Pistol[][] = {
	"weapon_usp",
	"weapon_glock18",
	"weapon_deagle",
	"weapon_p228",
	"weapon_elite",
	"weapon_fiveseven"
}

public plugin_init() {
	register_plugin(PLUGIN_NAME, "1.0", "Admin")

	g_Cvar = register_cvar("dm_mode", "0")
	hook_cvar_change(g_Cvar, "OnModeCvar")
	register_clcmd("dm_toggle", "CmdToggle")

	g_Zombie = get_cvar_pointer("zombie_mode")
	if (g_Zombie)
		hook_cvar_change(g_Zombie, "OnZombieCvar")

	RegisterHamPlayer(Ham_Spawn, "OnSpawn", 1)
	RegisterHookChain(RG_CBasePlayer_GiveNamedItem, "OnGive")
	WriteMode(MODE_OFF)
}

public plugin_cfg() {
	CollectSpawns()
}

public client_disconnected(id) {
	remove_task(TASK_EQUIP + id)
}

public CmdToggle(id) {
	if (!CanUse(id)) {
		Tell(id, "[Deathmatch] Нет доступа")
		return PLUGIN_HANDLED
	}

	new arg[8]
	read_argv(1, arg, charsmax(arg))
	new want = str_to_num(arg)
	if (want != MODE_DM && want != MODE_TDM)
		return PLUGIN_HANDLED

	if (g_Mode == want)
		Disable()
	else
		Enable(id, want)
	return PLUGIN_HANDLED
}

public OnModeCvar(pcvar, const oldValue[], const newValue[]) {
	#pragma unused pcvar, oldValue
	if (g_Lock)
		return
	if (str_to_num(newValue) == g_Mode)
		return
	WriteMode(g_Mode)
}

public OnZombieCvar(pcvar, const oldValue[], const newValue[]) {
	#pragma unused pcvar, oldValue
	if (str_to_num(newValue) == 1 && g_Mode)
		Disable()
}

public OnSpawn(id) {
	if (!g_Mode || !Playing(id))
		return
	remove_task(TASK_EQUIP + id)
	set_task(0.1, "Equip", TASK_EQUIP + id)
}

public Equip(taskid) {
	new id = taskid - TASK_EQUIP
	if (!g_Mode || !Playing(id) || !is_user_alive(id))
		return
	if (g_Mode == MODE_DM)
		GiveDm(id)
	else
		GiveTdm(id)
}

public OnGive(id, const item[]) {
	#pragma unused id
	if (g_Mode == MODE_DM && equal(item, "weapon_c4"))
		return HC_SUPERCEDE
	return HC_CONTINUE
}

Enable(id, mode) {
	if (g_Zombie && get_pcvar_num(g_Zombie) && is_user_connected(id))
		engclient_cmd(id, "zombie_toggle")

	if (!g_Keep)
		SaveCvars()
	g_Mode = mode
	WriteMode(mode)
	ApplyCvars(mode)
	RespawnAll()
	if (mode == MODE_DM)
		Announce("[Deathmatch] Режим включен")
	else
		Announce("[Team deathmatch] Режим включен")
}

Disable() {
	new was = g_Mode
	g_Mode = MODE_OFF
	WriteMode(MODE_OFF)
	for (new i = 1; i <= MaxClients; i++)
		remove_task(TASK_EQUIP + i)
	RestoreCvars()
	if (was == MODE_DM)
		Announce("[Deathmatch] Режим выключен")
	else if (was == MODE_TDM)
		Announce("[Team deathmatch] Режим выключен")
}

SaveCvars() {
	for (new i = 0; i < C_NUM; i++) {
		g_HasCvar[i] = bool:cvar_exists(g_CvarName[i])
		if (g_HasCvar[i])
			get_cvar_string(g_CvarName[i], g_Old[i], charsmax(g_Old[]))
	}
	g_Keep = true
}

RestoreCvars() {
	if (!g_Keep)
		return
	for (new i = 0; i < C_NUM; i++) {
		if (g_HasCvar[i])
			set_cvar_string(g_CvarName[i], g_Old[i])
	}
	g_Keep = false
}

ApplyCvars(mode) {
	SetCvar(C_FORCE, "2")
	SetCvar(C_RESPAWN, "-1")
	SetCvar(C_INFINITE, "efg")
	SetCvar(C_BOT, "1")
	if (mode == MODE_DM) {
		SetCvar(C_FFA, "1")
		SetCvar(C_YAPB, "2")
		SetCvar(C_POD, "1")
		SetCvar(C_BUYTIME, g_Old[C_BUYTIME])
		SetCvar(C_BUYANY, g_Old[C_BUYANY])
		SetCvar(C_FF, g_Old[C_FF])
	} else {
		SetCvar(C_FFA, "0")
		SetCvar(C_YAPB, "1")
		SetCvar(C_POD, "0")
		SetCvar(C_BUYTIME, "999")
		SetCvar(C_BUYANY, "1")
		SetCvar(C_FF, "0")
	}
}

SetCvar(id, const value[]) {
	if (g_HasCvar[id] && value[0])
		set_cvar_string(g_CvarName[id], value)
}

RespawnAll() {
	for (new i = 1; i <= MaxClients; i++) {
		if (!Playing(i))
			continue
		rg_round_respawn(i)
	}
}

GiveDm(id) {
	if (!g_Spawns)
		CollectSpawns()
	MoveRandom(id)

	rg_remove_all_items(id)
	rg_remove_item(id, "weapon_c4", true)
	rg_give_item(id, "weapon_knife")

	new primary[24]
	copy(primary, charsmax(primary), g_Primary[random_num(0, sizeof g_Primary - 1)])
	new pistol[24]
	copy(pistol, charsmax(pistol), g_Pistol[random_num(0, sizeof g_Pistol - 1)])
	GiveGun(id, primary)
	GiveGun(id, pistol)
	rg_give_item(id, "weapon_hegrenade")
	rg_give_item(id, "weapon_flashbang")
	rg_give_item(id, "weapon_flashbang")
	rg_give_item(id, "weapon_smokegrenade")
	rg_set_user_armor(id, 100, ARMOR_VESTHELM)

	new weapon = rg_find_weapon_bpack_by_name(id, primary)
	if (weapon)
		rg_switch_weapon(id, weapon)
}

GiveTdm(id) {
	rg_give_default_items(id)
	cs_set_user_money(id, MaxMoney(), 1)
}

GiveGun(id, const name[]) {
	rg_give_item(id, name)
	new WeaponIdType:wid = WeaponIdType:rg_get_weapon_info(name, WI_ID)
	new clip = rg_get_weapon_info(wid, WI_GUN_CLIP_SIZE)
	new pack = rg_get_weapon_info(wid, WI_MAX_ROUNDS)
	if (clip > 0)
		rg_set_user_ammo(id, wid, clip)
	if (pack > 0)
		rg_set_user_bpammo(id, wid, pack)
}

MoveRandom(id) {
	new spot
	if (!PickSpot(id, spot))
		return
	new Float:origin[3], Float:angles[3], Float:zero[3]
	origin[0] = g_Origin[spot][0]
	origin[1] = g_Origin[spot][1]
	origin[2] = g_Origin[spot][2]
	angles[0] = g_Angles[spot][0]
	angles[1] = g_Angles[spot][1]
	angles[2] = g_Angles[spot][2]
	engfunc(EngFunc_SetOrigin, id, origin)
	set_pev(id, pev_origin, origin)
	set_pev(id, pev_angles, angles)
	set_pev(id, pev_v_angle, angles)
	set_pev(id, pev_fixangle, 1)
	set_pev(id, pev_velocity, zero)
}

bool:PickSpot(id, &choice) {
	if (!g_Spawns)
		return false

	new tr = create_tr2()
	new ideal[MAX_SPAWNS], idealCount
	new best = -1
	new Float:bestDist

	for (new i = 0; i < g_Spawns; i++) {
		if (Blocked(g_Origin[i], tr))
			continue
		new Float:near = Nearest(g_Origin[i], id)
		if (best < 0 || near > bestDist) {
			bestDist = near
			best = i
		}
		if (near >= SPAWN_GAP && !Seen(g_Origin[i], id, tr))
			ideal[idealCount++] = i
	}
	free_tr2(tr)

	if (idealCount > 0) {
		choice = ideal[random_num(0, idealCount - 1)]
		return true
	}
	if (best >= 0) {
		choice = best
		return true
	}
	choice = random_num(0, g_Spawns - 1)
	return true
}

bool:Blocked(const Float:spot[3], tr) {
	new Float:end[3]
	end[0] = spot[0]
	end[1] = spot[1]
	end[2] = spot[2] + 1.0
	engfunc(EngFunc_TraceHull, spot, end, IGNORE_MONSTERS, HULL_HUMAN, 0, tr)
	return bool:get_tr2(tr, TR_StartSolid)
}

bool:Seen(const Float:spot[3], id, tr) {
	new Float:start[3], Float:end[3], Float:view[3]
	start[0] = spot[0]
	start[1] = spot[1]
	start[2] = spot[2] + 36.0
	for (new i = 1; i <= MaxClients; i++) {
		if (i == id || !is_user_alive(i))
			continue
		pev(i, pev_origin, end)
		pev(i, pev_view_ofs, view)
		end[0] += view[0]
		end[1] += view[1]
		end[2] += view[2]
		engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, id, tr)
		new Float:fraction
		get_tr2(tr, TR_flFraction, fraction)
		if (fraction >= 0.97)
			return true
	}
	return false
}

Float:Nearest(const Float:spot[3], id) {
	new Float:best = 99999.0
	new Float:origin[3]
	new bool:any
	for (new i = 1; i <= MaxClients; i++) {
		if (i == id || !is_user_alive(i))
			continue
		pev(i, pev_origin, origin)
		new Float:dist = Dist(spot, origin)
		if (!any || dist < best) {
			best = dist
			any = true
		}
	}
	return best
}

Float:Dist(const Float:a[3], const Float:b[3]) {
	new Float:dx = a[0] - b[0]
	new Float:dy = a[1] - b[1]
	new Float:dz = a[2] - b[2]
	return floatsqroot(dx * dx + dy * dy + dz * dz)
}

CollectSpawns() {
	g_Spawns = 0
	AddClass("info_player_start")
	AddClass("info_player_deathmatch")
}

AddClass(const classname[]) {
	new ent = -1
	while (g_Spawns < MAX_SPAWNS) {
		ent = find_ent_by_class(ent, classname)
		if (!ent)
			break
		pev(ent, pev_origin, g_Origin[g_Spawns])
		pev(ent, pev_angles, g_Angles[g_Spawns])
		g_Spawns++
	}
}

bool:Playing(id) {
	if (!is_user_connected(id) || is_user_hltv(id))
		return false
	new CsTeams:team = cs_get_user_team(id)
	return bool:(team == CS_TEAM_CT || team == CS_TEAM_T)
}

bool:CanUse(id) {
	if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
		return false
	if (!is_dedicated_server())
		return true
	return bool:(get_user_flags(id) & ADMIN_MENU)
}

MaxMoney() {
	if (cvar_exists("mp_maxmoney")) {
		new maxMoney = get_cvar_num("mp_maxmoney")
		if (maxMoney > 0)
			return maxMoney
	}
	return 16000
}

WriteMode(value) {
	g_Lock = true
	set_pcvar_num(g_Cvar, value)
	g_Lock = false
}

Announce(const msg[]) {
	client_print(0, print_chat, "%s", msg)
	server_print("%s", msg)
}

Tell(id, const msg[]) {
	client_print(id, print_chat, "%s", msg)
}
