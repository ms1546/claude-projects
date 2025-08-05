#!/bin/bash
# PRレビューコメント受信時の処理

# Hook入力からPR番号を取得（将来的な拡張用）
PR_INFO=$(jq -r '.pr_number // empty' <<< "$HOOK_INPUT" 2>/dev/null)

if [ -n "$PR_INFO" ]; then
    echo "📬 PR #$PR_INFO に新しいレビューコメントがあります"
    echo "確認: /pr-comments $PR_INFO"
    
    # 音声通知
    afplay /System/Library/Sounds/Glass.aiff
fi

# 現在のブランチのPRをチェック
CURRENT_PR=$(gh pr view --json number -q .number 2>/dev/null || echo "")
if [ -n "$CURRENT_PR" ]; then
    echo "💡 現在作業中のPR: #$CURRENT_PR"
    echo "レビュー確認: /pr-comments"
fi
