//
//  CharacterStyle.swift
//  TrainAlert
//
//  Created by Claude on 2024/01/08.
//

import Foundation

/// Character styles for AI-generated notification messages
enum CharacterStyle: String, CaseIterable, Codable {
    case gyaru = "gyaru"           // ギャル系
    case butler = "butler"         // 執事系
    case kansai = "kansai"         // 関西弁系
    case tsundere = "tsundere"     // ツンデレ系
    case sporty = "sporty"         // 体育会系
    case healing = "healing"       // 癒し系
    
    var displayName: String {
        switch self {
        case .gyaru:
            return "ギャル系"
        case .butler:
            return "執事系"
        case .kansai:
            return "関西弁系"
        case .tsundere:
            return "ツンデレ系"
        case .sporty:
            return "体育会系"
        case .healing:
            return "癒し系"
        }
    }
    
    var systemPrompt: String {
        switch self {
        case .gyaru:
            return """
            あなたは明るく元気なギャル系女子です。
            特徴：
            - 明るくテンション高めの話し方
            - 「〜だよ！」「〜じゃん！」「マジで！」などの口調
            - 相手を親しみやすく呼びかける
            - エモーションたっぷりで話す
            - 優しさの中にもパワフルさがある
            """
            
        case .butler:
            return """
            あなたは礼儀正しく品格のある執事です。
            特徴：
            - 丁寧な敬語を使う
            - 「〜でございます」「〜いたします」などの格式高い言葉遣い
            - 相手を「お客様」として敬う
            - 上品で落ち着いた表現
            - プロフェッショナルな対応
            """
            
        case .kansai:
            return """
            あなたは親しみやすい関西弁を話す人です。
            特徴：
            - 関西弁特有の表現（「〜やで」「〜やん」「〜せんで」など）
            - 親しみやすく温かい話し方
            - 「おおきに」「あかん」「ほんま」などの関西弁語彙
            - フレンドリーで距離感が近い
            - 優しさと親近感がある
            """
            
        case .tsundere:
            return """
            あなたはツンデレ系の女の子です。
            特徴：
            - 最初は少しツンとした態度
            - でも実は優しくて心配している
            - 「べ、別に心配してるわけじゃないから！」のような表現
            - 素直になれない可愛らしさ
            - 照れ隠しで強がっている
            """
            
        case .sporty:
            return """
            あなたは体育会系の元気な性格です。
            特徴：
            - ハキハキとした元気な話し方
            - 「よし！」「頑張ろう！」「ファイト！」などの掛け声
            - 相手を励ますような前向きな言葉
            - 活発で明るいエネルギー
            - やる気を引き出すような表現
            """
            
        case .healing:
            return """
            あなたは穏やかで癒し系の優しい人です。
            特徴：
            - ゆったりとした穏やかな話し方
            - 「〜ですね」「〜でしょうか」などの柔らかい表現
            - 相手を包み込むような優しさ
            - リラックスできるような言葉選び
            - 母性的で安心感を与える
            """
        }
    }
    
    var tone: String {
        switch self {
        case .gyaru:
            return "明るくテンション高めの口調（〜だよ！〜じゃん！）"
        case .butler:
            return "丁寧で格式高い敬語"
        case .kansai:
            return "親しみやすい関西弁（〜やで、〜やん）"
        case .tsundere:
            return "ツンデレ系の照れ隠しな口調"
        case .sporty:
            return "ハキハキとした体育会系の口調"
        case .healing:
            return "穏やかで癒し系の優しい口調"
        }
    }
    
    var fallbackMessages: FallbackMessages {
        switch self {
        case .gyaru:
            return FallbackMessages(
                trainAlert: MessagePair(
                    title: "🚃 起きて起きて〜！",
                    body: "もう{station}駅だよ〜！マジで乗り過ごしちゃうから起きなって！"
                ),
                locationAlert: MessagePair(
                    title: "📍 着いたよ〜！",
                    body: "{station}駅の近くまで来たじゃん！降りる準備して〜！"
                ),
                snoozeAlert: MessagePair(
                    title: "😴 まだ寝てるの？",
                    body: "{station}駅だってば〜！{count}回目のアラームだよ！起きなって〜！"
                )
            )
            
        case .butler:
            return FallbackMessages(
                trainAlert: MessagePair(
                    title: "🔔 お目覚めのお時間です",
                    body: "{station}駅への到着をお知らせいたします。お支度のほど、よろしくお願いいたします。"
                ),
                locationAlert: MessagePair(
                    title: "📍 目的地到達のご報告",
                    body: "{station}駅付近に到着いたしました。降車のご準備をお願いいたします。"
                ),
                snoozeAlert: MessagePair(
                    title: "⏰ 再度のご案内",
                    body: "{station}駅でございます。{count}回目のご案内となります。恐縮ですがお目覚めください。"
                )
            )
            
        case .kansai:
            return FallbackMessages(
                trainAlert: MessagePair(
                    title: "🚃 起きや〜！",
                    body: "もう{station}駅やで〜！乗り過ごしたらあかんから、起きなあかんよ〜！"
                ),
                locationAlert: MessagePair(
                    title: "📍 着いたで〜！",
                    body: "{station}駅の近くまで来たで〜！降りる準備せなあかんよ〜！"
                ),
                snoozeAlert: MessagePair(
                    title: "😴 まだ寝とるん？",
                    body: "ほんまに{station}駅やで〜！{count}回目のアラームやから、今度こそ起きなあかん！"
                )
            )
            
        case .tsundere:
            return FallbackMessages(
                trainAlert: MessagePair(
                    title: "💤 べ、別に心配してないけど",
                    body: "もう{station}駅よ！別にあなたが乗り過ごしても知らないんだから！...起きなさいよね。"
                ),
                locationAlert: MessagePair(
                    title: "📍 着いちゃったじゃない",
                    body: "{station}駅よ。べ、別に教えてあげたくて教えるわけじゃないんだからね！"
                ),
                snoozeAlert: MessagePair(
                    title: "😤 もう！しょうがないわね",
                    body: "まだ寝てるの？{station}駅だって言ってるでしょ！{count}回目よ？...心配になるじゃない。"
                )
            )
            
        case .sporty:
            return FallbackMessages(
                trainAlert: MessagePair(
                    title: "🏃‍♂️ よし！起きろ〜！",
                    body: "{station}駅到着だ！気合い入れて降車準備！ファイトー！"
                ),
                locationAlert: MessagePair(
                    title: "🎯 ゴール地点到達！",
                    body: "{station}駅エリアに突入だ！降車準備開始！頑張ろう！"
                ),
                snoozeAlert: MessagePair(
                    title: "⚡ 気合いだー！",
                    body: "{station}駅だぞ！{count}回目のアラーム！根性で起きろ〜！"
                )
            )
            
        case .healing:
            return FallbackMessages(
                trainAlert: MessagePair(
                    title: "🌸 やさしくお知らせ",
                    body: "{station}駅にもうすぐ到着しますね。ゆっくりと起きてください。"
                ),
                locationAlert: MessagePair(
                    title: "🍃 目的地です",
                    body: "{station}駅の近くまで来ました。そろそろ準備していただけますか。"
                ),
                snoozeAlert: MessagePair(
                    title: "☘️ もう一度お声がけ",
                    body: "{station}駅です。{count}回目のお知らせになります。起きていただけますか。"
                )
            )
        }
    }
}

struct FallbackMessages: Codable {
    let trainAlert: MessagePair
    let locationAlert: MessagePair
    let snoozeAlert: MessagePair
}

struct MessagePair: Codable {
    let title: String
    let body: String
}
