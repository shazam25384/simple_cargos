-- simple cargos Shazam253 - 2026-10-19 - MIT License
-- put at mission start to init global variables and such
-- install sounds by opening .miz file with archiver, 
-- i.e. 7zip and adding the sounds folder to it.

-- voice-overs made with voicemaker.in using basic Luna AI voice

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
--                      mission setup part
--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

-- specify one red, one blue for each cargo
sling_cargos={
  ['APC']={'BRDM-2','TPZ'},
  ['IFV']={'BMP-2','Marder'},
  ['AAA']={'ZSU-23-4 Shilka','Gepard'},
}
-- specify masses for above cargo groups
sling_masses={
  ['APC']=1000.,
  ['IFV']=2000.,
  ['AAA']=3000.,
}

-- line-up cargos
line_cargos={
  ['APC']={'BRDM-2','M-2 Bradley'},
  ['LTV']={'HL_KORD','M1043 HMMWV Armament'},
}

-- cargos that are loaded internally
internal_cargos={
  ['LTV']={'HL_KORD','M1043 HMMWV Armament'},
}

-- again, specify masses for said cargo groups
internal_masses={
  ['LTV']=2000.,
}

-- specify troops
troops={
  ['AT Squad']={{'Soldier AK','Soldier AK','Soldier AK','Soldier RPG','Soldier RPG',}, {'Soldier M4','Soldier M4','Soldier M4','Soldier RPG','Soldier RPG',}},
  ['AA Squad']={{'Soldier AK','Soldier AK','Soldier AK','SA-18 Igla-S manpad','SA-18 Igla-S manpad'}, {'Soldier M4','Soldier M4','Soldier M4','Soldier stinger','Soldier stinger'}},
}

-- pickup zones
zones={
  {'RedFARP','RedSupply','RedBackup'},
  {'BlueFARP','BlueSupply'},
}

skill='Excellent'

-- the distance at which new cargo is placed
cargo_offset=20.
-- unpack vicinity
unpack_distance=50.
-- maximum height above ground to unpack things
agl_max=5.
-- length of displayed messages
disp_message=15
-- the maximum amount of crates and cargo a helo can spawn at the same time
max_spawn=3

--+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
-- internal 'fixed' values
cid=5000
ud2=unpack_distance*unpack_distance

cargo_ac={'C-130J-30'}

helo_spawned={}
helo_internal_masses={}
helo_internal_cargos={}

-----------------------------------------------------------------------
--                            check_cargo
-----------------------------------------------------------------------

local function check_cargo(args)
  helo_name=args[1]
  local helo=Unit.getByName(helo_name)
  local uid=helo:getID()
  if helo ~= nil then
    if helo_internal_cargos[helo_name] ~= nil then
      local msg='Your loading list: ('
      for c,cargo in pairs(helo_internal_cargos[helo_name]) do
        msg=msg .. ' ' .. cargo
      end
      trigger.action.outTextForUnit(uid,msg .. ' ) with a total mass of ' .. helo_internal_masses[helo_name] .. ' kg or ' .. helo_internal_masses[helo_name]*2.2 .. ' lbm',disp_message,false)
      trigger.action.outSoundForUnit(uid,'simple_cargos/checklist.ogg')
    else
      --net.dostring_in('mission', string.format("a_out_picture_for_unit('%d','timer/empty.png',  1., false, 0, 0, 2, 10, '1')",uid))
      -- trigger.action.outSoundForUnit(uid ,'cargo/empty.ogg')
      trigger.action.outTextForUnit(uid,'You have nothing loaded internally',disp_message,false)
      trigger.action.outSoundForUnit(uid,'simple_cargos/noload.ogg')
    end
  end
end --check cargo

-----------------------------------------------------------------------
--                             clear_cargo
-----------------------------------------------------------------------

local function clear_cargo(args)
  helo_name=args[1]
  local helo=Unit.getByName(helo_name)
  local uid=helo:getID()
  helo_internal_masses[helo_name]=nil
  helo_internal_cargos[helo_name]=nil
  helo_spawned[helo_name]=0
  trigger.action.setUnitInternalCargo(helo_name, 0.)
  trigger.action.outTextForUnit(uid,'Cleared internal cargo, your helicopter is empty now',disp_message,false)
  trigger.action.outSoundForUnit(uid,'simple_cargos/clearedcargo.ogg')
end -- clear_cargo


-----------------------------------------------------------------------
--                             clear_crates
-----------------------------------------------------------------------

local function clear_crates(args)
  helo_name=args[1]
  local helo=Unit.getByName(helo_name)
  local uid=helo:getID()
  local pos=helo:getPosition()
  local agl=pos.p.y-land.getHeight({x=pos.p.x,y=pos.p.z})
  local coal=helo:getCoalition()
  local cleared=false
  for i,so in pairs(coalition.getStaticObjects(coal)) do
        -- check distance to helo
    local sop=so:getPosition()
    local son=so:getName()
    local soc=so:getCategory()
    local distance2=(pos.p.x-sop.p.x)^2+(pos.p.z-sop.p.z)^2
    if soc==6 and distance2<ud2 and agl<agl_max then
      so:destroy()
      trigger.action.outTextForUnit(uid,'Removed nearby crate ' .. son,disp_message,false)
      cleared=true
    end --soc
  end -- so
  if cleared then
    trigger.action.outSoundForUnit(uid,'simple_cargos/clearedcrates.ogg')
  end
end -- clear_crates

-----------------------------------------------------------------------
--                             dismiss_troops
-----------------------------------------------------------------------

local function dismiss_troops(args)
  helo_name=args[1]
  local helo=Unit.getByName(helo_name)
  local uid=helo:getID()
  local pos=helo:getPosition()
  local agl=pos.p.y-land.getHeight({x=pos.p.x,y=pos.p.z})
  local coal=helo:getCoalition()
  local dismissed=false
  for g,grp in pairs(coalition.getGroups(coal)) do
    local dismiss_grp=false
    for u,unt in pairs(grp:getUnits()) do
      -- only AG troops
      local desc=unt:getDesc().category
      local un=unt:getName()
      if desc==2 and ( string.find(un,'_Soldier') ~= nil or string.find(un,'_Vehicle') ~= nil) then
        local up=unt:getPosition()
        local distance2=(pos.p.x-up.p.x)^2+(pos.p.z-up.p.z)^2
        if distance2<ud2 and agl<agl_max then
          unt:destroy()
          trigger.action.outTextForUnit(uid,'Troops dismissed ' .. un,disp_message,false)
          dismissed=true
          dismiss_grp=true
        end -- in vicinity
      end -- is soldier
    end --unt
    if dismiss_grp then
      helo_spawned[helo]=max(0,helo_spawned[helo]-1)
    end
  end -- so
  if dismissed then
    trigger.action.outSoundForUnit(uid,'simple_cargos/dismissed.ogg')
  end -- dismissed
end -- dismiss_troops

-----------------------------------------------------------------------
--                           load_cargo
-----------------------------------------------------------------------

local function load_cargo(args)
  helo_name=args[1]
  cargo_type=args[2]
  local helo=Unit.getByName(helo_name)
  local uid=helo:getID()
  local inzone=false
  if helo ~= nil then
    local pos=helo:getPosition()
    local agl=pos.p.y-land.getHeight({x=pos.p.x,y=pos.p.z})
    local coal=helo:getCoalition()
    for z,zone in pairs(zones[coal]) do
      local zn=trigger.misc.getZone(zone)
      local ur2=(zn.point.x-pos.p.x)^2+(zn.point.z-pos.p.z)^2
      if ur2<zn.radius^2 then
        inzone=true
      end
    end
    if inzone then
      if agl<agl_max then
        local total_mass=internal_masses[cargo_type]
        if helo_internal_masses[helo_name] ~= nil then
          total_mass=total_mass+helo_internal_masses[helo_name]
        end
        trigger.action.setUnitInternalCargo(helo_name, total_mass)
        helo_internal_masses[helo_name]=total_mass
        local i=1
        if helo_internal_cargos[helo_name] ~= nil then
          i=#helo_internal_cargos[helo_name]+1
        else
           helo_internal_cargos[helo_name]={}
        end
        helo_internal_cargos[helo_name][i]=cargo_type
        trigger.action.outTextForUnit(uid,'Loaded ' .. cargo_type .. ' into your helo',disp_message,false)
        trigger.action.outSoundForUnit(uid,'simple_cargos/loadedhelo.ogg')
        -- add cargo to counter
        helo_spawned[helo_name]=helo_spawned[helo_name]+1
      else --agl
          trigger.action.outTextForUnit(uid,'You are too high above a pickup zone!',15,false)
          trigger.action.outSoundForUnit(uid,'simple_cargos/toohigh.ogg')
      end -- agl
    else -- inzone
      trigger.action.outTextForUnit(uid,'You are not in a pickup zone!',15,false)  
      trigger.action.outSoundForUnit(uid,'simple_cargos/nopickup.ogg')
    end -- inzone
  end -- helo
end --load_cargo

-----------------------------------------------------------------------
--                             spawn_cargo
-----------------------------------------------------------------------

local function spawn_cargo(args)
  helo_name=args[1]
  cargo_type=args[2]
  cargo_mode=args[3]
  local helo=Unit.getByName(helo_name)
  local uid=helo:getID()
  local inzone=false
  if helo ~= nil then
    local pos=helo:getPosition()
    local psi=math.atan2(pos.x.z,pos.x.x)
    local x=pos.p.x
    local y=pos.p.z
    local agl=pos.p.y-land.getHeight({x=pos.p.x,y=pos.p.z})
    local coal=helo:getCoalition()
    local ctry=helo:getCountry()
    for z,zone in pairs(zones[coal]) do
      local zn=trigger.misc.getZone(zone)
      local ur2=(zn.point.x-pos.p.x)^2+(zn.point.z-pos.p.z)^2
      if ur2<zn.radius^2 then
        inzone=true
      end
    end
    if inzone then
      if agl<agl_max then
        if helo_spawned[helo_name]<max_spawn then
          psi=psi+math.pi
          if cargo_mode>0 then
            local psi_offset = helo_spawned[helo_name]*2.*math.pi/max_spawn
            x=x+cargo_offset*math.sin(psi+psi_offset)
            y=y+cargo_offset*math.cos(psi+psi_offset)
            if cargo_mode==1 then
              -- group table
              local grp_table = {
                ['uncontrollable'] = false,
                ['task']='Ground Nothing',
                ['route']={
                  ['points']={
                    [1]={
                      ['type']='Turning Point',
                      ['y']=x,
                      ['x']=y,
                      ['action']='Off Road',
                      ['task']={
                        ['id']='ComboTask',
                        ['params'] = 
                        {
                          ['tasks'] = 
                          {
                            [1] = 
                            {
                              ['enabled']=true,
                              ['auto']=false,
                              ['id']='EmbarkToTransport',
                              ['number']=1,
                              ['params']= 
                              {
                                ['y']=y,
                                ['x']=x,
                                ['zoneRadius']=embark_radius,
                              }, -- end of ["params"]
                            }, -- end of [1]
                          }, -- end of ["tasks"]
                        }, -- end of ["params"]
                      }, -- end of ["task"]
                      ['speed_locked'] = true,
                    }, -- 1
                  }, -- points
                }, -- route
                ['groupId']=cid,
                ['hidden']=false,
                ['units']={},
                ['y']=y,
                ['x']=x,
                ['name']=cargo_type .. ' ' .. cid,
                ['start_time']=0,
              } -- troops
              -- add units
              for t,troop in pairs(troops[cargo_type][coal]) do
                cid=cid+1
                grp_table['units'][t]={
                  ['skill']=skill,
                  ['type']=troop,
                  ['unitId']=cid,
                  ['y']=y+pos.x.z*t,
                  ['x']=x+pos.x.x*t,
                  ['name']='_Soldier ' .. cid,
                  ['heading']=psi,
                }
              end
              coalition.addGroup(ctry, 2, grp_table)
              trigger.action.outTextForUnit(uid,'Troops ' .. cargo_type .. ' are ready to embark, use F7 menu',disp_message,false)
              trigger.action.outSoundForUnit(uid,'simple_cargos/troopsready.ogg')
            else -- cargo_mode != 1
              cid=cid+1
              local grp_table={
                ['groupId']=cid,
                ['name']='V' .. cid,
                ['category']=2,
                ['hidden']=false,
                ['units']={
                  [1]={
                    ['unitId']=cid,
                    ['name']='_Vehicle ' ..   cid .. '-' .. cargo_type,
                    ['type']=line_cargos[cargo_type][coal],
                    ['y']=y,
                    ['x']=x,
                    ['heading']=psi,
                    ['skill']=skill,
                    ['playerCanDrive']=true,
                  }
                },
                ['start_time']=0,
              }
              coalition.addGroup(ctry, 2, grp_table)
              trigger.action.outTextForUnit(uid,cargo_type .. ' vehicle ready to load, cargo menu',disp_message,false)
              trigger.action.outSoundForUnit(uid,'simple_cargos/vehicleready.ogg')
            end -- cargo_mode == 1
          else -- cargo_mode==0
              cid=cid+1
              local cargo = {
                ['name']='C' ..  cid .. '-' .. cargo_type,
                ['type']='container_cargo',
                ['y']=y+pos.x.z*cargo_offset,
                ['x']=x+pos.x.x*cargo_offset,
                ['heading']=psi,
                ['mass']=sling_masses[cargo_type],
              }
              coalition.addStaticObject(ctry, cargo)
              -- add cargo to counter
              trigger.action.outTextForUnit(uid,'Placed cargo ' ..cargo_type .. ' in front of you, use F6 menu',disp_message,false)
              trigger.action.outSoundForUnit(uid,'simple_cargos/cargoinfront.ogg')
          end -- cargo_mode>0
          helo_spawned[helo_name]=helo_spawned[helo_name]+1
        else
          trigger.action.outTextForUnit(uid,'You already spawned enough cargos, go deliver!',disp_message,false)
          trigger.action.outSoundForUnit(uid,'simple_cargos/enoughcargos.ogg')
        end -- max_spawn
      else
        trigger.action.outTextForUnit(uid,'You are too high above a pickup zone!',15,false)
        trigger.action.outSoundForUnit(uid,'simple_cargos/toohigh.ogg')
      end -- agl max
    else
      trigger.action.outTextForUnit(uid,'You are not in a pickup zone!',15,false)
      trigger.action.outSoundForUnit(uid,'simple_cargos/nopickup.ogg')
    end -- inzone
  end -- helo
end -- spawn cargo

-----------------------------------------------------------------------
--                             unbox
-----------------------------------------------------------------------

local function unbox(args)
  helo_name=args[1]
  local helo=Unit.getByName(helo_name)
  local uid=helo:getID()
  local pos=helo:getPosition()
  local agl=pos.p.y-land.getHeight({x=pos.p.x,y=pos.p.z})
  local coal=helo:getCoalition()
  local cntry=helo:getCountry()
  local unpacked=0
  local inzone=false
  for z,zone in pairs(zones[coal]) do
    local zn=trigger.misc.getZone(zone)
    local ur2=(zn.point.x-pos.p.x)^2+(zn.point.z-pos.p.z)^2
    if ur2<zn.radius^2 then
      inzone=true
    end
  end
  if inzone then
    trigger.action.outTextForUnit(uid,'You cannot unpack in a pickup zone',disp_message,false)
    trigger.action.outSoundForUnit(uid,'simple_cargos/nounpack.ogg')
  else
    for i,so in pairs(coalition.getStaticObjects(coal)) do
      -- check distance to helo
      local sop=so:getPosition()
      local son=so:getName()
      local soc=so:getCategory()
      local distance2=(pos.p.x-sop.p.x)^2+(pos.p.z-sop.p.z)^2
      if soc==6 and distance2<ud2 and agl<agl_max then
        local gid=string.sub(son,2,5)
        local cargo_type=sling_cargos[string.sub(son,7,string.len(son))][coal]
        local x=sop.p.x
        local y=sop.p.z
        local psi=math.atan2(sop.x.z,sop.x.x)
        -- 
        local delivery={
          ['groupId']=gid,
          ['name']='D' .. gid,
          ['category']=2,
          ['hidden']=false,
          ['units']={
            [1]={
              ['unitId']=gid,
              ['name']='D' ..  gid .. '-' .. cargo_type,
              ['type']=cargo_type,
              ['y']=y,
              ['x']=x,
              ['heading']=psi,
              ['skill']=skill,
              ['playerCanDrive']=true,
            }
          },
          ['start_time']=0,
        }
        trigger.action.outTextForUnit(uid,'delivered ' .. cargo_type,disp_message,false)
        so:destroy()
        coalition.addGroup(cntry,2,delivery)
        unpacked=unpacked+1
        -- reduce spawn counter
        helo_spawned[helo_name]=helo_spawned[helo_name]-1
        helo_spawned[helo_name]=math.max(0,helo_spawned[helo_name])
      else
        trigger.action.outTextForUnit(uid,'There are no nearby crates or you are too high!',disp_message,false)  
        trigger.action.outSoundForUnit(uid,'simple_cargos/nocrates.ogg')
      end -- category
    end -- loop SO
    trigger.action.outTextForUnit(uid,'unpacked ' .. unpacked .. ' crates',disp_message,false)
    trigger.action.outSoundForUnit(uid,'simple_cargos/unpacked.ogg')
  end --inzone
end -- unpack

-----------------------------------------------------------------------
--                             unload_cargo
-----------------------------------------------------------------------

local function unload_cargo(args)
  helo_name=args[1]
  local helo=Unit.getByName(helo_name)
  local uid=helo:getID()
  local pos=helo:getPosition()
  local agl=pos.p.y-land.getHeight({x=pos.p.x,y=pos.p.z})
  local coal=helo:getCoalition()
  local cntry=helo:getCountry()
  local unloaded=0
  local inzone=false
  for z,zone in pairs(zones[coal]) do
    local zn=trigger.misc.getZone(zone)
    local ur2=(zn.point.x-pos.p.x)^2+(zn.point.z-pos.p.z)^2
    if ur2<zn.radius^2 then
      inzone=true
    end
  end  
  if inzone then
    trigger.action.outTextForUnit(uid,'You cannot unload in a pickup zone',disp_message,false)
    trigger.action.outSoundForUnit(uid,'simple_cargos/nounload.ogg')
  else
    if helo_internal_cargos[helo_name] ~= nil then
      if agl<agl_max then
        for c,cargo in pairs(helo_internal_cargos[helo_name]) do
          cid=cid+1
          local gid=cid
          local cargo_type=internal_cargos[cargo][coal]
          local x=pos.p.x-pos.x.x*cargo_offset*c
          local y=pos.p.z-pos.x.z*cargo_offset*c
          local psi=math.atan2(pos.x.z,pos.x.x)
          -- 
          local delivery={
            ['groupId']=gid,
            ['name']='D' .. gid,
            ['category']=2,
            ['hidden']=false,
            ['units']={
              [1]={
                ['unitId']=gid,
                ['name']='D' ..  gid .. '-' .. cargo_type,
                ['type']=cargo_type,
                ['y']=y,
                ['x']=x,
                ['heading']=psi,
                ['skill']=skill,
                ['playerCanDrive']=true,
              }
            },
            ['start_time']=0,
          }
          trigger.action.outTextForUnit(uid,'unloaded ' .. cargo_type,disp_message,false)
          coalition.addGroup(cntry,2,delivery)
          unloaded=unloaded+1
        end
        -- wipe loads
        helo_internal_cargos[helo_name]=nil
        helo_internal_masses[helo_name]=nil
        trigger.action.setUnitInternalCargo(helo_name, 0)
        -- reduce spawn counter
        helo_spawned[helo_name]=helo_spawned[helo_name]-1
        helo_spawned[helo_name]=math.max(0,helo_spawned[helo_name])
        --
        trigger.action.outTextForUnit(uid,'unloaded ' .. unloaded .. ' vehicles',disp_message,false)
        trigger.action.outSoundForUnit(uid,'simple_cargos/unloaded.ogg')
      else -- agl
        trigger.action.outTextForUnit(uid,'You have to land to unload!',disp_message,false)
        trigger.action.outSoundForUnit(uid,'simple_cargos/land.ogg')
      end
    else -- internal cargo
      --net.dostring_in('mission',"a_out_picture('cargo/empty.png', 1., false, 0, 0, 2, 10, '1')"    )
      trigger.action.outTextForUnit(uid,'You have nothing loaded internally',disp_message,false)
      trigger.action.outSoundForUnit(uid,'simple_cargos/empty.ogg')
    end -- internal cargo
  end --
end -- unload_cargo



-----------------------------------------------------------------------
--                             cargo
-----------------------------------------------------------------------
local cargo = {};

function cargo:onEvent(event)
-- event handler to add menu upon birth
 if (world.event.S_EVENT_BIRTH  == event.id) then
    local desc=event.initiator:getDesc().category
    local helo_name=event.initiator:getName()
    local coal=event.initiator:getCoalition()
    local cat=event.initiator:getCategory()
    local cargo_runner=0
    if (helo_name ~= nil and cat == 1 and desc==1) then
      cargo_runner=1
    end

    if ( cat == 1 and desc == 0 ) then
      local ac_type=event.initiator:getTypeName()
      for a,ac in pairs(cargo_ac) do
        if (ac_type ~= nil and ac == ac_type) then
          cargo_runner=2
        end
      end
    end

    if (cargo_runner>0) then
      helo_internal_masses[helo_name]=nil
      helo_internal_cargos[helo_name]=nil
      helo_spawned[helo_name]=0
      gid=event.initiator:getGroup():getID()
      missionCommands.removeItemForGroup(gid,nil)
      local loads=missionCommands.addSubMenuForGroup(gid, 'prepare loads' , nil)
      for c,cargo in pairs(sling_cargos) do
        missionCommands.addCommandForGroup(gid,'prepare slinging ' .. c,     loads , spawn_cargo,  {helo_name,c,0})
      end
      if (cargo_runner>1) then
        for c,cargo in pairs(line_cargos) do
          missionCommands.addCommandForGroup(gid,'line up ' .. c,     loads , spawn_cargo,  {helo_name,c,2})
        end
      else
        for c,cargo in pairs(internal_cargos) do
          missionCommands.addCommandForGroup(gid,'load internally ' .. c,     loads , load_cargo,  {helo_name,c})
        end
      end        
      for t,troop in pairs(troops) do
        missionCommands.addCommandForGroup(gid,'line up ' .. t,  loads , spawn_cargo,  {helo_name,t,1})
      end
      missionCommands.addCommandForGroup(gid,'check internal cargo', nil , check_cargo, {helo_name})
      local unload=missionCommands.addSubMenuForGroup(gid, 'clear/unload' , nil)
      missionCommands.addCommandForGroup(gid,'clear nearby crates', unload , clear_crates, {helo_name})
      missionCommands.addCommandForGroup(gid,'clear internal cargo', unload , clear_cargo, {helo_name})
      missionCommands.addCommandForGroup(gid,'dismiss troops/vehicles', unload , dismiss_troops, {helo_name})
      missionCommands.addCommandForGroup(gid,'unbox nearby crates', unload , unbox, {helo_name})
      missionCommands.addCommandForGroup(gid,'unload internal all cargo', unload , unload_cargo, {helo_name})
    end -- current player
  end -- birth
  if (world.event.S_EVENT_UNIT_LOST == event.id) then
    if event.initiator ~= nil then
      local helo_name=event.initiator:getName()
      if helo_internal_masses[helo_name] ~= nil then
        local uid=event.initiator:getID()
        helo_internal_masses[helo_name]=nil
        helo_internal_cargos[helo_name]=nil
        helo_spawned[helo_name]=nil
        gid=event.initiator:getGroup():getID()
        missionCommands.removeItemForGroup(gid,nil)
        trigger.action.outTextForUnit(uid,'You lost your cargo!',disp_message,false)
        trigger.action.outSoundForUnit(uid,'simple_cargos/lost.ogg')
      end -- 
    end -- nil
  end -- end lost
end -- cargo

world.addEventHandler(cargo)