-- BUILD VERSION 0209_23_05_2024

os.loadAPI("inv")
os.loadAPI("t")

local x = 0
local y = 0
local z = 0
local max = 16
local deep = 64
local facingfw = true
local max_depth = 200	-- default max depth of the quarry
local chunks_forward = 1	-- default number of chunks to dig forward

local OK = 0
local ERROR = 1
local LAYERCOMPLETE = 2
local OUTOFFUEL = 3
local FULLINV = 4
local BLOCKEDMOV = 5
local USRINTERRUPT = 6
local MAXDEPTH = 7

local status = true

local CHARCOALONLY = false
local USEMODEM = false


-- Functions
function displayHelp()
	print("Quarry script example usage\n'quarry -{arg} -{next_arg}'\nAvailable parameters:\n-h	to display help\n-m	to use modem\n-c	to only use charcoal\n-f	to define how many chunks forward to dig\n-d	to define how deep should the turtle dig")
end

function out(s)
		
	s2 = "["..x..";"..y..";"..z.."] "..s

	print(s2)
	if USEMODEM then
		rednet.broadcast(s2, "PC1")
	end  
end

function dropInChest()
	turtle.turnRight()
	turtle.turnRight()
		
	local success, data = turtle.inspect()

	if success and (data.name == "minecraft:chest" or data.name == "ironchest:obsidian_chest") then
		out("Dropping items in chest")
		
		for i = 1, 16 do
			turtle.select(i)
			local item = turtle.getItemDetail()
			
			if item and item.name ~= "minecraft:charcoal" and item.name ~= "quark:charcoal_block" and not (item.name == "minecraft:coal" and CHARCOALONLY) and (not item.damage or item.damage ~= 1) then
				turtle.drop()
			end
		end
	else
		out("No chest found")
	end

	turtle.turnLeft()
	turtle.turnLeft()
end

function goDown()
	while true do
		-- Check if the turtle has reached max depth
		if math.abs(z) >= max_depth then
			return false
		end
		if turtle.getFuelLevel() <= fuelNeededToGoBack() then
			if not refuel() then
				return OUTOFFUEL
			end
		end
		
		if not turtle.down() then
			turtle.up()
			z = z+1
			return true
		end
		z = z-1
	end
end

function fuelNeededToGoBack()
	return -z + x + y + 2
end

function refuel()
    for i=1, 16 do
        -- Prioritize charcoal blocks
        turtle.select(i)
        item = turtle.getItemDetail()
        if item and (item.name == "quark:charcoal_block" and turtle.refuel(1)) then
            return true
        end
    end
    for i=1, 16 do
        -- Only run on Charcoal
        turtle.select(i)
        item = turtle.getItemDetail()
        if item and (item.name == "minecraft:charcoal" or (item.name == "minecraft:coal" and (CHARCOALONLY == false or item.damage == 1))) and turtle.refuel(1) then
            return true
        end
    end
    return false
end

function moveH()
	if inv.isInventoryFull() then
		out("Dropping thrash")
		inv.dropThrash()
		
		if inv.isInventoryFull() then
			out ("Stacking items")
			inv.stackItems()
		end
		
		if inv.isInventoryFull() then
			out("Full inventory!")
			return FULLINV  
		end
	end
	
	if turtle.getFuelLevel() <= fuelNeededToGoBack() then
		if not refuel() then
			out("Out of fuel!")
			return OUTOFFUEL
		end
	end
	
	if facingfw and y<max-1 then
		-- Going one way
		local dugFw = t.dig()
		if dugFw == false then
			out("Hit bedrock, can't keep going")
			return BLOCKEDMOV
		end
		t.digUp()
		t.digDown()
	
		if t.fw() == false then
			return BLOCKEDMOV
		end
		
		y = y+1
		
	elseif not facingfw and y>0 then
		-- Going the other way
		t.dig()
		t.digUp()
		t.digDown()
		
		if t.fw() == false then
			return BLOCKEDMOV
		end
		
		y = y-1
		
	else
		if x+1 >= max then
			t.digUp()
			t.digDown()
			return LAYERCOMPLETE -- Done with this Y level
		end
		
		-- If not done, turn around
		if facingfw then
			turtle.turnRight()
		else
			turtle.turnLeft()
		end
		
		t.dig()
		t.digUp()
		t.digDown()
		
		if t.fw() == false then
			return BLOCKEDMOV
		end
		
		x = x+1
		
		if facingfw then
			turtle.turnRight()
		else
			turtle.turnLeft()
		end
		
		facingfw = not facingfw
	end
	
	return OK
end

function digLayer()
	
	local errorcode = OK
	
	while errorcode == OK do
		if USEMODEM then
			local msg = rednet.receive(0.2)
			if msg ~= nil and string.find(msg, "return") ~= nil then
				return USRINTERRUPT
			end
		end
		errorcode = moveH()
	end
	
	if errorcode == LAYERCOMPLETE then
		return OK
	end
	
	return errorcode  
end

function goToOrigin()
	
	if facingfw then
		
		turtle.turnLeft()
		
		t.fw(x)
		
		turtle.turnLeft()
		
		t.fw(y)
		
		turtle.turnRight()
		turtle.turnRight()
		
	else
		
		turtle.turnRight()
		
		t.fw(x)
		
		turtle.turnLeft()
		
		t.fw(y)
		
		turtle.turnRight()
		turtle.turnRight()
		
	end
	
	x = 0
	y = 0
	facingfw = true
	
end

-- First goes up and then goes to the original position
function goBackToStart()
	
	while z < 0 do
		
		t.up()
		
		z = z+1
		
	end
	
	goToOrigin()
	
end

function mainloop()
	
	while true do
		
		-- if the turtle has reached max depth while in the loop go back to start
		if math.abs(z) >= max_depth then
			out("Reached max depth!, going back")
			goBackToStart()
			return LAYERCOMPLETE
		end

		local errorcode = digLayer()
		
		if errorcode ~= OK then
			goBackToStart()
			return errorcode
		end
		
		goToOrigin()
		
		for i=1, 3 do
			-- Changed code!
			if not t.digDown() then
				goBackToStart()
				return BLOCKEDMOV
			end
			success = t.down()
			
			if not success then
				goBackToStart()
				return BLOCKEDMOV
			end
			
			z = z-1
			out("Z: " .. z)
			
		end
	end
end


-- MAIN RUNTIME

-- Handling Arguments
local tArgs = {...}
for i=1,#tArgs do
	local arg = tArgs[i]
	if string.find(arg, "-") == 1 then
		local ch = string.sub(arg,2)
		if ch == 'h' then		-- display help
			displayHelp()
			os.exit()			-- exits the program
			status = false
			chunks_forward = 0
			break
		elseif ch == 'm' then	-- use modem
			USEMODEM = true
		elseif ch == 'c' then	-- use charcoal only
			CHARCOALONLY = true
		elseif ch == 'f' then	-- dig how many chunks forward
			print("How many chunks should the turtle dig forward?")
			chunks_forward = tonumber(io.read())
		elseif ch == 'd' then	-- dig how deep
			print("How deep do you wish the turtle to dig?")
			max_depth = tonumber(io.read())
		else
			io.print("Invalid flag '"..ch.."' !")
			io.print("Continue? (Y/N)")
			if (io.read() ~= "Y" or io.read() ~= "y")  then 
				status = false
			end
		end
	end
end

if USEMODEM then
	rednet.open("left")
end

-- Main runtime
print("#######################################")
print("#### QUARRY TURTLE SOFTWARE V0.1.1 ####")
print("#######################################\n")

out("Starting mining")

-- Digging chunks forward
for current_chunk = 1, chunks_forward, 1 do
	
	-- Digging chunk
	while status == true do

		-- if it can't go down then it reached max depth
		if goDown() then
			local errorcode = mainloop()
		else
			out("Reached max depth!, going back")
			errorcode = MAXDEPTH
			goBackToStart()
		end
		
		out("Chunk finished")

		-- if its on other chunks go back to first one and dump items in chest
		if current_chunk>1 then
			for j = 1, (chunks_forward-1)*16, 1 do
				turtle.back()
			end
		end
		dropInChest()
		
		if errorcode ~= FULLINV then
			break
		end
	end
	if chunks_forward>1 and current_chunk~=chunks_forward then
		out("Starting chunk "..current_chunk+1)
		for j = 1, ((current_chunk-1)*16)+15, 1 do
			turtle.forward()
		end
		turtle.dig()
		turtle.forward()
		turtle.digUp()
	end
end

if USEMODEM then
	rednet.close("left")
end