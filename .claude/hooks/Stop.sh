#!/bin/bash
# セッション終了時にプロジェクト状態を保存

# Git status確認
if [ -d .git ]; then
    echo "📋 Git status:"
    git status --short
    
    # 未コミットの変更がある場合は警告
    if ! git diff-index --quiet HEAD --; then
        echo "⚠️  未コミットの変更があります！"
    fi
fi

# チケット進捗確認
if [ -f "TrainAlert/docs/tickets/ticket_status.md" ]; then
    echo "📊 チケット進捗:"
    grep -E "In Progress|Completed" TrainAlert/docs/tickets/ticket_status.md | head -5
fi

# 作業時間記録
echo "⏱️  セッション時間: $(date)"

# 音声通知
afplay /System/Library/Sounds/Glass.aiff
