# Org Workspace

Откройте [org-workspace-demo.org](org-workspace-demo.org). Исходники, сохранённые таблицы и ссылки на результаты находятся в документе. Перемещайте его вместе с каталогом [org-workspace-assets](org-workspace-assets/).

## Компоненты

| Компонент | Версия | Расположение |
| --- | --- | --- |
| Emacs и штатный Org | 32.0.50 и 9.8.12 | `C:/Program Files/Emacs/emacs-31.1/` |
| Emacs Easy Draw | 1.3.1, `28029b9` | `elpa/edraw/` |
| org-mindmap | 0.3, `128e8fb` | `elpa/org-mindmap/` |
| Graphviz | 16.1.2 | `tools/graphviz/bin/dot.exe` |
| Eclipse Temurin JRE | 21.0.13.1+2 | `tools/java/bin/java.exe` |
| PlantUML | 1.2026.10 | `tools/plantuml/plantuml.jar` |
| TinyTeX-1 и dvisvgm | 2026.11 и 3.6 | `tools/tinytex/bin/windows/latex.exe`, `dvisvgm.exe` |
| Python, IPython | 3.13.3 и 8.37.0 | `%LOCALAPPDATA%/Programs/Python/Python313/python.exe`, `Scripts/ipython.exe` |
| pandas и Matplotlib | 2.3.2 и 3.10.5 | В окружении Python 3.13 |
| PostgreSQL и psql | 17.5 | `C:/Program Files/PostgreSQL/17/bin/` |

Пути `elpa/` и `tools/` в таблице отсчитываются от `C:/Users/samsy/.emacs.d/`. Конфигурация добавляет переносимые программы в `exec-path` и `PATH` процесса Emacs. Модули загружаются из `init.el`, пакеты установлены через `package-vc`. Исполняемые файлы, JAR, тестовый кластер PostgreSQL и кэш формул исключены из Git.

## Изображения и вложения

Для изображения без подписи вставьте `[[file:resources/image.png]]` или `[[file:resources/diagram.svg]]`. При открытии Org-файла Emacs пытается показать доступные локальные изображения. `C-c C-x C-v` переключает предпросмотр. Для большого документа можно добавить `#+startup: nolinkpreviews` и включать предпросмотр только в нужном разделе или выделении.

Для прикрепления файла используйте `C-c C-a` или `M-x org-attach-attach`. Вложения по ID хранятся в `data/` рядом с документом. Для выбранного каталога задайте свойство `DIR` у заголовка, например `resources/attachments`, и используйте ссылку `[[attachment:figure.png]]`. При переносе документа сохраните относительное расположение ресурсов.

`TAB` на заголовке или исходном блоке переключает его видимость. Чтобы сворачивать длинный результат отдельно, добавьте `drawer` к аргументу `:results` и используйте `TAB` на строке `:RESULTS:`. `C-c '` открывает исходный блок в режиме соответствующего языка. `C-c C-x C-l` на формуле строит локальный предпросмотр через `latex` и `dvisvgm`.

## Рисование

1. Создайте каталог ресурсов и добавьте ссылку `[[edraw:file=./resources/sketch.edraw.svg]]`.
2. На ссылке нажмите `C-c C-o` или вызовите `M-x edraw-org-edit-link`.
3. Выберите инструмент в панели рисунка и рисуйте мышью. `C-c C-c` сохраняет SVG и завершает редактирование. `C-c C-k` закрывает редактор с возможностью отменить изменения.
4. Повторное открытие ссылки загружает сохранённый SVG в тот же редактор. `M-x edraw-org-link-image-mode` переключает предпросмотр ссылок edraw.

## Карты мыслей

`C-c C-, m` вставляет блок `mindmap`. Напишите внутри имя корневого узла и нажмите `C-c C-c`, чтобы выровнять карту. `TAB` и `RET` добавляют дочерний и соседний узлы. `M-RET` редактирует подпись. `M-↑` и `M-↓` переставляют узлы, `M-←` и `M-→` меняют вложенность.

В Org-буфере с `org-mindmap-mode` доступны `C-c m c` для дочернего узла, `C-c m s` для соседнего, `C-c m d` для удаления и `C-c m v` для смены раскладки. `org-mindmap-list-to-mindmap` преобразует обычный вложенный список, `org-mindmap-to-list` возвращает его обратно. Команды заменяют исходный фрагмент при вызове. Карта представляет собой текстовый блок Org.

## Org Babel

Поставьте курсор в блок и нажмите `C-c C-c`. Стандартное подтверждение выполнения Babel включено. `C-c C-c` после редактирования блока пересоздаёт результат.

- **Graphviz.** Используйте `#+begin_src dot :file resources/diagram.svg :results file graphics` и тело `digraph { A -> B; B -> C; }`.
- **PlantUML.** Используйте `#+begin_src plantuml :file resources/sequence.svg :results file graphics` и тело `Author -> Org: Run`. Org запускает локальный JAR. Профиль `SANDBOX` ограничивает доступ диаграмм к внешним файлам и URL.
- **Python.** Для числа используйте `:results value scalar` и `return 6 * 7`. Для таблицы используйте `:results value table` и возвращайте список строк. Для pandas подойдёт `[df.columns.tolist(), None, *df.to_numpy().tolist()]`, где `None` становится разделителем заголовка. Для Matplotlib используйте `:results file graphics :file resources/plot.png` и верните объект `Figure`. Org сохранит его в файл.
- **Сессия Python.** Блоки с одинаковым заголовком `:session notebook-demo` разделяют отдельный процесс Babel. В режиме `:results value` оставьте выражение с результатом последней строкой. Python Workspace сохраняет свой отдельный процесс dREPL/IPython.
- **PostgreSQL.** `:engine postgresql :colnames yes :results value table :cmdline -X -w` включает таблицу с заголовком и отключает интерактивный запрос пароля от `psql`. Укажите адрес и базу либо профиль libpq. Демонстрация использует отдельную локальную базу.

## Локальный PostgreSQL

Тестовый кластер находится в `C:/Users/samsy/.emacs.d/.cache/org-workspace-postgres/`. Он слушает только `127.0.0.1:55432`, по умолчанию открывает транзакции только для чтения и аутентифицирует текущую учётную запись Windows через SSPI. Тестовый блок выполняет только `SELECT`. Сервер запущен отдельно от Emacs. После перезапуска Windows при необходимости запустите его из PowerShell.

```powershell
$orgDemoPg = 'C:/Users/samsy/.emacs.d/.cache/org-workspace-postgres'
& 'C:/Program Files/PostgreSQL/17/bin/pg_ctl.exe' -D $orgDemoPg -l "$orgDemoPg/postgresql.log" -w start
```

Для реальной базы можно вручную сопоставить несекретные параметры Clutch и Babel или завести профиль libpq и передать `:database service=имя_профиля`. Для парольной аутентификации `psql` использует `%APPDATA%/postgresql/pgpass.conf`; ограничьте доступ к нему средствами Windows. Clutch и Babel управляют независимыми подключениями. При ошибке откройте буфер `*Org-Babel Error Output*`, где находится сообщение `psql`.

## Обновление

- В Emacs обновите Git-версии пакетов через `M-x package-vc-upgrade` с именем `edraw` или `org-mindmap`. Для проверки откройте демонстрацию после обновления.
- Возьмите Graphviz, Temurin и PlantUML из официальных источников, сверьте SHA-256 и замените обновляемые файлы в соответствующих каталогах `tools/`. Сохраните имена каталогов и `plantuml.jar`.
- Для TinyTeX используйте `tools/tinytex/bin/windows/tlmgr.bat`. Для смены годового выпуска TeX Live используйте новый архив TinyTeX.
- Пакеты Python обновляйте в установленном интерпретаторе. Актуальный путь можно проверить в Emacs через `M-: (executable-find "python")`.

## Ограничения

Карты преобразуются в обе стороны между блоком `mindmap` и обычным вложенным списком. Заголовки Org и карта редактируются независимо. Если нужен просмотр очень большого документа, отключите автоматический предпросмотр в его строке `#+startup:`.

Формулы и диаграммы обрабатываются локально. Дополнительные пакеты LaTeX для незнакомых команд устанавливаются отдельно через `tlmgr`. В профиле PlantUML `SANDBOX` внешние включения по пути или URL недоступны.

При недоступности PostgreSQL штатный `ob-sql` в Org 9.8.12 может заменить сохранённый результат пустой таблицей. После восстановления подключения повторите выполнение блока.

## Официальные источники

[edraw](https://github.com/misohena/el-easydraw), [org-mindmap](https://github.com/krvkir/org-mindmap), [Graphviz](https://graphviz.org/download/), [Temurin](https://adoptium.net/temurin/releases/), [PlantUML](https://plantuml.com/download), [TinyTeX](https://github.com/rstudio/tinytex-releases).
