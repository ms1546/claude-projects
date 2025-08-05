#!/bin/bash
# ツール使用時の監視

# ツール情報を読み取り
TOOL_NAME=$(jq -r '.toolName' <<< "$HOOK_INPUT")

# Bashコマンドの監視
if [ "$TOOL_NAME" = "Bash" ]; then
    COMMAND=$(jq -r '.input.command // empty' <<< "$HOOK_INPUT" 2>/dev/null)
    
    # 危険なコマンドの警告
    if echo "$COMMAND" | grep -qE "rm -rf|sudo rm|:>|truncate"; then
        echo "⚠️  危険なコマンドを検出: $COMMAND"
        afplay /System/Library/Sounds/Basso.aiff
    fi
    
    # ビルドコマンドの通知
    if echo "$COMMAND" | grep -q "xcodebuild"; then
        echo "🏗️  Xcodeビルド開始..."
        afplay /System/Library/Sounds/Pop.aiff
    fi
fi

# ファイル編集の監視
if [ "$TOOL_NAME" = "Edit" ] || [ "$TOOL_NAME" = "Write" ]; then
    FILE_PATH=$(jq -r '.input.file_path // empty' <<< "$HOOK_INPUT" 2>/dev/null)
    
    # 重要ファイルの編集警告
    if echo "$FILE_PATH" | grep -qE "Info\.plist|\.xcodeproj|Podfile"; then
        echo "📝 重要なファイルを編集中: $FILE_PATH"
    fi
fi
