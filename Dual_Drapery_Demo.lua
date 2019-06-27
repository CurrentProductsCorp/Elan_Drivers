
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

		local URLforSocket = "https://" .. HOST
		local SSL_socket = ELAN_CreateSSLClientSocket(URLforSocket, 8081)
		local isConnected = ELAN_ConnectTCPSocketAsync(SSL_socket, 5000)
		ELAN_Trace(string.format("isConnected??: %s", tostring(isConnected)))

		ELAN_Trace(string.format("SSL_Socket: %d",SSL_socket))
		ELAN_Trace(string.format("sHTTP: %s",sHTTP))
		ELAN_Trace(string.format("sContent: %s",sContent))

		local response = ELAN_DoHTTPExchange(SSL_socket, sHTTP, sContent, true, 5000)
		local p1, p2
		p1,p2 = response:find("200 OK")
		
		ELAN_TraceActiveSockets()
		ELAN_Trace(string.format("Response: %s", response))
		if(p1 ~= nil) then
			ELAN_Trace("In p1")
			local content = ExtractHTTPContent(response)
			local hJSON = ELAN_CreateJSONMsg(content)
			ELAN_Trace("hJSON" .. hJSON)

			sAccessToken = ELAN_FindJSONValueByKey(hJSON, hJSON, "access_token")
			ELAN_SaveOAuthAccessToken(sAccessToken)
			ELAN_Trace("sAccessToken" .. sAccessToken)

			sRefreshToken = ELAN_FindJSONValueByKey(hJSON, hJSON, "refresh_token")
			ELAN_SaveOAuthRefreshToken(sRefreshToken)
			ELAN_Trace("sRefreshToken" .. sRefreshToken)

			iExpiration = ELAN_FindJSONValueByKey(hJSON, hJSON, "expires_in")
			ELAN_SetOAuthTokenExpiration(iExpiration)
			ELAN_Trace("iExpiration" .. iExpiration)
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


