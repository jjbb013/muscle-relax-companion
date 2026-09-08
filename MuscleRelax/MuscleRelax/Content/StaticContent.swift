import Foundation

// MARK: - 内置静态内容（随包只读，不进用户备份；需求 §4 / §6.5 / §6.6）
// 由 Content/ 实现填充；UI 仅通过本命名空间访问。
// 数据实现拆分为：RegionsData / TemplatesData / StretchGuidesData / SynonymsData。

enum StaticContent {
    /// 全部身体部位（含左右拆分，如 shoulder_l / shoulder_r）
    static let regions: [BodyRegion] = RegionsData.all

    /// 内置高频放松模板（10 个）
    static let builtinTemplates: [BuiltinTemplate] = TemplatesData.all

    /// 自助舒缓参考（按部位）
    static let stretchGuides: [StretchGuide] = StretchGuidesData.all

    /// 同义词表：口语词 → 规范部位分类关键词（语义识别用，如 "脖子"→"颈"）
    static let synonyms: [String: String] = SynonymsData.table

    static func region(id: String) -> BodyRegion? {
        regions.first { $0.id == id }
    }

    static func stretchGuides(forRegionId regionId: String) -> [StretchGuide] {
        stretchGuides.filter { $0.regionId == regionId }
    }

    static func templates(forRegionId regionId: String) -> [BuiltinTemplate] {
        builtinTemplates.filter { $0.regionId == regionId }
    }
}
