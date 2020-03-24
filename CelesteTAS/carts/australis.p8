pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- matt thorson + noel berry
-- mod by kris de asis

-- [globals]

room={x=0,y=0}
got_fruit={}
lvl_id=-1
objects={}
freeze=0
will_restart=false
delay_restart=0
sfx_timer=0
pause_player=false
flash_bg=false
music_timer=0
yadelie=false

-- camera stuff
cam_x=0
cam_y=0
cam_dx=0
cam_dy=0
cam_g=0.25

-- player 1 buttons
k_left=0
k_right=1
k_up=2
k_down=3
k_jump=4
k_dash=5

-- [entry point]

function _init()
  title_screen()
end

function title_screen()
  frames=0
  start_game=false
  start_game_flash=0
  music(40,0,7)
  load_room(-1)
end

function begin_game()
  score=0
  deaths=0
  frames=0
  seconds_f=0
  seconds=0
  minutes=0
  music_timer=0
  start_game=false
  music(0,0,7)
  load_room(0)
end

function rx()
  return is_title() and 7 or (2*min(15,lvl_id))%8
end

function ry()
  return is_title() and 3 or flr(min(15,lvl_id)/4)
end

function rw()
  return is_summit() and 1 or 2
end

function rh()
  return 1
end

function level_index()
  return lvl_id
end

function is_title()
  return lvl_id==-1
end

function is_summit()
  return lvl_id==15
end

-- [effects]

clouds={}
for i=0,8 do
  add(clouds,{
    x=rnd(128),
    y=rnd(64),
    spd=1+rnd(3),
    w=32+rnd(32)
  })
end

particles={}
for i=0,48 do
  add(particles,{
    x=rnd(128),
    y=rnd(128),
    s=0+flr(rnd(5)/4),
    spd=0.25+rnd(5),
    off=rnd(1),
    c=6+flr(rnd(1)+0.5)
  })
end

dead_particles={}

-- [player entity]

player = {
  init=function(this) 
    this.solids=true
    this.p_jump=false
    this.p_dash=false
    this.grace=0
    this.jbuffer=0
    this.dash_time=0
    this.dash_effect_time=0
    this.dash_target=0
    this.hitbox={x=1,y=3,w=6,h=5}
    this.spr_off=0
    this.was_on_ground=false
    this.ftimer=0
  end,
  update=function(this)
    if pause_player then
      return
    end
    -- horizontal input
    local input=(btn(k_right) and 1 or 0)+(btn(k_left) and -1 or 0)
    -- spike collision
    if spikes_at(this.x+this.hitbox.x,this.y+this.hitbox.y,this.hitbox.w,this.hitbox.h,this.spd.x,this.spd.y) then
      kill_player(this)
    end
    -- bottom death
    if this.y>rh()*128 then
      kill_player(this)
    end
    -- on ground and terrain checks
    local on_ground=this.is_solid(0,1)
    -- landing smoke
    if on_ground and not this.was_on_ground then
      init_object(smoke,this.x,this.y+4)
    end
    -- jump input
    local jump=btn(k_jump) and not this.p_jump
    this.p_jump=btn(k_jump)
    -- jump buffer
    if jump then
      this.jbuffer=4
    elseif this.jbuffer>0 then
      this.jbuffer-=1
    end
    -- dash input
    local dash=btn(k_dash) and not this.p_dash
    this.p_dash=btn(k_dash)
    -- grace frames and dash restoration
    if on_ground then
      this.grace=6
    elseif this.grace>0 then
      this.grace-=1
    end
    -- dash effect timer (for dash-triggered events, e.g., berry blocks)
    if this.dash_effect_time>0 then
      this.dash_effect_time-=1
    end
    -- gravity
    local maxfall=2
    local gravity=abs(this.spd.y)<=0.15 and 0.105 or 0.21
    -- dash startup period, accel toward dash target speed
    if this.dash_time>0 then
      this.dash_time-=1
      this.spd.x=appr(this.spd.x,this.dash_target,1.5)
    else
      -- x movement
      local maxrun=1
      local accel=on_ground and 0.6 or 0.4
      local deccel=0.15
      -- set x speed
      this.spd.x=abs(this.spd.x)<=maxrun and 
        appr(this.spd.x,input*maxrun,accel) or 
        appr(this.spd.x,sign(this.spd.x)*maxrun,deccel)
      -- y movement
      local maxfall=2
      local gravity=abs(this.spd.y)<=0.15 and 0.105 or 0.21
      -- wall slide
      if input~=0 and this.is_solid(input,0) then
        maxfall=0.4
        -- wall slide smoke
        if rnd(10)<2 then
          init_object(smoke,this.x+input*6,this.y)
        end
      end
      -- apply gravity
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
          if wall_dir~=0 then
            psfx(2)
            this.jbuffer=0
            this.spd.y=-2
            this.spd.x=-wall_dir*(maxrun+1)
            -- wall jump smoke
            init_object(smoke,this.x+wall_dir*6,this.y)
          end
        end
      end
      -- dash
      if this.grace>0 and dash then
        init_object(smoke,this.x,this.y)
        this.dash_time=4
        this.dash_effect_time=10
        -- calculate dash speeds
        this.spd.x=input~=0 and input*5 or (this.flip.x and -1 or 1)
        this.spd.y=0
        -- effects
        psfx(8)
        freeze=2
        -- dash target speeds and accels
        this.dash_target=2*sign(this.spd.x)
      end
    end
    -- facing direction
    if this.spd.x~=0 then
      this.flip.x=this.spd.x<0
    end
    -- animation
    this.spr_off+=0.125
    if abs(this.spd.x)>1 then
      -- goin fast
      this.spr=8
    elseif not on_ground then
      if this.is_solid(input,0) then
        -- wall slide
        this.spr=6
      else
        -- flap
        this.spr=abs(this.spd.y)<=1 and (flr(2*this.spr_off)%2==0 and 4 or 5) or 4
      end
    elseif btn(k_down) then
      -- crouch
      this.spr=7
    else
      -- walk or stand
      this.spr=2+(this.spd.x~=0 and (btn(k_left) or btn(k_right)) and round(sin(this.spr_off)) or 0)
    end
    -- exit off the top + fish get
    if this.y<-4 then
      local f=get_obj(fish)
      if f and f.follow then
        score+=1
        destroy_object(f)
        init_object(lifeup,f.x,f.y)
        this.ftimer=15
      end
      if this.ftimer>0 then
        this.y=-8
        this.spd.x=0
        this.spd.y=0
        this.ftimer-=1
      else
        next_room()
      end
    end
    -- was on the ground
    this.was_on_ground=on_ground
  end,
  draw=function(this)
    -- clamp in screen
    if this.x<-1 or this.x>128*rw()-7 then 
      this.x=clamp(this.x,-1,128*rw()-7)
      this.spd.x=0
    end
    -- draw player sprite
    spr(this.spr,this.x,this.y,1,1,this.flip.x,this.flip.y)
  end
}

-- [other entities]

player_spawn = {
  init=function(this)
    sfx(4)
    this.spr=4
    this.target=this.y
    this.y=flr(this.y/128)*128+128
    this.spd.y=-4
    this.state=0
    this.delay=0
    cam_x=this.x+4
    cam_y=this.y
  end,
  update=function(this)
    -- jumping up
    if this.state==0 then
      if this.y<this.target+16 then
        this.state=1
        this.delay=3
      end
    -- falling
    elseif this.state==1 then
      this.spd.y+=0.5
      if this.spd.y>0 then
        if this.delay>0 then
          -- stall at peak
          this.spd.y=0
          this.delay-=1
        elseif this.y>this.target then
          -- clamp at target y
          this.y=this.target
          this.spd={x=0,y=0}
          this.state=2
          this.delay=5
          init_object(smoke,this.x,this.y+4)
          sfx(5)
        end
      end
    -- landing and spawning player object
    elseif this.state==2 then
      this.delay-=1
      this.spr=7
      if this.delay<0 then
        destroy_object(this)
        init_object(player,this.x,this.y)
      end
    end
  end,
}

ramp = {
  init=function(this)
    this.hitbox=this.tile==9 and {x=1,y=6,w=1,h=1} or {x=5,y=6,w=1,h=1}
    this.dir=this.tile==9 and 1 or -1
  end,
  update=function(this)
    local hit
    hit=this.check(player,0,0)
    if hit and this.dir*hit.spd.x>1 and hit.dash_effect_time>0 then
      hit.dash_time=2
      hit.dash_effect_time=0
      hit.grace=0
      hit.dash_target=clamp(hit.dash_target,-3.5,3.5)
      ramp_launch(hit)
    end
    hit=this.check(ice,0,0)
    if hit and this.dir*hit.spd.x>1 then
      ramp_launch(hit)
    end
  end
}

function ramp_launch(obj)
  obj.move_y(-1)
  obj.spd.y=-2.5
  init_object(smoke,obj.x,obj.y)
end

-- ice blocks
ice = {
  init=function(this)
    this.solids=true
    if this.tile==116 then
      this.x+=4
    end
    this.ogx=this.x
    this.ogy=this.y
    this.big=this.tile==66
    this.respawn=false
    if this.big then
      this.hitbox.w=16
      this.hitbox.h=16
    end
  end,
  update=function(this)
    local on_ground=this.is_solid(0,1)
    -- clamp in screen
    if this.x<0 or this.x>128*rw()-this.hitbox.w then 
      this.x=clamp(this.x,0,128*rw()-this.hitbox.w)
      this.spd.x=0
    end
    -- carry other blocks
    if this.spd.x~=0 then
      local decay=1.0
      hit=this.check(ice,0,-1)
      while hit do
        decay*=0.5
        hit.move(decay*this.spd.x,0)
        hit=hit.check(ice,0,-1)
      end
    end
    -- deccel
    this.spd.x=appr(this.spd.x,0,0.11)
    -- nudge apart
    hit=this.check(ice,0,0)
    if hit then
      local dir=sign(this.x-hit.x)~=0 and sign(this.x-hit.x) or 2*round(rnd(1))-1
      if not this.is_terrain(dir,0) then
        this.x+=dir
      end
    end
    if not on_ground then
      -- apply gravity
      this.spd.y=appr(this.spd.y,2,abs(this.spd.y)<=0.15 and 0.105 or 0.21)
    end
    -- crush player
    hit=this.check(player,0,0)
    if hit then
      hit.y=this.y+(hit.y<=this.y and -8 or this.hitbox.h)
      hit.spd.y=0
      if hit.is_solid(0,0) then
        kill_player(hit)
      end
    end
    -- get hit by player
    local hit
    for i=-1,1,2 do
      hit=this.check(player,i,0)
      if hit and -i*hit.spd.x>0 and hit.dash_effect_time>0 then
        hit.dash_time=0
        hit.dash_effect_time=0
        hit.grace=0
        hit.spd.x=-1*sign(hit.spd.x)
        hit.spd.y=-1
        this.spd.x=-2.21*i
        break
      end
    end
    -- get hit by other blocks
    for i=-1,1,2 do
      hit=this.check(ice,i,0)
      if hit and -i*hit.spd.x>0 then
        this.spd.x=0.75*sign(hit.spd.x)
        break
      end
    end
    -- bottom death
    if this.y>rh()*128 then
      if this.respawn then
        init_object(ice,this.ogx,this.ogy,this.tile)
      end
      destroy_object(this)
    end
  end,
  draw=function(this)
    if not this.big then
      spr(117,this.x,this.y)
    else
      sspr(16,32,16,16,this.x,this.y)
    end
  end
}

-- sadelie
sadelie = {
  init=function(this)
    this.solids=true
    this.hitbox={x=1,y=3,w=6,h=5}
    this.spr_off=0
    this.yadelie=false
    this.spr_timer=0
  end,
  update=function(this)
    if this.is_solid(0,0) then
      yadelie=false
      kill_obj(this)
      if this.yadelie then
        init_object(swagdelie,this.x+128,this.y)
        init_object(swagdelie,this.x-128,this.y)
        init_object(swagdelie,this.x+128,this.y-128)
        init_object(swagdelie,this.x-128,this.y-128)
      end
    end
    if not this.yadelie then
      if this.is_solid(2,0) or not this.is_solid(7,1) then
        this.spd.x=appr(this.spd.x,0,1)
      else
        this.spd.x=appr(this.spd.x,1,0.05)
      end
      this.spr_off+=0.125
      this.spr=2+(this.spd.x~=0 and round(sin(this.spr_off)) or 14)
      local hit=this.check(egg,-4,0)
      if hit then
        yadelie=true
        psfx(63)
        this.spr=4
        this.spd.x=0
        this.x=hit.x
        this.flip.x=true
        this.yadelie=true
        init_object(noot,this.x,this.y)
        init_object(fish,this.x,this.y-16,26)
        destroy_object(hit)
      end
    else
      if this.is_solid(0,1) then
        this.spd.y=-1
      else
        this.spd.y=appr(this.spd.y,2,0.21)
      end
    end
  end,
  draw=function(this)
    spr(this.spr,this.x,this.y,1,1,this.flip.x)
  end
}

swagdelie = {
  init=function(this)
    this.hitbox={x=1,y=3,w=6,h=5}
    this.vel=0
  end,
  update=function(this)
    if rnd(1)<0.2 then
      init_object(smoke,this.x,this.y)
      if rnd(1)<0.05 then
        psfx(63)
      end
    end
    this.vel=appr(this.vel,5,0.25)
    if this.spd.x~=0 then
      this.flip.x=this.spd.x<0
    end
    local p=get_player()
    if p then
      local a=atan2(p.x-this.x,p.y-this.y)
      this.spd.x+=0.1*(cos(a)*this.vel-this.spd.x)
      this.spd.y+=0.1*(sin(a)*this.vel-this.spd.y)
    end
    if this.check(player,0,0) then
      kill_player(p)
    end
  end,
  draw=function(this)
    pal(5,0)
    spr(18,this.x,this.y,1,1,this.flip.x)
    pal(5,5)
  end
}

egg = {
  update=function(this)
    if this.is_solid(0,0) then
      kill_obj(this)
    end
  end
}

boost = {
  init=function(this) 
    this.offset=rnd(1)
    this.timer=0
    this.hitbox={x=-1,y=-1,w=10,h=10}
    if this.tile==43 then
      this.x+=4
    end
  end,
  update=function(this) 
    if this.spr==27 then
      this.offset+=0.01
      local hit
      hit=this.check(ice,0,0)
      if hit then
        psfx(3)
        hit.y=min(hit.y,this.y+2)
        init_object(smoke,this.x,this.y)
        hit.spd.y=-2.25
        this.spr=0
        this.timer=60
      else
        hit=this.check(player,0,0)
        if hit then
          psfx(3)
          if this.y+2<hit.y then
            hit.move_y(this.y+2-hit.y)
           end
          --hit.y=min(hit.y,this.y+2)
          init_object(smoke,this.x,this.y)
          hit.grace=0
          hit.move_y(2)
          hit.dash_target=0
          hit.spd.y=-2.1
          hit.dash_time=1
          this.spr=0
          this.timer=60
        end
      end
    elseif this.timer>0 then
      this.timer-=1
    else 
      psfx(7)
      init_object(smoke,this.x,this.y)
      this.spr=27 
    end
  end,
  draw=function(this)
    spr(this.spr,this.x,this.y+sin(this.offset)*1.5)
  end
}

fall_floor = {
  init=function(this)
    this.state=0
  end,
  update=function(this)
    -- idling
    if this.state==0 then
      if this.check(ice,0,-1) and not this.check(ice,0,0) then
        break_fall_floor(this)
      end
    -- shaking
    elseif this.state==1 then
      this.delay-=1
      if this.delay==5 then
        local hit
        for i=-1,1,2 do
          hit=this.check(fall_floor,i,0)
          if hit and hit.state==0 then
            break_fall_floor(hit)
          end
        end
      elseif this.delay<=0 then
        destroy_object(this)
      end
    end
  end,
  draw=function(this)
    spr(23+(this.state==0 and 0 or (15-this.delay)/5),this.x,this.y)
  end
}

function break_fall_floor(obj)
  psfx(15)
  obj.state=1
  obj.delay=15--how long until it falls
  init_object(smoke,obj.x,obj.y)
end

smoke={
  init=function(this)
    this.spr=45
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
    if this.spr>=47 then
      destroy_object(this)
    end
  end
}

fish={
  init=function(this) 
    this.y_=this.y
    this.off=0
    this.follow=false
    this.tx=this.x
    this.ty=this.y
  end,
  update=function(this)
    if not this.follow and this.check(player,0,0) then
      this.follow=true
      psfx(23)
    elseif this.follow then
      local p=get_player()
      if p then
        this.tx+=0.2*(p.x-this.tx)
        this.ty+=0.2*(p.y-this.ty)
        local a=atan2(this.x-this.tx,this.y_-this.ty)
        local k=((this.x-this.tx)^2+(this.y_-this.ty)^2)>144 and 0.2 or 0.1
        this.x+=k*(this.tx+12*cos(a)-this.x)
        this.y_+=k*(this.ty+12*sin(a)-this.y_)
      end
    end
    this.off+=1
    this.y=this.y_+sin(this.off/40)*2.5
  end
}

function get_obj(type)
  for i=1,count(objects) do
    if objects[i].type==type then
      return objects[i]
    end
  end
end

lifeup = {
  init=function(this)
    this.spd.y=-0.25
    this.duration=30
    this.x-=2
    this.y-=4
    this.flash=0
    sfx(13)
  end,
  update=function(this)
    this.duration-=1
    if this.duration<=0 then
      destroy_object(this)
    end
  end,
  draw=function(this)
    this.flash+=0.5
    print("1000",this.x-2,this.y,7+this.flash%2)
  end
}

noot = {
  init=function(this)
    this.spd.y=-0.25
    this.duration=30
    this.x-=2
    this.y-=4
    this.flash=0
    --sfx(13)
  end,
  update=function(this)
    this.duration-=1
    if this.duration<=0 then
      destroy_object(this)
    end
  end,
  draw=function(this)
    this.flash+=0.5
    print("noot",this.x-2,this.y,7+this.flash%2)
  end
}

flash = {
  init=function(this)
    this.r=1
    this.rspd=0
    this.rmax=200
    this.t=0
  end,
  update=function(this)
    this.r=min(this.r+this.rspd,this.rmax)
    this.rspd+=0.5
    this.t+=1
    if this.t>=62 then
      destroy_object(this)
    end
  end,
  draw=function(this)
    circfill(this.x,this.y,this.r,7)
  end
}

fake_wall = {
  init=function(this)
    if this.tile==65 then
      this.x-=8
    end
  end,
  update=function(this)
    this.hitbox={x=-1,y=-1,w=18,h=18}
    local hit=this.check(player,0,0)
    if hit and hit.dash_effect_time>0 then
      hit.spd.x=-sign(hit.spd.x)*1.5
      hit.spd.y=-1.5
      hit.dash_time=0
      sfx_timer=20
      sfx(16)
      destroy_object(this)
      init_object(smoke,this.x,this.y)
      init_object(smoke,this.x+8,this.y)
      init_object(smoke,this.x,this.y+8)
      init_object(smoke,this.x+8,this.y+8)
      if this.tile==64 then
        init_object(fish,this.x+4,this.y+4,26)
      end
    end
    this.hitbox={x=0,y=0,w=16,h=16}
  end,
  draw=function(this)
    sspr(0,32,16,16,this.x,this.y)
  end
}

message = {
  init=function(this)
    this.last=0
    if this.tile==98 then
      this.text="-- terra australis --#noot noot noot noot  #  noot noot noot noot"
    elseif this.tile==99 then
      this.x-=8
      this.text="-- pygosc. adeliae --# noot noot noot?     #           ... noot. "
    elseif this.tile==114 then
      this.y-=8
      this.text="-- hydru. leptonyx --# noot noot!! xd      #  'geagh gegg brehh' " 
    end
  end,
  draw=function(this)
    sspr(16,48,16,16,this.x,this.y)
    if this.check(player,4,4) then
      if this.index<#this.text then
       this.index+=0.5
        if this.index>=this.last+1 then
         this.last+=1
         sfx(35)
        end
      end
      local offx=round(cam_x)-64+12
      local offy=round(cam_y)-64+8
      for i=1,this.index do
        if sub(this.text,i,i)~="#" then
          rectfill(offx-2,offy-2,offx+5,offy+6,7)
          print(sub(this.text,i,i),offx,offy,0)
          offx+=5
        else
          offx=round(cam_x)-64+12
          offy+=7
        end
      end
    else
      this.index=0
      this.last=0
    end
  end
}

scene = {
  init=function(this)
    if not yadelie or score<10 then
      destroy_object(this)
    end
    this.solids=true
    this.state=0
    this.x+=4
    this.t=0
  end,
  update=function(this)
    if this.state==0 then
      if this.is_solid(0,1) then
        this.spd.y=-1
      else
        this.spd.y=appr(this.spd.y,2,0.21)
      end
      local hit=this.check(player,0,0)
      if hit then
        this.spd.y=0
        pause_player=true
        init_object(flash,this.x,this.y)
        this.t=60
        this.state=1
      end
    elseif this.state==1 then
      if this.t>0 then
        this.t-=1
      else
        del(objects,get_player())
        for i=1,count(objects) do
          if objects[i].type==flag then
            objects[i].show=false
            break
          end
        end
        this.state=2
        this.t=30
      end
    elseif this.state==2 then
      if this.t>0 then
        this.t-=1
      else
        this.t=15
        this.state=3
        sfx(23)
      end
    elseif this.state==3 then
      if this.t>0 then
        this.t-=1
      else
        this.state=4
        this.t=90
        music(-1,500,7)
        sfx(37)
        flash_bg=true
      end
    elseif this.state==4 then
      if this.t>0 then
        this.t-=1
      else
        this.state=5
        flash_bg=false
        this.o=80
        this.os=0
        sfx(51)
      end
    elseif this.state==5 then
      if this.o>0 then
        this.o+=this.os
        this.os-=0.5
      else
        this.state=6
      end
    elseif this.state==6 then
      local str="6565656654555555565700000057545568000000646565656657000000575455000000000000000000670000005764650000000000000000000000000067000000000000000000003900000000000000000000003900003a2800003a0000000000003a0028283a2828282828390000003a39282828283b2900002a3b283a393a2828282a38282800000000002828282828282900282829000000003a2838282a382800002a283d0070713f28282900002828390000282122232122232800003a3b290000002031323324482628444545280000000021222222252525235455554545454546242548252525252654555555555555562425252525254826545555"
      for y_=1,32,2 do
        for x_=1,32,2 do
          poke(6240+(y_-1)*64+x_/2, "0x"..sub(str,x_+(y_-1)/2*32,x_+(y_-1)/2*32+1))
        end
      end
      load_room(lvl_id)
      lvl_id=16
    end
  end,
  draw=function(this)
    if this.state==0 then
      spr(4,this.x,this.y)
    elseif this.state==1 then
      spr(4,this.x,this.y)
    elseif this.state==2 then
      spr(2,32,88)
      spr(2,48,88,1,1,true)
    elseif this.state==3 then
      spr(8,32,88)
      spr(8,48,88,1,1,true)
      spr(27,40,80)
    elseif this.state==4 then
      local t=90-this.t
      local s1=sin(0.25+(t/30)*(t%30)/30)
      local s2=sin(0.75+(t/30)*(t%30)/30)
      spr(8,40+8*s1,88,1,1,s1>=0.1)
      spr(8,40+8*s2,88,1,1,s2>=0.1)
      spr(27,40,80)
      if t>80 and flr(t/3)%2==0 then
        rectfill(0,0,127,127,7)
      end
    elseif this.state==5 then
      spr(4,32,88)
      spr(4,48,88,1,1,true)
      spr(62,40,this.o)
      local off=frames/30
      for i=0,7 do
        circfill(40+4+cos(off+i/8)*8,this.o+4+sin(off+i/8)*8,1,7)
      end
    end
  end
}

orb = {
  init=function(this)
    this.x=68
    this.y=0
    this.state=0
  end,
  update=function(this)
    this.y=appr(this.y,76,0.5)
    if this.state==0 and this.y==76 then
      sfx(16)
      this.state=1
    end
  end,
  draw=function(this)
    --sfx(51)
    if this.state==0 then
      spr(62,this.x,this.y)
      local off=frames/30
      for i=0,7 do
        circfill(this.x+4+cos(off+i/8)*8,this.y+4+sin(off+i/8)*8,1,7)
      end
    else
     spr(96,64,72)
     spr(97,72,72)
    end
    spr(112,64,80)
    spr(113,72,80)
    fillp(0b0000010100001010.1)
    rectfill(0,0,127,127,0)
    fillp()
  end
}

flag = {
  init=function(this)
    this.show=false
    this.x+=3
  end,
  draw=function(this)
    this.spr=118+(frames/5)%3
    spr(this.spr,this.x,this.y)
    if this.show then
      rectfill(32,2,96,31,0)
      spr(26,49,6)
      print(":"..score..'/10',58,9,7)
      draw_time(42,16)
      print("deaths:"..deaths,48,24,7)
    elseif this.check(player,0,0) then
      sfx(55)
      sfx_timer=30
      this.show=true
    end
  end
}

room_title = {
  init=function(this)
    this.delay=5
  end,
  draw=function(this)
    local camx=round(cam_x)-64
    local camy=round(cam_y)-64
    this.delay-=1
    if this.delay<-30 then
      destroy_object(this)
    elseif this.delay<0 then
      rectfill(camx+24,camy+58,camx+104,camy+70,0)
      if lvl_id==6 then
        print("transantarctic",camx+36,camy+62,7)
      elseif lvl_id==14 then
        print("polar plateau",camx+38,camy+62,7)
      elseif lvl_id==15 then
        print("south pole",camx+44,camy+62,7)
      elseif lvl_id==16 then
        print("mt celeste",camx+44,camy+62,7)
      else
        local level=(1+lvl_id)*100
        print(level.." m",camx+52+(level<1000 and 2 or 0),camy+62,7)
      end
      draw_time(camx+4,camy+4)
    end
  end
}

cam = {
	init=function(this)
		this.spr=0
		this.x=clamp(cam_x,64,128*rw()-64)
		this.y=clamp(cam_y,64,128*rh()-64)
		this.dx=cam_dx
		this.dy=cam_dy
	end,
	save=function(this)
		this.x=cam_x
		this.y=cam_y
		this.dx=cam_dx
		this.dy=cam_dy
	end,
	load=function(this)
		cam_x=this.x
		cam_y=this.y
		cam_dx=this.dx
		cam_dy=this.dy
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

psfx=function(num)
  if sfx_timer<=0 then
   sfx(num)
  end
end

-- [tile dict]

tiles={
  [2]=player_spawn,
  [9]=ramp,
  [10]=ramp,
  [16]=sadelie,
  [17]=egg,
  [23]=fall_floor,
  [26]=fish,
  [27]=boost,
  [43]=boost,
  [64]=fake_wall,
  [65]=fake_wall,
  [66]=ice,
  [88]=scene,
  [98]=message,
  [99]=message,
  [104]=orb,
  [114]=message,
  [116]=ice,
  [117]=ice,
  [118]=flag,
}

-- [object functions]

function init_object(type,x,y,tile)
  local obj={}
  obj.type=type
  obj.collideable=true
  obj.solids=false

  obj.tile=tile
  obj.spr=tile
  obj.flip={x=false,y=false}

  obj.x=x
  obj.y=y
  obj.hitbox={x=0,y=0,w=8,h=8}

  obj.spd={x=0,y=0}
  obj.rem={x=0,y=0}

  obj.is_solid=function(ox,oy)
    return (oy>0 and not obj.is_platform(ox,0) and obj.is_platform(ox,oy)) -- one way plat
      or obj.is_terrain(ox,oy) -- ground
      or (oy>0 and not obj.check(fall_floor,ox,0) and obj.check(fall_floor,ox,oy)) -- crumble
      or obj.check(fake_wall,ox,oy) -- berry block
      or obj.check(ice,ox,oy) -- ice
  end

  obj.is_terrain=function(ox,oy)
    return tile_flag_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h,0)
  end

  obj.is_platform=function(ox,oy)
    return tile_flag_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h,3)
  end
  
  obj.check=function(type,ox,oy)
    local other
    for i=1,count(objects) do
      other=objects[i]
      if other and other.type==type and other~=obj and other.collideable and
        other.x+other.hitbox.x+other.hitbox.w>obj.x+obj.hitbox.x+ox and 
        other.y+other.hitbox.y+other.hitbox.h>obj.y+obj.hitbox.y+oy and
        other.x+other.hitbox.x<obj.x+obj.hitbox.x+obj.hitbox.w+ox and 
        other.y+other.hitbox.y<obj.y+obj.hitbox.y+obj.hitbox.h+oy then
        return other
      end
    end
  end
  
  obj.move=function(ox,oy)
    -- [x] get move amount
    obj.rem.x+=ox
    local amount=round(obj.rem.x)
    obj.rem.x-=amount
    obj.move_x(amount,0)
    -- [y] get move amount
    obj.rem.y+=oy
    amount=round(obj.rem.y)
    obj.rem.y-=amount
    obj.move_y(amount)
  end
  
  obj.move_x=function(amount,start)
    if obj.solids then
      local step=sign(amount)
      for i=start,abs(amount) do
        if not obj.is_solid(step,0) then
          obj.x+=step
        else
          obj.spd.x=0
          obj.rem.x=0
          break
        end
      end
    else
      obj.x+=amount
    end
  end
  
  obj.move_y=function(amount)
    if obj.solids then
      local step=sign(amount)
      for i=0,abs(amount) do
      if not obj.is_solid(0,step) then
          obj.y+=step
        else
          obj.spd.y=0
          obj.rem.y=0
          break
        end
      end
    else
      obj.y+=amount
    end
  end

  add(objects,obj)
  if obj.type.init then
    obj.type.init(obj)
  end
  return obj
end

function destroy_object(obj)
  del(objects,obj)
end

function get_player()
  for i=1,count(objects) do
    if objects[i].type==player_spawn or objects[i].type==player then
      return objects[i]
    end
  end
end

function kill_obj(obj)
  sfx_timer=12
  sfx(0)
  destroy_object(obj)
  dead_particles={}
  for dir=0,7 do
    local angle=(dir/8)
    add(dead_particles,{
      x=obj.x+4,
      y=obj.y+4,
      t=10,
      dx=sin(angle)*3,
      dy=cos(angle)*3
    })
  end
end

function kill_player(obj)
  deaths+=1
  kill_obj(obj)
  restart_room()
end

-- [room functions]

function restart_room()
  will_restart=true
  delay_restart=15
end

function next_room()
  --printh('level: '..lvl_id+1)
  load_room(lvl_id+1)
  if lvl_id==6 then
    music(30,500,7) -- quiet
  elseif lvl_id==7 then
    music(20,500,7) -- other song
  elseif lvl_id==14 then
    music(30,500,7) -- quiet
  end
end

function load_room(id,y)
  -- remove existing objects
  foreach(objects,destroy_object)
  -- current room
  lvl_id=y==nil and id or id%8+y*8
  room.x=y==nil and id%8 or id
  room.y=y==nil and flr(id/8) or y
  -- entities
  for tx=0,16*rw()-1 do
    for ty=0,16*rh()-1 do
      local tile=mget(rx()*16+tx,ry()*16+ty)
      if tiles[tile] then
        init_object(tiles[tile],tx*8,ty*8,tile)
      end
    end
  end
  init_object(cam,0,0)
  -- room title
  if not is_title() then
    init_object(room_title,0,0)
  end
end

-- [main update loop]

function _update()
  frames=(frames+1)%30
  if not is_title() and lvl_id<15 then
    seconds_f=(seconds_f+1)%1800
	seconds=flr(seconds_f/30)
    if seconds_f==0 then
      minutes+=1
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
  if freeze>0 then 
    freeze-=1
    return
  end
  
  -- restart (soon)
  if will_restart and delay_restart>0 then
    delay_restart-=1
    if delay_restart<=0 then
      will_restart=false
      load_room(lvl_id)
    end
  end

  -- update each object
  foreach(objects,function(obj)
    obj.move(obj.spd.x,obj.spd.y)
    if obj.type.update then
      obj.type.update(obj) 
    end
  end)
  
  -- start game
  if is_title() then
    if not start_game and (btn(k_jump) or btn(k_dash)) then
      music(-1)
      start_game_flash=50
      start_game=true
      sfx(38)
    end
    if start_game then
      start_game_flash-=1
      if start_game_flash<=-30 then
        begin_game()
      end
    end
  end

  -- camera
  if is_title() then
    cam_x=64
    cam_y=64
  else
    local p=get_player()
    if p~=nil then
      cam_dx=cam_g*(4+p.x-cam_x)
      cam_dy=cam_g*(4+p.y-cam_y)
      cam_x+=cam_dx
      cam_y+=cam_dy
      if cam_x<64 or cam_x>128*rw()-64 then
        cam_dx=0
        cam_x=clamp(cam_x,64,128*rw()-64)
      end
      if cam_y<64 or cam_y>128*rh()-64 then
        cam_dy=0
        cam_y=clamp(cam_y,64,128*rh()-64)
      end
    end
  end
  savecamera()
end

-- [drawing functions]

function _draw()
  if freeze>0 then
    return
  end
  
  -- reset all palette values
  pal()
  
  -- start game flash
  if start_game then
    local c=start_game_flash>10 and (frames%10<5 and 7 or 10) or (start_game_flash>5 and 2 or (start_game_flash>0 and 1 or 0))
    if c<10 then
      for i=1,15 do
        pal(i,c)
      end
    end
  end
  
  loadcamera()
  camera(round(cam_x)-64,round(cam_y)-64)
  -- camera
  local camx=round(cam_x)-64
  local camy=round(cam_y)-64

  -- draw bg color
  rectfill(camx,camy,camx+128,camy+128,flash_bg and frames/5 or new_bg and 2 or 0)

  -- bg clouds effect
  if not is_title() then
    foreach(clouds, function(c)
      c.x+=c.spd-cam_dx
      fillp(0b0101111110101111.1)
      rectfill(camx+c.x-4,camy+c.y,camx+c.x+c.w+4,camy+c.y+4+(1-c.w/64)*12,1)
      rectfill(camx+c.x,camy+c.y-1,camx+c.x+c.w,camy+c.y+4+(1-c.w/64)*12+1,1)
      fillp(0b0101101001011010.1)
      rectfill(camx+c.x,camy+c.y,camx+c.x+c.w,camy+c.y+4+(1-c.w/64)*12,1)
      if c.x>128 then
        c.x=-c.w
        c.y=rnd(64)
      end
    end)
    fillp()
  end

  -- draw bg terrain
  map(rx()*16,ry()*16,0,0,rw()*16,rh()*16,4)

  -- draw terrain (offset if title screen)
  map(rx()*16,ry()*16,is_title() and -4 or 0,0,rw()*16,rh()*16,2)
  
  -- draw objects
  foreach(objects, function(o)
    draw_object(o)
  end)
  
  -- particles
  foreach(particles, function(p)
    p.x+=p.spd-cam_dx
    p.y+=sin(p.off)-cam_dy
    p.off+=min(0.05,p.spd/32)
    rectfill(camx+p.x,camy+p.y%128,camx+p.x+p.s,camy+p.y%128+p.s,p.c)
    if p.x>128+4 then 
      p.x=-4
      p.y=rnd(128)
    elseif p.x<-4 then
      p.x=128
      p.y=rnd(128)
    end
  end)
  
  -- dead particles
  foreach(dead_particles, function(p)
    p.x+=p.dx
    p.y+=p.dy
    p.t-=1
    if p.t<=0 then
      del(dead_particles,p)
    end
    rectfill(p.x-p.t/5,p.y-p.t/5,p.x+p.t/5,p.y+p.t/5,14+p.t%2)
  end)
  
  -- credits
  if is_title() then
    print("z+x",58,68,5)
    print("a mod of celeste",34,80,5)
    print("by matt thorson",36,86,5)
    print("and noel berry",38,92,5)
    print("kris de asis",42,104,5)
  end
  
  -- summit blinds effect
  if lvl_id==30 then
    local p=get_player()
    if p then
      local diff=min(24,40-abs(p.x+4-64))
      rectfill(0,0,diff,128,0)
      rectfill(128-diff,0,128,128,0)
    end
  end
end

function draw_object(obj)
  if obj.type.draw then
    obj.type.draw(obj)
  elseif obj.spr>0 then
    spr(obj.spr,obj.x,obj.y,1,1,obj.flip.x,obj.flip.y)
  end
end

function draw_time(x,y)
  camera()
  rectfill(x,y,x+44,y+6,0)
  print(two_digit_str(flr(minutes/60))..":".. -- hours
    two_digit_str(minutes%60)..":".. -- minutes
    two_digit_str(flr(seconds_f/30))..".".. -- seconds
    two_digit_str(flr(100*(seconds_f%30)/30)), -- centiseconds
    x+1,y+1,7)
  local camx=round(cam_x)-64
  local camy=round(cam_y)-64
  camera(camx,camy)
end

function two_digit_str(x)
  return x<10 and "0"..x or x
end

-- [helper functions]

function clamp(val,a,b)
  return max(a,min(b,val))
end

function appr(val,target,amount)
  return val>target and max(val-amount,target) or min(val+amount,target)
end

function sign(v)
  return v~=0 and sgn(v) or 0
end

function maybe()
  return rnd(1)<0.5
end

function round(x)
  return flr(x+0.5)
end

function tile_flag_at(x,y,w,h,flag)
  for i=max(0,flr(x/8)),min(16*rw()-1,(x+w-1)/8) do
    for j=max(0,flr(y/8)),min(16*rh()-1,(y+h-1)/8) do
      if fget(tile_at(i,j),flag) then
        return true
      end
    end
  end
  return false
end

function tile_at(x,y)
  return mget(rx()*16+x,ry()*16+y)
end

function spikes_at(x,y,w,h,xspd,yspd)
  for i=max(0,flr(x/8)),min(16*rw()-1,(x+w-1)/8) do
    for j=max(0,flr(y/8)),min(16*rh()-1,(y+h-1)/8) do
      local tile=tile_at(i,j)
      if tile==29 and ((y+h-1)%8>=6 or y+h==j*8+8) and yspd>=0 then
        return true
      elseif tile==28 and y%8<=2 and yspd<=0 then
        return true
      elseif tile==30 and x%8<=2 and xspd<=0 then
        return true
      elseif tile==31 and ((x+w-1)%8>=6 or x+w==i*8+8) and xspd>=0 then
        return true
      end
    end
  end
  return false
end

__gfx__
00000000000000000000000000000000101111010011110000000000000000000000000000000000000000004949494949494949494949494000000000000004
00000000001111000011110000111100111717110117171000111101000000000001111000000000000000004444444444444444444444440400000000000040
00000000011717100117171001171710111199111111991101717111001111001111171700000000000000000000040000000000004000000040000000000400
00000000011199100111991001119910011777101117771101991111011111100111119900000000000000000000400000000000000400000004000000004000
00000000011177111117771111177110011777100117771011777110011717101111117700000700007000000004000000000000000040000000400000040000
00000000011177111117771111177110011777100117771011777110111199111111177700007700007700000040000000000000000004000000040000400000
00000000011777100117771001177710119559101195591001777110111777110111777000777770077777000400000000000000000000400000004004000000
00000000199559901199599011995599009009000090090000995599119959900995990077777770077777774000000000000000000000040000000440000000
00000000000000000000000010111101101111010000000000000000494049494940494900000000000600000077770067656765000000005000000000000066
00000000000000000001111011171711117171110000000000000000444444044044440400400004000660000700007067706770000000006700000000007777
0011110000000000111155551111991111991111000000000000000000000000000400400000000060ddd5d07077000707000700000000007777000000000076
01171710000ff00001111559011aaa1001aaa11000000000000000000000000004000000000090006ddd5d5d7077cc0707000700000000006600000000000005
01c199c000ff7f0011111177011777100177711000000000000000000000000000000000000004006ddd5ddd700ccc0700000000007000705000000000000066
1117771100ffff00111117770117771001777110000000000000000000000000000000004900000460ddddd0700ccc0700000000007000706700000000007777
1119779100ffff000111777001177710017771100000000000000000000000000000000000400000000606000700007000000000067706777777000000000076
01196690000ff0000995990011995990099599110000000000000000000000000000000000000000000000000077770000000000567656766600000000000005
5777777557777777777777777777777577cccccccccccccccccccc77577777750505050505050505050505050000007707777770000000000000000070000000
77777777777777777777777777777777777cccccccccccccccccc777777777775555555555555550055555550000070077777777007700000770070007000007
777c77777777ccccc777777ccccc7777777cccccccccccccccccc777777777775050505050505000005050500000707777777777007770700777000000000000
77cccc77777cccccccc77cccccccc7777777cccccccccccccccc7777777cc7775555555555555000000555550000707777773377077777700770000000000000
77cccc7777cccccccccccccccccccc777777cccccccccccccccc777777cccc770505050505050000000005050000700c77773377077777700000700000000000
777cc77777cc77ccccccccccccc7cc77777cccccccccccccccccc77777cccc775555555555500000000005550000700c73773337077777700000077000000000
7777777777cc77cccccccccccccccc77777cccccccccccccccccc77777c7cc77505050505000000000000050000007007333bb37070777000007077007000070
5777777577cccccccccccccccccccc7777cccccccccccccccccccc7777cccc77555555555000000000000005000000770333bb30000000007000000000000000
77cccc7777cccccccccccccccccccc77577777777777777777777775777ccc770505050500000000000000050505050503333330000000000077770000000000
777ccc7777cccccccccccccccccccc77777777777777777777777777777cc7775055555555000000000000555555555503b33330000000000700007000000000
777ccc7777cc7cccccccccccc77ccc777777ccc7777777777ccc7777777cc7775050005050500000000000505000005003333330000000007077000700000030
77ccc77777ccccccccccccccc77ccc77777ccccc7c7777ccccccc77777ccc777555500555555000000005555550000550333b330000000007077bb07000000b0
77ccc777777cccccccc77cccccccc777777ccccccc7777c7ccccc77777cccc7705050505050500000005050505000005003333000000b000700bbb0700000b30
777cc7777777ccccc777777ccccc77777777ccc7777777777ccc777777cccc775505555555555500005555555500005500044000000b0000700bbb0703000b00
777cc777777777777777777777777777777777777777777777777777777cc7775050505050505050005050505050505000044000030b00300700007000b0b300
77cccc77577777777777777777777775577777777777777777777775577777755555555555555555555555555555555500999900030330300077770000303300
5777755777577775077777777777777007777777777777777777777007777770cccccccc000000000000000000000000000000000000000000000000000000c0
7777777777777777700007770000777770000777000077700000777770007777c77ccccc000000000000000000000000000000000000000000000000ccccccc0
7777cc7777cc777770cc777cccc7770770cc777cccc777ccccc7770770c77707c77cc7cc0000000000000000000000000000000000000000000000000ccccc00
777cccccccccc77770c777cccc777c0770c777cccc777ccccc777c0770777c07cccccccc00000000000000000000000000006000000000000000000000000000
77cccccccccccc77707770000777000770777000077700000777000777770007cccccccc00000000000000000000000000067600000000000777770000000000
57cc77ccccc7cc75777700007770000777770000777000007770000777700007cc7ccccc00000000000000000000000000d77760000000007777777000000000
577c77ccccccc77570000000000c00077000000000000000000c000770000c07ccccc7cc7770777077707770777000000d77777c000000007700000000000000
777cccccccccc777700000000000000770000000000000000000000770000007cccccccc070070007070707070700000d767777c00000000ccccccc000000000
777cccccccccc7777000000000000007700000000000000000000007700000070000000007007700770077007770000c7676767c000600000000000000000000
577cccccccccc77770000000000000077000000c000000000000000770cc0007000000000700777070707070707000d767676767c067d0000000000000000000
57cc7cccc77ccc75700000000000000770000000000cc0000000000770cc000700000000000000000000000000000c6666666666cd666d000000000000000000
77ccccccc77ccc777000000c0000000770c00000000cc00000000c0770000c070000000000000000000000000000000006600000066600000000000000000000
777cccccccccc7777000000c000c0007700000000000000000000007700000070000000070077000770077777007777770077777700077777007700000077700
7777cc7777cc777770c000000000000770000000000000000000000770c000070000000077077000770777777707777777077777770777777707700000077770
7777777777777777700000000000000770000000c000000000000007700000070000000077077000770770000000077000077000770770007707700000007700
577775777755777507777777777777707000000000000000000000077000c00700000000cc0cc000cc0ccccccc0d0cc06d0cccccc00ccccccc0cc0000000cc00
000000000000000000000000000000007000000000000000000000077000000700000000cc0cc000cc0000000c050cc0d50cc000cc0cc000cc0cc0000c00cc00
00aaaaaaaaaaaa000000000000000000700000000000000000000007700c000700000000cc0ccccccc0ccccccc0d0cc05d0cc050cc0cc050cc0ccccccc0ccc00
0a999999999999a00000000000000000700000000000c000000000077000000700000000cc00ccccc000ccccc0d50cc0d50cc0d0cc0cc0d0cc0ccccccc0cccc0
a99aaaaaaaaaa99a00000000000000007000000cc0000000000000077000cc070000000000000000000000000151500151500151005001510050000000000000
a9aaaaaaaaaaaa9a000d66666666d0007000000cc0000000000c00077000cc07000000000000000000000c151515151515151515151515151515c00000000000
a99999999999999a00d6666666666d0070c00000000000000000000770c0000700000000000000000000c11111111111111111111111111111111c0000000000
a99999999999999a00666ddd6dd6660070000000000000000000000770000007000000000000000000cc1010101010101010101010101010101010c000000000
a99999999999999a00666666666666000777777777777777777777700777777000000000000000000c010101010101010101010101010101010101c000000000
aaaaaaaaaaaaaaaa0066d6dddddd66000000077707777770004bbb00004b000000400bbb00000000c000000000000000000cc00000000000000000c000000000
a49494a11a49494a00666666666666000000700070007777004bbbbb004bb000004bbbbb000000010000000000000000000cc00000000000000000c00c000000
a494a4a11a4a494a0066d6dddd6d6600000070c770c7770704200bbb042bbbbb042bbb00000000c00000000000000000000cc000000000000000001010c00000
a49444aaaa44494a0066ddd6d6dd66000000707770777c07040000000400bbb004000000000001000000000000000000000000000000000000000001000c0000
a49999aaaa99994a0066dddd99dd6600000077777777000704000000040000000400000000000100000000000000777700000000000000000000000000010000
a49444999944494a00666dd666d666000000777077700c0742000000420000004200000000000100000000000007777700000000000000000000000000001000
a494a444444a494a006677d667777600000070007000000740000000400000004000000000000000000000000007700000000000000000000000000000000000
a49499999999494a077777777777777000000777077777704000000040000000400000000001000000000000000ccccc00000000000000000000000000000010
523302e10000000000001323238452525252330000000000000000000000a2425284232323232323331352525284621352621263425233e10000007342525233
00000000000000000000000000000000000000000000000000000000000000005252526213232323525252628292425252528423232352525262a28382000000
62e1000000000000000000c1001323528433c100000000000000000000000013523382b392000000a282138452525232426273125233920000000012525233c1
000000000000000000000000000000000000000000000000000000000000000052528433838282821323236292571323232333c1c1c14252526200a282000000
3300000000000000000000000000c11333c100000000000000000000000000c162920000000000000000a24252232323425222843382000000c0d0132333c100
0000000000000000000000000000d10000000000000000000000000000000000525262920000000000a28373240000a293000000000042522333f30082930000
c1000000000000000000000000000000000000000000000000000000000000a362002000d30000000000004233a2828313845262838200b100000000a3920000
00000000000000000000000000a3020000000000000000000000000000000000525262e02000d3000000000000002414728293000000133302123200828393d3
93a100000000000000000000000000000000000000000000000000000000a3a262b071c01232b0710000d003e100a100f142526200a29300000000a392000000
000000000000000000000000a383720000000047000000000000d10000000000525262c071711232b0710043533200004222630000f0c1122252522222222222
8293d1000000000000000000000000000000000000000000b10000f300a392d16200f112846200000000f173e1000000f14252620000a2930000a39200000000
0000000000000000000000a382927300000000a00000000000f102e10000000023846293a100426200000000f103e1f11333e000f00000135284525252525284
53536300000000000000000000000000000000000093000000000002b14322226200f1425262b0c07100f00272b0717171138462000000a293a3830000000000
00000000000000000000a38292f17293000000c0d00200d10000c1d100000000001362b393934233e0000071d0737171717171c0000000c11323525252845252
92c1c100000000000000000000d1000000000000a38392000000a392c0d013843300f1135262d10000f000020300570090a24233e100b100a282829300000000
0000000000000000d1d1123200f10392000000000082f102e1b1f102e100a000000073828282039200e00000000000000000000000d10000a282132323232352
d1d10000b100000000000000d002e1000000000000a2000000a2830000a2824232d100c14233b0c0c071f0a27371c0c0c0d00392e0000000000000a293000000
00000000000000d11232133300f103e10000000000a200c1000000000000c0d00000c1a282a273000000c07171d072717171717171d0020000f0a28393c1c113
223200000000d10000000000a2b3000000000000000000000000a2930000b3428432e1a373123200b1f000a382000000b14333e000e0000000000000a2933600
000000000000f11252522232e1f173e100000000d1000000000000000000000000000000a200c1000000000000001332d100000000000000f0d3d1d1a28293c1
8462000000f102e100b10000a39200d1000000d1000000b10000f172a057a2425262e1831252337171c0d01263b0c0c0c08214c0c0c0710000000000d3a29300
e02000d39000001323845233e100c100000000f172d1000000000000000000d00000000000000000000000000000c103b0c0717171c071d0435353630000a282
5233e1000000c1a3930000a39200f1720000a372000000000000f173c0c0d0425262e1824262e000004353629200000000839300f30000000000000012222222
c0c0c01232930000c11333c1d1000000d100b1f14232930000000000b1000000000000000000000000b10000d1000003930000000000000000000000000000a2
33829300b10000a28393a3920000f1038382827300000000000000a2930000132333e1a2426200e000c1c173b0c0c0c0d012223202b0c0000000000013525252
000000425232000000c1c1f102e100f1729300f11333829300000000000000000000000000000000000000f172e10073829300000000000000000000000000f0
00a2839300000000a28292000000f173920000000000000000000000a283828232c100d142620000e0b200000000000000428452320000000000000000132352
0000f1425262930000000000c100b1f17383930000c1a28393000000000000000000000000000000000000f173e10000a2839300d100000000d10000d100f000
e020a28293d30000a39200000000000000000000000000000000000000a282836293f1721333b0c0c0c0c0c0c0717171d013525262b000000000000000008213
0000f11384628293000000000000000000a28293000000a28293000000000000000000000000000000000000c100000000a2829372e1b100a302b0c0c0c00000
c0c0d012223200a39200000000000000000000000000000000000000000000a26282f14222320000000000000000000000024284620000000000000000a38382
000000f142628282000000000000000000a3828200000000b3829300000000000000000000000000000000000000b1000000a2b303e10000a292000000000000
00000042525252525284624252525252526242528452525252842333b393f102828282930000a28292a382920000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000a282020000000000000000000000000000000000000000000000000000000000000000
0000001384522352525262425252842323331323232323232333123282829312820000a293000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000a2120000000000000000000000000000000000000000000000000000000000000000
000000004262021323236213232333c1b39200000000a28293c1133372a2834282000000a2930090000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000d10000d3a3420000000000000000000000000000000000000000000000000000000000000000
000000d313236383829273e1570000008200000000000000a293f11262e18242a293f3d11232b0c0000000d10000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000f17257001222330000000000000000000000000000000000000000000000000000000000000000
311112222232920000000000020000a382000000005700005783f14262a38213d11222222333000000000002e100570000000000000000000000000000000000
00000000000000000000000000000000000000000000000000007357f113339200000000000000000000000000000000000000000094a4b4c400000000000000
2222528452330000000000000000a312320000000014d300122253233383828232132333c1c10000000000000024000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000002400000000000000000000000000000000000000000000000000b795a5b5c5d5e5f5e4000000
525252526202e10000d1d300a312228462e1d300000072714233028292000000522232c1000000000000000000000000000000d1d30000000000000000000000
000000000000000000000000000000d30000000000000000f1720000000000000000000000000000000000000000000000000000c796a6b6c6d6e6f6f4000000
8452525262c100000012327143232323627172c0c0d073e17392000000c0c0d05252330000000000000000000002b0c0710071d002e100000000000000000000
000000000000000000000000000000020000570000000000a3426300000000000000000000000000000000000000f300000000000097a7000000e7f700000000
5252525262000000d14233e10000c1c173e113320002b07100000000000000005262c100000000000000d30000c1000000000000a200000000000000000000a3
0000000000000000000000000000000071d04353630057028273b071000000820000000000000000000000000000122200000000000000000000000000000000
23238452330000001262b071000000000071d07300920000000000000000c0d05262000000000000000002e1000000000000000000000000000000a000d3a383
00d100000000000000f30000570000000000a2b39200240083020000000082820000000000000000000000000000135200000000000000000000000000000000
92c11333c10000001333000000000000000000a2000000000000000000000000523300000000000000000000d10000d10000000000000000000000c0d0122222
0002000000570000f172000057000000000200820000000072920000a38282920000000000000000000000000000c11300000000000000000000000000000000
000082c1000000009200000000000000000000000000000000000000000000d062c100000000002000d300f10200f10200000000000000000000000000132352
0000000000240000007371435363e10000c1008200000043330000a382828293002000d3a3829357000000000000000000000000000000000000000000000000
0020a293f30000000000000000000000000000000000000000000000002700f362930000000071c0d0123282829300a293d1d1d1000000000000000000040042
000100002000000000820082839200000000a3829300a382b393a38282118283b071710212536302000000000031114100000000000000000000000000000000
b0c0c012223200000000000000000000000000000000000000000000d11222226282009300000000004262a283829300a2432232e100b20000d300240000f342
2232d1c0c0d072000072d112223212320012223202d1122222222232d1720000000012223324007293006700a312223200000000000000000000000000000000
0000d142846202d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1d1128452523383938293930093004233e1a282828283824233e1000000a312329300122252
52843200000003d1d142228452621362d113525222228452525252522262d1d185a313625700a342321222321252528400000000000000000000000000000000
000012525262122222223202122222223202122222223202122222225252528482828282b38282b3820302e100a2828282820392000000a3b342522222525252
52526200000042222252525252523242320242525252525252525284525222221222324222222252624284624252525200000000000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00006600000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000
00006600000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000770000000000000000000000000000006000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000770000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f000000000000000000000000000
00000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000006000007700000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000770000000007700000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000770000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000700000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f000000000000f00000000000000000000
00000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000007700000000000000000000000000000000000000000000000000000000
000000000000000f0000000000000000000000000000000000000000000000000000007700000000000000000000000000000000000000000000000000000000
00000000000000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007700000000000
00000000000000000000000000000000000000000000000000000000000000000000000007000000000000000000000000000000000000000007700000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000000000000000700000000000000000
00000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000060000000000000067600000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000d77760000000070000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000007770777077707770777000000d77777c000007000000000000000000000000000000000000000000000000000000
000000000000770000000000000000000000070070007070707070700000d767777c000000000000000000000000000000000000000000700000000000000000
00000000060077000000000000000000000007007700770077007770000c7676767c000600000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000700777060707070707000d767676767c067d0000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000c6666666666cd666d000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000077000000000006600000066600000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000777770077000770077777007777770077777700f77777007700000077700077777000000000000000000000000000000
000000000f0000000000000000000007777777077000770777777707777777077777770777777707700000077770777777700000000000000000000000000000
000000000000000000000000000000077000770770007707700f0000077000077000770770007707700000007700770000000000000000000000000000000000
000000000f000000000000000000000ccccccc0cc000cc0ccccccc0d0cc06d0cccccc00ccccccc0cc0000000cc00ccccccc00000000000000000000000000000
0000000000000000000000000000000cc000cc0cc000cc0000000c050cc0d50cc000cc0cc000cc0ccf000c00cc00000000c00000000000000000000000000000
0000000000000000000000000000000cc000cc0ccccccc0ccccccc0d0cc05d0cc050cc0cc050cc0ccccccc0ccc00ccccccc00000000000000000000000000000
0000000000000000000000000000000cc000cc00ccccc000ccccc0d50cc0d50cc0d0cc0cc0d0cc0ccccccc0cccc00ccccc000000000000000000000000000000
00000000000000000000000000000000000000000000000000000151500151500151005001510050000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000c151515151515151515151515151515c00000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000c11111111111111111111111111111111c0000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000cc1010101010101010101010101010101010c000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000c010101010101010101010101010101010101c000000000000000000000000000000000000000000000
0000000000000000000000000000f0f0f0f0f0f0f0f0c0f00000000000000000000000000000000000c000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000100000000000000000000000000000000000000c00c000000000000000000000000000000000000000000
000000000000000000000000000000000000000000c0000000000000000000000000000000000000001010c0f000000000000000000000000000000000000000
000000000000000000000000000000000000000001000000000000000000000000000000000000000001000c00000000000000000000000000000000f0f0f0f0
00000000000000000000000000000000000000060100000000000000000000000000000000000000000000010000000000000000000600000000000000000000
000000000000000000000000000000000000000001000000000000000000000000000000000000000000000010000000000000f000f000f000f000f000f00000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000f0000000f00000000000f00000000000f0f0f000f00000000000f0000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000f0f00000000000000000000000000700000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005550000750500000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000050050050500000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000500555005000000000000000000f00000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005000050050500000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000555000005050000000000000f000f0000000f000f000f000f000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000600000000000000000000000000000000000000000000000000000000000000000f000f000f000f0000000f000f0000000000000000000000000
00f000f000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000005550000055500550550000000550555000000550555050005550055055505550000000000000000000000000000000
00000000000000000000000000000000005050000055505050505000005050500000005000500050605000500005005000000000000000000000000000000000
00000000000000000000000000000000005550000050505050505000005050550000005000550050005500555005005500000000000000000000000000000000
00000000000000000000000000000000005050000050505050505000005050500000005000500050005000005005005000000000000000000000000000000000
0000000000000000000f000006f00000005050000050505500555000005500500000000550555055505550550005005550000000000000000000000000000000
00000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000055505050000055505550555055500000555050500550555005500550550000000000000000000000000000000000
00000000000000000000000000000000000050505050000055505050050005000000050050505050505050005050505000000000000000000000000000000000
00000000000000000000000000000000000055005550000050505550050005000000050055505050550055505050505000000000000000000000000000000f00
0000000000000000000f000f00000000000050500050000050505050050005000000050050505050505000505050505000000000000000000000000000000000
000000000000000000000000f000000000005550555000005f505050050005000000050050505500505055005500505000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000f0000000000f0000000000000000000555055005500000055000550555050000000555055505550555050500000000000000000000000000000000000
000000000000000000000000000000060000005050505050500000505050505000500ff000505050005050505050500000000000000000000000000000000000
00000000000000000000000000000000000000555050505050000050505050550050000000550055005500550055500000000000000000000000000000000f00
0000000000000000000000000000000000000050505050505000005f505050500050000f005050500050505050005000000000000000000000000000f0000000
00000000000000000000000000000000000000505050505550000050505500555055500000555055505050505055500000000000000000000000000000000000
00000000000000000f00000000000000000000000000000000006000000000000000000000000000000000000000f00000000000000000000000000000000000
00700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000f00000000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000f000
00000000000000000000000000000f00000000000000000000000f000f0000000000000000000000000000000000000000000000000000000000000000000000
0000000000f000000000000000000000000f00000000000000000000000000000000000000000000000000000000777000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000770000000000000000000000000000000000
0000000000000000000000000000000000f00000000000000007000000f000000000000000000f0000000f000000000000000000000000000000000000000000
00000000000000000000000000000000000000000050505550555005500600550055500000555005505550055000000000000000000000000000000000000000
f00000000000000000000000000000000000000000505050500500500000f050505000f000505050000500500f00000000000000000000000000000000000000
000000000000000000000000000000000000000000550055f0f50055500000505055000000555055500500555000000000000000000000000000000000000000
0000000f00000f0f0f00000000000000000000000050505050050f0050000050505000000050500050050000500000000000000000000000000000000000f000
000000000000000000000000000000000000000000505050505550550000f0555055500000505055005550550000000000000000000000000000000f00000f00
000000000000000000000000f0000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000000000000000000
0000000000000000000000f0f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f000000000000
00000000000000000000f000000000000ff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000f00000000000000000000000000000000000000000000000000000000000000000000f0f000000006000000000000000000000
000000000000000000000000000000000000000f000000000000000000000f000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f0f000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000000
000000f0000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000000000000000000000000
00000000000000000f000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000f00000000000000000000f0
f000f000000000000000f0000000000000000000000000000000000000000000000000000000f0000000000000000000000f0000000000000000000000000000
000000000000f000000007000000000000000000000000000000000000000000000000000f0f0000000000000000000000000000000700000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000f000000000000000000000000000000f0f0000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000f00000000000000000000000000006000000000000000000000000000000000f000000000000000000
0000000000000000000007700000000000000000000000000000000f00000000000000000000000000f000f00f00000000000000000000000000000000000000
00000000000000000000077000000000000000000000000000000700000000000000000000000000000000000000000000000000000000000000000000000f00

__gff__
00000000000000000000000a0a0a040400000002020000000000000002020202030303030303030304040400020000000303030303030303040404040202000200000000020202020302020202020202000000000202020200020202020202020202000002020202000202020202020202020000000000000002020202020202
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
252525322525482532323331323232323225482600000031324825252548253300000000000000000000000000000000312675242624252628291f24252526000000000000000000000000000000000000000000000000001f242620000000002425323233312525482525252624262425483232323233242548332900000000
25252675313232331c00002a282900001c312526000000001c31323232323321000000000000000000000000000000001f2422253324253328391f24254826000000000000000000000000000000000000000000000000001f3125230000000031333b28291c3132323248252624263132331c0000002a313233290000003d00
31252522231c0000000000002a390000001c24263900000000002a2839391c3100000000000000000000000000000000003132332148261e2a38202425253300000000000000001a00000000000000000000000000000000001f31330e00000000002a2800000000001c31323331331c2a283900000000000e00000000212222
2331323233000000000000003a3839000000242523000000000000002a282828000000000000000000000000000000000000001c3125261e3a28344825261c000000000000000000000000000000000000000000000000000000001c0c0000000000002a3900000000000000004200000038283900000000000e000000312548
2523402a3900000020170d343522230000003125267527390000000000002a3800000000000000000000000000000000000000001c24483628291f242526000000000000000000000000000000000000000000000000000000000000000000000e02003a3839000000003a213600003435353620342222230b0c1700001c3132
4826003a38390000000000001c31322300002a313321252223003d000000002a0000001d0000000000001f2039000000000000000031332028391f2425331d0000000000000000000000000000000000000000000075003d00000000000000000c0c0c21222300000c0d21260000750000002a29203132330000000000001c1c
25252222222300000000000000002a300000000034323232332122222300000000001f273900000000001f27283900000000000000002a3b282839242621231d0000003f0000000000000000000000000000000034360c271d271d1d3a200c0d0000002448260e000000313236212223000000392a293a290000000000000000
25252548253300000000003d000000242300000000001c1c34323232330c0d3400001f303839001d00003a302838391d000000000000002a38282831332425231d1d1d34230000000000343522233d00000900001c1c214822253523291c000000003a2425260c0c00001c1c3432323320000028393a29000000000000000000
254825323300003423000021230c0d2426000000000000002a3b393a29000000000000372828282738282837282829271e00000000000000002a28202148252521222320300075090000001c3132352222230000003a313225267537000000000000282425260e00000000002a3b393a29000021232800000000000000000000
2532331c0000001c3700003133000024263f00000000000000002a2900000c0d0000002a283b2837290000002a2839301e0000000000003a212223753132322531254822333435360e0000002a3828314826000000282838313236000000000000002a3125260c171d000000002a283800000f31332900000000000000000000
33282900000000000000002a3800002433270000000000000000002a3839001d0e02003a28291f270000001d00002a370000000000003a213232252339001c31203132261c0000000c0c0000002a283b24261d003a28282829000000000000000000001c24330e0020000000001f3436000f001c1c0000000000000000000000
2328000000000000000000002a39003721260000000000000000001f212223200c0c172729001f3700001f2700000020000000002a342226343624252375001c28292937000000000000000000002a282425233828290000000000000000000000000000371c000c17170c0c0c1717170c000000000000000000000000000000
2620390200003d0000000000002a212248252300000900000000001f2448252200001d300000000000001f3000003a2700000000002a312522222525482339002902007500000000000000000000002824252628290000000000000000000000000000001c001a00000000000000000000000000000000000000000000000000
2522230b0c21230000000000001d24253225262122231e000000001f31252548001f2126000000000000003000002a370000000000002a3132323225252523390b0c0c2720000000000000000a003a2024482629000000000000000000000000000000000000001f200000000000000000000000000000000000000000000000
25252600003125230b0c170d212225267531332425331e00000000002a313232000024330000000000001d37000000000000000000000000212223312525267500000024231d1d1d1d1d1d1d212222233125261d00000000000000000000000000000000001f20391c1f20390000000000000000000000000000000000000000
25252600001c2426000000002425483236291f242629000000000000002a21221e0030200000000000002123000000000000000000000000244825233125252300002125262122222222222225482525233125230000000000000000000000000000000000001c2a39001c2a3900000000000000000000000000000000000000
001f312631482525252532252533242526000000000000001f3132324825252525323233313232482525252532331e0000000000000000000000243300001f2400000000000000000000000000000000000000000000000000000000000031250000007400000000000000000000000000000000000000000000000000000000
00002a31363132323233753133212548330e00000000000000002a28313225483338282829001c31322548331c0000000000000000000000000037270000003100000000000000000000000000000000000000000000000000000000003a20240000000075000000000000000000000000000000000000000000000000000000
0000000000000000004200001f2425261c0c0c00003d000000000000001c312529000000000000001c31260000000000000000000000000000002a313600002a00000000000000000000000000000000000000000000000000000000002827313900000042000000000000000000000000000000000000000000000000000000
000000000000003436000020003148263900000000270e000000000000001c2400000000000000000038303900003d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002125222000000000000000000000000000000000000000000000000000000000000000
000000000000000000750000000031332a3900001f30000e0000000000000024000000000075000000282423283827000009000000000000000000000000170d000000000000000000000000000000000000000000000000620074003a2425252300000041000000000000000000000000000000000000000000000000000000
000000000000212222222236172122361d2a39001f370b0c0c00001d0000002400000000270d2700002a3133002a31360b20000000000000000000000000000000000000000000000000000000000000000000000000003f00001d2122482525330000000000000000000000000000000000000a001d00000000000000000000
00000000000f31482532332900312675273a2900001c0000000000271e00003100000034331e242300000000000000000000000000000000003f00000000000000000000000000000000000000000000000000000000002021222331322525251c000d212223201e000000000000000000000034353600000000000000000000
000000000c0c0d31331c0000001f31222629000000000000000000371e00002a00000000000924260000200b273900000927000034231d212222361721230c0d000000000000000000000000000000000000000000001f21252525237531323200003d24254823270000000000000000001b002a3b271d0000001d0000000000
0e02003f00003a283800000000001f2426001a0000000000000000000000003a0b0c00270b2125260000000024222222222600002a31222525261d1d242600000000000000000000000000000000000000200b0c17170d31482525252222237500002125322533242300000000000000000000002a313600003f270000001d00
170c0d21232028282839000000000024260e001d000000000000000000000d20000000371e243233390000093125254825330000000031324825362132261d0000000000000000000000000000000000212300000000001c31323232252548220000242675373425260000000000000000001d3f0000410041212523003a2700
000000242522222222230b1717170d2432360b170000000000000000000000000000007509372122231d212223313232332900000000002a313334262024231d00000000000000000000007400270b0c24261f203900000000001c1c31322525003f24482342002426201e0000000000001d21232000000000242526002a3700
00000024482525322533000000000037290000000000001d00000900000000000b1700212321482525222525262028290000000000000000002a2831352525220000000000000000000042000024233d24261e1c28001d0000000000001c31320021252533003d2425231e00000000000021252522231d27214825261d000000
00001d3132252620371c00000000003b000000000000343536343600000000000000003126313232322525483338280000000000000000000000002a38313232000000003d000200000000000024482225331e3a381f27000000001a00002a283a2425262122224825261e00000000001d2425482526212631322525230e0200
00002122232448231c00000000003a290000000000001c2a38282839000000000002001f2422222223313233272828000000000000000000000000002828282800001d20270b0c0d2123201d1d242525331e002a20343339001d74000000002a214825332425252525331e000000001d212525252533242523002425260c0c17
001d24252631323300000000003a3839090000000000000028282828000000000b0c0d2148252525331d1d21262829000000000000000000000000002a28283b000020212600000024482222233125261e0000001c001c2a3834361e000000002425262924482525261e0000000000214825252526752425263d312548233900
00214825252223000000000000212222231e00000000003a282838290000000000000024252548262122222526280000000000000000000000000000002a2828000021252600001f2425252525232426000000000000000000000000000000002425260024252525261e000000001f2425252525262125482522232425263839
__sfx__
0002000036370234702f3701d4702a37017470273701347023370114701e3700e4701a3600c46016350084401233005420196001960019600196003f6003f6003f6003f6003f6003f6003f6003f6003f6003f600
0002000011070130701a0702407000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300000d07010070160702207000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200000642008420094200b420224402a4503c6503b6503b6503965036650326502d6502865024640216401d6401a64016630116300e6300b62007620056100361010600106000060000600006000060000600
000400000f0701e070120702207017070260701b0602c060210503105027040360402b0303a030300203e02035010000000000000000000000000000000000000000000000000000000000000000000000000000
000300000977009770097600975008740077300672005715357003470034700347003470034700347003570035700357003570035700347003470034700337003370033700337000070000700007000070000700
00030000241700e1702d1701617034170201603b160281503f1402f120281101d1101011003110001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00020000101101211014110161101a120201202613032140321403410000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
000200001f630256302a6302e63030630306202f6202e6202c6202a620286202662024610226101f6101c610196101661013610116100e6100b61007610056100361010600106000060000600006000060000600
0003000005110071303f6403f6403f6303f6203f6103f6153f6003f6003f600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
011000200177500605017750170523655017750160500605017750060501705076052365500605017750060501775017050177500605236550177501605006050177500605256050160523655256050177523655
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
000b00002935500300293453037030360303551330524300243050030013305243002430500300003002430024305003000030000300003000030000300003000030000300003000030000300003000030000300
001000003c5753c5453c5353c5253c5153c51537555375453a5753a5553a5453a5353a5253a5253a5153a51535575355553554535545355353553535525355253551535515335753355533545335353352533515
00100000355753555535545355353552535525355153551537555375353357533555335453353533525335253a5753a5453a5353a5253a5153a51533575335553354533545335353353533525335253351533515
001000200c0600c0300c0500c0300c0500c0300c0100c0000c0600c0300c0500c0300c0500c0300c0100f0001106011030110501103011010110000a0600a0300a0500a0300a0500a0300a0500a0300a01000000
001000000506005030050500503005010050000706007030070500703007010000000f0600f0300f010000000c0600c0300c0500c0300c0500c0300c0500c0300c0500c0300c010000000c0600c0300c0100c000
0010000003625246150060503615246251b61522625036150060503615116253361522625006051d6250a61537625186152e6251d615006053761537625186152e6251d61511625036150060503615246251d615
00100020326103261032610326103161031610306102e6102a610256101b610136100f6100d6100c6100c6100c6100c6100c6100f610146101d610246102a6102e61030610316103361033610346103461034610
00400000302453020530235332252b23530205302253020530205302253020530205302153020530205302152b2452b2052b23527225292352b2052b2252b2052b2052b2252b2052b2052b2152b2052b2052b215
000400002f45032450314502e4502f45030450000000000001400264002f45032450314502e4502f4503045030400304000000000000000000000000000000000000000000000000000000000000000000000000
__music__
01 150a5644
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
00 1c1b1a44
00 1d1b1a44
00 1f211a44
00 1f1a2144
00 1e1a2244
02 201a2444
00 41424344
00 41424344
01 2a272944
00 2a272944
00 2f2b2944
00 2f2b2c44
00 2f2b2944
00 2f2b2c44
00 2e2d3044
00 34312744
02 35322744
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

