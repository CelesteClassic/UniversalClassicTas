pico-8 cartridge // http://www.pico-8.com
version 29
__lua__

max_index=41
function vec(x,y)
return bt({x,y},"x,y")
end
function rct(x,y,w,h)
return bt({x,y,h,w},"x,y,h,w")
end
function bt(b, idxs)
local ret={}
for i,v in pairs(b) do
ret[split(idxs)[i]]=v
end
return ret
end
d_f=false
objects,got_fruit,freeze,delay_restart,sfx_timer,ui_timer={},{},0,0,0,-99
function _init()
m1=get_data(4096,3460)
m2=get_data(7556,2495)
m3=get_data(10051,2189)
load_mapdata(m1)
ldgfx()
frames,start_game_flash=0,0
load_level(-1)
end
function begin_game()
regfx()
max_djump,deaths,frames,seconds,minutes,time_ticking=1,0,0,0,0,true
load_level(0)
end
function is_credits()
return lvl_id==-2
end
function is_title()
return lvl_id==-1
end
function is_start()
return lvl_id==0
end
function get_fruit()
local froot=0
for _ in pairs(got_fruit) do
froot+=1
end
return froot
end
function rnd128()
return rnd(128)
end
function rndoff(range,off)
return rnd(range)+off
end
clouds={}
for i=0,16 do
add(clouds,bt({rnd128(),rnd128(),rndoff(4,1),rndoff(32,32)},"x,y,spd,w"))
end
particles={}
for i=0,24 do
add(particles,bt({rnd128(),rnd128(),flr(rnd(1.25)),rndoff(5,0.25),0,rnd(1),rndoff(2,6)},"x,y,s,spd,wspd,off,c"))
end
effect_clouds={}
for i=0,9 do
add(effect_clouds,vec(i*16,(i%2)*4+8))
end
player={
init=function(q)
q.grace,q.jbuffer,q.flying,q.djump=0,0,0,max_djump
q.dash_time,q.dash_effect_time,q.dash_target_x,q.dash_target_y,q.dash_accel_x,q.dash_accel_y,q.hitbox,q.spr_off,q.solids=0,0,0,0,0,0,rct(1,3,6,5),0,true
create_hair(q)
end,update=function(q)
if pause_player then
return
end
if q.flying>0 then
q.init_object_here(launch_effect,3,5)
q.flying-=1
q.y+=q.spd.y
if q.y<-64 then
fading=0.5
if globalfade==4 then
next_level()
fading=-0.5
end
end
return
end
local h_input=btn(1) and 1 or btn(0) and -1 or 0
if spikes_at(q.x+q.hitbox.x,q.y+q.hitbox.y,q.hitbox.w,q.hitbox.h,q.spd.x,q.spd.y)
or	q.y>lvl_ph then
kill_player(q)
end
local on_ground=q.is_solid(0,1)
if on_ground and not q.was_on_ground then
q.init_smoke(0,4)
end
local jump,dash=btn(4) and not q.p_jump,btn(5) and not q.p_dash
q.p_jump,q.p_dash=btn(4),btn(5)
if jump then
q.jbuffer=4
elseif q.jbuffer>0 then
q.jbuffer-=1
end
if on_ground then
q.grace=6
if q.djump<max_djump then
psfx(6)
q.djump=max_djump
end
elseif q.grace>0 then
q.grace-=1
end
if q.dash_effect_time>0 then
q.dash_effect_time-=1
end
if q.dash_time>0 then
q.init_smoke()
q.dash_time-=1
q.spd=vec(appr(q.spd.x,q.dash_target_x,q.dash_accel_x),appr(q.spd.y,q.dash_target_y,q.dash_accel_y))
else
local maxrun=1
local accel=on_ground and 0.6 or 0.4
local deccel=0.15
q.spd.x=abs(q.spd.x)<=1 and
appr(q.spd.x,h_input*maxrun,accel) or
appr(q.spd.x,sign(q.spd.x)*maxrun,deccel)
if q.spd.x~=0 then
q.flip.x=(q.spd.x<0)
end
local maxfall=2
local gravity=abs(q.spd.y)>0.15 and 0.21 or 0.105
if lvl_wind==1 then
maxfall,gravity=1,abs(q.spd.y)>0.15 and 0.16 or 0.08
elseif lvl_wind==-1 then
gravity=abs(q.spd.y)>0.15 and 0.26 or 0.13
end
if h_input~=0 and q.is_solid(h_input,0) then
maxfall,q.rem.x=0.4,0
if rnd(10)<2 then
q.init_smoke(h_input*6)
end
end
if not on_ground then
q.spd.y=appr(q.spd.y,maxfall,gravity)
end
if q.jbuffer>0 then
if q.grace>0 then
psfx(2)
q.jbuffer,q.grace,q.spd.y=0,0,-2
q.init_smoke(0,4)
else
local wall_dir=(q.is_solid(-3,0) and -1 or q.is_solid(3,0) and 1 or 0)
if wall_dir~=0 then
psfx(3)
q.jbuffer,q.spd.y,q.spd.x=0,-2,-wall_dir*(maxrun+1)
q.init_smoke(wall_dir*6)
end
end
end
local d_full=5
local d_half=3.5355339059
if q.djump>0 and dash then
q.init_smoke()
q.djump-=1
q.dash_time,has_dashed,q.dash_effect_time=4,true,10
local v_input=btn(2) and -1 or btn(3) and 1 or 0
q.spd=vec(h_input~=0 and
h_input*(v_input~=0 and d_half or d_full) or
(v_input~=0 and 0 or q.flip.x and -1 or 1)
,v_input~=0 and v_input*(h_input~=0 and d_half or d_full) or 0)
psfx(4)
freeze=2
q.dash_target_x=2*sign(q.spd.x)
q.dash_target_y=(q.spd.y>=0 and 2 or 1.5)*sign(q.spd.y)
q.dash_accel_x=q.spd.y==0 and 1.5 or 1.06066017177
q.dash_accel_y=q.spd.x==0 and 1.5 or 1.06066017177
elseif q.djump<=0 and dash then
psfx(5)
q.init_smoke()
end
end
q.spr_off+=0.25
q.spr = not on_ground and (q.is_solid(h_input,0) and 5 or 3) or
btn(3) and 6 or
btn(2) and 7 or
1+(q.spd.x~=0 and h_input~=0 and q.spr_off%4 or 0)
move_camera(q)
if q.y<-4 and lvl_effects~=1 and lvl_effects~=3 and lvl_effects~=4 then
if is_start() and q.x>256 then
load_override=m3
load_level(28)
else
next_level()
end
end
q.was_on_ground=on_ground
end,draw=function(q)
if q.x<-1 or q.x>lvl_pw-7 then
q.x,q.spd.x,q.rem.x=clamp(q.x,-1,lvl_pw-7),0,0
end
set_hair_color(q.djump)
draw_hair(q,q.flip.x and -1 or 1)
default_draw(q)
pal()
end
}
function create_hair(obj)
obj.hair={}
for i=1,5 do
add(obj.hair,vec(obj.x,obj.y))
end
end
function set_hair_color(djump)
pal(1,({1,flash(),rainbow()})[djump] or 12)
end
function draw_hair(obj,facing)
local last=vec(obj.x+4-facing*2,obj.y+(btn(3) and 4 or 3))
for i,h in pairs(obj.hair) do
h.x+=(last.x-h.x)/1.5
h.y+=(last.y+0.5-h.y)/1.5
circfill(h.x,h.y,clamp(4-i,1,2),1)
last=h
end
end
player_spawn={
init=function(q)
sfx(0)
q.spr,q.target,q.spd.y,q.state,q.delay,q.y=3,q.y,-4,0,0,min(q.y+48,lvl_ph)
cx,cy=clamp(q.x,64,lvl_pw-64),clamp(q.y,64,lvl_ph-64)
move_camera(q)
create_hair(q)
end,update=function(q)
if q.state==0 then
if q.y<q.target+16 then
q.state,q.delay=1,3
end
elseif q.state==1 then
q.spd.y+=0.5
if q.spd.y>0 then
if q.delay>0 then
q.spd.y=0
q.delay-=1
elseif q.y>q.target then
q.y,q.spd,q.state,q.delay=q.target,vec(0,0),2,5
q.init_smoke(0,4)
sfx(1)
end
end
elseif q.state==2 then
q.delay-=1
q.spr=6
if q.delay<0 then
destroy_object(q)
q.init_object_here(player)
end
end
move_camera(q)
end,draw=function(q)
set_hair_color(max_djump)
draw_hair(q,1)
default_draw(q)
pal()
end
}
fall_plat={
init=function(q)
q.yspd,q.state,q.timer=0,-1,-1
end,update=function(q)
local hit=q.check(player,0,-1)
if hit then
hit=q.check(spring,0,-1) or q.check(side_spring,1,0) or q.check(side_spring,-1,0)
trigger_fall_plat(q,hit)
end
if q.timer>0 then
q.timer-=1
if q.timer==0 then
q.state=1
end
end
if q.state==1 then
q.yspd=appr(q.yspd,3,0.4)
q.y+=q.yspd
end
if q.spring then
q.spring.y=q.spring.type==side_spring and q.y or q.y-8
end
end,draw=function(q)
if q.state==0 then
spr(83,rndoff(2,q.x),rndoff(2,q.y))
else
default_draw(q)
end
end
}
function trigger_fall_plat(obj,spring)
if obj.state==-1 then
obj.spring,obj.state,obj.timer=spring,0,10
psfx(8)
end
end
spring={
init=function(q)
q.dy,q.delay=0,0
end,update=function(q)
local hit=q.player_here()
if q.delay>0 then
q.delay-=1
elseif hit then
hit.y,hit.spd.y,q.dy,q.delay,hit.djump=q.y-4,-3,4,10,max_djump
hit.spd.x*=0.2
local below=q.check(fall_plat,0,1)
if below then
trigger_fall_plat(below,q)
end
psfx(11)
end
q.dy*=0.75
end,draw=function(q)
local dy=flr(q.dy)
sspr(16,8,8,8-dy,q.x,q.y+dy)
end
}
side_spring={
init=function(q)
q.dx,q.dir=0,q.spr==11 and 1 or -1
end,update=function(q)
local hit=q.player_here()
if hit then
hit.x,hit.spd.x,hit.spd.y,hit.dash_time,hit.dash_effect_time,q.dx,hit.djump=q.x+q.dir*4,q.dir*3,-1.5,0,0,4,max_djump
local left=q.check(fall_plat,-q.dir,1)
if left then
trigger_fall_plat(left,q)
end
psfx(11)
end
q.dx*=0.75
end,draw=function(q)
local dx=flr(q.dx)
sspr(96,0,8-dx,8,q.x+(q.spr-11)*dx,q.y,8-dx,8,q.spr==11)
end
}
balloon={
init=function(q)
q.offset,q.start,q.timer,q.hitbox,q.double=rnd(1),q.y,0,rct(-1,-1,10,10),q.spr==14
if q.spr==13 then
q.x+=4
end
q.spr=22
end,update=function(q)
if q.spr==22 then
q.offset+=0.01
q.y=q.start+sin(q.offset)*2
local hit=q.player_here()
local new_djump=q.double and 2 or max_djump
if hit and hit.djump<new_djump then
psfx(9)
q.init_smoke()
hit.djump,q.spr,q.timer=new_djump,0,60
end
elseif q.timer>0 then
q.timer-=1
else
psfx(10)
q.init_smoke()
q.spr=22
end
end,draw=function(q)
if q.spr==22 then
if q.double then
pal(1,flash())
end
spr(13+(q.offset*8)%3,q.x,q.y+6)
default_draw(q)
pal()
end
end
}
smoke={
init=function(q)
q.spd.y,q.spd.x,q.flip.x,q.flip.y=-0.1,rndoff(0.2,0.3),maybe(),maybe()
q.x+=rndoff(2,-1)
q.y+=rndoff(2,-1)
end,update=function(q)
q.spr+=0.2
if q.spr>=32 then
destroy_object(q)
end
end
}
function check_fruit(q)
local hit=q.player_here()
if hit then
hit.djump,sfx_timer,got_fruit[lvl_id]=max_djump,20,true
sfx(15)
q.init_object_here(lifeup)
destroy_object(q)
end
end
fruit={
if_not_fruit=true,init=function(q)
q.start,q.off=q.y,0
end,update=function(q)
check_fruit(q)
q.off+=0.025
q.y=q.start+sin(q.off)*2.5
end
}
fly_fruit={
if_not_fruit=true,init=function(q)
q.start,q.step,q.sfx_delay=q.y,0.5,8
end,update=function(q)
if has_dashed then
if q.sfx_delay>0 then
q.sfx_delay-=1
if q.sfx_delay==0 then
sfx_timer=20
sfx(14)
end
end
q.spd.y=appr(q.spd.y,-3.5,0.25)
if q.y<-16 then
destroy_object(q)
end
else
q.step+=0.05
q.spd.y=sin(q.step)*0.5
end
check_fruit(q)
end,draw=function(q)
spr(26,q.x,q.y)
for ox=-6,6,12 do
spr(not has_dashed and sin(q.step)<0 and (q.y>q.start and 47 or 46) or 45,q.x+ox,q.y-2,1,1,ox==-6)
end
end
}
lifeup={
init=function(q)
q.spd.y,q.duration,q.flash=-0.25,30,0
q.x-=2
q.y-=4
end,update=function(q)
q.duration-=1
if q.duration<=0 then
destroy_object(q)
end
end,draw=function(q)
if not d_f then q.flash+=0.5 end
?"1000",q.x-2,q.y,7+q.flash%2
end
}
fake_wall={
if_not_fruit=true,update=function(q)
q.hitbox.w,q.hitbox.h=18,18
local hit=q.check(player,-1,-1)
if hit and hit.dash_effect_time>0 then
hit.spd.x,hit.spd.y,hit.dash_time=sign(hit.spd.x)*-1.5,-1.5,-1
for ox=0,8,8 do
for oy=0,8,8 do
q.init_smoke(ox,oy)
end
end
init_fruit(q,4,4,q.spr~=64)
end
q.hitbox.w,q.hitbox.h=16,16
end,draw=function(q)
pal(3,fg_col)
pal(11,fg_alt)
sspr(0,32,8,16,q.x,q.y)
sspr(0,32,8,16,q.x+8,q.y,8,16,true,true)
pal()
end
}
function init_fruit(q,ox,oy,c)
sfx_timer=20
sfx(13)
if not c then
q.init_object_here(fruit,ox,oy,26)
end
destroy_object(q)
end
key={
if_not_fruit=true,update=function(q)
local was=flr(q.spr)
q.spr=9.5+sin(frames/30)
if q.spr==10 and q.spr~=was then
q.flip.x=not q.flip.x
end
if q.player_here() then
sfx(12)
sfx_timer,has_key=10,true
destroy_object(q)
end
end
}
chest={
if_not_fruit=true,init=function(q)
q.x-=4
q.start,q.timer=q.x,20
end,update=function(q)
if has_key then
q.timer-=1
q.x=q.start+rndoff(3,-1)
if q.timer<=0 then
init_fruit(q,0,-4)
end
end
end
}
big_chest={
init=function(q)
q.state,q.hitbox.w=(max_djump==1 or not is_start()) and 0 or 2,16
end,draw=function(q)
if not is_start() then
pal(10,7)
pal(9,6)
pal(4,5)
pal(1,rainbow())
end
if q.state==0 then
local hit=q.check(player,0,8)
if hit and hit.is_solid(0,1) then
if is_start() then
sfx(13)
q.init_object_here(orb,4,4)
q.state,sfx_timer=2,20
fset(101,0,false)
else
sfx(16)
q.init_smoke()
q.init_smoke(8)
bgm,pause_player,q.state,hit.spd,q.timer,q.particles,fading,contrast,globalfade,bg_col,bg_alt=-1,true,1,vec(0,0),60,{},0.5,1,0,0,0
end
end
default_draw(q)
spr(96,q.x+8,q.y,1,1,true)
elseif q.state==1 then
q.timer-=1
if q.timer<=45 and #q.particles<50 then
add(q.particles,{
x=rndoff(14,1),y=0,h=rndoff(32,32),spd=rndoff(8,8)
})
end
if q.timer<0 then
q.state,q.particles=2,{}
q.init_object_here(orb,4,4)
pause_player=false
fading,contrast,bg_col,bg_alt=-0.5,0,9,10
end
foreach(q.particles,function(p)
p.y+=p.spd
line(q.x+p.x,q.y+8-p.y,q.x+p.x,min(q.y+8-p.y+p.h,q.y+8),7)
end)
end
spr(112,q.x,q.y+8)
spr(112,q.x+8,q.y+8,1,1,true)
pal()
end
}
orb={
init=function(q)
q.spd.y=is_start() and -4 or -5.6
end,draw=function(q)
q.spd.y=appr(q.spd.y,0,0.5)
local hit=q.player_here()
if q.spd.y==0 and hit then
sfx(17)
destroy_object(q)
max_djump+=1
freeze,hit.djump=10,max_djump
if not is_start() then
hit.spd.x,hit.spd.y,hit.flying=0,-4,99
else
fset(101,0,true)
clock=true
end
end
if not is_start() then
pal(8,rainbow())
end
spr(0,q.x,q.y)
pal()
for i=0,0.875,0.125 do
circfill(q.x+4+cos(frames/30+i)*8,q.y+4+sin(frames/30+i)*8,1,7)
end
end
}
launch_orb={
init=function(q)
if q.spr==31 then
q.x+=4
if get_fruit()>11 then
q.spr=30
q.fruit=true
end
end
q.start,q.off=q.y,0
end,update=function(q)
q.off+=0.02
q.y=flr(q.start+sin(q.off)*2)
local hit=q.player_here()
if hit then
freeze,hit.djump,hit.spd.x,hit.spd.y,hit.dash_time,hit.x,hit.y,hit.flying=2,max_djump,0,-3,0,q.x,q.y,q.spr==30 and 99 or 2
sfx(19)
if q.spr~=30 then
target_ph=q.spr==31 and 128 or 208
end
q.init_smoke()
destroy_object(q)
end
end,draw=function(q)
pal(8,rainbow())
spr(0,q.x,q.y)
pal()
if q.fruit then
for i=0,0.95,0.084 do
circfill(q.x+4+cos(frames/60+i)*8,q.y+4+sin(frames/60+i)*8,1,i%0.168==0 and 2 or 8)
end
end
end
}
launch_effect={
init=function(q)
q.size=0.5
end,draw=function(q)
oval(q.x-q.size*2,q.y-q.size,q.x+q.size*2,q.y+q.size,q.size>3 and 6 or 7)
q.size+=0.5
if q.size>6 then
destroy_object(q)
end
end
}
checkpoint={
init=function(q)
foreach(checkpoints[lvl_id],function(c)
local t=split(c)
if q.x/8==t[2] and q.y/8+2==t[3] then
q.c_num,q.hitbox.h=t[1],24
end
end)
end,update=function(q)
if not q.active and q.player_here() then
sfx(18)
respawn,sfx_timer,q.active=q.c_num,30,true
q.init_smoke()
if q.c_num~="z" then
q.init_smoke(0,8)
end
end
end,draw=function(q)
if not q.active then
pal(2,1)
pal(14,3+frames\8%2*10)
end
spr(81,q.x,q.y+8)
default_draw(q)
?q.c_num,q.x+3,q.y+10,2
pal()
?q.c_num,q.x+3,q.y+9,q.active and 14 or 13
end
}
flag={
init=function(q)
q.x+=5
q.c_num="z" end,update=checkpoint.update,draw=function(q)
if not q.active then
pal(8,1+frames\8%2*12)
end
spr(q.spr+frames/5%3,q.x,q.y)
pal()
end
}
flag_alt={
init=flag.init,draw=flag.draw,}
heart={
init=function(q)
q.x+=4
q.y+=4
q.offset,q.start=0,q.y
if lvl_id==27 then
q.x+=32
elseif lvl_id==26 and get_fruit()>11 then
q.destroy=true
end
end,update=function(q)
if q.destroy then destroy_object(q) end
q.offset+=0.01
q.y=q.start+sin(q.offset)*2
local hit=q.player_here()
if hit and hit.dash_effect_time>0 then
init_dead_particles(q.x,q.y)
sfx(21,1)
time_ticking,fading,q.collected,sfx_timer=false,0.25,true,90
end
if q.collected and globalfade>=4 then
fading=-0.25
ldgfx()
load_level(-2)
end
end,draw=function(q)
if max_djump~=1 then
pal(12,deaths==0 and 10 or 8)
pal(1,deaths==0 and 9 or 2)
elseif deaths==0 then
pal(12,11)
pal(1,3)
end
if not q.collected then
spr(split"117,118,119,120,119,118,117,117" [1+frames\4%8],q.x,q.y)
end
pal()
end
}
watchtower={
update=function(q)
local pcheck=q.player_here()
if pcheck and btnp(4) then
if watchtower_active then
watchtower_active,pause_player=false,false
destroy_object(q.target)
else
pcheck.x,pcheck.y,pcheck.spd,pcheck.spr,watchtower_active,pause_player,q.target=q.x,q.y,vec(0,0),7,true,true,q.init_object_here(watchtower_target)
end
end
end,draw=function(q)
if q.player_here() and not watchtower_active then
circfill(q.x+4,q.y-8,5,1)
?"🅾️",q.x+1,q.y-10,7
end
end
}
watchtower_target={
update=function(q)
q.x,q.y=clamp(q.x+(btn(1) and 4 or btn(0) and -4 or 0),60,lvl_pw-64),clamp(q.y+(btn(2) and -4 or btn(3) and 4 or 0),60,lvl_ph-64)
move_camera(q)
end
}
cassette_block={
init=function(q)
q.collideable=q.spr==67
local top=tile_at(q.x/8,q.y/8-1)
local bot=tile_at(q.x/8,q.y/8+1)
q.top=top==0 or top==17
q.bot=bot==0 or bot==27
end,draw=function(q)
if q.spr==67 then
pal(12,14)
end
spr(q.collideable and 68 or 67,q.x,q.y)
pal()
end,draw_outline=function(q)
rect(q.x-1,q.y-1,q.x+8,q.y+8,0)
end,}
function switch_cassette_block(q)
local hit=q.player_here()
if hit then
kill_player(hit)
end
local ox,oy=lvl_x*16+q.x/8,lvl_y*16+q.y/8
if q.top then
mset(ox,oy-1,q.collideable and 0 or 17)
end
if q.bot then
mset(ox,oy+1,q.collideable and 0 or 27)
end
q.collideable=not q.collideable
end
cassette_controller={
init=function(q)
sfx(-1,0)
q.timer=0
q.spr=nil
end,update=function(q)
if fading~=0 then
sfx(-1,0)
return
end
if q.timer>=32 then
foreach(objects,function(c)
if c.type==cassette_block then
switch_cassette_block(c)
end
end)
q.timer=0
q.swap=not q.swap
if q.swap then
music(-1)
sfx(24,0,4,15)
end
end
q.timer+=1
end,}

newline=[[

]]
message={
init=function(q)
q.memorial,q.names=q.spr==82,bt(split(
[[-- mount everred --#this memorial to those#who skipped the gem
-- everred spire --#turn back now lest you#fall like those before
-- special thanks to: --#maddy and noel#augie745 and rubyred#gonengazit and meep#jackk and zep
-playtesters-#akliant, augie745,#beeb, cominixo,#flyingpenguin223, foolie,#gargin, glowyorange,#gonengazit, jackk,#lord snek, meep,#michael, mrgoodbar,#piehat, roundupgaming,#rubyred, and vawlpe
-golden reddish-#augie745, beeb,#gonengazit, jackk,#kamera, lord snek,#meep, mrgoodbar,#and vawlpe
-trueskip-#acedicdart, akliant917,#augie745, beeb,#cominixo, feetballer,#glowyorange, gonengazit,#jackk, lord snek,#meep, roundupgaming,#rubyred, snoo24,#sparky99,#thecookiemonster,#and theyeeter49
gonengazit#gemskip golden reddish#(gemskip deathless)
meep#moon reddish#(trueskip deathless)
akliant#moon reddish#(trueskip deathless)#+gemskip golden
lord snek#moon reddish#(trueskip deathless)#+gemskip golden]],newline),"10,31,27,93,122,123,107,105,124,106")
if q.memorial then
q.id=lvl_id
q.hitbox.x+=4
else
q.id=tile_at(q.x/8,q.y/8-1)
end
end,draw=function(q)
if q.memorial then
sspr(16,32,8,16,q.x+8,q.y-8,8,16,true)
end
if q.player_here() then
for i,s in pairs(split(q.names[q.id],"#")) do
ui_rct(7,7*i,120,7*i+6,7)
?s,64-#s*2+camx,7*i+1+camy,0
end
end
end
}
coverup_wall={
draw=function(q)
rectfill(q.x,q.y,q.x+7,q.y+23,3)
end
}
p8_console={
update=function(q)
minicheck=q.check(player,4,0)
end,draw=function(q)
if minicheck then
circfill(minicheck.x+4,minicheck.y-8,5,1)
?"🅾️",minicheck.x+1,minicheck.y-10,7
end
end
}
psfx=function(num)
if sfx_timer<=0 then
sfx(num)
end
end
tiles=bt(
{player_spawn,key,side_spring,side_spring,spring,watchtower,chest,balloon,balloon,balloon,fruit,launch_orb,launch_orb,launch_orb,fly_fruit,fake_wall,fake_wall,checkpoint,cassette_block,cassette_block,coverup_wall,cassette_controller,message,message,fall_plat,heart,big_chest,flag,flag_alt,p8_console},"1,8,11,12,18,19,20,22,13,14,26,29,30,31,45,64,80,65,67,68,76,77,82,121,83,117,96,73,89,126")
function empty() end
function init_object(type,x,y,tile)
if type.if_not_fruit and got_fruit[lvl_id] and tile~=80 then
return
end
local obj=bt({
type,true,false,tile,vec(),x,y,rct(0,0,8,8),vec(0,0),vec(0,0)
},"type,collideable,solids,spr,flip,x,y,hitbox,spd,rem")
function obj.is_solid(ox,oy)
return (oy>0 and not obj.is_platform(ox,0) and obj.is_platform(ox,oy)) or
tile_flag_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h,0)
or obj.check(fake_wall,ox,oy)
or obj.check(fall_plat,ox,oy)
or obj.check(cassette_block,ox,oy)
end
function obj.is_platform(ox,oy)
return tile_flag_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h,3)
end
function obj.check(type,ox,oy)
for other in all(objects) do
if other and other.type==type and other~=obj and other.collideable and
other.x+other.hitbox.x+other.hitbox.w>obj.x+obj.hitbox.x+ox and
other.y+other.hitbox.y+other.hitbox.h>obj.y+obj.hitbox.y+oy and
other.x+other.hitbox.x<obj.x+obj.hitbox.x+obj.hitbox.w+ox and
other.y+other.hitbox.y<obj.y+obj.hitbox.y+obj.hitbox.h+oy then
return other
end
end
end
function obj.player_here()
return obj.check(player,0,0)
end
function obj.init_object_here(type,ox,oy,tile)
return init_object(type,obj.x+(ox or 0),obj.y+(oy or 0),tile)
end
function obj.move(ox,oy)
for axis in all({"x","y" }) do
obj.rem[axis]+=axis=="x" and ox or oy
local amt=flr(obj.rem[axis]+0.5)
obj.rem[axis]-=amt
if obj.solids then
local step=sign(amt)
local d=axis=="x" and step or 0
for i=0,abs(amt) do
if not obj.is_solid(d,step-d) then
obj[axis]+=step
else
obj.spd[axis],obj.rem[axis]=0,0
break
end
end
else
obj[axis]+=amt
end
end
return (obj.type.update or empty)
end
function obj.init_smoke(ox,oy)
obj.init_object_here(smoke,ox,oy,29)
end
(obj.type.init or empty)(obj)
add(objects,obj)
return obj
end
function destroy_object(obj)
del(objects,obj)
end
function kill_player(obj)
delay_restart,fading,globalfade,dead_particles,sfx_timer,time_ticking=15,0,0,{},12,true
sfx(7)
deaths+=1
destroy_object(obj)
init_dead_particles(obj.x,obj.y)
end
function init_dead_particles(x,y)
dead_particles={}
for dir=0,0.875,0.125 do
add(dead_particles,bt({x+4,y+4,2,sin(dir)*3,cos(dir)*3},"x,y,t,dx,dy"))
end
end
function prev_level()
respawn=nil
load_level(lvl_id-1)
end
function next_level()
respawn=nil
load_override=lvl_id==20 and m2 or lvl_id==24 and m3 or lvl_id==26 and m1
if lvl_id==26 or lvl_id==30 then load_data(extra_sfx,0x39f8) end
load_level(lvl_id+1)
end
function load_level(lvl)
has_dashed,has_key,minicheck=false,false,false
foreach(objects,destroy_object)
same_room=lvl_id==lvl
lvl_id=lvl
cspdx,cspdy,clock=0,0,is_start() or lvl_id==10
local b=split(levels[lvl_id+3])
lvl_x,lvl_y,lvl_w,lvl_h,lvl_title,lvl_effects,lvl_wind=b[1],b[2],b[3]*16,b[4]*16,b[6],b[8],b[9] or 0
lvl_pw,lvl_ph=lvl_w*8,lvl_h*8
target_ph=lvl_ph
fg_col,fg_alt,bg_col,bg_alt,bgm,area=unpack(split(themes[b[5]+2]))
bgm=b[7]~=0 and b[7] or bgm
if not is_title() and not is_credits() then
load_override=lvl_id<=20 and m1 or lvl_id<=24 and m2 or lvl_id<=26 and m3 or lvl_id<28 and m1 or m3
if load_override then
load_mapdata(load_override)
load_override=nil
end
if not respawn then ui_timer=5 end
end
if mapdata[lvl_id] then
local l=1
for i=0,b[3]-1 do
for j=0,b[4]-1 do
replace_room(lvl_x+i,lvl_y+j,sub(mapdata[lvl_id],l,l+512))
l+=512
end
end
end
for tx=0,lvl_w-1 do
for ty=0,lvl_h-1 do
local tile=tile_at(tx,ty)
if tiles[tile] then
init_object(tiles[tile],tx*8,ty*8,tile)
end
end
end
if checkpoints[lvl_id] then
local spawned
foreach(objects,function(c)
if respawn and c.c_num==respawn then
c.active,spawned=true,true
c.init_object_here(player_spawn,0,c.type==flag and 0 or 16)
end
end)
if not spawned then
local c=split(checkpoints[lvl_id][1])
init_object(player_spawn,c[2]*8,c[3]*8)
end
end
end
function _update()
frames+=1
if time_ticking then
seconds+=frames\30
minutes+=seconds\60
seconds%=60
end
frames%=30
if btnp(2,1) then
d_f=not d_f
end
if current_bgm~=bgm then
music(bgm,0,7)
current_bgm=bgm
end
if sfx_timer>0 then
sfx_timer-=1
end
if minicheck and btnp(4) then
start_minigame()
end
if minigame then minigame_update() return end
if freeze>0 then
freeze-=1
foreach(objects,function(c)
if c.type==cassette_controller then
c.type.update(c)
end
end)
return
end
if delay_restart>0 then
delay_restart-=1
if delay_restart==0 then
load_level(lvl_id)
end
end
foreach(objects,function(obj)
obj.move(obj.spd.x,obj.spd.y)(obj)
end)
lvl_ph=appr(lvl_ph,target_ph,16)
if is_title() then
if start_game then
start_game_flash-=1
if start_game_flash<=-30 then
begin_game()
end
elseif btn(4) or btn(5) then
bgm,start_game_flash,start_game=-1,50,true
sfx(22)
end
end
end
function _draw()
if minigame then minigame_draw() return end
if freeze>0 then return end
pal()
if is_title() and start_game then
local c=d_f and 1 or start_game_flash>10 and (frames%10<5 and 7 or 10) or start_game_flash>5 and 2 or start_game_flash>0 and 1 or 0
if c<10 then
for i=1,15 do
pal(i,c)
end
end
end
camx,camy=flr(cx+0.5)-64,flr(cy+0.5)-64
camera(camx,camy)
local xtiles=lvl_x*16
local ytiles=lvl_y*16
cls(bg_col)
if not is_title() then
foreach(clouds, function(c)
c.x+=c.spd-cspdx
ui_rct(c.x,c.y,c.x+c.w,c.y+4+(1-c.w/64)*12,bg_alt)
if c.x>128 or c.x<-128 then
c.x,c.y=-c.w,rnd(120)
end
end)
foreach(objects,function(c)
if c.type.draw_outline then
c.type.draw_outline(c)
end
end)
pal(3,fg_col)
pal(11,fg_alt)
map(xtiles,ytiles,0,0,lvl_w,lvl_h,2)
pal()
end
map(xtiles,ytiles,0,0,lvl_w,lvl_h,4)
foreach(objects, function(obj)
(obj.type.draw or default_draw)(obj)
end)
map(xtiles,ytiles,0,0,lvl_w,lvl_h,8)
foreach(particles,function(p)
p.off+=min(0.05,p.spd/32)
p.x-=cspdx
p.y-=cspdy+lvl_wind*p.wspd
local a_wind=abs(lvl_wind)
p.wspd=appr(p.wspd,8*a_wind,0.5)
local draw_f,o1,o2=line,camx,camy
if lvl_wind==0 then
p.x+=p.spd
p.y+=sin(p.off)
draw_f,o1,o2=ui_rct,p.s,p.s
end
draw_f(p.x+a_wind*camx,p.y+a_wind*camy,p.x+o1,p.y+o2+p.wspd*2,p.c)
if p.x>=136 then
p.y=rnd128()
elseif p.y>=136 then
p.x=rnd128()
end
p.x,p.y=(p.x+8)%144-8,(p.y+8)%144-8
end)
foreach(dead_particles, function(p)
p.x+=p.dx
p.y+=p.dy
p.t-=0.2
if p.t<=0 then
del(dead_particles,p)
end
rectfill(p.x-p.t,p.y-p.t,p.x+p.t,p.y+p.t,14+5*p.t%2)
end)
foreach(effect_clouds,function(c) c.x=(c.x+3-cspdx+8)%159-8 end)
if lvl_effects==1 or lvl_effects==2 then
local s,a=3-2*lvl_effects,lvl_ph*lvl_effects-lvl_ph
rectfill(-64+cx,a,64+cx,a+s*8,7)
foreach(effect_clouds,function(c)
circfill(c.x+cx-64,a+s*c.y,8,7)
end)
end
if watchtower_active then
for i=0,1 do
rect(i+camx,i+camy,127-i+camx,127-i+camy,i*7)
end
local off=sin(frames/30)*2.5
if lvl_h>16 then
spr(76,60+camx,5+off+camy)
spr(76,60+camx,116-off+camy,1,1,false,true)
end
if lvl_w>16 then
spr(77,5+off+camx,60+camy,1,1,true)
spr(77,116-off+camx,60+camy)
end
?"🅾️:exit",camx+3,camy+120,7
end
if ui_timer>=-30 then
if ui_timer<0 then
draw_ui()
end
ui_timer-=1
elseif lvl_effects==4 then
ui_rct(1,1,40,7,0)
ui_tm(2+camx,2+camy)
end
if is_title() then
spr(0,8,-57)
sspr(24,0,24,8,-7,-49)
sspr(0,8,64,24,-31,-41)
spr(1,-39,-25)
spr(2,33,-25)
?"original game by",-31,-7,12
?"maddy thorson",-25,3,6
?"noel berry",-19,9,6
?"mod by",-11,24,12
?"taco360",-13,34,6
?"🅾️/❎",-9,49,11
end
if is_credits() then
if deaths==0 then
if max_djump==1 then
bg_col,bg_alt=3,11
else
bg_col,bg_alt=9,10
end
end
cx,cy=64,64
sspr(64,8,64,24,32,32)
rectfill(32,56,95,95,5)
rect(31,31,96,96,0)
ui_tm(45,58)
ui_gm(45,68)
?split"trueskip,gemskip,normal" [max_djump],52,68,7
ui_rd(45,78)
ui_dt(45,88)
end
if fading~=0 then
for c=contrast,15 do
if flr(globalfade)>=3 then
pal(c,7,1)
else
pal(c,split(fadetable[c+1])[flr(globalfade+1)],1)
end
end
globalfade=clamp(globalfade+fading,0,4)
if globalfade==0 then
fading=0
end
end
end
function default_draw(obj)
spr(obj.spr or -1,obj.x,obj.y,1,1,obj.flip.x,obj.flip.y)
end
function draw_ui()
ui_rct(5,58,123,70,0)
if lvl_title then
?lvl_title,64-#lvl_title*2+camx,62+camy,7
else
?(lvl_id*100).." m - " ..area,(lvl_id<10 and 12 or 9)+camx,62+camy,7
end
ui_rct(1,1,40,7,0)
ui_tm(2+camx,2+camy)
ui_rct(42,1,48,7,0)
ui_gm(43+camx,2+camy)
ui_rct(1,9,16,15,0)
ui_rd(2+camx,10+camy)
ui_rct(18,9,48,15,0)
ui_dt(19+camx,10+camy)
end
function ui_tm(x,y)
spr(78,x,y)
?two_digit_str(minutes\60)..":" ..two_digit_str(minutes%60)..":" ..two_digit_str(seconds),x+7,y,not is_credits() and not time_ticking and 11 or 7
end
function ui_gm(x,y)
pal(11,({11,8,14})[max_djump])
spr(79,x,y)
pal()
end
function ui_rd(x,y)
spr(94,x,y)
?get_fruit(),x+7,y,7
end
function ui_dt(x,y)
spr(95,x,y)
?deaths,x+7,y,7
end
function two_digit_str(x)
return x<10 and"0" ..x or x
end
function ui_rct(x1,y1,x2,y2,c)
rectfill(x1+camx,y1+camy,x2+camx,y2+camy,c)
end
function rainbow()
return d_f and 14 or frames\2%7+8
end
function flash()
return d_f and 8 or 2+frames\3%2*6
end
function clamp(val,a,b)
return max(a,min(b,val))
end
function appr(val,target,amt)
return val>target and max(val-amt,target) or min(val+amt,target)
end
function sign(v)
return v~=0 and sgn(v) or 0
end
function maybe()
return rnd(1)<0.5
end
function tile_flag_at(x,y,w,h,flag)
for i=max(0,x\8),min(lvl_w-1,(x+w-1)/8) do
for j=max(0,y\8),min(lvl_h-1,(y+h-1)/8) do
if fget(tile_at(i,j),flag) then
return true
end
end
end
end
function tile_at(x,y)
return mget(lvl_x*16+x,lvl_y*16+y)
end
function spikes_at(x,y,w,h,xspd,yspd)
for i=max(0,x\8),min(lvl_w-1,(x+w-1)/8) do
for j=max(0,y\8),min(lvl_h-1,(y+h-1)/8) do
local lk={((y+h-1)%8>=6 or y+h==j*8+8) and yspd>=0,y%8<=2 and yspd<=0,x%8<=2 and xspd<=0,((x+w-1)%8>=6 or x+w==i*8+8) and xspd>=0}
for i=1,2 do
for j=3,4 do
add(lk,lk[i] or lk[j])
end
end
local checks=bt(lk,"17,27,43,59,115,116,99,100")
if checks[tile_at(i,j)] then return true end
end
end
end
levels=split(
[[0,-1,1,1,-1
0,-1,1,1,0
5,3,3,1,1,beginnings
0,0,1,1,2
1,0,1,1,2
2,0,1,1,2
3,0,1,1,2
4,0,1,1,2
5,0,1,1,2
6,0,1,1,2
7,0,1,1,2
0,1,1,1,2
0,2,1,2,3,graveyard of the fallen,4
1,2,1,2,3
4,1,2,1,3
1,1,1,1,3
6,1,2,1,3
2,2,1,2,3
2,1,1,1,3
3,2,1,2,3
6,2,2,1,3
3,1,1,1,3
5,2,1,1,4,ancient trench,0,1
0,0,2,4,5,midpoint 1 - everred peaks,0,2
2,0,2,4,5,midpoint 2 - everred peaks,0,0,-1
4,0,4,4,5,midpoint 3 - everred peaks,0,0,1
0,0,7,1,5,midpoint 4 - everred peaks
6,0,2,4,6,summit approach,4,1
5,0,1,4,7,summit,0,4
4,2,1,2,8,hall of champions,0,3
1,1,3,1,9,overgrown footpath
0,1,1,3,10,secluded ridge
0,0,5,1,11,archaic ravine
4,1,1,1,12,spire approach,-1
4,2,1,1,12,aspiration
4,3,1,1,12,contemplation
0,0,1,1,12,determination
0,0,1,1,13,spire apex
0,0,1,1,13,exasperation
0,0,1,1,13,coordination
0,0,1,1,13,dedication
0,0,1,1,14,final climb,-1
0,0,1,4,14,etherealization
3,2,1,2,14,true summit,-1,4]],newline)
mapdata=bt(
{"000000003b3125262871290031252525001a0000003b2426296100006224252500000039003b3133006100111131252539003a280000712900623b2122233132283a2838393a720000003b31252522221028292a281029000000001b31322525292a393a292a000000000000613b2425003a28290000000000000000623b31253a3828290000000000111111000027312829380000001111112034362b002423290029001111212222232b61000024250000003b3436312525262b6200112425004500001b1b1b3132332b00002125254655000000000061622a390000242525222356000000006257012a39002425252525232b000000192123002a39244825","25482525262b0000000000002425252525252548262b3a000000003e2425482525252532332b2829001111202425252525253371722828103b343522254825254826717128382828391b1b312525252525267271102a002a2839003b3125254825263871290000002a3839003b2425252526287239000000002900003b312525252628292a28390000000000003b2425482600000029286700000000003b31252526000000002a283968000000003b2432330000000000292829000000003b241b1b0000000000002800000000003b24000000460100003a2800000000003b2400000021230000382839000000003b2400000024252300282828000000003b24","48323225263125262b2a72313232323226396231482331332b003829612a722a265d393e2426201b00002a006211290025222222252523111111111111272b0032323248323233202734353536302b001b1b1b371b1b1b1b371b1b1b1b372b000000001b000000001b000068391b003a000e000000002a3867682828282828100000001100000000112a102900112a2811111127111111112711111111272b3835352232353535354835353535262b2a613b302b6100623b30631b1b2a302b00613b302b6211003b302b000000372b3a623b372b3b272b3b372b000000613a2801001b163b302b161b16001100612a38233900003b302b0000003b2739623a28","25482525323328282924253232322525252532331b1b102839313328283824252526631b003a3821232b2a382a28242525262b0000002a31332b0029162a242525262b000000001b1b0000000000242525262b00000000003a675868393a3132482673111111002a29112a2838292a382525232122232b003b202b2829003a283232333132332b00001b002a39002a281b1b1b1b1b1b0000000000001029112a0000000000113a10283911002a3b2016000000003b202828293b272b16001b0000110000001b002a003b372b000000003b202b000000000000001b0000000000001b00000000000000001111111111110000000000000000003b27343535353500000000001111111174373900000000000000003b273435353620283900003a000000123b370000003a38292a393a2900003b2122230034353536212223283900003b242526001b1b1b1b2432332a2800003b2425260000000000301b1b003800003b312526111111113a37000000280000003b313334353536282700003a28000016000000002a38292a302839002a00000000000000003a393a37290000000000000000000000002a21232b0000001111111111111111111131332b0000002222222222233435362122230000000025252525252600000024252616000000252525252526001a0024253300000000252525252526675868242611110000002525252525331b1b1b313321232b000025254825262b000000002824332b000025252525262b000000002a372b00000025253232332b0000001100290000000025262122232b003a672700000000000025262448262b002a383000000000000025263132262b1200283011111111111125252223307327002a24222222222222253232333135262b0031323232323225330000002a38302b0000002a28393b2423000000002830731111110028383b2426000000002a31353535360028293b242600000000001b1b1b1b1b002a003b2426000000000000000000000000003b2426003a00212311111111110012003b24263a2839242522222222230053003b242628282824482525254826111111742426283828313232323232332021222225261029002829000000002a2831252525262800002a001111110000283824252526290000001121222300002a2824254826111111112125252600003b2125252525222222233132323300003b2425252525254825252328382900003b24482525253232322526102a0000003b242525252629002a2426290000111174242525252600133f242600003b2122233125482533393436313300003b2425252331252538282829000000003b2425482523313228290000000039003b2425252525222228013d3e003a28003b2425252548252522222223102838393b24252525252525","2a38293b31323232323232323232323200290000165000166200165000162a711111111111111111111111111111006222222235353535353535353522232b003232331b1b1b1b1b1b1b1b6424262b0072296100000000000000003b24332b1639006200000011000000003b3072390010393911111127111111003b30292a392a2828212235323535362b3b302b3a283a281031262b2a725000003b302b2a38002a293b302b00290011003b302b002a0000003b302b00003b271174302b00000000003b302b00003b313535332b00000000013b302b00003a292a7229000000503a2122262b00002a393a103900000021232425260b00003a38295353000000","252548322532323232322532332b3b312548261c371b1b1b1b1b371c2b00001b2532331c2b00000000003b1c2b00003a261c1c1c2b00000000003b1c2b3a28282522362b0000000000003b1c2b002a38323310390000000000003b1c2b0000291c2b2a382900111111003b20110000111c2b0028293b2122232b3b21232b3b211c2b3a29003b2448262b3b24262b3b2423283839003b2425262b3b24262b3b2426112a28393b2425332b3b31332b3b3125362b38293b31331c2b001b1b00001b331b3a286768293b1c2b0011000000001b00002a2828293b1c2b3b272b0012000100003a3829003b1c2b3b302b3b272b232b2a282839003b1c2b3b302b3b302b","25323232322525323232252548252525261c1c1c1c24261c1c1c3132322525253222222222252522231c1c1c1c2425252831323225252525261c2122222548253829000024482532331c313225253232280013462425331b1b1c1b1b31261c1c2900192125262b00001b00003b2423630000003125262b00000000003b24262b0000003a31262b00001100003b24262b0000002a28372b003b2700003b24262b0000003a413839003b3039003b31332b00002a10512829003b302800001b1b000000002a382839573b30383900000000000000181819212222262810001111000000000000003125252628293b21232b0000000000000024252628393b24262b2525252525252525252525482525252525252525252525252525252525252525252532322525252525252532323232322533393a3125252525253300000000003354385d2931323248260000001600001c1c1c1c1c1c1c1c24263900000000001b1b1b1b1b1b6421252638391111113a1600000000003b2425262810212223290000111100003b244833292a24252611003b21232b003b242600000031252522003b24262b003b24263900003b242525003b24262b003b31332800003b242525003b24262b00001b1b2839003b242525003b24262b0000003a2838003b242525003b24262b000000282829003b242525003b24262b00003a283839003b242525252525252525323232323248252525252525252548261c1c1c1c1c24252525253232323225261c2122222225252525250000002824261c2425253225252525330000002a3125222525261c24252526293a39393a2824324825261c24254826572828283810371c3132331c31322525222a283828293b1c2b003b1c2b10312525113a282a003b1c2b003b1c2b2a28242523382900003b1c2b00001b000028313226280000003b1c2b00000000002a28282629000000001b0000001100003a38412600000000000000003b1c2b00002a512611000000001100003b1c2b00003a2825230000003b1c2b003b1c2b003a212225260000003b1c2b003b1c2b002a24252525252525252525482525252525252525482525252525323232252525252525323225252532332828383132252548252928314826292a2a382a2a2824252526002a2931330000002900002a312525331356001b1b000000000000001b313353222300000000000000000000001b1b0048261111000000111111110000000000253236202b003b202123202b00000000331b1b1b0000001b24261b0000000000290000000000003a31252300001111003900000000002a102824260000212311283900000012002a2824261111242522283829003b272b3a2824252222252525232839003b302b2a3824254825252525482310293b302b002a242525252525482525252525252525482525252525252525252532323232322525252525252525323233002a38282824252525252525262828290000002a2931322548252525262900000000000000002a2425252525250b0000000000000000002425254825320000000000000000000024253232333900000000000000000000242628393a290000111111000000111124332a28290000002122232b003b343533530b2a390000002425332b00001b1b1b00003a28281111242638390000000000003a2929002222482629000000111100002839111125252533000000002123113a292a21222525262b0000001124252328391124252525262b00000021252526292a212525252532322525323232323232252525253233292a31330000003a2828312525482a2900001b1b0000002a2828382425251100000000000016002a10292a242525232b000011110000000029003a314825332b003b212311111100002a102931250000003b31332122231111002900112400000000212248252522362b003b2148000000002425253232331b00003b3125390000003125262900000000003a2831102900003b243300000000003a282838000000003b372b0000000000002a412811111111001b000000000000003a5129222235362b000000000000003a38283925331b1b00000000000000002a21222326000000000000000000000000242548262b003b1c3132323232323232323225262b003b1c631b1b1b1b1b1b1b1b6424262b1e3b1c2b00000000000000163b24262b003b1c2b00001111111100003b24262b00001b00003b213535362b003b24262b00000000163b30631b1b00003b242673111111111174302b160000003b242535353620343535262b000011117431262b00001b00003b302b003b34353522332b00000000003b302b00001b1b6424390000001100003b302b000000003b243800003b272b003b3073111100003b242900003b302b003b313535362b003b240045003b302b00001b1b1b1b00003b243955563b302b00000000000000163b2422222222262b00000000000000003b24","2526393a38313232323232331b1b1b2432332828291b1b1b1b1b1b20393900241b1b2a38390011110000001b2a1039240000002a291121232b000000002a282411111111112125262b120011002a282422222222222525262b533b272b0038243232323248252526731174372b002a317129002a31252548222222232b003b217200450000242525323232332b003b3129005501562425331b1b1b1b0000001b000021222225262b0000000000000000000031252548262b000000111111111100001b313232332b00003a3422222222000d001b1b1b1b00003a10723132324800000000000000002a382829612123310000000000000000003a382962242523"},"35,39,36,40,37,34,24,38")
themes=split(
[[12,7,7,7,-1
12,7,0,1,0
3,11,12,6,4
3,11,13,14,8,evergreen foothills
13,15,0,2,19,forgotten cliffside
9,10,0,0,4
2,14,9,10,31
14,7,6,7,4
14,7,12,6,-1
3,11,6,7,43
3,11,0,1,8
13,15,0,1,19
9,10,2,14,4
2,14,13,14,43
2,14,6,7,43
14,7,9,10,43]],newline)
checkpoints={
[21]={
"f,27,59","e,10,28","d,14,14",},[22]={
"c,4,61","b,11,43","a,11,32",},[23]=split(
[[9,2,61
8,10,44
7,36,46
6,53,31
5,16,23]],newline),[24]={
"4,4,12","3,47,13","2,94,13",},[25]={
"1,26,61",},[26]={
"0,2,61",},}
cx,cy,cspdx,cspdy,cgain=0,0,0,0,0.25
function move_camera(obj)
if clock then
if obj.type==player and (obj.y>128 or obj.x>128) then
clock=false
else
cx,cy=64,64
return
end
end
cspdx,cspdy=cgain*(4+obj.x-cx),cgain*(4+obj.y-cy)
cx+=cspdx
cy+=cspdy
if cx<64 or cx>lvl_pw-64 then
cspdx,cx=0,clamp(cx,64,lvl_pw-64)
end
if cy<64 or cy>lvl_ph-64 then
cspdy,cy=0,clamp(cy,64,lvl_ph-64)
end
end
function replace_room(x,y,room)
local offset=y<2 and 8192 or 0
for y_=0,15 do
load_data(sub(room,32*y_+1,32*y_+33),offset+x*16+y*2048+y_*128)
end
end
function load_mapdata(mapdata)
load_data(mapdata,0x4300)
px9_decomp(0, 0, 0x4300,mget,mset)
end
-- function get_data(start, len)
-- local str="" for addr=start,start+len-1 do
-- str..=chr(@addr)
-- end
function get_data(start, len) --hex instead of base256
local str="" 
for addr=start,start+len-1 do
  str=str..sub(tostr(peek(addr),true),5,6)
end
return str
end
-- function load_data(str,start)
-- for i=1,#str do
-- poke(start+(i-1),ord(sub(str,i,i)))
-- end
function load_data(str,start) -- hex instead of base256
for i=1,#str,2 do
poke(start+(i-1)/2,tonum("0x"..sub(str,i,i+1)))
end
end
extra_gfx="70000000000000000000000000000007000000eee6000000000000000000000030000b0b0000000010717701107177010000000000000000107177011071770170000000aaaaaa008888880000007007000000eee6000000000000000000000000b333000111111010717701107177011011111111111101117177011071771177000000aaaaaa0a88888808000070060000e0eee60e00000000000000000000208888021171711110717701107177011011111111111101117177011071771177000000aa00000088008008000077660000e8eeee0e00000000000000000000808988081111991110717701107177011071777777777701777777011071777777000000999900002200200200706768000088eeee0e00000000000000000000808898081071770110717701107177011071777777777701777777011071777777060000990000002200200200888628028028e2ee0200000000000000000000809888081071770110717701107177011071777777777701777777011071777767060000990000002222220200888828228828e2e2020000000000000000000020888802107177011071770110717701107177111171770111111101101111116e0e000099000000222222008088882222822222e222000000000000000000000082280010717701107177011199910910717701107177010000000000000000000000000000000000000000808888222222222222220000000000000000000066666666666666dddddddddddddddddddddddddddddddddd7767666666666666000000010000000000000000888828222222222222220000000001000000000066666666666666d7dddddddddddddddddddddddddddddddddd77676766666666000000110000000000000080686626222222222222220000000011000000000066666666666777d7dddddddddddddddddddddddddddddddddd7d7777666766660000101100000000010000666666d6222222222222d20d00001011000001000066666666667777ddddddddddedee77ee7767eedddddddddddddddddd777766660000101101000010010000666666dddd2d222222d2dd0d000011110000010000666666667677ddddddddeeeeee7e77776766e6eeeededddddddddddddd7777dd00001011010000101100606666d6dddddd2d22dddddd0d001011110110010000666667d777d7ddddedeeeeeeee7e67766666e6eeeeeeeedddddddddddddddddd00001111110000111101666666d6dddddddddddddddd0d1011111101101100007d7677ddddddddedeeeeeeeeeeee66666666e6eeee7eeeee7767dddddddddddd00001111110110111111666666dddddddddddddddddddd111111110111110000dd77d7ddddddedeeeeeeeeeeeeee6ee666e6eeeeee7eee7e676666dddddddddd00101111111111111111666666ddddddddd3dddddddddd111111111111110000ddddddddddedeeeeeeeeeeeeeeeeeeeeeeeeeeeeee7ee77e666666d6dddddddd00103111111111111161666666ddbdbb3b33bbdddddddd1d1111111111130100ddddddddddeeeeeeeeeeeeeeee9999999999eeeeee7ee7ee666e66dddddddddd00103313111111111161666666bbbbb33b33bbdbdddddd1d11bbbbbb31330100ddddddddedeeeeeeeeeeee9e99999999999999e9ee77e7eeeeeeeedddddddddd0011331311bbbbbb1166b3bbbbbb3b33bbb4bbbbbbbbdd1dbb3bbbbb3b330100ddddddddeeeeeeeeeeee99999999999999999999997767eeeeeeeededddddddd00114111bb3bbbbbbb3b33bbbb3b33333333b3bb3bbbbbbbbb33b3bbbb140100ddddddedeeeeeeeeee9999999999999999999999992766eeee1eeeeeddddddd100113333b333b3bbb33b33bb3b333333333333b333b3bbb3bb33b3bb33330100ddddddedeeeeeeee9e9999999999a9aaaa999999992762eeee11eeeededddd11303333333333333b33bbb43b333333333333333333333b33bb4bbb3333333300ddddddeeeeeeeeee9999999999a9aaaaaaaa9999792862eeee11e1eeeedddd113333333333333333333333333333333333333333333333333333333333333303ddddddeeeeeeeeee9999999999aaaaaaaaaa9a99892222e21e1111eeeedd1d110000000000000000000000000000000000000000000000000000000000000000ddddedeeeeeeee1e9999999999aaaaaa7aa79a99882222e2111111e1eede1111a0aaaa00aaaaaa00aaaaaa00aa00a00aaaaaaa00aaaaaa008888880088888800ddddedeee1eeee1191999999a9aaaaaa77a7aa992822221211111111eede1111aaaaaa0aaaaaaa0aaaaaaa0aaa00a00aaaaaaa0aaaaaaa0a8888880888888808ddddee1e11ee1e1191999919a9aaaa7a8777aa892822222211111111ee1e1111aa00a00aaa00a00aaa000000aa00a00aaa000000aa00a00a8800800888000000ddddee1111e11e111191991111aaaa7a8878a6882222222211111111111111119900900999999909999900009909990999990000999999092222220222220000dddd1e11111111111111191111a1aa8a887822222222222212111111111111119900900999999900990000009099990099000000999999002222220022000000dd1d111111111111111111111111aa888828222222222222121111111111111199999909990099009999990000990900999999009900990022002200222222001d1111111111111111111111111181888822222222222222221111111111111190999900990099099999990900900000999999099900990922002202222222021111111111111111111111111111818828222222222222222211111111111111"
function ldgfx()
--printh("loaded graphics")
load_data(extra_gfx,0x0)
end
function regfx()
--printh("unloaded gfx")
reload(0x0,0x0,0x0fff)
end
extra_sfx="0a040a04110411041304130413041304130413041104110413041304110411040a040a0411041104130413041304130413041304110411041304130411041104011700001236df00000000009e3500000000000012000000123612009e3500000000000012366901123669019e3569016901690112009e01123612009e3500009e01000001170000080408040e040e041104110411041104110411040f040f04110411040f040e04080408040e040e041104110411041104110411040f040f04110411040f040e04011700002b042b04df01df0129042904df01df0126042604df01dd0124042404db01d801220422044010dd052b042b044010df05220422045f10dd05160416046910dd05011700001236df00000000009e3500000000000012000000123612009e3500000000000012366933123669339e35690569056905e952e9521236e9529e35e954e954e954011700001d261d261d261d261d261d261d261d261d241d241d221d22000000000050000000000000000000000000000000000000d302d502d602d802da04db04dd04de04011700001236df04df54df549e35df52df52df5212000000123612009e350000000000001236d802d852d8529e35d852d852d85212009e01123612009e3500009e0100000117000013041304130413040c040c040c040c0413041304130413040a040a040c040c040a040a040a040a0413041304130413041104110411041104130413041304130401170000df05e205df05dd05df05df05df05df05df05dd05db05da05d805da05db05dd05db05db05d805d805da05da05db05db05d805d805d605d605d705d705d805d805011700001236dd04dd54dd549e35dd52dd52dd5212000000123612009e350000000000001236e204e254e2549e35e252e252e25212009e01123612009e3537003500370001170000dd05e005dd05db05dd05dd05dd05dd05e005e205e405e205e005dd05db05dd05e205e005df05e005e205e405db05df05dd05dd05e005e005dd05dd052204220401170000050405040504110408040804080408040a040a040a040a040c0418040c0418040a040a0408040a0408040a0408040704050405040304030411441d5405040504011700001236dd04dd54dd549e35dd52dd52dd5212000000123612009e350000000000001236e204e254e2549e35e252e252e25212009e01123612009e35eb549e359e3501170000dd05e005dd05db05dd05dd05dd05dd05e005e205e405e205e005dd05db05dd05e205e005df05e005e205e405db05df05dd05dd05db05db05dd05dd05dd05dd05011700002b042b04df05df0529042904df05df0526042604df05dd0524042404db05d805220422044010dd052b042b044010df05220422045f10dd05160416046910dd05011700001236df00000000009e3500000000000012000000123612009e350000000000001236e7231236e7239e35e723e723e723e723e723e723e7239e35e723e723e723011700001d261d261d261d261d261d261d261d261d241d241d221d52000000000050000000000000000000000000000000000000cf02d102d302d402d602d802da02db02011700001236db52db529e359e35db529e35db521236db521236db529e35db22db32db521236e252e2529e359e35e2529e35e2521236e2521236e2529e35e222e232e252011700000f040f040f040f040c040c040e040e040f040f040f040f040f04130416041304160416041604160411041104130413041604160416041604130413041104110401170000df05df05dd05df05db05e205df05dd05db05db05d805d805df05df05db05db05e205e205df05df05e205e205e405e405e205e205df05df05dd05dd05d805d805011700001236db0000009e359e35db229e35db3212360000123612009e350000000000001236e20022009e359e35e2229e35e23212369e01123612009e3500009e01000001170000db05df05db05df05db05db05db05db051b041b041b541b541b521b521b521b52df05e205df05e205df05df05df05df052204220422542254225222522252225201170000db05df05db05df05db05db05db05db051b041b041b541b541b521b521b521b52df05e205df05e205df05df05df05df051f041f041f541f541f521f521f521f52011700001236eb01eb019e359e35db009e35db0012360000123612009e350000000000001236e20022009e359e35e2009e35e20012369e01123612009e3500009e01000001170000130413040a040a040f040f040f040f040f040f040c040c040f040f0411041104130413040a040a040f040f040f040f040f040f040c040c040f040f041104110401170000eb07e907e707e907eb07eb07eb07eb07ee07eb07ee07eb07e907eb07e907e707e407e707e407e707e207e207e407e407e707e707e907e907eb07eb07eb07eb07011700001236eb47eb379e359e35db009e35db0012360000123612009e350000000000001236e20022009e359e35e2009e35e20012369e01123612009e3500009e01150001170000eb47eb37eb07e907ee07e907eb07eb07e907e707e407e207df07e207e407e607eb07e907eb07e907ee07eb07e907eb07f307f207f007ee07eb07e907eb07ee0701170000eb47eb37ee07eb07ee07f007f307f507f307f007f307f307f507f507f707f707fa07f707f307f307fa07f707f307f307f707f507f307f207f007ee07eb07e90701170000130413040a040a040f040f040f040f040f040f040c040c040a040a0407040704080408040e040e041104110411041104110411040f040f04110411040f040e0401170000eb47eb37eb07e907eb07e907e707e707e407e707e407e707e207e207df07df07dd07df07dd07df07dd05dd05dd05dd05dd05dd05dd05db05dd05df05dd05d805011700001236df04df54df549e35df54df54df5407500000123612009e350000000000001236df541236df549e35df54df54df5412009e01123612009e3500009e010000011700001236dd04dd54dd549e35dd54dd54dd54120000001236dd549e35dd54000000001236dd541236dd549e35dd54dd54dd5412009e011236dd549e35dd549e010000011700001d261d261d261d261d261d261d261d261d241d241d221d220000000000000000000000000000000000000000000000000000000000000000000000000000000001170000"
fadetable=split(
[[133,134,6
141,13,6
141,13,6
134,6,6
134,143,15
134,134,6
6,6,7
7,7,7
142,14,15
10,135,15
135,135,15
11,135,6
12,6,7
13,6,6
14,6,7
15,7,7]],newline)
fading,globalfade,contrast=0,0,0
function spr90(n,x,y,rot,fl)
if rot then
for _x=0,7 do
for _y=0,7 do
pset(x+_y,y+_x,sget(get_x(n)+_x,get_y(n)+(fl and _y or 7-_y)))
end
end
else
spr(n,x,y,1,1,false,fl)
end
end
function get_x(pos)
return pos%16*8
end
function get_y(pos)
return pos\16*8
end
function is_wall(pos)
return pos<16 or pos>=240 or pos%16==0 or pos%16==15
end
function start_minigame()
ldgfx()
poke(0x5f43,15)
music(8,0,7)
camera(0,0)
minigame,minicheck,minigame_over,miniframes,snake,minifruit,dir,new_dir=true,false,false,0,{136,152},104,2,2
end
function minigame_update()
if minigame_over then
if btnp(🅾️) then
start_minigame()
elseif btnp(❎) then
regfx()
poke(0x5f43,0)
minigame=false
end
else
miniframes+=1
for i=0,3 do
if(btnp(i) and i\2~=dir\2) new_dir=i
end
if miniframes%4==0 then
if new_dir~=dir then psfx(3) end
dir=new_dir
local head=dir<2 and snake[1]+2*dir-1 or snake[1]+32*dir-80
for i=#snake+(head==minifruit and 0 or -1),1,-1 do
snake[i+1]=snake[i]
if head==snake[i] or is_wall(head) then
sfx(7)
music(-1)
minigame_over=true
return
end
end
snake[1]=head
if head==minifruit then
sfx(15)
sfx_timer,minifruit=30,0
while is_wall(minifruit) or head==minigame_fruit do
minifruit=flr(rnd(256))
end
end
end
end
end
function minigame_draw()
cls(6)
rectfill(1,1,127,127,5)
rectfill(8,8,120,120,6)
rectfill(8,8,119,119,0)
?'pengu-8◆',89,122,7
if minigame_over then
?"game over :sadelie:\nscore:" ..(#snake-2).."\n\npress 🅾️ to restart\nor press ❎ to exit",9,9,8
else
local last_dir=snake[1]-snake[2]
for i,curr in pairs(snake) do
local x,y=get_x(curr),get_y(curr)
local seg_dir=i~=#snake and curr-snake[i+1] or last_dir
if seg_dir==last_dir then
spr90(i==1 and 9 or i==#snake and 11 or 10,x,y,seg_dir%16>0,seg_dir%17==16)
else
local d=bt(split("12,12,13,13"),"-14,31,33,-18")
local a=seg_dir+2*last_dir
spr(d[a] or d[-a]+2,x,y)
end
last_dir=seg_dir
end
spr(8,get_x(minifruit),get_y(minifruit)+2.5*sin(miniframes/40))
end
end
function
px9_decomp(x0,y0,src,vget,vset)
local function vlist_val(l, val)
for i=1,#l do
if l[i]==val then
for j=i,2,-1 do
l[j]=l[j-1]
end
l[1] = val
return i
end
end
end
local cache,cache_bits=0,0
function getval(bits)
if cache_bits<16 then
cache+=lshr(peek2(src),16-cache_bits)
cache_bits+=16
src+=2
end
local val=lshr(shl(cache,(32-bits)),16-bits)
cache=lshr(cache,bits)
cache_bits-=bits
return val
end
function gnp(n)
local bits=0
repeat
bits+=1
local vv=getval(bits)
n+=vv
until vv<(shl(1,bits))-1
return n
end
local
w,h_1,
eb,el,pr,x,y,splen,predict
=
gnp"1",gnp"0",gnp"1",{},{},0,0,0
for i=1,gnp"1" do
add(el,getval(eb))
end
for y=y0,y0+h_1 do
for x=x0,x0+w-1 do
splen-=1
if(splen<1) then
splen,predict=gnp"1",not predict
end
local a=y>y0 and vget(x,y-1) or 0
local l=pr[a]
if not l then
l={}
for e in all(el) do
add(l,e)
end
pr[a]=l
end
local v=l[predict and 1 or gnp"2" ]
vlist_val(l, v)
vlist_val(el, v)
vset(x,y,v)
            x+=1
            y+=x\w
            x%=w
        end
    end
end


-->8
-- evercore tas tool injection
function load_room(x,y)
    load_level(x+8*y)
    room=vec(x,y)
end

room=vec(0,0)
local __update=_update

_update=function() 
    __update()
    room=vec(lvl_id%8,flr(lvl_id/8))
end
function level_index()
    return lvl_id 
end

draw_time=ui_tm
__gfx__
00777700000000000000000001111110000000000000000000000000000000000077777000077700000070000000000000000000000060000000600000060000
070000700111111001111110111b111101111110011111100000000001b111100070007000070700000070000000600000060000000060000000600000060000
70770007111b1111111b111111bfff11111b11111111b111011111101b1dff110076067000070700000070000505700000075050000600000000600000060000
7077880711bfff1111bfff111bfdffd111bfff1111fffb11111b1111b1fffff10067776000067600000070005050700000070505000600000000600000060000
700888071bfdffd11bfdffd111fffff01bfdffd11dffdfb111bfff1111fffff10000700000007000000070005050700000070505000600000006000000006000
7008880711fffff011fffff001bbbb0011fffff00fffff111bfffff1113333100066700000067000000070000505700000075050000600000006000000006000
0700007001bbbb0001bbbb000700007007bbbb0000bbbb7011fdffd101bbbb000006700000007000000070000000600000060000000060000006000000006000
00777700007007000070007000000000000007000000700007733370007007000077700000067000000070000000000000000000000060000006000000006000
555555550000000000000000007777000000000000000000001111004fff4fff4fff4fff4fff4fff0b00b0b06665666577777775000000000000000070000000
555555550000000000000000077777700000000000000bbb0111111044444444444444444444444400b333006765676576666665007700000770070007000007
5500005500000000000000007117711704444440bb00b33301711110000450000000000000054000008228006770677076666665007770700777000000000000
550000550070007006777760611661164aa9999403b3333001111110004500000000000000005400082222800700070055555555077777700770000000000000
550000550070007000500500666666664a9999940033300001111110045000000000000000000540022222200700070077757777077777700000700000000000
55000055067706770005500006655660444444440003300001111110450000000000000000000054082222800000000066657666077777700000077000000000
555555555676567600500500000550004a95599400033b0000111100500000000000000000000005006776000000000066657666070777000007077007000070
555555555666566600055000005555004a9999940b3333b000000000000000000000000000000000000660000000000055555555000000007000000000000000
57777775577777777777777777777775773333333333333333333377577777755555555555555555555555555500000000077000000000000000000000000000
77777777777777777777777777777777777333333333333333333777777777775555555555555550055555556670000000777700000777770000000000000000
77737777777733333777777333337777777333333333333333333777777777775555555555555500005555556777700000777700007766700000000000000000
77333377777333333337733333333777777733333333333333337777777337775555555555555000000555556660000007737770076777000000000000000000
77333377773333333333333333333377777733333333333333337777773333775555555555550000000055555500000007737770077660000777770000000000
777337777733bb3333333333333b3377777333333333333333333777773333775555555555500000000005556670000007733770077770000777767007700000
777777777733bb333333333333333377777333333333333333333777773b3377555555555500000000000055677770000773b770070000000700007707777770
5777777577333333333333333333337777333333333333333333337777333377555555555000000000000005666000000733bb77000000000000000000077777
77333377773333333333333333333377577777777777777777777775777333775555555550000000000000050000066677333377000000000000000000000000
77733377773333333333333333333377777777777777777777777777777337775055555555000000000000550007777673b333370000000000aa0aa000000000
777333777733b333333333333bb333777773377333377773377337777773377755550055555000000000055500000766733333370000000000aaaaa000000030
7733377777333333333333333bb33377773333333b3333333333337777333777555500555555000000005555000000553333b33300000000000a9a00000000b0
773337777773333333377333333337777733333333333333333333777733337755555555555550000005555500000666033333300000b00000aaaaa000000b30
77733777777733333777777333337777777337733777733337733777773333775505555555555500005555550007777600044000000b000000aa3aa003000b00
77733777777777777777777777777777777777777777777777777777777337775555555555555550055555550000076600044000030b00300000b00000b0b300
77333377577777777777777777777775577777777777777777777775577777755555555555555555555555550000005500999900030330300000b00000303300
577775575511111500000000ddddddddcccccccc07777770000000000004400033333333004888000048000000400888000000000067000006d6000007770000
777777775111111100000000d111111dc111111c7777777700cc0cc00004400033333333004888880048800000488888000770000067700067d7600070007000
7777337751e11ee100000000d11d1d1dc1dccd1c7777777700ccccc0777777773333bb33042008880428888804288800007777000067770067ddd00070bb7000
7773333351eeeee100000666d1d1d11dc1cccc1c77772277000c1c0076b66b653333bb3304000000040088800400000007777770006777706777600070bb7000
7733333351eeeee100066555d11d1d1dc1cccc1c7777227700ccccc0766336653b33333304000000040000000400000077777777006777700666000007770000
5733bb33512ee2e100655555d1d1d11dc1dccd1c7277222700cc2cc0768228653333333342000000420000004200000066666666006777000000000000000000
5773bb33511221e100555555d111111dc111111c7222882700008000766776653333b33340000000400000004000000000000000006770000000000000000000
777333335111112106565666ddddddddcccccccc0222882000008000755555553333333340000000400000004000000000000000006700000000000000000000
777333335111111105555555577777755555555502222220000000000000000000000000004ce700004c0000004007ec5555005555555555b0b0b00007770000
577333335111111105566566777557775555555502822220000000000000000000000000004ce7ec004ce000004ce7ec55550055555555550333000061716000
5733b3335111111105555555776555775511115502222220008000000008000000000000042007ec042ce7ec042ce70050555555555555558222800066666000
773333335111111105555665755556575117171502228220000800000088020000000000040000000400e7e00400000055511155555ff555222220000ddd0000
7773333351111111055555557566555751119915002222000808080000800080555555550400000004000000040000005517171555ff7f550777000000d00000
7777337751111111005777557766557711177711000440000808028002200080555555554200000042000000420000005519911555ffff550000000000000000
7777777751111111077777777775577711197791007777000208202000200280555555554000000040000000400000005511111555ffff550000000000000000
577775775511111577777777577777755119dd950777777022022020002022205555555540000000400000004000000055966965555ff5550000000000000000
000000000003b000000b30005555666566655555773333333333337750000000000000055555555555aaaa5555555555a5aaaa59000000000000000077777775
00aaaaaa0003b00000033000555567656765555577733333333b37775500000000000055a5aaa9595aaaa9955aaaa555aa1a1a99000000000000000071111175
0a99999900033000000330005550677067700555777333b3333337775550000000000555aa1a1999aa1a91991a1aaa99aa44aa99000000000000000061181165
a99aaaaa000b3000000b0000550007000700005557773333333377755555000000005555aa449999aaa4499944aaa9955a7779950eeee0000000000061a1d165
a9aaaaaa00003000000b00005500070007000666577733333333777555555555555555555a776995aaa9999977aa99995a777995ee888e0000000000611c1165
a99999990000b000000300006670000000077776777333333b33377755555555555555555a766995aa777699777a99995a777995e88888e00080000061111165
a9999999000b30000000000067777000000007667773b3333333377755555555555555555a76699557776665577699955a777995888888800010000066666665
a99999990003300000000000666000000000005577333333333333775555555555555555544d449955766655554454455a776995888888800010d00000555500
aaaaaaaa5553b555555b35555500000000000666011001100010010000100100000110007777776655555555555555555a776995888888800777660005555550
a49494a15553b5555553355566700000000777761cc11cc101c11c1000111100000110005777776555555555555555555a776995288888809999999999999999
a494a4a1555335555553355567777000000007661cccc7c101ccc7100011110000011000557776555555555555aaa9555a776995022222004444444444444444
a49444aa555b3555555b555566600070007000551ccccc7101ccc710001111000001100055aaa95555aa95555a1a19955a766995028888800550000000010550
a49999aa55553555555b555555000070007000551cccccc101cccc10001111000001100055aa99555a1a19555a4499955a766995288888888440000000010440
a49444995555b55555535555555006770677055501cccc10001cc1000001100000011000557766555a449955aa7769995a766995ddddddddd440000000001440
a494a444555b3555555555555555567656765555001cc100001cc1000001100000011000577666655aa99955a47649995a766995005555000440000000000440
a494999955533555555555555555566656665555000110000001100000011000000110005776666554dd499554dd4995544d4499055555500440000000000441
ffffff0fff73eafff7608d19095299926a3c1a27a28cc25badcd0132854447605b0d8d09da7c8f9fa67a54086ca9209791905e28197c3c26bc89c59aba9d97eb
0932507a7db7d779b4f233dc4d6bbfdd7fffd12be1f1243fc32759ee9d7dd3a3e80940930d7ec776b33174f6bbfcde78bef8bf0eb2bc378ebe83ce79f7e79cef
9f5ed5ef17cff1eef9e97e94ed7ec3f79f329cf1bfb298737a339b8c6eacdfdd7db129836bd61b7eae1fbcf37f8c8b6f7df5bfbccf7933ebf5ef12f3c2f4464f
78f3e71c39cc3a90980f7503e7b8f7aa97c3fbcf3b34edd114255fbd5174a749fef39f17fc5e9be783c3a884f6dc2cefcdf06df74e4bf74e3f3c3e95e5276d36
2f8577df1798c39f5f75327c19cf01f74f0709c1cf51c17cfbe76f87d2c6f77444cf06f76852fb40fcb201d72fbb3078f1e7eff1cf26eff098c83e8cff2efbff
7070ffb8fbf292df29504288139ff9440bf29cef8ffc1bff236e87affb8fbe37895ab4f7c1b33ff0ff79521c19ffd84fbff502fbcf263f398189deff33fccf2f
beff70f48e1c12998c1dff19f1c6fcfa59cfa2f3397ef3bff34ad5ef0e2bc7ff788c77cff9e8502fc27ce83ca9fe000b3ef74fd342ef759efc429b69329fef99
a8319843fffaf2bf5c1e8fec3e8f4e7cffd0742fc4c842f013b62e8522b89cccff6e99ac6275cc3e3f7e62f7789ec7fb9766ff13789ff3026e90274674b93f70
f377b3e7a33bc59e3fdffce069d217c17dfcae16932de19932f7b4f7e3a5836974ea4d67f29a1214400365386274e967bc66f4eaffb96ef719de8cd972972bfd
887fe3229ff5cfd3786229b2ff7acff6eff083fb7f99cffeef769f2fcd13a4a213514faa9f83eff7fd131ea11b7aa9ff1ef0affb8c1ea9fef0236dfbc1d0dc77
0e1ff70dcf199f2ea93eff1f63f8885e37e1ffdff221ea6202709fbfd486e3d72f4e8a6eff6ff729f958767ff71f4e84f0b8011b2570237fff1088ff75c4e19e
3bf7309df3f2129a361175ce724cffa032bcef44eac37f9b1c5932936976fce8cb3c3daff46e65fb4846bc94fff893743e912d656ca69fffcbfc67e7bc57cff2
e70f31a0198aad7f01dbfff4f6dbffbcf1ef95ff9aff76e8d9a27ce853019ab2b71df5ff777026f5314699fff1520fdf89cfde78f16a70f37e99ff30b3c3e84f
f7aff7dff728f94239e0b5d16f35a2f3e7c1e49f9f7cf3befd6a74217ce8f9c11093cf3a0298d5e146a9c57cf89af583e9c4679fde0cf211dffe8ff278e17842
31143fc03e93eff8e71f30fb8509f9f642f315761f792f3452ce7ca5ec9a7e27a52bfd4a1569cea7a264490c1a6f7f2c8484ea5b6c1007c0e865013fff93c3d6
6c80184742623b5f0127cfccb146d3e01269e2dd57cf0fbcf3ffcff5cea3877fff8ff7c5ffef1ffbdbef74ff719ffeaceaffd0977e09f1f7f9c33f7cf69f3e4c
f5fbd37e58f38c384ef17e1f7d97ff8ff3a3f99fdaf7c32fdef74f34ffdf9ef7bfffdf1df12dc7569b43fbc4fa883ff976fcf5ffcf0e3fc5f3cecfe269f7a7ca
9f1eb3abff1f99ff1f8dab3e09cedd654d3f4fa329f692b3c0ab3e74ce1f30fffdc79f1efaf13b5c797ef7cea4d6d72dc39464e904e1e11754e8ef65956ff3ed
17c17852974f2ff3eff37fbf663e94ead7fac13fffd76bfb097ef7cbdff3af75e8075316bbeaacf54c2dc3fc57c1ff7ef1e7a3ac85e0fced1ffb37df3cc93b30
2cff9dcf61fd3fd5f34e898ff9c3d6ef8f30f3c1f3c266b12a90e87d510bcbabd8c5894e94aea46aa7ca9ff37e8c9f9c05b6778f35debf226b78cfd7572154ec
cffa13fc5ff7e23fb8302e844a4c9cf7c3d832bdc37b02998409f38e2fbe91cc0c12eb5422fdef9881b02808365eb488885be858854ef8075ef772a31feeabef
c5a873c13570f098b4e817c393778cf0dadf1dcf4f8c3348eea62ea9c24aff909e54c1921e953e1470ac7cb420f75cf61fcf8f045e1639bad010251f4674e195
4619ae1eaeef4249c1e8ce8f272d85ab724504602f7488b5ca83eac832d9c864221d290b43e9544257579c794fb42a9ff1bf2c097aedf76fc993e87effd742ff
3fb872cf0b76696b9cc3cfbfcfda8fc3e9702947f788ff74096e97e371febb62ef9f7e7097e851dc1a4131cb0e2e7b566c11e9c5fc836bc220df5f7ed34d6743
c27469c1bc0c190156f48d793effcecf1624d3bc5a39b228d02f9383c3f8b46e954c426ef1ba601c157838d1f909f72a93c3effe333b89accffd52f7b3409d50
e5ae3c17883c3d7e8413885c2170eae6176dfffeff46275fff1fe594eab6bd9c5ef70bb8c1d3e9842e5f6e217c99f2253409f3e77bac393a0c2c3744ae87e19f
c2c8bc2ef0ccda9dff0eff30dc2b384e9020e22bcff52e0f8dbfc6b5e99ec5c69ed1c2cf68c37c22f302431a26216e3768fde312f42cc2f31629b21c4c4e9cff
0cf462fb5c197fffedcf0752f79ffef70f7b3ecef17c52d1c19f7f8f7ff67dff1e7ffbed3378e6bff952fc32ffb8f74fa37ffb07cff3e78ff1fff93ecfebff3f
ff9ffaff1fff7f788c77644e9274ff8df1f7c3fe57d1f78cf5e2231273bf1e7bff18efefff8ff7c5fee838ff27f9ec6d1b73e3dee9b2fbe35271f54e626b3ef7
f193a1e9f9c79de037669775b919428b29856ea3adf666335f688bc6b324695e97ecad3197761fdd6ff93461a7c19c3e97a74a21b4793e127d36d762f4304293
ebd17c1db29c8d3d7b9f1ec52b0bdf9985290f75e2074e9958c14f72ba4249fd3a1dccff237667172d0aef7c8d844868c2f32c2ef7cb5029c558e59bcf73ff31
1ce8fe7d6c74c616bc1694c593eef5e0f8c3ff7eb2e70f94428cfdff32f4ce21fe2f46effcf35840ac16dd5fff7046efff1cef4a7a0ffba4679312f4a2797e29
74af44e35ef6442090691d7ff717f1bcf5b5af3b426838993ffff2c13dffff0facf7e836618fe0eccff5ef77f23df5684e97872fff728be7b70e7098eb9344f9
b236cf1446c5d5223c12bcefff587efff507dff78cff5c198325b43f4fbf72c2b836bf56b66ef93e8fffb1ef3079e6745ae8e1117ca7c170c2ae1f9907b0b98c
1cff3eff1f1396a930e1946ec3c29018d6639ffb046e478cf5ff3423d4cf0274794c39d1b30c16b706f42dde8a890f58429c14439ffff1e00f682b48432ff361
dfaffcff8ef767887226394477c2a51a43d7e836f8daf46efff8cb1942b44278f98b8f1e88d884c976cf4ec7ac3f34d3b885884d536effb9c96f06006eff68a6
7df5274cfff3944cf82bfffb1339e02f8fb6bc3908c3bff1e3fb462f7b846a29d611bf1d31c3bffbafd246322fbb83193e8ee899766ff383ef71b6e2ff5cfff8
ff90c7ffff3efff5c1ffff2eff1b42e70bae23fbc15b76125cc5efbbff73ee292fc3f3efddf7efd76eac03bc7f7ceee319ded3e84e120bd1270aeff7fffe5ea3
ff7cd65439ddd17cf378c1324a952298dbbf7e021098802f6ce3578ce9f583c28c20aa01f7be3078ff7d598cf4b4effb7daf394fc366f0cf0a10e0e85c08cc6b
cfe6dfbf794c9f3cf1f36df3ff78ffd1f97678fe022e523e17c1f4400d33fff82f5c79cd693f52987f832176e78bc4c71862c2701b32421977980f7fff4ef729
8d8893a529766dff1c3146216818f94f2ef72dbfdf3eb3ef87eff4ff7bf5eff5d53e9ff358034ecf18f5d7fbcffdebdf0fb5cafc1fc3cf3bfe4fd3dc11e717d4
2b943f2d886bb309d3b8c3f87cdb1a1ff08adb178fffb21cf01fc3dbf834dbc2f397ee77fbd2b45f8ca6197667bcd5ddf5e70965548327c69b734ef78e93a75e
3acce84ca9d31adffff21232993cff0f1157c3f11ecc537c39c7178be78c1fcde9c4296e7af1ecdcf8f34c3a7bfffe3bc34f8f126834f37cc33e9d86cf1d7ef8
f96c2f34fd72fbef2465e9f5fdf3eade89ff596af407ccef78d099972c12bf1c842d74122d5f58c1f46c855a68dffaef709defd75c29b2eaf3e7f4c2e098f729
cf1dc9264066fbacfd564ae769743462787a14d1fff766fc737cf5b09e974021135184a10787cff6c2f01c6ddc1f8d582c33f438ca9421b7e7901ffcf27fef7b
fb7f30121f46e9b4d21f7ce9f35b7cfffb9ff1d11f461d988d1e72f34483eccc2379e1f9c8c19c324524ed42b90562936c179ef4bff700b9834f78f70e2cf09a
effee8fdff2ffef5229c35f34c693fb50ecc3fbc36fbce7199c27cd6698326da1fd59ff7f1b3fcff593eaf9e1ca39ae19d3fbcf29721f57e12ec36fcf07ccee9
56675aff7ef927c67c27c50b32b832849478e9bada9d60fff72e1ad5b3ddf478300a9ff7328ac80dc35f3ce07f795e7ab2177ef821d3d1da5238b27d317e2f30
ad8191212ef7160b2e47dc97475bf3270b0c5ddeffd55dfffb3c1f6c29d57c55321ff6ec876dcf2f4c59c5dbff920b9e3dcbde3ff945e8db74ceba0dcf037fb9
f3ec3e37039ff1178cc7e1ffff7efff0dfff3ae39df4741cfffd120268cefaff54bf38cbfff7929d9f3a91404c99ff22eff1f7c222fff287cf169ff5934c5fdb
2f4ecc37fff7e62eea7ef747c7576ef157483f932fcffbaffba302709f5ce833961fd1face741dc59ffff4fff7aefff55e183e174fff162bbe01c5df32ffcff1
f9c0f7541b72d3f79f76cb2911b3efff5cff8c7ffff2ef7e7fdd4d2ebdc1295d3f4e794a784d142bffcfbcfee9fffb5ffffbefff89b6e0f3cf17c6f5274f91e2
d3d915b40ba85d4a756e940466b46888f6ae67c1ff7abfcff7cbf56edb37dfffb0e9f72f5c1f80cef8727def87eea529946bc967d575a71a9d5695daff31e8da
f44e716af11f3cf67c2f3d1b33b3efa01e0946ddc7fe699b4eccf8f0e4a477fb293e19b01836f290b3e8c112914e19346f33d5a0ccce4bff54c71eb0baf7f7e4
426f6f00ffffff0fff73eafff315231a071391276b208a27a325a63c1fce221a11844b0a5dc6614464e1680dda2e0e4164eb54527d391fc85471ba176c11a39b
06823e9fbf8c4f0e8f53f83344ceafec3afe7727cdf3cf17fd778f12c11ef7070fef272ff42f3cf0f8cff1e9f3e78df1f7c7f87deb31fb0e84df01668fd21ffc
ef8bec74e9c19fd23f57fb8bfbfced7db5ff6f8f9e98ccfd9aae2f79b7fb53f36a67cef9f3e673927c26ffdef8f38e43ff71a9ff410f7c278687d469de1f2e72
293cf5930e1eff011cc334f7cf3fe42cf8ca9f35ffc99f765f31f7d3d46ef8c1e78cfa9fedc1ff026ef13284de5f70f068f7e5ffefa9fbecf76fbe3ea3ba99f1
342dd4adf6fef3bdf3c9a1420883c2f3b6e07ce7cfbf7feef707cff122f78d01ffb88f362148f7f78fdc67d6940a9c7f7eb6be60f34f8f3e0177ce1c8ef09ae2
e90f4094e7cd3d5e39622f8c78ff78843427853ae3ef642ec44adcf3cdef9ff94eff2b53948bb14ff83657eff6e9a60dc3f00dbc18fc2c6e4f422c803fff1c99
802216ef2e74e73b852f8ffcff82f6ebf3e78f12ea4346872fcf3fa62319622e8ceb3e0fc1b4295fd47f3c1b06e11ff727afde7dfe78ef01d4c914e78ff54f8d
ffaafc32fc42294eaeaf7832fff2acd47ff3bbc2fc3305ebcffdebf3abbc6dfbef737445b8c3b38bf074ef7796eff75fc5fff9f9ee8c1593420c1df53f8b212d
fbbbd3fb72119f12fba3de019383cf8578af152ab3ae8ce43ef77c5dab7428832932e25327de7e4c8fd0c585a6abcff0d4440793e9e8fdcd7c66e7c7ed1675e9
8cc261e97affefaff741296a275c3f8670742ffbc96bfdf36b7e834f9ff942a9a84d59de87699ff7521619cebbe707cff9ec3f31ad5fff1ffc3aa6fb59ce8ff6
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000007000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000007000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000077000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000077000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000077000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000077600000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000076600000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000e6e00000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000070000000ee6e00000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000770000000ee6e00000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000076000000eee6ee0000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000776600008eeeeee0000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000077686000088eeeee0000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000008868822008822eee20000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000008888822288822e2e20000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000008888822222822222e22000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000008888822222222222222000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000010000000000000000088888222222222222222000000001000000000000000000000000000000000000000000
00000000000000000000000000000000000000011000000000000000886666222222222222222000000001100000000000000000000000000000000000000000
00000000000000000000000000000000000000111000000001000006666666d2222222222222dd00000011100001000000000000000000000000000000000000
0000000000000000000000000000000000000011110000001100000666666ddddd22222222dddd00000111100001000000000000000000000000000000000000
000000000000000000000000000000000000001111000000111000666666dddddddd222ddddddd00001111110011000000000000000000000000000000000000
000000000000000000000000000000000000011111100001111106666666dddddddddddddddddd00111111110011100000000000000000000000000000000000
00000000000000000000000000000000000001111111001111111666666dddddddddddddddddddd1111111110111100000000000000000000000000000000000
00000000000000000000000000000000000011111111111111111666666dddddddd3ddddddddddd1111111111111100000000000000000000000000000000000
00000000000000000000000000000000000011311111111111116666666dddbbbb333bbddddddddd111111111113110000000000000000000000000000000000
00000000000000000000000000000000000013331111111111116666666bbbb3bb333bbbdddddddd111bbbbbb133310000000000000000000000000000000000
0000000000000000000000000000000000011333111bbbbbb11663bbbbbbbb333bb4bbbbbbbbbddd1bbb3bbbbb33310000000000000000000000000000000000
00000000000000000000000000000000000111411bbb3bbbbbbb333bbbbb3333333333bbbb3bbbbbbbb333bbbbb4110000000000000000000000000000000000
000000000000000000000000000000000001133333b333bbb3bb333bbb33333333333333b333bbb3bbb333bbb333310000000000000000000000000000000000
00000000000000000000000000000000003333333333333b333bb4bb333333333333333333333b333bbb4bb33333333000000000000000000000000000000000
00000000000000000000000000000000033333333333333333333333333333333333333333333333333333333333333300000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000aaaaaa000aaaaa00aaaaaa00aaaaaa00aa000aa0aaaaaa00aaaaaa0088888800888888008888880000000000000000000000000
0000000000000000000000000aaaaaaa0aaaaaaa0aaaaaaa0aaaaaaa0aa000aa0aaaaaaa0aaaaaaa088888880888888808888888000000000000000000000000
0000000000000000000000000aa000000aa000aa0aa000aa0aa000000aa000aa0aa000000aa000aa088000880880000008800088000000000000000000000000
00000000000000000000000009999000099000990999999909999000099909990999900009999999022222220222200002200022000000000000000000000000
00000000000000000000000009900000099000990999999009900000009999900990000009999990022222200220000002200022000000000000000000000000
00000000000000000000000009900000099999990990099009999990000999000999999009900990022002200222222002222222000000000000000000000000
00000000000000000000000009900000009999900990099909999999000090000999999909900999022002220222222202222220000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000cc0ccc0ccc00cc0ccc0cc00ccc0c00000000cc0ccc0ccc0ccc00000ccc0c0c00000000000000000000000000000000
000000000000000000000000000000000c0c0c0c00c00c0000c00c0c0c0c0c0000000c000c0c0ccc0c0000000c0c0c0c00000000000000000000000000000000
000000000000000000000000000000000c0c0cc000c00c0000c00c0c0ccc0c0000000c000ccc0c0c0cc000000cc00ccc00000000000000000000000000000000
000000000000000000000000000000000c0c0c0c00c00c0c00c00c0c0c0c0c0000000c0c0c0c0c0c0c0000000c0c000c00000000000000000000000000000000
000000000000000000000000000000000cc00c0c0ccc0ccc0ccc0c0c0c0c0ccc00000ccc0c0c0c0c0ccc00000ccc0ccc00000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000066606660660066006060000066606060066066600660066066000000000000000000000000000000000000000
00000000000000000000000000000000000000066606060606060606060000006006060606060606000606060600000000000000000000000000000000000000
00000000000000000000000000000000000000060606660606060606660000006006660606066006660606060600000000000000000000000000000000000000
00000000000000000000000000000000000000060606060606060600060000006006060606060600060606060600000000000000000000000000000000000000
00000000000000000000000000000000000000060606060666066606660000006006060660060606600660060600000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000066000660666060000000666066606660666060600000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000060606060600060000000606060006060606060600000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000060606060660060000000660066006600660066600000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000060606060600060000000606060006060606000600000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000060606600666066600000666066606060606066600000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000ccc00cc0cc000000ccc0c0c0000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000ccc0c0c0c0c00000c0c0c0c0000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000c0c0c0c0c0c00000cc00ccc0000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000c0c0c0c0c0c00000c0c000c0000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000c0c0cc00ccc00000ccc0ccc0000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000066606660066006606660600066600000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000006006060600060600060600060600000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000006006660600060600660666060600000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000006006060600060600060606060600000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000006006060066066006660666066600000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000bbbbb0000b00bbbbb0000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000bb000bb00b00bb0b0bb000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000bb0b0bb00b00bbb0bbb000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000bb000bb00b00bb0b0bb000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000bbbbb00b0000bbbbb0000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0000000000000000000000000000000002020004000400080808000203000000030303030303030304040402040000000303030303030303040404020404040400000400000404040300000000000000000004000404020404000000040400000004040202030204040202020202020200040402020000000002020202020202
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
89678b90ec58e59ae3bfffcfffe64bf3fff810396d3b96642ecc39be475cf1c30f221bcf8ee3f9faff3c05726549f065b107f4c83c57e2f08cfce047ceed382c9ecfabffd3ffebff3606b33c715cfbfffa3989f14bb7932310dd91f5e76c5c048f6760065a166def3cf36e4bfef8dffc408ffe78347fec7ffcbfcb4f612761d7
1ef01ce910813e8b63571fc7734872dbf1fc7fceeffffc3f7afa5c587eb360ff2fd9e1d8e1e150fd9ff4cf7f7ecd42360797ffe9fff79fdf168e856c9e874af7bff9f92079fcfd77ad7dae63ac81a3f0bf2568aa24f2eff2fc1cd2fff513fa7f3b333c4b82936bfb7fcd6e7cf9dbff796dda43cc419e6bdfffe47ffaff7df2ec
97cd12ff83e549bf1ffe17ff8fdecffa881c55cefee337c91c3ffc3289df22598af47c1c79b60d0e7f5d48a4c7ff789b2748fcb69e17769c7b7f98b2e7d83262915ff6ede6cfecf75f9243131cd2589b05383cb20ccfdeff4d1cf5fcf0833c0ffbafef4e3d731d07e10849177ee9effdfde785a1ffafef20d76ff6db3939643e
cb71ac19471df7e17cbe3c7bc96ffb8e7f8e1c8b71e0401e03bf34bf3459e71191ec5f462aa1c71371883c986e3dfe5f7bf1d7965f9fe7b8f7345754931c491efcd03721515cf087cb939f8effc1d13cfbe588ff33ffef3d7dcf3c79e67fb7641707f9adc431c830af789ee7a9e498cd45788cadff73e327c95ff72fdb3fbbd6
ee62b01c12f0c4f69cb8f65bfe39cf3bc72ff2fe67c705bb1efc14e18984646b348d3bf611423ccbe2f89f073bb623f04b7f7d7e76e6f095ffbb67f23ff2db7b6c6f72fdf57f782f4804d12c712d103b7ee4387b5c318e045225e9174de559b8bad8137ea8fffdff1fc8b3e35917911c8c0209187fd413a9c526f85f565d3cc7
7fdfbc8e44deca79fc976daee975a4e389b7fb552105c9c144f46d62c7321d0bdfa46f47c89a5dc9f7c32fffffe0df441c9cc9f9faaeeb3872cc313b8e081cfe47e82521932b96fdbf93ff7fa07cf6f049e8b13c44fc544d7efcbff4f7547e7bffa791ef93253f24b9bef3e8e269b643726fefff1f48d27ac8e2d8df7210f63e
df8fffafefbeb7982548ae41cce48ae3f4d46de99e1c7ffeed8f439a7f1acbf11d1e5b127cd02d39ee7f789e6bdb9e64a17e4262db378e1a61a91c91b09d479e8421effe9170b01e070fdbb20d08c0c1ae4796b7f253c5242c89c41e59fe97120e6dcf2542fc4b7e24001984a7b3ac584867e4bf0ffbd2d4248daf7b7e392b89
245e13b5d8f2af67bff830fec9bdf0a864e43abdf97ff8a98d654f82e7f982fa9737bb74d992033b42d3f59ffc0ffe0f3ffd723fae9cfffcf14f05fcf71cfeb8ffb2fdb6339c2939ab9e304ce27f7319ff37f99fe576c854ee2b8d57906a9a85dff63f10435948d8f3fc733e3ffda47ffeb191834492c99220b97c623d7266f2
acfbff0b8be37f80bfae457eeccfff87e6086f8e0f3687e4cbf71c7b44b22d6b7fbb0fc79134cbe799e64ae5788e3dbfdfc44833ff24e773eca7a3038ae772f57fe538340e76ec5905a24bb6e5f3f15cfbe98fef98479ee9ec9f39f869abaa1ec7126972d995589e1d53d713dff75972d8a7924d52ab923aa220f43859f064f9
27f93f5c876fbec731ff53b3efe33a025aec21792fe7f3ab550ee9b1a78ef96fd993f6491691f81fc9c99efcefffffc1ffe8ffd47093abffe784c87710e5ff2f0c5efe771bc37c9fc393ff4182c915d5ed68c3b6e6d745fe48fe34078cd1246e47fe078723fbf79efc70e4f91f051b2d5b93ff815a177a9cdb11f93ff86be287
94b499911cb30396f5d812ddff7f20f860bf3cff0bf03f26ac08bd120bd771fc0f883aec8ffe8427719c9f0d24f2716cb2c793ecf13a9ddf9384a7c3ffc1f37f7bfaf3bd2dd9f6bff87ffc4e4ea1f21bfd7f1e977fb627079d27d93124994f96d717db7ef8ff0b24b2f7cf272e714515cbc211be0424afe3b8c1fe393ce2a8e7
be3a72269e5cc2d13f3d1e8a4892a4d98e1dcb919de149b3a0cf9a7fe2204793235bece54a13c75347495452c79934e72a498eb4633bfcb37fae246ae4afe5d0eb30de00ffe5b78fe3b2cc79ecb93a761cae338235fedc35e45f39ccfe53cbf263f6f763c077417fffa35e912e9dcc11eee0fb9278e2b725898904e0bfadcff9
2c4a317e7d9eabccef4905823fb143b0a6f25f8e5e6903ea78385cb2e0ef686a81ff24195104fc395126cfbeebc8717cf93c4d27a93ff373d2e388ffea38b8d2bffefaab992cfcb6e7d08925224712b9f2ff2907dbf1fcb63d158c588f645f34f3cb918d712e87f949fd76ec59e26fc9ee5f7af4ff1ff87f781d21473dc63107
7e5c7ffb5f3c21c791dfde5fb8e47b2d93e8137e9724cf7afffbdf3fec15b3881f6232c9fcd81dffaf1da73dc9daff7409e746eaf0d03c7e5bde4d76c8ceffc9f7fdfaebf33f78aec89aa8dd227f2a9243703c39be040e38ed74e7b812117e1ee61bb3eff89ffdb2e81cffcfa40f32fc56cbc2958e547234d920e55832ff7250
913ddf912624f224dffd7f09d9c25f4f7ef8dfffff831cf6bff83fac471e545ce4cb53fd3cfe07c96a1bc3eb4413187f1f7efbe7171eff9385cc92c493a7c9f328fc0dfffffff0ff37aeffbf05d0ed623264a949c2a27238550a528f6840ab8dc7c4b18444a399efd63b7e02174c06160612870ef1a4534437ce426bf56a94d2
6a2cde893cb6cdb37409974a4956e4bf6014f13f0eff2c6b723c2bd7f3579fef38fed6ff6dcff7ce3fb2bc2f0f07fd2dd7995c8ef0ff3f9ef7fb41f2cbf1875ff287feb3e4cb4ffeffddf1cb0f46fec92fb9a5cb77fdffd3f4aff18fd86f12077e04ff7fe8bbfefbd13fcf95bf80e4fdaf846df9ff33f327c62fbfc61f7fe557
be1fe6df9fa341eacf043f26c9ffe84874f2b71ff9ebaf43fffb67e71f7f68ff398ef9c79ef39f1dbfff0ffe0f13394c3ce258fe7a66b125f971fdcb4fd7d16dfe177bf64bfe987fe469fe303b599b24c424253f7dfad73fcb3f7e959f565b8e7fedc7943da9bfc6ebeacf185993f26dab34d96160701c56db1f19f9405211e0
9f2d0ebfed49facff24bfe1f7a35bd781d3992da4c0942849de12f8e26f53f191fc94a8f45d267f2f22f13907f76fe5f4480e1403d4776782cad637334872c2cff1b915c96c126be6596643cf9fff8278f827fbeff7ef33ff2fbffe1ff32a612cd0e292261f2528e5c2c1144e0214f1cd39a7f48825f7bfd0f7ec80e33bf74ff
a7ffd5ff8b11fe67887cc4c12198a0b58146f624097842327f73f09f2d11bf3c7b58df1961b978b203e17ff60e791c3d246044c8ffa4eb915fea979fff74e6df5fbfeb99a48edbfce2f8beef7bf8a5fde117aac7fe1fe7e1b73f1afb794ef6fe6f8e7f73e4f81ffd1f9ef7e139f38f5bd9b36c7f1cff373f1c682cd7f36b76fc
2f2ae7f4d9d15e9bb37fd5b3ec92264772c73c913bbbf67ff8df1d8e9ff3fcece9711cf9ff99ffe10f3b74dbd8932c75f5c7ffa3268148f6bffc318ee5d9ec094f1e7668b35fedb10a7f33e2e5784b87ff41e4d863b4fead7f7ff311e08fe3d243827592e3ff999e2421043d0e3271f9b09ebb16a74aff0875fc4ffc4fd5f6fc
038733481c497efd45fcabdb5b5289fc20b123f943761c492ee4ffeaf7f3382269fac7f9fff8dffe8fc6f3ffd5e57fdcd812323b921ffc6fcc1f924f8e59c511d750f17060bdfd9fe9fffafffd3fcf93db5f75fd2f3e4d12a9d79f1c862779242b8efc28527e6225910f07be748e1ff4c79f7fb2e7fffebfe79f5ff17fc86292
9f82fcf213ff240436922fa212f2d7825d31e2cab648f65cff83ffc3bffff67f5571f1ff24f2e3fe072479c81ff941120d09a7e57d7efee5af3d76c4f7ff10879c71c8aec0c346dc9ebcff7fe0ff1ffc184d9aff4f0e7fe5ff7634c7ffed071793fd1f62d910ba99c163d13ecf2c7ee3c88effc5c1fe1fb39023874716ff0f4b
f2c7f35b73942518122c0611399690443e4ff168b3e377943a7e3b1b954cb8d8e98f6d892cff7fc1d164dbfe0ca93d1c4f856d9efc1149bba371e4f27f95ffc3f1f25736975cc2cbf1f4979f50ffffe178afff3f11c9f34e45fc62243ccdca2b75382a32c97fa2f82b7379244df26a3c4e8e6eeb73fcf27ffa1ffdafe6f43f59
b7ff0b7b36bb4e193cc9f63d87589f3c72e6df64d79fffab24f9e779fa10fd9ff967f6bf0ae9692d797c751cd145722459ecd7ff01f5ef2f240e265978b2e6727c4fc4910c6cf3f07fb02be6ff71b1b8d5fe9df69c984dca596bf83bf9dd42e6afb8f23ffedf1207c7f080e627c98ac34443f92712d12db5d2c80f57446a99cc
3eee3def71f6381fe7e1e3f973cff17f9177deef9737c77edd0ffe81633d1261398ee4f1fa757bf61c88ffc3ff2cff3797acffffe27ff6ff37d214aefce8e290733fbc5fecfd6b3ffffc335f922489fd4ff3bf92e327bffd1fb4fb33fe1fdf1fbdffb8af907a7250f2cfc9ff343e01c9cd1a18173f4a8e63af5c891cdf6fffe4
9664f27fed8fc7fffff82bfbff23fb23fbed4a74beff4377406928f27f01febf80f0bfb5887d3f1ec9f1cbff6a9e27a7f7de8e1c70caff31ffffc47db9fe4787f89ff996ab44ce03b48965caff6bffa3ffad2f018d10fe7fc7f990b9bae7885d57caffab727a962d759cd63ffef8e379f28bff49608704f2bf3d8effc31fff87
1cefff9ff0ff57fcf2f9befccff62e6bf6fbb1bccb4a66cfff6f5f66ff7fe0ff7f38fc2fe27f82ffdfbb5dbf75ffdbffc3ff6075ace7ff325cbbfe2f4fae3fff5f7966f9aec7194f3c3fe4f0fbf7c796b42147e493f87f92ff590ee1e1ce5f0e5ff3a35f8320cf81af3f1dfeff0b02fe5fd2f882909090e1a1fc9acf20d71ca7
c6fe8f87fdcf72adeb97e4f30b953afe75a579f2d8965e16fbfeff0217c1ffcc2993c4ea390e4b62492cc991c35cff8a84c78eefb249f81b8929fa7feadff9ff335607eebf92fd374be8fdc7bfdf41f9b9b1857018ffbf57ff4ff9fe1fa4f31bebb35d07ffa75f9e8a1c94bfef1c91477690a49e83f07f5a44b0e32fc97d6688
d7a313671e3f3e9d24d9215896886cb379fe4f95473cfcff9bd2a37ef9291217e5c7c777452c4904e3605be07f761cfa3ff989ffff91bca229db2b951fbf6d19f22467131c3b6efadf37f8ffcc1221c90f3f1dfd2ddfefd9e3b0fd96ff892147b6c7c5f6f4d497c99ffe3ffde1f3f165fbe19798bd0fc7ffecff6f1487e3ff6f
fccffcaf347290efedfff4c78b19f95fc59faa26c7305bf3ff47b2d9f83ff1ed4ee2ffef647f2409ffabe30409b20b626cd9bf862bffffc7ff686793fe0fffff8b10c7e93d2597ff49cfe3fe5cf9e1e9f345af426ccfb344b8fac7ffe7d7fc5f9e1649feff504ae249ea7ff3f6fcedffe4ff1ffdf0d30f1cbbda1f1a8134f2fb
ae1efeff92ffc7f14cfe3fe9fdfff8ff2393df8e3d399ee3d8ffe62f39227fcdf5564ee24daf1f92f4f81fff7b5cf1e7ff43f9ff4ffc1fc9f2bf8aece971bce5ff23798fffc3ff24fbbe6b15d1d74fb34ad6e7393c0bbf7fff1b4dfeffd4de89dc34f90149feff55f0bfa9cbb2fd1f72d48ec7f209b5edff033c79e4ff963ffd
8f1c07fff7dfc9f1d9f2ff27f2bfc231fe3fa48e1e8eb69f44f8cbb31cd72f8db89cff07c912e317891fe77f93f4ff1ffc2ffe1739fc1f0e13fe5fbb0f90d461cf4166fb4990a3797827feb51cfb1c02000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
000400000f5701e570125702257017570265701b5602c560215503155027540365402b5303a530305203e52035510004000040000400004000070000000000000000000000000000000000000000000000000000
000300000977009770097600975008740077300672005715357003470034700347003470034700347003570035700357003570035700347003470034700337003370033700337000070000700007000070000700
0002000011570135701a5702457000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300000d57010570165702257000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200000642008420094200b420224402a4503c6503b6503b6503965036650326502d6502865024640216401d6401a64016630116300e6300b62007620056100361010600106000060000600001000060000600
0003000005110071303f6403f6403f6303f6203f6103f6153f6003f6003f600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
000300001f1302b13022030290301f1202b12022020290201f1102b11022010290101f3002b300225002950000000000000000000000000000000000000000000000000000000000000000000000000000000000
0002000036370234702f3701d4702a37017470273701347023370114701e3700e4701a3600c46016350084401233005420194001940019400193003f6003f6003f6003f6003f6003f6003f6003f6003f6003f600
00030000096450e655066550a6550d6550565511655076550c655046550965511645086350d615006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
00030000240700e0702d0701607034070200603b060280503f0402f020280101d0101001003010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00020000105101251014510165101a520205202653032540325403440000400002000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00030000075700a5700e5701057016570225702f5702f5602c5602c5502f5502f5402c5402c5302f5202f5102c500005000060000600000000000000000000000000000000000000000000000000000000000000
000600001857035570355703556035550355403553035520355103570000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
001000001f77518775277752730027300243001d300263002a3001c30019300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
000400002f7402b760267701d7701577015770197701c750177300170015700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
000400000c5501c5601057023570195702c5702157037570285703b5702c5703e560315503f540315303f530315203f520315203f520315103f510315103f510315103f510315103f50000500005000050000500
001000000c2500c2400c2300c2200f2500f2400f2300f220182501824013250132401825013250162401d26022270222702226022250222402222022210222002220018300133001330016300163001d3001d300
000500000363005631076410c641136511b6612437030371274702e4712437030371274702e4712436030361274602e4612435030351274502e4512434030341274402e4412433030331274202e4212431030311
000b00002955500500295453057030560305503054030530305203051530500305003050030500305003050030500305003050030500305003050030500305003050030500305003050030500305003050030500
00030000010510205104041070710b061110511a051230512b05130051360513d0513f0523f0523f0523f0523f0523f0523f0523f0523f0523f0523f0523f0523f0423f0423f0323f0323f0223f0223f0123f015
01080020223502235022350223552e346223452234022345223352233522335223352e3261d300223200000000000000001d300000002b3561f0001f350000001f3451f3451f3451f345243500a0351f3500a035
000800003f65039636326262a6423965234652246522a652256521965223652186520e652136520a65205652036520e64204642036420a6420963203632036220262200612006150230500001010010200100001
000c0000243752b37530375243652b36530365243552b35530355243452b34530345243352b33530335243252b32530325243152b31530315242052b20530205242052b205302053a2052e205002050020500205
002000200a1400a1300a1201113011120111101b1401b13018152181421813213140131401313013120131100f1400f1300f12011130111201111016142161321315013140131301312013110131101311013100
001000200177500605017750170523655017750160500605017750060501705076052365500605017750060501775017050177500605236550177501605006050177500605256050160523655256050177523655
001000202e750377502e730377302e720377202e71037710227502b750227302b7301d750247501d730247301f750277501f730277301f7202772029750307502973030730297203072029710307102971030710
01100000070700706007050110000707007060030510f0700a0700a0600a0500a0000a0700a0600505005040030700306003000030500c0700c0601105016070160600f071050500a07005050030510a0700a060
002000001d0401d0401d0301d020180401804018030180201b0301b02022040220461f0351f03016040160401d0401d0401d002130611803018030180021f061240502202016040130201d0401b0221804018040
002000002204022030220201b0112404024030270501f0202b0402202027050220202904029030290201601022040220302b0401b030240422403227040180301d0401d0301f0521f0421f0301d0211d0401d030
0008002001770017753f6253b6003c6003b6003f6253160023650236553c600000003f62500000017750170001770017753f6003f6003f625000003f62500000236502365500000000003f625000000000000000
001000200a0700a0500f0710f0500a0600a040110701105007000070001107011050070600704000000000000a0700a0500f0700f0500a0600a0401307113050000000000013070130500f0700f0500000000000
001000002953429554295741d540225702256018570185701856018500185701856000500165701657216562275142753427554275741f5701f5601f500135201b55135530305602454029570295602257022560
002000200c2650c2650c2550c2550c2450c2450c2350a2310f2650f2650f2550f2550f2450f2450f2351623113265132651325513255132451324513235132351322507240162701326113250132420f2600f250
00080020245753057524545305451b565275651f5752b5751f5452b5451f5352b5351f5252b5251f5152b5151b575275751b545275451b535275351d575295751d545295451d535295351f5752b5751f5452b545
00100000072750726507255072450f2650f2550c2750c2650c2550c2450c2350c22507275072650725507245072750726507255072450c2650c25511275112651125511245132651325516275162651625516245
000800201f5702b5701f5402b54018550245501b570275701b540275401857024570185402454018530245301b570275701b540275401d530295301d520295201f5702b5701f5402b5401f5302b5301b55027550
001000100107501075010753f6152f6553f6153f61501075010753f615010753f6152f6553f6152f6553f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
00100010010752f655010753f6152f6553f615010753f615010753f6152f655010752f6553f615010753f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
00100020112751126511255112451326513255182751826518255182451d2651d2550f2651824513275162550f2750f2650f2550f2451126511255162751626516255162451b2651b255222751f2451826513235
002000002904029040290302b031290242b021290142b01133044300412e0442e03030044300302b0412b0302e0442e0402e030300312e024300212e024300212b0442e0412b0342e0212b0442b0402903129022
000800201f5151f5151f5251f5251f5351f5351f5451f5451f5551f5551f5651f5651f575000051f575000051f565000051f565000051f555000051f555000051f545000051f535000051f525000051f51500005
002000001327513265132551324513235112651125511245162751626516255162451623513265132551324513275132651325513245132350f2650f2550f2450c25011231162650f24516272162520c2700c255
001000102f65501075010753f615010753f6152f65501075010753f615010753f6152f6553f615010753f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
000800202451524515245252452524535245352454524545245552455524565245652457500505245750050524565005052456500505245550050524555005052454500505245350050524525005052451500505
002000200c2750c2650c2550c2450c2350a2650a2550a2450f2750f2650f2550f2450f2350c2650c2550c2450c2750c2650c2550c2450c2350a2650a2550a2450f2750f2650f2550f2450f235112651125511245
0008002000075303003b6253b6253b6150000000075000002d6302d615000003b6002f61500000000750000000075000003b625000002f62500000000750c0002d6302d6252f6150000000075000002f62500000
010800200c0500c050303460c040303360c030243260c0250c0500c0500c0400c045303460c040243260c0250a0500a0500a0400a0402e3360a0300a0200a0250a0500a0500a0400a0402e3360a0300a0200a025
01100000183501834018330183201b3501b3401b3301b32024346303032434524345243263030024316303031835018330133501333016350163301d3501d330223462b30022345223452232522315223162b300
010800200c0500c050303460c040303360c030243260c0250c0500c0500c0400c045303360c040243260c0250a0500a0500a0400a04529336110351102011025050500505005040050452b336070300702007025
01100000183501834018330183201b3501b3401b3301b320243463030324345243452432630300243163030318350183301335013330163501633022350223301d34629000293452934529325293152931629000
010800200c050000000c050000000c0500c0000c050000000c0550c0550c050000000c050000000c050000000a0500000000000000002e7572940527720277002e7572940529400294002e757294052940029400
010800200c050000000c050000000c0500c0000c050000000c0550c0550c050000000c050000000c05000000050500000005050000002e7572940527720277002e7572940505050294002e757294052940029400
011000002b375303752b335303352b326303262b315303152b300303002b3752e3752b3352e3352b3252e325263752e375263352e335263262e325263162e315003000030024375293752b33524335293252b325
011000002b375303752b335303352b326303262b315303152b300303002b3752e3752b3352e3352b3252e325293752e375293352e335293262e325293162e315003000030022375293752e33522335293252b325
012000003005430030300202e0502e0302e0252b0542b0302405024030240252e0542e0302e0202b050240302705029051290550a5000a535055300005524030270502905129055165000a255160550a25616055
01200000002440c2460c1240c126002440c2460c1240c12000244161460a124161261614416146161240c126002440c2460c1240c126002440c2460c1240c12000244161460a1241612611144181461612413125
010800201f3501f3501f3501f3552b3461f3451f3401f3451f3351f3351f3351f3352b3261f3001f3200000000000000001d30000000293561d3001d350000001d3451d3451d3451d345293361d3001d33000000
001000003c7753c7453c7353c7253c7153c7153c7153c7153a7753a7553a7453a7353a7253a7253a7153a71537775377553774537745377353773537725377253771537715337753375533745337353372533715
001000003577535755357453573535725357253077530765377553773533775337553374533735337253372529775297452973529725297152971524775247552474524745247352473524725247252471524715
001000200c0600c0300c0500c0300c0500c0300c0100c0000a0600a0300a0500a0300a0500a0300a0100f00011060110301102011000110000a0000a0600a040000000a0000a0600a0400e0600e0400e0200e010
001000000506005030050500503005010050000706007030070500703007010000000f0600f0300f010000000c0600c0300c0500c0300c0500c0300c0500c0300c0500c0300c010000000c0600c0300c0100c000
0010000003625246150060503615246251b61522625036150060503615116253361522625006051d6250a61537625186152e6251d615006053761537625186152e6251d61511625036150060503615246251d615
00100020326103261032610326103161031610306102e6102a610256101b610136100f6100d6100c6100c6100c6100c6100c6100f610146101d610246102a6102e61030610316103361033610346103461034610
00500000181350c1001f1251310013100101001c1351d1351f12528125291252b1151f1001f1002e1052d1052911528125291151f1251d125111001c11510100101001c1001a1250e1000e100181150c1000c100
__music__
01 397a7c44
00 3a7b7c44
01 393b3d44
02 3a3c3d44
01 3e7e4344
00 3e7e4344
00 3e4a4344
02 3e3f4344
01 174a5644
00 17185644
00 18191a44
00 18191a44
00 181b1a44
00 1d1c1e44
00 4a1b1a44
00 4a191a44
00 18191a44
00 181f1e44
02 4a1f1e44
01 20672144
00 6f222144
00 6f222344
00 24222144
00 24222344
00 25262744
00 6e262744
00 29282a44
00 2c2b2a44
00 6e262744
00 6e6d2744
02 6e222744
01 2d2e2f44
00 2d303144
00 2d322f44
00 2d333144
00 2d323444
00 2d333544
00 2d323444
00 2d333544
00 2d2e3644
00 2d303644
00 2d373844
02 2d371444
01 1e1f4344
00 201f4144
00 1e1f2144
00 22202344
00 24252640
00 24252646
00 27282945
00 2a2b2946
00 1e1f2c47
00 202d2e47
00 2f30314b
00 2f30314c
00 32303344
00 32303444
00 35363744
00 38363944
00 35363a44
00 383b3c44
00 3d1e2c44
02 3e203f44

