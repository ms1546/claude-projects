#!/bin/bash
# GitHub MCP セットアップスクリプト

echo "🔐 GitHub MCP セキュアセットアップ"
echo ""

# .envファイルの確認
if [ ! -f ".env" ]; then
    echo "❌ .envファイルが見つかりません"
    echo ""
    echo "📝 セットアップ手順:"
    echo "1. cp .env.example .env"
    echo "2. .envファイルを編集してGitHub Personal Access Tokenを設定"
    echo "3. このスクリプトを再実行"
    exit 1
fi

# トークンの存在確認（値は表示しない）
if grep -q "YOUR_TOKEN_HERE" .env; then
    echo "⚠️  .envファイルのトークンを更新してください"
    exit 1
fi

# 環境変数を読み込み（エクスポートはしない）
source .env

# MCPサーバーの起動確認
echo "✅ GitHub Personal Access Tokenが設定されています"
echo ""
echo "🚀 GitHub MCPの使用方法:"
echo ""
echo "1. 環境変数を設定してClaude Codeを起動:"
echo "   source .env && claude"
echo ""
echo "2. または、direnvを使用:"
echo "   brew install direnv"
echo "   echo 'eval \"\$(direnv hook bash)\"' >> ~/.bashrc"
echo "   direnv allow ."
echo ""
echo "⚠️  セキュリティ注意事項:"
echo "- .envファイルは絶対にGitにコミットしない"
echo "- トークンは定期的に更新する"
echo "- 必要最小限の権限のみ付与する"