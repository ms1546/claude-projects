#!/bin/bash

echo "🧹 最終クリーンアップスクリプト"
echo "================================"

# 1. シミュレータをリセット
echo "📱 シミュレータをリセット中..."
xcrun simctl shutdown all
xcrun simctl erase all

# 2. DerivedDataを完全削除
echo "🗑️  DerivedDataを削除中..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# 3. プロジェクトをクリーン
echo "🔨 プロジェクトをクリーン中..."
xcodebuild clean -workspace TrainAlert.xcworkspace -scheme TrainAlert -quiet

echo "✅ 完了！"
echo ""
echo "次のステップ:"
echo "1. Xcodeを再起動"
echo "2. シミュレータを起動"
echo "3. Product > Build (⌘B)"
echo "4. アプリを実行"