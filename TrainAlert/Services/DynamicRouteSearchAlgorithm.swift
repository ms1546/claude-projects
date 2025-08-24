//
//  DynamicRouteSearchAlgorithm.swift
//  TrainAlert
//
//  時刻表データを使用した動的な経路探索アルゴリズム
//

import CoreLocation
import Foundation

/// 動的な経路探索アルゴリズム
class DynamicRouteSearchAlgorithm {
    // MARK: - Types
    
    /// 駅ノード
    struct StationNode: Hashable {
        let id: String  // ODPT Station ID
        let name: String
        let railway: String
        let location: CLLocationCoordinate2D?
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: StationNode, rhs: StationNode) -> Bool {
            lhs.id == rhs.id
        }
    }
    
    /// エッジ（駅間の接続）
    struct Edge {
        let from: StationNode
        let to: StationNode
        let weight: Int  // 所要時間（分）
        let isTransfer: Bool
        let railway: String
    }
    
    /// グラフ
    class StationGraph {
        private var adjacencyList: [StationNode: [Edge]] = [:]
        private var nodes: Set<StationNode> = []
        
        func addNode(_ node: StationNode) {
            nodes.insert(node)
            if adjacencyList[node] == nil {
                adjacencyList[node] = []
            }
        }
        
        func addEdge(_ edge: Edge) {
            addNode(edge.from)
            addNode(edge.to)
            adjacencyList[edge.from]?.append(edge)
        }
        
        func neighbors(of node: StationNode) -> [Edge] {
            adjacencyList[node] ?? []
        }
        
        func allNodes() -> Set<StationNode> {
            nodes
        }
    }
    
    /// 探索結果
    struct DynamicSearchResult {
        let path: [StationNode]
        let totalTime: Int
        let transferCount: Int
        let sections: [RouteSection]
        let apiCallCount: Int
    }
    
    /// 経路の区間
    struct RouteSection: Equatable {
        let railway: String
        let fromStation: String
        let toStation: String
        let duration: Int
    }
    
    // MARK: - Properties
    
    private var apiCallCount = 0
    
    // キャッシュされた路線データ
    private var cachedRailwayStations: [String: [ODPTStation]] = [:]
    
    // MARK: - Public Methods
    
    /// 動的に経路を探索
    func searchRoute(
        from departureStation: String,
        departureRailway: String,
        to arrivalStation: String
    ) async throws -> [DynamicSearchResult] {
        apiCallCount = 0
        
        print("🚃 Dynamic route search started")
        print("  From: \(departureStation) (\(departureRailway))")
        print("  To: \(arrivalStation)")
        
        // 1. 関連する路線を探索
        let relevantRailways = try await findRelevantRailways(
            departureStation: departureStation,
            departureRailway: departureRailway,
            arrivalStation: arrivalStation
        )
        
        print("📊 Found \(relevantRailways.count) relevant railways")
        
        // 2. グラフを構築
        let graph = try await buildGraph(railways: relevantRailways)
        
        print("🔗 Graph built with \(graph.allNodes().count) nodes")
        
        // 3. 出発駅と到着駅のノードを特定
        guard let startNode = findNode(name: departureStation, railway: departureRailway, in: graph) else {
            print("❌ Start station not found in graph")
            return []
        }
        
        let endNodes = findNodes(name: arrivalStation, in: graph)
        if endNodes.isEmpty {
            print("❌ End station not found in graph")
            return []
        }
        
        // 4. 各到着駅候補に対してダイクストラ法を実行
        var results: [DynamicSearchResult] = []
        
        for endNode in endNodes {
            if let result = dijkstra(graph: graph, start: startNode, end: endNode) {
                results.append(result)
            }
        }
        
        // 5. 結果をソート（所要時間順）
        results.sort { $0.totalTime < $1.totalTime }
        
        print("✅ Found \(results.count) routes (API calls: \(apiCallCount))")
        
        return Array(results.prefix(5))  // 上位5件を返す
    }
    
    // MARK: - Private Methods
    
    /// 関連する路線を探索
    private func findRelevantRailways(
        departureStation: String,
        departureRailway: String,
        arrivalStation: String
    ) async throws -> Set<String> {
        var relevantRailways = Set<String>()
        var stationsToCheck = [(name: departureStation, railway: departureRailway)]
        var checkedStations = Set<String>()
        
        // BFSで関連路線を探索（最大深さ1 = 1回乗り換えのみ）
        for _ in 0..<1 {
            var nextStations: [(name: String, railway: String)] = []
            
            for (stationName, railway) in stationsToCheck {
                let key = "\(stationName)_\(railway)"
                if checkedStations.contains(key) { continue }
                checkedStations.insert(key)
                
                // この路線を追加
                if let railwayId = getODPTRailwayId(from: railway) {
                    relevantRailways.insert(railwayId)
                    
                    // この路線の全駅を取得
                    let stations = try await getStations(for: railwayId)
                    
                    // 同名の他路線駅を探す
                    for station in stations {
                        if let name = station.stationTitle?.ja {
                            // 到着駅が見つかった場合
                            if name == arrivalStation {
                                relevantRailways.insert(station.railway)
                            }
                            
                            // 乗り換え可能駅を探す（同名の駅）
                            let sameNameStations = try await findSameNameStations(name: name)
                            for sameStation in sameNameStations {
                                let sameRailway = sameStation.railway
                                if !sameRailway.isEmpty && sameRailway != railway {
                                    nextStations.append((name: name, railway: sameRailway))
                                }
                            }
                        }
                    }
                }
            }
            
            stationsToCheck = nextStations
            if nextStations.isEmpty { break }
        }
        
        return relevantRailways
    }
    
    /// グラフを構築
    private func buildGraph(railways: Set<String>) async throws -> StationGraph {
        let graph = StationGraph()
        var stationNodeMap: [String: StationNode] = [:]  // 駅名 -> ノードのマップ
        
        // 各路線の駅データを取得してノードを作成
        for railwayId in railways {
            let stations = try await getStations(for: railwayId)
            
            // 駅をノードとして追加
            for (index, station) in stations.enumerated() {
                guard let stationName = station.stationTitle?.ja else { continue }
                
                let node = StationNode(
                    id: station.sameAs,
                    name: stationName,
                    railway: railwayId,
                    location: nil  // 簡略化のため省略
                )
                
                graph.addNode(node)
                
                // 同名駅のマッピング
                if stationNodeMap[stationName] == nil {
                    stationNodeMap[stationName] = node
                }
                
                // 隣接駅へのエッジを追加
                if index > 0 {
                    let prevStation = stations[index - 1]
                    if let prevName = prevStation.stationTitle?.ja {
                        let prevNode = StationNode(
                            id: prevStation.sameAs,
                            name: prevName,
                            railway: railwayId,
                            location: nil
                        )
                        
                        // 両方向のエッジを追加（所要時間は仮に2分）
                        let edge1 = Edge(
                            from: prevNode,
                            to: node,
                            weight: 2,
                            isTransfer: false,
                            railway: railwayId
                        )
                        let edge2 = Edge(
                            from: node,
                            to: prevNode,
                            weight: 2,
                            isTransfer: false,
                            railway: railwayId
                        )
                        
                        graph.addEdge(edge1)
                        graph.addEdge(edge2)
                    }
                }
            }
        }
        
        // 乗り換えエッジを追加
        addTransferEdges(to: graph)
        
        return graph
    }
    
    /// 乗り換えエッジを追加
    private func addTransferEdges(to graph: StationGraph) {
        let nodes = graph.allNodes()
        var stationGroups: [String: [StationNode]] = [:]
        
        // 同名駅をグループ化
        for node in nodes {
            if stationGroups[node.name] == nil {
                stationGroups[node.name] = []
            }
            stationGroups[node.name]?.append(node)
        }
        
        // 同名駅間に乗り換えエッジを追加
        for (_, nodesInStation) in stationGroups {
            if nodesInStation.count > 1 {
                for i in 0..<nodesInStation.count {
                    for j in 0..<nodesInStation.count {
                        if i != j {
                            let transferTime = getTransferTime(for: nodesInStation[i].name)
                            let edge = Edge(
                                from: nodesInStation[i],
                                to: nodesInStation[j],
                                weight: transferTime,
                                isTransfer: true,
                                railway: ""
                            )
                            graph.addEdge(edge)
                        }
                    }
                }
            }
        }
    }
    
    /// ダイクストラ法で最短経路を探索
    private func dijkstra(graph: StationGraph, start: StationNode, end: StationNode) -> DynamicSearchResult? {
        var distances: [StationNode: Int] = [:]
        var previous: [StationNode: StationNode] = [:]
        var transferCounts: [StationNode: Int] = [:]
        var unvisited = graph.allNodes()
        
        // 初期化
        for node in unvisited {
            distances[node] = Int.max
            transferCounts[node] = 0
        }
        distances[start] = 0
        
        while !unvisited.isEmpty {
            // 最小距離のノードを選択
            guard let current = unvisited.min(by: { distances[$0]! < distances[$1]! }),
                  let currentDistance = distances[current],
                  currentDistance < Int.max else {
                break
            }
            
            unvisited.remove(current)
            
            // ゴールに到達
            if current == end {
                break
            }
            
            // 隣接ノードを更新
            for edge in graph.neighbors(of: current) {
                let neighbor = edge.to
                let newDistance = currentDistance + edge.weight
                
                if newDistance < distances[neighbor]! {
                    distances[neighbor] = newDistance
                    previous[neighbor] = current
                    transferCounts[neighbor] = transferCounts[current]! + (edge.isTransfer ? 1 : 0)
                }
            }
        }
        
        // パスを復元
        guard let totalTime = distances[end], totalTime < Int.max else {
            return nil
        }
        
        var path: [StationNode] = []
        var current: StationNode? = end
        
        while let node = current {
            path.insert(node, at: 0)
            current = previous[node]
        }
        
        // セクションを作成
        let sections = createSections(from: path, in: graph)
        
        return DynamicSearchResult(
            path: path,
            totalTime: totalTime,
            transferCount: transferCounts[end] ?? 0,
            sections: sections,
            apiCallCount: apiCallCount
        )
    }
    
    /// 経路からセクションを作成
    private func createSections(from path: [StationNode], in graph: StationGraph) -> [RouteSection] {
        var sections: [RouteSection] = []
        var currentSection: (start: Int, railway: String)?
        
        for i in 0..<path.count - 1 {
            let currentRailway = path[i].railway
            
            if currentSection == nil || currentSection?.railway != currentRailway {
                // 新しいセクションを開始
                if let section = currentSection {
                    sections.append(RouteSection(
                        railway: section.railway,
                        fromStation: path[section.start].name,
                        toStation: path[i - 1].name,
                        duration: calculateDuration(from: section.start, to: i - 1, in: path)
                    ))
                }
                currentSection = (start: i, railway: currentRailway)
            }
        }
        
        // 最後のセクションを追加
        if let section = currentSection {
            sections.append(RouteSection(
                railway: section.railway,
                fromStation: path[section.start].name,
                toStation: path[path.count - 1].name,
                duration: calculateDuration(from: section.start, to: path.count - 1, in: path)
            ))
        }
        
        return sections
    }
    
    // MARK: - Helper Methods
    
    /// 路線の駅リストを取得（キャッシュ付き）
    private func getStations(for railwayId: String) async throws -> [ODPTStation] {
        // キャッシュを確認
        if let cached = cachedRailwayStations[railwayId] {
            print("📦 Using cached stations for \(railwayId)")
            return cached
        }
        
        // APIから取得（現状は空の配列を返す - 実際にはODPT APIから取得する必要がある）
        apiCallCount += 1
        print("🌐 API call #\(apiCallCount): Getting stations for \(railwayId)")
        
        // TODO: 実際のAPI呼び出しを実装
        // 現在はモックデータとして主要駅のみ返す
        let mockStations = createMockStations(for: railwayId)
        cachedRailwayStations[railwayId] = mockStations
        
        return mockStations
    }
    
    /// モック駅データを作成
    private func createMockStations(for railwayId: String) -> [ODPTStation] {
        // 簡易的なモックデータ
        switch railwayId {
        case let id where id.contains("Yamanote"):
            return [
                ODPTStation(
                    id: "1", 
                    sameAs: "odpt.Station:JR-East.Yamanote.Tokyo", 
                    date: nil, 
                    title: "東京", 
                    stationTitle: ODPTMultilingualTitle(ja: "東京", en: "Tokyo"), 
                    railway: railwayId, 
                    railwayTitle: nil, 
                    operator: "odpt.Operator:JR-East",  // operatorは必須フィールド
                    operatorTitle: nil, 
                    stationCode: nil, 
                    connectingRailway: nil
                ),
                ODPTStation(
                    id: "2", 
                    sameAs: "odpt.Station:JR-East.Yamanote.Shinjuku", 
                    date: nil, 
                    title: "新宿", 
                    stationTitle: ODPTMultilingualTitle(ja: "新宿", en: "Shinjuku"), 
                    railway: railwayId, 
                    railwayTitle: nil, 
                    operator: "odpt.Operator:JR-East",  // operatorは必須フィールド
                    operatorTitle: nil, 
                    stationCode: nil, 
                    connectingRailway: nil
                )
            ]
        case let id where id.contains("ChuoLine"):
            return [
                ODPTStation(
                    id: "3",
                    sameAs: "odpt.Station:JR-East.ChuoLine.Tokyo",
                    date: nil,
                    title: "東京",
                    stationTitle: ODPTMultilingualTitle(ja: "東京", en: "Tokyo"),
                    railway: railwayId,
                    railwayTitle: nil,
                    operator: "odpt.Operator:JR-East",
                    operatorTitle: nil,
                    stationCode: nil,
                    connectingRailway: nil
                ),
                ODPTStation(
                    id: "4",
                    sameAs: "odpt.Station:JR-East.ChuoLine.Shinjuku",
                    date: nil,
                    title: "新宿",
                    stationTitle: ODPTMultilingualTitle(ja: "新宿", en: "Shinjuku"),
                    railway: railwayId,
                    railwayTitle: nil,
                    operator: "odpt.Operator:JR-East",
                    operatorTitle: nil,
                    stationCode: nil,
                    connectingRailway: nil
                ),
                ODPTStation(
                    id: "5",
                    sameAs: "odpt.Station:JR-East.ChuoLine.Nakano",
                    date: nil,
                    title: "中野",
                    stationTitle: ODPTMultilingualTitle(ja: "中野", en: "Nakano"),
                    railway: railwayId,
                    railwayTitle: nil,
                    operator: "odpt.Operator:JR-East",
                    operatorTitle: nil,
                    stationCode: nil,
                    connectingRailway: nil
                )
            ]
        case let id where id.contains("TokyoMetro.Marunouchi"):
            return [
                ODPTStation(
                    id: "6",
                    sameAs: "odpt.Station:TokyoMetro.Marunouchi.Tokyo",
                    date: nil,
                    title: "東京",
                    stationTitle: ODPTMultilingualTitle(ja: "東京", en: "Tokyo"),
                    railway: railwayId,
                    railwayTitle: nil,
                    operator: "odpt.Operator:TokyoMetro",
                    operatorTitle: nil,
                    stationCode: nil,
                    connectingRailway: nil
                ),
                ODPTStation(
                    id: "7",
                    sameAs: "odpt.Station:TokyoMetro.Marunouchi.Shinjuku",
                    date: nil,
                    title: "新宿",
                    stationTitle: ODPTMultilingualTitle(ja: "新宿", en: "Shinjuku"),
                    railway: railwayId,
                    railwayTitle: nil,
                    operator: "odpt.Operator:TokyoMetro",
                    operatorTitle: nil,
                    stationCode: nil,
                    connectingRailway: nil
                )
            ]
        default:
            return []
        }
    }
    
    /// 同名の駅を検索
    private func findSameNameStations(name: String) async throws -> [ODPTStation] {
        // HeartRails APIを使用して高速に検索
        apiCallCount += 1
        print("🌐 API call #\(apiCallCount): Searching stations named '\(name)'")
        
        // searchStationsを使用（Exactメソッドはprivateのため）
        let heartRailsClient = await HeartRailsAPIClient.shared
        let stations = try await heartRailsClient.searchStations(by: name)
        
        // 完全一致する駅のみフィルタリング
        let exactMatches = stations.filter { $0.name == name }
        return exactMatches.map { $0.toODPTStation() }
    }
    
    /// ノードを検索
    private func findNode(name: String, railway: String, in graph: StationGraph) -> StationNode? {
        graph.allNodes().first { node in
            node.name == name && node.railway.contains(railway)
        }
    }
    
    /// 駅名でノードを検索
    private func findNodes(name: String, in graph: StationGraph) -> [StationNode] {
        graph.allNodes().filter { $0.name == name }
    }
    
    /// 路線名からODPT IDを取得
    private func getODPTRailwayId(from railwayName: String) -> String? {
        // StationIDMapperの逆引きロジックを使用
        StationIDMapper.getODPTRailwayID(from: railwayName)
    }
    
    /// 乗り換え時間を取得
    private func getTransferTime(for stationName: String) -> Int {
        // StationConnectionManagerから取得、なければデフォルト3分
        StationConnectionManager.shared.getTransferTime(for: stationName)
    }
    
    /// 区間の所要時間を計算
    private func calculateDuration(from startIndex: Int, to endIndex: Int, in path: [StationNode]) -> Int {
        // 簡略化：駅数 × 2分
        (endIndex - startIndex) * 2
    }
}
