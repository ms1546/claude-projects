//
//  Railway+Localization.swift
//  TrainAlert
//
//  鉄道路線名のローカライゼーション処理
//

import Foundation

extension String {
    /// 路線IDから日本語名を取得する
    func railwayJapaneseName() -> String {
        let components = self.split(separator: ":").map { String($0) }
        guard components.count >= 2 else { return self }
        
        let operatorAndLine = components[1].split(separator: ".").map { String($0) }
        guard operatorAndLine.count >= 2 else { return self }
        
        let operatorName = operatorAndLine[0]
        let lineName = operatorAndLine[1]
        
        // オペレーター名の日本語化
        let operatorJa = RailwayOperator.localizedName(for: operatorName)
        // 路線名の日本語化
        let lineJa = RailwayLine.localizedName(for: lineName)
        
        return operatorJa + lineJa
    }
}

enum RailwayOperator {
    static func localizedName(for operatorId: String) -> String {
        switch operatorId {
        case "TokyoMetro":
            return "東京メトロ"
        case "JR-East":
            return "JR東日本"
        case "Toei":
            return "都営"
        case "Tokyu":
            return "東急"
        case "Keio":
            return "京王"
        case "Odakyu":
            return "小田急"
        case "Seibu":
            return "西武"
        case "Tobu":
            return "東武"
        case "Keikyu":
            return "京急"
        case "Keisei":
            return "京成"
        case "Tokyo-Waterfront":
            return "東京臨海高速鉄道"
        case "Tsukuba-Express":
            return "つくばエクスプレス"
        default:
            return operatorId
        }
    }
}

enum RailwayLine {
    static func localizedName(for lineId: String) -> String {
        switch lineId {
        // 東京メトロ
        case "Hanzomon":
            return "半蔵門線"
        case "Ginza":
            return "銀座線"
        case "Marunouchi":
            return "丸ノ内線"
        case "Hibiya":
            return "日比谷線"
        case "Tozai":
            return "東西線"
        case "Chiyoda":
            return "千代田線"
        case "Yurakucho":
            return "有楽町線"
        case "Namboku":
            return "南北線"
        case "Fukutoshin":
            return "副都心線"
            
        // JR東日本
        case "Yamanote":
            return "山手線"
        case "Chuo", "ChuoRapid":
            return "中央線"
        case "Keihin-TohokuNegishi":
            return "京浜東北線"
        case "Sobu", "SobuRapid":
            return "総武線"
        case "Saikyo":
            return "埼京線"
        case "Shonan-Shinjuku":
            return "湘南新宿ライン"
        case "Tokaido":
            return "東海道線"
        case "Yokosuka":
            return "横須賀線"
        case "Nambu":
            return "南武線"
        case "Yokohama":
            return "横浜線"
        case "Musashino":
            return "武蔵野線"
        case "Keiyo":
            return "京葉線"
        case "Takasaki":
            return "高崎線"
        case "Utsunomiya":
            return "宇都宮線"
        case "Joban", "JobanRapid":
            return "常磐線"
            
        // 都営地下鉄
        case "Asakusa":
            return "浅草線"
        case "Mita":
            return "三田線"
        case "Shinjuku":
            return "新宿線"
        case "Oedo":
            return "大江戸線"
            
        // 私鉄
        case "Toyoko":
            return "東横線"
        case "Den-en-toshi":
            return "田園都市線"
        case "Oimachi":
            return "大井町線"
        case "Meguro":
            return "目黒線"
        case "Ikegami":
            return "池上線"
        case "Keio":
            return "京王線"
        case "Inokashira":
            return "井の頭線"
        case "Odawara":
            return "小田原線"
        case "Tama":
            return "多摩線"
        case "Enoshima":
            return "江ノ島線"
        case "Ikebukuro":
            return "池袋線"
        case "Isesaki", "Skytree":
            return "伊勢崎線"
        case "Nikko":
            return "日光線"
        case "Airport":
            return "空港線"
        case "Main":
            return "本線"
        case "Oshiage":
            return "押上線"
        case "Kanamachi":
            return "金町線"
        case "Rinkai":
            return "りんかい線"
            
        default:
            return lineId + "線"
        }
    }
}
