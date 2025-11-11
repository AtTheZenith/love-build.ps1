---@class camera
---@field x number
---@field y number
---@field scale number
---@field canvas love.Canvas
local camera = {}
camera.__index = camera

function camera:new()
  local new = setmetatable({}, camera)
  new.x = 0
  new.y = 0
  new.scale = 1
  new.canvas = love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight())
  return new
end

function camera:refreshcanvas()
  if self.canvas then
    self.canvas:release()
  end
  self.canvas = love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight())
end

function camera:enable()
  love.graphics.setCanvas(self.canvas)
  love.graphics.clear(0.1, 0.1, 0.1)
  love.graphics.push()
  love.graphics.translate(love.graphics.getWidth() / 2, love.graphics.getHeight() / 2)
  love.graphics.rotate(0)
  love.graphics.scale(self.scale)
  love.graphics.translate(self.x, self.y)
end

function camera:disable()
  love.graphics.pop()
  love.graphics.setCanvas()
  love.graphics.draw(self.canvas, 0, 0)
end

return camera
