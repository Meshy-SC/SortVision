import Foundation
import CoreGraphics

struct LevelGroup: Codable, Sendable {
    let levels: [Level]
}

struct Level: Codable, Sendable, Identifiable {
    let no: Int
    let map: [LevelColumn]

    var id: Int { no }

    /// Converts the raw level map into grouped liquid data,
    /// compressing consecutive same-color values into single LiquidData entries.
    /// Faithfully mirrors Unity Level.GetLiquidDatas(LevelColumn).
    var liquidDataMap: [[LiquidData]] {
        map.map { Self.getLiquidDatas(from: $0) }
    }

    static func getLiquidDatas(from column: LevelColumn) -> [LiquidData] {
        let values = column.values
        guard !values.isEmpty else { return [] }

        var result: [LiquidData] = []
        var i = 0
        while i < values.count {
            let currentGroup = values[i]
            var count = 0
            while i < values.count && values[i] == currentGroup {
                count += 1
                i += 1
            }
            result.append(LiquidData(groupId: currentGroup, value: CGFloat(count)))
        }
        return result
    }
}

struct LevelColumn: Codable, Sendable {
    let values: [Int]
}

struct LiquidData: Sendable {
    let groupId: Int
    let value: CGFloat
}
