pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- ~caligo~
-- matt thorson + noel berry + @gunturtle

-- globals --
-------------

room = { x=0, y=0 }
objects = {}
types = {}
freeze=0
shake=0
will_restart=false
delay_restart=0
got_fruit={}
has_dashed=false
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

-- entry point --
-----------------

function _init()
	title_screen()
end

haz_fruit=false

function title_screen()
	got_fruit = {}
	for i=0,29 do
		add(got_fruit,false) end
	frames=0
	deaths=0
	max_djump=1
	start_game=false
	start_game_flash=0
	music(40,0,7)
	
	load_room(7,3)
	--begin_game()
end

function begin_game()
	frames=0
	seconds=0
	minutes=0
	music_timer=0
	start_game=false
	music(0,0,7)--start here
	load_room(0,0)
end

function level_index()
	return room.x%8+room.y*8
end

function is_title()
	return level_index()==31
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
		this.spr_off=0
		this.was_on_ground=false
		this.spinning=false
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
				accel=0.3
	--[[		elseif on_ice then
				accel=0.1
				if input==(this.flip.x and -1 or 1) then
					accel=0.1
				end--]]
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
			--[[
			if input!=0 and this.is_solid(input,0) and not this.is_ice(input,0) then
		 	maxfall=0.4
		 	if rnd(10)<2 then
		 		init_object(smoke,this.x+input*6,this.y)
				end
			end--]]

			if not on_ground then
				this.spd.y=appr(this.spd.y,maxfall,gravity)
			else
				this.spinning=false
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

				end
			end

					-- wall jump
			if this.spinning and input!=0 then
				local wall_dir=(this.is_solid(-1,0) and -1 or this.is_solid(1,0) and 1 or 0)
				if not this.is_ice(wall_dir,0) and wall_dir!=0 and input==wall_dir then
			 	psfx(2)
			 	this.jbuffer=0
			 	this.spd.y=-2
			 	this.spd.x=-wall_dir*(maxrun+1)
			 	this.spinning=false
			 	if not this.is_ice(wall_dir*3,0) then
		 			init_object(smoke,this.x+wall_dir*6,this.y)
					end
				end
			end
		
			-- dash
			local d_full=5
			local d_half=d_full*0.70710678118
		
			if this.djump>0 and dash then
		 	init_object(smoke,this.x,this.y)
		 	this.djump-=1		
		 	this.dash_time=4
		 	this.spinning=true
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
		 	if this.wind then
		 		init_object(madblock,this.x,this.y)
		 		this.wind=false
		 	end		 	
		 	psfx(3)
		 	--freeze=2
		 	shake=6
		 	this.dash_target.x=2.2*sign(this.spd.x)
		 	this.dash_target.y=2.2*sign(this.spd.y)
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
			elseif dash and this.djump<=0 then
			 psfx(9)
			 init_object(smoke,this.x,this.y)
			end
		
		end
		
		-- animation
		this.spr_off+=0.25
		if not on_ground then
			if this.is_solid(input,0) then
				--this.spr=5
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
		-- next level
		if this.y<-4 and level_index()<20 then next_room() end
		
		-- was on the ground
		this.was_on_ground=on_ground
		
	end, --<end update loop
	
	draw=function(this)
	
		-- clamp in screen
		if this.x<-1 or this.x>121 then 
			this.x=clamp(this.x,-1,121)
			this.spd.x=0
		end
		
		set_hair_color(this.djump)
		draw_hair(this,this.flip.x and -1 or 1)
		if not this.spinning then
			spr(this.spr,this.x,this.y,1,1,this.flip.x,this.flip.y)
		else
			local idxa=flr(time()*20)%5+1
			spr(({73,1,5,5,1})[idxa],this.x,this.y,1,1,({false,false,false,true,true})[idxa],true)
		end
		unset_hair_color()
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
	pal(8,(djump==1 and 8 or djump==2 and (7+flr((frames/3)%2)*4) or 12))
end

draw_hair=function(obj,facing)
	local last={x=obj.x+4-facing*2,y=obj.y+(btn(k_down) and 4 or 3)}
	foreach(obj.hair,function(h)
		h.x+=(last.x-h.x)/1.5
		h.y+=(last.y+0.5-h.y)/1.5
		circfill(h.x,h.y,h.size,8)
		last=h
	end)
end

unset_hair_color=function()
	pal(8,8)
end

player_spawn = {
	tile=1,
	init=function(this)
	 sfx(4)
		this.spr=3
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
				shake=5
				init_object(smoke,this.x,this.y+4)
				sfx(5)
			end
		-- landing
		elseif this.state==2 then
			this.delay-=1
			this.spr=6
			if this.delay<0 then
				destroy_object(this)
				init_object(player,this.x,this.y)
			end
		end
	end,
	draw=function(this)
		set_hair_color(max_djump)
		draw_hair(this,1)
		spr(this.spr,this.x,this.y,1,1,this.flip.x,this.flip.y)
		unset_hair_color()
	end
}
add(types,player_spawn)

stickblck = {
	tile=98,
	init=function(this)
		this.respawn=0
		this.hitbox={x=-2,y=-2,w=12,h=12}
	end,
	update=function(this)
		if this.respawn<=0 then
		local hit = this.collide(player,0,-1)
			if hit!=nil and hit.dash_time>0 then
				hit.dash_time=12
				hit.dash_effect_time=20
				hit.djump=max_djump
				this.respawn=60
				hit.x=this.x
				hit.y=this.y
			end
		end
		this.respawn-=1
	end,
	draw=function(this)
		if this.respawn<=0 then
			local tm=flr(time()*-15)%6
			if tm%2==0 then
				pal(10,9)
				pal(9,10)
			end
			spr(98+tm%3,this.x,this.y)
			pal()
		else
			local tm=60-this.respawn
			for i=0,3 do
				local sc=i+cos(tm/120-0.125)*3.9
				rect(this.x-sc,this.y-sc,this.x+8+sc,this.y+8+sc,9+i/2)
			end
		end
	end
}
add(types,stickblck)

screw = {
	tile=123,
	init=function(this)
		this.last=this.x
		this.solid=true
		this.collideable=true
		--mset(this.x/8+room.x*16,this.y/8+room.y*16,74)
	end,
	update=function(this)
		local hit =  this.collide(player,1,0) or this.collide(player,-1,0) or this.collide(player,0,-2) or this.collide(player,0,1)
		if hit!=nil then
			if (hit.dash_effect_time>0) and this.spd.x==0 and hit.spinning then
					if hit.spd.y<0 and hit.y>this.y then
						this.spd.x=2
						this.collideable=false
					end
					if hit.spd.y>0 and hit.y<this.y and hit.dash_time>0 then
						this.spd.x=-2
						this.collideable=false
						hit.grace=0
					end
			else

				if not this.collideable and abs(this.spd.x)>1.7 then
					hit.spd.y=-sgn(this.spd.x)*2
					if abs(hit.spd.x)<0.5 then
						hit.spd.x=0
					end
				end
			end
			if this.collideable and hit.y<this.y+7 then
				hit.move_x(this.x-this.last,1)
			end
		else
			this.collideable=true
		end
		
		-- spring
		below=this.collide(spring,0,-1)
		if below!=nil then
			below.x+=this.x-this.last
		end		
		if this.check(player,0,0) then
			this.collideable=false
		end
		
		
		this.spd.x*=0.951
		if abs(this.spd.x)<0.2 then this.spd.x=0 end
		this.last=this.x
	end,
	draw=function(this)
		for i=0,this.hitbox.w/8-1 do
			spr(123+this.x%3,this.x+i*8,this.y)
		end
	end
}
--add(types,screw)

spring = {
	tile=18,
	init=function(this)
		this.hide_in=0
		this.hide_for=0
		this.hitbox={x=-1,y=0,w=10,h=8}
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
				--hit.djump=max_djump
				hit.spinning=true
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

function break_spring(obj)
	obj.hide_in=15
end

bigballoon = {
	tile=66,
	init = function(this)
		this.respawn=0
		this.ogx=this.x
		this.ogy=this.y
	end,
	update=function(this)
		if this.respawn<0 then
		if this.attach!=nil then
			this.wttach=true
			this.respawn=0
			local atc=get_player()
			if atc.p_dash==false and btn(k_dash) then
				this.x=atc.x
				this.y=atc.y
				this.spd.x=((btn(k_left) and -1) or (btn(k_right) and 1))or ((atc.flip.x and -1) or 1)
				this.spd.y=0
				this.attach=nil
			end
			if abs(this.spd.x)<1 then
				this.spd.y-=0.1
			else
				this.spd.y=0.1
			end
			if distance(this,atc)>24 then
				local datc=atan2(atc.x-this.x,atc.y-this.y)
				this.spd.x=cos(datc)
				this.spd.y=sin(datc)
				this.move_x((atc.x-cos(datc)*24)-this.x,1)
				this.move_y((atc.y-sin(datc)*24)-this.y,1)
			end
		elseif this.wttach then
			if this.is_solid(sgn(this.spd.x)*2,0) then
				this.spd.x*=-1
			end
			this.spd.x*=0.97
			this.spd.y-=0.01
			local hit =this.collide(player,0,-1)
			if hit!=nil and abs(this.spd.x)<=0.5 then
				hit.spd.y=-2 
			--	hit.djump=max_djump
				hit.spinning=true
				this.respawn=60
				psfx(6)
				init_object(smoke,this.x,this.y)

			end
		else
			local hit = this.collide(player,0,0)
			if hit!=nil then
				this.attach=true
			end			
		end
		else
			if this.respawn==1 then
				this.x=this.ogx
				this.y=this.ogy
				this.attach=nil
				this.wttach=false
				this.spd.x=0
				this.spd.y=0
				init_object(smoke,this.x,this.y)
				psfx(7)
			end
		end
		this.respawn-=1
		if this.wttach and this.respawn<=-90 then
	  this.respawn=6
			init_object(smoke,this.x,this.y)
		end
	end,
	draw=function(this)
		local ofs=(not this.wttach and cos(time()/4)*2.5) or 0
		if this.respawn<=0 then
		spr(66,this.x,this.y+ofs)
		if this.attach!=nil then
			local atc=get_player()
			line(this.x+4,this.y+8,atc.x+4,atc.y,4)
		else
			pal(6,4)
			spr(13+(ofs+this.x)%3,this.x,this.y+8+ofs)
			pal()
		end
		end
	end
	
}
add(types,bigballoon)

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
		obj.delay=15--how long until it falls
		init_object(smoke,obj.x,obj.y)
		local hit=obj.collide(spring,0,-1)
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

fruit = {
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
			--got_fruit[1+level_index()] = true
			haz_fruit=true
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
			--got_fruit[1+level_index()] = true
			haz_fruit=true
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
			init_object(fruit,this.x+4,this.y+4)
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

platform = {
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
		this.text="-- mt. caligo --#this memorial to those#who grew nauseous on#the climb"
		if this.check(player,4,0) then
			if this.index<#this.text then
			 this.index+=0.5
				if this.index>=this.last+1 then
				 this.last+=1
				 sfx(35)
				end
			end
			this.off={x=8,y=96}
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
		 shake=5
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
	tile=102,
	init=function(this)
		--this.spd.y=
		this.solids=false
		this.particles={}
		this.attach=nil
	end,
	update=function(this) end,
	draw=function(this)
		this.spd.y=appr(this.spd.y,0,0.5)
		local hit=this.collide(player,0,0)
		if this.spd.y==0 and hit~=nil then
		 music_timer=45
			sfx(51)
			--freeze=10
			--shake=10			
			hit.wind=true
		end
		
		spr(102,this.x,this.y)
		local off=frames/30
		for i=0,7 do
			circfill(this.x+4+cos(off+i/8)*8,this.y+4+sin(off+i/8)*8,1,7)
		end
	end
}
add(types,orb)

madblock = {
	tile=67,
	init=function(this)
		this.timer=40
		this.collideable=false
	end,
	update=function(this)
		this.timer-=1
		local hit=this.collide(player,0,0)
		if this.timer<=36 and hit==nil then
			this.collideable=true
		end
		--if count(this.type)>1 then
			--destroy_object(this)
		--end
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
		this.spr=118+(frames/5)%3
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
			
			rectfill(24,58,104,70,0)
			--rect(26,64-10,102,64+10,7)
			--print("---",31,64-2,13)
			if room.x==3 and room.y==1 then
				print("old site",48,62,7)
			elseif level_index()==20 then
				print("summit",52,62,7)
			else
				local level=(1+level_index())*100
				print(level.." m",52+(level<1000 and 2 or 0),62,7)
			end
			--print("---",86,64-2,13)
			
			draw_time(4,4)
		end
	end
}

-- object functions --
-----------------------

function init_object(type,x,y)
	--if type.if_not_fruit~=nil and got_fruit[1+level_index()] then
	--	return
	--end
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

	obj.is_solid=function(ox,oy)
		if oy>0 and not obj.check(platform,ox,0) and obj.check(platform,ox,oy) then
			return true
		end
		return solid_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h)
		 or obj.check(fall_floor,ox,oy)
		 or obj.check(fake_wall,ox,oy)
			or obj.check(screw,ox,oy)
			or obj.check(madblock,ox,oy)
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
	haz_fruit=false
	shake=10
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
	if haz_fruit then
		got_fruit[level_index()+1]=true
	end
	haz_fruit=false
 if room.x==2 and room.y==1 then
  music(30,500,7)
 elseif room.x==3 and room.y==1 then
  music(20,500,7)
 elseif room.x==3 and room.y==2 then
  music(30,500,7)
 elseif room.x==4 and room.y==3 then
  music(30,500,7)
 end

	if room.x==7 then
		load_room(0,room.y+1)
	else
		load_room(room.x+1,room.y)
	end
end

function load_room(x,y)
	has_dashed=false
	has_key=false

	--remove existing objects
	foreach(objects,destroy_object)

	--current room
	room.x = x
	room.y = y

	-- entities
	for tx=0,15 do
		for ty=0,15 do
			local tile = mget(room.x*16+tx,room.y*16+ty);
			if tile==11 then
				init_object(platform,tx*8,ty*8).dir=-1
			elseif tile==12 then
				init_object(platform,tx*8,ty*8).dir=1
			elseif tile==123 and mget(room.x*16+tx-1,room.y*16+ty)!=123 then
				wi=0
				while mget(room.x*16+tx+wi,room.y*16+ty)==123 do
					--mset(room.x*16+tx+wi,room.y*16+ty,74)
					wi+=1
				end
				init_object(screw,tx*8,ty*8).hitbox.w=wi*8
			else
			
				foreach(types, 
				function(type) 
					if type.tile == tile then
						init_object(type,tx*8,ty*8)
					end 
				end)
			end
		end
	end
	
	if not is_title() then
		init_object(room_title,0,0)
	end
end

-- update function --
-----------------------

function _update()
	frames=((frames+1)%30)
	if frames==0 and level_index()<20 then
		seconds=((seconds+1)%60)
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
	if freeze>0 then freeze-=1 return end

	-- screenshake
	if shake>0 then
		shake-=1
		camera()
		if shake>0 then
			camera(-2+rnd(5),-2+rnd(5))
		end
	end
	
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
	rectfill(0,0,128,128,bg_col)

	-- clouds
	if not is_title() then
		foreach(clouds, function(c)
			c.x += c.spd
			rectfill(c.x,c.y,c.x+c.w,c.y+4+(1-c.w/64)*12,new_bg~=nil and 14 or 1)
			if c.x > 128 then
				c.x = -c.w
				c.y=rnd(128-8)
			end
		end)
	end

	-- draw bg terrain
	map(room.x * 16,room.y * 16,0,0,16,16,4)

	-- platforms/big chest
	foreach(objects, function(o)
		if o.type==platform or o.type==big_chest then
			draw_object(o)
		end
	end)

	-- draw terrain
	local off=is_title() and -4 or 0
	map(room.x*16,room.y * 16,off,0,16,16,2)
	
	-- draw objects
	foreach(objects, function(o)
		if o.type~=platform and o.type~=big_chest then
			draw_object(o)
		end
	end)
	
	-- draw fg terrain
	map(room.x * 16,room.y * 16,0,0,16,16,8)
	
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
	
	-- draw outside of the screen for screenshake
	rectfill(-5,-5,-1,133,0)
	rectfill(-5,-5,133,-1,0)
	rectfill(-5,128,133,133,0)
	rectfill(128,-5,133,133,0)
	
	-- credits
	if is_title() then
		print("x+c",58,74,5)
		print("original 'celeste' by",24,90)
		print("matt thorson",42,96,5)
		print("noel berry",46,102,5)
		print("mod by @gunturtle",32,114)
	end
	
	if level_index()==20 then
		local p
		for i=1,count(objects) do
			if objects[i].type==player then
				p = objects[i]
				break
			end
		end
		if p~=nil then
			local diff=min(24,40-abs(p.x+4-64))
			rectfill(0,0,diff,128,0)
			rectfill(128-diff,0,128,128,0)
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

	local s=seconds
	local m=minutes%60
	local h=flr(minutes/60)
	
	rectfill(x,y,x+32,y+6,0)
	print((h<10 and "0"..h or h)..":"..(m<10 and "0"..m or m)..":"..(s<10 and "0"..s or s),x+1,y+1,7)

end

-- helper functions --
----------------------
function get_player()
  for obj in all(objects) do
    if obj.type==player or obj.type==player_spawn then
      return obj
    end
  end
end

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
 for i=max(0,flr(x/8)),min(15,(x+w-1)/8) do
 	for j=max(0,flr(y/8)),min(15,(y+h-1)/8) do
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
 for i=max(0,flr(x/8)),min(15,(x+w-1)/8) do
 	for j=max(0,flr(y/8)),min(15,(y+h-1)/8) do
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

function distance(o1,o2)
	return sqrt((o1.x-o2.x)^2+(o1.y-o2.y)^2)
end
__gfx__
000000000000000000000000088888800000000000000000000000000000000000aaaaa0000aaa000000a0000007707770077700000060000000600000060000
000000000888888008888880888888880888888008888880000000000888888000a000a0000a0a000000a0000777777677777770000060000000600000060000
000000008888888888888888888ffff888888888888888880888888088f1ff1800a909a0000a0a000000a0007766666667767777000600000000600000060000
00000000888ffff8888ffff888f1ff18888ffff8888888ff8888888888fffff8009aaa900009a9000000a0007677766676666677000600000000600000060000
0000000088f1ff1888f1ff1808fffff088f1ff18888888ff888ffff888fffff80000a0000000a0000000a0000000000000000000000600000006000000006000
0000000008fffff008fffff00033330008fffff0088888f088fffff8083333800099a0000009a0000000a0000000000000000000000600000006000000006000
00000000003333000033330007000070073333000033330008f1ff10003333000009a0000000a0000000a0000000000000000000000060000006000000006000
000000000070070000700070000000000000070000606000077333700070070000aaa0000009a0000000a0000000000000000000000060000006000000006000
555555550000000000000000000000000000000000000000008888004999999449999994499909940300b0b0666566650300b0b0000000000000000070000000
55555555000000000000000000000000000000000000000008888880911111199111411991140919003b330067656765003b3300007700000770070007000007
550000550000000000000000000000000aaaaaa00000000008788880911111199111911949400419028888206770677002888820007770700777000000000000
55000055007000700499994000000000a998888a1111111108888880911111199494041900000044089888800700070078988887077777700770000000000000
55000055007000700050050000000000a988888a1000000108888880911111199114094994000000088889800700070078888987077777700000700000000000
55000055067706770005500000000000aaaaaaaa1111111108888880911111199111911991400499088988800000000008898880077777700000077000000000
55555555567656760050050000000000a980088a1444444100888800911111199114111991404119028888200000000002888820070777000007077007000070
55555555566656660005500004999940a988888a1444444100000000499999944999999444004994002882000000000000288200000000007000000000000000
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
777ccc7777cc7cccccccccccc77ccc777777ccc7ccc7777c7ccc7777777cc77755550055555000000000055500000766033333300000000000eeeee000000030
77ccc77777ccccccccccccccc77ccc77777cccccccccccccccccc77777ccc777555500555555000000005555000000550333b33000000000000e8e00000000b0
77ccc777777cccccccc77cccccccc777777cccccccccccccccccc77777cccc7755555555555550000005555500000666003333000000b00000eeeee000000b30
777cc7777777ccccc777777ccccc77777777ccc7c77cc77c7ccc777777cccc775505555555555500005555550007777600044000000b000000ee3ee003000b00
777cc777777777777777777777777777777777777777777777777777777cc7775555555555555550055555550000076600044000030b00300000b00000b0b300
77cccc77577777777777777777777775577777777777777777777775577777755555555555555555555555550000005500999900030330300000b00000303300
577775577757777549999994bbbbbbbbbbbbbbbbbbbbbbbb0000000000000000cccccccc00000000000000000000000505050505000000000000000000000000
777777777777777799aaaa993bbbbbb3bbbbbbbbbbbbbbbb0000000000000000c77ccccc08888880500050000000000500000005000000000000000000000000
7777cc7777cc77779aaaaaa933bbbb33bbbbbbbbbbbbbbbb0000000000000000c77cc7cc88888888500050000000000500000000000000000000000000000000
777cccccccccc7779aaaaaa9333aa333bbbbbbbbbbbbbbbb0000000000000000cccccccc88ffff8850505050000000050000000d0d0d0d000000000000000000
77cccccccccccc77999aa999333aa333bbbbbbbbbbbbbbbb0002eeeeeeee2000cccccccc881ff18850505050000000000000000d00000d000000000000000000
57cc77ccccc7cc759999999933111133bbbbbbbbbbbbbbbb002eeeeeeeeee200cc7ccccc08ffff8050005000000d0d0d0d00000d00000d000000000000000000
577c77ccccccc7750244442031111113bbbbbbbbbbbbbbbb00eeeeeeeeeeee00ccccc7cc0033330050005000000d00000d00000dd000dd000000000000000000
777cccccccccc7770999999011111111bbbbbbbbbbbbbbbb00e22222e2e22e00cccccccc0006060000000000000d0000dd0000000000d0000000000000000000
777cccccccccc777666d666d666d666d666d6665666d666500eeeeeeeeeeee00000000000000000000000000000dd000d00606060600d0505050000000000000
577cccccccccc777666d666d666d666d666d6665666d666500e22e2222e22e000000000000000000000000000000d000d00600000600d0000050000000000000
57cc7cccc77ccc75666d666d666d666d666d6665666d666500eeeeeeeeeeee000000000000000000000000050505d000d00600000600d0000050d0d000000000
77ccccccc77ccc775dddddddddddddddddddddd5ddddddd500eee222e22eee000000000000000000000000000000d000000000000000cc00055000d000000000
777cccccccccc7775666d666d666d666d666d6665666d66600eeeeeeeeeeee005555555500000000000006060600c00000000000000000c0050000d000000000
7777cc7777cc77775666d666d666d666d666d6665666d66600eeeeeeeeeeee00555555550000000000000600060c0000000000000000000c050000d000000000
77777777777777775666d666d666d666d666d6665666d66600ee77eee7777e005555555500000000000000000cc000000000000000000000ccc000d000000000
57777577775577755ddddddddddddddddddddddd5ddddddd07777777777777705555555500000000060600000000000000000000000000000000000000000000
00000000000000009999999999999999aaaaaaaabbbbbbbb00000000500000000000000500000000060000666006660066000666600666000666006060000000
00aaaaaaaaaaaa00999999999aaaaaa9a999999abbbbbbbb0bbbbbb0550000000000005500000000060006666066666066000666606666606666600060000000
0a999999999999a099aaaa999aaaaaa9a999999abbbbbbbb03bbbb30555000000000055500000000066006600066066066000066006600006606600060000000
a99aaaaaaaaaa99a99aaaa999aa99aa9a99aa99abbbbbbbb033aa33055550000000055550000000000600dd000ddddd0dd0000dd00dd0dd0dd0dd00660000000
a9aaaaaaaaaaaa9a99aaaa999aa99aa9a99aa99abbbbbbbb033aa33055555555555555550000000000600dddd0ddddd0dddd0dddd0ddddd0ddddd00600000000
a99999999999999a99aaaa999aaaaaa9a999999abbbbbbbb03311330555555555555555500000000006000ddd0dd0dd00ddd0dddd00dddd00ddd000600000000
a99999999999999a999999999aaaaaa9a999999abbbbbbbb0311113055555555555555550000000000cc000000000000000000000000000000000c0000000000
a99999999999999a9999999999999999aaaaaaaabbbbbbbb000000005555555555555555000000000c000000000000000000000000000000000000c000000000
aaaaaaaaaaaaaaaabbbbbbbbbbbbbbbbbbbbbbbb07777770004bbb00004b000000400bbb00000000c0000000fffff666fffff666eeeee666000000c000000000
a49494a11a49494abbbbbbbbbbbbbbbbbbbbbbbb70007777004bbbbb004bb000004bbbbb0000000100000000ffffffffffffffffeeeeeeee000000c00c000000
a494a4a11a4a494abbbbbbbbbbbbbbbbbbbbbbbb70c7770704200bbb042bbbbb042bbb00000000c000000000fffffeeeffffffffeeeeefff0000001010c00000
a49444aaaa44494abbbbbbbbbbbbbbbbbbbbbbbb70777c07040000000400bbb0040000000000010000000000eeeeeeeeffffffffffffffff00000001000c0000
a49999aaaa99994abbbbbbbbbbbbbbbbbbbbbbbb777700070400000004000000040000000000010000000000eeeeeeeeffffffffffffffff0000000000010000
a49444999944494abbbbbbbbbbbbbbbbbbbbbbbb77700c074200000042000000420000000000010000000000eeeeeeeeeeeeefffffffffff0000000000001000
a494a444444a494abbbbbbbbbbbbbbbbbbbbbbbb700000074000000040000000400000000000000000000000ffffffffeeeeeeeeffffffff0000000000000000
a49499999999494abbbbbbbbbbbbbbbbbbbbbbbb077777704000000040000000400000000001000000000000fffff666eeeee666fffff6660000000000000010
525223232333132323233382828282422232000000000000000000000000008252525252624252620000868282828225a2828282934252525262425252525252
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
526283828292000000123282838292425262000000000000000000000000a382522323233313233300a382828282822500a20182824223232333132323232352
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
523382820000240000426282920000425262000000000000000000a382828282620000a382828255828282828282822500000000a273b1b1b1b1b1b1b1b1b142
000000000000a3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
33123282000000000013339200000042526200000000000000002535353535353310a38282828255828292000000a2250000000000b100000000000000000042
00000000000001000093000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
43233392000000000000000000000042233300000000000000002535353535352222223200a28255829200000000007272000000000000000000000026000042
00000000a30082000083000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000004235450000002400000000828282828282232323330000a255000000000000a30303000000002600001111110000000042
00000000827682000001009300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
006100000000000000000000000000423545a1000000000000008282828282828292000000000055000000110000827303111111111111111222327661000042
00000000828382670082768200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000001111000011111111111142354500000000000000a38282018292008200000000000055828282558282828213535363435353631352628293858642
00000000a28282123282839200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000868282123200b312222222223213354500000000000000828282828282768224000000000000a28282558282828282828292b1b1b1b1b113338282828242
000000868382251323638293a3000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00a3828201423393b3135252232333023545000000000000a38292008201828292000000000000000082825582828282829200000000000000b3720182018213
000000a2822535351222328283860000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
008282920073122222321333122222223545000000000000828200008282920000000000000000000000005500a28282820000000011110000b3739200000012
85858682921222225252623535458600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00828300b3724252525232125252525235450000002400008282000025450000111100000000006100000000000000829221000000254500000000000000a342
82018283001323525284623535458200000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
a3828200b3031352525262425252525235450000000000008282858625450000123293000000000000000061000000a200b70000001182000000000024008242
00a28293f31232425223333535353545000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
82018200b30302132323334252525252354500000000000082828382254500001333829300000000000000000026000000000000005582930000000000008242
00002535355262133312323535353545000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
82828210b3731222222222525252525235450010000000a382828282254511112545828282829300000000000000000000100000005501820000000021a38242
10002535358452222252523235353545000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
222222222222525252525252525252521222223200a3828283828282254512322545828282828282760000000000000000710000005582829300000071820142
12223242525252525252845222222232000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b4c4d4000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000095a5b5c5d5e5f500000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000096a6b6c6d6e6f600000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000097a7000000e7f700000000
__label__
00000000000000000000000000000000ffffffff00000000000000000000000000000000000000000000000000000000000fffff000000000000000000000000
0000ffff0000000000000000000000000000000000000000000000000000ff000000ff0000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007700000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007700000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000060000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000505050505000000000000000000000000000000000000000000000000000000000007
00000000000000000006000000000000000000000000000000000000000500000005000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000050000000d0d0d0d000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000d00000d000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000d0d0d0d00000d00000d000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000d00000d00000dd000dd000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000d0000dd0000000000d0000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000dd000d00606060600d0505050000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000d000d00600000600d0000050000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000050505d000d00600000600d0000050d0d000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000007000000d000000000070000cc00055000d000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000006060600c00000000000000000c0050000d000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000600060c0000000000000000000c050000d000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000cc000000000000000000000ccc000d000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000060600000000000000060000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000060000666006660066000666600666000666006060000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000060006666066666066000666606666606666600060000000000000000000000000000000000000070000
00000000000000000000000000000000000000000000066006600066066066000066006600006606600060000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000600dd000ddddd0dd0000dd00dd0dd0dd0dd00660000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000600dddd0ddddd0dddd0dddd0ddddd0ddddd00600000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000006000ddd0dd0dd00ddd0dddd00dddd00ddd000600000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000cc000000000000000000000000000000000c0000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000c000000000000000000000060000000000000c000000000000000000000000000000000000000000000
0000000000000000000000000000f0f0f0f0f0f0f0f0f0f00000000000000000000000000000000000c000000000000000000000000000000000000000000000
0000000000000000000000000000000000000060000100000000000000000000000000000000000000c00c000000000000000000000000000000000000000000
000000000000000000000000000000000000000000c0000000000000000000000000000000000000001010c0f000000000000000000000000000000000000000
000000000000000000000000000000000000000001000000000000000000000000000000000000000001000c00000000000000000000000000000000f0f0f0f0
00000000000000000000000000000000000000000100000000000000000000000000000000000000000000010000000000000000000000000000000000000000
000000000000000000000000000000000000000001000000000000000000000000000000000000000000000010000000000000f000f000f000f000f000f00000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000f0000000f00000000000f00000000000f0f0f000f00000000000f0000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000f0f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000f000f0000000f000f000f000f000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005050000005500000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000050500500500000000000f000f000f000f0000000f000f0000000000000000000000000
00f000f000f000000000000000000000000000000000000000000000000500555050000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005050050050000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000005050000005500000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000f0000000000000000000000000000660000
0000000000000000000000000000000000000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000f660000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000
0000000000000000000f00000000000000000000000000000000000000000f000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000f000000000f0000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000f000f000000000000070000000000000000000000000000000000000000000000000000000000000
000000000000000000000000f55055505550055055505500555050000f0005000550555050005550055055505550050000005550505000000000000000000000
000000000000000000000000505f505005005000050050505050500000005000500050005000500050000500500050000000505f505000000000000000000000
00f00000000000000000000050505500050050000500505055505000000000005000550050005500555005005500000000005500555000000000000000000000
00000000000000000000000050505050050050500500505050505000000000005000500050005000005005005000000000005050005000000000000000000000
0000000000000000000000005500505055505550555050505050555000f000000550555055505550550005005550000000005550555000000000000000000000
00000000000f0000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000f0000000000000000000000000
0f000000000000000000000000000000000000000055505550555055500000555050500550555005500550550000000000000000000000000000000000000000
0000000f0000000000000000000000000000000000555050500500050000000500505050505050500050505050000000000000000000000000000f0000000000
00000000000000000000000000000000000000000050505550050005000000050055505f505500555050505f50000000000000000000000000000000000f0000
00000000000000000000000000000000000000000050505050050005000000050050505050505000505050505000000000000000000000000000000000000000
00000000700000000000000000000000000000000f50505050050005000000050050505500505055005500505000000000000000000000000000000000000000
00000000000000000000000000000000000000000000f00000000000000000000000000000000000000000000000000000000000000000f0000000000000000f
0000000000000000000000000000000000000f0f0f000055000550555050000000555055505550555050500000000000000000000000000000000000000000f0
00000000000000000000000000000070000000000000005050505050605000000050505000505f50505050000000000000000000000000000000000000000000
0000000000000000000f0000000000000000000000000050505050550050000000550055005500550055500000000000f00000000000000000000000000f0000
000000000000000000000000000000000f0000000000005050505050005000000050505000505050500050000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000050505500555055500000555055505050505055500000000f0f0000f00f00f0f0000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000f000000000f0000000000000000000000000000000000000000000000
0000000000000000000000000000000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000f000000000
000000f000000000000000000000000000000000000000000000f0000000000000000000000000000000000f000000000000f000000000000000000000007000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000
000f0000000000000000000000000000f000000000000000000000000000000000000000f000000000000000000000000000000000000000000000f000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000f00000f000000000000000000000000000000000000f00000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000555005505500000055505050000005000550505055005550505055505550500055500000000000000000000000000000
000000000000000000000000000000005550505050500000505050500000505f5000505050500500505050500500500050000000000000000000000000000000
00000000000000000000000f00000000505050505050000055005550000050505000505f50500500505055000500500055000000000000f00000000000f00000
000000000000000000000000660000005050505050500000505000500000500050505050505005005050505005005000500f0000000000000000000000000000
00000000000000000000000066000000505055005550000055505550000005505550055050500500055050500500555055500000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000
00f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000f000000000000000000000000000000000000000f0000000000000000000000000000000f00000000000000000000000000f0000000
00000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000000000000000000000
00000000000000000000000000000000f000000000000000000000006000000000000000000000000000000000000000000000000000000000000000f0000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000f0f000f00000f00000000000000000000f00000000000000
0f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f0000000000000000000f0000000000000000

__gff__
0000000000000000000000000000000004020000000000000000000200000000030303030303030304040402020000000303030303030303040404020202020200000004040002020300020202020202000013171713020204020202020202020000000000000004040202020202020200000000001300000002000000000202
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
252525252525252526000000000000242525262425262828282828282828285231323232323233212223282828282824262b000000000000002122222324252531323232323232261028282824252526300000000031322525252525252525263425252526242526242525252526282853542900000000000052535353532426
25323232323232252600000000000024323233313233282828282900000000522700000028282824252628282828282426000000000000000024252533242525281028282828283028282810313232333000000000002a3132323232322525262324323233242526313232323226292a53540000000000000052535321222526
26000000002828242639000000000024222222235354280000000000000000523000000028282824323328000000002426000000003b3435353232332024252528282829002a28302838282820290016300000000000002a2828282828242526263721222331323300002a282830393a53541200000000000052343532323233
26001a003a2828242628000000000024323232335354290000000000000000523700013a281028372123290000000024262b000000002829000028000031322528282800113a28242329000020000000300000000000000028280000283132332634252526282829000000002830282853547b7b7b1111111111281028282829
260000002810282426283900000000242021235353541111110000000000005221222223282838212526000000000024262b000000002800003a28000000002400002a2827282831260000001700000030000000000000002a28393a282021232536313233000000000000001030282854000000002122222223282828290000
262828282828282426282800000000242331335353535353540000000000005224252533282828242533170000000024262b00000000283900282800160000240016002837283828370000001100000030004a4a00004a4a4a007b7b7b2125263028282829000000110000002a37105254000000002425252526100000000000
25222223382a28242610280000000024262122222354282828390000000000523132332000002a31335400003a282824262b0000003a282828282800000000240000002a552900000000000020000000300000000000000000000000002425263028000000000000520000000000285254000016003132252526280000000000
252525262800282425222300000000242624252526542828282828282821222323282800000000525354282810382824262b003a282828282828286758000024000000001700000000000000270000003000000000000000000000003a24323330290000000000005200000000002852543900003a2123242526290000000000
2525252628002a242525330000000024263132323354282828282828282425262628280000000052535428282828292425222222232828281028282828382824000000001100000000000000303900003000000000000000000000282837212337000000000000005200000000002a5254281028282426313233000000000000
32323233290000313233280000000024332021232122222354002a2828313233262828391111115253542900000000242525252525360000282810282828282428282828270000000000003a3028001230000000000000000000002828212526007b7b0000001111000000000000005254282828383132353620000000000100
281028280000000000282800000000242122252624252533540000002a2122232628282834362122353600000000002425253232332000002a2828282828282428282828300000000000002830282827307b7b7b7b004a4a00003a28282425262900282839002123000000000000002754290000002a2828287b7b7b7b212223
2a2828283900003a2828280000003a24313232333132335354390000002425262638282828283133282839000000002425332828282800000000000000002a242900002a3000000000000028372a283030000000202123000000282828242526393a281028283133390000000011113054000000003a28292a39000000242526
0001002a2828282828282810282821252828282828285253542800000031252626002828282900002a10280000000024262828281028000000000000120000240001000030110000001200282800103030000000212526000000282828312526290128281028212328000000002122265400000000282816002800003a313233
222222222222222222232900000024250000002a28282828282839000021233726002a102800160000282820343621252600002a28280000000000002711112421222311242300001120002828002830300001002425260000002828282824262123282828282426280000001a31323354390000002828393a28000028205353
2525252525252525252611111111242500010000002a282828282828392425232600002828000000002a2122222225252600000128280000000000112422222531323321252611112123002828162830242222222525260000002828282824262426002a28282426285800000021222254280000001028282828282810525353
25252525252525252525222222222525222222222223212222222222233132332600002828000000000024252525252525222223282839000000002125252525212223242526212324263a281000283024252525252526000028282828282426242600002a28242610282839002425252123393a282838282828102828525353
3132323232323232330000000000000053535353535353535428282900000024252524252525262426242525252628100000000000000000000000000024252600000000000000002425252600000000000000000053535353535353535353532525262425262800000000285253535353535428282810282828282824254825
00000000000000000000000000000000535353535353535354102900000000242525242532323324263132252526282900000000000000000000000000242533000000000000000024252526000000000000160000282900002a2800000000002525262425262800000000285253535353535438282828292a28282824323232
0000000000000000000000000000000000002a283828282855280000000000242525313338282831330000242526280000000000000000000000000000313353000000000016000031323233000000000000000000281111111128004200000025252631252628390000005253535353535354282900000000002a1037212222
000000000000000000000000000000000016000000162a105529000000000024323328282828102829000031323329000000000000000000000000000052535300000000000000005221230000000000000000000028535353532800000000002525323631323536000000525353535353535428000000000000002821252525
00000000000000000000000000000000000011000000002855111100160000242828102828290000000000000000000000000000000000000000000000525353001600000000000052242600000000000000000000102828282828682839000032332828382800000000001b1b2a282853535429000000000000002a31252548
00000000001111000000000000000000000055000000002a27535400000000242900000000000000000000000000000000000000001111110000000000525321000000000000000052242600000000000000000011282800002a2828532839002223282828280000000000000000002a2222230000000011000000002a313232
0000000000522700000000620000000000005539000000003753540000000024000000000000000000000000001111110000000000525354390000003a52532400000000000000005224266700000000000068282728281111002a28282828582533002828280000000000000000001a2532330000003b272b00000000000000
0000000000523000000000000000000000005528282800003b5354000000002400007b000000000000000000005253530000620000525354282828281052532400000000000000005224262800000000003a2828372828525300002a102828283300002a2828391100000000000000003754000000003b302b00000000000000
0000006200523000000000000000000000005528282839003b53540000000024000000000000000000000000001b1b1b00000000005221231028282900212225000000000000000052243327390000003a382828282828282858000028281200000000002838282700000000000062005354000000003b302828390000000000
000000003a523700000000000000000000005500002828003b535400000000240000000000000000000000000062000000004647005224262829000000242525000000000000000052372126280000002828290000002a2828283900280055000000003a28282837110000000000000053540c0000003b302810282828390000
00003a2828522700000000001a00000000005500011028393b535400001600310000000000000000000000000000000000015657002125262900000000312525000000000000000052532426283900002828000000000011112a3828280055000000002862282853536700000000000053540000000000302828282828282839
002828282852300000000000000000000000525353535353535354000000002100000000000000000000000000000000212223343525253311111111112731320000004200000000525324262828670028280042000000525400282828005500000000282828281b1b283900000000005354000000000030290000002a282828
0010290100523000000011110000000000005253535353535353540000000024000000000000000c0000000000000000242525222331332122222222222525250000000000000000525324262828283928280000000000525400282838005500000042282a282828282838000000000053540001000000300042000000002a28
3a21222334222611111121230000000000001b1b1b00002810282900000000240000000000000000000000001a000000242525252621233132323232322525250000000100001200525324262821222328280100000000525400282a28005500000000280028101111112867000000005354002739000030000000003a102828
282425252324252222362426390000000000620000003a28282800000000002400000100000000000000000000000000313225253324252300001c000024252500002122222222232122252523242526222222230012005254002800280055000000012800282853535328280000000053543930286700300012003a28282828
28242525262425252621252638282839000000003a28283828280000000000243a282039000000000000000000000000343631262024252600000000002425250000242525252526242525252624252625252525222222535300280028005500212222222222235353531028283900005354283028283930672728382829002a
__sfx__
0002000036370234702f3701d4702a37017470273701347023370114701e3700e4701a3600c46016350084401233005420196001960019600196003f6003f6003f6003f6003f6003f6003f6003f6003f6003f600
0002000011070130701a0702407000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010400000c3520c35110351103511d35529355213552d355223552e35524355303550030500305003050030500305003050030500305003050030500305003050030500305003050030500305003050030500305
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
011000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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

