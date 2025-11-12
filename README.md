# Sych

Игровой проект на движке Godot 4.5.

## Разработка

### Требования
- Godot 4.5+
- Git

### Структура проекта
```
sych/
├── assets/                # Исходные ассеты (в т.ч. LFS)
│   ├── audio/             # Звуковые ресурсы
│   ├── models/            # 3D-модели
│   └── textures/
│       └── characters/    # Портреты и биллборды персонажей
├── scenes/                # Игровые сцены
│   ├── actors/            # Сцены персонажей (игрок, NPC)
│   └── world/             # Мир: шарага, двор, внешние локации
├── scripts/               # GDScript-логика
│   ├── actors/            # Скрипты персонажей
│   ├── tools/             # Отладочные и вспомогательные скрипты
│   └── world/             # Логика мира и локаций
├── project.godot          # Файл проекта Godot
└── icon.svg               # Иконка проекта
```
С
### Запуск проекта
1. Клонируйте репозиторий
2. Откройте проект в Godot
3. Запустите сцену

## Git Workflow

Проект настроен для работы с Git и Git LFS. Основные файлы `.gitignore` и `.gitattributes` уже настроены согласно best practices для Godot.

### Настройка Git LFS

Git LFS (Large File Storage) используется для хранения больших файлов (текстуры, аудио, 3D модели) отдельно от основного репозитория.

#### Установка Git LFS:

**macOS:**
```bash
brew install git-lfs
```

**Windows:**
Скачайте с [git-lfs.github.io](https://git-lfs.github.io/)

**Linux (Ubuntu/Debian):**
```bash
sudo apt install git-lfs
```

#### Инициализация в проекте:
```bash
# После клонирования репозитория
git lfs install
git lfs pull
```

#### Проверка LFS файлов:
```bash
git lfs ls-files  # показать LFS файлы
git lfs status    # статус LFS файлов
```

### Настройки экспорта
- `export_presets.cfg` - отслеживается в Git (настройки команды)
- `export_credentials.cfg` - игнорируется (приватные ключи)

### Коммиты
- Делайте коммиты при завершении значимых изменений
- Используйте понятные сообщения коммитов
- Коммитьте минимум раз в день по окончании работы
- LFS файлы автоматически обрабатываются при `git add` и `git commit`

### Важные команды для команды:
```bash
# Первоначальная настройка (делается один раз на машине)
git lfs install

# После клонирования проекта
git lfs pull

# Проверка размера репозитория
git count-objects -vH
``` 

## Релизы и деплой

1. Создайте рабочую ветку `feature/...` (например, `feature/dialogue-system`), фиксируйте изменения в стиле Conventional Commits и опишите функциональность в PR на `main`.
2. После мержа Release Please автоматически откроет PR `chore: release` с обновлёнными `VERSION` и `CHANGELOG.md`. Проверьте заметки и смёржьте PR.
3. Мерж релизного PR создаёт тег `vX.Y.Z`; его появление запускает workflow `build-and-deploy`, который экспортирует HTML5 сборку Godot в `build/web` и выкладывает её в `occultnerdbird/sych-game` через секрет `SYCH_GAME_TOKEN`.
4. GitHub Pages на `sych-game` обновляется автоматически — итоговую версию смотрите по адресу `https://occultnerdbird.github.io/sych-game/`.
5. Для повторного деплоя перезапустите workflow на нужном теге или пересоздайте тег `vX.Y.Z`.

Чтобы Telegram-бот присылал уведомления после публикации релиза, добавьте в `Settings → Secrets and variables → Actions` секреты `TELEGRAM_BOT_TOKEN` (токен бота) и `TELEGRAM_CHAT_ID` (ID целевого чата).
После успешного релиза бот автоматически пришлёт сообщение в чат с описанием изменений и ссылкой на игру.
