---
description: UI/UXデザインの確認と実装
argumentHints: "[component-name] [preview|implement]"
---

# デザイン実装コマンド

コンポーネント: $ARGUMENTS

@TrainAlert/docs/ui_design.md のデザイン仕様に基づいて:

1. 指定されたコンポーネントのデザインを確認
2. カラーパレット、フォント、スペーシングを適用
3. SwiftUIプレビューコードを生成

## 実装手順
- デザインシステムから適切なカラーとスタイルを選択
- アクセシビリティ要件を確認
- ダークモード対応を確認
- Dynamic Type対応を実装

## プレビュー生成
```swift
struct ${COMPONENT_NAME}_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // ライトモード
            ComponentView()
            
            // ダークモード
            ComponentView()
                .preferredColorScheme(.dark)
            
            // アクセシビリティサイズ
            ComponentView()
                .environment(\.sizeCategory, .accessibilityLarge)
        }
    }
}
```
