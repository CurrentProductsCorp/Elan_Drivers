-- Current_Products_Serial.lua



--| Globals -----------------------------------------------------------------------
	

--| Init --------------------------------------------------------------------------
    
	function EDRV_Init()
	    -- called when the driver starts up
		-- May be used to get all the current devices later
    end



--| System Calls ------------------------------------------------------------------

	--[[-------------------------------------------------------
		Called when the slider is set to open
	--]]-------------------------------------------------------
    function EDRV_ActivateDevice(deviceID, deviceSubType, isReversed)
    -- Instruct the driver to turn the device on (CLOSE)
		level = (isReversed == "true") and 0 or 100

		--reverse order because of Endianness.
		deviceID = ReverseAddr(deviceID);
		--ELAN_Trace(string.format("New Address: %x", deviceID))
	
		sCmd = GenerateMsg(deviceID, 1, MOVEMENT, deviceSubType, level, 0)
	
		SendPacket(sCmd, deviceID, deviceSubType, level)
    end

	--[[-------------------------------------------------------
		Called when the slider is set to close
	--]]-------------------------------------------------------
    function EDRV_DeactivateDevice(deviceID, deviceSubType, isReversed)
    -- Instruct the driver to turn the device off (OPEN)
		level = (isReversed == "true") and 100 or 0

		--reverse order because of Endianness.
		deviceID = ReverseAddr(deviceID);
		--ELAN_Trace(string.format("New Address: %x", deviceID))
	
		sCmd = GenerateMsg(deviceID, 1, MOVEMENT, deviceSubType, level, 0)
	
		SendPacket(sCmd, deviceID, deviceSubType, level)
    end

	--[[-------------------------------------------------------
		Called when the slider is set to a new position
	--]]-------------------------------------------------------
    function EDRV_DimDeviceTo(level, deviceID, deviceSubType, isReversed)
		-- Ternary for reversing motor
		level = (isReversed == "true") and 100 - level or level
	
		--reverse order because of Endianness.
		deviceID = ReverseAddr(deviceID);
		--ELAN_Trace(string.format("New Address: %x", deviceID))
	
		sCmd = GenerateMsg(deviceID, 1, MOVEMENT, deviceSubType, level, 0)
	
		SendPacket(sCmd, deviceID, deviceSubType, level)
    end

	--[[-------------------------------------------------------
		Tells the driver what to do with each configuration
		button
	--]]-------------------------------------------------------
	function EDRV_ExecuteConfigProc(procID)
		ELAN_Trace(string.format("procID = %s", procID))
		if procID == 1 then
			DeviceDiscovery()
		elseif procID == 2 then
			--ELAN_Trace("Clearing Command List")
			--for i,values in ipairs(command_list) do
			--	commandList[i] = nil
				--data = string.format()
				--EDRV_ProcessIncoming(data)
			--end
		end
	end

	--[[-------------------------------------------------------
		Called when the ELAN box gets a new message
	--]]-------------------------------------------------------
    function EDRV_ProcessIncoming(data)
		ELAN_Trace(string.format("    PROCESSING INCOMING DATA: %s", data))
		-- Is packed empty or nil
		if string.len(tostring(data)) == 0 then
			-- throw out packet?
			return
		end

		-- Debugging: print out full packet.
--		for i=1, string.len(tostring(data)), 1 do
--			ELAN_Trace(string.format("   %x", string.byte(data, i)))
--		end

		-- Check for the packet starting with 'X'
		startChar = string.byte(data, 1)
		while startChar == 0x58 do
			ELAN_Trace(string.format("    Packet: %s", StringToBytes(data)))
			packetSize = string.byte(data, 2)
			payloadLength = string.byte(data,12)
			-- if packet_size == nil or payload_length == nil then
			-- 	ELAN_Trace(string.format("Payload was nil"))
				-- TODO: Handle error
			-- else
			
			if (not packetSize or not payloadLength or packetSize ~= (payloadLength + HEADER_SIZE)) then
				ELAN_Trace(string.format("Length Mismatch; Packet Length %d but payload length + header %d",packetSize,(payloadLength+13)))
				return
				-- TODO: Handle error
			end
		
	 		local crc = string.byte(data,packetSize)
			-- Calculate CRC
			checkCRC = CalculateFullCRC(StringToBytes(string.sub(data,0,packetSize-1)))

			-- Check CRC
			if(checkCRC ~= crc) then
				ELAN_Trace(string.format("CRC Incorrect; Received %02x but calculated %02x",crc,checkCRC))
				-- TODO: Handle error
			end
			handleData(data)
			data = string.sub(data,packetSize+1)
			if data ~= nil then
				startChar = string.byte(data,1)			
			else 
				startChar = 'A'
			end
		end
    end



--| Unused ------------------------------------------------------------------------ 

    function EDRV_ActivateScene(deviceTag)
    -- Instruct the driver to turn the scene on
    end

    function EDRV_DeactivateScene(deviceTag)
    -- Instruct the driver to turn the scene off
    end

    function EDRV_DeviceBeginRampUp(deviceTag)
    -- Instruct the driver to start ramping up the device level
    end

    function EDRV_DeviceBeginRampDown(deviceTag)
    -- Instruct the driver to start rampng down the device level
    end

    function EDRV_DeviceEndRampUpDown(deviceTag)
    -- Instruct the driver to stop ramping the device up/down
    end

    function EDRV_VirtualButtonPress(deviceTag)
    -- Notification from the core that a virtual button was pressed
    end

    function EDRV_VirtualButtonRelease(deviceTag)
    -- Notification from the core that a virtual button was released
    end

    function EDRV_KeypadButtonPress(buttonTag, deviceTag)
    -- Notification from the core that a keypad button was pressed in the g! UI
    end

    function EDRV_KeypadButtonRelease(buttonTag, deviceTag)
    -- Notification from the core that a keypad button was released in the g! UI
    end


