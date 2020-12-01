-- Current_Products_Serial.lua



--| Globals -----------------------------------------------------------------------

	logging = false	

--| Init --------------------------------------------------------------------------
    
	function EDRV_Init()
	    -- called when the driver starts up
		ELAN_Trace("DRIVER STARTING UP")
		ELAN_SetTimer(0, 20 * 1000) --Timer to get the position every 20 seconds
    end



--| System Calls ------------------------------------------------------------------

	--[[-------------------------------------------------------
		Called when the config page is updated
	--]]-------------------------------------------------------
	function EDRV_SetConfigPgString (sPageTag, sTag, sValue)
		--Remove whitespace
		deviceString = trim(sValue)
		--Set to lowercase
		deviceString = string.lower(deviceString)
		ELAN_SetPersistentValue("swappedDevices",deviceString)
		ELAN_Trace(string.format("Input String: %s", deviceString))
	end	

	--[[-------------------------------------------------------
		Called when the slider is set to open
	--]]-------------------------------------------------------
    function EDRV_ActivateDevice(deviceID, deviceSubType)
		deviceLabel = deviceSubType == "blackout" and "p" or "s" 		
		searchID = deviceID .. deviceLabel
		isReversed = getIsReversed(searchID)

    		-- Instruct the driver to turn the device on (CLOSE)
		level = (isReversed) and 100 or 0

		--reverse order because of Endianness.
		deviceID = ReverseAddr(deviceID);
		--ELAN_Trace(string.format("New Address: %x", deviceID))

		sCmd = GenerateMsg(deviceID, 1, MOVEMENT, deviceSubType, level, 0)
	
		SendPacket(sCmd, deviceID, deviceSubType, level)
    end

	--[[-------------------------------------------------------
		Called when the slider is set to close
	--]]-------------------------------------------------------
    function EDRV_DeactivateDevice(deviceID, deviceSubType)
		deviceLabel = deviceSubType == "blackout" and "p" or "s" 
		searchID = deviceID .. deviceLabel
		isReversed = getIsReversed(searchID)

    		-- Instruct the driver to turn the device off (OPEN)
		level = (isReversed) and 0 or 100

		--reverse order because of Endianness.
		deviceID = ReverseAddr(deviceID);
	
		sCmd = GenerateMsg(deviceID, 1, MOVEMENT, deviceSubType, level, 0)
	
		SendPacket(sCmd, deviceID, deviceSubType, level)
    end

	--[[-------------------------------------------------------
		Called when the slider is set to a new position
	--]]-------------------------------------------------------
    function EDRV_DimDeviceTo(level, deviceID, deviceSubType)
		deviceLabel = deviceSubType == "blackout" and "p" or "s" 
		searchID = deviceID .. deviceLabel
		isReversed = getIsReversed(searchID)
		ELAN_Trace(string.format("Got isReversesd %s from %s", tostring(isReversed), searchID))		

		-- Ternary for reversing motor
		level = (isReversed) and level or 100 - level
	
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
		if procID == 1 then
			DeviceDiscovery()
		end
	end

	--[[-------------------------------------------------------
		Called when the ELAN box gets a new message
	--]]-------------------------------------------------------
    function EDRV_ProcessIncoming(data)
		ELAN_Trace(string.format("    PROCESSING INCOMING DATA: %s", StringToBytes(string.sub(data,0,30))))
		-- Is packed empty or nil
		if string.len(tostring(data)) == 0 then
			-- throw out packet.
			return
		end

		-- Debugging: print out full packet.
--		for i=1, string.len(tostring(data)), 1 do
--			ELAN_Trace(string.format("   %x", string.byte(data, i)))
--		end

		-- Check for the packet starting with 'X'
--		startChar = string.byte(data, 1)
		preamble = StringToBytes(string.sub(data,0,4))
		ELAN_Trace(string.format("Preamble %s is %s",preamble,tostring(preamble == "fe161616")))
		while preamble == "fe161616" do
			ELAN_Trace(string.format("    Packet: %s", StringToBytes(data)))
			packetSize = string.byte(data, PACKET_SIZE_LOCATION)
			payloadLength = string.byte(data, PAYLOAD_LENGTH_LOCATION)
			ELAN_Trace(string.format("packetSize: %02x", packetSize))
			ELAN_Trace(string.format("packetLength: %02x", payloadLength))
			-- if packet_size == nil or payload_length == nil then
			-- 	ELAN_Trace(string.format("Payload was nil"))
				-- TODO: Handle error
			-- else
			
			if (not packetSize or not payloadLength or packetSize ~= (payloadLength + HEADER_SIZE)) then
				ELAN_Trace(string.format("Length Mismatch; Packet Length %d but payload length + header %d",packetSize,(payloadLength+13)))
				return
			end
		
	 		local crc = string.byte(data,packetSize)
			-- Calculate CRC
			checkCRC = CalculateFullCRC(StringToBytes(string.sub(data,0,packetSize-1)))

			-- Check CRC
			if(checkCRC ~= crc) then
				ELAN_Trace(string.format("CRC Incorrect; Received %02x but calculated %02x",crc,checkCRC))
			end
			handleData(data)
			data = string.sub(data,packetSize+1)
			if data ~= nil then
				preamble = StringToBytes(string.sub(data,0,4))			
			else 
				preamble = 'A'
			end
		end
    end

	function EDRV_OnTimer(timer_id)
		ELAN_Trace("Timer expired.")
		DeviceDiscovery()
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















