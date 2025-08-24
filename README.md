# Sych

Игровой проект на движке Godot 4.4.

## Разработка

### Требования
- Godot 4.4+
- Git

### Структура проекта
```
sych/
├── assets/          # Игровые ресурсы
│   ├── sounds/      # Звуковые файлы
│   └── textures/    # Текстуры и изображения
├── scenes/          # Сцены Godot
├── scripts/         # Скрипты GDScript/C#
├── project.godot    # Главный файл проекта
└── icon.svg         # Иконка проекта
```

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
