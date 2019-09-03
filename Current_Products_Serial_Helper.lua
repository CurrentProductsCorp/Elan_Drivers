-- Current_Products_Serial_Helper.lua



--| Handling Incoming Data --------------------------------------------------------

	--[[-------------------------------------------------------
		Parses incoming data
	--]]-------------------------------------------------------
	function handleData(data)
		-- Since valid, get all other bytes
		payload_length = string.byte(data, PAYLOAD_LENGTH_LOCATION)
		request_byte = string.byte(data, REQUEST_BYTE_LOCATION)
		to_address = string.byte(data,TO_ADDR_LOCATION,6)
		from_address = string.byte(data,FROM_ADDR_LOCATION,10)

		if payload_length > 0 and string.len(tostring(data)) > HEADER_SIZE then
			payload = string.byte(data,PAYLOAD_LOCATION,(PAYLOAD_LOCATION+payload_length))
		end
		-- Request
		if request_byte == 0x01 then
			ELAN_Trace("Has request flag")
		-- Acknowledged
		elseif request_byte == 0x02 then
			ELAN_Trace("Has Acknowledge flag")
			if(payload_length > 0) then
				HandleAcknowledgeByte(data, from_address, payload_length, payload);
			end
		-- Not Acknowledged
		elseif request_byte == 0x04 then
			ELAN_Trace("Has Not Acknowledged flag")
		-- Announce
		elseif request_byte == 0x40 then
			ELAN_Trace("Has announce packet")
			if(payload_length > 0) then
				HandleAnnounceByte(data, from_address, payload_length, payload);
			end
		-- Has Error
		elseif request_byte == 0x08 then
			ELAN_TRACE("Has Error")
		-- Heartbeat
		elseif request_byte == 0x80 then
			ELAN_Trace("Has Heartbeat Flag")
		-- If it isn't an announce packet, see if there's a payload.
		elseif(length > 12) then
			payloadString = string.sub(tostring(data), 12, length-1)
			ELAN_Trace(string.format("Payload: [%s]", payloadString));
			data_length = string.len(payloadString)
			for i=1, data_length, 1 do
				ELAN_Trace(string.format("Byte: %x ", string.byte(payloadString, i)))
				-- payloadString = payloadString .. string.format("%x ", string.byte(payloadString, i))
			end		
		end	
	end

	--[[-------------------------------------------------------
		Makes a new device if the ACK doesn't alread exist as
		a device, otherwise, it removes the movement from the 
		command list
	--]]-------------------------------------------------------
	function HandleAcknowledgeByte(data, from_address, payload_length, payload)
		local_dev_list = ELAN_GetPersistentValue("device_list")
		ELAN_Trace(string.format("from_address: %s", from_address))
		byte1, byte2, byte3, byte4 = string.byte(data,7,10) --Get the bytes that make up the address. Added or concatenated?
		ELAN_Trace(string.format("from: %d",Bytes_To_Addr(byte1, byte2, byte3, byte4)))

		deviceID = Bytes_To_Addr(byte1, byte2, byte3, byte4)

		if local_dev_list[from_address] == nil then		ELAN_Trace(string.format("DeviceID: %d",deviceID))
			-- Determine if device is dual or single
			deviceNumMotors = GetNumberMotors(payload)
			if deviceNumMotors > 1 then
				ELAN_AddLightingDevice("DIMMER", deviceID, deviceID .. " Motor 1", "blackout", "false")
				ELAN_AddLightingDevice("DIMMER", deviceID, deviceID .. " Motor 2", "sheer", "false")
			else
				ELAN_AddLightingDevice("DIMMER", deviceID, deviceID .. "", "Device Type", "blackout","false")
			end
			-- TODO: Reversed motor?
			table.append(dev_list,from_address)
			ELAN_SetPersistentValue("device_list", dev_list)
		end
		
		-- If command is a movement acknowledge
		if string.byte(data,13) == 0x01 then
			-- If there is a device of type blackout
			if string.byte(data,15) ~= 0xFF then
				-- remove the waited item from the queue
				queue[string.format("%08x%s",deviceID,"blackout")] = nil
			end
			-- If there is a device of type sheer
			if string.byte(data,18) ~= 0xFF then
				-- remove the waited item from the queue
				queue[string.format("%08x%s",deviceID,"sheer")] = nil
			end
		end
	end

	--[[-------------------------------------------------------
		Makes a new device if the device doesn't already exist
	--]]-------------------------------------------------------
	function HandleAnnounceByte(data, from_address, payload_length, payload)
		byte1, byte2, byte3, byte4 = string.byte(data,7,10) -- Get the bytes that make up the address. Added or concatenated?
		ELAN_Trace(string.format("from: %d",Bytes_To_Addr(byte1, byte2, byte3, byte4)))

		deviceID = Bytes_To_Addr(byte1, byte2, byte3, byte4)

		-- deviceID = string.unpack(">I4", string.sub(data,7,10))
		ELAN_Trace(string.format("DeviceID: %d",deviceID))

		-- Determine if device is dual or single
		deviceNumMotors = GetNumberMotors(payload)
		if deviceNumMotors > 1 then
			ELAN_AddLightingDevice("DIMMER", deviceID, deviceID .. " Motor 1", "blackout", "false")
			ELAN_AddLightingDevice("DIMMER", deviceID, deviceID .. " Motor 2", "sheer", "false")
		else
			ELAN_AddLightingDevice("DIMMER", deviceID, deviceID .. "", "Device Type", "blackout","false")
		end
		-- TODO: Reversed motor?
		table.append(dev_list,from_address)
		ELAN_SetPersistentValue("device_list", dev_list)
	end

	--[[-------------------------------------------------------
		Grabs the number of motors found in the payload
	--]]-------------------------------------------------------
	function GetNumberMotors(payload) 
		if string.byte(payload,4) ~= 0xFF and string.byte(payload,5) ~= 0xFF then
			return 0x00
		elseif string.byte(payload,4) ~= 0xFF then
			return 0x01
		elseif string.byte(payload,5) ~= 0xFF then
			return 0x02
		else
			return 0xFF
		end
	end

	--[[-------------------------------------------------------
		Needed for sending messages, since all parts of 
		outgoing messages are in bytes
	--]]-------------------------------------------------------
	function GetDeviceSubTypeInBytes(device_sub_type)
		if string.find(string.lower(device_sub_type),"blackout") then
			return 0x01
		elseif string.find(string.lower(device_sub_type),"sheer") then
			return 0x02
		end
	end

	--[[-------------------------------------------------------
		Makes a broadcast to get all devices after clearing 
		the device list
	--]]-------------------------------------------------------
	function DeviceDiscovery()
		dev_list = {}
		ELAN_SetPersistentValue("device_list", dev_list)
		ELAN_Trace(string.format("Device ID: %s", device_tag))
		sCmd = string.format("%02x0000%04x%02x%02x%02s", string.byte('X'), 0, 65, 3, 55)
		local crc = 0
		for i=1,string.len(sCmd),2 do
			calculated_crc = Calculate_CRC(string.sub(sCmd,i,i+1))
			crc = BitXOR(crc, calculated_crc)
		end
		sCmd = sCmd .. string.format("%02x",crc)
		ELAN_Trace(string.format("Sending: %s", sCmd))
		response = ELAN_SendToDeviceStringHEX(sCmd)
		ELAN_Trace(string.format("Response: %s", response))
		-- TODO: Devices not found.
	end




--| Message Generation ------------------------------------------------------------

	--[[-------------------------------------------------------
		Takes everything needed for the payload and formats it
		into a byte array that the device can use.
	--]]-------------------------------------------------------
	function Generate_Msg(to_addr, request_byte, payload_type, device_subtype, position, toggle_byte)
		type_byte = 0x03
		if (device_subtype == "blackout") then
			type_byte = 0x01
		elseif (device_subtype == "sheer") then
			type_byte = 0x02
		end
		packet = string.format("%02x",START_CHAR)
		packet_msg = ""
		if payload_type == MOVEMENT then
			packet_msg = string.format("%02x%02x%02x%02x",0x03,MOVEMENT,type_byte,position)
		elseif payload_type == DEVICE_INFO then
			packet_msg = string.format("%02x%02x",0x01,DEVICE_INFO)
		elseif payload_type == SWAP_MOTOR then
			packet_msg = string.format("%02x%02x%02x",0x02,SWAP_MOTOR,toggle_byte)
		elseif payload_type == DELETE_MOTOR then
			packet_msg = string.format("%02x%02x%02x",0x02,DELETE_MOTOR,type_byte)
		elseif payload_type == REVERSE_DIRECTION then
			packet_msg = string.format("%02x%02x%02x",0x02,REVERSE_DIRECTION,BitXOR(toggle_byte,type_byte))
		elseif payload_type == JOG then
			packet_msg = string.format("%02x%02x%02x",0x02,JOG,type_byte)
		elseif payload_type == SMART_ASSIST then
			packet_msg = string.format("%02x%02x%02x",0x02,SMART_ASSIST,toggle_byte)
		end
		payload_size = (string.len(packet_msg)/2)
		pkt_size = 13 + payload_size
		ELAN_Trace(string.format("payload_size: %02x",payload_size))
		ELAN_Trace(string.format("packet_size: %02x", pkt_size))
		packet = packet .. string.format("%02x",pkt_size) .. string.format("%08x%08x%02x%02x",to_addr,0,1,payload_size) .. packet_msg
		ELAN_Trace(string.format("Output message: %s",packet))

		crc = Calculate_Full_CRC(packet)
		packet = packet .. string.format("%02x",crc)
		
		return packet
	end
	
	--[[-------------------------------------------------------
		Creates an error message for cases where message does
		match. 
	--]]-------------------------------------------------------
	function Generate_Error_Msg(to_addr, err_type, command_type, options_byte)
		packet = string.format("%02x%0x02", START_CHAR,0x10,to_addr,0,ERR,0x03,err_type,command_type,options_byte)
		crc = Calculate_Full_CRC(packet)
		packet = packet .. string.format("%02x",crc)		
		return packet
	end




--| Byte Conversions --------------------------------------------------------------

	--[[-------------------------------------------------------
		Converts each ASCII value in a string into a byte,
		then puts the byte value into a string.
	--]]-------------------------------------------------------
	function String_To_Bytes(value)
		final_string = ""
		for i=1, string.len(value) do
			final_string = final_string .. string.format("%02x",string.byte(value,i))
		end
		return final_string
	end

	--[[-------------------------------------------------------
		Takes each individual byte value ORs them together into
		one address
	--]]-------------------------------------------------------
	function Bytes_To_Addr(byte1, byte2, byte3, byte4)
		total = BitOR(LshiftLong(byte1,8),byte2)
		total = BitOR(LshiftLong(total,8),byte3)
		total = BitOR(LshiftLong(total, 8),byte4)
		return total
	end

	--[[-------------------------------------------------------
		Takes each individual byte value ORs them together into
		one address
	--]]-------------------------------------------------------
	function Addr_To_Bytes(addr_string)
		addr_int = tonumber(addr_string)
		return string.format("%08x",addr_int)
	end



--| CRC Calculation ---------------------------------------------------------------

	--[[-------------------------------------------------------
		XORs full string to get the CRC
	--]]-------------------------------------------------------
	function Calculate_Full_CRC(value)
		local crc = 0
		for i=1,string.len(value),2 do
			calculated_crc = Calculate_CRC(string.sub(value,i,i+1))
			crc = BitXOR(crc, calculated_crc)
		end
		return crc
	end

	--[[-------------------------------------------------------
		Calculates the CRC value based on the input byte
	--]]-------------------------------------------------------
	function Calculate_CRC(value)
		generator = 0x1D
		if(value == nil) then
			return 0
		end
		crc = tonumber(value,16)
		for i=0,7 do
			if (BitAND(crc,0x80) ~= 0) then
				crc = BitXOR( Lshift( crc, 1) , generator)
			else
				crc = Lshift(crc, 1)
			end
		end
		--ELAN_Trace(string.format("CRC: %02x",crc))
		return crc
	end



--| Bitwise Operations ------------------------------------------------------------

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
		Bitwise Left Shift for the CRC function
	--]]-------------------------------------------------------
	function LshiftLong(x, by)
	  return BitAND((x * 2 ^ by),0xffffffff)
	end

	--[[-------------------------------------------------------
		Bitwise Right Shift for the CRC function
	--]]-------------------------------------------------------	
	function Rshift(x, by)
	  return math.floor(x / 2 ^ by)
	end



--| Debug -------------------------------------------------------------------------

	--[[-------------------------------------------------------
		Prints whatever is in the command list
	--]]-------------------------------------------------------
	function Print_Queue()
		for k, v in pairs(queue) do
		    ELAN_Trace(string.format("K: %s V: %s", k, v))
		end
	end	