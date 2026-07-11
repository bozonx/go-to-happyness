#!/usr/bin/env bash
#
# Установка godot_voxel (GDExtension) в проект.
# Либа не хранится в git (см. .gitignore) — этот скрипт её скачивает и распаковывает.
#
#   Использование:
#     ./install_voxel.sh            # поставить, если ещё не стоит
#     ./install_voxel.sh --force    # переустановить поверх
#
set -euo pipefail

# Версия расширения (GDExtension-сборка для Godot 4.5+). Меняй тут при апгрейде.
VERSION="v1.6x"
URL="https://github.com/Zylann/godot_voxel/releases/download/${VERSION}/GodotVoxelExtension.zip"

# Корень проекта = папка со скриптом.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="${ROOT}/addons/zylann.voxel"
MARKER="${DEST}/voxel.gdextension"

FORCE=0
[[ "${1:-}" == "--force" ]] && FORCE=1

if [[ -f "$MARKER" && "$FORCE" -eq 0 ]]; then
	echo "✓ godot_voxel уже установлен: ${DEST}"
	echo "  (перезаписать: ./install_voxel.sh --force)"
	exit 0
fi

# Нужен распаковщик.
command -v unzip >/dev/null 2>&1 || { echo "✗ Нужна утилита 'unzip'"; exit 1; }

# Скачивание (curl или wget).
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
ZIP="${TMP}/GodotVoxelExtension.zip"

echo "→ Скачиваю ${VERSION} (~41 МБ)…"
if command -v curl >/dev/null 2>&1; then
	curl -fL --retry 3 -o "$ZIP" "$URL"
elif command -v wget >/dev/null 2>&1; then
	wget -O "$ZIP" "$URL"
else
	echo "✗ Нужен curl или wget"; exit 1
fi

# Проверка целостности архива.
unzip -tq "$ZIP" >/dev/null || { echo "✗ Битый архив"; exit 1; }

echo "→ Распаковываю в ${ROOT}/addons/ …"
rm -rf "$DEST"
unzip -oq "$ZIP" -d "$ROOT"

# Оставляем только нужные платформы (Linux + Windows), чтобы не держать 100 МБ.
# Закомментируй строку ниже, если разрабатываешь под macОS/Android/iOS.
rm -rf "${DEST}/bin/"libvoxel.android.* "${DEST}/bin/"libvoxel.ios.* "${DEST}/bin/"libvoxel.macos.* 2>/dev/null || true

echo "✓ Готово. Перезапусти Godot, если он открыт."
