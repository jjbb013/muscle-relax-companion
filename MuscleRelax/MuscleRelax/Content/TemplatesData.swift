import Foundation

// MARK: - 内置高频放松模板（需求 §6.5）
// 口径：内容为通用身体放松常识整理，供与按摩师沟通使用；非医疗指导。
// 每条模板末尾统一附"非医疗属性"轻提示（需求 §6.5 第 2 条）。

enum TemplatesData {
    /// 统一轻提示后缀（需求 §6.5 / §8.2：非医疗属性声明）
    static let disclaimerSuffix = "（以上为个人身体状态描述，非医疗诊断）"

    static let all: [BuiltinTemplate] = [
        BuiltinTemplate(
            id: "tpl_neck_shoulder_desk",
            name: "久坐肩颈紧绷",
            content: "您好，我最近久坐办公，颈部和肩膀这一带感觉紧绷发硬，低头或转头时更明显，大概持续好几天了。麻烦您帮我重点放松颈部两侧、肩颈连接和肩膀上方的位置，力度中等偏轻，觉得重了我会随时告诉您。" + disclaimerSuffix,
            regionId: "neck_c"
        ),
        BuiltinTemplate(
            id: "tpl_back_desk",
            name: "伏案背部发紧",
            content: "您好，我最近伏案时间比较长，肩胛骨之间和上背部一直觉得发紧、发沉，挺胸伸展时会舒服一些。麻烦您帮我重点放松两侧肩胛骨周围和脊柱两旁的背部肌肉，力度适中，谢谢。" + disclaimerSuffix,
            regionId: "back_c"
        ),
        BuiltinTemplate(
            id: "tpl_waist_fatigue",
            name: "腰部疲劳",
            content: "您好，我的腰部最近比较容易累，久坐之后起身会觉得发僵，弯腰时也有酸胀感。麻烦您帮我放松腰部脊柱两侧和腰眼附近的位置，力度轻柔一些，请不要做大幅度的扳动。" + disclaimerSuffix,
            regionId: "waist_c"
        ),
        BuiltinTemplate(
            id: "tpl_calf_sore",
            name: "小腿酸胀",
            content: "您好，我最近走路和站立比较多，小腿肚子酸胀明显，用手按会有紧绷感，休息一晚后能缓解一些。麻烦您帮我重点放松小腿后侧的腓肠肌和比目鱼肌位置，两侧都要，力度中等即可。" + disclaimerSuffix,
            regionId: "calf_l"
        ),
        BuiltinTemplate(
            id: "tpl_post_exercise",
            name: "运动后肌肉紧绷",
            content: "您好，我前两天做了下肢运动（跑步/深蹲），现在大腿前侧和后侧肌肉都比较紧绷酸胀，上下楼梯时更明显。麻烦您帮我以放松大腿肌肉为主，手法轻一点、节奏慢一点，避开有明显痛感的位置。" + disclaimerSuffix,
            regionId: "thigh_l"
        ),
        BuiltinTemplate(
            id: "tpl_driving_stiff",
            name: "长途驾车腰背僵硬",
            content: "您好，我刚开了长途车，腰部和整个背部都比较僵硬，久坐保持一个姿势后特别明显，下车活动一下会稍微松一些。麻烦您帮我放松腰背脊柱两侧的肌肉，力度适中偏轻，过程中如果我觉得不舒服会马上告诉您。" + disclaimerSuffix,
            regionId: "waist_c"
        ),
        BuiltinTemplate(
            id: "tpl_phone_neck",
            name: "低头族颈部疲劳",
            content: "您好，我平时用手机时间比较长，习惯低头，脖子后面和颈肩交界处经常觉得累、发紧，抬头时会有些僵。麻烦您帮我重点放松颈部后侧和颈肩连接的位置，手法轻柔，不要快速扭动脖子。" + disclaimerSuffix,
            regionId: "neck_c"
        ),
        BuiltinTemplate(
            id: "tpl_foot_standing",
            name: "站立过久足底疲劳",
            content: "您好，我的工作需要长时间站立，一天下来足底和小腿都比较酸胀，足底踩地时感觉发沉。麻烦您帮我放松足底和足弓位置，两侧都需要，力度适中，谢谢。" + disclaimerSuffix,
            regionId: "foot_l"
        ),
        BuiltinTemplate(
            id: "tpl_arm_overuse",
            name: "手臂用力过度酸胀",
            content: "您好，我最近手臂用力比较多（搬东西/抱孩子/运动），上臂和前臂都有酸胀感，握拳和抬臂时能感觉到紧绷。麻烦您帮我放松上臂和前臂的肌肉，力度中等偏轻，肘关节附近请轻一些。" + disclaimerSuffix,
            regionId: "upper_arm_l"
        ),
        BuiltinTemplate(
            id: "tpl_knee_tight",
            name: "膝盖周围紧绷",
            content: "您好，我最近爬楼和走路比较多，膝盖周围一圈感觉紧绷，久坐后起身时膝盖会有点僵。麻烦您帮我放松膝盖上方的大腿前侧和膝盖周围的软组织，不要直接按膝盖骨，力度轻柔。" + disclaimerSuffix,
            regionId: "knee_l"
        ),
    ]
}
