import Foundation

// MARK: - 身体部位静态数据（需求 §4 / §6.1）
// 口径：仅作身体状态记录与按摩放松沟通参考；按压点统一标注"位置示意，仅供参考"。

private func point(_ id: String, _ name: String, _ regionId: String) -> PressPoint {
    PressPoint(id: id, name: name, regionId: regionId, note: "位置示意，仅供参考")
}

enum RegionsData {
    static let all: [BodyRegion] = [

        // MARK: 精细渲染区（isFineRendered = true）

        BodyRegion(
            id: "neck_c",
            displayName: "颈部",
            side: .center,
            category: .neck,
            muscleNames: ["斜方肌上部", "胸锁乳突肌", "头夹肌", "肩胛提肌"],
            pressPoints: [
                point("pp_neck_fengchi", "风池区域", "neck_c"),
                point("pp_neck_jianjing", "肩井区域", "neck_c"),
                point("pp_neck_tianzhu", "天柱区域", "neck_c"),
            ],
            fatigueScenes: ["长时间低头看手机", "久坐伏案、头部长时间前伸", "睡眠姿势不当后晨起僵硬"],
            relaxSuggestions: ["颈部轻柔拉伸与缓慢转头活动", "颈后部热敷 10–15 分钟", "调整屏幕与视线平齐，每 30–40 分钟抬头休息"],
            isFineRendered: true
        ),

        BodyRegion(
            id: "shoulder_l",
            displayName: "左肩",
            side: .left,
            category: .shoulder,
            muscleNames: ["三角肌", "斜方肌上部", "冈上肌", "冈下肌"],
            pressPoints: [
                point("pp_shoulder_l_jianjing", "肩井区域", "shoulder_l"),
                point("pp_shoulder_l_tianzong", "天宗区域", "shoulder_l"),
                point("pp_shoulder_l_jianyu", "肩髃区域", "shoulder_l"),
            ],
            fatigueScenes: ["久坐伏案、含胸耸肩", "单肩背包或侧卧受压", "长时间抬手操作（开车、理发、家务）"],
            relaxSuggestions: ["耸肩—沉肩缓慢交替练习", "肩部轻柔画圈活动", "温热毛巾敷肩 10–15 分钟"],
            isFineRendered: true
        ),

        BodyRegion(
            id: "shoulder_r",
            displayName: "右肩",
            side: .right,
            category: .shoulder,
            muscleNames: ["三角肌", "斜方肌上部", "冈上肌", "冈下肌"],
            pressPoints: [
                point("pp_shoulder_r_jianjing", "肩井区域", "shoulder_r"),
                point("pp_shoulder_r_tianzong", "天宗区域", "shoulder_r"),
                point("pp_shoulder_r_jianyu", "肩髃区域", "shoulder_r"),
            ],
            fatigueScenes: ["久坐伏案、含胸耸肩", "长时间使用鼠标", "单肩背包或侧卧受压"],
            relaxSuggestions: ["耸肩—沉肩缓慢交替练习", "肩部轻柔画圈活动", "温热毛巾敷肩 10–15 分钟"],
            isFineRendered: true
        ),

        BodyRegion(
            id: "back_c",
            displayName: "背部",
            side: .center,
            category: .back,
            muscleNames: ["斜方肌", "背阔肌", "竖脊肌", "菱形肌"],
            pressPoints: [
                point("pp_back_tianzong", "天宗区域", "back_c"),
                point("pp_back_gaohuang", "膏肓区域", "back_c"),
                point("pp_back_zhiyang", "至阳区域", "back_c"),
            ],
            fatigueScenes: ["久坐伏案、背部持续紧绷", "弯腰搬重物后酸胀", "长时间站立或驾驶"],
            relaxSuggestions: ["猫式伸展等轻柔脊柱活动", "靠墙站立、双肩后展放松", "背部热敷或温水淋浴"],
            isFineRendered: true
        ),

        BodyRegion(
            id: "waist_c",
            displayName: "腰部",
            side: .center,
            category: .waist,
            muscleNames: ["竖脊肌", "腰方肌", "多裂肌"],
            pressPoints: [
                point("pp_waist_shenshu", "肾俞区域", "waist_c"),
                point("pp_waist_dachangshu", "大肠俞区域", "waist_c"),
                point("pp_waist_yaoyan", "腰眼区域", "waist_c"),
            ],
            fatigueScenes: ["久坐后起身时腰部发僵", "长时间弯腰劳作", "长途驾驶或乘车"],
            relaxSuggestions: ["仰卧抱膝轻柔摇摆", "婴儿式放松体位", "腰部热敷，避免久坐超过 1 小时"],
            isFineRendered: true
        ),

        BodyRegion(
            id: "abdomen_c",
            displayName: "腹部",
            side: .center,
            category: .abdomen,
            muscleNames: ["腹直肌", "腹外斜肌", "腹横肌"],
            pressPoints: [
                point("pp_abdomen_zhongwan", "中脘区域", "abdomen_c"),
                point("pp_abdomen_tianshu", "天枢区域", "abdomen_c"),
                point("pp_abdomen_qihai", "气海区域", "abdomen_c"),
            ],
            fatigueScenes: ["核心训练后腹部酸胀", "久坐弓腰、腹部长期收紧", "咳嗽或大笑频繁后腹部用力感"],
            relaxSuggestions: ["仰卧腹式呼吸放松", "轻柔腹部顺时针抚摩", "避免在过饱或空腹时按压"],
            isFineRendered: true
        ),

        BodyRegion(
            id: "thigh_l",
            displayName: "左大腿",
            side: .left,
            category: .thigh,
            muscleNames: ["股四头肌", "腘绳肌", "股内侧肌", "阔筋膜张肌"],
            pressPoints: [
                point("pp_thigh_l_futu", "伏兔区域", "thigh_l"),
                point("pp_thigh_l_fengshi", "风市区域", "thigh_l"),
                point("pp_thigh_l_xuehai", "血海区域", "thigh_l"),
            ],
            fatigueScenes: ["跑步、深蹲等运动后酸胀", "长时间爬山或上下楼梯", "久坐后大腿前侧发紧"],
            relaxSuggestions: ["站姿或侧卧轻柔拉伸大腿前侧", "泡沫轴缓慢滚动放松", "运动后慢走 5–10 分钟缓和"],
            isFineRendered: true
        ),

        BodyRegion(
            id: "thigh_r",
            displayName: "右大腿",
            side: .right,
            category: .thigh,
            muscleNames: ["股四头肌", "腘绳肌", "股内侧肌", "阔筋膜张肌"],
            pressPoints: [
                point("pp_thigh_r_futu", "伏兔区域", "thigh_r"),
                point("pp_thigh_r_fengshi", "风市区域", "thigh_r"),
                point("pp_thigh_r_xuehai", "血海区域", "thigh_r"),
            ],
            fatigueScenes: ["跑步、深蹲等运动后酸胀", "长时间爬山或上下楼梯", "久坐后大腿前侧发紧"],
            relaxSuggestions: ["站姿或侧卧轻柔拉伸大腿前侧", "泡沫轴缓慢滚动放松", "运动后慢走 5–10 分钟缓和"],
            isFineRendered: true
        ),

        BodyRegion(
            id: "calf_l",
            displayName: "左小腿",
            side: .left,
            category: .calf,
            muscleNames: ["腓肠肌", "比目鱼肌", "胫骨前肌"],
            pressPoints: [
                point("pp_calf_l_chengshan", "承山区域", "calf_l"),
                point("pp_calf_l_weizhong", "委中区域", "calf_l"),
                point("pp_calf_l_zusanli", "足三里区域", "calf_l"),
            ],
            fatigueScenes: ["长时间站立或行走后酸胀", "跑步、跳绳后小腿紧绷", "穿高跟鞋时间过长"],
            relaxSuggestions: ["推墙小腿拉伸，每侧保持 20–30 秒", "温水泡脚 10–15 分钟", "休息时垫高小腿"],
            isFineRendered: true
        ),

        BodyRegion(
            id: "calf_r",
            displayName: "右小腿",
            side: .right,
            category: .calf,
            muscleNames: ["腓肠肌", "比目鱼肌", "胫骨前肌"],
            pressPoints: [
                point("pp_calf_r_chengshan", "承山区域", "calf_r"),
                point("pp_calf_r_weizhong", "委中区域", "calf_r"),
                point("pp_calf_r_zusanli", "足三里区域", "calf_r"),
            ],
            fatigueScenes: ["长时间站立或行走后酸胀", "跑步、跳绳后小腿紧绷", "穿高跟鞋时间过长"],
            relaxSuggestions: ["推墙小腿拉伸，每侧保持 20–30 秒", "温水泡脚 10–15 分钟", "休息时垫高小腿"],
            isFineRendered: true
        ),

        BodyRegion(
            id: "knee_l",
            displayName: "左膝",
            side: .left,
            category: .knee,
            muscleNames: ["股四头肌腱", "髌腱", "髂胫束", "腘绳肌下端"],
            pressPoints: [
                point("pp_knee_l_xiyan", "膝眼区域", "knee_l"),
                point("pp_knee_l_yanglingquan", "阳陵泉区域", "knee_l"),
                point("pp_knee_l_xuehai", "血海区域", "knee_l"),
            ],
            fatigueScenes: ["爬山、爬楼梯后膝盖周围发紧", "深蹲或跳跃类运动后", "久坐后起身时膝关节僵硬感"],
            relaxSuggestions: ["坐姿轻柔伸屈膝活动", "膝盖周围轻柔抚摩放松", "运动后冰敷 10 分钟（无明显肿痛时改温热敷）"],
            isFineRendered: true
        ),

        BodyRegion(
            id: "knee_r",
            displayName: "右膝",
            side: .right,
            category: .knee,
            muscleNames: ["股四头肌腱", "髌腱", "髂胫束", "腘绳肌下端"],
            pressPoints: [
                point("pp_knee_r_xiyan", "膝眼区域", "knee_r"),
                point("pp_knee_r_yanglingquan", "阳陵泉区域", "knee_r"),
                point("pp_knee_r_xuehai", "血海区域", "knee_r"),
            ],
            fatigueScenes: ["爬山、爬楼梯后膝盖周围发紧", "深蹲或跳跃类运动后", "久坐后起身时膝关节僵硬感"],
            relaxSuggestions: ["坐姿轻柔伸屈膝活动", "膝盖周围轻柔抚摩放松", "运动后冰敷 10 分钟（无明显肿痛时改温热敷）"],
            isFineRendered: true
        ),

        // MARK: 基础点位区（isFineRendered = false）

        BodyRegion(
            id: "upper_arm_l",
            displayName: "左上臂",
            side: .left,
            category: .upperArm,
            muscleNames: ["肱二头肌", "肱三头肌", "三角肌"],
            pressPoints: [
                point("pp_upper_arm_l_binao", "臂臑区域", "upper_arm_l"),
                point("pp_upper_arm_l_sanjiaoji", "三角肌区域", "upper_arm_l"),
            ],
            fatigueScenes: ["搬运重物或提拉后酸胀", "长时间抱孩子", "投掷、挥拍类运动后"],
            relaxSuggestions: ["对侧手轻柔拿捏上臂肌肉", "手臂自然下垂轻轻甩动放松", "温热水冲淋上臂"],
            isFineRendered: false
        ),

        BodyRegion(
            id: "upper_arm_r",
            displayName: "右上臂",
            side: .right,
            category: .upperArm,
            muscleNames: ["肱二头肌", "肱三头肌", "三角肌"],
            pressPoints: [
                point("pp_upper_arm_r_binao", "臂臑区域", "upper_arm_r"),
                point("pp_upper_arm_r_sanjiaoji", "三角肌区域", "upper_arm_r"),
            ],
            fatigueScenes: ["搬运重物或提拉后酸胀", "长时间抱孩子", "投掷、挥拍类运动后"],
            relaxSuggestions: ["对侧手轻柔拿捏上臂肌肉", "手臂自然下垂轻轻甩动放松", "温热水冲淋上臂"],
            isFineRendered: false
        ),

        BodyRegion(
            id: "forearm_l",
            displayName: "左前臂",
            side: .left,
            category: .forearm,
            muscleNames: ["肱桡肌", "桡侧腕屈肌", "指伸肌群"],
            pressPoints: [
                point("pp_forearm_l_quchi", "曲池区域", "forearm_l"),
                point("pp_forearm_l_shousanli", "手三里区域", "forearm_l"),
                point("pp_forearm_l_hegu", "合谷区域", "forearm_l"),
            ],
            fatigueScenes: ["长时间打字、用鼠标", "拧毛巾、握持工具过久", "网球、羽毛球等挥拍运动后"],
            relaxSuggestions: ["掌心向上轻柔伸展腕指", "对侧拇指沿前臂缓慢按揉", "定时松手、甩腕休息"],
            isFineRendered: false
        ),

        BodyRegion(
            id: "forearm_r",
            displayName: "右前臂",
            side: .right,
            category: .forearm,
            muscleNames: ["肱桡肌", "桡侧腕屈肌", "指伸肌群"],
            pressPoints: [
                point("pp_forearm_r_quchi", "曲池区域", "forearm_r"),
                point("pp_forearm_r_shousanli", "手三里区域", "forearm_r"),
                point("pp_forearm_r_hegu", "合谷区域", "forearm_r"),
            ],
            fatigueScenes: ["长时间打字、用鼠标", "拧毛巾、握持工具过久", "网球、羽毛球等挥拍运动后"],
            relaxSuggestions: ["掌心向上轻柔伸展腕指", "对侧拇指沿前臂缓慢按揉", "定时松手、甩腕休息"],
            isFineRendered: false
        ),

        BodyRegion(
            id: "hip_l",
            displayName: "左髋",
            side: .left,
            category: .hip,
            muscleNames: ["臀大肌", "臀中肌", "梨状肌", "髂腰肌"],
            pressPoints: [
                point("pp_hip_l_huantiao", "环跳区域", "hip_l"),
                point("pp_hip_l_chengfu", "承扶区域", "hip_l"),
            ],
            fatigueScenes: ["久坐后髋部外侧发紧", "长距离步行或跑步后", "跷二郎腿时间过长"],
            relaxSuggestions: ["仰卧四字拉伸（脚踝搭对侧膝上）", "坐姿轻柔转髋活动", "起身走动、避免久坐"],
            isFineRendered: false
        ),

        BodyRegion(
            id: "hip_r",
            displayName: "右髋",
            side: .right,
            category: .hip,
            muscleNames: ["臀大肌", "臀中肌", "梨状肌", "髂腰肌"],
            pressPoints: [
                point("pp_hip_r_huantiao", "环跳区域", "hip_r"),
                point("pp_hip_r_chengfu", "承扶区域", "hip_r"),
            ],
            fatigueScenes: ["久坐后髋部外侧发紧", "长距离步行或跑步后", "跷二郎腿时间过长"],
            relaxSuggestions: ["仰卧四字拉伸（脚踝搭对侧膝上）", "坐姿轻柔转髋活动", "起身走动、避免久坐"],
            isFineRendered: false
        ),

        BodyRegion(
            id: "foot_l",
            displayName: "左足",
            side: .left,
            category: .other,
            muscleNames: ["足底筋膜", "踇展肌", "趾短屈肌"],
            pressPoints: [
                point("pp_foot_l_yongquan", "涌泉区域", "foot_l"),
                point("pp_foot_l_taixi", "太溪区域", "foot_l"),
            ],
            fatigueScenes: ["长时间站立或行走后足底酸胀", "穿硬底鞋时间过长", "登山或长距离徒步后"],
            relaxSuggestions: ["足底踩网球缓慢滚动", "温水泡脚 10–15 分钟", "轻柔扳脚趾做背伸活动"],
            isFineRendered: false
        ),

        BodyRegion(
            id: "foot_r",
            displayName: "右足",
            side: .right,
            category: .other,
            muscleNames: ["足底筋膜", "踇展肌", "趾短屈肌"],
            pressPoints: [
                point("pp_foot_r_yongquan", "涌泉区域", "foot_r"),
                point("pp_foot_r_taixi", "太溪区域", "foot_r"),
            ],
            fatigueScenes: ["长时间站立或行走后足底酸胀", "穿硬底鞋时间过长", "登山或长距离徒步后"],
            relaxSuggestions: ["足底踩网球缓慢滚动", "温水泡脚 10–15 分钟", "轻柔扳脚趾做背伸活动"],
            isFineRendered: false
        ),
    ]
}
