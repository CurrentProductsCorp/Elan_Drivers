--| Init --------------------------------------------------------------------------
    function EDRV_Init()
    -- called when the driver starts up
    end


--| System Calls ------------------------------------------------------------------

--[[-------------------------------------------------------
	Called when the slider is set to open
--]]-------------------------------------------------------
    function EDRV_ActivateDevice(device_tag)
    -- Instruct the driver to turn the device on
		sCmd = string.format("%02x%04x%04x%02x%02x%02s", string.byte('X'), 1, 0xFF, 1, 2, 0)
		local crc = 0
		for i=1,string.len(sCmd),2 do
			calculated_crc = Calculate_CRC(string.sub(sCmd,i,i+1))
			crc = BitXOR(crc, calculated_crc)
		end
		sCmd = sCmd .. string.format("%02x",crc)
		ELAN_Trace(string.format("Sending: %s", sCmd))
		response = ELAN_SendToDeviceStringHEX(sCmd)
		ELAN_Trace(string.format("Response: %s", response))
    end

--[[-------------------------------------------------------
	Called when the slider is set to close
--]]-------------------------------------------------------
    function EDRV_DeactivateDevice(device_tag)
    -- Instruct the driver to turn the device off
		ELAN_Trace(string.format("Device ID: %s", device_tag))
		sCmd = string.format("%02x%04x%04x%02x%02x%02s", string.byte('X'), 1, 0xFF, 1, 2, 100)
		local crc = 0
		for i=1,string.len(sCmd),2 do
			calculated_crc = Calculate_CRC(string.sub(sCmd,i,i+1))
			crc = BitXOR(crc, calculated_crc)
		end
		sCmd = sCmd .. string.format("%02x",crc)
		ELAN_Trace(string.format("Sending: %s", sCmd))
		response = ELAN_SendToDeviceStringHEX(sCmd)
		ELAN_Trace(string.format("Response: %s", response))
    end

--[[-------------------------------------------------------
	Called when the slider is set to a new position
--]]-------------------------------------------------------
    function EDRV_DimDeviceTo(level, device_tag)
    -- Instruct the driver to set the device to a level
		sCmd = string.format("%02x%04x%04x%02x%02x%02s", string.byte('X'), 1, 0xFF, 1, 2, String_To_Bytes(level))
		local crc = 0
		for i=1,string.len(sCmd),2 do
			calculated_crc = Calculate_CRC(string.sub(sCmd,i,i+1))
			crc = BitXOR(crc, calculated_crc)
		end
		sCmd = sCmd .. string.format("%02x",crc)
		ELAN_Trace(string.format("Sending: %s", sCmd))
		response = ELAN_SendToDeviceStringHEX(sCmd)
		ELAN_Trace(string.format("Response: %s", response))
    end

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

    function EDRV_ProcessIncoming(data)
		ELAN_Trace(string.format("Data: %s", data));
    -- Process data sent from the device
    end

--| Helper Functions --------------------------------------------------------------

--[[-------------------------------------------------------
	Converts each ASCII value in a string into a byte,
	then puts the byte value into a string.
--]]-------------------------------------------------------
	function String_To_Bytes(value)
		final_string = ""
		for i=1, string.len(value) do
			final_string = final_string .. string.format("%02x",string.byte(value,i))
		end
		ELAN_Trace(string.format("Result:        ",final_string))
		return final_string
	end

--[[-------------------------------------------------------
	Calculates the CRC value based on the input string.
--]]-------------------------------------------------------
	function Calculate_CRC(value)
		--ELAN_Trace(string.format("Value: %02x", tonumber(value,16)))
		generator = 0x1D
		if(value == nil) then
			ELAN_Trace("CRC: nil")
			return 0
		end
		crc = tonumber(value,16)
		for i=0,7 do
			if (BitAND(crc,0x80) ~= 0) then
				crc = BitXOR( Lshift( crc, 1) , generator)
				ELAN_Trace(string.format("Anded:   %02x",crc))
			else
				crc = Lshift(crc, 1)
				ELAN_Trace(string.format("Shifted: %02x",crc))
			end
		end
		ELAN_Trace(string.format("CRC: %02x",crc))
		return crc
	end

--[[-------------------------------------------------------
	Bitwise AND for the CRC function
--]]-------------------------------------------------------
	function BitAND(a,b)
	    local p,c=1,0
	    while a>0 and b>0 do
	        local ra,rb=a%2,b%2
	        if ra+rb>1 then c=c+p end
	        a,b,p=(a-ra)/2,(b-rb)/2,p*2
	    end
	    return c
	end

--[[-------------------------------------------------------
	Bitwise OR for the CRC function
--]]-------------------------------------------------------
	function BitOR(a,b)
	    local p,c=1,0
	    while a+b>0 do
	        local ra,rb=a%2,b%2
	        if ra+rb>0 then c=c+p end
	        a,b,p=(a-ra)/2,(b-rb)/2,p*2
	    end
	    return c
	end

--[[-------------------------------------------------------
	Bitwise XOR for the CRC function
--]]-------------------------------------------------------	
	function BitXOR(a,b)
	    local p,c=1,0
	    while a>0 and b>0 do
	        local ra,rb=a%2,b%2
	        if ra~=rb then c=c+p end
	        a,b,p=(a-ra)/2,(b-rb)/2,p*2
	    end
	    if a<b then a=b end
	    while a>0 do
	        local ra=a%2
	        if ra>0 then c=c+p end
	        a,p=(a-ra)/2,p*2
	    end
	    return c
	end

--[[-------------------------------------------------------
	Bitwise Left Shift for the CRC function
--]]-------------------------------------------------------
	function Lshift(x, by)
	  return BitAND((x * 2 ^ by),0xff)
	end

--[[-------------------------------------------------------
	Bitwise Right Shift for the CRC function
--]]-------------------------------------------------------	
	function Rshift(x, by)
	  return math.floor(x / 2 ^ by)
	end












