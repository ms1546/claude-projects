#!/bin/bash
# 会話圧縮前の処理

echo "📚 会話を圧縮中..."

# 現在の作業内容をメモリに保存
if [ -d "TrainAlert" ]; then
    # 進行中のチケットを記録
    ACTIVE_TICKETS=$(grep -l "In Progress" TrainAlert/docs/tickets/*.md 2>/dev/null | xargs basename -s .md | tr '\n' ',' | sed 's/,$//')
    
    if [ -n "$ACTIVE_TICKETS" ]; then
        echo "🎫 進行中のチケット: $ACTIVE_TICKETS"
        echo "メモ: これらのチケットの作業を継続してください"
    fi
    
    # 最近編集したファイルを記録
    echo "📝 最近編集したファイル:"
    find TrainAlert -name "*.swift" -mtime -1 -type f | head -5
fi

# 音声通知
afplay /System/Library/Sounds/Purr.aiff