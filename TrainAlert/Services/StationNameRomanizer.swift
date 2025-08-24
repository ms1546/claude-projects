//
//  StationNameRomanizer.swift
//  TrainAlert
//
//  駅名のローマ字変換を専門に扱うクラス
//

import Foundation

/// 駅名ローマ字変換クラス
struct StationNameRomanizer {
    // MARK: - Singleton
    static let shared = StationNameRomanizer()
    
    // MARK: - 主要駅名の完全マッピング
    
    /// よく使われる駅名の正確なローマ字表記
    private static let exactMapping: [String: String] = [
        // 全路線共通の駅名マッピング（あいうえお順）
        
        // あ
        "あ": "a",
        "赤羽岩淵": "AkabaneIwabuchi",
        
        // お
        "お台場海浜公園": "OdaibaKaihinKoen",
        
        // か
        "か": "ka",
        
        // が
        "が": "ga",
        
        // さ
        "さ": "sa",
        
        // ざ
        "ざ": "za",
        
        // た
        "た": "ta",
        
        // だ
        "だ": "da",
        
        // な
        "な": "na",
        
        // は
        "は": "ha",
        
        // ば
        "ば": "ba",
        
        // ぱ
        "ぱ": "pa",
        
        // ま
        "ま": "ma",
        
        // ゃ
        "ゃ": "ya",
        
        // や
        "や": "ya",
        
        // ら
        "ら": "ra",
        
        // わ
        "わ": "wa",
        
        // ア
        "ア": "a",
        
        // イ
        "板橋区役所前": "ItabashiKuyakushomae",
        "板橋本町": "ItabashiHoncho",
        
        // カ
        "カ": "ka",
        
        // ガ
        "ガ": "ga",
        
        // サ
        "サ": "sa",
        
        // ザ
        "ザ": "za",
        
        // タ
        "タ": "ta",
        
        // ダ
        "ダ": "da",
        
        // テ
        "テレコムセンター": "TelecomCenter",
        
        // ナ
        "ナ": "na",
        
        // ハ
        "ハ": "ha",
        
        // バ
        "バ": "ba",
        
        // パ
        "パ": "pa",
        
        // マ
        "マ": "ma",
        
        // ャ
        "ャ": "ya",
        
        // ヤ
        "ヤ": "ya",
        
        // ラ
        "ラ": "ra",
        
        // ワ
        "ワ": "wa",
        
        // 一
        "一之江": "Ichinoe",
        
        // 三
        "三ノ輪": "Minowa",
        "三田": "Mita",
        "三越前": "Mitsukoshimae",
        "三鷹": "Mitaka",
        
        // 上
        "上": "kami",
        "上野": "Ueno",
        "上野広小路": "UenoHirokoji",
        "上野御徒町": "UenoOkachimachi",
        
        // 下
        "下": "shimo",
        "下北沢": "ShimoKitazawa",
        "下総中山": "ShimosakaNakayama",
        
        // 世
        "世田谷代田": "SetagayaDaita",
        
        // 丘
        "丘": "oka",
        
        // 両
        "両国": "Ryogoku",
        
        // 中
        "中": "naka",
        "中井": "Nakai",
        "中延": "Nakanobu",
        "中目黒": "NakaMeguro",
        "中野": "Nakano",
        "中野坂上": "NakanoSakaue",
        "中野富士見町": "NakanoFujimicho",
        "中野新橋": "NakanoShimbashi",
        
        // 乃
        "乃木坂": "Nogizaka",
        
        // 九
        "九段下": "Kudanshita",
        
        // 亀
        "亀戸": "Kameido",
        "亀有": "Kameari",
        
        // 二
        "二重橋前": "Nijubashimae",
        
        // 五
        "五反田": "Gotanda",
        
        // 京
        "京橋": "Kyobashi",
        
        // 人
        "人形町": "Ningyocho",
        
        // 代
        "代々木": "Yoyogi",
        "代々木上原": "YoyogiUehara",
        "代々木八幡": "YoyogiHachiman",
        "代々木公園": "YoyogiKoen",
        
        // 仲
        "仲御徒町": "NakaOkachimachi",
        
        // 伊
        "伊": "i",
        "伊勢原": "Isehara",
        
        // 住
        "住吉": "Sumiyoshi",
        
        // 信
        "信濃町": "Shinanomachi",
        
        // 元
        "元": "moto",
        
        // 光
        "光が丘": "Hikarigaoka",
        
        // 入
        "入谷": "Iriya",
        
        // 八
        "八丁堀": "Hatchobori",
        "八王子": "Hachioji",
        
        // 六
        "六本木": "Roppongi",
        "六本木一丁目": "RoppongiItchome",
        
        // 内
        "内幸町": "Uchisaiwaicho",
        
        // 冬
        "冬": "fuyu",
        
        // 前
        "前": "mae",
        
        // 勝
        "勝どき": "Kachidoki",
        
        // 勢
        "勢": "se",
        
        // 北
        "北": "kita",
        "北千住": "KitaSenju",
        "北参道": "KitaSando",
        "北綾瀬": "KitaAyase",
        
        // 千
        "千川": "Senkawa",
        "千歳船橋": "ChitoseFunabashi",
        "千石": "Sengoku",
        "千葉": "Chiba",
        "千駄ヶ谷": "Sendagaya",
        "千駄木": "Sendagi",
        
        // 半
        "半蔵門": "Hanzomon",
        
        // 南
        "南": "minami",
        "南千住": "MinamiSenju",
        "南新宿": "MinamiShinjuku",
        "南砂町": "MinamiSunamachi",
        "南行徳": "MinamiGyotoku",
        "南阿佐ケ谷": "MinamiAsagaya",
        
        // 厚
        "厚": "atsu",
        "厚木": "Atsugi",
        
        // 原
        "原": "hara",
        "原宿": "Harajuku",
        "原木中山": "BarakiNakayama",
        
        // 参
        "参宮橋": "Sangubashi",
        
        // 取
        "取手": "Toride",
        
        // 台
        "台": "dai",
        "台場": "Daiba",
        
        // 合
        "合": "go",
        
        // 吉
        "吉祥寺": "Kichijoji",
        
        // 名
        "名": "na",
        
        // 向
        "向": "muko",
        "向ヶ丘遊園": "MukogaokaYuen",
        
        // 和
        "和光市": "Wakoshi",
        "和泉多摩川": "IzumiTamagawa",
        
        // 品
        "品川": "Shinagawa",
        "品川シーサイド": "ShinagawaSeaside",
        
        // 喜
        "喜多見": "Kitami",
        
        // 四
        "四ツ谷": "Yotsuya",
        "四谷三丁目": "YotsuyaSanchome",
        
        // 国
        "国会議事堂前": "KokkaiGijidomae",
        "国分寺": "Kokubunji",
        "国立": "Kunitachi",
        "国立競技場": "KokuritsuKyogijo",
        "国際展示場": "KokusaiTenjijo",
        
        // 園
        "園": "en",
        
        // 地
        "地下鉄成増": "ChikatetsuNarimasu",
        "地下鉄赤塚": "ChikatetsuAkatsuka",
        
        // 士
        "士": "shi",
        
        // 売
        "売": "uri",
        
        // 夏
        "夏": "natsu",
        
        // 外
        "外苑前": "Gaiemmae",
        
        // 大
        "大": "o",
        "大井町": "Oimachi",
        "大塚": "Otsuka",
        "大宮": "Omiya",
        "大島": "Ojima",
        "大崎": "Osaki",
        "大手町": "Otemachi",
        "大森": "Omori",
        "大門": "Daimon",
        
        // 天
        "天王台": "Tennodai",
        "天王洲アイル": "TennozuIsle",
        
        // 妙
        "妙典": "Myoden",
        
        // 学
        "学": "gaku",
        
        // 宝
        "宝町": "Takaracho",
        
        // 宮
        "宮": "miya",
        
        // 富
        "富": "tomi",
        "富水": "Tomizawa",
        
        // 寺
        "寺": "dera",
        
        // 小
        "小": "ko",
        "小伝馬町": "Kodenmacho",
        "小岩": "Koiwa",
        "小川町": "Ogawamachi",
        "小田原": "Odawara",
        "小田急相模原": "OdakyuSagamihara",
        "小竹向原": "KotakeMukaihara",
        
        // 山
        "山": "yama",
        
        // 岩
        "岩本町": "Iwamotocho",
        
        // 島
        "島": "shima",
        
        // 崎
        "崎": "saki",
        
        // 川
        "川": "kawa",
        "川崎": "Kawasaki",
        
        // 巣
        "巣鴨": "Sugamo",
        
        // 巻
        "巻": "maki",
        
        // 市
        "市": "shi",
        "市ケ谷": "Ichigaya",
        "市ヶ谷": "Ichigaya",
        "市場前": "ShijoMae",
        "市川": "Ichikawa",
        
        // 幕
        "幕張": "Makuhari",
        "幕張本郷": "MakuhariHongo",
        
        // 平
        "平": "hira",
        "平井": "Hirai",
        "平和台": "Heiwadai",
        
        // 広
        "広尾": "Hiroo",
        
        // 座
        "座": "za",
        "座間": "Zama",
        
        // 後
        "後楽園": "Korakuen",
        
        // 御
        "御徒町": "Okachimachi",
        "御成門": "Onarimon",
        "御茶ノ水": "Ochanomizu",
        
        // 志
        "志村三丁目": "ShimuraSanchome",
        "志村坂上": "ShimuraSakaue",
        "志茂": "Shimo",
        
        // 恵
        "恵比寿": "Ebisu",
        
        // 愛
        "愛": "aiko",
        "愛甲石田": "AikoIshida",
        
        // 成
        "成": "sei",
        "成城学園前": "SeijogakuenMae",
        
        // 我
        "我孫子": "Abiko",
        
        // 戸
        "戸越": "Togoshi",
        
        // 押
        "押上": "Oshiage",
        
        // 新
        "新": "shin",
        "新中野": "ShinNakano",
        "新大久保": "ShinOkubo",
        "新大塚": "ShinOtsuka",
        "新宿": "Shinjuku",
        "新宿三丁目": "ShinjukuSanchome",
        "新宿御苑前": "ShinjukuGyoemmae",
        "新宿西口": "ShinjukuNishiguchi",
        "新富町": "Shintomicho",
        "新小岩": "ShinKoiwa",
        "新御徒町": "ShinOkachimachi",
        "新御茶ノ水": "ShinOchanomizu",
        "新木場": "Shinkiba",
        "新松田": "ShinMatsuda",
        "新板橋": "ShinItabashi",
        "新検見川": "ShinKemigawa",
        "新橋": "Shimbashi",
        "新江古田": "ShinEgota",
        "新百合ヶ丘": "ShinYurigaoka",
        "新豊洲": "ShinToyosu",
        "新高円寺": "ShinKoenji",
        "新高島平": "ShinTakashimadaira",
        
        // 方
        "方南町": "Honancho",
        
        // 日
        "日": "hi",
        "日の出": "Hinode",
        "日暮里": "Nippori",
        "日本橋": "Nihombashi",
        "日比谷": "Hibiya",
        "日野": "Hino",
        
        // 早
        "早稲田": "Waseda",
        
        // 明
        "明治神宮前": "MeijiJingumae",
        
        // 星
        "星": "hoshi",
        
        // 春
        "春": "haru",
        "春日": "Kasuga",
        
        // 曙
        "曙橋": "Akebonobashi",
        
        // 月
        "月": "tsuki",
        "月島": "Tsukishima",
        
        // 有
        "有明": "Ariake",
        "有明テニスの森": "AriakeTennisNoMori",
        "有楽町": "Yurakucho",
        
        // 木
        "木": "ki",
        "木場": "Kiba",
        
        // 末
        "末広町": "Suehirocho",
        
        // 本
        "本": "hon",
        "本八幡": "MotoYawata",
        "本厚木": "HonAtsugi",
        "本所吾妻橋": "HonjoAzumabashi",
        "本蓮沼": "Motohasunuma",
        "本郷三丁目": "HongoSanchome",
        "本駒込": "HonKomagome",
        
        // 村
        "村": "mura",
        
        // 東
        "東": "higashi",
        "東中野": "HigashiNakano",
        "東京": "Tokyo",
        "東京テレポート": "TokyoTeleport",
        "東京ビッグサイト": "TokyoBigSight",
        "東京国際クルーズターミナル": "TokyoKokusaiCruiseTerminal",
        "東北沢": "HigashiKitazawa",
        "東大前": "Todaimae",
        "東大島": "HigashiOjima",
        "東小金井": "HigashiKoganei",
        "東新宿": "HigashiShinjuku",
        "東日本橋": "HigashiNihombashi",
        "東池袋": "HigashiIkebukuro",
        "東海大学前": "TokaidaigakuMae",
        "東船橋": "HigashiFunabashi",
        "東銀座": "HigashiGinza",
        "東陽町": "Toyocho",
        "東雲": "Shinonome",
        "東高円寺": "HigashiKoenji",
        
        // 松
        "松": "matsu",
        "松戸": "Matsudo",
        
        // 林
        "林": "bayashi",
        
        // 柏
        "柏": "Kashiwa",
        
        // 柿
        "柿": "kaki",
        "柿生": "Kakio",
        
        // 栗
        "栗": "kuri",
        "栗平": "Kurihira",
        
        // 根
        "根津": "Nezu",
        
        // 桜
        "桜": "sakura",
        "桜田門": "Sakuradamon",
        
        // 梅
        "梅": "ume",
        "梅ヶ丘": "Umegaoka",
        
        // 森
        "森": "mori",
        "森下": "Morishita",
        
        // 模
        "模": "mi",
        
        // 横
        "横浜": "Yokohama",
        
        // 橋
        "橋": "bashi",
        
        // 武
        "武": "bu",
        "武蔵境": "MusashiSakai",
        "武蔵小金井": "MusashiKoganei",
        
        // 水
        "水天宮前": "Suitengumae",
        "水道橋": "Suidobashi",
        
        // 氷
        "氷川台": "Hikawadai",
        
        // 永
        "永": "naga",
        "永田町": "Nagatacho",
        
        // 汐
        "汐留": "Shiodome",
        
        // 江
        "江戸川橋": "Edogawabashi",
        
        // 池
        "池": "ike",
        "池袋": "Ikebukuro",
        
        // 沢
        "沢": "sawa",
        
        // 河
        "河": "kawa",
        
        // 沼
        "沼": "numa",
        
        // 泉
        "泉": "sen",
        "泉岳寺": "Sengakuji",
        
        // 津
        "津田沼": "Tsudanuma",
        
        // 浅
        "浅草": "Asakusa",
        "浅草橋": "Asakusabashi",
        
        // 浜
        "浜": "hama",
        "浜松町": "Hamamatsucho",
        "浜町": "Hamacho",
        
        // 浦
        "浦和": "Urawa",
        "浦安": "Urayasu",
        
        // 海
        "海": "umi",
        "海老名": "Ebina",
        
        // 淡
        "淡路町": "Awajicho",
        
        // 清
        "清澄白河": "KiyosumiShirakawa",
        
        // 渋
        "渋": "shibu",
        "渋沢": "Shibusawa",
        "渋谷": "Shibuya",
        
        // 温
        "温": "on",
        
        // 港
        "港": "minato",
        
        // 湖
        "湖": "ko",
        
        // 湯
        "湯島": "Yushima",
        
        // 溜
        "溜池山王": "TameikeSanno",
        
        // 牛
        "牛込柳町": "UshigomeYanagicho",
        "牛込神楽坂": "UshigomeKagurazaka",
        
        // 狛
        "狛江": "Komae",
        
        // 玉
        "玉": "tama",
        "玉川学園前": "TamagawagakuenMae",
        
        // 王
        "王子": "Oji",
        "王子神谷": "OjiKamiya",
        
        // 瑞
        "瑞江": "Mizue",
        
        // 生
        "生": "iku",
        "生田": "Ikuta",
        
        // 田
        "田": "ta",
        "田原町": "Tawaramachi",
        "田町": "Tamachi",
        "田端": "Tabata",
        
        // 甲
        "甲": "ko",
        
        // 町
        "町": "machi",
        "町屋": "Machiya",
        "町田": "Machida",
        
        // 登
        "登戸": "Noborito",
        
        // 白
        "白": "shiro",
        "白山": "Hakusan",
        "白金台": "Shirokanedai",
        "白金高輪": "ShirokaneTakanawa",
        
        // 百
        "百": "yuri",
        "百合ヶ丘": "Yurigaoka",
        
        // 目
        "目白": "Mejiro",
        "目黒": "Meguro",
        
        // 相
        "相": "saga",
        "相模大野": "SagamiOno",
        "相武台前": "SobudaiMae",
        
        // 石
        "石": "ishi",
        
        // 神
        "神": "kami",
        "神保町": "Jimbocho",
        "神楽坂": "Kagurazaka",
        "神田": "Kanda",
        "神谷町": "Kamiyacho",
        
        // 祥
        "祥寿寺": "Soshigaya",
        
        // 秋
        "秋": "aki",
        "秋葉原": "Akihabara",
        
        // 秦
        "秦": "hada",
        "秦野": "Hadano",
        
        // 稲
        "稲毛": "Inage",
        "稲荷町": "Inaricho",
        
        // 空
        "空": "sora",
        
        // 立
        "立川": "Tachikawa",
        
        // 竹
        "竹": "take",
        "竹橋": "Takebashi",
        "竹芝": "Takeshiba",
        
        // 築
        "築地": "Tsukiji",
        "築地市場": "TsukijiShijo",
        
        // 篠
        "篠崎": "Shinozaki",
        
        // 経
        "経堂": "Kyodo",
        
        // 綾
        "綾瀬": "Ayase",
        
        // 緑
        "緑": "midori",
        
        // 練
        "練馬": "Nerima",
        "練馬春日町": "NerimaKasugacho",
        
        // 老
        "老": "ebi",
        
        // 船
        "船堀": "Funabori",
        "船橋": "Funabashi",
        
        // 芝
        "芝公園": "Shibakoen",
        "芝浦ふ頭": "ShibauraFuto",
        
        // 花
        "花": "hana",
        
        // 若
        "若松河田": "WakamatsuKawada",
        
        // 茅
        "茅場町": "Kayabacho",
        
        // 茗
        "茗荷谷": "Myogadani",
        
        // 荻
        "荻窪": "Ogikubo",
        
        // 菊
        "菊川": "Kikukawa",
        
        // 落
        "落合": "Ochiai",
        "落合南長崎": "OchiaiMinamiNagasaki",
        
        // 葛
        "葛西": "Kasai",
        
        // 蒲
        "蒲田": "Kamata",
        
        // 蓮
        "蓮根": "Hasune",
        
        // 蔵
        "蔵前": "Kuramae",
        
        // 虎
        "虎ノ門": "Toranomon",
        "虎ノ門ヒルズ": "ToranomonHills",
        
        // 蛍
        "蛍": "hotaru",
        
        // 螢
        "螢沢": "Hotaruzawa",
        
        // 行
        "行徳": "Gyotoku",
        
        // 表
        "表参道": "OmoteSando",
        
        // 西
        "西": "nishi",
        "西ケ原": "Nishigahara",
        "西八王子": "NishiHachioji",
        "西千葉": "NishiChiba",
        "西台": "Nishidai",
        "西国分寺": "NishiKokubunji",
        "西大島": "NishiOjima",
        "西巣鴨": "NishiSugamo",
        "西新宿": "NishiShinjuku",
        "西新宿五丁目": "NishiShinjukuGochome",
        "西日暮里": "NishiNippori",
        "西早稲田": "NishiWaseda",
        "西船橋": "NishiFunabashi",
        "西荻窪": "NishiOgikubo",
        "西葛西": "NishiKasai",
        "西馬込": "NishiMagome",
        "西高島平": "NishiTakashimadaira",
        
        // 要
        "要町": "Kanamecho",
        
        // 見
        "見": "mi",
        
        // 読
        "読": "yomi",
        "読売ランド前": "YomiurilandMae",
        
        // 護
        "護国寺": "Gokokuji",
        
        // 谷
        "谷": "ya",
        
        // 豊
        "豊島園": "Toshimaen",
        "豊洲": "Toyosu",
        "豊田": "Toyoda",
        
        // 豪
        "豪徳寺": "Gotokuji",
        
        // 赤
        "赤": "aka",
        "赤坂": "Akasaka",
        "赤坂見附": "AkasakaMitsuke",
        "赤羽": "Akabane",
        "赤羽橋": "Akabanebashi",
        
        // 足
        "足": "ashi",
        "足柄": "Ashigara",
        
        // 辰
        "辰巳": "Tatsumi",
        
        // 遊
        "遊": "yu",
        
        // 都
        "都庁前": "Tochomae",
        
        // 野
        "野": "no",
        
        // 金
        "金": "kane",
        "金町": "Kanamachi",
        
        // 鉄
        "鉄": "tetsu",
        
        // 銀
        "銀": "gin",
        "銀座": "Ginza",
        "銀座一丁目": "GinzaItchome",
        
        // 錦
        "錦糸町": "Kinshicho",
        
        // 長
        "長": "naga",
        
        // 門
        "門前仲町": "MonzenNakacho",
        
        // 開
        "開": "kai",
        "開成": "Kaisei",
        
        // 間
        "間": "ma",
        
        // 阿
        "阿佐ヶ谷": "Asagaya",
        
        // 雑
        "雑司が谷": "Zoshigaya",
        
        // 雨
        "雨": "ame",
        
        // 雪
        "雪": "yuki",
        
        // 雲
        "雲": "kumo",
        
        // 霞
        "霞ケ関": "Kasumigaseki",
        "霞ヶ関": "Kasumigaseki",
        
        // 青
        "青": "ao",
        "青山一丁目": "AoyamaItchome",
        "青海": "Aomi",
        
        // 風
        "風": "kaze",
        
        // 飯
        "飯田橋": "Iidabashi",
        
        // 馬
        "馬喰横山": "BakuroYokoyama",
        "馬込": "Magome",
        
        // 駅
        "駅": "eki",
        
        // 駒
        "駒込": "Komagome",
        
        // 高
        "高": "taka",
        "高円寺": "Koenji",
        "高尾": "Takao",
        "高島平": "Takashimadaira",
        "高田馬場": "Takadanobaba",
        "高輪ゲートウェイ": "TakanawagGateway",
        "高輪台": "Takanawadai",
        
        // 鶯
        "鶯谷": "Uguisudani",
        
        // 鶴
        "鶴": "tsuru",
        "鶴川": "Tsurukawa",
        "鶴巻温泉": "TsurumakinOnsen",
        
        // 麹
        "麹町": "Kojimachi",
        
        // 麻
        "麻布十番": "AzabuJuban",
        
        // 黒
        "黒": "kuro"
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
    
    // MARK: - 逆変換（英語名から日本語名へ）
    
    /// 英語名から日本語名への逆引き辞書（遅延初期化）
    private static let reverseMapping: [String: String] = {
        var mapping: [String: String] = [:]
        for (japanese, english) in exactMapping {
            // 大文字小文字を無視して比較できるように、小文字をキーとする
            mapping[english.lowercased()] = japanese
            
            // ハイフンをマイナスに置き換えたバージョンも追加（Aoyama-itchome対応）
            let englishWithMinus = english.replacingOccurrences(of: "-", with: "")
            if englishWithMinus != english {
                mapping[englishWithMinus.lowercased()] = japanese
            }
        }
        return mapping
    }()
    
    /// 英語名から日本語名に変換
    /// - Parameter englishName: 英語の駅名
    /// - Returns: 日本語の駅名（見つからない場合はnil）
    func toJapanese(_ englishName: String) -> String? {
        // 大文字小文字を無視して検索
        let key = englishName.lowercased()
        
        // 完全一致を優先
        if let japanese = StationNameRomanizer.reverseMapping[key] {
            return japanese
        }
        
        // ハイフンを除去したバージョンでも検索
        let keyWithoutHyphen = key.replacingOccurrences(of: "-", with: "")
        if let japanese = StationNameRomanizer.reverseMapping[keyWithoutHyphen] {
            return japanese
        }
        
        // 特殊なケース: "Aoyama-itchome" -> "青山一丁目"
        if englishName.lowercased() == "aoyama-itchome" || englishName.lowercased() == "aoyamaitchome" {
            return "青山一丁目"
        }
        
        return nil
    }
}
