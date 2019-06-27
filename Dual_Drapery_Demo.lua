
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

		local SSL_socket = ELAN_CreateTCPClientSocket(HOST,80)
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
		else
			ELAN_CloseSocket(SSL_socket)
		end
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



