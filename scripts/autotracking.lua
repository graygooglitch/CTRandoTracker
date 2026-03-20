-- Configuration --------------------------------------
AUTOTRACKER_ENABLE_DEBUG_LOGGING = false
-------------------------------------------------------

print("")
print("Active Auto-Tracker Configuration")
print("---------------------------------------------------------------------")
if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
    print("Enable Debug Logging:        ", "true")
end
print("---------------------------------------------------------------------")
print("")

--
-- Invoked when the auto-tracker is activated/connected
--
function autotracker_started()
    
end

--
-- Print a debug message if debug logging is enabled
--
function printDebug(message)

  if AUTOTRACKER_ENABLE_DEBUG_LOGGING then
    print(message)
  end

end

--
-- Check if the tracker variant is set to Items Only.
--
function itemsOnlyTracking()

  return string.find(Tracker.ActiveVariantUID, "items")

end

--
-- Check if the tracker is in Chronosanity mode
--
function chronosanityMode()

  return Tracker:ProviderCountForCode("chronosanity") > 0
  
end

--
-- Check if the game is currently running
--
function inGame()

  -- Check the first 2 character slots.  If both are 0 (Crono's ID) then the game 
  -- hasn't started yet or has been reset.
  return not (AutoTracker:ReadU8(0x7E2980) == 0 and AutoTracker:ReadU8(0x7E2981) == 0) 

 end

--
-- Handle toggling the green "Go" button on the tracker.
--
function handleGoMode()
  local jetsoftime2 = Tracker:FindObjectForCode("jetsoftime2")
  local omen = Tracker:FindObjectForCode("omen")
  local bucket = Tracker:FindObjectForCode("bucket")
  local gatekey = Tracker:FindObjectForCode("gatekey")
  local rseries = Tracker:FindObjectForCode("rseriesboss")
  local apoc = Tracker:FindObjectForCode("apoc")
  local pendant = Tracker:FindObjectForCode("pendant")
  local rubyknife = Tracker:FindObjectForCode("rubyknife")
  local magus = Tracker:FindObjectForCode("magus")
  local eot = Tracker:FindObjectForCode("eot")
  local algetty = Tracker:FindObjectForCode("algetty")
  local blacktyranoboss = Tracker:FindObjectForCode("blacktyranoboss")
  local magusboss = Tracker:FindObjectForCode("magusboss")
  
  local goMode = false
    goMode = 
      (gatekey.Active and bucket.Active and eot.Active) or  -- Lazy attempt at gate key EoT rules (need 4 chars)
      (rseries.Active and bucket.Active) or -- R series for EoT
      (pendant.CurrentStage == 2 and rubyknife.Active) or -- Impossible Lavos Route
      (magus.Active and rubyknife.Active and magusboss.Active) or -- Impossible Lavos Route (magus magus)
      (magus.Active and rubyknife.Active and blacktyranoboss.Active) or -- Impossible Lavos Route (tyrano magus)   
      (jetsoftime2.Active and apoc.Active) or -- epoch crash   
      (jetsoftime2.Active and omen.Active and algetty.Active ) -- Omen Route


  local goButton = Tracker:FindObjectForCode("gomode")
  goButton.Active = goMode

end

--
-- Update an event from an address and flag.
--
function updateEvent(name, segment, address, flag)

  local trackerItem = Tracker:FindObjectForCode(name)
  local completed = 0
  
  if trackerItem then
    if trackerItem.Owner.ModifiedByUser then
      -- early return if the item has been modified by the user. 
      return 0
    end
  
    local value = segment:ReadUInt8(address)
    if (value & flag) ~= 0 then
      trackerItem.AvailableChestCount = 0
      completed = 1
    else
      trackerItem.AvailableChestCount = 1
    end
  else
    printDebug("Update Event: Unable to find tracker item: " .. name)  
  end
  
  return completed
  
end

--
-- Update a boss from an address and flag
--
function updateBoss(name, segment, address, flag)

  local trackerItem = Tracker:FindObjectForCode(name)
  if trackerItem then
    if trackerItem.Owner.ModifiedByUser then
      -- early return if the item has been modified by the user. 
      return
    end
    
    local value = segment:ReadUInt8(address)
    trackerItem.Active = ((value & flag) ~= 0)
  else
    printDebug("Update Boss: Unable to find tracker item: " .. name)  
  end
  
end

--
-- Handle items that can also show up in character's equipment slots.
-- This includes the Hero Medal and the Masamune.
--
function handleEquippableItem(keyItem)

  local equipmentSlot = AutoTracker:ReadU8(keyItem.address, 0)
  local itemOwned = keyItem.found or equipmentSlot == keyItem.value
  
  local trackerItem = Tracker:FindObjectForCode(keyItem.name)  

  if keyItem.type == "toggle" then
    if trackerItem and not trackerItem.Owner.ModifiedByUser then
      trackerItem.Active = itemOwned
    else
      printDebug("Update Items: Unable to find tracker item: " .. name)
    end
  elseif keyItem.type == "progressive" then
    if trackerItem and not trackerItem.Owner.ModifiedByUser then
      if itemOwned and keyItem.stage > trackerItem.CurrentStage then
        trackerItem.CurrentStage = keyItem.stage
      end
    else
      printDebug("Update Items: Unable to find tracker item: " .. name)
    end
  end

end

--
-- Handle items that are lost on turn-in.  Address, flag attributes 
-- are used to determine if the turn-in event has occured.
--
function handleItemTurnin(keyItem)

  usedItem = (AutoTracker:ReadU8(keyItem.address) & keyItem.flag) ~= 0
  itemFound = keyItem.found or usedItem
  
  local trackerItem = Tracker:FindObjectForCode(keyItem.name)
  if trackerItem and not trackerItem.Owner.ModifiedByUser then
    trackerItem.Active = itemFound
  end

end

--
-- table of key item memory values and names as 
-- registered with the tracker via items.json.
-- Some items have an additional callback field.
-- This is a callback function for special processing.
--
-- Values can be specified as a scalar number or as a table with multiple
-- item IDs.
--
-- NOTE: Key items must be defined after the callback
--       functions are defined or they won't trigger properly.
--
KEY_ITEMS = {
  {value=0x3D, name="masamune", callback=handleEquippableItem, address=0x7E2769,type="progressive",stage=1},
  {value=0x50, name="bentsword",type="toggle"},
  {value=0x51, name="benthilt",type="toggle"},
  {value=0xB3, name="heromedal", callback=handleEquippableItem, address=0x7E276A,type="toggle"},
  {value=0xD4, name="seed",type="toggle"},
  {value=0xD5, name="bikekey",type="toggle"},
  {value=0xD6, name="pendant",type="progressive",stage=1},
  {value=0xD7, name="gatekey",type="toggle"},
  {value=0xD8, name="rainbowshell",type="progressive",stage=2},
  {value=0xD9, name="clonectrigger",type="progressive",stage=2},
  {value=0x42, name="masamune", callback=handleEquippableItem, address=0x7E2769,type="progressive",stage=2},
  {value=0xDA, name="tools", callback=handleItemTurnin, address=0x7F019E, flag=0x40,type="toggle"},
  {value=0xDB, name="jerky", callback=handleItemTurnin, address=0x7F01D2, flag=0x04,type="toggle"},
  {value=0xDC, name="dreamstone",type="toggle"},
  {value=0xDD, name="racelog",type="toggle"},
  {value=0xDE, name="moonstone", callback=handleItemTurnin, address=0x7F013A,type="toggle", flag=0x04},
  {value=0xDF, name="sunstone",type="toggle"},
  {value=0xE0, name="rubyknife",type="toggle"},
  {value=0xE2, name="clonectrigger",type="progressive",stage=1},
  {value=0xE3, name="tomapop", callback=handleItemTurnin, address=0x7F01A3, flag=0x80,type="toggle"},
  {value=0xE9, name="jetsoftime", callback=handleItemTurnin, address=0x7F00BA, flag=0x80,type="toggle"},
  {value=0xEA, name="pendant",type="progressive",stage=2},
  {value=0xEB, name="rainbowshell",type="progressive",stage=1},
  {value=0xE1, name="yakrakey",type="toggle"},

  -- Objective Items
  {value=0x1C, name="objective1", objective=true},
  {value=0x1D, name="objective2", objective=true},
  {value=0x1E, name="objective3", objective=true},
  {value=0x2A, name="objective4", objective=true},
  {value=0x2B, name="objective5", objective=true},
  {value=0x2C, name="objective6", objective=true},
  {value=0x2D, name="objective7", objective=true},
  {value=0x3A, name="objective8", objective=true},
}

function loadObjectives(segment)
  local objective_parse = {}
  local obj_sum = 0
  local mapId = AutoTracker:ReadU16(0x7E0100)
  if mapId == 0x0000 or mapId == 0x01B1 then
    for i=0,0x07 do
      obj_id = segment:ReadUInt8(0x7F0220 + i)
      table.insert(objective_parse, obj_id)
      obj_sum = obj_sum + obj_id
    end

    -- Sanity check to make sure we have real objective data
    -- Map 0x0000 sets the objectives, but the pendulum scene
    -- (0x01B1) seems to set them back to zero. They are then
    -- set again when the map transitions to the battle mode
    -- screen (map 0x0000 again)
    if obj_sum ~= 0 then
      for i=1,8 do
        local trackerItem = Tracker:FindObjectForCode("obj"..i)
          trackerItem.CurrentStage = objective_parse[i]+1
      end
    else
      printDebug("Objective data read failed!")
    end
  end
end

--
-- Update key items from the inventory memory segment.
-- Some items provide callbacks for special handling.  All other
-- items just get directly toggled on the tracker.
--
function updateItemsFromInventory(segment)

  -- Nothing to track if we're not actively in the game
  if not inGame() then
    return
  end

  -- Reset all items to "not found"
  for k,v in pairs(KEY_ITEMS) do
    v.found = false
  end

  -- Loop through the inventory, determine which key items the player has found
  for i=0,0xF1 do
    local item = segment:ReadUInt8(0x7E2400 + i)
    -- Loop through the table of key items and see if the current 
    -- inventory slot maches any of them
    for k,v in pairs(KEY_ITEMS) do
      if type(v.value) == "number" then
        if item == v.value then
          v.found = true
        end
      elseif type(v.value) == "table" then
        -- Loop through possible IDs for items with more than one
        -- Not currently used but leaving this in case it's needed in the future.
        for k2, v2 in pairs(v.value) do
          if item == v2 then
            v.found = true
          end
        end
      end
    end -- end key item loop
  end -- end inventory loop
  
  -- Loop the key items and toggle them based on whether or not they were found
  local objective_checks = {}
  for k,v in pairs(KEY_ITEMS) do
    if v.objective then
      -- This item is an objective marker
      -- When objective markers to away, the objective is complete
      table.insert(objective_checks, v.found)
    elseif v.callback then
      v.callback(v)
    else
      local trackerItem = Tracker:FindObjectForCode(v.name)
      if v.type == "toggle" then
        if trackerItem and not trackerItem.Owner.ModifiedByUser then
          trackerItem.Active = v.found
        else
          printDebug("Update Items: Unable to find tracker item: " .. name)
        end
      elseif v.type == "progressive" then
        if trackerItem and not trackerItem.Owner.ModifiedByUser then
          if v.found and v.stage > trackerItem.CurrentStage then
            trackerItem.CurrentStage = v.stage
          end
        else
          printDebug("Update Items: Unable to find tracker item: " .. name)
        end
      end
      
    end
  end
  
  -- Loop the objectives and set state to complete if found = false
  mapId = AutoTracker:ReadU16(0x7E0100)
  for k,v in pairs(objective_checks) do
    if mapId ~= 0x0000 and mapId ~= 0x01B1 then
      local trackerItem = Tracker:FindObjectForCode("obj"..k)
      if v == false then
        trackerItem.CurrentStage = 70
      end
    end
  end

  -- Check if this puts the player in Go Mode
  handleGoMode()
  
end

--
-- Update events and boss kills
--
function updateEventsAndBosses(segment) 

  -- Nothing to track if we're not actively in the game
  if not inGame() then
    return
  end

  -- Don't autotrack during gate travel:
  -- During a gate transition the memory flags holding the event
  -- and boss data are overwritten.  After the animation, memory 
  -- goes back to normal.
  s1 = segment:ReadUInt16(0x7F0000)
  s2 = segment:ReadUInt16(0x7F0002)
  if s1 == 0x4140 and s2 == 0x4342 then
    return
  end

  -- Handle boss tracking.
  -- This is done in both Map Tracker and Item Tracker variants
  local keyItemChecksDone = 0
  
  -- Prehistory
  updateBoss("nizbelboss", segment, 0x7F0102, 0x10)
  updateBoss("blacktyranoboss", segment, 0x7F00EE, 0x08)
  updateBoss("dactyl", segment, 0x7F0160, 0x10) 
  updateBoss("dactylrecruit", segment, 0x7F0160, 0x10) 

  -- Dark Ages
  updateBoss("northcaperecruit", segment, 0x7F0138, 0x01)
  updateBoss("algetty", segment, 0x7F0105, 0x80)
  updateBoss("omen", segment, 0x7F0104, 0x40)  
  updateBoss("bucket", segment, 0x7F0104, 0x20)  
  updateBoss("apoc", segment, 0x7F0105, 0x04)  
  updateBoss("dalton", segment, 0x7F00BA, 0x80)
  updateBoss("jetsoftime2", segment, 0x7F00BA, 0x80)
  updateBoss("gigagaiaboss", segment, 0x7F0104, 0x08)
  updateBoss("mammon", segment, 0x7F0102, 0x40)
  updateBoss("golemboss", segment, 0x7F0102, 0x80)
  updateBoss("twinboss", segment, 0x7F0103, 0x02)
  updateBoss("plant", segment, 0x7F00F7, 0x02)
  updateBoss("mudimpboss", segment, 0x7F0103, 0x04)

  -- Middle Ages
  updateBoss("cathrecruit1", segment, 0x7F0100, 0x08)
  updateBoss("cathrecruit2", segment, 0x7F0100, 0x80)
  updateBoss("burrowrecruit", segment,0x7F0101, 0x40)
  updateBoss("burrow", segment, 0x7F0101, 0x20)
  updateBoss("tata", segment, 0x7F0101, 0x04)
  updateBoss("cyrus", segment, 0x7F01A3, 0x40)
  updateBoss("yakraboss", segment, 0x7F0100, 0x10)
  updateBoss("masamuneboss", segment, 0x7F00F3, 0x20)
  updateBoss("retiniteboss", segment, 0x7F01A3, 0x01)
  updateBoss("rusttyranoboss", segment, 0x7F01D2, 0x40)
  updateBoss("magusboss", segment, 0x7F01F9, 0x04)
  updateBoss("zomborboss", segment, 0x7F019A, 0x04)
  
  -- Present
  updateBoss("fair", segment, 0x07F0054, 0x20)
  updateBoss("refinements", segment, 0x7F0103, 0x20)
  updateBoss("snail", segment, 0x7F01D0, 0x10)
  updateBoss("bekkler", segment, 0x7F0104, 0x02) 
  updateBoss("jerkytrade", segment, 0x7F0103, 0x40) 
  updateBoss("melchior", segment, 0x7F0104, 0x04) 
  updateBoss("fionacomplete", segment, 0x7F007C, 0x10) 
  updateBoss("heckranboss", segment, 0x7F0104, 0x01)
  updateBoss("dragontankboss", segment, 0x7F0199, 0x04)
  updateBoss("prisonrecruit", segment, 0x7F0199, 0x04)  
  updateBoss("yakraxiiiboss", segment, 0x7F0050, 0x40)
  updateBoss("fairrecruit", segment, 0x7F0055, 0x01)
  
  -- Future
  updateBoss("roboribbon", segment, 0x7F0107, 0x01)
  updateBoss("belthasar", segment, 0x7F00EE, 0x02)
  updateBoss("protorecruit", segment, 0x7F0102, 0x01)
  updateBoss("doan", segment, 0x7F0101, 0x80)
  updateBoss("guardianboss", segment, 0x7F00A4, 0x01)
  updateBoss("moonstonecharge", segment, 0x7F013A, 0x40)
  updateBoss("rseriesboss", segment, 0x7F0102, 0x04)
  updateBoss("sonofsunboss", segment, 0x7F013A, 0x02)
  updateBoss("motherbrainboss", segment, 0x7F013B, 0x10)
  updateBoss("lavosspawnboss", segment, 0x7F0057, 0x40)
  updateBoss("deathpeakrecruit", segment, 0x7F0057, 0x40)
  updateBoss("zealboss", segment, 0x7F01A8, 0x80)
  updateBoss("gaspar", segment, 0x7F007C, 0x01)
  updateBoss("count1", segment, 0x7F0106, 0x01)
  updateBoss("count2", segment, 0x7F0106, 0x02)
  updateBoss("count3", segment, 0x7F0106, 0x04)
  updateBoss("count4", segment, 0x7F0106, 0x08)
  updateBoss("count5", segment, 0x7F0106, 0x10)
  updateBoss("count6", segment, 0x7F0106, 0x20)
  updateBoss("count7", segment, 0x7F0106, 0x40)
  updateBoss("count8", segment, 0x7F0106, 0x80)
  
  -- Only track events in the "Map Tracker" variant
  if not itemsOnlyTracking() then
    -- Prehistory
		updateEvent("@Dactyl Nest/Dactyl Flight", segment, 0x7F0160, 0x10)
		updateEvent("@Laruba Ruins/Dactyl Flight", segment, 0x7F0160, 0x10)
		updateEvent("@Laruba Ruins/Sleepy Nu", segment, 0x7F01AC, 0x20)
		updateEvent("@Hunting Range/Nu Fight", segment, 0x7F01D1, 0x08)
		updateEvent("@Ioka Sweetwater Hut/Ioka Tonic", segment, 0x7F0160, 0x40)
    
    -- Dark Ages
		updateEvent("@Kajar/Nu Scratch (Scratch Spot in Zeal)", segment, 0x7F00F6, 0x08)
		updateEvent("@Terra Cave (Mt Woe Ent)/Tab Sparkle", segment, 0x7F01A4, 0x10)
		updateEvent("@Mt Woe/Screen 4 Sparkle", segment, 0x7F01A4, 0x20)
		updateEvent("@Enhasa/Hidden Room Nus", segment, 0x7F00F4, 0x08)
		updateEvent("@Kajar/Hidden Room Poyozo", segment, 0x7F00F4, 0x20)
		updateEvent("@Terra Cave (Mt Woe Ent)/Mud Imp", segment, 0x7F0103, 0x04)
		updateEvent("@Kajar/Research Room Sparkle", segment, 0x7F00F6, 0x04)
    
      -- Middle Ages
		updateEvent("@Guardia Castle 600/Chef", segment, 0x7F00A9, 0x10)
		updateEvent("@Manoria Cathedral/Soldier Bucket Sparkle", segment, 0x7F00F6, 0x10)
		updateEvent("@Guardia Forest 600/Forest Tab", segment, 0x7F01D3, 0x08)
		updateEvent("@Dorino Residence/Locked Dresser (Naga-ette Bromide from Cathedral)", segment, 0x7F00F6, 0x02)
		updateEvent("@Dorino Inn/Rest at Inn (Marle in Party)", segment, 0x7F0107, 0x40)
		updateEvent("@Denadoro Mts/Frog Rock Catch (Frog Leading)", segment, 0x7F00F7, 0x08)
		updateEvent("@Denadoro Mts/Mountains're Nice", segment, 0x7F0070, 0x01)
		updateEvent("@Denadoro Mts/Left Corner Sparkle", segment, 0x7F0064, 0x40)
		updateEvent("@Porre Market/Corner Tab", segment, 0x7F01D3, 0x01)
		updateEvent("@Ozzie's Fort/Guillotine Room Sparkle (Hidden)", segment, 0x7F01A4, 0x40)
		updateEvent("@Sun Keep 600/Tab Sparkle", segment, 0x7F014A, 0x02)
		updateEvent("@Northern Ruins 600 (Carpenter Fixes)/Basement Chest", segment, 0x7F01AC, 0x02)
		updateEvent("@Northern Ruins 600 (Carpenter Fixes)/Left Room Chest", segment, 0x7F01AC, 0x08)
		updateEvent("@Choras Cafe/Toma's Pop", segment, 0x7F01A0, 0x02)
		updateEvent("@Giant's Claw (Defile Toma's Grave in 1000)/Behind Drop Skull Sparkle", segment, 0x7F01D3, 0x02)
		updateEvent("@Giant's Claw (Defile Toma's Grave in 1000)/Caverns Sparkle After Drop", segment, 0x7F01D3, 0x80)
		updateEvent("@Giant's Claw (Defile Toma's Grave in 1000)/Right Skull Sparkle", segment, 0x7F01D3, 0x40)
		updateEvent("@Truce Inn 600/Sealed Chest", segment, 0x7F014A, 0x80)
		updateEvent("@Guardia Forest 600/Sealed Chest", segment, 0x7F01D2, 0x80)
		updateEvent("@Guardia Castle 600/Sealed Chest", segment, 0x7F00D9, 0x02)
    
      -- Present
		updateEvent("@Crono's House/Allowance", segment, 0x7F0140, 0x02)
		updateEvent("@Millenial Fair/Marle Pendant", segment, 0x7F0054, 0x20)
		updateEvent("@Snail Stop/Buy for 9900G", segment, 0x7F01D0, 0x10)
		updateEvent("@Lucca's House/Taban's Gift", segment, 0x7F007A, 0x01)
		updateEvent("@Truce Inn 1000/Sealed Chest", segment, 0x7F014A, 0x20)
		updateEvent("@Guardia Forest 1000/Sealed Chest", segment, 0x7F01D1, 0x20)
		updateEvent("@Guardia Forest 1000/Tab Sparkle", segment, 0x7F01D3, 0x04)
		updateEvent("@Guardia Castle 1000/Sealed Chest", segment, 0x7F00D9, 0x04)
		updateEvent("@Guardia Castle 1000/Yakra Chest (Recruit and Key Item)", segment, 0x7F00A7, 0x80)
		updateEvent("@Guardia Castle 1000/Melchior's Refinements (Rainbow)", segment, 0x7F006D, 0x20)
		updateEvent("@Guardia Castle 1000/Melchior's Refinements (Sunstone)", segment, 0x7F0103, 0x20)
		updateEvent("@Crono Trial Prison/Cell Gift", segment, 0x7F019B, 0x80)
		-- updateEvent("@Truce Mayor's House/Mayor Gift", segment, 
		updateEvent("@Heckran Cave/Sealed Chest", segment, 0x7F01A0, 0x04)
		updateEvent("@Medina Elder's House/Counter Sparkle", segment, 0x7F014A, 0x04)
		updateEvent("@Medina Elder's House/Upstairs Sparkle", segment, 0x7F014A, 0x02)
		updateEvent("@Forest Ruins/Blue Pyramid Sealed Chest (Left)", segment, 0x7F01A0, 0x01)
		updateEvent("@Forest Ruins/Blue Pyramid Sealed Chest (Right)", segment, 0x7F0100, 0x04)
		updateEvent("@West Cape/Behind Grave", segment, 0x7F01AC, 0x10)
		updateEvent("@Choras Residence/Carpenter's Wife (Speak to Carpenter in Inn)", segment, 0x7F019E, 0x80)
		-- updateEvent("@Northern Ruins 1000 (Carpenter Fixes in 600)/Grave Room Sparkle", segment,
		updateEvent("@Northern Ruins 1000 (Carpenter Fixes in 600)/Basement Chest", segment, 0x7F01AC, 0x01)
		updateEvent("@Northern Ruins 1000 (Carpenter Fixes in 600)/Left Room Chest", segment, 0x7F01AC, 0x04)
      
    -- Future
		updateEvent("@Trann Dome/Sealed Door Sparkle", segment, 0x7F00D5, 0x04)
		updateEvent("@Arris Dome/Sealed Door Sparkle", segment, 0x7F00D5, 0x08)
		updateEvent("@Lab 32/Johnny Race Score Tab", segment, 0x7F0136, 0x02)
		updateEvent("@Keeper's Dome/Sealed Door Sparkle", segment, 0x7F0070, 0x02)
		updateEvent("@Death Peak/Entrance Sparkle", segment, 0x7F007C, 0x08)
		updateEvent("@Proto Dome/Time Gate Sparkle", segment, 0x7F014A, 0x01)
		updateEvent("@Geno Dome/Sparkle Under Switch Poyozo Doll", segment, 0x7F014B, 0x01)
		updateEvent("@Geno Dome/Sparkle Hidden in Secret Passage Above Conveyor", segment, 0x7F014A, 0x04)
		updateEvent("@Geno Dome/Second Floor Red Hallway Sparkle", segment, 0x7F014A, 0x08)
		updateEvent("@Geno Dome/Sparkle Above Atropos XR Fight", segment, 0x7F014B, 0x02)
	
	-- Last Village
		updateEvent("@North Cape/Recruit Character", segment, 0x7F0138, 0x02)
		updateEvent("@Last Village Nu Hut/Sparkle Behind Nu", segment, 0x7F014A, 0x10)

  end -- end event tracking

  handleGoMode()
end

--
-- Toggle a character based on whether or not he/she was found in the party.
--
function toggleCharacter(name, found)

  character = Tracker:FindObjectForCode(name)
  if character then
    if not character.Owner.ModifiedByUser then
      character.Active = found
    end
  else
    printDebug("Unable to find character: " .. name)
  end

end

--
-- Read the PC and PC Reserve slots to determine which
-- characters have been acquired.
--
function updateParty(segment)

  -- Don't track if we're not actively in game
  if not inGame() then
    return
  end

  -- Character IDs:
  -- NOTE: items.jason uses characters' real names, not defaults.
  -- 0 Crono
  -- 1 Nadia (Marle)
  -- 2 Lucca
  -- 3 R66-Y (Robo)
  -- 4 Glenn (Frog)
  -- 5 Ayla
  -- 6 Janus (Magus)

  charsFound = 0
  -- Loop through the character slots and mark off which ones are found
  -- 0x80 is the "empty" value for a slot
  for i=0, 8 do
    charId = segment:ReadUInt8(0x7E2980 + i)
    
    if charId ~= 0x80 then
      charsFound = charsFound | (1 << charId)
    end
  end

  -- Toggle tracker icons based on what characters were found
  toggleCharacter("Crono", (charsFound & 0x01 ~= 0))
  toggleCharacter("Nadia", (charsFound & 0x02 ~= 0))
  toggleCharacter("Lucca", (charsFound & 0x04 ~= 0))
  toggleCharacter("R66-Y", (charsFound & 0x08 ~= 0))
  toggleCharacter("Glenn", (charsFound & 0x10 ~= 0))
  toggleCharacter("Ayla",  (charsFound & 0x20 ~= 0))
  toggleCharacter("Janus", (charsFound & 0x40 ~= 0))
  
  -- Check if this puts the player in Go Mode
  handleGoMode()
  
end

--
-- Update the checklist of number of objectives completed.
--
function updateChecklistCount(segment)

  local counter = Tracker:FindObjectForCode("checklist")
  counter.AcquiredCount = segment:ReadUInt8(0x7F0045)
  
  handleGoMode()
end

function updateScaling(segment)

  local counter = Tracker:FindObjectForCode("scale")
  counter.AcquiredCount = segment:ReadUInt8(0x7E2881)

end

function updateEoT(segment)

  local eot = false
  local trackerItem = Tracker:FindObjectForCode("eot")
  local value = segment:ReadUInt8(0x7F0047)

  if value == 7 then
  return
  elseif value >= 4 then
    eot = true
  end

  trackerItem.Active = eot

end

--
-- Handle updating the chest counters for a given area.
--
function handleChests(segment, locationName, treasureMap)

  -- Base address of the block of treasure bits
  -- Treasure pointers are stored as offsets from this address
  local baseAddress = 0x7F0001
  local totalTreasures = 0
  
  -- Loop through each sub-location for this location
  for locationCode,treasures in pairs(treasureMap) do
    local location = Tracker:FindObjectForCode(locationName .. locationCode)
    if location == nil then
      -- If the location doesn't exist, don't error, just return 0
      return 0
    end
    
    -- Loop through and count the treasures in each subsection
    --    treasure[1] - Offset from the base treasure address
    --    treasure[2] - Bitmask flag for this treasure
    local collectedTreasures = 0
    for _, treasure in pairs(treasures) do
      local address = baseAddress + treasure[1]
      local treasureByte = segment:ReadUInt8(address)
      if (treasureByte & treasure[2]) ~= 0 then
        collectedTreasures = collectedTreasures + 1
      end
    end -- end treasure loop
    
    location.AvailableChestCount = location.ChestCount - collectedTreasures
    totalTreasures = totalTreasures + collectedTreasures
    
  end -- End location loop
  
  return totalTreasures
  
end

--
-- Update the chests that have been collected
-- by the player.  Only chests considered for 
-- key item placement in Chronosanity mode are
-- tracked here.
--
function updateChests(segment)
  
  -- Don't autotrack during gate travel:
  -- During a gate transition the memory flags holding the chest
  -- data  are overwritten.  After the animation, memory 
  -- goes back to normal.
  s1 = segment:ReadUInt16(0x7F0000)
  s2 = segment:ReadUInt16(0x7F0002)
  if s1 == 0x4140 and s2 == 0x4342 then
    return
  end
  
  -- 
  -- Treasures for each loction are stored as an offset
  -- from the base treasure address and a bit flag
  -- for the specific chest. 
  --
  -- Named entries are subsections within the location.
  --
  local chestsOpened = 0
  local chests = {}
  --------------------------
  --    65,000,000 BC     --
  --------------------------
  -- Mystic Mountains
  chests = {
    ["Chests"] = {
      {0x13, 0x20}
    }
  }
  handleChests(segment, "@Mystic Mountain/", chests)
  
  -- Forest Maze
  chests = {
    ["Chests"] = {
      {0x13, 0x40},
      {0x13, 0x80},
      {0x14, 0x01},
      {0x14, 0x02},
      {0x14, 0x04},
      {0x14, 0x08},
      {0x14, 0x10},
      {0x14, 0x20},
      {0x14, 0x40}
    }
  }
  handleChests(segment, "@Forest Maze/", chests)
  
  -- Dactyl Nest
  chests = {
    ["Chests"] = {
      {0x15, 0x80},
      {0x16, 0x01},
      {0x16, 0x02}
    }
  }
  handleChests(segment, "@Dactyl Nest/", chests)
  
  -- Reptite Lair
  chests = {
    ["Chests"] = {
      {0x15, 0x20},
      {0x15, 0x40}
    }
  }
  handleChests(segment, "@Reptite Lair/", chests)
  
  --------------------------
  --      12000 BC        --
  --------------------------
  -- Mount Woe
  -- Screen 1 - Middle Eastern Face (0x18A)
  -- Screen 2 - Western Face (0x188)
  -- Screen 3 - Lower Eastern Face (0x189)
  -- Screen 4 - Upper Eastern Face (0x18B)
  chests = { 
    ["Screen 1"] = {
      {0x1B, 0x08}
    },
    ["Screen 2"] = {
      {0x1A, 0x02}, -- Screen 2, Bottom Right Chest
      {0x1A, 0x04}, -- Screen 2, Top Right Island, Top Chest
      {0x1A, 0x08}, -- Screen 2, Top Right Island, Bottom Chest
      {0x1A, 0x10}, -- Screen 2, Top Left Chest
      {0x1A, 0x20}  -- Screen 2, Mid Left Chest
    },
    ["Screen 3"] = {
      {0x1A, 0x40}, -- Screen 3, Right Island, Bottom chest
      {0x1A, 0x80}, -- Screen 3, Right Island, Top chest
      {0x1B, 0x01}, -- Screen 3, Bottom Left Chest
      {0x1B, 0x02}, -- Screen 3, Top Left Island, Right Chest
      {0x1B, 0x04}  -- Screen 3, Top Left Island, Left Chest
    },
    ["Screen 4"] = {
      {0x1B, 0x10}, -- Screen 4, Right Chest
      {0x1B, 0x20}  -- Screen 4, Left Chest
    }
  }
  handleChests(segment, "@Mt Woe/", chests)
  
  --------------------------
  --       600 AD         --
  --------------------------
  -- Fiona's Villa
  chests = {
    ["Chests"] = {
      {0x07, 0x40},
      {0x07, 0x80}
    }
  }
  handleChests(segment, "@Fiona's Villa/", chests)
  
  -- Truce Canyon
  chests = {
    ["Chests"] = {
      {0x03, 0x08},
      {0x03, 0x10}
    }
  }
  handleChests(segment, "@Truce Canyon/", chests)

  -- Guardia Castle Past
  chests = {
    ["Left Tower"] = {
      {0x1E, 0x04},
      {0x03, 0x20}
    },
    ["Right Tower"] = {
      {0x1D, 0x08},
	  {0x03, 0x40}
    },
    ["Kitchen"] = {
      {0x03, 0x80}
    }
  }
  handleChests(segment, "@Guardia Castle 600/", chests)
  
  -- Manoria Cathedral
  chests = {
    ["Front Half"] = {
      {0x04, 0x02},
      {0x04, 0x04},
      {0x04, 0x08}
    },
    ["Bromide Room"] = {
      {0x0C, 0x08},
      {0x0C, 0x10},
      {0x0C, 0x20}
    },
    ["Disguised Royalty"] = {
      {0x0C, 0x02},
      {0x0C, 0x04}
    },
    ["Shrine"] = {
      {0x0C, 0x40},
      {0x0C, 0x80}
    },
    ["Back Half"] = {
      {0x04, 0x10},
      {0x04, 0x20},
      {0x04, 0x40},
      {0x04, 0x80}
    },
    ["Final Chest"] = {
      {0x0C, 0x01}
    }
  }
  handleChests(segment, "@Manoria Cathedral/", chests)
  
  -- Cursed Woods
  chests = {
    ["Burrow Right Chest"] = {
      {0x05, 0x04}
    },
    ["Forest Chests"] = {
      {0x05, 0x01},
      {0x05, 0x02}
    }
  }
  handleChests(segment, "@Cursed Woods/", chests)
  
  -- Denadoro Mountains
  chests = {
    ["Entrance"] = {
      {0x06, 0x40}, -- Entrance Cliff
      {0x06, 0x80}, -- Entrance
      {0x05, 0x20}, -- Back room from entrance
      {0x05, 0x08}, -- Screen 2 top chest
      {0x05, 0x10}  -- Screen 2 left chest
    },
    ["Right Side Climb"] = {
      {0x06, 0x01}, -- climb, right side (rock thrower)
      {0x07, 0x01}, -- Outlaw race chest
      {0x07, 0x02}, -- Outlaw race chest
      {0x07, 0x04}, -- Outlaw race chest
      {0x07, 0x08}, -- Outlaw race chest
      {0x07, 0x10}  -- Right side, before gauntlet
    },
    ["Waterfall Top"] = {
      {0x06, 0x08}, -- Waterfall top - bottom right chest
      {0x06, 0x10}, -- Waterfall top - top chest
      {0x06, 0x20}  -- Waterfall top - Left Chest
    },
    ["Waterfall Drop"] = {
      {0x06, 0x02}, -- Waterfall bottom - left chest
      {0x06, 0x04}  -- Waterfall bottom - right chest
    },
    ["Left Side"] = {
      {0x05, 0x40}, -- Final screen bottom chest
      {0x05, 0x80}, -- Final screen top chest
      {0x07, 0x20}  -- Left side by save point
    }
  }
  handleChests(segment, "@Denadoro Mts/", chests)
  
  -- Giant's Claw
  chests = {
    -- Throne room chests are shared between here and Tyrano Lair.
    ["Entrance Throne Room"] = {
      {0x16, 0x04},
      {0x16, 0x08}
    },
    ["Cave After Throne"] = {
      {0x0B, 0x04} -- Left chest after throne room
    },
    ["Behind Cave Skull"] = {
      {0x03, 0x04}  -- Chest north of the pit you jump down
    },
    ["Ladder Caverns"] = {
      {0x0B, 0x20}, -- Caverns room 2, left side
      {0x0B, 0x10} -- Caverns room 2, right side
    },
    ["Caverns After Drop"] = {
      {0x0B, 0x80}, -- Caverns room 1
      {0x0B, 0x40}, -- Blue Rock chest
      {0x0B, 0x04}
    },
    ["Left Switch Cave"] = {
      {0x0B, 0x08}  -- Left door of pit room
    },
    ["Chest Drop"] = {
      {0x03, 0x04}
    },
    ["Kino's Cell"] = {
      {0x03, 0x02}  -- Kino's Cell
    }    
  }
  handleChests(segment, "@Giant's Claw (Defile Toma's Grave in 1000)/", chests)
  
  -- Ozzie's Fort
  chests = {
    ["Guillotine Room"] = {
      {0x0A, 0x10}
    },
	["Guillotine Room (Hidden)"] = {
      {0x0A, 0x20},
      {0x0A, 0x40},
      {0x0A, 0x80}
    },
    ["Boss Room"] = {
      {0x0B, 0x01},
      {0x0B, 0x02}
    }
  }
  handleChests(segment, "@Ozzie's Fort/", chests)
  
  --------------------------
  --       1000 AD        --
  --------------------------
  -- Guardia Castle Present 
  chests = {
    ["Left Tower"] = {
      {0x1E, 0x08},
      {0x00, 0x10}
    },
    ["Right Tower"] = {
      {0x1E, 0x10},
      {0x00, 0x20}
    },
    ["Courtroom Tower"] = {
      {0x1E, 0x20}
    },
    ["Prison Tower"] = {
      {0x1E, 0x40}
    },
    ["Rainbow Shell Treasury"] = {
      {0x00, 0x40},
      {0x00, 0x80},
      {0x01, 0x01},
      {0x1D, 0x01},
      {0x1D, 0x02},
      {0x1D, 0x04}
    }
  }
  handleChests(segment, "@Guardia Castle 1000/", chests)
  
  -- Chrono Trial Prison 
  chests = {
    ["Prison Treasury"] = {
      {0x02, 0x02},
      {0x02, 0x04},
	  {0x02, 0x08},
	  {0x02, 0x80}
    },
    ["Guillotine Chamber"] = {
      {0x01, 0x02}
    },
    ["Fritz Chamber"] = {
      {0x03, 0x01}
    },
    ["Empty Cell Chest"] = {
      {0x02, 0x01}
    },
    ["Wall Climb Cell Chest"] = {
      {0x02, 0x40}
    },
	["Hole Cell Chests"] = {
      {0x02, 0x10},
	  {0x02, 0x20}
    }
  }
  handleChests(segment, "@Crono Trial Prison/", chests)
  
  -- Truce Mayor's House
  chests = {
    ["Chests"] = {
      {0x00, 0x04},
      {0x00, 0x08}
    }
  }
  handleChests(segment, "@Truce Mayor's House/", chests)
  
  -- Porre Mayor's House
  chests = {
    ["Upstairs Chest"] = {
      {0x01, 0x80}
    }
  }
  handleChests(segment, "@Porre Mayor's House/", chests)
  
  -- Forest Ruins
  chests = {
    ["Entry Chest"] = {
      {0x01, 0x04}
    }
  }
  handleChests(segment, "@Forest Ruins/", chests)
  
  -- Heckran's Cave
  chests = {
    ["Chests"] = {
      {0x01, 0x08},
      {0x01, 0x10},
      {0x01, 0x20},
      {0x01, 0x40}
    }
  }
  handleChests(segment, "@Heckran Cave/", chests)
  
  --------------------------
  --       2300 AD        --
  --------------------------
  -- Bangor Dome
  chests = {
    ["Sealed Door Chests"] = {
      {0x0D, 0x01},
      {0x0D, 0x02},
      {0x0D, 0x04}
    }
  }
  handleChests(segment, "@Bangor Dome/", chests)
  
  -- Trann Dome
  chests = {
    ["Sealed Door Chests"] = {
      {0x0D, 0x08},
      {0x0D, 0x10}
    }
  }
  handleChests(segment, "@Trann Dome/", chests)
  
  -- Arris Dome 
  chests = {
    ["Food Storage Chest"] = {
      {0x1A, 0x01}  -- Food Storage
    },
	["LR+A Chest"] = {
      {0x0E, 0x02}, -- Passageway
    },
    ["Sealed Door Chests"] = {
      {0x0E, 0x04}, 
      {0x0E, 0x08},
      {0x0E, 0x10}, 
      {0x0E, 0x20}
    }
  }
  handleChests(segment, "@Arris Dome/", chests)
  
  -- Factory Ruins 
  chests = {
    ["Left Side"] = {
      {0x0F, 0x02}, -- Auxillary computer (hatch room)
      {0x0F, 0x04}, -- Security Center
      {0x0F, 0x08}, -- Security Center
      {0x10, 0x08}  -- Power Core
    },
    ["Right Side"] = {
      {0x0F, 0x10},
      {0x0F, 0x20},
      {0x0F, 0x40},
      {0x0F, 0x80}, -- hidden chest
      {0x10, 0x01}, 
      {0x10, 0x02},
      {0x10, 0x04},
      {0x12, 0x08},
      {0x12, 0x10}
      -- 7F001D   80  Inaccessible chest
    }
  }
  handleChests(segment, "@Factory/", chests)
  
  -- Sewers
  chests = {
    ["Chests"] = {
      {0x10, 0x10}, -- Front chest
      {0x10, 0x20}, -- Krawlie chest
      {0x10, 0x40}  -- Back chest (left of exit)
    }
  }
  handleChests(segment, "@Sewers/", chests)
  
  -- Lab 16
  chests = {
    ["Chests"] = {
      {0x0D, 0x20}, -- Chest 2 (after 3 volcanos)
      {0x0D, 0x40}, -- Chest 3 (Before 5 volcanos)
      {0x0D, 0x80}, -- Chest to the right of the entrance
      {0x0E, 0x01}  -- East side chest
    }
  }
  handleChests(segment, "@Lab 16/", chests)
  
  -- Lab 32
  chests = {
    ["Entrance Chest"] = {
      {0x0E, 0x80}
    },
	["Middle Chest"] = {
      {0x0F, 0x01}
    }
  }
  handleChests(segment, "@Lab 32/", chests)
  
  -- Geno Dome 
  chests = {
    ["Central Chest"] = {
      {0x11, 0x08}, -- Control Room (By electricity)
    },
	["Entryway Treasure Room"] = {
      {0x11, 0x80}, -- South electricity room, left chest
      {0x12, 0x01} -- South electricity room, right chest
    },
	["Doppelganger Chest"] = {
      {0x11, 0x40} -- Far left chest (by 2nd doll)
    },
	["Right Side Treasure Room"] = {
      {0x11, 0x10}, -- Robot storage top chest
      {0x11, 0x20} -- Robot storage bottom chest
    },
	["Conveyor Charge Treasure Room"] = {
	  {0x12, 0x02}, -- Proto 4 room, top chest
      {0x12, 0x04}  -- Proto 4 room, bottom chest
    },
    ["Entry Catwalk Chest"] = {
      {0x13, 0x08} -- Left catwalk chest
    },
	["Catwalk Room Chest"] = {
      {0x13, 0x02} -- Back catwalk chest
    },
	["Chest Above Atropos XR Fight"] = {
      {0x13, 0x04} -- Laser cell chest
    },
	["Second Floor Bottom Right Chest"] = {
      {0x13, 0x10}  -- Chest by first set of laser guards
    }
  }
  handleChests(segment, "@Geno Dome/", chests)
  
  -- Death Peak 
  chests = {
    ["First Area Chest"] = {
      {0x10, 0x80}
    },
	["Save Point Chest"] = {
      {0x11, 0x04}
    },
	["Cave Chests"] = {
      {0x12, 0x40},
	    {0x13, 0x01},
	    {0x12, 0x80}
    },
	["Monster Dispenser Chest"] = {
      {0x12, 0x20}
    },
	["Final Climb Chests"] = {
      {0x11, 0x01},
	    {0x11, 0x02}
    },
  }
  handleChests(segment, "@Death Peak/", chests)
    
end

--
-- Set up memory watches on memory used for autotracking.
--
printDebug("Adding memory watches")
ScriptHost:AddMemoryWatch("Party", 0x7E2980, 9, updateParty)
ScriptHost:AddMemoryWatch("Checklist", 0x7F0045, 1, updateChecklistCount)
ScriptHost:AddMemoryWatch("Eot", 0x7F0047, 1, updateEoT)
ScriptHost:AddMemoryWatch("Scaling", 0x7E2881, 1, updateScaling)
ScriptHost:AddMemoryWatch("Events", 0x7F0000, 512, updateEventsAndBosses)
ScriptHost:AddMemoryWatch("Inventory", 0x7E2400, 0xF2, updateItemsFromInventory)
ScriptHost:AddMemoryWatch("Chests", 0x7F0000, 0x20, updateChests)
ScriptHost:AddMemoryWatch("ObjectiveInitLoad", 0x7F0220, 0x08, loadObjectives)