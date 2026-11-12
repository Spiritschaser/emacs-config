# xjupyter: совместимость с GNU Emacs

Проверено 11 ноября 2026 года. Локальная среда: GNU Emacs 31.1, Windows.

## Результат

Готовую версию xjupyter для обычного GNU Emacs найти не удалось.
Проверены основной репозиторий, публичные ветки и оба публичных форка,
а также индексы MELPA, GNU ELPA и NonGNU ELPA. Это результат поиска
на указанную дату, а не доказательство отсутствия любых других портов.

Основной проект: [commercial-emacs/xjupyter](https://github.com/commercial-emacs/xjupyter).
HEAD и единственная обнаруженная ветка `gitawonk` указывали на
[коммит 657f348 от 5 октября 2026](https://github.com/commercial-emacs/xjupyter/commit/657f348b5258aa031912fa916b0a9bf18d1b8f0b).
Теги через `git ls-remote` не обнаружены.
Lisp-файл содержит версию `0.0.1`, Python-проект — `0.1.0`;
для воспроизводимости следует фиксировать коммит.

## Как устроен mode-overlay

Механизм Commercial Emacs позволяет участкам общего текста работать
в разных major modes. Он сочетает overlays и косвенные буферы:
текст разделяется с основным буфером, а major mode и локальные настройки
могут отличаться. При входе курсора в область и выходе из неё происходит
переключение активного буфера.

В xjupyter основной буфер содержит блокнот, а области ввода связываются
с косвенными буферами с `python-mode`. Выполнение ячейки получает код
из соответствующего буфера. Это часть устройства редактора ячеек,
а не только подсветка.

Ссылки на закреплённый коммит xjupyter:

- [Обязательная загрузка mode-overlay](https://github.com/commercial-emacs/xjupyter/blob/657f348b5258aa031912fa916b0a9bf18d1b8f0b/lisp/xjupyter.el#L14-L17).
- [Получение кода и выполнение ячейки](https://github.com/commercial-emacs/xjupyter/blob/657f348b5258aa031912fa916b0a9bf18d1b8f0b/lisp/xjupyter.el#L177-L191).
- [Создание области с python-mode](https://github.com/commercial-emacs/xjupyter/blob/657f348b5258aa031912fa916b0a9bf18d1b8f0b/lisp/xjupyter.el#L721-L732).
- [Режим блокнота jpr-mode](https://github.com/commercial-emacs/xjupyter/blob/657f348b5258aa031912fa916b0a9bf18d1b8f0b/lisp/xjupyter.el#L509-L570).

Обычные overlays GNU Emacs сами по себе не назначают участку отдельный
major mode. Косвенные буферы в GNU Emacs существуют, но сами по себе
не обеспечивают весь механизм Commercial Emacs.

## Почему копирования mode-overlay.el недостаточно

Lisp-файл вызывает функции из C-ядра форка. Ссылки ниже закреплены
на коммите Commercial Emacs `bf4184f985d0674a7c03c12eb33b66ac833d9e29`,
полученном при сохранении заметки.

- [make-mode-overlay вызывает make-mode--overlay](https://github.com/commercial-emacs/commercial-emacs/blob/bf4184f985d0674a7c03c12eb33b66ac833d9e29/lisp/mode-overlay.el#L45-L77).
- [Переключение использует overlay-on-enter](https://github.com/commercial-emacs/commercial-emacs/blob/bf4184f985d0674a7c03c12eb33b66ac833d9e29/lisp/mode-overlay.el#L78-L83).
- [Вход в косвенный буфер и выход в основной](https://github.com/commercial-emacs/commercial-emacs/blob/bf4184f985d0674a7c03c12eb33b66ac833d9e29/src/buffer.c#L1061-L1084).
- [Создание mode overlay](https://github.com/commercial-emacs/commercial-emacs/blob/bf4184f985d0674a7c03c12eb33b66ac833d9e29/src/buffer.c#L1121-L1264).
- [C-примитив make-mode--overlay](https://github.com/commercial-emacs/commercial-emacs/blob/bf4184f985d0674a7c03c12eb33b66ac833d9e29/src/buffer.c#L1267-L1290).
- [C-примитив overlay-on-enter](https://github.com/commercial-emacs/commercial-emacs/blob/bf4184f985d0674a7c03c12eb33b66ac833d9e29/src/buffer.c#L4060-L4066).

В работающей локальной сессии проверено отсутствие `make-mode-overlay`,
`make-mode--overlay` и `overlay-on-enter`. Обычная `overlay-buffer`
присутствует; это не свидетельствует о поддержке mode overlays.

Также проверены дерево master и src/buffer.c
[GNU Emacs](https://github.com/emacs-mirror/emacs):
файл mode-overlay.el и названные C-примитивы не обнаружены.

## Форки и архивы

Оба найденных публичных форка сохраняют зависимость от mode-overlay
и вызовы make-mode-overlay. Признаков готового порта для GNU Emacs
в проверенных ветках не обнаружено.

- [aesbetic/xjupyter: проверенный исходник](https://github.com/aesbetic/xjupyter/blob/99a71318355676e481338dc2c70a6a5a709dc476/lisp/xjupyter.el).
- [jph6366/xjupyter: проверенный исходник](https://github.com/jph6366/xjupyter/blob/59b09465aacf948d451310e82f956556e308563b/lisp/xjupyter.el).
- [Список форков через API](https://api.github.com/repos/commercial-emacs/xjupyter/forks?per_page=100).
- [Ветки основного проекта](https://api.github.com/repos/commercial-emacs/xjupyter/branches).

Названия xjupyter и mode-overlay не найдены в проверенных индексах:
[MELPA](https://melpa.org/packages/archive-contents),
[GNU ELPA](https://elpa.gnu.org/packages/archive-contents),
[NonGNU ELPA](https://elpa.nongnu.org/nongnu/archive-contents).

## Особенности Windows и объём портирования

Штатная установка использует Bash, pipx и Unix-пути.
Клиент запускает bin/app, собирая строку команды и разбивая её
через split-string. Это требует адаптации для Windows,
в частности для путей с пробелами.

- [Штатная сборка](https://github.com/commercial-emacs/xjupyter/blob/657f348b5258aa031912fa916b0a9bf18d1b8f0b/Makefile#L1-L14).
- [Штатная установка](https://github.com/commercial-emacs/xjupyter/blob/657f348b5258aa031912fa916b0a9bf18d1b8f0b/Makefile#L53-L63).
- [Запуск RPC-процесса](https://github.com/commercial-emacs/xjupyter/blob/657f348b5258aa031912fa916b0a9bf18d1b8f0b/lisp/xjupyter.el#L997-L1038).
- [Зависимости Python: typing_extensions, jupyter_client, ipykernel](https://github.com/commercial-emacs/xjupyter/blob/657f348b5258aa031912fa916b0a9bf18d1b8f0b/pyproject.toml#L10-L17).

Установка исходного xjupyter в эту конфигурацию GNU Emacs не даст
работающего клиента без дополнительных изменений. Потребуется заменить
или воспроизвести поведение mode overlays, проверить переключение буферов,
редактирование и undo, а также адаптировать запуск Python под Windows.
Объём и надёжность такого порта пока не установлены.
Называть его простой настройкой или небольшим слоем совместимости
преждевременно.

В ходе исследования xjupyter не устанавливался, конфигурация Emacs
и Python-окружения не изменялись.
