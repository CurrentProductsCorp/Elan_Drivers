-- Current_Products_Serial_Helper.lua



--| Handling Incoming Data --------------------------------------------------------

	--[[-------------------------------------------------------
		Parses incoming data
	--]]-------------------------------------------------------
	function handleData(data)
		-- Since valid, get all other bytes
		ELAN_Trace(string.format("Data To String: %s", tostring(data)))
		payloadLength = string.byte(data, PAYLOAD_LENGTH_LOCATION)
		requestByte = string.byte(data, REQUEST_BYTE_LOCATION)
		toAddr1, toAddr2, toAddr3, toAddr4 = string.byte(data, TO_ADDR_LOCATION, TO_ADDR_LOCATION + 4)
		fromAddr1, fromAddr2, fromAddr3, fromAddr4 = string.byte(data, FROM_ADDR_LOCATION, FROM_ADDR_LOCATION + 4)
		
		toAddress =  BytesToAddr(toAddr1, toAddr2, toAddr3, toAddr4)
		fromAddress = BytesToAddr(fromAddr1, fromAddr2, fromAddr3, fromAddr4)
	
		--ELAN_Trace(string.format("RequestByte: %02x", requestByte ))
		if payloadLength > 0 and string.len(tostring(data)) > HEADER_SIZE then
			payload = {string.byte(data, PAYLOAD, (PAYLOAD_LOCATION + payloadLength))}
			commandByte = string.byte(data, PAYLOAD_LOCATION)
			--ELAN_Trace(string.format("Command Byte: %02x", commandByte))
		end
		-- Request
		if requestByte == REQ then
			ELAN_Trace("        Has request flag")
		-- Acknowledged
		elseif requestByte == ACK then
			ELAN_Trace("        Has Acknowledge flag")
			if(payloadLength > 0) then
				HandleAcknowledgeByte(data, fromAddress, payloadLength, commandByte);
			end
		-- Not Acknowledged
		elseif requestByte == NAK then
			ELAN_Trace("        Has Not Acknowledged flag")
		-- Has Error
		--elseif requestByte == ERR then
		--	ELAN_Trace("Has Error")
		--	-- TODO: Get specific error
		-- Announce
		elseif requestByte == ANN then
			ELAN_Trace("        Has announce packet")
			if(payloadLength > 0) then
				HandleAnnounceByte(data, fromAddress);
			end

		-- Heartbeat
		elseif requestByte == HBT then
			ELAN_Trace("        Has Heartbeat Flag")
		-- If it isn't an announce packet, see if there's a payload.
		end	
	end

	--[[-------------------------------------------------------
		Compares the expected address to the response address
		and verifies that they are the same
	--]]-------------------------------------------------------
	function MoveResponseIsMatch(data, targetDeviceAddr)
		payloadLength = string.byte(data, PAYLOAD_LENGTH_LOCATION)
		requestByte = string.byte(data, REQUEST_BYTE_LOCATION)
		toAddr1, toAddr2, toAddr3, toAddr4 = string.byte(data, TO_ADDR_LOCATION, TO_ADDR_LOCATION + 4)
		fromAddr1, fromAddr2, fromAddr3, fromAddr4 = string.byte(data, FROM_ADDR_LOCATION, FROM_ADDR_LOCATION + 4)
		
		fromAddress = BytesToAddr(fromAddr1, fromAddr2, fromAddr3, fromAddr4)
		if(fromAddress == nil) then
			return false
		end
		--ELAN_Trace(string.format("from Addr:   %x", fromAddress))
		--ELAN_Trace(string.format("target Addr: %x", ReverseAddr(targetDeviceAddr)))
	
		targetDeviceAddr = ReverseAddr(targetDeviceAddr)		
		
		if(string.byte(data,1) ~= 0x58) then
			ELAN_Trace("BAD START CHAR")
		end
		if(targetDeviceAddr ~= fromAddress) then
			ELAN_Trace("ADDRESS MISMATCH")
			return false
		end
		if(requestByte == 0x02) then
			--ELAN_Trace("Removing command from list")
			return true
		else
			ELAN_Trace("REQUEST BYTE NOT ACK")
			return false
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

		--ELAN_Trace(string.format("Type Byte: %02x",commandType))		
		if commandType == DEVICE_INFO then		
			-- Determine if device is dual or single
			deviceNumMotors = GetNumberMotors(string.sub(data, PAYLOAD_LOCATION, (PAYLOAD_LOCATION + payloadLength)))
			--ELAN_Trace(string.format("Number of Motors: %02x", deviceNumMotors))
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
		sCmd = string.format("%08x%02x%08x%08x%02x%02x%02s", 0xFE161616, 0x0E, fromAddress, 0x00000064, 1, 1, DEVICE_INFO)
		local crc = 0
		crc = CalculateFullCRC(sCmd)
		sCmd = sCmd .. string.format("%02x",crc)
		response = ELAN_SendToDeviceStringHEX(sCmd)
	end

	--[[-------------------------------------------------------
		Grabs the number of motors found in the payload
	--]]-------------------------------------------------------
	function GetNumberMotors(payload)
		--ELAN_Trace(string.format("MOTOR PAYLOAD: %02x%02x",string.byte(payload,10),string.byte(payload,11)))
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
		sCmd = string.format("%08x%02x%08x%08x%02x%02x%02x", 0xFE161616, 0x11, 0xFFFFFFFF, 0x00000064, 1, 1, DEVICE_INFO)
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
			packetMsg = string.format("%02x%02x%02x",MOVEMENT,typeByte,position)
		elseif payloadType == DEVICE_INFO then
			packetMsg = string.format("%02x",DEVICE_INFO)
		elseif payloadType == SWAP_MOTOR then
			packetMsg = string.format("%02x%02x",SWAP_MOTOR,toggleByte)
		elseif payloadType == DELETE_MOTOR then
			packetMsg = string.format("%02x%02x",DELETE_MOTOR,typeByte)
		elseif payloadType == REVERSE_DIRECTION then
			packetMsg = string.format("%02x%02x",REVERSE_DIRECTION,BitXOR(toggleByte,typeByte))
		elseif payloadType == JOG then
			packetMsg = string.format("%02x%02x",JOG,typeByte)
		elseif payloadType == SMART_ASSIST then
			packetMsg = string.format("%02x%02x",SMART_ASSIST,toggleByte)
		end
		payloadSize = (string.len(packetMsg)/2)
		pktSize = HEADER_SIZE + payloadSize
		--ELAN_Trace(string.format("payloadSize: %02x",payloadSize))
		--ELAN_Trace(string.format("packetSize: %02x", pktSize))
		packet = packet .. string.format("%02x",pktSize) .. string.format("%08x%08x%02x%02x",toAddr,0x00000064,1,payloadSize) .. packetMsg
		--ELAN_Trace(string.format("Output message: %s",packet))

		crc = CalculateFullCRC(packet)
		packet = packet .. string.format("%02x",crc)
		
		return packet
	end

	--[[-------------------------------------------------------
		Sends the packet over the line and retries if there
		is a failure
	--]]-------------------------------------------------------
	function SendPacket(sCmd, deviceID, deviceSubType, level)
		command = string.format("%08x:%s:%02x",deviceID, string.lower(deviceSubType), level)
		ELAN_SetPersistentValue(command, command)

		-- If no response, try sending again.
		resendCount = 0
		while resendCount < 3  do
			ELAN_Trace(string.format("Sending: %s", sCmd))
			response = ELAN_SendToDeviceStringHEX(sCmd)
			responseStr = ELAN_WaitResponse(0,20*resendCount)

			ELAN_Trace("    Response is: ")
			ELAN_Trace(string.format("    %s", response))
			ELAN_Trace("    ResponseStr is: ")
			ELAN_Trace(string.format("    %s", StringToBytes(responseStr)))

			size = string.len(responseStr)
			if(size == 0 or responseStr == nil) then
				ELAN_Trace("Response was nil. Resending.")
			elseif(MoveResponseIsMatch(responseStr, deviceID)) then
				ELAN_DeletePersistentValue(command)
				break
			end
			--ELAN_Trace(string.format("Response: %s", response))
			resendCount = resendCount + 1
		end
		--After givin up on retries, delete the persistent value
		ELAN_DeletePersistentValue(command)
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

	function BytesToString(str)
		return (str:gsub('..', function (cc)
        	return string.char(tonumber(cc, 16))
    	end))
	end

	--[[-------------------------------------------------------
		Takes each individual byte value ORs them together into
		one address
	--]]-------------------------------------------------------
	function BytesToAddr(byte1, byte2, byte3, byte4)
		--ELAN_Trace("In BytesToAddr with")
		--ELAN_Trace(string.format("%02x%02x%02x%02x", byte1, byte2, byte3, byte4))
		if(byte1 == nil or byte2 == nil or byte3 == nil or byte4 == nil) then
			ELAN_Trace(string.format("Something was nil..."))
			return nil
		end
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

	--[[-------------------------------------------------------
		Swaps the Endianness of the address
	--]]-------------------------------------------------------
	function ReverseAddr(deviceID)
		deviceIDString = string.format("%x",deviceID)
		reversedID = ""
		local i = 0
		strLen = string.len( deviceIDString )

		for i=1, strLen, 2 do
			reversedID = string.sub( deviceIDString , i, i+1 ) .. reversedID 
		end
		--ELAN_Trace(string.format( "Attempt to Reverse: %x", tonumber(reversedID, 16)))
		return (tonumber(reversedID, 16))
	end



--| CRC Calculation ---------------------------------------------------------------

	--[[-------------------------------------------------------
		XORs full string to get the CRC
	--]]-------------------------------------------------------
	function CalculateFullCRC(value)
		local crc = 0
		for i=1,string.len(value),2 do
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
-- Current_Products_Serial_Defs.lua



	MOVEMENT = 0x01
	DEVICE_INFO = 0x02
	SWAP_MOTOR = 0x03
	DELETE_MOTOR = 0x04
	REVERSE_DIRECTION = 0x05
	JOG = 0x06
	SMART_ASSIST = 0x07

	REQ = 0x01
	ACK = 0x02
	NAK = 0x04
	ERR = NAK
	--| Reserved
	ANN = 0x40
	HBT = 0x80

	UNKNOWN_FAILURE = 0x01
	BAD_PKT_LEN = 0x02
	BAD_VALS_IN_PAYLOAD = 0x03
	BAD_OPTIONS_IN_BYTE = 0x04
	MOTOR_NOT_FOUND = 0x05
	MOTOR_HARDWARE_FAILURE = 0x06
	CRC_FAILURE = 0x07
	BAD_ADDR = 0x08

	START_CHAR_LOCATION = 1
	PACKET_SIZE_LOCATION = 5
	TO_ADDR_LOCATION = 6
	FROM_ADDR_LOCATION = 10
	REQUEST_BYTE_LOCATION = 14
	PAYLOAD_LENGTH_LOCATION = 15
	PAYLOAD_LOCATION = 16

	HEADER_SIZE = 16

	MOVEMENT_LEN = 0x03

	BLACKOUT = 0x01
	SHEER = 0x02
	BOTH = 0x03

	START_CHAR = 0x58
	PREAMBLE = 0xFE161616

	ON = 0x10
	OFF = 0x20
	TOGGLE = 0x00

	CLOSED = 100
	OPEN = 0







 