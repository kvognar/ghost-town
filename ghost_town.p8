pico-8 cartridge // http://www.pico-8.com
version 36
__lua__
--setup

t=0
sunset=0
speaking=false
has_book=false

timeout=0
timeout_fn=nil

b={
  left=0,
  right=1,
  up=2,
  down=3,
  z=4,
  x=5,
}
cam={x=0,y=0}

actors = {}

stage = {tile_sx=0,tile_sy=0,tile_w=16,tile_h=16,actors={},palette_swaps={}}

sugars={}

function normalize(x,y)
 local length=sqrt(x^2+y^2)
 if (length==0) return nil
 return {x=x/length,y=y/length}
end

function stage:new(attrs)
  attrs=attrs or {}
  setmetatable(attrs,{__index=self})
  attrs.width=attrs.tile_w*8
  attrs.height=attrs.tile_h*8
  return attrs
end

function stage:update() end

function stage:exit_right()
  wipe:init(1, function()
    current_stage=current_stage.right()
    pl.x=1
  end)
end
function stage:exit_left()
  wipe:init(-1, function()
    current_stage=current_stage.left()
    pl.x=current_stage.width-pl.w
  end)
end

function stage:exit_up()
  wipe:init(-1, function()
   current_stage=current_stage.up()
   pl.x=64
   pl.y=40
   pl.can_fly=true
   pl.flying=true
   pl.dy=0
   pl.dx=0
   sugar_mode=false
   sugar_magistrate.drift=false
   sugar_magistrate.dispense=false
   sugar_magistrate:interact()

   foreach(sugar_crew, function(crewmate)
    del(schoolhouse_entrance.actors,crewmate)
    add(the_sky.actors,crewmate)
    crewmate.damping=0.95
    crewmate.flying=true
   end
   )
   sugar_magistrate.x=80
   sugar_magistrate.y=40
   sugar_captain.x=32
   sugar_captain.y=40
   sugar_maestro.x=64
   sugar_maestro.y=60
   sugar_magistrate.dispense=false
   sugars={}
  end,true)
end

function stage:exit_down()
	wipe:init(1, function()
		current_stage=current_stage.down()
		current_stage.up=nil
		pl.x=64
		pl.y=10
	end, true)
end

function stage:draw()
  self:draw_sky()
  -- draw simple tiles
  map(self.tile_sx,self.tile_sy,0,0,self.tile_w,self.tile_h,0)
  -- draw palette-overloaded tiles
  for set in all (self.palette_swaps) do
    pal(set[1],set[2])
  end
  map(self.tile_sx,self.tile_sy,0,0,self.tile_w,self.tile_h,2)
  pal()
end

function stage:draw_sky()
  if (t%100==0) sunset+=1
  local width=self.width-1
  rectfill(0,0,width,11+sunset/4,1)
  rectfill(0,12+sunset/4,width,23+sunset/3,2)
  rectfill(0,24+sunset/3,width,35+sunset/2,8)
  rectfill(0,36+sunset/2,width,47+sunset,9)
  rectfill(0,48+sunset,width,128,10)
end

function set_camera()
  local camera_window=56
  if pl.x>cam.x+128-camera_window then
    cam.x+=pl.x-(cam.x+128-camera_window)
  end
  if pl.x<cam.x+camera_window then
    cam.x-=cam.x+camera_window-pl.x
  end
  cam.x=max(cam.x,0)
  cam.x=min(cam.x,current_stage.width-128)
  if current_stage.width < 128 then
    --center camera
    cam.x=-(128-current_stage.width)/2
  end
  if current_stage.height < 128 then
    cam.y=-(dialog.y-current_stage.height)/2
  else
    cam.y=0
  end
  camera(cam.x,cam.y)
end

dialog={
 message="",
 phrases={},
 phrase_index=1,
 index=0,
 line_index=1,
 x=0,
 y=95,
 w=127,
 h=32,
}

function dialog:new(attrs)
 attrs=attrs or {}
 return setmetatable(attrs,{__index=self})
end

function dialog:draw()
 camera()
 rectfill(self.x,self.y,self.x+self.w,self.y+self.h,0)
 rect(self.x,self.y,self.x+self.w,self.y+self.h,5)
 if speaking then
   if (self.speaker) self:draw_speaker()
   print(sub(self.message,0,self.index),self.x+4,self.y+3,7)
   if self.wait and t%30 < 15 then
     print("\151",self.x+self.w-10,self.y+self.h-7,7)
   end
 end
end

function dialog:draw_speaker()
  local width = #self.speaker.name*4+6
  rectfill(self.x,self.y-8,width,self.y,0)
  rect(self.x,self.y-8,width,self.y,5)
  line(self.x+1,self.y,width-1,self.y,0)
  print(self.speaker.name, self.x+4,self.y-5,13)
end

silent={' ','.',',','?','!'}



function dialog:update()
 if self.index <#self.message then
  if btnp(b.x) and self.index>1 then
   self:rush()
  else
   self.index+=1
    self.speaker:vocalize()
   self:insert_newlines()
  end
 else
  self.wait=true
  if btnp(b.x) then
   self.wait=false
   self:advance()
  end
 end
end

function dialog:advance()
 self.phrase_index+=1
 if self.phrase_index <= #self.phrases then
  self.message=self.phrases[self.phrase_index]
  self.index=0
  self.line_index=0
 else
   speaking=false
   if (self.callback) self.callback(self.speaker)
 end
end

function dialog:rush()
 while (self.index<#self.message) do
  self.index+=1
  self:insert_newlines()
 end
end

function dialog:insert_newlines()
 if sub(self.message,self.index,self.index) == " "
 and 4*(self:next_word() - self.line_index) > self.w - 4
 then
  self.message=sub(self.message,1,self.index).."\n"..sub(self.message,self.index+1)
  self.line_index=self.index+1
 end
end

function dialog:next_word()
 local n=self.index+1
 while n <= #self.message do
  if sub(self.message,n,n) == " " then
   break
  else
   n+=1
  end
 end
 return n-1
end

function dialog:init(phrases,speaker,callback)
  self.phrases=phrases
  self.speaker=speaker
  self.callback=callback
  self.phrase_index=0
  self:advance()
  speaking=true
  speaker.met=true
end

entity = {
 x=0,y=0,dx=0,dy=0,ax=0,ay=0,
 damping=1,
 w=5,h=8,
 spr_w=1,spr_h=1,
 frames={},
 frame_index=1,
 frametime=1,
 facing_left=false
 }

function entity:new(attrs)
  attrs = attrs or {}
  return setmetatable(attrs,{__index=self})
end

function entity:draw()
  if self.current_frames and #self.current_frames > 0 then
   local y_offset=0
   if (self.flying and t%60<30) y_offset=-1
    spr(
    self.current_frames[self.frame_index],
    self.x,
    self.y+y_offset,
    self.spr_w,
    self.spr_h,
    self.facing_left
   )
  else
    -- rectfill(self.x,self.y,self.x+self.w,self.y+self.h,8)
  end
end

function entity:lerp_to(other, weight)
 v=lerp_points(self,other,weight)
 self.ax=v.x-self.x
 self.ay=v.y-self.y
end

function entity:aim_for(other)
 self.ax=other.x-self.x
 self.ay=other.y-self.y
end

-- "I'm outta here"
-- If you're going to lerp, do this one to
-- bounce in the other direction first
function entity:bounce()
 self:aim_for(self.target_point)
 local norms=normalize(self.ax,self.ay)
 self.dx+=norms.x*-4
 self.dy+=norms.y*-4

end

function entity:update()
 local a_norm=normalize(self.ax,self.ay)

 if a_norm then
  self.ax=a_norm.x*.5
  self.ay=a_norm.y*.5
 end

 self.dx+=self.ax
 self.dy+=self.ay

 self.x+=self.dx
 self.y+=self.dy
 self.dx*=self.damping
 self.dy*=self.damping
end

player=entity:new({
  jumping=false,
  grounded=true,
  damping=1,
  gravity=.2,
  spr_w=1,
  spr_h=1.5,
  h=11,
  w=6,
  frames={
    standing={0},
    walking={0,1,0,2},
    upjump={3},
    downjump={4},
  },
  icon_offset=1,
  sugars={}
})

function player:update()
  self:process_buttons()
  self:check_boundaries()
  self:collide_and_move()
  self:select_frames()
end

function player:draw()
  entity.draw(self)

  if (t%20==0) self.icon_offset*=-1
  local other = colliding_actor()
  if other and other.icon and not speaking then
    spr(other.icon,self.x,self.y-(10+self.icon_offset))
  end
end

function player:collide_and_move()
  self.dx*=self.damping
  if not self.flying then
   self.dy+=self.gravity*((100-#self.sugars)/100)
  end

  --collide left
  if is_solid(self.x+self.dx,self.y+self.h) or
     is_solid(self.x+self.dx,self.y)
  then
    self.dx=0
  end

  --collide right
  if is_solid(self.x+self.dx+self.w,self.y+self.h) or
     is_solid(self.x+self.dx+self.w,self.y)
  then
    self.dx=0
  end
  self.x+=self.dx

  -- collide down
  if is_solid(self.x,self.y+self.h+self.dy) or
     is_solid(self.x+self.w,self.y+self.h+self.dy)
  then
    self.jumping=false
    self.flying=false
    self.dy=0
  end

  -- collide up
  if self.flying and
  	(is_solid(self.x,self.y+self.dy) or
  	 is_solid(self.x+self.w,self.y+self.dy))
  then
  	 self.dy=0
  end

  self.y+=self.dy

end

function player:process_buttons()

  if self.flying then
   self.dy*=0.90
   self.dx*=0.90
   if btn(b.up) then
    self.dy-=.3
   elseif btn(b.down) then
    self.dy+=.3
   end
   self.dy=mid(-2,self.dy,2)

   if btn(b.left) then
    self.dx-=.4
   elseif btn(b.right) then
    self.dx+=.4
   end
   self.dx=mid(-2,self.dx,2)

  else
   if btn(b.left) then
     self.dx=-1
   elseif btn(b.right) then
     self.dx=1
   else
     self.dx=0
   end
  end

  if self.can_fly then
   if btn(b.up) then
    self.flying=true
   end
  else
   if btn(b.up) and not self.jumping then
     self.jumping=true
     self.dy=-2-#self.sugars/10
     -- self.dy=-3-#self.sugars--/10
     --self.dy=-10
   end

  end

  local other = colliding_actor()
  if other and btnp(other.button) then
    other:interact()
  end

end

function player:select_frames()
  if abs(self.dx) > 0 then
    self.current_frames=self.frames.walking
  else
    self.current_frames=self.frames.standing
  end
  if self.jumping or self.flying then
    if self.dy <0 then
      self.current_frames=self.frames.upjump
    else
      self.current_frames=self.frames.downjump
    end
  end

  if (self.dx < 0) self.facing_left=true
  if (self.dx > 0) self.facing_left=false

  if t%8==0 then
    self.frame_index = (self.frame_index%#self.current_frames)+1
  end
end

function player:check_boundaries()

 if self.x+self.dx+self.w/2 > current_stage.width then
 	if current_stage.right
  and not sugar_mode then
   current_stage:exit_right()
  else
   self.dx=0
  end
 elseif self.x+self.dx < -5 then
  if current_stage.left
  and not sugar_mode then
   current_stage:exit_left()
  else
   self.dx=0
  end

 elseif self.y+self.h<1 then
  if current_stage.up then
   current_stage.exit_up()
  else
   self.dy=max(0,self.dy)
  end
 end
end

ghost=entity:new({
  phrases={},
  current_frames={123,124,125,126,127,126,125,124},
  w=12,
  button=b.x,
  icon=90,
  phrase_index=1,
  met=false,
  finished=false,
  can_flip=true,
  interactable=true,
  favorite_book="readme.txt",
  voice_clip=6,
  voice_start=0,
  voice_length=3,
  last_words="good night, good luck, please remember that ☉ will see you on the morrow."
})

function ghost:interact()
  dialog:init(self.phrases[self.phrase_index][1],
  self,
  self.phrases[self.phrase_index][2])
  self:face_toward(pl.x)
end

function ghost:face_toward(x)
 if self.can_flip and x<(self.x+self.w/2) then
 	self.facing_left=true
 else
 	self.facing_left=false
 end
end

function ghost:update()
  if t%8==0 then
    self.frame_index = (self.frame_index%#self.current_frames)+1
  end
  if self.blinking then
    self.blink_counter-=1
    if self.blink_counter<0 then
      self.blinking=false
      self:blink_callback()
    end
  end
  if self.target_point then
   self:aim_for(self.target_point)

  end
  entity.update(self)
end

function ghost:increment_phrase()
  self.phrase_index+=1
end

function ghost:vanish_to(stage)
 self:add_entry()
  self:blink(function(self)
    del(current_stage.actors,self)
    -- add(stage.actors,self)
  end)
end

function ghost:add_entry()
	self.finished=true
end

function ghost:blink(callback)
  self.blinking=true
  self.blink_counter=20
  self.blink_callback=callback
end

function ghost:draw()
  if (not state==states.book)
  and (self.blinking and t%2==0)
  then
   return
  end
  entity.draw(self)
  if (self.target_point) then
   circfill(self.target_point.x,self.target_point.y,4,0)
  end
end

function ghost:vocalize()
	if (t%4~=0) return
	local num = self.voice_start+
		flr(rnd(self.voice_length))

	sfx(self.voice_clip,
   	-1,
   	num,--self.voice_start+num,
   	1
   	--self.voice_length
   )
end

function is_solid(x,y)
  return fget(get_tile(x,y)) == 1
end

function colliding_actor()
	if (sugar_mode) return nil
  chatbox = {
    x=pl.x,
    y=pl.y,
    w=pl.w,
    h=pl.h
  }
  if pl.facing_left then
    chatbox.x-=4
  else
    chatbox.x+=8
  end

  for a in all(current_stage.actors) do
    -- collide in front of player if it's a person
    -- collide directly with player otherwise
    if a.interactable then
	    if a.name then
	      collider=chatbox
	    else
	      collider=pl
	    end
	    if collider.x+collider.w > a.x and
	       a.x+a.w > collider.x and
	       collider.y+collider.h > a.y and
	       a.y+a.h > collider.y
	    then
	      return a
	    end
    end
  end
end

door=entity:new(
	{
		w=12,h=19,
		icon=91,
		button=b.down,
		interactable=true
		}
		)
function door:interact()
  -- set up exit
  self.return_stage=current_stage
  self.room.door=self

  fade_to(function()
    current_stage=self.room
    pl.x=1
    pl.y=current_stage.height-20
  end)
end

function add_actor(actor_class, options)
  local actor = actor_class:new(options)
  add(actors, actor)
  actor:init()
end

function get_tile(x,y)
  x=flr(x/8)+current_stage.tile_sx
  y=flr(y/8)+current_stage.tile_sy
  if (x<current_stage.tile_sx or x>current_stage.tile_sx+current_stage.tile_w) return nil
  return mget(x,y)
end

function initialize_actors()
  starting_area.actors={
    flower,
  }
  schoolhouse_entrance.actors={
    sugar_captain,
    sugar_maestro,
    sugar_magistrate,
    door:new({x=48,y=56,w=16,h=24,room=schoolhouse})
  }
  schoolhouse.actors={
    teacher,
  }
  blueberry_lane.actors={
    door:new({x=19,y=62,w=10,h=16,room=blueberry_lane_1}),
    door:new({x=99,y=62,w=10,h=16,room=blueberry_lane_2}),
    door:new({x=155,y=62,w=10,h=16,room=blueberry_lane_3}),
    door:new({x=235,y=62,w=10,h=16,room=blueberry_lane_4}),
  }
  blueberry_lane_1.actors={
    scaredy_ghost,
    tea_ghost,
  }
  blueberry_lane_2.actors={
    scientist,
  }
  blueberry_lane_3.actors={
    erwin,
  }
  blueberry_lane_4.actors={
   sleepy,
  }


  fountain.actors={
  }
  rosemary_way.actors={
    stargazer,
    door:new({x=99, y=62, w=10, h=16, room=rosemary_way_2}),
    door:new({x=155, y=62, w=10, h=16, room=rosemary_way_3}),
    door:new({x=236, y=62, w=10, h=16, room=rosemary_way_4}),
  }
  rosemary_way_2.actors={
    ant,
  }
  rosemary_way_3.actors={
    statue,
  }
  rosemary_way_4.actors={
    elder,
  }

  library_entrance.actors={
    door:new({x=53,y=60,w=13,h=16,room=library})
  }

  library.actors={
    librarian,
  }

  cemetery.actors={
    mourner,
  }
end

fades={
 {1,1,0,0,0,0},
 {2,1,1,0,0,0},
 {3,5,2,1,1,0},
 {4,2,1,1,1,0},
 {5,2,1,1,1,0},
 {6,5,2,1,1,0},
 {7,13,5,2,1,0},
 {8,4,5,2,1,0},
 {9,5,2,1,1,0},
 {10,4,5,2,1,0},
 {11,4,5,2,1,0},
 {12,5,5,2,1,0},
 {13,5,2,1,1,0},
 {14,4,5,2,1,0},
 {15,4,5,2,1,0}
}

fading=false
fade_index=1
fade_direction=1
fade_callback=nil
fade_to=nil

function fade_to(callback)
  fading=true
  fade_callback=callback
end

function fade_update()
  fade_index+=fade_direction
  if fade_index == #fades[1] then
    fade_callback(fade_to)
    fade_direction*=-1
    center_sugars()
  end
  if fade_index == 1 then
    fading=false
    fade_direction=1
    pal()
  end
end

function fade_palette()
  for i=1,15 do
    pal(i,fades[i][fade_index],1)
  end
end

wipe={x=0,dx=0,callback=nil,vertical=false}
function wipe:init(dir,callback,vertical)
  wiping=true
  self.callback=callback
  self.vertical=vertical
  self.x=-200*dir
  self.dx=15*dir
end

function wipe:update()
  self.x+=self.dx
  --switch stages when the entire screen is black
  if self.x*self.dx>0 and self.callback then
    self.callback()
    self.callback=nil
    foreach(current_stage.actors,
    function(actor)
    	actor:update()
    end)
   	center_sugars()
  end

  if self.x>200 or self.x<-200 then
    wiping=false
  end
end

function wipe:draw()
 if self.vertical then
  rectfill(0,wipe.x,127,wipe.x+200,0)
 else
  rectfill(wipe.x,0,wipe.x+200,127,0)
	end
end


-- "good morning. the day is still young yet, and there are adventures to be had.",
-->8
-- characters

-- define npcs

sugar_captain=ghost:new({
  phrases={
    {{"did you know that sugar gliders are exuda-tivorous?", "that means they eat plant goo like eucalyptus sap and honeydew!"}},
    {
     {
      'the sugar was inside you all along!'
     },
     function() sugar_maestro:interact() end
    }
  },
  current_frames={78},
  x=100,
  y=65,
  flying=true,
  name="sugar captain",
  voice_clip=7,
  voice_start=16,
  voice_length=3,
  favorite_book="red rackham's treasure - herge",
  last_words="sugar gliders are basically vampires but for trees."
})

sugar_maestro=ghost:new({
  phrases={
   {{"shh, i'm in torpor.", "that's like a nap, but more nappier."}},
   {
    {
    "i can smell the frosty flakes on your breath.",
    },
    function()
     sugar_magistrate:increment_phrase()
     sugar_magistrate:interact()
    end
  }
  },
  current_frames={77},
  x=10,
  y=70,
  voice_clip=7,
  voice_start=14,
  voice_length=3,
  name="sugar maestro",
  favorite_book="the tea dragon society - kay o'neill",
  last_words="when i'm bigger, i'll fly you around in my pocket."
})

function sugar_maestro:update()
 ghost.update(self)
 if sugar_mode then
 	self:face_toward(pl.x)
 	self.y=max(1,sugar_magistrate.y)
 end
end

function sugar_captain:update()
	sugar_maestro.update(self)
end

function begin_sugar_lesson()
 foreach(sugar_crew, function(crewmate)
 	crewmate:increment_phrase()
 	crewmate.flying=true
 end)
	sugar_magistrate.dispense=true
	sugar_mode=true
end

function exit_sugar_crew()
 foreach(sugar_crew, function(crewmate)
  crewmate.target_point={x=64,y=-32,w=0,h=0}
  crewmate:bounce()
  crewmate:add_entry()
  sfx(3)
 end)
 set_timeout(90,function()
 	current_stage:exit_down()
 	pl.sugars={
 		pl.sugars[1],
 		pl.sugars[2],
 		pl.sugars[3]
 	}
 end)
 teacher:increment_phrase()
end


sugar_magistrate=ghost:new({

 phrases={
 	{
 		{
 			"we've been getting real good at flying lately.",
 			"you wanna learn how? it's easy, watch!",
 			"you just gotta be like a sugar glider.",
 			"fly with the power of sugar!",
 			"i'll give you some sugar, okay?",
 			"the more you get, the higher you can fly.",
 			"okay, let's go!"
 		},
 		begin_sugar_lesson
 	},

  {
   {
    'you did it!',
    'see? flying is easy.',
    'you wanna know a secret?',
    "i didn't give you any sugar.",
    "that was just regular ghost stuff.",
   },
   function() sugar_captain:interact() end
  },
  {
   {
    'okay bye!'
   },
   exit_sugar_crew
  }
 },


 current_frames={79},
 x=30,y=20,
 name="sugar magistrate",
 sx=54,
 sy=30,
 offset=0,
 dispense=false,
 drift=true,
 voice_clip=7,
 voice_start=12,
 voice_length=3,
 sy_m=8,
 favorite_book="falling up - shel silverstein",
 last_words="see? you can do anything if you just believe you can."
})

sugar_crew={
	sugar_maestro,
	sugar_captain,
	sugar_magistrate
}

function sugar_magistrate:update()
 ghost.update(self)
 if self.drift then
 	local new_x=self.sx+30*sin(self.offset/300)
  self.facing_left=new_x<self.x
  self.x=new_x
  self.y=self.sy+self.sy_m*sin(self.offset/500)-(2*#pl.sugars)
  self.offset+=1
 end

 if self.dispense then
  if t%60==0 and #sugars<5 then
   add_sugar(self.x, self.y)
  end
 end
end

teacher=ghost:new({
 phrases={
  {
   {
   	"hi there.",
   	"sorry, i need to collect myself for a moment.",
   	"can you check on the kids for me?"
  	},
  	function()
  		sugar_magistrate.sy=60
  		sugar_magistrate:update()
  	end
  },

{{
 "thanks for being so patient with the kids.",
 "we were learning about marsupials the day we died.",
 "they're crazy about sugar gliders like i used to be about armadillos.",
 "i don't curl up and roll around the yard anymore, though.",
 "you know, you grow up and you get to know the world, you learn about math and art and weird bugs,",
 "and it's beautiful and incredible and there's so much to see...",
 "and then you get used to it.",
 "snowflakes are still pretty. poe is still gloomy. fennec foxes are still adorable.",
 "but nothing really hits you the way it did when you were a kid.",
 "when i teach my students about sugar gliders or photosynthesis or shel silverstein, though...",
 "i get to be amazed with them all over again.",
 "now we're dead, and it looks like lessons are over.",
 "but this afterlife business is a new experience. whatever comes next, we'll all be learning together.",
 "my students will be brilliant ghosts, i'm sure of it."
}, function(self)
 self:vanish_to(fountain)
end
}

},
  current_frames={195},
  x=70,
  y=48,
  spr_h=2,
  spr_w=2,
  h=16,
  facing_left=true,
  name="mrs. lovegarden",
  favorite_book="piranesi - susanna clarke",
  last_words="perk up those ears. there's something new for us to learn today."
})

scientist=ghost:new({
  phrases={
{{
 "so here's something to consider about ghosthood:",
 'i have no body. my "eye" has no lens to refract light, and no retina to absorb it.',
 "and yet i can see you all the same.",
 "in my time as a ghost, i have learned that my perception is limited only by my attention.",
 "if i focus, i can see radio waves, infrared light, and the occasional cosmic ray.",
 "i can watch as electrons are stripped from glucose molecules and harnessed for muscle contraction.",
 "sodium ion cascades in your neurons are as clear to me as waves on the ocean.",
 "\141 i can see your blood flow \141 \141 i can see your cells grow \141",
 "the mechanics of your body are a symphony - one that i used to play in as well.",
 "what a shame that, now that i can see how our bodies worked, it no longer means anything to me.",
 "i suppose i will have the rest of eternity to learn what ghosts are."
}, function(self)
 self:vanish_to(fountain)
end
}
},
  x=30,
  y=24,
  spr_h=2,
  spr_w=2,
  h=16,
  eye_x=37,
  eye_y=27,
  current_frames={236},
  name="dr. vera, phd",
  voice_clip=7,
  voice_start=0,
  voice_length=4,
  can_flip=false,
  favorite_book="the dragons of eden - carl sagan",
  last_words="i suppose i will have the rest of eternity to learn what ghosts are."
})

function scientist:draw()
  ghost.draw(self)
  circ(self.eye_x, self.eye_y, 2, 13)
  rectfill(self.eye_x-1,self.eye_y-1, self.eye_x+1,self.eye_y+1, 1)
end

function scientist:update()
  ghost.update(self)
  x_offset = mid((pl.x - self.x) / 10, -2, 2)
  y_offset = mid((pl.y - self.y) / 5, -1, 1)
  self.eye_x = self.x+7 + x_offset
  self.eye_y = self.y+3 + y_offset
end

scaredy_ghost=ghost:new({
  phrases={
    {
     {"th... there are ghosts all over this town! don't you see them?",
    "run! run for your life!"},
    function(self)
     self:vanish_to(fountain)
     tea_ghost.phrase_index=2

    end
 }
  },
  current_frames={241},
  x=54,
  y=32,
  name="clyde",
  favorite_book="scary stories to tell in the dark - alvin schwartz",
  last_words="w-w-what's that on your shoulder?"
})

tea_ghost=ghost:new({
  phrases={
    {{
     "hello! would you like some tea?",
     "oh, hang a second. i haven't figured out how to pick up the kettle."
  }},
   {{
    "don't worry about clyde. i'll go check up on him in a moment.",
    "he's kind of a worry wart, but he'll be fine.",
    "if i'm honest, calming him down is the only thing keeping me steady.",
    "life can be scary. death too, apparently.",
    "but we've got each other, and we've always kept each other afloat",
    "and i can't see anything stopping us from doing that just because we're dead.",
    "i count myself lucky.",
    "i can't think of anyone i'd rather spend eternity with."
   }},
  },
  current_frames={242},
  x=36,
  y=32,
  name="alex",
  favorite_book="everyone's a aliebn when ur a aliebn too - jomny sun",
  last_words="i can't think of anyone i'd rather spend eternity with."

})

erwin=ghost:new({
  phrases={
    {{"when i was alive i wanted to be so many things.",
    "a botanist, a filmmaker, a stay-at-home dad,",
    "a baker, a chemist, a barkeep, a monk.",
    "i could never decide, and i ended up sitting in the middle of everything i could be,",
    "turning into absolutely nobody.",
    "and then one day there's this flash, and i'm dead, and i never got to do any of it.",
    "what a weird unfairness of life that it should have too many good things, right?",
    "well.",
    "i don't know what this afterlife thing has to offer,",
    "but you can bet i won't let the world pass me by a second time."
  }, function(self) self:vanish_to(fountain) end }
  },
  current_frames={198},
  x=46,
  y=26,
  spr_h=2,
  spr_w=2,
  h=12,
  name="erwin",
  favorite_book="sum: forty tales from the afterlives - david eagleman",
  last_words="what a weird unfairness of life that it should have too many good things."
})

stargazer=ghost:new({
  phrases={
    {{
"i always wondered why ghosts were supposed to haunt places.",
"why stick around in some dusty old ruin?",
"you don't get hungry, you don't get tired, you can't get hurt. and you can fly!",
"go explore! there's a hundred billion lifetimes of things to see on this planet alone.",
"and when you're done with that, you've got the rest of the universe waiting for you.",
"gravity is nothing to a ghost.",
"thousands of years of interstellar travel is nothing if you're immortal.",
"just be patient, and one day you'll find another world to explore.",
}, ghost.increment_phrase},
{{
". . .",
"i say that, but i've been stuck here. just sitting, watching the stars.",
"like trying to convince myself to get out of bed.",
"maybe that's what the deal with ghosts is. post-death depression.",
"hey, thanks for coming to talk to me. i guess living people can fly now too, so that's cool.",
"okay, i'm gonna do it. i'm gonna go.",
"i'll sneak into a hollywood studio and watch them make a movie.",
"and then i'm gonna go fly around with a bunch of starlings.",
"and then i think i'm gonna figure out where the giant squids like to hang out.",
"yeah. that sounds good."
}, ghost.increment_phrase},
{{
 "okay! yes. off i go.",
 "hey, when you die too, come find me.",
 "i'll show you around ganymede or something. it'll be fun."
}, function(self) self:vanish_to(fountain) end }
},
current_frames={193},
spr_w=2,
spr_h=2,
width=10,
height=12,
x=22,
y=28,
name="stargazer",
can_flip=false,
favorite_book="diaspora - greg egan",
last_words="what do you think the cosmic microwave background tastes like?"
})

librarian=ghost:new({
  phrases={
    {
      {
        "hello! would you like to borrow a book?",
        "...honestly, you can keep whatever you like here. the rest of us are over and done.",
        "but, if you do, can you do me a favor, please?",
        "the townfolk are good souls. i watched a lot of them grow up here.",
        "i know their favorite books. i know what worried them, what excited them, what they looked forward to.",
        "you can tell a lot about a person by what they choose to read.",
        "it'll be time soon for us to move on, but before we all do...",
        "can you meet with the others and write down their last words for me?",
        "take the notebook with you when you're done, as a memento of what we used to be.",
        "they deserve to be rememembered."
      },
      function(self)
       has_book=true
       self:vanish_to(fountain)
      end
    },
  },
  current_frames={192},
  spr_h=2,
  h=16,
  x=25,
  y=48,
  name="library ann",
  favorite_book="kalpa imperial: the greatest empire that never was - angelica gorodischer",
  last_words="they deserve to be remembered. every one of them."
})

mourner=ghost:new({
  phrases={
  {{"hi."}, ghost.increment_phrase},
  {{"uh. i mean, boo?"}, ghost.increment_phrase},
  {{"sorry. not feeling very spooktacular today.",
  "i was here visiting my nan the day i died.",
  "the actual dying part was kind of a bummer, as you might expect,",
  "but when i realized i'd turned all ectoplasmic, i got kind of excited.",
  "i thought i'd get to see my family again - that maybe nan was waiting here for me.",
  "but, nope. nothing here but me and a bunch of old rocks.",
  "here lies kat, the only ghost in a field full of dead people.",
  "what kind of loser ghost haunts a graveyard by herself?",
  ". . .",
  "i just want my nanna back."
}, ghost.increment_phrase},
{{"i think i hear voices in the distance.",
"are there other ghosts out there?",
"i'm not the only one?",
"why them and not nan?",
". . .",
"i guess i'll go see what's going on.",
"thanks for pulling me out of my funk."
},
 function(self) self:vanish_to(fountain) end}
  },
  current_frames={197},
  sx=64,
  sy=60,
  name="kathlyn",
  offset=0,
  favorite_book="all my puny sorrows - miriam toews"
})
function mourner:update()
  local new_x=self.sx+30*sin(self.offset/300)
  self.facing_left=new_x<self.x
  self.x=new_x
  self.y=self.sy+10*sin(self.offset/500)
  self.offset+=1
end
elder=ghost:new({
  phrases={
    {{
      "after a lifetime you might think you know yourself.",
      "you've been molded and sculpted and put through the kiln, and your ways are set.",
      "i lived for ninety years. i'm proud of the person i made of myself.",
      "but i'm standing now in front of eternity.",
      "who might i be in another ninety years?",
      "in ten thousand?",
      "in a trillion trillion centuries?",
      "after all that time, these ninety years will be nothing in comparison.",
      "i will be a ghost, through and through,",
      "who just happened to sprout from a human long ago.",
      "what do all these years matter when they shrink into eternity?",
      "will i even remember what it was like to be alive?"
    }, function (self) self:vanish_to(fountain) end}
  },
  current_frames={227},
  x=45,
  y=24,
  spr_h=2,
  spr_w=2,
  name="muriel",
  favorite_book="breakfast of champions - kurt vonnegut",
  last_words="i'm starting to realize what \"strange eons\" might be."
})

ant=ghost:new({
  phrases={
  {{
    "i never liked squishing bugs.",
    "i was always the person who would scoop up spiders in a cup while her friends cowered in the corner.",
    "anything to save a little life, right?",
    "but the morning i died, i found my kitchen sink just swarming with ants, and i freaked.",
    "without a moment's hesitation, i turned on the hot water and drowned them all.",
    "i felt like garbage for the rest of... my life, i guess.",
    "do you think ants get to become ghosts, too?",
    "what do they do for their whole tiny afterlife?",
    "do they watch over their descendants, warding off evil spirits?",
    "do they wander the earth, one little step at a time?",
    "do they even know they're dead?",
    "maybe they swarm together into some sort of hive-soul.",
    "i have all of eternity ahead of me, and while that's kind of exciting,",
    "i think that i will never, ever know what it's like to be an ant.",
    "that whole slice of existence is closed off forever - ",
    "an infinity that will never intersect with my infinity."
  }, function(self) self:vanish_to(fountain) end}
  },
  current_frames={231},
  x=27,
  y=24,
  spr_h=2,
  spr_w=5,
  name="mae",
  can_flip=false,
  favorite_book="watership down - richard adams",
  last_words="maybe when the universe is done, we can start over and i'll be a bee."
})

flower=ghost:new({
  phrases={
    {{
      "look, thoughts and feelings and bread pudding are nice and all, but you know what's real great?",
      "nothing.",
      "and you know who's best at nothing?",
      "trees. flowers. punkins. grasses. big ol' strands of kudzu, even.",
      "i been runnin' around with a brain fulla words for forty years, and i'm sick of it.",
      "no more tv, no more money, no more bosses gettin' on your case over safety regulations,",
      "no more angry exes callin' you up at midnight,",
      "no more gettin' drunk and callin' her back at 2am.",
      "i'm done with it.",
      "you know what i'm gonna do, now i'm dead?",
      "i'm gonna put down some roots,",
      "and sit in the sun,",
      "and just",
      "be."
    },
    	function(self)
    		self.interactable=false
    	end
    }
  },
  current_frames={206},
  x=37,
  y=61,
  spr_h=3,
  spr_w=2,
  h=16,
  name="chuck",
  can_flip=false,
  voice_start=4,
  favorite_book="a heap o' livin' - edgar a. guest",
  last_words="..."
})

statue=ghost:new({
  phrases={
    {{
      "look, living is an act of creation.",
      "you are born a block of fresh marble, and every day of your life you chisel away at it.",
      "every chip is permanent.",
      "if you break off a chunk by accident, you're not gluing that thing back on.",
      "but you can always work with what you've got left.",
      "i tried really hard to make something good out of myself.",
      "i read my books, i painted in the morning, i did a lot of sit-ups, i told my friends i loved them.",
      "i didn't delude myself. i knew i'd never be the sort of heroic statue that stands in town square.",
      "but i could be pretty good, you know? something nice to put out in the backyard by the lilies.",
      "dying early was so frusting. just... look! i wasn't done yet! not even close!",
      "i was supposed to make a children's book.",
      "i was supposed to learn portuguese.",
      "i was supposed to be the kind of person who could take care of her parents.",
      "but one day comes a flash of light, wshhh, and my hammer and chisel are taken away.",
      "this is all i am, and all i will ever be.",
      "but you know what?",
      "screw it.",
      "we all deserve to be put on a pedestal.",
      "appreciate what you've made of yourself. let yourself be remembered, chips and cracks and all.",
      "even if you wanted to be so much more."
    }, function(self) self:vanish_to(fountain) end}
  },
  current_frames={93},
  x=46,
  y=16,
  spr_h=3,
  spr_w=2,
  h=24,
  name="rosetta",
  last_words="appreciate what you've made of yourself. let yourself be remembered.",
  favorite_book="the mezzanine - nicholson baker"
})

sleepy=ghost:new({
 phrases={
  {{
   "i think i'm tired.",
   "not body-tired, like after a long hike, but a heavy, cluttered, brain-tired.",
   "do you know the feeling?",
   "all the thoughts of the day piled on top of each other, dissolving into a buzzing mass.",
   "i used to hear about heaven and think, \"wouldn't that be exhausting?\"",
   "infinite joy for all of eternity, like a never-ending song.",
   "i was terrified of the thought.",
   "even when i'm having a good time, partying or reading comics or birdwatching,",
   "i can feel this static building up inside of me.",
   "nothing but sleep will let it settle.",
   "after a good night, all that static is wiped away, and i feel like a new person.",
   "i think i can do this afterlife thing, and i think i'll enjoy it,",
   "but only if every now and then i get to sleep for a hundred years or so.",
   "just give me some time.",
   "i have a lot of thoughts i need to wash away.",
  }}
 },
 current_frames={225},
 x=36,
 y=32,
 spr_w=2,
 spr_h=1,
 facing_left=true,
 favorite_book="order of tales - evan dahm",
 name="neil",
 last_words="dream quiet dreams. the world will be waiting for you when you wake."
})

ghosts={
 librarian,
 mourner,
 elder,
 ant,
 flower,
 statue,
 stargazer,
 erwin,
 tea_ghost,
 scaredy_ghost,
 scientist,
 teacher,
 sugar_maestro,
 sugar_captain,
 sugar_magistrate
 -- last ghost
}


-->8
-- places

starting_area=stage:new({tile_sx=0,tile_sy=0,tile_w=16,})
function starting_area:right()
  return schoolhouse_entrance
end

schoolhouse_entrance=stage:new({
  tile_sx=16,tile_sy=0,tile_w=16,
  palette_swaps={
    {14,2},
    {10,8},
    {12,8}
  }
})
function schoolhouse_entrance:left()
  return starting_area
end
function schoolhouse_entrance:right()
  return blueberry_lane
end
function schoolhouse_entrance:up()
 return the_sky
end

the_sky=stage:new({
 tile_w=16
})
function the_sky:draw()
 self:draw_sky()
end
function the_sky:down()
  return schoolhouse_entrance
end

blueberry_lane=stage:new({
  tile_sx=32,tile_sy=0,tile_w=33,
  palette_swaps={
    {12,13},
    {8,12},
    {2,13},
    {10,1},
    {14,1},
  }
})
function blueberry_lane:left()
  return schoolhouse_entrance
end
function blueberry_lane:right()
  return fountain
end

fountain=stage:new({tile_sx=65,tile_sy=0,})
function fountain:left()
  return blueberry_lane
end
function fountain:right()
  return rosemary_way
end

rosemary_way=stage:new({
  tile_sx=32,tile_sy=0,tile_w=33,
  palette_swaps={
    {14,4},
    {2,4},
    {10,15},
    {8,15},
    {12,15},
    {1,9},
  }
})
function rosemary_way:left()
  return fountain
end
function rosemary_way:right()
  return library_entrance
end

library_entrance=stage:new({
  tile_sx=81,tile_y=0,
})
function library_entrance:left()
  return rosemary_way
end
function library_entrance:right()
  return cemetery_path
end

cemetery_path=stage:new({
  tile_sx=97,tile_sy=0,
})
function cemetery_path:left()
  return library_entrance
end
function cemetery_path:right()
  return cemetery
end

cemetery=stage:new({
  tile_sx=0,tile_sy=16,
})
function cemetery:left()
  return cemetery_path
end

room=stage:new({left=true})
function room:draw()
  map(self.tile_sx,self.tile_sy,0,0,self.tile_w,self.tile_h)
end
function room:exit_left()
  fade_to(function()
    current_stage=self.door.return_stage
    pl.x=self.door.x
    pl.y=68
  end)
end
blueberry_lane_1=room:new({tile_sx=30,tile_sy=16,tile_w=9,tile_h=6,})
blueberry_lane_2=room:new({tile_sx=39,tile_sy=16,tile_w=9,tile_h=6,})
blueberry_lane_3=room:new({tile_sx=30,tile_sy=22,tile_w=9,tile_h=6,})
blueberry_lane_4=room:new({tile_sx=39,tile_sy=22,tile_w=9,tile_h=6,})


rosemary_way_1=room:new({tile_sx=31,tile_sy=16,tile_w=9,tile_h=6,})
rosemary_way_2=room:new({tile_sx=30,tile_sy=22,tile_w=9,tile_h=6,})
rosemary_way_3=room:new({tile_sx=30,tile_sy=16,tile_w=9,tile_h=6,})
rosemary_way_4=room:new({tile_sx=30,tile_sy=16,tile_w=9,tile_h=6,})

schoolhouse=room:new({tile_sx=16,tile_sy=16,tile_w=14,tile_h=9,})
function schoolhouse:draw()
  rectfill(8,8,103,63,15)
  rectfill(0,40,8,71,15)
  room.draw(self)
  color(7)
  print("marsupials",36,25)
  print("\137\137\137",35,40)
  print("\135", 70,40,14)
  rect(31,23,80,48,4)
  print("abcdefghilmnoprstuvwxyz",10,9,1)
end

library=room:new({tile_sx=48,tile_sy=16,tile_w=14,tile_h=9,})
function library:draw()
  rectfill(8,8,103,63,15)
  rectfill(0,40,8,71,15)
  room.draw(self)
end
-->8
--todo

--add last-word hooks

--move all ghosts to fountain
--give ghosts goodbyes
--script ghost's exit

--figure out an intro!

--add title screen
--add voices maybe

-- fix rosetta's starting position (and erwin's) (and muriel's)
-- make erwin poof into a ghost cloud

-->8
--game state

states = {}

states.game = {}

function states.game:update()
   current_stage:update()
   if (not speaking) then
    pl:update()
    if (btnp(b.z) and has_book) then
     book:page_to(book.ghost_idx)
    	fade_to(function()
     state=states.book
     end)
    end
   end
   if (speaking) dialog:update()
   foreach(current_stage.actors, function(actor)
     actor:update()
   end)

   foreach(sugars, sugar.update)
   foreach(pl.sugars, sugar.update)
 t+=1
end

function states.game:draw()
 cls()
 set_camera()
 current_stage:draw()
 foreach(current_stage.actors, function(actor)
   actor:draw()
 end)

 pl:draw()
 foreach(sugars, sugar.draw)
 foreach(pl.sugars, sugar.draw)

 dialog:draw()
end
-->8
--book state


book={}
states.book=book

book.book_rec=dialog:new({x=16,y=56,w=110,h=16})
book.epitaph=dialog:new({x=16,y=80,w=110,h=32})

function book:update()
	if (btnp(b.left)) then
	 self:page_to(max(book.ghost_idx-1, 1))
	end

	if (btnp(b.right)) then
	 self:page_to(min(book.ghost_idx+1,#ghosts))
	end

	if (btnp(b.z)) then
		fade_to(function()
	 	state=states.game
		end)
	end


end

function book:page_to(idx)
 book.ghost_idx=idx
 local ghost=ghosts[idx]
 book.epitaph.message="\""..ghost.last_words.."\""
 book.epitaph.line_index=0
 book.epitaph.index=0
 book.epitaph:rush()
 book.book_rec.message=ghost.favorite_book
 book.book_rec.line_index=0
 book.book_rec.index=0
 book.book_rec:rush()
end

function book:draw()
	cls()
	rectfill(0,0,255,255,1)
	rectfill(0,2,124,124, 4)
	rectfill(0,4,122,122,15)
	rectfill(0,4,6,122,5)
	rectfill(8,4,10,122,5)
	line(13,4,13,122,5)

	local ghost=ghosts[book.ghost_idx]
	local tmpx=ghost.x
	local tmpy=ghost.y

	ghost.x=64-(ghost.spr_w*4)
	ghost.y=32-(ghost.spr_h*4)

	if (not ghost.met) then
		pal({
		[6]=1,
		[7]=1,
		[13]=1
		})
	else
		pal()
	end

	ghost:draw()

	ghost.x=tmpx
	ghost.y=tmpy

	local name="???"
	if (ghost.met) name=ghost.name

	print(
	name,
	64-(#name*2),
	12,
	2
	)

 if ghost.finished then
 	print("favorite book:",16,50)
	 print(book.book_rec.message)
		print(book.epitaph.message, 16,80)
 end

	print(book.ghost_idx, 64,116)
	if (book.ghost_idx > 1) then
		print("⬅️", 105,116)
	end

	if (book.ghost_idx < #ghosts) then
		print("➡️", 114,116)
	end
end

-- title screen

title={}
states.title=title

function title:init()

end

function title:update()
	t+=1
	if btnp(b.z) then
		fade_to(function ()
			state=states.game
		end)
	end
end

function title:draw()
	fountain:draw()
	print("last words",
		42,
		26,
		7)
	print("press z to end",
		32,
		40
	)
end
-->8
--builtins

function _init()
 dialog.message=dialog.phrases[dialog.phrase_index]
 current_stage=schoolhouse_entrance
 initialize_actors()
 pl = player:new({x=30,y=20})
 state = states.title
 book.ghost_idx=1
end


function _draw()
	state.draw()
 if (fading) fade_palette()
 if (wiping) wipe:draw()
end

function _update()
	timeout_update()

 if fading then
   fade_update()
 elseif wiping then
   wipe:update()
 else
  state:update()
 end
end

function timeout_update()
	if timeout_fn then
		timeout-=1
		if timeout<1 then
			timeout_fn()
			timeout=0
			timeout_fn=nil
		end
	end
end
-->8
--sugar mode
sugar_mode=false

sugar=entity:new({
 x=0,
 y=0,
 w=0,
 h=0,
 dx=0,
 dy=0,
 moon=nil,
 gravity=0.1
})

function sugar:draw()
 if sugar_mode or pl.flying then
 	pset(self.x,self.y,7)
 end
end

function sugar:update()
 if self.moon then
  self:lerp_to(self.moon,0.06)

  local xwiggle=(rnd(2)-1)
  local ywiggle=(rnd(2)-1)

  self.dx+=self.ax
  self.dy+=self.ay
  self.dx*=0.9
  self.dy*=0.9

  if t%5==self.id%5 then
  self.dx+=xwiggle
  self.dy+=ywiggle
  end
 else
   self.dy+=self.gravity
 end
 self.x+=self.dx
 self.y+=self.dy

 if (self.y>128) del(sugars,self)
 if (#sugars > 50) del(sugars,sugars[1])
 if (#pl.sugars > 50) del(pl.sugars,pl.sugars[1])
 if dist(self, pl) < 8 and not (self.moon==pl) then
  add(pl.sugars, self)
  del(sugars, self)
  self.moon=pl
  self.dy=0
  sfx(4,-1,
  ((#pl.sugars-1)%8)*2
  ,2)
  sfx(5,-1,
  ((#pl.sugars-1)%8)*2
  ,2)
 end
end

function add_sugar(x,y)
	add(
	sugars,
	sugar:new({x=x,y=y,id=#sugars,moon={x=x,y=y,w=0,h=0}})
	)
end

-- distance between the center
-- of two entities
function dist(a,b)
	local x=(a.x+a.w/2)-(b.x+b.w/2)
	local y=(a.y+a.h/2)-(b.y+b.h/2)

 return sqrt(x*x+y*y)
end

--turns out this isn't being used
--properly but I'm gonna leave it
function lerp(a,b,weight)
	return (1-weight)*a+weight*b
end

function lerp_points(a,b,weight)
 return {
 	x=lerp(a.x+(a.w/2),b.x+(b.w/2),weight),
 	y=lerp(a.y+(a.h/2),b.y+(b.h/2),weight)
 }
end

function set_timeout(frames,callback)
 timeout=frames
 timeout_fn=callback
end

function center_sugars()
 foreach(pl.sugars, function(sugar)
		sugar.x=pl.x
		sugar.y=pl.y
 end)
end
__gfx__
00eeee00000000000000000000eeee000000000000eeee00333333330000b00000000000000000000000000000000000333f3f3fffffffff0000000000000000
0eeee4e000eeee0000eeee000eeee4e0e0eeee000eeeeee03333333300b0b0b000000000000000000000000000000000f3f333f3ffffffff0000000000000000
0e4b4be00eeee4e00eeee4e00e4b4be0eeeee4e00eeeeee45335533303b3b3b00000000000000000000000000000000053355f3f9ff99fff0000000000000000
0e4444e00e4b4be00e4b4be04e4444e4ee4b4be00eeeeee425524535b3bbb3b30000000000000000000000000300303025524539299249f90f00f0f00f00f0f0
eee44ee00e4444e00e4444e04ee44ee44e4444e40eeeeeee42242452333333330000000000000000000000003333333342242492422424923f3f3fffffffffff
ee6aa6e0eee44ee0eee44ee0e46aa6404ee44ee44eeeeeee44444224333333330008080000007000000a5a00333333334444422444444224f3f3ff3fffffffff
04aaaa40ee6aa6e0ee6aa6e000aaaa00046aa64004aeee00444444443333333300088800000777000005a5003333333344444444444444443fff3fffffffffff
04aaaa4044aaaa4004aaaa4000aaaa0000aaaa0000aaaa0044424442333333330000800000007000000a5a00333333334442444244424442f3f3f3f3ffffffff
00aaaa0000aaaa04004aaa0000aaaa0000aaaa0000aaaa004242424242424242424242423f3f3fffffffffff00000000f33333f300ffffff000000001288ac88
00aaaa0000aaaa0000aaaa0000aaa40000aaa40004aaaa00242424242422242222222222f3f3ff3fffffffff000000003333333300ffffff000000001288ac88
0040040000044000044004000040004000400040040004004242424242424242242424243fff3fffffffffff000000003333f33f0fffffff000000001222e222
004004000004000000000040040004000400040000000400242424242224222422222222f3f3f3f3ffffffff0300303033333333ffffffff0000000011111111
0060000000000000000000000000000000000000000000004242424242424242424242423f3f3fffffffffff33333333333333f3ffffffff00000f0f88ac8812
066006000000000000000000000000000000000000000000242424242422242222222222f3f3ff3fffffffff3f3333f3333f3333ffffffff00000fff78ac8812
0066600000000000000000000000000000000000000000004242424242424242242424243fff3fffffffffff333333333333333fffffffff0000ffff47722212
006060000000000000000000000000000000000000000000242424242224222422222222f3f3f3f3ffffffff333f333333333f33ffffffff000fffff44471111
1288ac887628ac881288ac88754444451288ac770000000700000007dd666dd5777777777611222222221167777777777728ac88544444571288ac674447ac88
1288ac887628ac881288ac887544444512887755000000760000007d5666665ddd666ddd7612277777722167dd666ddd5577ac88544444571288ac6744447c88
1222e2227622e2221222e222754444451227554500000765000007ddd55555dd6666666576227009900722676666666554557222544444571222e26744447222
11111111761111111111111175444945117544450000765d000076666dd5dd665666665d76270099a90072675666665d54445711549444571111116744447111
88ac881276ac881288ac88127544494588754445000755dd00075666665d5666d55555dd768700999a007867d55555dd544457125494445788ac886744447812
88ac881776ac881288ac881275444945875444450075dd66007dd55555ddd5556dd5dd6676870999999078676dd5dd66544445725494445788ac886744447812
22e2277476e2221222e222127544444527544445075d56660777777777777777665d5666768700999900786777777777544445725444445722e2226744447212
111174447611111111111111754444457544444575ddd555666666666666666655ddd55576870000000078676666666654444457544444571111116744447111
128874447628ac877728ac8870000000700000007628ac881288ac881288ac6712874444444472887288ac8875444445544444571288ac777288ac6733333333
128744447628ac757572ac8867000000d70000007628ac881288ac881288ac6712874444444472885728ac8875444445544444571288a7575788ac6733333333
122744447622e2757572e22266700000dd7000007622e2221222e2221222e26712274444444472225722e22275444445544444571222e7575722e26733b3333b
1117444476111177777111115667000066d7000073113131131131311311313713173434434431317711111173443435534434371111177777111167b33b33b3
88a7444476ac887575728812d55d7000666d7000333333333333333333333333333333333333333357ac8812333333333333333388ac875757ac886733333333
88a7494476ac887575728812dd56670055566700333333333333333333333333333333333333333357ac8812333333333333333388ac875757ac886733333333
22e7494476e222777772221265d5667077777770333333333333333333333333333333333333333377e22212333333333333333322e2277777e2226733333333
1117444476111111111111115ddd55d7666666663333333333333333333333333333333333333333111111113333333333333333111111111111116733333333
76555555555555555555556755777555555557644445544446755555555555555555555555555555000000000000000000000000000000000000000000000000
7655bd852dd52d55bd85bd67272727d52d5576444445544444672d552dd52d552d552d552dd52dd5000000000000000000000000000000000600006000000000
76d52dd52dd52dd52dd52d67271727d52dd574444445544444472dd52dd52dd52dd52dd52dd52dd5000000000000000000000000006666000066660000666600
762552b55225522552b5526757777725522764444445544444467225522552255225522552255225000007777777777777700000066d7d00006d7d00006d7d00
76555555555555555555556757172755555764444445544444467555555555555555555555555555000776666666666666677000666777000067770000077700
76bd55bdd52d552d85bd5567d717172dd5276444494554944446752dd52dd52dd777777dd52dd52d0776652dd52d552dd5266770666666000006600000766000
762dd52dd52dd52dd52dd567d777772dd5276444494554944446752dd52dd52776666667752dd52d766dd52dd52dd52dd52dd667007667000076670000066700
7652b552255225522552b56725522552255764444945549444467552255225766445544667522552765225522552255225522567007070000060600000707000
333336666666666666633333555555555557644444455444444675557655555555555567ffffffff00000000000000000000000000000d000000000000000000
3333666666666666666633332dd52d552dd764444445544444467dd576d52d552dd52d67ff66669f0000000000000000000000000000666d77d0000000000000
333dddddddddddddddddd3332dd52dd52dd764444445544444467dd576d52dd52dd52d67f66dd66900777d000007d00000000000000007666660000000000000
333d3d3dd3dd3d3dd3d3d333522552255227644444455444444672257625522552255267f6666669077777d00007d00000000000000007777766d00000000000
333333333333333333333333555555555566666666666666666666557655555555555567f6dd6d6900777d00077777000000000000000dd7dd76000000000000
333333333333333333333333d52d552dd6666666666666666666666d762dd52dd52d5567f6666669000007d000777d0000000000000007777770000000000000
333333333333333333333333d52dd52ddddddddddddddddddddddddd762dd52dd52dd567f6f66f69000000000007d00000000000000007777700000000000000
333333333333333333333333253235525ddddddddddddddddddddddd7352353223523537ffffffff000000000000000000000000000000077000000000000000
00000000000000000005500000000000000550001777ac67000000000000900076ca777100000000000000003333333300000000000007777dd0000000000000
000000000000000000055000000000000055550075757c670000000000b0909076c75757000000000000000033333333000000000000777dddd7000000000000
0000000000000000000550000000000055555555757572670000000003b39f90762757570000000000000000333333330000000000077dddd667700000000000
03003030030030300305503003003030c555555c7777716703003030b3bb9f9f76177777000000000000000033333333000000000007dddd6667700000000000
33333333333333333355553333333333cccccccc75757867337777333f3f3fff7687575700000006669000003333333300000000007777777777777000000000
33555555555555555555555555555533555555557575786755171755f3f3ff3f7687575700000066666900003333333300000000007777777777777000000000
35ccccccccccccccc555555ccccccc535555555577777267cc7777cc3fff3fff7627777700000666666690003333333300000000000777777777770000000000
5cccccccccccccccccccccccccccccc55555555511111167cccc6cccf3f3f3f376111111000066dd6dd669003333333300000000000067676767600000000000
5555555555555555000000005555555500000000000000005577775500009000ffffffff00006666666669002244224404400000000067676767600000000000
5555555555555555000000005555555500000000000000005755657500909090ffffffff00006d6dd6dd69004444444404400000000067676767600000000000
555555555555555555555555555555550055555555555500575777570f9f9f90ff9ffff900006666666669004444444404400000000067676767600000000000
3535553553553535cccccccc5355535305cccccccccccc50555565559f999f9f9ff9ff9f00006ddd6d6d69004244424404400000000067676767600000000000
3333333333333333cccccccc333333335cccccccccccccc533677733ffffffffffffffff00006666666669004422442204400000000067676767600000000000
33333333333333335555555533333333555555555555555533367333ffffffffffffffff00f06f6666f66f002424242404400000000777777777770000000000
33333333333333335555555533333333555555555555555533733733ffffffffffffffffffffffffffffffff4242424204400000007777777777777000000000
33333333333333335555555533333333055555555555555037337333ffffffffffffffffffffffffffffffff2424242404400000007777777777777000000000
ddcccddd000762400000000000000000000000000000000000000000000000000666666003666660000000000000000000000000068888860000000000000000
dddcdddc0007624000111100000000000000000000000000000000006666666606dd666003333330000000000000000000000000006666600000000000000000
cdddddcc0007624001111110000000000000000000000000000000006d66dd660666666044444444000000000000000606000000444444440000000000000000
dddcdddc000762400d1111d0000000000000000000000000000000006ddd66d606dddd60222222200000000000060606c6060600222222220066066000000000
ddcccddd00076240dd1111dd0000000000000000000000000000000066d66dd60666666044444400000000000556a656c656b655444444440006860000000000
dddcdddc00076240dddddddd000000000000000000000000000000006d66ddd606dddd6044444400000000000506a606c606b605444444440006860000000000
cdddddcc00076240dddddddd0000000000000000000000000000000066666666066d6d6044444400000000000506a606c606b605444444440068886000000000
dddcdddc0007624002000020000000000000000000000000000000000000000006666660444444000333333005006006c606b605444444440688888644444444
dddddddd000000000000000000000000000000000000000000000000000000000000000000000000000000000500000060006005400000000000000000000004
be8dbedd000000055555555550000000000011111111000000100000000001000070000070000000000000000555555555555555400000020006002000d00034
3eed3eed0000005cccccccccc500000000011111111110000d110000000011d00000000000000000000000004444444444444444400000d2d016502505d06034
d3bdd3bd0000005cccccccacc5000000000d11111111d0000d110000000011d070000000000000000000400002222222222222224ddd00d2d216532505d16534
dddddddd000000533ecec3333500000000dd11111111dd000dddd000000dddd00000000000700000220404000044444444444444455550d2d216532505d16534
8dbeddbe00000053333333333500000000dddddddddddd000ddddd0000ddddd00700000000000000002400000044444444444444455555d2d21d53155051d134
ed3eed3e00000005555555555000000000dddddddddddd000ddddd0000ddddd00000000000000000044240000044444444444444411111d2d216532550d16534
bdd3bdd300000000000000000000000000020000000020000200200000020020060666000606660040dd04000044444444444444444444444444444444444444
2444444444444444444444442400246776240024000000000000000000000000006660600000000040dd00000055500000000000400000000000000000000004
242224222224222222422224240024677624002404200000000000000000024000066600066006600dddd0000555550000000000410002000015150010000004
240004000004000000400024244444677624444404200000444444440000024044444444444444440dddd000551115500000000041060230dd15150613000004
2400040000040000004000242400246776240024042000000004200000000240000420000004200000dd000051555150000000004156d230dd1515261300ddd4
240024444444444444440024240024677624002404200000000420000000024000042000000420000444440051111150000000004156d230dd15152613055554
2444442222222222222444442400246776240024044444000004200000444440000420000004200004204200555555500100001041d6d1032251512613666664
240024666666666666240024240024677624002404204200000420000024024000042000000420000420420055511150050000504156d203dd15152613222224
24002467777777777624002424002467762400240420420000444400002402400044440000444400042042005951515005000050444444444444444444444444
444444445555555500000000000000000000000000000000000000004c444c400000000000000000000000005951515005555550000000000000000000000000
222242221115111500055500000555000000000000000024007770006c777c600005550000055500000000005551115005000050000000000000000000000000
44442444555555550051115000511150000000000000066407575700cc575cc00053335000533350000000005555555005555550444444444444444444444444
22422242511151110051f1500051f4505333333333333354075757006c575c60005f3350005d3f50005555505111115005000050022222222222222222222220
24444244555555550053315000511250244444444444444407777700cc777cc000523f5000531150005666505155515005555550004444444444444444444400
424224421115111500533150005122502400000000000024075757006c575c600052215000533150005666505155515005000050004444444444444444444400
24244224555555550005550000055500240000000000002407575700cc575cc00005550000055500005555505111115005555550004444444444444444444400
224222425111511100000000000000002400000000000024077777006c777c600000000000000000000000005555555005000050004444444444444444444400
0077770000000000000000000000077770000000000000000000000000000000000000000000000000000000006666000000070070000000000dd000ddd00000
0ddd7ddd0000000000000000000077d7d70000000000000000000000000000000000000000000000000000000666676000007000070000000000dd0ddd000000
0d7ddd7d00000000000000000000777777000000000677700000000000000000000000000000000000000000067d7d60000007777000000000000ddddd00dd00
0ddd7ddd000000000000000000007d777d00000000677777000000000000000000000000000000000000000066777766000077777700000000ddd67777dddd00
067777700000000777000000000067ddd70000000067d7d700000000d7700000000000000000000000000000660770660000d7777d0000000ddd6777777dd000
00677700000000677d7000000000067770000000777777770000000777d70000000000000000000000000000006666000000dd77dd000000000d6dd7dd7d0000
000770000000006d7770000007700077000000000677dd770007770777770000000000000000000000000000076666700000dd77dd0000000ddd6777777ddd00
00677700000000677770000070000677700000700066777000d7d7777776000000000000000000000000000007666670000007777000000000dd6777777dd000
0677777000000006770000007007677777000707000000000077777076607770000000000000000000000000006666000000667760000000000d67ddd7700000
06777770000000007770070070706777777007000000700700777760000777770000000000000000000000000066660000006677600000000000d67777d00000
067777700000000677707070707067777707070000007d7d0007660777077d7d000000000000000000000000007007000000000777000000000dddd7dddd0000
06777770000000600677706770706777770707000700777707770077777777760000000000000000000000000070070000000777777700000000000700000000
0677777000000000067000000700067770007000700007707d7d707d777076600000000000000000000000000000000000007077777070000000000700dddd00
067777700000000000070000000006777000000007777770777770777d6000000000000000000000000000000000000000000007770000000000000076ddd000
0677777000000000067700000000007700000000007777707777600766000000000000000000000000000000000000000000007000700000000dddd070dd0000
06707070000000000600000000000677700000000070707007660000000000000000000000000000000000000000000000000777077700000000ddd670000000
000777700000000000000000000000000000000000000000000000007777000000000000000000000000000000000000000007777700000000000dd700000000
0077d7d0000000000000000000000000000000000000000000000000770070000000000000000000000000000000000000077777777700000000000700000000
00777770000000000000777000000000000000000000000000000000000070000000000000000007000000000000000007777777777777000000000700000000
07777000000000000006777700000000000000000066066000000000000007000000000000000077700000000000000067777777777777600000000000000000
70700700000667067767777700000007777760000006060000000000000077700077770000000760700000000000000006777777777776000000000000000000
7077070000677777777dd7dd000000777777760066677766600000000077dd700777777000077677767000000000000000067777777600000000000000000000
706007000067777777777777000000d7d7777600067d7d7600000000077ddd700777777007776777767700000000000000000677760000000000000000000000
70770700000777077700777000000077777777600077777000000000077777777777777007767777776770000000000000000077700000000000000000000000
7070070000000000000000000000000777777760667ddd76600000006677770777777770777677777767700000000000000007777700000000000eeeeee00000
00670000000000000000000000000000007777770667776600000000606777006677777777677777777670000000000000007077707000000000e555555e0000
0777700000000000000000000000000077077707000070000000000006000000006666776677777777776600000000000000707770700000000eeddddddee000
07007000000000000007770000000000700707000dd070dd0000000000000007777760660666666666607760000000000000707770700000000eeeeeeeeed000
07007000000000000077d7d0000000000007070000dd7dd00000000000000077000660007700600000000706600000000000707070700000000eeeeeeeede000
07007000066660000077777000000000007007000000700000000000000000700660000000770666000000700600000000007070707000000000eeeeeeee0000
0700700067d7d70000777770000000000070070000007000000000000000777066000000000070060000000700600000000000707000000000000eeeeee00000
070070006777770000707070000000007770770000077700000000000077700660000000000077706600000700600000000000707000000000000e0000e00000
__gff__
0000000000000100000000000101000000000000000001010100000000000002020202000200000000000000020002020202020000020202020202000002020000000000000000000000000000000000000000000000000000000000000000000000000000020000020000000000000000000000000000000000000100000000
0101000000000000000000000000000001000000000000000000000000000000010101010100000000000000000000000101000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000025330000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000002627273400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000292a000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000004a4b4b4b4b4b4b4c0000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000252828282833000000000000000000000000000000000000000000000000000000000000000000252828283300000000000000000000000000000000000000004a40414141414141424c00000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000026272727272727340000000000002528282833000000000000000000000000252828282833000026272727272734000000000000000000000000000000000000004040434141434143424200000000000000000000000000000000000000000000000000000000000000000000
000000000000000000000000000000000000000021222222222e0000000000002627272727273400262b2b2b2b2b2b340026272727272727340000213d3a3d3e00000000000000007472750000000000000000004040414748494141424200000000000000000000000000000000000000000000000000000000000000000000
00080900000000000000000000000a00000009003132242c3d3e000000000a000021201f222e000000212222201f2e00000021201f22222e0000002122201f2e00000000000000747264727500000000000000004040434445464143424200000000000000000000000000000000000000000000000000000000000000000000
070707070b0b0b0b0b0b0b0b0b07070b0b07070b2122232d222e0b0b0b0707070721302f3d3e070b07313222302f2e0b070721302f3d3a2e070b073132302f2e07070b07070b606266626162630b0b070b070707575753545556535358580707070707070b0b0b1b1b0e0e670e0e0f7777000000000000000000000000000000
6b3f6b6b3f6b6b6b6b6b6b6b3f3f6b6b3f6b6b3f35363b3c36376b6b6b3f3f6b3f35383936376b3f3f3536363839373f6b6b3538393636376b3f3f35363839373f6b3f3f6b3f707176717171733f3f6b3f3f6b3f3f6b50515151523f6b3f3f6b3f6b6b3f3f6b3f6b1c19191919191a1a78000000000000000000000000000000
0606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060606060c0c0c0c0c0d0d0d000000000000000000000000000000
7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b000000000000000000000000000000
1717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717000000000000000000000000000000
1717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717171717000000000000000000000000000000
1818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818000000000000000000000000000000
1818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818181818000000000000000000000000000000
00000000000000000000000000000000a0a1a1a1a1a1a1a1a1a1a1a1a1a2a0a1a1a1a1a1a1a1a2a0a1a1a1a1a1a1a1a2a0a1a1a1a1a1a1a1a1a1a1a1a1a2a0a1a1a1a1a1a1a1a2a0a1a1a1a1a1a1a1a2a0a1a1a1a1a1a20000000000000000000000000000000006060606060606060606060606060606000000000000000000
00000000000000000000000000000000a3000000000000000000000000a4a300000000000000a4a300000000000000a4a300000000ac8f8f8f8f8f8f8fa4a300000000000000a4a300000000008100a4a30000000000a4000000000000000000000000000000007b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b000000000000000000
00000000000000000000000000000000a3000000000000000000000000a4000000b600000000a40000b6000000b600a4a300000000bc9d9e9e9e9eaeafa40000b60000b60000a40000b600b6008100a4a300b600b600000000000000000000000000000000000017a0a1a1a1a1a1a1a1a1a1a1a1a1a217000000000000000000
00000000000000000000000000000000a30000006b6b6b6b6b6b000000a400009800b2b30000a4000000b8b90000b3a4a300b60000bc9dae9e9eaeae9fa4000000009a00b9b8a400000000000081aba4a30000980000000000000000000000000000000000000017a300000000000000000000bc00a417000000000000000000
00000000000000000000000000000000a30000006b6b6b6b6b6b000000a400a5a8a70000b4b5a40000009495009700a4a300000000bcad9e9eae9e9eafa400009495aa00a6a7a40000a5a6a70081bba4a300a5a8a700000025282828282833000000000000000018a300000000000000000000bc00a418000000000000000000
00000000000000000000000000000000000000006b6b6b6b6b6b008f8fa4b0b0b0b0b0b0b0b0b0b1b1b1b1b1b1b1b1b10000000000bcad9e9e9eaeae9fa4b0b0b0b0b0b0b0b0b0b1b1b1b1b1b1b1b1b1b1b1b1b1b1b1b12627272727272727340000252828330018a300870000000000008700bc00a418000000000000000000
00000000000000001e0f77770f0f777700000000000000000000009d9fa4a0a1a1a1a1a1a1a1a2a0a1a1a1a1a1a1a1a200ba000000bc9dae9e9e9e9e9fa4a0a1a1a1a1a1a1a1a2a0a1a1a1a1a1a1a1a20000000000000000213d3a223d3a2e000026272727273418a38f8f0088880000000000bc88a418000000000000000000
0000000000001e771d1a1a1a1a1a781a0000000000bdbebebf0000adafa4a300000000000000a4a300000000000000a40000bdbebfbcad9eaeae9eaeafa4a300000000000000a4a300000000000000a4000000000000000068201f22201f6500000021201f2e0018a39d9fdedf000087880000bc00a418000000000000000000
770f0f7777771d591a1a1a1a78785978b0b0b0b0b0b0b0b0b0b0b0b0b0b00000b7000000b700a4000000b700919293a4b0b0b0b0b0b0b0b0b0b0b0b0b0b00000b7000000b700a40000b6000000b600a4000000000000000721302f22302f2e07070b21302f650718a3ad9feeef668b8c8e8a88bc00a418000000000000000000
78781a1a1a78591a1a1a781a591a787800000000000000000000000000000000009192930000a400b2b30000000000a400000000000000000000000000000000009a00b80000a400009192930000b3a4000000000000003f353839363839373f3f6b353839376b18a3adaffeff769b9c8d8900bc00a418000000000000000000
0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0d0000000000000000000000000000000000a5a9a70000a40000949500a5a9a7a40000000000000000000000000000000082aa8200b4b5a40000a5a6a700b4b5a4000000000000000606060606060606060606060606060618b1b1b1b1b1b1b1b1b1b1b1b1b1b118000000000000000000
7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b000000a0a1a1a1a1a1a1a2000000b1b1b1b1b1b1b1b1b1b0b0b0b0b0b0b0b0b00000000000000000000000000000b1b1b1b1b1b1b1b1b1b0b0b0b0b0b0b0b0b0000000000000007b7b7b7b7b7b7b7b7b7b7b7b7b7b7b7b18181818181818181818181818181818000000000000000000
17171717171717171717171717171717000000a3000000000000a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001717171717171717171717171717171718181818181818181818181818181818000000000000000000
17171717171717171717171717171717000000a3000000000000a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001717171717171717171717171717171718181818181818181818181818181818000000000000000000
18181818181818181818181818181818000000a3000000000000a40000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001818181818181818181818181818181818181818181818181818181818181818000000000000000000
18181818181818181818181818181818000000b1b1b1b1b1b1b1b10000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001818181818181818181818181818181818181818181818181818181818181818000000000000000000
__sfx__
000600001c5501f5501c550205501c550215501c550225501c550235501c550255501c55026550015000050000500005000250002500025000250002500015000050000500005000750003500075000350003500
01060000285502c550285502d550285502e550285502f550285503155028550335502855034550000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
010600000c750187500c7501a7500c7501c7500c7501d7500c7501f7500c750217500c750237500c7502475000700007000070000700007000070000700007000070000700007000070000700007000070000700
010600001875024750187502675018750287501875029750187502b750187502d750187502f750187503075000700007000070000700007000070000700007000070000700007000070000700007000070000700
00060000187501c7501a7501d7501c7501f7501d750217501f7502375021750247502375026750247502875024750287502675029750287502b750297502d7502b7502f7502d750307502f750327503075034750
0106000024750287502675029750287502b750297502d7502b7502f7502d750307502f75032750307503475000700007000070000700007000070000700007000070000700007000070000700007000070000700
010c0000297202a7202f72030720007200172002720257203072033720187301a7301362016620136201062000700007000070000700007000070000700007000070000700007000070000700007000070000700
010c000018520195201a5201b5501c5501d5501e5501f550205502155022550235502455025550265502755028550295502a5502b5502c5502d5502e5502f5503055031550325503355034550355503655037550
011000002675024750187501f7502475026750287502675024750187501f7502475026750287502675024750187501f7502475026750287502675024750187501f75024750267502875026750247502875000000
__music__
00 05424344
04 04424344

