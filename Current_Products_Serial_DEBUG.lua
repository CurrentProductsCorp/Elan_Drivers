
    function EDRV_Init()
    -- called when the driver starts up
    end

    function EDRV_ActivateDevice(device_tag)
    -- Instruct the driver to turn the device on
		ELAN_Trace(string.format("Device ID: %s", device_tag))
		sCmd = string.format("%02x%02x%02x%02x%02x%02x%02x", string.byte('X'), device_tag, 1234, 16, 8, 100, Calculate_CRC(100))
		ELAN_Trace(string.format("Sending: %s", sCmd))
		ELAN_SendToDeviceStringHEX(sCmd)
    end

    function EDRV_DeactivateDevice(device_tag)
    -- Instruct the driver to turn the device off
		ELAN_Trace(string.format("Device ID: %s", device_tag))
		sCmd = string.format("%02x%02x%02x%02x%02x%02x%02x", string.byte('X'), device_tag, 1234, 16, 8, 0, Calculate_CRC(0))
		ELAN_Trace(string.format("Sending: %s", sCmd))
		ELAN_SendToDeviceStringHEX(sCmd)
    end

    function EDRV_DimDeviceTo(level, device_tag)
    -- Instruct the driver to set the device to a level
		ELAN_Trace(string.format("Device ID: %s", device_tag))
		--sCmd = string.format("%02x %04x %04x %02x %02x %02x", string.byte('X'), device_tag, 1234, 1, 1, level)
		sCmd = {string.byte('X'), string.byte(tostring(device_tag)), string.byte(tostring(1234)), string.byte(tostring(1)), string.byte(tostring(1)), string.byte(tostring(level))}
		local crc = 0
		for i=1,5 do
			ELAN_Trace(string.format("sCmd at %d is %02x ",i,sCmd[i]))
			crc = BitXOR(crc, Calculate_CRC(sCmd[i]))
		end
		ELAN_Trace(string.format("CRC Final:  %02x",crc))
		ELAN_Trace(string.format("Cmd Final:  %s",sCmd))
		table.insert(sCmd,crc)
		--sCmd = sCmd .. string.format(" %02x",crc)
		ELAN_Trace(string.format("Sending:    %s ",sCmd[1],))
		ELAN_Trace("Should be:  58 0001 04d2 01 01 5a 4f")
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

	function Calculate_CRC(value)
		ELAN_Trace(string.format("Value: %02x", value))
		generator = 0x1D
		if(value == nil) then
			ELAN_Trace("CRC: nil")
			return 0
		end
		crc = string.byte(value)
		--ELAN_Trace(string.format("value: %x",crc))
		for i=0,8 do
			if (BitAND(crc,0x80) ~= 0) then
				crc = BitXOR( Lshift( crc, 1), generator)
				ELAN_Trace(string.format("Anded:   %04x",crc))
			else
				crc = Lshift(crc, 1)
				ELAN_Trace(string.format("Shifted: %04x",crc))
			end
		end
		ELAN_Trace(string.format("CRC: %04x",crc))
		return crc
	end

	function BitAND( a,b) --Bitwise and
	    local p,c=1,0
	    while a>0 and b>0 do
	        local ra,rb=a%2,b%2
	        if ra+rb>1 then c=c+p end
	        a,b,p=(a-ra)/2,(b-rb)/2,p*2
	    end
	    return c
	end

	function BitOR(a,b)--Bitwise or
	    local p,c=1,0
	    while a+b>0 do
	        local ra,rb=a%2,b%2
	        if ra+rb>0 then c=c+p end
	        a,b,p=(a-ra)/2,(b-rb)/2,p*2
	    end
	    return c
	end
	
	function BitXOR(a,b)--Bitwise xor
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

	function Lshift(x, by)
	  return BitAND((x * 2 ^ by),0xff)
	end
	
	function Rshift(x, by)
	  return math.floor(x / 2 ^ by)
	end

	function toByte()
		
	end

    function EDRV_ProcessIncoming(data)
		ELAN_Trace(string.format("Data: %s", data));
    -- Process data sent from the device
    end









 