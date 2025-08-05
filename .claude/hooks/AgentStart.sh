#!/bin/bash
# Agent開始時の処理

AGENT_NAME=$(jq -r '.agentName // empty' <<< "$HOOK_INPUT" 2>/dev/null)

if [ -n "$AGENT_NAME" ]; then
    echo "🤖 Agent [$AGENT_NAME] を起動中..."
    
    # code-reviewerの場合
    if [ "$AGENT_NAME" = "code-reviewer" ]; then
        echo "📋 コードレビューの準備:"
        echo "- SwiftLintルールを確認"
        echo "- 最近の変更ファイルを特定"
        echo "- テストカバレッジを確認"
    fi
    
    # 音声通知
    afplay /System/Library/Sounds/Hero.aiff
fi
