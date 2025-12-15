Ball = Class{}

function Ball:init(x,y,width,height)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.dx = 0
    self.dy = 0

    self.dx = math.random(2) == 1 and -100 or 100
    self.dy = math.random(-50, 50)

    self.collisionTimer = 0
end

function Ball:collides(box)
    if self.x > box.x +box.width or self.x + self.width < box.x then
        return false
    end

    if self.y > box.y + box.height or self.y + self.height < box.y then
        return false
    end

    return true
end

function Ball:reset()
    self.x = VIRTUAL_WIDTH / 2 - 2
    self.y = VIRTUAL_HEIGHT / 2 - 2

    self.dx = math.random(2) == 1 and -150 or 150
    self.dy = math.random(-80, 80)
end

function Ball:update(dt)

    if self.collisionTimer > 0 then
        self.collisionTimer = self.collisionTimer - dt
    end
    
    self.x = self.x + self.dx * dt
    self.y = self.y + self.dy * dt

    local drag = 1.0 - (0.2 * dt) -- 阻力系数

    --大于100后减速
    if math.abs(self.dx) > 100 then
        self.dx = self.dx * drag
    end
    
    if math.abs(self.dy) > 50 then
        self.dy = self.dy * drag
    end
end

function Ball:render()
    love.graphics.rectangle("fill",self.x,self.y, self.width, self.height)
end