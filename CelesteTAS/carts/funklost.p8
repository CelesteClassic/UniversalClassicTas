pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- ~celeste~
-- matt thorson + noel berry + funky kong

-- this is a community collaboration stared by cupps and dankus
-- and ended by amegpo, cominixo, cupps, dankus, flatkiwi,
-- glowyorange, jpegsarebad, meep, noel, qads, and rubyred

-- did you know? in amegpo's don games, something special happens when you hold up and c at the title screen... ;)

-- globals --
-------------
roomid = 0
room = { x=0, y=0 }
objects = {}
types = {}
freeze=0
--will_restart=false
delay_restart=0
got_fruit={}
--has_dashed=false
sfx_timer=0
has_key=false
pause_player=false
flash_bg=false
music_timer=0

k_left=0
k_right=1
k_up=2
k_down=3
k_jump=4
k_dash=5

message_text="shoutouts to simpleflips"

creators={"cupps","dankus","cupps","cupps","dankus","jpegsarebad","dankus","cominixo","rubyred","amegpo","qads","flatkiwi","meep","cominixo","amegpo","rubyred","jpegsarebad","qads","flatkiwi","meep","cominixo","noel","rubyred","amegpo","glowyorange","qads","flatkiwi","meep","cominixo","rubyred","dankus"}

-- dankus sset stuff --
-----------------------
ssetcolors='eeeeeeeeeeeeeeeeeeee7777eeeeeeeeeee7ffff7eeeeeeeee7f111cf7eeeeeee7f9af1cf7eeeeee7f9aaa111f7eeeeee7fff11111f7eeeeee77f11c11f7eeeeee7f11fc111f7eeeee7f11fcc11f7eeeee7f111fcc11f7eeeee7f1111c111f7eeeee7ff11faaaff7eeeee774f74f777eeeeee74f74f7eeeeeeeeee77e77eeeee'
setsign='777776777766646776f4446764ff4ff644444444000440000077770007776670'

-- amegpo extra level stuff --
------------------------------
amegpo_level1="253232323232323232252526002a3824332b002a2a2810293b31482600002a241b000000002a2900001b2426000000240000000000000000003a313300000031000000000000000000002a290000001b000000000000000000000000000000000000003a39000000000000000000000000003a28103900000000000000000000003a28282828390000000000007c0000002a282828282900000000000000000000002a382829000000000000000000000000002a2900000000000000000000000000000000000011110000000000003a00007c0000001121232b003f003a681000003a0000112125262b3b21222222222b3a38393b212548262b3b2425252548"
amegpo_level2="3232323232323232323233002a102828282828282810282900000000002a283828282828284e29000000000000002a28282828382900000000000000007c002a282829290000000000000000000000002a290000000000000000000000000000000000007c001111000000000000000000000000003a2123390000000000000000000000002a2426283912000000111111111100002a24262810170000112122222223111111242629290000002125252525252222222526110000001124482525252525252525252311111121252525252525254825252525222222252525252525252525252525252525482525252525482525252525482525252525252525"
amegpo_level3="28282828281024252525482525252525283828292a282425252525252525254828292900002a24254825252525482525290000000000313232323232323232320000000000001b1b1b1b1b1b1b1b1b1b0000002c00000000003a383900003a280000003c000000002a282a282828281022222222230000000000002a00002a282548253233001111111111111100002a25253338283921222222222223007c002533292a282824254825252526000000332900002a382425252548252600000029000000002a3132323232323300000000003a0039001b1b1b1b1b1b1b00000000002a2810390000000000000000000000002a28282911111111111111001600"

reserve_level=""
camx=0
camy=0
snowball_timer=0
wind_particles={}
player_y=0

function replace_level(top,x,y,level,reserve)
 reserve=reserve or false
 if reserve then
  reserve_level=""
 end
 for y_=1,32,2 do
  for x_=1,32,2 do
   local offset=4096+4096*int(top)
   local hex=sub(level, x_+(y_-1)/2*32, x_+(y_-1)/2*32+1)
   if reserve then
    reserve_level=reserve_level..num2hex(peek(offset+x*16+y*2048+(y_-1)*64+x_/2))
   end
   poke(offset+x*16+y*2048+(y_-1)*64+x_/2, "0x"..hex)
  end
 end
end

function num2hex(number)
  local base = 16
  local result = {}
  local resultstr = ""

  local digits = "0123456789abcdef"
  local quotient = flr(number / base)
  local remainder = number % base

  add(result, sub(digits, remainder + 1, remainder + 1))

  while (quotient > 0) do
    local old = quotient
    quotient /= base
    quotient = flr(quotient)
    remainder = old % base

    add(result, sub(digits, remainder + 1, remainder + 1))
  end

  for i = #result, 1, -1 do
    resultstr = resultstr..result[i]
  end
  if #resultstr==1 then

    resultstr="0"..resultstr
  end

  return resultstr
end

function int(b)
  return b==true and 1 or 0
end

function is_long(x,y)
  return (x==1 and y==1) or (x==6 and y==1)
end

function is_high(x,y)
  return (x==7 and y==2)
end

function is_wind(x,y)
  return (x==6 and y==1)
end

function is_snowball(x,y)
  return (x==6 and y==1) or (x==7 and y==2)
end

-- entry point --
-----------------

function _init()
  title_screen()
end

function title_screen()
  got_fruit = {}
  for i=0,29 do
    add(got_fruit,false) end
  roomid=0
  frames=0
  deaths=0
  max_djump=1
  start_game=false
  start_game_flash=0
  music(40,0,7)
  load_room(7,3)
end

function begin_game()
  frames=0
  centiseconds=0
  seconds=0
  minutes=0
  roomid=1
  music_timer=0
  start_game=false
  music(0,0,7)
  --replace_level(true,2,1,amegpo_level1,true)
  max_djump=1
  load_room(0,0)
end

function level_index()
  return room.x%8+room.y*8
end

function is_title()
  return roomid==0
end

-- effects --
-------------

clouds = {}
for i=0,16 do
  add(clouds,{
      x=rnd(128),
      y=rnd(128),
      spd=1+rnd(4),
      w=32+rnd(32)
    })
end

particles = {}
for i=0,24 do
  add(particles,{
      x=rnd(128),
      y=rnd(128),
      s=0+flr(rnd(5)/4),
      spd=0.25+rnd(5),
      off=rnd(1),
      c=6+flr(0.5+rnd(1))
    })
end

dead_particles = {}

-- player entity --
-------------------

function do_dash(this, input)
  --this.visible=true
  local d_full=5
  local d_half=d_full*0.70710678118
  local input = btn(k_right) and 1 or (btn(k_left) and -1 or 0)
  init_object(smoke,this.x,this.y)
  this.djump-=1
  this.dash_time=4
  has_dashed=true
  this.dash_effect_time=10
  local v_input=(btn(k_up) and -1 or (btn(k_down) and 1 or 0))
  if input!=0 then
    if v_input!=0 then
      this.spd.x=input*d_half
      this.spd.y=v_input*d_half
    else
      this.spd.x=input*d_full
      this.spd.y=0
    end
  elseif v_input!=0 then
    this.spd.x=0
    this.spd.y=v_input*d_full
  else
    this.spd.x=(this.flip.x and -1 or 1)
    this.spd.y=0
  end

  psfx(3)
  freeze=2
  this.dash_target.x=2*sign(this.spd.x)
  this.dash_target.y=2*sign(this.spd.y)
  this.dash_accel.x=1.5
  this.dash_accel.y=1.5

  if this.spd.y<0 then
    this.dash_target.y*=.75
  end

  if this.spd.y!=0 then
    this.dash_accel.x*=0.70710678118
  end
  if this.spd.x!=0 then
    this.dash_accel.y*=0.70710678118
  end
end

player =
{
  init=function(this)
    this.p_jump=false
    this.p_dash=false
    this.grace=0
    this.jbuffer=0
    this.djump=max_djump
    this.dash_time=0
    this.dash_effect_time=0
    this.dash_target={x=0,y=0}
    this.dash_accel={x=0,y=0}
    this.hitbox = {x=1,y=3,w=6,h=5}
    if treecret then
      this.hitbox = {x=1,y=-6,w=6,h=14}
      this.spr=60
      this.spr2=true
    end
    this.spr_off=0
    this.was_on_ground=false
    create_hair(this)
  end,
  update=function(this)
    if (pause_player) return

    local input = btn(k_right) and 1 or (btn(k_left) and -1 or 0)

    -- spikes collide
    if spikes_at(this.x+this.hitbox.x,this.y+this.hitbox.y,this.hitbox.w,this.hitbox.h,this.spd.x,this.spd.y) then
      kill_player(this) end

    -- bottom death
    if this.y>128 then
      kill_player(this) end

    local on_ground=this.is_solid(0,1)
    local on_ice=this.is_ice(0,1)

    if (btn(k_down) or level_index()==12 or level_index()==11 or level_index()==17 or level_index()==18 or level_index()==25 or level_index()==26 or level_index()==27) and treecret then
      this.hitbox = {x=1,y=3,w=6,h=5}
      this.spr2=false
      this.spr=44
    elseif not this.is_solid(0,-11) and treecret then
      this.hitbox = {x=1,y=-6,w=6,h=14}
      this.spr2=true
      this.spr=60
    end

    -- smoke particles
    if on_ground and not this.was_on_ground then
      init_object(smoke,this.x,this.y+4)
    end

    local jump = btn(k_jump) and not this.p_jump
    this.p_jump = btn(k_jump)
    if (jump) then
      this.jbuffer=4
    elseif this.jbuffer>0 then
      this.jbuffer-=1
    end

    local dash = btn(k_dash) and not this.p_dash
    this.p_dash = btn(k_dash)

    if on_ground then
      this.grace=6
      if this.djump<max_djump then
        psfx(54)
        this.djump=max_djump
      end
    elseif this.grace > 0 then
      this.grace-=1
    end

    this.dash_effect_time -=1
    if this.dash_time > 0 then
      init_object(smoke,this.x,this.y)
      this.dash_time-=1
      this.spd.x=appr(this.spd.x,this.dash_target.x,this.dash_accel.x)
      this.spd.y=appr(this.spd.y,this.dash_target.y,this.dash_accel.y)
    else

      -- move
      local maxrun=1
      local accel=0.6
      local deccel=0.15

      if not on_ground then
        accel=0.4
      elseif on_ice then
        accel=0.05
        if input==(this.flip.x and -1 or 1) then
          accel=0.05
        end
      end

      if abs(this.spd.x) > maxrun then
        this.spd.x=appr(this.spd.x,sign(this.spd.x)*maxrun,deccel)
      else
        this.spd.x=appr(this.spd.x,input*maxrun,accel)
      end

      --facing
      if this.spd.x!=0 then
        this.flip.x=(this.spd.x<0)
      end

      -- gravity
      local maxfall=2
      local gravity=0.21

      if abs(this.spd.y) <= 0.15 then
        gravity*=0.5
      end

      -- wall slide
      if input!=0 and this.is_solid(input,0) and not this.is_ice(input,0) then
        maxfall=0.4
        if rnd(10)<2 then
          init_object(smoke,this.x+input*6,this.y)
        end
      end

      if not on_ground then
        this.spd.y=appr(this.spd.y,maxfall,gravity)
      end

      -- jump
      if this.jbuffer>0 then
        if this.grace>0 then
          -- normal jump
          psfx(1)
          this.jbuffer=0
          this.grace=0
          this.spd.y=-2
          init_object(smoke,this.x,this.y+4)
        else
          -- wall jump
          local wall_dir=(this.is_solid(-3,0) and -1 or this.is_solid(3,0) and 1 or 0)
          if wall_dir!=0 then
            psfx(2)
            this.jbuffer=0
            this.spd.y=-2
            this.spd.x=-wall_dir*(maxrun+1)
            if not this.is_ice(wall_dir*3,0) then
              init_object(smoke,this.x+wall_dir*6,this.y)
            end
          end
        end
      end

      -- dash
      if this.djump>0 and dash then
        do_dash(this)
      elseif dash and this.djump<=0 then
        psfx(9)
        init_object(smoke,this.x,this.y)
      end
    end

    if not treecret then
      -- animation
      this.spr_off+=0.25
      if not on_ground then
        if this.is_solid(input,0) then
          this.spr=5
        else
          this.spr=3
        end
      elseif btn(k_down) then
        this.spr=6
      elseif btn(k_up) then
        this.spr=7
      elseif (this.spd.x==0) or (not btn(k_left) and not btn(k_right)) then
        this.spr=1
      else
        this.spr=1+this.spr_off%4
      end
    end

    -- camera (amegpo)
    if is_long(room.x, room.y) then
      if this.x > camx+84 then
        camx=this.x-84
      end
      if this.x < camx+40 then
        camx=this.x-40
      end
      camx=mid(0, camx, 128)
    end
    if is_high(room.x, room.y) then
      if this.y > camy+84 then
        camy=this.y-84
      end
      if this.y < camy+40 then
        camy=this.y-40
      end
      camy=mid(-128, camy, 0)
    end

    -- next level
    if ((this.y<-4-128*int(is_high(room.x,room.y)) and level_index()<30)) or (this.x>130 and this.y>32 and level_index()==5) then
      next_room()
    end
    if this.y<-4 and level_index()==30 then
      roomid=2
    end

    -- was on the ground
    this.was_on_ground=on_ground

    player_y=this.y

  end,  --<end update loop

  draw=function(this)

    -- clamp in screen
    if((this.x<-1 or this.x>121+128*int(is_long(room.x, room.y))) and level_index()!=5) or ((this.x<-1 or (this.x>121 and this.y<32)) and level_index()==5) then
      this.x=clamp(this.x,-1,121+128*int(is_long(room.x, room.y)))
      this.spd.x=0
    end

    if not treecret then
      set_hair_color(this.djump)
      draw_hair(this,this.flip.x and -1 or 1)
    elseif this.spr2 then
      spr(44,this.x,this.y-8,1,1,this.flip.x,this.flip.y)
    end

    spr(this.spr,this.x,this.y,1,1,this.flip.x,this.flip.y)
    if(not treecret)unset_hair_color()
  end
}

psfx=function(num)
  if sfx_timer<=0 then
    sfx(num)
  end
end

create_hair=function(obj)
  obj.hair={}
  for i=0,4 do
    add(obj.hair,{x=obj.x,y=obj.y,size=max(1,min(2,3-i))})
  end
end

set_hair_color=function(djump)
  pal(8,(djump==1 and 8 or djump==2 and 11 or 12))
end

draw_hair=function(obj,facing)
  local last={x=obj.x+4-facing*2,y=obj.y+(btn(k_down) and 4 or 3)}
  foreach(obj.hair,function(h)
      h.x+=(last.x-h.x)/1.5
      h.y+=(last.y+0.5-h.y)/1.5
      circfill(h.x,h.y,h.size,4)
      last=h
    end)
end

unset_hair_color=function()
  pal(8,8)
end

player_spawn = {
  tile=1,
  init=function(this)
    camx=0
    camy=0
    sfx(4)
    this.spr=3
    if(treecret)this.spr=60
    this.target= {x=this.x,y=this.y}
    this.y=128
    this.spd.y=-4
    this.state=0
    this.delay=0
    this.solids=false
    create_hair(this)
  end,
  update=function(this)
    -- jumping up
    if this.state==0 then
      if this.y < this.target.y+16 then
        this.state=1
        this.delay=3
      end
    -- falling
    elseif this.state==1 then
      this.spd.y+=0.5
      if this.spd.y>0 and this.delay>0 then
        this.spd.y=0
        this.delay-=1
      end
      if this.spd.y>0 and this.y > this.target.y then
        this.y=this.target.y
        this.spd = {x=0,y=0}
        this.state=2
        this.delay=5
        init_object(smoke,this.x,this.y+4)
        sfx(5)
      end
    -- landing
    elseif this.state==2 then
      this.delay-=1
      if(not treecret) this.spr=6
      if this.delay<0 then
        destroy_object(this)
        init_object(player,this.x,this.y)
      end
    end
  end,
  draw=function(this)
    if not treecret then
      set_hair_color(max_djump)
      draw_hair(this,1)
    else
      spr(44,this.x,this.y-8,1,1,this.flip.x,this.flip.y)
    end

    spr(this.spr,this.x,this.y,1,1,this.flip.x,this.flip.y)
    if(not treecret)unset_hair_color()
  end
}
add(types,player_spawn)

green_bubble = {  --by amegpo
  tile=124,
  init=function(this)
    this.timer=0
    this.dead_timer=0
    this.shake=0
    this.base_x=this.x
    this.base_y=this.y
  end,
  update=function(this)
    local hit=this.collide(player, 0, 0)
    if hit~=nil then
      if this.spr>0 then
        hit.visible=false
        if this.timer==0 then
          this.timer=1
          this.shake=5
        end
      end
      if this.timer>0 then
        this.x=this.base_x
        this.y=this.base_y
        if this.shake>0 then
          --this.x=this.base_x+rnd(2)-1
          --this.y=this.base_y+rnd(2)-1
          this.shake-=1
        end
        hit.x=(this.x+hit.x)/2
        hit.y=this.y
        this.timer+=1
        if this.timer==20 or btn(k_dash) then
          this.x=this.base_x
          this.y=this.base_y
          hit.visible=true
          do_dash(hit)
          hit.djump=max_djump
          this.spr=0
          this.timer=0
        end
      end
    end
    if this.spr==0 then
      this.dead_timer+=1
      if this.dead_timer==60 then
        this.dead_timer=0
        this.spr=124
        init_object(smoke, this.x, this.y)
      end
    end
  end
}
add(types, green_bubble)

snowball = {  --by amegpo
  tile=125,
  init=function(this)
  end,
  update=function(this)
    this.x-=2
    local hit=this.collide(player, 0, 0)
    if hit~=nil then
      if hit.y<this.y then
        hit.djump=max_djump
        hit.spd.y=-2
        psfx(1)
        hit.dash_time=-1
        init_object(smoke, this.x, this.y)
        destroy_object(this)
      else
        kill_player(hit)
      end
    end
  end
}

spring = {
  tile=18,
  init=function(this)
    this.hide_in=0
    this.hide_for=0
  end,
  update=function(this)
    if this.hide_for>0 then
      this.hide_for-=1
      if this.hide_for<=0 then
        this.spr=18
        this.delay=0
      end
    elseif this.spr==18 then
      local hit = this.collide(player,0,0)
      if hit ~=nil and hit.spd.y>=0 then
        this.spr=19
        hit.y=this.y-4
        hit.spd.x*=0.2
        hit.spd.y=-3
        hit.djump=max_djump
        this.delay=10
        init_object(smoke,this.x,this.y)

        -- breakable below us
        local below=this.collide(fall_floor,0,1)
        if below~=nil then
          break_fall_floor(below)
        end

        psfx(8)
      end
    elseif this.delay>0 then
      this.delay-=1
      if this.delay<=0 then
        this.spr=18
      end
    end
    -- begin hiding
    if this.hide_in>0 then
      this.hide_in-=1
      if this.hide_in<=0 then
        this.hide_for=60
        this.spr=0
      end
    end
  end
}
add(types,spring)

springl = {
  tile=77,
  init=function(this)
    this.hide_in=0
    this.hide_for=0
    this.delay=0
  end,
  update=function(this)
    if this.hide_for>0 then
      this.hide_for-=1
      if this.hide_for<=0 then
        this.spr=77
        this.delay=0
      end
    elseif this.spr==77 then
      local hit = this.collide(player,0,0)
      if hit ~=nil and hit.spd.x<=0 then
        this.spr=123
        hit.x=this.x+4
        hit.spd.x=3
        hit.spd.y=-1
        hit.djump=max_djump
        hit.dash_time=0
        hit.dash_effect_time=0
        this.delay=10
        init_object(smoke,this.x,this.y)
        local left=this.collide(fall_floor,-1,0)
        if left~=nil then
          break_fall_floor(left)
        end
        psfx(8)
      end
    elseif this.delay>0 then
      this.delay-=1
      if this.delay<=0 then
        this.spr=77
      end
    end
    -- begin hiding
    if this.hide_in>0 then
      this.hide_in-=1
      if this.hide_in<=0 then
        this.hide_for=60
        this.spr=0
      end
    end
  end
}
add(types,springl)

springr = {
  tile=79,
  init=function(this)
    this.hide_in=0
    this.hide_for=0
    this.delay=0
  end,
  update=function(this)
    if this.hide_for>0 then
      this.hide_for-=1
      if this.hide_for<=0 then
        this.spr=79
        this.delay=0
      end
    elseif this.spr==79 then
      local hit = this.collide(player,0,0)
      if hit ~=nil and hit.spd.x>=0 then
        this.spr=123
        hit.x=this.x-4
        hit.spd.x=-3
        hit.spd.y=-1
        hit.djump=max_djump
        hit.dash_time=0
        hit.dash_effect_time=0
        this.delay=10
        init_object(smoke,this.x,this.y)
        local right=this.collide(fall_floor,1,0)
        if right~=nil then
          break_fall_floor(right)
        end
        psfx(8)
      end
    elseif this.delay>0 then
      this.delay-=1
      if this.delay<=0 then
        this.spr=79
      end
    end
    -- begin hiding
    if this.hide_in>0 then
      this.hide_in-=1
      if this.hide_in<=0 then
        this.hide_for=60
        this.spr=0
      end
    end
  end,
  draw=function(this)
    if this.spr==123 then
      spr(this.spr,this.x,this.y, 1.0, 1.0, true, false)
    else
      spr(this.spr,this.x,this.y)
    end
  end
}
add(types,springr)

function break_spring(obj)
  obj.hide_in=15
end

balloon = {
  tile=22,
  init=function(this)
    this.offset=rnd(1)
    this.start=this.y
    this.timer=0
    this.hitbox={x=-1,y=-1,w=10,h=10}
  end,
  update=function(this)
    if this.spr==22 then
      this.offset+=0.01
      this.y=this.start+sin(this.offset)*2
      local hit = this.collide(player,0,0)
      if hit~=nil and hit.djump<max_djump then
        psfx(6)
        init_object(smoke,this.x,this.y)
        hit.djump=max_djump
        this.spr=0
        this.timer=60
      end
    elseif this.timer>0 then
      this.timer-=1
    else
      psfx(7)
      init_object(smoke,this.x,this.y)
      this.spr=22
    end
  end,
  draw=function(this)
    if this.spr==22 then
      spr(13+(this.offset*8)%3,this.x,this.y+6)
      spr(this.spr,this.x,this.y)
    end
  end
}
add(types,balloon)

fall_floor = {
  tile=23,
  init=function(this)
    this.state=0
    this.solid=true
  end,
  update=function(this)
    -- idling
    if this.state == 0 then
      if this.check(player,0,-1) or this.check(player,-1,0) or this.check(player,1,0) then
        break_fall_floor(this)
      end
    -- shaking
    elseif this.state==1 then
      this.delay-=1
      if this.delay<=0 then
        this.state=2
        this.delay=60  --how long it hides for
        this.collideable=false
      end
    -- invisible, waiting to reset
    elseif this.state==2 then
      this.delay-=1
      if this.delay<=0 and not this.check(player,0,0) then
        psfx(7)
        this.state=0
        this.collideable=true
        init_object(smoke,this.x,this.y)
      end
    end
  end,
  draw=function(this)
    if this.state!=2 then
      if this.state!=1 then
        spr(23,this.x,this.y)
      else
        spr(23+(15-this.delay)/5,this.x,this.y)
      end
    end
  end
}
add(types,fall_floor)

function break_fall_floor(obj)
  if obj.state==0 then
    psfx(15)
    obj.state=1
    obj.delay=15  --how long until it falls
    init_object(smoke,obj.x,obj.y)
    local hit=obj.collide(spring,0,-1)
    if hit~=nil then
      break_spring(hit)
    end
    hit=obj.collide(springl,1,0)
    if hit~=nil then
      break_spring(hit)
    end
    hit=obj.collide(springr,-1,0)
    if hit~=nil then
      break_spring(hit)
    end
  end
end

smoke={
  init=function(this)
    this.spr=29
    this.spd.y=-0.1
    this.spd.x=0.3+rnd(0.2)
    this.x+=-1+rnd(2)
    this.y+=-1+rnd(2)
    this.flip.x=maybe()
    this.flip.y=maybe()
    this.solids=false
  end,
  update=function(this)
    this.spr+=0.2
    if this.spr>=32 then
      destroy_object(this)
    end
  end
}

fruit={
  tile=26,
  if_not_fruit=true,
  init=function(this)
    this.start=this.y
    this.off=0
  end,
  update=function(this)
    local hit=this.collide(player,0,0)
    if hit~=nil then
      hit.djump=max_djump
      sfx_timer=20
      sfx(13)
      got_fruit[1+level_index()] = true
      init_object(lifeup,this.x,this.y)
      destroy_object(this)
    end
    this.off+=1
    this.y=this.start+sin(this.off/40)*2.5
  end
}
add(types,fruit)

fly_fruit={
  tile=28,
  if_not_fruit=true,
  init=function(this)
    this.start=this.y
    this.fly=false
    this.step=0.5
    this.solids=false
    this.sfx_delay=8
  end,
  update=function(this)
    --fly away
    if this.fly then
      if this.sfx_delay>0 then
        this.sfx_delay-=1
        if this.sfx_delay<=0 then
          sfx_timer=20
          sfx(14)
        end
      end
      this.spd.y=appr(this.spd.y,-3.5,0.25)
      if this.y<-16 then
        destroy_object(this)
      end
    -- wait
    else
      if has_dashed then
        this.fly=true
      end
      this.step+=0.05
      this.spd.y=sin(this.step)*0.5
    end
    -- collect
    local hit=this.collide(player,0,0)
    if hit~=nil then
      hit.djump=max_djump
      sfx_timer=20
      sfx(13)
      got_fruit[1+level_index()] = true
      init_object(lifeup,this.x,this.y)
      destroy_object(this)
    end
  end,
  draw=function(this)
    local off=0
    if not this.fly then
      local dir=sin(this.step)
      if dir<0 then
        off=1+max(0,sign(this.y-this.start))
      end
    else
      off=(off+0.25)%3
    end
    spr(45+off,this.x-6,this.y-2,1,1,true,false)
    spr(this.spr,this.x,this.y)
    spr(45+off,this.x+6,this.y-2)
  end
}
add(types,fly_fruit)

lifeup = {
  init=function(this)
    this.spd.y=-0.25
    this.duration=30
    this.x-=2
    this.y-=4
    this.flash=0
    this.solids=false
  end,
  update=function(this)
    this.duration-=1
    if this.duration<= 0 then
      destroy_object(this)
    end
  end,
  draw=function(this)
    this.flash+=0.5

    print("1000",this.x-2,this.y,7+this.flash%2)
  end
}

fake_wall = {
  tile=64,
  if_not_fruit=true,
  init=function(this)
    this.spawn_fruit=true
  end,
  update=function(this)
    this.hitbox={x=-1,y=-1,w=18,h=18}
    local hit = this.collide(player,0,0)
    if hit~=nil and hit.dash_effect_time>0 then
      hit.spd.x=-sign(hit.spd.x)*1.5
      hit.spd.y=-1.5
      hit.dash_time=-1
      sfx_timer=20
      sfx(16)
      destroy_object(this)
      init_object(smoke,this.x,this.y)
      init_object(smoke,this.x+8,this.y)
      init_object(smoke,this.x,this.y+8)
      init_object(smoke,this.x+8,this.y+8)
      if this.spawn_fruit then
        init_object(fruit,this.x+4,this.y+4)
      end
    end
    this.hitbox={x=0,y=0,w=16,h=16}
  end,
  draw=function(this)
    spr(64,this.x,this.y)
    spr(65,this.x+8,this.y)
    spr(80,this.x,this.y+8)
    spr(81,this.x+8,this.y+8)
  end
}
add(types,fake_wall)

fruitless_fake_wall = {
  tile=65,
  init=function(this)
    this.spawn_fruit=false
    this.x = this.x - 8
  end,
  update=fake_wall.update,
  draw=fake_wall.draw
}
add(types,fruitless_fake_wall)

key={
  tile=8,
  if_not_fruit=true,
  update=function(this)
    local was=flr(this.spr)
    this.spr=9+(sin(frames/30)+0.5)*1
    local is=flr(this.spr)
    if is==10 and is!=was then
      this.flip.x=not this.flip.x
    end
    if this.check(player,0,0) then
      sfx(23)
      sfx_timer=10
      destroy_object(this)
      has_key=true
    end
  end
}
add(types,key)

chest={
  tile=20,
  if_not_fruit=true,
  init=function(this)
    this.x-=4
    this.start=this.x
    this.timer=20
  end,
  update=function(this)
    if has_key then
      this.timer-=1
      this.x=this.start-1+rnd(3)
      if this.timer<=0 then
        sfx_timer=20
        sfx(16)
        init_object(fruit,this.x,this.y-4)
        destroy_object(this)
      end
    end
  end
}
add(types,chest)

platform={
  init=function(this)
    this.x-=4
    this.solids=false
    this.hitbox.w=16
    this.last=this.x
  end,
  update=function(this)
    this.spd.x=this.dir*0.65
    if this.x<-16 then this.x=128
    elseif this.x>128 then this.x=-16 end
    if not this.check(player,0,0) then
      local hit=this.collide(player,0,-1)
      if hit~=nil then
        hit.move_x(this.x-this.last,1)
      end
    end
    this.last=this.x
  end,
  draw=function(this)
    spr(11,this.x,this.y-1)
    spr(12,this.x+8,this.y-1)
  end
}

message={
  tile=86,
  last=0,
  draw=function(this)
    if this.check(player,4,0) then
      if this.index<#message_text then
        this.index+=0.5
        if this.index>=this.last+1 then
          this.last+=1
          sfx(35)
        end
      end
      this.off={x=64-2.5*#message_text,y=96}
      for i=1,this.index do
        if sub(message_text,i,i)~="#" then
          rectfill(this.off.x-1,this.off.y-2,this.off.x+4,this.off.y+6 ,7)
          print(sub(message_text,i,i),this.off.x,this.off.y,0)
          this.off.x+=5
        else
          this.off.x=8
          this.off.y+=7
        end
      end
    else
      this.index=0
      this.last=0
    end
  end
}
add(types,message)

big_chest={
  tile=96,
  init=function(this)
    this.state=0
    this.hitbox.w=16
  end,
  draw=function(this)
    if this.state==0 then
      local hit=this.collide(player,0,8)
      if hit~=nil and hit.is_solid(0,1) then
        music(-1,500,7)
        sfx(37)
        pause_player=true
        hit.spd.x=0
        hit.spd.y=0
        this.state=1
        init_object(smoke,this.x,this.y)
        init_object(smoke,this.x+8,this.y)
        this.timer=60
        this.particles={}
      end
      spr(96,this.x,this.y)
      spr(97,this.x+8,this.y)
    elseif this.state==1 then
      this.timer-=1
      flash_bg=true
      if this.timer<=45 and count(this.particles)<50 then
        add(this.particles,{
            x=1+rnd(14),
            y=0,
            h=32+rnd(32),
            spd=8+rnd(8)
          })
      end
      if this.timer<0 then
        this.state=2
        this.particles={}
        flash_bg=false
        new_bg=true
        init_object(orb,this.x+4,this.y+4)
        pause_player=false
      end
      foreach(this.particles,function(p)
          p.y+=p.spd
          line(this.x+p.x,this.y+8-p.y,this.x+p.x,min(this.y+8-p.y+p.h,this.y+8),7)
        end)
    end
    spr(112,this.x,this.y+8)
    spr(113,this.x+8,this.y+8)
  end
}
add(types,big_chest)

orb={
  init=function(this)
    this.spd.y=-4
    this.solids=false
    this.particles={}
  end,
  draw=function(this)
    this.spd.y=appr(this.spd.y,0,0.5)
    local hit=this.collide(player,0,0)
    if this.spd.y==0 and hit~=nil then
      music_timer=45
      sfx(51)
      freeze=10
      destroy_object(this)
      max_djump=2
      hit.djump=2
    end

    spr(102,this.x,this.y)
    local off=frames/30
    for i=0,7 do
      circfill(this.x+4+cos(off+i/8)*8,this.y+4+sin(off+i/8)*8,1,7)
    end
  end
}

flag = {
  tile=118,
  init=function(this)
    this.x+=5
    this.score=0
    this.show=false
    for i=1,count(got_fruit) do
      if got_fruit[i] then
        this.score+=1
      end
    end
  end,
  draw=function(this)
    this.spr=118+(frames/10)%2
    spr(this.spr,this.x,this.y)
    if this.show then
      rectfill(32,2,96,31,0)
      spr(26,55,6)
      print("x"..this.score,64,9,7)
      draw_time(49,16)
      print("deaths:"..deaths,48,24,7)
    elseif this.check(player,0,0) then
      sfx(55)
      sfx_timer=30
      this.show=true
    end
  end
}
add(types,flag)

room_title = {
  init=function(this)
    this.delay=5
  end,
  draw=function(this)
    this.delay-=1
    if this.delay<-30 then
      destroy_object(this)
    elseif this.delay<0 then

      rectfill(24,58,104,70+8*int(level_index()<31),0)
      --rect(26,64-10,102,64+10,7)
      --print("---",31,64-2,13)
      if room.x==2 and room.y==1 then
        print("old site",48,62,7)
        local creator=creators[level_index()+1]
        print(creator,64-2*#creator,70)
      elseif level_index()==30 then
        print("summit",52,62,7)
        print("dankus",52,70)
      else
        local level=(1+level_index())*100
        print(level.." m",52+(level<1000 and 2 or 0),62,7)
        local creator=creators[level_index()+1]
        print(creator,64-2*#creator,70)
      end
      --print("---",86,64-2,13)

      if level_index()<30 then
        draw_time(4,4)
      end
    end
  end
}
cam = {
	init=function(this)
		this.x=0
		this.y=0
		this.visible=false
	end,
	save=function(this)
		this.x=camx
		this.y=camy
	end,
	load=function(this)
		camx=this.x
		camy=this.y
	end
}

function loadcamera()
	for i=1,#objects do 
		if objects[i].type==cam then
			cam.load(objects[i])
		end 
	end 
end
function savecamera()
	for i=1,#objects do 
		if objects[i].type==cam then
			cam.save(objects[i])
		end 
	end 
end
-- object functions --
-----------------------

function init_object(type,x,y)
  if type.if_not_fruit~=nil and got_fruit[1+level_index()] then
    return
  end
  local obj = {}
  obj.type = type
  obj.collideable=true
  obj.solids=true

  obj.spr = type.tile
  obj.flip = {x=false,y=false}

  obj.x = x
  obj.y = y
  obj.hitbox = { x=0,y=0,w=8,h=8 }

  obj.spd = {x=0,y=0}
  obj.rem = {x=0,y=0}

  obj.visible = true

  obj.is_solid=function(ox,oy)
    if oy>0 and not obj.check(platform,ox,0) and obj.check(platform,ox,oy) then
      return true
    end
    return solid_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h)
    or obj.check(fall_floor,ox,oy)
    or obj.check(fake_wall,ox,oy)
    or obj.check(fruitless_fake_wall,ox,oy)
  end

  obj.is_ice=function(ox,oy)
    return ice_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h)
  end

  obj.collide=function(type,ox,oy)
    local other
    for i=1,count(objects) do
      other=objects[i]
      if other ~=nil and other.type == type and other != obj and other.collideable and
      other.x+other.hitbox.x+other.hitbox.w > obj.x+obj.hitbox.x+ox and
      other.y+other.hitbox.y+other.hitbox.h > obj.y+obj.hitbox.y+oy and
      other.x+other.hitbox.x < obj.x+obj.hitbox.x+obj.hitbox.w+ox and
      other.y+other.hitbox.y < obj.y+obj.hitbox.y+obj.hitbox.h+oy then
        return other
      end
    end
    return nil
  end

  obj.check=function(type,ox,oy)
    return obj.collide(type,ox,oy) ~=nil
  end

  obj.move=function(ox,oy)
    local amount
    -- [x] get move amount
    obj.rem.x += ox
    if is_wind(room.x,room.y) and obj.type==player and obj.dash_time<=0 then
      obj.rem.x-=0.5
    end
    amount = flr(obj.rem.x + 0.5)
    obj.rem.x -= amount
    obj.move_x(amount,0)

    -- [y] get move amount
    obj.rem.y += oy
    amount = flr(obj.rem.y + 0.5)
    obj.rem.y -= amount
    obj.move_y(amount)
  end

  obj.move_x=function(amount,start)
    if obj.solids then
      local step = sign(amount)
      for i=start,abs(amount) do
        if not obj.is_solid(step,0) then
          obj.x += step
        else
          obj.spd.x = 0
          obj.rem.x = 0
          break
        end
      end
    else
      obj.x += amount
    end
  end

  obj.move_y=function(amount)
    if obj.solids then
      local step = sign(amount)
      for i=0,abs(amount) do
        if not obj.is_solid(0,step) then
          obj.y += step
        else
          obj.spd.y = 0
          obj.rem.y = 0
          break
        end
      end
    else
      obj.y += amount
    end
  end

  add(objects,obj)
  if obj.type.init~=nil then
    obj.type.init(obj)
  end
  return obj
end

function destroy_object(obj)
  del(objects,obj)
end

function kill_player(obj)
  sfx_timer=12
  sfx(0)
  deaths+=1
  destroy_object(obj)
  dead_particles={}
  for dir=0,7 do
    local angle=(dir/8)
    add(dead_particles,{
        x=obj.x+4,
        y=obj.y+4,
        t=10,
        spd={
          x=sin(angle)*3,
          y=cos(angle)*3
        }
      })
    restart_room()
  end
end

-- room functions --
--------------------

function restart_room()
  will_restart=true
  delay_restart=15
end

function next_room()
  if room.x==1 and room.y==1 then
    music(30,500,7)
  elseif room.x==2 and room.y==1 then  --after old site
    for y=40,47 do
      for x=48,55 do
        local i=(y-40)*8+(x-56)+1
        sset(x,y,tonum("0x"..sub(setsign,i,i)))
      end
    end
    message_text = 'press x from spawn'
    music(20,500,7)
  elseif room.x==3 and room.y==2 then
    music(30,500,7)
  elseif room.x==5 and room.y==3 then
    music(30,500,7)
  end

  if room.x==7 then
    load_room(0,room.y+1)
  else
    load_room(room.x+1,room.y)
  end
end

function load_room(x,y)
 --remove existing objects
 foreach(objects,destroy_object)
 --prev room
 local x_prev = room.x
 local y_prev = room.y
 --current room
 room.x = x
 room.y = y

 camx=0
 camy=0
 has_dashed=false
 has_key=false
 snowball_timer=0
 if level_index()==10 then
  message_text='shoutouts to simpleflips'
 elseif level_index()==30 and max_djump==1 then
  for y=32,47 do
   for x=48,63 do
    local i=(y-32)*16+(x-48)+1
    sset(x,y,tonum("0x"..sub(ssetcolors,i,i)))
   end
  end
  message_text='hi confused, im amber!'
 elseif level_index()==30 then
  for y=32,47 do
   for x=48,63 do
    local i=(y-32)*16+(x-48)+1
    sset(x,y,14)
   end
  end
  message_text=''
 end

 --amegpo stuff
 same_room = (room.x == x_prev) and (room.y == y_prev)
 if room.x==1 and room.y==1 and not same_room then 
  replace_level(true,2,1,amegpo_level1,true)
 elseif x_prev==1 and y_prev==1 and not same_room then
  replace_level(true,2,1,reserve_level,false)
 end
 if room.x==6 and room.y==1 and not same_room then
  replace_level(true,7,1,amegpo_level2,true)
 elseif x_prev==6 and y_prev==1 and not same_room then
  replace_level(true,7,1,reserve_level,false)
 end
 if room.x==7 and room.y==2 and not same_room then
  replace_level(true,7,1,amegpo_level3,true)
 elseif x_prev==7 and y_prev==2 and not same_room then
  replace_level(true,7,1,reserve_level,false)
 end

 -- entities
 init_object(cam,0,0)
 for tx=0,15+16*int(is_long(x,y)) do
  for ty=0-16*int(is_high(room.x,room.y)),15 do
   local tile = mget(room.x*16+tx,room.y*16+ty);
   if tile==11 then
    init_object(platform,tx*8,ty*8).dir=-1
   elseif tile==12 then
    init_object(platform,tx*8,ty*8).dir=1
   elseif not (tile==86 and max_djump==2) then
    foreach(types, 
    function(type) 
     if type.tile == tile then
      if not ((tx>15 or ty<0) and tile==1) then
       init_object(type,tx*8,ty*8) 
      end
     end 
    end)
   end
  end
 end
 
 init_object(room_title,0,0)
end

-- update function --
-----------------------

function _update()
  frames=((frames+1)%30)
  if roomid==1 then
    centiseconds=flr(100*frames/30)
    if frames==0 and roomid==1 then
      seconds=((seconds+1)%60)
      if seconds==0 then
        minutes+=1
      end
    end
  end

  if music_timer>0 then
    music_timer-=1
    if music_timer<=0 then
      music(10,0,7)
    end
  end

  if sfx_timer>0 then
    sfx_timer-=1
  end

  -- cancel if freeze
  if freeze>0 then freeze-=1 return end

  -- restart (soon)
  if will_restart and delay_restart>0 then
    delay_restart-=1
    if delay_restart<=0 then
      will_restart=false
      load_room(room.x,room.y)
    end
  end
	
  -- update each object
  foreach(objects,function(obj)
      obj.move(obj.spd.x,obj.spd.y)
      if obj.type.update~=nil then
        obj.type.update(obj)
      end
    end)
  
  -- snowballs (amegpo)
  if is_snowball(room.x, room.y) then
    snowball_timer+=1
    if snowball_timer==60 then
      snowball_timer=0
      init_object(snowball, camx+128, player_y)
    end
  end
  savecamera()
  -- start game
  if is_title() then
    if not start_game and (btn(k_jump) or btn(k_dash)) then
      music(-1)
      start_game_flash=50
      start_game=true
      sfx(38)
      if (btn(k_up)) treecret=true
    end
    if start_game then
      start_game_flash-=1
      if start_game_flash<=-30 then
        begin_game()
      end
    end
  end
end

-- drawing functions --
-----------------------

function _draw()
  if freeze>0 then return end

  -- reset all palette values
  pal()

  -- start game flash
  if start_game then
    local c=10
    if start_game_flash>10 then
      if frames%10<5 then
        c=7
      end
    elseif start_game_flash>5 then
      c=2
    elseif start_game_flash>0 then
      c=1
    else
      c=0
    end
    if c<10 then
      pal(6,c)
      pal(12,c)
      pal(13,c)
      pal(5,c)
      pal(1,c)
      pal(7,c)
    end
  end

  -- clear screen
  local bg_col = 0
  if flash_bg then
    bg_col = frames/5
  elseif new_bg~=nil then
    bg_col=2
  end
  rectfill(0,-128,256,128,bg_col)

  -- clouds
  loadcamera()
  if not is_title() then
    foreach(clouds, function(c)
        c.x += c.spd
        rectfill(c.x+camx,c.y,c.x+camx+c.w,c.y+4+(1-c.w/64)*12,new_bg~=nil and 14 or 1)
        if c.x > 128 then
          c.x = -c.w
          c.y=rnd(128+128*int(is_high(room.x,room.y))-8)-128*int(is_high(room.x,room.y))
        end
      end)
  end
  camera(camx,camy)

  -- draw bg terrain
  map(room.x*16,room.y*16-16,0,-128,32,32,4)

  -- platforms/big chest
  foreach(objects, function(o)
      if o.type==platform or o.type==big_chest then
        draw_object(o)
      end
    end)

  -- adjust colors and stuff for summit easter egg
  if level_index()==30 or level_index()==12 then
    pal(15,0)
    palt(14,true)
  end

  -- draw terrain
  local off=is_title() and -4 or 0
  map(room.x*16,room.y*16-16,off,-128,32,32,2)
  pal(15,15)
  palt()

  -- draw objects
  foreach(objects, function(o)
      if o.type~=platform and o.type~=big_chest and o.type~=message and o.visible==true then
        draw_object(o)
      end
    end)

  foreach(objects, function(o)
      if o.type==message then
        draw_object(o)
      end
    end)

  -- draw fg terrain
  map(room.x * 16,room.y * 16,0,0,32,16,8)

  -- wind particles (amegpo)
  if is_wind(room.x,room.y) then
    foreach(wind_particles, function(o)
        line(camx+o.x, o.y, camx+o.x+8, o.y, 7)
        o.x-=5
      end)
    if snowball_timer%5==0 then
      local o={}
      o.x=128
      o.y=rnd(128)
      add(wind_particles, o)
    end
  end

  -- particles
  foreach(particles, function(p)
      p.x += p.spd
      p.y += sin(p.off)
      p.off+= min(0.05,p.spd/32)
      rectfill(p.x,p.y,p.x+p.s,p.y+p.s,p.c)
      if p.x>128+4 then
        p.x=-4
        p.y=rnd(128)
      end
    end)

  -- dead particles
  foreach(dead_particles, function(p)
      p.x += p.spd.x
      p.y += p.spd.y
      p.t -=1
      if p.t <= 0 then del(dead_particles,p) end
      rectfill(p.x-p.t/5,p.y-p.t/5,p.x+p.t/5,p.y+p.t/5,14+p.t%2)
    end)

  -- credits
  if is_title() then
    print("must find funk the",28,102,5)
    print("the funk",48,110,5)
    print("cupps - dankus",38,118,5)
  end

  if level_index()==30 then
    local p
    for i=1,count(objects) do
      if objects[i].type==player then
        p = objects[i]
        break
      end
    end
  end
end
	
function draw_object(obj)
  if obj.type.draw ~=nil then
    obj.type.draw(obj)
  elseif obj.spr > 0 then
    spr(obj.spr,obj.x,obj.y,1,1,obj.flip.x,obj.flip.y)
  end
end

function draw_time(x,y)
  local cs=centiseconds
  local s=seconds
  local m=minutes%60
  local h=flr(minutes/60)

  rectfill(x,y,x+44,y+6,0)
  print((h<10 and "0"..h or h)..":"..(m<10 and "0"..m or m)..":"..(s<10 and "0"..s or s).."."..(cs<10 and "0"..cs or cs),x+1,y+1,7)
end

-- helper functions --
----------------------

function clamp(val,a,b)
  return max(a, min(b, val))
end

function appr(val,target,amount)
  return val > target
  and max(val - amount, target)
  or min(val + amount, target)
end

function sign(v)
  return v>0 and 1 or
  v<0 and -1 or 0
end

function maybe()
  return rnd(1)<0.5
end

function solid_at(x,y,w,h)
  return tile_flag_at(x,y,w,h,0)
end

function ice_at(x,y,w,h)
  return tile_flag_at(x,y,w,h,4)
end

function tile_flag_at(x,y,w,h,flag)
  for i=max(0,flr(x/8)),min(15+16*int(is_long(room.x,room.y)),(x+w-1)/8) do
    for j=max(-16*int(is_high(room.x,room.y)),flr(y/8)),min(15,(y+h-1)/8) do
      if fget(tile_at(i,j),flag) then
        return true
      end
    end
  end
  return false
end

function tile_at(x,y)
  return mget(room.x * 16 + x, room.y * 16 + y)
end

function spikes_at(x,y,w,h,xspd,yspd)
  for i=max(0,flr(x/8)),min(15+16*int(is_long(room.x,room.y)),(x+w-1)/8) do
    for j=max(-16*int(is_high(room.x,room.y)),flr(y/8)),min(15,(y+h-1)/8) do
      local tile=tile_at(i,j)
      if tile==17 and ((y+h-1)%8>=6 or y+h==j*8+8) and yspd>=0 then
        return true
      elseif tile==27 and y%8<=2 and yspd<=0 then
        return true
      elseif tile==43 and x%8<=2 and xspd<=0 then
        return true
      elseif tile==59 and ((x+w-1)%8>=6 or x+w==i*8+8) and xspd>=0 then
        return true
      end
    end
  end
  return false
end
__gfx__
000000000000000000000000088744400000000000000000000000000000000000aaaaa0000aaa000000a0000007707770077700000060000000600000060000
000000000887444008874440878844440887444004447880000000008788444000a000a0000a0a000000a0000777777677777770000060000000600000060000
000000008788444487884444481111148788444444448870088744404811111400a909a0000a0a000000a0007766666667767777000600000000600000060000
00000000481111144811111444f11f1448111114411114808788444444f11f14009aaa900009a9000000a0007677766676666677000600000000600000060000
0000000044f11f1444f11f1404ff77f044f11f1441f11f40484ffff444ff77f40000a0000000a0000000a0000000000000000000000600000006000000006000
0000000004ff77f004ff77f000cccc0004ff77f00f77ff404411111404cccc400099a0000009a0000000a0000000000000000000000600000006000000006000
0000000000cccc0000cccc000700007007cccc0000cccc7004f11f1000cccc000009a0000000a0000000a0000000000000000000000060000006000000006000
000000000070070000700070000000000000070000007000077ccc700070070000aaa0000009a0000000a0000000000000000000000060000006000000006000
5555555500000000000000000000000000000000000000000088880049999994499999944999099400000aa06665666500000aa0000000000000000070000000
555555550000000000000000000000000000000000000000088888809111111991114119911409190000009a676567650000009a007700000770070007000007
550000550000000000000000000000000aaaaaa00000000008788880911111199111911949400419000009496770677000000949007770700777000000000000
55000055007000700499994000000000a998888a1111111108888880911111199494041900000044aaaaaa4a07000700aaaaaa4a077777700770000000000000
55000055007000700050050000000000a988888a10000001088888809111111991140949940000009aaaa4aa070007009aaaa4aa077777700000700000000000
55000055067706770005500000000000aaaaaaaa111111110888888091111119911191199140049949944aaa0000000049944aaa077777700000077000000000
55555555567656760050050000000000a980088a14444441008888009111111991141119914041199aaaaaa0000000009aaaaaa0070777000007077007000070
55555555566656660005500004999940a988888a144444410000000049999994499999944400499409aaaa000000000009aaaa00000000007000000000000000
5777777557777777777777777777777577cccccccccccccccccccc77577777755555555555555555555555555500000007777770000000000000000000000000
77777777777777777777777777777777777cccccccccccccccccc777777777775555555555555550055555556670000077777777000777770000000000000000
777c77777777ccccc777777ccccc7777777cccccccccccccccccc777777777775555555555555500005555556777700077777777007766700000000000000000
77cccc77777cccccccc77cccccccc7777777cccccccccccccccc7777777cc7775555555555555000000555556660000077773377076777000000000000000000
77cccc7777cccccccccccccccccccc777777cccccccccccccccc777777cccc775555555555550000000055555500000077773377077660000777770000000000
777cc77777cc77ccccccccccccc7cc77777cccccccccccccccccc77777cccc775555555555500000000005556670000073773337077770000777767007700000
7777777777cc77cccccccccccccccc77777cccccccccccccccccc77777c7cc77555555555500000000000055677770007333bb37000000000000007700777770
5777777577cccccccccccccccccccc7777cccccccccccccccccccc7777cccc77555555555000000000000005666000000333bb30000000000000000000077777
77cccc7777cccccccccccccccccccc77577777777777777777777775777ccc775555555550000000000000050000066603333330000000000000000000000000
777ccc7777cccccccccccccccccccc77777777777777777777777777777cc7775055555555000000000000550007777603b333300000000000ee0ee000000000
777ccc7777cc7cccccccccccc77ccc777777ccc7777777777ccc7777777cc77755550055555000000000055500000766033333300000000000eeeee000000030
77ccc77777ccccccccccccccc77ccc77777ccccc7c7777ccccccc77777ccc777555500555555000000005555000000550333b33000000000000e8e00000000b0
77ccc777777cccccccc77cccccccc777777ccccccc7777c7ccccc77777cccc7755555555555550000005555500000666003333000000b00000eeeee000000b30
777cc7777777ccccc777777ccccc77777777ccc7777777777ccc777777cccc775505555555555500005555550007777600044000000b000000ee3ee003000b00
777cc777777777777777777777777777777777777777777777777777777cc7775555555555555550055555550000076600044000030b00300000b00000b0b300
77cccc77577777777777777777777775577777777777777777777775577777755555555555555555555555550000005500999900030330300000b00000303300
5777755777577775077777777777777777777770077777700000000000000000cccccccc55555555500000055555555500000000000000005555555500000000
7777777777777777700007770000777000007777700077770000000000000000c77ccccc05555555550000555555555000000000000040005555555500040000
7777cc7777cc777770cc777cccc777ccccc7770770c777070000000000000000c77cc7cc00555555555005555555550000000000050590005555555500095050
777cccccccccc77770c777cccc777ccccc777c0770777c070000000000000000cccccccc00055555555555555555500000006000505090005555555500090505
77cccccccccccc777077700007770000077700077777000700005dddddd50000cccccccc00055555555555555555500000060600505090005555555500090505
57cc77ccccc7cc7577770000777000007770000777700007000d11111111d000cc7ccccc00555555555555555555550000d00060050590005550055500095050
577c77ccccccc7757000000000000000000c000770000c07000d11111111d000ccccc7cc0555555555555555555555500d00000c000040005500005500040000
777cccccccccc777700000000000000000000007700000070005111111115000cccccccc555555555555555555555555d000000c000000005000000500000000
777cccccccccc7777000000000000000000000077000000700085d7766d580000000000000000000000000000000000c00000000c00600000000000000000000
577cccccccccc7777000000c000000000000000770cc0007000e77eee88e8000000000000000000000000000000000d000000000c060d0000000000000000000
57cc7cccc77ccc7570000000000cc0000000000770cc0007000e77eee88e800000000000000000000000000000000c00000000000d000d000000000000000000
77ccccccc77ccc7770c00000000cc00000000c0770000c070008e7eee88e80000000000000000000000000000000000000000000000000000000000000000000
777cccccccccc777700000000000000000000007700000070008ddd8888e80005555555566666606600660660066066006606600000066660006666006666660
7777cc7777cc777770000000000000000000000770c00007000d7777dd88dd005555555566666606600660660066066066606600000666666066666606666660
777777777777777770000000c0000000000000077000000700d7777777d777d05555555566000006600660666066066666006600000660066066000000066000
57777577775577757000000000000000000000077000c0070777777777777ddd55555555dddd000dd00dd0dddddd0dddd0006600000dd00dd0dddddd000dd000
000000000000000070000000000000000000000770000007000000005000000000000005dd00000dd00dd0dd0ddd0dd0dd00dd000d0dd00dd000000d000dd000
00aaaaaaaaaaaa00700000000000000000000007700c0007000000005500000000000055dd00000dddddd0dd00dd0dd00dd0dddddd0dddddd0dddddd000dd000
0a999999999999a0700000000000c0000000000770000007000000005550000000000555dd000000dddd00dd00dd0dd00dd0dddddd00dddd000dddd0000dd000
a99aaaaaaaaaa99a7000000cc0000000000000077000cc07000bb700555500000000555500000000000000000000000000000000000000000000000000000000
a9aaaaaaaaaaaa9a7000000cc0000000000c00077000cc0700b7bb0055555555555555550000000000000c000000000000000000000000000000c00000000000
a99999999999999a70c00000000000000000000770c00007000b00005555555555555555000000000000c00000000000000000000000000000000c0000000000
a99999999999999a700000000000000000000007700000070000000055555555555555550000000000cc0000000000000000000000000000000000c000000000
a99999999999999a07777777777777777777777007777770000000005555555555555555000000000c000000000000000000000000000000000000c000000000
aaaaaaaaaaaaaaaa0777777777777777777777700777777000000000000000005555555500000000c00000000000000000bbbb0000777700000000c000000000
a49494a11a49494a700077700000777000007777700077771011110100111100555555550000000100000000400000000bb77bb007777770000000c00c000000
a494a4a11a4a494a70c777ccccc777ccccc7770770c77707111717110117171055555555000000c00000000090000000bb7777bb777777770000001010c00000
a49444aaaa44494a70777ccccc777ccccc777c0770777c07111199110111991055555555000001000000000090000000b6b773337777777700000001000c0000
a49999aaaa99994a77770000077700000777000777770007011777101117771100000000000001000000000090000000b6b33333777777770000000000010000
a49444999944494a77700000777000007770000777700c07011777101117771100000000000001000000000090000000bb333333777777760000000000001000
a494a444444a494a700000000000000000000007700000070117771001177710000000000000000000000000400000000b333330077777600000000000000000
a49499999999494a0777777777777777777777700777777011995990119959900000000000010000000000000000000000333300006666000000000000000010
0000000000a3934252525252525252526200133323232323232323232323232362a2037303731333133313525252525223339200000000a20182920013232352
0324343444b2000000000000000000005252232323232352525252628282825223232323232323528462b200b3425252e300a282820012222222222232000000
0000000000a283425284525252525252620012321000f3008282000000e3024262007300739200a2a2a2834284525252839200000000000000a20000b1a28213
0325353545b2000000000000000000005233828282828242525252628282014201920000000000135262b200b313845222223283920013525284525262111111
000000000000a2425252525252525252620013331222223282010000001222426200b100b10011110000a213235252529200000000000000000000000000a283
0325353545b2110000000000000000006282829200a2824252525262a2828242000000111100a3834262b20000a21352845233920000a2132323525284222222
000000000000a31323235252525284526200123213232333928243535323234262c700000000123200c10000b342528493000011000000000000210000000082
0326363646123200000000000000000062828211110082425252526200829242d3100012638282824233b2000000820352339300000000a28201132323525252
0000000000a38292a20142525252525262004262b1b1b1b100a2b1b1b1b1b1426200110011a3426200000000b34252529200b302b211000000000200110000a2
422222222252620000000000000000006282824363a3821323235262b282b34232435333920000a203040000000083736201920000000000a282828382132384
00000000a3839200a1a24252525252526200426200000000c70000a3828201426211722172a24262e3d3000000425252000000b1b302b21100000000020000d3
132323232323330000000000000000006200a2827282828282821333b282b3425222639300000011030000f300008201339200000000000000a2a28282018213
000000a3829200000000132352525252620013620000000000a2828283018242627203720321422322320000004284520000000000b1b302b200a28382930002
0000000000000000000000000000000033110082039200a282920014008293425233a2010000111252222232b200a2829200000000000000000000a2a2828283
0000a3019200000000000082428452526200000311111111111111111100004252222222225333a2426293610013232300100000000000b10000000000a29300
00000000000000000000000000000000536300a203000000000000000083824262b200820000125252845262b2000082000000000000a39300000000c7a2a292
00c08292000000000000008213525252331100035353535353535353320000135252232333b1b1004262920000000072007211111111111111111111a392a293
0000000000000000000000061600000032820000030000000011111100a2824262b2008293c0425252525262b20000a20000000000a382829300000000000000
0000a20000000000000000a28242525232b1000302b1b1b1b1b1b1b17300a3125233929200000000426211111100a303004253535353532222535363b2000002
000000000000000000000007170000006282610003111100a31222320000824262b200a28393425284525233b200000000000000a30192a28293000000000000
0000000000000000000000008342525262c71103b200a393a2829200b100a2426292000000000000425253536300a2730073b1b1b1b1b11333b1b1b1000000a2
00000000000000000000d3123200000062920000422232b28242526200a3824262b2000000a21323232333000000111100000000a28293a38292000000000000
0000000000000000000000008242525262001262b2a382a2838200000000004262d310f3d300000042629292000000b100b1a28293a382b1b1a383a2829300a3
00000000c2000000000012525232000062111111422333b282132362a3928242523211000000004353630000000043630000000000a282839200000000000000
0000000000000000000000008213528462004262b2a382111111111100c70042522222223211211142629200000000110000009200a2920000a2920082820002
00000000c3100024344442525262e3005222535333920000828282038200a24252523211006100a28282006100111222000000000000a2920000000000000000
000000000000000000000000a201425262c213338282001222222232110000425252525252327143233300b3570000720085860000a393111100930082920024
000000122222322535454284525232005233000000000000a2828303820000428452523211000000839200001172425293000000000000000000000021210000
0000000000000000000000001082425262c3828282938242525284523211114252528452526200a2829300a372b2b30300a282932192a21232d4828292000025
0000125252526225354542525252522262f310d30000000000828203926100425252846272110000a200001143334284b41000f3000000000000001112321111
00000000000000000000001222225252522222222222225252525252522222525252525252622434343444a203b2b303000000837100004262a3018200000025
000042528452622535454252528452525222222232000000a382826200000042525252621363b2000000b3122222525222222232930000000000b31252522232
525223232323232323232323236282922333b1b1b1b1b1b1b1b14213233382005252845223235262b200b34284528452363636363636363645b200b325353636
132323232323232323330000a39200b3525252624252628382132323235284520000000000000000001323232323525200000000000000000000000000000000
8462b2b1b1b1b1b1b1b1b1b1b10392006282828393a393a393a342845262a2938452523392924262b200b31323232384d31000a393b302b255b200b3254600c2
c200a292b1b1b1b1002444e3940000b352845262132362920000a283b342522300006700000000a3a4a493000000428400000000000000000000000000000000
5262b200a393000000000000a303000062b2a392a292a292a2921323233300a2522333d492f44262b2c7000000c7b342373737478227343445b200b3550200c3
c3100000000000a4a3253544920000b35252522363726200e3000082b3133312002737374772009492a2b4000000135200000000000000000000000000000000
5262b2a382839300000000a38203b20062b2a293001111110000a293010000006292009261924262b21100411100b3428282838282b3253546b200b326373737
122232111111118292263646000000b352233392007342222232b292b3122252001222222233009493a3b4000000004200000000000000000000000000000000
5262b2a282829200000000a20103b20062b20192b3b2b100000000a2820000006221610092614252222222223200b3428382920192b32545b20000a2a282b1b1
13233343535363b400122222329300b33301920000a342845262b200b342525200132384620000a2e4e49200000000420000000000000000c400000000000000
5262b200a29200e300000000a203b20062829200b3b200c700000000a283828262c2d40000f442522323232333c7b3428292000000b32645b2000000a2a28293
00000072b2a3929400425252621193b382820000a28313232333b200b342525200019313330000006474001222222252000000000095a5b5c5d5e5f500000000
5262b20000b3123200110000a203b2005232b20000b11111111111111111111162c3002100d3426200a39200c200b342821111111111d355b200000000a20083
00000003b21100b411428452523294b3839261000000b1b1b1b10000b342528493a20193000000006575004252528452000000000096a6b6c6d6e6f600000000
5262b20000b34262b302b2001103b200525232b20000b1b1b1b1b14353535353522222222222846200820002c300b3428227373737373745b20000f3000000a2
006100030072a39272425252244483b3000000000000000061000000b313232382939482768512222222634284525252000000000097a7000000e7f700000000
8462b20000b3426200b100b30273b200525262b20000c700000000a2018282828452522323232333009493123200b342920000000000b3254493a302040000a2
1100860300739200032434343545b4000000110000001111111111111112536383829200a2824252846212522323235200000000000000000000000000000000
5262b20000b3426200110000b1000021528462b21111110000000000a2828282528462b1b1b1b102009483133300b342000000000000b3254501920000000000
72a3b47300000000732636363646920000b372b2000012535363024353338392a292000071711323233313338283824200000000000000000000000000000000
5262b20000b34262b302b20093920071232323535363721111111111118282a223233300000000b1a3839272b2000042000000000000b3254511111111000000
039200000000000000b1b1b1b1b1000080b303b200a3039200a292000000d34100000000a3827686920000a28282834200000000000000000000000000000000
2333b20000b3426200b10000a3a200009300000001927353535353637282820000a283930011768601920003b2b3125211111111930011253534343447b200b3
0300000000000000000000000000000000b373b200837300f300000000a34363000000a38392000000000000a292004200000000000000000000000000000000
9200000000b342629300001100000000839300008200b1b1b1b1b10203928200100094b42102921111111103b2b34252343434448283273636363646b20000b3
730000110000a37685111111111100000000b100a382b1a343536393a30192127171a382b4000000000000000000004200000000000000000000000000000000
f310000000b313339200b302b200a3a3a292c20082e30000000000b373009200343434343444214353536373b2b342843636354500828200a30182a2006100a3
b100007286a48283931222222232002100930000a2829383b31232829200004200a3920000000010000000720012225200000000000000000000000000000000
1222320000a38282930000b10000a3821000c3a3820211111111000000000000353535353545c7a292a28792800042526700254500a282828283920000000082
1111110311110000a242525252620002a383610000a20182b342628200100042a382930071711222223200422252525200000000000000000000000000000000
42526200a382820182930000a3a3828322222222222222222232c70000212100353535353545111111111111122284522232254571718283820000000000a383
122222522232000000425252526200008201930000a38282b3426283001222528282827685864252846200428452845200000000000000000000000000000000
__label__
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7700000000000000000000000077cccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc7cccccccccccccccccccccc7700000000000000000000000077cccccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc77ccc7700000000000000000000000077cc7ccccccccccc
ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc77c6c7700000000000000000000000077cccccccccccccc
ccc77cccccc77cccccc77cccccc77cccccc77cccccc77cccccc77cccccc77cccccc77cccccc77cccccccc777000000000000000000000000777cccccccc77ccc
c777777cc777777cc777777cc777777cc777777cc777777cc777777cc777777cc777777cc777777ccccc77770000000000000000000000007777ccccc777777c
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777770000000000000000000000007777777777777777
77777777777777777777777777777777777777777777777777777777777777777777777777777777777777750000000000070000000000005777777777777777
55555555555555556665666566656665666566656665666500000000000006665777777557777777777777750000000000000000000000005555555500000666
51555555555555516765676567656765676567656765676500000000000777767777777777777777777777770000000000000000000000005555555000077776
5555115555555511677167716771677167716771677067700000000000000766777777777777cccccccc77770000000000000000000000005555550000000766
5555115555555111171117111711171117111711070607000000000000000055777cc777777cccccccccc7770000000000000000000000005555500000000055
555555555555111117111711171117111711171107000700000000000000066677cccc7777cccccccccccc770000000000000000000000005555500070000666
551555555551111111111111111111111111111100000000000000000007777677cccc7777cc77ccccc7cc770000000000000000000000005555550000077776
555555555511111111111111111116111111111100000000000000000000076677c7cc7777cc77cccccccc770000000000000000000600005555555000000766
555555555111111111111111111111111111111100000000000000000000005577cccc7777cccccccccccc770000000000000000000000005555555500000055
111111111111111111111111111111111111111555555555000000000000066677cccc7777cccccccccccc770000000000000000000000005555555500000666
1111111111111111111111111111111111111155555555500000000000077776777ccc77777cccccccccc7770000400000000000000000000555555500077776
0000000000000000000000000000000000000555555555000000000000000766777ccc77777cccccccccc7770505900000000000000000000055555511111766
000000000000000000000000000000000000555555555000000000000000005577ccc7777777cccccccc77775050900000000000000000000005555511111155
000000000000000000000000000000005555555555555000000000000000066677ccc7777777cccccccc77775050900000000000000f00000005555511111666
1111111111111111111111111111111155555555555555111111111111177776777cc777777cccccccccc7770505900000000000000000000055555511177776
1111111111111111111111111111111155555555555555511111111111111766777cc777777cccccccccc7770000400000000000000000000555555511111766
111111111111111111111111111111115555555555555555111111111111115577cccc7777cccccccccccc770000000000000000f00000005555555511111155
777777755511111111111111111111111111111155555555111111111111166677cccc7777cccccccccccc770000000000000000000000055555555511111666
7777777766711111111111111111111111111111515555551111111111177776777ccc7777cccccccccccc770000000000000000000000555555555111177776
cccc777767777111111111111111111111111111555511551111111111111766777ccc7777cc7cccc77ccc770000000000000000000005555555551111111766
ccccc7776661111111111111100000000000000055550055000000000000005577ccc77777ccccccc77ccc770000000000000000000055555555701111111155
cccccc775511111111111111100000000000000055555555000000000000066677ccc777777cccccccccc7770000000000000000000555555555000000000666
ccc7cc7766711111111111111000000000000000550555550000000000077776777cc7777777cccccccc77770000000000000000005555555550000000077776
cccccc7767777111111111111000000000000000555555550000000000000766777cc77777777777777777770000000000000000055555555500000000000766
cccccc776661111111111111100600000000000055555555000000000000005577cccc7757777777777777750000000000000000555555555000000000000055
cccccc775500000000000000000000000000000055555555500000000000066677cc6c7700000000000000000000000055555555555555550000000000000000
ccccc77766700000000000000000000000000000055555555500000000077776777ccc7700000000000000000000000005555555555555500000000000000700
ccccc77767777000000000000000000000000000005555555550000000000766777ccc7700000000000000000000000000555555555555000000000000000000
cccc77776660000000000006007000700070007000055555555500000000005577ccc77700700070007000700070007000055555555550000000000000000000
cccc77775500000000000000007000700070007000005555555550000000066677ccc77700700070007000700070007000055555555500000000000000000000
ccccc77766700000000000000677067706770677000005555555550000077776777cc77706770677067706770677067700555555555000000000000000000000
ccccc77767777111111111115676567656765676111111555555555111111766777cc77756765676567656765676567605555555550000000000000000000000
cccccc776661111111111111566656665666566611111115555555551111115577cccc7756665666566656665666566655555555700000000000000000000000
cccccc775511111111111666577777777777777511111111555555551111166677cccc7757777777777777777777777555555555000000000000000000000000
ccccc77766711111111777767777777777777777111111115555555111177776777ccc7777777777777777777777777755555550000000000000000000000000
ccccc77767777111111117667777cccccccc7777111111115555551111111766777ccc777777ccc7777777777ccc777755555500000000000000000000000000
cccc77776661111111111155777cccccccccc77711111111555551111111115577777777777ccccc777777ccccccc77755555000007000700000000000000000
cccc7777550000000001166677cccccccccccc7711111111555551111111166677c76677777ccaac776677c7ccccc77755550000007000700000000000000000
ccccc777667000000007777677cc77ccccc7cc77111111115555551111177776777c77767777cc97677777777ccc777755500000067706770000000000000000
ccccc777677770000001176677cc77cccccccc77111111115555555111111766777cc66777777947766777777777777755000000567656760000000000000000
cccccc77666111111111115577cccccccccccc7711100000555555550000005577ccc777aaaaaa47777777777777777550000000566656660000000000000000
cccccc77551111111111166677cc6ccccccccc77555555555555555500000666777ccc779aaaa4aa000000055555555500000666577777755500000000000000
ccccc7776671111111177776777cccccccccc777555555555555555000077776777cc77749944aaa000000555555555000077776777777776670000000888800
ccccc7776777711111111766777cccccccccc777555555555555550000000766777cc7779aaaaaa0000005555555550000000766777777776777700008888880
cccc777766611111111111557777cccccccc777755555555555550000000005577ccc77709aaaa00000055555555500000000055777cc7776660000008788880
cccc777755111111111116667777cccccccc777755555555555500000000066677cccc770000000000055555555500000000066677cccc775500000008888880
ccccc7776671111111177776777cccccccccc77755555555555000000007777677cccc770000000000555555555000000007777677cccc776670000008888880
ccccc7776777711111111766777cccccccccc777555555555500000000000766777cc7770000000005555555550000000000076677c7cc776777700008888880
cccccc77666111111111115577cccccccccccc77555555555000000000000055577777750000000055555555500000000000005577cccc776660000000888800
cccccc77550000000000066677ccccccccccc677f0f0f0f00000000000000000000000000000000055555555000000000000066677cccc775500000000060000
cccccc776670000000077776777cccccccccc7770000000000000000000000000000000000000000555555500000000000077776777ccc776670000000060000
c77ccc776777700000000766777cccccccccc777000000000000000000000000000000000000000055555500f000000000000766777ccc776777700000060000
c77ccc7766600000000000557777cccccccc7777000000000000000000000000000000000000000055555000000000000000005577ccc77766600000f0f060f0
ccccc77755000000000006667777cccccccc7777000000000000000000000000000000000000000055555000000000000000066677ccc7775500000000006000
cccc77776670000000077776777cccccccccc7770000000000000000000000000000000000000000555555000000000000077776777cc777667000f000f06000
777777776777700000000766777cccccccccc7770000000000000000000000000000000000000000555555500000000000000766777cc7776777700000006000
77777775666000000000005577cccccccccccc77000000000000770000000000000000000000000055555555000000000000005577cccc776660000000000000
55000000000000000000000077cccccccccccc770000000008877740000000000000f0000000f00055555555500000000000f66677cccc7755000000f0000000
667000000000000000000000777cccccccccc7770000004487884444000000000000011111111111155555555511111111177776777ccc776671111111110000
677770000000000000000000777cccccccccc7770000044448111114000000000000011111111111115555555551111111111766777ccc776777711111110000
66600000000000000070f0707777cccccccc77770000044444f11f1400000000000001111111111111155555555511111111115577ccc7776661111111110000
5500000000000000007000707777cccccccc77770000044444ff77f000000000000001111111111111155555555555551111166677ccc7775511111111110000
667000000000000006770677777cccccccccc7770000004444cccc00000000000000011111111111115555555555555511177776777cc7776671111111110000
677770000000000056765676777cccccccccc7770000000007000070000000000000011111111111155555555555555511111766777cc7776777711111110000
66611011111111115666566677cccccccccccc77111111111111100000000000000001111111111155555555555555551111115577cccc776661111111110000
551110111111166657777777cccccccccccccc771117711111111000000000070000000055555555555555555555555500f00666777ccc775500000000000000
667110111117777677777777c77cccccccccc7777177711111111000000000000000000005555555555555555055555500077776777cc7776670000000000000
67777011111117667777ccccc77cc7ccccccc7777777771111111000000000000000000000555555555555555555005500000766777cc7776777700000000000
6661101111111155777ccccccccccccccccc77777777771111111000000000000000000000055555555555555555005500f0005577ccc7776660000000000000
551110111111166677cccccccccccccccccc7777777777111111100000000000000000000000555555555555555555550000066677cccc775500000000000000
667110111117777677cc77cccc7cccccccccc777977797111111100000000000000000000000055555555555550555550007777677cccc776670000000000000
677770111111176677cc77ccccccc7ccccccc7774111411111111111111111111111111111111155555555555555555500000766777cc7776777700000000000
666000111111115577cccccccccccccccccccc771111111111111111111111111111111111111105555555555555555500000055577777756660000000888800
550000000000066677cccccccccccccccccccc771111111111111111111111111111111111111111111111115555555500000000666566650000000008888880
667000000007777677cccccccccccccccccccc771111111111111111111111111111111111111111111111110555555500000000676567650000000008788880
677770000000076677cc7cccccccccccc77ccc771111111111111111111111111111111111111111111111110055555500000000677067700000000008888880
666000000000005577ccccccccccccccc77ccc771111111111111111111111111171117111711171111111110005555500000000070007000000000008888880
5500f00000000666777cccccccc77cccccccc7771111111111111111111111111171117111711171111111110005555500000000070007000000000008888880
66700000000777767777ccccc777777ccccc77771111111111111111111111111677167716771677111111110055555500000000000000000000000000888800
67777000000007667777777777777777777777771111111111111111111111115676567656765676111111110555555500000000000000000000000000060000
66600000000000555777777777777777777777750001111111111111111111115666566656665666000000005566555500000f000000000000f00000000600f0
00000000000000005555555550000000000000000001111111111111111116665777777777777775550000005566555500000000000000000000000000060000
00000000000006f005555555550000000000000000000000000000000007777677777777777777776670000055555550000000000000000000000000f0006000
00000f000000000000555555555000000000000000000f0000000000000007667777ccc77ccc777767777000555555000000000f00000000000f000000006000
0066000000000000000555555555000000000000000000000000000000000055777cccccccccc777666000005555500000000000000000000000000000006000
0066000000000000f00055555555500000000000000000000000000000000666777cccccccccc77755000000555550f000000000000000000000000000006000
00000000000000000000055555555500000000000000000000000000000777767777ccc77ccc7777667000005555550000000000000000000000000000000000
11111111111111111111115555555551111111111111111111110000000007667777777777777777677770005555555000000000000000000000000000000000
11111111111111111111111555555555111111111111111111110000000000555777777777777775666011115555555511111111111111111111111111111111
11111111171111115555555555555555111111111111111111110000000000000000000000000000000011115555555511111111111111111111111151111115
11ee1ee1111111111555555555555551111111111111111111111111111111000000000000000000000011115555555511111111111111111111111155111155
11eeeee11111111111555555555555111111111111111111111111111111110000000000000000f0000011115555555511111111111111111111111155511555
000e8e00000fff000f05555555555111117111711111111111111111111111000000000000000000000011115555555511111111111111111111111155555555
f0eeeee0000000000005555555551111117111711111111111111111111111000000000000000000000011115555555511111111111111111111111155555555
00ee3ee0000000000055555555511111167716771111111111111111111111000000000000000000000011115551155511111111111111111111111155555555
0000b0000000000005555555551111115676567611111111111111111111110000000000000000000000000055000055000000000000000f0000000f55555555
0000b000000000005555555551111111566656661111111111111111111111000f00000000000000000000005000000500000000000000000000000055555555
7777777500000000555555551111111157777775111111111111111111111100000f000f00000000000000000000000000000000000000000000000555555555
777777770000000055555551111111117777777711111111111111111111110000000000000000000000000f0000f00000000000000000000000005555555550
cccc77770000000055555501111111117777777711111111111111111111110000000000000000000000000000000000000f0000000000000000055555555500
ccccc777000000005555500000000000777cc777007000700000000000000f0000000000000000000000000f00f0000f0000000f000000000000555555555000
cccccc77000000005555500f0000000077cccc77007000700000000000000000f000000000000000000000000000000000000000000000005555555555555000
ccc7cc770000000055555500f000000077cccc770677067700000000000000000000000000000000000000000000000000000000000000005555555555555500
cccccc7700000000555555500000000077c7cc775676567600000000000000000000000000000000000000000000000000000000000000005555555555555550
cccccc7700000000555555550000000077cccc77566656660000000000000000000000f000000000000000000000000f00000000000000005555555555555555
cccccc77000000005555555550000000777ccc775777777555000000000000000000000000000000000000000000000000000000000000055555555550000000
cccccc77111111111555555555111111777cc7777777777766711111111111100000000000000000000000000000000000000000000000555055555555000000
c77ccc77111111111155555555511111777cc777777c77776777711111111110000000000000000000000000000000000000f000000005555555005555500000
c77ccc7711111111111555555555111177ccc77777cccc7766611111111111100000000000000000000000000000000000000000000055555555005555550000
ccccc77711111111111155555555511177cccc7777cccc775511111111111110000000000000000000000f000000000f00000000555555555555555555555000
cccc777711111111111115555555551177cccc77777cc77766711111111111100000000000000000000000000000000000000000555555555505555555555500
77777777000000000000005555555550777cc7777777777767777000000000000000000000000000000000000000000000000000555555555555555555555550
7777777500000000000000055555555557777775577777756660000000000000000000000000000000000000000000000f7f0000555555555555555555555555
000000000000000000000000555555550000000000000000000000000000000550000000ff000000000000000000000000000005555555550000000055555555
0000000000000000000000005555555500000f00f000000000000000000000555500000000000000000000000000000000000055555555500000000005555555
00000000000000000000000055555555000000000000000000000000000005555550000f00000000000000000000000000000555555555000000000000555555
0000000000000000000000005555555500000000000000000000000000005555555500000000000f000f00000000000000005555555550000000000000055555
00000000000000000000000055555555000000000000000000000000000555555555555555555555555555555555555555555555555550000000000000005555
000000000000000000000000555005550000000000f0000000000000005555555555555555555555555555555555555555555555555555000000000000000555
0000000000f00000f0f0f0f055f0f055000000000000f00000000000055555555555555555555555555555555555555555555555555555500000000000000055
00000000000000000000000050000005000000000000000000000000555555555555555555555555555555555555555555555555555555550000000000000005

__gff__
0000000000000000000000000000000004020000000000000000000200000000030303030303030304040402020000000303030303030303040404020202020200001313131302020302020202020202000013131313020204020202020202020000131313130004040202020202020200001313131300000202020200000202
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
25260000002425333132323225254825252548331b1b1b2425482526002a242526002a2a28282425323232332425253225260000003125253233313232322525382828290031323232323232254825252532323232323232323232330000000033000000371b1b1b1b1b1b1b1b1b1b1b253300002831331b1b1b313232252548
253300000031331b1b1b1b1b312525252548262c000000242525252600002448263900002a38242629002a283125262025260000006831332900002a293d2448282829000000000000002a2831322548260000003a28292a28290000000000002839003a390000000000001100000000332b00002a2867000000000000242525
2640000000582800000000003a2425252525263c00000024252548260000242526283900002a24261a00002a282425224826390058282829000000000034322522222300000000000000162a382831322600003a2838393a29000000000011112829002a2839001100003b202b000000434343442b0049282839001100244825
2600003a2828286700000058283125254825482223390031323232330000242526102900002a2426000000002a31252525262828382828000000000000281024482525232b000000000000002a28282826393a102900000000000000111121222800160028293b202b00001b00001100535353542b004e1600283b202b242525
2522232838285828393a281028282425323232323328003a2828282900002448262911000000243320111111002a313225262828282900000000000000002824252548262b00000011000000002a281026282829000000000000000021222548280000002a2c001b00000000003b202b535353542b0000000028001b00242525
252526282800002a28282829002c242500005828282900727373740000002425333b202b000030212222222300002a2a25252329111111111111000000002a24253232332b00163b202b000000082a2a332a290000001111111100003132323223000000003c00140000000000001b00636363642b000011112a4b0000313232
2548262829003e0028390000003c2425003a281028580000000000000000313229001b00003a373132323233000000002532333b343535353523000000123e24332122232b0000001b00003d2123003f280000000000212222230000000000002639003b2122222339000000003a39000028000000000021232b490000212223
2525252222222223202868283934252522232900282800000000111100000000000000003b343536382829290000000026102900001b1b1b1b3700003a343535222532332b00000000003a212525222238393e000000242548265858585839002639393b242525332a393a393a2828390028000000006824262b4b004f242526
25323232323232323536282828283125252523002a286700111121230000003a110000003b21222328290000000000112629000000000000000000002828003b25262b00003a4a39003b212525254825222223000000242525267878787829002629293b31323339002a292a293b21220049670000004931332b2a6700313233
2600000000002839000000002a28382432322523002828282122482600003a28200000003b3132332900000000003a21332900000000000000003a282900003b32332b000049104b003b3125482525252532330000002425253300001600000026290000112a4b4939000000003b242500002839003a2900000000494b212222
26010000003a2828000000000028292428383126003a2838244825263a3a382823000000000000000000000011002a312900000000111111115810283912003b28290000002a4e2900003b3132323232262a4b000000242533585858583900002600003b202b2a392a390000003b3125586838282828002c000016002a242525
252300000028002a2867000000285824282900370000002a24252526727421233339000000000000000000002700002a00013f0000212222232829002827003b2900002c000000000000000000002a2826002a393d0024267878787878290000260000001b0000212222232b0000002400492829004e003c0000000000242548
25330000682800002828000000212225280100000000006831323233212225262223390000003a3a3900000030000000222222230024253232353523212222223e01003c00000000000000000000142a2600002a21222526000000000000000026000000000000242525262b0000002400002800002122230000000000242525
26000000281000002123111111242548727374270000002828212223242548264826290000004243443900003000013a3232322600243300003a0030242525252222222300000000003f3e3a3a212222260001002425252600000000001111112601003a284e28242548262b003b21253d012839002425260000001111242525
26003f3a21231111242522222225252521222226110000002824253324252526252611111111626364103900302122220000003039302900002867302425482548252526390000003a212222222542442621222225254826111100000021222225222223675868242525262b003b2425222328000024252600003b2122252525
25222222252621222525252525252525313232323628393a28313321254825262525222222222222232828393024254800000030103000003a28283024252525252548482339003a28244825254253542624482525252525222300000024482525482526282828242525262b083b2425252628000024252600003b2425482525
254825253232323232323225323300002532323232323232323232322525252538291b1b1b1b1b1b1b1b1b1b1b3125252525252525252525264e3b313232252532323232323232333132252526293b31323232323232323232323300000031322525482525252525252525482525323228292a24253232252548253232252525
323232330000000000343630280000003328382828290000001b1b1b31322525290039007c00000000002a282810312525482525254825252668391b1b1b31251b1b0011001b1b00111b31322612004f38291b1b1b1b003b2721230000004b3b252525252525254825252532323328283816002433292a312532333829312548
00002a3839000000000000302900003a2a28282829000000000000001b1b3126003a280000000000002a0000002a2824252525252525323226283900007c3b314d00002017204d1127001b1b3717003b01000000684b003b3024264d0000493b253232323232323232323300002a283829000037290000003738290000003132
0000002a281039110000003000000010002a2810000000000000000000001b370028100011000000393a000046472c24252525482533000037124b111111581b2b004f1000003b34264d170000000012232b00000038003b30313300003a293b33281028290000000000000000002a280000001b000000001b28000000000000
3e000000002a282039000030000034350000282900000000000000000000001b0028283b272b007c002a393e56573c2425252525260000000034352223204b7c2b0000290011114f3136274d11113b20262b0011112a393b30111111492900003828292900000000000000390000002a00000000003d00003a28001100000000
2223110000111127290000300000002a000029000000003e0000000000000000222222222611111100002a212222232425252525267c000000000031261b49112b0000003b212312001b312222231111262b3b2123004b3b30343536291100002829000000000000003a00283900120000000000003c3a2810283b2700000000
3232362b0034363000003a30393d000000000000003435360000000000000000254825323235353639000024254826242548252526001111117c003b307c4b202b1200110031252311004f3132332122262b3b242628293b37003a293b272b1629000000000000003828281028001700111100003b34362b2a283b3000001717
38290000001b1b30000010373436000000000000003a10283900000000000000323233002a28282829000024252526242525252526003435231100003711491b2b202b202b1b3125231200001b3b3132332b3b242600000000004b003b302b000000000000000000002a28282900000035362b00001b1b00002a393000000000
000000000000003000002a282900000000007c00002a282839111100000000000000003a28282829000000313232333125252525267c3a383123110000204b7c2b1b001b00001b3125234d29294f21222b00112426000000000049673b302b000000000000007c000000002a000000001b1b00000000000011002a373e000000
222311000011113000003f280000003a003a390000002a28382123111100000000003a28287c000000000021222223212525254826004929003123113d3e4967204d00001100001b31334d29294f31252b3b2148264d0000002a28383b372b00000000003a2800000000000000111111000000000000000027000034362b0000
3232362b00343631353536283900002a3a383900000000002a24252223110000003a382a2828390000000024252526242525252526112900003b4273737373731b00002a201100001b1b002900004f242b3b31323300000011110049001b001600000000283800000000001111212222000000001100003a3000000000000000
00000000000000000000002a383900002a2a2a6700000000002448252523110001283900002a2839003d3f244825262432323225252311007c3b552122222222001200004f2011000011000000003b2400002a390000003b34362b4b000000000000003a28290000000011212225252500000000273a28103700000000000000
0001000000000000000000002a2867582c00002829000000112425252525232b2122230000002a21222222242525262410293a313232362b003b552425254825002039393a29204d3b27001100003b243e004929110000000000004e0000004a0000002829000000001121252525254839013d00303828282700000000000000
2223003d00000000003a3900002a29113c01002a39000000212525254825262b242526000021222325252524252526243e012839001b1b00003b55244825252501002a38290038003b303b202b003b2423004b0027110000001c00000000684b00003a28000000000021252525252525382123393729002a3067683900171717
48267274000000003a281039111111212222222329000011242525252525262b24482622222325262548252425252624222223297c0000007c3b55242548252523005600123a29003b30391b00123b3133002a3937202b000000000000683839013a281029001200002425482525252542442610270012003038102839000000
25252223003a2828382828282122222525254826000000212525482525252523242526254826252625252524252526242525261111111111113b55242525252548222223272900003b3028393927003a0000004e0000003a67585858684b002a2223282829002700002425252525252552542628300017003028283828675858
__sfx__
0002000036370234702f3701d4702a37017470273701347023370114701e3700e4701a3600c46016350084401233005420196001960019600196003f6003f6003f6003f6003f6003f6003f6003f6003f6003f600
0002000011070130701a0702407000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300000d07010070160702207000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200000642008420094200b420224402a4503c6503b6503b6503965036650326502d6502865024640216401d6401a64016630116300e6300b62007620056100361010600106000060000600006000060000600
000400000f0701e070120702207017070260701b0602c060210503105027040360402b0303a030300203e02035010000000000000000000000000000000000000000000000000000000000000000000000000000
000300000977009770097600975008740077300672005715357003470034700347003470034700347003570035700357003570035700347003470034700337003370033700337000070000700007000070000700
00030000241700e1702d1701617034170201603b160281503f1402f120281101d1101011003110001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00020000101101211014110161101a120201202613032140321403410000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00030000070700a0700e0701007016070220702f0702f0602c0602c0502f0502f0402c0402c0302f0202f0102c000000000000000000000000000000000000000000000000000000000000000000000000000000
0003000005110071303f6403f6403f6303f6203f6103f6153f6003f6003f600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
001000200177500605017750170523655017750160500605017750060501705076052365500605017750060501775017050177500605236550177501605006050177500605256050160523655256050177523655
002000001d0401d0401d0301d020180401804018030180201b0301b02022040220461f0351f03016040160401d0401d0401d002130611803018030180021f061240502202016040130201d0401b0221804018040
00100000070700706007050110000707007060030510f0700a0700a0600a0500a0000a0700a0600505005040030700306003000030500c0700c0601105016070160600f071050500a07005050030510a0700a060
000400000c5501c5601057023570195702c5702157037570285703b5702c5703e560315503e540315303e530315203f520315203f520315103f510315103f510315103f510315103f50000500005000050000500
000400002f7402b760267701d7701577015770197701c750177300170015700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
00030000096450e655066550a6550d6550565511655076550c655046550965511645086350d615006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
011000001f37518375273752730027300243001d300263002a3001c30019300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
011000002953429554295741d540225702256018570185701856018500185701856000500165701657216562275142753427554275741f5701f5601f500135201b55135530305602454029570295602257022560
011000200a0700a0500f0710f0500a0600a040110701105007000070001107011050070600704000000000000a0700a0500f0700f0500a0600a0401307113050000000000013070130500f0700f0500000000000
002000002204022030220201b0112404024030270501f0202b0402202027050220202904029030290201601022040220302b0401b030240422403227040180301d0401d0301f0521f0421f0301d0211d0401d030
0108002001770017753f6253b6003c6003b6003f6253160023650236553c600000003f62500000017750170001770017753f6003f6003f625000003f62500000236502365500000000003f625000000000000000
002000200a1400a1300a1201113011120111101b1401b13018152181421813213140131401313013120131100f1400f1300f12011130111201111016142161321315013140131301312013110131101311013100
001000202e750377502e730377302e720377202e71037710227502b750227302b7301d750247501d730247301f750277501f730277301f7202772029750307502973030730297203072029710307102971030710
000600001877035770357703576035750357403573035720357103570000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
001800202945035710294403571029430377102942037710224503571022440274503c710274403c710274202e450357102e440357102e430377102e420377102e410244402b45035710294503c710294403c710
0018002005570055700557005570055700000005570075700a5700a5700a570000000a570000000a5700357005570055700557000000055700557005570000000a570075700c5700c5700f570000000a57007570
010c00103b6352e6003b625000003b61500000000003360033640336303362033610336103f6003f6150000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000c002024450307102b4503071024440307002b44037700244203a7102b4203a71024410357102b410357101d45033710244503c7101d4403771024440337001d42035700244202e7101d4102e7102441037700
011800200c5700c5600c550000001157011560115500c5000c5700c5600f5710f56013570135600a5700a5600c5700c5600c550000000f5700f5600f550000000a5700a5600a5500f50011570115600a5700a560
001800200c5700c5600c55000000115701156011550000000c5700c5600f5710f56013570135600f5700f5600c5700c5700c5600c5600c5500c5300c5000c5000c5000a5000a5000a50011500115000a5000a500
000c0020247712477024762247523a0103a010187523a0103501035010187523501018750370003700037000227712277222762227001f7711f7721f762247002277122772227620070027771277722776200700
000c0020247712477024762247523a0103a010187503a01035010350101875035010187501870018700007001f7711f7701f7621f7521870000700187511b7002277122770227622275237012370123701237002
000c0000247712477024772247722476224752247422473224722247120070000700007000070000700007002e0002e0002e0102e010350103501033011330102b0102b0102b0102b00030010300123001230012
000c00200c3320c3320c3220c3220c3120c3120c3120c3020c3320c3320c3220c3220c3120c3120c3120c30207332073320732207322073120731207312073020a3320a3320a3220a3220a3120a3120a3120a302
000c00000c3300c3300c3200c3200c3100c3100c3103a0000c3300c3300c3200c3200c3100c3100c3103f0000a3300a3201333013320073300732007310113000a3300a3200a3103c0000f3300f3200f3103a000
00040000336251a605000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005
000c00000c3300c3300c3300c3200c3200c3200c3100c3100c3100c31000000000000000000000000000000000000000000000000000000000000000000000000a3000a3000a3000a3000a3310a3300332103320
001000000c3500c3400c3300c3200f3500f3400f3300f320183501834013350133401835013350163401d36022370223702236022350223402232013300133001830018300133001330016300163001d3001d300
000c0000242752b27530275242652b26530265242552b25530255242452b24530245242352b23530235242252b22530225242152b21530215242052b20530205242052b205302053a2052e205002050020500205
001000102f65501075010753f615010753f6152f65501075010753f615010753f6152f6553f615010753f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
0010000016270162701f2711f2701f2701f270182711827013271132701d2711d270162711627016270162701b2711b2701b2701b270000001b200000001b2000000000000000000000000000000000000000000
00080020245753057524545305451b565275651f5752b5751f5452b5451f5352b5351f5252b5251f5152b5151b575275751b545275451b535275351d575295751d545295451d535295351f5752b5751f5452b545
002000200c2650c2650c2550c2550c2450c2450c2350a2310f2650f2650f2550f2550f2450f2450f2351623113265132651325513255132451324513235132351322507240162701326113250132420f2600f250
00100000072750726507255072450f2650f2550c2750c2650c2550c2450c2350c22507275072650725507245072750726507255072450c2650c25511275112651125511245132651325516275162651625516245
000800201f5702b5701f5402b54018550245501b570275701b540275401857024570185402454018530245301b570275701b540275401d530295301d520295201f5702b5701f5402b5401f5302b5301b55027550
00100020112751126511255112451326513255182751826518255182451d2651d2550f2651824513275162550f2750f2650f2550f2451126511255162751626516255162451b2651b255222751f2451826513235
00100010010752f655010753f6152f6553f615010753f615010753f6152f655010752f6553f615010753f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
001000100107501075010753f6152f6553f6153f61501075010753f615010753f6152f6553f6152f6553f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
002000002904029040290302b031290242b021290142b01133044300412e0442e03030044300302b0412b0302e0442e0402e030300312e024300212e024300212b0442e0412b0342e0212b0442b0402903129022
000800202451524515245252452524535245352454524545245552455524565245652457500505245750050524565005052456500505245550050524555005052454500505245350050524525005052451500505
000800201f5151f5151f5251f5251f5351f5351f5451f5451f5551f5551f5651f5651f575000051f575000051f565000051f565000051f555000051f555000051f545000051f535000051f525000051f51500005
000500000373005731077410c741137511b7612437030371275702e5712437030371275702e5712436030361275602e5612435030351275502e5512434030341275402e5412433030331275202e5212431030311
002000200c2750c2650c2550c2450c2350a2650a2550a2450f2750f2650f2550f2450f2350c2650c2550c2450c2750c2650c2550c2450c2350a2650a2550a2450f2750f2650f2550f2450f235112651125511245
002000001327513265132551324513235112651125511245162751626516255162451623513265132551324513275132651325513245132350f2650f2550f2450c25011231162650f24516272162520c2700c255
000300001f3302b33022530295301f3202b32022520295201f3102b31022510295101f3002b300225002950000000000000000000000000000000000000000000000000000000000000000000000000000000000
010b00002935529300293423037230362303553034530335303253031513304243042430400304003042430424303003030030300303003000030000300003000030000300003000030000300003000030000300
001000003c5753c5453c5353c5253c5153c51537555375453a5753a5553a5453a5353a5253a5253a5153a51535575355553554535545355353553535525355253551535515335753355533545335353352533515
00100000355753555535545355353552535525355153551537555375353357533555335453353533525335253a5753a5453a5353a5253a5153a51533575335553354533545335353353533525335253351533515
001000200c0600c0300c0500c0300c0500c0300c0100c0000c0600c0300c0500c0300c0500c0300c0100f0001106011030110501103011010110000a0600a0300a0500a0300a0500a0300a0500a0300a01000000
001000000506005030050500503005010050000706007030070500703007010000000f0600f0300f010000000c0600c0300c0500c0300c0500c0300c0500c0300c0500c0300c010000000c0600c0300c0100c000
0010000003625246150060503615246251b61522625036150060503615116253361522625006051d6250a61537625186152e6251d615006053761537625186152e6251d61511625036150060503615246251d615
00100020326103261032610326103161031610306102e6102a610256101b610136100f6100d6100c6100c6100c6100c6100c6100f610146101d610246102a6102e61030610316103361033610346103461034610
00400000302453020530235332252b23530205302253020530205302253020530205302153020530205302152b2452b2052b23527225292352b2052b2252b2052b2052b2252b2052b2052b2152b2052b2052b215
001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
01 0a155644
00 0a160c44
00 0a160c44
00 0a0b0c44
00 14131244
00 0a160c44
00 0a160c44
02 0a111244
00 41424344
00 41424344
01 18191a44
00 18191a44
00 1b1c1a44
00 1b1d1a44
00 1f211a44
00 1f1a2144
00 1e1a2244
02 201a2444
00 41424344
00 41424344
01 29272a44
00 29272a44
00 2f2b2944
00 2f2b2c44
00 2f2b2944
00 2f2b2c44
00 2e2d3044
00 27313444
02 27323544
00 41424344
01 3d7e4344
00 3d7e4344
00 3d4a4344
02 3d3e4344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
01 383a3c44
02 393b3c44

