-- Current_Products_Serial_Helper.lua



--| Handling Incoming Data --------------------------------------------------------

	--[[-------------------------------------------------------
		Parses incoming data
	--]]-------------------------------------------------------
	function handleData(data)
		-- Since valid, get all other bytes
		payloadLength = string.byte(data, PAYLOAD_LENGTH_LOCATION)
		requestByte = string.byte(data, REQUEST_BYTE_LOCATION)
		toAddr1, toAddr2, toAddr3, toAddr4 = string.byte(data, TO_ADDR_LOCATION, TO_ADDR_LOCATION + 4)
		fromAddr1, fromAddr2, fromAddr3, fromAddr4 = string.byte(data, FROM_ADDR_LOCATION, FROM_ADDR_LOCATION + 4)
		
		toAddress =  BytesToAddr(toAddr1, toAddr2, toAddr3, toAddr4)
		fromAddress = BytesToAddr(fromAddr1, fromAddr2, fromAddr3, fromAddr4)
	
		ELAN_Trace(string.format("Data To String: %s", tostring(data)))
		ELAN_Trace(string.format("Length: %s", string.len(tostring(data))))
		if payloadLength > 0 and string.len(tostring(data)) > HEADER_SIZE then
			ELAN_Trace(string.format("Payload Length: %d", payloadLength))
			payload = {string.byte(data, PAYLOAD, (PAYLOAD_LOCATION + payloadLength))}
			commandByte = string.byte(data, PAYLOAD_LOCATION)
			ELAN_Trace(string.format("Command Byte: %02x", commandByte))
		end
		-- Request
		if requestByte == 0x01 then
			ELAN_Trace("Has request flag")
		-- Acknowledged
		elseif requestByte == 0x02 then
			ELAN_Trace("Has Acknowledge flag")
			if(payloadLength > 0) then
				HandleAcknowledgeByte(data, fromAddress, payloadLength, commandByte);
			end
		-- Not Acknowledged
		elseif requestByte == 0x04 then
			ELAN_Trace("Has Not Acknowledged flag")
		-- Announce
		elseif requestByte == 0x40 then
			ELAN_Trace("Has announce packet")
			if(payloadLength > 0) then
				HandleAnnounceByte(data, fromAddress);
			end
		-- Has Error
		elseif requestByte == 0x08 then
			ELAN_Trace("Has Error")
			-- TODO: Get specific error
		-- Heartbeat
		elseif requestByte == 0x80 then
			ELAN_Trace("Has Heartbeat Flag")
		-- If it isn't an announce packet, see if there's a payload.
		-- elseif(length > 12) then
		--	payloadString = string.sub(tostring(data), 12, length-1)
		--	ELAN_Trace(string.format("Payload: [%s]", payloadString));
		--	dataLength = string.len(payloadString)
		--	for i=1, dataLength, 1 do
		--		ELAN_Trace(string.format("Byte: %x ", string.byte(payloadString, i)))
				-- payloadString = payloadString .. string.format("%x ", string.byte(payloadString, i))
		--	end		
		end	
	end

	--[[-------------------------------------------------------
		Makes a new device if the ACK doesn't alread exist as
		a device, otherwise, it removes the movement from the 
		command list
	--]]-------------------------------------------------------
	function HandleAcknowledgeByte(data, fromAddress, payloadLength, commandType)
		ELAN_Trace(string.format("fromAddress: %s", fromAddress))
		byte1, byte2, byte3, byte4 = string.byte(data,7,10) --Get the bytes that make up the address. Added or concatenated?
		--ELAN_Trace("Got the bytes of the address")
		--deviceID = BytesToAddr(byte1, byte2, byte3, byte4)
		--ELAN_Trace(string.format("from: %d",deviceID))

		ELAN_Trace(string.format("Type Byte: %02x",commandType))		
		if commandType == DEVICE_INFO then		
			ELAN_Trace(string.format("DeviceID: %s", fromAddress))
			-- Determine if device is dual or single
			deviceNumMotors = GetNumberMotors(string.sub(data, PAYLOAD_LOCATION, (PAYLOAD_LOCATION + payloadLength)))
			ELAN_Trace(string.format("Number of Motors: %02x", deviceNumMotors))
			if deviceNumMotors == 0x03 and deviceNumMotors ~= 0xFF then
				ELAN_AddLightingDevice("DIMMER", fromAddress, fromAddress.. " Motor 1", "blackout", "false")
				ELAN_AddLightingDevice("DIMMER", fromAddress, fromAddress.. " Motor 2", "sheer", "false")
			elseif deviceNumMotors == 0x01 then
				ELAN_AddLightingDevice("DIMMER", fromAddress, fromAddress.. "", "blackout", "false")
			elseif deviceNumMotors == 0x02 then
				ELAN_AddLightingDevice("DIMMER", fromAddress, fromAddress.. "", "sheer", "false")
			end
			-- TODO: Reversed motor(?)
		-- If command is a movement acknowledge
		elseif commandType == MOVEMENT then
			-- If there is a device of type blackout
			blackoutTo = string.byte(data,14)
			sheerTo = string.byte(data,18)
			if blackoutTo ~= nil and blackoutTo ~= 0xFF then
				-- remove the waited item from the command_list
				ELAN_DeletePersistentValue(string.format("%08x:%s:%02x",fromAddress,"blackout",blackoutTo))
			end
			-- If there is a device of type sheer
			if sheerTo ~= nil and sheerTo ~= 0xFF then
				-- remove the waited item from the command_list
				ELAN_DeletePersistentValue(string.format("%08x:%s:%02x",fromAddress,"sheer",sheerTo))
			end
		end
	end

	--[[-------------------------------------------------------
		Makes a new device if the device doesn't already exist
	--]]-------------------------------------------------------
	function HandleAnnounceByte(data, fromAddress)
		sCmd = string.format("%02x%02x%08x%08x%02x%02x%02s", string.byte('X'), 0x0E, fromAddress, 0x00000064, 1, 1, DEVICE_INFO)
		local crc = 0
		crc = CalculateFullCRC(sCmd)
		sCmd = sCmd .. string.format("%02x",crc)
		response = ELAN_SendToDeviceStringHEX(sCmd)
	end

	--[[-------------------------------------------------------
		Grabs the number of motors found in the payload
	--]]-------------------------------------------------------
	function GetNumberMotors(payload)
		ELAN_Trace(string.format("MOTOR PAYLOAD: %02x%02x",string.byte(payload,10),string.byte(payload,11)))
		if string.byte(payload,11) ~= 0xFF and string.byte(payload,12) ~= 0xFF then
			return 0x03
		elseif string.byte(payload,11) ~= 0xFF then
			return 0x01
		elseif string.byte(payload,12) ~= 0xFF then
			return 0x02
		else
			return 0xFF
		end
	end

	--[[-------------------------------------------------------
		Needed for sending messages, since all parts of 
		outgoing messages are in bytes
	--]]-------------------------------------------------------
	function GetDeviceSubTypeInBytes(deviceSubType)
		if string.find(string.lower(deviceSubType),"blackout") then
			return 0x01
		elseif string.find(string.lower(deviceSubType),"sheer") then
			return 0x02
		end
	end

	--[[-------------------------------------------------------
		Makes a broadcast to get all devices after clearing 
		the device list
	--]]-------------------------------------------------------
	function DeviceDiscovery()
		sCmd = string.format("%02x%02x%08x%08x%02x%02x%02x", string.byte('X'), 0x0E, 0xFFFFFFFF, 0x00000064, 1, 1, DEVICE_INFO)
		local crc = 0
		crc = CalculateFullCRC(sCmd)
		sCmd = sCmd .. string.format("%02x",crc)
		ELAN_Trace(string.format("Sending: %s", sCmd))
		response = ELAN_SendToDeviceStringHEX(sCmd)
		ELAN_Trace(string.format("Response: %s", response))
	end



--| Message Generation ------------------------------------------------------------

	--[[-------------------------------------------------------
		Takes everything needed for the payload and formats it
		into a byte array that the device can use.
	--]]-------------------------------------------------------
	function GenerateMsg(toAddr, requestByte, payloadType, deviceSubType, position, toggleByte)
		typeByte = 0x03
		if (deviceSubType == "blackout") then
			typeByte = 0x01
		elseif (deviceSubType == "sheer") then
			typeByte = 0x02
		end
		packet = string.format("%02x",START_CHAR)
		packetMsg = ""
		if payloadType == MOVEMENT then
			packetMsg = string.format("%02x%02x%02x%02x",0x03,MOVEMENT,typeByte,position)
		elseif payloadType == DEVICE_INFO then
			packetMsg = string.format("%02x%02x",0x01,DEVICE_INFO)
		elseif payloadType == SWAP_MOTOR then
			packetMsg = string.format("%02x%02x%02x",0x02,SWAP_MOTOR,toggleByte)
		elseif payloadType == DELETE_MOTOR then
			packetMsg = string.format("%02x%02x%02x",0x02,DELETE_MOTOR,typeByte)
		elseif payloadType == REVERSE_DIRECTION then
			packetMsg = string.format("%02x%02x%02x",0x02,REVERSE_DIRECTION,BitXOR(toggleByte,typeByte))
		elseif payloadType == JOG then
			packetMsg = string.format("%02x%02x%02x",0x02,JOG,typeByte)
		elseif payloadType == SMART_ASSIST then
			packetMsg = string.format("%02x%02x%02x",0x02,SMART_ASSIST,toggleByte)
		end
		payloadSize = (string.len(packetMsg)/2)
		pktSize = HEADER_SIZE + payloadSize
		ELAN_Trace(string.format("payloadSize: %02x",payloadSize))
		ELAN_Trace(string.format("packetSize: %02x", pktSize))
		packet = packet .. string.format("%02x",pktSize) .. string.format("%08x%08x%02x%02x",toAddr,0x00000064,1,payloadSize) .. packetMsg
		ELAN_Trace(string.format("Output message: %s",packet))

		crc = CalculateFullCRC(packet)
		packet = packet .. string.format("%02x",crc)
		
		return packet
	end
	
	--[[-------------------------------------------------------
		Creates an error message for cases where message does
		match. 
	--]]-------------------------------------------------------
	function GenerateErrorMsg(toAddr, errType, commandType, optionsByte)
		packet = string.format("%02x%0x02", START_CHAR,0x10,toAddr,0,ERR,0x03,errType,commandType,optionsByte)
		crc = CalculateFullCRC(packet)
		packet = packet .. string.format("%02x",crc)		
		return packet
	end



--| Byte Conversions --------------------------------------------------------------

	--[[-------------------------------------------------------
		Converts each ASCII value in a string into a byte,
		then puts the byte value into a string.
	--]]-------------------------------------------------------
	function StringToBytes(value)
		finalString = ""
		for i=1, string.len(value) do
			finalString = finalString .. string.format("%02x",string.byte(value,i))
		end
		return finalString
	end

	--[[-------------------------------------------------------
		Takes each individual byte value ORs them together into
		one address
	--]]-------------------------------------------------------
	function BytesToAddr(byte1, byte2, byte3, byte4)
		--ELAN_Trace("In BytesToAddr with")
		--ELAN_Trace(string.format("%02x%02x%02x%02x", byte1, byte2, byte3, byte4))
		total = BitOR(LshiftLong(byte4,8),byte3)
		total = BitOR(LshiftLong(total,8),byte2)
		total = BitOR(LshiftLong(total, 8),byte1)
		--ELAN_Trace(string.format("F: %x", total))
		return total
	end

	--[[-------------------------------------------------------
		Takes each individual byte value ORs them together into
		one address
	--]]-------------------------------------------------------
	function AddrToBytes(addrString)
		addrInt = tonumber(addrString)
		return string.format("%08x",addrInt)
	end



--| CRC Calculation ---------------------------------------------------------------

	--[[-------------------------------------------------------
		XORs full string to get the CRC
	--]]-------------------------------------------------------
	function CalculateFullCRC(value)
		ELAN_Trace(string.format("Value: %s", value))
		local crc = 0
		for i=1,string.len(value),2 do
			-- ELAN_Trace(string.format("segment: %02s", string.sub(value,i,i+1)))
			calculatedCrc = CalculateCRC(string.sub(value,i,i+1))
			crc = BitXOR(crc, calculatedCrc)
		end
		return crc
	end

	--[[-------------------------------------------------------
		Calculates the CRC value based on the input byte
	--]]-------------------------------------------------------
	function CalculateCRC(value)
		generator = 0x1D
		crc = tonumber(value,16)
		for i=0,7 do
			if (BitAND(crc,0x80) ~= 0) then
				crc = BitXOR( Lshift( crc, 1) , generator)
			else
				crc = Lshift(crc, 1)
			end
		end
		ELAN_Trace(string.format("CRC: %02x", crc))
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
