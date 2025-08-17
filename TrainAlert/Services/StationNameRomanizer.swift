//
//  StationNameRomanizer.swift
//  TrainAlert
//
//  駅名のローマ字変換を専門に扱うクラス
//

import Foundation

/// 駅名ローマ字変換クラス
struct StationNameRomanizer {
    // MARK: - 主要駅名の完全マッピング
    
    /// よく使われる駅名の正確なローマ字表記
    private static let exactMapping: [String: String] = [
        // 山手線
        "東京": "Tokyo",
        "有楽町": "Yurakucho",
        "新橋": "Shimbashi",
        "浜松町": "Hamamatsucho",
        "田町": "Tamachi",
        "高輪ゲートウェイ": "TakanawagGateway",
        "品川": "Shinagawa",
        "大崎": "Osaki",
        "五反田": "Gotanda",
        "目黒": "Meguro",
        "恵比寿": "Ebisu",
        "渋谷": "Shibuya",
        "原宿": "Harajuku",
        "代々木": "Yoyogi",
        "新宿": "Shinjuku",
        "新大久保": "ShinOkubo",
        "高田馬場": "Takadanobaba",
        "目白": "Mejiro",
        "池袋": "Ikebukuro",
        "大塚": "Otsuka",
        "巣鴨": "Sugamo",
        "駒込": "Komagome",
        "田端": "Tabata",
        "西日暮里": "NishiNippori",
        "日暮里": "Nippori",
        "鶯谷": "Uguisudani",
        "上野": "Ueno",
        "御徒町": "Okachimachi",
        "秋葉原": "Akihabara",
        "神田": "Kanda",
        
        // 中央線主要駅
        "御茶ノ水": "Ochanomizu",
        "水道橋": "Suidobashi",
        "飯田橋": "Iidabashi",
        "市ヶ谷": "Ichigaya",
        "四ツ谷": "Yotsuya",
        "信濃町": "Shinanomachi",
        "千駄ヶ谷": "Sendagaya",
        "中野": "Nakano",
        "高円寺": "Koenji",
        "阿佐ヶ谷": "Asagaya",
        "荻窪": "Ogikubo",
        "西荻窪": "NishiOgikubo",
        "吉祥寺": "Kichijoji",
        "三鷹": "Mitaka",
        "武蔵境": "MusashiSakai",
        "東小金井": "HigashiKoganei",
        "武蔵小金井": "MusashiKoganei",
        "国分寺": "Kokubunji",
        "西国分寺": "NishiKokubunji",
        "国立": "Kunitachi",
        "立川": "Tachikawa",
        "日野": "Hino",
        "豊田": "Toyoda",
        "八王子": "Hachioji",
        "西八王子": "NishiHachioji",
        "高尾": "Takao",
        
        // 総武線
        "両国": "Ryogoku",
        "浅草橋": "Asakusabashi",
        "錦糸町": "Kinshicho",
        "亀戸": "Kameido",
        "平井": "Hirai",
        "新小岩": "ShinKoiwa",
        "小岩": "Koiwa",
        "市川": "Ichikawa",
        "本八幡": "MotoYawata",
        "下総中山": "ShimosakaNakayama",
        "西船橋": "NishiFunabashi",
        "船橋": "Funabashi",
        "東船橋": "HigashiFunabashi",
        "津田沼": "Tsudanuma",
        "幕張本郷": "MakuhariHongo",
        "幕張": "Makuhari",
        "新検見川": "ShinKemigawa",
        "稲毛": "Inage",
        "西千葉": "NishiChiba",
        "千葉": "Chiba",
        
        // その他主要駅
        "横浜": "Yokohama",
        "川崎": "Kawasaki",
        "蒲田": "Kamata",
        "大井町": "Oimachi",
        "大森": "Omori",
        "大宮": "Omiya",
        "浦和": "Urawa",
        "赤羽": "Akabane",
        "亀有": "Kameari",
        "金町": "Kanamachi",
        "松戸": "Matsudo",
        "柏": "Kashiwa",
        "我孫子": "Abiko",
        "天王台": "Tennodai",
        "取手": "Toride",
        
        // 東京メトロ千代田線
        "代々木公園": "YoyogiKoen",
        "明治神宮前": "MeijiJingumae",
        "表参道": "OmoteSando",
        "国会議事堂前": "KokkaiGijidomae",
        "霞ヶ関": "Kasumigaseki",
        "日比谷": "Hibiya",
        "二重橋前": "Nijubashimae",
        "大手町": "Otemachi",
        "新御茶ノ水": "ShinOchanomizu",
        "湯島": "Yushima",
        "根津": "Nezu",
        "千駄木": "Sendagi",
        "町屋": "Machiya",
        "北綾瀬": "KitaAyase",
        
        // 東京メトロその他
        "永田町": "Nagatacho",
        "赤坂": "Akasaka",
        "溜池山王": "TameikeSanno",
        "虎ノ門": "Toranomon",
        "銀座": "Ginza",
        "日本橋": "Nihombashi",
        "三越前": "Mitsukoshimae",
        "神保町": "Jimbocho",
        "九段下": "Kudanshita",
        "半蔵門": "Hanzomon",
        "青山一丁目": "AoyamaItchome",
        
        // 小田急線
        "南新宿": "MinamiShinjuku",
        "参宮橋": "Sangubashi",
        "代々木八幡": "YoyogiHachiman",
        "代々木上原": "YoyogiUehara",
        "東北沢": "HigashiKitazawa",
        "下北沢": "ShimoKitazawa",
        "世田谷代田": "SetagayaDaita",
        "梅ヶ丘": "Umegaoka",
        "豪徳寺": "Gotokuji",
        "経堂": "Kyodo",
        "千歳船橋": "ChitoseFunabashi",
        "祥寿寺": "Soshigaya",
        "成城学園前": "SeijogakuenMae",
        "喜多見": "Kitami",
        "狛江": "Komae",
        "和泉多摩川": "IzumiTamagawa",
        "登戸": "Noborito",
        "向ヶ丘遊園": "MukogaokaYuen",
        "生田": "Ikuta",
        "読売ランド前": "YomiurilandMae",
        "百合ヶ丘": "Yurigaoka",
        "新百合ヶ丘": "ShinYurigaoka",
        "柿生": "Kakio",
        "鶴川": "Tsurukawa",
        "玉川学園前": "TamagawagakuenMae",
        "町田": "Machida",
        "相模大野": "SagamiOno",
        "小田急相模原": "OdakyuSagamihara",
        "相武台前": "SobudaiMae",
        "座間": "Zama",
        "海老名": "Ebina",
        "厚木": "Atsugi",
        "本厚木": "HonAtsugi",
        "愛甲石田": "AikoIshida",
        "伊勢原": "Isehara",
        "鶴巻温泉": "TsurumakinOnsen",
        "東海大学前": "TokaidaigakuMae",
        "秦野": "Hadano",
        "渋沢": "Shibusawa",
        "新松田": "ShinMatsuda",
        "開成": "Kaisei",
        "栗平": "Kurihira",
        "富水": "Tomizawa",
        "螢沢": "Hotaruzawa",
        "足柄": "Ashigara",
        "小田原": "Odawara"
    ]
    
    // MARK: - かな→ローマ字変換テーブル
    
    /// ひらがな・カタカナ→ローマ字の基本変換
    private static let kanaToRoman: [String: String] = [
        // あ行
        "あ": "a", "い": "i", "う": "u", "え": "e", "お": "o",
        "ア": "a", "イ": "i", "ウ": "u", "エ": "e", "オ": "o",
        
        // か行
        "か": "ka", "き": "ki", "く": "ku", "け": "ke", "こ": "ko",
        "カ": "ka", "キ": "ki", "ク": "ku", "ケ": "ke", "コ": "ko",
        "が": "ga", "ぎ": "gi", "ぐ": "gu", "げ": "ge", "ご": "go",
        "ガ": "ga", "ギ": "gi", "グ": "gu", "ゲ": "ge", "ゴ": "go",
        
        // さ行
        "さ": "sa", "し": "shi", "す": "su", "せ": "se", "そ": "so",
        "サ": "sa", "シ": "shi", "ス": "su", "セ": "se", "ソ": "so",
        "ざ": "za", "じ": "ji", "ず": "zu", "ぜ": "ze", "ぞ": "zo",
        "ザ": "za", "ジ": "ji", "ズ": "zu", "ゼ": "ze", "ゾ": "zo",
        
        // た行
        "た": "ta", "ち": "chi", "つ": "tsu", "て": "te", "と": "to",
        "タ": "ta", "チ": "chi", "ツ": "tsu", "テ": "te", "ト": "to",
        "だ": "da", "ぢ": "ji", "づ": "zu", "で": "de", "ど": "do",
        "ダ": "da", "ヂ": "ji", "ヅ": "zu", "デ": "de", "ド": "do",
        
        // な行
        "な": "na", "に": "ni", "ぬ": "nu", "ね": "ne", "の": "no",
        "ナ": "na", "ニ": "ni", "ヌ": "nu", "ネ": "ne", "ノ": "no",
        
        // は行
        "は": "ha", "ひ": "hi", "ふ": "fu", "へ": "he", "ほ": "ho",
        "ハ": "ha", "ヒ": "hi", "フ": "fu", "ヘ": "he", "ホ": "ho",
        "ば": "ba", "び": "bi", "ぶ": "bu", "べ": "be", "ぼ": "bo",
        "バ": "ba", "ビ": "bi", "ブ": "bu", "ベ": "be", "ボ": "bo",
        "ぱ": "pa", "ぴ": "pi", "ぷ": "pu", "ぺ": "pe", "ぽ": "po",
        "パ": "pa", "ピ": "pi", "プ": "pu", "ペ": "pe", "ポ": "po",
        
        // ま行
        "ま": "ma", "み": "mi", "む": "mu", "め": "me", "も": "mo",
        "マ": "ma", "ミ": "mi", "ム": "mu", "メ": "me", "モ": "mo",
        
        // や行
        "や": "ya", "ゆ": "yu", "よ": "yo",
        "ヤ": "ya", "ユ": "yu", "ヨ": "yo",
        
        // ら行
        "ら": "ra", "り": "ri", "る": "ru", "れ": "re", "ろ": "ro",
        "ラ": "ra", "リ": "ri", "ル": "ru", "レ": "re", "ロ": "ro",
        
        // わ行
        "わ": "wa", "を": "wo", "ん": "n",
        "ワ": "wa", "ヲ": "wo", "ン": "n",
        
        // 小文字
        "ゃ": "ya", "ゅ": "yu", "ょ": "yo",
        "ャ": "ya", "ュ": "yu", "ョ": "yo",
        "っ": "", "ッ": "",
        
        // 長音
        "ー": ""
    ]
    
    // MARK: - 漢字の読み仮名（駅名でよく使われるもの）
    
    /// 駅名でよく使われる漢字の読み
    private static let kanjiReadings: [String: String] = [
        // 方角
        "東": "higashi",
        "西": "nishi",
        "南": "minami",
        "北": "kita",
        "中": "naka",
        "上": "kami",
        "下": "shimo",
        "新": "shin",
        "元": "moto",
        "本": "hon",
        
        // 地形
        "川": "kawa",
        "河": "kawa",
        "山": "yama",
        "丘": "oka",
        "台": "dai",
        "原": "hara",
        "野": "no",
        "田": "ta",
        "島": "shima",
        "崎": "saki",
        "沢": "sawa",
        "谷": "ya",
        "橋": "bashi",
        "池": "ike",
        "沼": "numa",
        "浜": "hama",
        "海": "umi",
        "湖": "ko",
        "港": "minato",
        
        // その他よく使われる漢字
        "駅": "eki",
        "前": "mae",
        "町": "machi",
        "市": "shi",
        "村": "mura",
        "宮": "miya",
        "寺": "dera",
        "神": "kami",
        "大": "o",
        "小": "ko",
        "高": "taka",
        "永": "naga",
        "長": "naga",
        "青": "ao",
        "赤": "aka",
        "白": "shiro",
        "黒": "kuro",
        "緑": "midori",
        "金": "kane",
        "銀": "gin",
        "鉄": "tetsu",
        "木": "ki",
        "森": "mori",
        "林": "bayashi",
        "花": "hana",
        "桜": "sakura",
        "松": "matsu",
        "竹": "take",
        "梅": "ume",
        "富": "tomi",
        "士": "shi",
        "見": "mi",
        "月": "tsuki",
        "日": "hi",
        "星": "hoshi",
        "空": "sora",
        "雲": "kumo",
        "風": "kaze",
        "雨": "ame",
        "雪": "yuki",
        "春": "haru",
        "夏": "natsu",
        "秋": "aki",
        "冬": "fuyu",
        
        // 追加の駅名用漢字
        "生": "iku",
        "向": "muko",
        "遊": "yu",
        "園": "en",
        "読": "yomi",
        "売": "uri",
        "百": "yuri",
        "合": "go",
        "柿": "kaki",
        "鶴": "tsuru",
        "玉": "tama",
        "学": "gaku",
        "相": "saga",
        "模": "mi",
        "武": "bu",
        "座": "za",
        "間": "ma",
        "老": "ebi",
        "名": "na",
        "厚": "atsu",
        "愛": "aiko",
        "甲": "ko",
        "石": "ishi",
        "伊": "i",
        "勢": "se",
        "巻": "maki",
        "温": "on",
        "泉": "sen",
        "秦": "hada",
        "渋": "shibu",
        "開": "kai",
        "成": "sei",
        "栗": "kuri",
        "平": "hira",
        "蛍": "hotaru",
        "足": "ashi",
        "柄": "gara"
    ]
    
    // MARK: - Public Methods
    
    /// 駅名をローマ字に変換
    static func romanize(_ stationName: String) -> String {
        // まず完全一致を確認
        if let exact = exactMapping[stationName] {
            return exact
        }
        
        // 「駅」を除去
        let name = stationName.replacingOccurrences(of: "駅", with: "")
        
        // 簡易的な漢字→かな→ローマ字変換
        // より完全な実装には、MeCabやCoreNLPなどの形態素解析が必要
        return convertToRoman(name)
    }
    
    // MARK: - Private Methods
    
    /// 文字列をローマ字に変換
    private static func convertToRoman(_ text: String) -> String {
        var result = ""
        var i = text.startIndex
        
        while i < text.endIndex {
            let char = String(text[i])
            
            // かなの場合
            if let roman = kanaToRoman[char] {
                result += roman
                i = text.index(after: i)
                continue
            }
            
            // 漢字の場合（簡易実装）
            if let reading = kanjiReadings[char] {
                result += reading
                i = text.index(after: i)
                continue
            }
            
            // その他の文字（変換できない漢字など）はスキップ
            // ASCIIの場合はそのまま追加
            if char.unicodeScalars.first?.isASCII == true {
                result += char
            }
            i = text.index(after: i)
        }
        
        // 最初の文字を大文字に
        if !result.isEmpty {
            let firstChar = result.prefix(1).uppercased()
            let rest = result.dropFirst()
            result = firstChar + rest
        }
        
        return result
    }
}
