pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- ~perisher~ by daniel linssen
-- + matt thorson + noel berry

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

buttons=0

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
end

function begin_game()
	frames=0
	seconds=0
	minutes=0
	music_timer=0
	start_game=false
	music(0,0,7)
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

		if this.spd.y < 0 then on_ground=false end
		
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
			if this.djump<max_djump and this.dash_time <= 0 then
			 if this.dash_effect_time<=0 then psfx(54) end
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

		local d_full=5
		local d_half=d_full*0.70710678118
	
		if this.djump>0 and dash then
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
		 	shake=6
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
			elseif dash and this.djump<=0 then
				psfx(9)
				init_object(smoke,this.x,this.y)
			end
		
		end
		
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
		
		-- next level
		if this.y<-4 and level_index()<30 then
			if buttons == 0 then
				next_room()
			else
				this.y=-4
				if this.spd.y < 0 then this.spd.y = 0 end
			end
		end
		
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
		spr(this.spr,this.x,this.y,1,1,this.flip.x,this.flip.y)		
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
				this.delay=60--how long it hides for
				this.collideable=false
			end
		-- invisible, waiting to reset
		elseif this.state==2 then
			this.delay-=1
			if this.delay<=0 and (not this.check(player,0,0)) and (not this.check(push_wall,0,0)) then
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

collision_ver=function(this, that)

	local hit = this.collide(player,0,0) or this.collide(push_wall,0,0)
	if hit!=nil and hit.dash_effect_time>3 and hit.dash_target.y*that > 0 then
		this.dash_target={x=0,y=sign(hit.dash_target.y)}
		this.spd.y=this.dash_target.y
		if(hit.type==player) then
			hit.spd.x=hit.dash_target.x
			hit.spd.y=-sign(hit.dash_target.y)*2
		end

		hit.dash_time=-1
		hit.dash_effect_time=1
		this.dash_effect_time=10

		init_object(smoke,this.x,this.y)
		shake=4 > shake and 3 or shake
	end

end

collision_hor=function(this, that)

	local hit = this.collide(player,0,0) or this.collide(push_wall,0,0)
	if hit!=nil and hit.dash_effect_time>3 and hit.dash_target.x*that > 0 then
		this.dash_target={x=sign(hit.dash_target.x),y=0}
		this.spd.x=this.dash_target.x
		if(hit.type==player) then
			hit.spd.y=hit.dash_target.y
			if(hit.spd.y<0) hit.spd.y/=0.75
			hit.spd.x=-sign(hit.dash_target.x)*2
		end

		hit.dash_time=-1
		hit.dash_effect_time=1
		this.dash_effect_time=10

		init_object(smoke,this.x,this.y)
		shake=4 > shake and 3 or shake
	end

end

push_wall = {
	tile=70,

	init=function(this)
		this.lastx=this.x
		this.dash_time = 1
		this.dash_effect_time = 10
		this.dash_target={x=0,y=0}
	end,

	update=function(this)

		this.hitbox={x=0,y=-1,w=8,h=9} -- above
		collision_ver(this,1)

		this.hitbox={x=0,y=0,w=8,h=9} -- below
		collision_ver(this,-1)

		this.hitbox={x=-1,y=0,w=9,h=8} -- left
		collision_hor(this,1)

		this.hitbox={x=0,y=0,w=9,h=8} -- right
		collision_hor(this,-1)

		this.hitbox={x=0,y=0,w=8,h=8}
		
		if not this.check(player,0,0) then
			local hit=this.collide(player,0,-1)
			if hit~=nil then
				hit.move_x(this.x-this.lastx,1)
			end
		end
		this.lastx=this.x

		if this.spd.x!=0 or this.spd.y!=0 then
			if rnd(1) < 0.3 then init_object(smoke,this.x,this.y) end
		end

	end,

	draw=function(this)
		-- clamp in screen
		if this.x<0 or this.x>120 then 
			this.x=clamp(this.x,0,120)
			this.spd.x=0
		end
		if this.y<0 or this.y>120 then 
			this.y=clamp(this.y,0,120)
			this.spd.y=0
		end
		spr(70,this.x,this.y)
	end
}
add(types,push_wall)

push_button = {
	tile=71,

	init=function(this)
		--buttons += 1
		this.pressed=false
	end,

	update=function(this)
		if not this.pressed and this.check(push_wall,0,0) then
			psfx(63)
			--destroy_object(this)
			init_object(smoke,this.x-2,this.y-2)
			init_object(smoke,this.x-2,this.y+2)
			init_object(smoke,this.x+2,this.y-2)
			init_object(smoke,this.x+2,this.y+2)
			this.pressed=true
		end

	end
}
add(types,push_button)

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
		this.text="   perisher mountain  #this memorial to those#dedicated to the climb"
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

warning={
	tile=75,
	last=0,
	draw=function(this)
		this.text="  caution! #treacherous# path ahead"
		if this.check(player,0,0) then
			if this.index<#this.text then
			 this.index+=0.5
				if this.index>=this.last+1 then
				 this.last+=1
				 sfx(35)
				end
			end
			local offx=39
			this.off={x=offx,y=72}
			for i=1,this.index do
				if sub(this.text,i,i)=="#" then
					this.off.x=offx
					this.off.y+=7
				else
					rectfill(this.off.x-2,this.off.y-2,this.off.x+7,this.off.y+6 ,7)
					print(sub(this.text,i,i),this.off.x,this.off.y,0)
					this.off.x+=5
				end
			end
		else
			this.index=0
			this.last=0
		end
	end
}
add(types,warning)

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
				--new_bg=true -- !!!
				--init_object(orb,this.x+4,this.y+4)
				music_timer = 60 -- !!!
				init_object(push_wall,this.x+4,this.y-4)
				init_object(smoke,this.x+4,this.y-4)
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
			shake=10
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
			if level_index()==11 then
				print("dedication",44,62,7)
			elseif level_index()==19 then
				print("warning",50,62,7)
			elseif level_index()==30 then
				print("summit",52,62,7)
			elseif level_index()==25 then
				print("???",58,62,7)
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

	obj.is_solid=function(ox,oy)
		if oy>0 and not obj.check(platform,ox,0) and obj.check(platform,ox,oy) then
			return true
		end
		return solid_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h)
		 or obj.check(fall_floor,ox,oy)
		 or obj.check(fake_wall,ox,oy)
		 or obj.check(push_wall,ox,oy)
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
 if room.x==2 and room.y==1 then
  music(30,500,7)
 elseif room.x==3 and room.y==1 then
  music(20,500,7)
 elseif room.x==2 and room.y==2 then
  music(30,500,7)
 elseif room.x==3 and room.y==2 then
  music(20,500,7)
 elseif room.x==0 and room.y==3 then
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

function prev_room() -- for cheating
	if room.x==0 then
		load_room(7,room.y-1)
	else
		load_room(room.x-1,room.y)
	end
end

function load_room(x,y)
	has_dashed=false
	has_key=false
	buttons = 0

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
	if frames==0 and level_index()<30 then
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
	buttons=0
	for i=1,#objects do 
		if objects[i].type==push_button and not objects[i].pressed then 
			buttons=buttons+1
		end 
	end
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
			start_game_flash=40
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

	-- cheats!

	--if btnp(1, 1) then next_room() end
	--if btnp(0, 1) then prev_room() end

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
		local d=10
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
		if start_game_flash>0 then
			-- nothing yet
		elseif start_game_flash>-5 then
			d=2
		elseif start_game_flash>-10 then
			d=1
		else
			d=0
		end

		if c<10 then
			pal(6,c)
			pal(12,c)
			pal(13,c)
			pal(5,c)
			pal(1,c)
			pal(7,c)
		end
		if d<10 then
			pal(8,d)
			pal(14,d)
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
		print("daniel linssen",38,108,5)
		print("a mod of celeste",34,80,5)
		print("by matt thorson",36,86,5)
		print("and noel berry",38,92,5)
	end
	
	if level_index()==30 then
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
__gfx__
000000000000000000000000028888800008888000000000000000000288888000aaaaa0000aaa000000a0000007707770077700000060000000600000060000
00000000028888800288888028f8888802888888088882000000000028ff888800a000a0000a0a000000a0000777777677777770000060000000600000060000
0000000028f8888828f8888828ff888828ff88888888f8200288888028f1ff1800a909a0000a0a000000a0007766666667767777000600000000600000060000
0000000028ffff8828ffff888ff1ff1828fffff888fff82028f888888ffffff8009aaa900009a9000000a0007677766676666677000600000000600000060000
000000008ff1ff188ff1ff1808fffff08ff1ff1081ff1f8028ffff8808fffff00000a0000000a0000000a0000000000000000000000600000006000000006000
0000000008fffff008fffff000dddd0008fffff00ffff8008ffffff800dddd000099a0000009a0000000a0000000000000000000000600000006000000006000
0000000000dddd0000dddd000700007007dddd0000dddd7008f1ff1000dddd000009a0000000a0000000a0000000000000000000000060000006000000006000
000000000070070000700070000000000000070000007000077ddd700070070000aaa0000009a0000000a0000000000000000000000060000006000000006000
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
777ccc7777cc7cccccccccccc77ccc777777ccc7777777777ccc7777777cc77755550055555000000000055500000766033333300000000000eeeee000000030
77ccc77777ccccccccccccccc77ccc77777ccccc7c7777ccccccc77777ccc777555500555555000000005555000000550333b33000000000000e8e00000000b0
77ccc777777cccccccc77cccccccc777777ccccccc7777c7ccccc77777cccc7755555555555550000005555500000666003333000000b00000eeeee000000b30
777cc7777777ccccc777777ccccc77777777ccc7777777777ccc777777cccc775505555555555500005555550007777600044000000b000000ee3ee003000b00
777cc777777777777777777777777777777777777777777777777777777cc7775555555555555550055555550000076600044000030b00300000b00000b0b300
77cccc77577777777777777777777775577777777777777777777775577777755555555555555555555555550000005500999900030330300000b00000303300
5777755777577775077777777777777777777770077777705777777500000000cccccccc00000000000000008888888000000000000000000000555555550000
7777777777777777700007770000777000007777700077777777777705777750c77ccccc00000000000000008822228800000000000000000000055555500000
7777cc7777cc777770cc777cccc777ccccc7770770c77707777ee77707000070c77cc7cc00000000000000008888888800000000000000000000005555000000
777cccccccccc77770c777cccc777ccccc777c0770777c0777eeee77070ee070cccccccc0000000000000000822822280000e000000000000000000550000000
77cccccccccccc777077700007770000077700077777000777eeee77070ee070cccccccc00000005500000008888888800060600000000000000000000000000
57cc77ccccc7cc7577770000777000007770000777700007777ee77707000070cc7ccccc00000055550000000000400000d00060000000000000000000000000
577c77ccccccc7757000000000000000000c000770000c077777777705777750ccccc7cc0000055555500000007770000d00000c000000000000000000000000
777cccccccccc777700000000000000000000007700000075777777500000000cccccccc000055555555000007777770d000000c000000000000000000000000
777cccccccccc77770000000000000000000000770000007000eeeeeeeeee0000000000000000000000000000000000c0000000c000600000000000000000000
577cccccccccc7777000000c000000000000000770cc000700eeeeeeeeeeee00000000000000000000000000000000d000000000c060d0000000000000000000
57cc7cccc77ccc7570000000000cc0000000000770cc000700e22e2222e22e0000000000000000000000000000000c00000000000d000d000000000000000000
77ccccccc77ccc7770c00000000cc00000000c0770000c0700eeeeeeeeeeee000000000000000000000000000000000000000000000000000000000000000000
777cccccccccc7777000000000000000000000077000000700eee222e22eee00555555550eeeee00eeeee00eeeee00eeeee000eeee00ee00e00eeeee00eeeee0
7777cc7777cc777770000000000000000000000770c0000700eeeeeeeeeeee00555555550eeeeee0eeeeee0eeeeee0eeeeee0eeeeee0ee00ee0eeeeee0eeeeee
777777777777777770000000c0000000000000077000000700ee77eee7777e00555555550ee00ee0ee00000ee00ee000ee000ee00000ee00ee0ee00000ee00ee
57777577775577757000000000000000000000077000c00707777777777777705555555508888800888800088888000088000888888088888808888000888880
00000000000000007000000000000000000000077000000700777700500000000000000508800000880000088008800088000000008088008808800000880088
00aaaaaaaaaaaa00700000000000000000000007700c000707000070550000000000005508800000888880088008808888880888888088008808888800880088
0a999999999999a0700000000000c000000000077000000770770007555000000000055508800000888888088008808888880088880088008808888880880088
a99aaaaaaaaaa99a7000000cc0000000000000077000cc077077bb07555500000000555500000000000000000000000000000000000000000000000000000000
a9aaaaaaaaaaaa9a7000000cc0000000000c00077000cc07700bbb0755555555555555550000000000000c000000000000000000000000000000c00000000000
a99999999999999a70c00000000000000000000770c00007700bbb075555555555555555000000000000c00000000000000000000000000000000c0000000000
a99999999999999a700000000000000000000007700000070700007055555555555555550000000000cc0000000000000000000000000000000000c000000000
a99999999999999a07777777777777777777777007777770007777005555555555555555000000000c000000000000000000000000000000000000c000000000
aaaaaaaaaaaaaaaa07777777777777777777777007777770004eee00004e000000400eee00000000c0000000555555555555555555555555000000c000000000
a49494a11a49494a70007770000077700000777770007777004eeeee004ee000004eeeee0000000100000000555555555555555555555555000000c00c000000
a494a4a11a4a494a70c777ccccc777ccccc7770770c7770704200eee042eeeee042eee00000000c0000000005555555555555555555555550000001010c00000
a49444aaaa44494a70777ccccc777ccccc777c0770777c07040000000400eee004000000000001000000000055555555555555555555555500000001000c0000
a49999aaaa99994a7777000007770000077700077777000704000000040000000400000000000100000000005555000000000000000055550000000000010000
a49444999944494a77700000777000007770000777700c0742000000420000004200000000000100000000005550000000000000000005550000000000001000
a494a444444a494a7000000000000000000000077000000740000000400000004000000000000000000000005500000000000000000000550000000000000000
a49499999999494a0777777777777777777777700777777040000000400000004000000000010000000000005000000000000000000000050000000000000010
52525223232352845262828282920000522323330000001323232323232323845262135262425252525252525262828200000000000000000000000000000000
00000000000000000000000000000000000000b3425223232323232323232323525252525252525262b2a2828292868200000042842323232323233342525252
525262123274132352628276858693413300e482a400a382829200000000001352523242621384525252525252628283000000a3829300000000000000000000
00000000000000000000000000000000000000b34262b2a282820182b7c7f400525223235252528462b200828200828200000042330000000000868213232323
8452334262a301821333839200a21222746400a2828201b7f4000000000064745252621333024252525284522362828200a49482920000000000000000000000
11111100000000000000000000000000006100b34262b200a382829200000000526212321323232333b2008292a30182000000031000000000a30192b1b14322
5262101333a2828293000000000013233200000000a2f40000000000000000125252522222321352522323337403b7c700a2828276a400000000000000000000
22223293009486000011000000111111000000b34262b200d78393000000000052624262b20000007100a38282828282210000422263110000a2820064007442
2333710276868300a20111000000a282330000000000000000000000000000135252525252523213338282000003948600a382f4000000000000000000000000
52526282a3828293b302b200a3122222000000b34262b200004363b20000610052624262b20000000272828392b312227100001333123200a2938276a4001284
829200948682926400820276000000821100000000b00011110000001100b01152845223232333828282829394038282a2838293b40000000000610000000000
52526282820182828282938683428452006100125233b20000b1b1111111000023334262b2000000b103f4a20000425200000012225262000083921111114252
01000000a282000000a282920000008232000000000000436300610002858612232333b1b1b1b1a2828382828203820100e40212223211111100000000000000
528462828292e4c7d78382828242522393948513337464000000b3432232000000021333b26400000003110000004252000000132323331100a2b34322225252
92000000009276000000920000000083330000000000a3828393948682b7c713828292001164110082c70182b77382820000b3132352324363b2000000000000
52523382a2001100009200e4824262128282836474123211110000b3426200000000a282f400000000423211000042520000001222222232000000b342525252
000000000000a29200000000210000a274640000000000a2828282828200647482f40000122232009200d79200e483820000b312321333008276850000000000
5262729200b302b200001186821333428292004353232353630000b3426200000000a382930000001142843200b31352000000425284526200e4930013238452
00000000000000000000000071000000320000000000000000e4c7d792000012b710000013233300000000000000a2820000b342522232008282820000000000
526273000000001111b37292e4122252820000b182b7c7d7930000b34233000010a20192a29300111252526200000042000000425252233300008292b1b11352
0000002100000000002100000000000033000000000000000000000000000013223200000000020000e30000000000120000b3132323330082828376a4000000
523372000000101232007300004252528276858682111111828293b303b20000222232111183110242232333b2000042000000132333123211a3820064007442
000000710000210000710000000000001111111100c00011110000000000c01152620000000000000043630000000042000000018282a4a38282828200000000
6212620000006442620000000042525222223243535353535363122262b261005252842232821222620000000000004200000000a28213236382017685861252
000000000000710000000000000000005353630200610043630000000000004352627685a40000000000000064000042000000e4d78282828282820193000000
6213330061000013330000610013845223233382018282828282132333b200005252525262824252620000000000b342000000000000a29200a2828282834252
0000000000000000000000000000000000e4d782768586829200000000000000526282828212223200000000122222520000000000828282927171e4d776a400
5222320000a300027200000000024252000000a2f4a282828392b1b1b10000005223232333821323337171122222225200000000009300a37686829200a21352
00000000000000000000000000000000100000828282820100000000000000005284222232425262741222228452525210000000a38282821111111111829200
525262868382931262a393009412525200100000000000b7f4006100000061006274e4d782828201828282132352525200002100a38382828282820064007442
00000000000000000000800000000000223200a2828283f40000000000000000525252526242526272425252525252523200a282838282821222222232820000
52526282828282426282838282425252222222320000000000000000000000005222222222222222222222223242525200243434343434448282827685861252
000000b3263636364613232323238452232323334252525262030000000342525252525223232323232323525252628223235252525252621352528462828282
52842323232323235262000000000000000000425252525252525252525252520000000000000000000000000000000000000000000000000000000000000000
93000000000000000000000000001352b1b1b1b113232323330300000003425252525233828282b7f4a28313845262e482821352522352843242525262828282
2333b1000000b1b11362000000e300f3000000425252525252235252525223520000000000000000000000000000000000000000000000000000000000000000
82a30000000041d3000000610000004200000000b1b1b1b1b17300000003132352526292008292800000b7d7425262868282821362021323331323526282a282
7283930000000000b303a37686122222006100132323232333024252526274420000000000000000000000000000000000000000000000000000000000000000
82829300b343630200000000000000420000000000000000000000000073b1b15284330061a21172110000001352628282828382423274123274804262820082
7392000000000000b303829200132323000000123243535363125252526200420000000000000000670000000000000000000000000000000000000000000000
8282820000b1b102000000000000a342000000000000000093000000000000005233b1000011125232110000b113628282018282133300133300541333929483
b100110000000000b30382000000a28200000042628282920213232323330013000000000000000072a30000000000000000000000000000c4d4000000000000
82838276a41100b100000011000082130000000093000086820000a30000000062b10000111252525232110000b103828282926400000064000056b1b10000a2
1100721111111100b3038241a2018282000000133392000072828282838293a200000000000000864232a40000000000000000000095a5b5c5d5e5f500000000
828282018202b20000000072b29482820000a385828286828282828293000000620061b343845252525263b200000382f4a20000000000000000000000000000
7200034353536300b34222321182838200000064110000007383929486019200000000000000a28342522232a4000000000000000096a6b6c6d6e6f600000000
828282828292000000000073b20000e486938282828201920000a20182a3768662110000b11352525233b1000011038200000000000000610000000000004100
037603b1b1b1b100b3425252329200a20000004363000000a282001100a2000000000000008601821352526254000000000000000097a7000000e7f700000000
82828282820000111111941111111111828282a28382820000000000828282828432110000b1422362b100001112629271000000000000000000000000122222
0383030000000000b342845233006100000000b1b1000000009200720000000000000000a3828282824252625500000000000000000000000000000000000000
828282829200001222328212222222228282920082829200061600a3828382a2525263b261000364030000b3438462a400000000000000000000000000428452
738203930011111111422333b1768586000000000000000000000073000000000000009486838282821323335672000000000000000000000000000000000000
8282828200640042526282425252525283820000a282d3000717f382829200005233b1000011422262110000b113628200000000000000000000000000422323
b1a20382b31232644333b1b1a3829200000000000000001100c000920000a311000000a382828282122222222262000000000000000000000000000000000000
82828283939486132333b713232384528282930000a2122232122232820000a333b10000111252528432110000b1738300000000000000000000001100738293
118603a2934233b1a283760000a2000000000000000000720000000000938272000000a224448282135252525262930000000000000000000000000000000000
828282828282011232b100b11232132301920000000213233342846292002434b10000b343525252525263b20000b1a200000000000000000000b37200a38382
028203b28273b1000000000000111100000000000000007300000000a30182730000a37625456412324252522333839200000000000000000000000000000000
22223200a282824262118011425222228200100000122222225252523211253500000000b11323232333b1000000000000000000000000000000b303000000a2
b1a20382920000000027373737374700c0000000000000e40000a276858292a200a2123226461252621323331222320000000000000000000000000000000000
52233310009200428432741252525252343434344442528452525252627226361041000094018282828200000000000000000000000000000000b303a4001000
111073f40061000000000012223200000000000000000000000000838282d3100010425222225252522222225252629300000000000000000000000000000000
62243444000000425252225252845252353535354542525252525284624222222232858683828282828293000012222200000000000000000000b30382761222
222232800000000000000042526200000000000000000000000000a2828212228612525252525252525252525252628200000000000000000000000000000000
__label__
00600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000066000000000000000000
00000000000000000000000000000000000000000000066000000000000000000000000000000000000000000000000000000000000066000000000000000000
00000000000000000000000000000000000000000000066000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000006000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000066000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000066000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000060600000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000d00060000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000d00000c000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000d000000c000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000c0000000c000600000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000d000000000c060d0000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000c00000000000d000d0000000000000000000000000000000000000000000f0000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000eeeee00eeeee00eeeee00eeeee000eeee00ee00e00eeeee00eeeee0000000000000000000000000000000000000
0000000000000000000000000000000000000eeeeee0eeeeee0eeeeee0eeeeee0eeeeee0ee00ee0eeeeee0eeeeee000000000000000000000000000000000000
00000f0000000000000000000000000000000ee00ee0ee00000ee00ee000ee000ee00000ee00ee0ee00000ee00ee000000000000000000000000000000000000
00000000000000000000000000000000000008888800888800088888000088000888888088888808888000888880000000000000000000000000000000000000
00000000000000000000000000000000000008800000880000088008800088000000008088008808800000880088000000000000000000000000000000000000
00000000000000000000000000000000000008800000888880088008808888880888888088008808888800880088000000000000000000000000000000000000
0000000000000000000000000000000000000880000088888808800880888888008888008800880888888088008800000f000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000600
0000000000000000000000000000000000000000000000000c000000000000000000000000000000c00000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000c00000000000000000000000000000000c0000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000cc0000000000000000000000000000000000c000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000c000000000000000000000000000000000000c000000000000000000000000000000000000000006600
0000000000000000000000000000f0f0f0f0f0f0f0f0c0f00000000000000000000000000000000000c000000000000000000000000000000000000600006600
0000000000000000000000000000000000000000000100000000000000000000000000000000000000c00c000000000000000000000000000000000000000000
000000000000000000000000000000000000000000c0000000000000000000000000000000000000001010c0f000000000000000000000000000000000000000
000000000000000000000000000000000000000001000000000000000000000000000000000000000001000c00000000000000000000000000000000f0f0f0f0
00000000000000000000000000000000000000000100000000000000000000000000000000000000000000010000000000000000000000000000000000000000
000000000000000000000000000000000000000001000000000000000000000000000000000000000000000010000000000000f000f000f000f000f000f00000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000010000000070000000000000000000000000000000000000000010000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000f0000000f00000000000f00000000000f0f0f000f00000000000f0000000
00000000000000000000000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000007700000000000000000000
000000000000000000f0f00000000000000000000000000000000000000000000000000000000000000000000000000000000000007700000000000000000000
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000005550000055500550550000000550555000000550555050005550055055505550000000000000000000000000000000
00077000000000000000000000000000005050000055505050505000005050500000005000500050005000500005005000000000000000000000000000000000
00077000000000000000000000000000005550000050505050505000005050550000005000550050005500555005005500000000000000000000000000000000
00000000000000000000000000000000005050000050505050505000005050500000005000500050005000005005005000000000000000000000000000000000
000000000000000000000000000000000050500000505055005550000055005000000005505550555055505500050055500f0000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000005550505000005550555055505550000055505050f550555005500550550000000000000000000000000000000000
00000000f000000000000000000000000000505050500000555050500500050000000500505050505050500050505050000000000000000000000000f0000000
000000000000000000000000f000000000f055005550000050505550050005000000050055505050550f55505050505000000000000000000000000000000000
0000000f0000000000000000000000f000f050500050000050505050050005000000050050505050505000505050505000000000000000000000000000000000
0000000000000000000000000f000f000000555055500000505050500500050f0000050f50505500505055005500505000000007700000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f000000000007700000000000000000000000
00000000000000000000000000000000000000555055005500000055000550555050000000555055505550555050500000000000000000000000000000000000
0000000000000000000000000f00000000000050505050505000005050505050005000000050505000505050505f50000f0000000000000000f0000000000000
00000000000000000000000f0000000000000055505050505000f050505050550050000000550055005500550055500000000000000000000000000000000000
0000000000f000000000000000000000000000505050505050000050505050500050000000505050005050505000500000000000000000000000000000000000
00000000000000000000000000000000000000505050505550000050505500555055500000555055505050505055500000000000000000000000000700000000
000000000000000000000000000000000000000000000000000000000000000f000000000000000000000000000000000000000000000000000000000f000000
0000000000000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000f000000000000000000000
0000000000000000000000000000000000000f0000f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000f0000000000000000000000000000000000000000000000000000000000000f000000000000000000000000000000000000000000000000000000000000f0
0000000000000000000000f0000000000000000f000000000000f00000000000000000f00000000000000000000000000000000000000000f0000000000f0000
0000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000000000000000000000f000000000
0000000000000000000000000000000000000000000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00070000000000000000000000000000000000000000000000000000000000000000f000000000000000000f0000000000000000000000000000000000000000
00000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000f00000000f00000000000000000
000000000000000000000000000000000000f055005550550055505550500000005000555055000550055055505500000000000000000000f000000000000000
0000000000007700000000000000000000000050505050505f050050005000000050000500505050005000500050500000000000000000000000000000000000
00000000000077000000000000000000000000505055505050050055005000000050000500505055505550550050500000000000000000000000000000000000
00000000000000000000000000000000f0f000505050505050050050005000000050000500505000500050500050500000000000000000000000000000000000
00000000000000000000000000000000000000555050505050555055505550000055505550505055005500555050500000000000000000000000000000000000
00000000000000000f0000000000066000000000000000000000000000000ff0000000000000000000000000000000000f000000000000000000000000000000
000000000000000000000000000006600000000000000000000000000000000000000000000000000000f00000000000000000000000000000f0000000000000
000000000000000000000000000000000000000000000000000000000000000f000000000f000000000000000000000000000000000000000000000000000f00
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000f00000000000000000000000000000000600000000000000f0000000000000000000000000000000000000000
00000000000000000000000000000000000000000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000f000000000000000000000000000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000f0000000000070000000f00000000000000000000000000000000000f0f0000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000f00000000000000000000000000000000000000000000000000000000000000000000000000000000f000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000f0000000f00000000000000000000000000000000000000
00f0000000000000f0000000000000000000000000000000000000000000000000000000000000000000000000000000000007000000000000000000000f0000
000f0000000000000000000000000000000000000000000000000000070000f000000000000000000000000000000000000000000000000000f0000000000000
00000000000000000000000000000000000000000000000f00000000000f000000f0000000000000000000000000000000000000000000000000000000000000

__gff__
0000000000000000000000000000000004020000000000000000000200000000030303030303030304040402020000000303030303030303040404020202020200001313131300000304040202020404000013131313020204020202020202020000131313130004040202020202020200001313131300000002020404040202
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
000000000000000000242548252525252525252526303132323300000000000000000000002426242525252525252624252525252525252526000031323232253232323232323248252638002a2828243300003b2425253232323232323232253f00000000002425253232323232482500000000283831323324263132324825
00000000000000000031323232323232252525482637290000000000000000000000000000242624252532323232332425253232323248252600000000000024000000002a38283132262839002828240000003b24323329004e2810290000242300000000003132332828284f3a312500000049282900003b24262b00003125
0000000000000000000000002a28284625252532332828674a00003e003f2122002c00003a31332425260000003a383132330000000031323300000000000024000000000000002828372900002a38310000003b3028380000002a28003e002426000000003a38282810287d6729002400000028281400003b31332b00000024
00000000000000002a3900000038282148252600002838290000212222223232003c0000282821483233001c00003d2a0000003a67683828212222232b0000240000463f0000002a001b0000000000470000003b302829000000003435362148263d002c00002a2828282811110000240017002a21231100001b1b0000080024
001a0000000012120028675868282824252526003a2828282839242525264243222300002a28242600000000004621220000000000102828243232332b000024000034362b0011000000000011212222233d003b37293a671100002a283824252523003c000000003a382921232b002400170000314823110000000011212225
3d003f0000003436682828282828343225252523281028282821252525265253252600003a282426002a38393a7b2425000100002a28282830272b000000003100001b1b003b202b0016003b3448252533200000004928292700000028293125252522223611111134361124332b002400170000282448361100001121252525
212223000000002a294e282900002a2832322526002a212222483232323352532526122a28382426000028202747242522231111113a282830372b001600000000000000003a2838390000004e2425252347496828102800300000002a4000242525323342434343434421262b0000240000003a283133212311112125252525
31323300000000000068284a001600282223313300003132323329004e38525325262028282824261700283924222525254835353628282924230000000011110000000049102829000000000031323225222222223629003000000020676824253328386263636363642426000000240000004e102829313334353225252525
20284f00000000000028282839003a38252523470000004600000000002a5253323321231029313367582810242525252533382900002a7b2426390000112122000000002a282a287b4f00000028292a25323232330000003700003a2122222526282828283900000021252600003b24000000002a2800000000000024252525
23290000000000003a283828286828283248252222222321232123673a286263000031332800202a2828292a313232322600000000000011242628003b212525001600000000002a00000000002a00002600000046000000113a2828313225252628282829000001002425260000003100000000002839000000000031324825
3300000000000000002a28282828282828313232323233242631332828282900000000282900204a38390000000000002600001111111121252638393b313232000000000000000000000000000000002600003a28286758272838282828242533281028460000342248323300000000000000006828284f000000001b1b3125
0000000000000000000000681028282838290000004e7d3133282828283900000000002a00007b4f290000000000000026003b34222222253233282828282122111111110000000017170000000000002600003828282829307b4f002a2824252838284f727373743133003435360000000000002a3828000000000046004724
00000000000000000000002a2828282828674a00000000102829382828280000000000000000000000001717000000002600000031323233002a282828282425353535362b000000000000000000000026003a2123282a003700000000012425282a2900000000000000001b1b1b000000000000002828390000000000002125
00000000000011110000000021232122282900000000002a00002a34353600000000000000000000000000000000000026000000000020000000002a2828242528382828000000000000000000000000252223313329002123000021222225252900000000000000000000000000002100000000002123290000001111112425
0001000000002123111111113133242529013d0000000000000021222338000000000000010000000000000000000000330000003e0046000000003a38282425012a2829000000000000171700000000252548222300002426000024252548250000000046000000000000000011112400010000002426111111112122222525
2222233949682425222222222222252522222300000000000000242526290000000021222223390000000000000000000000002122222223004968282821252522222300000000000000000000000000252525252600002426000024252525252222222222230000000000000021222500270000002448222222222525252525
25253232252526313232323232482628262828282432322525252532323225252628282425253324252525252532323225252533000000000000000000000052252526000024252525252525252533212525252525252525252526000000003a2525252533626363636364525354000028282830313232323232323232323232
3233000024252600000000000031262826282a7b3742443132323328382824252610282425332125252525252642434348252600000000000000000000000052323233000031323232323232323321252525323232254825252526000000002825254826752000282828286263640000283828302839002839000000107b4f00
00000000244833000000000000003028334f00000062641b1b1b1b002a282425262828313347313232252525265200002525260000000000000000000000005220204244000000004e282828390024252526282828242532323233000067683832323233205868282828282828674a3a4f2a2830292a68382828676828000000
0000000031330000000000461111374f43440000001b1b000000080000282425262838287b4f4e4244313232335200003232336700000000000000000000420043446264003f00003a282900000024253233382828242621222222233a102828002a281028282828282828283828282800002930000034353535362b29000000
000000001b1b00000000003b2122236853540000000000000000114968282425267b282900000052547d2828385200002223282800002c56572c000000425353535420343621222222222300000024252828294e283133242525254822232828010028282828282810282136204243430000123700003b72741b1b0000160000
3f001400000000000011003b3132332863644244001111004958277b7c7d242533002a000001006264007c28296263632526382867003c21233c42434353636353542828283125254832266758212525290000002a2821253232323232262a2823203435352328282828304243535353003b21231100001b2700000000000000
22222339000000463b202b002a3828282223626434353628282830391600242547000000004600004600004f004600472533282828392731332752535364000053547d282a28313233473728282425323e00002c000024261b1b1b1b1b3011282642434344374e382828376263636363003b2426462b00003000000000000000
252533280000000000000000492828283232362828291b4e7c7d37286758242544000000000000000000000000000042262a2828102824222226626364000000636400290000000000004e7c7d3133212300003c003f24330000000000243629266263636400002a287b7c4f00002021003b31331b0000003000000000000000
32332828674a00000000000029004e282a2810284f00000000001b002a38242554000000000000000000000000000062260029002a2824482525230000000000232800003a2820673a58390000002a24334621223536371b0000000000371b004823470046001600280016004600472400001b1b000000113000000000000000
7d28102828384f000000000000000028012828290000110000000000002924255400000000000c00000000000000000c260000000021252525252600000000002628173828282828287b282839170024000024261b1b200000110000001b000032260000000000497b390000000000310000000000003b212600160000000000
002a282828280000000000110000002a23287b0000002700000011000000242554000000000000000000000000000000330000000031322525253300000000002628002a2829004e7c004e7d280000240000313300001b0000270000000000004437674a00004e29164e00000000492812001400000000242600000000000000
000000282828671100003b202b000000262800461111300000002700460024256400000000000000000000000000000000000000424344242526283900000000262901004f003a001717173a294621250000000000001100003000000011111254282a0000000000000000000000002922223611111111242611110000000000
00013a28282828202b00000000000000267d4a493435260046003000000024252900000000000000000000000000000000000000525354244826282800000000252222233a2828674a00682867682425000000000000200000370000002122226429000000000000461100000000000048267273737374313334362b00000000
222328283828291b00000000000000002611112a38283011001130110011242500000000000000000000000000000000003f01005253542425262810673a3900252548262828281029002828282824250001000000114611114611111131252500000000000011113b4500000000000032333900000000000000000000000000
25337b7d287b4f00000011000000080025222347291424234721252347212525000000000000000000000000000000000021222352535424253328282838290025252525237c7d2867682838292148252223000000727373737373737374242500000000000042443b55000000000000013a3867682839000000000000000800
2600000000000000003b202b0000000025252522222225252225252522252525000000000000000000000000000000000024252652535424264628282828283925252525260021222222222300242525252600496828212222222222222248250000000000005254475500000000000022222328282838391717170000000000
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
001000000c3500c3400c3300c3200f3500f3400f3300f320183501834013350133401835013350163401d3600a370093700a360093600a350093400a330093200a30009300133001330016300163001d3001d300
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
000400001d6101f620246303074030750307503074030740307303072030710307103070030700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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

