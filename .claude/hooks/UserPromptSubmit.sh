#!/bin/bash
# ユーザープロンプト送信時の処理

# プロンプトの内容を読み取り
PROMPT=$(jq -r '.prompt' <<< "$HOOK_INPUT")

# テスト関連のキーワードチェック
if echo "$PROMPT" | grep -qiE "test|テスト|spec"; then
    echo "🧪 テスト関連のタスクを検出しました"
    echo "ヒント: /swift-test コマンドでテストを実行できます"
fi

# ビルド関連のキーワードチェック
if echo "$PROMPT" | grep -qiE "build|ビルド|archive|testflight"; then
    echo "🔨 ビルド関連のタスクを検出しました"
    echo "ヒント: /build コマンドでビルド操作ができます"
fi

# API関連のキーワードチェック
if echo "$PROMPT" | grep -qiE "api|heartrails|openai"; then
    echo "🌐 API関連のタスクを検出しました"
    echo "ヒント: /api-test コマンドでAPI動作確認ができます"
fi

# チケット番号の検出
if echo "$PROMPT" | grep -qE "#[0-9]{3}|ticket.*[0-9]{3}"; then
    TICKET_NUM=$(echo "$PROMPT" | grep -oE "[0-9]{3}" | head -1)
    echo "🎫 チケット #$TICKET_NUM に関連するタスクです"
    echo "ヒント: /ticket start $TICKET_NUM でチケットを開始できます"
fi
