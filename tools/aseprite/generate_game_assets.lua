-- Procedural 32px-style assets for a top-down action game.
-- Modes: animated hero, weapons catalog, and item catalog.

local dlg = Dialog { title = "Game Asset Generator" }
dlg:combobox {
  id = "kind", label = "Asset",
  options = { "Character", "Weapons", "Items" }, option = "Character"
}
dlg:number { id = "size", label = "Cell size", text = "32", decimals = 0 }
dlg:number { id = "seed", label = "Seed", text = "2026", decimals = 0 }
dlg:button { id = "generate", text = "Generate", focus = true }
dlg:button { id = "cancel", text = "Cancel" }
dlg:show()
if not dlg.data.generate then return end

local S = math.max(16, math.min(64, math.floor(dlg.data.size or 32)))
local SCALE = S / 32
local function q(v) return math.floor(v * SCALE + .5) end
local state = math.floor(dlg.data.seed or 2026) % 2147483647
if state <= 0 then state = state + 2147483646 end
local function rnd(n) state = (state * 48271) % 2147483647; return state % n end

local C = {
  clear=app.pixelColor.rgba(0,0,0,0), outline=app.pixelColor.rgba(25,25,32,255),
  shadow=app.pixelColor.rgba(37,35,45,150), skin=app.pixelColor.rgba(205,151,112,255),
  skinHi=app.pixelColor.rgba(235,184,137,255), hair=app.pixelColor.rgba(65,43,38,255),
  cloth=app.pixelColor.rgba(48,91,126,255), clothHi=app.pixelColor.rgba(66,126,158,255),
  leather=app.pixelColor.rgba(104,67,45,255), leatherHi=app.pixelColor.rgba(151,101,61,255),
  metal=app.pixelColor.rgba(151,164,174,255), metalHi=app.pixelColor.rgba(219,226,225,255),
  metalDark=app.pixelColor.rgba(72,81,91,255), gold=app.pixelColor.rgba(218,166,61,255),
  red=app.pixelColor.rgba(169,54,61,255), green=app.pixelColor.rgba(71,132,83,255),
  blue=app.pixelColor.rgba(60,114,173,255), purple=app.pixelColor.rgba(125,73,154,255),
  white=app.pixelColor.rgba(232,225,205,255), black=app.pixelColor.rgba(38,37,43,255),
}

local image = Image(S * 4, S * 4, ColorMode.RGB)
image:clear(C.clear)
local function rect(x,y,w,h,c)
  x,y,w,h=q(x),q(y),math.max(1,q(w)),math.max(1,q(h))
  image:clear(Rectangle(x,y,w,h),c)
end
local function cellRect(col,row,x,y,w,h,c) rect(col*32+x,row*32+y,w,h,c) end
local function pixel(col,row,x,y,c) cellRect(col,row,x,y,1,1,c) end
local function line(col,row,x0,y0,x1,y1,c,thick)
  local dx,sx=math.abs(x1-x0),x0<x1 and 1 or -1
  local dy,sy=-math.abs(y1-y0),y0<y1 and 1 or -1
  local err=dx+dy
  while true do
    cellRect(col,row,x0,y0,thick or 1,thick or 1,c)
    if x0==x1 and y0==y1 then break end
    local e2=2*err
    if e2>=dy then err,x0=err+dy,x0+sx end
    if e2<=dx then err,y0=err+dx,y0+sy end
  end
end

local function hero(col,row)
  local phase=col
  local bob=(phase==1 or phase==3) and 1 or 0
  local step=({0,2,0,-2})[phase+1]
  -- soft ground shadow
  cellRect(col,row,9,27,14,2,C.shadow)
  -- legs, alternating for walk cycle
  cellRect(col,row,11+math.max(0,step),21-bob,4,7,C.outline)
  cellRect(col,row,17+math.min(0,step),21-bob,4,7,C.outline)
  cellRect(col,row,12+math.max(0,step),22-bob,2,5,C.leather)
  cellRect(col,row,18+math.min(0,step),22-bob,2,5,C.leather)
  -- body and arms
  cellRect(col,row,8,12-bob,16,11,C.outline)
  cellRect(col,row,10,13-bob,12,9,C.cloth)
  cellRect(col,row,11,13-bob,3,8,C.clothHi)
  cellRect(col,row,7,14-bob,3,7,C.skin)
  cellRect(col,row,22,14-bob,3,7,C.skin)
  cellRect(col,row,10,20-bob,12,2,C.leather)
  pixel(col,row,16,20-bob,C.gold)
  -- direction-specific head and readable face
  cellRect(col,row,10,4-bob,12,10,C.outline)
  cellRect(col,row,11,5-bob,10,8,C.skin)
  if row==0 then -- down
    cellRect(col,row,10,4-bob,12,4,C.hair)
    pixel(col,row,13,9-bob,C.black); pixel(col,row,18,9-bob,C.black)
    cellRect(col,row,15,12-bob,3,1,C.skinHi)
  elseif row==1 then -- left
    cellRect(col,row,10,4-bob,9,4,C.hair); cellRect(col,row,10,5-bob,3,8,C.hair)
    pixel(col,row,12,9-bob,C.black); pixel(col,row,10,11-bob,C.hair)
  elseif row==2 then -- right
    cellRect(col,row,13,4-bob,9,4,C.hair); cellRect(col,row,19,5-bob,3,8,C.hair)
    pixel(col,row,19,9-bob,C.black); pixel(col,row,21,11-bob,C.hair)
  else -- up
    cellRect(col,row,10,4-bob,12,9,C.hair)
    cellRect(col,row,12,5-bob,8,2,C.leatherHi)
  end
end

local function sword(c,r,variant)
  line(c,r,8,24,22,10,C.outline,3); line(c,r,9,23,22,10,C.metal,1)
  line(c,r,21,8,24,11,C.metalHi,2); line(c,r,7,21,11,25,C.gold,2)
  line(c,r,6,26,10,22,variant and C.red or C.leather,3)
end
local function axe(c,r)
  line(c,r,9,26,20,8,C.outline,4); line(c,r,10,25,21,8,C.leatherHi,2)
  cellRect(c,r,17,6,10,8,C.outline); cellRect(c,r,18,7,8,6,C.metal)
  cellRect(c,r,22,8,5,3,C.metalHi)
end
local function bow(c,r)
  line(c,r,8,7,12,4,C.leatherHi,2); line(c,r,8,7,6,16,C.leatherHi,2)
  line(c,r,6,16,9,25,C.leatherHi,2); line(c,r,9,25,13,28,C.leatherHi,2)
  line(c,r,12,5,12,27,C.white,1); line(c,r,5,22,25,10,C.metalHi,1)
end
local function wand(c,r,magic)
  line(c,r,9,26,20,10,C.outline,4); line(c,r,10,25,21,10,C.leatherHi,2)
  cellRect(c,r,18,6,8,8,C.outline); cellRect(c,r,20,8,4,4,magic)
  pixel(c,r,23,5,magic); pixel(c,r,27,9,magic); pixel(c,r,18,4,magic)
end

local function drawWeapons()
  for r=0,3 do
    sword(0,r,r%2==1); axe(1,r); bow(2,r)
    wand(3,r,({C.blue,C.green,C.purple,C.red})[r+1])
    -- Tiny variation marks keep rows visually distinct.
    for i=1,r do pixel(i%4,r,3+i*2,28-r,({C.gold,C.red,C.green})[(i%3)+1]) end
  end
end

local function potion(c,r,color)
  cellRect(c,r,12,7,8,4,C.outline); cellRect(c,r,14,9,4,5,C.white)
  cellRect(c,r,9,13,14,14,C.outline); cellRect(c,r,11,15,10,10,color)
  cellRect(c,r,12,15,3,2,C.white); cellRect(c,r,13,6,6,3,C.leather)
end
local function coin(c,r)
  cellRect(c,r,8,8,16,16,C.outline); cellRect(c,r,10,9,12,14,C.gold)
  cellRect(c,r,12,10,7,2,C.white); cellRect(c,r,14,13,4,8,C.leatherHi)
end
local function key(c,r)
  cellRect(c,r,7,7,10,10,C.outline); cellRect(c,r,9,9,6,6,C.gold)
  cellRect(c,r,11,11,2,2,C.outline); line(c,r,15,15,25,25,C.outline,4)
  line(c,r,15,15,24,24,C.gold,2); cellRect(c,r,21,20,5,3,C.gold)
end
local function chest(c,r)
  cellRect(c,r,6,10,20,16,C.outline); cellRect(c,r,8,12,16,12,C.leather)
  cellRect(c,r,8,12,16,4,C.leatherHi); cellRect(c,r,14,15,4,7,C.gold)
  pixel(c,r,15,18,C.black)
end
local function drawItems()
  local colors={C.red,C.blue,C.green,C.purple}
  for r=0,3 do
    potion(0,r,colors[r+1]); coin(1,r); key(2,r); chest(3,r)
    if r>0 then
      for i=1,r do pixel(1,r,7+i*5,26,C.gold) end
    end
  end
end

local kind=dlg.data.kind
if kind=="Character" then for row=0,3 do for col=0,3 do hero(col,row) end end
elseif kind=="Weapons" then drawWeapons()
else drawItems() end

app.transaction("Generate "..kind, function()
  local sprite=Sprite(image.width,image.height,ColorMode.RGB)
  sprite.filename=string.lower(kind).."_"..S.."px.aseprite"
  sprite.layers[1].name=kind
  sprite.cels[1].image=image
  sprite.gridBounds=Rectangle(0,0,S,S)
  app.activeSprite=sprite
end)
app.refresh()

