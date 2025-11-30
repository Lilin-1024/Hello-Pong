Class = require "class"
push = require "push"

require "Ball"
require "Paddle"

WINDOW_WIDTH = 1280
WINDOW_HEIGHT = 720

VIRTUAL_WIDTH = 432
VIRTUAL_HEIGHT = 243

PADDLE_SPEED = 200

menuItems = {
    "Players",
    "Win Score",
    "Free Mode",
    "Particles",
    "Music"
}


function love.load()
    math.randomseed(os.time())

    love.graphics.setDefaultFilter("nearest", "nearest")

    love.window.setTitle('Pong')

    instructFont = love.graphics.newFont("fonts/ari_w9500/ari-w9500.ttf", 11)

    smallFont = love.graphics.newFont("fonts/font.ttf", 8)

    titleFont = love.graphics.newFont("fonts/ari_w9500/ari-w9500-condensed-display.ttf", 32)


    scoreFont = love.graphics.newFont("fonts/font.ttf", 32)

    victoryFont = love.graphics.newFont("fonts/font.ttf", 24)

    sounds = {
        ['paddle_hit'] = love.audio.newSource('sounds/paddle_hit.wav','static'),
        ['score']=love.audio.newSource('sounds/score.wav','static'),
        ['wall_hit']=love.audio.newSource('sounds/wall_hit.wav','static'),
    }

    --initialization
    player1Score = 0
    player2Score = 0

    winningPlayer = 0

    servingPlayer = math.random(2) == 1 and 1 or 2
    
    paddle1 = Paddle(5, 20, 5, 20)
    paddle2 = Paddle(VIRTUAL_WIDTH - 10, VIRTUAL_HEIGHT - 30, 5, 20)
    ball = Ball(VIRTUAL_WIDTH / 2 - 2, VIRTUAL_HEIGHT / 2 - 2, 5, 5)

    --menu initialization
    gameState = 'menu'
    selectedItem = 1
    playersConfig = 2

    if servingPlayer == 1 then
        ball.dx = 100
    else
        ball.dx = -100
    end

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

    if ball:collides(paddle1) then
        ball.dx = -ball.dx*1.2
        ball.x = paddle1.x + ball.width

        sounds['paddle_hit']:play()
    end

    if ball:collides(paddle2) then
        ball.dx = -ball.dx*1.2
        ball.x = paddle2.x - ball.width

        sounds['paddle_hit']:play()
    end

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

    paddle1:update(dt)
    paddle2:update(dt)

    --player1 movement
    if love.keyboard.isDown{'w'} then
        paddle1.dy = -PADDLE_SPEED
    elseif love.keyboard.isDown{'s'} then
        paddle1.dy = PADDLE_SPEED
    else
        paddle1.dy = 0
    end

    --player2 movement
    if love.keyboard.isDown{'up'} then
        paddle2.dy = -PADDLE_SPEED
    elseif love.keyboard.isDown{'down'} then
        paddle2.dy = PADDLE_SPEED
    else
        paddle2.dy = 0
    end

    --计分
    if gameState == "play" then
            ball:update(dt)
            if ball.x < 0 then
                player2Score = player2Score + 1
                ball:reset()
                servingPlayer = 1
                ball.dx = 100

                sounds['score']:play()

                if player2Score == 5 then
                    gameState = 'victory'
                    winningPlayer = 2
                else
                    gameState = 'serve'
                end

            end

            if ball.x > VIRTUAL_WIDTH - 4 then
                player1Score = player1Score + 1
                ball:reset()
                servingPlayer = 2
                ball.dx = -100
                gameState = 'serve'

                sounds['score']:play()

                if player1Score == 5 then
                    gameState = 'victory'
                    winningPlayer = 1
                else
                    gameState = 'serve'
                end
            end
    end
    
end


-- state switch
function love.keypressed(key)

    --menu press
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
                -- win score
            elseif item == 'Free Mode' then
                -- free mode
            elseif item == 'Particles' then
                -- particles
            elseif item == 'Music' then
                -- music
            end
            

        elseif key == 'enter' or key == 'return' then
            gameState = 'serve'
        elseif key == "escape" then
            love.event.quit()
        end
    elseif gameState == 'submenu_players' then
        --submenu press
        if key == 'left' then
            playersConfig = 1
        elseif key == 'right' then
            playersConfig = 2
        elseif key == 'z' or key == 'escape' then
            gameState = 'menu'
        end
    elseif gameState == 'serve' then
        if key == 'enter' or key == 'return' then
            gameState = 'play'
        elseif key == "escape" then
            gameState = 'menu'
        end
    elseif gameState == 'play' then
        if key == "escape" then
            gameState = 'menu'
        end
    elseif gameState == 'victory' then
        if key == 'enter' or key == 'return' then
            gameState = 'start'
            player1Score = 0
            player2Score = 0
        elseif key == "escape" then
            gameState = 'menu'
        end
    end
end

function love.draw()
    push:apply("start")

    love.graphics.clear(40/255, 45/255, 52/255, 1)

    if gameState =='menu' then
        drawMenu()
    elseif gameState == 'submenu_players' then
        drawPlayersSettings()
    elseif gameState == 'play' or gameState == 'serve' or gameState == 'victory' then
        drawGame()
    end

    displayFPS()

    push:apply("end")
end

function displayFPS()
    love.graphics.setColor(1,1,1,1)
    love.graphics.setFont(smallFont)
    love.graphics.print('FPS: '..tostring(love.timer.getFPS()),40,20)
    love.graphics.setColor(1,1,1,1)
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
            end

            love.graphics.print(item, x, y2)

        else
            -- 1~4 
            local x = startX + (i - 1) * spacing

            if selectedItem == i then
                love.graphics.setColor(1, 1, 0)
            else
                love.graphics.setColor(1, 1, 1)
            end

            love.graphics.print(item, x, y)
        end
    end

    love.graphics.setColor(1, 1, 1)
end

function drawMenu()
    --title
        love.graphics.setFont(titleFont)
        love.graphics.printf("100% Hello Pong!",0,50,VIRTUAL_WIDTH,'center')

        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.setFont(smallFont)
        love.graphics.printf("< Use <- -> to navigate and Z to select >", 0, 95, VIRTUAL_WIDTH, "center")
        love.graphics.setColor(1, 1, 1, 1)

        love.graphics.setFont(smallFont)
        love.graphics.printf("-- press enter to start --", 0, 110, VIRTUAL_WIDTH, "center")

        --option
        drawMenuOptions()
end

function drawGame()
    love.graphics.setFont(smallFont)

    if gameState == 'serve' then
        love.graphics.printf('Player'..tostring(servingPlayer).."'s turn!",0,20,VIRTUAL_WIDTH,'center')
        love.graphics.printf('Press Enter to Serve!',0,32,VIRTUAL_WIDTH,'center')
    elseif gameState == 'victory' then
        love.graphics.setFont(victoryFont)
        love.graphics.printf('Player'..tostring(winningPlayer).." wins!",0,10,VIRTUAL_WIDTH,'center')
        love.graphics.setFont(smallFont)
        love.graphics.printf('Press Enter to Restart!',0,42,VIRTUAL_WIDTH,'center')
    end

    if gameState == 'serve' or gameState == 'play' or gameState == 'victory' then
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
    love.graphics.setFont(instructFont)

    love.graphics.printf("Select Players", 0, 40, VIRTUAL_WIDTH, "center")

    local text = "Players : " .. tostring(playersConfig)
    
    love.graphics.printf(text, 0, 120, VIRTUAL_WIDTH, "center")

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setFont(smallFont)
    love.graphics.printf("< Use <- -> to change and Z to confirm >", 0, VIRTUAL_HEIGHT - 40, VIRTUAL_WIDTH, "center")
end
