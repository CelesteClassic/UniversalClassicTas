pico-8 cartridge // http://www.pico-8.com
version 25
__lua__
-- ~snek mod~
-- matt thorson + noel berry

-- jojo's bizzare adventure:
-- code is spaghetti

-- globals --
-------------

--enable debug mode
debug=false

screenshake=false
lastroom=0

--trial effect
spook=false

--debug stuff
k_mute=3
k_gemless=5
k_dec=0
k_inc=1

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

function is_trial()
	return level_index()==15
end

function is_heaven()
	return level_index()==20
end

function is_heck()
	return level_index()==23
end

function stop_timer()
	return is_heaven() or is_heck()
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
	--oof
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
			if is_trial() then
				spook=false
				load_room(7,2)
			else
				kill_player(this) 
			end
		end
		
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
		
		-- trial thing
		if is_trial() and max_djump==2 then
			if not spook and this.y>60 then
				spook=true
				music(-1)
				sfx(63)
			end
		end
		
		-- next level
		-- all this is hardcoded lol
		if level_index()==2 then
			if this.x>120 and this.y>64 then
				load_room(5,2)
			elseif this.y<-4 then
				next_room()
			end
		elseif level_index()==7 then
			if this.x<0 and this.y>64 then
				load_room(6,2)
			elseif this.y<-4 then
				next_room()
			end
		elseif level_index()==8 then
			if this.x>132 then
				next_room()
			elseif this.y<-4 then
				if max_djump~=2 then
					music(20,500,7)
				end
				new_bg=true
				load_room(2,1)
			end
		elseif level_index()==9 then
			if this.x<-4 then
				load_room(0,1)
			elseif this.y<-4 then
				--speedrun shortcut
				next_room()
			end
		elseif is_trial() then
			if max_djump==1 and this.y<-4 then
				music(10,500,7)
				new_bg=nil
				next_room()
			end
		elseif level_index()==21 and this.y<-4 then
			load_room(3,0)
		elseif level_index()==22 and this.y<-4 then
			load_room(0,1)
		elseif this.y<-4 and not stop_timer() then 
			next_room()
		end
		
		-- was on the ground
		this.was_on_ground=on_ground
		
	end, --<end update loop
	
	draw=function(this)
	
		-- clamp in screen
		if (this.x<-1 and level_index()~=9) or (this.x>121 and level_index()~=8) then 
			this.x=clamp(this.x,-1,121)
			this.spd.x=0
		end
		
		set_hair_color(this.djump)
		if is_heaven() then
			spr(60,this.x,this.y,1,1,this.flip.x,this.flip.y)
			spr(44,this.x,this.y-8,1,1,this.flip.x,this.flip.y)
		else
			draw_hair(this,this.flip.x and -1 or 1)
			spr(this.spr,this.x,this.y,1,1,this.flip.x,this.flip.y)		
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
	 if lastroom==9 and level_index()==8 then
			this.x=96
			this.y=112
		elseif is_heaven() then
			this.y+=8
		end
	 this.target= {x=this.x,y=this.y}
		this.spr=3
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
		if is_heaven() then
			spr(60,this.x,this.y,1,1,this.flip.x,this.flip.y)
			spr(44,this.x,this.y-8,1,1,this.flip.x,this.flip.y)
		else
			draw_hair(this,1)
			spr(this.spr,this.x,this.y,1,1,this.flip.x,this.flip.y)		
		end
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
		if level_index()==9 then
			this.text=" for centuries we have guarded#  the treasure of our people  #       ~the dash stone~       "
		elseif level_index()==22 then
			this.text="discordapp.com/channels/4956487#33057253388/524691612895412224/#716671796379648041 baldjared :)"
		elseif is_heaven() then
			this.text="   we are proud to call you   #          ~one of us~         #  now sit with us; eternally  #   guard our precious stone   "
		elseif is_heck() then
			this.text="you stole what we prized the #most. now you must lose in   #turn what you value the most.#many a year we guarded our   #treasure, as many a year you #must rot in hell.            "
		end
		if this.check(player,4,0) then
			if this.index<#this.text then
			 this.index+=0.5
				if this.index>=this.last+1 then
				 this.last+=1
				 sfx(35)
				end
			end
			if is_heaven() then
				this.off={x=3,y=98}
			else
				this.off={x=3,y=16}
			end
			for i=1,this.index do
				if sub(this.text,i,i)~="#" then
					rectfill(this.off.x-1,this.off.y-2,this.off.x+6,this.off.y+6 ,7)
					print(sub(this.text,i,i),this.off.x,this.off.y,0)
					this.off.x+=4
				else
					this.off.x=3
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
		if max_djump==2 then
			this.state=2
		else
			this.state=0
		end
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
   spr(96,this.x+8,this.y,1,1,true)
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
  spr(112,this.x+8,this.y+8,1,1,true)
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
		if is_heaven() then
			this.y+=5
		end
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
			rectfill(2,2,125,11,0)
			spr(26,3,3)
			print("x"..this.score,12,5,7)
			draw_time(35,4)
			print("deaths:"..deaths,82,5,7)
		elseif this.check(player,0,0) then
			sfx(55)
	  sfx_timer=30
			this.show=true
		end
	end
}
add(types,flag)

alt_flag = {
	tile=67,
	init=function(this)
		this.x+=5
		this.score=0
	end,
	draw=function(this)
		this.spr=67+(frames/5)%3
		spr(this.spr,this.x,this.y)
	end
}
add(types,alt_flag)

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
			if is_trial() then
				print("trial of the stone",28,62,7)
			elseif is_heck() then
				print("depths of hell",37,62,7)
			elseif level_index()==19 then
				print("summit",52,62,7)
			elseif is_heaven() then
				print("ascension",47,62,7)
			elseif level_index()==21 then
				print("tunnel",52,62,7)
			elseif level_index()==22 then
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
		if spook then return false end
		if oy>0 and not obj.check(platform,ox,0) and obj.check(platform,ox,oy) then
			return true
		end
		return solid_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h)
		 or obj.check(fall_floor,ox,oy)
		 or obj.check(fake_wall,ox,oy)
	end
	
	obj.is_ice=function(ox,oy)
		return ice_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h)
	end
	
	obj.collide=function(type,ox,oy)
		if spook then return nil end
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
 if level_index()==7 then
  music(30,500,7)
 elseif level_index()==14 then
  music(30,500,7)
 	new_bg=nil
 elseif level_index()==16 then
 	music(45,500,7)
 elseif level_index()==18 then
 	music(-1,5000)
 end
 
	if room.x==7 then
		load_room(0,room.y+1)
	else
		load_room(room.x+1,room.y)
	end
end

function prev_room()
 if room.x==0 then
		load_room(7,room.y-1)
	else
		load_room(room.x-1,room.y)
	end
end

function load_room(x,y)
	has_dashed=false
	has_key=false
	spook=false

	--remove existing objects
	foreach(objects,destroy_object)
	
	--ignore deaths
	if level_index()~=8 then
		lastroom=level_index()
	end

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
	--debug stuff pls ignore
  if debug then
  if btnp(k_gemless,1) then
    if max_djump==1 then
      max_djump=2
    else
      max_djump=1
    end
  end
  if btnp(k_mute,1) then
    muted=not muted
  end
  if muted then
    music(-1)
  end
  if not flash_bg then
   if btnp(k_inc,1) then
    next_room()
   end
   if btnp(k_dec,1) then
    prev_room()
   end
  end
  end
  

	frames=((frames+1)%30)
	if frames==0 and not stop_timer() and not is_title() then
		seconds=((seconds+1)%60)
		if seconds==0 then
			minutes+=1
		end
	end
	
	if music_timer>0 then
	 music_timer-=1
	 if music_timer<=0 then
	  music(20,0,7)
	 end
	end
	
	if sfx_timer>0 then
	 sfx_timer-=1
	end
	
	-- cancel if freeze
	if freeze>0 then freeze-=1 return end
	
	if spook then
		-- beeg shake
		camera()
		camera(-2+rnd(5),-2+rnd(5))
	elseif is_heck() then
		if screenwait then
			-- smol shake
			camera()
			camera(-1+rnd(3),-1+rnd(3))
			screenwait=false
		else
			screenwait=true
		end
	elseif screenshake then
		-- screenshake
		if shake>0 then
			shake-=1
			camera()
			if shake>0 then
				camera(-2+rnd(5),-2+rnd(5))
			end
		end
	else
		camera()
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
	local bg_col=0
	local cloud_col=1
	if spook then
		bg_col=8
		cloud_col=8
	elseif is_heck() then
		bg_col=2
		cloud_col=2
	elseif flash_bg then
		bg_col = frames/5
	elseif new_bg~=nil then
		bg_col=2
		cloud_col=14
	end
	rectfill(0,0,128,128,bg_col)

	-- clouds
	if level_index()<21 then
		foreach(clouds, function(c)
			c.x += c.spd
			rectfill(c.x,c.y,c.x+c.w,c.y+4+(1-c.w/64)*12,cloud_col)
			if c.x > 128 then
				c.x = -c.w
				c.y=rnd(128-8)
			end
		end)
	end
	
	if not spook then
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
		if is_heck() then
			pal(12,5,1)
		end
		
		-- particles
		foreach(particles, function(p)
			if is_heck() then
				p.c=0
			end
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
	else
		-- draw objects
		foreach(objects, function(o)
			if o.type==player then
				draw_object(o)
			end
		end)
	end
	
	-- draw outside of the screen for screenshake
	rectfill(-5,-5,-1,133,0)
	rectfill(-5,-5,133,-1,0)
	rectfill(-5,128,133,133,0)
	rectfill(128,-5,133,133,0)
	
	-- credits
	if is_title() then
		print("x+c",58,80,5)
		print("matt thorson",42,96,5)
		print("noel berry",46,102,5)
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
 if spook then return false end
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
-->8
menuitem(1,"practice mod", function()
  -- 0-indexed highest level you can scroll to
  lvl_max=23
  
  -- update per level globals (reset fruits, powerups, etc.)
  function level_globals(level)
    got_fruit[1+level]=false
    max_djump=((level>=10 and level<=15 and not gemskip) or level==23) and 2 or 1
    new_bg=((level>=10 and level<=15) or level==23) and true or nil
      spook=level==23
  end
  
  -- additional globals
  showdebug=true
  last_time=0
  gemskip=false
  
  -- reset frame counter, show last time during spawn
  function reset_frame_count(last)
    last_time=last
    level_time=nil
  end
  
  -- draw button for input display
  function draw_button(x,y,b)
    rectfill(x,y,x+2,y+2,btn(b) and 7 or 1)
  end

  -- override player init (start frame counter)
  _player_init=player.init
  function player.init(this)
    _player_init(this)
    level_time=0
  end
  
  -- override kill_player (freeze frame count and restart level)
  _kill_player=kill_player
  function kill_player(obj)
    _kill_player(obj)
    reset_frame_count(level_time)
  end
  
  -- override next_room (freeze frame count and restart level)
  function next_room()
    will_restart=true
    delay_restart=1
    reset_frame_count(level_time)
  end
  
  -- override load_room (update globals, manage music, etc.)
  _load_room=load_room
  function load_room(x,y)
    pause_player=false
    flash_bg=false
    will_restart=false
    dead_particles={}
    level_globals(x+y*8)
    _load_room(x,y)
    music(-1)
  end
  
  -- override _update (frame counter and practice mod controls)
  __update=_update
  function _update()
    if level_time and level_time<999 then
      level_time+=1
    end
    if btnp(2,1) then
      showdebug=not showdebug
    end
    if btnp(5,1) then
        gemskip=not gemskip
        reset_frame_count(0)
        load_room(level_index()%8,flr(level_index()/8))
    end
    for i=0,1 do
      if btnp(i,1) then
        reset_frame_count(0)
        local lvl=clamp(level_index()+2*i-1,0,lvl_max)
        load_room(lvl%8,flr(lvl/8))
      end
    end
    __update()
  end
  
  -- override _draw (draw frame counter and input display)
  __draw=_draw
  function _draw()
    __draw()
    if showdebug then
      -- draw frame counter
      rectfill(2,2,14,8,0)
      local t=level_time and level_time or last_time
      print(sub('00',1,3-#tostr(t)),3,3,1)
      print(t,15-4*#tostr(t),3,7)
      -- draw input display
      rectfill(16,2,37,10,0)
      draw_button(26,7,0) -- l
      draw_button(34,7,1) -- r
      draw_button(30,3,2) -- u
      draw_button(30,7,3) -- d
      draw_button(17,7,4) -- z
      draw_button(21,7,5) -- x
    end
  end
  
  -- override draw_time (hide it)
  function draw_time() end

  -- entry point
  start_game=false
  frames=0
  seconds=0
  minutes=0
  deaths=0
  max_djump=1
  load_room(0,0)
  menuitem(1)
end)
__gfx__
000000000444444004444440044444400444444004444400000000000444444000aaaaa0000aaa000000a0000007707770077700000060000000600000060000
000000004444444444444444444444444444444444444440000000004444444400a000a0000a0a000000a0000777777677777770000060000000600000060000
000000008888888888888888888ffff888888888888888800444444088f1ff1800a909a0000a0a000000a0007766666667767777000600000000600000060000
00000000888ffff8888ffff888f1ff18888ffff88ffff8804444444488fffff8009aaa900009a9000000a0007677766676666677000600000000600000060000
0000000088f1ff1888f1ff1808fffff088f1ff1881ff1f80888ffff888fffff80000a0000000a0000000a0000000000000000000000600000006000000006000
0000000008fffff008fffff00033330008fffff00fffff8088fffff8083333800099a0000009a0000000a0000000000000000000000600000006000000006000
00000000003333000033330007000070073333000033337008f1ff10003333000009a0000000a0000000a0000000000000000000000060000006000000006000
000000000070070000700070000000000000070000007000077333700070070000aaa0000009a0000000a0000000000000000000000060000006000000006000
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
000000000000000000000000004ccc00004c000000400ccc0000000000000000cccccccc00000000000000000000000000000000000000000000000011111111
000000000000000000400004004ccccc004cc000004ccccc0000000000000000c77ccccc00000000000000000000000000000000000000000000000011111111
00000000000000000040000404200ccc042ccccc042ccc000000000000000000c77cc7cc00000000000000000000000000000000000000000000000011111111
aaaaaaaa0000000000400004040000000400ccc0040000000002eeeeeeee2000cccccccc00000000000000000000000000000000000000000000000011111111
999999990000000000400045040000000400000004000000002eeeeeeeeee200cccccccc00000000000000000000000000000000000000000000000011111111
99999999000000000044004542000000420000004200000000eeeeeeeeeeee00cc7ccccc0000000000000000000000000000000000cc00000000000011111111
88888888000000004004504540000000400000004000000000e22222e2e22e00ccccc7cc000000000000000000000000cc00000000ccccccccc000cc11111111
88888888000000004404545040000000400000004000000000eeeeeeeeeeee00cccccccc00000ccccccc0000cc000000cc00000000ccccccccc000cc11111111
88888888cccccccc0454445066666666000000000000000000e22e2222e22e00000000000000cccccccc0000cc000000cc00000000ccc000000000cc0000ccc0
88888888cccccccc0444444066666666000000000000000000eeeeeeeeeeee0000000000000cccc000000000ccc00000cc00000000ccc000000000cc00ccccc0
88888888cccccccc0004440066666666000000000000000000eee222e22eee0000000000000cc00000000000ccc00000cc000000000cc000000000ccccccc000
88888888aaaaaaaa0000450066666666000000000000000000eeeeeeeeeeee0000000000000ccc000000000ccccc0000ccc00000000cc000ccccc0cccccc0000
88888888999999990000400066666666000770777007770000e77e777ee7770055555555000cccc00000000cc0ccc000ccc00000000cccccccccc0cccc000000
8888888899999999000440006666666607777776777777700777777677777770555555550000cccc0000000cc0cccc000cc00000000cccccc00000cccc000000
88888888888888880004400066666666776666666776777777666666677677775555555500000cccc000000ccc0ccc000cc00000000ccc00000000ccccc00000
888888888888888800999900666666667677766676666677767776667666667755555555000000cccc00000ccc00ccc00ccc00000000cc0000000ccccccc0000
0000000077cccccc000000000007707770077700000000000077770050000000000000050000000cccc00000cc000ccc00cc00000000ccccccc00cc00ccccc00
00aaaaaa777ccccc0000000007777776777777700770000007000070550000000000005500000cccccc00000cc0000ccc0cc00000000ccccccc00cc0000cccc0
0a999999777ccccc00000000776666666776777777770000707700075550000000000555000cccccccc00000cc00000ccccc00000000000000000ccc0000ccc0
a99aaaaaaaaaaaaa000000777677766676666677776700007077bb075555000000005555000cccc000000000cc000000cccc00000000000000000ccc00000cc0
a9aaaaaa9999999900000777666666666666666666677000700bbb0755555555555555550000000000000000000000000ccc0000000000000000000000000000
a99999999999999900007777666666666666666666667700700bbb07555555555555555500000000000000000000000000000000000000000000000000000000
a9999999888888880000776666666666666666666666677007000070555555555555555500000000000000000000000000000000000000000000000000000000
a9999999888888880007676666666666666666666667677000777700555555555555555500000000000000000000000000000000000000000000000000000000
aaaaaaaacccccc7700767666666666666666666666676770004bbb00004b000000400bbb50000000000000050000010000000000000000000000000000000000
a49494a1ccccc77700777666666666666666666666766700004bbbbb004bb000004bbbbb55000000000000550100110000010000011110000010000000000000
a494a4a1ccccc7770007676666666666666666666666700004200bbb042bbbbb042bbb0055500000000005550111111001111000010011000000100000000000
a49444aaaaaaaaaa00076666666666666666666666677000040000000400bbb00400000055550000000055550101001001001100010001000000000000000000
a49999aa999999990000767777666667666777677677000004000000040000000400000055550000000055550100001001000100010111000010000000000000
a4944499999999990000776677776776666666777770000042000000420000004200000055500000000005550000000001100100011100000011011000000000
a494a444888888880000077707777777677777707000000040000000400000004000000055000000000000550000000000111100000000000001110000000000
a4949999888888880000000700777007770770000000000040000000400000004000000050000000000000050000000000010000000000000000000000000000
23232323235262b1b1b1b1b1b1b1b1b1828292a28392a28292000000001142520000001352525233000000000000000000000000000000000000000000000000
000000f4f4f4f4f4f4f4f4f4f4000000525252525223235252526200a28200425252526200000000000000004252525200000000000000000000000000000000
b1b1b1b1b14262b200000000000000b3828293000000a39200000000b302132300000082132333010000000000000002000000000000000000c0000000000000
000000f40000000000000000f4000000525223233382831323526211008293425252233300000000000000001323525200000000000000720000000000000000
10000000b34262b200000000000000b392a201768586820000000000000000b3000000828282829200000000000000b1000000b0000000000000000000000000
000000f40000000000000000f4000000523392a201828292a242523200a28242523300000000a300000000000000425200000000000000423200000000000000
32111100b34262b200009311a30000b3858682828382920000000000000000b3000000a2838282000000000000000000000000000000000000000000000000b0
000000f40000647400106700f400000062920c1c00a28200001352620000824262000000000082828282930000a3425200000000000000426200000000000000
522232b2b34262b20000a202829200b3828382920000000000000000000000b3000000008282829300000000000000000000000000c000000000000000000000
000000f44555657545554555f4000000623d0d1d00009200000042620000a2426200000093a38282828282000082135200000000000024426200000000000000
525262b2b34262b2000000a2920000b3000000000000000000000000000000b300000000a282828293000000000000000000000000000000b000000000000000
00002636353535353535353546560000522222320000000000a3426200001142620000a38282018282018293a382824200000000000025425232000000000000
842333b2b34262b200000000000000b3000000000000000000000000000000b300000000a3829282820000000000000000000000000000000000000000c00000
00002747374737473747374737570000525252620000003ca32d426293001252523200a282828292a28282828282924200000000000012525262000000000000
62b1b100b34262b200000000000000b300000000000000000000000000b30212000000a382820082829300000000b00000000000000000000000000000000000
0000000000000000000000000000000052525262932c4c122222526282004252526200a382828282828282829200004200000000001252525262000000000000
62001111114262b200000000111111110000000000000000000000000000b34200000082829200a2828293000000000000000000000000000000000000000000
00000000000000000000000000000000525252522222225252525233829342525262a38282828383838382820000125200000000004252232352322400000000
62004353532333b200000000122222220000000000000000000000000000b3420000a38282000000a28283930000000000000000340000000000000000000000
00000000000000000000000000000000525252525252525223233300a282425252628292a2838383838383920000425200000000125233000013622500000000
6200b1b1b1b1b10000c20000428452520000000000000000000000000000b3420012328382000000008282829300000000000000123200000000000000000000
000000000000000000000000000000002323235252232333b1b1b100008242525252329300a2a283838382936474425200000024423300000000423200000000
620000110000000000c3000042525252c200000000000010000000000000b313a313338292000000a38282820100000000000000426200000000000000000000
0000647400c200c200060000c200c200a2930013330000a29300000000a2425252526292000000a200a282826575425200000025036474000000426200000000
62000072b20000b34363b20042525252c302020000000002000000000000a3828393a38200000000828282828293000000000000425232000000000000000000
0000657500c300c300000000c300c30000a293b1b1001111a29311111222525252525232000000000000a2821222525200000012626575106700426200000000
62a39303b2009300b1b100004252525222222232000000122232e3000000a20182828292000010a3828292a28282930000000012525262000000000000000000
001222223212223212222232122232120010a2930000123200a212225252525252525252320010000000a3824252525200000042522222222222525232000000
6292a203b2a301930000a3a3425252525252525232001252525232000000a3828201829300a31222328200008282830000000042525262100000000000000000
00135252621323334252526213233342222222222222525222225252525252525252525252222222222222225252525204040416151515151515151517040404
6293a303b200a2a2768682924252525252525252522252525252627686828382828282828201428462920000a283829300000042525252320000000000000000
00004252522222225252525222222252525252525252525252525252525252525252525252525252525252525252525205050505050505050505050505050505
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000003bb3000000000000010111101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000bbbbbb00001011110111717111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000bbbb7bb90001171711111991111000011100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000bbbbbbb00001199111101777110000171710000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000bbbb777600001177711101777110000199110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000bbbb677700000977911001777110000111110000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000b3bb7777000009669110099d99110009669600000000000000000000000000000000000000000000000000000000000000000094a4b4c4d4e40000000000
000bbfbb777760005555555500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b3fb3777770005555555500000000c00c000c00000000000000000000000000000000000000000000000000000000000000000095a5b5c5d5e5f500000000
00033f33777770005511115500111100c00c0c0c0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00033f37777770005000000500107000cccc000c00000000000000000000000000000000000000000000000000000000000000000096a6b6c6d6e6f600000000
000f3ff777777000100900110d1797d0c00c0c000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00ffff7777777000117771110d6666d0c00c0c0c0000000000000000000000000000000000000000000000000000000000000000000000b7c7d7e70000000000
0fffff97777790001977911100666600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000009996669990059669115069dd900cccccccc0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
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
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000
0000000000000000000000000000000000000000000000000f00000000000000000000000000000000000000000000000000000000000000000000000f000000
00000000000000000000000f000000000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000
000000f000000000000000000000000000000000000000000000000f000000000000000000000000000000000000000000000000000000000000000000000000
00f000f000000000000000000000000000000000000000000000000f000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000007f0000000006600000000000000000f0000000000000000000f000f0000000000000000
00000000000000000f00000000000000000000000000000000000000000000000000660000000000000000000000000000000000000000000000000000000000
0000000000000000000000000f00000000000000000000000f00000f000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000f00000000000000000000000000000000000000000000000000000f000f0000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000007000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000f0000000000000555055505550555000f0555050500550555005500550550000000000000000000000000000000000000000
00000000000f000000000000000000000000f0000055505050050005000000050050505050505050005050505000000000000000000000000000000000000000
00000000000000000000000000000000000000000050505550050005000000050055505050550055505050505000000000000000000000000000000000000000
0000000000000000000000f00000000000000000005050505005000500000005005050505050500050505050500000000000000000000000000f0000f0000000
00000000000000000000000000000000000000000050505050050005000000050f50505500505055005500505000000000000000000000000000000000000000
00000000000000000000000000f00000000000000000000f0000000000000000000000000000000000000000000000000000000f000000000000000000000000
00000000000000000000000000000000000f00000000605500055055505000f00055505550555055505050000000000000000000000000000000000000000000
000000000000000000000000000000000000000f000000505050505000500000005050500050505050505000000000000000000000000000000000000000f000
00000000000000000000000000000000000000000000005050505055005000000055005500550055005550000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000005050505050005000000050505000505050500050000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000f0505055005550555000005550555050505f505550000000000000000000000000000000000000000000
00000000000000000000000000000000000000f00000000000000000000000f0000000000000000000000000000000000000f000000000000000000000000000
0000000000000000f000000000f0000000000000f0f0f0f000f0f0f0f0f000000000000000000000000000000000000000000000000000000f00000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000f000000000
000000000000f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000
000000000006000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000f000000000000000000000000600000000000000000000000000000000000000000
00000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000000000000000000000f000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000f0000000000000000000000000000000000000000000000000f00000000f00000000000000000000000000000000000
00000f00000f0000000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000f0000000000000000000
0f0000000000000000000000000000000000000f00000000000f000000f000000000000000000000000000000000000000000000000000000000000000000000
00000000000000f0000000000000000000000000000000000000000000000000000f000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000f000000000000000f0000000000000f00000000000000000000000000000000000000000000000000000000f
0000000000000000f00000000000000000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000f00000000000000f00000000000000000000000000000000000000000000000f0f0000000000000000000000000
00000000000000000000000000f000f00f0f00f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
00000000000000000000000000000000040200000000000000000002000000000303030303030303040404020200000003030303030303030404040202020202020002000000020203020202020200110202020b0808020204020202020202020002090909090004040202020202020200020909090900000004040202020200
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002020202020000000000000000000000020202020000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
2838292a00003b242525252525252525252532323232330000000000000000583232323232323226000000002a292a29483232323232323225265868102900000000003125253232323232323232323225323232323232323248260000003b241b1b1b1b1b1b1b1b1b1b1b003a293b24003b3132323232323232323232323232
2828002839003b24252525323232323225261b1b1b1b1b000000000000003a291b1b1b1b1b1b1b300000000000676839262b00000000000124262839000000000000000024262b28390000110000000126290000000000000024260000003b240000000000000000000000002a003b2400001b1b1b1b1b1b1b1b1b1b1b00002a
2a393a5829003b242532333a2828292a48262b000000000000000000002829000000000000000030000000003a281028261100002135353532332929000000000000000024262b2a28393b202b00002026000000000100000024260000003b2400140000000000160000001600003b2400000000000000000000000000000000
2a29676800000024330028282838290032332b0000000000171700000028393a0000000000000030000000002a292a2a32362b00302b00002a290000000000000000000024262b003a29001b0000001b262c0000213617173448260000003b24223600000000000e001111111111112417000000171700001717000017170000
00003a290000003029002a292a67586829000000000000000000000000286867000000212300003000000011111111111b1b0000302b0000000011000000003a0000000031262b2a1067000000000000333c3f3e300000003b24260000003b3126000000000000003b2135353535352511111111111111111111111111110000
28382900000000300000000000282900390000000011000000000000002a391100003b2433000030000000212222222200000000302b0000000027003a6768290000000000302b00292900000000001120313233370000003b2426000000001b26390000000000003b3000000000002422222222222222222222222222360000
290000000000003000000000002a675810290000002711110000000000002a3400003b3000000030000000242525254800111111302b0000000030002a1028290000000000302b000000000000003b212867586827000000112432360000000033280000000000163b30000008000024252548252525252525254825262b0000
2222232b00003b300000000000002a382900000000312223111111110000001b00163b3000000030000000313232252500343535332b00000000300000002a392c00000000302b000000001111003b241029002a3000003b21331b1b00000011102900000000000e3b3000000000002432323232323232323232323232360000
2525262b00003b30000000002122232a11000000001b31252222223600000000000e3b30000000300000000000003125001b1b1b1b0000000000300000002a383c00000000302b0000003b34362b3b31290000003000003b3000000000003a3429000000000000003b302b0000003b241b1b1b1b1b1b1b1b1b1b1b1b1b1b0000
2525262b00003b370000000024482600232b000000001b312525262b0000000000003b30000000300000000000003b240000000000001111111130000000000023202b0000302b000000001b1b003a2800000000370000113000000000002a2800000000000000003b302b0000003b2400000000000000000000000000000000
2548262b0000001b0000003a24252600483536000000003b3132332b0000000001003b30000000370000000000003b240000000000003435353532353536000025232b0000302b00000000002a676838001400001b0000203700001100006828110000000000000000302b0016003b2400000000000000000000000000001600
2525262b000000000000002031323300261b1b00000000001b1b1b000000000023003a30000000000016000000003b240000000000001b1b1b1b1b1b1b1b000048262b0000372b0000000000002a2a2a22232b000000001b1b0000270000082a232b00000021222222332b000e003b2411110000001100000000001100000e00
2525262b001600000000002728290000332b003a0000000000000000000000002639383000000000000e000000003b240000000000000000000000000000000025262b00001b0000000000000011111148262b0000000000000000242222233a262b000034323232330000003a393a2422232b013b272b0000003b2700000000
2525262b000e001100000030280001001b00283800000000001111000000012c262a2830000000000000000000003b243535362b00000000000000000000001225262b0000000000111111111127212225261111110000000000002425254822262b000000000000000000002a10292448262b173b302b1717173b3000005868
2525262b00003b2700000030290027000068292a0017170000212300003b203c26682830000000110000000000003b311b1b1b00000012000000120000003b2725262b0000000000212222222226242525482222230000110000002448252525262b000000000001000000003a29002425260011003000111111003000002a38
2525262b00003b3000000030000030006828003a6758000000242600003b21232638293000003b272b00000000003a1067683900003b272b003b272b00003b3025262b00003a6768244825252526242548252525260000270000002425254825262b3a3917171720003a393a2a39002425265827583058272727583067686729
254825252525252628382824252525250000002c00000000000000002c000000261b1b1b1b1b1b00002a10293b2425252525252525252532323232324826002a3232323232323232323232323233002a1029003132323232323232323232323232323248483232323232323232332b2a482525252525252525262b0000002a39
252525252525323329002a31322525480000003c00000000000000003c000000262b000000000000166829003b242525252525254825262b1b1b1b3b242667001b1b1b1b1b1b1b1b1b1b1b1b1b1b00002900000000001600000000000000000001000024261b1b1b1b1b1b1b1b1b0000252525323225252525262b0000003a29
3232322548262b00000000003b31323200003b202b0000000000003b202b0000262b0000000000000e2a29003b242525252525252525262b0000003b24262900000000000000000000000000000000000000000000000e0000000000002c000017000024262b00000000001600000000252526290124252525262b00003a293a
0000003132332b0000000000000000000000001b00000000000000001b000000262b0000000011111111111111242548252525252525262b0016003b3126006800000000000000000000001111111111111111111111111111111100003c000011000024262b00160000111111111111253233003425252525261100002a393a
0000000000000000000000000000000000000000000000000000000000000000262b0000001121233435353536313225254825252525262b000e00003b30002a080000000000000000003b343535353522222223343535353535353522362b00232b0024262b000e003b343535353535261b1b00582425323232360000002a10
0000000000000000000000000000000000000000000000000000000000000000262b0000112148331b1b1b1b1b1b3b24323232323232332b000000003b30000035353535353621232b00000000002a2832323233282829000000102830000000262b0024262b000000001b1b1b1b1b1b2600003a3824261b1b1b1b0000003a29
0000000000001100000000000000000000000000000000000000000000000000262b163b2031331b0000000000003b241b1b1b1b1b1b1b39000011003b302b001b1b1b1b1b3b24262b00000000003a1039003a102900000011002a383000003a262b0024262b0000000000000000160026682828293133003a3a390000002a38
0000000000002000000000000000000000000000000000000000000000000000262b0e001b1b1b000000000000003b24000000003a003a28003b27393b302b0001140000003b24262b000000002a292a286768290000003b270000283000002a332b0024261111111111111111000e0026282900001b1b3a28292a390000002a
0000000000002a390000000000003900003a0000000000000000000000000000262b0000000000000000000000003b2400013a2838675828003b30293b302b0022231111003b24262b00000000000011292a29000000003b3000002a30000000000000242535353535353535362b0068263800000000002828393a2900000000
0000000000003a2839003a28282810797a102828287900000000000000000000262b00000000003b2122232b00003b2422232b2a293a1029003b30003b302b1648253536003b31332b00000000003b27111111000000003b300000003000003a00111124261b1b1b1b1b1b1b1b00002a262900000000002a1028290000003422
0000000000002a382828282900002900002a0000000000000000000000000000262b00000000003b3132332b00003b2425262b00003a3829003b30003b372b0e25262b0000002a380000000000003b37222223110000003b300000003700002a68212248262b000000001600003a676826000000000000002810390000003b24
0000000000003a28292a39000000000000004647002c002c006000002c002c0026111111111111001b1b1b0000003b2425262b0000002900003b3000001b000025262b000000002a390000000000001b252525232b00003b300000001b0000002a242525262b000000111111112a102926111111003a00002a28290000003b24
0000000000212321222223000000000000015657003c003c000000003c003c00482222222222232b000000000011112425262b1100000011003b300000003a67252611111100003b3435362b00003a28323232332b00163b300000001600000000313232332b00000021222223002a0025222223002a39000028000000003b24
0100000000313324252526000000000000212222232122232122222321222321252525252548262b000000003b21224825262b202b003b20393b300000112a2a25253535362b00001b1b1b28676828381b1b1b1b00000e3b303900000e00003a6768290000000000002425252600003a25252526003a28393a28390012003b24
232b000021222225252526000000000000312525263132332425252631323324252525252525262b010000003b24252525262b1b0012001b383b30003b272b0025261b1b1b0000003a38681039002a100100002a6768293b302900001100002a28290000000000003a2425252658682925252525222222222222222222222225
262b000024252525252526002700000000002425252222222525252522222225252525252525262b176768393b24482525262b3a67206810283b30003b302b0025262b00003a6768292a29002a6768282000003a292a393b3039003a2739003a102839001717173a29242525262a390025252525252525252525252525252525
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
010400003e6503e6503d6403d6403c6403b64039640376403464032630306302d6302b6302863025630206201b620156200f62009610026100107001070010700107001060010600106001060010600104001015
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
00 41424344
00 41424344
00 41424344
01 183d5a44
00 18193d44
00 1c1b3d44
00 1d1b7d44
00 1f217d44
00 1f7d2144
00 1e3d2244
02 203d2444

