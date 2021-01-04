pico-8 cartridge // http://www.pico-8.com
version 29
__lua__
--~falleste~--

--original celeste by:
--matt thorson + noel berry

--mod by sparky99
--based off of evercore v3.1
--by taco360

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
grav=0.105
keys=0

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
  max_djump,deaths,frames,seconds,minutes,music_timer,time_ticking=0,0,0,0,0,0,true
  music(0,0,7)
  load_level(0)
end

function is_title()
  return lvl_id==-1
end

function is_summit()
  return lvl_id==3
end

function get_player()
  for obj in all(objects) do
    if obj.type==player or obj.type==player_spawn then
      return obj
    end
  end
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
        this.spd.y=appr(this.spd.y,maxfall,abs(this.spd.y)>0.15 and grav*2 or grav)
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
    if lvl_id<17 and this.y<-4 then
      if lvl_id==16 and keys==5 then
        load_level(18)
      else
        next_level()
      end
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
  pal(8,djump==1 and 8 or djump==2 and 7+(frames\3)%2*4 or 12)
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

waterfall={
		init=function(this)
				this.t=0
				this.pt=0
				while (not this.is_solid(0,8) and this.hitbox.h<128) do	this.hitbox.h+=8 end
		end,
		update=function(this)
				local hit=this.check(player,0,0)
				if hit then 
					this.pt+=1
				else 
					this.pt=0
				end
				while (not this.is_solid(0,1) and this.hitbox.h<128) do this.hitbox.h+=1 end
				if (hit and maybe()) init_object(smoke,this.x+rnd(4)-2,hit.y-4)   
				if (maybe() and this.y+this.hitbox.h<128) init_object(smoke,this.x+rnd(4)-2,this.y+this.hitbox.h-4)
		  if (hit and this.pt%2==0) hit.spd.y+=0.2
		end,
		draw=function(this)
				this.t=(this.t+1)%8
				for i=0,this.hitbox.h/8-1 do
						sspr(120,40-this.t,8,this.t,this.x,this.y+8*i)
						sspr(120,32,8,8-this.t,this.x,this.y+8*i+this.t)
				end
		end
}

moving_spike_vert={
 init=function(this)
  this.up=false
  this.down=true
 end,
 update=function(this)
  if this.down then
   if not this.is_solid(0,1) and this.y<120 then
    this.y+=1
   else
    this.up=true
    this.down=false
   end
  else
    if not this.is_solid(0,-1) and this.y>0 then
    this.y-=1
   else
    this.up=false
    this.down=true
   end
  end
  local hit=this.check(player,0,0)
  if hit then
   kill_player(hit)
  end
 end,
 draw=function(this) 
  spr(75,this.x,this.y)
 end
}

moving_spike_horiz={
 init=function(this)
  this.left=false
  this.right=true
 end,
 update=function(this)
  if this.right then
   if not this.is_solid(1,0) and this.x<120 then
    this.x+=1
   else
    this.right=false
    this.left=true
   end
  else
    if not this.is_solid(-1,0) and this.x>0 then
    this.x-=1
   else
    this.right=true
    this.left=false
   end
  end
  local hit=this.check(player,0,0)
  if hit then
   kill_player(hit)
  end
 end,
 draw=function(this)
  spr(78,this.x,this.y)
 end 
}

balloon={
  init=function(this) 
    this.offset=0
    this.start=this.y-4
    this.timer=0
    this.hitbox=rectangle(3,3,10,10)
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
      spr(this.spr,this.x,this.y+6)
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

fall_block={
  init=function(this)
    this.hitbox=rectangle(0,0,24,16)
    this.fall_timer=31
    this.shake=false
    this.x_=this.x
    this.y_=this.y
  end,
  update=function(this)
    local hit=get_player()
    if hit then
      if this.fall_timer==31 and hit.y<this.y+12 and hit.x<this.x+25 and hit.y>this.y-10 and hit.x>this.x-8 then
        this.fall_timer=20
        this.shake=true
      end
    end
    if this.fall_timer<31 then
      this.fall_timer-=1
    end
    if this.fall_timer<1 then
      this.y+=this.fall_timer/6*-1
      this.shake=false
    end
    if this.y>lvl_ph then
      destroy_object(this)
    end
    if this.shake then
      this.x=this.x_+-1+rnd(3)
      this.y=this.y_+-1+rnd(3)
      this.hitbox.y=this.y_-this.y
      this.hitbox.x=this.x_-this.x
    end
  end,
  draw=function(this)
    sspr(104,0,24,8,this.x,this.y)
    sspr(104,0,24,8,this.x,this.y+8,24,8,true,true)
  end
}

bounce={
  init=function(this)
    this.timer=0
    this.hitbox=rectangle(1,3,6,6)
  end,
  update=function(this)
    if this.timer>0 then
      this.timer-=1
    end
    local hit=this.check(player,0,0)
    if hit and this.timer==0 then
      this.timer=30
      hit.spd.y=-1.5
    end
  end,
  draw=function(this)
    if this.timer==0 then
      spr(45,this.x,this.y)
    end
  end
}

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

qblock={
  init=function(this)
    this.hitbox=rectangle(2,2,4,4)
  end
}

half_block_right={
  init=function(this)
   this.hitbox=rectangle(4,0,4,8)
  end
}

half_block_top={
  init=function(this)
   this.hitbox=rectangle(0,0,8,4)
  end
}

half_block_bottom={
  init=function(this)
   this.hitbox=rectangle(0,4,8,4)
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
      keys+=1
    end
  end
}

move_plat={
  init=function(this)
    this.x_=this.x
    this.left=true
    this.right=false
    this.last=this.x
  end,
  update=function(this)
    if this.left then
      this.spd.x=-0.65
      if this.x<this.x_-16 then
        this.right=true
        this.left=false
      end
    elseif this.right then
      this.spd.x=0.65
      if this.x>this.x_+16 then
        this.right=false
        this.left=true
      end
    end
    if not this.check(player,0,0) then
      local hit=this.check(player,0,-1)
      if hit then
        hit.move_x(this.x-this.last,1)
      end
    end
    if not this.check(spring,0,0) then
      local above=this.check(spring,0,-1)
      if above then
        above.move_x(this.x-this.last,1)
      end
    end
    this.last=this.x
  end
}

half_block={
  init=function(this)
    this.hitbox=rectangle(0,0,4,8)
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
    if this.x<-16 then this.x=lvl_pw
    elseif this.x>lvl_pw then this.x=-16 end
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
 init=function(this)
  this.last=0
  this.text="-- falleste mountain --#  the land of endless  # fall and bitter cold  "
  this.hitbox=rectangle(0,-8,16,16)
 end,
	draw=function(this)
		if this.check(player,0,0) then
			if this.index<#this.text then
			 this.index+=0.5
				if this.index>=this.last+1 then
				 this.last+=1
				 sfx(35)
				end
			end
			this.off={x=8+(cam_x-64),y=96+(cam_y-64)}
			for i=1,this.index do
				if sub(this.text,i,i)~="#" then
					rectfill(this.off.x-2,this.off.y-2,this.off.x+7,this.off.y+6 ,7)
					print(sub(this.text,i,i),this.off.x,this.off.y,0)
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
      spr(96,this.x,this.y)
      spr(96,this.x+8,this.y,1,1,true)
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
        if lvl_id==2 then
          new_bg=true
        elseif lvl_id==11 then
          new_bg=false
          orange_bg=true
        end
        init_object(orb,this.x+4,this.y+4)
        pause_player=false
      end
      foreach(this.particles,function(p)
        p.y+=p.spd
        line(this.x+p.x,this.y+8-p.y,this.x+p.x,min(this.y+8-p.y+p.h,this.y+8),lvl_id<8 and 10 or 7)
      end)
    end
    if lvl_id==11 then
      pal(12,8)
      pal(1,2)
    end
    spr(112,this.x,this.y+8)
    spr(112,this.x+8,this.y+8,1,1,true)
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
      if lvl_id==2 then
        max_djump=1
        hit.djump=1
      elseif lvl_id==11 then
        max_djump=2
        hit.djump=2
      end
    end
    if lvl_id==11 then
      pal(8,11)
    end
    spr(102,this.x,this.y)
    for i=0,7 do
      circfill(this.x+4+cos(frames/30+i/8)*8,this.y+4+sin(frames/30+i/8)*8,1,7)
    end
  end
}

boooster={
  init=function(this)
    this.timer=0
  end,
  update=function(this)
    local hit=this.check(player,0,0)
    if hit then
      init_object(smoke,this.x,this.y)
      this.timer=1
      hit.spd.y=-6
      grav=0.008
      hit.djump=max_djump
    end
    if this.timer>0 then
      if this.timer<16 then
        this.timer+=1
      else
        grav=0.105
        init_object(smoke,this.x,this.y)
        destroy_object(this)
      end
    end
  end
}

flag={
  init=function(this)
    this.show=false
    this.x+=5
    this.score=0
    this.expand=0
    this.expanding=false
    this.truekey=false
    this.gs=false
    this.hundo=false
    for k,v in pairs(got_fruit) do
      this.score+=1
    end
  end,
  draw=function(this)
    this.spr=118+(frames/5)%3
    spr(this.spr,this.x,this.y)
    if this.show then
      foreach(objects,function(o)
        if o.type~=flag then
          destroy_object(o)
        end
      end)
      circfill(this.x,this.y,this.expand,7)
      if this.expand>80 then
        spr(26,55,46)
        ?"x"..this.score,64,48,0
        draw_time(49,58,7,0)
        ?"deaths:"..deaths,48,68,0
        if keys>4 then
          this.truekey=true
          keys=0
        end
        if max_djump>1 then
          this.gs=true
          max_djump=0
        end
        if this.score>8 then
          this.hundo=true
          this.score=0
        end
        if not this.hundo and this.gs and not this.truekey then
          ?"any%",56,75,0
        else
          if this.truekey then
            ?"true key%!!",47,81,0
          end
          if not this.gemskip then
            ?"gemskip!",50,87,0
          end
          if this.hundo then
            ?"hundo",52,93,0
          end
        end
      end
    elseif this.check(player,0,0) then
      sfx(55)
      sfx_timer,this.show,time_ticking=30,true,false
      this.expanding=true
	  lvl_id+=1
    end
    if this.expand>200 then
      this.expanding=false
    end
    if this.expanding then
      this.expand+=5
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
  [13]=fall_block,
  [18]=spring,
  [20]=chest,
  [22]=balloon,
  [23]=fall_floor,
  [26]=fruit,
  [28]=move_plat,
  [45]=bounce,
  [64]=qblock,
  [65]=half_block_bottom,
  [74]=half_block,
  [75]=moving_spike_vert,
  [78]=moving_spike_horiz,
  [79]=waterfall,
  [80]=half_block_right,
  [81]=half_block_top,
  [86]=message,
  [96]=big_chest,
  [97]=boooster,
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
           (oy>0 and not obj.check(move_plat,ox,0) and obj.check(move_plat,ox,oy)) or
           tile_flag_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h,0) or 
           obj.check(fall_floor,ox,oy) or
           obj.check(fake_wall,ox,oy) or
           obj.check(fall_block,ox,oy) or
           obj.check(half_block_bottom,ox,oy) or
           obj.check(half_block_top,ox,oy) or
  									obj.check(half_block,ox,oy) or
  									obj.check(half_block_right,ox,oy) or
           obj.check(qblock,ox,oy)
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
  grav=0.105
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
  end
  load_level(next_lvl)
  has_key=false
end

function load_level(lvl)
  has_dashed=false
  
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
  
  --chcek for hex mapdata
  if get_data() then
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
      if tiles[tile]==key then
       if not has_key then
        init_object(key,tx*8,ty*8,tile)
       end
      elseif tiles[tile]~=key and tiles[tile] then
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
      if lvl_id==2 then
        music(20,500,7)
      else
        music(10,0,7)
      end
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
  camera(camx,camy)
  if lvl_id>15 and frames%2==0 and time_ticking then
    camera(camx+(rnd(2)-1),camy+(rnd(2)-1))
  end

  --local token saving
  local xtiles=lvl_x*16
  local ytiles=lvl_y*16
  
  -- draw bg color
  cls(flash_bg and frames/5 or new_bg and 2 or orange_bg and 9 or 1)
  pal(2,130,1)

  -- bg clouds effect
  if not is_title() then
    foreach(clouds, function(c)
      c.x+=c.spd-cam_spdx
      -- old clouds
      -- rectfill(c.x+camx,c.y+camy,c.x+c.w+camx,c.y+4+(1-c.w/64)*12+camy,5)
      -- new clouds
      for i=0,(c.w/3) do
        circfill((c.x+i*4)+camx,c.y+camy,(i==2 or i==5 or i==9 or i==13 or i==16) and 4 or 3,5)
      end
      if orange_bg then
        pal(5,143,1)
      end
      if c.x>128 then
        c.x=-c.w*2
        c.y=rnd(120)
      end
    end)
  end

		-- draw bg terrain
  map(xtiles,ytiles,0,0,lvl_w,lvl_h,4)
		
		-- platforms
  foreach(objects, function(o)
    if o.type==platform then
      draw_object(o)
    end
  end)
		
  -- draw terrain
  map(xtiles,ytiles,0,0,lvl_w,lvl_h,2)
  pal(14,2,1)
  
  -- draw objects
  foreach(objects, function(o)
    if o.type~=platform then
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
    ?"🅾️+❎",58,60,6
    ?"noel berry",71,106,6
    ?"matt thorson",63,114,6
    ?"mod by sparky99",51,122,6
  end
  
  -- summit blinds effect
  if is_summit() and objects[2].type==player then
    local diff=min(24,40-abs(objects[2].x-60))
    rectfill(0,0,diff,127,0)
    rectfill(127-diff,0,127,127,0)
  end
  pal(9,137,1)
  pal(10,9,1)
  pal(4,132,1)
  if lvl_id>13 then
    for i=1,3 do
      pal(i,2,1)
    end  
    for i=4,5 do
      pal(i,8,1)
    end
  elseif lvl_id>14 then
    for i=1,3 do
      pal(i,2,1)
    end  
    for i=4,5 do
      pal(i,8,1)
    end
    for i=9,15 do
      pal(i,14,1)
    end
    pal(6,14,1)
    pal(7,14,1)
  else
		  if max_djump==0 then
		    pal(13,130,1)
		  elseif max_djump==1 then
		    pal(13,129,1)
		  else
		    pal(13,133,1)
		  end
		  if is_title() then
		    pal(11,10,1)
		  end
		  if lvl_id>9 then
		    pal(14,142)
		  end
		  if new_bg then
		    pal(5,142,1)
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

function draw_time(x,y,c1,c2)
  rectfill(x,y,x+32,y+6,c1)
  ?two_digit_str(minutes\60)..":"..two_digit_str(minutes%60)..":"..two_digit_str(seconds),x+1,y+1,c2
end

function draw_ui(camx,camy)
 rectfill(24+camx,58+camy,104+camx,70+camy,0)
 local title=lvl_title
 if title then
  ?title,hcenter(title,camx),62+camy,7
 else
 	local level=(1+lvl_id)*100
  ?level.." m",52+(level<1000 and 2 or 0)+camx,62+camy,7
 end
 draw_time(4+camx,4+camy,0,7)
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
	[-1]="3,3,1,1,0m",
	[0]="0,0,1,1,0m",
	[1]="1,0,1,1,32m",
	[2]="2,0,1,1,64m",
	[3]="3,0,2,1,96m",
	[4]="5,0,1,1,128m",
	[5]="6,0,2,1,160m",
	[6]="0,1,3,1,192m",
	[7]="3,1,2,2,224m",
	[8]="0,2,3,1,256m",
	[9]="5,1,1,3,320m",
	[10]="6,1,2,3,352m",
	[11]="0,0,3,2,448m",
	[12]="0,0,5,1,544m",
	[13]="0,0,3,2,576m",
	[14]="0,0,4,2,640m",
	[15]="0,0,2,3,highway to hell",
	[16]="0,0,2,3,end of the line",
	[17]="1,3,2,1,summit",
	[18]="0,0,1,2,last chance"
}
--mapdata table
--rooms separated by commas
mapdata={
 [11]="5353e153535353535353e1e1e1e1e1e153e200e0e153535353e2000000000000e200000000e05353d200000000000000001a00000000d053e200000000000000000000c31111e0d20000000000000000c20000d3004e00e30000000000000000d20000d3000000000000000000000000d20000d31200004b00000000000000c0d21bf053c200000000000000000000d0d200505353c2000000000000000000d0534a00d05353c1c1c2000000000000d053c200e053535353d20000000000c05353d20000e0e15353e1f200000000d05353e200000000e0e20000000000c05353d2000000000000000000c0c1c15353e1e20000000000c0c1c1c1535353e1e242,000000c0c1c1535353535353e2424363000000d053535353535353e242636400000000d0535353535353e24264000000000000e0e1e1e1e1e1e242640000000000004243434343434343540000000000000052535353535353536400000000000000525353535353535400000011424400005253535353535354000011425353000062535353535353640000425353530000005253636363542b00005253535300000062541b1b1b552b0011525353530000003b552b163b552b0042535353530000003b652b003b652b005253535353000000001b00000000000052535353534400000000000000000000525353535353440000000000000000005253535353,e1e153535353535353535353535353c20000e0e15353535353535353535353e200000000e0535353535353535353d21bc300000000e05353535353535353d22bd0c200000000d053535353535353d211d0d200000000e05353535353535353c2d053c200000000e053535353535353e25353d20000000000d05353535353d21b535353c1c2000000e05353535353d22b53535353d200000000e053535353e22b53535353d20000000000e0e1e1e200005353535353c2000000000000000000005353535353d200000000000000000000535353535353c2000000000000000000e1e153535353d20000000000c0c1c1c14344e0e1535353c200000000e0535353,63634344e05353d20000000000d053530000626344e053d20000000000d05353000000006244e053c200000000d0535300000000005244d0d200000000d0535300000000005264d0d200000000e05353000000004264c053e20000000000d0530001004264c053d2000000000000d05343434364c05353d2000000000000e053536364c05353e1e200000000000000d054c0c1d153e2000000000000000000d354e05353e200000000000000000000d35344d0d20000000000000000000000e35354d0d20000600000000000000000005354d053c200000000000000000000005354d05353c1c1c1c2000000000000005354d0535353535353c1c20000000000,2b00003bc053535353d20000d05353532b00003be053535353e20000e0535353000000001bd05353d22b00003be05353000000003bd05353d22b0000003be0530016000011d05353d22b0008000000e02b00003bc0535353d2000000000000002b00003be0535353e200000000000000000000001bd053d20000000011001600000000003bd053d20000003bf32b00000000000011d053e2000000001b0000000000003bc053d20000000000000000000000003bd053d2000000000000000000000000c05353e2000016000000000000c0c1c15353d2000000000000000000005353535353e20000000000000000000053535353e20000000000000000000000,535353d2000000000000000000000000535353e20000000000000000000000005353d2000000000000000000000000005353d2000000000000000000000000005353e20000000000000000000000000053d2000000000000000000000000000053e20000001200000000000000000000d2000000001c00000000000000000000e200000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
 [12]="535353e1e1e1e1e1e1e1e1e1e1e1e1e153e1e200000000000000000000000000e200000011000000000000001600000000000000c3000000000000000000000000000000d3111111000000000000000000001111d0c1c1c22b000000000000000011c0c1535353d22b0000000000000000c05353535353d22b1100000011000000e0e1e1535353d211c3111111c3111100000000e0535353c153c1c1c153c1c10000000000e0e153535353e1e1e1e1e1c1c20000000000e05353e200000000005353c1c22b000000e0d20000003bc0c1535353d22b00000000e30000003bd053535353d22b00000000000000003bd053535353d22b00000000000000003bd053,535353535353535353535353535353e1e0e153535353535353535353e1e1e2000000e053535353535353e1e200000000000000e0e1e1535353e2000000000000000000000000e0e1e20000000000000000000000000000000000000000000000000000000000000000000000000000000011000000110000000000c0c1c2000011c3111111c3111111c0c15353d20000c153c1c1c153c1c1c1e1e15353d21100e1e1e1e1e1e1e1e1e20000e05353c200000000000000000000000000d053d200c1c1c1c1c1c1c1c200000000d053d2005353535353535353c20001c05353d211535353535353535353c1c153535353c2535353535353535353535353535353d2,e153535353535353535353535353535300e0e1e153535353535353535353535300000000e0e1e1e1e1e153535353535300000000000000000000e0e1e1e1e1e1000000000000000011001b1b1b1b000000000000000000c0f1f1c212c0c211110000000000c0c1e20008d0c15353c1c1000000f0f1e1d22b003ed053e1e1e1e2000000000000e0f200f0e1e20000000000000000000011000000110000000000000000c0c1c1c1f217f0c2000000000000f0f1e15353d2000000e0f1c1c1c20000000000e0e1e1c20000143bd0e1e1f100000000000000e0f1f1f1f1e20000000000000000000000001600000000000000000000000000000000000000000000,535353535353535353535353535353535353535353535353e1e1e1e1535353535353e1e1e1e1e1e200000000e0e15353e1e2000000000000000000000000e05300000000000000000000110000001bd000000000000000000000c300000000e0f1f1f200000000000000d3110000001b00000000000000000011d0c200000000000000000000000000c053d200000000000000000000000000d053d211000000000000000000000000d05353c2000000000000000000000011d05353d2110000f200000000000000c053535353c211000000000000000000d05353535353c21100000d0000000000d0535353535353c10000000000000000d053535353535353,53535353535353535353d2000000000053535353535353535353d20000000000535353535353535353e1e200000000005353535353535353d21b0000000000005353535353535353e20000000000000053535353535353d21b00000000000000d0535353535353d20000000000000000d0535353535353e14a0000000000c0c1e05353535353d21b000000000011d0531bd053535353e2000000000011c0535300e053e1e1e22b0000001111c0535353001be32b000000001111c0c15353535316001b0000111111c0c15353535353531111111100c0c1c15353535353535353c1c1c1c1c1535353535353535353535353535353535353535353535353535353",
 [13]="53535353535353535353535353535353535353e1e1e1e1e1e1e1535353535353e1e1e200000000000000e0e1e1e1e1e100001600000000000000c3000000000000000000000000000000d3000000000011001111111100110000e30000001111c23bf0f1f1f200c32b001b00003bf0f1d2001b1b1b1b00d32bf0f1f200001b1bd2110016000000d32b1b1b1b0000000053c21111000800d300001100000000005353c1c2111100e30000c3000000000053535353c1c2111b0000d30000110000535353535353c200003be30011c31111535353535353e20000001111c053c1c15353535353e200000011c0c15353535353535353e2000000c0c1535353535353,535353e2000000c0535353535353535353e1e200000000d05353535353535353e20000000000c053535353535353e1e10000000000c0535353535353e1e20000000000c0c1535353535353e200000000003bc053535353535353d20000000000003bd0535353e1e1e1e1d20000000000003bd05353e22b1b1b3be32b00000000003be0e1e21b001600001b000000000000001b1b1b00000000001100000000000000111111110000003bc32b00000000003bc0c1c1c22b00003bd32b00000000123bd05353d22b00003bd32b00000000173bd05353d22b00003bd32b00001200003bd05353d22b00003bd32b00001c00003bd05353d22b00003bd32b00000000,5353535353535353535353535353535353535353535353535353535353535353e1e153535353535353535353535353530000e0e1e1e1e1e1e153535353535353000000000000000000e053535353535311111100000000000000e0e153535353f1f1f22b0000000000000000d05353531b1b1b00c300000000000000e05353d200000011d0c200000000000000d053d2000011c053d200000000000000d053e20011c05353d200000016000000e0d20000c0535353d21100000000000000e30011d053535353c2110000000016000000c1535353535353c211110000000000005353535353535353c1c211110000111153535353535353535353c1c21111c0c1,535353535353535353535353c1c1535353e1e1e1e1e153535353e1e1e1e1e1e2e20000000000e0e1e1e200000000001b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000c0530000000000000000000000000000d05300000000000000000000000000c05353000000000000000000000000c0535353000000000000000000000000d05353530000000000000000000000c053535353000000c0c1c2000100c0c15353535353000000d05353c1c1c153535353535353,53d2000000000000000000000000000053d2000000160000000000160000000053d2000000000000000000000000000053e20000000000000000000000000000d2000000000000000000000000000000d2000000000016000000000000000000e2000000000000000016000000000011000000000000000000000000000011c00000000000000000000000000011c05300000016000000000000001111c053530000000000000000111111c0c15353530000000000001111c0c1c15353535353160000111111c0c15353535353535353111111c0c1c1535353535353e1e1e1e1c0c1c15353535353535353e200000000535353535353e1e1e1e1e20000000000,e1e1e1e1e1e200000000000000000000000000000000000000000000000000111100000000000000000000001a0011f3c300000000000000000000000011f300d3000000000000000000000011f30000d0c200000000000011111111f3000000d0d200000000003bf0f1f1f20000000053d20000000000003b3b3b3b000000005353c2000000003bf0f1f1f2000000005353d200000000000000f300000000005353d2110011111111f3000000000000535353c23bf0f1f1f200000800000000535353d2001b1b1b0011000000000000535353d20000000000c32b000000000053535353c200000000d32b000000000053535353d20000003bd32b0000000000",
 [14]="0000e0e1e1e1e153535353535353535300000000000000e0e1e153535353535300000000000000000000e0e15353535300000000000000000000004fe053535300000000000000000000000000e053530000000000000000000000000000d0530000000000000000000000000000e053c20000000000000000000000000000e053c200000000000000000000000000005353c2000000000000000000000000005353d200000000000000000000000000535353c2000000000000000000000000535353d200000000000000000000000053535353c2000000000000000000000053535353d200000000000000000000005353535353c1c2000000000000000000,53535353535353c2000000000000000053535353535353d200000000000000005353535353535353c1c211111111111153535353535353535353c1c1c1c1c1c153535353535353e1e1e1e1e1e1e15353535353e1e1e1e200000000000000e0e15353e20000000000000000000000000053d2000000000011000000000000000053d20000000000c3000000000000000053d20000000000d3000000000000000053d20000000000d3000000000000000053d200000000c0d2110000000000000053d200000000d053c2000000000000005353c20100c05353d211000000000000535353c1c153535353c211111111111153535353535353535353c1c1c1c1c1c1,535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353e1e1e1e1e1e1e1e1e1e15353535353e21b1b1b4f1b1b1b1b4f1b53535353d24f0000000000000000000053535353e20000000000000000000000535353d21b0000000000000000000000d05353e2000000000000000000000000e053d21b0000000000000000000000001bd0e20000000000000000000000000000e31b00000000000000000000000000004f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000,00000000000000000000000000000000000000000011111111c311111111c3111111111111c0c1c1c153c1c1c1c153c1c1c1c1c1c1535353535353535353535353535353535353535353535353535353e1e1e1e1e1e1e1e1e1e1e1e1e1e1e1e10000000000000000001100000000111100000000000000003bc32b00003bf0f200001100000000003be32b0000001b1b003bc30000000000001b000000001111003bd3000000110000160000003bf0f1003bd300003bc3000011000000001b1b003bd300003bd3003bc32b0000000000003bd3001111d31111d31111111111111111d311c0c153c1c153c1c1c1c1c1c1c1c153c1535353535353535353535353,535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353e1e1e1e1e1e1e1e1e1e15353535353531b1b1b4f1b1b1b1b1b1be05353535353000000000000000000001bd0535353530000000000000000000000e05353535300000000000000000000001be05353530000000000000000000000001bd0535300000000000011000000000000e05353000000000000c30000000000001be053000000000000d3000000000000004fe0000000000000d300000000000000001b000000000000d3000000000000000000000000000000d3000000000000000000000000000000d3000000000000000000,000000000000d3000000000000000000111111c31111d3120000000000000000c1c1c153c1c153c1c1c1c200000000005353535353535353535353c1c1c1c1c153535353535353535353535353535353e1e1e1e1e153535353535353535353530000000000e0e15353535353535353532b000011000000e0e1e1e1e1e1e1535316003bc300000000000000000000e0e111113be3001111111111001600000000f1f22b1b00f0f1f1f1f22b11111111111b1b000000001b1b1b1b3bf0f1f1f1f10000000000000000000000000000000011000000110000000011000000000000c2111111c311111111c311000000000053c1c1c153c1c1c1c153c22b00004000,535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353535353d0535353535353535353535353535353e0e153535353535353535353535353534f00e0e15353535353535353535353530000001be05353535353535353535353,0000000000e053535353535353535353000000000000e053535353535353535300000000000000e0e153535353535353c20000000000000000e0e1535353535353c1c1c1c2000000000000e0e15353535353535353c1c2000000000000e0e1e153535353535353c1c200000000000000535353535353535353c2000000000000e1e1e1e1e1e1e1e1e1e1f1f1f2000000000000000000000000000000000000c0110000160000000000000000000000d0f200000000000000000000000000c0533b00000000000000000016000000e0533b1600001600001600000000000000e03b0000000000000000000000000000003b000000000000000000000000000000",
 [15]="535353535353535353535353535353d25353535353535353535353535353e1e2535353535353d1535353535353e2c0c1535353535353535353535353e2c053535353535353535353535353d2c05353d15353d153535353535353e1e2d05353535353535353d153e1e1e21b1be0e15353535353535353e21b1b1b00001b1be0e153535353e1e21b000000000000001b3b535353d21b1b00000000000000000000535353e22b00000000000016000000005353e21b00000000000000000000000053d21b0000000000000000000011111153e22b00000000000000111111c0c1c1d21b0000000000000011c0c1c1535353e2000000000000003bc0535353535353,1b0000000000001111d0535353d1535300000000001111c0c1535353535353530000000011c0c1535353d1535353e1e10000003bf053535353535353e1e21b1b000000001be0e1535353e1e21b1b000000000000001b1be053e21b1b00000000000000000000001be31b00000000000000610000000000001b000000000011110000000000000011000000000011c0c10000000000003bf32b0000163bc05353111100000000001b0000000011d05353c1c22b00000000000000003bc05353d153d211110016000000000011e0e153535353c1c22b00000000003bc0c1c2e0e1535353d211000000000011d05353c1c25353d153c22b0000003bc05353d15353,53535353d2110000003bd053535353535353535353c21100163be05353535353e05353535353c21111113be05353e1e200e0e153535353c1c1c2113be0e21b1b000000e0e1e1e1e1e1e1f2001b1b000011111111111111111111111100000000c1c1c1c1c1c2f0c1c1c1c1c211111111535353535353c2d053535353c1c1c1c2535353535353d2d05353535353535353535353d15353d2d0d15353535353d153535353535353d2d05353535353535353535353535353d2e0e1e1e1e1e1e1e1e153535353e1e1e200000000000000000053d153d2000000000000000000000000535353d2001a00000000110000000000535353d200000000003bc32b00000000,d05353535353535353d2110000000000d0535353535353535353c2000000000053535353535353535353d21100000000535353d15353d153535353c2000016005353535353535353535353d211000000535353535353535353535353c22b0000535353535353535353535353d22b0000535353535353535353535353d22b0000e0e1e1535353535353535353e22b00001b1b3be0e153535353d153d21b0000000000001b1be05353535353e22b00000000000000003be0e1e1e1e21b000016001100000000001b1b1b1b1b0000000011c21100160000000000000000000000c053c211000000000000001600001111d05353c211110000000000111111c0c153,535353c1c21111111111c0c1c15353535353535353c1c1c1c1c1535353535353e15353535353535353535353535353531be0e153535353535353535353535353001b1be0e1e153535353d1535353d1530000001b1b1be05353535353535353530000000000003be05353535353535353111100000000003bd053535353535353c1c211110000003be0535353535353535353c1c2110000003bd053535353535353535353c22b00003bd053535353535353535353d22b00003bd053535353535353535353e22b00003bd053535353d153535353e21b0000003bd0535353535353e053d21b0000003bc05353d153535353c2d0e2000000003bd053535353535353,d2e31b000000003be0e1e1e1e1e1e1e1e21b000000003bc0c1c1c1c1c1c1c1c11b00000000003bd053535353535353530000000000003bd0535353535353535300000000003bc053535353e1e1e1e1e1000000003bc053e1e1e1e21111111111000000003be0e211111111c0c1c1c1c111110000001111c0c1c1c2d053535353c1c22b003bc0c1535353d2e05353d15353d22b613bd05353535353c2e0e1535353d22b003bd05353d15353d2003bd053e1e22b003bd05353535353d2013bd053001b00003be0e1e1e1e1e1e2173bd05300120000001b1b1b1b1b0000003bd053001c00000000000000000000003bd053000000000000000000000000003be0e1",
 [16]="c2e0535353d153535353535353e2d05353c2e0535353535353d15353d2c053535353c2e0e153535353535353e2d05353535353c1c2e0535353d153d2c053d15353d1535353c2e0e1535353e2d0535353535353535353c1c2e0e1e2c05353535353535353535353d2c0c1c15353d153d2535353d1535353e2d0535353535353e2e1e153535353e2c0535353d15353d229c1c2e0e1e1e2c053535353535353e2005353c1c2c0c153535353535353d22900535353d2d053535353d1535353e2002d53d153d2d053d15353535353d2290000535353e2e0e1535353535353e2002d005353e2c0c1c2e05353d153d229000000e1e2c0535353c2e0e1e1e1e2002d0000,0000e0e1e1d153c1c1c1c22b000000000000000000e053535353e22b0000000000000000002ad0d153d22b00000000000000003a3900e05353e22b0000000000000000f3c3392ae0d22b000000000000000000f0d2f3392ae32b0000000000000000002ad0c1c2392a3900000000000d00000000e0e153f1f1f2000000000000000000002af3e300000000000000000000000000c0c20000000000000000000000000012e0e200000000000000000000390000c0c200000000000000000000002a3900e0e200000000000000000000000028c0c2000000000000000000000000002ae0e21100000000000000000000000000c0c1c20000000000000000000000,0000e0e1e21100000000000000000000000000c0c1c211111111111111110000390000e05353c1c1c1c1c1c1c1c2111110393a29e0e1e1e1e1e1e1e153d2c0c12a3829000011c0c1c1c2292ae0e2d053162a39393ac0535353e20000002ae05300002a0011d053e1e21b000000002ae00000002ac053e21b1b0000000000002a00000011e0e21b000000111100000000000011c0c21b00000011c0c2110000000011c053e200001111c05353c200000000c053e21b0011c0c1535353e200000000e0e21b0000f0e1e15353e21b000000162a29000011c0c1c2e0d21b00000000003a390011c0535353c2e300003ac0c1002d2d00c053535353e21b003ac05353,5353d2290000000000000000000000005353e2002d000000000000000000000053d2290000000000000000000000000053e2002d000000000000000000000000d2290000000000000000000000000000e2002d0000000000000000000000000029000000000000000000000000000000002d0000000000000000000000000000000000000000000000000000000000002d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000,00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000,000000000000000000000000000000000000000000000000000000000000000011000000000000000000000000000000c211110000000000000000000000000053c1c2000000000000000000000000005353d211000000000000000000000000535353c2110000000000000000000000d053d153c20000000000000000000000e0e15353d21100000000000000000000002ae0e1e1f21100000000000000000000002ac0c1c1c2000000000000000000000000d05353d211000000000000000000003ad0535353c20000000000000000013ac05353d153d21100000000000000c1c2e05353535353c2000000000000005353c2e053535353d200000000000000",
 [18]="000000000000000000000011000000000011000000007600000000c30000000000c300000000c32b000000d30000000000d300000000d32b000000d30000000000d300000000e32b110000e30011000000e3000000001b00c300001b00c30000001b000000000000d300000000d300000000001100000000d300000000d30000000000c300000000e300160000e30000000000d3000000001b000011001b0000000000d300000011000000c300000000000000e3000000c3000000d3000000000000001b000000d3000000d30000000000000000000000d3000000e30000000000000000001100e30000001b000011000000160000c3001b000000000000c300,0000110000d30000001100000000d300003bc32b00d3000000c300000000d300003bd32b00e3000000d300000000e300003bd32b001b000000d3000000001b00003be32b0000000000e300000000000000001b0000000000001b0000000000000000000000000000000000000000000011000000000000000000000000000000c2000000110000000011000000001100d2111111f311111111f311111111c300d1c1c1c1c1c1c1c1c1c1c1c1c1c1d200e1e1e1e1e1e1e1e1e1e1e1e1e153e20000000000000000000000000000e32b0001000000000000000000000000000000c0c20000000011000000000000000000e0e200000000c32b0000000000000000"
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
  number\=16
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
000000000000000000000000082888800000000000000000000000000000000000aaaaa0000aaa000000a0000007707770077700da9a9a999a9a9999999a999d
000000000828888008288880823288880828888008888200000000000222888000a000a0000a0a000000a00007777776777777709999e9a999a999aaa9e9a999
000000008232888882328888832ffff882328888888823200828888083f1ff1800a909a0000a0a000000a00077666666677677779a9eeeeeeee9aa9eeeee9aa9
00000000832ffff8832ffff888f1ff18832ffff88ffff2308232888888fffff8009aaa900009a9000000a000767776667666667799eeeeeeeeeeeeeeeeeeee99
0000000088f1ff1888f1ff1808fffff088f1ff1881ff1f80832ffff888fffff80000a0000000a0000000a00000000000000000009aeeeeeeeeeeeeeeeeeeeeea
0000000008fffff008fffff00033330008fffff00fffff8088fffff8083333800099a0000009a0000000a0000000000000000000a9ee99eeeeeeeeeeeeeaeee9
00000000003333000033330007000070073333000033337008f1ff10003333000009a0000000a0000000a00000000000000000009aeeaeeeeeeeeeeeeeeeee99
000000000070070000700070000000000000070000007000077333700070070000aaa0000009a0000000a00000000000000000009eeeeeeeeeeeeeeeeeeeeea9
dddddddd00000000000000000000000000000000000000000006600049999994499999944999099401112220666066609a9aa9a9000000000000000070000000
dddddddd0000000000000000000000000000000000000000006886009111111991114119911409191111222267606760a9aeea9a007700000770070007000007
dd0000dd0000000000000000000000000aaaaaa0000000000688886091111119911191194940041911cc8822677067700eeeeee0007770700777000000000000
dd0000dd007000700499994000000000a998888a11111111688888869111111994940419000000441ccde8880700070000eeee00077777700770000000000000
dd0000dd007000700060060000000000a988888a10000001688ee886911111199114094994000000cdcc88e80700070000000000077777700000700000000000
dd0000dd067706770006600000000000aaaaaaaa1111111106e88e609111111991119119914004990cdce8800000000000000000077777700000077000000000
dddddddd067606760060060000000000a980088a14444441006ee6009111111991141119914041190ccc8e800000000000000000070777000007077007000070
dddddddd066606660006600004999940a988888a144444410006600049999994499999944400499400dce8000000000000000000000000007000000000000000
d99a999dda9a9a999a9a9999999a999da9444444444444444444449ad999999ddddddddddddddddddddddddd0000000007777770000000000000000000000000
99a9a9a9999999a999a999aaa999a9999994444444444444444449a99a9a9a99ddddddddddddddd00ddddddd6670000077777777000000000000000000000000
9a9499999a9a444449a9aa9444449aa9a9a4444444444444444449999999999adddddddddddddd0000dddddd6777700077777777000990000000000000000000
a944449a999444444449a4444444499999a94444444444444444a99a99a449a9ddddddddddddd000000ddddd6660000077779977009aa9000000000000000000
9a4444999a444444444444444444449a99a944444444444444449999aa44449adddddddddddd00000000dddd000000007777997709aaaa900000000000000000
a99449aaa944994444444444444a4499a99444444444444444444a9999444499ddddddddddd0000000000ddd6670000079779997090aa0900000000000000000
9a999a999a44aa444444444444444499999444444444444444444999a94a44aadddddddddd000000000000dd677770007999aa97009aa9000000000000000000
d9a99a9d9944444444444444444444a9aa444444444444444444449a9a444499ddddddddd00000000000000d666000000999aa90000990000000000000000000
a9444499a94444444444444444444499d99999999a99999999aa999da99444a9ddddddddd00000000000000d0000066609999990000000000000000000000000
99a4449a9a444444444444444444449a99aa9999999a9a9aa9999a9a99a44999d0dddddddd000000000000dd0007777609a999900000000000aa0aa000000000
9a9444999944944444444444499444a9a9994449a9a999999444a99999944a99dddd00ddddd0000000000ddd00000766099999900000000000aaaaa000000090
a94449aaa94444444444444449a4449a99944444949999444444499a9a44499adddd00dddddd00000000dddd000000000999a99000000000000a9a00000000a0
9944499999944444444994444444499999a44444449a9a4944444999994444a9ddddddddddddd000000ddddd00000666009999000000a00000aaaaa000000a90
9a944a999a99444449a9a99444449aa9aa99444999a99999944499a9a9444499dd0ddddddddddd0000dddddd0007777600044000000a000000aa3aa009000a00
9a94499aa999999a9999999999a9999999a9999a99999a99a9999a9999a44a9addddddddddddddd00ddddddd0000076600044000090a00900000b00000a0a900
a94444a9d99a99a9a9a999a9a99a9a9dd9a99a99a9a9999a9a9a9a9dda999a9ddddddddddddddddddddddddd0000000000999900090990900000b00000909900
0000000000000000da9a9a999a9a9999999a999dd999999d00000000000000004444444400000000777d00000070070000000000000000000000000007000070
0000000000000000999999a999a999aaa999a9999a9a9a9900777000000000004a94444400000000e777000006760760000000007000000006760760070c0070
00d77d00000000009a9aeeeee9a9aa9eeeee9aa99999999a077777777000000044a9944400000000ee77000007776770000000060700000077777777070c0070
0077e70000000000999eeeeeeee9aeeeeeeee99999aee9a90764477777777000449aa94400000000e77700000076676000000660070000000076666007000070
007e7700d777777d9aeeeeeeeeeeeeeeeeeeee9aaaeeee9a774544774767770044499a4490000000e77700000676670000006000070000000666670007000070
00d77d0077777777a9ee99eeeeeeeeeeeeeaee9999eeee9974455474545577774444a9440a000000ee770000077677700000600007000000777777770700c070
0000000077e77e779aeeaaeeeeeeeeeeeeeeee99a9eaeeaa7644444454544577444444a400990000e7770000067067600006000000700000067067600700c070
000000007eeeeee799eeeeeeeeeeeeeeeeeeeea99aeeee9906455454444455474444444400009a00777d00000070070000600000007000000000000007000070
0000d7777eeeeee7a9eeeeeeeeeeeeeeeeeeee9aa9eeee990c644445454444400000000000000000000000000000000000600000007000000000000000000000
0000777e77e77e77999eeeeeeeeeeeeeeeeee9a999aeee9a0cc60444454554770000000000000000000000000000000066000000007000000000000000000000
000077ee77777777a9aeeeeeeeeeeeeeeeeee9999a9eee9900c00444444466600000000000000000000000000000000600000000000000000000000000000000
0000777ed777777d99a9eeeeeeeeeeeeeeeea99aa9eee9aa00c00444400cc0000000000000000000000000000000007000000000000000000000000000000000
0000777e0000000099a9eeeeeeeeeeeeeeee999999eee999000004444000c000ddddddddaaaaaa000aaaaa00aa000600aa000000bbbbbb000bbbbb00bbbbbb00
000077ee00000000a99eeeeeeeeeeeeeeeeeea999a9eea990000444440000000ddddddddaaaaaaa0aaaaaaa0aa000600aa000000bbbbbbb0bbbbbbb0bbbbbbb0
0000777e00000000999eeeeeeeeeeeeeeeeee9999a9ee99a0000444400000000ddddddddaa000000aaa0aaa0aa000000aa000000bb000000bb00000000bb0000
0000d77700000000aaeeeeeeeeeeeeeeeeeeee9aa9eeeea90000444400000000dddddddd99990000990009909900000099000000aaaa0000aaaaaaa000aa0000
0000000000055000a9eeeeeeeeeeeeeeeeeeee99a99eeea900777700d00000000000000d99000000999999909900009099000090aa000000000000a000aa0000
00cccccc005dd5009aeeeeeeeeeeeeeeeeeeee9a99aee99907000070dd000000000000dd99000000990009909999999099999990aaaaaa00aaaaaaa000aa0000
0cdddddd05dddd5099ee9eeeeeeeeeeee99eeea9999eea9970770007ddd0000000000ddd99000000990009909999999099999990aaaaaaa00aaaaa0000aa0000
cddccccc5dddddd5a9eeeeeeeeeeeeeee9aeee9a9aeee99a70778807dddd00000000dddd00000000000000000000000000000000000000000000000000000000
cdcccccc005dd500999eeeeeeee99eeeeeeee99999eeeea970088807dddddddddddddddd00000000000000a90000000000000000000009000000000000000000
cddddddd005dd5009a99eeeee9a9a99eeeee9aa9a9eeee9970088807dddddddddddddddd00000000000009000000000000000000000009000000000000000000
cddddddd005dd500a999999a9999999999a9999999aeea9a07000070dddddddddddddddd00000000000a90000000000000000000000009000000000000000000
cddddddd00055000d99a99a9a9a999a9a99a9a9dda999a9d00777700dddddddddddddddd00000000009000000000000000000000000000900000000000000000
cccccccc00000000d99999999a99999999aa999dd99a999d004bbb00004b000000400bbb000000000900000000000000aa000000000000a00000000000009000
c1d1d1c10000000099aa9999999a9a9aa9999a9a99a9a9a9004bbbbb004bb000004bbbbb000000a9a000000000000000aaaaaa00000000090000000000000a00
c1d1c1c100000000a999eee9a9a999999eeea9999a9e999904200bbb042bbbbb042bbb00000009000000000000000000aaaaaaa0000000009000000000000900
c1d111cc00000000999eeeee9e9999eeeeeee99aa9eeee9a040000000400bbb00400000000000900000000000000000000000000000000000900000000000090
c1ddddcc0000000099aeeeeeee9a9ae9eeeee9999aeeee990400000004000000040000000000900000000000bbbbbb0000000000000000000900000000000009
c1d111dd00000000aa99eee999a999999eee99a9a99ee9aa4200000042000000420000000000900000000000bbbbbbb0000000000000000000a0000000000000
c1d1c1110000000099a9999a99999a99a9999a999a999a99400000004000000040000000009a000000000000bb00000000000000000000000009000000000000
c1d1dddd00000000d9a99a99a9a9999a9a9a9a9dd9a99a9d4000000040000000400000009000000000000000aaaa000000000000000000000000900000000000
36353535353535353536363645000d35353535353535353535353535351e1e1e1e1e1e1e1e1e1e3535351e1e1e1e353535450000000026353535353535354500
00000025353547b20000000000000000456111112434343435353535353535350000000000000000000c352d11000000b10e351ca40000000000000000000000
0026353535353536460000a155000d3535353535353535353535351e2e000000000000110000b10e352d801111000e3535460000000000263535353535354600
000011253545b10061000000000000004500273735353535353535353535353500000000000000000535352e4411006100b10e352c0000000000000000000000
0000263535364600000000b355000e1e1e1e1e1e1e1e353535352e00000000000000003c110000b10e2d110c2c00000d46000000110000002635353535450000
001124353545000000000000000000004500b1b126363636353535353535353500000000000000051c352e243544b2000000b10d35a400000000000000000000
000000264600000000243434450000000000000000000e35352e0000000000000c1c1c352cb26100b10e1c352d00000e00000011540000610026363535460000
0024353535450000000000000000000045000000b1b1b1b12636363636353535000000000000000c352d24353545b2006100b30e351ca4000000000000000000
00000000001111540026363636343434373744000000000d2d0000000000000c35353535352cb20000000e1d2d00000000000024451100000000002646000000
112535353545000000000000000000004500000000000000b1b1b1b1b12636350000000000000535352e253535451100000000b10e352c000000000000000000
00000000002434450000000000263646000026470061000e2e0000000c1c1c35351e1e1e1e1e2fb20000000d2d00000000000025354411111100000000000000
243535353546b200000000000000000045000000000000000000000000b1b1250000000000051c352e243535353544b200006100b10d35a40000000000000000
0000000024353545000000000000000000000000000000000000000c35351e1e2e000000000000000000000e2d00000000000025353534344411000000000011
2535353545b1000000000000000000004500000000b00000000000000000002500000000051c352d243535353535451100000000b30d352c0000000000000000
00000000263535450000000000000000000000000000000000b30f1e1e2e00000000000000000000000000000e2c00000000002535353535354411d000001124
3535353545000061000000000000000045000000000000000000000000000025000000000c35352e2535353535353544b2000000b30e352d0000000000000000
0000000000253546000000000000000000000000000000000000b10000000000000000000000000000000000003e000000000025353535353535440000002435
35353535450000000000000000000000450000000000000000000000000000250000000535352d2435353535353535451100610000b10d35a400000000000000
00000000002645000000000000000000000000000000000000000000000000001100000000000000002100000000000000000025353535353535450000002535
35353535450000000000000000000000450000000000000000000000002100250000051c35352e25353535353535353544b2000000b30e351ca4000000000000
00000000000055000000000000000000000000000000000000000000000000b354b2000000000000007100000000000000002435353535353535451111112535
363636364600000000000000000000004500000000000000000000000071002500000c35352e0026363635353535353545b200000000b10d352c000000000000
00000000000056000000000000000000000000000000000000000000000000b355b20000c1000000000000000000000000002635353536363636363737373646
0000000000000000000000000000000045000000000000000000000000000025000535352d000000f40026363535353546b200000000b30d352d000000000000
21000000000000000000000000000000000010000000000000000000000000b355b2000000000000000000000000000000000026364600000000000000000000
0000000000000000000000000000000045000000000000000000000000000025000c35352d00e400000000002636364600000000c100b30e3535a40000000000
47000000000000000000000000000000000c1c2c0000000000000000c10000b355b2000000000000000000000000000000000000000000000000000000610000
0000000000000000000000000000000045000000000000000000000000000025000d35352e000000000000000000000000000000000000000d351ca400000000
0000000000000000000000000000b00c1c3535351c1c2c0011000000000000b355b2000000000000000000000000000000000000006100000000000000000000
00000000000000000000000000000000450000000000000000006474000000250c35352e0000000000000000002434440000c100000000000e35352c00000000
00000000000000000000000000000c35353535353535351c2c000000000000b355b2000000000000000000000000000000000000000000000000000000000000
00000000d0000000000000000000000045000000000000000000657500243435351e2e000000000000000000d32535450000000000000000b10e3535a4000000
d7777777777777777777777dd777777d000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
777777ee777777777777777777777777450000e40000000f1f1c1c1c2c2635352e243444000000000000000024353545000000000000000000b10d352c000000
7777eeeee777777eeeee777777777777000000670000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
777eeeeeeee77eeeeeeee777777ee7774500000000000000f40e1e35352c253524353545d30000000000d32435353545000000000000000000000e352d000000
77eeeeeeeeeeeeeeeeeeee7777eeee770000003cb200000000000000000000000000000000000000000000000000000000000000000000000000000000000000
77ee77eeeeeeeeeeeee7ee7777eeee7745000000000000000000000e1e2d25353535353544e30000000027363636354500000000000000000000b10d35a40000
77ee77eeeeeeeeeeeeeeee7777e7ee770000b33d11000000000000000000000000000000000000000000000000000000d3000000000000000000000000000000
77eeeeeeeeeeeeeeeeeeee7777eeee774500d0000000000000000000003e253535353535354400f300c200b1b1b1264511111111111111111111110d351ca400
77eeeeeeeeeeeeeeeeeeee7777eeee770000b30d2cb200000000000000000000000000000000000000000000000000003200000000000000c4d4000000000000
777eeeeee777eeeeeeeee777777eee7745000000000000000000000000002635353535353535344400c300000000b32634343434343434343737470e35352c00
777eeeeeeee77eeeeeeee777777eee770000b30e2d110000000000000000000000000000000000000000000000000000620000000095a5b5c5d5e5f5b7000000
7777eeeee7e77e7eeeee777777eee77745000000000000000000000000000025353535353536363634344400000000b3263636363636363545b2a1000e352d00
7777eeeee7e7777eeeee777777eee777000000b10e2cb20000000000000000000000b33c1400000000000000000000005232f3000096a6b6c6d6e6f6c7000000
777eeeeee77eeeeeeeeee777777ee77745000000000000000000c100000000253535353646b1b1b12636363434441100b1b1b1b1b1b1b1263544b2000535352c
777eeeeeee777eeeeeeee777777ee77700001400b13d110000000000000000000000110d352c14000000000000000000845232d30097a70000d7e70000000000
77eeeeeeeeeeeeeeeeeeee7777eeee7745000000000000000000000000000025353546b1b1000000b1b1b1263635441161000000006100b1263544b2000e1e35
77eeeeeeeeeeeeeeeeeeee77777eee7700113db2b30d2cb2000000000000000000b30c353535352c0000000000000000522323536300d300f300f79400c20000
77eeeeeeeeeeeeeeeeeeee77777ee777450000000000000000000000000000253546b10000000000000000b1b12635441111111111111100b12635440000000e
77ee7eeeeeeeeeeee77eee77777ee777000c2db2b30e2db2000000000000000000b30d35353535352c14000000000000331222223243535353535363f3c30000
77eeeeeeeeeeeeeee77eee7777eee7774500000000000000000000000000002545b10000000000000000000000b12636343434343434440000b1264661000000
777eeeeeeee77eeeeeeee77777eeee77000d2db261b13d11000000000000000000b30d353535353535351c2c1400100012525284522222222222222222536300
7777eeeee777777eeeee777777eeee7745000000000000000000c100000000254500000000000000000000000000b1b12636363636363544110000b100000000
777777777777777777777777777ee777000d2d1100b30d2cb20000000000000000110d353535353535353535351c1c1c1352525284525284525284233300f400
d7777777777777777777777dd777777d4500000000000000000000000000002546000000000000000000000000000000b1b1b1b1b1b326354400000000000000
d7777777777777777777777dd777777d000d352cb2b30d2db200000000000000b30c353535353535353535353535353532135252525252522323330000000000
7777777777777777777777777777777745000000000000000000000000000025b1000000000000001100000000110000000000000000b32545b2000000000000
7777eee7777777777eee7777777e7777000d352db2b30e2eb200000000000000b30d353535353535353535353535353552321323232352330000000000000000
777eeeee7e7777eeeeeee77777eeee774500001000000000000000000000002500000000100000b357b20000b357b204000000000000b32545b2000000000000
777eeeeeee7777e7eeeee77777eeee770c35352d1100b1b10000000000000000b30d353535353535353535353535353552331222223273000000000000000000
7777eee7777777777eee7777777ee777353434440000000000000000000000250000002434440000b100040000b10000001111110061b32646b2001414000000
777777777777777777777777777777770d3535351c1c1c1c2c00000000000000b30d353535353535353535353535353533125284526200000000000000000000
d7777777777777777777777dd777777d353535354400000000000000000000250024343535354400000000000000000000243444b20000006100000d2d000000
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
0000000000000000000000000000000004020000000000000000000200000000030303030303030304040402020000000303030303030303040404020202020200000303030302020302000002020000000003030303020204020202020202020000030303030004040202020202020200000303030300000002020202020202
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003030303000000000000000000000000030303030000000000000000000000000303030300000000000000000000000003030303000000000000000000000000
__map__
0000000000000000003126000000000000000000003a1010390000000000242500000000000000000000003a1029000032323232323232323232323232323225252525252525253233000000000000001b1b1b1b31252526000000003b2425251b1b31252525252525260000000000242525262b000000003b24252600003125
0000000000000000002a303900000000000000000028383828000000003b2425000000000000002c003a3829000000110000000000000000000000000000003125252525252533000000000000000000000000001b242533000000003b24252500001b312525323225262b00000011242525332b000000003b24252600000024
0000000000000000003a37103900000000000000002a292a29000000003b2425000000000000003c3a29000000003b20000000000000000000000000000000002425252525330000000000000000000000001a003b31261b000000003b2425250000001b3133000024332b000000212525262b0000001a003b24252523000024
0000000000000000002a292a2900003b0000002c00002a2900000000113b24250000000000003f27290000003d3f2122272b0000003d3f1100000000000000003125252526000000000000000000000000000000001b30000000000021252525000000001b000001301b0000003b242525262b00000000003b31252526000024
00000000000000000000000000003b210000003c123f3a390000003b21222525003a39003a0021260000000034352525302b00000021222223110000000000000024252533000000000000000000000000000000003b37000000001124252525000000000000212233000000003b242525332b00000000000000312526003b24
00000000000000000000000058683432003d11212223292a00000034323225253a292a39383d2425230000004f3b3132260000002125252525233d0000000000002425260000000012000000000000000000000000001b00001111212525252500000000002125261b000000003b3125331b0000000000000000003133003b24
675858683900000000003a3829000000003435322526393a393a204f000031323a29003f2a212525263e000000002a39332b00003125323232252300000000000031252600000000170000000000000000000000000000003b3422252525252500000000003125260000000000001b201b00000000000000000000004f003b24
2a6768292a10393d2c11272900000000002a3829313328283829000000000000293d002122252532323600000000002a0000000000374f000024261100000000000024330000000000000000000000000000000000000000000031322525252500000000001b2433000000000000001b00000000000000000011000000003b24
00000000002d11212222253600000000003a283900002a292a39000000000000002122252532331b390000000000000000000000001b0000003125230000000000003000000000000000000000000000000000000000000000004f0031252525000000000000301b0000000000000000000016000000000000273d0000112125
000000000068343225253300000000003a10290000000000002a39000000110100242525332b002a38390000000000000000003f11000000000024260000000000003700000000000000000000000000000000000000000000000000002425250000000000003700000000001100000000000000000000003b2423003d212525
003d00003a38291b31334f00000000002900000000000000003a123d003f2122222532332b000000002a27110000000000000021230000000000242611000000000000000000000000000000000000000000003d1100120000000000002425250000000000000000000000112011001600110000000000003b24252222252525
11203e0129000000000000000000000000000000000000003a1121222222482525262b000000000000212523000000000000002425230000013f24252300000000000000000000000000000000000000000011212222233f110000003d2425250000000000000000001600212223110011271100000000003b24252525252525
22222223113f0000000000000000000000000000000000002a342525254825252533000000000000002425263f00000000003d242525233d212225252600000000000000000000000000000000000000000021252525252222233e01212525250000000000000000000000242525231121252300000000003b24252525252525
252548252236000000000000000000000000000000000000002a313232252548262b00006000000000242525230000000000212525252522252525252600000000000000001200000000000000000000000024252525252525252222252525250000000000000000000000242525252225252600000000003b24252525252525
25252532330000000000000000000000000000000000003a392900002a312525262b013d00003f1100242525260000000000242525252525252525252600000000000000001700000000000000000000000024252525252525252525252525250000000000000000000000242525252525252600000000003b24252525252525
2548260000000000000000000000000000000000000000293a2a3900002a3125252222222222222222252525260000000000242525252525252525252600000000000000000000000000000000000000000024252525252525252525252525250000000000000000000000242525252525252600000000003b24252525252525
25252525253232323232322525252525262b1b3b52535353535353542b6253535353535353535353542b000000000000323225252525323232323232336263646253535353535353636452540000005253535353535353535353535353d200d00000000000000000000000000000000000000000000000000000000000000000
25252525261b1b1b1b1b1b3125252525332b003b62535353535353542b005253535353535353535353440000000000000000312525260000000000000000000000525353535353640000625400003b52535353535353535353535353e1e200d00000000000000000000000000000000000000000000000000000000000000000
25252525260016001111161b312525260000000000526353535353642b0062535353535353535353535373740000000000000024253300000000001100000000006253535353541b0000006500000052535353535353535353e1e1e21b0000d00000000000000000000000000000000000400000000000000000000000000000
2525252526000000212311001b31252600000000006500625353542b00000062535353535353535353640000c30000c311000031260000000000004511000000001b525353535400000000000000005253535353535353e1e21b1b1b000000e00000000000000000000000000000000000000000000000000000000000000000
252525253300000024252311001b313300000000000000005253542b00000000625353535353535364000000d300f0d2444e000030000000000000524400000000006253535364000000000000003b5253535353e1e1e21b1b000000000000420000000000000000000000000000000000000000000000000000000000000000
252525331b001611242525231100000000000000000000005253642b00000000006263535353535400000000d30000d35400000037000000000011525400000000001b5253541b000000000000003b6253e1e1e21b1b1b0000000000000000520000000000000000000000000000000000000000000000000000000000000000
2532331b000011212525252523003f0000000000000000006254000000000000000000626363636400000000d0f200d3540000004f000000000042535411000000000052536400000000000000000000d21b1b1b0000000000000040000000520000000000000000000000000000000000000000000000000000000000000000
33000000001121252525252525222300000000000000000000550000000000000000001b1b1b1b1b00000000d30000d35411000000000000000052535344000000000062541b00000000000000000000d20000000016000000004000000000520000000000000000000000000000c30000000000000000000000000000000000
00001600112132322525252525252522233d113d3f0000000055000000000000000000000000000000000000d30000d353443f1100003d0000005253535400000000001b550000000011000000000000d200000000000000000000000000005200000000000000000000000000c0d20000000000000000000000000000000000
0000000034330000312525252525252525222235360000000065000000000000000000111111111100000000d0f24bd353534344013e4511001252535354000000000000550000003b72434400000000d200000000000000000000000000005200000000000000000000000000d0534a00000000000000000000000000000000
0000000000000000002425252525252525253300000000000000000000000000000000212222222300000000e30000d353535353434353443d425353535400000000000065000000003b626400000000d200000000000000000000000000005200000000000000000000000000d053c200000000000000000000000000000000
00000000000000000024252525252525252611000000000000000000000000000000343225253233000000000000c0e253535353535353534353535353534344110000004b0000000000000000000000534a0000000000000000000000000052000000000000000000000000f0e153534a000000000000000000000000000000
000000000000000121252525252525252525230000000000004b000000000000000042443133424434360000f0f1e200535353535353535353535353535353d144000000110000000000000000000000d20000000000000000000000000000520000000000000000000000000000e053c14a0000000000000000000000000000
0000000000112122252525252525252525252600000000000000000000000000727363537373636374000000000000005353535353535353535353535353535354000000450000000000000000000000d200000000000000000000000000005200000000000000000000c341001600e053c20000000000000000000000000000
0000000000212525252525252525252525252600000000000d00000000000000000000651a00160000001600000000005353536363535353535353535353535364000011524400000000000000000000e200000000000000111111111111115200000000000000000000d0d22b00001bd0534a00000000000000000000000000
0000000000242525252525252525252525252600000000000000000000000000000000160000000000000000000000005353640000625353535353535353536400000042535400000000000000000000440000001111111142434343434343530000000000000000005053d22b16003be053c14a000000000000000000000000
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
002000201310000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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

