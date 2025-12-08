// crt.glsl

extern number time;        // 游戏运行时间
extern vec2 inputSize;     // 虚拟分辨率 (VIRTUAL_WIDTH, VIRTUAL_HEIGHT)

// 桶形畸变函数
vec2 curve(vec2 uv)
{
    uv = (uv - 0.5) * 2.0;
    uv *= 1.1;	
    uv.x *= 1.0 + pow((abs(uv.y) / 5.0), 2.0);
    uv.y *= 1.0 + pow((abs(uv.x) / 4.0), 2.0);
    uv  = (uv / 2.0) + 0.5;
    uv =  uv * 0.92 + 0.04;
    return uv;
}

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
    vec2 q = texture_coords;
    vec2 uv = q;
    
    // 应用屏幕弯曲
    uv = curve(uv);
    
    // 计算色差偏移量 (RGB Split)
    float x = sin(0.3 * time + uv.y * 21.0) * sin(0.7 * time + uv.y * 29.0) * sin(0.3 + 0.33 * time + uv.y * 31.0) * 0.0005;

    vec3 col;

    col.r = Texel(tex, vec2(x + uv.x + 0.0005, uv.y + 0.0005)).r + 0.05;
    col.g = Texel(tex, vec2(x + uv.x + 0.0000, uv.y - 0.0010)).g + 0.05;
    col.b = Texel(tex, vec2(x + uv.x - 0.0010, uv.y + 0.0000)).b + 0.05;

    // 添加残影 (Ghosting)
    col.r += 0.02 * Texel(tex, 0.75 * vec2(x + 0.025, -0.027) + vec2(uv.x + 0.001, uv.y + 0.001)).r;
    col.g += 0.01 * Texel(tex, 0.75 * vec2(x - 0.022, -0.02)  + vec2(uv.x + 0.000, uv.y - 0.002)).g;
    col.b += 0.02 * Texel(tex, 0.75 * vec2(x - 0.02,  -0.018) + vec2(uv.x - 0.002, uv.y + 0.000)).b;

    // 对比度增强
    col = clamp(col * 0.6 + 0.4 * col * col * 1.0, 0.0, 1.0);

    // 暗角 (Vignette)
    float vig = (0.0 + 1.0 * 16.0 * uv.x * uv.y * (1.0 - uv.x) * (1.0 - uv.y));
    col *= vec3(pow(vig, 0.3));

    // 整体变亮一点
    col *= vec3(0.95, 1.05, 0.95);
    col *= 2.8;

    // 扫描线 (Scanlines)
    // 使用 inputSize.y (虚拟高度) 来计算扫描线密度
    float scans = clamp(0.35 + 0.35 * sin(2 * time + uv.y * inputSize.y * 1), 0.0, 1.0);
    float s = pow(scans, 1.7);
    col = col * vec3(0.6 + 0.4 * s);

    // 屏幕闪烁 (Flicker)
    col *= 1.0 + 0.01 * sin(110.0 * time);

    // 黑边裁剪 (去掉畸变产生的边缘拉伸)
    if (uv.x < 0.0 || uv.x > 1.0) col *= 0.0;
    if (uv.y < 0.0 || uv.y > 1.0) col *= 0.0;
    
    // 像素网格掩码 (Phosphor Mask)
    // 使用 screen_coords (真实屏幕像素坐标)
    col *= 1.0 - 0.65 * vec3(clamp((mod(screen_coords.x, 2.0) - 1.0) * 2.0, 0.0, 1.0));

    // 输出最终颜色
    return vec4(col, 1.0);
}