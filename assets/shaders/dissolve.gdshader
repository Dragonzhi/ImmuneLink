shader_type canvas_item;

uniform float progress : hint_range(0.0, 1.0) = 0.0;

// 简单的伪随机噪声函数
// Takes a 2D vector and returns a pseudo-random float between 0.0 and 1.0
float rand(vec2 co){
    return fract(sin(dot(co.xy, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
    // 生成一个噪声值
    float noise = rand(SCREEN_UV);
    
    // 如果噪声值大于当前进度，则丢弃该片元（使其透明）
    if (noise > progress) {
        discard;
    }
    
    // 否则，将其颜色设置为纯黑
    COLOR = vec4(0.0, 0.0, 0.0, 1.0);
}
