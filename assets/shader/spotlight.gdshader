// Spotlight shader
shader_type canvas_item;

// 遮罩层的背景色
uniform vec4 bg_color : source_color = vec4(0.0, 0.0, 0.0, 0.7);

// "洞"的中心位置 (UV坐标, 0-1)
uniform vec2 hole_center = vec2(0.5, 0.5);
// "洞"的大小 (UV坐标, 0-1)
uniform vec2 hole_size = vec2(0.2, 0.2);
// 边缘的柔和度/羽化程度 (UV坐标)
uniform float edge_softness : hint_range(0.0, 0.5) = 0.05;


void fragment() {
    // 计算当前像素到"洞"中心的距离（按维度）
    // abs(UV - hole_center) 得到一个向量，其x,y分量分别是水平和垂直方向上到洞中心的距离
    // / hole_size 将距离归一化，这样洞内的点，其结果向量的分量应该小于0.5
    vec2 dist = abs(UV - hole_center) / hole_size;

    // smoothstep(edge1, edge2, x) 是一个平滑阶跃函数
    // 当 x < edge1 时，返回0
    // 当 x > edge2 时，返回1
    // 当 edge1 < x < edge2 时，返回0到1之间的平滑插值

    // 我们希望洞的边缘是平滑的。
    // 0.5 - edge_softness 是内边界
    // 0.5 是外边界
    // max(dist.x, dist.y) 获取水平和垂直距离中较大的一个，这定义了一个矩形区域
    float outside_factor = smoothstep(0.5 - edge_softness, 0.5, max(dist.x, dist.y));
    
    // outside_factor 的值：
    // 在洞内部（且远离边缘）时，为 0
    // 在洞外部时，为 1
    // 在洞的边缘时，从 0 平滑过渡到 1

    // 使用 mix 函数进行混合
    // 当 outside_factor = 0 时，颜色为完全透明 (vec4(0.0))
    // 当 outside_factor = 1 时，颜色为背景色 (bg_color)
    COLOR = mix(vec4(0.0), bg_color, outside_factor);
}
