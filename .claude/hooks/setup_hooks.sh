#!/bin/bash
# Hooksのセットアップスクリプト

echo "🔧 TrainAlert用Hooksをセットアップ中..."

# Hooksディレクトリの確認
HOOKS_DIR="$(pwd)/.claude/hooks"
if [ ! -d "$HOOKS_DIR" ]; then
    echo "❌ .claude/hooks ディレクトリが見つかりません"
    exit 1
fi

# 各Hookの登録
claude hook add SessionStart "afplay /System/Library/Sounds/Ping.aiff"
claude hook add Stop "$HOOKS_DIR/Stop.sh"
claude hook add UserPromptSubmit "$HOOKS_DIR/UserPromptSubmit.sh"
claude hook add ToolUse "$HOOKS_DIR/ToolUse.sh"
claude hook add PreCompact "$HOOKS_DIR/PreCompact.sh"
claude hook add AgentStart "$HOOKS_DIR/AgentStart.sh"

echo "✅ Hooksのセットアップが完了しました！"
echo ""
echo "設定されたHooks:"
echo "- SessionStart: セッション開始音"
echo "- Stop: Git状態とチケット進捗の確認"
echo "- UserPromptSubmit: キーワード検出とヒント表示"
echo "- ToolUse: 危険なコマンドの警告"
echo "- PreCompact: 会話圧縮前の作業記録"
echo "- AgentStart: Agent起動時の準備"
echo ""
echo "Hooksを確認: claude hook list"
