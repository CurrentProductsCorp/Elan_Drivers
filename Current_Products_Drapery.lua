--| Initialization ----------------------------------------------------------------
    function EDRV_Init()
    -- called when the driver starts up
		HOST = "api.currentproducts.io"
		CLIENT_ID = "ELANdriver"
		CLIENT_SECRET = "ELANsecret"
		local sAuthURL = "https://" .. HOST .. "/oauth/authorize?"
				.. "client_id=" .. CLIENT_ID
				.. "&response_type=code"
				.. "&redirect_uri=" .. ELAN_GetOAuthRedirectURI()
				.. "&state=" .. ELAN_GetOAuthState()
		ELAN_InitOAuthorizeURL(sAuthURL)
    end

--| Oauth -------------------------------------------------------------------------


--[[-------------------------------------------------------
	Is called when a user hits authorize
--]]-------------------------------------------------------
	function EDRV_RecvOAuthorizationCode( sAuthCode )
		ELAN_SetDeviceState ("YELLOW", "Authorizing")
		--create headers and body
		local sHTTP = "POST /oauth/token HTTP/1.1\r\n"
					.. "Accept: application/json\r\n"
					.. "Host: " .. HOST .. "\r\n"
					.. "Content-Type: application/x-www-form-urlencoded\r\n"
					.. "\r\n"

		local sContent = "grant_type=authorization_code"
					.. "&code=" .. sAuthCode
					.. "&client_id=" .. CLIENT_ID
					.. "&client_secret=" .. CLIENT_SECRET
					.. "&redirect_uri=" .. ELAN_GetOAuthRedirectURI()
		--socket interaction
		local socket = ELAN_CreateTCPClientSocket(HOST,80) --TODO: make this ELAN_CreateSSLClientSocket(?)
		local isConnected = ELAN_ConnectTCPSocket(socket)

		--response validation
		local response = ELAN_DoHTTPExchange(socket, sHTTP, sContent, true, 5000)
		local p1, p2
		p1,p2 = response:find("200 OK")
		
		ELAN_TraceActiveSockets()
		ELAN_Trace(string.format("Response: %s", response))

		if(p1 ~= nil) then
			--response parsing
			ELAN_Trace(string.format("p1: %s, p2: %s", tostring(p1), tostring(p2)))			

			local hJSON = ELAN_CreateJSONMsg(response)

			sAccessToken = ELAN_FindJSONValueByKey(hJSON, hJSON, "access_token")
			ELAN_SaveOAuthAccessToken(sAccessToken)

			sRefreshToken = ELAN_FindJSONValueByKey(hJSON, hJSON, "refresh_token")
			ELAN_SaveOAuthRefreshToken(sRefreshToken)

			iExpiration = ELAN_FindJSONValueByKey(hJSON, hJSON, "expires_in")
			ELAN_Trace(string.format("Expiration: %s",iExpiration))

			--Resets the Token to 0. If this is not done, the token expiration is added instead of set.
			--If authorization is somehow done several times within a minute, this prevents the expiration time from getting unreasonably high.
			ELAN_SetOAuthTokenExpiration(-(ELAN_GetOAuthTokenTTL())) 
			--Sets the Token expiration to the new time.
			ELAN_SetOAuthTokenExpiration(iExpiration)

			ELAN_Trace(string.format("isExpired? %s", ELAN_GetOAuthTokenTTL()))

			--Populates the Lighting interface with devices from the server
			DeviceDiscovery(socket)

			ELAN_SetDeviceState ("GREEN", "Connected To Server")
		else
			ELAN_CloseSocket(socket)
			ELAN_SetDeviceState ("RED", "Could Not Authorize")
		end
	end

--[[-------------------------------------------------------
	Checks token for refresh needs, cycles if necessary
	@return boolean for refresh success
--]]-------------------------------------------------------
	function checkTokenExpired()
		ELAN_SetDeviceState ("YELLOW", "Refreshing Token")
		ELAN_Trace(string.format("Time to live: %d", ELAN_GetOAuthTokenTTL()))
		if (tonumber(ELAN_GetOAuthTokenTTL()) <= 0) then
			--create headers and body
			local sHTTP = "POST /oauth/token HTTP/1.1\r\n"
						.. "Accept: application/json\r\n"
						.. "Host: " .. HOST .. "\r\n"
						.. "Content-Type: application/x-www-form-urlencoded\r\n"
						.. "\r\n"
			local sContent = "grant_type=refresh_token"
						.. "&refresh_token=" .. ELAN_GetOAuthRefreshToken()
						.. "&client_id=" .. CLIENT_ID
						.. "&client_secret=" .. CLIENT_SECRET
			--socket interaction
			local socket = ELAN_CreateTCPClientSocket(HOST,80)
			ELAN_ConnectTCPSocketAsync(socket, 5000)
			
			ELAN_Trace(string.format("socket: %d", socket))
			--response validation
			ELAN_Trace(string.format("Content: %s", sContent))
			local response = ELAN_DoHTTPExchange(socket, sHTTP, sContent, true, 5000)
			local p1, p2
			p1,p2 = response:find("200 OK")

			ELAN_Trace(string.format("Response: %s", response))

			if(p1 ~= nil) then
				--response parsing
				local hJSON = ELAN_CreateJSONMsg(response)

				sAccessToken = ELAN_FindJSONValueByKey(hJSON, hJSON, "access_token")
				ELAN_SaveOAuthAccessToken(sAccessToken)

				sRefreshToken = ELAN_FindJSONValueByKey(hJSON, hJSON, "refresh_token")
				ELAN_SaveOAuthRefreshToken(sRefreshToken)

				iExpiration = ELAN_FindJSONValueByKey(hJSON, hJSON, "expires_in")

				ELAN_SetOAuthTokenExpiration(tonumber(iExpiration))
				ELAN_Trace(string.format("am me expired?? %d",tonumber(iExpiration)))

				ELAN_SetDeviceState ("GREEN", "Connected To Server")
			else
				ELAN_CloseSocket(socket)
				ELAN_SetDeviceState ("RED", "Could Not Authorize")
				--socket comms failed
				return false
			end
			--set new token properly
			return true
		else
			--token wasn't expired
			ELAN_SetDeviceState ("GREEN", "Connected To Server")
			return true
		end
		--function failed
		ELAN_SetDeviceState ("RED", "Issue Getting Auth")
		return false
	end

--[[-------------------------------------------------------
	Populates the configurator with all the devices from
	the server
--]]-------------------------------------------------------
	function DeviceDiscovery(socket)
		ELAN_SetDeviceState ("YELLOW", "GETTING DEVICES")
		local sHTTP = "GET /v1/devices/concise HTTP/1.1\r\n"
					.. "Accept: application/json\r\n"
					.. "Host: " .. HOST .. "\r\n"
					.. "Authorization: Bearer " .. ELAN_GetOAuthAccessToken() .. "\r\n"
					.. "Content-Type: application/x-www-form-urlencoded\r\n"
					.. "\r\n"
		local response = ELAN_DoHTTPExchange(socket, sHTTP, 5000)
		local devicesJSON = ELAN_CreateJSONMsg(response)
		
		local deviceCount = ELAN_GetJSONSubNodeCount(devicesJSON, devicesJSON )
		local index = 0

		--Search through devices on server and add them to the configurator
		for index = 0, deviceCount-1 do
			local deviceItemJSON = ELAN_GetJSONSubNode(devicesJSON, devicesJSON,index)
			local deviceID = ELAN_GetJSONValue(devicesJSON,deviceItemJSON)		
			local deviceName = ELAN_FindJSONValueByKey(devicesJSON, deviceItemJSON, "name")
			local deviceType = ELAN_FindJSONValueByKey(devicesJSON, deviceItemJSON, "type")
			local deviceNumMotors = ELAN_FindJSONValueByKey(devicesJSON, deviceItemJSON, "numMotors")
			--Create a second device if the decvice has two motors. This will append the appropriate motor number to the device name for lookup.
			if deviceNumMotors > 1 then
				ELAN_AddLightingDevice("DIMMER",deviceName .. " Motor 1",deviceID,deviceType,"sheer", "false")
				ELAN_AddLightingDevice("DIMMER",deviceName .. " Motor 2",deviceID,deviceType,"blackout","false")
			else
				ELAN_AddLightingDevice("DIMMER",deviceName,deviceID,deviceType,"blackout","false")
			end
		end
		ELAN_CloseSocket(socket)
	end

--| System Calls ------------------------------------------------------------------


--[[-------------------------------------------------------
	Called when the slider is set to a new position
--]]-------------------------------------------------------
	function EDRV_DimDeviceTo(data, deviceID, deviceType, motor, isMotorReversed)
		--Check to see if motor reversed is set.
		isRev = isMotorReversed:find("true") or isMotorReversed:find("yes")
		if(isRev ~= nil) then
			ELAN_Trace("motor is reversed")
			SetPosition(deviceID, 100-data, motor)
		else
			SetPosition(deviceID, data, motor)
		end
	end

--[[-------------------------------------------------------
	Called when the slider is set to closed
--]]-------------------------------------------------------
	function EDRV_ActivateDevice(deviceID, deviceType, motor, isMotorReversed)
		--Check to see if motor reversed is set.
		isRev = isMotorReversed:find("true") or isMotorReversed:find("yes")
		if(isRev ~= nil) then
			SetPosition(deviceID, 0, motor)
		else
			SetPosition(deviceID, 100, motor)
		end
	end

--[[-------------------------------------------------------
	Called when the slider is set to open
--]]-------------------------------------------------------
	function EDRV_DeactivateDevice(deviceID, deviceType, motor, isMotorReversed)
		--Check to see if motor reversed is set.
		isRev = isMotorReversed:find("true") or isMotorReversed:find("yes")
		if(isRev ~= nil) then
			SetPosition(deviceID, 100, motor)
		else
			SetPosition(deviceID, 0, motor)
		end
	end

--[[-------------------------------------------------------
	HTTP call for setting the new position
--]]-------------------------------------------------------
	function SetPosition(deviceID, position, motor, isMotorReversed)
		--First, check and see if the token is still valid. Get a new one if it is.
		local recievedToken = checkTokenExpired()
		
		if not(recievedToken) then
			ELAN_Trace("ERROR: Token could not be refreshed")
			return
		end
		local sHTTP = "POST /v1/position/reduced HTTP/1.1\r\n"
					.. "Accept: application/json\r\n"
					.. "Host: " .. HOST .. "\r\n"
					.. "Authorization: Bearer " .. ELAN_GetOAuthAccessToken() .. "\r\n"
					.. "Content-Type: application/json\r\n"
					.. "\r\n"
		local socket = ELAN_CreateTCPClientSocket(HOST,80) --TODO: make this ELAN_CreateSSLClientSocket(?)
		local JSONMsg = ELAN_CreateJSONMsg(string.format("{\"id\":%d,\"position\":%d,\"motor\":\"%s\"}",deviceID,position,motor))
		local response = ELAN_DoHTTPExchange(socket, sHTTP, JSONMsg, 5000)
		ELAN_Trace(string.format("Response: %s", response))
		local p1, p2	
		p1,p2 = response:find("200 OK")
		if p1 ~= nil then
			ELAN_Trace("Response OK")
		else
			ELAN_Trace(string.format("Error: %s", response)) --TODO: Create unique responses for different types of errors.
			ELAN_SetDeviceState ("RED", "Error Sending Position")
		end
		ELAN_CloseSocket(socket)
	end







