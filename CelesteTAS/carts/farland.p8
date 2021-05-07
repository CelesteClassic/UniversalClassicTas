pico-8 cartridge // http://www.pico-8.com
version 30
__lua__
--~farland~
--by kamera

--original game by:
--matt thorson + noel berry

--using evercore base cart

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
  frames,start_game_flash=0,0
  music(40,0,7)
  load_level(0)
end

function begin_game()
  max_djump,deaths,frames,seconds,minutes,music_timer,time_ticking=1,0,0,0,0,0,true
  music(30,0,7)
  load_level(1)
end

function is_title()
  return lvl_id==0
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
      this.init_smoke(0,4)
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
      this.init_smoke()
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
      
      
      -- faster fall
      if not on_ground and btn(⬇️) then
        maxfall=2.6
      end

      -- wall slide
      if h_input~=0 and this.is_solid(h_input,0) and not this.is_ice(h_input,0) then
        maxfall=0.4
        -- wall slide smoke
        if rnd(10)<2 then
          this.init_smoke(h_input*6)
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
          psfx(44)
          this.jbuffer=0
          this.grace=0
          this.spd.y=-2
          this.init_smoke(0,4)
        else
          -- wall jump
          local wall_dir=(this.is_solid(-3,0) and -1 or this.is_solid(3,0) and 1 or 0)
          if wall_dir~=0 then
            psfx(2)
            has_dashed=true
            this.jbuffer=0
            this.spd.y=-2
            this.spd.x=-wall_dir*(maxrun+1)
            if not this.is_ice(wall_dir*3,0) then
              -- wall jump smoke
              this.init_smoke(wall_dir*6)
            end
          end
        end
      end
    
      -- dash
      local d_full=5
      local d_half=3.5355339059 -- 5 * sqrt(2)
    
      if this.djump>0 and dash then
        this.init_smoke()
        this.djump-=1   
        this.dash_time=4
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
        this.init_smoke()
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
    if this.y<-2 and lvl_id<33 or not lvl_id==28 then
      next_level()
    elseif lvl_id==24 and this.x<-1.8 then
      secret_level()
    elseif this.y<4.5 and lvl_id==28 then
      skip_level()
    elseif this.y<4 and lvl_id==32 then
      pure_summit()
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
  pal(8,djump==1 and 8 or djump==2 and 14 or 11)
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
		cam_x=clamp(this.x,64,lvl_pw-64)
		cam_y=clamp(this.y,64,lvl_ph-64)
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
          this.init_smoke(0,4)
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
      local hit=this.player_here()
      if hit and hit.spd.y>=0 then
        this.spr=19
        hit.y=this.y-4
        hit.spd.x*=0.2
        hit.spd.y=-3
        if hit.djump==2 or max_djump==2 then
         hit.djump=2
        elseif max_djump==0 then
         hit.djump=0
        elseif hit.djump==1 or 0 then
         hit.djump=1
        end
        this.delay=10
        this.init_smoke()
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

balloon={
  init=function(this) 
    this.offset=rnd(1)
    this.start=this.y
    this.timer=0
    this.hitbox=rectangle(-1,-1,10,10)
	this.base_spr=this.spr
  end,
  update=function(this) 
    if this.spr==this.base_spr then
      this.offset+=0.01
      this.y=this.start+sin(this.offset)*2
      local hit=this.player_here()
      if hit and (this.spr==22 and hit.djump<max_djump or this.spr==21 and hit.djump<2) then
        psfx(6)
        this.init_smoke()
        hit.djump=this.spr==22 and max_djump or 2
        this.spr=0
        this.timer=60
      end
    elseif this.timer>0 then
      this.timer-=1
    else 
      psfx(7)
      this.init_smoke()
      this.spr=this.base_spr 
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
      if this.delay<=0 and not this.player_here() then
        psfx(7)
        this.state=0
        this.collideable=true
        this.init_smoke()
      end
    end
  end,
  draw=function(this)
    if this.state~=2 then
      if this.state~=1 then
        spr(23,this.x,this.y)
      else
        spr(26-this.delay/5,this.x,this.y)
      end
    end
  end
}

function break_fall_floor(obj)
 if obj.state==0 then
  psfx(15)
    obj.state=1
    obj.delay=15--how long until it falls
    obj.init_smoke()
    local hit=obj.check(spring,0,-1)
    if hit then
      hit.hide_in=15
    end
  end
end

smoke={
  init=function(this)
    this.spd=vector(0.3+rnd(0.2),-0.1)
    this.x+=-1+rnd(2)
    this.y+=-1+rnd(2)
    this.flip=vector(maybe(),maybe())
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
    check_fruit(this)
    this.off+=0.025
    this.y=this.start+sin(this.off)*2.5
  end
}

fly_fruit={
  if_not_fruit=true,
  init=function(this) 
    this.start=this.y
    this.step=0.5
    this.sfx_delay=8
  end,
  update=function(this)
    --fly away
    if has_dashed then
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
      this.step+=0.05
      this.spd.y=sin(this.step)*0.5
    end
    -- collect
    check_fruit(this)
  end,
  draw=function(this)
    draw_obj_sprite(this)
    for ox=-6,6,12 do
      spr((has_dashed or sin(this.step)>=0) and 45 or (this.y>this.start and 47 or 46),this.x+ox,this.y-2,1,1,ox==-6)
    end
  end
}

function check_fruit(this)
  local hit=this.player_here()
  if hit then
    hit.djump=max_djump
    sfx_timer=20
    sfx(13)
    got_fruit[lvl_id]=true
    init_object(lifeup,this.x,this.y)
    destroy_object(this)
  end
end


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

function init_fruit(this,ox,oy)
  sfx_timer=20
  sfx(16)
  init_object(fruit,this.x+ox,this.y+oy,26)
  destroy_object(this)
end

key={
  if_not_fruit=true,
  update=function(this)
    local was=flr(this.spr)
    this.spr=9.5+sin(frames/30)
    if this.spr==10 and this.spr~=was then
      this.flip.x=not this.flip.x
    end
    if this.player_here() then
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
        init_fruit(this,0,-4)
      end
    end
  end
}

jumpthrough={
  init=function(this)
    this.x-=0
    this.hitbox.w=8
    this.last=this.x
  end
}


message={
  draw=function(this)
   if lvl_id==1 then
    this.text="-- farland mountain --#a warning to all who  #seek to climb farland #mountain continue at  #your own risk,consider#returning to your home"
    if this.check(player,4,0) then
      if this.index<#this.text then
       this.index+=0.5
        if this.index>=this.last+1 then
          this.last+=1
          sfx(35)
        end
      end
      local _x,_y=8,12
      for i=1,this.index do
        if sub(this.text,i,i)~="#" then
          rectfill(_x-2,_y-2,_x+7,_y+6 ,7)
          ?sub(this.text,i,i),_x,_y,0
          _x+=5
        else
          _x=8
          _y+=7
        end
      end
    else
      this.index=0
      this.last=0
    end
   end 
  end
}

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
        this.init_smoke()
        this.init_smoke(8)
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
        if lvl_id>21 then
         new_bg=true
        end
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
    local hit=this.player_here()
    if this.spd.y==0 and hit then 
      sfx(51)
      destroy_object(this)
      if lvl_id==17 then
       music(35,500,7)
       freeze=5
       next_level()
       max_djump=0
       hit.djump=0
      elseif lvl_id==21 then
       freeze=10
       max_djump=2
       hit.djump=2
      end
    end
    spr(102,this.x,this.y)
    for i=0,0.875,0.125 do
      circfill(this.x+4+cos(frames/30+i)*8,this.y+4+sin(frames/30+i)*8,1,7)
    end
  end
}


flag={
  init=function(this)
    this.x+=5
    this.score=0
    for _ in pairs(got_fruit) do
     this.score+=1
    end
  end, 
  draw=function(this)
    this.spr=118+frames/5%3
    draw_obj_sprite(this)
    if this.show then
      rectfill(32,2,96,31,0)
      rectfill(27,95,104,110,0)
      spr(26,50,6)
      ?"x"..this.score.."/8",59,9,7 
      draw_time(49,16)
      ?"deaths:"..deaths,49,24,7
      ?"thanks for playing",30,98,7
      if this.score==8 then
       ?"100%",58,105,7
      elseif this.score<8 then
       ?"any%",58,105,7
      elseif this.score==9 then
       ?"true 100%",48,105,7
      end
    elseif this.player_here() then
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
  [11]=jumpthrough,
  [12]=jumpthrough,
  [13]=jumpthrough,
  [18]=spring,
  [20]=chest,
  [21]=balloon,
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
  if type.if_not_fruit and got_fruit[lvl_id] then
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
    return (oy>0 and not obj.check(jumpthrough,ox,0) and obj.check(jumpthrough,ox,oy)) or
           obj.is_flag(ox,oy,0) or 
           obj.check(fall_floor,ox,oy) or
           obj.check(fake_wall,ox,oy)
  end
  
  function obj.is_ice(ox,oy)
    return obj.is_flag(ox,oy,4)
  end
  
  function obj.is_flag(ox,oy,flag)
    return tile_flag_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h,flag)
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
  
  function obj.move(ox,oy,start)
    for axis in all({"x","y"}) do
      obj.rem[axis]+=axis=="x" and ox or oy
      local amt=flr(obj.rem[axis]+0.5)
      obj.rem[axis]-=amt
      if obj.solids then
        local step=sign(amt)
        local d=axis=="x" and step or 0
        for i=start,abs(amt) do
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
  end

  function obj.init_smoke(ox,oy) 
    init_object(smoke,obj.x+(ox or 0),obj.y+(oy or 0),29)
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
  for dir=0,0.875,0.125 do
    add(dead_particles,{
      x=obj.x+4,
      y=obj.y+4,
      t=2,
      dx=sin(dir)*3,
      dy=cos(dir)*3
    })
  end
  delay_restart=15
end

-- [room functions]


function next_level()
  local next_lvl=lvl_id+1
  if next_lvl==21 then --wind music
    music(30,500,7)
  elseif next_lvl==2 then
    music(0,500,7)
  elseif next_lvl==10 then --wind music
    music(30,500,7)
  elseif next_lvl==11 then
    music(20,500,7)
  elseif next_lvl==17 then --wind music
    music(30,500,7)
  elseif next_lvl==22 then 
    music(10,500,7)
  elseif next_lvl==29 then
    music(30,500,7)
  elseif next_lvl==30 then
    music(43,500,7)
  elseif next_lvl==33 then
    music(31,500,7)
  elseif next_lvl==34 then
    music(31,500,7)
  end
  load_level(next_lvl)
end

function secret_level()
  local secret_lvl=29
    music(30,500,7)
  load_level(secret_lvl)
end

function skip_level()
  local skip_lvl=33
   music(31,500,7)
  load_level(skip_lvl)
end

function pure_summit()
 local pure_lvl=34
  music(31,500,7)
 load_level(pure_lvl)
end

function load_level(lvl)
  has_dashed=false
  has_key=false
  
  --remove existing objects
  foreach(objects,destroy_object)
  
  --reset camera speed
  cam_spdx=0
		cam_spdy=0
		
  local diff_room=lvl_id~=lvl
  
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
   if diff_room then reload() end 
  	ui_timer=5
  end
  
  --chcek for hex mapdata
  if diff_room and get_data() then
  	--replace old rooms with data
  	for i=0,get_lvl()[3]-1 do
      for j=0,get_lvl()[4]-1 do
        replace_room(lvl_x+i,lvl_y+j,get_data()[i*get_lvl()[4]+j+1])
      end
  	end
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
  frames+=1
  if time_ticking then
    seconds+=frames\30
    minutes+=seconds\60
    seconds%=60
  end
  frames%=30
  
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
  		cam_spdx,cam_spdy=0,0
    delay_restart-=1
    if delay_restart==0 then
      load_level(lvl_id)
    end
  end

  -- update each object
  foreach(objects,function(obj)
    obj.move(obj.spd.x,obj.spd.y,0)
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
      start_game_flash,start_game=50,true
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
  camera(camx,camy)

  --local token saving
  local xtiles=lvl_x*16
  local ytiles=lvl_y*16
  
  -- draw bg color
  if lvl_id>9 and  lvl_id<18 then
   cls(flash_bg and frames/5 or new_bg and 7 or 9)
  elseif lvl_id<10 then
   cls(flash_bg and frames/5 or new_bg and 7 or 0)
  elseif lvl_id>17 and lvl_id<22  then
   cls(flash_bg and frames/5 or new_bg and 7 or 0) 
  elseif lvl_id>21 and lvl_id<30 or lvl_id>33 then
   cls(flash_bg and frames/5 or new_bg and 10 or 10)
  elseif lvl_id>29 and lvl_id<33 then    
   cls(flash_bg and frames/5 or new_bg and 13 or 13)
  elseif lvl_id==33 then
   cls(flash_bg and frames/5 or new_bg and 10 or 10)
  elseif lvl_id==34 then
   cls(flash_bg and frames/5 or new_bg and 10 or 10) 
  end

  -- bg clouds effect
  if not is_title() then
    foreach(clouds, function(c)
      c.x+=c.spd-cam_spdx
      if lvl_id>9 and lvl_id<18 then
       rectfill(c.x+camx,c.y+camy,c.x+c.w+camx,c.y+16-c.w*0.1875+camy,new_bg and 11 or 7)
      elseif lvl_id<10 then
       rectfill(c.x+camx,c.y+camy,c.x+c.w+camx,c.y+16-c.w*0.1875+camy,new_bg and 11 or 13)
      elseif lvl_id>17 and lvl_id<22 then
       rectfill(c.x+camx,c.y+camy,c.x+c.w+camx,c.y+16-c.w*0.1875+camy,new_bg and 11 or 13)  
      elseif lvl_id>21 and lvl_id<30 then
       rectfill(c.x+camx,c.y+camy,c.x+c.w+camx,c.y+16-c.w*0.1875+camy,new_bg and 11 or 11) 
      elseif lvl_id>29 and lvl_id<33 then   
       rectfill(c.x+camx,c.y+camy,c.x+c.w+camx,c.y+16-c.w*0.1875+camy,new_bg and 7 or 7) 
      elseif lvl_id==33 then
       rectfill(c.x+camx,c.y+camy,c.x+c.w+camx,c.y+16-c.w*0.1875+camy,new_bg and 11 or 11)  
      elseif lvl_id==34 then
       rectfill(c.x+camx,c.y+camy,c.x+c.w+camx,c.y+16-c.w*0.1875+camy,new_bg and 7 or 7)        
      end
      if c.x>128 then
        c.x=-c.w
        c.y=rnd(120)
      end
    end)
  end
  --draw terrian
  map(xtiles,ytiles,0,0,lvl_w,lvl_h,2)
    if lvl_id>9 and lvl_id<17 then
      pal(1,2,1)
      pal(12,7,1)
    elseif lvl_id>16 and lvl_id<22 then
      pal(1,6,1)
      pal(12,7,1)
    elseif lvl_id>21 then
      pal(1,142,1)
      pal(12,7,1)
    end
    
  --draw flag and moonberry color
  if lvl_id>32 then
   pal(5,11,1)
  end 

		-- draw bg terrain
  map(xtiles,ytiles,0,0,lvl_w,lvl_h,4)
		
		-- draw orb color
		if lvl_id==17 then
		 pal(14,12,1)
		elseif lvl_id==21 then
		 pal(14,14,1)
		end
		
		-- platforms
  foreach(objects, function(o)
    if o.type==jumpthrough then
      draw_object(o)
    end
  end)
		
  -- draw objects
  foreach(objects, function(o)
    if o.type~=jumpthrough then
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
    p.t-=0.2
    if p.t<=0 then
      del(dead_particles,p)
    end
    rectfill(p.x-p.t,p.y-p.t,p.x+p.t,p.y+p.t,14+5*p.t%2)
  end)
  
  -- draw level title
  if ui_timer>=-30 then
  	if ui_timer<0 then
  		draw_ui(camx,camy)
  	end
  	ui_timer-=1
  end
  
  -- change dash
  if lvl_id>29 and lvl_id<33 or lvl_id==34 then
   max_djump=1
  end
  
  
  -- credits
  if is_title() then
				sspr(72,32,56,32,36,32)
				?"by kamera",47,94,5
    ?"🅾️/❎",55,80,5
    ?"original game by",34,104,5
    ?"matt thorson",42,112,5
    ?"noel berry",46,118,5
  end
  pal(10,1,1)
  pal(11,12,1)
  if lvl_id==17 or lvl_id==18 then
   pal(4,11,1)
   pal(2,3,1)
  elseif lvl_id==21 then
   pal(2,2,1) 
   pal(4,14,1)
  end
  pal()
end

 
function draw_object(obj)
  (obj.type.draw or draw_obj_sprite)(obj)
end

function draw_obj_sprite(obj)
  spr(obj.spr,obj.x,obj.y,1,1,obj.flip.x,obj.flip.y)
end

function draw_time(x,y)
  rectfill(x,y,x+32,y+6,0)
  ?two_digit_str(minutes\60)..":"..two_digit_str(minutes%60)..":"..two_digit_str(seconds),x+1,y+1,7
end

function draw_ui(camx,camy)
 rectfill(24+camx,58+camy,104+camx,70+camy,0)
 if lvl_title then
  ?lvl_title,64-#lvl_title*2+camx,62,7
 else
 	local level=((lvl_id)*100)-100
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

function appr(val,target,amount)
  return val>target and max(val-amount,target) or min(val+amount,target)
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
	[0]="-1,-1,1,1", --title screen
	"0,0,3,1,base",
	"3,0,1,1",
	"4,0,1,1",
	"5,0,2,1",
	"7,0,1,1",
	"0,1,1,1",
	"1,1,1,2",
	"2,1,1,1",
	"3,1,1,1",
	"4,1,2,1,golden peak",
	"6,1,1,1",
	"7,1,1,1",
	"2,2,2,1",
	"0,2,1,1",
	"4,2,1,1",
	"5,2,1,1",
	"6,2,1,1",
	"7,2,1,1,escapism",
	"0,3,1,1,reverie",
	"1,3,2,1,perseverance",
	"3,3,1,1,exemption",
	"4,3,1,1,final ascent",
	"5,3,1,1",
	"6,3,1,1",
	"6,3,1,1", 
	"6,3,1,1",
	"6,3,1,1",
	"6,3,1,1",
	"6,3,1,1,???",
	"6,3,1,1,???",
	"6,3,1,1,???",
	"6,3,1,1,???",
	"7,3,1,1,summit",
	"6,3,1,1,pure summit",                         
}

--mapdata table
--rooms separated by commas
mapdata={
	[24]="25323225252525323225252526000000260000242525260100242525330000002600003125252617172425330000000026000000312526000024260000001200260000000031330000242600000017002600000000000000002426000000000026000000001111000024260000000000260000000021230000242600000000002600000000242600002426000000000026000000002426111124260000000000260000000024252222252600000000003300000000313232323233000000000000000000001b1b1b1b1b1b00000000000000000000000000000000000000000000000000001111111111110000000000000000003b2122222222231717000000",
	[25]="323232322525252525252600000000000000000031322525252526000000000000000000110031323232330000000000000000002700000000000000000000001100001630000000000000000000000027000000300000000000000000000000300000003000000000000000000000003000000030000000000000000000000030000000300000110000001111000000300000003700002700000021232b0000300000001b00003000000024262b0000300000000000003000000024262b0000300000001100003000000024262b0000300000002700003000000024262b0000300000003000003000000024262b0100300000003000003000000024262b2000",
 [26]="32323232323232323232322525260000000000000000000000003b2425260000000000000000000000003b2425260000000000000000000000003b2425260000000000000000111100003b2425260000000000000000212300003b2425330000000000000011242600003b2426000000000000000021252600003b2426000000000000000031252600003b242600000000000000003b242600003b242600000000000000003b242600003b313300000000000000003b24260000001b1b00000000010000123b2426000000000000000022230000173b2426000000000000000025260000003b2426000000111111111125260000003b242600003b2122222222",
 [27]="323232323232323232330000242525250000000000000000000000002425252500000000000011000000000024252525000000000000270000000000242525250000000000003000000000002425252500001111111130111111111124252525000021222222252222222222252525250000313232252525252525253232323200001b1b1b312525252525331b1b1b1b000000000000312525253300000001001200000000000031323300000021222217001111110000000000000011242525003b2122231100000000001121252525003b2425252311000000112125252525003b2425252523111111212525252525003b2425252525222222252525252525",
 [28]="323232322525330000312525252525251b1b1b1b2426000000002425252525250100000024260000000024252525252523000000242600000000242525252525260000002425232b3b21252525252525261111002425332b3b313232323232322522230024260000000000000000000025323300242617171717212222222300260000002426000000003132322526002600000024262b0000000000002426002600111124262b0000000000003133002600212225262b003b212317171b1b002600313232332b003b2426000000000026001b1b1b1b00003b2426111111111126001600000000003b2425222222222226000000000000003b24252525252525",
 [29]="252525262b000000003b242525252525252525332b000000003b2425252525252525332b00000000003b24252525252525262b0000000000003424252525252525332b0000000000003b312525252525262b00000000000000003b3125252525332b0000000000000000003b2425252500000000000000000000003b312525250000000000000000000000003b2425250000000000000000000000003b2425250000000000000000000000003b312525222300000000000000000000003b312525252300000000000000000000003b31252525230000212223000001000000002525252522222525252222222300000025252525252525252525252526000000",
 [30]="4500000000003b5253636363636363636500000000003b52542b1b1b1b1b1b3b1b00000000003b52542b15000000003b0000000000003b52542b00001100003b0000000000003b62642b003b452b003b000000000000001b1b00003b552b153b000000000000001111111111652b003b0000000000003b42434343442b00003b0000000000003b52535353542b00003b0000000000003b62636363642b00013b000000000000001500000000424343430000000000003b17170000005253535300000000000000000000000052535353000000000000000000000000525353530000000000000000000000005253535300000000000000000000000052535353",
 [31]="1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b000000000000000000000000000000000000000000000000000000000000000000000000001111111111000000000000000000003b42434343442b0000000000000000003b52535353542b1500000000000000003b5253535353434400000000000000003b525363636353541b1b1b1b000000003b52541b1b1b525400000000000000003b626400003b52540000001100000000001b1b16003b5254000000450000000000111100003b626416000055000000000042442b00001b1b00003b55010000120052542b0000000011003b55170000170052542b0000003b452b3b55000000000052542b0000003b552b3b55",
 [32]="0000006253535353535353535353535300000000626363635353535353535353001200000000000062636363635353530017000000000000000000000062636311111111111100000000000000000000434343434343434343434344160000005353636363636363636353540000000053541b1b1b1b1b1b1b1b52540000000053542b0000001111003b52540011111153542b00003b4244003b52540042434353542b00003b5254003b52540062636363642b00003b5254003b6264001b1b1b1b1b0000003b525400001b1b0000000001000000003b5254000000000000000043442b00003b5254000011110000000053542b00003b52540000424400000000",
 [34]="00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007600000000000000000000000000000042440000000000000000000000000042535344000000000000000000000042535353540000000000000000000042535353535344000e00000000000000525353535353540000000000000000425353535353535343440000000100425353535353535353535344000043435353535353535353535353534400535353535353535353535353535353435353535353535353535353535353535353535353535353535353535353535353"
}

function get_lvl()
	return split(levels[lvl_id])
end

function get_data()
	return split(mapdata[lvl_id],",",false)
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
   local hex=sub(room,x_+(y_-1)*16,x_+(y_-1)*16+1)
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
  number\=16
  resultstr=sub("0123456789abcdef",remainder,remainder)..resultstr
 end
 return #resultstr==0 and "00" or #resultstr==1 and "0"..resultstr or resultstr
end

-- evercore tas tool injection
function load_room(x,y)
    load_level(x+8*y+1)
    room=vector((lvl_id-1)%8,flr((lvl_id-1)/8))
end

room=vector(0,0)
local __update=_update

_update=function() 
    __update()
    room=vector((lvl_id-1)%8,flr((lvl_id-1)/8))
end
function level_index()
    return lvl_id-1 
end
__gfx__
000000000000000000000000088888800000000000000000000000000000000000aaaaa0000aaa000000a0004fff4fff4fff4ffffff4fff40000000000000000
000000000888888008888880888888880888888008888800000000000888888000a000a0000a0a000000a0004444444444444444444444440000000000000000
000000008888888888888888888ffff888888888888888800888888088faffa800a909a0000a0a000000a0000004500000000000000540000000000000000000
00000000888ffff8888ffff888faffa8888ffff88ffff8808888888888fffff8009aaa900009a9000000a0000045000000000000000054000000000000000000
0000000088faffa888faffa808fffff088faffa88affaf80888ffff888fffff80000a0000000a0000000a0000450000000000000000005400000000000000000
0000000008fffff008fffff00033330008fffff00fffff8088fffff8083333800099a0000009a0000000a0004500000000000000000000540000000000000000
00000000003333000033330007000070073333000033337008faffa0003333000009a0000000a0000000a0005000000000000000000000050000000000000000
000000000070070000700070000000000000070000007000077333700070070000aaa0000009a0000000a0000000000000000000000000000000000000000000
55555555000000000000000000000000000000000007700000077000d666666dd666666dd666066d030030306665666503003030000000000000000070000000
5555555500000000000000000000000000000000007ee700007887006dddddd56ddd5dd56dd50dd5003333006765676500333300007700000770070007000007
550000550000000000000000000000000999999007eeee7007888870666ddd55666d6d5556500555028888206770677002888820007770700777000000000000
5500005500700070049999400000000098888889007ee7007888888766ddd5d5656505d5000000550898888007000700b898888b077777700770000000000000
550000550070007000500500000000009888888907eeee70788888876ddd5dd56dd50655650000000888898007000700b888898b077777700000700000000000
5500005506770677000550000000000099999999007ee700078888706ddd6d656ddd7d656d500565088988800000000008898880077777700000077000000000
5555555556765676005005000000000098800889000770000078870005ddd65005d5d65005505650028888200000000002888820070777000007077007000070
55555555566656660005500004999940988888890000000000077000000000000000000000000000002882000000000000288200000000007000000000000000
5cccccc50cccccccccccccccccccccc0cc11111111111111111111cc5cccccc55555555555555555555555555500000007777770000000000000000000000000
ccccccccccccccccccccccccccccccccccc111111111111111111ccccccccccc5555555555555550055555556670000077777777000bbbbb0000000000000000
ccc1cccccccc11111cccccc11111ccccccc111111111111111111ccccccccccc555555555555550000555555677770007777777700bbaab00000000000000000
cc1111ccccc11111111cc11111111ccccccc1111111111111111ccccccc11ccc55555555555550000005555566600000777733770babbb000000000000000000
cc1111cccc11111111111111111111cccccc1111111111111111cccccc1111cc55555555555500000000555555000000777733770bbaa0000bbbbb0000000000
ccc11ccccc11cc1111111111111c11ccccc111111111111111111ccccc1111cc55555555555000000000055566700000737733370bbbb0000bbbbab00bb00000
cccccccccc11cc1111111111111111ccccc111111111111111111ccccc1111cc555555555500000000000055677770007333333700000000000000bb00bbbbb0
5cccccc5cc11111111111111111111cccc11111111111111111111cccc1111cc55555555500000000000000566600000033333300000000000000000000bbbbb
cc1111cccc11111111111111111111cc5cccccccccccccccccccccc5ccc111cc5555555550000000000000050000066603333330000000000000000000000000
ccc111cccc11111111111111111111ccccccccccccccccccccccccccccc11ccc50555555550000000000005500077776033333300000000000ee0ee000000000
ccc111cccc11c111111111111cc111cccccc111cccccccccc111ccccccc11ccc55550055555000000000055500000766033333300000000000eeeee000000030
cc111ccccc111111111111111cc111ccccc11111c1cccc1111111ccccc111ccc555500555555000000005555000000550333333000000000000e8e0000000030
cc111cccccc11111111cc11111111cccccc1111111cccc1c11111ccccc1111cc55555555555550000005555500000666003333000000300000eeeee000000330
ccc11ccccccc11111cccccc11111cccccccc111cccccccccc111cccccc1111cc55055555555555000055555500077776000440000003000000ee3ee003000300
ccc11cccccccccccccccccccccccccccccccccccccccccccccccccccccc11ccc5555555555555550055555550000076600044000030300300000300000303300
cc1111cc0cccccccccccccccccccccc05cccccccccccccccccccccc55cccccc55555555555555555555555550000005500999900030330300000300000303300
00000000000000000770770770770770770077700777777000000000000000001111111100000000000000000000000000000000000000000000000000000000
00000000000000007777777777777777777777777777777700000000000000001cc1111100000000000000000000000000000000000000000000000000000000
00000000000000007777666667777776666677777777777700000000000000001cc11c1100000000000000000000000000000000000000000000000000000000
0000000000000000077666666667766666666770077667700000000000000000111111110000000000000000000000000000c000000000000000000000000000
0000000000000000776666666666666666666677776666770002eeeeeeee200011111111000000000000000000000000000c0c00000000000000000000000000
000000000000000077666666666666666666667777666677002eeeeeeeeee20011c1111100000000000000000000000000c000c0000000000000000000000000
00000000000000000766666666666666666666700766667000eeeeeeeeeeee0011111c110000000000000000000000000c000001000000000000000000000000
00000000000000007766666666666666666666777766667700e22222e2e22e001111111100000000000000000000000010000001000000000000000000000000
00000000000000007766666666666666666666777766667700eeeeeeeeeeee000000000000000000000000000000000100000001000100000000000000000000
00000000000000000776666666666666666667700776667000e22e2222e22e000000000000000000000000000000001000000000101010000000000000000000
00000000000000007776666666666666666667777776667700eeeeeeeeeeee000000000000000000000000000000010000000000010001000000000000000000
00000000000000007777666666666666666677777766677700eee222e22eee000000000000000000000000000000010000000000000000000000000000000000
00000000000000000777666666666666666677700766677000eeeeeeeeeeee005555555566666600066666006666600066000000066666006600066066666600
00000000000000000776666666666666666667707776677700eeeeeeeeeeee005555555566666660666666606666660066000000666666606660066066666660
00000000000000007776666666666666666667777776677700eecceeecccce005555555566000000660006606600660066000000660006606666066066000660
0000000000000000776666666666666666666677076666700cccccccccccccc055555555dd000000ddddddd0ddddd000dd000000ddddddd0ddddddd0dd000dd0
000000000000000077666666666666666666667777766677007777005000000000000005dddd0000dd000dd0dd00dd00dd000000dd000dd0ddddddd0dd000dd0
004444444444440007666666666666666666667007766770070000705500000000000055dd000000dd000dd0dd00dd00ddddddd0dd000dd0dd0dddd0ddddddd0
042222222222224077666666666666666666667777766777707700075550000000000555dd000000dd000dd0dd00dd00ddddddd0dd000dd0dd00ddd0dddddd00
4224444444444224776666666666666666666677776667777077ee07555500000000555500000000000000000000000000000000000000000000100000000000
424444444444442407766666666776666666677007666670700eee07555555555555555500000000000001000000000000000000000000000000100000000000
422222222222222477776666677777766666777777666677700eee07555555555555555500000000000010000000000000000000000000000000010000000000
42222222222222247777777777777777777777777776677707000070555555555555555500000000001100000000000000000000000000000000001000000000
42222222222222240770770770777077707707700777777000777700555555555555555500000000010000000000000000000000000000000000001000000000
44444444444444440000000000000000000000000000000000455500004500000040055500000000100000000000000000000000000000000000001000000000
4222224aa42222240000000000000000000000000000000000455555004550000045555500000001000000000000000000000000000000000000001001000000
4222224aa42222240000000000000000000000000000000004200555042555550425550000000010000000000000000000000000000000000000001010100000
42222244442222240000000000000000000000000000000004000000040055500400000000000100000000000000000000000000000000000000000100010000
42222244442222240000000000000000000000000000000004000000040000000400000000000100000000000000000000000000000000000000000000010000
42222222222222240000000000000000000000000000000042000000420000004200000000000100000000000000000000000000000000000000000000001000
42222222222222240000000000000000000000000000000040000000400000004000000000001000000000000000000000000000000000000000000000000100
42222222222222240000000000000000000000000000000040000000400000004000000000010000000000000000000000000000000000000000000000000010
23232323232323232323235262000042525262000000000000000000000000422323525252232323232323232323232323232323525252526200000000000000
00000042522323232323232323232323232323525223232352525223330000005252525252525252525252525252525200000000000000000000000000000000
0000000000000000000000426200004252526200000000000000000000000042000013526200000000000000b100000000000000425252526200000000000000
0000004262b1b1b1b1b1b1b1b1b1b1b1b10010426200000042526200000000005252525252525252525252525252525200000000000000000000000000000000
00000000000000000000001333000042525262000000000000001100000000420000004262510000000011000000001100000000425252526200000000000000
0000004262b20000510000000051000000b31252620000c142526200000000005252525252525223235252525252525200000000000000710000000000000000
00000000610011000000000000000042525262000000000000007200000061420000004252222222222222222222222232000000132323526200000000000000
0000004262b20000111100000000000000b342526200000042526261111111115252525252233300001323525252525200000000000000000000000000000000
0000000000b372b2000000000000b342525262000000000000000300000000420000001323232323232323232323232333b0c0000000b3426200000000000000
0000004262b200001232b2000000000000b342526200001252526200122222225252232333000000000000132352525200000000000000000000000000000000
0000000000b303b2000000000000b3425252330000000000000003000000004200000000000000000000000000000000000000000000b3426200000000000000
0000004262b200004262b2000000000000b313233300004252526200132323232333000000000000000000000013232300000000000000007171000000000011
00000000000003b2000000000000b3425262000000000000000073000000b34200000000000000000000000000000000000000610000b3426200000000000000
0000004262b200004262b20000000000000000000000004252526200b1b1b1b10000000000000006160000000000000000000000000000000000000000000072
00000000000003b2000000c10000b3425262000000000000000000000000b34200000000000000000000000000000000000000000000b34262000000b3122222
0051001333b200004262b20000000000000000006100004223233300000000000000000000000007170000000000000000000000000000000011000000000073
00000000000003b2000000210000b3425262000000000000000000000000b34200000000000000000000000000000000000000000000b34262000000b3425252
00000000000000004262b200005100001111110000000003b1b1b100000000000000000000000012320000000000000011000000000000000072000000000000
00000000000003b2000000710000b3425262000000000000000000000000b34200000000000000000000000000000000000000000000b31333000000b3425252
00000000000000004262b20000000000222232000000000300000000000000000000000000122252522232000000000072000000000000000003000000000000
0010000000b3031111000011111111425262000000000000000000000000b3420000000000000000000000000000000000000000000000b1b1000000b3425252
00000000000000004262b20000000000232333000000b30300000000000000000010001222525252525252223200000073000000000000000003000000000000
2222223200b3034363000043535363425262000000000000000000000000b34200000000000000001111111111111111110000000000000000000000b3425252
00000000000000004262b20000000000000000000000b30300000000000021002222225252525252525252525222222200000000110000000003000000000071
52525262000073b1b10000b1b1b1b1425233000000000000000000000000b34200000000000000111222222222222222321100000000001111000000b3425252
00000000000000004262b20000000000000000000000b30300000000000071005252525252525252525252525252525200000000720000000073000000110000
525252620000000000000000000000426200000000001000210000000000b34200100000000000125252525252525252523200000000b31232b20000b3132352
00000000000000004262b20000001000000000000000007300000000000000005252525252525252525252525252525200000000730000000000000000720000
52525262b200000051000000000000426200000012222222320000000000b34222223200002100425252525252525252526200210000b34262b200000000a142
00000000000000004262b20000122222000000000000006100000000000000005252525252525252525252525252525210000000000000110000000000730000
525252522232111111111111000000426200000042525252620000000000b34252526200007200425252525252525252526200720000b34262b20000b3122252
00000000000000004262b20000425252000000000000000000000000000000005252525252525252525252525252525232000000000000720000000000000000
00000000000000000000000000000000000000b34262000000000000000000000000000042525252525252525262000052525252525252525252330000004252
00004252525223232323232323232323b1b1b1b14252525252620000000000002323232352523300001352525252525200000000000000000000000000000000
00000000000000000000000000000000000000b34262000000000000000000000000000042525252525252525262000052522352525252232333000000004252
000042525262b200000000000000000000000000425252525262000000000000b1b1b1b142620000000042525252525200000000000000000000000000000000
00000000000000000071710000000000000000b34262000000000000000000000000000042525252525252525262000023330013522333000000000000001352
000042522333b2000000000000000000000000004252525252620000000000001000000042620000000042525252525200000000000000000000000000000000
00000000122232000000000000000000000000b34262000000000000000000000000000042525252525252525262000000000000730000000000000061000013
00004262000000000000001232000000000000001323235252620000000000003200000042620000000042525252525200000000000000000000000000000000
0000c100425262000000000000007171000000b34262000000000000000000000000000042525252525252525262000000000000000000000000000000000000
0000426200000000000000426200000000000000b1b1b142526200000000000062000000425232b2b31252525252525200000000000000670000000000000000
00000000425262000000000000000000100000b34262000000000000000000000000000042525252525252525262000000000000000000000000000000000000
000042620000000000000042620000000000000000000042526200000000000062111100425233b2b31323232323232300000000000000123200000000000000
00000000425262000071000000000000320000b3426200000000b312222232000000000042525252525252525262000000000000000000000000000000000000
00004262000000111111114262000000000000001111004252626100000000005222320042620000000000000000000000000000000012525232000000000000
00000000425262000000000000000000620000b3426200000011b342525262111111000013232323232323232333000000000000000000000000000000000000
000042620000001222222252620000b3000000b31232004252620000111100005223330042627171717112222222320000000000001252525262000000000000
00000000135262000000007171000000620000b3426200000072b3135252522222321100b1b1b1b1b1b1b1000000000000000000000000000000000000000000
00004262000000425252232333000072000000b34262214252620000123200006200000042620000000013232352620000000000125252525252320000000000
00000000004262000000000000007100620000b313330000007300b3425252525252320000000000000000000000000000000000000000061600000000000000
00001333000000425262b20000000003000000b3426271425262000042620000620000004262b200000000000042620000000000425252525252620000000000
0000000000426200000000000000000062000000b1b10000000000b3425252525252620000000000000000000000000000100000000000071700000000000000
00000000000000425262b20000000073000000b3426200132333000042620000620011114262b200000000000013330000000012525252525252522232000000
000000000042620000000000000071006200000000000000000000b3135252525252620000000000000000000000000022223200000000123200000000122222
00000000006100425262b20000000000000000b342620000b1b1000042620000620012225262b200b312327171b1b10010001252525252525252525252320000
00000000001333000000000000000000620000000000000000000000b34252525252621111111111000000000021000052526200000000426200000000425252
00000000000000425262000000000000000000b3426200000000000042620000620013232333b200b34262000000000022225252525252525252525252523200
00000000000000000071710000000000620000001111000000000000b34252525252522222222232110000000071000052526200000000426200000000425252
11111111111111425262100000000000001000b34262000011111111426200006200b1b1b1b10000b34262111111111152525252525252525252525252525222
00100000000000000000000000000000620000b31232000000002100b34252525252525252525252320000000000000052526200000000426200000000425252
22222222222222525252222222320000222222225262000012222222526200006200610000000000b34252222222222252525252525252525252525252525252
22223200007171000000000000000000620000b34262000000007100b34252525252525252525252620000000000000052526200000000426200000000425252
525252525252525252525252526200005252525252620000425252525262a1006200000000000000b34252525252525252525252525252525252525252525252
__label__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000007700000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000007700000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000060000000000000000000600000000000000000000000000000000000
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000c000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000c0c00000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000c000c0000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000c000001000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000010000001000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000100000001000100000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000001000000000101010000000000000000000000000000000000000000000000000000000
00000000000000000000060000000000000000000000000000000000010000000000010001000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000066666600066666006666600066000000066666006600066066666600000000000000000000000000000000000000
00000000000000000000000000000000000066666660666666606666660066000000666666606660066066666660000000000000000000000000000000000000
00000000000000000000000000000000000066000000660006606600660066000000660006606666066066000660000000000000000000000000000000000000
000000000000000000000000000000000000dd000000ddddddd0ddddd000dd000000ddddddd0ddddddd0dd000dd0000000000000000000000000000000000000
000000000000000000000000000000000000dddd0000dd000dd0dd00dd00dd000000dd000dd0ddddddd0dd000dd0000000000000000000000000000000000000
000000000000000000000000000000000000dd000000dd000dd0dd00dd00ddddddd0dd000dd0dd0dddd0ddddddd0000000000000000000000000000000000000
000000000000000000000000000000000000dd000000dd000dd0dd00dd00ddddddd0dd000dd0dd00ddd0dddddd00000000600000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000001000000000000000000000000000000100000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000010000000000000000000000000000000010000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000001100000000000000000000000000000000001000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000010000000000000000000000000000000000001000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000100000000000000000000000000000000000001000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000001000000000000000000000000000000000000001001000000000000000000000000000000000000000000
00000000000000000000000000000000000000000010000000000000000000000000000000000000001010100000000000000000000000000000000000000000
00000000000000000000000000000000000000000100000000000000000000000000000000000000000100010000000000000000000000000000000000000000
00000000000000000000000000000000000000000100000000000000000000000000000000000000000000010000000000000000000000000000000000000000
00000000000000000000000000000000000000000100000000000000000000000000000000000000000000001000000000000000000000000000000000000000
00000000000000000000000000000000000000001000000000000000000000000000000000000000000000000100000000000000000000000000000000000000
00000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
06000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000007000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000
00000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000060000000000000000000000000000000000555550000500555550000000000000000000000000000000000000000000000000000000
00000000000000000000000000000660000000000000000000000005500055005005505055000000000000000000000000000000000000000000000000000000
00000000000000000000000000000660000000000000000000000005505055005005550555000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000005500055005005505055000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000555550050000555550000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000555050500000505055505550555055505550000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000505050500000505050505550500050505050000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000550055500000550055505050550055005550000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000505000500000505050505050500050505050000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000555055500000505050505050555050505050000000000000000000000000000000000000000000000
00000000000000066000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000066000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000550555055500550555055005550500000000550555055505550000055505050000000000000000000000000000000
00000000000000000000000000000000005050505005005000050050505050500000005000505055505000000050505050000000000000000000000000000000
00000000000000000000000000000000005050550005005000050050505550500000005000555050505500000055005550000000000000000000000000000000
00000000000000000000000000000000005050505005005050050050505050500000005050505050505000000050500050000000000000000000000000000000
00000000000000000000000000000000005500505055505550555050505050555000005550505050505550000055505550000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000055505550555055500000555050500550555005500550550000000000000000000000000000000000000000
00000000000000000000000000000000000000000055505050050005000000050050505050505050005050505000000000000000000000000000000000000000
00000000000000000000000000000000000000000050505550050005000000050055505050550055505050505000000000000000000000000000000000000000
00000000000000000000000000000000000000000050505050050005000000050050505050505000505050505000000000000000000000000000000000000000
00000000000000000000000000000000000000000050505050050005000000050050505500505055005500505000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000005500055055505000000055505550555055505050000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000005050505050005000000050505000505050505050000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000005050505055005000000055005500550055005550000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000005050505050005000000050505000505050500050000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000005050550055505550000055505550505050505550000000000000000000000000000000000000000006
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000066000

__gff__
0000000000000000000000000000000004020000000000000000000200000000030303030303030304040402020000000303030303030303040404020202020200000303030302020300000002000202000003030303020204020202020202020000030303030004040202020202020200000000000000000002020202020202
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000242600000000313232323232322525252525252600000024252532323232323225000000000000000000002425262b00000000000000000000000000242525252532323232330000000031323232323232
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000242600000000000000000000002448252525252600000024252600000000000024000000000000000000002425262b00000000000000000000000000242525252500000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000024260000000000000000000000242525252525260b0c0d31323300000000000024000000000000000000002425262b00000000000000000000000000242525252500000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000242600000000000000000000002425482525252600000000000000000000000024000000000000000000002425262b00000000000000000000000000242525252500000000000000160000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000242522222222222223000000003132252525252600000000000000000000000024000000000000000000002425262b00000000000000000000000000242525252500000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002c00242525252525252525230000000000242525252600000000000021230000000024000000000000000017172425262b00000000000000001111000000312525252500000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000003d003c002425252525252525252600000000002425252526112123111111242600000000240000000000000000000024252600000000000000000021232b0000003125252500000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000003e21222222222525252525252525252600000000002425252525222525222222252600000000240000000000000000000024252600000000000000000024262b0000000031252500000000000000010000000000000000
000000000000000000000000000000000000000000000000000000002c0000000000000000000000002125252525252525252525252525252600000000002425252525323232323232323300000000240000000000000000000024252600000000000000000024262b0000000000242500000000002122222300000000000000
00000000000000000000000000000000000000000000000000003e003c003d00003d000000000000112425252525252532323232323232252600000000212525252526000000001b1b1b1b000000212500000000000017170000242526002122232b0000000024262b0000000000242500000000002425252600000000000000
0000000046470000000000000000000000000000000000000021222222222222222223000000000021252525252525251b1b1b1b1b1b1b242600003b212525252525260000000000000000000000242500000000000000000000242526002425262b0000000024262b0000000000242500000000212525252523000000000000
00013d0056573f0000000000003f3e3d000000000000000000242525252525252525260000000011242525252525252500000000000000313300003b242525252525260000000011111111000000242517170000000000000000313233002425262b000000002426000000000000242500000021252525252525230000000000
222222222222230000000000002122222223110000000000003125252525252525252600000000212525252525252525000001000000001b1b00003b2425252525252601000000212222222222222525000000000000000000001b1b1b002425262b000000002426000000010000242500002125252525252525260000000000
252525252525261100000000002425252525230000000000003b2425252525252525260000000024252525252525252500002122230000000000003b242525252525252222222225252525252525252500000000000000000000000000002425262b000000002426002122230000312500002425252525252525252300000000
252525252525252300000000003125252525260000000000003b3125252525252525260000000024252525252525252522222525260000000000003b242525252525252525252525252525252525252500000017170000000000000000002425262b000000002426002425260000002400212548252525252525252523000000
252525252525252600001a00003b3125252526000000000000003b24252525252525260000000024252525252525252525252525260000000000003b242525482525252525252525252525252525252500000000000000212223000000002425262b000000002426002425260000002421252525252525252525252525222222
25252525262b00000024253232252525252525252525261b1b1b1b0000000024252525323232323232330000000024253232323233000000002425252525252525252525252525252525252525252526000000002425252525252525252525250000000000000000000000003b30000025252525252525252526000024252525
25252525262b0000002426010024252525252525252526000000000000000024252526000000000000000000000024250000000000000000002425252525252525252525252525252525252525252526000000002425252525252525252525250000000000000000000000003b30000025253232252525252533000031323232
25252525262b0000002426171724252525252525252526001a00000000000024252526000000000000000000000024250000000000000011112425252525252525252525252525252525252525252533000000002425252525252525252525250000000000000000000000003b3000002526010031322525331b00001b1b1b1b
25252525262b0016002426000024252525252525253233000000000000000024252526000000000000000000000024250000000016003b21222525252525252525252525252525252525252525253300000000002425252525252525252525250000000000000000000000003b30000025261717003b24262b00000000000000
25252525262b0000002426000024252525252525260000000011111100000024252526000000160000000000000031250000000000003b24252525252525252525252525252525252525253232330000000000002425252525252525252525250000000000000000000000003b30000025260015003b24260000000000000000
25252525262b0000002426000024252525252525260000000021222300000024252526000000000000000000000000240000000000003b24252525252525252525252525252525252525330000000000000000002425252525252525252525250000000000000000000000003b30000025260000003b24260000000000000000
25252525262b0016003133000024252525252525261111111124323300000024252526000000000000000000000000240000000000003b31323232322525252525252525252525252533000000000000003e00002425252525252525252525250000000000000011110000003b30000025260000003b24260000000000000000
25252525262b0000001b1b00002425252525252525353535353300000000002425252600000000000000000000000024000000271717001b1b1b1b1b3132322525252525252525253300000000000000212222222525252525252525252525250000000000003b21232b00003b30000025260000003b24260000000000000000
25252525262b0000000000000024252525252525260000000000000000001224252526000000000000000000000000240000003000000000000000000000002425252525252525330000000000003d21252525252525252525252525252525250000000000003b24262b00003b30000025330000003b24262b00000000000000
25252525262b0000001111000024252525252525330000000000000000212225252526160000000000000000000000240000003000000000000000000000002425252525323233000000000000212225252525252525252525252525252525250000000000003b24262b00003b30000026000000003b24262b00000015000000
25252525262b00000021230000242525252525260000000000000000002425252525260000000000000000000000002400171737000000111111001600000024252532330000000000003d0021252525252525252525252525252525252525250000000000003b24262b00003b37000026000000003b31332b00000000000000
25252525262b00000024260000312525252525260b0c0c0d212222222225252525252600000000000000000000000024000000000000002122232b000000002432330000000000000021222225252525252525252525252525252525252525250000150000003b24262b00000000000026000000000000000000000000000000
25252525262b000000242600000031252525252600000000242525252525252525252600000100000000000000000024000000000000002425262b000000002400000000000000002125252525252525252525252525252525252525252525250100000000003b24262b00000000000026000000000011110000000000000000
25252525262b000000242600000000242525252600000000242525252525252525252600212223000021222222230024000000000000002425262b000001002400000000000000212525252525252525252525252525252525252525252525252222222300003b24262b00000000000026000000003b21230000000000000000
25252525262b00000024260000001a2425252533000000003132322525252525252526002425260000242525252600240000001717170024252522222222222500000001002122252525252525252525252525252525252525252525252525252525252600003b24262b00003b21222226000000003b24260000000000000000
25252525262b0000002426000000002425252600000000000000003132323225252526002425260000242525252600240000000000000024252525252525252500002122222525252525252525252525252525252525252525252525252525252525252600003b24262b00003b24252526000000003b24260000000000000000
__sfx__
0102000036370234702f3701d4702a37017470273701347023370114701e3700e4701a3600c46016350084401233005420196001960019600196003f6003f6003f6003f6003f6003f6003f6003f6003f6003f600
010200201857018570187701877018770187701876018760187601876018760187601875018750187501875018740187401874018730187301873018730187201872018720187201872018710187101871018715
000300000d07010070160702207000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200000642008420094200b420224402a4503c6503b6503b6503965036650326502d6502865024640216401d6401a64016630116300e6300b62007620056100361010600106000060000600006000060000600
000400000f0701e070120702207017070260701b0602c060210503105027040360402b0303a030300203e02035010000000000000000000000000000000000000000000000000000000000000000000000000000
000300000977009770097600975008740077300672005715357003470034700347003470034700347003570035700357003570035700347003470034700337003370033700337000070000700007000070000700
00030000241700e1702d1701617034170201603b160281503f1402f120281101d1101011003110001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00020000101101211014110161101a120201202613032140321403410000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00030000070700a0700e0701007016070220702f0702f0602c0602c0502f0502f0402c0402c0302f0202f0102c000000000000000000000000000000000000000000000000000000000000000000000000000000
0003000005110071303f6403f6403f6303f6203f6103f6153f6003f6003f600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
01400000307423070230732337222b73230702307223070230702307223070230702307123070230702307122b7422b7022b73227722297322b7022b7222b7022b7022b7222b7022b7022b7122b7022b7022b712
002000001d0401d0401d0301d020180401804018030180201b0301b02022040220461f0351f03016040160401d0401d0401d002130611803018030180021f061240502202016040130201d0401b0221804018040
010f00000c625000003060030600306353060000000000000c6100c61530635000000c6100c6150c6100c61500000000000c6100c615306350c6000c6100c6150c6100c615186101861530635000000c6000c615
000400000c5501c5601057023570195702c5702157037570285703b5702c5703e560315503e540315303e530315203f520315203f520315103f510315103f510315103f510315103f50000500005000050000500
000400002f7402b760267701d7701577015770197701c750177300170015700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
00030000096450e655066550a6550d6550565511655076550c655046550965511645086350d615006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
011000001f37518375273752730027300243001d300263002a3001c30019300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
001000002953429554295741d540225702256018570185701856018500185701856000500165701657216562275142753427554275741f5701f5601f500135201b55135530305602454029570295602257022560
010f00001f9701f9701f9701f970000000000000000000000090000900219702197021970219701f9701f9701d9701d9701d9701d9701c9701c9701c9701c9701a9701a9701a9701a97018970189701897018970
010f0000080500804500000070000c000000000f05000000130501304500000070000f050000000a0500a0450c0000000000000070000c0000000007050000000a0500a045000000700007050070450000000000
0008002001770017753f6253b6003c6003b6003f6253160023650236553c600000003f62500000017750170001770017753f6003f6003f625000003f62500000236502365500000000003f625000000000000000
002000200a1400a1300a1201113011120111101b1401b13018152181421813213140131401313013120131100f1400f1300f12011130111201111016142161321315013140131301312013110131101311013100
001000202e750377502e730377302e720377202e71037710227502b750227302b7301d750247501d730247301f750277501f730277301f7202772029750307502973030730297203072029710307102971030710
000600001877035770357703576035750357403573035720357103570000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
001800202945035710294403571029430377102942037710224503571022440274503c710274403c710274202e450357102e440357102e430377102e420377102e410244402b45035710294503c710294403c710
010f0000070500704500000070000c000000000e05000000130501304500000070000e0500000007050070450c0000000000000070000c000000000e050000001305013045000000700013040130350000000000
010c00103b6352e6003b625000003b61500000000003360033640336303362033610336103f6003f6150000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000c002024450307102b4503071024440307002b44037700244203a7102b4203a71024410357102b410357101d45033710244503c7101d4403771024440337001d42035700244202e7101d4102e7102441037700
000f00001c9701c97500000000001c9701c9701d9701d9701f9701f9701f9701f9700000018900189000000000000000001f9701f9701d9701d9701c9701c9701d9701d9701c9701c97018970189701391013910
001800200c5700c5600c55000000115701156011550000000c5700c5600f5710f56013570135600f5700f5600c5700c5700c5600c5600c5500c5300c5000c5000c5000a5000a5000a50011500115000a5000a500
000c0020247712477024762247523a0103a010187523a0103501035010187523501018750370003700037000227712277222762227001f7711f7721f762247002277122772227620070027771277722776200700
000c0020247712477024762247523a0103a010187503a01035010350101875035010187501870018700007001f7711f7701f7621f7521870000700187511b7002277122770227622275237012370123701237002
000c0000247712477024772247722476224752247422473224722247120070000700007000070000700007002e0002e0002e0102e010350103501033011330102b0102b0102b0102b00030010300123001230012
000c00200c3320c3320c3220c3220c3120c3120c3120c3020c3320c3320c3220c3220c3120c3120c3120c30207332073320732207322073120731207312073020a3320a3320a3220a3220a3120a3120a3120a302
000c00000c3300c3300c3200c3200c3100c3100c3103a0000c3300c3300c3200c3200c3100c3100c3103f0000a3300a3201333013320073300732007310113000a3300a3200a3103c0000f3300f3200f3103a000
00040000336251a605000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005
000c00000c3300c3300c3300c3200c3200c3200c3100c3100c3100c31000000000000000000000000000000000000000000000000000000000000000000000000a3000a3000a3000a3000a3310a3300332103320
001000000c3500c3400c3300c3200f3500f3400f3300f320183501834013350133401835013350163401d36022370223702236022350223402232013300133001830018300133001330016300163001d3001d300
010c0000247752b77530775247652b76530765247552b75530755247452b74530745247352b73530735247252b72530725247152b71530715247052b70530705247052b705307053a7052e705007050070500705
001000102f65501075010753f615010753f6152f65501075010753f615010753f6152f6553f615010753f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
0010000016270162701f2711f2701f2701f270182711827013271132701d2711d270162711627016270162701b2711b2701b2701b270000001b200000001b2000000000000000000000000000000000000000000
010f00001f9701f9701f9701f970000000000000000000000090000900219702197021970219701f9701f9701d9701d9701d9701d9701c9701c9701c9701c9701a9701a9701a9701a97018970189701897018970
002000200c2650c2650c2550c2550c2450c2450c2350a2310f2650f2650f2550f2550f2450f2450f2351623113265132651325513255132451324513235132351322507240162701326113250132420f2600f250
00100000072750726507255072450f2650f2550c2750c2650c2550c2450c2350c22507275072650725507245072750726507255072450c2650c25511275112651125511245132651325516275162651625516245
0002000011070130701a0702407000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00100020112751126511255112451326513255182751826518255182451d2651d2550f2651824513275162550f2750f2650f2550f2451126511255162751626516255162451b2651b255222751f2451826513235
00100010010752f655010753f6152f6553f615010753f615010753f6152f655010752f6553f615010753f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
001000100107501075010753f6152f6553f6153f61501075010753f615010753f6152f6553f6152f6553f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
010f00000c625000003060030600306353060000000000000c6100c61530635000000c6100c6150c6100c6150000000000306350c600306000c6000c6100c6150c6100c615186151860030635000000c6000c615
000800202451524515245252452524535245352454524545245552455524565245652457500505245750050524565005052456500505245550050524555005052454500505245350050524525005052451500505
000800201f5151f5151f5251f5251f5351f5351f5451f5451f5551f5551f5651f5651f575000051f575000051f565000051f565000051f555000051f555000051f545000051f535000051f525000051f51500005
000500000373005731077410c741137511b7612437030371275702e5712437030371275702e5712436030361275602e5612435030351275502e5512434030341275402e5412433030331275202e5212431030311
002000200c2750c2650c2550c2450c2350a2650a2550a2450f2750f2650f2550f2450f2350c2650c2550c2450c2750c2650c2550c2450c2350a2650a2550a2450f2750f2650f2550f2450f235112651125511245
002000001327513265132551324513235112651125511245162751626516255162451623513265132551324513275132651325513245132350f2650f2550f2450c25011231162650f24516272162520c2700c255
000300001f3302b33022530295301f3202b32022520295201f3102b31022510295101f3002b300225002950000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b00002935500300293453037030360303551330524300243050030013305243002430500300003002430024305003000030000300003000030000300003000030000300003000030000300003000030000300
011000003c7723c7423c7323c7223c7123c71237752377423a7723a7523a7423a7323a7223a7223a7123a71235772357523574235742357323573235722357223571235712337723375233742337323372233712
01100000357723575235742357323572235722357123571237752377323377233752337423373233722337223a7723a7423a7323a7223a7123a71233772337523374233742337323373233722337223371233712
010f00001b9701b97500000000001b9701b9701d9701d9701f9701f9701f9701f9700000018900189000000000000000001891000000000000000000000000000000000000000000000000000000000000000000
010f00001897018970189701897018900189001a9001c900189701897018970189701a9701a9701c9701c9701c9701c970189001890018900189001890000900009000090000900009001c9701c9701d9701d970
000f00000c0500c04500000070000c0000000007050000000c0500c045000000700007050000000a0500a0450c0000000000000070000c0000000007050000000a0500a045000000700007050070450000000000
00100020326103261032610326103161031610306102e6102a610256101b610136100f6100d6100c6100c6100c6100c6100c6100f610146101d610246102a6102e61030610316103361033610346103461034610
00400000301453010530135331252b13530105301253010530105301253010530105301153010530105301152b1452b1052b13527125291352b1052b1252b1052b1052b1252b1052b1052b1152b1052b1052b115
__music__
01 154a5644
00 4a164c44
00 4a164c44
00 4a0b4c44
00 4a164c44
00 4a164c44
02 4a115244
00 4a515244
00 41424344
00 41424344
01 18591a44
00 18591a44
00 5c1b1a44
00 5d1b1a44
00 1f211a44
00 1f1a2144
00 1e1a2244
02 201a2444
00 41424344
00 41424344
01 2a276944
00 2a276944
00 2f2b6944
00 2f2b6c44
00 2e2d7044
00 2e2d7044
00 34312744
02 35322744
00 75726744
00 41424344
03 3d7e4344
00 3d7e4344
00 3d4a4344
02 3d3e4344
00 41424344
01 3d7e4344
02 3d0a4344
00 41424344
00 41424344
00 41424344
01 387a7c44
02 397b7c44
00 41424344
01 3c3b0c44
00 3c290c44
00 133a3044
02 191c3044

