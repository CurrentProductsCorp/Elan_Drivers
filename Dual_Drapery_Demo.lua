--| Initialization ----------------------------------------------------------------
    function EDRV_Init()
    -- called when the driver starts up
		HOST = "testing.currentproducts.io"
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

		local SSL_socket = ELAN_CreateTCPClientSocket(HOST,80) --TODO: make this SSLClientSocket
		ELAN_Trace(string.format("Connecting to %s:%d", HOST,80))

		local isConnected = ELAN_ConnectTCPSocket(SSL_socket)

		local response = ELAN_DoHTTPExchange(SSL_socket, sHTTP, sContent, true, 5000)
		local p1, p2
		p1,p2 = response:find("200 OK")
		
		ELAN_TraceActiveSockets()
		ELAN_Trace(string.format("Response: %s", response))

		if(p1 ~= nil) then
			ELAN_Trace(string.format("p1: %s, p2: %s", tostring(p1), tostring(p2)))			

			local hJSON = ELAN_CreateJSONMsg(response)
			ELAN_Trace(string.format("hJSON: %s", tostring(hJSON)))

			sAccessToken = ELAN_FindJSONValueByKey(hJSON, hJSON, "access_token")
			ELAN_SaveOAuthAccessToken(sAccessToken)
			ELAN_Trace(string.format("sAccessToken: %s", tostring(sAccessToken)))

			sRefreshToken = ELAN_FindJSONValueByKey(hJSON, hJSON, "refresh_token")
			ELAN_SaveOAuthRefreshToken(sRefreshToken)
			ELAN_Trace(string.format("sRefreshToken: %s", tostring(sRefreshToken)))

			iExpiration = ELAN_FindJSONValueByKey(hJSON, hJSON, "expires_in")
			ELAN_SetOAuthTokenExpiration(iExpiration)
			ELAN_Trace(string.format("iExpiration: %s", tostring(iExpiration)))

			DeviceDiscovery(SSL_socket)
		else
			ELAN_CloseSocket(SSL_socket)
		end
	end

--[[-------------------------------------------------------
	Checks token for refresh needs, cycles if necessary
	@return boolean for refresh success
--]]-------------------------------------------------------
	function checkTokenExpired()
		if (ELAN_getOAuthTokenTTL() <= 0) then
			--create headers and body
			local sHTTP = "POST /oauth/token HTTP/1.1\r\n"
						.. "Accept: application/json\r\n"
						.. "Host: " .. HOST .. "\r\n"
						.. "Content-Type: application/x-www-form-urlencoded\r\n"
						.. "\r\n"
			local sContent = "grant_type=refresh_token"
						.. "&refresh_token=" .. ELAN_getOAuthRefreshToken()
						.. "&client_id=" .. CLIENT_ID
						.. "&client_secret=" .. CLIENT_SECRET
			--socket interaction
			local socket = ELAN_CreateTCPClientSocket(HOST,80)
			ELAN_ConnectTCPSocketAsync(socket, 5000)
			
			--response validation
			local response = ELAN_DoHTTPExchange(socket, sHTTP, sContent, true, 5000)
			local p1, p2
			p1,p2 = response:find("200 OK")
			if(p1 ~= nil) then
				--response parsing
				local hJSON = ELAN_CreateJSONMsg(response)
				sAccessToken = ELAN_FindJSONValueByKey(hJSON, hJSON, "access_token")
				ELAN_SaveOAuthAccessToken(sAccessToken)
				sRefreshToken = ELAN_FindJSONValueByKey(hJSON, hJSON, "refresh_token")
				ELAN_SaveOAuthRefreshToken(sRefreshToken)
				iExpiration = ELAN_FindJSONValueByKey(hJSON, hJSON, "expires_in")
				ELAN_SetOAuthTokenExpiration(iExpiration)
			else
				ELAN_CloseSocket(SSL_socket)
				--socket comms failed
				return false
			end
			--set new token properly
			return true
		else
			--token wasn't expired
			return true
		end
		--function failed
		return false
	end

--[[-------------------------------------------------------
	Populates the configurator with all the devices from
	the server
--]]-------------------------------------------------------
	function DeviceDiscovery(socket)
		local sHTTP = "GET /v1/devices/concise HTTP/1.1\r\n"
					.. "Accept: application/json\r\n"
					.. "Host: " .. HOST .. "\r\n"
					.. "Authorization: Bearer " .. ELAN_GetOAuthAccessToken() .. "\r\n"
					.. "Content-Type: application/x-www-form-urlencoded\r\n"
					.. "\r\n"
		local response = ELAN_DoHTTPExchange(socket, sHTTP, 5000)
		ELAN_Trace(response)
		local devicesJSON = ELAN_CreateJSONMsg(response)
		

		local deviceCount = ELAN_GetJSONSubNodeCount(devicesJSON, devicesJSON )
		ELAN_Trace(string.format("Device Count:  %d",deviceCount))
		local index = 0
		for index = 0, deviceCount-1 do
			local deviceItemJSON = ELAN_GetJSONSubNode(devicesJSON, devicesJSON,index)
			local deviceID = ELAN_GetJSONValue(devicesJSON,deviceItemJSON)
			ELAN_Trace(string.format("JSON: %s",tostring(deviceID)))
			local numSubNodes = ELAN_GetJSONSubNodeCount(devicesJSON, deviceItemJSON)
			ELAN_Trace(string.format("Number of subnodes: %d",numSubNodes))			
			local deviceName = ELAN_FindJSONValueByKey(devicesJSON, deviceItemJSON, "name")
			local deviceType = ELAN_FindJSONValueByKey(devicesJSON, deviceItemJSON, "type")
			local deviceNumMotors = ELAN_FindJSONValueByKey(devicesJSON, deviceItemJSON, "numMotors")
			if deviceNumMotors > 1 then
				ELAN_AddLightingDevice("DIMMER_MULTI_CH",deviceName,deviceID,deviceType)
			else 
				ELAN_AddLightingDevice("DIMMER",deviceName,deviceID,deviceType)
			end
			ELAN_Trace(string.format("JSON: %s",tostring(devicesJSON)))
			ELAN_Trace(string.format("Name: %s",tostring(deviceName)))
			ELAN_Trace(string.format("Type: %s",tostring(deviceType)))
			ELAN_Trace(string.format("NumMotors:  %d",deviceNumMotors))
		end
	end

	function EDRV_ProcessIncoming(data)
		ELAN_Trace(string.format("Data: %s",tostring(data)))
	end

    function EDRV_ExecuteFunction(funcName)
        if (funcName == "Sample Command 1") then
            -- Execute Command 1
        end

        if (funcName == "Sample Command 2") then
            -- Execute Command 2
        end

        if (funcName == "Sample Command 3") then
            -- Execute Command 3
        end
    end



