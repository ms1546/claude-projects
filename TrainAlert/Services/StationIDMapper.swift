//
//  StationIDMapper.swift
//  TrainAlert
//
//  HeartRails APIとODPT APIのID変換を管理
//

import Foundation

/// 駅IDマッピング管理クラス
struct StationIDMapper {
    // MARK: - 路線名マッピング
    
    /// HeartRails路線名 -> ODPT路線IDのマッピング
    static let railwayMapping: [String: String] = [
        // JR東日本
        "JR山手線": "odpt.Railway:JR-East.Yamanote",
        "JR中央線": "odpt.Railway:JR-East.ChuoRapid",
        "JR中央線快速": "odpt.Railway:JR-East.ChuoRapid",
        "JR中央・総武線": "odpt.Railway:JR-East.ChuoSobuLocal",
        "JR中央・総武線各駅停車": "odpt.Railway:JR-East.ChuoSobuLocal",
        "JR京浜東北線": "odpt.Railway:JR-East.KeihinTohokuNegishi",
        "JR京浜東北・根岸線": "odpt.Railway:JR-East.KeihinTohokuNegishi",
        "JR埼京線": "odpt.Railway:JR-East.Saikyo",
        "JR常磐線": "odpt.Railway:JR-East.Joban",
        "JR常磐線快速": "odpt.Railway:JR-East.JobanRapid",
        "JR常磐線各駅停車": "odpt.Railway:JR-East.JobanLocal",
        "JR総武線快速": "odpt.Railway:JR-East.SobuRapid",
        "JR総武本線": "odpt.Railway:JR-East.SobuRapid",
        "JR湘南新宿ライン": "odpt.Railway:JR-East.ShonanShinjuku",
        "JR横須賀線": "odpt.Railway:JR-East.Yokosuka",
        "JR横浜線": "odpt.Railway:JR-East.Yokohama",
        "JR南武線": "odpt.Railway:JR-East.Nambu",
        "JR武蔵野線": "odpt.Railway:JR-East.Musashino",
        "JR鶴見線": "odpt.Railway:JR-East.Tsurumi",
        "JR五日市線": "odpt.Railway:JR-East.Itsukaichi",
        "JR青梅線": "odpt.Railway:JR-East.Ome",
        "JR高崎線": "odpt.Railway:JR-East.Takasaki",
        "JR宇都宮線": "odpt.Railway:JR-East.Utsunomiya",
        "JR京葉線": "odpt.Railway:JR-East.Keiyo",
        
        // 東京メトロ
        "東京メトロ銀座線": "odpt.Railway:TokyoMetro.Ginza",
        "東京メトロ丸ノ内線": "odpt.Railway:TokyoMetro.Marunouchi",
        "東京メトロ丸ノ内線分岐線": "odpt.Railway:TokyoMetro.MarunouchiBranch",
        "東京メトロ日比谷線": "odpt.Railway:TokyoMetro.Hibiya",
        "東京メトロ東西線": "odpt.Railway:TokyoMetro.Tozai",
        "東京メトロ千代田線": "odpt.Railway:TokyoMetro.Chiyoda",
        "東京メトロ有楽町線": "odpt.Railway:TokyoMetro.Yurakucho",
        "東京メトロ半蔵門線": "odpt.Railway:TokyoMetro.Hanzomon",
        "東京メトロ南北線": "odpt.Railway:TokyoMetro.Namboku",
        "東京メトロ副都心線": "odpt.Railway:TokyoMetro.Fukutoshin",
        
        // 都営地下鉄
        "都営大江戸線": "odpt.Railway:Toei.Oedo",
        "都営浅草線": "odpt.Railway:Toei.Asakusa",
        "都営三田線": "odpt.Railway:Toei.Mita",
        "都営新宿線": "odpt.Railway:Toei.Shinjuku",
        
        // 東急
        "東急東横線": "odpt.Railway:Tokyu.Toyoko",
        "東急田園都市線": "odpt.Railway:Tokyu.DenEnToshi",
        "東急目黒線": "odpt.Railway:Tokyu.Meguro",
        "東急池上線": "odpt.Railway:Tokyu.Ikegami",
        "東急多摩川線": "odpt.Railway:Tokyu.Tamagawa",
        "東急大井町線": "odpt.Railway:Tokyu.Oimachi",
        "東急世田谷線": "odpt.Railway:Tokyu.Setagaya",
        "東急こどもの国線": "odpt.Railway:Tokyu.Kodomonokuni",
        
        // 京王
        "京王線": "odpt.Railway:Keio.Keio",
        "京王井の頭線": "odpt.Railway:Keio.Inokashira",
        "京王相模原線": "odpt.Railway:Keio.Sagamihara",
        "京王高尾線": "odpt.Railway:Keio.Takao",
        "京王動物園線": "odpt.Railway:Keio.Dobutsuen",
        "京王競馬場線": "odpt.Railway:Keio.Keibajo",
        "京王新線": "odpt.Railway:Keio.New",
        
        // 小田急
        "小田急線": "odpt.Railway:Odakyu.Odawara",
        "小田急小田原線": "odpt.Railway:Odakyu.Odawara",
        "小田急江ノ島線": "odpt.Railway:Odakyu.Enoshima",
        "小田急多摩線": "odpt.Railway:Odakyu.Tama",
        
        // 西武
        "西武新宿線": "odpt.Railway:Seibu.Shinjuku",
        "西武池袋線": "odpt.Railway:Seibu.Ikebukuro",
        "西武有楽町線": "odpt.Railway:Seibu.Yurakucho",
        "西武豊島線": "odpt.Railway:Seibu.Toshima",
        "西武狭山線": "odpt.Railway:Seibu.Sayama",
        "西武多摩湖線": "odpt.Railway:Seibu.Tamako",
        "西武国分寺線": "odpt.Railway:Seibu.Kokubunji",
        "西武多摩川線": "odpt.Railway:Seibu.Tamagawa",
        "西武拝島線": "odpt.Railway:Seibu.Haijima",
        "西武西武義線": "odpt.Railway:Seibu.SeibuChichibu",
        "西武山口線": "odpt.Railway:Seibu.Yamaguchi",
        
        // 東武
        "東武東上線": "odpt.Railway:Tobu.Tojo",
        "東武東上本線": "odpt.Railway:Tobu.Tojo",
        "東武スカイツリーライン": "odpt.Railway:Tobu.TobuSkytree",
        "東武伊勢崎線": "odpt.Railway:Tobu.TobuSkytree",
        "東武亀戸線": "odpt.Railway:Tobu.Kameido",
        "東武大師線": "odpt.Railway:Tobu.Daishi",
        "東武佐野線": "odpt.Railway:Tobu.Sano",
        "東武桐生線": "odpt.Railway:Tobu.Kiryu",
        "東武小泉線": "odpt.Railway:Tobu.Koizumi",
        "東武日光線": "odpt.Railway:Tobu.Nikko",
        "東武宇都宮線": "odpt.Railway:Tobu.Utsunomiya",
        "東武鬼怒川線": "odpt.Railway:Tobu.Kinugawa",
        "東武野田線": "odpt.Railway:Tobu.TobuUrbanPark",
        "東武アーバンパークライン": "odpt.Railway:Tobu.TobuUrbanPark",
        
        // 京成
        "京成本線": "odpt.Railway:Keisei.Main",
        "京成押上線": "odpt.Railway:Keisei.Oshiage",
        "京成金町線": "odpt.Railway:Keisei.Kanamachi",
        "京成千葉線": "odpt.Railway:Keisei.Chiba",
        "京成千原線": "odpt.Railway:Keisei.Chihara",
        "京成成田スカイアクセス": "odpt.Railway:Keisei.NaritaSkyAccess",
        "成田スカイアクセス": "odpt.Railway:Keisei.NaritaSkyAccess",
        
        // 京急
        "京急本線": "odpt.Railway:Keikyu.Main",
        "京急空港線": "odpt.Railway:Keikyu.Airport",
        "京急大師線": "odpt.Railway:Keikyu.Daishi",
        "京急逸見線": "odpt.Railway:Keikyu.Zushi",
        "京急久里浜線": "odpt.Railway:Keikyu.Kurihama",
        
        // その他の私鉄
        "リニモ": "odpt.Railway:TWR.Rinkai",
        "りんかい線": "odpt.Railway:TWR.Rinkai",
        "東京臨海高速鉄道りんかい線": "odpt.Railway:TWR.Rinkai",
        "ゆりかもめ": "odpt.Railway:Yurikamome.Yurikamome",
        "東京モノレール": "odpt.Railway:TokyoMonorail.HanedaAirport",
        "東京モノレール羽田空港線": "odpt.Railway:TokyoMonorail.HanedaAirport",
        "多摩都市モノレール": "odpt.Railway:TamaMonorail.TamaMonorail",
        "多摩モノレール": "odpt.Railway:TamaMonorail.TamaMonorail",
        "日暮里・舎人ライナー": "odpt.Railway:MIR.NipporiToneri",
        "つくばエクスプレス": "odpt.Railway:MIR.Tsukuba",
        "北総線": "odpt.Railway:HokusoCo.Hokuso",
        "皇埼アクセス線": "odpt.Railway:ShibayamaCo.ShibayamaRailway",
        "東葉高速線": "odpt.Railway:ToyoRapid.ToyoRapid",
        "埼玉高速鉄道線": "odpt.Railway:SaitamaRailway.SaitamaRailway",
        "横浜高速鉄道みなとみらい線": "odpt.Railway:YokohamaMinatomiraiRailway.MinatomiraiLine",
        "みなとみらい線": "odpt.Railway:YokohamaMinatomiraiRailway.MinatomiraiLine"
    ]
    
    // MARK: - 駅名マッピング（特殊ケース）
    
    /// 路線固有の駅名表記ルール（将来の拡張用）
    /// 現在はStationNameRomanizerを使用するため、このマッピングは参考として残す
    static let stationNameMapping: [String: [String: String]] = [:]
    
    // MARK: - 変換メソッド
    
    /// HeartRails形式の駅情報をODPT形式に変換
    /// - Parameters:
    ///   - stationName: 駅名（日本語）
    ///   - lineName: 路線名（日本語）
    /// - Returns: ODPT形式の駅ID（例: odpt.Station:JR-East.Yamanote.Tokyo）
    static func convertToODPTStationID(stationName: String, lineName: String) -> String? {
        // 路線IDを取得
        guard let railwayID = railwayMapping[lineName] else {
            print("StationIDMapper: Unknown railway - \(lineName)")
            return nil
        }
        
        // 駅名をローマ字に変換（StationNameRomanizerを使用）
        let romanizedName = StationNameRomanizer.romanize(stationName)
        
        // 事業者を抽出
        let components = railwayID.split(separator: ":")
        guard components.count >= 2 else { return nil }
        
        let operatorAndLine = components[1].split(separator: ".")
        guard operatorAndLine.count >= 2 else { return nil }
        
        let operatorName = operatorAndLine[0]
        let lineNameComponent = operatorAndLine[1]
        
        // ODPT形式の駅IDを生成
        let stationId = "odpt.Station:\(operatorName).\(lineNameComponent).\(romanizedName)"
        print("StationIDMapper: Generated station ID: \(stationId) from \(stationName) on \(lineName)")
        return stationId
    }
    
    /// HeartRails形式の駅情報をODPT形式に変換（非同期版）
    /// - Parameters:
    ///   - stationName: 駅名（日本語）
    ///   - lineName: 路線名（日本語）
    /// - Returns: ODPT形式の駅ID（例: odpt.Station:JR-East.Yamanote.Tokyo）
    static func convertToODPTStationIDAsync(stationName: String, lineName: String) async -> String? {
        // 路線IDを取得
        guard let railwayID = railwayMapping[lineName] else {
            print("StationIDMapper: Unknown railway - \(lineName)")
            return nil
        }
        
        // ODPT APIから正しい駅IDを取得
        do {
            if let stationId = try await ODPTAPIClient.shared.findStationOnRailway(
                stationName: stationName,
                railwayId: railwayID
            ) {
                print("StationIDMapper: Found station ID from API: \(stationId)")
                return stationId
            }
        } catch {
            print("StationIDMapper: Failed to find station from API: \(error)")
        }
        
        // APIから取得できなかった場合は、フォールバックとして既存のメソッドを使用
        return convertToODPTStationID(stationName: stationName, lineName: lineName)
    }
    
    /// ODPT路線IDを取得
    /// - Parameter lineName: HeartRails形式の路線名
    /// - Returns: ODPT形式の路線ID
    static func getODPTRailwayID(from lineName: String) -> String? {
        railwayMapping[lineName]
    }
    
    // MARK: - 逆変換
    
    /// ODPT形式の駅IDからHeartRails形式に変換
    static func convertFromODPTStationID(_ odptID: String) -> (stationName: String, lineName: String)? {
        // 実装予定
        nil
    }
}

// MARK: - キャッシュ対応

extension StationIDMapper {
    /// 変換結果のキャッシュ
    private static var conversionCache = [String: String]()
    
    /// キャッシュをクリア
    static func clearCache() {
        conversionCache.removeAll()
    }
    
    /// キャッシュを使用した変換
    static func convertToODPTStationIDWithCache(stationName: String, lineName: String) -> String? {
        let cacheKey = "\(stationName):\(lineName)"
        
        if let cached = conversionCache[cacheKey] {
            return cached
        }
        
        let result = convertToODPTStationID(stationName: stationName, lineName: lineName)
        if let result = result {
            conversionCache[cacheKey] = result
        }
        
        return result
    }
}
