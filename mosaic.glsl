extern number pixelSize;
extern vec2 resolution;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    if (pixelSize <= 1.0) {
        return Texel(tex, texture_coords) * color;
    }

    float dx = pixelSize / resolution.x;
    float dy = pixelSize / resolution.y;
    vec2 size = vec2(dx, dy);

    // 把坐标原点移到屏幕中心 (0.5, 0.5)
    vec2 centered_uv = texture_coords - vec2(0.5);
    
    // 基于中心进行量化
    vec2 coord = floor(centered_uv / size) * size;
    
    // 移回原来的坐标系
    coord += vec2(0.5);
    
    // 采样点偏移
    coord += size * 0.5;
    
    return Texel(tex, coord) * color;
}