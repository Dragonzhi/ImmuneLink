shader_type canvas_item;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

uniform float pixel_size : hint_range(1.0, 100.0) = 10.0; // 像素块大小

void fragment() {
    // 获取屏幕纹理的UV坐标
    vec2 uv = SCREEN_UV;
    
    // 计算屏幕分辨率
    vec2 screen_pixel_size = 1.0 / SCREEN_PIXEL_SIZE; // SCREEN_PIXEL_SIZE 是单个像素的UV大小
    
    // 将UV坐标转换为像素坐标
    vec2 pixel_coords = uv * screen_pixel_size;
    
    // 对像素坐标进行四舍五入，以实现像素化效果
    // 将像素坐标除以pixel_size，向下取整，然后乘以pixel_size，得到像素块的左上角坐标
    vec2 pixelated_pixel_coords = floor(pixel_coords / pixel_size) * pixel_size;
    
    // 将像素化后的像素坐标转换回UV坐标
    vec2 pixelated_uv = pixelated_pixel_coords / screen_pixel_size;
    
    // 从像素化后的UV坐标采样纹理颜色
    COLOR = texture(SCREEN_TEXTURE, pixelated_uv);
}
