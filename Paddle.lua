Paddle = Class{}

function Paddle:init(x,y,width,height)
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.dx = 0
    self.dy = 0

    self.isSprinting = false
    self.sprintTimer = 0
    self.sprintDuration = 0.3
    
    self.cooldownTimer = 0
    self.cooldownMax = 3.0

    self.speedMultiplier = 1.0


    self.particles = {}
end

function Paddle:attemptSprint()
    -- only sprint when it's not cooling
    if self.cooldownTimer <= 0 and not self.isSprinting then
        self.isSprinting = true
        self.sprintTimer = self.sprintDuration
        self.cooldownTimer = self.cooldownMax 
        self.speedMultiplier = 5
        sounds['dash']:play()
    end
end

function Paddle:update(dt)
    if self.isSprinting then
        self.sprintTimer = self.sprintTimer - dt


        if self.dx ~= 0 or self.dy ~= 0 then
            self:spawnParticle()
        end


        if self.sprintTimer <= 0 then
            self.isSprinting = false
            self.speedMultiplier = 1.0
        end
    end

    if self.cooldownTimer > 0 then
        self.cooldownTimer = self.cooldownTimer - dt
    end

    --update particles

    for i = #self.particles, 1, -1 do
        local p = self.particles[i]
        p.life = p.life - dt
        p.x = p.x + p.dx * dt
        p.y = p.y + p.dy * dt
        p.size = p.size - dt * 10

        if p.life <= 0 or p.size <= 0 then
            table.remove(self.particles, i)
        end
    end

    if self.dy < 0 then
        self.y = math.max(0, self.y + self.dy * dt * self.speedMultiplier)
    elseif self.dy > 0 then
        self.y = math.min(VIRTUAL_HEIGHT-20, self.y + self.dy * dt * self.speedMultiplier)
    end

    if self.dx < 0 then
        self.x = math.max(0, self.x + self.dx * dt * self.speedMultiplier)
    elseif self.dx > 0 then
        self.x = math.min(VIRTUAL_WIDTH - self.width, self.x + self.dx * dt * self.speedMultiplier)
    end
end

function Paddle:spawnParticle()
    local p = {}

    p.x = self.x + self.width/2 + math.random(-5, 5)
    p.y = self.y + self.height/2 + math.random(-5, 5)

    p.dx = math.random(-20, 20)
    p.dy = math.random(-20, 20)
    p.life = 0.4
    p.size = math.random(1, 4)
    table.insert(self.particles, p)
end

function Paddle:render()
    love.graphics.setColor(1, 1, 1, 1)
    for _, p in ipairs(self.particles) do
        love.graphics.rectangle('fill', p.x, p.y, p.size, p.size)
    end
    love.graphics.setColor(1, 1, 1, 1)

    love.graphics.rectangle('fill',self.x,self.y,self.width,self.height)

    self:drawCooldownUI()
end

function Paddle:drawCooldownUI()

    local radius = 4
    local uiX, uiY

    if self.x < VIRTUAL_WIDTH / 2 then
        uiX, uiY = 15, 15
    else
        uiX, uiY = VIRTUAL_WIDTH - 15, 15
    end

    local ratio = 0
    if self.cooldownTimer > 0 then
        ratio = 1 - (self.cooldownTimer / self.cooldownMax)
    else
        ratio = 1
    end
    
    love.graphics.setColor(0.3, 0.3, 0.3, 1)
    love.graphics.circle('line', uiX, uiY, radius)
    
    if ratio > 0 then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.arc('line', 'open', uiX, uiY, radius, -math.pi/2, -math.pi/2 + (math.pi * 2 * ratio))
    end
end