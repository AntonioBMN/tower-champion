-- Compact top-down dungeon tilesheet generator (4 columns x 4 rows).
local d=Dialog{title="Dungeon Tiles"}
d:number{id="size",label="Tile size",text="32",decimals=0}
d:number{id="seed",label="Seed",text="1337",decimals=0}
d:button{id="ok",text="Generate",focus=true}; d:button{id="cancel",text="Cancel"}; d:show()
if not d.data.ok then return end
local S=math.max(16,math.min(64,math.floor(d.data.size or 32)))
local st=math.floor(d.data.seed or 1337)%2147483647; if st<=0 then st=1 end
local function rnd(n) st=(st*48271)%2147483647; return st%n end
local C={
  floor=app.pixelColor.rgba(51,54,64,255), floor2=app.pixelColor.rgba(61,64,74,255),
  dark=app.pixelColor.rgba(29,30,37,255), wall=app.pixelColor.rgba(78,82,94,255),
  hi=app.pixelColor.rgba(112,117,128,255), shade=app.pixelColor.rgba(45,48,57,255),
  moss=app.pixelColor.rgba(72,94,68,255)
}
local im=Image(S*4,S*4,ColorMode.RGB); im:clear(app.pixelColor.rgba(0,0,0,0))
local function R(x,y,w,h,c) if w>0 and h>0 then im:clear(Rectangle(x,y,w,h),c) end end
local function P(x,y,c) if x>=0 and y>=0 and x<im.width and y<im.height then im:drawPixel(x,y,c) end end
local function L(x0,y0,x1,y1,c)
  local dx,sx=math.abs(x1-x0),x0<x1 and 1 or -1; local dy,sy=-math.abs(y1-y0),y0<y1 and 1 or -1
  local e=dx+dy
  while true do P(x0,y0,c); if x0==x1 and y0==y1 then break end; local e2=2*e
    if e2>=dy then e,x0=e+dy,x0+sx end; if e2<=dx then e,y0=e+dx,y0+sy end end
end
local function floor(c,r,v)
  local x,y=c*S,r*S; R(x,y,S,S,v==3 and C.shade or C.floor)
  local step=math.max(8,math.floor(S/3))
  for yy=step,S-1,step do L(x,y+yy,x+S-1,y+yy,C.shade) end
  for yy=0,S-1,step do local sh=(math.floor(yy/step)%2)*math.floor(step/2)
    for xx=step-sh,S-1,step do L(x+xx,y+yy,x+xx,math.min(y+yy+step-1,y+S-1),C.shade) end end
  for i=1,math.max(3,math.floor(S/6)) do P(x+rnd(S),y+rnd(S),v==3 and C.moss or C.floor2) end
  if v==1 then L(x+S*.25,y+S*.25,x+S*.48,y+S*.48,C.dark); L(x+S*.48,y+S*.48,x+S*.38,y+S*.7,C.dark) end
  if v==2 then for i=1,4 do R(x+2+rnd(S-5),y+2+rnd(S-5),2,2,C.dark) end end
end
local function edge(c,r,side)
  floor(c,r,0); local x,y=c*S,r*S; local n=math.max(8,math.floor(S*.34))
  if side==0 then R(x,y,S,n,C.wall); L(x,y+n-1,x+S-1,y+n-1,C.shade)
  elseif side==1 then R(x,y+S-n,S,n,C.wall); L(x,y+S-n,x+S-1,y+S-n,C.hi)
  elseif side==2 then R(x,y,n,S,C.wall); L(x+n-1,y,x+n-1,y+S-1,C.shade)
  else R(x+S-n,y,n,S,C.wall); L(x+S-n,y,x+S-n,y+S-1,C.hi) end
end
local function corner(c,r,top,left)
  floor(c,r,0); local x,y=c*S,r*S; local n=math.max(8,math.floor(S*.34))
  R(x,top and y or y+S-n,S,n,C.wall); R(left and x or x+S-n,y,n,S,C.wall)
end
local function solid(c,r)
  local x,y=c*S,r*S; R(x,y,S,S,C.wall); local h=math.max(6,math.floor(S/4))
  for yy=h,S-1,h do L(x,y+yy,x+S-1,y+yy,C.dark) end
  L(x,y,x+S-1,y,C.hi); L(x,y+S-1,x+S-1,y+S-1,C.shade)
  for i=1,3 do P(x+rnd(S),y+rnd(S),c==3 and C.moss or C.floor2) end
end
floor(0,0,0);floor(1,0,1);floor(2,0,2);floor(3,0,3)
for c=0,3 do edge(c,1,c) end
corner(0,2,true,true);corner(1,2,true,false);corner(2,2,false,true);corner(3,2,false,false)
for c=0,3 do solid(c,3) end
app.transaction("Generate dungeon tiles",function()
  local s=Sprite(im.width,im.height,ColorMode.RGB); s.filename="dungeon_tiles_"..S.."px.aseprite"
  s.layers[1].name="Dungeon Tiles"; s.cels[1].image=im; s.gridBounds=Rectangle(0,0,S,S); app.activeSprite=s
end); app.refresh()
