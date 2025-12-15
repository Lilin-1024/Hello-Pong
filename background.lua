
local Background = {}

Background.BALL_COUNT = 15       -- 球的数量
Background.BG_COLOR = {20/255, 20/255, 35/255, 1} -- 底色 (深色)
Background.BALL_COLOR = {1, 1, 1} -- 球的颜色

local balls = {}

function Background.load()
    balls = {} -- 清空

    for i = 1, Background.BALL_COUNT do
        table.insert(balls, {
            -- 随机位置
            x = math.random(10, VIRTUAL_WIDTH - 10),
            y = math.random(10, VIRTUAL_HEIGHT - 10),

            -- 随机半径 
            radius = math.random(2, 3),

            -- 随机速度向量
            dx = math.random(-40, 40),
            dy = math.random(-40, 40),

            -- 样式
            style = math.random() > 0.5 and 'line' or 'fill',
            --style = 'fill',

            -- 呼吸灯计时器
            timer = math.random(0, 10)
        })
    end
end

function Background.update(dt)
    for _, ball in ipairs(balls) do
        -- 移动
        ball.x = ball.x + ball.dx * dt
        ball.y = ball.y + ball.dy * dt

        -- 呼吸计时器更新
        ball.timer = ball.timer + dt

        -- 3. 边界反弹逻辑

        if ball.x < 0 then
            ball.x = 0
            ball.dx = -ball.dx
        elseif ball.x > VIRTUAL_WIDTH then
            ball.x = VIRTUAL_WIDTH
            ball.dx = -ball.dx
        end

        if ball.y < 0 then
            ball.y = 0
            ball.dy = -ball.dy
        elseif ball.y > VIRTUAL_HEIGHT then
            ball.y = VIRTUAL_HEIGHT
            ball.dy = -ball.dy
        end
    end
end

function Background.draw(bgColor, ballColor)

    local bg = bgColor or {20/255, 20/255, 35/255, 1}
    love.graphics.clear(bg)

    -- 画中线

    local fg = ballColor or {1, 1, 1, 1}
    love.graphics.setColor(fg[1], fg[2], fg[3], 0.05)
    love.graphics.setLineWidth(2)
    love.graphics.line(VIRTUAL_WIDTH / 2, 0, VIRTUAL_WIDTH / 2, VIRTUAL_HEIGHT)

    -- 2. 画球
    for _, ball in ipairs(balls) do
        local alpha = 0.1 + 0.2 * math.abs(math.sin(ball.timer * 0.8))

        love.graphics.setColor(fg[1], fg[2], fg[3], alpha)

        love.graphics.setLineWidth(1)
        love.graphics.rectangle(ball.style, ball.x - ball.radius, ball.y - ball.radius, ball.radius * 2, ball.radius * 2)
    end

    -- 3. 重置颜色
    love.graphics.setColor(1, 1, 1, 1)
end

return Background