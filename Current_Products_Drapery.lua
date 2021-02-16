--| Initialization ----------------------------------------------------------------


    function EDRV_Init()
    -- called when the driver starts up
		ELAN_Trace("[SYSTEM]: Initializing")
		ELAN_Trace(string.format("[OAUTH]:  Get Oauth State: %s",ELAN_GetOAuthState()))
		hasToken = false
		HOST = "api.currentproducts.io"
		CLIENT_ID = "ELANdriver"
		CLIENT_SECRET = "ELANsecret"
		local sAuthURL = "https://" .. HOST .. "/oauth/authorize?"
				.. "client_id=" .. CLIENT_ID
				.. "&response_type=code"
				.. "&redirect_uri=" .. "https://auth.corebrandsdev.net/oauth.htm"
				.. "&state=" .. ELAN_GetOAuthState()
		ELAN_InitOAuthorizeURL(sAuthURL)
		ELAN_SetTimer(1, 20 * 1000) --Timer to get the position every 20 seconds
    end


--| Oauth -------------------------------------------------------------------------


--[[-------------------------------------------------------
	Is called when a user hits authorize
--]]-------------------------------------------------------
	function EDRV_RecvOAuthorizationCode( sAuthCode )
		HOST = "api.currentproducts.io"
		CLIENT_ID = "ELANdriver"
		CLIENT_SECRET = "ELANsecret"
		--create headers and body
		local sHTTP = "POST /oauth/token/ HTTP/1.1\r\n"
					.. "Accept: application/json\r\n"
					.. "Host: " .. HOST .. "\r\n"
					.. "Content-Type: application/x-www-form-urlencoded\r\n"
					.. "\r\n"

		local sContent = "grant_type=authorization_code"
					.. "&code=" .. sAuthCode
					.. "&client_id=" .. CLIENT_ID
					.. "&client_secret=" .. CLIENT_SECRET
					.. "&redirect_uri=" .. "https://auth.corebrandsdev.net/oauth.htm"
		
		local p1, p2	
		local isConnected
		local socket
		local response
		if (hasToken == false) then
			ELAN_SetDeviceState ("YELLOW", "Authorizing")
			--socket interaction
			socket = ELAN_CreateTCPClientSocket(HOST,80)
			isConnected = ELAN_ConnectTCPSocket(socket)
	
			--response validation
			response = ELAN_DoHTTPExchange(socket, sHTTP, sContent, true, 5000)
			p1,p2 = response:find("200 OK")
		end

		ELAN_Trace(string.format("[OAUTH]:  Response: %s", response))
		
		if(p1 ~= nil) then
			local hJSON = ELAN_CreateJSONMsg(response)

			sAccessToken = ELAN_FindJSONValueByKey(hJSON, hJSON, "access_token")
			hasAccessToken = ELAN_SetPersistentValue("access_token", sAccessToken)
			ELAN_Trace(string.format("[OAUTH]:  Got AccessToken: %s", tostring(hasAccessToken)))

			sRefreshToken = ELAN_FindJSONValueByKey(hJSON, hJSON, "refresh_token")
			hasRefreshToken = ELAN_SetPersistentValue("refresh_token", sRefreshToken)
			ELAN_Trace(string.format("[OAUTH]:  Got RefreshToken: %s", tostring(hasRefreshToken)))

			iExpiration = ELAN_FindJSONValueByKey(hJSON, hJSON, "expires_in")
			ELAN_Trace(string.format("[OAUTH]:  Expiration: %s",iExpiration))
			ELAN_Trace(string.format("[OAUTH]:  Expiration new Time: %s",tonumber(iExpiration)*1000 - 20000))

			--Sets the Token expiration to the new time.
			ELAN_SetTimer(0, (tonumber(iExpiration)*1000 - 20000))

			--Populates the Lighting interface with devices from the server
			DeviceDiscovery()
			hasToken = true
			ELAN_SetDeviceState ("GREEN", "Connected To Server")
			ELAN_DeleteJSONMsg(devicesJSON)
		elseif (hasToken == false) then
			ELAN_SetDeviceState ("RED", "Could Not Authorize")
		end
			ELAN_CloseSocket(socket)
	end

--[[-------------------------------------------------------
	Refresh the auth token
--]]-------------------------------------------------------
	function RefreshToken()
		ELAN_SetDeviceState ("YELLOW", "Refreshing Token")

		--create headers and body
		local sHTTP = "POST /oauth/token HTTP/1.1\r\n"
					.. "Accept: application/json\r\n"
					.. "Host: " .. HOST .. "\r\n"
					.. "Content-Type: application/x-www-form-urlencoded\r\n"
					.. "\r\n"
		local sContent = "grant_type=refresh_token"
					.. "&refresh_token=" .. ELAN_GetPersistentValue("refresh_token")
					.. "&client_id=" .. CLIENT_ID
					.. "&client_secret=" .. CLIENT_SECRET
		--socket interaction
		local socket = ELAN_CreateTCPClientSocket(HOST,80)
		ELAN_ConnectTCPSocket(socket)
		
		local response = ELAN_DoHTTPExchange(socket, sHTTP, sContent, false, 5000)
		local p1, p2
		p1,p2 = response:find("200 OK")

		ELAN_Trace(string.format("[OAUTH]:  Response: %s", response))

		if(p1 ~= nil) then
			--response parsing
			local hJSON = ELAN_CreateJSONMsg(response)

			sAccessToken = ELAN_FindJSONValueByKey(hJSON, hJSON, "access_token")
			hasAccessToken = ELAN_SetPersistentValue("access_token", sAccessToken)
			ELAN_Trace(string.format("[OAUTH]:  Got AccessToken: %s", tostring(hasAccessToken)))

			sRefreshToken = ELAN_FindJSONValueByKey(hJSON, hJSON, "refresh_token")
			hasRefreshToken = ELAN_SetPersistentValue("refresh_token", sRefreshToken)
			ELAN_Trace(string.format("[OAUTH]:  Got RefreshToken: %s", tostring(hasRefreshToken)))

			iExpiration = ELAN_FindJSONValueByKey(hJSON, hJSON, "expires_in")

			ELAN_SetDeviceState ("GREEN", "Connected To Server")
			ELAN_DeleteJSONMsg(devicesJSON)
		else
			ELAN_CloseSocket(socket)
			ELAN_SetDeviceState ("RED", "Could Not Authorize")
			--socket comms failed
			return false
		end
		ELAN_CloseSocket(socket)
		--set new token properly
		return true
	end


--[[-------------------------------------------------------
	Populates the configurator with all the devices from
	the server
--]]-------------------------------------------------------
	function DeviceDiscovery()
		if (ELAN_GetPersistentValue("access_token") == nil) then
			ELAN_Trace("[OAUTH]:  No access token to obtain devices.")
			return
		end		
		
		local socket = ELAN_CreateTCPClientSocket(HOST,80)
		local isConnected = ELAN_ConnectTCPSocket(socket)

		ELAN_SetDeviceState ("YELLOW", "GETTING DEVICES")
		local sHTTP = "GET /v1/devices/concise HTTP/1.1\r\n"
					.. "Accept: application/json\r\n"
					.. "Host: " .. HOST .. "\r\n"
					.. "Authorization: Bearer " .. ELAN_GetPersistentValue("access_token") .. "\r\n"
					.. "Content-Type: application/x-www-form-urlencoded\r\n"
					.. "\r\n"
		local response = ELAN_DoHTTPExchange(socket, sHTTP, 5000)
		local devicesJSON = ELAN_CreateJSONMsg(response)
		ELAN_Trace(string.format("[INFO]:   RESPONSE: %s", response))
		local deviceCount = ELAN_GetJSONSubNodeCount(devicesJSON, devicesJSON )
		local index = 0

		local p1, p2	
		p1,p2 = response:find("200 OK")
		if p1 ~= nil then
			ELAN_Trace("[INFO]:   Response OK")
			ELAN_SetDeviceState ("GREEN", "Connected To Server")
		end

		for index = 0, deviceCount-1 do
			local deviceItemJSON = ELAN_GetJSONSubNode(devicesJSON, devicesJSON, index)
			local deviceID = ELAN_GetJSONValue(devicesJSON, deviceItemJSON)		
			local deviceName = ELAN_FindJSONValueByKey(devicesJSON, deviceItemJSON, "name", true)
			local deviceType = ELAN_FindJSONValueByKey(devicesJSON, deviceItemJSON, "type", true)
			local blackoutPos = ELAN_FindJSONValueByKey(devicesJSON, deviceItemJSON, "blackoutPos", true)
			local sheerPos = ELAN_FindJSONValueByKey(devicesJSON, deviceItemJSON, "sheerPos", true)
			local deviceNumMotors = ELAN_FindJSONValueByKey(devicesJSON, deviceItemJSON, "numMotors")
			--Create a second device if the decvice has two motors. This will append the appropriate motor number to the device name for lookup.
			if deviceNumMotors > 1 then
				ELAN_AddLightingDevice("DIMMER",deviceName .. " Motor 1",deviceID,deviceType,"sheer", "false")
				ELAN_AddLightingDevice("DIMMER",deviceName .. " Motor 2",deviceID,deviceType,"blackout","false")
			else
				ELAN_AddLightingDevice("DIMMER",deviceName,deviceID,deviceType,"blackout","false")
			end
		end
		ELAN_SetDeviceState ("GREEN", "Connected to server")
		ELAN_CloseSocket(socket)
		ELAN_DeleteJSONMsg(devicesJSON)
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
	end	

--[[-------------------------------------------------------
	Timer function, calls GetAllPositions or RefreshToken
	depending on which timer calls it.
--]]-------------------------------------------------------
	function EDRV_OnTimer(timer_id)
		if timer_id > 1 or ELAN_GetPersistentValue("refresh_token") == nil then
			return
		end

		if timer_id == 0 then
			RefreshToken()
		end		

		if timer_id == 1 then
			GetAllPositions()
		end
	end

--[[-------------------------------------------------------
	Called when the slider is set to a new position
--]]-------------------------------------------------------
	function EDRV_DimDeviceTo(data, deviceID, deviceType, motor)
		--Check to see if motor reversed is set.
		isRev = getIsReversed(deviceID, motor)
		if(isRev) then
			SetPosition(deviceID, 100-data, motor)
		else
			SetPosition(deviceID, data, motor)
		end
	end

--[[-------------------------------------------------------
	Called when the slider is set to closed
--]]-------------------------------------------------------
	function EDRV_ActivateDevice(deviceID, deviceType, motor)
		--Check to see if motor reversed is set.
		isRev = getIsReversed(deviceID, motor)
		if(isRev) then
			SetPosition(deviceID, 0, motor)
		else
			SetPosition(deviceID, 100, motor)
		end
	end

--[[-------------------------------------------------------
	Called when the slider is set to open
--]]-------------------------------------------------------
	function EDRV_DeactivateDevice(deviceID, deviceType, motor)
		--Check to see if motor reversed is set.
		isRev = getIsReversed(deviceID, motor)
		if(isRev) then
			SetPosition(deviceID, 100, motor)
		else
			SetPosition(deviceID, 0, motor)
		end
	end

	function EDRV_ExecuteConfigProc(proc_id)
		if proc_id == 1 then
			DeviceDiscovery()
		end
	end

--[[-------------------------------------------------------
	HTTP call for setting the new position
--]]-------------------------------------------------------
	function SetPosition(deviceID, position, motor)
		local sHTTP = "POST /v1/position/reduced HTTP/1.1\r\n"
					.. "Accept: application/json\r\n"
					.. "Host: " .. HOST .. "\r\n"
					.. "Authorization: Bearer " .. ELAN_GetPersistentValue("access_token") .. "\r\n"
					.. "Content-Type: application/json\r\n"
					.. "\r\n"
		local socket = ELAN_CreateTCPClientSocket(HOST,80) --TODO: make this ELAN_CreateSSLClientSocket(?)
		local JSONMsg = ELAN_CreateJSONMsg(string.format("{\"id\":%d,\"position\":%d,\"motor\":\"%s\"}",deviceID,position,motor))
		local response = ELAN_DoHTTPExchange(socket, sHTTP, JSONMsg, 5000)
		ELAN_Trace(string.format("[INFO]:   Response: %s", response))
		local p1, p2	
		p1,p2 = response:find("200 OK")
		if p1 ~= nil then
			ELAN_Trace("[INFO]:   Response OK")
			ELAN_SetDeviceState ("GREEN", "Connected To Server")
		else
			ELAN_Trace(string.format("[ERROR]:  %s", response)) --TODO: Create unique responses for different types of errors.
			ELAN_SetDeviceState ("RED", "Error Sending Position")
		end
		ELAN_CloseSocket(socket)
		ELAN_DeleteJSONMsg(devicesJSON)
	end

--[[-------------------------------------------------------
	HTTP call for getting the new position
--]]-------------------------------------------------------
	function GetAllPositions()
		if (ELAN_GetPersistentValue("access_token") == nil) then
			ELAN_Trace("No access token to obtain devices.")
			return
		end		
		
		local socket = ELAN_CreateTCPClientSocket(HOST,80)
		local isConnected = ELAN_ConnectTCPSocket(socket)

		local sHTTP = "GET /v1/devices/concise HTTP/1.1\r\n"
					.. "Accept: application/json\r\n"
					.. "Host: " .. HOST .. "\r\n"
					.. "Authorization: Bearer " .. ELAN_GetPersistentValue("access_token") .. "\r\n"
					.. "Content-Type: application/x-www-form-urlencoded\r\n"
					.. "\r\n"
		local response = ELAN_DoHTTPExchange(socket, sHTTP, 5000)
		local devicesJSON = ELAN_CreateJSONMsg(response)
		ELAN_Trace(string.format("[INFO]:   RESPONSE: %s", response))
		local deviceCount = ELAN_GetJSONSubNodeCount(devicesJSON, devicesJSON )
		local index = 0

		local p1, p2	
		p1,p2 = response:find("200 OK")
		if p1 ~= nil then
			ELAN_Trace("[INFO]:   Response OK")
			ELAN_SetDeviceState ("GREEN", "Connected To Server")
		end

		--Search through devices on server and add them to the configurator
		for index = 0, deviceCount-1 do
			local deviceItemJSON = ELAN_GetJSONSubNode(devicesJSON, devicesJSON, index)
			--ELAN_Trace(string.format("deviceItemJSON: %s", deviceItemJSON))
			local deviceID = ELAN_GetJSONValue(devicesJSON, deviceItemJSON)		
			local deviceType = ELAN_FindJSONValueByKey(devicesJSON, deviceItemJSON, "type", true)
			local blackoutPos = ELAN_FindJSONValueByKey(devicesJSON, deviceItemJSON, "blackoutPos", true)
			local sheerPos = ELAN_FindJSONValueByKey(devicesJSON, deviceItemJSON, "sheerPos", true)
			local deviceNumMotors = ELAN_FindJSONValueByKey(devicesJSON, deviceItemJSON, "numMotors")
			--Create a second device if the decvice has two motors. This will append the appropriate motor number to the device name for lookup.
			if deviceNumMotors > 1 then
				ELAN_RegisterDeviceLevel(GetPosition(deviceID,"blackout",blackoutPos),deviceID,deviceType,"blackout","false")
				ELAN_RegisterDeviceLevel(GetPosition(deviceID,"sheer",sheerPos),deviceID,deviceType,"sheer","false")
			else
				ELAN_RegisterDeviceLevel(GetPosition(deviceID,"",blackoutPos),deviceID,deviceType,"blackout","false")
			end
		end
		ELAN_CloseSocket(socket)
		ELAN_DeleteJSONMsg(devicesJSON)
	end




--| Settings Functions ---------------------------------------------------------------


--[[-------------------------------------------------------
	Use the deviceID, the motor, and the input position to 
	get the real position
--]]-------------------------------------------------------
	function GetPosition(deviceID, motor, position)
		local isRev = getIsReversed(deviceID, motor)
		if isRev then 
			return (100 - position)
		else
			return position
		end
	end


--[[-------------------------------------------------------
	Checks the settings string for the device ID to see
	if it exists in the string list of devices to swap
	open/close position
--]]-------------------------------------------------------	
	function getIsReversed(value, motor)
		local motorChar = ""
		if motor == "blackout" then
			motorChar = "p"
		elseif motor == "sheer" then
			motorChar = "s"
		end

		local value = value .. motorChar
		value = string.lower(value)
		swappedString = ELAN_GetPersistentValue("swappedDevices")

		if swappedString == nil then
			return false
		end

		if string.find(swappedString, "all") then
			return true
		elseif string.find(swappedString, value) then
			return true
		else
			return false
		end	
	end


--| String Functions --------------------------------------------------------------


--[[-------------------------------------------------------
	Trims out whitespace using string.gsub
--]]-------------------------------------------------------	
	function trim(deviceString)
		return (string.gsub(deviceString,"%s+",""))
	end

--[[-------------------------------------------------------
	Trims out whitespace using string.gsub
--]]-------------------------------------------------------	
	function split(inputString,delimiter)
		if delimiter == nil then
			delimiter = "%s+"
		end
		
		local tokens={}
		for item in string.gmatch(inputString, "([^" .. delimiter .. "]+)") do
			table.insert(tokens, item)
		end
		return tokens
	end



