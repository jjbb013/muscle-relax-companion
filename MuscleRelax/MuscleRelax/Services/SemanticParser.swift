import Foundation
import NaturalLanguage

// MARK: - 语义识别（需求 §6.3）
//
// 管线：NLTagger(.word) 分词 → 本地部位词典（StaticContent.regions）
// 精确匹配 → 同义词表（StaticContent.synonyms）映射匹配 → 左右侧邻近窗口检测
// → 等级推断词。识别失败返回空数组，绝不强行猜测（§6.3.3 手动点选兜底）。
//
// 纯值类型、无状态、Sendable，可在任意线程调用。

struct SemanticParser: SemanticParsing {

    init() {}

    // MARK: 词表（§6.3.2 等级推断词）

    /// 重度：数组按"更具体在前"排列，contains 扫描时避免 "很" 提前截获 "很严重"
    private static let severeWords = ["特别严重", "非常严重", "很严重", "严重", "非常", "特别", "很"]
    /// 中度
    private static let moderateWords = ["比较", "挺", "中度"]
    /// 轻度：长的在前，避免 "一点" 截获 "一点儿"
    private static let mildWords = ["轻微", "有点儿", "有点", "一点儿", "一点", "略"]

    /// 左侧修饰词
    private static let leftWords: [Character] = ["左"]
    /// 右侧修饰词
    private static let rightWords: [Character] = ["右"]
    /// 双侧修饰词
    private static let bothWords = ["双侧", "两边", "两侧", "双"]

    /// 侧别修饰词与部位词之间的最大字符距离（邻近窗口）
    private static let sideWindow = 4

    // MARK: SemanticParsing

    func parse(_ text: String) -> [SemanticMatch] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        // 1) NLTagger(.word) 分词。zh-CN 下可直接处理中英文混合文本。
        //    分词用于"整词命中"判定；同时保留子串命中兜底，
        //    因为中文部位词（如"斜方肌"）可能被分词器切开或合并。
        let tokens = tokenize(trimmed)

        // 2) 全局等级推断（对整句生效，施加到所有部位候选上）
        let level = inferLevel(in: trimmed)

        // 3) 部位匹配：每个部位取所有命中途径中的最高置信度
        var bestByRegion: [String: (confidence: Double, matchedTerm: String)] = [:]

        for region in StaticContent.regions {
            var best: (confidence: Double, matchedTerm: String)?

            func consider(_ confidence: Double, _ term: String) {
                if best == nil || confidence > best!.confidence {
                    best = (confidence, term)
                }
            }

            // 3a) displayName 精确命中：最高置信
            if hit(term: region.displayName, in: trimmed, tokens: tokens) {
                consider(0.90, region.displayName)
            }
            // 3b) 关联肌肉名命中
            for muscle in region.muscleNames where hit(term: muscle, in: trimmed, tokens: tokens) {
                consider(0.75, muscle)
            }
            // 3c) 同义词命中：口语词映射到规范关键词，规范关键词需能关联回本部位
            for (spoken, canonical) in StaticContent.synonyms
            where hit(term: spoken, in: trimmed, tokens: tokens)
                && Self.canonical(canonical, belongsTo: region) {
                consider(0.70, spoken)
            }

            if let best {
                bestByRegion[region.id] = best
            }
        }

        // 4) 组装结果：侧别 = 命中词邻近窗口内的"左/右/双"修饰，缺省回退部位自身侧别
        var matches: [SemanticMatch] = []
        matches.reserveCapacity(bestByRegion.count)

        for region in StaticContent.regions {
            guard let (confidence, term) = bestByRegion[region.id] else { continue }
            let detectedSide = detectSide(forTerm: term, in: trimmed)
            let side = detectedSide ?? region.side

            // 置信度规则（供评审/调参）：
            //   displayName 精确命中 0.90 > 肌肉名 0.75 > 同义词 0.70；
            //   邻近窗口内检测到明确侧别 +0.05（封顶 1.0），因为左右歧义是
            //   本 App 最高风险错误（§6.2 强制确认弹窗），显式侧别应提高置信。
            //   命中途径之间不叠加，取最高值，避免长词典刷分。
            var final = confidence
            if detectedSide != nil { final = min(1.0, final + 0.05) }

            matches.append(SemanticMatch(
                regionId: region.id,
                side: side,
                level: level,
                confidence: final
            ))
        }

        // 5) 按置信度降序；同分时按部位 id 保证输出稳定
        return matches.sorted {
            $0.confidence != $1.confidence
                ? $0.confidence > $1.confidence
                : $0.regionId < $1.regionId
        }
    }

    // MARK: 分词与命中

    /// NLTokenizer 分词，返回去空白/标点后的词元
    private func tokenize(_ text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.setLanguage(.simplifiedChinese)
        tokenizer.string = text
        var tokens: [String] = []
        tokens.reserveCapacity(32)
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let token = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
            if !token.isEmpty { tokens.append(token) }
            return true
        }
        return tokens
    }

    /// 命中判定：词元整词相等，或作为原文子串出现（兜底中文分词的不稳定性）
    private func hit(term: String, in text: String, tokens: [String]) -> Bool {
        guard !term.isEmpty else { return false }
        return tokens.contains(term) || text.contains(term)
    }

    /// 同义词映射出的规范关键词是否关联到该部位：
    /// 与部位的 displayName / 分类名 / 肌肉名存在包含关系即视为关联。
    private static func canonical(_ canonical: String, belongsTo region: BodyRegion) -> Bool {
        guard !canonical.isEmpty else { return false }
        if region.displayName.contains(canonical) || canonical.contains(region.displayName) {
            return true
        }
        if region.category.displayName.contains(canonical) {
            return true
        }
        return region.muscleNames.contains { $0.contains(canonical) }
    }

    // MARK: 侧别检测

    /// 在命中词前向邻近窗口（最多 sideWindow 个字符）内查找 左/右/双 修饰词；
    /// 也在全句范围查找"双/两边/两侧"（双侧修饰通常不受位置限制）。
    /// 找不到返回 nil，由调用方回退部位自身侧别。
    private func detectSide(forTerm term: String, in text: String) -> RegionSide? {
        if let range = text.range(of: term) {
            let windowStart = text.index(range.lowerBound,
                                         offsetBy: -Self.sideWindow,
                                         limitedBy: text.startIndex) ?? text.startIndex
            let window = text[windowStart..<range.lowerBound]
            if window.contains(where: { Self.leftWords.contains($0) }) { return .left }
            if window.contains(where: { Self.rightWords.contains($0) }) { return .right }
            if Self.bothWords.contains(where: { window.contains($0) }) { return .both }
        }
        if Self.bothWords.contains(where: { text.contains($0) }) { return .both }
        return nil
    }

    // MARK: 等级推断

    /// 严重度取全句最高命中档：先扫重度词、再中度、再轻度。
    /// 注意：单字词（"很"、"挺"）可能出现在非严重语境（如"挺好"），
    /// 本 App 输入域限定为酸痛描述，误报可接受；低置信结果本就会走手动确认（§6.2/§6.3.3）。
    private func inferLevel(in text: String) -> SoreLevel? {
        if Self.severeWords.contains(where: { text.contains($0) }) { return .severe }
        if Self.moderateWords.contains(where: { text.contains($0) }) { return .moderate }
        if Self.mildWords.contains(where: { text.contains($0) }) { return .mild }
        return nil
    }
}
