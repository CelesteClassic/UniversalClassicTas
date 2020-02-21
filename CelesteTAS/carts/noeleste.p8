pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
--~noeleste~
--celeste classic mod by taco360
--original by matt thorson + noel berry

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
screenshake=false
bg=0
atmosphere=true
playerx=0
playery=0

k_left=0
k_right=1
k_up=2
k_down=3
k_jump=4
k_dash=5
k_screenshake=2

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
	
	--oof
	--[[
	max_djump=1
	target_level=10
	for i=1,target_level-1 do
		next_room()
	end
	--]]
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
for i=0,200 do
	add(particles,{
		x=rnd(128),
		y=rnd(128),
		s=0+flr(rnd(5)/4),
		spd=0.2+rnd(1.5),
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
		local on_cursed=this.is_cursed(0,1)
		local on_superice=this.is_superice(0,1)
		local on_stickyice=this.is_stickyice(0,1)
		local on_speedyice=this.is_speedyice(0,1)
		
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
			if this.djump<max_djump and not on_cursed then
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
			elseif on_superice then
				deccel=0
				accel=0.00
				if input==(this.flip.x and -1 or 1) or this.spd.x==0 then
					accel=0.02
				end
			elseif on_stickyice then
				accel=0.00
				this.spd.x=0.00
				if input==(this.flip.x and -1 or 1) then
					accel=0.00
				end
			elseif on_speedyice then
				accel=0.1
				maxrun=5
				if input==(this.flip.x and -1 or 1) then
					accel=0.25
				end
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
			
			if atmosphere==false then
				gravity=0.105
			 maxfall=2
			 if abs(this.spd.y) <= 0.30 then
   		gravity*=0.5
				end
			else
				if abs(this.spd.y) <= 0.15 then
   		gravity*=0.5
				end
			end
		
			--sticky ice wall slide
			if input!=0 and this.is_solid(input,0) and this.is_stickyice(input,0) then
				maxfall=0
				this.spd.y=0
			--speedy ice wall slide
			elseif input!=0 and this.is_solid(input,0) and this.is_speedyice(input,0) then
			maxfall=8
			-- wall slide
			elseif input!=0 and this.is_solid(input,0) and not this.is_ice(input,0) and not this.is_superice(input,0) then
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
			 		if not this.is_ice(wall_dir*3,0) and not this.is_superice(wall_dir*3,0) then
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
		if this.y<-4 then
			if level_index()==15 then
				load_room(3,3)
			elseif level_index()<15 then
				next_room()
			end
		end
		
		-- was on the ground
		this.was_on_ground=on_ground
		
		--player coordinates code
		playerx=this.x
		playery=this.y
		
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
		
		--draw santa hat
		--spr(79,this.x,this.y-8)
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
  for i=1,5 do
   obj.hair[i].x+=(last.x-obj.hair[i].x)/1.5
   obj.hair[i].y+=(last.y+0.5-obj.hair[i].y)/1.5
   circfill(obj.hair[i].x,obj.hair[i].y,obj.hair[i].size,(i == 5) and 7 or 8)
   last=obj.hair[i]
  end
  circfill(obj.x+4-facing*(facing==1 and 3 or 2),obj.y+(obj.spr==3 and 2 or (obj.spr==6 and 4 or 3)), 2.5, 7)
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
		
		--entry santa hat
		--spr(79,this.x,this.y-8)
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
				if hit.djump<=max_djump then
					hit.djump=max_djump
				end
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
			if hit~=nil and (hit.djump<max_djump or (max_djump==0 and hit.djump==0)) then
				psfx(6)
				init_object(smoke,this.x,this.y)
				if max_djump==0 then
					hit.djump=1
				else
					hit.djump=max_djump
				end
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
		spr(80,this.x+8,this.y,1,1,true,true)
		spr(80,this.x,this.y+8)
		spr(64,this.x+8,this.y+8,1,1,true,true)
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
		--this.x-=4
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
				init_object(fruit,this.x,this.y-8)
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
		this.text=" -- noeleste mountain --#when the penguins gather# they shall return home "
		if this.check(player,4,0) then
			if this.index<#this.text then
			 this.index+=0.5
				if this.index>=this.last+1 then
				 this.last+=1
				 sfx(35)
				end
			end
			this.off={x=4,y=15}
			for i=1,this.index do
				if sub(this.text,i,i)~="#" then
					rectfill(this.off.x-2,this.off.y-2,this.off.x+7,this.off.y+6 ,13)
					print(sub(this.text,i,i),this.off.x,this.off.y,6)
					this.off.x+=5
				else
					this.off.x=4
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

smallmessage={
	tile=65,
	last=0,
	draw=function(this)
		if level_index()<5 then
			this.text="    @ogs :swageline:   "
		elseif level_index()<10 then
			this.text="no secret clubs here!.."
		else
			this.text="interference - dash off"
		end
		if this.check(player,4,0) then
			if this.index<#this.text then
			 this.index+=0.5
				if this.index>=this.last+1 then
				 this.last+=1
				 sfx(35)
				end
			end
			this.off={x=6,y=115}
			for i=1,this.index do
				if sub(this.text,i,i)~="#" then
					rectfill(this.off.x-2,this.off.y-2,this.off.x+7,this.off.y+6,13)
						print(sub(this.text,i,i),this.off.x,this.off.y,6)
					this.off.x+=5
				else
					this.off.x=6
					this.off.y+=7
				end
			end
		else
			this.index=0
			this.last=0
		end
	end
}
add(types,smallmessage)

big_chest={
	tile=96,
	init=function(this)
		this.state=0
		this.hitbox.w=16
		this.vel=0
		this.particles={}
		this.delp=false
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
			if this.timer<0 then
				this.state=2
				spr(188,this.x,this.y)
				spr(189,this.x+8,this.y)
			elseif this.timer<20 then
				spr(188,this.x,this.y)
				spr(189,this.x+8,this.y)
			elseif this.timer<27 then
				spr(188,this.x,this.y)
				spr(187,this.x+8,this.y)
			elseif this.timer<35 then
				spr(186,this.x,this.y)
				spr(187,this.x+8,this.y)
				if this.delp==false then
					-- delete player
					foreach(objects, function(o)
						if o.type==player then
							destroy_object(o)
							pause_player=false
						end
					end)
					this.delp=true
				end
			end
		else
			if this.y<-128 then
				next_room()
			end
			this.vel+=0.075
			this.y-=this.vel
			spr(188,this.x,this.y)
			spr(189,this.x+8,this.y)
			if count(this.particles)<50 then
				add(this.particles,{
					x=1+rnd(14),
					y=0,
					h=32+rnd(32),
					spd=8+rnd(8)
				})
			end
		end
		foreach(this.particles,function(p)
				p.y-=p.spd
				line(this.x+p.x,this.y+8-p.y,this.x+p.x,max(this.y+8-p.y+p.h,this.y+8),7)
			end)
		spr(112,this.x,this.y+8)
		spr(112,this.x+8,this.y+8,1,1,true)
		spr(143,this.x,this.y+16)
		spr(143,this.x+8,this.y+16,1,1,true)
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

longdelie = {
	tile=113,
	--this code is a mess, i know, but it works
	draw=function(this)
		if playery>=this.y or playery<=0 then
			spr(78,this.x,this.y)
		elseif playery>=this.y-12 then
			spr(113,this.x,this.y)
			spr(81,this.x,this.y-8)
		else
			spr(113,this.x,this.y)
			for i=this.y-8,playery+4,-1 do
				spr(97,this.x,i)
				if i==playery+4 then
					spr(81,this.x,i-4)
				end
			end
		end
	end
}
add(types,longdelie)

adelie = {
	tile=126,
	init=function(this)
		collided=false
		this.timer=15
		this.start=this.y
	end,
	update=function(this)
		if collided==false then
			local hit = this.collide(player,0,0)
			if hit~=nil then
				init_object(fruit,this.x,this.y-12)
				collided=true
				psfx(63)
			end
		elseif this.timer>=1 then
			this.timer-=1
			this.y=this.start-flr(rnd(2))
		else
			this.y=this.start
		end
	end,
	draw=function(this)
		if playerx<this.x then
			spr(this.spr,this.x,this.y,1,1,true,false)
		else
			spr(this.spr,this.x,this.y,1,1,false,false)
		end
	end
}
add(types,adelie)

peng1 = {
	tile=203,
	init=function(this) 
		this.offset=rnd(1)
		this.start=this.y
		this.timer=0
	end,
	update=function(this) 
		this.offset+=0.01
		this.y=this.start+sin(this.offset)*2
	end,
	draw=function(this)
		spr(this.spr,this.x,this.y)
	end
}
add(types,peng1)

peng2 = {
	tile=219,
	init=function(this) 
		this.offset=rnd(1)
		this.start=this.y
		this.timer=0
	end,
	update=function(this) 
		this.offset+=0.01
		this.y=this.start+sin(this.offset)*2
	end,
	draw=function(this)
		spr(this.spr,this.x,this.y)
	end
}
add(types,peng2)

peng3 = {
	tile=235,
	init=function(this) 
		this.offset=rnd(1)
		this.start=this.y
		this.timer=0
	end,
	update=function(this) 
		this.offset+=0.01
		this.y=this.start+sin(this.offset)*2
	end,
	draw=function(this)
		spr(this.spr,this.x,this.y)
	end
}
add(types,peng3)

peng4 = {
	tile=251,
	init=function(this) 
		this.offset=rnd(1)
		this.start=this.y
		this.timer=0
	end,
	update=function(this) 
		this.offset+=0.01
		this.y=this.start+sin(this.offset)*2
	end,
	draw=function(this)
		spr(this.spr,this.x,this.y)
	end
}
add(types,peng4)

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
			if room.x==0 and room.y==0 then
				print("the penguin path",33,62,7)
			elseif room.x==5 and room.y==0 then
				print("frozen wastes",40,62,7)
			elseif room.x==2 and room.y==1 then
				print("summit",52,62,7)
			elseif room.x==3 and room.y==1 then
				print("snowspace",44,62,7)
			elseif room.x==7 and room.y==1 then
				print("planet adelie",40,62,7)
			elseif room.x==3 and room.y==3 then
				print("temple of longdelie",27,62,7)
				music(30,5000,7)
			elseif room.x==4 and room.y==1 then
				print("9700m",52,62,7)
			elseif room.x==5 and room.y==1 then
				print("9800m",52,62,7)
			elseif room.x==6 and room.y==1 then
				print("9900m",52,62,7)
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
	end
	
	obj.is_cursed=function(ox,oy)
		return cursed_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h)
	end
	
	obj.is_ice=function(ox,oy)
		return ice_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h)
	end
	
	obj.is_superice=function(ox,oy)
		return superice_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h)
	end
	
	obj.is_stickyice=function(ox,oy)
		return stickyice_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h)
	end
	
	obj.is_speedyice=function(ox,oy)
		return speedyice_at(obj.x+obj.hitbox.x+ox,obj.y+obj.hitbox.y+oy,obj.hitbox.w,obj.hitbox.h)
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
 if room.x==4 and room.y==0 then
  music(30,500,7)
  bg=1
 elseif room.x==5 and room.y==0 then
  music(20,500,7)
 elseif room.x==1 and room.y==1 then
  music(-1,500,7)
  particles={}
 elseif room.x==2 and room.y==1 then
  max_djump=0
  music(10,500,7)
  atmosphere=false
  for i=0,200 do
			add(particles,{
				x=rnd(128),
				y=rnd(128),
				s=0+flr(rnd(5)/4),
				spd=0.1+rnd(0.4),
				off=rnd(1),
				c=6+flr(0.5+rnd(1))
			})
		end
	elseif room.x==6 and room.y==1 then
		music(50,500,7)
		atmosphere=true
		max_djump=1
		bg=2
	end
 
 --custom particles
 if level_index()==4 or level_index==8 then
		foreach(particles, function(p)
			p.s+=0.25
			p.spd+=1 
		end)
	elseif room.x==6 and room.y==1 then
		foreach(particles, function(p)
			p.spd=0
		end)
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
	if ((room.x>=7 and room.y>=1) or room.y>1) then 
		atmosphere=true 
	elseif ((room.x>=3 and room.y>=1) or room.y>1) then 
		atmosphere=false 
	else 
		atmosphere=true 
	end
end

-- update function --
-----------------------

function _update()
	frames=((frames+1)%30)
	if frames==0 and level_index()<15 then
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
	if btnp(k_screenshake,1) then
		screenshake=not screenshake
	end
	if shake>0 then
		shake-=1
		if screenshake then
 		camera()
 		if shake>0 then
 			camera(-2+rnd(5),-2+rnd(5))
 		end
		end
	end
	
	-- screenshake
	if btnp(k_screenshake,1) then
		screenshake=not screenshake
	end
	if shake>0 then
		shake-=1
		if screenshake then
 		camera()
 		if shake>0 then
 			camera(-2+rnd(5),-2+rnd(5))
 		end
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
			pal(2,c)
			pal(6,c)
			pal(7,c)
			pal(8,c)
			pal(9,c)
			pal(10,c)
			pal(11,c)
			pal(12,c)
			pal(13,c)
			if c<2 then
			pal(1,c)
			end
		end
	end

	-- clear screen
	local bg_col = 1
	if flash_bg then
		bg_col = frames/5
	elseif bg==1 then
		bg_col=0
	elseif bg==2 then
		bg_col=6
	end
	rectfill(0,0,128,128,bg_col)

	-- clouds
	if not is_title() and atmosphere then
		foreach(clouds, function(c)
			c.x += c.spd
			rectfill(c.x,c.y,c.x+c.w,c.y+4+(1-c.w/64)*12,bg==1 and 1 or bg==2 and 7 or 3)
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
		if o.type==platform or o.type==big_chest or o.type==player_spawn or o.type==adelie then
			draw_object(o)
		end
	end)
	
	if level_index()<15 then
		pal(15,6)
	else
	 pal(15,12)
	end
	
	-- draw terrain
	--local off=is_title() and 3 or 0
	map(room.x*16,room.y * 16,off,0,16,16,2)
	
	-- draw objects
	foreach(objects, function(o)
		if o.type~=platform and o.type~=big_chest and o.type~=player and o.type~=player_spawn and o.type~=adelie then
			draw_object(o)
		end
	end)
	
	if level_index()~=31 then
		pal()
	end
	
	-- draw player
	foreach(objects, function(o)
		if o.type==player then
			draw_object(o)
		end
	end)
	
	-- draw fg terrain
	-- (removed - replaced with cursed ground)
	--map(room.x * 16,room.y * 16,0,0,16,16,8)
	
	-- particles
	if atmosphere then
		foreach(particles, function(p)
			p.x += sin(p.off)
			p.y += p.spd
			p.off+= min(0.05,p.spd/32)
			rectfill(p.x,p.y,p.x+p.s,p.y+p.s,p.c)
			if p.y>128+4 then 
				p.y=-4
				p.x=rnd(128)
			end
		end)
	else
		foreach(particles, function(p)
			p.x += sin(p.off)
			p.y -= p.spd
			p.off+= min(0.05,p.spd/32)
			rectfill(p.x,p.y,p.x+p.s,p.y+p.s,p.c)
			if p.y<0-4 then 
				p.y=128+4
				p.x=rnd(128)
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
		print("z/x or x/c",44,50,13)
		print("matt thorson",40,66,12)
		print("noel berry",44,72,12)
		print("taco360",50,88,10)
		print("meep",56,94,10)
		
		print("holiday mod for classic discord",2,116,11)
		print("tech demo for a future project",4,122,8)
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

	--secret palette
	if level_index()~=15 and level_index()~=27 then
		pal(1,129,1)
		pal(3,131,1)
		pal(11,139,1)
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

function cursed_at(x,y,w,h)
 return tile_flag_at(x,y,w,h,3)
end


function ice_at(x,y,w,h)
 return tile_flag_at(x,y,w,h,4)
end

function superice_at(x,y,w,h)
 return tile_flag_at(x,y,w,h,5)
end

function stickyice_at(x,y,w,h)
 return tile_flag_at(x,y,w,h,6)
end

function speedyice_at(x,y,w,h)
 return tile_flag_at(x,y,w,h,7)
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
000000000000000000000000088888800000000000000000000000000000000000aaaaa0000aaa000000a0000007707770077700000060000000600000060000
000000000888888008888880888888880888888008888800000000000888888000a000a0000a0a000000a0000777777677777770000060000000600000060000
000000008888888888888888881111188888888888888880088888808811111800a909a0000a0a000000a0007766666667767777000600000000600000060000
00000000881111188811111888f11f1888111118811111808888888888f11f18009aaa900009a9000000a0007677766676666677000600000000600000060000
0000000088f11f1888f11f1808fffff088f11f1881f11f80888ffff888fffff80000a0000000a0000000a0000000000000000000000600000006000000006000
0000000008fffff008fffff00022220008fffff00fffff8088111118082222800099a0000009a0000000a0000000000000000000000600000006000000006000
00000000002222000022220007000070072222000022227008f11f10002222000009a0000000a0000000a0000000000000000000000060000006000000006000
000000000070070000700070000000000000070000007000077222700070070000aaa0000009a0000000a0000000000000000000000060000006000000006000
555555550000000000000000000000000000000000000000008888004999999449999994499909940300b0b0666566650300b0b0000000000000000070000000
55555555000000000000000000000000000000000000000008888880911111199111411991140919003b330067656765003b3300007700000770070007000007
550000550000000000000000000000000aaaaaa00000000008788880911111199111911949400419028888206770677002888820007770700777000000000000
55000055007000700499994000000000a998888a1111111108888880911111199494041900000044089888800700070078988887077777700770000000000000
55000055007000700050050000000000a988888a1000000108888880911111199114094994000000088889800700070078888987077777700000700000000000
55000055067706770005500000000000aaaaaaaa1111111108888880911111199111911991400499088988800000000008898880077777700000077000000000
55555555567656760050050000000000a980088a1444444100888800911111199114111991404119028888200000000002888820070777000007077007000070
55555555566656660005500004999940a988888a1444444100000000499999944999999444004994002882000000000000288200000000007000000000000000
5777777557777777777777777777777577ffffffffffffffffffff77577777755555555555555555555555555500000000077000000000000000000000000000
77777777777777777777777777777777777ffffffffffffffffff777777777775555555555555550055555556670000000577b00000777770000000000000000
777f77777777fffff777777fffff7777777ffffffffffffffffff777777777775555555555555500005555556777700000785700007766700000000000000000
77ffff77777ffffffff77ffffffff7777777ffffffffffffffff7777777ff7775555555555555000000555556660000007737770076777000000000000000000
77ffff7777ffffffffffffffffffff777777ffffffffffffffff777777ffff775555555555550000000055555500000008737850077660000777770000000000
777ff77777ff77fffffffffffff7ff77777ffffffffffffffffff77777ffff7755555555555000000000055566700000075b5770077770000777767007700000
7777777777ff77ffffffffffffffff77777ffffffffffffffffff77777f7ff775555555555000000000000556777700007733770000000000000007700777770
5777777577ffffffffffffffffffff7777ffffffffffffffffffff7777ffff77555555555000000000000005666000000b333375000000000000000000077777
77ffff7777ffffffffffffffffffff77577777777777777777777775777fff775555555550000000000000050000066673585b57000000000000000000000000
777fff7777ffffffffffffffffffff77777777777777777777777777777ff77750555555550000000000005500077776733333370000000000ee0ee000000000
777fff7777ff7ffffffffffff77fff777777fff7777777777fff7777777ff77755550055555000000000055500000766833335850000000000eeeee000000030
77fff77777fffffffffffffff77fff77777fffff7f7777fffffff77777fff7775555005555550000000055550000005535b5533300000000000e8e00000000b0
77fff777777ffffffff77ffffffff777777fffffff7777f7fffff77777ffff7755555555555550000005555500000666033333300000b00000eeeee000000b30
777ff7777777fffff777777fffff77777777fff7777777777fff777777ffff775505555555555500005555550007777600044000000b000000ee3ee003000b00
777ff777777777777777777777777777777777777777777777777777777ff7775555555555555550055555550000076600044000030b00300000b00000b0b300
77ffff77577777777777777777777775577777777777777777777775577777755555555555555555555555550000005500999900030330300000b00000303300
5777755700b00000077777777777777777777770077777700000000000000000ffffffff06666666666666666666666006666660000000000000000000000000
777777770050000070000777000077700000777770007777000b000000000000f77fffff600006660000666000006666600066660d0000000011110000111100
7777ff770050000070cc777cccc777ccccc7770770c777070005000000000000f77ff7ff60dd666dddd666ddddd6660660d66606000000000171711001171710
777fffff5555555570c777cccc777ccccc777c0770777c070005000000000000ffffffff60d666dddd666ddddd666d0660666d06000000d00199111001119910
77ffffff5dddddd5707770000777000007770007777700070005000055555000ffffffff60666000066600000666000666660006000000001177711111177711
57ff77ff5dcd77d57777000077700000777000077770000700cccccccccccc00ff7fffff6666000066600000666000066660000600dd00001177711111177711
577f77ff5dddddd57000000000000000000c000770000c0700c5555555555c00fffff7ff6000000000000000000d000660000d0600dd00000177711001177710
777fffff555555557000000000000000000000077000000700c5dddddddd5c50ffffffff60000000000000000000000660000006000000000996991111996990
777fffff000000007000000000000000000000077000000700c5d9d7777d5c500000000060000000000000000000000760000006000000000000000000000000
577fffff101111017000000c000000000000000770cc000700c5dddddddd5c50000000006000000d000000000000000760dd00060c0000001011110110111101
57ff7fff1171711170000000000cc0000000000770cc000700c5d8d7777d5c000000000060000000000dd0000000000760dd0006000000001171711111171711
77ffffff1199111170c00000000cc00000000c0770000c0700c5dddddddd5c500000000060d00000000dd00000000d0760000d06000000c01199111111119911
777fffff017771107000000000000000000000077000000700c5555555555c505555555560000000000000000000000760000006000000000177711001177710
7777ff7701777110700000000000000000cc000770c0000700cccccccccccc5055555555600000000000000000dd000760d0000600cc00000177711001177710
777777770177711070000000c000000000cc00077000000700cc77ccc7777c005555555560000000d000000000dd00076000000600cc00000177711001177710
57777577017771107000000000000000000000077000c0070777777777777770555555556000000000000000000000076000d006000000000996991111996990
00000000017771107000000000000000000000077000000700777700500000000000000560000000000000000000000660000006000000000000000000000000
00aaaaaa01777110700000000000000000000007700c0007070000705500000000000055600000000000000000000006600d00060b0000000000000000000000
0a99999901777110700000000000c0000000000770000007707700075550000000000555600000000000d0000000000660000006000000000011110000111100
a99aaaaa017771107000000cc0000000000000077000cc077077bb0755550000000055556000000dd0000000000000066000dd06000000b00057510000157500
a9aaaaaa017771107000000cc0000000000c00077000cc07700bbb0755555555555555556000000dd0000000000d00066000dd06000000000d7971d00d1797d0
a99999990177711070c00000000000000000000770c00007700bbb07555555555555555560d00000000000000000000660d0000600bb00000d6666d00d6666d0
a999999901777110700000000000000000000007700000070700007055555555555555556000000000000000000000066000000600bb00000066660000666600
a999999901777110077777777777777777777770077777700077770055555555555555550666666666666666666666600666666000000000009dd960069dd900
aaaaaaaa0177711007777777777777777777777007777770004bbb00004b000000400bbb06666666666666666666666006666660000000000000000000000000
a49494a10177711070007770000077700000777770007777004bbbbb004bb000004bbbbb60006660000066600000666660006666080000000588888000000000
a494a4a10177711070c777ccccc777ccccc7770770c7770704200bbb042bbbbb042bbb0060d666ddddd666ddddd6660660d66606000000005988888800111100
a49444aa0177711070777ccccc777ccccc777c0770777c07040000000400bbb00400000060666ddddd666ddddd666d0660666d060000008058888ff801717110
a49999aa0177711077770000077700000777000777770007040000000400000004000000666600000666000006660006666600060000000088f1ff180c991c10
a49444990177711077700000777000007770000777700c0742000000420000004200000066600000666000006660000666600d060088000008fffff011777111
a494a44401777110700000000000000000000007700000074000000040000000400000006000000000000000000000066000000600880000002ee20019779111
a4949999099699110777777777777777777777700777777040000000400000004000000006666666666666666666666006666660000000000070070009669110
066666666666666666666660066666600eeeeeeeeeeeeeeeeeeeeee00eeeeee0333333333333333333333333000000000000000000a0000000000000a4949999
60000666000066600000666660006666e0000eee0000eee00000eeeee000eeee3d3dd33d3dd3d3d3d3ed33d300000000000000000a4a00000a000a00a4444444
60bb666bbbb666bbbbb6660660b66606e088eee8888eee88888eee0ee08eee0e5dded3ddddedddddeddddd550000000000000000a949aaa00aa0a9a0aaa99994
60b666bbbb666bbbbb666b0660666b06e08eee8888eee88888eee80ee0eee80e55ddddde5dddd5de5d5555570000006000000000a444449aa94a44a000a44494
60666000066600000666000666660006e0eee0000eee00000eee000eeeee000e75555dd555dd555d555577570000060600000000aa4994994949499a00aaa494
66660000666000006660000666600006eeee0000eee00000eee0000eeee0000e7577555575555755757777770000600060000000aa499444444449aa0000a444
6000000000000000000b000660000b06e0000000000000000008000ee000080e7777775777557777777776770006000007000000aa4999aaa99a44aa0000aaaa
60000000000000000000000660000006e0000000000000000000000ee000000e7766677766777667777666770060000007000000aaaaaaaaaaaaaaaa00000000
60000000000000000000000660000006e0000000000000000000000ee000000e0000000000000000000000000700000007000600000000000000000000000000
6000000b000000000000000660bb0006e0000008000000000000000ee088000e0000000000000000000000006000000000706060000000000000000000000000
60000000000bb0000000000660bb0006e0000000000880000000000ee088000e0000000000000000000000070000000000060006000000000000000000000000
60b00000000bb00000000b0660000b06e0800000000880000000080ee000080e0000000000000000000000000000000000000000000000000000000000000000
60000000000000000000000660000006e0000000000000000000000ee000000e6600060006666600666666006600000066666600066666006666660066666600
600000000000000000bb000660b00006e0000000000000000088000ee080000e6660066066666660666666606600000066666660666666606666666066666660
60000000b000000000bb000660000006e0000000800000000088000ee000000e6666066066000660660000006600000066000000660000000066000066000000
6000000000000000000000066000b006e0000000000000000000000ee000800eddddddd0dd000dd0dddd0000dd000000dddd0000ddddddd000dd0000dddd0000
60000000000000000000000660000006e0000000000000000000000ee000000edd0dddd0dd000dd0dd000000dd0000d0dd000000000000d000dd0000dd000000
600000000000000000000006600b0006e0000000000000000000000ee008000edd00ddd0ddddddd0dddddd00ddddddd0dddddd00ddddddd000dd0000dddddd00
600000000000b0000000000660000006e0000000000080000000000ee000000edd000dd00ddddd00ddddddd0ddddddd0ddddddd00ddddd0000dd0000ddddddd0
6000000bb0000000000000066000bb06e0000008800000000000000ee000880e0000000000000000000000000000000000000000000000000000000000000000
6000000bb0000000000b00066000bb06e0000008800000000008000ee000880e0000000000000006000000000000000000000000000000600000000000000000
60b00000000000000000000660b00006e0800000000000000000000ee080000e0000000000000060000000000000000000000000000000060000000000000000
60000000000000000000000660000006e0000000000000000000000ee000000e0000000000006600000000000000000000000000000000006000000000000000
066666666666666666666660066666600eeeeeeeeeeeeeeeeeeeeee00eeeeee00000000000060000000000000000000000000000000000006000000000000000
066666666666666666666660066666600eeeeeeeeeeeeeeeeeeeeee00eeeeee00000000000600000000000000000000000000000000000006000000000000000
60006660000066600000666660006666e000eee00000eee00000eeeee000eeee000000000d000000000000000000000000000000000000006006000000000000
60b666bbbbb666bbbbb6660660b66606e08eee88888eee88888eee0ee08eee0e000000006000000000000000000000000000000000000000d0d0600000000000
60666bbbbb666bbbbb666b0660666b06e0eee88888eee88888eee80ee0eee80e0000000d00000000000008888880000000000888888000000d00060000000000
66660000066600000666000666660006eeee00000eee00000eee000eeeee000e0000000d000000000000888888880000000088888888000000000d0000000000
66600000666000006660000666600b06eee00000eee00000eee0000eeee0080e0000000d000000000000888ffff800000ccc888ffff80000000000d000000000
60000000000000000000000660000006e0000000000000000000000ee000000e000000d000000000000088f1ff180000c7c788f1ff18ddd00000000d00000000
066666666666666666666660066666600eeeeeeeeeeeeeeeeeeeeee00eeeeee000000d0000000000000008fffff00000c99cc8fffffd7d7d00000000d0000000
0dddddd00dddddd00dddddd00dddddd000dddd0000dddd00000000000000000000000000c000000cc000000c0000000000000000000000000000000000000000
0dccccd0cdccccdc0dccccd0cdccccdc0dddddd00dddddd0000000000000000000000000c0cccc0cc0cccc0cc0cccc0c00000000000000000000000000000000
0c7c7cc0cc7c7ccc0cc7c7c0ccc7c7cc0dccccd00dccccd00000ddd00000000000000000ccc7c7cccc7c7ccccc7c7ccc00000000000000000000000000000000
0c99ccc0cc99cccc0ccc99c0cccc99cc0c7c7cc00cc7c7c0000ddddd000dd00000000000cc99cccccccc99cccc99cccc007c0000000000b8c800000000007c00
cc777ccc0c777cc0ccc777cc0cc777c00c99ccc00ccc99c0000c7c7c00d77d00000dd0000c777cc00cc777c00c777cc000000000000000000000000000000000
cc777ccc0c777cc0ccc777cc0cc777c0cc777cccccc777cc000c99cc00d77d0000d77d000c777cc00cc777c009977cc0003c00008999d9b9c9d9e9f900001c00
0c777cc00c777cc00cc777c00cc777c0c9779cccccc9779c000ccccc000dd00000d77d00099799cccc997990000699c000000000000000000000000000000000
099699cc099699cccc996990cc99699009669cc00cc966900009669600dddd00000dd0000900900000090090000000cc005700008a9aaabacadaeafa00005700
044444400444444004444440044444400044440000444400000000000000000000000000b000000bb000000b0000000000000000000000000000000000000000
04bbbb40b4bbbb4b04bbbb40b4bbbb4b0444444004444440000000000000000000000000b0bbbb0bb0bbbb0bb0bbbb0b000000008b9b00000000ebfb00000000
0b7bb7b0bb7bb7bb0b7bb7b0bb7bb7bb04bbbb4004bbbb40000044400000000000000000bb7bb7bbbb7bb7bbbb7bb7bb00000000000000000000000000000000
0b99bbb0bb99bbbb0bbb99b0bbbb99bb0b7bb7b00b7bb7b0000444440004400000000000bb99bbbbbbbb99bbbbbb99bb00000000000000000000000000000000
bb777bbb0b777bb0bbb777bb0bb777b00b99bbb00bbb99b00007bb7b00477400000440000b777bb00bb777b00bb777b000000000000000670000000000000000
bb777bbb0b777bb0bbb777bb0bb777b0bb777bbbbbb777bb000b99bb00477400004774000b777bb00bb777b00bb7799000000000000000000000000000000000
0b777bb00b777bb00bb777b00bb777b0b9779bbbbbb9779b000bbbbb0004400000477400099799bbbb9979900b99600000000000009300123200000000000000
099699bb099699bbbb996990bb99699009669bb00bb966900009669600444400000440000900900000090090bb00000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000d000000dd000000d0000000093a39300a38200426285869300000000
00dddd00d0dddd0d00dddd00d0dddd0d0dd0000000000000000000000000000000000000d0dddd0dd0dddd0d00dddd0000000000000000000000000000000000
0d7d7dd0dd7d7ddd0dd7d7d0ddd7d7ddddd7d00000dddd00000000000000000000000000ddd7d7dddd7d7ddd0d7d7dd083920000828300425232820100000000
0799d7d0d799d7dd0d7d9970dd7d997d99797d000dd7d7d00000ddd00500000000055000dd99dd7dd7dd99ddd799d7dd00000000000000000000000000000000
dd777ddd0d777dd0ddd777dd0dd777d09779dd000d7d9970000d7d7d55505500005775000d777dd00dd777d0dd777ddd82000000828212525262839200000000
dd777ddd0d777dd0ddd777dd0dd777d0677d7d00ddd777dd000799d755557750005775000d777dd00dd777d009977dd000000000000000000000000000000000
0d777dd00d777dd00dd777d00dd777d099d7dd00ddd9779d000ddddd5555775000055000099799dddd997990000699d082930000821252525252320000000000
099699dd099699dddd996990dd9959909dddd0000dd966900009669655555500005555000900900000090090000000dd00000000000000000000000000000000
06666660066666600666666006666660006666000066660000000000000000000000000080000008800000080000000082920000834252525252523200000000
06888860868888680688886086888868066666600666666000000000000000000000000080888808808888080088880000000000000000000000000000000000
08888880888888880888888088888888068888600688886000006660000000000000000088888888888888880888888082000000125252525252526200000000
08787880887878880887878088878788088888800888888000066666000660000000000088878788887878888878878800000000000000000000000000000000
88998888089988808888998808889980087878800887878000088888006776000006600008998880088899808888998882100012525252525252525232001712
88777888087778808887778808877780889988888888998800087878006776000067760008777880088777808877777800000000000000000000000000000000
08777880087778800887778008877780897798888889779800089988000660000067760009979988889979900097779022222252525252525252525252222252
09969988099699888899699088996990096698800889669000096699006666000006600009009000000900900009690000000000000000000000000000000000
__label__
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff77fffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffff7f77fffffff7fffffffffffffffffffffffffffffffffff77fffffffffffffffffffffffffffffffffffffffff
fffffffffff77fffffffffffffffffffffffffff77ffffff6ffffffffffffffffffffff6ffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffffffff77fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7fffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7fffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6ffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffffffffffff7ffffffffffffffffffffffffff6fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff66ffffffffffffffffff
fffffffff7fddfffffffffffffffffffffffffffffffffffffffffffffffff6fffffff6fffffffffffffffffffffffffffffffffffff66fffffddfffffffffff
ffffffffffd77dfffffffffffffffffffffffffffffffffffffffffffffff6f6ffffffffffffffffffffffffffffffffffffffffffffffffffd77dffffffffff
ffffffffffd77dffffffffffffffffffffffffffffffffffffffffffffff6fff6fffffff6ffffffffffffff7ffffffffffffffffffffffffffd77dffffffffff
fffffffffffddffffffffffffffffffffffffffffffffffffffffffffff6fffff7fffffffffffffffffffffffffffffffffffffffffffffffffddfffffffffff
ffffffffffddddffffffffffffffffff6fffffffffffffffffffffffff6ffffff7ffffffffffffff66ffffffffffffffffffffffffffffffffddddffffffffff
fffffffffddddddffffffffffffffffffffffffffffffffffffffffff7fffffff7fff6ffffffffff66fffffffffffffffffffffffffffffffddddddfffffffff
ffffffffcdccccdcffffffffffffffffffffffffffffffffffffffff6fffffffff7f6f6fffffffffffffffffffffffffffffff7fffffffffcdccccdcffffffff
ffffffffccc7c7ccfffffffffffffffffffffffffffffffffffffffffffffffffff6fff6ffffffffffffffffffffffffffffffffffffffffcc7c7cccffffffff
ffffffffcccc97ccfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6ffffffffffffffffffffffffcc99ccccffffffff
fffffffffcc777cfffffffffffffffff66fff6fff66666fff66666ff66ffffff6666666ff66666ff666666ff666666fffffffff66ffffffffc777ccfffffffff
fffffffffcc777cfffffffffffffffff666ff66f6666666f6666666f66ffffff6666666f6666666f6666666f6666666ffffffff66fff7ffffc777ccfffffffff
fffffffffcc777cfffffffffffffffff6666f66f66fff66f66ffffff66fffff666ffffff66ffffffff666fff66fffffffffffffffffffffffc777ccfffffffff
ffffffffcc99699fffffffffffffffffdddd7ddfddfffddfdddddddfddffffffddddffffdddddddfffddffffddddf6fffffffffffffffffff97699ccffffffff
fffffffff777777fffffffffffffffffddfddddfddfffddfddffffffddffffdfddffffffffffffdfffddffffddfffffffffffffffffffffff777777fffffffff
ffffffff7fff7777ffffffffffffffffddffdddfdddddddfddddddffdddddddfddddddffdddddddfffddffffddddddffffffffffffffffff7ff77777ffffffff
ffffffff7fc777f7fff6ffffffffffffddfffddffdddddffdddddddfdddddddfdd6ddddffddd7dffffddffffdd77dddfffffffffffffffff7fc777f7ffffffff
ffffffff7f777cf7ffffffffffffffffffffffffff6fffffffffffffffffffffffffffffffffffffffffffffff77ffffffffffffffffffff7f777cf7ffffffff
ffffffff7777fff7fffffffffffffffffffffffffffffff6ffffffffffffffffffffffffffffff6fffff6fffffffffffffffffffffffffff7777fff7ffffffff
ffffffff777ffcf7fffffffffffffffffffffff77fffff6ffffffffffffffffffffffffffffffff6ffffffffffffffffffffffffffffffff777ffcf7ffffffff
ffffffff7ffffff7fffffffffffffffffffffff77fff66ffffffffffffffffffffffffffffffffff6fffffffffffffffffffffffffffffff7ffffff7ffffffff
fffffffff777777ffffffffffffffffffffffffffff6ffffffffffffffffffffffffffffffffffff6ffffffffffffffffffffffffffffffff777776fffffffff
ffffffffffffffffffffffffffffffffffffffffff6ffffffffffffffffffffffffff6ffffffffff6fffffffffffffffffffffffffffffffffffffffffffff7f
fffffffffffffffffffffffffffffffff66ffffffdfffffffffffffffff7ffffffffff6fffffffff6ff6ffffff7fffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffffff7766fffff6fffffffffffffffffffffffffffffffffffffffdfdf6fffffffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffff66ffff77ffffffdf6fffffffffffffffffffffffffffff7fffffffffdfff6ffffffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffff66ffffffffffff7fffffffffffff7fffffffffffffffffffffffffffffffdffffffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffffffffffffffdffffffffffffffffffffffffffffffffffffffffffffffdffffffffffffffffffff6ffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffdffffffffffffffffffffffffffffffffffffffffffffffffdffffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffffffffffffdffffffffffffffffffffffffffffffffffffffffffffffffffdfffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff66fffffffffffffffff
ffffffffffffffff6fffffffff6ffffffffffffffffff6ffffffffffffffffffffffffffffffff6ffffffffffffffffffff6fffffffff66fffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff77ffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff77ffffffffffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffffffffffffffff6fffffffffffffffffffffffff6ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffff7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffffffffffffff6ffffdddfffdfdfdffffffddfdddfffffdfdfffdffddfffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffdffdffdfdfffffdfdfdfdfffffdfdffdffdfffffffffffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffffffffffffffffffffdfffdfffdffffffdfdfddfffffffdfffdffdffffffffffffffffffffffff77fffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffdffffdffdfdfffffdfdfdfdfffffdfdffdffdffffffffffffffffffffffff77fffffffffffffffffffff
ffffffffffffffffffffffffffffffff7fffffffffffdddfdfffdfdfffffddffdfdff6ffdfdfdffffddfffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffff7fffffffffffffffffffffffffffffffffffffffffffffffffffffffff6fffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffff6fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7fffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff77ffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff77ff6fffffffffffffffffffffffffffff
fffffffffffffffffffffffffffffffffffffff7fffffffffffffffffffffffffffffffffffffffffffffffffff6ffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff77ffffffff66ffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffff6ffffffffffffffffff6ffffffffffffffffffffffffffff77ffffffff66ffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6fffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffff7fffffffffffffffffffffffff6fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffcccfcccfcccfcccfffffcccfcfcffccfcccffccffccfccffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffcccfcfcffcfffcfffffffcffcfcfcfcfcfcfcfffcfcfcfcffffffffffff66fffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffcfcfcccffcfffcfffffffcffcccfcfcfccffcccfcfcfcfcffffffffffff66fffffffffffffffffffffffffff
ff77ffffffffffffffffffffffffffffffffffffcfcfcfcffcfffcfffffffcffcfcfcfcfcfcfffcfcfcfcfcffffffffffffffffffffffffffffffffff6ffffff
ff77ffffffffffffffffffffffffffffffffffffcfcfcfcffcfffcfffffffcffcfcfccffcfcfccffccffcfcfffffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffffffffffffffffffffffffff7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6ffffff
ffffffffffffffffffffffffffffffffffffffffffffccfffccfcccfcfffffffcccfcccfcccfcccfcfcfffffffffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffff6ffffffffffffffffffffcfcfcfcfcfffcfffffffcfcfcfffcfcfcfcfcfcfffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffcfcfcfcfccffcfffffffccffccffccffccffcccfff7fffffffffffffffffffffffffffffffffffffffff
fffffff6ffffffffffffffffffffffffffffffffffffcfcfcfcfcfffcfffffffcfcfcfffcfcfcfcfffcfffffffffffffffffffffffffff7fffffffffffffffff
fffffffffffffffffffffffffffffffffffffff6ff7fcfcfccffcccfcccfffffcccfcccfcfcfcfcfcccfffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffff7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffff6ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6ffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6ff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6fffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff77ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffff6ffffff7ffffffffffffffffffffffffffffffffff7fffffff77ffffffffffffffffffffffffffffffffffffffffffffffffffff6fffffffff
ffffffffffffffffffffff66fffffffff7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6fffffff7fff
ffffffffffffffffffffff66fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7ffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffffffffffffff6ffffffffffffffffff7fffffffffffffff77ffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffaaafaaa6faaffaafaaafafffaaafffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffff7ffffffffffffffffffffaffafafafffafafffafafffafa6ffffffffffffffffffffffffffffffffffffffffffffffffff
fffffffffffffff66ffffffffffffffffffff6fffff66ffffffaffaaafafffafaffaafaaafafaffffffff6ffffffffffffffffffffffffffffffffffffffffff
fffffffffffffff66ffffffffffffffffffffffffff66ffffffaffafafaf6fafafffafafafafafffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffff7ffffffffffffffffffffffffaffafaffaafaaffaaafaaafaaafffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffff7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7fff66ffffffffffff
fffffffffffffffffffffffffffffffffffff6ffffffffffffffffffaaafaaafaaafaaafffffffffffffffffffffffffffffffffffffffffff66ffffffffffff
ffffffffff6fffffffffffffffffffffffffffffffffffffffffffffaaafafffafffafafffffffffffffffffffffffffffffff7fffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffafafaaffaaffaaafffffffffffffffffffffffffffffffff6ff7ffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffafafafffafffafffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffafafaaafaaafafffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffff6fffffffffffff6f6ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffff7fffffffffffffffffffffffffffffffffffffffffffff6f7ffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffff66fffffffffffffffffffff7ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffff66ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff77ffffffff
ffff66fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff6ffffffffff77ffffffff
ffff66ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7ffffffffffffffffffffffffff6ffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffffffffffffffffffffffffffffff6ffffffffffffffffffffffffffffffffff66ffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffffffffffff7ffffffffffffffffffffffffffffffffffffffffffffffffffff66ffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffff6ffffffff77fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7ffffffffffffffffff7ffffffffff
fffffffffffffffffffffffffffffff77fffffffffffffffffffffffffffffffffff66ffffffff7fffffffffffffffffffffffffffffff7fffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff66ffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffff7fffffffffffffffffffffffffffffff6fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff76fffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7ffffffffffffffffffffffffffffffffff
ffffffffffffffffffffffffffffffffffffffffffffff7fffffffff7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7ffffffffffffffffff77ffffffffffffffffffffffff6ffffff77fffffffffff
ffff888f888ff88f8f8fffff88ff888f888ff88fffff888ff88f888fffff888fffff888f8f8f888f8f87888f888fffff888f8886f88f888f8887788f888fffff
fffff8ff8fff8fff8f8fffff8f8f8fff888f8f8fffff8fff8f8f8f8fffff8f8ff66f8fff8f8ff8ff8f8f8f8f8fff77ff8f8f8f8f8f8ff8ff8fff8ffff8f6ffff
fffff8ff88ff8fff888fffff8f8f88ff8f8f8f8fffff88ff8f8f88ffffff888ff66f88ff8f8ff8ff8f8f88ff88ff77ff888f88ff8f8ff8ff88ff8ffff8ffffff
fffff8ff8fff8fff8f8fffff8f8f8fff8f8f8f8fffff8fff8f8f8f8fffff8f8fffff8fff8f8ff8ff8f8f8f8f8fffffff8fff8f8f8f8ff8ff8fff8ffff8ffff6f
fffff8ff888ff88f8f8fffff888f888f8f8f88ffffff8fff88ff8f8fffff8f8fffff8ffff88ff8fff88f8f8f888fffff8fff8f8f88ff88ff888ff88ff8ffffff
66ffffffffffffffffffffffffffffffffffff7fffffffffffffffffffffffffffffffffffffffffffffffffff7fffff6fffffffffffffffffffffffffffffff

__gff__
0000000000000000000000000000000004020000000000000000000200000000030303030303030304040402020000000303030303030303040404020202020200021313131302020323232323230202000013131313020204232323231302020000131313130004042323232313020200001313131300000023232323000002
43434343838383830b0b0b020202020043434343838383830202020202020202434343438383838302020202020202024343434383838383020200000000020202020202020202020202020000000000020202020202020202020200000000000202020202020202020202000000000002020202020202020202020000000000
__map__
20312525482525323232323233000024000000000000000000000000000000002525252525253233283828283125252500000024260000000000003b243232325363636363636363636353540000005991919200000000000000000000949595262b00003ba0a1a1a1a1a1a1a1a1a19125252525252548323233000000000000
4427313232323329000028290000002400000000000000000000000000000000254825253233002a282829281b31482500000024260000000000003b30000000540000001b1b1b1b0000525400003b596d91a200000000000000000000a4957d262b00000000000000d900000000009025482525253233000000000000000000
543122362a28383900002a00c8003d2400000000000000000000000000000000252525262b0000002900002a001b313200000031330000001100003b3000080054000000000000000000525400003b5991920000000000000000000000009495262b000000000000000000000000009025252525330000000000000000000000
53443040002a290000000000c420202400000000000000000000000000000000252525262b0000000000000000001b1b0000001b1b00003b272b003b3700000054000000111111110000525400003b596d92d700000000000000000000f7947d262b0000e40000e70000000000000090252548262b0000000000000000000000
535437000000000000000000343522480000000000000000000000002c00000032323226797a7b000000000000000000001400111100003b302b00000000000054003b497a7a7a4b0000626400003b599192d500000000000000000000f4949526b5b5b5b5b5b5b5b585b5b600000090252525262b0000000000000000001600
5353434343441111110000003a2831250000002c000000110000003d3c3e123f1b1b1b3135222300000000000000000022223522232b003b302b00000000000054003b5c0000005c00001b1b00003b596d91820000000000000000000084957d262b0000000000003b972b0000000090252525262b00000000001111110000d6
53535353535343737400002a28281024002c3d3c000000272b00003435222222001a001b1b312611111111000000c72c25330031262b003b302b000000000000542b005c0000005c0000000000003b599191923f3d3e3d00003d3e3d3f949595332b0000000000003ba72b0000000090482525262b003b888989898989898989
53535363636364000000000000002a243f3c2020000000302b000000c931252500000000001b2422222236000000c13c26000000302b003b302b000011000000542b005cc700005c0000000000003b59a1a1a221222236000034222223a4a5a51b00000000000000001b000000000090252525262b003b313232322525252525
6363640000000000000000000011113122222223000000372b3a3900682831250000000000c6242525332b00003b212226413d00302b123b302b123b2700000054003b5cc500c65c2b3b497a7a7a7a6a2222222532330000000031322522222200000000000000000000000000160090252525262b000000fa00003125252548
0000000000000000000000000072434325254826000000202828283828282824000000003b343232332b0000003b242525223600302b173b302b173b3000000054003b697a7a7a6b2b3b5c00c700ca003232323300ca00000000e9003132322500000000001100000011000000000090252548262b0000000000003b24482525
000000000000000000000000003b525348252526390000002a002a282810282400000000001b1b1b1b000000003b2425252600003011111130111111300000005400001b1b1b1b1b003b5c00c100000033000000000000000000000000000031000000003b83000000832b0000000090323232262b0000000000003b24252525
2cc700000000000000000000003b525d3232323328000000000000002a282824000000000000000000000000003b2425253300003122222225222222330000005400000000000000003b597a7b000000000000000000000000000000000000000000000000930000f69300000000009000000037b4b5b5b5b600003b24252548
3cc3000000002c0000000011111152531b1b1b2a383900000000000000290024000000000011111111000000003b242526002c0000313232323232332b0000005400000000000000003b5c00000000000001000000002c46472c000000000000002c000000932b003b930000000000902c00001b1b1b1b1b1b00003b24482525
22233d013d3f3c0000111142434353530000000028280000000000000000002400013f003b342222362b0000003b3125263f3c013d000000001111000000003a6400000100000000003b5c00000000004a4a4b0000003c56573c0000e7494a4a013c00003ba32b003ba32b00000000903c013d00000000000000003b24252525
48252222222223111142435d53535d5d000100002a28000000000000000000242222230000282426494a4a4a4a4a4b242522222223494a4a4a4a4a4a4b2b002822222222232b0000003b5c00000000005a5a5a4a4a4b21222223494a4a5a5a5a22230000001b0000001b00000000009021222384858585858600003b24254825
2525252548252642435d53535d53535d0017000000383900000000000000002425482600002a2426595a4d5a4d5a5b312525252526595a5a5a5a5a5a5b2b3a2825252525262b0000003b5c00000000005a5a5a5a21222525252522235a5a5a5a2526000000000000000000000000009024252694959595959600003b24252525
95a5a5a5953132323225262b0000002425252628282828242532323232254825000000000000000000000000000000000000000000000000000000001100000000111100000000000000000000000000000000000000000000000000000000000000001100000000202020202020202000000000000000000000000000000000
96000000972b002a2831332b000000242548332838282831261b1b1b1b31322500000000000000000000000000000000000000003900db0000000000201100003b20200000000000000000000000000000000000000000000000000000000000fb111120000000003b2020201b1b1b200000000000000000003f000000000000
96000000972b00002a2839003a39112425331b000000001b30000000001b1b3100000000000000000000000000000000000000002a00000000000000202000003b2020000000000000000000000000000000000000000000000000000000000011202020111100003b20202b00000038000000000000f80000213600d7000000
96000100970000000028282828282125261b000000000000370000000000001b00000000000000000000000000000000000011000000000000000000201b0000001b20000000000000000000f800cb000000000000000000000000000000000020202020202000003b20202b00160000000000000000f57f2126003dd3000000
95b5b600970016002a28283828282425330000888a0000001b00000000000000000000000000000000000000000000000011200000000000000000001b00390000001b000000000000000000f5000000000000000011111111000000000000001b202020201b00000000000000000000000000003d0021222532353536000000
961b1b009700000068282828282824251b00112426000000000000000011000000000000000000000000000000000000002020000000003a0000000000002a00000000000000000000003b202020202b0000000000202020202b000000000000001b1b1b1b001111110000000000000000000000342225253300fa0000000000
96000000972b003a28282829002a313200002125260000000000000000272b00000000000000000000000000000000000020200000000028390000000000000000000000000000000000001b20201b0000000000001b2020202b00000000000000000000003b2020201111111100000000000000003125260000000000000000
96000000972b002828283900000017000000242526110000888a110000302b0000000000000000000000000000000000001b20000000002828000000000000000016000000000000000000001b1b00000000000000001b1b1b0000000000000000000016003b2020202020202000000000005f00e10024260000000000000000
96001111972b6828282828000000171a000024252523001124252300003039000000000000000000000000000000000000001b000000002a2800000000000000000000000000000000110000000000000000000000000000000000000000160000000000003b20202020202b000000000034352222222525235f6e004e3d0000
963bb4b5a62b28282828290000000000d54124252526112125322611113038000000000000000000000000000000000000000000000000002a000000e7e50000000000000000000000202b00000000000000000000000000000000000000000000000000003b20202020202b0000000000c90031323232252522223535360000
96001b1b1b3a282828286758000000003522253232252225332831222226283900000000000000000000000000000000003a0000000000000000002020200000000000000000000000202b00000000000000000000000000000000000000200011000000003b20202020202b000000000000000000d73f2425253300ea000000
960000003a282828292828290000003a2831332810313233382828313233282800000000000000600000000000000000002900000000000000000020201b0000000000000000000000202b0000000000000000000000000000000000000020002000000000001b1b1b20202b0000000000003d3e7fd021252526000000000000
96111111282a2900f728100012002a282a2838282829002a28283829002a28380000000000003e00003e002c0000000000008d8e000100410000001b1b0000000000000000000000001b00000000000000000000000000000000eb00000020001b00000000000000d71b1b0000000000000034353535252525266f0000000000
9585858638000000f12a28888a0000283e012a2828111111102828111111282800002c013f3d212222233f3c3d2c000000002020202020200000000000000000000100000000000000000000000000000100000000000000000000000000d9000000000000000100d3e600000000000000000000000024252525236f6e7e6e00
957d9596280088898a00282426003a282123808181818181818181818181818200003c212222252525252222233c000000001b202020201b0000000000000000202020000000000000000000000000002000120000000000000000000000000000000000000020202020200000000000005f000100212525252525222222236f
95957d9628672425260028242628283824269091919191919191919191919192003a21252525252525252525252339000000001b1b1b1b00000000000000000000200000000000000000000000000000200020000000000000000000000000000000000000000020202000000000000022222222222525252525252525252522
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
012800001d0401d0301d0201d015180401803018020180151b0301b02022040220461f0351f03016040160401d0401d0401d002130611803018030180021f061240502202016040130201d0401b0221804018040
00100000070700706007050110000707007060030510f0700a0700a0600a0500a0000a0700a0600505005040030700306003000030500c0700c0601105016070160600f071050500a07005050030510a0700a060
000400000c5501c5601057023570195702c5702157037570285703b5702c5703e560315503e540315303e530315203f520315203f520315103f510315103f510315103f510315103f50000500005000050000500
000400002f7402b760267701d7701577015770197701c750177300170015700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
00030000096450e655066550a6550d6550565511655076550c655046550965511645086350d615006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
011000001f37518375273752730027300243001d300263002a3001c30019300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300
011800002953429554295741d540225702256018570185701856018500185701856000500165701657216562275142753427554275741f5701f5601f500135201b55135530305602454029570295602257022560
011000200a0700a0500f0710f0500a0600a040110701105007000070001107011050070600704000000000000a0700a0500f0700f0500a0600a0401307113050000000000013070130500f0700f0500000000000
012800002204022030220201b0112404024030270501f0202b0402202027050220202904029030290201601022040220302b0401b030240422403227040180301d0401d0301f0521f0421f0301d0211d0401d030
0108002001770017753f6253b6003c6003b6003f6253160023650236553c600000003f62500000017750170001770017753f6003f6003f625000003f62500000236502365500000000003f625000000000000000
002800200a1400a1300a1201113011120111101b1401b13018152181421813213140131401313013120131100f1400f1300f12011130111201111016142161321315013140131301312013110131101311013100
011800202e750377402e730377302e720377202e71037715227502b750227302b7301d750247501d730247301f750277401f730277201f7102771529750307502973030730297203072029710307102971030715
000600001877035770357703576035750357403573035720357103570000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700007000070000700
001e00202975035710297403571029730377102972037710227503571022740277503c710277403c710277202e750357102e740357102e730377102e720377102e710247402b75035710297503c710297403c710
001e002005570055700557005570055700000005570075700a5700a5700a570000000a570000000a5700357005570055700557000000055700557005570000000a570075700c5700c5700f570000000a57007570
000c00103b6352e6003b625000003b61500000000003360033640336303362033610336103f6003f6150000000000000000000000000000000000000000000000000000000000000000000000000000000000000
001e002024750307102b7503071024740307102b74030710247203a7102b7203a71024710357102b710357101d75033710247503c7101d74037710247402e7301d7202e730247202e7101d7102e7102471037700
001e00200c5700c5600c550000001157011560115500c5000c5700c5600f5710f56013570135600a5700a5600c5700c5600c550000000f5700f5600f550000000a5700a5600a5500f50011570115600a5700a560
001e00200c5700c5600c55000000115701156011550000000c5700c5600f5710f56013570135600f5700f5600c5700c5700c5600c5600c5500c5300c5000c5000c5000a5000a5000a50011500115000a5000a500
001e0020247712477024762247523a7103a710187523a7103571035710187523571018750370003700037000227712277222762227001f7711f7721f762247002277122772227620070027771277722776200700
011e0020247712477024762247523a7103a710187503a71035710357101875035710357151870018700007001f7711f7701f7621f7521870000700180011b7002277122770227622275222742227322272222715
011e0000247712477024772247622475224742247322472224712247150070000700007000070000700007002e0002e0002e7112e711357113571133711337112b7112b7112b7112b00130711307113071130712
000c00200c3320c3320c3220c3220c3120c3120c3120c3020c3320c3320c3220c3220c3120c3120c3120c30207332073320732207322073120731207312073020a3320a3320a3220a3220a3120a3120a3120a302
000c00000c3300c3300c3200c3200c3100c3100c3103a0000c3300c3300c3200c3200c3100c3100c3103f0000a3300a3201333013320073300732007310113000a3300a3200a3103c0000f3300f3200f3103a000
01040000336251a605000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005
000c00000c3300c3300c3300c3200c3200c3200c3100c3100c3100c31000000000000000000000000000000000000000000000000000000000000000000000000a3000a3000a3000a3000a3310a3300332103320
001000000c3500c3300c3200c315133001630016300336253c600336253c600336253c6003c600000000000019610156201263011640106501165014650176501b65021650296502c650246401b630186200f610
000c0000242752b27530275242652b26530265242552b25530255242452b24530245242352b23530235242252b22530225242152b21530215242052b20530205242052b205302053a2052e205002050020500205
001000102f65501075010753f615010753f6152f65501075010753f615010753f6152f6553f615010753f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
0010000016270162701f2711f2701f2701f270182711827013271132701d2711d270162711627016270162701b2711b2701b2701b270000001b200000001b2000000000000000000000000000000000000000000
00140020245753057524545305451b565275651f5752b5751f5452b5451f5352b5351f5252b5251f5152b5151b575275751b545275451b535275351d575295751d545295451d535295351f5752b5751f5452b545
002000200c2650c2650c2550c2550c2450c2450c2350a2310f2650f2650f2550f2550f2450f2450f2351623113265132651325513255132451324513235132351322507240162701326113250132420f2600f250
00140000072750726507255072450f2650f2550c2750c2650c2550c2450c2350c22507275072650725507245072750726507255072450c2650c25511275112651125511245132651325516275162651625516245
001400201f5702b5701f5402b54018550245501b570275701b540275401857024570185402454018530245301b570275701b540275401d530295301d520295201f5702b5701f5402b5401f5302b5301b55027550
00140020112751126511255112451326513255182751826518255182451d2651d2550f2651824513275162550f2750f2650f2550f2451126511255162751626516255162451b2651b255222751f2451826513235
00100010010752f655010753f6152f6553f615010753f615010753f6152f655010752f6553f615010753f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
001000100107501075010753f6152f6553f6153f61501075010753f615010753f6152f6553f6152f6553f61500005000050000500005000050000500005000050000500005000050000500005000050000500005
002800002904029040290302b031290242b021290142b01133044300412e0442e03030044300302b0412b0302e0442e0402e030300312e024300212e024300212b0442e0412b0342e0212b0442b0402903129022
000f00202451524515245252452524535245352454524545245552455524565245652457500505245750050524565005052456500505245550050524555005052454500505245350050524525005052451500505
000f00201f5151f5151f5251f5251f5351f5351f5451f5451f5551f5551f5651f5651f575000051f575000051f565000051f565000051f555000051f555000051f545000051f535000051f525000051f51500005
000500000373005731077410c741137511b7612437030371275702e5712437030371275702e5712436030361275602e5612435030351275502e5512434030341275402e5412433030331275202e5212431030311
012400201657216562165521654216532125621255212542195721956219552195421953212562125521254212572125621255212542125320d5620d5520d5421657216562165521654216532125621255212542
012400001357213562135521354213532115621155211542165721656216552165421653213562135521354213572135621355213542135320f5620f5520f5420c55211532165620f54216572165520c5720c552
000300001f3302b33022530295301f3202b32022520295201f3102b31022510295101f3002b300225002950000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b00002935500300293453037030360303551330524300243050030013305243002430500300003002430024305003000030000300003000030000300003000030000300003000030000300003000030000300
001600003c5753c5453c5353c5253c5153c51537555375453a5753a5553a5453a5353a5253a5253a5153a51535575355553554535545355353553535525355253551535515335753355533545335353352533515
00160000355753555535545355353552535525355153551537555375353357533555335453353533525335253a5753a5453a5353a5253a5153a51533575335553354533545335353353533525335253351533515
001000200c0600c0300c0500c0300c0500c0300c0100c0000c0600c0300c0500c0300c0500c0300c0100f0001106011030110501103011010110000a0600a0300a0500a0300a0500a0300a0500a0300a01000000
001000000506005030050500503005010050000706007030070500703007010000000f0600f0300f010000000c0600c0300c0500c0300c0500c0300c0500c0300c0500c0300c010000000c0600c0300c0100c000
0010000003625246150060503615246251b61522625036150060503615116253361522625006051d6250a61537625186152e6251d615006053761537625186152e6251d61511625036150060503615246251d615
00140020326103261032610326103161031610306102e6102a610256101b610136100f6100d6100c6100c6100c6100c6100c6100f610146101d610246102a6102e61030610316103361033610346103461034610
00400000302453020530235332252b23530205302253020530205302253020530205302153020530205302152b2452b2052b23527225292352b2052b2252b2052b2052b2252b2052b2052b2152b2052b2052b215
000500003705632056360562e0563a056360563805633006380062f0062f0063a0063300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
01 154a5644
00 4a164c44
00 4a164c44
00 4a4c0b44
00 54135244
00 4a164c44
00 4a164c44
02 4a115244
00 41424344
00 41424344
01 18595a44
00 18595a44
00 5c1b5a44
00 5d1b5a44
00 1f615a44
00 1f5a6144
00 1e5b6244
02 205a6444
00 41424344
00 41424344
01 3d672944
00 3d672944
00 3d6b2c44
00 3d6b2c44
00 3d6b2944
00 3d6b2c44
00 3d6d3044
00 3d316744
02 3d326744
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
01 387a7c44
02 397b7c44
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
00 41424344
01 347f4344
02 35424344

