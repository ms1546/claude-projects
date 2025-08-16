# Xcodeに追加する必要があるファイル (2025年8月16日)

以下のファイルをXcodeプロジェクトに追加してください：

## Services グループ

1. **StationIDMapper.swift**
   - パス: `/Services/StationIDMapper.swift`
   - 説明: HeartRails APIとODPT APIのID変換マッピング

2. **APICacheManager.swift**
   - パス: `/Services/APICacheManager.swift`
   - 説明: APIレスポンスのキャッシュ管理

3. **StationNameRomanizer.swift**
   - パス: `/Services/StationNameRomanizer.swift`
   - 説明: 駅名のローマ字変換処理

## 追加手順

1. Xcodeでプロジェクトを開く
2. プロジェクトナビゲータで「Services」グループを右クリック
3. 「Add Files to "TrainAlert"...」を選択
4. 上記のファイルを選択
5. 「Copy items if needed」にチェック
6. 「Add to targets: TrainAlert」にチェック
7. 「Add」をクリック

## ビルド確認

ファイル追加後、以下を確認してください：
- ビルドエラーが解消されること
- 駅検索時にキャッシュが効いていること
- APIタイムアウトエラーが発生しないこと