---
description: serenaでコードベースを分析
argumentHints: "[structure|dependencies|complexity|unused] [path]"
---

# コード分析コマンド

分析タイプ: $ARGUMENTS

serenaのツールを組み合わせてコードベースを詳細に分析します。

## 使用例
- `/analyze structure TrainAlert/` - プロジェクト構造を分析
- `/analyze dependencies LocationManager` - 依存関係を分析
- `/analyze complexity Views/` - 複雑度の高い箇所を特定
- `/analyze unused` - 未使用コードを検出

## 分析内容

### 1. structure（構造分析）
- `get_symbols_overview`でプロジェクト構造を可視化
- クラス階層、モジュール構成を理解
- ファイル間の関係性を把握

### 2. dependencies（依存関係）
- `find_referencing_symbols`で依存を追跡
- 循環依存の検出
- 影響範囲の特定

### 3. complexity（複雑度）
- 大きなクラス/メソッドを検出
- ネストの深い処理を特定
- リファクタリング候補を提案

### 4. unused（未使用コード）
- 参照されていないシンボルを検出
- デッドコードの特定
- 削除可能な要素をリストアップ

分析結果は見やすくフォーマットして、改善提案と共に表示します。
