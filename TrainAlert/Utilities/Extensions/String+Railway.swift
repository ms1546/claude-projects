//
//  String+Railway.swift
//  TrainAlert
//
//  路線ID文字列を日本語表示名に変換する拡張
//

import Foundation

extension String {
    /// 路線IDから日本語の路線名を取得
    /// 例: "odpt.Railway:TokyoMetro.Hanzomon" → "東京メトロ半蔵門線"
    var railwayDisplayName: String {
        let components = self.split(separator: ":").map { String($0) }
        guard components.count >= 2 else { return self }
        
        let operatorAndLine = components[1].split(separator: ".").map { String($0) }
        guard operatorAndLine.count >= 2 else { return self }
        
        let operatorName = operatorAndLine[0]
        let lineName = operatorAndLine[1]
        
        // オペレーター名の日本語化
        let operatorJa: String
        switch operatorName {
        case "TokyoMetro":
            operatorJa = "東京メトロ"
        case "JR-East":
            operatorJa = "JR東日本"
        case "Toei":
            operatorJa = "都営"
        case "Tokyu":
            operatorJa = "東急"
        case "Keio":
            operatorJa = "京王"
        case "Odakyu":
            operatorJa = "小田急"
        case "Seibu":
            operatorJa = "西武"
        case "Tobu":
            operatorJa = "東武"
        case "Keikyu":
            operatorJa = "京急"
        case "Keisei":
            operatorJa = "京成"
        case "TWR":
            operatorJa = "りんかい線"
        default:
            operatorJa = operatorName
        }
        
        // 路線名の日本語化
        let lineJa: String
        switch lineName {
        // 東京メトロ
        case "Hanzomon":
            lineJa = "半蔵門線"
        case "Ginza":
            lineJa = "銀座線"
        case "Marunouchi":
            lineJa = "丸ノ内線"
        case "Hibiya":
            lineJa = "日比谷線"
        case "Tozai":
            lineJa = "東西線"
        case "Chiyoda":
            lineJa = "千代田線"
        case "Yurakucho":
            lineJa = "有楽町線"
        case "Namboku":
            lineJa = "南北線"
        case "Fukutoshin":
            lineJa = "副都心線"
        // JR東日本
        case "Yamanote":
            lineJa = "山手線"
        case "Chuo", "ChuoRapid":
            lineJa = "中央線"
        case "Keihin-TohokuNegishi":
            lineJa = "京浜東北線"
        case "Sobu", "SobuRapid":
            lineJa = "総武線"
        case "Saikyo":
            lineJa = "埼京線"
        case "Tokaido":
            lineJa = "東海道線"
        case "Yokosuka":
            lineJa = "横須賀線"
        case "Takasaki":
            lineJa = "高崎線"
        case "Utsunomiya":
            lineJa = "宇都宮線"
        case "Joban", "JobanRapid":
            lineJa = "常磐線"
        case "Keiyo":
            lineJa = "京葉線"
        case "Musashino":
            lineJa = "武蔵野線"
        case "Nambu":
            lineJa = "南武線"
        case "Yokohama":
            lineJa = "横浜線"
        // 都営
        case "Asakusa":
            lineJa = "浅草線"
        case "Mita":
            lineJa = "三田線"
        case "Shinjuku":
            lineJa = "新宿線"
        case "Oedo":
            lineJa = "大江戸線"
        // その他私鉄
        case "Toyoko":
            lineJa = "東横線"
        case "DenEnToshi":
            lineJa = "田園都市線"
        case "Meguro":
            lineJa = "目黒線"
        case "Ikegami":
            lineJa = "池上線"
        default:
            lineJa = lineName + "線"
        }
        
        return operatorJa + lineJa
    }
}
