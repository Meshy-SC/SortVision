import Foundation

// MARK: - Level Data Models

/// Container for decoding level JSON files.
///
/// Each JSON file (e.g., `levels.json`, `levels-hard.json`) contains
/// a `levels` array of `Level` objects.
struct LevelGroup: Codable, Sendable {
    let levels: [Level]
}

/// Represents a single puzzle level with its tube configuration.
///
/// Each level defines a `map` of tube columns, where each column contains
/// color values (groupIds) that correspond to liquid segments.
///
/// ## JSON Format
/// ```json
/// {
///   "no": 1,
///   "map": [
///     { "values": [1, 1, 2] },
///     { "values": [2, 2, 1] },
///     { "values": [] }
///   ]
/// }
/// ```
///
/// ## Hashable Conformance
/// Required for `NavigationPath` routing. Auto-synthesized from `no` and `map`.
struct Level: Codable, Sendable, Identifiable, Hashable {
    /// 1-based level number, unique within its game mode.
    let no: Int

    /// Array of tube columns defining the initial puzzle state.
    let map: [LevelColumn]

    var id: Int { no }

    /// Converts the raw level map into grouped liquid data,
    /// compressing consecutive same-color values into single `LiquidData` entries.
    ///
    /// For example, `[1, 1, 2]` becomes:
    /// ```
    /// [LiquidData(groupId: 1, value: 2), LiquidData(groupId: 2, value: 1)]
    /// ```
    ///
    /// Faithfully mirrors Unity `Level.GetLiquidDatas(LevelColumn)`.
    var liquidDataMap: [[LiquidData]] {
        map.map { Self.getLiquidDatas(from: $0) }
    }

    /// Compresses a column's raw color values into grouped `LiquidData` entries.
    ///
    /// Consecutive values with the same groupId are merged into a single entry
    /// whose `value` equals the count of consecutive occurrences.
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

/// Represents a single tube column in the level definition.
///
/// Contains an array of color group IDs from bottom to top.
/// An empty `values` array represents an empty tube.
///
/// `Equatable` and `Hashable` are auto-synthesized from the `values` property.
struct LevelColumn: Codable, Sendable, Hashable {
    /// Color group IDs from bottom to top of the tube.
    /// Empty array represents an empty tube.
    let values: [Int]
}

/// A single liquid segment with a color group and volume.
///
/// Produced by compressing consecutive same-color values in a `LevelColumn`.
/// Used by `HolderNode.initialize(with:)` to populate tubes at level start.
struct LiquidData: Sendable, Equatable, Hashable {
    /// Index into `ColorPalette.colors` (0–10).
    let groupId: Int

    /// Number of liquid units this segment occupies.
    let value: CGFloat
}
