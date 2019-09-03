-- Current_Products_Serial.lua



--| Globals -----------------------------------------------------------------------
	
	-- Queue to hold outgoing messages with no replies.
	queue = {}
	-- List of devices added.
	dev_list = {}



--| Init --------------------------------------------------------------------------
    
	function EDRV_Init()
	    -- called when the driver starts up
		-- May be used to get all the current devices later
    end



--| System Calls ------------------------------------------------------------------

	--[[-------------------------------------------------------
		Called when the slider is set to open
	--]]-------------------------------------------------------
    function EDRV_ActivateDevice(device_id, device_name, device_sub_type, is_reversed)
    -- Instruct the driver to turn the device on (CLOSE)
		level = (is_reversed == "true") and 0 or 100
		sCmd = Generate_Msg(device_id, 1, MOVEMENT, device_sub_type, level, 0)
		ELAN_Trace(string.format("Sending: %s", sCmd))
		queue[string.format("%08x%s",device_id,device_sub_type)] = {sCmd}
		-- If no response, try sending again.
		resend_count = 0
		while resend_count < 3 do
			if queue[string.format("%08x%s",device_id,device_sub_type)] == nil then 
				break
			end
			ELAN_Trace(string.format("Sending: %s", sCmd))
			response = ELAN_SendToDeviceStringHEX(sCmd)
			ELAN_Trace(string.format("Response: %s", response))
			ELAN_Sleep(30)
			Print_Queue()
			resend_count = resend_count + 1
		end
    end

	--[[-------------------------------------------------------
		Called when the slider is set to close
	--]]-------------------------------------------------------
    function EDRV_DeactivateDevice(device_id, device_name, device_sub_type, is_reversed)
    -- Instruct the driver to turn the device off (OPEN)
		level = (is_reversed == "true") and 100 or 0
		sCmd = Generate_Msg(device_id, 1, MOVEMENT, device_sub_type, level, 0)
		queue[string.format("%08x%s",device_id,device_sub_type)] = {sCmd}
		-- If no response, try sending again.
		resend_count = 0
		while resend_count < 3 do
			if queue[string.format("%08x%s",device_id,device_sub_type)] == nil then 
				break
			end
			ELAN_Trace(string.format("Sending: %s", sCmd))
			response = ELAN_SendToDeviceStringHEX(sCmd)
			ELAN_Trace(string.format("Response: %s", response))
			ELAN_Sleep(30)
			resend_count = resend_count + 1
		end
    end

	--[[-------------------------------------------------------
		Called when the slider is set to a new position
	--]]-------------------------------------------------------
    function EDRV_DimDeviceTo(level, device_id, device_name, device_sub_type, is_reversed)
	ELAN_Trace(string.format("Level: %d", level))
	level = (is_reversed == "true") and 100 - level or level
	size = string.len(tostring(level))
    -- Instruct the driver to set the device to a level
		sCmd = Generate_Msg(device_id, 1, MOVEMENT, device_sub_type, level, 0)
		queue[string.format("%08x%s",device_id,device_sub_type)] = {sCmd}
		-- If no response, try sending again.
		resend_count = 0
		while resend_count < 3 do
			if queue[string.format("%08x%s",device_id,device_sub_type)] == nil then 
				break
			end
			ELAN_Trace(string.format("Sending: %s", sCmd))
			response = ELAN_SendToDeviceStringHEX(sCmd)
			ELAN_Trace(string.format("Response: %s", response))
			--response = ELAN_SendToDeviceStringHEX(sCmd)
			--ELAN_Trace(string.format("Response: %s", response))
			ELAN_Sleep(30)
			Print_Queue()
			resend_count = resend_count + 1
		end

    end

	--[[-------------------------------------------------------
		Tells the driver what to do with each configuration
		button
	--]]-------------------------------------------------------
	function EDRV_ExecuteConfigProc(proc_id)
		ELAN_Trace(string.format("proc_id = %s", proc_id))
		if proc_id == 1 then
			DeviceDiscovery()
		elseif proc_it == 2 then
			ELAN_Trace("Clearing Queue")
			for i,values in ipairs(queue) do
				queue[i] = nil
				--data = string.format()
				--EDRV_ProcessIncoming(data)
			end
		end
	end

	--[[-------------------------------------------------------
		Called when the ELAN box gets a new message
	--]]-------------------------------------------------------
    function EDRV_ProcessIncoming(data)
		ELAN_Trace("Incoming Data: %s", data)
		-- Is packed empty or nil
		if data == nil or string.len(tostring(data)) == 0 then
			-- throw out packet?
			return
		end

		-- Debugging: print out full packet.
		for i=1, string.len(tostring(data)), 1 do
			ELAN_Trace(string.format("   %x", string.byte(data, i)))
		end

		-- Check for the packet starting with 'X'
		start_char = string.byte(data, 1)
		if start_char == 0x58 then
			packet_size = string.byte(data, 2)
			payload_length = string.byte(data,12)
			if packet_size == nil or payload_length == nil then
				ELAN_Trace(string.format("Payload was nil"))
				-- Handle error
			elseif packet_size ~= (payload_length + HEADER_SIZE) then
				ELAN_Trace(string.format("Length Mismatch; Packet Length %d but payload length + header %d",packet_size,(payload_length+13)))
				-- Handle error
			end

	 		crc = string.byte(data,length)
			-- Calculate CRC
			local check_crc = Calculate_Full_CRC(data)

			-- Check CRC
			if(check_crc ~= crc) then
				ELAN_Trace(string.format("CRC Incorrect; Received %02x but calculated %02x",crc,check_crc))
			end

			handleData(data)
		end
    end



--| Unused ------------------------------------------------------------------------ 

    function EDRV_ActivateScene(device_tag)
    -- Instruct the driver to turn the scene on
    end

    function EDRV_DeactivateScene(device_tag)
    -- Instruct the driver to turn the scene off
    end

    function EDRV_DeviceBeginRampUp(device_tag)
    -- Instruct the driver to start ramping up the device level
    end

    function EDRV_DeviceBeginRampDown(device_tag)
    -- Instruct the driver to start rampng down the device level
    end

    function EDRV_DeviceEndRampUpDown(device_tag)
    -- Instruct the driver to stop ramping the device up/down
    end

    function EDRV_VirtualButtonPress(device_tag)
    -- Notification from the core that a virtual button was pressed
    end

    function EDRV_VirtualButtonRelease(device_tag)
    -- Notification from the core that a virtual button was released
    end

    function EDRV_KeypadButtonPress(button_tag, device_tag)
    -- Notification from the core that a keypad button was pressed in the g! UI
    end

    function EDRV_KeypadButtonRelease(button_tag, device_tag)
    -- Notification from the core that a keypad button was released in the g! UI
    end
