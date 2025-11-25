Class = require "class"
push = require "push"

require "Ball"
require "Paddle"

WINDOW_WIDTH = 1280
WINDOW_HEIGHT = 720

VIRTUAL_WIDTH = 432
VIRTUAL_HEIGHT = 243

PADDLE_SPEED = 200

function love.load()
    math.randomseed(os.time())

    love.graphics.setDefaultFilter("nearest", "nearest")

    love.window.setTitle('Pong')

    smallFont = love.graphics.newFont("font.ttf", 8)

    scoreFont = love.graphics.newFont("font.ttf", 32)

    player1Score = 0
    player2Score = 0

    servingPlayer = math.random(2) == 1 and 1 or 2
    
    paddle1 = Paddle(5, 20, 5, 20)
    paddle2 = Paddle(VIRTUAL_WIDTH - 10, VIRTUAL_HEIGHT - 30, 5, 20)
    ball = Ball(VIRTUAL_WIDTH / 2 - 2, VIRTUAL_HEIGHT / 2 - 2, 5, 5)
    gameState = 'start'

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
            resizable = false,
            vsync = true
        }
    )
end

function love.update(dt)

    if ball:collides(paddle1) then
        ball.dx = -ball.dx
        ball.x = paddle1.x + 5
    end

    if ball:collides(paddle2) then
        ball.dx = -ball.dx
        ball.x = paddle2.x
    end

    if ball.y <= 0 then
        ball.dy = math.random(10,150)
        ball.y = 0
    end
    
    if ball.y >= VIRTUAL_HEIGHT - 4 then
        ball.dy = -math.random(10,150)
        ball.y = VIRTUAL_HEIGHT - 5
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

    if gameState == "play" then
            ball:update(dt)
            if ball.x < 0 then
                player2Score = player2Score + 1
                ball:reset()
                servingPlayer = 1
                ball.dx = 100
                gameState = 'serve'
            end

            if ball.x > VIRTUAL_WIDTH - 4 then
                player1Score = player1Score + 1
                ball:reset()
                servingPlayer = 2
                ball.dx = -100
                gameState = 'serve'
            end
    end
    
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    elseif key == 'enter' or key == 'return' then
        if gameState == 'start' then
            gameState = 'serve'
        elseif gameState =='serve' then
            gameState = 'play'
        end
    end
end

function love.draw()
    push:apply("start")

    love.graphics.clear(40/255, 45/255, 52/255, 1)

    love.graphics.setFont(smallFont)

    if gameState == 'start' then
        love.graphics.printf('Welcome to Pong!',0,20,VIRTUAL_WIDTH,'center')
        love.graphics.printf('Press Enter to Play!',0,32,VIRTUAL_WIDTH,'center')
    elseif gameState == 'serve' then
        love.graphics.printf('Player'..tostring(servingPlayer).."'s turn!",0,20,VIRTUAL_WIDTH,'center')
        love.graphics.printf('Press Enter to Serve!',0,32,VIRTUAL_WIDTH,'center')
    end

    love.graphics.setFont(scoreFont)
    love.graphics.print(player1Score,VIRTUAL_WIDTH / 2 - 50, VIRTUAL_HEIGHT / 3)
    love.graphics.print(player2Score,VIRTUAL_WIDTH / 2 + 30, VIRTUAL_HEIGHT / 3)

    paddle1:render()
    paddle2:render()

    ball:render()

    displayFPS()

    push:apply("end")
end

function displayFPS()
    love.graphics.setColor(0,1,0,1)
    love.graphics.setFont(smallFont)
    love.graphics.print('FPS: '..tostring(love.timer.getFPS()),40,20)
    love.graphics.setColor(1,1,1,1)
end