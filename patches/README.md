# Локальный патч Emacs MCP bridge

`codex-ide-emacsclient-server-file.patch` меняет только `-s` на `--server-file`
в `bin/codex-ide-mcp-server.py`. Базовая ревизия:
`5eba84dd58ad8609e8f7e8c4159d4aac90b4f303`.

Текущий `lisp/init-codex.el` передаёт путь к файлу подключения TCP-сервера.
`-s` выбирает Unix-сокет, `--server-file` — файл подключения TCP-сервера.
При переносе на Linux с Unix-сокетом этот патч нельзя применять автоматически.

## Обновление

Выполнять вне активной сессии Codex, использующей обновляемый мост.
Сначала сделать свежую полную копию checkout с `.git` и незакоммиченными
изменениями, `init.el`, `lisp/init-codex.el` и `elpa/codex-ide/`.
Начальный снимок: `backups/codex-ide-working-20261110-222632/`.

Из корня `.emacs.d` посмотреть состояние и изменения:

```bash
git -C codex-ide-backup status --short
git -C codex-ide-backup diff
```

Отдельное изменение `codex-ide-autoloads.el` не входит в патч. Если оно мешает
обновлению, сначала разобрать его. Не выполнять `reset --hard` или `clean`.
Следующие команды выполнять по одной, продолжая только после успеха предыдущей:

```bash
git -C codex-ide-backup apply --reverse --check ../patches/codex-ide-emacsclient-server-file.patch
git -C codex-ide-backup apply --reverse ../patches/codex-ide-emacsclient-server-file.patch
```

Затем обновить пакет штатным способом через `package-vc`. Если обновление
не удалось, восстановить патч либо рабочую копию до запуска новой сессии.
Проверить фактический каталог пакета: команды предполагают, что используется
прежний `codex-ide-backup/`.

Проверить обновлённый `EmacsProxy.call_tool` и обработку имени сервера.
Если upstream уже корректно поддерживает файл TCP-сервера, патч не нужен.
Иначе проверить и применить его, продолжая только после успешной проверки:

```bash
git -C codex-ide-backup apply --check ../patches/codex-ide-emacsclient-server-file.patch
git -C codex-ide-backup apply ../patches/codex-ide-emacsclient-server-file.patch
```

Если проверка не прошла, остановиться и адаптировать патч по новому коду.
Не применять принудительно, через `--reject` или слепую замену текста.
В новой сессии Codex проверить MCP `emacs_get_all_buffers`.
Если обновлялись загруженные Lisp-модули, отдельно учесть их перезагрузку.

## Откат

Снимок `backups/codex-ide-working-20261110-222632/` содержит полный архив checkout
с `.git`, файлы подключения, старые заметки, diff и SHA-256 исходных файлов.
Порядок восстановления: `RESTORE.md` внутри снимка.
Это снимок пакета и его подключения, а не всей установки Emacs, Python и Codex CLI.
Файл авторизации Emacs-сервера в него не копировался и остаётся на штатном месте.
