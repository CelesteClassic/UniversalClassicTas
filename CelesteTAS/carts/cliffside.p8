pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
--~cliffside~
--mod by: rubyred

--built with:
--~evercore~
--a celeste classic mod base
--v3.0 - polished version
--mod by: taco360
--based on meep's smalleste
--and akliant's hex loading

--original game by:
--matt thorson + noel berry

-- [data structures]

function vector(x,y)
  return {x=x,y=y}
end

function rectangle(x,y,w,h)
  return {x=x,y=y,w=w,h=h}
end

-- [globals]

objects,got_fruit,
freeze,delay_restart,sfx_timer,music_timer,
ui_timer=
{},{},
0,0,0,0,-99

-- [entry point]

function _init()
  title_screen()
end

function title_screen()
  frames,start_game_flash=0,0
  music(40,0,7)
  load_level(-1)
end

function begin_game()
  max_djump,deaths,frames,seconds,minutes,music_timer,time_ticking,shake=1,0,0,0,0,0,true,0
  music(0,0,7)
  load_level(0)
end

function is_title()
  return lvl_id==-1
end

-- [effects]

function rnd128()
  return rnd(128)
end

clouds={}
for i=0,16 do
  add(clouds,{
    x=rnd128(),
    y=rnd128(),
    spd=1+rnd(4),
    w=32+rnd(32)
  })
end

particles={}
for i=0,24 do
  add(particles,{
    x=rnd128(),
    y=rnd128(),
    s=flr(rnd(1.25)),
    spd=0.25+rnd(5),
    off=rnd(1),
    c=6+rnd(2),
  })
end

dead_particles={}

-- [player entity]

player={
  init=function(this) 
    this.grace,this.jbuffer=0,0
    this.djump=max_djump
    this.dash_time,this.dash_effect_time=0,0
    this.dash_target_x,this.dash_target_y=0,0
    this.dash_accel_x,this.dash_accel_y=0,0
    this.hitbox=rectangle(1,3,6,5)
    this.spr_off=0
    this.solids=true
    create_hair(this)
  end,
  update=function(this)
    if pause_player then
      return
    end
    
    if lvl_id>=30 and this.y>lvl_ph then
      next_level()
      return
    end

    if this.y < -4 then
      cam_gain=0.25
    else
      cam_gain=0
    end

    -- horizontal input
    local h_input=btn(➡️) and 1 or btn(⬅️) and -1 or 0
    
    -- spike collision / bottom death
    if spikes_at(this.x+this.hitbox.x,this.y+this.hitbox.y,this.hitbox.w,this.hitbox.h,this.spd.x,this.spd.y)
	   or	this.y>lvl_ph then
	    kill_player(this)
    end

    -- on ground checks
    local on_ground=this.is_solid(0,1)
    
    -- landing smoke
    if on_ground and not this.was_on_ground then
      init_object(smoke,this.x,this.y+4)
    end

    -- jump and dash input
    local jump,dash=btn(🅾️) and not this.p_jump,btn(❎) and not this.p_dash
    this.p_jump,this.p_dash=btn(🅾️),btn(❎)

    -- jump buffer
    if jump then
      this.jbuffer=4
    elseif this.jbuffer>0 then
      this.jbuffer-=1
    end
    
    -- grace frames and dash restoration
    if on_ground then
      this.grace=6
      if this.djump<max_djump then
        psfx(54)
        this.djump=max_djump
      end
    elseif this.grace>0 then
      this.grace-=1
    end

    -- dash effect timer (for dash-triggered events, e.g., berry blocks)
    this.dash_effect_time-=1

    -- dash startup period, accel toward dash target speed
    if this.dash_time>0 then
      init_object(smoke,this.x,this.y)
      this.dash_time-=1
      this.spd=vector(appr(this.spd.x,this.dash_target_x,this.dash_accel_x),appr(this.spd.y,this.dash_target_y,this.dash_accel_y))
    else
      -- x movement
      local maxrun=1
      local accel=this.is_ice(0,1) and 0.05 or on_ground and 0.6 or 0.4
      local deccel=0.15
    
      -- set x speed
      this.spd.x=abs(this.spd.x)<=1 and 
        appr(this.spd.x,h_input*maxrun,accel) or 
        appr(this.spd.x,sign(this.spd.x)*maxrun,deccel)
      
      -- facing direction
      if this.spd.x~=0 then
        this.flip.x=(this.spd.x<0)
      end

      -- y movement
      local maxfall=2
    
      -- wall slide
      if h_input~=0 and this.is_solid(h_input,0) and not this.is_ice(h_input,0) then
        maxfall=0.4
        -- wall slide smoke
        if rnd(10)<2 then
          init_object(smoke,this.x+h_input*6,this.y)
        end
      end

      -- apply gravity
      if not on_ground then
        this.spd.y=appr(this.spd.y,maxfall,abs(this.spd.y)>0.15 and 0.21 or 0.105)
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
            if not this.is_ice(wall_dir*3,0) then
              -- wall jump smoke
              init_object(smoke,this.x+wall_dir*6,this.y)
            end
          end
        end
      end
    
      -- dash
      local d_full=5
      local d_half=3.5355339059 -- 5 * sqrt(2)
    
      if this.djump>0 and dash then
        init_object(smoke,this.x,this.y)
        this.djump-=1   
        this.dash_time=4
        has_dashed=true
        this.dash_effect_time=10
        -- vertical input
        local v_input=btn(⬆️) and -1 or btn(⬇️) and 1 or 0
        -- calculate dash speeds
        this.spd=vector(h_input~=0 and 
        h_input*(v_input~=0 and d_half or d_full) or 
        (v_input~=0 and 0 or this.flip.x and -1 or 1)
        ,v_input~=0 and v_input*(h_input~=0 and d_half or d_full) or 0)
        -- effects
        psfx(3)
        freeze=2
        -- dash target speeds and accels
        this.dash_target_x=2*sign(this.spd.x)
        this.dash_target_y=(this.spd.y>=0 and 2 or 1.5)*sign(this.spd.y)
        this.dash_accel_x=this.spd.y==0 and 1.5 or 1.06066017177 -- 1.5 * sqrt()
        this.dash_accel_y=this.spd.x==0 and 1.5 or 1.06066017177
      elseif this.djump<=0 and dash then
        -- failed dash smoke
        psfx(9)
        init_object(smoke,this.x,this.y)
      end
    end
    
    -- animation
    this.spr_off+=0.25
    this.spr = not on_ground and (this.is_solid(h_input,0) and 5 or 3) or  -- wall slide or mid air
      btn(⬇️) and 6 or -- crouch
      btn(⬆️) and 7 or -- look up
      1+(this.spd.x~=0 and h_input~=0 and this.spr_off%4 or 0) -- walk or stand
    
   	--move camera to player
   	--this must be before next_level
   	--to avoid loading jank
    move_camera(this)
    
    -- exit level off the top (except summit)
    if this.y<-4 and lvl_id<30 then
      next_level()
    end

    -- was on the ground
    this.was_on_ground=on_ground
  end,
  
  draw=function(this)
    -- clamp in screen
  		if this.x<-1 or this.x>lvl_pw-7 then
   		this.x=clamp(this.x,-1,lvl_pw-7)
   		this.spd.x=0
  		end
    -- draw player hair and sprite
    set_hair_color(this.djump)
    draw_hair(this,this.flip.x and -1 or 1)
    spr(this.spr,this.x,this.y,1,1,this.flip.x,this.flip.y)   
    unset_hair_color()
  end
}

function create_hair(obj)
  obj.hair={}
  for i=1,5 do
    add(obj.hair,vector(obj.x,obj.y))
  end
end

function set_hair_color(djump)
  pal(8,djump==1 and 8 or djump==2 and 7+(flr(frames/3))%2*4 or 12)
end

function draw_hair(obj,facing)
  local last=vector(obj.x+4-facing*2,obj.y+(btn(⬇️) and 4 or 3))
  for i,h in pairs(obj.hair) do
    h.x+=(last.x-h.x)/1.5
    h.y+=(last.y+0.5-h.y)/1.5
    circfill(h.x,h.y,clamp(4-i,1,2),8)
    last=h
  end
end

function unset_hair_color()
  pal(8,8)
end

-- [other entities]

player_spawn={
  init=function(this)
    sfx(4)
    this.spr=3
    this.target=this.y
    this.y=min(this.y+48,lvl_ph)
    if lvl_id ~= 31 then
		  cam_x=clamp(this.x,64,lvl_pw-64)
		  cam_y=clamp(this.y,64,lvl_ph-64)
    end
    this.spd.y=-4
    this.state=0
    this.delay=0
    create_hair(this)
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
          this.spd=vector(0,0)
          this.state=2
          this.delay=5
          init_object(smoke,this.x,this.y+4)
          sfx(5)
        end
      end
    -- landing and spawning player object
    elseif this.state==2 then
      this.delay-=1
      this.spr=6
      if this.delay<0 then
        destroy_object(this)
        init_object(player,this.x,this.y)
      end
    end
    move_camera(this)
  end,
  draw=function(this)
    set_hair_color(max_djump)
    draw_hair(this,1)
    spr(this.spr,this.x,this.y)
    unset_hair_color()
  end
}

spring={
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
      local hit=this.check(player,0,0)
      if hit and hit.spd.y>=0 then
        this.spr=19
        hit.y=this.y-4
        hit.spd.x*=0.2
        hit.spd.y=-3
        hit.djump=max_djump
        this.delay=10
        init_object(smoke,this.x,this.y)
        -- crumble below spring
        local below=this.check(fall_floor,0,1)
        if below then
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

function break_spring(obj)
  obj.hide_in=15
end

balloon={
  init=function(this) 
    this.offset=rnd(1)
    this.start=this.y
    this.timer=0
    this.hitbox=rectangle(-1,-1,10,10)
  end,
  update=function(this) 
    if this.spr==22 then
      this.offset+=0.01
      this.y=this.start+sin(this.offset)*2
      local hit=this.check(player,0,0)
      if hit and hit.djump<max_djump then
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

fall_floor={
  init=function(this)
    this.state=0
  end,
  update=function(this)
    -- idling
    if this.state==0 then
      if this.check(player,0,-1) or this.check(player,-1,0) or this.check(player,1,0) then
        break_fall_floor(this)
      end
    -- shaking
    elseif this.state==1 then
      this.delay-=1
      if this.delay<=0 then
        this.state=2
        this.delay=60--how long it hides for
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
    if this.state~=2 then
      if this.state~=1 then
        spr(23,this.x,this.y)
      else
        spr(23+(15-this.delay)/5,this.x,this.y)
      end
    end
  end
}

function break_fall_floor(obj)
 if obj.state==0 then
  psfx(15)
    obj.state=1
    obj.delay=15--how long until it falls
    init_object(smoke,obj.x,obj.y)
    local hit=obj.check(spring,0,-1)
    if hit then
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
  end,
  update=function(this)
    this.spr+=0.2
    if this.spr>=32 then
      destroy_object(this)
    end
  end
}

fruit={
  if_not_fruit=true,
  init=function(this) 
    this.start=this.y
    this.off=0
  end,
  update=function(this)
   local hit=this.check(player,0,0)
    if hit then
      hit.djump=max_djump
      sfx_timer=20
      sfx(13)
      got_fruit[1+lvl_id]=true
      init_object(lifeup,this.x,this.y)
      destroy_object(this)
    end
    this.off+=1
    this.y=this.start+sin(this.off/40)*2.5
  end
}

fly_fruit={
  if_not_fruit=true,
  init=function(this) 
    this.start=this.y
    this.fly=false
    this.step=0.5
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
    local hit=this.check(player,0,0)
    if hit then
      hit.djump=max_djump
      sfx_timer=20
      sfx(13)
      got_fruit[1+lvl_id]=true
      init_object(lifeup,this.x,this.y)
      destroy_object(this)
    end
  end,
  draw=function(this)
    local off=0
    if not this.fly then
      if sin(this.step)<0 then
        off=1+max(0,sign(this.y-this.start))
      end
    else
      off=(off+0.25)%3
    end
    spr(45+off,this.x-6,this.y-2,1,1,true)
    spr(this.spr,this.x,this.y)
    spr(45+off,this.x+6,this.y-2)
  end
}

lifeup={
  init=function(this)
    this.spd.y=-0.25
    this.duration=30
    this.x-=2
    this.y-=4
    this.flash=0
  end,
  update=function(this)
    this.duration-=1
    if this.duration<=0 then
      destroy_object(this)
    end
  end,
  draw=function(this)
    this.flash+=0.5
    ?"1000",this.x-2,this.y,7+this.flash%2
  end
}

fake_wall={
  if_not_fruit=true,
  update=function(this)
    this.hitbox.w=18
    this.hitbox.h=18
    local hit=this.check(player,-1,-1)
    if hit and hit.dash_effect_time>0 then
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
      if lvl_id==30 then
        init_object(secret_effect, this.x+8, this.y+8)
        sfx(3)
      else
        init_object(fruit,this.x+4,this.y+4,26)
      end
    end
    this.hitbox.w=16
    this.hitbox.h=16
  end,
  draw=function(this)
    sspr(0,32,16,16,this.x,this.y)
  end
}

secret_effect = {
  init=function(this)
    this.timer=10
    shake=20
    objects[1].hidespr=true
    replace_room(6,3,mapdata[34])
  end,
  update=function(this)
    this.timer-=1
    if this.timer<=0 then
      destroy_object(this)
    end
  end,
  draw=function(this)
    if this.timer==9 or this.timer==7 then
      rectfill(0, 0, 128, 128, 7)
    end
    rectfill(this.x-16*(this.timer/10), 0, this.x+16*(this.timer/10), 128, 7)
  end
}

key={
  if_not_fruit=true,
  update=function(this)
    local was=flr(this.spr)
    this.spr=9.5+sin(frames/30)
    if this.spr==10 and this.spr~=was then
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

chest={
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
        init_object(fruit,this.x,this.y-4,26)
        destroy_object(this)
      end
    end
  end
}

platform={
  init=function(this)
    this.x-=4
    this.hitbox.w=16
    this.last=this.x
    this.dir=this.spr==11 and -1 or 1
  end,
  update=function(this)
    this.spd.x=this.dir*0.65
    if this.x<-16 then this.x=128
    elseif this.x>128 then this.x=-16 end
    if not this.check(player,0,0) then
      local hit=this.check(player,0,-1)
      if hit then
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
  draw=function(this)
    this.text="  -- cliffside --  # mountain climbing #training simulation"
    if this.check(player,4,0) then
      if this.index<#this.text then
       this.index+=0.5
        if this.index>=this.last+1 then
          this.last+=1
          sfx(35)
        end
      end
      local _x,_y=16,72 
      for i=1,this.index do
        if sub(this.text,i,i)~="#" then
          rectfill(_x-2,_y-2,_x+7,_y+6 ,7)
          ?sub(this.text,i,i),_x,_y,0
          _x+=5
        else
          _x=16
          _y+=7
        end
      end
    else
      this.index=0
      this.last=0
    end
  end
}

--w=19,h=32
avatar={
  init=function(this)
    this.activated=-1
    this.reveal=0
  end,
  update=function(this)
    if this.activated==-1 and this.check(player,0,0) then
      sfx(4)
      this.activated=10
    end

    if this.activated > 0 then
      this.activated-=1
      if this.activated == 0 then
        this.reveal=10
      end
    end

    if this.reveal > 0 then
      this.reveal-=1
    end
  end,
  draw=function(this)
    spr(21, this.x,this.y)
    circ(this.x+120, this.y-72, 2, 1)
    if this.activated ~= -1 then
      local scale = (10-this.activated)/10
      rectfill(this.x+6, this.y-34*scale, this.x+24*scale, this.y-2, 13)
      if this.activated==0 then
        draw_path(mapdata[36], this.x+11, this.y-3)
        draw_path(mapdata[37], this.x+19, this.y-3)
        local scale2 = (this.reveal)/10
        rectfill(this.x+6, this.y-34, this.x+24, this.y-34+32*scale2, 13)
      end
      line(this.x+6, this.y-2, this.x+6, this.y-34*scale, 7)
      line(this.x+6, this.y-2, this.x+24*scale, this.y-2, 7)
      line(this.x+24, this.y-34, this.x+24, this.y-34+32*scale, 7)
      line(this.x+24, this.y-34, this.x+24-18*scale, this.y-34, 7)
    end
  end
}

function draw_path(input,x,y)
  local counter=0
  for i=1,#input do
    local num = tonum(sub(input,i,i))-3
    local dir = num > 0 and 1 or -1
    for w=0,num,dir do
      pset(x+counter+w, y-i, 1)
    end
    counter += num
  end
  pset(x,y-1,11)
end

big_chest={
  init=function(this)
    this.state=0
    this.hitbox.w=16
  end,
  draw=function(this)
    if this.state==0 then
      local hit=this.check(player,0,8)
      if hit and hit.is_solid(0,1) then
        music(-1,500,7)
        sfx(37)
        pause_player=true
        hit.spd=vector(0,0)
        this.state=1
        init_object(smoke,this.x,this.y)
        init_object(smoke,this.x+8,this.y)
        this.timer=60
        this.particles={}
      end
      sspr(0,48,16,8,this.x,this.y)
    elseif this.state==1 then
      this.timer-=1
      flash_bg=true
      if this.timer<=45 and #this.particles<50 then
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
    sspr(0,56,16,8,this.x,this.y+8)
  end
}

orb={
  init=function(this)
    this.spd.y=-4
  end,
  draw=function(this)
    this.spd.y=appr(this.spd.y,0,0.5)
    local hit=this.check(player,0,0)
    if this.spd.y==0 and hit then
     music_timer=45
      sfx(51)
      freeze=10
      destroy_object(this)
      max_djump=2
      hit.djump=2
    end
    spr(102,this.x,this.y)
    for i=0,7 do
      circfill(this.x+4+cos(frames/30+i/8)*8,this.y+4+sin(frames/30+i/8)*8,1,7)
    end
  end
}

flag={
  init=function(this)
    this.show=false
    this.hidespr=false
    this.x+=5
    this.score=0
    for k,v in pairs(got_fruit) do
      this.score+=1
    end
  end,
  draw=function(this)
    this.spr=118+(frames/5)%3
    if not this.hidespr then
      spr(this.spr,this.x,this.y)
    end
    if this.show then
      rectfill(32,2,96,31,0)
      spr(26,55,6)
      ?"x"..this.score,64,9,7
      draw_time(49,16)
      ?"deaths:"..deaths,48,24,7
    elseif this.check(player,0,0) then
      sfx(55)
      sfx_timer,this.show,time_ticking=30,true,false
    end
  end
}

psfx=function(num)
  if sfx_timer<=0 then
   sfx(num)
  end
end

-- [tile dict]
tiles={
  [1]=player_spawn,
  [8]=key,
  [11]=platform,
  [12]=platform,
  [18]=spring,
  [20]=chest,
  [21]=avatar,
  [22]=balloon,
  [23]=fall_floor,
  [26]=fruit,
  [28]=fly_fruit,
  [64]=fake_wall,
  [86]=message,
  [96]=big_chest,
  [118]=flag
}

-- [object functions]

function init_object(type,x,y,tile)
  if type.if_not_fruit and got_fruit[1+lvl_id] then
    return
  end

  local obj={
    type=type,
    collideable=true,
    solids=false,
    spr=tile,
    flip=vector(false,false),
    x=x,
    y=y,
    hitbox=rectangle(0,0,8,8),
    spd=vector(0,0),
    rem=vector(0,0),
  }

  function obj.is_solid(ox,oy)
    return (oy>0 and not obj.check(platform,ox,0) and obj.check(platform,ox,oy)) or
           tile_flag_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h,0) or 
           obj.check(fall_floor,ox,oy) or
           obj.check(fake_wall,ox,oy)
  end
  
  function obj.is_ice(ox,oy)
    return tile_flag_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h,4)
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
  
  function obj.move(ox,oy)
    -- x movement
    obj.rem.x+=ox
    local amount=round(obj.rem.x)
    obj.rem.x-=amount
    obj.move_x(amount,0)
    -- y movement
    obj.rem.y+=oy
    amount=flr(obj.rem.y+0.5)
    obj.rem.y-=amount
    obj.move_y(amount)
  end
  
  function obj.move_x(amount,start)
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
  
  function obj.move_y(amount)
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

function kill_player(obj)
  sfx_timer=12
  sfx(0)
  deaths+=1
  destroy_object(obj)
  dead_particles={}
  for dir=0,7 do
    add(dead_particles,{
      x=obj.x+4,
      y=obj.y+4,
      t=10,
      dx=sin(dir/8)*3,
      dy=cos(dir/8)*3
    })
  end
  restart_level()
end

-- [room functions]

function restart_level()
  delay_restart=15
end

function next_level()
  local next_lvl=lvl_id+1
  if next_lvl==11 or next_lvl==21 or next_lvl==30 then -- quiet for old site, 2200m, summit
    music(30,500,7)
  elseif next_lvl==12 then -- 1300m
    music(20,500,7)
  end

  if next_lvl==30 then
    time_ticking=false
  end

  load_level(next_lvl)
end

function load_level(lvl)
  has_dashed=false
  has_key=false
  
  --remove existing objects
  foreach(objects,destroy_object)
  
  --reset camera speed
  cam_spdx=0
	cam_spdy=0
		
	--set level index
  lvl_id=lvl
  
  --set level globals
  local tbl=get_lvl()
  lvl_x,lvl_y,lvl_w,lvl_h,lvl_title=tbl[1],tbl[2],tbl[3]*16,tbl[4]*16,tbl[5]
  lvl_pw=lvl_w*8
  lvl_ph=lvl_h*8

  --reload map
  --level title setup
  if not is_title() then
  	reload()
  	ui_timer=5
  end
  
  --check for hex mapdata
  if get_data() then
  	--replace old rooms with data
  	for i=0,get_lvl()[3]-1 do
   	for j=0,get_lvl()[4]-1 do
     --replace_room(lvl_x+i,lvl_y+j,get_data()[i*get_lvl()[4]+j+1])
   	end
  	end
  end

  if lvl_id==30 and max_djump<2 then
    replace_room(6,3,mapdata[33])
  end

  if lvl_id==31 then
    replace_room(0, 0, mapdata[31])
    replace_room(1, 0, mapdata[32])
    cam_x=64
    cam_y=64
  end

  
  -- entities
  for tx=0,lvl_w-1 do
    for ty=0,lvl_h-1 do
      local tile=mget(lvl_x*16+tx,lvl_y*16+ty)
      if tiles[tile] then
        init_object(tiles[tile],tx*8,ty*8,tile)
      end
    end
  end
end

-- [main update loop]

function _update()
  frames=(frames+1)%30
  if frames==0 and time_ticking then
    seconds=(seconds+1)%60
    if seconds==0 then
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
  if delay_restart>0 then
    delay_restart-=1
    if delay_restart==0 then
      load_level(lvl_id)
    end
  end

  if shake and shake>0 then
    shake-=1
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
    if start_game then
      start_game_flash-=1
      if start_game_flash<=-30 then
        begin_game()
      end
    elseif btn(🅾️) or btn(❎) then
      music(-1)
      start_game_flash=50
      start_game=true
      sfx(38)
    end
  end
end

-- [drawing functions]

function _draw()
  if freeze>0 then
    return
  end
  
  -- reset all palette values
  pal()
  
  -- start game flash
  if is_title() and start_game then
    local c=start_game_flash>10 and (frames%10<5 and 7 or 10) or (start_game_flash>5 and 2 or start_game_flash>0 and 1 or 0)
    if c<10 then
      for i=1,15 do
        pal(i,c)
      end
    end
  end
		
		--set cam draw position
  local camx=is_title() and 0 or round(cam_x)-64
  local camy=is_title() and 0 or round(cam_y)-64

  if shake then camx+=(sin(shake/5)*3) end
  if shake then camy+=(sin(shake/10)*1) end

  camera(camx,camy)

  --local token saving
  local xtiles=lvl_x*16
  local ytiles=lvl_y*16
  
  -- draw bg color
  cls(flash_bg and frames/5 or new_bg and 2 or 0)

  -- bg clouds effect
  if not is_title() then
    foreach(clouds, function(c)
      c.x+=c.spd-cam_spdx
      rectfill(c.x+camx,c.y+camy,c.x+c.w+camx,c.y+4+(1-c.w/64)*12+camy,new_bg and 14 or 1)
      if c.x>128 then
        c.x=-c.w
        c.y=rnd(120)
      end
    end)
  end

		-- draw bg terrain
  map(xtiles,ytiles,0,0,lvl_w,lvl_h,4)

  -- platforms/big chest
  foreach(objects, function(o)
    if o.type==platform or o.type==big_chest then
      draw_object(o)
    end
  end)

  -- draw terrain
  map(xtiles,ytiles,0,0,lvl_w,lvl_h,2)
  
  -- draw objects
  foreach(objects, function(o)
    if o.type~=platform and o.type~=big_chest then
      draw_object(o)
    end
  end)
  
  -- particles
  foreach(particles, function(p)
    p.x+=p.spd-cam_spdx
    p.y+=sin(p.off)-cam_spdy
    p.off+=min(0.05,p.spd/32)
    rectfill(p.x+camx,p.y%128+camy,p.x+p.s+camx,p.y%128+p.s+camy,p.c)
    if p.x>132 then 
      p.x=-4
      p.y=rnd128()
   	elseif p.x<-4 then
     	p.x=128
     	p.y=rnd128()
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
  
  -- draw level title
  if ui_timer>=-30 then
  	if ui_timer<0 then
  		draw_ui(camx,camy)
  	end
  	ui_timer-=1
  end
  
  -- credits
  if is_title() then
		sspr(72,32,64,32,36,32)
    local icoy=start_game and (50-start_game_flash) or 0
    spr(21, 114, 118+icoy)
    ?"z+x",58,80,5
    ?"matt thorson",42,96,5
    ?"noel berry",46,102,5
    ?"mod by rubyred",38,110,5
    rect(0,0,127,127,7)
  end
  
  -- summit blinds effect
  if lvl_id==30 then
    local summitplayerindex = max_djump<2 and 3 or 2
    if objects[summitplayerindex] and objects[summitplayerindex].type==player then
      local diff=min(24,40-abs(objects[summitplayerindex].x-60))
      rectfill(0,0,diff,127,0)
      rectfill(127-diff,0,127,127,0)
    end
  end
end

function draw_object(obj)
  if obj.type.draw then
    obj.type.draw(obj)
  elseif obj.spr then
    spr(obj.spr,obj.x,obj.y,1,1,obj.flip.x,obj.flip.y)
  end
end

function draw_content(x,y,r,c)
  rectfill(x,y,x+111,y+111,13)
  rectfill(x+48,y-8,x+63,y,13)
  local con=mapdata[35]
  for i=1,#mapdata[35] do
    if sub(con,i,i)=="1" then
      local yoff=flr((i-1)/29)
      local xoff=((i-1)%29)
      rectfill(x+xoff*2+27,y+yoff*2+27,x+xoff*2+1+27,y+yoff*2+1+27,1)
    end
  end
end

function draw_time(x,y)
  rectfill(x,y,x+32,y+6,0)
  ?two_digit_str(flr(minutes/60))..":"..two_digit_str(minutes%60)..":"..two_digit_str(seconds),x+1,y+1,7
end

function draw_ui(camx,camy)
  if lvl_title and lvl_title=="" then return end

 rectfill(24+camx,58+camy,104+camx,70+camy,0)
 local title=lvl_title
 if title then
  ?title,hcenter(title,camx),62,7
 else
 	local level=(1+lvl_id)*100
  ?level.." m",52+(level<1000 and 2 or 0)+camx,62+camy,7
 end
 draw_time(4+camx,4+camy)
end

function two_digit_str(x)
  return x<10 and "0"..x or x
end

-- [helper functions]

function round(x)
  return flr(x+0.5)
end

function clamp(val,a,b)
  return max(a,min(b,val))
end

function hcenter(s,camx)
	return (64-#s*2)+camx
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

circ=draw_content

function tile_flag_at(x,y,w,h,flag)
  for i=max(0,flr(x/8)),min(lvl_w-1,(x+w-1)/8) do
    for j=max(0,flr(y/8)),min(lvl_h-1,(y+h-1)/8) do
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
  for i=max(0,flr(x/8)),min(lvl_w-1,(x+w-1)/8) do
    for j=max(0,flr(y/8)),min(lvl_h-1,(y+h-1)/8) do
      local tile=tile_at(i,j)
      if (tile==17 and ((y+h-1)%8>=6 or y+h==j*8+8) and yspd>=0) or
         (tile==27 and y%8<=2 and yspd<=0) or
         (tile==43 and x%8<=2 and xspd<=0) or
         (tile==59 and ((x+w-1)%8>=6 or x+w==i*8+8) and xspd>=0) then
         return true
      end
    end
  end
end
-->8
--scrolling level stuff

--level table
--strings follow this format:
--"x,y,w,h,title"
levels={
	[-1]="0,-1,1,1",
	[0]="0,0,1,1",
	[1]="1,0,1,1",
  [2]="2,0,1,1",
  [3]="3,0,1,1",
  [4]="4,0,1,1",
  [5]="5,0,1,1",
  [6]="6,0,1,1",
  [7]="7,0,1,1",
  [8]="0,1,1,1",
  [9]="1,1,1,1",
  [10]="2,1,1,1",
  [11]="3,1,1,1,old site",
  [12]="4,1,1,1",
  [13]="5,1,1,1",
  [14]="6,1,1,1",
  [15]="7,1,1,1",
  [16]="0,2,1,1",
  [17]="1,2,1,1",
  [18]="2,2,1,1",
  [19]="3,2,1,1",
  [20]="4,2,1,1",
  [21]="5,2,1,1",
  [22]="6,2,1,1",
  [23]="7,2,1,1",
  [24]="0,3,1,1",
  [25]="1,3,1,1",
  [26]="2,3,1,1",
  [27]="3,3,1,1",
  [28]="4,3,1,1",
  [29]="5,3,1,1",
  [30]="6,3,1,1,summit",
  [31]="0,0,2,1,"
}

--mapdata table
--rooms separated by commas
mapdata={
  [31]="25323232323233000031323232323225260000000000000000000000000000242600000000000000000000000000002426000000000000000000000000000024260000000000000000000000000000242600000000000000000000000000002426000000000000000000010000000024260000000000000000003436000000242600000000000000000000000000002426000000000000000000000000000024260015000000000000000000000000242522222300000000000000000000002425252525230000000000000000000024252525252523000000000000000000242525252525252300000000000000002425252525252525222222222222222225",
  [32]="25323232323233000031323232323225260000000000000000000000000000242600000000000000000000000000002426000000000000000000000000000024260000000000000000000000000000242600000000000000000000000000002426000000000000000000000000000024260000000000000000000000000000242600000000000000000000000000002426000000000000000000000000000024260000000000000000000000000000242600000000000000000000000000002426000000000000000000000000000024260000000000000000000000000000242600000000000000000000000000002425222222222222222222222222222225",
  [33]="000000000000000000000000000000000000000000002a000029000000000000000000000000003a3900000000000000000000000000002a2900000000000000000000000039000000003a00000000000000003a3a29000000002a393900000000002a10280000760000002810290000000000002a393a4000393a290000000000000000002a27000027290000000000000000000021252222252300000000000000003a21253232323225233900000000003a21252642434344242523390000002a282425265253535424252628290000002125252652535354242525230000013a313232336263636431323233390021222372737374000072737374212223",
  [34]="000000000000000000000000000000000000000000002a000029000000000000000000000000003a3900000000000000000000000000002a2900000000000000000000000039000000003a00000000000000003a3a29000000002a393900000000002a10280000000000002810290000000000002a39000000003a290000000000000000002a00000000290000000000000000000027000000002700000000000000003a21260000000024233900000000003a21252600000000242523390000002a282425260000000024252628290000002125252600000000242525230000003a313232330000000031323233390021222372737400000000727374212223",
  [35]="1111111001101011100010111111110000010101111110100001000001101110100101010010011010111011011101011101011011010101110110111010011000111000101011101100000101101111111110010000011111111010101010101010111111100000000010100101111100000000111110111100000111001101010101011010110000000101000011101011100110001011100100000001100011100011001010000111011110011101111111101011110011000000000110001110000001001111111010000101100010111001000001011111010110100010000111111111001111101010010000111010000110000100000011111001100011011110111001101000001110010100000111010011101111101001001101110001101011110110111100001111111100000000010110010101110001001011111110100111100100101011100100000100111000001111000101111011101011000111001011111011110111010111100000010110100000101110101111111101010111001101000001010110100100100000110111111110101010111001011011100",
  [36]="34332233432432244334233242334",
  [37]="34422222623252334324324422334"
}

function get_lvl()
	return split(levels[lvl_id])
end

function get_data()
	return split(mapdata[lvl_id])
end

--not using tables to conserve tokens
cam_x=0
cam_y=0
cam_spdx=0
cam_spdy=0
cam_gain=0.25

function move_camera(obj)
  --set camera speed
  cam_spdx=cam_gain*(4+obj.x+0*obj.spd.x-cam_x)
  cam_spdy=cam_gain*(4+obj.y+0*obj.spd.y-cam_y)

  cam_x+=cam_spdx
  cam_y+=cam_spdy

  if cam_x<64 or cam_x>lvl_pw-64 then
    cam_spdx=0
    cam_x=clamp(cam_x,64,lvl_pw-64)
  end
  if cam_y<64 or cam_y>lvl_ph-64 then
    cam_spdy=0
    cam_y=clamp(cam_y,64,lvl_ph-64)
  end
end

--replace mapdata with hex
function replace_room(x,y,room)
 for y_=1,32,2 do
  for x_=1,32,2 do
   local offset=4096+(y<2 and 4096 or -4096)
   local hex=sub(room,x_+(y_-1)/2*32,x_+(y_-1)/2*32+1)
   poke(offset+x*16+y*2048+(y_-1)*64+x_/2, "0x"..hex)
  end
 end
end

--[[

short on tokens?
everything below this comment
is just for grabbing data
rather than loading it
and can be safely removed!

--]]

--returns mapdata string of level
--printh(get_room(),"@clip")
function get_room(x,y)
  local reserve=""
  local offset=4096+(y<2 and 4096 or 0)
  y=y%2
  for y_=1,32,2 do
    for x_=1,32,2 do
      reserve=reserve..num2hex(peek(offset+x*16+y*2048+(y_-1)*64+x_/2))
    end
  end
  return reserve
end

--convert mapdata to memory data
function num2hex(number)
 local resultstr=""
 while number>0 do
  local remainder=1+number%16
  number=flr(number/16)
  resultstr=sub("0123456789abcdef",remainder,remainder)..resultstr
 end
 return #resultstr==0 and "00" or #resultstr==1 and "0"..resultstr or resultstr
end


-->8

-- evercore tas tool injection
function load_room(x,y)
	load_level(x+8*y)
	room=vector(x,y)
end

room=vector(0,0)
local __update=_update

_update=function() 
	__update()
	room=vector(lvl_id%8,flr(lvl_id/8))
end
function level_index()
	return lvl_id 
end

__gfx__
000000000000000000000000088888800000000000000000000000000000000000aaaaa0000aaa000000a0000007707770077700000060000000600000060000
000000000888888008888880888888880888888008888800000000000888888000a000a0000a0a000000a0000777777677777770000060000000600000060000
000000008888888888888888888ffff888888888888888800888888088f1ff1800a909a0000a0a000000a0007766666667767777000600000000600000060000
00000000888ffff8888ffff888f1ff18888ffff88ffff8808888888888fffff8009aaa900009a9000000a0007677766676666677000600000000600000060000
0000000088f1ff1888f1ff1808fffff088f1ff1881ff1f80888ffff888fffff80000a0000000a0000000a0000000000000000000000600000006000000006000
0000000008fffff008fffff00033330008fffff00fffff8088fffff8083333800099a0000009a0000000a0000000000000000000000600000006000000006000
00000000003333000033330007000070073333000033337008f1ff10003333000009a0000000a0000000a0000000000000000000000060000006000000006000
000000000070070000700070000000000000070000007000077333700070070000aaa0000009a0000000a0000000000000000000000060000006000000006000
555555550000000000000000000000000000000000000000008888004999999449999994499909940300b0b0666566650300b0b0000000000000000070000000
55555555000000000000000000000000000000001011110108888880911111199111411991140919003b330067656765003b3300007700000770070007000007
550000550000000000000000000000000aaaaaa0111b1b1108788880911111199111911949400419028888206770677002888820007770700777000000000000
55000055007000700499994000000000a998888a1111991108888880911111199494041900000044089888800700070078988887077777700770000000000000
55000055007000700050050000000000a988888a0117771008888880911111199114094994000000088889800700070078888987077777700000700000000000
55000055067706770005500000000000aaaaaaaa0117771008888880911111199111911991400499088988800000000008898880077777700000077000000000
55555555567656760050050000000000a980088a0117771000888800911111199114111991404119028888200000000002888820070777000007077007000070
55555555566656660005500004999940a988888a1199d99000000000499999944999999444004994002882000000000000288200000000007000000000000000
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
5777755777577775077777777777777777777770077777700000000000000000cccccccc00000000000000000000000000000000000000000000000000000000
7777777777777777700007770000777000007777700077770000000000000000c77ccccc00000000000000000000000000000000000000000000000000000000
7777cc7777cc777770cc777cccc777ccccc7770770c777070000000000000000c77cc7cc00000000000000000000000000000000000000000000000000000000
777cccccccccc77770c777cccc777ccccc777c0770777c070000000000000000cccccccc00000000000000000000000000060000000000000000000000000000
77cccccccccccc77707770000777000007770007777700070002eeeeeeee2000cccccccc00000000000000000000000000606000000000000000000000000000
57cc77ccccc7cc7577770000777000007770000777700007002eeeeeeeeee200cc7ccccc0000000000000000000000000d000600000000000000000000000000
577c77ccccccc7757000000000000000000c000770000c0700eee222e22eee00ccccc7cc000000000000000000000000d00000c0000000000000000000000000
777cccccccccc7777000000000000000000000077000000700eeeeeeeeeeee00cccccccc00000000000000000000000d000000c0000000000000000000000000
777cccccccccc7777000000000000000000000077000000700ee2e222222ee00000000000000000000000000000000c0000000c0006000000000000000000000
577cccccccccc7777000000c000000000000000770cc000700eeeeeeeeeeee0000000000000000000000000000000d000000000c060d00000000000000000000
57cc7cccc77ccc7570000000000cc0000000000770cc000700ee2e2222e2ee000000000000000000000000000000c00000000000d000d0000000000000000000
77ccccccc77ccc7770c00000000cc00000000c0770000c0700ee222e2e22ee00000000000000000000000000000c000000000000000000000000000000000000
777cccccccccc7777000000000000000000000077000000700ee22229922ee0055555555000006666600660000d0666006666660066666600000000000000000
7777cc7777cc777770000000000000000000000770c0000700eee22eee2eee0055555555000066666660660000d0666606666666066666660000000000000000
777777777777777770000000c0000000000000077000000700ee772ee7777e005555555500006600066066000c00066006600000066000000000000000000000
57777577775577757000000000000000000000077000c0070777777777777770555555550000dd000000dd0000000dd00dddd0000dddd00d0000000000000000
0000000000000000700000000000000000000007700000070077770050000000000000050000dd000dd0dd0000d00dd00dd000000dd00000d000000000000000
00aaaaaaaaaaaa00700000000000000000000007700c00070700007055000000000000550000ddddddd0ddddddd0ddd00dd000000dd000000c00000000000000
0a999999999999a0700000000000c000000000077000000770770007555000000000055500000ddddd00ddddddd0dddd0dd000000dd000000d00000000000000
a99aaaaaaaaaa99a7000000cc0000000000000077000cc077077bb07555500000000555500000000000000000000000000000000000000000000000000000000
a9aaaaaaaaaaaa9a7000000cc0000000000c00077000cc07700bbb075555555555555555000000000000c0000000000000666660066600766666006666660000
a99999999999999a70c00000000000000000000770c00007700bbb07555555555555555500000000000c00000000000006000006600066000000660000006000
a99999999999999a70000000000000000000000770000007070000705555555555555555000000000cc000000000000060000000600006000000060000000600
a99999999999999a0777777777777777777777700777777000777700555555555555555500000000c00000000000000060066666060066006660060066666000
aaaaaaaaaaaaaaaa07777777777777777777777007777770004bbb00004b000000400bbb0000000c0000000000000000d0000000dd00dd00d0d00d0000d00000
a49494a11a49494a70007770000077700000777770007777004bbbbb004bb000004bbbbb0000001000000000000000000dddddd0dd00dd00ddd00d00dddd0000
a494a4a11a4a494a70c777ccccc777ccccc7770770c7770704200bbb042bbbbb042bbb0000000c000000000000000000d0000000d000dd0000000d000000d000
a49444aaaa44494a70777ccccc777ccccc777c0770777c07040000000400bbb0040000000000100000000000000000000d00000dd0000d000000dd0000000d00
a49999aaaa99994a7777000007770000077700077777000704000000040000000400000000001000000000000000000000ddddd00dddd0dddddd00ddddddd000
a49444999944494a77700000777000007770000777700c0742000000420000004200000000000000000000000000000000000000000000000000000000000000
a494a444444a494a7000000000000000000000077000000740000000400000004000000000010000000000000000000000000000000000000000000000001000
a49499999999494a0777777777777777777777700777777040000000400000004000000000100000000000000000000000000000000000000000000000000100
5252522323232323330000824252845252525252525252620000132323235252525262425262b200b342845262425252232323331323232362b200b342528452
0000a28213232323232323331352525252525233425252526227373737470000525252525252233393000000001352520082828200000000a213232323528452
2323338382920000000000a24252232352525252525252620000000000a21352525262428462b261b342525262425252000000a28382920073b200b313235252
0000a3829200a28292000000001323525252621252522323235363000000000023232323523301829200000000a213520082839200000000000000a282132352
9200a28282829300000000001333839252528452525252620000d30000008242525262425262b200b313232333428452004100a39200000000000000a2824252
c20083820011a392000061000000a2132323331323338392000000000000002400a2838203829200000000000000824200a28211110000000000000082019213
00000000a20172000000000000a282005252525252525233110012329300a242525262425262930000a2828212525252225353533200e3000000610000831352
c3123292b37201000000000000000082a201920000a28200000000000000a3250000829273920000000000000000a242000082123293000000000000a28200a2
0000000000a273000000000011a39200525223232323331232111333830011425252621323338200000000a24252525262b1b1b1135353320000000000829213
22523300b3739200110000001100008200a20000000092000000000000008226e3a39200b100000000000000111111420000a242338282829300110000820000
11000000000000000011000072820000233382920000a313522232829200125252525232828292000000000013235252620000000000a2030000000000a20082
23339200000000a372b2000072b200a20000000000000000000000000000a2012232b20000000000000000b34353225200000073b1a28283828202b200a20000
7200001100000000b37211110392000083920000000082834252629200004252525252628392000000000061a2821323620000000080000300000000000000a2
a20100000000a38273b200a373b20000000000061600000000000000000000825262b2000000000000000000b1b11323000000b1000000a28292b10000000000
0393007200001100b3135363030000008200001111a382924252330000b313525284526282000000000000000083829262930000435363031111110000000000
00820000000082827686828292000000000000071700000000000000000000a22333b20011000000110000000000b11200000000000000000000000061000000
7383a3030000720000b1b1b17300610092100012638200111333b20000b3721352525262920000000000000000a282006282002100a201135353639300000000
0092000000a382828282839200000000004353222222223200d30000000000002232b200720000a372b200000000004200000011000000000000000000000000
b1a2820300000300000000000000000022225333a29200122263b20000b342225252526200000000000000000000820062839371110082b1b1b1b18200000000
000000a38283828282920000000000000000a213235252235353536300000000526211110376868373b2000000a3824200000072930000000000000000000000
0000827300a3039300000000000000a3523392000000114233b20000b3125252522323330000000000000000000092006282828272a39200006100a29300f300
00000082828292000000000000110000000000a2821333920000000000a393f3232353533382828292000000a283924293000003829200000000000011111100
9300a2720082738200000000110000823372000000a3123392000000b342525233839200610000000000000000000000339200a203820000000000a383122222
000000a29200000000000000a372b2000000000082839200000000000082436382920000a2920000000000000082114283000003830000000000111112223200
92000003a38272829300e300721100a22262e3a3828273a2829300f3b3425252a2820000000000000000000000000000320000000392001111111182a2425252
0000000000001100000011a38373b20000000000a282000000000000a382920083000000000000000000000000a212528210d3039200000000a3122252526211
000000038392038212226300423200005252223201920000821222222252845200820000000000000000d31000000000620010d3031111122222329200425252
0010d30000b3729300b37282829200000000000000920000000000436382930082001000d300000000a39300000042522222226211111100a283425252845222
f3001003920003a213330011426293005284526282000000a24252525252525200a293000000000000001263a393000052222222624322525252621111135284
0012320000b3738200b373920000000000d30010000000e30000a3828382243482931222329300000082123200f3425252528452321232111111132352525252
222222620000030012320012526282005252526292000000004252525252525200a301930000000000a303244401829352528452523242525252522222324252
1252620000a382829300000000000000222222222222222232122222223225358212525262820000a30142522232425252525252624252222222223242525252
5252525262010000132323232323525252528452525223232333b200b313525272b1b1b1b1b1b1b1b1b143639300000000000042232352525233425223235252
62110000000000a21323232323525252525252525252525252525223339300000000000000000000000000000000000000000000000000000000000000000000
5252525262920000b1b1b1b1b1b1135252522323233382828392000000b3132373930000000000000000a283820000000000f303828213526243233392a24284
523211110000000000a28382001323525252845252525252232333a282920000000000000000a200009200000000000000000000000000000000000000000000
5252525262006100000000000000b1132333019200a29200000000000000a2828392000000110000000000a28293e30000a3123383a282136200a28200001352
845222321111111100008292000000425252525252232333828292000000000000000000000000a3930000000000000000000000000000000000000000000000
528452526211111111110000000000b1a2828293000000110000000000000092920061000072b200001100a38212222200a203829200a282030000920000a213
5223232353535363b200a20000610042522323233383829200a200000011111100000000000000a2920000000000000000000000000000000000000000000000
525252526212222253639300000000000000a2821100a3720000000000000000110000001173b200b372b2122252528400007392000000007300000000000082
33b2a283920000000000000000000013339200a282920000000000111112222200000000009300000000a30000000000000000000094a4b4c4d4e4f400000000
525252526213233382839200000000a30000008272828373000011111111111172b200b372b20000b303b213232323230000b10000110000b1000000000000a2
b100009200001100000000000000001292000000920000000000111222525252000000a3a39200000000a29393000000000000000095a5b5c5d5e5f500000000
23235252522263829200000000000083000000a273921111111112225353222203b200b303b20000004222328382829200000000007293000000000000000000
0000000000b372b20000000000111142e30000000000000000001252525284520000a201820000670000008201920000000000000096a6b6c6d6e6f600000000
8382132352629200000011000000008200000000111112222232133392a2135203b200b303b20000a3132362a292000000006100a30383000000000011000000
0000006100b3031100000011111222522232111111000000000013232352525200000000a293a3123293a39200000000000000000097a7b7c7d7e7f700000000
9200a2011362000000b37200000000a2000000e312225252525232920000824273b200b373b20000a282010310d3000000000000a20392000000000072930000
0000000000b34232b200b31253232323525222223211110000000000821323230000000000a21252523292000000000000000000000000000000000000000000
000000828203b20000b303000021000000001222525252232323620010d3a24282000000019300000000a2422232000011111111110311111111111103820000
0000000000b34262b200b3739200a282528452525222321111000000a28382000000000000125252525232000000000000000000000000000000000000000000
10d300a28203b20000b303110071000000a34223232362b200b303934363004292006100a2829311000000425262000053535353321353535353222233829300
0000000000114262111100b10010d38252525223235252226393000000829200000000a312522323232352329300000000000000000000000000000000000000
436300008203b20000b34232000000a3008203b200b303b261b373838292001300000000a3828272b2000013233393000000a28203830000a282136282838200
00000000001252522232b2000043638252523312321323338292000000a200000000a31252622434344442523293000000000000000000000000000000000000
32b200008373b20000b3426200b00082a38303b261b373b20000a292000000a2111111a382829203b20000a28282820000100000039200d3a3828303a2828293
00000000001323235262b20000a282835262101333018292000000000000000000a2824252622535354542526282920000000000000000000000000000000000
62b20000a292000000b342621100a382a28273b20000829300000000000000002222638392111103b20000008283920043630000730000436382927300824363
930061000000a2831333b200000000a252627100a292000000000000210000000000125252622535354542525232000000000000000000000000000000000000
62b200000000000000b3425232a3838200a292000000a2820000000000a300005233721111122262b2000000a282000001920000b1000000000000b100a29200
830000000000008282920000000000005262000000000000000000007100000010a3132323332636364613232333930000000000000000000000000000000000
62b2000000a3829300b3425262828282000000000000a30193000000008293006212522222525262b20000000082000082000000000000000000000000000000
829300000000a3829200000000000000526200000000000000000000000000002222322737374700002737374712222200000000000000000000000000000000
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000700000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000f000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000770000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000770000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000007000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000f00000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000000000000
00000000000000000000000006000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000070000000000000000006000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000f00000000000060600000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000d000600000000000000660000000000000000000000000000000f0000000000000
0000000000000000000000000000000000000000000000000000000000000d00000c00f000000000066000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000d000000c000000000000000000000000000000000000000000000000060000000000
00000000000000000000000000000000000000000000000000000000000c0000000c000600000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000d000000000c060d0000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000c00000000000d000d000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000006666600666666006600c00066666600066666006666660066666600000000000000000000000000000000000000
0000000000000000000000000000000000006666666066666660660c000066666660666666606666666066666660000000000000000000000000000000000000
00000000000000000000000000000000000066000660660000006600000066000000660000000066000066000000000000000000000000000000000000000000
000000000000000000000000000000000000dd000000dddd0000dd000000dddd0000ddddddd000dd0000dddd0000000000000000000000000000000000000000
000000000000000000000000000000000000dd000dd0dd000000dd0000d0dd000000000000d000dd0000dd000000000000000000000000000000000000000000
000000000000000000000000000000000000ddddddd0dddddd00ddddddd0dddddd00ddddddd000dd0000dddddd00000000000000000000000000000000000000
0000000000000000000000000000000000000ddddd00ddddddd0ddddddd0ddddddd00ddddd0000dd0000ddddddd000000f000000000000000f00000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000c000000000000000000000000000000c00000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000c00000000000000000000000000000000c0000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000cc0000000000000000000000000000000000c000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000c000000000000000000000000000000000000c000000000000000000000000000000000000000000000
0000000000000000000000000000f0f0f0f0f0f0f0f0c0f00000000000000000000000000000000000c000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000100000000000000000000000000000000000000c00c000000000000000000000000000000000000000000
000000000000000000000000000000000000000000c0000000000000000000000000000000000000001010c0f000000000000000000000000000000000000000
000000000000000000000000000000000000000001000000000000000000000000000000000000000001000c00000000000000000000000000000000f0f0f0f0
00000000000000000000000000000000000000000100000000000000000000000000000000000000000000010000000600000000000000000000000000000000
000000000000000000000000000000000000000001000000000000000000000000000000000000000000000010000000000000f000f000f000f000f000f00000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000f0000000f00000000000f00000000000f0f0f000f00000000000f0000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000f0f00000000000000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000f000f0000000f000f000f000f000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000f000f000f000f0000000f000f0000000000000000000000000
00f000f000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005050000005500000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005050050050006000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000500555050000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005050050050000000000000600000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005050000005500000000000f00000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000
000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000f0000000000000000000000000f0000000000000000000000000000000000000000000f00000000000000000000
0000000000f000000000f000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000
0000000000000000f000f000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000f000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000700000000006600f0000000000000000000000000000f0000000000000000000f000f00
000000000000f000000000000000000f000000000000000000000000000000000000660000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000f00000000000000000000000f00000f0000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000f00000000000000000000000000000000000000000000000000000f000f00000000000000000000000000000000
f0000000000000000000000000000000000000000000000000007000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000055505550555055500000555050500550555005500550550000000000000000000000000000000000000000
0000000000000000000000000f000000000000000055505050f500050000000500505050505050500050505050000000000000f0000000000000000000000000
00000000000000000000000000000000000000000050505550050005000000050055505050550055505050505000000000000000000000000000000000000000
000000000f00000000000000000000000000f0000050505050050005000000050050505050505000505050505000000000000000000000000000000000000000
000000000000000000000000000000000000000000505050500500050000000500505055005050550055005050000000f0000000000000000000000000000000
f000000000000000000000000000000000000000f00000000000000000000f0000000000000000000000000000000000000000000000000000000f0000000000
0000000000000000000000000000000000000000000060550f0550555050f0000055505550555055505050000000000000000000000000000000000000000000
000f000f000000000000000000000000000000000000005050505f50005000000050505000505050505050000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000005050505055005000000055005500550055005550000000000000000000000000000000000000000000
000f0000000000000000000000000000000000000000005050505050005000000050505000505050500050000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000050505500555055500000555055505050505055500000000f0000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000f00000000000000000000000f0000000000000000000000000000000000000f0000000000000
000000000000000000000000000000f000000000f0000000000000f0f0f0f000f0f0f0f0f000000000000000000000000000000000000000000000000000000f
000000f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000f00000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000
00000000000600000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000f0000000000600000000000000000000000000000000000000000
0000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000000000000000000000f0000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000f00000000f000000000000000000000
0000000000000000000f00000f0000000f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0f0000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000f00000
0000000000f0000f0000000000000000000000000000000000000f00000000000f000000f0000000000000000000000000000000000000000000000000000000
0000000000000000000000000000f0000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000f000000000000000f0000000000000f0000000000000000000000000000000000000000000
000000000000000000000000000000f00000000000000000f0000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000f00000000000000f00000000000000000000000000000000000000000000000f0f00000000000
0000000000000000000000000000000000000000f000f00f0f00f000000000000000000000000000000000000000000000000000000000000000000000000000
00000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0000000000000000000000000000000004020000000000000000000200000000030303030303030304040402020000000303030303030303040404020202020200001313131302020302020202020202000013131313020204020202020202020000131313130004040202020202020200001313131300000002020202020202
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
003a24252548253232323232323232252525263900313232323232252631252525323232322525253329000000242548263125252548252628003a2900002a38000000002a2810290000000000000000252525253232323233313225253329003a24252525323232333132323232323200000028282828290000000000000000
002a31323232330000003435364000242525332800002a2900002a3132362425332910283b242533000000003a3125252523313225252526290028110000002838392c000000000000000000110000004825323328290000002a3824262800002a312548262838290000002a282839010000002a382900000000000000000000
00002a382900000000002a38283900312526282900000000000000002a28313229002a283b242628390000002a283132253338293132323300122a272b00002a28283c00000000000000003a202b000025263829000000000000283133290000002a2425262a280000000000002a282700000000290000000000000000000000
0000002a2839003d000000282a2834362526293d00002c0000000000000000003f0100383b242638282828393a290000332a28001b1b1b1b112011302b0000002934362b000000110000002a2839003a253328000000003d00002a2900000000003a31323300290000111111111111370000000000000000000000000011003a
0000003b2122222300000029000021223233212223003c00000000111100000022232b283b24262900002a28100000000000290000000000342222332b000000001b1b0000000020390000002a282838332729000021223639000011000000003a281b1b1b00000000343535353535353900000000000000000000003b270028
3900003b312525263900000000002425222225252634233436393b21232b003a25262b293b242600000011112800001400000000003f000000312600000000000000000011003a282900001100002a28222600003a24261029003b27390000002810000000000000001b1b1b1b1b1b2728000000000000000011111111303a38
2828393b27312533283f000000003132252525323236313638293b24262b121025262b003b242639003b212328393436003a393d003436393a29373e003a39000000003b202b2a38003a28202b000000253300002a24332800003b372838391129283911110000000000000000003a303839003d0000013a1021223621262828
3828283b37343536212300000000002125252638292a282829003b24262b172825262b003b313310393b242629003b27002a3423403b20281039002122362800000000001b00002a2828291b000000002610000000302829000000002a282827002a2821232b0000000011113a2810302828343535353535353233343233292a
29002a2829003b212526390000000024252526283f00000000003b24262b3a2825262b00001b1b28283b242600003b300000283011002a2828283a313327280039000000000000003a28283900000000262800003f3038000000000011002a3700003a24262b0000003b2123382828302a102900002a38282900000040000000
0000002a00003b313233380000000024323225222223000000003b31262b2a2925262b00003a2828293b242600003b3000002a31360000002a38282900372900382900000000113a283828100000000026290000212629000000003b2700002a00003824262b003a003b242629002a3700000000000000000000000000000000
0000000000000000002a290000000024002a24253233000000003b27372b000048262b000011112a003b242611111130390000002a390000002900000000000000000000003b2029002a2829000000002600003a242600000000003b3739001100002831262b0010393b31330000002100000011110000003f00000021230000
003d0100000000000000000000003a24010031332829000000003b24232b003a25262b003b21232b003b2425222223372801000000282900000000000000003a0000000000001b1100002a2829001200263a283824330000000000003a29002700002a27372b3a2829001b1b0000002400003b34362b00343639000031260000
0021222300003a28283900000000282417173a290000000000003b31262b002825262b003b24262b173b3132322525222223003e3a100000000000003a2828280000013d00003b202b000000003b202b262829003039001c000000002839003700120024232b382800000000000000243e00001b1b00002a102900002a373900
3931252600002a21232828393e002824003a2800000000001200003b302b002825262b003b24262b003a29000024252525252223282900000000003a38291111003a21230000001b0000000000000000262901003028390000003e3a2838282800200024262b2829001111110012002435363900000000002a391200003a2800
102931331111113126102a212222222568102800000000001739003b372b3a38252611111124262b3a1039083d3125254825252638000000003a28291111212200283126390000000000003a39000000252236212610282839212328292a282911111124262b28120021222300200024232a3800003a00003a28200000283839
290021222222222337290024254825252828290000003a383928390000002828252522232125262b283b21222222233125252526283900003a28103b212225253a727437380000003a282828383900002526212526002a2122252629003a100022222225262b2a200024252600000024263a28393a2839002a2829003a282828
2525323232323232323331252526282829002a38290000000000002a24482525323225482525253331323233382900003232334524482639000000002a313352252533290000001b1b31323232254825252532323232323233390024252525252525262b003b2425252525253324252525252525252525252526000031323232
2526282828290000002a2831322628380014003f1212003a2839000024252525400031323232332a2810292a2900003a00002a65242526291c000000002a2962253328000000000000002a2828313225252638290000002a28290024252548252532332b393b242548252526212525252525252525254825252600001b1b1b1b
253328382839111111002a2829302a2822223535353535222329003a313232250000002a282829002a28000000000028010000282425260000000000000000002628290012000000000000003a282824253328001111111111003f24253232322639003a383b3132323232333132322525254825252525252526000000000000
26282900002a2122233e0028003000283233282828282924260000283828292400000000382800000028000000003a282300003824252672737373740000000033380000170000111100000028382831332729003435353536213532332a2828262828282900002a382900002a28282425252525252525253233001600001600
262800000000313232222329003000282223382900010031263e3a2828290024000000002a280000002a000000002a38263f002a312525232122223639003a282a2800000000003436393e3a28282829222600002a28293b212628282900282926002a28000000002900160000002a2425252525252532332123111111003a28
2629000000002a38283126000030002a252600003435353631353535230000240000000000280000000000000000002a25230000282425332425262810282821002900000000002a10343523282900002526393e3a28003b31332900003a38002611111000001111111111111100002432323232323321222532353536102828
26111100000000002a2830000037000025263a2810290000002a282830003b24000000000029000000000000000b0011252639002a3133212548262828290024000000000011000000003b302800000025252222232900001b1b00003b27280025223628393f21362135353536003a241b1b1b1b1b1b3125331b1b1b1b2a2838
252223000011110000003000001b000025262900000000000000002a30393b240000000000000000000000000000002725262839000045242525262900000024000000003b272b0000003b30290000002548252526001600000000003b3029003233342235353300372a3828273928240000000000001b371b0000000000002a
25252600002123000000300000000000252611111100001111000011303839240000000000000000001111111111113732337529000065242525330000003f24000000003b302b0000003b30000000003232323233001111111100003b30000028290030282829001b00282930282931001600001600001b0000160000000000
2532331212242600003a3000001100004825222223390021232b002126292a2400000000000000000021353535353535237274000000003132332900003a2132000000003b302b3d01003b370000000028282900003b343535362b003b300000100001372900000000002a003038002139000011110000000000111111000000
332122222225263a28283000002739002532323226383924262b0031262b0024003e0000000000003a30282900002a282522233a3900002a2829000000283742000000000031353535353536000000003828000000001b1b1b1b00003b3000002800343639000000110000003729002438390021231100160011212223000000
2225252525482638292a3039003029003329002a37292824262b002a30000024003436390000000010302800000000002525252328000000000000003a2875620000000000002a2838282900000000002829000000000000000000003b37390029002a282900003a270000001b00002429283a24252311111121252526391200
252525253232262800003028003700112300080000002a24262b000037393b24002a28280000003a28372900013d00003232252638000000464700002821222200001600000000002a28000000000000280000000000000000003d00003a2800000000280000002a3000160000160024002a2824252522222324252526281700
25482526002a3729000030103a271121261112111111112425232b002a28002400002838393f3a28291b0000343639007274242628393d005657003a38243225000000001111110000281111110012002901000000001111112123393a382800171700283912000030390000111111243d012831322525252631254826290000
2525252601000000003d302838302125252222223621222548262b003d28392400002a2834362900000000002a1029002222252522223535353535352226752400001111212223391610212223391700222339001200212236242628282829000000002a382711113710393a2122222522222222232425252523242526111111
252525252222222321222628283024252525252621252525252523212222222500003a2829000000000000003a28000025254825252672737373737424267524003a2122252526383a282425262829002526283a270024262125262829000000000000002824222223292a282425252525252525262425252526242525222222
__sfx__
0102000036370234702f3701d4702a37017470273701347023370114701e3700e4701a3600c46016350084401233005420196001960019600196003f6003f6003f6003f6003f6003f6003f6003f6003f6003f600
0002000011070130701a0702407000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300000d07010070160702207000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200000642008420094200b420224402a4503c6503b6503b6503965036650326502d6502865024640216401d6401a64016630116300e6300b62007620056100361010600106000060000600006000060000600
000400000f0701e070120702207017070260701b0602c060210503105027040360402b0303a030300203e02035010000000000000000000000000000000000000000000000000000000000000000000000000000
000300000977009770097600975008740077300672005715357003470034700347003470034700347003570035700357003570035700347003470034700337003370033700337000070000700007000070000700
00030000241700e1702d1701617034170201603b160281503f1402f120281101d1101011003110001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00020000101101211014110161101a120201202613032140321403410000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00030000070700a0700e0701007016070220702f0702f0602c0602c0502f0502f0402c0402c0302f0202f0102c000000000000000000000000000000000000000000000000000000000000000000000000000000
0003000005110071303f6403f6403f6303f6203f6103f6153f6003f6003f600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
011000200d073006050177301705236550177301605006050d07300605017050d043236550060501773006050d073017050177300605236550177301605006050d07300605256050160523655256050177323655
012000001d0401d0401d0351d0251804018045180350c0201b0351b02522040220461f0351303116040160401d0401d04329535130651803018033245271f065240552202516045130251d0401b022180400c040
01100000070750706513055000550707007060030510f0700a0750a0650a050160000a0700a0600505505046030750306003000030550c0750c0651105011035160600f071050500a07005055070550a0700c060
000400000c5501c5601057023570195702c5702157037570285703b5702c5703e560315503e540315303e530315203f520315203f520315103f510315103f510315103f510315103f50000500005000050000500
000400002f7402b760267701d7701577015770197701c750177300170015700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
00030000096450e655066550a6550d6550565511655076550c655046550965511645086350d615006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
011000001f37518375273752730027300243001d300263002a3001c30019300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
011000002953429554295741d540225702256018570185701856018500185701856000500165701657216562275142753427554275741f5701f5601f500135201b551355353056524545295471d5002257022563
011000200a0750a0550f0710f0500a0650a040110701105007000070001107505055070600704000000000000a0700a0500f075030500a0600a0401307113050000000000013075070550f0700f0500000000000
012000002204022030220251b0112404024030270551f0252b040220202705022020290451d036290251601022040220352b0451b035240422403227045180351d0401d0301f0521f04222035220252404624036
010800200d073017753f6253b6003c6003b6003f6253160023650236553c600000003f625000000d053017000d073017753f6003f6003f625000003f62500000236502365500000000003f625000000000000000
012000200a1450a1350a1251113511125111151b1451b13718152181451813513145131451313507125131150f1450f1350f12511135111251111516142161371315513145071001312513116071001311607100
011000202e750377502e730377302e720377202e71037710227502b750227302b7301d750247501d730247301f750277501f730277301f7202772029750307502973030730297203072029710307102971030710
000600001877035770357703576035750357403573035720357103570000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
011800202945529425294403571029435377152942537715224503571022440274503c715274453c746274252e450357102e440357102e435377152e425377152e410244402b45035710294553c715294453c715
0118002005575115750f57505575115750000005575075750a570075700a5760a0000a575000000a57503575055750f5701157505525055751157511500000000a570075700c575005700f570000000a57507575
010c00200c0532e6003b625000003b61500000000003360033640336303362033610336103f6000c053000000c0532e6003b625000003b61500000000003360033640336303362033610336103f6003f61500000
010c002024450307102b4503071024440307002b44037700244203c7103a42037710354103371530415377151d45033710244503a7101d4403771024440337001d42035700244202e7101d4102e7102441037700
011800200c575165651855000575115751b5651d5501d5130c5750c5600f5760f56013570135600a5700a5600c5700c5600c553005550f5700f5600f553075550a5700a5600a5500f50011575115620a5750a565
011800200c575165651855000575115751b5651d5501d5130c5750c5600f5760f56013570135600a5700a5600c570005700c560005600c550005300c555005350c5000a5000a5000a50011500115000a5000a500
010c0020247712477024762247523a0103a010187523a0103501035010187523501018750370003700037000227722277222763227001f7721f7751f700247002277522772227630070027772277722776200700
010c0020247712477024762247523a0103a010187503a01035010350101875035010187501870018700007001f7701f7701f7621f7531870000700187551b7002277122775227622275237012370123701237002
010c0000247712477024772247722476224752247422473224722247120070000700007000070000700007002e0002e0002e0102e010350103501033011330102b0102b0102b0102b00030010300123001230012
010c00200c3320c3350c3220c3250c3000c3000c3150c3020c3320c3320a3220a32207312073120a3120a31507332073321332513322073120731213312073020a3350a33216322163220a4220a422163120a302
010c00000c3320c3350c3220c3250c3000c3000c3150c3020c3320c3320a3220a32207312073120a3120a3150a3300a3201333013320073300732013311113000a3350a3250a3153c0000f3320f3250f3123a000
00040000336251a605000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005
010c00000c3300c3300c3300c3200c3200c3200c3100c3100c3100c31000000000000000000000000000000000000000000000000000000000000000000000000a3000a3000a3000a3000a3500a3350a3450a355
001000000c3500c3400c3300c3200f3500f3400f3300f320183501834013350133401835013350163401d36022370223702236022350223402232013300133001830018300133001330016300163001d3001d300
000c0000242752b27530275242652b26530265242552b25530255242452b24530245242352b23530235242252b22530225242152b21530215242052b20530205242052b205302053a2052e205002050020500205
011000100d0732f6152f6250d0332f645276152f6350d0330d0733f6150d033276152f655336150d0333f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
0010000016270162701f2711f2701f2701f270182711827013271132701d2711d270162711627016270162701b2711b2701b2701b270000001b200000001b2000000000000000000000000000000000000000000
01080020245753057524545305451b565275651f5752b5751f5452b5451f5352b5351f5252b5251f5152b5151b575275751b545275451b535275351d575295751d545295451d535295351f5752b5751f5452b545
012000200c2650c2650c25516255182450c2450c2350a2310f2650f2650f255182551b2450f2450f235162311326513265132551b2551d2451f24513235072351322507240162701326113250132420f2650f255
01100000072750f26511255132450f2650f2550c2750c26500255002450c2350c2250c2350c2251125513245072750f26511255132450c2650c25511275112651125511245132651325516275162651625518245
010800201f5702b5701f5402b54018550245501b570275701b540275401857024570185402454018530245301b570275701b540275401d530295301d520295201f5702b5701f5402b5401f5302b5301b55027550
01100020112751126511255112451326513255182751826518255182451d2651d2550f2651824513275162550f2750f2650f2550f2451126511255162751626516255162451b2651b255222751f2451826513235
011000100d0732f6250d033276152f6553f6150d033336150d0733f6152f6250d0532f655336150d0333f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
011000100d073010430d0132f6152f645276152f6350d0330d073336150d033276152f655336150d0333f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
012000002904029040290352b031290242b021290142b01133044300412e0442e03030044300302b0412b0302e0442e0402e035300312e024300212e024300212b0442e0412b0342e0212b0442b0402903129022
000800202451524515245252452524535245352454524545245552455524565245652457500505245750050524565005052456500505245550050524555005052454500505245350050524525005052451500505
000800201f5151f5151f5251f5251f5351f5351f5451f5451f5551f5551f5651f5651f575000051f575000051f565000051f565000051f555000051f555000051f545000051f535000051f525000051f51500005
000500000373005731077410c741137511b7612437030371275702e5712437030371275702e5712436030361275602e5612435030351275502e5512434030341275402e5412433030331275202e5212431030311
012000200c2750c2650c25516245182350a2650a255162450f2750f2650f255182451b2350c265002550c2450c2750c2650c25516245182350a2650a255162450f2750f2650f255182450f235112650525511245
002000001327513265132551324513235112651125511245162751626516255162451623513265132551324513275132651325513245132350f2650f2550f2450c25011231162650f24516272162520c2700c255
000300001f3302b33022530295301f3202b32022520295201f3102b31022510295101f3002b300225002950000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b00002935500300293453037030360303551330524300243050030013305243002430500300003002430024305003000030000300003000030000300003000030000300003000030000300003000030000300
011000003c5753c5453c5353c5253c5003c50037555375453a5753a5553a5453a5353a5002e5003a0262e50035575355553554535545355003550035525355253553535535335753355533026270003301627000
01100000355753555535545355353502629000110151102537555375353357533555375263751533535335153a5753a5453a5353a5253a5003a50033575335553354533545335353353533026270003301627000
011000200c0650c0000c055000500c0000c0000c0550c0500c0550c0000c0000c000000500c05518050000551106511000110550505005000110000a0650a0300a0550a0000a000070500a050160100c05018050
01100000050650500005055050502900035000050550705007055130350701500000030600f0351b010030650c0650c0000c055000300c0000c0000c0550c0300c0000c0000c055000300c000000000c03518015
011000000c053246150060503615246451b61522625036150c05303615116253361522645006050c0330a6150c053186152e6251d615246453761537625186150c0531d61511625036152264503615246251d615
01100020326103261032610326103161031610306102e6102a610256101b610136100f6100d6100c6100c6100c6100c6100c6100f610146101d610246102a6102e61030610316103361033610346103461034610
01400000302453020530235332252b23530205302253020530205302253020530205302153020530205302152b2452b2052b23527225292352b2052b2252b2052b2052b2252b2052b2052b2152b2052b2052b215
0110002000710007100071000710007100071030710007100072000720007200c7200072000720007200072000720007200072000720007202472000720007200071000710007101871000710007100071000710
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
01 3d7e3f44
00 3d7e3f44
00 3d4a3f44
02 3d3e3f44
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
01 383a3c44
02 393b3c44

