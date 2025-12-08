---@diagnostic disable: lowercase-global
Class = require "class"
push = require "push"

require "Ball"
require "Paddle"

WINDOW_WIDTH = 1280
WINDOW_HEIGHT = 720

VIRTUAL_WIDTH = 432
VIRTUAL_HEIGHT = 243

PADDLE_SPEED = 50

local MAX_BALL_SPEED_X = 550 -- 略微降低最大速度上限
local MAX_BALL_SPEED_Y = 400
local FRICTION_COEF = 0.25   -- 降低Y轴切球的摩擦系数 (原0.35)

-- 动能传递系数：原0.4 -> 现0.15
-- 冲刺(250) * 0.15 = 37.5 (原来是100)
-- 加上基础反弹，这个增幅已经足够产生战术差异，但不会秒杀
local MOMENTUM_TRANSFER = 0.15

menuItems = {
    "Players",
    "Win Score",
    "Free Mode",
    "AutoServe",
    "Music"
}


function love.load()
    math.randomseed(os.time())

    love.graphics.setDefaultFilter("nearest", "nearest")

    love.window.setTitle('Pong')

    instructFont = love.graphics.newFont("fonts/ari_w9500/ari-w9500.ttf", 11)

    smallFont = love.graphics.newFont("fonts/font.ttf", 8)

    largeFont = love.graphics.newFont("fonts/font.ttf", 32)

    titleFont = love.graphics.newFont("fonts/ari_w9500/ari-w9500-condensed-display.ttf", 32)

    scoreFont = love.graphics.newFont("fonts/font.ttf", 32)

    victoryFont = love.graphics.newFont("fonts/font.ttf", 24)

    sounds = {
        ['paddle_hit'] = love.audio.newSource('sounds/paddle_hit.wav','static'),
        ['score']=love.audio.newSource('sounds/score.wav','static'),
        ['wall_hit']=love.audio.newSource('sounds/wall_hit.wav','static'),
        ['dash']=love.audio.newSource('sounds/dash.wav','static'),
        ['select']=love.audio.newSource('sounds/select.wav','static'),
        ['music_track1']=love.audio.newSource('sounds/track1.mp3','static'),
        ['music_track2']=love.audio.newSource('sounds/LuckyStar2.wav','static'),
        ['music_track3']=love.audio.newSource('sounds/LuckyStar1.wav','static'),
    }

    --initialization
    player1Score = 0
    player2Score = 0

    combo = 0
    winningPlayer = 0

    serveTimer = 3

        -- 震动系统变量
    shakeTimer = 0
    shakeMagnitude = 0

    servingPlayer = math.random(2) == 1 and 1 or 2

    paddle1 = Paddle(5, math.random(20,230), 5, 20)
    paddle2 = Paddle(VIRTUAL_WIDTH - 10, math.random(20,230), 5, 20)
    ball = Ball(VIRTUAL_WIDTH / 2 - 2, VIRTUAL_HEIGHT / 2 - 2, 5, 5)

    --menu initialization
    gameState = 'menu'
    selectedItem = 1
    playersConfig = 2
    winScore = 5
    freeModeSet = 1
    autoServeSet = 1

    if servingPlayer == 1 then
        ball.dx = 100
    else
        ball.dx = -100
    end

    loadMusicMenu()

    crtShader = love.graphics.newShader('crt.glsl')
    
    -- 2. 发送分辨率给 Shader (用于计算扫描线密度)
    -- 注意：这里必须传你的 VIRTUAL 宽高，不是 WINDOW 宽高
    crtShader:send('inputSize', {VIRTUAL_WIDTH, VIRTUAL_HEIGHT})
    
    -- 3. 初始化时间变量
    shaderTimer = 0

    push:setupScreen(
        VIRTUAL_WIDTH,
        VIRTUAL_HEIGHT,
        WINDOW_WIDTH,
        WINDOW_HEIGHT,
        {
            fullscreen = false,
            resizable = true,
            vsync = true
        }
    )
end

function love.resize(w,h)
    push:resize(w,h)
end

function love.update(dt)

    ballCollision()

    paddle1:update(dt)
    paddle2:update(dt)

    if love.keyboard.isDown('lshift') then
        paddle1:attemptSprint()
    end

    if playersConfig == 2 then
        if love.keyboard.isDown('rshift') then
            paddle2:attemptSprint()
        end
    end

    playerMovement()

    --score
    scoreUpdate(dt)

    if gameState == 'music_select' then
        updateMusicMenu(dt)
    end

    if shakeTimer > 0 then
        shakeTimer = shakeTimer - dt
        -- 让震动幅度随时间变小 (Lerp)
        -- 这样震动会越来越弱，直到消失，手感更好
        shakeMagnitude = math.max(0, shakeMagnitude - 10 * dt)
    end

    shaderTimer = shaderTimer + dt
    crtShader:send('time', shaderTimer)
end


-- state switch
function love.keypressed(key)

    pressAudio(key)

    menuPress(key)
end

function love.draw()
    push:start()

    love.graphics.clear(10/255, 10/255, 10/255, 1)
    if musicMenu.selection == 2 then
        love.graphics.clear(255/255, 255/255, 255/255, 1)
    end

    if musicMenu.selection == 3 then
        love.graphics.clear(104/255, 145/255, 227/255, 1)
    end

    drawShake()


    if gameState =='menu' then
        drawMenu()
    elseif gameState == 'submenu_players' then
        drawPlayersSettings()
    elseif gameState == 'submenu_WinScore' then
        drawWinScore()
    elseif gameState == 'submenu_FreeMode' then
        drawFreeMode()
    elseif gameState == 'submenu_autoServe' then
        drawServeSet()
    elseif gameState == 'music_select' then
        drawMusicMenu()
    elseif gameState == 'play' or gameState == 'serve' or gameState == 'victory' then
        drawGame()
    end

    push:finish(crtShader)
end

function ballCollision()

    handleCollision(ball, paddle1) -- compare x and y collision
    handleCollision(ball, paddle2)

    if ball.y <= 0 then
        ball.dy = -ball.dy
        ball.y = 0

        sounds['wall_hit']:play()
    end
    
    if ball.y >= VIRTUAL_HEIGHT - 4 then
        ball.dy = -ball.dy
        ball.y = VIRTUAL_HEIGHT - 4

        sounds['wall_hit']:play()
    end

    local ballMaxSpeed = 900
    if ball.dx > ballMaxSpeed then
        ball.dx = ballMaxSpeed
    elseif ball.dx < -ballMaxSpeed then
        ball.dx = -ballMaxSpeed
    end
end

function handleCollision(ball, paddle)
    if ball:collides(paddle) then
        sounds['paddle_hit']:play()
        combo = combo + 1
        startShake(0.4, math.abs(paddle.dx)/30) -- 震动稍微减弱一点

        -- === 1. 计算 X 轴新速度 ===
        local currentSpeedX = math.abs(ball.dx)
        local paddleSpeedX = math.abs(paddle.dx)
        
        -- 【改动点】计算增加的速度
        local addedSpeed = paddleSpeedX * MOMENTUM_TRANSFER
        
        -- 【平衡核心】：如果球本身已经很快了，就很难再加速
        -- 这是一个简单的线性衰减：球速越接近 MAX，获得的加速收益越低
        if currentSpeedX > 300 then
            addedSpeed = addedSpeed * 0.5
        end

        -- 基础反弹倍率从 1.05 降到 1.02 (避免普通对拉时球速涨太快)
        local newSpeedX = (currentSpeedX + addedSpeed) * 1.02
        
        -- 绝对硬上限
        if newSpeedX > MAX_BALL_SPEED_X then newSpeedX = MAX_BALL_SPEED_X end

        -- ... (中间的碰撞位置计算代码 ball_center_x 等等保持不变) ...
        local ball_center_x = ball.x + ball.width / 2
        local ball_center_y = ball.y + ball.height / 2
        local paddle_center_x = paddle.x + paddle.width / 2
        local paddle_center_y = paddle.y + paddle.height / 2
        local delta_x = ball_center_x - paddle_center_x
        local delta_y = ball_center_y - paddle_center_y
        local min_dist_x = ball.width / 2 + paddle.width / 2
        local min_dist_y = ball.height / 2 + paddle.height / 2
        local depth_x = min_dist_x - math.abs(delta_x)
        local depth_y = min_dist_y - math.abs(delta_y)

        if depth_x < depth_y then
            -- 【侧面碰撞】
            
            -- === 2. Y 轴摩擦力 (削弱) ===
            ball.dy = ball.dy + paddle.dy * FRICTION_COEF
            
            -- 限制 Y 轴
            if ball.dy > MAX_BALL_SPEED_Y then ball.dy = MAX_BALL_SPEED_Y end
            if ball.dy < -MAX_BALL_SPEED_Y then ball.dy = -MAX_BALL_SPEED_Y end

            if delta_x < 0 then
                ball.x = paddle.x - ball.width
                ball.dx = -newSpeedX
            else
                ball.x = paddle.x + paddle.width
                ball.dx = newSpeedX
            end
        else
            -- 【顶部/底部碰撞】
            if delta_y < 0 then
                ball.y = paddle.y - ball.height
                ball.dy = -math.abs(ball.dy) * 1.02 -- 这里也降到 1.02
            else
                ball.y = paddle.y + paddle.height
                ball.dy = math.abs(ball.dy) * 1.02
            end
        end
    end
end

function drawMenuOptions()
    love.graphics.setFont(instructFont)

    local startX = 70
    local y = 165
    local spacing = 80

    for i, item in ipairs(menuItems) do
        if i == 5 then

            local x = VIRTUAL_WIDTH - 50
            local y2 = VIRTUAL_HEIGHT - 30

            if selectedItem == 5 then
                love.graphics.setColor(1, 1, 0)
            else
                love.graphics.setColor(1, 1, 1)

                colorChange(2,3,74,166,65)

            end

            love.graphics.print(item, x, y2)

        else
            -- 1~4 
            local x = startX + (i - 1) * spacing

            if selectedItem == i then
                love.graphics.setColor(1, 1, 0)
            else
                love.graphics.setColor(1, 1, 1)

                colorChange(2,3,74,166,65)
            end

            love.graphics.print(item, x, y)
        end
    end

    love.graphics.setColor(1, 1, 1)
    colorChange(2,3,74,166,65)

end

function drawMenu()
        local offsetY = math.sin(love.timer.getTime() * 3) * 3

        love.graphics.setFont(titleFont)
        
        -- 1. 先画阴影 (黑色，位置固定，或者只有微小的浮动)
        love.graphics.setColor(0, 0, 0, 0.1) -- 半透明黑色
        
        love.graphics.printf("100% Hello Pong!", 2, 44 + offsetY, VIRTUAL_WIDTH, 'center') 
        -- offsetY * 0.2 让阴影也动一点点，模拟光照距离变化
        
        -- 2. 再画本体 (白色，大幅度浮动)
        love.graphics.setColor(1, 1, 1, 1) -- 改回白色

        colorChange(2,3,74,166,65)
        
        love.graphics.printf("100% Hello Pong!", 0, 40 + offsetY, VIRTUAL_WIDTH, 'center')

        ---

        love.graphics.setColor(1, 1, 1, 0.8)

        colorChange(2,3,74,166,65)
        
        love.graphics.setFont(smallFont)
        love.graphics.printf("< Use <- -> to navigate and Z to select >", 0, 95, VIRTUAL_WIDTH, "center")
        love.graphics.setColor(1, 1, 1, 1)

        colorChange(2,3,74,166,65)
        

        love.graphics.setFont(smallFont)
        love.graphics.printf("-- press enter to start --", 0, 110, VIRTUAL_WIDTH, "center")

        --option
        drawMenuOptions()
end

function drawGame()
    love.graphics.setFont(smallFont)

    love.graphics.print('Combo: '..tostring(combo),360,30)

    if gameState == 'serve' then
        colorChange(2,3,74,166,65)
        

        love.graphics.printf('Player'..tostring(servingPlayer).."'s turn!",0,20,VIRTUAL_WIDTH,'center')

        if autoServeSet == 1 then
            local secondsLeft = math.ceil(serveTimer)
            if secondsLeft < 1 then secondsLeft = 1 end

            -- 【修改点 1：让它一开始变得更大】
            -- 原来是 * 0.5，现在改成 * 2.0 甚至更大
            -- 逻辑：(serveTimer % 1) 是 0.99，乘以 2.0 等于 1.98
            -- 最终 zoom = 1 + 1.98 ≈ 3倍大小
            local zoom = 1 + (serveTimer % 1) * 1

            love.graphics.setFont(largeFont)
            local text = tostring(secondsLeft)
            local textW = largeFont:getWidth(text)
            local textH = largeFont:getHeight()

            -- 【修改点 2：位置上移】
            -- VIRTUAL_HEIGHT / 2 是正中心
            -- 减去 50 (或者更多) 就会往上跑
            local drawY = VIRTUAL_HEIGHT / 2 - 50

            love.graphics.print(text, 
                VIRTUAL_WIDTH / 2,  -- X轴还在中间
                drawY,              -- Y轴往上移了
                0,
                zoom, zoom, 
                textW / 2, textH / 2)
            
            love.graphics.setFont(smallFont)
        else
            love.graphics.printf('Press Enter to Serve!', 0, 32, VIRTUAL_WIDTH, 'center')
        end

    elseif gameState == 'victory' then
        love.graphics.setFont(victoryFont)
        love.graphics.printf('Player'..tostring(winningPlayer).." wins!",0,10,VIRTUAL_WIDTH,'center')
        love.graphics.setFont(smallFont)
        love.graphics.printf('Press Enter to Restart!',0,42,VIRTUAL_WIDTH,'center')
    end

    if gameState == 'serve' or gameState == 'play' or gameState == 'victory' then
        colorChange(2,3,74,166,65)
        
        love.graphics.setFont(scoreFont)
        love.graphics.print(player1Score,VIRTUAL_WIDTH / 2 - 50, VIRTUAL_HEIGHT / 3)
        love.graphics.print(player2Score,VIRTUAL_WIDTH / 2 + 30, VIRTUAL_HEIGHT / 3)

        paddle1:render()
        paddle2:render()

        ball:render()
    end
end

function drawPlayersSettings()
    love.graphics.setColor(1,1,1,1)

    colorChange(2,3,74,166,65)
    

    love.graphics.setFont(instructFont)

    love.graphics.printf("Select Players", 0, 40, VIRTUAL_WIDTH, "center")

    local text = "Players : " .. tostring(playersConfig)
    
    love.graphics.printf(text, 0, 120, VIRTUAL_WIDTH, "center")

    love.graphics.setColor(1, 1, 1, 0.8)

    colorChange(2,3,74,166,65)
    

    love.graphics.setFont(smallFont)
    love.graphics.printf("< Use <- -> to change and Z to confirm >", 0, VIRTUAL_HEIGHT - 40, VIRTUAL_WIDTH, "center")
end

function drawWinScore()
    love.graphics.setColor(1,1,1,1)
    love.graphics.setFont(instructFont)

    colorChange(2,3,74,166,65)
    

    love.graphics.printf("Set the Win Score", 0, 40, VIRTUAL_WIDTH, "center")

    local text = "Win Scores : " .. tostring(winScore)

    love.graphics.printf(text, 0, 120, VIRTUAL_WIDTH, "center")

    love.graphics.setColor(1, 1, 1, 0.8)

    colorChange(2,3,74,166,65)
    
    love.graphics.setFont(smallFont)
    love.graphics.printf("< Use <- -> to adjust and Z to confirm >", 0, VIRTUAL_HEIGHT - 40, VIRTUAL_WIDTH, "center")
end

function drawFreeMode()
    love.graphics.setColor(1,1,1,1)
    love.graphics.setFont(instructFont)
    colorChange(2,3,74,166,65)
    

    love.graphics.printf("Enable the Free Mode", 0, 40, VIRTUAL_WIDTH, "center")

    local text

    if freeModeSet == 0 then
        text = "Free Mode : OFF"
    elseif freeModeSet == 1 then
        text = "Free Mode : ON"
    end

    love.graphics.printf(text, 0, 120, VIRTUAL_WIDTH, "center")

    love.graphics.setColor(1, 1, 1, 0.8)

    colorChange(2,3,74,166,65)
    
    love.graphics.setFont(smallFont)
    love.graphics.printf("< Use <- -> to adjust and Z to confirm >", 0, VIRTUAL_HEIGHT - 40, VIRTUAL_WIDTH, "center")
end

function drawServeSet()
    love.graphics.setColor(1,1,1,1)
    love.graphics.setFont(instructFont)

    colorChange(2,3,74,166,65)
    

    love.graphics.printf("Enable Auto Serve", 0, 40, VIRTUAL_WIDTH, "center")

    local text

    if autoServeSet == 0 then
        text = "Auto Serve : OFF"
    elseif autoServeSet == 1 then
        text = "Auto Serve: ON"
    end

    love.graphics.printf(text, 0, 120, VIRTUAL_WIDTH, "center")

    love.graphics.setColor(1, 1, 1, 0.8)

    colorChange(2,3,74,166,65)
    

    love.graphics.setFont(smallFont)
    love.graphics.printf("< Use <- -> to adjust and Z to confirm >", 0, VIRTUAL_HEIGHT - 40, VIRTUAL_WIDTH, "center")
end

function lerp(a, b, t)
    return a + (b - a) * t
end

-- 专辑数据初始化
function loadMusicMenu()
    musicMenu = {
        selection = 1, -- 当前选第几个
        timer = 0,     -- 用于计算浮动的时间
        spacing = 110, -- 两个专辑之间的间距 (像素)
        
        -- 这里定义你的专辑列表
        items = {
            {
                name = "Default",
                cover = love.graphics.newImage('sprites/cover1.png'), -- 替换你的图片路径
                music = sounds['music_track1'], -- 替换你的音乐变量
                -- 下面是用于动画的动态变量
                x = VIRTUAL_WIDTH / 2,
                y = VIRTUAL_HEIGHT / 2,
                scale = 1,
                alpha = 1
            },
            {
                name = "LuckyStar!!!",
                cover = love.graphics.newImage('sprites/cover2.png'),
                music = sounds['music_track2'],
                x = VIRTUAL_WIDTH / 2 + 110, -- 初始位置稍微错开一点
                y = VIRTUAL_HEIGHT / 2,
                scale = 0.8,
                alpha = 0.5
            },
            {
                name = "LuckyStar!!!",
                cover = love.graphics.newImage('sprites/cover3.png'),
                music = sounds['music_track3'],
                x = VIRTUAL_WIDTH / 2 + 220,
                y = VIRTUAL_HEIGHT / 2,
                scale = 0.8,
                alpha = 0.5
            }
        }
    }

    -- 播放默认第一首
    playSelectedMusic()
end

function playSelectedMusic()
    -- 先停止所有音乐（或者停止上一首）
    for _, item in ipairs(musicMenu.items) do
        item.music:stop()
    end
    -- 播放选中的
    local current = musicMenu.items[musicMenu.selection]
    current.music:setLooping(true)
    current.music:play()
end

function updateMusicMenu(dt)
    local menu = musicMenu
    menu.timer = menu.timer + dt * 2 -- 控制浮动速度

    for i, item in ipairs(menu.items) do
        -- 1. 计算目标位置
        -- spacing 设为 110 (因为没有倾斜了，宽一点好看)
        local targetX = VIRTUAL_WIDTH / 2 + (i - menu.selection) * 110
        
        -- 2. 平滑移动 (Lerp X)
        item.x = lerp(item.x, targetX, 10 * dt)
        
        -- 3. 上下浮动 (Sine Wave Y)
        local baseY = VIRTUAL_HEIGHT / 2 
        -- i * 0.8 是相位差，让它们像波浪一样起伏，而不是一起动
        local floatOffset = math.sin(menu.timer + i * 0.8) * 5 
        item.y = baseY + floatOffset

        -- 4. 缩放和亮度目标
        local targetScale = 0.8 -- 没选中的大小
        local targetAlpha = 0.4 -- 没选中的亮度 (灰色)
        
        if i == menu.selection then
            targetScale = 1.2 -- 选中的放大 (1.2倍)
            targetAlpha = 1.0 -- 选中的全亮
        end
        
        -- 5. 平滑应用缩放和亮度
        item.scale = lerp(item.scale, targetScale, 10 * dt)
        item.alpha = lerp(item.alpha, targetAlpha, 10 * dt)
    end
end

function musicMenuKeyPressed(key)
    if key == 'left' or key == 'a' then
        if musicMenu.selection > 1 then
            musicMenu.selection = musicMenu.selection - 1
            sounds['select']:play() -- 播放音效
            playSelectedMusic()
        end
    elseif key == 'right' or key == 'd' then
        if musicMenu.selection < #musicMenu.items then
            musicMenu.selection = musicMenu.selection + 1
            sounds['select']:play()
            playSelectedMusic()
        end
    elseif key == 'return' or key == 'z' then
        -- 确认选择，进入游戏
        gameState = 'menu' -- 或你定义的其他状态
    end
end

function drawMusicMenu()
    -- 背景色：迈阿密风格通常偏深色，比如深紫/深蓝，让封面弹出来
    love.graphics.clear(20/255, 20/255, 30/255, 1) 

    local menu = musicMenu

    for i, item in ipairs(menu.items) do
        -- 1. 设置透明度：根据 item.alpha (在update里计算好的)
        love.graphics.setColor(item.alpha, item.alpha, item.alpha, 1)

        -- 2. 设置原点为图片中心 (假设你已经把图片处理成 80x80 了)
        -- 如果没处理好，可以用 item.cover:getWidth()/2
        local ox = item.cover:getWidth() / 2
        local oy = item.cover:getHeight() / 2
        
        -- 3. 绘制图片 (没有倾斜参数)
        love.graphics.draw(
            item.cover, 
            item.x, 
            item.y, 
            0,          -- 旋转角度 (0表示正立)
            item.scale, -- X轴缩放
            item.scale, -- Y轴缩放
            ox, oy      -- 原点
        )
        
        -- 4. 绘制标题 (只有选中的显示)
        if i == menu.selection then
             love.graphics.setColor(1, 1, 1, 1) -- 字体纯白
             -- 字体位置：在专辑下方 50 像素处
             love.graphics.printf(item.name, 0, item.y + 50, VIRTUAL_WIDTH, 'center')
        end
    end
    
    -- 重置颜色
    love.graphics.setColor(1, 1, 1, 1)

    colorChange(2,3,74,166,65)
    
    
    -- 简单的操作提示
    love.graphics.setFont(smallFont) -- 记得确保你定义了字体，没有就删掉这行
    love.graphics.printf("SELECT ALBUM", 0, 20, VIRTUAL_WIDTH, 'center')
end

function playerMovement()
    if love.keyboard.isDown{'w'} then
        paddle1.dy = -PADDLE_SPEED
    elseif love.keyboard.isDown{'s'} then
        paddle1.dy = PADDLE_SPEED
    else
        paddle1.dy = 0
    end

    --p1 freeMode
    if freeModeSet == 1 then
        if love.keyboard.isDown{'a'} then
            paddle1.dx = -PADDLE_SPEED
        elseif love.keyboard.isDown{'d'} then
            paddle1.dx = PADDLE_SPEED
        else
            paddle1.dx = 0
        end
        
        if paddle1.x >= VIRTUAL_WIDTH / 3 -paddle1.width then
            paddle1.x = VIRTUAL_WIDTH / 3 -paddle1.width
        end
    end

    --player2 movement

    if playersConfig == 2 then
        if love.keyboard.isDown{'up'} then
        paddle2.dy = -PADDLE_SPEED
        elseif love.keyboard.isDown{'down'} then
            paddle2.dy = PADDLE_SPEED
        else
            paddle2.dy = 0
        end
        --p2 freeMode
        if freeModeSet == 1 then
            if love.keyboard.isDown{'left'} then
                paddle2.dx = -PADDLE_SPEED
            elseif love.keyboard.isDown{'right'} then
                paddle2.dx = PADDLE_SPEED
            else
                paddle2.dx = 0
            end
            
            if paddle2.x <= VIRTUAL_WIDTH / 3 * 2 then
                paddle2.x = VIRTUAL_WIDTH / 3 * 2
            end
        end

    elseif playersConfig == 1 then
        --AI--
        paddle2.x = VIRTUAL_WIDTH - 10
        if ball.dx > 0 then
            local diff = ball.y - paddle2.y - paddle2.height / 2
            paddle2.dy = diff * 10
        else
            paddle2.dy = 0
        end

        local maxSpeed = 180
        if paddle2.dy > maxSpeed then paddle2.dy = maxSpeed end
        if paddle2.dy < -maxSpeed then paddle2.dy = -maxSpeed end
    end
end

function scoreUpdate(dt)

    if gameState == 'serve' then
        if autoServeSet == 1 then
            serveTimer = serveTimer - dt
            if serveTimer < 0 then
                gameState = 'play'
                combo = 0
                serveTimer = 3
            end
        end
    end

    if gameState == "play" then
        ball:update(dt)
        if ball.x < 0 then
            player2Score = player2Score + 1
            ball:reset()
            servingPlayer = 1
            ball.dx = 100

            sounds['score']:play()

            if player2Score == winScore then
                gameState = 'victory'
                winningPlayer = 2
            else
                gameState = 'serve'
                serveTimer = 3
            end
        end

        if ball.x > VIRTUAL_WIDTH - 4 then
            player1Score = player1Score + 1
            ball:reset()
            servingPlayer = 2
            ball.dx = -100
            gameState = 'serve'
            sounds['score']:play()
            if player1Score == winScore then
                gameState = 'victory'
                winningPlayer = 1
            else
                gameState = 'serve'
                serveTimer = 3
            end
        end
    end
end

function pressAudio(key)
    if gameState~='serve' and gameState~='play' and gameState~='victory' then
        if key == 'right' or key == 'left' or key == 'z' then
            sounds['select']:stop()
            sounds['select']:play()
        end
    end
end

function menuPress(key)
    if gameState == "menu" then
        if key == "right" then
            selectedItem = selectedItem + 1
            if selectedItem > 5 then
                selectedItem = 1
            end
        elseif key == "left" then
            selectedItem = selectedItem - 1
            if selectedItem < 1 then
                selectedItem = 5
            end
        elseif key == 'z' then
            --submenu set
            local item = menuItems[selectedItem]
            if item == 'Players' then
                gameState = 'submenu_players'
            elseif item == 'Win Score' then
                gameState = 'submenu_WinScore'
            elseif item == 'Free Mode' then
                gameState = 'submenu_FreeMode'
            elseif item == 'AutoServe' then
                gameState = 'submenu_autoServe'
            elseif item == 'Music' then
                gameState = 'music_select'
            end
        elseif key == 'enter' or key == 'return' then
            gameState = 'serve'
        elseif key == "escape" then
            love.event.quit()
        end

    elseif gameState == 'submenu_players' then
        --submenu press
        if key == 'left' then
            playersConfig = playersConfig - 1
        elseif key == 'right' then
            playersConfig = playersConfig + 1
        elseif key == 'z' or key == 'enter' or key == 'return' or key == 'escape' then
            gameState = 'menu'
        end

        if playersConfig > 2 then
            playersConfig = 1
        elseif playersConfig < 1 then
            playersConfig = 2
        end
    elseif gameState == 'submenu_WinScore' then
        --submenu press
        if key == 'left' then
            winScore = winScore - 1
        elseif key == 'right' then
            winScore = winScore + 1
        elseif key == 'z' or key == 'enter' or key == 'return' or key == 'escape' then
            gameState = 'menu'
        end
        if winScore > 7 then
            winScore = 1
        elseif winScore < 1 then
            winScore = 7
        end
    elseif gameState == 'submenu_FreeMode' then
        --submenu press
        if key == 'left' then
            freeModeSet = freeModeSet - 1
        elseif key == 'right' then
            freeModeSet = freeModeSet + 1
        elseif key == 'z' or key == 'enter' or key == 'return' or key == 'escape' then
            gameState = 'menu'
        end
        if freeModeSet > 1 then
            freeModeSet = 0
        elseif freeModeSet < 0 then
            freeModeSet = 1
        end
    elseif gameState == 'submenu_autoServe' then
        --submenu press
        if key == 'left' then
            autoServeSet = autoServeSet - 1
        elseif key == 'right' then
            autoServeSet = autoServeSet + 1
        elseif key == 'z' or key == 'enter' or key == 'return' or key == 'escape' then
            gameState = 'menu'
        end
        if autoServeSet > 1 then
            autoServeSet = 0
        elseif autoServeSet < 0 then
            autoServeSet = 1
        end
    elseif gameState == 'music_select' then
        musicMenuKeyPressed(key)
    elseif gameState == 'serve' then
        if key == 'enter' or key == 'return' then
            gameState = 'play'
            combo = 0
        elseif key == "escape" then
            gameState = 'menu'
            player1Score = 0
            player2Score = 0
            combo = 0
        end
    elseif gameState == 'play' then
        if key == "escape" then
            gameState = 'menu'
            ball:reset()
            player1Score = 0
            player2Score = 0
            combo = 0
        end
    elseif gameState == 'victory' then
        if key == 'enter' or key == 'return' then
            gameState = 'play'
            player1Score = 0
            player2Score = 0
            combo = 0
        elseif key == "escape" then
            gameState = 'menu'
        end
    end
end

function colorChange(selection,r,g,b,t)
    if musicMenu.selection == selection then
        love.graphics.setColor(r/255, g/255, b/255, t/100)
    end
end

function startShake(duration, magnitude)
    shakeTimer = duration or 0.2 -- 默认震动0.2秒
    shakeMagnitude = magnitude or 5 -- 默认震动幅度5像素
end

function drawShake()
    if shakeTimer > 0 then
            -- 在 X 和 Y 轴上随机偏移一个 (-magnitude, magnitude) 之间的值
            -- 比如幅度是 3，就会在 -3 到 3 之间随机跳动
            local dx = math.random(-shakeMagnitude, shakeMagnitude)
            local dy = math.random(-shakeMagnitude, shakeMagnitude)
            love.graphics.translate(dx, dy)
        end
end