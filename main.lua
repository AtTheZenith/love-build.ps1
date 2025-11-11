local camera = require 'src.camera'
local input = require 'src.input'

local currentcamera
local randomobjects = {}

local sin, cos = {}, {}
for i = 0, 360 do
  local radians = math.rad(i)
  sin[i] = math.sin(radians)
  cos[i] = math.cos(radians)
end


function love.load()
  love.window.setTitle 'Hello World'
  love.window.setMode(800, 600, { resizable=true })

  ---@cast currentcamera camera
  currentcamera = camera:new()
  for _ = 1, 10 do
    table.insert(randomobjects, {
      x = math.random(-400, 400),
      y = math.random(-300, 300),
      size = math.random(20, 50)
    })
  end

  print 'Hello, World!'
end

function love.update(dt)
  local movespeed = 200
  local zoomspeed = 0.5

  if input.isdown("a") then
    currentcamera.x = currentcamera.x + movespeed * dt
  end
  if input.isdown("d") then
    currentcamera.x = currentcamera.x - movespeed * dt
  end
  if input.isdown("w") then
    currentcamera.y = currentcamera.y + movespeed * dt
  end
  if input.isdown("s") then
    currentcamera.y = currentcamera.y - movespeed * dt
  end
end

function love.draw()
  currentcamera:refreshcanvas()
  currentcamera:enable()
  for _, obj in next, randomobjects do
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", obj.x - obj.size/2, obj.y - obj.size/2, obj.size, obj.size)
  end
  love.graphics.setColor(1, 0, 0)
  love.graphics.circle("fill", 0, 0, 10)
  currentcamera:disable()

  love.graphics.circle("fill", love.graphics.getWidth()/2, love.graphics.getHeight()/2, 15)

  love.graphics.printf('Hello World!', 0, 20, love.graphics.getWidth(), 'center')
end
