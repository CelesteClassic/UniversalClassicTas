pico-8 cartridge // http://www.pico-8.com
version 18
__lua__
-- matt thorson + noel berry
-- mod by kris de asis

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
sfx_timer=0
pause_player=false
flash_bg=false
music_timer=0

k_left=0 --left
k_right=1 --right
k_up=2 --up
k_down=3 --down
k_jump=4 --up
k_dash=3 --z
k_shoot=5 --x

-- entry point --
-----------------

function _init()
  title_screen()
end

function title_screen()
  got_fruit = {}
  for i=0,29 do
    add(got_fruit,false)
  end
  frames=0
  deaths=0
  start_game=false
  start_game_flash=0
  music(0,0,7)
  load_room(7,3)
end

function begin_game()
  frames=0
  centiseconds=0
  seconds=0
  minutes=0
  music_timer=0
  start_game=false
  music(6,100,0)
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
for i=0,12 do
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
max_djump=1
max_djumps=0
player = 
{
  init=function(this) 
    this.spr=1
    this.p_jump=false
    this.p_dash=false
    this.p_shoot=false
    this.dir=1
    this.grace=0
    this.djumps=0
    this.jbuffer=0
    this.dash_time=0
    this.dash_cd=0
    this.shoot_cd=0
    this.dash_target={x=0,y=0}
    this.dash_accel={x=0,y=0}
    this.hitbox={x=1,y=3,w=6,h=5}
    this.spr_off=0
    this.was_on_ground=false
  end,
  update=function(this)
    if pause_player then
      return
    end
    
    local input = btn(k_right) and 1 or (btn(k_left) and -1 or 0)
    
    -- spikes collide
    if spikes_at(this.x+this.hitbox.x,this.y+this.hitbox.y,this.hitbox.w,this.hitbox.h,this.spd.x,this.spd.y) then
      kill_player(this)
    end
     
    -- bottom death
    if this.y>128 then
      kill_player(this)
    end

    local on_ground=this.is_solid(0,1)
    
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

    local shoot = btn(k_shoot) and not this.p_shoot
    this.p_shoot = btn(k_shoot)

    if on_ground then
      this.grace=6
      this.djumps=0
    elseif this.grace>0 then
      this.grace-=1
    end

    if this.dash_cd>0 then
      this.dash_cd-=1
    end
    if this.dash_time>0 then
      if rnd(10)<4 then
        init_object(smoke,this.x,this.y)
      end
      this.dash_time-=1
      this.spd.x=appr(this.spd.x,this.dash_target.x,this.dash_accel.x)
    end

    -- move
    local maxrun=1
    local accel=0.6
    local deccel=0.15
    
    if not on_ground then
      accel=0.4
    end
    
    if abs(flr(10000*this.spd.x+0.5)/10000)>1.3 then
      if this.dash_time==0 then
        this.spd.x=appr(this.spd.x,sign(this.spd.x)*maxrun,deccel)
      end
      if input==-sign(this.spd.x) then
        this.spd.x=appr(this.spd.x,input*maxrun,accel)
      end
    elseif abs(flr(10000*this.spd.x+0.5)/10000)>1 then
      this.spd.x=appr(this.spd.x,sign(this.spd.x)*maxrun,deccel)
    else
      this.spd.x=appr(this.spd.x,input*maxrun,accel)
    end
      
    --facing
    if (this.spd.x!=0) then
      this.flip.x=(this.spd.x<0)
      this.dir=this.flip.x and -1 or 1
    end

    -- gravity
    local maxfall=2
    local gravity=0.21

    if abs(this.spd.y)<=0.15 then
      gravity*=0.5
    end
    
    -- wall slide
    local wallslide=(input!=0) and this.is_solid(input,0)
    if wallslide then
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
        this.spd.y=this.dash_time==0 and -2 or -2.2
        init_object(smoke,this.x,this.y+4)
      else
        -- wall jump
        local wall_dir=(this.is_solid(-3,0) and -1 or this.is_solid(3,0) and 1 or 0)
        if (wall_dir!=0) then
          psfx(2)
          this.jbuffer=0
          this.spd.y=-2
          this.spd.x=-wall_dir*(maxrun+0.3)
          init_object(smoke,this.x+wall_dir*6,this.y)
        elseif this.djumps<max_djumps then
          psfx(1)
          this.jbuffer=0
          this.spd.y=-1.8
          this.djumps+=1
        end
      end
    end

    -- dash
    if dash and this.dash_cd==0 and on_ground then
      init_object(smoke,this.x,this.y) 
      this.dash_time=4
      this.dash_cd=8
      this.spd.x=(input!=0 and input or this.dir)*4
      this.spd.y=0
      psfx(3)
      this.dash_target.x=3*sign(this.spd.x)
      this.dash_accel.x=0.4
    end

    if this.shoot_cd>0 then
      this.shoot_cd-=1
    end
    if shoot and this.shoot_cd==0 then
      sfx(6)
      this.shoot_cd=10
      local ldir=(wallslide and not on_ground) and -this.dir or this.dir
      local lemon = init_object(lemon,this.x+ldir*3,this.y)
      lemon.dir=ldir
      lemon.good=true
    end
    
    -- animation
    this.spr_off+=0.25
    if not on_ground then
      this.spr=this.is_solid(input,0) and 5 or 3
    elseif btn(k_down) or this.dash_time>0 then
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
      next_room()
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
    pal(9,max_djumps==0 and 1 or (this.djumps==0 and 7 or 13))
    pal(8,this.djumps==0 and 8 or 2)
    spr(this.spr,this.x,this.y,1,1,this.flip.x,this.flip.y)
    pal(9,9)
    pal(8,8)
  end
}

psfx=function(num)
 if sfx_timer<=0 then
  sfx(num)
 end
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
    --create_hair(this)
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
        --shake=5
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
    pal(9,max_djumps==0 and 1 or 7)
    spr(this.spr,this.x,this.y,1,1,this.flip.x,this.flip.y)
    pal(9,9)
  end
}
add(types,player_spawn)

maddy_intro=true
hp=20
mrng_a=1337.8008
mrng_b=8008.1337
mrng_m=143.24
mrnd=144.4667861009766
maddy_spawned=false
seeds={144.4668, 84.2295, 74.9755, 13.6295, 28.7528, 131.8417, 96.7317, 41.2645, 110.8889, 73.2164, 95.3304, 28.7771, 21.0996, 63.3651, 26.3924, 125.3801, 46.7243, 109.8058, 56.6043, 5.9243, 34.0092, 1.7679, 59.9301, 14.7296, 68.1461, 44.5418, 54.8823, 137.3518, 19.6701, 13.1133, 54.3327, 118.2676, 128.7118, 63.5112, 78.6907, 113.5786, 90.4346, 68.1533, 54.2177, 107.6735, 68.8403, 113.8014, 101.9672, 26.587, 99.2095, 61.5659, 54.5087, 67.1724, 106.479, 46.4925, 86.1477, 62.8425, 43.4192, 128.6195, 83.2921, 110.0085, 41.2119, 40.4837, 69.0856, 12.3056, 119.7196, 65.9148, 142.9217, 22.6284, 103.2057, 107.9086, 96.826, 24.1986, 55.2896, 109.2003, 105.966, 76.3387, 118.4259, 53.9782, 73.7068, 35.1705, 123.0386, 65.5546, 90.7877, 110.8157, 118.4525, 89.6605, 35.291, 141.0018, 32.4343, 43.5805, 57.989, 139.4421, 94.4561, 5.0195, 112.7876, 34.9136, 65.7599, 78.9471, 26.964, 30.6398, 77.8819, 34.3374, 11.2383, 124.3985, 22.763, 140.1124, 131.8097, 53.9251, 2.7504, 85.2386, 135.8235, 123.7226, 121.2598, 120.9429, 126.7824, 60.6202, 78.5388, 53.6866, 113.3914, 126.4443, 38.0853, 11.693, 16.4309, 52.1966, 125.3595, 19.1461, 28.262, 48.1696, 37.9862, 22.3287, 132.0509, 90.0965, 45.6388, 90.0296, 99.4281, 67.5257, 74.0211, 25.9221, 69.0821, 7.5901, 113.941, 2.2477, 128.9251, 62.306, 41.972, 54.6476, 109.754, 130.521, 48.7249, 64.5621, 52.0676, 96.0465, 127.3296, 76.4996, 47.1216, 68.3857, 78.5902, 122.4588, 6.093, 116.5394, 108.5708, 123.2381, 46.0388, 52.1002, 139.6491, 84.9835, 80.9536, 132.9418, 136.0637, 15.2863, 96.7021, 1.6628, 62.6455, 66.3645, 28.279, 70.8895, 133.737, 53.9379, 19.8363, 92.2345, 41.0169, 66.1848, 74.4137, 121.4547, 95.1806, 114.8401, 59.1972, 37.0034, 140.056, 56.3012, 30.1969, 58.3482, 47.0706, 0.0422, 43.1776, 91.9378, 73.8835, 128.336, 133.7344, 50.4677, 104.259, 84.5108, 21.5733, 124.1335, 98.0074, 29.0931, 14.1374, 135.2877, 123.1124, 21.033, 117.5218, 133.6752, 114.5044, 39.7651, 110.3846, 114.6369, 73.8956, 1.2837, 128.4186, 100.9095, 44.065, 133.1283, 99.0537, 139.6065, 27.9081, 4.4866, 116.0558, 109.9603, 119.9665, 109.6799, 31.4148, 112.0303, 24.465, 125.1427, 15.7175, 100.5176, 92.7522, 17.4171, 82.486, 34.2988, 102.7512, 72.82, 137.9549, 110.2823, 121.0267, 95.6518, 29.0208, 60.6187, 76.5587, 126.2841, 110.2265, 46.3756, 72.9612, 40.4401, 10.7038, 125.5234, 95.1849, 120.5762, 65.9318, 22.4425, 141.0323, 73.2608, 11.4725, 7.899, 97.4458, 137.2041, 108.5093, 40.9729, 7.211, 36.5557, 114.0308, 122.4816, 36.6516, 99.1288, 96.8199, 16.1354, 86.6349, 141.6766, 75.7691, 72.5186, 21.3146, 64.5686, 60.8453, 93.1538, 125.0139, 129.8895, 63.3229, 113.149, 88.742, 95.6363, 8.3014, 62.8233, 17.7802, 138.4169, 12.1538, 59.9297, 14.2806, 40.3246, 142.6149, 41.8589, 46.6256, 120.9519, 138.7445, 20.7057, 109.3374, 2.858, 85.8506, 95.0966, 2.5061, 44.903, 108.3024, 50.7516, 54.429, 103.8962, 28.9677, 132.8411, 1.3364, 55.7062, 93.6641, 91.4933, 52.1655, 83.8186, 98.1462, 71.5726, 44.8549, 43.9396, 108.5921, 8.4746, 8.0334, 133.9646, 71.9619, 135.9782, 44.1919, 16.4455, 71.7729, 26.278, 115.5413, 137.8468, 108.9354, 38.0929, 21.8792, 103.6578, 139.7311, 51.4237, 94.1302, 142.0348, 125.1882, 76.5285, 85.7843, 6.3195, 133.0324, 113.9966, 76.6335, 83.0689, 97.9247, 61.6322, 0.0049, 136.5277, 63.072, 64.0153, 36.7802, 127.8906, 110.7508, 31.6759, 31.6418, 129.1765, 112.2563, 40.366, 54.8172, 50.2486, 97.6868, 29.8497, 23.5858, 94.8529, 106.2066, 111.714, 31.0393, 39.4013, 53.4329, 60.4811, 35.7327, 15.7237, 108.8871, 116.6434, 104.4673, 76.7121, 44.9774, 64.6177, 126.5554, 43.4944, 85.9555, 92.1363, 52.8774, 33.5378, 87.4239, 51.1814, 56.4278, 56.3254, 62.511, 29.7436, 24.8926, 124.3041, 39.7064, 31.8345, 100.5155, 89.9352, 116.2694, 109.2041, 111.0693, 28.0207, 11.8349, 63.0951, 94.8801, 142.5013, 33.102, 77.3823, 82.0657, 44.9766, 63.5358, 111.5764, 133.4124, 49.4483, 29.6729, 73.5378, 95.5128, 129.618, 129.8712, 38.9291, 137.8233, 77.4786, 67.7556, 95.0867, 132.4367, 33.2848, 35.4323, 43.4666, 48.783, 142.3568, 126.3301, 28.4711, 41.412, 21.7436, 65.4447, 86.93, 106.6463, 126.9406, 129.0041, 24.7453, 70.4136, 70.029, 128.4738, 31.545, 142.9559, 68.3336, 8.8587, 92.1754, 105.1761, 22.3079, 104.2277, 42.6637, 120.6409, 9.2847, 89.1729, 99.2273, 85.4698, 15.3026, 118.4626, 103.072, 72.1859, 5.8835, 122.6846, 21.7287, 45.603, 42.1606, 20.5974, 107.8068, 103.869, 135.7089, 113.5573, 61.9173, 94.8847, 5.5077, 49.7086, 91.4833, 38.7132, 135.5583, 55.3596, 59.6774, 106.4067, 92.933, 116.033, 79.3812, 34.7398, 119.7333, 84.2459, 96.8789, 95.0325, 59.9494, 40.532, 133.571, 118.3221, 58.347, 45.5191, 73.1687, 31.5799, 46.4622, 45.6071, 47.5701, 95.4315, 20.7951, 85.7801, 0.7059, 71.5903, 68.4934, 79.4472, 122.9453, 84.0086, 65.9333, 24.443, 95.7477, 14.0983, 82.989, 134.3423, 4.2292, 58.124, 33.5783, 141.5189, 8.0384, 140.7418, 114.3743, 8.9824, 114.4458, 104.6183, 135.563, 61.6673, 46.9349, 105.0691, 22.3696, 43.4979, 90.7526, 63.9061, 33.9636, 84.0744, 10.7151, 140.67, 18.2484, 48.6579, 118.188, 22.2569, 35.9659, 41.1578, 111.3385, 101.6095, 121.0407, 114.3299, 92.8199, 108.0314, 117.892, 55.9604, 3.9468, 110.0361, 78.1394, 92.2693, 87.6203, 27.5216, 60.4001, 70.5989, 31.4472, 12.148, 52.1523, 66.1407, 15.3787, 76.9825, 120.1788, 107.2907, 129.6734, 60.7312, 83.805, 80.0193, 28.899, 40.9816, 18.9486, 50.6357, 42.6102, 49.0518, 72.1953, 18.4989, 97.1997, 94.3984, 71.118, 9.5825, 57.8578, 107.21, 21.7079, 17.6982, 28.7163, 82.9521, 84.8606, 59.8264, 19.2414, 12.5638, 35.473, 97.9903, 6.1691, 74.998, 43.739, 126.7402, 4.2593, 98.4401, 34.9296, 87.2142, 57.2042, 92.2293, 34.0356, 37.1644, 68.9151, 70.6066, 41.6334, 31.4594, 28.4581, 24.1016, 68.7423, 125.9476, 89.8349, 125.3945, 66.0965, 99.4407, 84.4687, 108.432, 80.7791, 42.6138, 53.8081, 132.5998, 108.1805, 30.8492, 71.5326, 134.5714, 24.2741, 13.0542, 118.5531, 80.9845, 30.9161, 17.8658, 109.7563, 133.6442, 73.0247, 125.3387, 134.6037, 67.4072, 134.1177, 133.5074, 33.1989, 63.7662, 133.3156, 63.1255, 135.6657, 55.7675, 32.322, 36.4976, 36.2361, 116.1143, 44.8825, 80.8671, 17.1376, 138.2766, 110.8934, 79.1566, 20.7576, 35.5227, 21.277, 14.2092, 88.1123, 112.7655, 5.4165, 70.8367, 63.0869, 83.8978, 60.8509, 100.6251, 93.2621, 126.6058, 110.8172, 120.4122, 132.9901, 57.4111, 82.6342, 89.3528, 53.3988, 14.8372, 68.7785, 31.1074, 130.5259, 55.3591, 59.0446, 119.2696, 36.7664, 109.4574, 20.2496, 72.2074, 34.6661, 21.2395, 107.3756, 99.9309, 24.023, 106.8338, 91.3391, 132.2679, 93.8517, 55.9326, 110.0755, 130.928, 20.2467, 68.3289, 2.6327, 70.909, 16.5239, 33.3956, 40.3514, 35.2818, 128.6314, 99.1327, 102.1478, 124.9783, 82.2042, 87.0478, 121.0576, 136.9069, 140.6614, 6.7558, 0.4668, 38.2767, 124.5981, 3.2879, 88.1148, 116.0521, 104.9386, 134.2757, 58.3859, 97.4708, 27.4009, 42.1715, 35.1725, 125.6719, 7.4072, 12.4673, 49.579, 61.2721, 91.2333, 134.0442, 35.2177, 42.9367, 56.0931, 38.1997, 21.5522, 95.8612, 22.7327, 99.5309, 61.9116, 87.3318, 71.2888, 94.9706, 120.4138, 135.0723, 121.3577, 108.6946, 2.3706, 6.8123, 76.1182, 109.9348, 85.9377, 68.2732, 71.3644, 52.7965, 68.4449, 14.5127, 64.4317, 20.9583, 17.5582, 128.007, 123.325, 18.95, 52.4321, 10.6971, 116.562, 138.7619, 43.9767, 15.0787, 105.3377, 95.2439, 56.3354, 75.9021, 107.2411, 63.31, 95.9611, 13.0972, 32.8784, 64.6861, 74.7667, 20.6933, 92.8231, 112.2161, 129.8376, 137.1579, 46.7185, 101.9671, 26.5258, 17.2912, 57.2761, 45.1968, 71.6186, 106.4211, 112.2643, 51.0421, 13.3359, 65.7633, 83.3972, 107.436, 37.4864, 69.9957, 83.8709, 24.944, 49.8158, 91.687, 24.7701, 103.6872, 35.7662, 60.4491, 136.105, 70.5041, 47.819, 141.9116, 103.6118, 78.2261, 65.0172, 88.0544, 35.2565, 94.8883, 10.3253, 48.7913, 10.2625, 108.0309, 117.2388, 41.5308, 37.4001, 97.6969, 43.3632, 53.7847, 101.3063, 1.9304, 134.0705, 70.308, 72.0096, 56.4479, 83.1688, 88.2892, 62.8952, 113.9877, 64.753, 21.0591, 9.168, 76.2314, 118.0384, 108.6465, 81.2885, 8.0112, 104.3655, 83.7347, 129.1748, 109.868, 139.7473, 73.1026, 86.2878, 106.9346, 82.9488, 80.4922, 88.5856, 29.702, 112.527, 116.0166, 57.4166, 89.9626, 9.6711, 33.1574, 8.1606, 17.7309, 72.523, 27.1936, 51.2971, 67.9609, 83.2462, 48.5851, 20.7965, 87.6581, 78.0444, 108.3758, 5.5972, 26.1105, 34.7054, 73.7628, 110.0666, 119.0475, 26.1524, 90.7805, 101.2623, 86.2782, 94.1763, 60.4835, 38.9172, 121.9418, 30.7339, 60.6119, 67.4749, 81.3491, 89.0313, 52.9918, 43.3153, 132.9272, 116.4262, 32.4291, 36.6196, 56.2814, 3.6801, 39.795, 7.1341, 76.811, 34.0355, 37.0011, 136.9124, 4.7089, 126.9556, 5.9323, 44.7873, 96.8306, 30.4451, 103.8688, 135.5251, 11.0221, 121.6028, 6.8313, 101.5327, 18.2805, 91.5869, 34.079, 95.1992, 139.7238, 41.6458, 48.0349, 1.0387, 87.0418, 113.0148, 52.3252, 10.9425, 15.107, 143.2246, 141.3712, 96.9388, 31.9552, 118.8054, 131.9554, 105.5906, 3.8118, 72.7823, 87.6159, 21.6018, 19.0459, 37.4688, 46.3776, 75.6966, 118.8163, 3.2905, 91.4626, 11.0329, 136.0349, 120.0066, 20.0859, 139.6127, 36.2571, 1.0649, 122.1934, 80.7659, 24.9971, 120.8947, 62.2562, 118.5424, 66.6135, 74.9836, 24.3873, 21.1782, 25.3348, 142.9397, 46.6343, 132.6282, 2.9908, 120.2465, 54.5221, 85.1973, 80.5241, 131.2901, 74.912, 71.9301, 93.3554, 108.1926, 47.0573, 125.5023}
m_cnt=1
function mrng(high)
  m_cnt+=1
  mrnd=seeds[m_cnt]
  return mrnd*high/mrng_m
end
globals={
	init=function(this) 
		globals.save(this)
		this.spr=0
	end,
	save=function(this) 
		this.maddy_intro=maddy_intro
		this.hp=hp 
		this.mrng_a=mrng_a 
		this.mrng_b=mrng_b
		this.mrng_m=mrng_m
		this.mrnd=mrnd
		this.maddy_spawned=maddy_spawned
		this.m_cnt=m_cnt
	end,
	load=function (this) 
		maddy_intro=this.maddy_intro
		hp=this.hp 
	    mrng_a=this.mrng_a 
	    mrng_b=this.mrng_b
	    mrng_m=this.mrng_m
		mrnd=this.mrnd
		maddy_spawned=this.maddy_spawned
		m_cnt=this.m_cnt
	end
}
function get_globals() 
	for i in all(objects) do 
		if(i.type==globals) then 
			return i  
		end 
	end 
end 
maddy = {
  tile=10,
  init=function(this)
    this.spr=10
    this.target={x=this.x,y=this.y}
    this.dash_target={x=this.x,y=this.y}
    this.dash_accel={x=0,y=0}
    this.y=128
    this.spd.y=-4
    this.state=0
    this.delay=0
    this.solids=false
    this.flip.x=true
    this.dir=-1
    this.djump=maddy_intro and 1 or 2
    this.dash_time=0
    this.hair={}
    for i=0,4 do
      add(this.hair,{x=this.x,y=this.y,size=max(1,min(2,3-i))})
    end
    this.was_on_ground=false
    this.p=nil
    this.draw_hp=0
  end,
  update=function(this)
    local on_ground=this.is_solid(0,1)
    local gravity=abs(this.spd.y)<=0.15 and 0.105 or 0.21
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
        this.spd={x=0,y=0}
        init_object(smoke,this.x,this.y+4)
        sfx(5)
        this.state=2
      end
    -- landing
    elseif this.state==2 then
      this.spr=9
      this.solids=true
      if not maddy_intro then
        this.delay=30-(20-hp)
        this.state=4
      end
    -- grabbing orb
    elseif this.state==3 then
      if on_ground then
        psfx(1)
        this.spd.y=-2
        init_object(smoke,this.x,this.y+4)
      else
        this.spd.y=appr(this.spd.y,2,gravity)
      end
    -- loading healthbar
    elseif this.state==4 then
      this.spd.y=appr(this.spd.y,2,gravity)
      this.delay-=1
      this.draw_hp=min(this.draw_hp+1,hp)
      psfx(9)
      if this.delay==0 then
        this.target.x=120
        this.state=5
        pause_player=false
      end
    elseif this.state==5 then
      -- kill player
      local hit=this.collide(player,0,0)
      if hit~=nil then
        kill_player(hit)
      end
      -- lemon
      local hit = this.collide(lemon,0,0)
      if hit~=nil then
        explode(this,3)
        destroy_object(hit)
        hp-=2
      end
      -- death
      if hp==0 then
        sfx(0)
        explode(this,15)
        destroy_object(hit)
        init_object(capsule_top,64,88)
        init_object(capsule_bottom,64,88+24)
        destroy_object(this)
      end
      -- decision making
      local jump=true
      local dash=false
      local h_input=sign(this.target.x-this.x)
      local v_input=0
      this.p=get_player()
      if mrng(1.0)<0.05 then
        dash=true
        if mrng(1.0)<0.75 then
          v_input=mrng(1.0)<0.5 and -1 or 0
        else
          v_input=1
          h_input=0
        end
      end
      if abs(this.target.x-this.x)<4 then
        this.target.x=this.target.x==120 and 0 or 120
      end
      -- landing smoke
      if on_ground and not this.was_on_ground then
        init_object(smoke,this.x,this.y+4)
      end
      -- keep dashing
      if this.dash_time>0 then
        init_object(smoke,this.x,this.y)
        this.dash_time-=1
        this.spd.x=appr(this.spd.x,this.dash_target.x,this.dash_accel.x)
        this.spd.y=appr(this.spd.y,this.dash_target.y,this.dash_accel.y)
      else 
        -- move
        if abs(this.spd.x)>1 then
          this.spd.x=appr(this.spd.x,sign(this.spd.x),0.15)
        else
          this.spd.x=appr(this.spd.x,on_ground and 0 or h_input,on_ground and 0.6 or 0.4)
        end
        -- facing
        if (this.spd.x!=0) then
          this.flip.x=(this.spd.x<0)
          this.dir=this.flip.x and -1 or 1
        end
        -- gravity
        if not on_ground then
          this.spd.y=appr(this.spd.y,2,gravity)
        else
        -- reset dashes
          if this.djump<2 then
            psfx(16)
            this.djump=2
          end
        end
        -- jump
        if on_ground and jump then
          psfx(1)
          this.spd.y=-2
          init_object(smoke,this.x,this.y+4)
        end
        -- dashing
        if this.djump>0 and dash then
          local d_full=5
          local d_half=d_full*0.70710678118
          init_object(smoke,this.x,this.y)
          this.djump-=1   
          this.dash_time=4
          if (h_input!=0) then
            if (v_input!=0) then
              this.spd.x=h_input*d_half
              this.spd.y=v_input*d_half
            else
              this.spd.x=h_input*d_full
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
          --freeze=2
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
        end
      end
      -- was on ground
      this.was_on_ground=on_ground
      -- sprites
      this.spr=on_ground and 9 or 10
    end
  end,
  draw=function(this)
    -- draw hp bar
    if this.state<6 then
      if this.state>=4 then
        rectfill(128-4-2-6-1,4-1,128-4-2+1,4+2*19+1,0)
        for i=0,(this.state==4 and this.draw_hp or hp)-1 do
          rectfill(128-4-2-6,4+2*19-i*2,128-4-2,4+2*19-i*2, 10)
          rectfill(128-4-2-5,4+2*19-i*2,128-4-3,4+2*19-i*2, 7)
        end
      end
      -- clamp in screen
      if this.x<-1 or this.x>121 then 
        this.x=clamp(this.x,-1,121)
        this.spd.x=0
      end
      -- draw hair
      pal(8,(this.djump==1 and 8 or this.djump==2 and (7+flr((frames/3)%2)*4) or 12))
      local last={x=this.x+4-this.dir*2,y=this.y+3}
      foreach(this.hair,function(h)
        h.x+=(last.x-h.x)/1.5
        h.y+=(last.y+0.5-h.y)/1.5
        circfill(h.x,h.y,h.size,8)
        last=h
      end)
      -- draw maddy
      spr(this.spr,this.x,this.y,1,1,this.flip.x,this.flip.y) 
      -- unset hair  
      pal(8,8)
    end
  end,
}

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
        hit.djumps=0
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
  psfx(11)
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
  tile=45,
  if_not_fruit=true,
  init=function(this) 
    this.start=this.y
    this.off=0
  end,
  update=function(this)
   local hit=this.collide(player,0,0)
    if hit~=nil then
      --hit.djump=max_djump
      sfx_timer=20
      sfx(10)
      got_fruit[1+level_index()] = true
      init_object(lifeup,this.x,this.y)
      destroy_object(this)
    end
    this.off+=1
    this.y=this.start+sin(this.off/40)*2.5
    local was=flr(this.spr)
    this.spr=46+(sin(frames/30)+0.5)*1
    local is=flr(this.spr)
    if (is==47 and (is!=was)) or (is==45 and (is!=was)) then
      this.flip.x=not this.flip.x
    end
  end
}
add(types,fruit)

lemon={
  tile=8,
  init=function(this) 
    this.timer=20
    this.ang=0
    this.hitbox={x=2,y=4,w=4,h=3}
  end,
  update=function(this)
    if not this.good then
      local hit=this.collide(player,0,0)
      if hit~=nil then
        kill_player(hit)
      end
    end
    this.timer-=1
    if this.timer==0 or this.is_solid(0, 0) then
      destroy_object(this)
    end
    this.x+=cos(this.ang)*this.dir*3
    this.y+=sin(this.ang)*3
  end
}

copter={
  tile=28,
  init=function(this) 
    this.dir=-1
    this.f0=frames
    this.hitbox={x=0,y=4,w=8,h=4}
    this.x_track=this.x
    this.y_track=this.y
  end,
  update=function(this)
    -- touch player
    local hit=this.collide(player,0,0)
    if hit~=nil then
      kill_player(hit)
    end
    -- touch lemon
    local hit = this.collide(lemon,0,0)
    if hit~=nil and hit.good then
      sfx(0)
      explode(this,5)
      destroy_object(this)
      destroy_object(hit)
    end
    local p=get_player()
    if p~=nil then
      this.x_track=appr(this.x_track,p.x,0.4)
      this.y_track=appr(this.y_track,p.y,0.4)
    end
    this.x=this.x_track+4*sin((frames - this.f0)/30)
    this.y=this.y+0.1*(this.y_track-this.y)
  end,
  draw=function(this)
    spr(28,this.x,this.y,1,1,flr(frames/2)%2==0,false)
  end
}
add(types,copter)

met={
  tile=13,
  init=function(this) 
    this.dir=-1
    this.timer=0
    this.state=0
    this.hitbox={x=0,y=4,w=8,h=4}
  end,
  update=function(this)
    -- touch player
    local hit=this.collide(player,0,0)
    if hit~=nil then
      kill_player(hit)
    end
    -- touch lemon
    local hit = this.collide(lemon,0,0)
    if hit~=nil and hit.good then
      if this.state==0 then
        sfx(9)
      else
        sfx(0)
        explode(this,5)
        destroy_object(this)
      end
      destroy_object(hit)
    end
    -- mechanics
    if this.state==0 then
      if this.timer>0 then
        this.timer-=1
      else
        local p=get_player()
        if p~=nil then
          if abs(p.x-this.x) + abs(p.y-this.y)<=60 and p.y-this.y<=8 then
            this.dir=p.x>this.x and 1 or (p.x<this.x and -1 or this.dir)
            this.state=1
            this.timer=30
          end
        end
      end
    else
      if this.timer==25 then
        sfx(6)
        for i=0,2 do
          local lemon=init_object(lemon,this.x+this.dir*3,this.y)
          lemon.dir=this.dir
          lemon.ang=i*0.0625
          lemon.good=false
        end
      end
      this.timer-=1
      if this.timer==0 then
        this.state=0
        this.timer=20
      end
    end
  end,
  draw=function(this)
    spr(this.state==0 and 13 or 14,this.x,this.y,1,1,this.dir==1,false)
  end
}
add(types,met)

chest={
  tile=20,
  init=function(this) 
    this.dir=-1
    this.timer=0
    this.state=0
    this.hitbox={x=1,y=3,w=6,h=5}
  end,
  update=function(this)
    this.spd.y=appr(this.spd.y,2,0.21)
    if this.y>128 then
      sfx(0)
      explode(this,5)
      destroy_object(this)
    end
    -- touch player
    local hit=this.collide(player,0,0)
    if hit~=nil then
      kill_player(hit)
    end
    -- touch lemon
    local hit = this.collide(lemon,0,0)
    if hit~=nil and hit.good then
      if this.state==1 and this.timer<=20 then
        sfx(0)
        explode(this,5)
        destroy_object(this)
      else
        sfx(9)
      end
      destroy_object(hit)
    end
    -- mechanics
    if this.state==0 then
      if this.timer>0 then
        this.timer-=1
      else
        local p=get_player()
        if p~=nil then
          if abs(p.x-this.x) <= 60 and abs(p.y-this.y) <= 4 then
            this.dir=p.x>this.x and 1 or (p.x<this.x and -1 or this.dir)
            if this.is_solid(0,1) and not this.is_solid(0,-8) and this.offset%2==0 then
              this.spd.y=-1.5
            end
            this.state=1
            this.timer=30
          end
        end
      end
    else
      if this.timer==20 then
        sfx(6)
        local lemon=init_object(lemon,this.x+this.dir*3,this.y)
        lemon.dir=this.dir
        lemon.good=false
      end
      this.timer-=1
      if this.timer==0 then
        this.state=0
        this.timer=30
      end
    end
  end,
  draw=function(this)
    spr(((this.state==1 and this.timer<=20) and 21 or 20),this.x,this.y,1,1,this.dir==-1,false)
  end
}
add(types,chest)

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
    this.text="-- celeste mountain --#this memorial to those#  who are memorable   "
    if this.check(player,4,0) then
      if this.index<#this.text then
       this.index+=0.5
        if this.index>=this.last+1 then
         this.last+=1
         sfx(12)
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
    this.state=maddy_intro and 0 or 2
    this.hitbox.w=16
	if not maddy_spawned then 
		init_object(maddy,this.x+4,this.y+8)
		maddy_spawned=true
	end 
  end,
  draw=function(this)
    if this.state==0 then
      local hit=this.collide(maddy,0,8)
      if hit~=nil and hit.state==2 and hit.is_solid(0,1) then
        music(-1,500,7)
        sfx(13)
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
        this.collide(maddy,0,8).state=3
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

capsule_top={
  init=function(this)
    this.state=0
    this.hitbox.w=16
    this.timer=32
  end,
  draw=function(this)
    if this.state==0 and update then
      this.y-=1
      this.timer-=1
      local hit=this.collide(player,0,-1)
      if hit~=nil then
        hit.y-=1
      end
      if this.timer==0 then
        this.state=1
      end
    else
    end
    spr(64,this.x,this.y)
    spr(65,this.x+8,this.y)
  end
}
add(types,capsule_top)

capsule_bottom={
  init=function(this)
    this.state=0
    this.hitbox.w=16
    this.timer=32
    music(17,500,0)
  end,
  draw=function(this)
    local p=get_player()
	if not update then 
    elseif this.state<2 then
      -- rising
      if this.state==0 then
        init_object(smoke,64,88)
        init_object(smoke,64+8,88)
        if frames%2==0 then
          sfx(11)
        end
        this.y-=1
        this.timer-=1
        local hit=this.collide(player,0,-1)
        if hit~=nil then
          hit.y-=1
        end
        if this.timer==0 then
          this.state=1
        end
      -- wait for player to enter
      else
        local hit=this.collide(player,0,-1)
        if hit~=nil then
          pause_player=true
          p.dir=1
          p.flip.x=false
          hit.spd.x=0
          hit.spd.y=0
          this.state=2
        end
      end
    -- suck player in
    elseif this.state==2 then
      if p.x~=68 then
        p.x=appr(p.x,68,1)
      else
        flash_bg=true
        this.state=3
        this.timer=60
        music(-1,1000,7)
        sfx(13)
      end
    -- effects
    elseif this.state==3 then
      this.timer-=1
      if this.timer==0 then
        this.state=4
        this.timer=30
        sfx(15)
        flash_bg=false
        max_djumps=1
		max_djump=2
        p.spr=22
      end
      for i=0,15 do
        if rnd(1.0)<(this.timer<=3 and 1.0 or 0.2) then
          line(this.x+i,this.y,this.x+i,this.y-16,7)
        end
      end
    elseif this.state==4 then
      this.timer-=1
      if this.timer==0 then
        this.state=5
        this.timer=35
        music_timer=35
        p.spr=1
      end
    elseif this.state==5 then
      this.timer-=1
      p.spd.y=appr(p.spd.y,2,0.21)
      if this.timer>=25 then
        p.spd.x=1
        --p.move_x(1,0)
      elseif this.timer==24 then
        psfx(1)
        p.spr=3
        p.spd.x=0
        p.spd.y=-2
      elseif this.timer==7 then
        psfx(1)
        p.djumps=1
        p.spd.y=-1.8
      elseif this.timer==0 then
        this.state=6
        pause_player=false
      end
    end
    spr(80,this.x,this.y)
    spr(81,this.x+8,this.y)
    line(this.x,this.y,this.x,this.y-16,6)
    line(this.x+15,this.y,this.x+15,this.y-16,6)
  end
}
add(types,capsule_bottom)

orb={
  init=function(this)
    this.spd.y=-4
    this.solids=false
    this.particles={}
  end,
  draw=function(this)
    this.spd.y=appr(this.spd.y,0,0.5)
    local hit=this.collide(maddy,0,0)
    if this.spd.y==0 and hit~=nil then
      sfx(15)
      freeze=10
      shake=10
      destroy_object(this)
      hit.djump=2
      hit.state=4
      hit.delay=30
      maddy_intro=false
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
    spr(this.spr,this.x+3,this.y)
    if this.show then
      rectfill(32,2,96,32,0)
      spr(45,49,6)
      print(":"..this.score.."/10",58,9,7)
      --print("x"..this.score.."/10",64,9,7)
      draw_time(42,16)
      print("deaths:"..deaths,48,25,7)
    elseif this.check(player,0,0) then
      sfx(17)
    sfx_timer=30
      this.show=true
    end
  end
}
add(types,flag)

yadelie = {
  tile=103,
  init=function(this)
    this.timer=0
    this.h=this.y
  end,
  update=function(this)
    if this.h==this.y and rnd(1)<0.05 then
      this.timer=2
      this.y=this.h-1
    end
    this.timer-=1
    if this.timer==0 then
      this.y=this.h
    end
  end,
}
add(types,yadelie)

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
      elseif level_index()==30 then
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
     or obj.check(capsule_top,ox,oy)
     or obj.check(capsule_bottom,ox,oy)
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
  explode(obj,10)
  restart_room()
end

function explode(obj,duration)
  dead_particles={}
  for dir=0,7 do
    local ang=(dir/8)
    add(dead_particles,{
      x=obj.x+4,
      y=obj.y+4,
      t=duration,
      spd={
        x=sin(ang)*3,
        y=cos(ang)*3
      }
    })
  end
end

function get_player()
  for i=1,count(objects) do
    if objects[i].type==player then
      return objects[i]
    end
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
  music(2,500,7)
 elseif room.x==3 and room.y==1 then
  music(6,100,0)
 elseif room.x==4 and room.y==2 then
  music(2,500,7)
 elseif room.x==5 and room.y==3 then
  music(2,500,7)
 end
  if room.x==7 then
    load_room(0,room.y+1)
  else
    load_room(room.x+1,room.y)
  end
end

function load_room(x,y)
  --remove existing objects
  foreach(objects,destroy_object)

  --current room
  room.x = x
  room.y = y 
  
  
  if level_index()==21 then 
	maddy_intro=true
	hp=20
	mrng_a=1337.8008
	mrng_b=8008.1337
	mrng_m=143.24
	mrnd=144.4667861009766
	maddy_spawned=false
	m_cnt=1
  end
  
  -- init globals object 
  init_object(globals,0,0)
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
  if level_index() < 30 then
    centiseconds=flr(100*frames/30)
  end
  if frames==0 and level_index()<30 then
    seconds=((seconds+1)%60)
    if seconds==0 then
      minutes+=1
    end
  end
  
  if music_timer>0 then
   music_timer-=1
   if music_timer<=0 then
    music(6,0,0)
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
  -- load globals 
  globals.load(get_globals())
  
  -- hack to fix off by 1 with max_djump compared to vanilla 
  max_djumps=max_djump-1
  
  -- update each object
  foreach(objects,function(obj)
    obj.move(obj.spd.x,obj.spd.y)
    if obj.type.update~=nil then
      obj.type.update(obj) 
    end
  end)
  -- save globals 
  globals.save(get_globals())
  
  -- start game
  if is_title() then
    if not start_game and (btn(k_jump) or btn(k_shoot)) then
      music(-1)
      start_game_flash=50
      start_game=true
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
      pal(6,c)
      pal(12,c)
      pal(13,c)
      pal(5,c)
      pal(1,c)
      pal(7,c)
      pal(10,c)
      pal(9,c)
      pal(4,c)
    end
  end

  -- clear screen
  local bg_col = 0
  if flash_bg then
    bg_col = frames/5
  end
  rectfill(0,0,128,128,bg_col)

  -- clouds
  if not is_title() then
    foreach(clouds, function(c)
      c.x += c.spd
      rectfill(c.x,c.y,c.x+c.w,c.y+4+(1-c.w/64)*12,1)--new_bg~=nil and 14 or 1)
      if c.x > 128 then
        c.x = -c.w
        c.y=rnd(128-8)
      end
    end)
  end

  -- draw bg terrain
  map(room.x*16,room.y*16,0,0,16,16,4)

  -- platforms/big chest
  foreach(objects, function(o)
    if o.type==platform or o.type==big_chest or o.type==capsule_top or o.type==capsule_bottom then
      draw_object(o)
    end
  end)

  -- draw terrain
  map(room.x*16,room.y * 16,is_title() and -4 or 0,0,16,16,2)
  
  -- draw objects
  foreach(objects, function(o)
    if o.type~=platform and o.type~=big_chest and o.type~=capsule_top and o.type~=capsule_bottom then
      draw_object(o)
    end
  end)
  
  -- draw fg terrain
  map(room.x*16,room.y*16,0,0,16,16,8)
  
  -- particles
  foreach(particles, function(p)
    p.x+=p.spd
    p.y+=sin(p.off)
    p.off+=min(0.05,p.spd/32)
    rectfill(p.x,p.y,p.x+p.s,p.y+p.s,p.c)
    if p.x>128+4 then 
      p.x=-4
      p.y=rnd(128)
    end
  end)
  
  -- dead particles
  foreach(dead_particles, function(p)
    p.x+=p.spd.x
    p.y+=p.spd.y
    p.t-=1
    if p.t<=0 then del(dead_particles,p) end
    rectfill(p.x-p.t/5,p.y-p.t/5,p.x+p.t/5,p.y+p.t/5,14+p.t%2)
  end)
  
  -- draw outside of the screen for screenshake
  rectfill(-5,-5,-1,133,0)
  rectfill(-5,-5,133,-1,0)
  rectfill(-5,128,133,133,0)
  rectfill(128,-5,133,133,0)
  
  -- credits
  if is_title() then
    --print("z+x",58,80,5)
    --print("matt thorson",42,96,5)
    --print("noel berry",46,102,5)
    print("a mod of celeste",34,80,5)
    print("by matt thorson",36,86,5)
    print("and noel berry",38,92,5)
    print("kris de asis",42,108,5)
  end
  
  -- summit blinds effect
  if level_index()==30 then
    local p=get_player()
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

  local cs=centiseconds
  local s=seconds
  local m=minutes%60
  local h=flr(minutes/60)
  
  rectfill(x,y,x+44,y+6,0)
  print((h<10 and "0"..h or h)..":"..(m<10 and "0"..m or m)..":"..(s<10 and "0"..s or s).."."..(cs<10 and "0"..cs or cs),x+1,y+1,7)

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
000000000001cc000001cc000001cc000001cc00000cc10000000000000ccc000000000000000000088888800007707770077700000000000000000000060000
0000000000191cc000191cc000191cc000191cc000cc19100001cc000019c8800000000008888880888888880777777677777770000000000000000000060000
000000000c11c8810c11c8810c11c8810c11c8810188c11c00191cc00c1c1f1c0000000088888888888ffff877666666677677770000000000aaa00000060000
000000000c1c1f1c0c1c1f1c0c1c1f1c0c1c1f1c0c1f1c1c0c11c8810c1ffff100000000888ffff888f1ff1876777666766666770000000093aaaa0000060000
00000000001ffff0001ffff0701ffff7001ffff000ffff100c1c1f1c001fff100007700088f1ff1808fffff0000000000000000000aaaa0009911aa000006000
0000000001dd1d1771dd1d1701dd1d1071dd1d17001d1dd7071ffff001dd1d17009aa90008fffff00033330000000000000000000aaaaaa00119911000006000
00000000705cc500005cc110005cc511011cc5000705cc51005cc500705cc5000009900000333300070000700000000000000000013a11101717199000006000
00000000011001100110000001100000000001100000110111001170011001100000000000700700000000000000000000000000999999991111111900006000
0101010100000000000000000000000000b3b05b00b3b000001cc1004999999449999994499909940300b0b06665666500000000000000000000000070000000
101010100000000000000000000000000bbb3b57bb5b3b00091cc190911111199111411991140919003b330067656765ddd22777007700000770070007000007
010000010000000000000000000000000bb1815d67518100c1c88c1c911111199111911949400419028888206770677000055000007770700777000000000000
100000100070007004999940000000000bbb3b57dd5b3b00c11ff17c911111199494041900000044089888800700070000211200077777700770000000000000
0100000100700070005005000000000000bb3b57675b3b0000ffff10911111199114094994000000088889800700070002888820077777700000700000000000
100000100776077600055000000000000511d1536751d17001dd1d10911111199111911991400499088988800000000008788780077777700000077000000000
01010101567656760050050000000000073b30506b5b3000075cc500911111199114111991404119028888200000000008888880070777000007077007000070
10101010566656660005500004999940011001103510011001100110499999944999999444004994002882000000000007677670000000007000000000000000
5777777557777777777777777777777577dddddddddddddddddddd775777777501010101010101010101010155000000077777700d1001d001d11d1000011000
77777777777777777777777777777777777dddddddddddddddddd777777777771010101010101010001010106670000077777777555115550555115000155100
777d77777777ddddd777777ddddd7777777dddddddddddddddddd77777777777010101010101010000010101677770007777777788e22e88088e228000888e00
77dddd77777dddddddd77dddddddd7777777dddddddddddddddd7777777dd777101010101010100000001010666000007777337788e22e88088e228000888e00
77dddd7777dddddddddddddddddddd777777dddddddddddddddd777777dddd77010101010101000000000101550000007777337788e22e88088e228000888e00
777dd77777dd77ddddddddddddd7dd77777dddddddddddddddddd77777dddd77101010101010000000000010667000007377333708e22e80088e228000888e00
7777777777dd77dddddddddddddddd77777dddddddddddddddddd77777d7dd77010101010100000000000001677770007333bb37001551000011510000155100
5777777577dddddddddddddddddddd7777dddddddddddddddddddd7777dddd77101010101000000000000000666000000333bb30000dd0000001d00000011000
77dddd7777dddddddddddddddddddd77577777777777777777777775777ddd770101010100000000000000010000066603333330000000000000000000000000
777ddd7777dddddddddddddddddddd77777777777777777777777777777dd7771010101010000000000000100007777603b333300000000000ee0ee000000000
777ddd7777dd7dddddddddddd77ddd777777ddd7777777777ddd7777777dd77701010001010000000000010100000766033333300000000000eeeee000000030
77ddd77777ddddddddddddddd77ddd77777ddddd7d7777ddddddd77777ddd777101000101010000000001010000000550333b33000000000000e8e00000000b0
77ddd777777dddddddd77dddddddd777777ddddddd7777d7ddddd77777dddd7701010101010100000001010100000666003333000000b00000eeeee000000b30
777dd7777777ddddd777777ddddd77777777ddd7777777777ddd777777dddd771000101010101000001010100007777600044000000b000000ee3ee003000b00
777dd777777777777777777777777777777777777777777777777777777dd7770101010101010100010101010000076600044000030b00300000b00000b0b300
77dddd77577777777777777777777775577777777777777777777775577777751010101010101010101010100000005500999900030330300000b00000303300
5111288888821115077777777777777777777770077777700000000000000000dddddddd00000000000000000000000000000000000000000000000000000000
1111111111111111700007770000777000007777700077770000000000000000d77ddddd00000000000000000000000000000000000000000000000000000000
155dddccccddd55170cc777cccc777ccccc7770770c777070000000000000000d77dd7dd00000000000000000000000000000000000000000000000000000000
155dddccccddd55170c777cccc777ccccc777c0770777c070000000000000000dddddddd00000000000000000000000000006000000049999990000004999999
5111111111111115707770000777000007770007777700070005dddddddd5000dddddddd00000000000000000000000000060600000004999900000000499990
155dddddddddd55177770000777000007770000777700007005dddddddddd500dd7ddddd00000000000000000000000000d00060000000499990000004999900
4dd9999999999dd47000000000000000000c000770000c0700dddddddddddd00ddddd7dd0000000000000000000000000d00000c000000499990000049999000
54444444444444457000000000000000000000077000000700d55555d5d55d00dddddddd000000000000000000000000d000000c00000004aaaa00004aaaa000
54444444444444457000000000000000000000077000000700dddddddddddd000000000000000000000000000000000c0000000c00060004aaaa0004aaaa0000
4dd9999999999dd47000000c000000000000000770cc000700d55d5555d55d00000000000000000000000000000000d000000000c060d0004aaaa04aaaa00000
111111111111111170000000000cc0000000000770cc000700dddddddddddd0000000000000000000000000000000c00000000000d000d004aaaa04aaaa00000
115dddccccddd51170c00000000cc00000000c0770000c0700ddd555d55ddd0000000000000000000000000000000c0000000000000000000000000000000000
65111d1111d111567000000000000000000000077000000700dddddddddddd000000000006666600666666006600c00066666600066666006666660066666600
6511d1cccc1d115670000000000000000000000770c0000700dddddddddddd00000000006666666066666660660c000066666660666666606666660066666660
115d1dccccd1d51170000000c0000000000000077000000700dd77ddd7777d000000000066000660660000006600000066000000660000000066000066000000
51111111111111157000000000000000000000077000c007077777777777777000000000dd000000dddd0000dd000000dddd0000ddddddd000dd0990dddd0000
000000000000000070000000000000000000000770000007007777000000000000000000dd000dd0dd000000dd0000d0dd000000000000d000dd0990dd000000
00aaaaaaaaaaaa00700000000000000000000007700c0007070000701011110100000000ddddddd0dddddd00ddddddd0dddddd00ddddddd000dd0990dddddd00
0a999999999999a0700000000000c00000000007700000077077000711717111000000000ddddd00ddddddd0ddddddd0ddddddd00ddddd0040dd0990ddddddd0
a99aaaaaaaaaa99a7000000cc0000000000000077000cc077077bb07119911110000000000000000000000000000000000000000000000004000049000000000
a9aaaaaaaaaaaa9a7000000cc0000000000c00077000cc07700bbb0701777110000000000000000000000c000000000000000000000000049999049999000000
a99999999999999a70c00000000000000000000770c00007700bbb070177711000000000000000000000c00000000000000000000000004aaaa0004aaaa00000
a99999999999999a700000000000000000000007700000070700007001777110000000000000000000cc000000000000000000000000004aaaa0004aaaa00000
a99999999999999a0777777777777777777777700777777000777700099d991100000000000000000c0000000000000000000000000004aaaa000004aaaa0000
aaaaaaaaaaaaaaaa0777777777777777777777700777777008277620082776200827762000000000c0000000000000000000000000004aaaa0000004aaaa0000
a49494a11a49494a700077700000777000007777700077770888778008887780088877800000000100000000000000000000000000004aaaa00000004aaaa000
a494a4a11a4a494a70c777ccccc777ccccc7770770c7770707888cc507888cc507888cc5000000c0000000000000000000000000000477770000000047777000
a49444aaaa44494a70777ccccc777ccccc777c0770777c07978f1f15978f1f15078f1f1500000100000000000000000000000000004777700000000004777700
a49999aaaa99994a77770000077700000777000777770007a98ffff0a98ffff0098ffff000000100000000000000000000000000047777770000000047777770
a49444999944494a77700000777000007770000777700c0792232327922323270223232700000100000000000000000000000000000000000000000000000000
a494a444444a494a7000000000000000000000077000000779577500795775007957750000000000000000000000000000000000000000000000000000000000
a49499999999494a0777777777777777777777700777777098800880088908800889988000010000000000000000000000000000000000000000000000000010
00000000000000008242525252528452339200001323232352232323232352230000000000000000b302000013232352526200a2828342525223232323232323
00000000000000a20182920013232352363636462535353545550000005525355284525262b20000000000004252525262828282425284525252845252525252
00000000000000008242845252525252b1000000b1b1b1b103b1b1b1b1b103b100000000000000111102000000a282425233000000a213233300009200008392
000000000000110000a2000000a28213000000002636363646550000005525355252528462b2a300000000004252845262828382132323232323232352528452
000000000000a2018213525252845252000000000000000073000000000073000000000000000043536300d00000011362b2000041000000000000000000a200
0000000000b302b2002100000000a282000000000000000000560000005626365252522333b28292000000024252525262019200829200000000a28213525252
0000000000000000a2824252525252840000710000000000b10000000000b1000000000000000000b34353639300000062273737373737373737374711000000
000000110000b1000002b20000000082000000000000000000000000000000005252338282828201b31222225252525262820000a20000410000008283425252
0000000000000093a382135252525252000000000000000000000000000000001100000000000000000000020182000052222222222222222222222232000000
0000b3020000000000b10000000000a2000000000000000093000000000000008462828282838282b3132323528452526292000000112434440000a282425284
00000000000000a2828382428452525200000000b372009300000072b20000007293a30000000000000000b1a282931252845252525252232323232333000012
000000b10000001100000000720000410000000093000000820000a3000000005262828201a200a2828292001323232362111111112435354500000012525252
000000000000000082828213232323238200c1a3b373a38293000073b2000000738283931100000000000011a382821323232323528462829200a20100000013
000000000000b302b2000000730000710000a300828200828282828293000000526283829200000000a200000000000052222222322636364600000042525252
00d20011f34111a3828201000000b1b18293a38293b18282110000b100000012b100a282721100000000b372828283b122222232132333000000009200000000
00100000000000b1000000000000000000938282828201920000a20182a300005262828293000000000000000000000052528452523282839200000042845252
0000001222223282838282930000000082828282828382b302b20000000000131100a382737200000000b373a2829200525284628382a2000000a20000000000
00021111111111111111111100000000828282a28382820000000000828282825262829200000000000000000000000052525252526201a20000000042525252
00000113235252225353536300000000828300a282828201b1930000000000b172828292b1039300000000b100a282125223526292000000000041a300000000
004353535353535353535353536300008282920082829200061600a3828382a28462000000000000000000000000000052845252526292000011110242525252
0000a28282132333b1b1b1b1000000009200000000a28282828293b37200000073820100110382a3000000000082821362101333000000210000718293210000
0002828382828202828282828272000083820000a282d3000717f38282920000526200000000000093000000000000005252525284620000b312223213528452
000000828392000000000000000000000000000000000082828282b303000000b1a28283720382019300b372a38292b162710000000000719300008382710000
00b1a282820182b1a28283a282730000828210000082122232122232820000a3233300000000000082920000000000002323232323330000b342525232135252
000000a28200000000110000a37200000010000000111111118283b3730000a300008282730392008283b373828300d262930000000000008200008282920000
0000009200a28200008200008282000037374712320213233342846257243434000000000000000082000000000000008382829200000000b342528452321323
00001000820000a3007200a2820300002222321111125353630182829200008300009200b1030000a28200b18282001262829200210000a38292008282000000
00000000008282a3d08293008292d00002111113331222222252525232253535000000f3100000a3820000a2010000008292000000009300b342525252522222
1232122232b200839303000083039300528452222262c000a28282820000a38210000000a3730000008293008292001362820000710000828300a38201000000
02a20000000000820200435363000200343434344442528452525252622535350000001263000083829300008200c1008210d3e300a38200b342525252845252
1333425262b20082820382820103820052525252846200000082829200008282320000008382930000a28201820000b162839300000000828200828282930000
0000718371007100a28201820000000035353535454252525252528462253535000000032444008282820000829300002222223201828393b342525252525252
525252525262b2b1b1b1132323526200845223232323232352522323233382825252525252525252525284522333b2822323232323526282820000b342525252
52845252525252848452525262838242528452522333828292425223232352520000000000000000000000000000000000000000000000000000000000000000
525252845262b2000000b1b1b142620023338200000000824233b2a282018283525252845252232323235262b1b10083921000a382426283920000b342232323
2323232323232323232323526201821352522333c100018200133383828242840000000000000000000000000000000000000000000000000000000000000000
525252525262b20000000000a242620082828392000011a273b200a382729200525252525233b1b1b1b11333000000825353536382426282000000000382a2a2
c1829200a2828382820182426200a2835262b1b10000831232b20000d2014252000000000000a300000000000000000000000000000000000000000000000000
528452232333b20000001100824262928201a2000000720092000000830300002323525262b200000000b3720000a371828283828242522232b2000073920000
000100110092a2829211a2133300a3825262b2000000a21333b20000008242520000000000000100009300000000000000000000000000000000000000000000
525262122232b200a30072b2a24262838292000000000300000000a3820300002232132333b200000000b303829300a2838292019242845262b200000200d200
00a2b302b2a30082b302b200110000825262b200000000b1b10000a283a2425200000000a30082000083000000000000000000000094a4b4c4d4e4f400000000
525262428462b200a28303b200426292830000000000030000000000a203e3005252222232b200000000b30392000000829200000042525262b2000000000000
000000b100a2828200b100b302b211a25262b20000000000000000009200428400000000820082000001009300000000000000000095a5b5c5d5e5f500000000
232333132362b221008203b200133300829300009300031111111111114222225252845262000000d000b30300000000821111111142528462b2000000000000
000000000000110100000000b1b3020084621111111100000000000000b0135200000000828382670082008200000000000000000096a6b6c6d6e6f600000000
8200d200a203117200a203b2000182938282838243532353535353535352528452525252620000007200b303b2000000824353535323235262b20000d0000000
0000000000b30282828372b20000b100525232122232b200000000000000b14200000000a28282123282839200000000000000000097a7b7c7d7e7f700000000
920011000013536200001353535353539200a20000018282828292c1b342525223232323620000000300b3030000000092b1b1b1b1b1b34262b200b372000000
000000000000b1a2828273b200000000232333132333b200001111000000b342000000008382125252328293a300000000000000000000000000000000000000
c1b372b200a2830300000000a2829300000000000000a2828382820012525252b1b1b1b1730000000393b30300000000000000000000b34262b200b303000000
b302b211000000110092b10000000071b1b1b1b1b1b100111112320000000042000000a282125284525232828300000000000000000000000000000000000000
00b303b200008203111111110082830011111111110000829200928242528452000000a3820000000382b37300000000000000000000b3426211111103000000
00b1b302b200b372b200000000000082b21000000000b31222522363b20000130000008292425252525262018282000000000000000000000000000000000000
00b373b20000a21353535363008292002222222232111102b20000a2132352520000000183920000038282820000000011111111930011425222222233b20000
100000b10000b303b200000000000082b27100000000b3425233b1b1000000b182018283001323525284629200a2820000000000000000000000000000000000
9300b100000000000000000000a2000223232323235363b100000000b1b1135200000000820000b30382839200000000222222328283432323232333b2000000
329300000000b373b200000000a20182111111110000b31333b100a30000000000a28293f3123242522333020000820000000000000000000000000000000000
829200001000000000000000000000b39310d30000a28200000000000000824200000000820000b30300a282000000005252526200828200a30182a200000072
62820000000000b100000093a382838222222232b20000b1b1000083004100000000122222526213331222329300a29300000000000000000000000000000000
010000a31222321111111111000000b322223293000182930000000000a301131000a383829200b373000083920000005284526200a282828283920000000073
62839321000000000000a3828282820152845262b200000093000082a371a382100013525284522222525252320076a200000000000000000000000000000000
828382824252522222222232000000b352526282a38283820000000012328282320001828200000083000082010000005252526271718283820000000000a382
628201729300000000a282828382828252528462b20000a38371a302018283821222324252525252525284525222223200000000000000000000000000000000
__label__
0000000000f000f000f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000f00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000f00000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000
00000000000000000000000000000007000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000006000000049999990000004999999000000000000000000000000000000000000
00000000000000000000000000f00000000000000000000000f00000000000060600000004999900000000499990000000000000000000000000000000000000
00000000000000000000000060000000000000000000000000000000000000d000600000004999900000049999000000000000000000000000f0000000000000
0000000006600000000000000000000000000000000000000000000000000d00000c70f000499990000049999000000000000000000000000000000000000000
000000000660000000000000000000000000000000000000000000000000d000000c00000004aaaa00004aaaa000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000c0000000c00060004aaaa0004aaaa0000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000d000000060c060d0004aaaa04aaaa00000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000c00000000000d000d004aaaa04aaaa00000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000c0000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000006666600666666006600c00066666600066666006666660066666600000000000000000000000000000000000000
0000000000000000000000000000000000006666666066666660660c000066666660666666606666660066666660000000000000000000000000000000000000
00000000000000000000000000000000000066000660660000006600000066000000660000000066000066000000000000000000000000000000000000000000
000000000000000000000000000000000000dd000000dddd0000dd000000dddd0000ddddddd000dd0990dddd0000000000000000000000000000000000000000
000000000000000000000000000000000000dd000dd0dd000000dd0000d0dd000000000000d000dd0990dd000000000000000000000000000000000000000000
000000000000000000000000000000000000ddddddd0dddddd00ddddddd0dddddd00ddddddd000dd0990dddddd00000000000000000000000000000000000000
0000000000000000000000000000000000000ddddd00ddddddd0ddddddd0ddddddd00ddddd0040dd0990ddddddd000000f000000000000000f00000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000004000049000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000c000000000000000000000000049999049999000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000c00000000000000000000000004aaaa0004aaaa00000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000cc000000000000000000000000004aaaa0004aaaa00000000000000000000000000000000000000000
000000000000000000000000000000000000000000000c0000000000000000000000000004aaaa000004aaaa0000000000000000000000000000000000000000
00000000000000000000000000000000000000000000c0000000000000000000000000004aaaa0000004aaaa0000000000000000000000000000000000000000
0000000000000000000000000000000000000000000100000000000000000000000000004aaaa00000004aaaa000000000000000000000000000000000000000
000000000000000000000000000000000000000000c0000000000000000000000000000477770000000047777000000000000000000000000000000000000000
00000000000000000000000000000000000000000100000000000000000000000000004777700000000004777700000000000000000000000000f0f0f0f0f0f0
0000000000000000000000000000000000000000010000000000000000f000f000f00477777700f0000047777770000000000000000000000000000000000000
00000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000010000000000000000000000000000000000000000000000000010000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000070000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000005550000055500550550000000550555000000550555050005550055055505550000000000000000000000000000000
00000000000000000000000000000000005050000055505050505000005050500000005000500050005000500005005000000000000000000000000000000000
00000000000000000000000000000000005550000050505050505000005050550000005000550050005500555005005500000000000000000000000000000000
00000000000000000000000000000000005050000050505050505000005050500000005000500050005000005005005000000000000000000000000000000000
0000000000000000000000000000000000505000005050550055500f00550050000000055055505550555055000500555000000000000000000000000f000000
000000000000000000000000000000000000000000000000000000000000000000000000f00f00000000000000000000000000000000000000000000f0000000
0000000000000000000000000000000000005550505000005550555055505550000055505050f550555005500550550000000000000000000000000000000000
0000000000000000000000000000000000005050505000005550505005000500000005005050505050505f005050505000000000000000000000000000000000
00000000000f00000000000f000000000000550055500f0050505550050005000000050055505050550055505050505000000000000000000000000000000000
0000000000000000000000000000000000005050005f000f50505050050005000f00050050505050505000505050505000000000000000000000000000000000
0000000000000000000f00000f00000f00f05550555000f050505050050005f0000005005050550050505500550050500f000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000f0000000000
00000000000000000000f0000000000000000055505500550000005500055055505000f0005550555055505550505000000f000000000000000000f000000000
000000000f0000000000000000000000000000505050505050000050505050500050000000505f5000505050505050000000000000f000000000000660000f00
00000000000f00000000000000000000000000555050505050000050505050550050000000550055005500550055500000000000000000000000000660000000
00000000000000000000000000000000000000505050505050000050505050500050000000505050005050505f00500000000000000000000000f00000000000
00000000000000000000000000000000000000505050505550000050505500555055500000555055505050505055500000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f0000f0f0f0f0f00000
0000000000000000000000000000000f0000000000000000000000000000000000000f000000000000000f000f0000000000000000000000f000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000f0f0ff000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000f000000000000000000000000000000000000000000000000000000f0000000000000000f00f000
0000000000f00000000000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000000000000f0000000000000
0000000000000000000000000000000000f0f0000000000000000f00000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000f0000000000000000000000000000000000000000000000000000000000000000000000f000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000505055505550055000005500555000005550055055500550000000000000000000f0000000000000000000
0000000000000000000000000000000000000000005050505005005000000050505000000050505000050050000000000000000000000000000000f000000000
000000000000000000f0000000000000000000000055005500050055500000505055000000555055500500555000f00000000000000000000000000000000000
000000000000000000000000000000000f0000000050505050050000500000505050000000505000500500005000000000000000000000000000000000000000
000000f00000000000000000000000000000000f005050505055505500f000555055500000505055005550550000000000000000000000000000000000000000
0000000000000000000000000000000000000000f00000000000000000000000770000000000000000000000f000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000f0000000000000007700000000000000000000000000000000000000000000000000000f00000f00
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000f000000000000000000000000000000000000000000f00000000000000000000000000000000000000000000000f00000000
00000000000000000000000000000f000000000000000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000
00000000000000000000000000000000000000000000000000000000000000f0000000000000000000000f000000000000000000000000000000000000000000
0000000000000f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000f00000f0000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000000000000000000000000000000000000f0000000000000000000000000000000000000000000000
000000000000000000000000000000000000000000000000f00000000000000f0000000000000000000000000000000000000000000000000000000000000000
0000f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000f00000000000000000000000000000000000f000000000000f000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000f0f00f0000000000000000000000000f0000000000000000000000000
00000000000000000000000000000000000000000f0000000000f0000000000000000000000000000000000000000f0000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

__gff__
0000000000000000000000000000000004020000000000000000000200000000030303030303030304040402020000000303030303030303040404020202020200001313131302020302020202020202000013131313020204020202020202020000131313130000040202020202020200001313131300000002020202020202
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
2331252548252532323232323300002425262425252631323232252628282824252525252525323328382828312525253232323233000000313232323232323232330000003132323233313233000024252525482525252525252526282824252548252525262828282831254825252526282828283132323225482525252525
252331323232332900002829000000242526313232332828002824262a102824254825252526002a2828292810244825282828290000000028282900000000002810000000002829000000002a2800242525252525482525323232332828242525254825323338282a28273125254825262a382828282a2a2831323232322525
252523201028380000002a0000003d24252523201028292900282426003a382425252548253300002900002a0031322528382900003a00003828000000002d003828393e003a28000000000000280024252532323232323321222223282824252525323334362829000024363132252526002828282900002a28282838282448
3232332828282900000000003f2020244825262828290000002a243300002a2425322525260000000000000000000024290000000021222328280000000000002a2828343536290000000000002839242526212223203423313232332828242548261b1b00200000000037001b1b242526002828000000000028282828282425
2300283828293a2839000000343522252548262900000000000030000000002433003125333d3f00000000000000002400001c3a3a31252620283900000000000010282828290000000011113a28283132332425262d00313628282828382425252600001c0000000000001c0000242526002828001400002a28283828282425
263a2d2828102829000000000000312525323300000000110000370000003e2400000037212223000000000000000031390000282828242628290000000000002a28282900000000003b2123283828292828313233282829002a002a282824252533000000000011110000000000314826112810001700000028282828282425
25223535362828000d000000003a282426003d003a39002700000000000021250000000024252611111111000000000028382828283831332800000017170000002a000000000000000024261028290028281b1b1b11110000000021222225482628390c00003b34362b00000c002824252328283a00003a28282829002a3132
25333828282900343535360000283824252320201029003039000000000024480000003a313232353535360000000000282828281028212329000000000000000000000000000000003a2426282800003828390000212329003435323232323226101000000000282839000000002a2425332828283800343536390000001700
2600002a28000000003a283a2828282425252223283900372800390000283132000000282828282827202828283921222829002a28282426000000000000000000000000000034362828312523000000282828290024260000003a00002828003338280b00000010382800000b00003133282828282800282828280000001700
330000002800000000281028283422252525482628280020282828382828212200003a283828102937002a28382824252a0000002838242600000017170000000000000000002728282a283133390000282900000031260000001428282829002a2839000000002a282900000000000028282838282828282828290000000000
0000003a2828383e3a2828283828242548252526002a282729002a28283432250000002a2828282c0000002810282425000000002a282426000000000000000000000000000037280000002a2828390011000000391b372b3b212236282800000028290000002a2828000000000000002a282828281028282828000000000000
0000002838282821223536002a28242532322526003a2830000000002a28282400000000002a283c3d143f28282824480000003a28283133000000000000171700013f0000002029000000003828000d20013a28281028000031330028290027002a280c0000003a380c00000000000c00002a2828282828292828290000003a
00013a2123282a313329001111112425002831263a3829300000000000002a310000000000002834222236292a0024253e013a3828292a00000000000000000035353536000020000000003d2a28002022222328282828283900002838283d37003a290000000028280000000000000000002a28282a29000000100012002a28
22222225262900212311112122222525002a3837282900301111110000003a2800013f0000002a282426290000002425222222232900000000000000171700002a282039003a2000003a003435353535252525222222232828282810282821220b10000000000b28100000000b0000002c00002838000000002a283917000028
2548252526111124252222252525482500012a2828003f242222230000003828222223000012002a24260000001224252525252600000000171700000000000000382028392827000028000020282828254825252525262a28282122222225253a28013d0000000028390000000000003c0100282800171717003a2800003a28
25252525252222252525252525252525222222222222222525482600000028282548260000270000242600000021252525254826171700000000000000000000002a2028102830003a282828202828282525252548252600002a2425252548252821222300000028282800000000000022222223280000000000282839002838
2532330000002432323232323232252525252628282828242532323232254825323232323232323225262828282448252525252600000000000000000000005225253232323233313232323233282900262829280000000000002828313232322525253233282800312525482525254825254826283828313232323232322548
26282800000030202a282828282824252548262838282831333828290031322528280000003a28283133282838242525482525330000000000000000002d005225261b0000000000002a10282838390026281c3820393d000000002a3828282825252628282829003b2425323232323232323233282828282828102828203125
3328390000003700002a3828002a2425252526282828282028292a0000002a31282800000d282828000028002a312525252526000000000000000000000000522526000000000014000000292a28290026283a2820102011111121222328281025252628382800003b24262b002a2a38282828282829002a2800282838282831
282810290000000000002828390024482525262829002820000000000000000038102122232b3b3435361029002a24253232330000000000000000000000420025263900000021230000000000212222252222232122232122232448262828283232332828202b003b31332b00000028102829000000000029002a2828282900
282828001c00000d002a2828280024252525262700002a2029000000000000002829242533292a0000002a00111124252223282800002c46472c000d00425353252628000020242600000000002425252525482631323331323324252620283822222328292800000028290000000000283800111100001200000028292a0000
283828000000342223003a28290031254825263700000029000000000000003a29002426283900000000003b212225252526382800003c56573c4243435363632526283900282426111111111124252525482526201b1b1b1b1b24252628282825252600002a28143a2900000000000028293b21230000170000112800000000
282828000000003133202838000027313232332000000000000000000027282800003133290000000000003b312548252533282828392122222352535364000025262a28382831323535353522254825252525252300000000003132332810284825261111113435360000001100000000003b31331111111111272829000000
2828282810290000002a2828000024233535353611110014000000001130283800002828000000000000002a28313225262a282810282425252662636400000032323628282829000000000031322525252525252600000000002000002a28282525323535352222222222353639000000003b34353535353536303800000027
282900002a0000000000382a29002426282828343620001700001700203028280b002a29000011110000000028282831260029002a282448252523000000000039001b282900000000000000002831322525482526382900000017000000002832331028293b2448252526282828000000003b201b1b1b1b1b1b302800000037
283a0000000000000000280000003133283810292a000000000000002a3710281111111111112136000000002a283800260000000021252525252600000000002828283b202b0000000000002a382829252525252628000000001700002a212228282900003b242525482628282912000000001b00000000000030290000003b
3829000000000000003a102900002838282828000000000000000000002a2828223535353535330000000000002828393300000000313225252533000000000028382829000000003b202b00002828003232323233290000000000000000312528280000003b3132322526382800170000000000000000110000370000000000
290000000000000000002a000000282928292a00000000000000000000002812332838282829000000000000001028280000000042434424252628390000000028002a0000110000001b002a2010292c1b1b1b1b00000000000000000000103128292d0000001b1b1b313328100000000000001100003a2700001b0000000000
00000100000011111100000000002a3a2a0000000000000000000000002a2817282829002a000000001717000028282800000000525354244826282800000000290000003b202b39000000002900003c000000000000000000000000000028282800000000000000001b1b2a282900000100002739003830000000000000000d
1111201111112122230000001212002a0001000000000000000000000000290029000000000000000000000000282900003f01005253542425262810003a3900013f0000001b3829000000000000002101000000000000003a00000000002a382800000000000100000000002800000021230037282928300000000000212222
222222222223244826111111202011110027390000171700000017170000000000010000000017170000002a2838393a0021222352535424253328282838290022232b00000028393b27000000000d24230000001200000028290000000000282828102800001717171717282839000031333927101228370000000027242525
254825252526242526212222222222223a303800000000000000000000000000001717000000000000003a28282828280024252652535424262828282828283925262b00003a28103b30000000212225260000002700003a28000000000000282838282828390000000000283828000022233830281728270000000030242525
__sfx__
0102000036370234702f3701d4702a37017470273701347023370114701e3700e4701a3600c460163500844012330054201900019000190001900019000190001900019000190001900019000190001900019000
0002000011070130701a0702407000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000300000d07010070160702207000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
000200001f630256302a6302e63030630306202f6202e6202c6202a620286202662024610226101f6101c610196101661013610116100e6100b61007610056100361010600106000060000600006000060000600
000400000f0701e070120702207017070260701b0602c060210503105027040360402b0303a030300203e02035010000000000000000000000000000000000000000000000000000000000000000000000000000
000300000977009770097600975008740077300672005715357003470034700347003470034700347003570035700357003570035700347003470034700337003370033700337000070000700007000070000700
0001000036270342702e2702a270243601d360113500a3400432001300012001d1001010003100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00020000101101211014110161101a120201202613032140321403410000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100001000010000100
00030000070700a0700e0701007016070220702f0702f0602c0602c0502f0502f0402c0402c0302f0202f0102c000000000000000000000000000000000000000000000000000000000000000000000000000000
000300003f0503f0503f3403f3303f6203f6103f6103f6053f6003f6003f600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600006000060000600
000400000c5501c5601057023570195702c5702157037570285703b5702c5703e560315503e540315303e530315203f520315203f520315103f510315103f510315103f510315103f50000500005000050000500
00030000096450e655066550a6550d6550565511655076550c655046550965511645086350d615006050060500605006050060500605006050060500605006050060500605006050060500605006050060500605
00040000336251a605000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005000050000500005
001000000c3500c3400c3300c3200f3500f3400f3300f320183501834013350133401835013350163401d36022370223702236022350223402232013300133001830018300133001330016300163001d3001d300
000c0000242752b27530275242652b26530265242552b25530255242452b24530245242352b23530235242252b22530225242152b21530215242052b20530205242052b205302053a2052e205002050020500205
000500000373005731077410c741137511b7612437030371275702e5712437030371275702e5712436030361275602e5612435030351275502e5512434030341275402e5412433030331275202e5212431030311
000300001f3302b33022530295301f3202b32022520295201f3102b31022510295101f3002b300225002950000000000000000000000000000000000000000000000000000000000000000000000000000000000
000b00002935500300293453037030360303551330524300243050030013305243002430500300003002430024305003000030000300003000030000300003000030000300003000030000300003000030000300
001000003c5753c5453c5353c5253c5153c51537555375453a5753a5553a5453a5353a5253a5253a5153a51535575355553554535545355353553535525355253551535515335753355533545335353352533515
00100000355753555535545355353552535525355153551537555375353357533555335453353533525335253a5753a5453a5353a5253a5153a51533575335553354533545335353353533525335253351533515
001000200c0600c0300c0500c0300c0500c0300c0100c0000c0600c0300c0500c0300c0500c0300c0100f0001106011030110501103011010110000a0600a0300a0500a0300a0500a0300a0500a0300a01000000
001000000506005030050500503005010050000706007030070500703007010000000f0600f0300f010000000c0600c0300c0500c0300c0500c0300c0500c0300c0500c0300c010000000c0600c0300c0100c000
0010000003625246150060503615246251b61522625036150060503615116253361522625006051d6250a61537625186152e6251d615006053761537625186152e6251d61511625036150060503615246251d615
00100020326103261032610326103161031610306102e6102a610256101b610136100f6100d6100c6100c6100c6100c6100c6100f610146101d610246102a6102e61030610316103361033610346103461034610
00400000302353020530225332152b22530205302153020530205302153020530205302153020530205302152b2352b2052b22527215292252b2052b2152b2052b2052b2152b2052b2052b2152b2052b2052b215
000b00000b0500b0550b0500b0550b0500b0550b0500b0550b0500b0550b0500b0550b0500b0550b0500b05006050060550605006055060500605506050060550605006055060500605506050060550605006050
000b00003b2253b22039225392203b2253b22036225362203b2253b22039225392203b2253b22036225362203b2253b22039225392203b2253b22036225362203b2253b22039225392203b2253b2203622536220
000b00000b4400b4450b4400b44017440174400b4400b4400d4400d4450d4400d44019440194400d4400d4400e4400e4450e4400e4401a4401a4400e4400e4400644006445064400644012440124400644006440
000b00000b4400b4450b4400b44017440174400b4400b4450b4400b4450b4400b44017440174400b4400b44006440064450644006440124401244006440064450644006445064400644012440124400644006440
000b00000705007055070500705507050070550705007055070500705507050070550705007055070500705009050090550905009055090500905509050090500a0500a0550a0500a0550a0500a0550a0500a050
000b00000000000000000000000012140121400000000000000000000012140121400000000000101401014010140101401014010140101401014010140101401014010140000000000000000000000000000000
000b00000744007445074400744013440134400744007445074400744507440074401344013440074400744009440094450944009440154401544009440094400a4400a4450a4400a44016440164400a4400a440
000b0000070500705507050070550705007055070500705507050070550705007055070500705507050070500a0500a0550a0500a0550a0500a0550a0500a0550a0500a0550a0500a0550a0500a0550a0500a050
000b00003723537230322353223037235372303b2353b2303723537230322353223037235372303b2353b2303a2353a23036235362303a2353a23036235362303a2353a230362353623031235312303a2353a230
000b00000b3400b3450b3400b34017340173400b3400b3450b3400b34017340173400b3400b340153401534015340153401534015340153401534015340153401534015340063400634009340093400a3400a340
000b00000744007445074400744013440134400744007445074400744507440074401344013440074400744006440064450644006440124401244006440064450644006445064400644012440124400644006440
000b00000b0500b0550b0500b0550b0500b0550b0500b0500d0500d0550d0500d0550d0500d0550d0500d0500e0500e0550e0500e0550e0500e0550e0500e0501205012055120501205512050120551205012050
000b000036240322402f24036240322402f2403624032240372403424031240372403424031240372403424039240362403224039240362403224039240362403b24039240362403b24039240362403b24039240
010700000903009030090300903009030090300903009030090300903009030090300903009030090300903009030090300903009030090300903009030090300903009030090300903009030090300903009030
010700000703007030070300703007030070300703007030070300703007030070300703007030070300703007030070300703007030070300703007030070300703007030070300703007030070300703007030
010700000503005030050300503005030050300503005030050300503005030050300503005030050300503005030050300503005030050300503005030050300503005030050300503005030050300503005030
00070000000000000000000000002f1202f1200000000000301203012000000000002f1202f1200000000000321203212000000000002f1202f12000000000003012030120000000000032120000000000000000
000700002432000000000000000024320243200000000000000000000000000000002432024320000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__music__
01 12141644
02 13151644
01 177e4344
00 177e4344
00 177e4344
03 17184344
01 191a1c5c
00 1d1a1f5f
00 191a1c5c
00 1d1a1f5f
00 20212363
00 24251b5b
00 201a2363
00 1e1a2262
00 1e1a2262
00 1e1a2262
02 1e1a2262
01 26292a43
00 27292a43
00 28292a43
02 27292a43

