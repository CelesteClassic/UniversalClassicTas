pico-8 cartridge // http://www.pico-8.com
version 27
__lua__
-- ✽why?✽
-- acedicdart

-- globals --
-------------

cartdata("why-ruins")

room = { x=0, y=0 }
objects = {}
types = {}
freeze = 0
shake = 0
will_restart = false
delay_restart = 0
got_fruit = {}
has_dashed = false
sfx_timer = 0
has_key = false
pause_player = false
flash_bg = false
music_timer = 0
countdown = 7.6
fadein = 0
has_treasure = false
level_num = 31

if peek4(0x5e18)~=0 then
	saved_time=peek4(0x5e18)
else
	saved_time=10800.0
end


k_left=0
k_right=1
k_up=2
k_down=3
k_jump=4
k_dash=5

tempshake=0

----------
----------

stmusic = music
current_music = -1

function music(a,b,c)
	stmusic(a,b,c)

	current_music = a
end

regret_text = "-- gIVE UP, INTRUDER --#yOU SHALL NEVER ESCAPE,#AFTER WHAT YOU'VE DONE."

level_data = {
	{
		"\"keep out\"",
		"-UseOld",
		"-SlowDash",
		music = 0,
	},
	{
		"tEMPLE eNTRANCE",
		"-UseOld",
		"-SlowDash",
	},
	{
		"tREASURE rOOM",
		"-UseOld",
		music = 30,
		chest_opened = false,
	},
	{
		"sPLIT pATHS",
	},
	{
		"mOUNTAIN uNDERSIDE",
	},
	{
		"oLD cLIMBING pATH",
	},
	{
		"cLIFF",
	},
	{
		"tIGHT sPACE",
	},
	{
		"tUNNEL",
	},
	{
		"tIGHTER sPACE",
	},
	{
		"eXIT ?",
	},
	{
		"rEGRET",
		"-StopTime",
		music = 30,
	},
	{
		"tRAP",
		"-Wrap",
		music = 20,
	},
	{
		"sHORTCUTS",
		"-Wrap",
	},
	{
		"wALL",
		"-Wrap",
	},
	{
		"oUT OF rEACH",
		"-Wrap",
	},
	{
		"pINK",
		"-Wrap",
	},
	{
		"oVERHANGING rOCK",
		"-Wrap",
	},
	{
		"cOLD pLACE",
		"-Wrap",
	},
	{
		"tUNNELS",
		"-Wrap",
	},
	{
		"mAZE",
		"-Wrap",
	},
	{
		"oNE-WAY cLIMB",
		"-Wrap",
	},
	{
		"tIGHTEST sPACE",
		"-Wrap",
	},
	{
		"thief thief thief",
		"-Wrap",
	},
	{
		"sUMMIT",
		"-StopTime",
		"-Wrap",
		music = 30,
	},
	{
		"iT'S A sECRET!",
		"-UseOld",
		"-StopTime",
		"-Wrap",
		music = 10,
	},
}

if saved_time<1800 then
	regret_text="aND NOW YOU WILL ALWAYS#   BE STUCK HERE, AND  #   EVERY TIME WILL BE  # HARDER THAN THE LAST. "
	level_data[12][1]="rEPETITION"
end

function hastag(l,s)
	for k in all(level_data[l]) do
		if k==s then
			return true
		end
	end
end

done_ev = {}

function do_once(id,func) 
	if not done_ev[id] then
		done_ev[id] = true
		func()
	end
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
	milliseconds=0
	seconds=0
	minutes=0
	music_timer=0
	start_game=false
	music(0,0,7)
	load_room(0,0)
end

function is_title()
	return level_num==32
end

function level_index() -- old
	return level_num-1 -- probably shouldn't use this
end                    -- meh

if (not poke4) and (not peek4) then
	function poke4()end
	function peek4()end
end   -- don't ask

-- effects --
-------------

clouds = {}
for i=0,16 do
	add(clouds,{
		x=rnd(128),
		y=rnd(128),
		spd=.2+rnd(.5),
		w=32+rnd(32)
	})
end

particles = {}
for i=0,24 do
	add(particles,{
		x=rnd(128),
		y=rnd(128),
		s=0+flr(rnd(5)/4),
		spd=0.01+rnd(1),
		off=rnd(1),
		c=10
	})
end

rocks = {}
add(rocks,{
	x=rnd(128),
	y=rnd(100)-100,
	s=rnd(2)+1,
	spd=2+rnd(1)
})

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
		if (pause_player) then return end
		
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
		 this.grace-=0
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
			if this.spd.x~=0 then
				this.flip.x=(this.spd.x<0)
			end

			-- gravity
			local maxfall=2
			local gravity=0.21

  	if abs(this.spd.y) <= 0.15 then
   	gravity*=0.5
			end
		
			-- wall slide
			if input~=0 and this.is_solid(input,0) and not this.is_ice(input,0) then
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
			local wall_dir=(this.is_solid(-3,0) and -1 or this.is_solid(3,0) and 1 or 0)

		 		if not on_ground and wall_dir~=0 then
		  			-- wall jump
		  			psfx(2)
				 	this.jbuffer=0
				 	this.spd.y=-2
				 	this.spd.x=-wall_dir*(maxrun+1)
			 		if not this.is_ice(wall_dir*3,0) then
		 				init_object(smoke,this.x+wall_dir*6,this.y)
					end
				elseif this.grace>0 then
					-- normal jump
					psfx(1)
		  			this.jbuffer=0
		  			this.grace=0
					this.spd.y=-2
					init_object(smoke,this.x,this.y+4)
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
		 	if input~=0 then
		  	if v_input~=0 then
		   	this.spd.x=input*d_half
		   	this.spd.y=v_input*d_half
		  	else
		   	this.spd.x=input*d_full
		   	this.spd.y=0
		  	end
		 	elseif v_input~=0 then
		 		this.spd.x=0
		 		this.spd.y=v_input*d_full
		 	else
		 		this.spd.x=(this.flip.x and -1 or 1)
		  	this.spd.y=0
		 	end
		 	
		 	psfx(3)
		 	freeze = ( hastag(level_num,"-SlowDash") and 3 or 0 )
		 	this.dash_target.x=2*sign(this.spd.x)
		 	this.dash_target.y=2*sign(this.spd.y)
		 	this.dash_accel.x=1.5
		 	this.dash_accel.y=1.5
		 	
		 	if this.spd.y<0 then
		 	 this.dash_target.y*=.75
		 	end
		 	
		 	if this.spd.y~=0 then
		 	 this.dash_accel.x*=0.70710678118
		 	end
		 	if this.spd.x~=0 then
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
		if level_num<25 then
		 if this.y<-4 then next_room() end
		elseif level_num==25 then -- special case
		 if this.y<0 then next_room() end
		end
		
		-- was on the ground
		this.was_on_ground=on_ground
		
	end, --<end update loop
	
	draw=function(this)
	
		-- screen border
		if this.x<-1 or this.x>121 then 
			if hastag(level_num,"-Wrap") then
				if this.x<-4 then
					this.x=122
				elseif this.x>124 then
					this.x=-2
				end
			else
				this.x=clamp(this.x,-1,121)
				this.spd.x=0
			end
		end
		
		set_hair_color(this.djump)
		draw_hair(this,this.flip.x and -1 or 1)
		if this.grace>0 then
			pal(5,14)
		end
		spr(this.spr,this.x,this.y,1,1,this.flip.x,this.flip.y)	
		pal(5,5)
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
		if this.spr==22 or this.spr==15 then
			this.offset+=0.01
			this.y=this.start+sin(this.offset)*2
			local hit = this.collide(player,0,0)
			if (not this.pink) and hit~=nil and hit.djump<max_djump then
				psfx(6)
				init_object(smoke,this.x,this.y)
				hit.djump=max_djump
				this.spr=0
				this.timer=60
			end
			if this.pink and hit~=nil and hit.grace<1 then
				psfx(6)
				init_object(smoke,this.x,this.y)
				hit.grace=6
				this.spr=0
				this.timer=60
			end
		elseif this.timer>0 then
			this.timer-=1
		else 
		 psfx(7)
		 init_object(smoke,this.x,this.y)
			this.spr=this.pink and 15 or 22 
		end
	end,
	draw=function(this)
		if this.spr==22 or this.spr==15 then
			spr(13+((this.offset*8)%3<1 and 0 or 1),this.x,this.y+6,1,1,this.offset>1.5)
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
		if this.state~=2 then
			if this.state~=1 then
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
			got_fruit[level_num] = true
			init_object(lifeup,this.x,this.y)
			destroy_object(this)
		end
		this.off+=1
		this.y=this.start+sin(this.off/40)*2.5
	end
}
add(types,fruit)

fly_fruit={
	tile=45,
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
			got_fruit[level_num] = true
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
		spr(26,this.x,this.y)
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
		if is==10 and is~=was then
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
		this.x+=4
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
	init=function(this)
		this.timer=0
	end,
	draw=function(this)
		this.timer+=.05
		if this.timer<6 then
			rectfill(this.x+3,this.y-2+this.timer,this.x+13,this.y+3,6)
		end
		if this.check(player,4,0) then
			if this.index<#regret_text then
			 this.index+=0.5
				if this.index>=this.last+1 then
				 this.last+=1
				 --sfx(35)
				end
			end
			this.off={x=5,y=96}
			for i=1,this.index do
				if sub(regret_text,i,i)~="#" then
					rectfill(this.off.x-2,this.off.y-2,this.off.x+7,this.off.y+6 ,7)
					print(sub(regret_text,i,i),this.off.x,this.off.y,0)
					this.off.x+=5
				else
					this.off.x=5
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

small_adelie_statue={
	tile=105,
	update=function(this)
		for x=-1,1 do
			for y=-1,1 do
				local hit=this.collide(player,x,y)
				if hit~=nil then
					this.spd.x=x*2
					this.spd.y=y
				end
			end
		end
		this.spd.x*=.9
		this.spd.y=appr(this.spd.y,2,.21)
		if this.y>128 then

			dead_particles={}
			for dir=0,7 do
			local angle=(dir/8)
			sfx(0)
			add(dead_particles,{
				x=this.x+4,
				y=this.y+4,
				t=10,
				spd={
					x=sin(angle)*3,
					y=cos(angle)*3
				}
			})
			mset(61,26,0)
			destroy_object(this)
			end 
		end
	end,
	draw=function(this)
		if this.x<-1 or this.x>121 then 
			this.x=clamp(this.x,-1,121)
			this.spd.x=0
		end

		spr(this.spr,this.x,this.y)
	end
}
add(types,small_adelie_statue)

big_chest={
	tile=96,
	init=function(this)
		this.state=0
		this.hitbox.w=16
		if level_data[3].chest_opened and has_treasure then
			destroy_object(this)
		end
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
				this.timer=100
				sset( 74, 42, 2 )
				sset( 76, 42, 2 )
				sset( 75, 34, 2 )
				sset( 77, 34, 2 )
				sset( 73, 107, 12 )
				sset( 77, 107, 12 )
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
				for i=1,3 do
					mset(44,i,0)
					init_object(smoke,128-32,i*8)
				end
				foreach(clouds, function(c)
					c.spd+=4+rnd(3.5)
				end)
				sset( 74, 42, 8 )
				sset( 76, 42, 8 )
				sset( 75, 34, 8 )
				sset( 77, 34, 8 )
				level_data[3].chest_opened=true
				countdown=10800.0
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
		music(20,500,7)
	end,
	draw=function(this)
		this.spd.y=appr(this.spd.y,0,0.5)
		local hit=this.collide(player,0,0)
		if this.spd.y==0 and hit~=nil then
		 --music_timer=45
			sfx(51)
			freeze=10
			destroy_object(this)
			has_treasure=true
			countdown=saved_time
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
		local position = (frames/5)%3
		sspr(48,56,3,8,this.x,this.y)
		if position>=2 then
		 sspr(51,56,5,3,this.x+3,this.y)
		elseif position>=1 then
		 sspr(51,59,5,4,this.x+3,this.y,5,4)
		elseif position>=0 then
		 sspr(51,56,5,3,this.x+3,this.y,5,3,false,true)
		end
		if this.show then
			rectfill(25,2,103,39,0)
			spr(26,46,5)
			print("X"..this.score,55,8,7)
			if has_treasure then
				spr(102,70,5)
			end
			print("cOUNTDOWN-",28,15,8)
			draw_time(68,15)
			print("gLOBAL-",28,23,7)
			draw_time(56,23,true)
			print("dEATHS:"..deaths,48,32,7)
		elseif this.check(player,0,0) then
			sfx(55)
	  		sfx_timer=30
			this.show=true
		end
		if not this.show then
			local p
			for i=1,count(objects) do
				if objects[i].type==player then
					p = objects[i]
					break
				end
			end
			if p~=nil then
				print("☉",this.x+(p.x/32-2),this.y-32,8)
			else
				print("☉",this.x-1,this.y-34,8)
			end
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

			local cname = level_data[level_num]
			if cname then
				print(cname[1],64-(#cname[1])*2,62,7)
			else
				local level=(level_num)*100
				print(level.." M",52+(level<1000 and 2 or 0),62,7)
			end
			--print("---",86,64-2,13)
			
			draw_time(4,4)
		end
	end
}

-- object functions --
-----------------------

function init_object(type,x,y)
	if type.if_not_fruit~=nil and got_fruit[level_num] then
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
	end
	
	obj.is_ice=function(ox,oy)
		return ice_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h)
	end
	
	obj.collide=function(type,ox,oy)
		local other
		for i=1,count(objects) do
			other=objects[i]
			if other ~=nil and other.type == type and other ~= obj and other.collideable and
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
 if level_num==24 then
  if has_treasure then
  	poke4(0x5e18,saved_time-countdown+7.7)
  end
  shake=0
  foreach(clouds, function(c)
	c.spd=.2+rnd(.5)
  end)
 end

 local leveldat = level_data[level_num+1]
 if leveldat then
 	if leveldat.music then
		music(leveldat.music,500,7)
 	end
 end

 if countdown>7.5 then
	if room.x==7 then
		load_room(0,room.y+1)
	else
		load_room(room.x+1,room.y)
	end
 end
end

function load_room(x,y)
	level_num=x%8+y*8+1
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
			elseif tile==15 then 
				local b=init_object(balloon,tx*8,ty*8)
				b.pink=true 
				b.spr=15
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

	if hastag(level_num,"-UseOld") then
		foreach(clouds, function(c)
			c.spd=.2+rnd(.5)
  		end)
	else
		foreach(clouds, function(c)
			c.spd=2+rnd(5)
  		end)
	end
	
	if not is_title() then
		init_object(room_title,0,0)
	end
end

-- update function --
-----------------------

function _update()
	frames=((frames+1)%30)
	if level_num<25 then
		milliseconds=flr(frames*100/30)
		if frames==0 then
			seconds=((seconds+1)%60)
			if seconds==0 then
				minutes+=1
			end
		end
	end
	
	if music_timer>0 then
	 music_timer-=1
	 if music_timer<=0 then
	  stmusic(current_music,1000,7)
	 end
	end
	
	if sfx_timer>0 then
	 sfx_timer-=1
	end
	
	-- cancel if freeze
	if freeze>0 then freeze-=1 return end

	-- screenshake
	camera(-(shake/2)+rnd(shake),-(shake/2)+rnd(shake))

	
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
	
	poke(0x5f2d,1)
	-- start game
	if is_title() then
		if not start_game and (btn(k_jump) or btn(k_dash)) then
			music(-1)
			start_game_flash=50
			start_game=true
			sfx(38)
		elseif not start_game and btn(k_down) then
			poke4(0x5e18,0)
			saved_time=10800.0
			sfx(14)
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
function _draw(recursion)
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
			pal(3,c)
		end
	end

	-- clear screen
	local new_bg = (not hastag(level_num,"-UseOld")) or (level_num==3 and level_data[3].chest_opened)
	local bg_col = 12
	if flash_bg then
		bg_col = frames/5
	elseif new_bg then
		bg_col=0
	end
	if is_title() then
	  bg_col=0
	end
	rectfill(0,0,128,128,bg_col)

	-- clouds
	if not is_title() then
		foreach(clouds, function(c)
			c.x += c.spd
			rectfill(c.x,c.y,c.x+c.w,c.y+4+(1-c.w/64)*12, new_bg and 2 or 6)
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
		p.y += p.spd
		p.x += sin(p.off)
		p.off+= min(0.05,p.spd/64)
		circfill(p.x,p.y,p.s,p.c)
		if p.y>128+4 then 
			p.y=-4
			p.x=rnd(128)
		end
	end)

	if ((not hastag(level_num,"-UseOld")) or (level_num==3 and level_data[3].chest_opened)) and not is_title() then

		-- rocks
		if (countdown<1800) then
			foreach(rocks, function(r)
				r.y += r.spd
				for i=r.s,0,-1 do
					circfill(r.x,r.y+i*2+(i-1)*2+2,i,10)
					circfill(r.x+rnd(4)-2,r.y+2,rnd(1.5),6)
				end
				if (r.y>128+(r.s/2)*(1+r.s)) and (level_num<24) then 
					r.y=rnd(100)-100
					r.x=rnd(128)
					r.s=rnd(2)+1
				end
			end)
		end

		-- screenshake switch
		menuitem(1,"screenshake: " .. (shake==0 and "off" or "on"),function()
			if shake==0 then
				shake=tempshake
			else
				tempshake=shake
				shake=0
			end
		end)

	end
	
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
		print("WHY ARE YOU STEALING FROM",14,27,5)
		print("❎/🅾️ sTART",42,78,5)
		if saved_time<10800.0 then
			print("⬇️ rESET BEST TIME",28,84,5)
		end
		print("celeste BY: mATT tHORSON,\n       nOEL bERRY",16,98,5)
		print("mOD BY: aCEDICdART",32,112,5)
	end

	if level_num==26 then
		rectfill(8,116,122,124,0)
		print("HTTPS://YOUTU.BE/ZWzisYPGa9m",10,118,9)
		pal(9,frames/3.75+8,1)
	end
	
	if level_num==25 then
		menuitem(1)
		local p
		for i=1,count(objects) do
			if objects[i].type==player then
				p = objects[i]
				break
			end
		end
		if p~=nil then
			local diff=min(23,40-abs(p.x+4-64))
			rectfill(0,0,diff,128,0)
			rectfill(128-diff,0,128,128,0)
		end
	end

	if level_data[3].chest_opened and (level_num<25) then

		camera()
		draw_time(4,4)
		if (not hastag(level_num,"-StopTime")) or (countdown<7.6) then
			countdown-=0.1
			if (countdown<1800) then
				do_once("inc_shk",function()
					shake=2
				end)
				if (countdown%min(saved_time/15,120)<0.1) then
					add(rocks,{
						x=rnd(128),
						y=rnd(100)-100,
						s=rnd(2)+1,
						spd=3+rnd(1)
					})
				end
			end
			if countdown%1800<0.1 then
				stmusic(-1,500)
				sfx(63,1)
				music_timer=240
			end
		end
		if countdown<3.75 then
			
			do_once("expl_rocks", function()
				for i=1,7 do
					add(rocks,{
						x=rnd(128),
						y=rnd(100)-100,
						s=rnd(3)+1,
						spd=5+rnd(1)
					})
				end
			end)

		end
	end

	if not recursion then
		change()
	else
		return 1
	end
end

function change()
	for i=0,6 do pal(i,128+i,1) end 
	pal(12,140,1)
	pal(10,6,1)
	poke(0x5f2e,1)


	if countdown<7.6 then

		music(-1,1000)

		local fadetable={
		{128,133,133,5,5,141,134,134,134,134,6,6,6,6,7},
		{1,1,133,5,5,141,13,13,13,134,6,6,6,6,7},
		{133,133,5,141,141,134,134,134,134,6,6,6,6,7,7},
		{131,131,5,5,13,13,13,13,6,6,6,6,6,7,7},
		{132,132,4,4,134,134,134,134,134,6,6,6,6,7,7},
		{133,5,5,141,134,134,134,134,134,6,6,6,6,7,7},
		{134,134,134,134,6,6,6,6,6,6,6,15,7,7,7},
		{7,7,7,7,7,7,7,7,7,7,7,7,7,7,7},
		{8,8,8,142,142,14,14,14,14,14,15,15,15,7,7},
		{9,9,9,10,10,143,143,135,135,15,15,15,15,7,7},
		{6,6,6,6,6,6,6,6,7,7,7,7,7,7,7},
		{11,11,11,11,11,138,138,6,6,6,6,6,6,7,7},
		{12,12,12,12,12,12,6,6,6,6,6,6,7,7,7},
		{13,13,13,13,6,6,6,6,6,6,6,6,7,7,7},
		{14,14,14,14,14,15,15,15,15,15,15,7,7,7,7},
		{15,15,15,15,15,15,15,7,7,7,7,7,7,7,7}
		}

		local function fade(i)
			for c=0,15 do
				if flr(i+1)>=16 then
					pal(c,7,1)
				else
					pal(c,fadetable[c+1][flr(i+1)],1)
				end
			end
		end
		
		fade(fadein)
		fadein+=.2

		if fadein<=30 and flr(rnd(8)/1)==1 then
			sfx(35,-1)
		end

		if fadein>=20 then
			pause_player=true
			pal()
			cls(7)
			print([[
aND SO, THE WHOLE TEMPLE
CAVED IN, WITH YOU STILL
 INSIDE. yOU COULD NOT
ESCAPE WITH THE TREASURE.
dO YOU WISH TO TRY YOUR
     LUCK AGAIN?

          🅾️]],16,46,6)
			if btn()>0 then
				run()
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

function draw_time(x,y,force)

	if (not level_data[3].chest_opened) or force then
		local s=seconds
		local m=minutes%60
		local h=flr(minutes/60)
	
		rectfill(x,y,x+44,y+6,0)
		print((h<10 and "0"..h or h)..":"..(m<10 and "0"..m or m)..":"..(s<10 and "0"..s or s).."."..(milliseconds<10 and "0"..milliseconds or milliseconds),x+1,y+1,7)
	else
		local ms=flr((countdown%3)*1000/30)
		local s=flr((countdown%180)/3)
		local m=flr(countdown/180)
		rectfill(x,y,x+32,y+6,0)
		print((m<10 and "0"..m or m)..":"..(s<10 and "0"..s or s).."."..(ms<10 and "0"..ms or ms),x+1,y+1,8)
	end
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

 if hastag(level_num,"-Wrap") then

 for i=flr(x/8),(x+w-1)/8 do
 	for j=max(0,flr(y/8)),min(15,(y+h-1)/8) do
 		if fget(tile_at(i,j),flag) then
 			return true
 		end
 	end
 end

 else

 for i=max(0,flr(x/8)),min(15,(x+w-1)/8) do
 	for j=max(0,flr(y/8)),min(15,(y+h-1)/8) do
 		if fget(tile_at(i,j),flag) then
 			return true
 		end
 	end
 end

 end

	return false
end

function tile_at(x,y)
 return mget(room.x * 16 + x%16, room.y * 16 + y%16)
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
000000000000000000000000088888800000000000000000000000000000000000aaaaa0000aaa000000a00000077077700777000000a0000000a00000eeee00
000000000888888008888880888888880888888008888800000000000888888000a000a0000a0a000000a00007777776777777700000a0000000a0000eeeeee0
000000008888888888888888888ffff888888888888888800888888088f1ff1800ad0da0000a0a000000a0007766666667767777000a00000000a0000e7eeee0
00000000888ffff8888ffff888f1ff18888ffff88ffff8808888888888fffff800daaad0000dad000000a0007677766676666677000a00000000a0000eeeeee0
0000000088f1ff1888f1ff1808fffff088f1ff1881ff1f80888ffff888fffff80000a0000000a0000000a0000000000000000000000a0000000a00000eeeeee0
0000000008fffff008fffff00055550008fffff00fffff8088fffff80855558000dda000000da0000000a0000000000000000000000a0000000a00000eeeeee0
00000000005555000055550007000070075555000055557008f1ff1000555500000da0000000a0000000a00000000000000000000000a000000a000000eeee00
000000000070070000700070000000000000070000007000077555700070070000aaa000000da0000000a00000000000000000000000a000000a000000000000
555555550000000000000000000000000000000000000000008888004999999449999994499909940000000bddd1ddd100000000000000000000000070000000
5555555500000000000000000000000000000000000000000888888091111119911141199114091900aa0a70d7d1d7d100000000007700000770070007000007
550000550000000000000000000000000aaaaaa0000000000878888091111119911191194940041900dddaa0d770d77000000000007770700777000000000000
55000055007000700499994000000000a77dddda11111111088888809111111994940419000000440ada7dd00700070000000000077777700770000000000000
55000055007000700050050000000000a7ddddda10000001088888809111111991140949940000000adaada70700070000000000077777700000700000000000
550000550d770d770005500000000000aaaaaaaa11111111088888809111111991119119914004990dddddaa0000000000000000077777700000077000000000
555555551d7d1d7d0050050000000000a7d00dda1444444100888800911111199114111991404119ada7ddd00000000000000000070777000007077007000070
555555551ddd1ddd0005500004999940a7ddddda1444444100000000499999944999999444004994adaa0aa00000000000000000000000007000000000000000
57777775577777777777777777777775773333333333333333333377577777755555555555555555555555551100000007777770000000000000000000000000
7777777777777777777777777777777777733333333333333333377777777777555555555555555005555555dd70000077777777000777770000000000000000
7773777777773333377777733333777777733333333333333333377777777777555555555555550000555555d777700077777777007766700000000000000000
7733337777733333333773333333377777773333333333333333777777733777555555555555500000055555ddd0000077773377076777000000000000000000
77333377773333333333333333333377777733333333333333337777773333775555555555550000000055551100000077773377077660000777770000000000
7773377777337733333333333337337777733333333333333333377777333377555555555550000000000555dd70000073773337077770000777767007700000
7777777777337733333333333333337777733333333333333333377777373377555555555500000000000055d77770007333bb37000000000000007700777770
5777777577333333333333333333337777333333333333333333337777333377555555555000000000000005ddd000000333bb30000000000000000000077777
773333777733333333333333333333775777777777777777777777757773337755555555500000000000000500000ddd03333330000000000000000000000000
77733377773333333333333333333377777777777777777777777777777337775055555555000000000000550007777d03b333300000000000ee0ee000000000
7773337777337333333333333773337777773337777777777333777777733777555500555550000000000555000007dd033333300000000000eeeee000000030
7733377777333333333333333773337777733333737777333333377777333777555500555555000000005555000000110333b33000000000000e8e00000000b0
773337777773333333377333333337777773333333777737333337777733337755555555555550000005555500000ddd003333000000b00000eeeee000000b30
77733777777733333777777333337777777733377777777773337777773333775505555555555500005555550007777d00044000000b000000ee3ee003000b00
7773377777777777777777777777777777777777777777777777777777733777555555555555555005555555000007dd00044000030b00300000b00000b0b300
77333377577777777777777777777775577777777777777777777775577777755555555555555555555555550000001100999900030330300000b00000303300
57777557775777750777777777777777777777700777777000000000000000003333333300000000000000000000000000000000000000000000000000000000
77777777777777777000077700007770000077777000777700000000000000003773333300555500000000000000000000000000000000000000000000000000
777733777733777770cc777cccc777ccccc7770770c7770700000000000000003773373305575750000000000000000000000000000000000000000000000000
777333333333377770c777cccc777ccccc777c0770777c0700000000000000003333333305556650000000000000000000070000000000000000000000000000
77333333333333777077700007770000077700077777000700056666666650003333333355577755000000000000000000707000000000000000000000000000
57337733333733757777000077700000777000077770000700566666666665003373333355577755000000000000000007000d00000000000000000000000000
57737733333337757000000000000000000c000770000c07006666666666660033333733055777500000000000000000300000d0000000000000000000000000
7773333333333777700000000000000000000007700000070065555565655600333333335566266000000000000000003000000d000000000000000000000000
77733333333337777000000000000000000000077000000700666666666666000000000000000000000000000000000300000003000700000000000000000000
57733333333337777000000c000000000000000770cc00070065565555655600000000000055550000000000000000d0000000003070d0000000000000000000
573373333773337570000000000cc0000000000770cc0007006666666666660000000000057575500000000000000300000000000d000d000000000000000000
773333333773337770c00000000cc00000000c0770000c0700666555655666000000000005665550000000000000030000000000000000000000000000000000
77733333333337777000000000000000000000077000000700666666666666005555555555777555777777007700377000777000770007700777770000000000
777733777733777770000000000000000000000770c0000700677666666776005555555555777555777777707703077000777700777007707777777000000000
777777777777777770000000c0000000000000077000000700777776677777005555555505777550770007707700077000077000777707707700000000000000
57777577775577757000000000000000000000077000c00777777777777777705555555506626655dddddd00dd000dd0000dd000ddddddd0ddddddd000000000
00000000000000007000000000000000000000077000000700777700500000000000000500000000dd000dd0dd000dd0000dd000dd0dddd0000000d000000000
00ffffffffffff00700000000000000000000007700c000707000070550000000000005500000000dd000dd0ddddddd000ddd000dd00ddd0ddddddd000000000
0f666666666666f0700000000000c000000000077000000770770007555000000000055500555000dd000dd00ddddd0000dddd00dd000dd00ddddd0000000000
f66ffffffffff66f7000000cc0000000000000077000cc0770779907555500000000555505757500000000000000000000000000000000000000000000000000
f6ffffffffffff6f7000000cc0000000000c00077000cc0770099907555555555555555505665500000033000000000000000000000000000300000000000000
f66666666666666f70c00000000000000000000770c0000770099907555555555555555555777550000300000000000000000000000000000030000000000000
f66666666666666f7000000000000000000000077000000707000070555555555555555505777500003000000000000000000000000000000003300000000000
f66666666666666f0777777777777777777777700777777000777700555555555555555506626650030000000000000000000000000000000000033300000000
ffffffffffffffff07777777777777777777777007777770004aaa00000000000000000000000000030000000000000000555500000000000000000030000000
f56565f11f56565f70007770000077700000777770007777004aaaaa000000000000000000000030030000000000000005555550000000000000000010000000
f565f5f11f5f565f70c777ccccc777ccccc7770770c7770704200aaa000000000000000000000301010000000000000005500550000000000000000003000000
f56555ffff55565f70777ccccc777ccccc777c0770777c07040a0000000000000000000000003000100000000000000000000550000000000000000000100000
f56666ffff66665f77770000077700000777000777770007040aa000000000000000000000001000000000000000000000055500000000000000000000100000
f56555666655565f77700000777000007770000777700c07420aaaaa000000000000000000010000000000000000000000055000000000000000000000100000
f565f555555f565f700000000000000000000007700000074000aaa0000000000000000000000000000000000000000000000000000000000000000000000000
f56566666666565f0777777777777777777777700777777040000000000000000000000001000000000000000000000000055000000000000000000000001000
13232323232323629c00001323232352000000a2425252525252525252525233232323232323235252629c9c4233824200004252525284525252620000000000
13232323232323232323330000000000525252525284525262828382930042625252525252525223525252629300425222222232b1b1b1b1b142525262930000
00000000000010038c0094000000b3420000000013235252528452525284331200a201828282921323338e9c0383824200001323232323235252330000000000
00b1b1b10000b38200b38293800000005252232323232323338282828293426213845252525233004252846283b3425284525262a38282930042525262838293
0000000000b312629c1232b200f0b3130000000000a242525252525223331252000000a2839200b1b1b100a273821252000000a28382820142629c0000610000
001111119400b38200b31222223293a35262b1b1b1b1b18e9c00a282828342623213235252620000425252338293425252525262828283920042528462828283
0000000000b342629c4262b20000b38d0000000000001323525252331222525200000000a293001111110000a3824233000000000000a28242339c0000000000
222222328e8c9c8293b342525262b1b1526200001000009c9c000082a28242625232021323330010135233a28282425223232333828292009513232333828282
0000000000b313339c1333b20000b39c00000000f00000a242523312525252520000000000a293122222222222533300111111111111008203728d1111111111
232323339c9c9c8282b3132323330000526200007100008f9c110082001142625252223200a3829c9c73000000a24252b1b1b1a282828282243444b1b100a282
0000000000b39c9c9c9c9cb200f0b39c000000000000000013331252528452523434343444122252525252233300000053638d9c9c0200a2422353639c8f9c43
b1b1b1b10000b38282b383920000000084620000000000122232b292b3125262525252330182829c8c0000000000425200000000a201828225354500000000a2
0000000000b38e9c8d9c8cb2d200b312000000000000000000a242525252525236363636461323232323332444000000b1b1b1b1b1b1000003b1b1b1b1b1b1b1
000011000000b38392b382930000000052621111111100425262b2a3b3425262525262a3829200720000111111111352000000000000a28226364694000000a3
0000000000b312329c1232b20000b342000000000000000000001323525252520000f000002444000000002545000000000011111111111103c0001111111111
000072000000b38200b382828293000052628282018282428433b282b3135262525262a28211117300b3435353536342000000000000a3828282123200a38282
0000000000b342629c4262b20000b3420000000000000000f00000a24252525200000000002545000000002545b2000043639c8e9c435322620000029c9c8c43
111103110000b38200b38f9c01828293526292000000004262b1008200b1426284526200828283020000b1b1b1b11252000000a3828282828292426282018282
0000000000b342629c4262b200f0b3420000000000000000000000001323528400000000002646001000002545b20000b1b1b1b1b1b1b142620000b1b1b1b1b1
222252222222329200b39c9c1263b1b15262001111111142620000820000426252526200a2828272a38282018293425294411082828382920000426282828292
0000000000b313338f1333b20000b34200000000000000000000000000a242520000000000002434440000254500000011111111000000426200000000000000
232323232323338200b39c8d73930000846282828283824262b20082930042625252621111a282038392001100a2428412222222328292009500133300000000
000000000000b1b1b1b1b1000000b34200000000000000000000000000001323000000000000253545000025450000002222223200000042522232f300940000
b1b1b1000000b38200b3828282839200526200000000a2426200a3828282426223233382838292730000b372b261132342525252629200009c8e9c9c8f000000
0000000000000000000000000000b342000000000000000000000000100000000000f000000026364600002545000000525252620000c2425252522222222222
000000000000b38200b38382920000a3233311111111001333a3838282821333b1b1b10000000002b200b303b200b1b142525284523200009c9c9c8d9c829300
0000000000000000f00000000000b3420000000000000000000000729c8c0000000000000000a2019200002545000000528452620010c3425252525252525252
111111000010b38300b382934100a382828283828282828d9c82828292610000111111000000b372b200b303b200111113232323525232008c9c9c9c9c828293
0000000000000000000000000000b3420000000000000000000000039c9c0000000000000000a392000000254500000052525262931222525252525284525252
222222222222328200b3728e9c9cb1b1920000000000009c8c82920000000000222232f00000b303b200b303b2001222770000125284522232b2a28282018282
0000000000000000000000000000b3420000000000000000000000039c9c11110000000000a38293000000254500000052525262824252525252525252525252
525252528452629300b3039c9c8c0000000000000000009c9c92000000000000528462000000b303b200b303b2004252778000425252525262b200a282828283
00000000000000a39300000000000000000000000066000000000000000000006661616566626665101111011011110100000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000006663616566626665111717111171711100000000000000000000000000000000
000000000000a392a293000000000000006100006600660000000000000000006662366566626665111166111166111100000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000002223232522222225011777100177711000000000000000000000000000000000
000000000000a293a39200a3000000000000006600660066000000000000f0005313236656662666011777100177711000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000001666216656662666011777100177711000000000000000000000000000000000
00000000930000a29200000100000000000066006600660066000000000000005166216656662666011777100177711000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000005322223252222222011777100177711000000000000000000000000000000000
000000008300000000a3008200000000000000660066006600000000000000001362366500000000011777100177711000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000636236655055550501177710017771100000000000000000c400000000000000
00000000010093000082768200000000000000006600660000f00000100000006132366555757555011777100177711000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000022133225556655550117771001777110000000000000a5b5c5d5e50000000000
00000000827682670082838200000000000000000066000000000000ac0000005661266605777550011777100177711000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000056633166057775500117771001777110000000000000a6b6c6d6e60000000000
000000008282921232a2828200000000008000000000000000000000ad0000005136233605777550011777100177711000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000053222212057775500117771001777110000000000097a700c700e7f700000000
00000076838212525232829393000000000000e3e30096e300000000ad0000006622266505777550000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000006665566505777550008888888888880000000000000000000000000000000000
00000092821252845252328283760000222222222222226300000000ad0000006666266505777550088888888888888000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000005525556605777550888888888888888800000000000000000000000000000000
85857682924252525252620182827600845252522323330000000000ad0000005665525505777550877788888888888800000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000005666266605777550888777888888888800000000000000000000000000000000
82018283001323525284629200a282005223233300bc000000f00000ad0000bc5665666605777550778887788888778800000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000005222222205777550888888788887888800000000000000000000000000000000
00a282930000a34252233393000082003300000000bd000000000000ad0000bd66626665057775508888887788788888000dd000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000066655665057775508888888787788888000da000000000000000000000000000
0000a28293a38313330000a2839382860000000000bd000000ac0000ad0000bd66625665057775508888888777888888000da000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000026525255057775508887778877888888000da000000000000000000000000000
100000a282829200000000000201838200ac000000bd000000ad0000ad0000bd55255666057775508887878878888888000da000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000056626666057775508887778888888888000da000000000000000000000000000
12223200a2839300000000021222223200ad000000bd000000ad0000ad0000bd56665666057775500888888888888880000da000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000052222222066266550088888888888800000da000000000000000000000000000
__label__
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg6ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggg6ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg6ggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggggggggggggggggggggggggggg6gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggglglglglglglggggggllgllgglllggggglglggllglglggggggllglllglllggllglggglllgllgggllggggglllgllgggllglllggggggggggggggg
gggggggggggggglglglglglllggggglglglglgllgggggglllglglglglggggglgggglggllgglglglgggglgglglglgggggggllgglglglglglllggggggggggggggg
gggggggggggggglllglllggglggggglllgllgglggggggggglglglglglggggggglgglgglggglllglgggglgglglglglggggglgggllgglglglglggggggggggggggg
gggggggggggggglllglglgllgggggglglglglggllgggggllggllgggllgggggllggglgggllglglggllglllglglglllggggglggglglgllgglglggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg6ggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg7gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg7g7ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg7gggdgggggggggggggggggggggggggggggggg6ggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggjgggggdggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggjggggggdgggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggjgggggggjggg7gggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggdgggggggggjg7gdggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggjgggggggggggdgggdgggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggjgggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggg777777gg77ggj77ggg777ggg77ggg77gg77777gggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggg6ggggggggggggggggggg7777777g77gjg77ggg7777gg777gg77g7777677ggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggg77ggg77g77ggg77gggg77ggg7777g77g77gggggggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggggggggggggggggggddddddggddgggddggggddgggdddddddgdddddddggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggg6ggggggggggggggddgggddgddgggddggggddgggddgddddgggggggdggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggggggggggggggggggddgggddgdddddddgggdddgggddggdddgdddddddggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggggggggggggggggggddgggddggdddddggggddddggddgggddggdddddgggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggggggggggggggggggggggjjgggggggggggggggggggggggggggjgggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggjggggggggggggggggggggggggggggggjggggggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggggggggggggggggggggjggggggggggggggggggggggggggggggggjjggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggjgggggggggggggggggggggggggggggggggggjjjgggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggjggggggggggggggggllllggggggggggggggggggjggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggggggggggggggggjggjgggggggggggggggllllllggggggggggggggggghggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggjghghgggggggggggggggllggllggggggggggggggggggjgggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggggggggggggggjggghggggggggggggggggggggllggggggggggggggggggghggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggghgggggggggggggggggggggglllgggggggggggggggggggghggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggggggggggggghgggggggggggggggggggggggllggggggggggggggggggggghggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggggggggggghgggggggggggggggggggggggggllggggggggggggggggggggggghggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg6ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg666gggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg6ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggggggggggggggggggg6gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggggggggggggggggglllllgggglgglllllgggggggllggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggggggggggggggggllglgllgglggllgggllggggglggglllggllgllgglllggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggglllglllgglggllglgllggggglllgglgglglglglgglgggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggggggggggggggggllglgllgglggllgggllggggggglgglgglllgllggglgggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggggggggggggggggggggggggglllllgglgggglllllggggggllggglgglglglglgglgggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggllglllglggglllggllglllglllggggggggggggggggggggglllggggggggggggggggglllggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggglggglggglggglggglgggglgglgggggggllgglglgglgggggglllggllglllglllgggggglgglglggllgllgggllggllgllgggggggggggggggggg
ggg6gggggggggggglgggllgglgggllgglllgglggllggggggllgglllggggggggglglglglgglggglggggggglgglglglglglglglggglglglglggggggggggggggggg
gggggggggggggggglggglggglggglggggglgglgglggggggglglggglgglgggggglglglllgglggglggggggglgglllglglgllgggglglglglglgglgggggggggggggg
gggggggggggggggggllglllglllglllgllggglgglllggggglllgllgggggggggglglglglgglggglggggggglgglglgllgglglgllggllgglglglggggggggggggggg
ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg6gggggggg
gggggggggggggggggggggg6gggggggggggggggggggggllgggggggggggggggggglllggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
ggggggggggggggggggggg666gggggggggggggggggggglglggllglllglggggggglglglllgllggllgglglggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggg6ggggggggggggggggggggglglglglgllgglgggggggllggllgglglglglglllggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggglglglglglggglggggggglglglgggllggllgggglggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggglglgllgggllggllggggglllggllglglglglgllgggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggglllggggggggggggggggggggggggggggglllgggggggggggggggggggggllgggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggglllggllgllggggggllgglglgglgggggglglggllglllgllgglllggllglglggllgllgglllggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggglglglglglglgggggllgglllggggggggglllglgggllgglglgglgglggglglglglglglgglgggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggglglgl6lglglggggglglggglgglgggggglglglggglggglglgglgglggglglglllgllggglggggggggg6gggggggggggggggg
gggggggggggggggggggggggggggggggglglgllggllgggggglllgllgggggggggglglggllggllgllgglllggllglllglglglglgglgggggggg666ggggggggggggggg
ggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg6gggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg
gggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggggg

__gff__
0000000000000000000000000000000004020000000000000000000203000000030303030303030304040402020000000303030303030303040404020202020200001313131302020308020002000000000013131313020204080202020202000000131313130804040002020202020004041313131300000002020202020002
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000303030300000000000000000000000003030303000000000000000000000000030302020000000000000000000000000303020202000000
__map__
0000003125254825252525332b382824002a1028392125262b00003bc9c80000c9c9c9c9c924254825252526c9c9000025482639003b2425262b003828242525323225253331333125262b00003b313325252525252526280000000000000000000000000000000000000000000000002b3b30e8c9c9c9c9c930d830c9c9f8c9
0000001b312525252525261b002a2824002c2821222525262b003b27c9c9003ac9e8c9c9c924252525323233d9002d002525262a393b2448262b3a293b242525013b24262b2a293b24262b0000001b1b25252525254826286758000000000000390000212223212321222311111111112b3b30c9c8c9c9e8c924353328100000
00000000003125254825260000002a24003c2125252525262b1a3b2423c93a38c9c9e8c9c924253233380000e90000004825262b2a3924252628281a3b244825173b24262b3a393b24262000003d0000252548252532332810290000110000003828392425263133244826c9c9c9c8c92b3b24231b1b1b1b1b302b2a2828390b
000000003a283132252526395858683100212525252525262b003b3125232829c9c9c9c9c93133003a286758f9c9c8c92525262b3a292425262b2a393b242525003b24262b28103b31323535353536002548252526c9f8c9c8e8c9c9c92b000028382824252620212525262b000000002b3b24262b0000003b302b00002a2839
0000000010281b1b3132332a2838282122252525482525332b00003b24332900c9f8c9c9c91b1b682810282820c9c9f82525263a293b2425262b001028242525003b24262b3828001b1b1b1b1b1b1b002525252526c9c9c9d8c8e8f8c92b00002a282824254822252525262b49000059003b24332b0016003b302b000000002a
0000000028280000002123392a2828242548252525252642442b003b37000000c9c9c9e8f8003a2828282828282122223232332a393b3125332b3a293b313232003b24262b2a290000000000000000002525254826283828291b1b1b1b00000000002a2425252525482526c9e8c9c9c9003b301b000011003b302b00003d013a
000000002a28000000242610392a38242525252525252662642b00001b00000000283828003a38282900002a28312525c9f8c92b2a28c930c83828003bc9e8c9003b31332b00000017170000000011113232323233282828000000000000000000000031252532323225332b002828385868302b003b272b3b372b0000212222
00000000002839003a24262828392a24252525482532331b1b00000000000000002a282828282829606100002a282448c9c9c92b3a28d830c92b2a393bf8c9c900001b1b0000000011110000003b21231b1b1b1b1b1028283911111111111100003a28382433292920302b00002a28280016372b003b302b001b000000244825
3d0100000028283a28242611002a392448252525331b1b00000000000000000000002a281028290070710000002a24252222233a293b2125232b002828212222000000000000003b21232b00003b2426000000003f2a28382821222223c9c8c9282928283028290000302b000000382800001b00003b302b0000000000242533
2223003f3a283828293133202b002a24252525261b0000110000000000003ff849000028282900c8e8e8c8000059242525252628393b2425262b3a293b242548000017170000003b24262b00003b242600000000343535352225253233c9f8f8282828293029000000302b0000002a2800000000003b302b0000000000243320
2525222338290000001b21232b000024252525262b0011200000000000002122c900002a282867c8c9d8f800002125252525332838282425263829003b242525000011110000003b24262b00003b24260000000000001b1b2432332828c9c9e83829003b302b002d3b302b000000002a000000000011302b0000000000372122
48252525232b0000000031332b003b24253232332b3b21231100000000212525c90000002a3828c9c9c9c9002125252525262029002a3132332900003b313225003b34362b00003b31332b00003b31330000000000000000302b2a3828c9d8c92900003b302b00003b302b0000000000000000003b20302b0000000000212525
25252525262b00000000201b00003b2433000000003b24252311000000242525d8004900012a28c9c9c9c9003132323248262900000000000000000000002a24003bc9e82b00003bc9c92b002d3bd8c90000003900000000372b0028291b1b1b0000003b372b00003b372b000000010000001a003b21262b0000000000313232
25252525332b00eaeb001b0000003b242b000001003b24252523003e21254825c8c9c9c9c9c9c9c9c9c9c9c9e8c9f8c925260000000000000000000000000024003bc9c92b00003bf8c92b00003bc9c900003a282900000028000028013e00000b000000000000000000000000212222000000003b24262b00000000002a2900
254825262b0000fafb00000000003b2439003f2122222525482522222525252523c8c9c9c9c9c9c9f827c9c9c920c9c925260000120001005900000000000024003b21232b00003b27202b00003b2123000028386700003a38003b212223400000000000000000000000000000242525000000001124262b000000000000593a
252525332b0000fcfc00000000003b243839202425252525252525252525252526c9e8c92123c9c92030c9c9c9c934352526000027c9c9c92700000000000024003b24262b00003b24232b00003b2426000028102828282828673b2425262123000000000000000000000000002425480000003b2024262b00000000003bc9c9
4825323226c9c90000c8c931323232252533c9e831323324252526000000003100000000000000000000000000000000000000000000000000000000000000000000000000000000313225252223000032323233c9f8c9313232323233390000313248252526244825262924252525252031323232332b3b2432332828383924
3233280037c9c90000f8c92029002a24333900003a282831254826110000001b000000000000273900003a2700000000000000000000000000000000000000002223003f00000000000031322525222328281039001b1b1b1b1b1b002a283900000031323233242525260024254825253a28291b1b1b003b304244002a282824
002a10393ac9e80000c9c929000000242a3800682828281024252536c9c867580000000000003010393a383000000000000000000000000000000000000000002525222300000000003a3828313225252a28282839000000000000003a28283800000000000031323233393132323232282839000000003b3052542b002a2824
00002a28293b272b002123390014012400283a28382828283125261b1b1b0000000000000000302a282829303d0000000000000000000000000000000000000031322525222300003a2828282900313200002a38291111111111113a28382828000000000000c9c93ac8102900002d00283828000000003b3052542b00000024
00005938393b302b3b24262868212225002a2828282900003b24262b000011110000000000003000282839242300000000000000000000000000000000000000000031322526002728282829000000000000003435353536e8c9c82034352222000000000000f8c9e8283828395900002a2828390000003b3052540000003b31
2b002123293b302b3b2426283824252500013828290000003b24265858682122000000003f2126002829282426000000000000000000000000000000000000000000000031334024222329000000000000003a28291b1b1b1b1b1b00003a313200000000000021222223282921222222002a28280000003b3052540000003b42
2b0024262b3b372b3b24262829244825c9c9c9c93f0000003b2426002a103132000000002148263a2828292426002c00390c000000000000000000000000000000000000003a343225252223003d0000003a102800000000000000000028280000000000000024252525230031252548000028281039003b3062642b00000052
2b3a31332b001b003b2426283b242525c9e8c9c9272b00003b24262b002a27003d004000242526282829003125233c0038390000000000000000000000000000003f00003a28282831322525222300003a282828391111111111113a282829000000000000003125252526e8c924253300002a282828003b2422362b00000062
2b2821232b000c003b24262a3924252522222222262b00003b24262b000030592223003e313233382800003b24482300282839000000000000000000000000002223003a28382829000031322525222328293e2a3821222222222222222300000000000000001b2425322523c93133210000002a2828003b2426450000003b21
3a3824262b0008003b2426392a2425253225254825232b003b242600000030c925252222222223282839003b312526002a2828283900000000000046470000002525222328282900000000003132252522222222233132323232323232330000000000000000003133273133d821222500490100282828282426650000003b24
282831336758585868313328392425481b31252525262b003b3126110000242225482525252533002a2839000031252300002a2828393e00003f00565769000025252525222300000000000000003132323232323235360028382800000000000000000000000021222522230024252535222223382810282425230000003b31
2829201b1b1b1b1b1b1b2a3828242525001b313232332b00003b2423160024252525323232332b003a282838393b2425013f003821222222222235353536000025482525252522230000000000000000000000000000003a28282800000000000000000000001124482525263a24252500313233282829002425262b00000000
10000000000000000000002a2824252500001b212222232b003b3133003b2425252601c9c82b000028282828281024252222222225253232323329000000000032323232324825252223003d0000000000000000003a28282828283900593f000000000000002125252525262824254800003bc92b0000003125262b00000000
29003d0011111111110000002a312525000000312548262b00001b1b003b2425253317e82b00003a2828283a2828312525252525323329000000000000000000c9c9e8c9c92425252525222300000000003d01003a282828292a28283435352200000000000024252525252638242525001600c92b0000001b31332b00000000
22222222222222222222222222233125004900002425262b00001111003b2425262b000000003a3828002a2828293b242532323329000000000000000000000022222223c92425252525252522230001222222233828290000000010c9c8f824000001003f0024252525252628242525000000c82b000000001b1b0000000000
25252548252525252525252548252331c9c9c9f82425262b003b21232b3b2425332b00003a2828282900002a10003b313329000000000000000000000000000025254826d8242548252525252525222325482526282900000000002ac9d8c92422222222222324252548252628242525000000d82b0000000000000000000000
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
000200003067530675306752f6752e6752e6752d6752d6552c6552a65529655276552565524645216451f6451d6451a64515635136350a63504635006051e6051f6051f6051f60520605206051d6050000500005
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
0010000003625246150060503615246251b61522625036150060503615116213361122625006051d6250a61537625186152e6251d615006053761537625186152e6251d61511625036150060503615246251d615
00100020326103261032610326103161031610306102e6102a610256101b610136100f6100d6100c6100c6100c6100c6100c6100f610146101d610246102a6102e61030610316103361033610346103461034610
00400000302453020530235332252b23530205302253020530205302253020530205302153020530205302152b2452b2052b23527225292352b2052b2252b2052b2052b2252b2052b2052b2152b2052b2052b215
012b01000771507772077710777107751077310771502572025710257102551025310251505072050710507105051050310501105011050150f5000f5000f5000f5000f5000f5000f5000f500000000000000000
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

