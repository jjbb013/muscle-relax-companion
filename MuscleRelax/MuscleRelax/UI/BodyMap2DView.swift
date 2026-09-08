import SwiftUI

// MARK: - 2D 人体热区图（需求 §6.1 / §3.3 降级方案，首发启用）
//
// SwiftUI Canvas 绘制正面 + 背面人体剪影，热区覆盖 StaticContent.regions 全部 20 个部位。
// - 前 / 背面分段切换；双侧部位（shoulder_l / shoulder_r 等）独立热区可选；
// - 选中反馈：1.05× 放大 + 渐变填色（primary → primaryLight）+ 柔和回弹（≤ 300ms spring）；
// - 无障碍：每个热区有 VoiceOver 语义标签；「列表选择」提供等价兜底入口（§10.1）。
//
// 坐标系说明：unit 坐标（0...1）。正面 = 面对用户，故人体左侧位于画面右侧；
// 背面 = 背对用户，人体左侧位于画面左侧。列表选择为精确兜底，不受图示影响。

struct BodyMap2DView: View {

    enum MapSide: String, CaseIterable, Identifiable {
        case front, back
        var id: String { rawValue }
        var displayName: String { self == .front ? "正面" : "背面" }
    }

    /// 单个热区的归一化布局（中心点 + 椭圆宽高）
    struct Hotspot {
        let regionId: String
        let x: CGFloat
        let y: CGFloat
        let w: CGFloat
        let h: CGFloat
    }

    @Binding var selectedRegionId: String?
    var onSelect: ((BodyRegion) -> Void)? = nil

    @State private var mapSide: MapSide = .front
    @State private var showRegionList = false

    // MARK: 热区布局表

    /// 正面：人体左侧 = 画面右侧
    private static let frontHotspots: [Hotspot] = [
        Hotspot(regionId: "neck_c",       x: 0.500, y: 0.145, w: 0.150, h: 0.070),
        Hotspot(regionId: "shoulder_r",   x: 0.295, y: 0.215, w: 0.170, h: 0.085),
        Hotspot(regionId: "shoulder_l",   x: 0.705, y: 0.215, w: 0.170, h: 0.085),
        Hotspot(regionId: "abdomen_c",    x: 0.500, y: 0.395, w: 0.230, h: 0.120),
        Hotspot(regionId: "upper_arm_r",  x: 0.170, y: 0.345, w: 0.105, h: 0.150),
        Hotspot(regionId: "upper_arm_l",  x: 0.830, y: 0.345, w: 0.105, h: 0.150),
        Hotspot(regionId: "forearm_r",    x: 0.140, y: 0.515, w: 0.100, h: 0.140),
        Hotspot(regionId: "forearm_l",    x: 0.860, y: 0.515, w: 0.100, h: 0.140),
        Hotspot(regionId: "thigh_r",      x: 0.425, y: 0.615, w: 0.135, h: 0.170),
        Hotspot(regionId: "thigh_l",      x: 0.575, y: 0.615, w: 0.135, h: 0.170),
        Hotspot(regionId: "knee_r",       x: 0.425, y: 0.740, w: 0.115, h: 0.065),
        Hotspot(regionId: "knee_l",       x: 0.575, y: 0.740, w: 0.115, h: 0.065),
        Hotspot(regionId: "calf_r",       x: 0.425, y: 0.845, w: 0.110, h: 0.135),
        Hotspot(regionId: "calf_l",       x: 0.575, y: 0.845, w: 0.110, h: 0.135),
        Hotspot(regionId: "foot_r",       x: 0.415, y: 0.955, w: 0.125, h: 0.055),
        Hotspot(regionId: "foot_l",       x: 0.585, y: 0.955, w: 0.125, h: 0.055),
    ]

    /// 背面：人体左侧 = 画面左侧（与肩 / 大腿 / 小腿热区复用同部位 id，背面肌群同样可选）
    private static let backHotspots: [Hotspot] = [
        Hotspot(regionId: "neck_c",       x: 0.500, y: 0.145, w: 0.150, h: 0.070),
        Hotspot(regionId: "shoulder_l",   x: 0.295, y: 0.215, w: 0.170, h: 0.085),
        Hotspot(regionId: "shoulder_r",   x: 0.705, y: 0.215, w: 0.170, h: 0.085),
        Hotspot(regionId: "back_c",       x: 0.500, y: 0.330, w: 0.250, h: 0.130),
        Hotspot(regionId: "waist_c",      x: 0.500, y: 0.450, w: 0.220, h: 0.095),
        Hotspot(regionId: "hip_l",        x: 0.405, y: 0.545, w: 0.140, h: 0.095),
        Hotspot(regionId: "hip_r",        x: 0.595, y: 0.545, w: 0.140, h: 0.095),
        Hotspot(regionId: "thigh_l",      x: 0.425, y: 0.650, w: 0.135, h: 0.140),
        Hotspot(regionId: "thigh_r",      x: 0.575, y: 0.650, w: 0.135, h: 0.140),
        Hotspot(regionId: "calf_l",       x: 0.425, y: 0.845, w: 0.110, h: 0.135),
        Hotspot(regionId: "calf_r",       x: 0.575, y: 0.845, w: 0.110, h: 0.135),
    ]

    private var hotspots: [Hotspot] {
        mapSide == .front ? Self.frontHotspots : Self.backHotspots
    }

    var body: some View {
        VStack(spacing: 10) {
            // 前 / 背面切换 + 列表选择入口
            HStack {
                Picker("人体视角", selection: $mapSide) {
                    ForEach(MapSide.allCases) { side in
                        Text(side.displayName).tag(side)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("人体视角切换，正面或背面")

                Button {
                    showRegionList = true
                } label: {
                    Label("列表", systemImage: "list.bullet")
                        .font(DT.Font.auxiliary.weight(.medium))
                        .foregroundStyle(DT.Color.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(DT.Color.primaryLight)
                        .clipShape(RoundedRectangle(cornerRadius: DT.Radius.tag))
                }
                .accessibilityLabel("列表选择部位")
                .accessibilityHint("以列表形式选择身体部位，适合旁白用户")
            }
            .padding(.horizontal, 4)

            // 人体图 + 热区
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    Canvas { context, canvasSize in
                        drawFigure(context: &context, size: canvasSize, back: mapSide == .back)
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                    ForEach(hotspots, id: \.regionId) { spot in
                        hotspotButton(spot: spot, canvasSize: size)
                    }
                }
            }
            .aspectRatio(0.52, contentMode: .fit)
            .frame(maxWidth: .infinity)

            Text(mapSide == .front ? "正面示意 · 点选不适部位" : "背面示意 · 点选不适部位")
                .font(DT.Font.auxiliary)
                .foregroundStyle(DT.Color.textSecondary)
        }
        .sheet(isPresented: $showRegionList) {
            RegionListSheet(selectedRegionId: $selectedRegionId) { region in
                select(region)
            }
        }
    }

    // MARK: 热区按钮

    @ViewBuilder
    private func hotspotButton(spot: Hotspot, canvasSize: CGSize) -> some View {
        let isSelected = selectedRegionId == spot.regionId
        let region = StaticContent.region(id: spot.regionId)
        let center = CGPoint(x: spot.x * canvasSize.width, y: spot.y * canvasSize.height)
        let w = spot.w * canvasSize.width
        let h = spot.h * canvasSize.height

        Button {
            if let region { select(region) }
        } label: {
            Ellipse()
                .fill(
                    isSelected
                    ? LinearGradient(colors: [DT.Color.primary, DT.Color.primaryLight],
                                     startPoint: .top, endPoint: .bottom)
                    : LinearGradient(colors: [DT.Color.primaryLight.opacity(0.55),
                                              DT.Color.primaryLight.opacity(0.35)],
                                     startPoint: .top, endPoint: .bottom)
                )
                .overlay(
                    Ellipse()
                        .stroke(DT.Color.primary.opacity(isSelected ? 0.9 : 0.35),
                                lineWidth: isSelected ? 2 : 1)
                )
                .frame(width: w, height: h)
                .overlay {
                    if isSelected, let region {
                        Text(region.displayName)
                            .font(DT.Font.auxiliary.weight(.semibold))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.5)
                            .lineLimit(1)
                            .padding(.horizontal, 4)
                    }
                }
                .scaleEffect(isSelected ? 1.05 : 1.0)
        }
        .buttonStyle(.plain)
        .position(center)
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isSelected)
        .accessibilityLabel(region?.displayName ?? "部位")
        .accessibilityHint(isSelected ? "已选中" : "双击选中该部位")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func select(_ region: BodyRegion) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
            selectedRegionId = region.id
        }
        onSelect?(region)
    }

    // MARK: 剪影绘制（Canvas）

    private func drawFigure(context: inout GraphicsContext, size: CGSize, back: Bool) {
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect {
            CGRect(x: x * size.width, y: y * size.height,
                   width: w * size.width, height: h * size.height)
        }
        let fill = DT.Color.layeredBackground
        let stroke = DT.Color.textSecondary.opacity(0.35)

        func fillStroke(_ path: Path) {
            context.fill(path, with: .color(fill))
            context.stroke(path, with: .color(stroke), lineWidth: 1.5)
        }

        // 头
        fillStroke(Path(ellipseIn: rect(0.425, 0.015, 0.150, 0.105)))
        // 颈
        fillStroke(Path(roundedRect: rect(0.455, 0.115, 0.090, 0.045), cornerRadius: 6))
        // 躯干（肩到髋）
        fillStroke(Path(roundedRect: rect(0.290, 0.165, 0.420, 0.380), cornerRadius: 26))
        // 左臂 / 右臂（画面左右）
        fillStroke(Path(roundedRect: rect(0.120, 0.185, 0.105, 0.400), cornerRadius: 24))
        fillStroke(Path(roundedRect: rect(0.775, 0.185, 0.105, 0.400), cornerRadius: 24))
        // 手
        fillStroke(Path(ellipseIn: rect(0.125, 0.580, 0.095, 0.065)))
        fillStroke(Path(ellipseIn: rect(0.780, 0.580, 0.095, 0.065)))
        // 左腿 / 右腿
        fillStroke(Path(roundedRect: rect(0.355, 0.545, 0.135, 0.380), cornerRadius: 24))
        fillStroke(Path(roundedRect: rect(0.510, 0.545, 0.135, 0.380), cornerRadius: 24))
        // 足
        fillStroke(Path(ellipseIn: rect(0.340, 0.930, 0.150, 0.055)))
        fillStroke(Path(ellipseIn: rect(0.510, 0.930, 0.150, 0.055)))

        if back {
            // 背面脊柱示意线
            var spine = Path()
            spine.move(to: CGPoint(x: 0.5 * size.width, y: 0.17 * size.height))
            spine.addLine(to: CGPoint(x: 0.5 * size.width, y: 0.52 * size.height))
            context.stroke(spine, with: .color(DT.Color.textSecondary.opacity(0.25)),
                           style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
        }
    }
}

// MARK: - 列表选择（VoiceOver 等价兜底，需求 §10.1）

struct RegionListSheet: View {
    @Binding var selectedRegionId: String?
    var onSelect: (BodyRegion) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(RegionCategory.allCases, id: \.self) { category in
                    let regions = StaticContent.regions.filter { $0.category == category }
                    if !regions.isEmpty {
                        Section(category.displayName) {
                            ForEach(regions) { region in
                                Button {
                                    onSelect(region)
                                    dismiss()
                                } label: {
                                    HStack {
                                        Text(region.displayName)
                                            .font(DT.Font.body)
                                            .foregroundStyle(DT.Color.textPrimary)
                                        Spacer()
                                        if selectedRegionId == region.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(DT.Color.primary)
                                                .accessibilityHidden(true)
                                        }
                                    }
                                }
                                .accessibilityLabel(region.displayName)
                                .accessibilityHint(selectedRegionId == region.id ? "当前已选中" : "双击选择")
                            }
                        }
                    }
                }
            }
            .navigationTitle("列表选择部位")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}
