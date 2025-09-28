#!/bin/bash

# Script to create symlinks from project directory to local copies
# Usage: ./create_symlinks.sh /path/to/project_root

TARGET_ROOT="$1"
if [ -z "$TARGET_ROOT" ]; then
  echo "Error: Provide the target project root path as argument"
  exit 1
fi

PROJECT_NAME=$(basename "$TARGET_ROOT")
SOURCE_DIR="./$PROJECT_NAME"

if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: Source directory $SOURCE_DIR does not exist"
  exit 1
fi

# Walk the source directory and create symlinks
find "$SOURCE_DIR" -type f -print0 | while IFS= read -r -d '' file; do
  rel_path="${file#"$SOURCE_DIR/"}"
  target_file="$TARGET_ROOT/$rel_path"
  mkdir -p "$(dirname "$target_file")"
  ln -sf "$PWD/$file" "$target_file"
done

echo "Symlinks created successfully"