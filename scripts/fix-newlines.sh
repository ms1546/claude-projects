#!/bin/bash

# Fix missing newlines at end of files

echo "🔧 Fixing missing newlines at end of files..."

# Swift files
echo "📱 Checking Swift files..."
find TrainAlert -type f -name "*.swift" -exec sh -c 'if [ -n "$(tail -c 1 "$1")" ]; then echo "" >> "$1" && echo "✅ Fixed: $1"; fi' _ {} \;

# Markdown files
echo "📝 Checking Markdown files..."
find . -type f -name "*.md" -not -path "./.git/*" -exec sh -c 'if [ -n "$(tail -c 1 "$1")" ]; then echo "" >> "$1" && echo "✅ Fixed: $1"; fi' _ {} \;

# Configuration files
echo "⚙️  Checking configuration files..."
for file in .swiftlint.yml .editorconfig .gitignore; do
    if [ -f "$file" ] && [ -n "$(tail -c 1 "$file")" ]; then
        echo "" >> "$file"
        echo "✅ Fixed: $file"
    fi
done

# Shell scripts
echo "🐚 Checking shell scripts..."
find . -type f -name "*.sh" -not -path "./.git/*" -exec sh -c 'if [ -n "$(tail -c 1 "$1")" ]; then echo "" >> "$1" && echo "✅ Fixed: $1"; fi' _ {} \;

echo "✨ Done! All files now have proper newlines at the end."
