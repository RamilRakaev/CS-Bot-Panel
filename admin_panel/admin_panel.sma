#include <amxmodx>
#include <cstrike>
#include <fakemeta>
#include <reapi>

#define PLUGIN_NAME "Admin Panel"
#define MENU_NAME "AdminPanel"
#define MENU_TIME 60
#define BOT_LIMIT 64
#define PAGE_SIZE 6

enum {
	ST_MAIN = 0,
	ST_MORE,
	ST_SLAP,
	ST_GIVE,
	ST_TAKE,
	ST_SKILL,
	ST_PERSON,
	ST_TEAM,
	ST_LIST
}

enum {
	KIND_VALVE = 0,
	KIND_YAPB,
	KIND_POD
}

enum {
	LIST_SWAP = 0,
	LIST_SLAP,
	LIST_KILL,
	LIST_KICK,
	LIST_GIVE,
	LIST_TAKE
}

new g_State[33]
new g_List[33]
new g_Page[33]
new g_Amount[33]
new g_Kind[33]
new g_Skill[33]
new g_Person[33]
new g_Slot[33][PAGE_SIZE]
new g_Shown[33]
new g_HasNext[33]
new g_HasPrev[33]
new g_MsgDamage
new g_MsgHealth
new g_MsgShake
new g_BloodSpray
new g_BloodDrop
new g_Vacate
new bool:g_Locking
new bool:g_Ready
new bool:g_BotsStopped

public plugin_precache() {
	g_BloodSpray = precache_model("sprites/bloodspray.spr")
	g_BloodDrop = precache_model("sprites/blood.spr")
	precache_sound("weapons/knife_stab.wav")
	precache_sound("player/bhit_helmet-1.wav")
	precache_sound("player/bhit_flesh-1.wav")
	precache_sound("player/bhit_flesh-2.wav")
	precache_sound("player/bhit_flesh-3.wav")
}

public plugin_init() {
	register_plugin(PLUGIN_NAME, "1.0", "Admin")

	register_clcmd("say", "OnSay")
	register_clcmd("say_team", "OnSay")
	register_clcmd("admin", "CmdMenu")

	register_menucmd(register_menuid(MENU_NAME), 1023, "OnMenu")

	g_MsgDamage = get_user_msgid("Damage")
	g_MsgHealth = get_user_msgid("Health")
	g_MsgShake = get_user_msgid("ScreenShake")
	g_Vacate = get_cvar_pointer("bot_auto_vacate")

	register_forward(FM_CmdStart, "OnBotMove")

	RegisterHookChain(RG_CSGameRules_BalanceTeams, "BlockBalance")
	RegisterHookChain(RG_CSGameRules_RestartRound, "OnRoundReady", true)

	HookZero("mp_autoteambalance")
	HookZero("mp_limitteams")
	HookZero("mp_kill_filled_spawn")
	if (g_Vacate)
		hook_cvar_change(g_Vacate, "OnForcedCvar")

	register_forward(FM_StartFrame, "OnFrame")
}

public plugin_cfg() {
	g_Ready = true
	server_cmd("pb removebots")
	server_exec()
	LockRules()
}

public OnFrame() {
	if (g_Ready)
		LockRules()
}

public OnBotMove(id, handle) {
	if (!g_BotsStopped || !is_user_bot(id))
		return
	set_ucmd(handle, ucmd_forwardmove, 0.0)
	set_ucmd(handle, ucmd_sidemove, 0.0)
	set_ucmd(handle, ucmd_upmove, 0.0)
	set_ucmd(handle, ucmd_buttons, 0)
	set_pev(id, pev_velocity, Float:{0.0, 0.0, 0.0})
}

public client_putinserver(id) {
	if (is_user_bot(id) || is_user_hltv(id))
		return
	set_task(5.0, "ShowHint", id)
}

public ShowHint(id) {
	if (!is_user_connected(id) || !CanOpen(id))
		return
	PrintChat(id, "[Admin Panel] Нажмите H, чтобы открыть меню")
}

public OnSay(id) {
	new text[48]
	read_args(text, charsmax(text))
	remove_quotes(text)
	trim(text)
	if (equali(text, "/admin") || equali(text, "!admin")) {
		CmdMenu(id)
		return PLUGIN_HANDLED
	}
	return PLUGIN_CONTINUE
}

public CmdMenu(id) {
	if (!CanOpen(id)) {
		PrintChat(id, "[Admin Panel] Нет доступа")
		return PLUGIN_HANDLED
	}
	ShowMain(id)
	return PLUGIN_HANDLED
}

public OnMenu(id, key) {
	if (!CanOpen(id))
		return PLUGIN_HANDLED

	switch (g_State[id]) {
		case ST_MAIN: MainChoice(id, key)
		case ST_MORE: MoreChoice(id, key)
		case ST_SLAP: AmountChoice(id, key, LIST_SLAP)
		case ST_GIVE: AmountChoice(id, key, LIST_GIVE)
		case ST_TAKE: AmountChoice(id, key, LIST_TAKE)
		case ST_SKILL: SkillChoice(id, key)
		case ST_PERSON: PersonChoice(id, key)
		case ST_TEAM: TeamChoice(id, key)
		case ST_LIST: ListChoice(id, key)
	}
	return PLUGIN_HANDLED
}

public BlockBalance() {
	return HC_SUPERCEDE
}

public OnRoundReady() {
	LockRules()
}

public OnForcedCvar(pcvar, const oldValue[], const newValue[]) {
	if (g_Locking || str_to_num(newValue) == 0)
		return
	g_Locking = true
	set_pcvar_num(pcvar, 0)
	g_Locking = false
}

public LockRules() {
	g_Locking = true
	set_cvar_num("mp_autoteambalance", 0)
	set_cvar_num("mp_limitteams", 0)
	set_cvar_num("mp_kill_filled_spawn", 0)
	set_cvar_num("bot_quota", CountValveBots())
	set_cvar_string("bot_join_team", "CT")
	if (g_Vacate)
		set_pcvar_num(g_Vacate, 0)
	g_Locking = false

	set_member_game(m_iLimitTeams, 0)
	set_member_game(m_iUnBalancedRounds, 0)
	RaiseSpawns(m_iSpawnPointCount_CT)
	RaiseSpawns(m_iSpawnPointCount_Terrorist)
}

MainChoice(id, key) {
	switch (key) {
		case 0: OpenList(id, LIST_SWAP)
		case 1: ShowSlap(id)
		case 2: OpenList(id, LIST_KILL)
		case 3: OpenList(id, LIST_KICK)
		case 4: DrawRound(id)
		case 5: ShowMoney(id, true)
		case 6: ShowMoney(id, false)
		case 7: OpenBot(id, KIND_VALVE)
		case 8: ShowMore(id)
	}
}

AmountChoice(id, key, list) {
	if (key == 8) {
		ShowMain(id)
		return
	}
	if (key == 9)
		return

	new amounts[3]
	if (list == LIST_SLAP) {
		amounts[0] = 50
		amounts[1] = 10
		amounts[2] = 5
	} else {
		amounts[0] = 5000
		amounts[1] = 1000
		amounts[2] = 100
	}
	if (key < 0 || key > 2)
		return

	g_Amount[id] = amounts[key]
	OpenList(id, list)
}

SkillChoice(id, key) {
	if (key == 8) {
		BackFromBot(id)
		return
	}
	if (key == 9)
		return

	switch (g_Kind[id]) {
		case KIND_YAPB: {
			if (key < 0 || key > 4)
				return
			g_Skill[id] = key
			ShowPerson(id)
		}
		case KIND_POD: {
			if (key < 0 || key > 6)
				return
			new skills[7] = { 10, 30, 50, 70, 90, 100, 101 }
			g_Skill[id] = skills[key]
			ShowPerson(id)
		}
		default: {
			if (key < 0 || key > 3)
				return
			new skills[4] = { 3, 2, 1, 0 }
			g_Skill[id] = skills[key]
			ShowTeam(id)
		}
	}
}

PersonChoice(id, key) {
	if (key == 8) {
		ShowSkill(id)
		return
	}
	if (key == 9)
		return

	if (g_Kind[id] == KIND_POD) {
		if (key < 0 || key > 3)
			return
		new persons[4] = { 1, 2, 3, 5 }
		g_Person[id] = persons[key]
	} else {
		if (key < 0 || key > 2)
			return
		g_Person[id] = key
	}
	ShowTeam(id)
}

TeamChoice(id, key) {
	if (key == 8) {
		if (g_Kind[id] == KIND_VALVE)
			ShowSkill(id)
		else
			ShowPerson(id)
		return
	}
	if (key == 9 || (key != 0 && key != 1))
		return

	AddBot(id, key == 0)
	ShowTeam(id)
}

ListChoice(id, key) {
	if (key >= 0 && key < PAGE_SIZE) {
		if (key < g_Shown[id])
			UseTarget(id, g_Slot[id][key])
		return
	}
	if (key == 6 && g_HasNext[id]) {
		g_Page[id]++
		ShowList(id)
		return
	}
	if (key == 7 && g_HasPrev[id]) {
		g_Page[id]--
		ShowList(id)
		return
	}
	if (key == 8)
		BackFromList(id)
}

ShowFixed(id, keys, const text[], time, const menuid[]) {
	new fixed[1024]
	FixText(text, fixed, charsmax(fixed))
	show_menu(id, keys, fixed, time, menuid)
}

FixText(const src[], dest[], len) {
	new n, ch
	for (new i = 0; src[i] && n < len; i++) {
		ch = src[i]
		if ((ch & 0xFF) == 0xFF)
			ch = 0xDF
		dest[n++] = ch
	}
	dest[n] = 0
}

PrintChat(id, const msg[], any:...) {
	new formatted[192], fixed[192]
	vformat(formatted, charsmax(formatted), msg, 3)
	FixText(formatted, fixed, charsmax(fixed))
	client_print(id, print_chat, "%s", fixed)
}

PrintConsole(id, const msg[], any:...) {
	new formatted[192], fixed[192]
	vformat(formatted, charsmax(formatted), msg, 3)
	FixText(formatted, fixed, charsmax(fixed))
	client_print(id, print_console, "%s", fixed)
	server_print("%s", fixed)
}

ShowMain(id) {
	g_State[id] = ST_MAIN
	new menu[512]
	formatex(menu, charsmax(menu), "\yAdmin Panel^n^n\r1. \yПерекинуть в другую команду^n\r2. \yУдарить^n\r3. \yУбить^n\r4. \yКикнуть^n\r5. \yОбъявить раунд ничьей^n\r6. \yПередать деньги^n\r7. \yОтобрать деньги^n\r8. \yДобавить Valve бота^n\r9. \yДальше^n^n\r0. \yВыход")
	ShowFixed(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7|MENU_KEY_8|MENU_KEY_9|MENU_KEY_0, menu, MENU_TIME, MENU_NAME)
}

ShowMore(id) {
	g_State[id] = ST_MORE
	new menu[512]
	new zombie[48], pod[64]
	ZombieLabel(zombie, charsmax(zombie))
	if (ZombieOn())
		formatex(pod, charsmax(pod), "\d2. \dДобавить POD бота")
	else
		formatex(pod, charsmax(pod), "\r2. \yДобавить POD бота")
	formatex(menu, charsmax(menu), "\yДобавить бота^n^n\r1. \yДобавить YaPB бота^n%s^n\r3. \y%s^n\r4. \y%s^n^n\r9. \yНазад^n\r0. \yВыход", pod, g_BotsStopped ? "Включить всех ботов" : "Остановить всех ботов", zombie)
	ShowFixed(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_9|MENU_KEY_0, menu, MENU_TIME, MENU_NAME)
}

MoreChoice(id, key) {
	if (key == 8) {
		ShowMain(id)
		return
	}
	if (key == 9)
		return
	if (key == 0)
		OpenBot(id, KIND_YAPB)
	else if (key == 1) {
		if (ZombieOn()) {
			RefusePod(id)
			return
		}
		OpenBot(id, KIND_POD)
	}
	else if (key == 2)
		ToggleBots(id)
	else if (key == 3)
		OpenZombie(id)
}

ToggleBots(id) {
	g_BotsStopped = !g_BotsStopped
	new hold = g_BotsStopped ? 1 : 0
	if (cvar_exists("bot_stop"))
		set_cvar_num("bot_stop", hold)
	if (cvar_exists("bot_freeze"))
		set_cvar_num("bot_freeze", hold)
	if (cvar_exists("yb_freeze_bots"))
		set_cvar_num("yb_freeze_bots", hold)
	if (g_BotsStopped)
		PrintChat(id, "[Admin Panel] Боты остановлены")
	else
		PrintChat(id, "[Admin Panel] Боты включены")
	ShowMore(id)
}

ZombieLabel(dest[], len) {
	if (ZombieOn())
		formatex(dest, len, "Выключить зомби режим")
	else
		formatex(dest, len, "Зомби режим")
}

bool:ZombieOn() {
	return bool:(cvar_exists("zombie_mode") && get_cvar_num("zombie_mode"))
}

RefusePod(id) {
	PrintConsole(id, "[Admin Panel] POD-ботов нельзя добавлять в зомби-режиме: они не атакуют зомби.")
	ShowMore(id)
}

OpenZombie(id) {
	if (!cvar_exists("zombie_mode")) {
		PrintChat(id, "[Admin Panel] Зомби-режим недоступен")
		ShowMore(id)
		return
	}
	client_cmd(id, "zombie_toggle")
	ShowMore(id)
	remove_task(200 + id)
	new parm[1]
	parm[0] = id
	set_task(0.2, "RefreshZombieMenu", 200 + id, parm, sizeof parm)
}

public RefreshZombieMenu(parm[]) {
	new id = parm[0]
	if (!is_user_connected(id) || g_State[id] != ST_MORE)
		return
	ShowMore(id)
}

OpenBot(id, kind) {
	g_Kind[id] = kind
	ShowSkill(id)
}

BackFromBot(id) {
	if (g_Kind[id] == KIND_VALVE)
		ShowMain(id)
	else
		ShowMore(id)
}

ShowSlap(id) {
	g_State[id] = ST_SLAP
	new menu[256]
	formatex(menu, charsmax(menu), "\yУдарить^n^n\r1. \y50 HP^n\r2. \y10 HP^n\r3. \y5 HP^n^n\r9. \yНазад^n\r0. \yВыход")
	ShowAmount(id, menu)
}

ShowMoney(id, bool:give) {
	g_State[id] = give ? ST_GIVE : ST_TAKE
	new menu[256]
	formatex(menu, charsmax(menu), "\y%s^n^n\r1. \y5000$^n\r2. \y1000$^n\r3. \y100$^n^n\r9. \yНазад^n\r0. \yВыход", give ? "Передать деньги" : "Отобрать деньги")
	ShowAmount(id, menu)
}

ShowAmount(id, const menu[]) {
	ShowFixed(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_9|MENU_KEY_0, menu, MENU_TIME, MENU_NAME)
}

ShowSkill(id) {
	g_State[id] = ST_SKILL
	new menu[512]
	new keys = MENU_KEY_9|MENU_KEY_0
	switch (g_Kind[id]) {
		case KIND_YAPB: {
			formatex(menu, charsmax(menu), "\yДобавить YaPB бота^n^n\r1. \yНовичок^n\r2. \yСредний^n\r3. \yНормальный^n\r4. \yПрофессионал^n\r5. \yБог^n^n\r9. \yНазад^n\r0. \yВыход")
			keys |= MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5
		}
		case KIND_POD: {
			formatex(menu, charsmax(menu), "\yДобавить POD бота^n^n\r1. \yТупой^n\r2. \yНовичок^n\r3. \yСредний^n\r4. \yПродвинутый^n\r5. \yПрофессионал^n\r6. \yБог^n\r7. \yСлучайный^n^n\r9. \yНазад^n\r0. \yВыход")
			keys |= MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4|MENU_KEY_5|MENU_KEY_6|MENU_KEY_7
		}
		default: {
			formatex(menu, charsmax(menu), "\yДобавить Valve бота^n^n\r1. \yЭксперт^n\r2. \yСильный^n\r3. \yСредний^n\r4. \yСлабый^n^n\r9. \yНазад^n\r0. \yВыход")
			keys |= MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_4
		}
	}
	ShowFixed(id, keys, menu, MENU_TIME, MENU_NAME)
}

ShowPerson(id) {
	g_State[id] = ST_PERSON
	new menu[384]
	new keys = MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_9|MENU_KEY_0
	if (g_Kind[id] == KIND_POD) {
		formatex(menu, charsmax(menu), "\yЛичность^n^n\r1. \yОбычная^n\r2. \yАгрессивная^n\r3. \yОборонительная^n\r4. \yСлучайная^n^n\r9. \yНазад^n\r0. \yВыход")
		keys |= MENU_KEY_4
	} else
		formatex(menu, charsmax(menu), "\yЛичность^n^n\r1. \yОбычная^n\r2. \yАгрессивная^n\r3. \yОсторожная^n^n\r9. \yНазад^n\r0. \yВыход")
	ShowFixed(id, keys, menu, MENU_TIME, MENU_NAME)
}

ShowTeam(id) {
	g_State[id] = ST_TEAM
	new menu[192]
	new skill[32]
	SkillName(g_Kind[id], g_Skill[id], skill, charsmax(skill))
	formatex(menu, charsmax(menu), "\yКоманда бота: %s^n^n\r1. \yCT^n\r2. \yT^n^n\r9. \yНазад^n\r0. \yВыход", skill)
	ShowFixed(id, MENU_KEY_1|MENU_KEY_2|MENU_KEY_9|MENU_KEY_0, menu, MENU_TIME, MENU_NAME)
}

OpenList(id, list) {
	g_List[id] = list
	g_Page[id] = 0
	ShowList(id)
}

ShowList(id) {
	g_State[id] = ST_LIST

	new targets[64], total
	CollectTargets(id, g_List[id], targets, sizeof targets, total)

	new pages = (total + PAGE_SIZE - 1) / PAGE_SIZE
	if (pages < 1)
		pages = 1
	if (g_Page[id] >= pages)
		g_Page[id] = pages - 1
	if (g_Page[id] < 0)
		g_Page[id] = 0

	new start = g_Page[id] * PAGE_SIZE
	new shown = total - start
	if (shown > PAGE_SIZE)
		shown = PAGE_SIZE
	if (shown < 0)
		shown = 0

	g_Shown[id] = shown
	g_HasPrev[id] = g_Page[id] > 0
	g_HasNext[id] = (start + PAGE_SIZE) < total
	for (new i = 0; i < PAGE_SIZE; i++)
		g_Slot[id][i] = (i < shown) ? targets[start + i] : 0

	new menu[768], len, title[64]
	ListTitle(id, g_List[id], title, charsmax(title))
	if (pages > 1)
		len = formatex(menu, charsmax(menu), "\y%s \d(%d/%d)^n^n", title, g_Page[id] + 1, pages)
	else
		len = formatex(menu, charsmax(menu), "\y%s^n^n", title)

	if (!shown)
		len += formatex(menu[len], charsmax(menu) - len, "\dНет игроков^n")

	new keys
	for (new i = 0; i < shown; i++) {
		new line[64]
		PlayerLine(g_Slot[id][i], g_List[id], line, charsmax(line))
		len += formatex(menu[len], charsmax(menu) - len, "\r%d. \y%s^n", i + 1, line)
		keys |= (1 << i)
	}

	len += formatex(menu[len], charsmax(menu) - len, "^n")
	if (g_HasNext[id]) {
		len += formatex(menu[len], charsmax(menu) - len, "\r7. \yДальше^n")
		keys |= MENU_KEY_7
	}
	if (g_HasPrev[id]) {
		len += formatex(menu[len], charsmax(menu) - len, "\r8. \yПред.^n")
		keys |= MENU_KEY_8
	}
	len += formatex(menu[len], charsmax(menu) - len, "\r9. \yНазад^n\r0. \yВыход")
	keys |= MENU_KEY_9 | MENU_KEY_0

	ShowFixed(id, keys, menu, MENU_TIME, MENU_NAME)
}

BackFromList(id) {
	switch (g_List[id]) {
		case LIST_SLAP: ShowSlap(id)
		case LIST_GIVE: ShowMoney(id, true)
		case LIST_TAKE: ShowMoney(id, false)
		default: ShowMain(id)
	}
}

UseTarget(id, target) {
	if (!Allowed(id, target, g_List[id])) {
		PrintChat(id, "[Admin Panel] Игрок недоступен")
		ShowList(id)
		return
	}

	switch (g_List[id]) {
		case LIST_SWAP: {
			SwapTeam(id, target)
			ShowList(id)
		}
		case LIST_KILL: {
			KillPlayer(id, target)
			ShowList(id)
		}
		case LIST_KICK: {
			KickPlayer(id, target)
			ShowList(id)
		}
		case LIST_SLAP: {
			SlapPlayer(id, target, g_Amount[id])
			ShowList(id)
		}
		case LIST_GIVE: {
			GiveMoney(id, target, g_Amount[id])
			ShowList(id)
		}
		case LIST_TAKE: {
			TakeMoney(id, target, g_Amount[id])
			ShowList(id)
		}
	}
}

DrawRound(id) {
	server_cmd("endround")
	server_exec()
	PrintChat(id, "[Admin Panel] Раунд объявлен ничьей")
	ShowMain(id)
}

AddBot(id, bool:ct) {
	if (CountBots() >= BOT_LIMIT) {
		PrintChat(id, "[Admin Panel] Лимит ботов: 64")
		return
	}

	switch (g_Kind[id]) {
		case KIND_YAPB:
			client_cmd(id, "yapb %s %d %d", ct ? "add_ct" : "add_t", g_Skill[id], g_Person[id])
		case KIND_POD: {
			if (ZombieOn()) {
				RefusePod(id)
				return
			}
			client_cmd(id, "pb add %d %d %d 5", g_Skill[id], g_Person[id], ct ? 2 : 1)
		}
		default: {
			client_cmd(id, "bot_difficulty %d", g_Skill[id])
			client_cmd(id, ct ? "bot_add_ct" : "bot_add_t")
		}
	}

	new skill[32], kind[16]
	SkillName(g_Kind[id], g_Skill[id], skill, charsmax(skill))
	KindName(g_Kind[id], kind, charsmax(kind))
	if (g_Kind[id] == KIND_VALVE)
		PrintChat(id, "[Admin Panel] Бот добавлен: %s, %s, %s", kind, skill, ct ? "CT" : "T")
	else {
		new person[32]
		PersonName(g_Kind[id], g_Person[id], person, charsmax(person))
		PrintChat(id, "[Admin Panel] Бот добавлен: %s, %s, %s, %s", kind, skill, person, ct ? "CT" : "T")
	}
}

SwapTeam(id, target) {
	new CsTeams:team = cs_get_user_team(target)
	if (team == CS_TEAM_CT)
		cs_set_user_team(target, CS_TEAM_T, CS_T_TERROR)
	else if (team == CS_TEAM_T)
		cs_set_user_team(target, CS_TEAM_CT, CS_CT_URBAN)
	else
		return

	new name[32]
	get_user_name(target, name, charsmax(name))
	PrintChat(id, "[Admin Panel] %s переведен в другую команду", name)
}

SlapPlayer(id, target, damage) {
	new Float:health
	pev(target, pev_health, health)
	new Float:left = health - float(damage)
	if (left < 1.0)
		left = 1.0
	set_pev(target, pev_health, left)

	new hp = floatround(left)
	message_begin(MSG_ONE, g_MsgHealth, _, target)
	write_byte(hp > 255 ? 255 : hp)
	message_end()

	KnifeHeadshot(id, target, damage)

	new name[32]
	get_user_name(target, name, charsmax(name))
	PrintChat(id, "[Admin Panel] %s: удар %d HP, осталось %d", name, damage, hp)
}

KillPlayer(id, target) {
	user_kill(target)
	new name[32]
	get_user_name(target, name, charsmax(name))
	PrintChat(id, "[Admin Panel] %s убит", name)
}

KickPlayer(id, target) {
	new name[32]
	get_user_name(target, name, charsmax(name))
	if (IsYaPB(target) && cvar_exists("yb_quota")) {
		new left = get_cvar_num("yb_quota") - 1
		if (left < 0)
			left = 0
		set_cvar_num("yb_quota", left)
	}
	new valve = CountValveBots()
	if (IsValveBot(target) && valve > 0)
		valve--
	set_cvar_num("bot_quota", valve)
	server_cmd("kick #%d", get_user_userid(target))
	server_exec()
	set_cvar_num("bot_quota", CountValveBots())
	PrintChat(id, "[Admin Panel] %s кикнут", name)
}

GiveMoney(id, target, amount) {
	new moved = amount
	new bool:playing = AdminPlaying(id)
	new bool:self = bool:(id == target)
	if (playing && !self && moved > cs_get_user_money(id))
		moved = cs_get_user_money(id)

	new room = MaxMoney() - cs_get_user_money(target)
	if (moved > room)
		moved = room
	if (moved < 0)
		moved = 0

	new name[32]
	get_user_name(target, name, charsmax(name))
	if (moved <= 0) {
		if (playing && !self && cs_get_user_money(id) <= 0)
			PrintChat(id, "[Admin Panel] Не хватает денег")
		else
			PrintChat(id, "[Admin Panel] Карман полон")
		return
	}

	if (playing && !self)
		cs_set_user_money(id, cs_get_user_money(id) - moved, 1)
	cs_set_user_money(target, cs_get_user_money(target) + moved, 1)

	if (playing && !self)
		PrintChat(id, "[Admin Panel] %s получил %d$, у вас %d$", name, moved, cs_get_user_money(id))
	else
		PrintChat(id, "[Admin Panel] %s получил деньги, сейчас %d$", name, cs_get_user_money(target))
}

TakeMoney(id, target, amount) {
	new moved = amount
	new source = cs_get_user_money(target)
	if (moved > source)
		moved = source

	new bool:playing = AdminPlaying(id)
	new bool:self = bool:(id == target)
	if (playing && !self) {
		new room = MaxMoney() - cs_get_user_money(id)
		if (moved > room)
			moved = room
	}
	if (moved < 0)
		moved = 0

	new name[32]
	get_user_name(target, name, charsmax(name))
	if (moved <= 0) {
		if (source <= 0)
			PrintChat(id, "[Admin Panel] Не хватает денег")
		else
			PrintChat(id, "[Admin Panel] Карман полон")
		return
	}

	cs_set_user_money(target, source - moved, 1)
	if (playing && !self)
		cs_set_user_money(id, cs_get_user_money(id) + moved, 1)

	if (playing && !self)
		PrintChat(id, "[Admin Panel] У %s забрано %d$, у вас %d$", name, moved, cs_get_user_money(id))
	else
		PrintChat(id, "[Admin Panel] У %s забраны деньги, сейчас %d$", name, cs_get_user_money(target))
}

KnifeHeadshot(attacker, victim, damage) {
	new Float:head[3], Float:view[3], Float:from[3]
	pev(victim, pev_origin, head)
	pev(victim, pev_view_ofs, view)
	head[0] += view[0]
	head[1] += view[1]
	head[2] += view[2]
	pev(attacker, pev_origin, from)

	engfunc(EngFunc_EmitSound, victim, CHAN_WEAPON, "weapons/knife_stab.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)

	new CsArmorType:armorType
	cs_get_user_armor(victim, armorType)
	if (armorType == CS_ARMOR_VESTHELM)
		engfunc(EngFunc_EmitSound, victim, CHAN_BODY, "player/bhit_helmet-1.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	else {
		new flesh[32]
		formatex(flesh, charsmax(flesh), "player/bhit_flesh-%d.wav", random_num(1, 3))
		engfunc(EngFunc_EmitSound, victim, CHAN_BODY, flesh, 1.0, ATTN_NORM, 0, PITCH_NORM)
	}

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BLOODSTREAM)
	write_coord(floatround(head[0]))
	write_coord(floatround(head[1]))
	write_coord(floatround(head[2]))
	write_coord(0)
	write_coord(0)
	write_coord(80)
	write_byte(247)
	write_byte(110)
	message_end()

	if (g_BloodSpray && g_BloodDrop) {
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_BLOODSPRITE)
		write_coord(floatround(head[0]))
		write_coord(floatround(head[1]))
		write_coord(floatround(head[2]))
		write_short(g_BloodSpray)
		write_short(g_BloodDrop)
		write_byte(247)
		write_byte(16)
		message_end()
	}

	new Float:punch[3]
	punch[0] = random_float(-24.0, -12.0)
	punch[1] = random_float(-8.0, 8.0)
	punch[2] = 0.0
	set_pev(victim, pev_punchangle, punch)

	new shown = damage
	if (shown < 1)
		shown = 1
	if (shown > 255)
		shown = 255
	message_begin(MSG_ONE, g_MsgDamage, _, victim)
	write_byte(0)
	write_byte(shown)
	write_long((1 << 7) | (1 << 12))
	write_coord(floatround(from[0]))
	write_coord(floatround(from[1]))
	write_coord(floatround(from[2]))
	message_end()

	message_begin(MSG_ONE, g_MsgShake, _, victim)
	write_short(FixedUnsigned16(6.0, 1 << 12))
	write_short(FixedUnsigned16(0.6, 1 << 12))
	write_short(FixedUnsigned16(14.0, 1 << 8))
	message_end()
}

CollectTargets(admin, list, dest[], maxDest, &count) {
	count = 0
	new CsTeams:mine = cs_get_user_team(admin)
	new CsTeams:firstTeam = CS_TEAM_CT
	new CsTeams:secondTeam = CS_TEAM_T
	if (mine == CS_TEAM_T) {
		firstTeam = CS_TEAM_T
		secondTeam = CS_TEAM_CT
	}
	AppendTeam(admin, list, firstTeam, dest, maxDest, count)
	AppendTeam(admin, list, secondTeam, dest, maxDest, count)
}

AppendTeam(admin, list, CsTeams:team, dest[], maxDest, &count) {
	for (new i = 1; i <= MaxClients && count < maxDest; i++) {
		if (!Allowed(admin, i, list) || cs_get_user_team(i) != team)
			continue
		dest[count++] = i
	}
}

bool:Allowed(admin, target, list) {
	if (!is_user_connected(target))
		return false
	new CsTeams:team = cs_get_user_team(target)
	if (team != CS_TEAM_CT && team != CS_TEAM_T)
		return false

	switch (list) {
		case LIST_SLAP, LIST_KILL: {
			if (target == admin || !is_user_alive(target))
				return false
		}
		case LIST_KICK: {
			if (target == admin)
				return false
		}
		case LIST_GIVE: {
			if (cs_get_user_money(target) >= MaxMoney())
				return false
		}
		case LIST_TAKE: {
			if (cs_get_user_money(target) <= 0)
				return false
		}
	}
	return true
}

PlayerLine(id, list, output[], len) {
	if (!is_user_connected(id)) {
		formatex(output, len, "Нет игрока")
		return
	}
	new name[32]
	get_user_name(id, name, charsmax(name))
	for (new i = 0; name[i]; i++) {
		if (name[i] == 94 || name[i] == 92 || name[i] == 37)
			name[i] = ' '
	}
	new team[4]
	formatex(team, charsmax(team), "%s", cs_get_user_team(id) == CS_TEAM_CT ? "CT" : "T")
	if (list == LIST_GIVE || list == LIST_TAKE)
		formatex(output, len, "%s: %s %d$", team, name, cs_get_user_money(id))
	else if (list == LIST_SLAP) {
		new Float:health
		pev(id, pev_health, health)
		formatex(output, len, "%s: %s %d HP", team, name, floatround(health))
	} else
		formatex(output, len, "%s: %s", team, name)
}

ListTitle(id, list, output[], len) {
	switch (list) {
		case LIST_SWAP: formatex(output, len, "Перекинуть")
		case LIST_SLAP: formatex(output, len, "Ударить: %d HP", g_Amount[id])
		case LIST_KILL: formatex(output, len, "Убить")
		case LIST_KICK: formatex(output, len, "Кикнуть")
		case LIST_GIVE: formatex(output, len, "Передать деньги: %d$", g_Amount[id])
		case LIST_TAKE: formatex(output, len, "Отобрать деньги: %d$", g_Amount[id])
		default: formatex(output, len, "Admin Panel")
	}
}

KindName(kind, output[], len) {
	switch (kind) {
		case KIND_YAPB: formatex(output, len, "YaPB")
		case KIND_POD: formatex(output, len, "POD")
		default: formatex(output, len, "Valve")
	}
}

SkillName(kind, skill, output[], len) {
	if (kind == KIND_YAPB) {
		switch (skill) {
			case 0: formatex(output, len, "Новичок")
			case 1: formatex(output, len, "Средний")
			case 2: formatex(output, len, "Нормальный")
			case 3: formatex(output, len, "Профессионал")
			default: formatex(output, len, "Бог")
		}
		return
	}
	if (kind == KIND_POD) {
		switch (skill) {
			case 10: formatex(output, len, "Тупой")
			case 30: formatex(output, len, "Новичок")
			case 50: formatex(output, len, "Средний")
			case 70: formatex(output, len, "Продвинутый")
			case 90: formatex(output, len, "Профессионал")
			case 100: formatex(output, len, "Бог")
			default: formatex(output, len, "Случайный")
		}
		return
	}
	switch (skill) {
		case 3: formatex(output, len, "Эксперт")
		case 2: formatex(output, len, "Сильный")
		case 1: formatex(output, len, "Средний")
		default: formatex(output, len, "Слабый")
	}
}

PersonName(kind, person, output[], len) {
	if (kind == KIND_POD) {
		switch (person) {
			case 2: formatex(output, len, "Агрессивная")
			case 3: formatex(output, len, "Оборонительная")
			case 5: formatex(output, len, "Случайная")
			default: formatex(output, len, "Обычная")
		}
		return
	}
	switch (person) {
		case 1: formatex(output, len, "Агрессивная")
		case 2: formatex(output, len, "Осторожная")
		default: formatex(output, len, "Обычная")
	}
}

bool:AdminPlaying(id) {
	new CsTeams:team = cs_get_user_team(id)
	return bool:(team == CS_TEAM_CT || team == CS_TEAM_T)
}

bool:CanOpen(id) {
	if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
		return false
	if (!is_dedicated_server())
		return true
	return bool:(get_user_flags(id) & ADMIN_MENU)
}

CountBots() {
	new count
	for (new i = 1; i <= MaxClients; i++) {
		if (is_user_connected(i) && is_user_bot(i))
			count++
	}
	return count
}

CountValveBots() {
	new count
	for (new i = 1; i <= MaxClients; i++) {
		if (IsValveBot(i))
			count++
	}
	return count
}

bool:IsValveBot(id) {
	return bool:NameStarts(id, "Valve Bot ", 10)
}

bool:IsYaPB(id) {
	return bool:NameStarts(id, "YaPB ", 5)
}

bool:NameStarts(id, const prefix[], length) {
	if (!is_user_connected(id) || !is_user_bot(id))
		return false
	new name[32]
	get_user_name(id, name, charsmax(name))
	return bool:equal(name, prefix, length)
}

MaxMoney() {
	new maxMoney = get_cvar_num("mp_maxmoney")
	return maxMoney > 0 ? maxMoney : 16000
}

HookZero(const name[]) {
	new pcvar = get_cvar_pointer(name)
	if (pcvar)
		hook_cvar_change(pcvar, "OnForcedCvar")
}

RaiseSpawns(CSGameRules_Members:member) {
	new count = get_member_game(member)
	if (count > 0 && count < BOT_LIMIT)
		set_member_game(member, BOT_LIMIT)
}

FixedUnsigned16(Float:value, scale) {
	new output = floatround(value * float(scale))
	if (output < 0)
		return 0
	if (output > 0xFFFF)
		return 0xFFFF
	return output
}
