# CS Bot Panel

Админ-меню для Counter-Strike 1.6. Из него добавляют ботов Valve, YaPB и POD-Bot по одному, а также переводят игрока, бьют, убивают, кикают, передают и забирают деньги, объявляют раунд ничьей.

Самой игры в репозитории нет. Нет и готовых пакетов MetaMod, AMX Mod X, YaPB и POD-Bot: их ставят отдельно, а отсюда берут меню и настройки.

Меню открывается командой `admin`. В `userconfig.cfg` она повешена на клавишу `H`.

## Что лежит в репозитории

- `admin_panel/admin_panel.sma` — исходник.
- `admin_panel/compile.ps1` — сборка плагина.
- `cstrike/addons/amxmodx/plugins/admin_panel.amxx` — уже собранный плагин.
- `cstrike/addons/metamod/plugins.ini` — порядок загрузки AMX Mod X, YaPB и POD-Bot.
- `cstrike/userconfig.cfg` — клавиша `H`.
- `tools/prefix-valve-names.ps1` — дописывает к никам ботов Valve префикс `Valve Bot`.

## Установка

Нужна своя копия Counter-Strike 1.6. Файлы из этого репозитория копируются в её корень, рядом с `cstrike`.

1. Поставьте [MetaMod](https://github.com/theAsmodai/metamod-r). В `cstrike/liblist.gam` строка игры должна указывать на него:

```
gamedll "addons\metamod\dlls\metamod.dll"
```

2. Поставьте [AMX Mod X](https://www.amxmodx.org/) и модуль [ReAPI](https://github.com/s1lentq/reapi). В `cstrike/addons/amxmodx/configs/modules.ini` включите:

```
reapi
cstrike
```

В конец `cstrike/addons/amxmodx/configs/plugins.ini` добавьте:

```
admin_panel.amxx
```

Скопируйте `cstrike/addons/amxmodx/plugins/admin_panel.amxx` в ту же папку своей игры.

3. Для локальной игры в `cstrike/addons/amxmodx/configs/users.ini` оставьте админа без пароля:

```
"loopback" "" "abcdefghijklmnopqrstuv" "de"
"127.0.0.1" "" "abcdefghijklmnopqrstuv" "de"
"STEAM_ID_LAN" "" "abcdefghijklmnopqrstuv" "ce"
"STEAM_ID_LOOPBACK" "" "abcdefghijklmnopqrstuv" "ce"
```

На выделенном сервере меню открывается только у игрока с флагом `u`. В локальной игре его может открыть любой человек.

4. Поставьте [YaPB](https://github.com/yapb/yapb) и [POD-Bot](https://github.com/APGRoboCop/podbot). Скопируйте `cstrike/addons/metamod/plugins.ini` поверх одноимённого файла. В нём три строки:

```
win32 addons/amxmodx/dlls/amxmodx_mm.dll
win32 addons/yapb/bin/yapb.dll
win32 addons/podbot/podbot_mm.dll
```

5. Боты не должны заходить сами. В `cstrike/addons/yapb/conf/yapb.cfg`:

```
yb_quota "0"
yb_name_prefix "YaPB"
```

В `cstrike/addons/podbot/podbot.cfg`:

```
pb_minbots 0
pb_maxbots 0
pb_bot_quota_match 0
```

Строк `pb add` и `pb fillserver` быть не должно. По желанию меню POD открывается клавишей `=`:

```
bind "=" "pb menu"
```

6. Меню узнаёт ботов Valve по префиксу в нике. Из корня игры выполните:

```
powershell -File tools\prefix-valve-names.ps1
```

Скрипт правит локальный `cstrike/BotProfile.db` и сам файл игры никуда не выкладывает. Повторный запуск уже помеченные ники не меняет.

Плагин сам держит `mp_autoteambalance` на 0, чтобы игра не перекидывала игроков между командами.

## Сборка

Компилятор AMX Mod X должен лежать в `cstrike/addons/amxmodx/scripting/amxxpc.exe`. Из корня игры:

```
powershell -File admin_panel\compile.ps1
```

Готовый `admin_panel.amxx` появится в `cstrike/addons/amxmodx/plugins/`.
