local TAS={}

TAS.practice_timing=false
TAS.practice_time=0

TAS.advance_frame=false
TAS.cart_update=false
TAS.keypresses={}
TAS.keypresses[1]={}
TAS.states={}
TAS.states_flags={}
TAS.current_frame=0
TAS.keypress_frame=1

TAS.prev_state={room={x=0,y=0},deaths=0,index=1}
TAS.start=false
TAS.balloon_mode=false
TAS.balloon_selection=0
TAS.balloon_count=0
TAS.up_time=0
TAS.down_time=0

TAS.djump=-1
TAS.show_keys=false
TAS.showdebug=true

TAS.balloon_seeds={}
TAS.cloud_offsets={}

TAS.reproduce=false
TAS.final_reproduce=false
TAS.save_reproduce=false


--[[local function draw_time(x,y)
	if pico8.cart.time_ticking or (pico8.cart.level_index()<30 and pico8.cart.time_ticking==nil) then 
		pico8.cart.centiseconds=math.floor(100*pico8.cart.frames/30)
	end
	if TAS.showdebug and TAS.final_reproduce then
		local cs=pico8.cart.centiseconds
		local s=pico8.cart.seconds
		local m=pico8.cart.minutes
		--local h=math.floor(pico8.cart.minutes/60)

		pico8.cart.rectfill(x,y,x+32,y+6,0)
		pico8.cart.print((m<10 and "0"..m or m)..":"..(s<10 and "0"..s or s).."."..(cs<10 and "0"..cs or cs),x+1,y+1,7)
	end
end]]--

-- this is a comment
local function empty() 
end

local function clone(org,dst)
	for i,o in pairs(org) do
		if type(o)=="table" and i~="type" then 
			dst[i]={}
			clone(o,dst[i])
		elseif type(o)~="function" then
			dst[i]=o  
		end
	end
end
local function clone_function(fn)
  local dumped = string.dump(fn)
  local cloned = loadstring(dumped)
  local i = 1
  while true do
    local name = debug.getupvalue(fn, i)
    if not name then
      break
    end
    debug.upvaluejoin(cloned, i, fn, i)
    i = i + 1
  end
  setfenv(cloned,getfenv(fn))
  return cloned
end
local function get_state()
	local state={}
	local state_flag={}
	
	state_flag.state_practice_time=TAS.practice_time
	state_flag.got_fruit=pico8.cart.got_fruit[pico8.cart.level_index()+1]
	state_flag.has_dashed=pico8.cart.has_dashed
	state_flag.frames=pico8.cart.frames
	state_flag.seconds=pico8.cart.seconds
	state_flag.minutes=pico8.cart.minutes
	state_flag.has_key=pico8.cart.has_key
	state_flag.new_bg=pico8.cart.new_bg
	state_flag.flash_bg=pico8.cart.flash_bg
	state_flag.pause_player=pico8.cart.pause_player
	state_flag.max_djump=pico8.cart.max_djump
	state_flag.practice_timing=TAS.practice_timing
	state_flag.will_restart=pico8.cart.will_restart
	state_flag.delay_restart=pico8.cart.delay_restart
	state_flag.start=TAS.start
	state_flag.practice_timing=TAS.practice_timing
	state_flag.show_keys=TAS.show_keys
	state_flag.freeze=pico8.cart.freeze
	local objects=pico8.cart.objects
	for i,o in pairs(objects) do
		local s={}
		clone(o,s)
		table.insert(state,s)
			
	end
	
	return state, state_flag
end
TAS.get_state=get_state

local function set_state(state, state_flag)
	pico8.cart.got_fruit[pico8.cart.level_index()+1]=state_flag.got_fruit
	pico8.cart.has_dashed=state_flag.has_dashed
	pico8.cart.frames=state_flag.frames
	pico8.cart.seconds=state_flag.seconds
	pico8.cart.minutes=state_flag.minutes
	pico8.cart.has_key=state_flag.has_key
	pico8.cart.new_bg=state_flag.new_bg
	pico8.cart.flash_bg=state_flag.flash_bg
	pico8.cart.pause_player=state_flag.pause_player
	pico8.cart.max_djump=state_flag.max_djump
	pico8.cart.will_restart=state_flag.will_restart
	pico8.cart.delay_restart=state_flag.delay_restart
	TAS.practice_timing=state_flag.practice_timing
	TAS.show_keys=state_flag.show_keys
	pico8.cart.freeze=state_flag.freeze
	pico8.cart.objects={}
	for i,o in pairs(state) do
		local e = pico8.cart.init_object(o.type,o.x,o.y)
		clone(o,e)
	end
	TAS.start=state_flag.start
end
TAS.set_state=set_state

local function update_balloon(initial_offset, iterator)
	TAS.balloon_seeds[iterator]=initial_offset
	for i=0,#TAS.states do
		local _iterator=0
		for _,o in pairs(TAS.states[i]) do
			if o.type==pico8.cart.balloon then
				if _iterator==iterator then
					o.offset=o.offset - (o.initial_offset - initial_offset)
					o.initial_offset=initial_offset
					o.y=o.start+math.sin(-o.offset*2*math.pi)*2
				end
				_iterator=_iterator+1
			elseif o.type==pico8.cart.chest then
				if _iterator==iterator then
					o.offset=initial_offset
				end
				_iterator=_iterator+1
			end			
		end
	end
end
local function update_cloud(initial_offset, iterator)
	TAS.cloud_offsets[iterator]=initial_offset
	for i=0,#TAS.states do
		local _iterator=TAS.balloon_count
		for _,o in pairs(TAS.states[i]) do
			if o.type==pico8.cart.platform then 
				if _iterator==iterator then				
					--o.offset=o.offset or 0
					o.rem.x=o.rem.x+((initial_offset-o.offset)*.65)*o.dir
					o.offset=initial_offset
					
					local amount
					amount = math.floor(o.rem.x + 0.5)
					o.rem.x =o.rem.x-amount
					o.x=o.x+amount
				end
				_iterator=_iterator+1
			end
		end
	end
end

local function update()
	if TAS.balloon_mode then
		local iterator=0
		for _,o in pairs(pico8.cart.objects) do
			if o.type==pico8.cart.balloon then
				if iterator==TAS.balloon_selection then
					if love.keyboard.isDown("up") then
						TAS.up_time=TAS.up_time+1
						local delta=0.0001*TAS.up_time/2
						update_balloon((o.initial_offset+delta)%1,iterator)
						o.initial_offset=(o.initial_offset+delta)%1
						o.offset=(o.offset+delta)%1
						o.y=o.start+math.sin(-o.offset*2*math.pi)*2
					else
						if love.keyboard.isDown("down") then
							TAS.down_time=TAS.down_time+1
							local delta=0.0001*TAS.down_time/2
							update_balloon((o.initial_offset-delta)%1,iterator)
							o.initial_offset=(o.initial_offset-delta)%1
							o.offset=(o.offset-delta)%1
							o.y=o.start+math.sin(-o.offset*2*math.pi)*2
						else
							TAS.down_time=0
						end
						TAS.up_time=0
					end
				end
				iterator=iterator+1
			elseif o.type==pico8.cart.chest then
				if iterator==TAS.balloon_selection then
					if love.keyboard.isDown("up") then
						if TAS.up_time==0 then
							TAS.up_time=1
							o.offset=o.offset+1
							if o.offset==2 then
								o.offset=-1
							end
							update_balloon(o.offset,iterator)
						end
					else
						if love.keyboard.isDown("down") then
							if TAS.down_time==0 then
								TAS.down_time=1
								o.offset=o.offset-1
								if o.offset==-2 then
									o.offset=1
								end
								update_balloon(o.offset,iterator)
							end
						else
							TAS.down_time=0
						end
						TAS.up_time=0
					end
				end
				iterator=iterator+1
			end
		end
		for _,o in pairs(pico8.cart.objects) do
			if o.type==pico8.cart.platform then
				if iterator==TAS.balloon_selection then
					if love.keyboard.isDown("up") then
						if TAS.up_time==0 then
							TAS.up_time=1
							local newoff=(o.offset or 0)+1
							if newoff==2 then
								newoff=-1
							end
							update_cloud(newoff,iterator)
							o.rem.x=o.rem.x+((newoff-o.offset)*.65)*o.dir
							o.offset=newoff
							
							local amount
							amount = math.floor(o.rem.x + 0.5)
							o.rem.x =o.rem.x-amount
							o.x=o.x+amount
						end
					else
						if love.keyboard.isDown("down") then
							if TAS.down_time==0 then
								TAS.down_time=1
								local newoff=(o.offset or 0) -1
								if newoff==-2 then
									newoff=1
								end
								update_cloud(newoff,iterator)
								o.rem.x=o.rem.x+((newoff-o.offset)*.65)*o.dir
								o.offset=newoff
					
								local amount
								amount = math.floor(o.rem.x + 0.5)
								o.rem.x =o.rem.x-amount
								o.x=o.x+amount
							end
						else
							TAS.down_time=0
						end
						TAS.up_time=0
					end
				end
				iterator=iterator+1
			end 
		end
		
	end
	
	local seen_player=false
	local seen_player_spawn=false
	for _,o in pairs(pico8.cart.objects) do
		if o.type==pico8.cart.player then 
			seen_player=true
		elseif o.type==pico8.cart.player_spawn then 
			seen_player_spawn=true
			if o.state==2 and o.delay==0 then
				TAS.show_keys=true
			end
		end
	end
	if seen_player_spawn then 
		TAS.practice_timing=false 
	end
	if seen_player then 
		if not TAS.practice_timing then 
			TAS.practice_timing=true
			TAS.practice_time=0
		end
	end
	if TAS.advance_frame then
		TAS.advance_frame=false
		local prev_frames=TAS.keypress_frame-2
		
		pico8.cart.update=true
		TAS.cart_update=true
		
		if seen_player_spawn and not TAS.start then
			TAS.start=true
			TAS.current_frame=0
			TAS.practice_time=0
			TAS.keypress_frame=1
		elseif not seen_player_spawn then
			TAS.start=false 
		end
		
		TAS.current_frame=TAS.current_frame+1
		
		if pico8.cart.deaths~=TAS.prev_state.deaths then
			TAS.show_keys=false
			pico8.cart.max_djump=TAS.djump==-1 and pico8.cart.max_djump or TAS.djump
		end
		if TAS.show_keys then
			TAS.keypress_frame=TAS.keypress_frame+1
		end
		
		if TAS.prev_state.room.x>=0 and 
		(TAS.prev_state.room.x~=pico8.cart.room.x or TAS.prev_state.room.y~= pico8.cart.room.y) then
			if not TAS.final_reproduce then
				if TAS.save_reproduce then 
					TAS.save_reproduce=false
					TAS.save_file(true,prev_frames+2)
					log("Saved compressed file to "..love.filesystem.getRealDirectory(""))
					TAS.reproduce=false
				end 
				if pico8.cart.level_index()<=21 then
					pico8.cart.max_djump=TAS.djump==-1 and 1 or TAS.djump
					pico8.cart.new_bg=nil
				end
				
				TAS.practice_timing=false
				TAS.show_keys=false
				TAS.keypress_frame=1
				TAS.current_frame=0
				load_level(TAS.prev_state.room.x, TAS.prev_state.room.y, false)
				set_seeds()
			else
				if TAS.save_reproduce then 
					TAS.save_file(true,prev_frames+2)
					log("Saved compressed file to "..love.filesystem.getRealDirectory(""))
					TAS.reproduce=false
				end 
				local numFrames=TAS.current_frame
				TAS.load_file(love.filesystem.newFile("TAS/TAS"..tostring(pico8.cart.level_index()+1)..".tas"))
				TAS.reproduce=true
				log(tostring(pico8.cart.minutes<10 and "0"..pico8.cart.minutes or pico8.cart.minutes)..":"..tostring(pico8.cart.seconds<10 and "0"..pico8.cart.seconds or pico8.cart.seconds)..tostring(pico8.cart.frames/30):sub(2).." ("..prev_frames..")")
				if pico8.cart.level_index()==30 then
					--TAS.final_reproduce=false
					--TAS.showdebug=true
					
					--pico8.cart.draw_time=draw_time
					--pico8.cart.centiseconds=math.floor(100*pico8.cart.frames/30)
				end
			end
		end
		
		if not TAS.keypresses[TAS.keypress_frame+1] then
			TAS.keypresses[TAS.keypress_frame+1]={}
		end
		
		
		
		if TAS.practice_timing then
			TAS.practice_time=TAS.practice_time+1
		end
	else
		pico8.cart.update=false
		TAS.cart_update=false
	end
	
	if TAS.reproduce then
		TAS.advance_frame=true
		local state, state_flag=get_state()
		TAS.states[TAS.current_frame]=state
		TAS.states_flags[TAS.current_frame]=state_flag
	end
	TAS.prev_state.room ={x=pico8.cart.room.x,y=pico8.cart.room.y}
	TAS.prev_state.deaths=pico8.cart.deaths
	TAS.prev_state.index=pico8.cart.level_index()+1
end
TAS.update=update

local function draw()
	if TAS.balloon_mode then
		local iterator=0
		for _,o in pairs(pico8.cart.objects) do
			if o.type==pico8.cart.balloon then
				if iterator==TAS.balloon_selection then
					love.graphics.setColor(1,0,1)
					love.graphics.rectangle("line",o.x,o.y-1,9,9)
					local offset=tostring(math.floor(o.initial_offset*10000))
					if #offset==1 then
						offset="000"..offset
					elseif #offset==2 then
						offset="00"..offset
					elseif #offset==3 then
						offset="0"..offset
					end
					pico8.cart.print(offset,o.x+5-#offset*2,o.y+10,9)
				end
				iterator=iterator+1
			elseif o.type==pico8.cart.chest then
				if iterator==TAS.balloon_selection then
					love.graphics.setColor(1,0,1)
					love.graphics.rectangle("line",o.x,o.y-1,9,9)
					pico8.cart.print(o.offset,o.x+3,o.y+10,9)
				end
				iterator=iterator+1
			end
		end
		for _,o in pairs(pico8.cart.objects) do
			if o.type==pico8.cart.platform then
				if iterator==TAS.balloon_selection then
					love.graphics.setColor(1,0,1)
					love.graphics.rectangle("line",o.x,o.y-1,17,9)
					pico8.cart.print(o.offset or 0,o.x+7,o.y+10,9)
				end
				iterator=iterator+1
			end
		end
	end

	if TAS.showdebug and pico8.cart.level_index()<=30 and not TAS.final_reproduce then
		--[[pico8.cart.rectfill(pico8.camera_x+1,pico8.camera_y+1,pico8.camera_x+13,pico8.camera_y+7,0)
		pico8.cart.print(tostring(TAS.practice_time),pico8.camera_x+2,pico8.camera_y+2,7)
		
		local inputs_x=15
		pico8.cart.rectfill(pico8.camera_x+inputs_x,pico8.camera_y+1,pico8.camera_x+inputs_x+24,pico8.camera_y+11,0)
		if TAS.show_keys then
			pico8.cart.rectfill(pico8.camera_x+inputs_x + 12, pico8.camera_y+7, pico8.camera_x+inputs_x + 14, pico8.camera_y+9, TAS.keypresses[TAS.keypress_frame][0] and 7 or 1) -- l
			pico8.cart.rectfill(pico8.camera_x+inputs_x + 20, pico8.camera_y+7, pico8.camera_x+inputs_x + 22, pico8.camera_y+9, TAS.keypresses[TAS.keypress_frame][1] and 7 or 1) -- r
			pico8.cart.rectfill(pico8.camera_x+inputs_x + 16, pico8.camera_y+3, pico8.camera_x+inputs_x + 18, pico8.camera_y+5, TAS.keypresses[TAS.keypress_frame][2] and 7 or 1) -- u
			pico8.cart.rectfill(pico8.camera_x+inputs_x + 16, pico8.camera_y+7, pico8.camera_x+inputs_x + 18, pico8.camera_y+9, TAS.keypresses[TAS.keypress_frame][3] and 7 or 1) -- d
			pico8.cart.rectfill(pico8.camera_x+inputs_x + 2, pico8.camera_y+7, pico8.camera_x+inputs_x + 4, pico8.camera_y+9, TAS.keypresses[TAS.keypress_frame][4] and 7 or 1) -- z
			pico8.cart.rectfill(pico8.camera_x+inputs_x + 6, pico8.camera_y+7, pico8.camera_x+inputs_x + 8, pico8.camera_y+9, TAS.keypresses[TAS.keypress_frame][5] and 7 or 1) -- x
		end]]--
		pico8.cart.camera(0,0)
		pico8.cart.rectfill(1,1,13,7,0)
		pico8.cart.print(tostring(TAS.practice_time),2,2,7)
		
		local inputs_x=15
		pico8.cart.rectfill(inputs_x,1,inputs_x+24,11,0)
		if TAS.show_keys then
			pico8.cart.rectfill(inputs_x + 12, 7, inputs_x + 14, 9, TAS.keypresses[TAS.keypress_frame][0] and 7 or 1) -- l
			pico8.cart.rectfill(inputs_x + 20, 7, inputs_x + 22, 9, TAS.keypresses[TAS.keypress_frame][1] and 7 or 1) -- r
			pico8.cart.rectfill(inputs_x + 16, 3, inputs_x + 18, 5, TAS.keypresses[TAS.keypress_frame][2] and 7 or 1) -- u
			pico8.cart.rectfill(inputs_x + 16, 7, inputs_x + 18, 9, TAS.keypresses[TAS.keypress_frame][3] and 7 or 1) -- d
			pico8.cart.rectfill(inputs_x + 2, 7, inputs_x + 4, 9, TAS.keypresses[TAS.keypress_frame][4] and 7 or 1) -- z
			pico8.cart.rectfill(inputs_x + 6, 7, inputs_x + 8, 9, TAS.keypresses[TAS.keypress_frame][5] and 7 or 1) -- x
		end
	end
end
TAS.draw=draw

local function save_file(compress,idx)
	local file=love.filesystem.newFile("TAS"..tostring(TAS.prev_state.index)..".tas")

	file:open("w")
	
	file:write("[")
	for _,o in pairs(TAS.balloon_seeds) do
		file:write(tostring(o)..",")
	end
	file:write("]")
	local finish
	if(compress) then 
		finish=idx 
	else
		finish=#TAS.keypresses
	end
	for _=2,finish do
		local i=TAS.keypresses[_]
		local line=0
		for x=0,5 do
			if i[x] then
				if x==0 then
					line=line+1
				elseif x==1 then
					line=line+2
				elseif x==2 then
					line=line+4
				elseif x==3 then
					line=line+8
				elseif x==4 then
					line=line+16
				else
					line=line+32
				end
			end
		end
		file:write(tostring(line)..",")
	end
	
	file:close()
end
TAS.save_file=save_file

local function ready_level()
	TAS.states={}
	TAS.state_flags={}
	TAS.keypresses={}
	TAS.keypresses[1]={}
	TAS.current_frame=0
	TAS.practice_timing=false
	TAS.practice_time=0
	TAS.show_keys=false
	TAS.balloon_mode=false
	TAS.balloon_selection=0
	TAS.balloon_count=0
	TAS.balloon_seeds={}
	pico8.cart.freeze=0
	TAS.keypress_frame=1
	TAS.prev_state={room={x=-1,y=-1},deaths=pico8.cart.deaths,index=-1}
	TAS.start=false
	TAS.save_reproduce=false
end

function set_seeds()
	local iterator2=0
	local clouditer=0
	for _,o in pairs(pico8.cart.objects) do
		if o.type==pico8.cart.balloon then
			o.initial_offset=TAS.balloon_seeds[iterator2]
			o.offset=o.initial_offset
			iterator2=iterator2+1
		elseif o.type==pico8.cart.chest then
			o.offset=TAS.balloon_seeds[iterator2]
			iterator2=iterator2+1
		elseif o.type==pico8.cart.platform and not TAS.final_reproduce then
			o.offset=TAS.cloud_offsets[TAS.balloon_count+clouditer]
			o.rem.x=o.dir*0.65*TAS.cloud_offsets[TAS.balloon_count+clouditer]
			local amount
			amount = math.floor(o.rem.x + 0.5)
			o.rem.x = o.rem.x- amount
			o.x=o.x+amount
			
			clouditer=clouditer+1
		end
	end
end

function load_level(room_x, room_y, reset_seeds)
	pico8.cart.got_fruit[1+room_y*8+room_x%8]=false
	pico8.cart.load_room(room_x, room_y)
	TAS.practice_time=0
	TAS.practice_timing=false
	TAS.balloon_count=0
	TAS.cloud_count=0
	local i=0
	for _,o in pairs(pico8.cart.objects) do
		if o.type==pico8.cart.balloon then
			TAS.balloon_count=TAS.balloon_count+1
		    if reset_seeds then
				TAS.balloon_seeds[i]=0
				o.initial_offset=0
				o.offset=0
				i=i+1
			end
		elseif o.type==pico8.cart.chest then
			TAS.balloon_count=TAS.balloon_count+1
		    if reset_seeds then
				TAS.balloon_seeds[i]=0
				o.offset=0
				i=i+1
			end
		end 
	end 
	for _,o in pairs(pico8.cart.objects) do
		if o.type==pico8.cart.platform then
			TAS.cloud_count=TAS.cloud_count+1
			if reset_seeds then 
				TAS.cloud_offsets[i]=0
				o.offset=0
				o.rem.x=0
			end
			i=i+1
		end
	end
end

local function load_file(file)
	TAS.keypresses={}
	local data=file:read()
	if data~=nil then
		local iterator=2
		local h=0
		for x in data:gmatch("([^]]+)") do
			if h==0 then
				local i=0
				for s in x:sub(2):gmatch("([^,]+)") do
					TAS.balloon_seeds[i]=tonumber(s)
					i=i+1
				end
				h=1
			else
				for s in x:gmatch("([^,]+)") do
					TAS.keypresses[iterator]={}
					for i=0,5 do
						TAS.keypresses[iterator][i]=false
					end
					local c=tonumber(s)
					for i=0,5 do
						if math.floor(c/math.pow(2,i))%2==1 then
							TAS.keypresses[iterator][i]=true
						end
					end
					iterator=iterator+1
				end
			end
		end
	end
	TAS.reproduce=false
	TAS.practice_timing=false
	pico8.cart.got_fruit[1+pico8.cart.level_index()]=false
	if not TAS.final_reproduce then
		pico8.cart.load_room(pico8.cart.room.x,pico8.cart.room.y)
	end
	TAS.show_keys=false
	TAS.current_frame=0
	TAS.keypress_frame=1
	TAS.states={}
	TAS.states_flags={}
	set_seeds()
end
TAS.load_file=load_file
local function reload_level(reset_seeds)
	TAS.practice_timing=false
	TAS.show_keys=false
	pico8.cart.will_restart=false
	TAS.current_frame=0
	TAS.keypress_frame=1
	TAS.states={}
	TAS.states_flags={}
	load_level(pico8.cart.room.x, pico8.cart.room.y, reset_seeds)
	pico8.cart.max_djump=TAS.djump==-1 and pico8.cart.max_djump or TAS.djump
	set_seeds()
end
local function keypress(key)
	if key=='p' then
		TAS.reproduce=not TAS.reproduce
		TAS.save_reproduce=false
	elseif key=='e' then
		TAS.showdebug=not TAS.showdebug
	elseif key=='b' then
		if not TAS.final_reproduce then
			if TAS.current_frame>0 then
				TAS.balloon_mode=not TAS.balloon_mode
			end
		end
	elseif key=='n' then
		TAS.final_reproduce=not TAS.final_reproduce
		if TAS.final_reproduce then
			ready_level()
			pico8.cart.load_room(0,0)
			TAS.load_file(love.filesystem.newFile("TAS/TAS1.tas"))
			pico8.cart.max_djump=1
			pico8.cart.new_bg=nil
			pico8.cart.music(0,0,7)
		end
		TAS.reproduce=TAS.final_reproduce
		TAS.save_reproduce=false
		--TAS.showdebug=not TAS.final_reproduce
		TAS.balloon_mode=false
		--pico8.cart.draw_time=TAS.final_reproduce and draw_time or empty
		pico8.cart.frames=0
		pico8.cart.centiseconds=0
		pico8.cart.seconds=0
		pico8.cart.minutes=0
		pico8.cart.deaths=0
	elseif key=='i' then 
		TAS.final_reproduce=not TAS.final_reproduce
		if TAS.final_reproduce then
			ready_level()
			pico8.cart.load_room(0,0)
			TAS.load_file(love.filesystem.newFile("TAS/TAS1.tas"))
			pico8.cart.max_djump=1
			pico8.cart.new_bg=nil
			pico8.cart.music(0,0,7)
		end
		TAS.reproduce=TAS.final_reproduce
		TAS.save_reproduce=TAS.final_reproduce
		--TAS.showdebug=not TAS.final_reproduce
		TAS.balloon_mode=false
		--pico8.cart.draw_time=TAS.final_reproduce and draw_time or empty
		pico8.cart.frames=0
		pico8.cart.centiseconds=0
		pico8.cart.seconds=0
		pico8.cart.minutes=0
		pico8.cart.deaths=0
	elseif key=='y' then
		for _,o in pairs(pico8.cart.objects) do
			if o.type==pico8.cart.player then
				log("----------------------------------")
				log("position: "..tostring(o.x)..", "..tostring(o.y))
				log("rem values: "..tostring(o.rem.x)..", "..tostring(o.rem.y))
				log("speed: "..tostring(o.spd.x)..", "..tostring(o.spd.y))
			end
		end
	elseif key=='f' then
		pico8.cart.will_restart=false
		if not TAS.final_reproduce then
			if not pico8.cart.pause_player then
				ready_level()
				if pico8.cart.level_index()<30 then
					local newx=pico8.cart.room.x
					local newy=pico8.cart.room.y
					if pico8.cart.room.x==7 then
						newx=0
						newy=pico8.cart.room.y+1
					else
						newx=pico8.cart.room.x+1
					end
					load_level(newx, newy, true)
					if pico8.cart.level_index()>21 then
						pico8.cart.max_djump=TAS.djump==-1 and 2 or TAS.djump
						pico8.cart.new_bg=true
					end
				else
					load_level(pico8.cart.room.x, pico8.cart.room.y, true)
				end
			end
		end
	elseif key=='s' then
		pico8.cart.will_restart=false
		if not TAS.final_reproduce then
			if not pico8.cart.pause_player then
				ready_level()
				if pico8.cart.level_index()>0 then
					local newx=pico8.cart.room.x
					local newy=pico8.cart.room.y
					if pico8.cart.room.x==0 then
						newx=7
						newy=pico8.cart.room.y-1
					else
						newx=pico8.cart.room.x-1
					end
					load_level(newx, newy, true)
					if pico8.cart.level_index()<=21 then
						pico8.cart.max_djump=TAS.djump==-1 and 1 or TAS.djump
						pico8.cart.new_bg=nil
					end
				else
					load_level(pico8.cart.room.x, pico8.cart.room.y, true)
				end
			end
		end
	elseif key=='d' then
		if not TAS.final_reproduce then
			TAS.reproduce=false
			TAS.save_reproduce=false
			reload_level()
		end
	elseif key=='r' then
		if not TAS.final_reproduce then
			ready_level()
			reload_level(true)
		end
	elseif key=='l' then
		if not TAS.final_reproduce then
			TAS.advance_frame=true
			local state, state_flag=get_state()
			TAS.states[TAS.current_frame]=state
			TAS.states_flags[TAS.current_frame]=state_flag
		end
	elseif key=='k' then
		if not TAS.final_reproduce then
			if TAS.current_frame>0 then
				TAS.current_frame=TAS.current_frame-1
				if TAS.show_keys then
					TAS.keypress_frame=TAS.keypress_frame-1
				end
				set_state(TAS.states[TAS.current_frame], TAS.states_flags[TAS.current_frame])
				TAS.practice_time=math.max(TAS.practice_time-1,0)
			end
		end
	elseif key=='1' or key=='2' or key=='3' or key=='0' then 
		TAS.djump=tonumber(key)
		reload_level()
	elseif key=='-' then 
		TAS.djump=-1
		reload_level()
	elseif key=='up' then
		if not TAS.reproduce then
			if not TAS.balloon_mode then
				TAS.keypresses[TAS.keypress_frame][2]=not TAS.keypresses[TAS.keypress_frame][2]
			end
		end
	elseif key=='down' then
		if not TAS.reproduce then
			if not TAS.balloon_mode then
				TAS.keypresses[TAS.keypress_frame][3]=not TAS.keypresses[TAS.keypress_frame][3]
			end
		end
	elseif key=='left' then
		if not TAS.reproduce then
			if TAS.balloon_mode then
				TAS.balloon_selection=TAS.balloon_selection-1
				if TAS.balloon_selection==-1 then
					TAS.balloon_selection=TAS.balloon_count+TAS.cloud_count-1
				end
			else
				TAS.keypresses[TAS.keypress_frame][0]=not TAS.keypresses[TAS.keypress_frame][0]
			end
		end
	elseif key=='right' then
		if not TAS.reproduce then
			if TAS.balloon_mode then
				TAS.balloon_selection=TAS.balloon_selection+1
				if TAS.balloon_selection==TAS.balloon_count+TAS.cloud_count then
					TAS.balloon_selection=0
				end
			else
				TAS.keypresses[TAS.keypress_frame][1]=not TAS.keypresses[TAS.keypress_frame][1]
			end
		end
	elseif key=='c' or key=='z' then
		if not TAS.reproduce then
			TAS.keypresses[TAS.keypress_frame][4]=not TAS.keypresses[TAS.keypress_frame][4]
		end
	elseif key=='x' then
		if not TAS.reproduce then
			TAS.keypresses[TAS.keypress_frame][5]=not TAS.keypresses[TAS.keypress_frame][5]
		end
	elseif key=='m' then
		TAS.save_file(false)
		log("Saved file to "..love.filesystem.getRealDirectory(""))
	elseif key=='u' then 
		if not TAS.final_reproduce then 
			TAS.save_file(false)
			log("Saved uncompressed file to "..love.filesystem.getRealDirectory(""))
			TAS.reproduce=true 
			TAS.save_reproduce=true
		end 
	elseif key=='w' then 
		if not TAS.final_reproduce then 
			TAS.load_file(love.filesystem.newFile("TAS/TAS"..(pico8.cart.level_index()+1)..".tas"))
		end
	end
end
TAS.keypress=keypress

local function init() 
	--setfenv(draw_time,pico8.cart)
	--pico8.cart.draw_time=draw_time
	--[[local draw_orb=clone_function(pico8.cart.orb.draw)
	local draw_chest=clone_function(pico8.cart.big_chest.draw)
	local draw_time=clone_function(pico8.cart.draw_time)]]--
	
	
	
	if pico8.cart.big_chest~=nil then 
		local draw_chest=pico8.cart.big_chest.draw
		pico8.cart.big_chest.draw=function(this)
			if not TAS.cart_update and this.state==1 then
				this.state=3
			end
			draw_chest(this)
			if this.state==3 then 
				this.state=1
			end
		end
	end
	if pico8.cart.orb~=nil then 
		local draw_orb=pico8.cart.orb.draw
		pico8.cart.orb.draw=function(this)
			local tmpcollide=this.collide
			if not TAS.cart_update then 
				this.spd.y=this.spd.y-0.5
				this.collide=function() end
			end
			draw_orb(this)
			this.collide=tmpcollide
		end
	end
	if pico8.cart.draw_time~=nil then
		local draw_time=pico8.cart.draw_time
		pico8.cart.draw_time=function(...)
			local arg={...}
			if (TAS.showdebug and TAS.final_reproduce) or pico8.cart.level_index()==30 then 
				if arg[1]~=4 or arg[2]~=4 then 
					draw_time(...)
				end
			end 
		end
	end
	if pico8.cart.balloon~=nil then
		local balloon_init=pico8.cart.balloon.init
		pico8.cart.balloon.init=function(this) 
			balloon_init(this)
			this.initial_offset=this.offset 
		end
	
	end
	
	if pico8.cart.chest~=nil then
		local chest_init=pico8.cart.chest.init 
		pico8.cart.chest.init=function(this)
			chest_init(this)
			this.offset=0
		end 
		local chest_update=pico8.cart.chest.update 
		pico8.cart.chest.update=function(this)
			local _rnd=pico8.cart.rnd
			if(this.timer-1<=0) then 
				pico8.cart.rnd=function() return this.offset+1 end
			end 
			chest_update(this)
			pico8.cart.rnd=_rnd
		end
	end
	local _draw=pico8.cart._draw
	pico8.cart._draw=function() 
		_draw()
		if pico8.cart.level_index()<30 then
			pico8.cart.draw_time(1,1,7)
		end
	end
	pico8.cart.begin_game()
	load_level(pico8.cart.room.x,pico8.cart.room.y,true)
end
TAS.init=init
local function restart()
	TAS.practice_timing=false
	TAS.practice_time=0
	TAS.advance_frame=false
	TAS.cart_update=false
	TAS.keypresses={}
	TAS.keypresses[1]={}
	TAS.states={}
	TAS.states_flags={}
	TAS.current_frame=0
	TAS.keypress_frame=1
	TAS.balloon_mode=false
	TAS.balloon_selection=0
	TAS.balloon_count=0
	TAS.up_time=0
	TAS.down_time=0
	TAS.djump=-1
	TAS.showdebug=true
	TAS.show_keys=false
	TAS.balloon_seeds={}
	TAS.cloud_offsets={}
	TAS.reproduce=false
	TAS.final_reproduce=false
	TAS.save_reproduce=false
	TAS.start=false
	TAS.prev_state={room={x=0,y=0},deaths=0,index=1}
end
TAS.restart=restart

return TAS