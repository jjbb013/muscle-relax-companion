import SwiftUI
import SceneKit

// MARK: - 3D 人体模型交互视图（需求 §3.3 / §6.1）
//
// 程序化低模人形（SCN 几何体拼装，零外部 3D 资产，规避商用授权风险）：
// 球体头（装饰不可选）、胶囊颈、躯干分 背/胸腹/腰 三段、肩部球关节、
// 上臂/前臂胶囊、髋部球、大腿/小腿胶囊、膝球、足部扁盒。
// 身高约 1.75 场景单位，正面朝 +Z，居中站立（足底 y≈0，头顶 y≈1.74）。
//
// 交互：
// - allowsCameraControl：单指旋转 / 双指捏合缩放 / 双指平移；
// - 单击 SCNHitTest 选部位（沿父链找 regionId 节点）；
// - 双击复位相机视角；
// - 选中反馈（§6.1.4）：emission 变 DT 主色 + 1.05× 缩放（SCNTransaction ≤300ms），
//   上一选中节点还原；左/右部位相机向该侧微倾环绕。
//
// 对外接口与 BodyMap2DView 同构：@Binding selectedRegionId + onSelect 回调，
// 可互换使用；「列表选择」保留为 VoiceOver 等价兜底路径（§10.1）。
//
// 侧别约定：人体正面朝 +Z，默认相机位于 +Z，故人体左侧 = +X（画面右侧），
// 与 2D 正面图一致（shoulder_l 在画面右半区）。

struct BodyScene3DView: View {
    @Binding var selectedRegionId: String?
    var onSelect: ((BodyRegion) -> Void)? = nil

    @State private var showRegionList = false

    var body: some View {
        VStack(spacing: 10) {
            // 列表选择入口（VoiceOver 等价路径，§10.1）
            HStack {
                Spacer()
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

            BodySceneRepresentable(selectedRegionId: $selectedRegionId, onSelect: onSelect)
                .aspectRatio(0.72, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: DT.Radius.card))

            Text("拖动旋转 · 捏合缩放 · 点选不适部位")
                .font(DT.Font.auxiliary)
                .foregroundStyle(DT.Color.textSecondary)
        }
        .sheet(isPresented: $showRegionList) {
            RegionListSheet(selectedRegionId: $selectedRegionId) { region in
                withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                    selectedRegionId = region.id
                }
                onSelect?(region)
            }
        }
    }
}

// MARK: - UIViewRepresentable 包装

private struct BodySceneRepresentable: UIViewRepresentable {
    @Binding var selectedRegionId: String?
    var onSelect: ((BodyRegion) -> Void)?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> BodySceneView {
        let view = BodySceneView()
        view.onRegionTapped = { id in
            context.coordinator.selectFromGesture(id)
        }
        // 无障碍（§10.1）：整体作为单个可访问元素，列表选择为等价路径
        view.isAccessibilityElement = true
        view.accessibilityLabel = "3D 人体模型，可旋转缩放"
        view.accessibilityHint = "单指拖动旋转，双指捏合缩放，点按选择部位。也可使用列表选择按钮。"
        view.accessibilityTraits = .allowsDirectInteraction
        if let selectedRegionId {
            view.select(regionId: selectedRegionId, animated: false)
        }
        return view
    }

    func updateUIView(_ view: BodySceneView, context: Context) {
        // 外部绑定变化（如列表选择）同步到 3D 高亮，不触发回调
        if view.currentRegionId != selectedRegionId {
            view.select(regionId: selectedRegionId, animated: true)
        }
    }

    final class Coordinator {
        private let parent: BodySceneRepresentable

        init(_ parent: BodySceneRepresentable) {
            self.parent = parent
        }

        func selectFromGesture(_ id: String) {
            parent.selectedRegionId = id
            if let region = StaticContent.region(id: id) {
                parent.onSelect?(region)
            }
        }
    }
}

// MARK: - SCNView 实现

final class BodySceneView: SCNView {

    /// 手势点选回调（regionId）
    var onRegionTapped: ((String) -> Void)?

    /// 当前高亮的 regionId（含外部同步），nil = 无选中
    private(set) var currentRegionId: String?

    private let cameraNode = SCNNode()
    private var regionNodes: [String: SCNNode] = [:]
    private var baseScales: [String: SCNVector3] = [:]

    /// 相机环绕中心（人体躯干中心）与默认距离
    private let cameraLookTarget = SCNVector3(0, 0.9, 0)
    private let cameraHomeDistance: Float = 3.1

    // MARK: 初始化

    /// SCNView 的指定初始化器是 init(frame:options:)，子类必须覆盖
    override init(frame: CGRect, options: [String: Any]? = nil) {
        super.init(frame: frame, options: options)
        commonInit()
    }

    convenience init() {
        self.init(frame: .zero, options: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func commonInit() {
        backgroundColor = UIColor(hex: 0xF7F8FA) // DT.Color.layeredBackground
        antialiasingMode = .multisampling4X
        autoenablesDefaultLighting = false
        allowsCameraControl = true

        let scene = SCNScene()
        scene.background.contents = UIColor(hex: 0xF7F8FA) // 跟随 DT.Color.layeredBackground
        self.scene = scene

        buildLights(into: scene)
        buildCamera(into: scene)
        buildFigure(into: scene)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        tap.require(toFail: doubleTap)
        addGestureRecognizer(tap)
        addGestureRecognizer(doubleTap)
    }

    // MARK: 场景搭建

    private func buildCamera(into scene: SCNScene) {
        let camera = SCNCamera()
        camera.fieldOfView = 55
        camera.zNear = 0.05
        camera.zFar = 50
        cameraNode.camera = camera
        applyCameraTransform(yaw: 0, animated: false)
        scene.rootNode.addChildNode(cameraNode)
        pointOfView = cameraNode
        // 环绕中心固定为人体躯干中心，单指旋转 / 双指捏合缩放围绕该点
        defaultCameraController.target = cameraLookTarget
    }

    /// 计算环绕机位：yaw 为绕 Y 轴偏转角（0 = 正面），相机始终看向 cameraLookTarget
    private func cameraTransform(yaw: Float) -> (position: SCNVector3, orientation: SCNQuaternion) {
        let distance = cameraHomeDistance
        let height: Float = 0.98
        let position = simd_float3(distance * sin(yaw), height, distance * cos(yaw))
        let target = simd_float3(cameraLookTarget.x, cameraLookTarget.y, cameraLookTarget.z)
        let forward = simd_normalize(target - position)   // 相机视线方向（世界 -Z 应对齐到它）
        let zAxis = -forward
        let xAxis = simd_normalize(simd_cross(simd_float3(0, 1, 0), zAxis))
        let yAxis = simd_cross(zAxis, xAxis)
        let q = simd_quatf(simd_float3x3(xAxis, yAxis, zAxis))
        return (SCNVector3(position.x, position.y, position.z),
                SCNQuaternion(q.vector.x, q.vector.y, q.vector.z, q.vector.w))
    }

    /// 应用相机机位（可选动画），不影响 allowsCameraControl 的环绕中心
    private func applyCameraTransform(yaw: Float, animated: Bool) {
        let transform = cameraTransform(yaw: yaw)
        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated ? 0.3 : 0
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cameraNode.position = transform.position
        cameraNode.orientation = transform.orientation
        SCNTransaction.commit()
    }

    private func buildLights(into scene: SCNScene) {
        // 环境光：保证无死黑阴影
        let ambientNode = SCNNode()
        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = UIColor(white: 1.0, alpha: 1.0)
        ambient.intensity = 500
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        // 主光：柔和 directional，前上方偏右，不投影
        let keyNode = SCNNode()
        let key = SCNLight()
        key.type = .directional
        key.color = UIColor(white: 1.0, alpha: 1.0)
        key.intensity = 750
        key.castsShadow = false
        keyNode.light = key
        keyNode.eulerAngles = SCNVector3(-0.7, 0.6, 0)
        scene.rootNode.addChildNode(keyNode)

        // 补光：左后方低强度，避免背面全暗
        let fillNode = SCNNode()
        let fill = SCNLight()
        fill.type = .omni
        fill.color = UIColor(hex: 0xDCE9FF)
        fill.intensity = 320
        fillNode.light = fill
        fillNode.position = SCNVector3(-1.6, 1.6, -1.4)
        scene.rootNode.addChildNode(fillNode)
    }

    /// 程序化低模人形（正面朝 +Z；人体左侧 = +X）
    private func buildFigure(into scene: SCNScene) {
        let root = SCNNode()
        scene.rootNode.addChildNode(root)

        // 地面软垫（装饰）
        let floorNode = SCNNode(geometry: SCNCylinder(radius: 0.44, height: 0.008))
        floorNode.position = SCNVector3(0, 0.004, 0)
        floorNode.geometry?.firstMaterial = decorativeMaterial(color: UIColor(hex: 0xE4EAF3))
        root.addChildNode(floorNode)

        // 头（装饰节点，不可选）
        let head = SCNNode(geometry: SCNSphere(radius: 0.105))
        head.position = SCNVector3(0, 1.63, 0)
        head.geometry?.firstMaterial = decorativeMaterial(color: UIColor(hex: 0xD9E6F9))
        root.addChildNode(head)

        // 颈
        addRegion("neck_c", to: root,
                  geometry: SCNCapsule(capRadius: 0.048, height: 0.12),
                  position: SCNVector3(0, 1.47, 0))

        // 躯干核心（装饰，垫在 背/胸腹/腰 三段之下）
        let torsoCore = SCNNode(geometry: SCNCapsule(capRadius: 0.115, height: 0.42))
        torsoCore.position = SCNVector3(0, 1.19, 0)
        torsoCore.geometry?.firstMaterial = decorativeMaterial(color: UIColor(hex: 0xC3D8F3))
        root.addChildNode(torsoCore)

        // 躯干三段：背（后凸贴片）、胸腹（前凸贴片）、腰（环带）
        addRegion("back_c", to: root,
                  geometry: SCNCapsule(capRadius: 0.10, height: 0.20),
                  position: SCNVector3(0, 1.30, -0.10),
                  scale: SCNVector3(1.15, 1.0, 0.5))
        addRegion("abdomen_c", to: root,
                  geometry: SCNCapsule(capRadius: 0.09, height: 0.16),
                  position: SCNVector3(0, 1.15, 0.10),
                  scale: SCNVector3(1.2, 1.0, 0.5))
        addRegion("waist_c", to: root,
                  geometry: SCNCapsule(capRadius: 0.105, height: 0.13),
                  position: SCNVector3(0, 1.01, 0),
                  scale: SCNVector3(1.1, 1.0, 1.0))

        // 肩 / 臂（左侧 = +X）
        for side in [-1.0, 1.0] as [Double] {
            let suffix = side > 0 ? "_l" : "_r"
            let x = Float(0.20 * side)

            addRegion("shoulder\(suffix)", to: root,
                      geometry: SCNSphere(radius: 0.07),
                      position: SCNVector3(x, 1.40, 0))
            addRegion("upper_arm\(suffix)", to: root,
                      geometry: SCNCapsule(capRadius: 0.047, height: 0.26),
                      position: SCNVector3(Float(0.215 * side), 1.20, 0))
            addRegion("forearm\(suffix)", to: root,
                      geometry: SCNCapsule(capRadius: 0.042, height: 0.24),
                      position: SCNVector3(Float(0.235 * side), 0.94, 0))

            // 手（装饰）
            let hand = SCNNode(geometry: SCNSphere(radius: 0.045))
            hand.position = SCNVector3(Float(0.245 * side), 0.78, 0)
            hand.geometry?.firstMaterial = decorativeMaterial(color: UIColor(hex: 0xD9E6F9))
            root.addChildNode(hand)

            // 髋 / 腿
            addRegion("hip\(suffix)", to: root,
                      geometry: SCNSphere(radius: 0.075),
                      position: SCNVector3(Float(0.085 * side), 0.92, 0),
                      scale: SCNVector3(1.0, 0.8, 1.0))
            addRegion("thigh\(suffix)", to: root,
                      geometry: SCNCapsule(capRadius: 0.068, height: 0.38),
                      position: SCNVector3(Float(0.085 * side), 0.71, 0))
            addRegion("knee\(suffix)", to: root,
                      geometry: SCNSphere(radius: 0.058),
                      position: SCNVector3(Float(0.085 * side), 0.50, 0))
            addRegion("calf\(suffix)", to: root,
                      geometry: SCNCapsule(capRadius: 0.052, height: 0.34),
                      position: SCNVector3(Float(0.085 * side), 0.30, 0))

            // 足（扁盒 + 踝球子节点，命中后沿父链归并到 foot_*）
            let foot = addRegion("foot\(suffix)", to: root,
                                 geometry: SCNBox(width: 0.09, height: 0.09, length: 0.17, chamferRadius: 0.025),
                                 position: SCNVector3(Float(0.085 * side), 0.055, 0.03))
            let ankle = SCNNode(geometry: SCNSphere(radius: 0.042))
            ankle.position = SCNVector3(0, 0.07, -0.02)
            ankle.geometry?.firstMaterial = foot.geometry?.firstMaterial
            foot.addChildNode(ankle)
        }
    }

    @discardableResult
    private func addRegion(_ id: String, to parent: SCNNode,
                           geometry: SCNGeometry,
                           position: SCNVector3,
                           scale: SCNVector3 = SCNVector3(1, 1, 1)) -> SCNNode {
        let node = SCNNode(geometry: geometry)
        node.name = id
        node.position = position
        node.scale = scale
        let category = StaticContent.region(id: id)?.category ?? .other
        geometry.firstMaterial = regionMaterial(category: category)
        parent.addChildNode(node)
        regionNodes[id] = node
        baseScales[id] = scale
        return node
    }

    // MARK: 材质

    /// 肌肉分区配色：以 #3D8BFF 蓝色系为主基调，颈/肩一组柔和暖色点缀
    private func baseColor(for category: RegionCategory) -> UIColor {
        switch category {
        case .neck, .shoulder: return UIColor(hex: 0xF2B49B) // 暖杏
        case .back:            return UIColor(hex: 0x7BAFEE)
        case .waist:           return UIColor(hex: 0x8FBBF2)
        case .abdomen:         return UIColor(hex: 0xA9CBF7)
        case .upperArm:        return UIColor(hex: 0x93BFF3)
        case .forearm:         return UIColor(hex: 0xA5CAF6)
        case .hip:             return UIColor(hex: 0x84B7F0)
        case .thigh:           return UIColor(hex: 0x9CC4F5)
        case .knee:            return UIColor(hex: 0xA9CBF7)
        case .calf:            return UIColor(hex: 0xB3D1F8)
        case .other:           return UIColor(hex: 0xC3D8F3) // 足部
        }
    }

    /// 部位材质：哑光 + 轻微半透明
    private func regionMaterial(category: RegionCategory) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = baseColor(for: category)
        material.roughness.contents = NSNumber(value: 0.85)
        material.metalness.contents = NSNumber(value: 0.0)
        material.transparency = 0.95
        return material
    }

    private func decorativeMaterial(color: UIColor) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = color
        material.roughness.contents = NSNumber(value: 0.9)
        material.metalness.contents = NSNumber(value: 0.0)
        return material
    }

    // MARK: 选中反馈

    /// 设置 / 清除选中高亮。emission 变 DT 主色 + 1.05× 缩放（SCNTransaction ≤300ms），
    /// 旧选中节点还原；左/右部位相机向该侧微倾（§6.1.4）。
    func select(regionId: String?, animated: Bool) {
        guard regionId != currentRegionId else { return }

        // 还原旧选中
        if let oldId = currentRegionId, let oldNode = regionNodes[oldId] {
            let base = baseScales[oldId] ?? SCNVector3(1, 1, 1)
            SCNTransaction.begin()
            SCNTransaction.animationDuration = animated ? 0.25 : 0
            oldNode.scale = base
            oldNode.geometry?.firstMaterial?.emission.contents = UIColor.black
            oldNode.geometry?.firstMaterial?.emission.intensity = 1.0
            SCNTransaction.commit()
        }

        currentRegionId = regionId

        guard let id = regionId, let node = regionNodes[id] else { return }
        let base = baseScales[id] ?? SCNVector3(1, 1, 1)

        // 新选中：高亮 + 放大弹簧（≤300ms）
        SCNTransaction.begin()
        SCNTransaction.animationDuration = animated ? 0.28 : 0
        SCNTransaction.animationTimingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        node.scale = SCNVector3(base.x * 1.05, base.y * 1.05, base.z * 1.05)
        node.geometry?.firstMaterial?.emission.contents = UIColor(hex: 0x3D8BFF) // DT.Color.primary
        node.geometry?.firstMaterial?.emission.intensity = 0.85
        SCNTransaction.commit()

        // 相机向选中侧微倾（左侧 +X：相机绕 Y 轴 +0.22 rad 环绕偏转）
        let yaw: Float = id.hasSuffix("_l") ? 0.22 : (id.hasSuffix("_r") ? -0.22 : 0)
        applyCameraTransform(yaw: yaw, animated: animated)
    }

    // MARK: 手势

    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        let hits = hitTest(location, options: [
            SCNHitTestOption.searchMode: NSNumber(value: SCNHitTestSearchMode.closest.rawValue)
        ])
        for hit in hits {
            var node: SCNNode? = hit.node
            while let current = node {
                if let name = current.name, regionNodes[name] != nil {
                    select(regionId: name, animated: true)
                    onRegionTapped?(name)
                    return
                }
                node = current.parent
            }
        }
    }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        // 双击复位相机视角
        applyCameraTransform(yaw: 0, animated: true)
    }
}

// MARK: - UIColor hex

private extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
