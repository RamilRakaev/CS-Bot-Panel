# CS Bot Panel

Админ-меню для Counter-Strike 1.6. Из него добавляют ботов Valve, YaPB и POD-Bot по одному, а также переводят игрока, бьют, убивают, кикают, передают и забирают деньги, объявляют раунд ничьей.

Меню открывается командой `admin`. В `userconfig.cfg` она повешена на клавишу `H`.

Самой игры в репозитории нет. Здесь лежит всё, что ставится поверх готовой сборки Counter-Strike 1.6.

## Состав

- `admin_panel/` — исходник меню и сборка.
- `cstrike/addons/amxmodx/` — [AMX Mod X](https://www.amxmodx.org/), модуль [ReAPI](https://github.com/s1lentq/reapi) и плагин `admin_panel.amxx`.
- `cstrike/addons/metamod/` — [MetaMod](https://github.com/theAsmodai/metamod-r) и порядок загрузки плагинов.
- `cstrike/addons/yapb/` — [YaPB](https://github.com/yapb/yapb), конфиг и графы карт.
- `cstrike/addons/podbot/` — [POD-Bot](https://github.com/APGRoboCop/podbot), конфиг и вейпоинты.
- `cstrike/liblist.gam` — игра запускает MetaMod.
- `cstrike/userconfig.cfg` — клавиша `H`.
- `tools/prefix-valve-names.ps1` — дописывает к никам ботов Valve префикс `Valve Bot`.

Боты сами на сервер не заходят. У YaPB квота `0` и префикс ника `YaPB`. У POD-Bot `pb_minbots`, `pb_maxbots` и `pb_bot_quota_match` равны `0`, строк `pb add` и `pb fillserver` нет. Меню POD по желанию открывается клавишей `=`.

Локальному игроку меню доступно без пароля: в `users.ini` прописаны `loopback`, `127.0.0.1`, `STEAM_ID_LAN` и `STEAM_ID_LOOPBACK`. На выделенном сервере меню открывается только у игрока с флагом `u`.

## Установка

Скопируйте содержимое репозитория в корень своей Counter-Strike 1.6, рядом с папкой `cstrike`, с заменой существующих файлов.

После копирования из корня игры один раз выполните:

```
powershell -File tools\prefix-valve-names.ps1
```

Скрипт правит локальный `cstrike/BotProfile.db`, чтобы меню отличало ботов Valve. Повторный запуск уже помеченные ники не меняет. Сам файл профилей принадлежит игре и в репозиторий не входит.

Плагин сам держит `mp_autoteambalance` на 0, чтобы игра не перекидывала игроков между командами.

## Сборка

Компилятор уже лежит в `cstrike/addons/amxmodx/scripting/amxxpc.exe`. Из корня игры:

```
powershell -File admin_panel\compile.ps1
```

Готовый `admin_panel.amxx` появится в `cstrike/addons/amxmodx/plugins/`. Для игры сборка не нужна: плагин уже собран.
