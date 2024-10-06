require "lib.text-draw"

local json = require("lib.json")
local qrcode = require('lib.loveqrcode')
local https = require("https")
local uuidgen = require("lib.uuid")
local ltn12 = require("ltn12")
local bit = require("bit")    
local sha1 = require("sha1")
local struct = require("lib.struct")
local jsonread = true
local code128 = require("lib.bar128") -- an awesome Code128 library made by Nawias (POLSKA GUROM)
local itfbarcode = require("lib.i25")
local SCREEN_WIDTH = 400
local SCREEN_HEIGHT = 240
local theme = "light"
local codes = {}
local exists = "dunno"
local buttons = {}
love.graphics.setDefaultFilter("nearest")
kodyexist = love.filesystem.exists("kody.json")

if love._potion_version == nil then
	local nest = require("nest").init({ console = "3ds", scale = 1 })
	love._nest = true
    love._console_name = "3DS"
end

function love.load()
	jsonread = false
	refresh_data("https://zabka-snrs.zabka.pl/v4/server/time", data, {["api-version"] = "4.4", ["application-id"] = "%C5%BCappka", ["user-agent"] = "Synerise Android SDK 5.9.0 pl.zabka.apb2c", ["accept"] = "application/json", ["mobile-info"] = "horizon;28;AW700000000;9;CTR-001;nintendo;5.9.0", ["content-type"] = "application/json; charset=UTF-8", ["authorization"] = authtoken}, "GET")
	if not string.find(body, "serverTime") then
		intranet = "true"
	else	
		intranet = "false"
	end
	jsonread = true
	showcode = false
	codetypes = {"CODE128", "CODEI25", "ZAPPKA"}
    state = "main_page"
    code_type = 0
	selectioncode = 1
    checkforcodes()
	table.insert(buttons, createButton(195, 195, "assets/add.png", addcode, "main_page", "barcode"))
end
local function isLeapYear(year)
    return (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
end

local function daysInMonth(month, year)
    local days = {31, isLeapYear(year) and 29 or 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
    return days[month]
end

local function isoToUnix(isoDate)
    local pattern = "(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)%.(%d+)Z"
    local year, month, day, hour, min, sec, ms = isoDate:match(pattern)

    year, month, day = tonumber(year), tonumber(month), tonumber(day)
    hour, min, sec = tonumber(hour), tonumber(min), tonumber(sec)

    -- Days calculation since the Unix epoch (1970-01-01)
    local days = 0
    for y = 1970, year - 1 do
        days = days + (isLeapYear(y) and 366 or 365)
    end

    for m = 1, month - 1 do
        days = days + daysInMonth(m, year)
    end

    days = days + (day - 1)

    -- Convert to total seconds
    local totalSeconds = days * 86400 + hour * 3600 + min * 60 + sec

    return totalSeconds
end
function createButton(x, y, imagePath, callback, statename, secstatename, thrdstate)
    local image = love.graphics.newImage(imagePath) -- Load the image
    return {
        x = x,
        y = y,
        width = image:getWidth(),
        height = image:getHeight(),
        image = image,
        callback = callback,
        draw = function(self)
            -- Draw the image as the button
			if state == statename or state == secstatename then
				love.graphics.draw(self.image, self.x, self.y)
			end
        end,
        isTouched = function(self, touchX, touchY)
            -- Check if touch is within button boundaries
            return touchX > self.x and touchX < self.x + self.width and
                   touchY > self.y and touchY < self.y + self.height
        end
    }
end
function calculatetotp() --NAPRAWIŁEM KURWA
	local javaIntMax = 2147483647

	local function c(arr, index)
		local result = 0
		for i = index, index + 4 do
			result = bit.bor(bit.lshift(result, 8), bit.band(arr:byte(i), 0xFF))
		end
		return result
	end
	local secretHex = codes[selectioncode].qrsecret
	local secret = (secretHex:gsub('..', function(hex)
        return string.char(tonumber(hex, 16))
    end))
	if intranet == "true" then
		czas = alt_kalibracja()
	else
		czas = updatetime_withserver()
		print("internet: " .. czas)
	end
	if love._console == "3ds" then
		ts = math.floor(czas / 30)
	else 
		ts = math.floor(czas / 30)
	end
	print(ts)
    local msg = struct.pack(">L8", ts)

    local outputBytes = sha1.hmac_binary(secret, msg)
	--print(outputBytes)
	if outputBytes ~= nil then
		local magicNumber = bit.band(c(outputBytes, bit.band(outputBytes:byte(#outputBytes), 15)), 2147483647) % 1000000		
		totp = string.format("%06d", magicNumber)
		print(totp)
		print("https://zlgn.pl/view/dashboard?ploy=" .. codes[selectioncode].zappkaid .. "&loyal=" .. totp)
		qr1 = qrcode("https://zlgn.pl/view/dashboard?ploy=" .. codes[selectioncode].zappkaid .. "&loyal=" .. totp)
		generated_once = true
	else
		generated_once = true
		qr1 = nil
	end
end
function alt_kalibracja()
	local lastserverczas = love.filesystem.read("LastCzasInternet.txt")
	local lastlocalczas = love.filesystem.read("LastCzasIntranet.txt")
	local currentlocalczas = os.time()
	local dawajczas = lastserverczas + (currentlocalczas - lastlocalczas)
	love.filesystem.write("LastCzasInternet.txt", dawajczas)
	love.filesystem.write("LastCzasIntranet.txt", os.time())
	return dawajczas
end
function refresh_data(url, request, inheaders, metoda)
    print(url)
	print(request)
	--love.filesystem.write("data.txt", request)
    -- Headers
    -- local myheaders = {
        -- ["user-agent"] = "Mozilla/5.0 (Windows NT 10.0; rv:129.0) Gecko/20100101 Firefox/129.0",
        -- ["accept"] = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/png,image/svg+xml,*/*;q=0.8",
        -- ["sec-fetch-user"] = "?1",
		-- ["sec-fetch-site"] = "none",
        -- ["sec-fetch-mode"] = "navigate",
        -- ["sec-fetch-dest"] = "document",
        -- ["accept-encoding"] = "gzip, deflate, br, zstd",
        -- ["accept-language"] = " pl,en-US;q=0.7,en;q=0.3",
		-- ["upgrade-insecure-requests"] = "1",
		-- ["te"] = "trailers",
		-- ["content-length"] = "0",
        -- ["priority"] = "u=0, i"
    -- }
    -- Response table to collect the response body
	local request_body = request --the json body
    response_body = {}
    -- Making the HTTP request

	code, body, headers = https.request(url, {data = request_body, method = metoda, headers = inheaders})
	print(body)
	print(code)
	if jsonread == true then
		responded = json.decode(body)
	end
end
function updatetime_withserver()
	local data = ""
	refresh_data("https://zabka-snrs.zabka.pl/v4/server/time", data, {["api-version"] = "4.4", ["application-id"] = "%C5%BCappka", ["user-agent"] = "Synerise Android SDK 5.9.0 pl.zabka.apb2c", ["accept"] = "application/json", ["mobile-info"] = "horizon;28;AW700000000;9;CTR-001;nintendo;5.9.0", ["content-type"] = "application/json; charset=UTF-8", ["authorization"] = authtoken}, "GET")
	local dawajczas = isoToUnix(responded.serverTime) 
	love.filesystem.write("LastCzasInternet.txt", dawajczas)
	love.filesystem.write("LastCzasIntranet.txt", os.time())
	return dawajczas
end
function love.draw(screen)
    if screen == "bottom" then
        draw_bottom_screen()
    else
        draw_top_screen()
    end
end 
function zappkalogin()
	declarecode = codetypes[selectioncode]
	changes = "numtel"
	love.keyboard.setTextInput(true, {type = "numpad", hint = "Numer Tel."})
	love.keyboard.setTextInput(false)
end
function kod_sms()
	declarecode = codetypes[selectioncode]
	changes = "smscode"
	love.keyboard.setTextInput(true, {type = "numpad", hint = "Kod SMS"})
	love.keyboard.setTextInput(false)
end
function add_new_code()
	declarecode = codetypes[selectioncode]
	changes = "code"
	love.keyboard.setTextInput(true, {type = "numpad", hint = "Numerki z Kodu"})
	love.keyboard.setTextInput(false)
end

function add_new_name()
	changes = "name"
	love.keyboard.setTextInput(true, {hint = "Nazwa kodu"})
	love.keyboard.setTextInput(false)
end
function save_code()
	table.insert(codes, {code = codeinput, codetype = declarecode, name = nameinput})
	love.filesystem.write("kody.json", json.encode(codes))
	state = "main_page"
end
function checkforcodes()
	if kodyexist then
		codes = json.decode(love.filesystem.read("kody.json"))
	else 
		codes = {{code = "123456", codetype = "CODE128", name = "Example"}}
		love.filesystem.write("kody.json", json.encode(codes))
	end
end

function addcode()
	state = "whatcodetype"
end
--kod podjebany z żappka3ds lol (no wsm nie podjebany bo to mój kod)
function test()
	local data = json.encode({idToken = boinaczejjebnie})
    refresh_data("https://www.googleapis.com/identitytoolkit/v3/relyingparty/getAccountInfo?key=AIzaSyDe2Fgxn_8HJ6NrtJtp69YqXwocutAoa9Q", data, {["Content-Type"] = "application/json", ["X-Android-Package"] = "pl.zabka.apb2c", ["X-Android-Cert"] = "FAB089D9E5B41002F29848FC8034A391EE177077", ["Accept-Language"] = "en-US", ["X-Client-Version"] = "Android/Fallback/X22003001/FirebaseCore-Android", ["X-Firebase-GMPID"] = "1:146100467293:android:0ec9b9022788ad32b7bfb4", ["X-Firebase-Client"] = "H4sIAAAAAAAAAKtWykhNLCpJSk0sKVayio7VUSpLLSrOzM9TslIyUqoFAFyivEQfAAAA", ["Content-Length"] = "894", ["User-Agent"] = "Dalvik/2.1.0 (Linux; U; Android 9; SM-A600FN Build/PPR1.180610.011)", ["Host"] = "www.googleapis.com", ["Connection"] = "Keep-Alive"}, "POST")
end
function handle_authflow()
	local data = json.encode({clientType = "CLIENT_TYPE_ANDROID"})
    refresh_data("https://www.googleapis.com/identitytoolkit/v3/relyingparty/signupNewUser?key=AIzaSyDe2Fgxn_8HJ6NrtJtp69YqXwocutAoa9Q", data, {["content-type"] = "application/json"}, "POST")
	boinaczejjebnie = responded.idToken
end
function sendvercode(nrtel)
	local data = json.encode({operationName = "SendVerificationCode", query = "mutation SendVerificationCode($input: SendVerificationCodeInput!) { sendVerificationCode(input: $input) { retryAfterSeconds } }",variables = {input = {phoneNumber = {countryCode = "48", nationalNumber = nrtel}}}})
	refresh_data("https://super-account.spapp.zabka.pl/", data, {["content-type"] = "application/json", ["authorization"] = responded.idToken}, "POST")
end
function sendbackvercode(smscode)  
	local data = json.encode({operationName = "SignInWithPhone",variables = {input = {phoneNumber = {countryCode = "48", nationalNumber = numertel},verificationCode = smscode}}, query = "mutation SignInWithPhone($input: SignInInput!) { signIn(input: $input) { customToken } }"})
	refresh_data("https://super-account.spapp.zabka.pl/", data, {["content-type"] = "application/json", ["authorization"] = "Bearer " .. boinaczejjebnie, ["user-agent"] = "okhttp/4.12.0", ["x-apollo-operation-id"] = "a531998ec966db0951239efb91519560346cfecac77459fe3b85c5b786fa41de"	,["x-apollo-operation-name"] = "SignInWithPhone", ["accept"] = "multipart/mixed; deferSpec=20220824, application/json"}, "POST")
	--love.filesystem.write("data.txt", data)
	--love.filesystem.write("debug.txt", body)
	local tokentemp = responded.data.signIn.customToken
	local data = json.encode({token = tokentemp, returnSecureToken = "true"})
	refresh_data("https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyCustomToken?key=AIzaSyDe2Fgxn_8HJ6NrtJtp69YqXwocutAoa9Q", data, {["content-type"] = "application/json"}, "POST")
	local tokentemp = responded.idToken
	local data = json.encode({idToken = tokentemp})
	refresh_data("https://www.googleapis.com/identitytoolkit/v3/relyingparty/getAccountInfo?key=AIzaSyDe2Fgxn_8HJ6NrtJtp69YqXwocutAoa9Q", data, {["content-type"] = "application/json"}, "POST")
	loadingtext = "Logowanie 45%..."
	uuidgen.seed()
	local data = json.encode({identityProviderToken = tokentemp, identityProvider = "OAUTH", apiKey = "b646c65e-a43d-4a61-9294-6c7c4385c762", uuid = uuidgen(), deviceId = "0432b18513e325a5"})
	refresh_data("https://zabka-snrs.zabka.pl/sauth/v3/auth/login/client/conditional", data, {["api-version"] = "4.4", ["application-id"] = "%C5%BCappka", ["user-agent"] = "Synerise Android SDK 5.9.0 pl.zabka.apb2c", ["accept"] = "application/json", ["mobile-info"] = "horizon;28;AW700000000;9;CTR-001;nintendo;5.9.0", ["content-type"] = "application/json; charset=UTF-8"}, "POST")
	loadingtext = "Logowanie 65%..."
	authtoken = responded.token
	local data = ""
	refresh_data("https://qr-bff.spapp.zabka.pl/qr-code/secret", data, {["authorization"] = "Bearer " .. tokentemp, ["content-type"] = "application/json", ["accept"] = "application/json", ["app"] = "zappka-mobile", ["user-agent"] = "okhttp/4.12.0", ["content-length"] = "0"}, "GET")
	id = responded.userId
	secret = responded.secrets.loyal
	refresh_data("https://zabka-snrs.zabka.pl/v4/my-account/personal-information", data, {["api-version"] = "4.4", ["application-id"] = "%C5%BCappka", ["user-agent"] = "Synerise Android SDK 5.9.0 pl.zabka.apb2c", ["accept"] = "application/json", ["mobile-info"] = "horizon;28;AW700000000;9;CTR-001;nintendo;5.9.0", ["content-type"] = "application/json; charset=UTF-8", ["authorization"] = authtoken}, "GET")	
	zappkaname = responded.firstName
	table.insert(codes, {qrsecret = secret, codetype = declarecode, name = "Żappka " .. "( " .. zappkaname .. ")", zappkaid = id})
	love.filesystem.write("kody.json", json.encode(codes))
	state = "restartplz"
end

function draw_top_screen()
    SCREEN_WIDTH = 400
    SCREEN_HEIGHT = 240

    -- Fill background
    if theme == "light" then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    else
        if theme == "dark" then
            love.graphics.setColor(0.19, 0.20, 0.22, 1)
            love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
        end 
    end

    if state == "main_page" then
		if showcode == true then
			if codeteraz == "CODE128" then
				love.graphics.setColor(0, 0, 0, 1)
				barcode:draw('notext', 70)
			elseif codeteraz == "CODEI25" then
				love.graphics.setColor(1, 1, 1, 1)
				local imageWidth = barcodeImage:getWidth()
				local currentX2 = (400 - imageWidth) / 2
				love.graphics.draw(barcodeImage, currentX2, 70)
			elseif codeteraz == "ZAPPKA" then
				love.graphics.setColor(0, 0, 0, 1)
				qr1:draw(95,10,0,6.5)
			end
		else
			TextDraw.DrawTextCentered("Ticket Manager", SCREEN_WIDTH/2, 16, {0, 0, 0, 1}, font, 2.3)
			TextDraw.DrawTextCentered("by TehFridge", SCREEN_WIDTH/2, 42, {0, 0, 0, 1}, font, 1.9)
		end
    end
	if state == "whatcodetype" then
        TextDraw.DrawTextCentered("Select a code type", SCREEN_WIDTH/2, 106, {0, 0, 0, 1}, font, 2.3)
    end
	if state == "restartplz" then
        TextDraw.DrawTextCentered("Restart the app plz.", SCREEN_WIDTH/2, 106, {0, 0, 0, 1}, font, 2.3)
    end
end
       
function draw_bottom_screen()
    SCREEN_WIDTH = 400
    SCREEN_HEIGHT = 240

    -- Fill background
    if theme == "light" then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
    else
        if theme == "dark" then
            love.graphics.setColor(0.19, 0.20, 0.22, 1)
            love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
        end 
    end
    if state == "main_page" then
		scrolllimit = #codes
        TextDraw.DrawTextCentered("Your Codes/Tickets", SCREEN_WIDTH/2.5, 20, {0, 0, 0, 1}, font, 2.3)
		TextDraw.DrawText("->", 5, 50 + selectioncode * 20, {0, 0, 0, 1}, font, 1.9)
		for i = 1, #codes do
			TextDraw.DrawText(codes[i].name, 27, 50 + 20 * i, {0, 0, 0, 1}, font, 1.9)
		end
    end 
	if state == "whatcodetype" then
		scrolllimit = 3
		TextDraw.DrawText("->", 5, 50 + selectioncode * 20, {0, 0, 0, 1}, font, 1.9)
        TextDraw.DrawText("Code128", 27, 70, {0, 0, 0, 1}, font, 1.9)
		TextDraw.DrawText("Code I2/5 (Pyrkon)", 27, 90, {0, 0, 0, 1}, font, 1.9)
		TextDraw.DrawText("Żappka (Requires Internet)", 27, 110, {0, 0, 0, 1}, font, 1.9)
    end 
	for _, button in ipairs(buttons) do
		love.graphics.setColor(1, 1, 1, 1)
		button:draw()
	end	
end
function rendercode()
	if codes[selectioncode].codetype == "CODE128" then
		barcode = code128(codes[selectioncode].code, 60, 3)
	elseif codes[selectioncode].codetype == "CODEI25" then
		barcodeImage = itfbarcode.generateImage(codes[selectioncode].code, config)
	elseif codes[selectioncode].codetype == "ZAPPKA" then
		calculatetotp()
	end
	codeteraz = codes[selectioncode].codetype
	showcode = true
end
function love.touchpressed(id, x, y, dx, dy, pressure)
    -- Check if any button is pressed
    for _, button in ipairs(buttons) do
        if button:isTouched(x, y) then
            button.callback() -- Call the button's callback
        end
    end
end
function love.gamepadpressed(joystick, button)
	if state == "main_page" or state == "whatcodetype" then
		if button == "dpup" then
			if selectioncode ~= 1 then
				selectioncode = selectioncode - 1
			end
		end
		if button == "dpdown" then
			if selectioncode ~= scrolllimit then
				selectioncode = selectioncode + 1
			end
		end
	end
	if state == "whatcodetype" then
		if button == "a" then
			if selectioncode ~= 3 then
				add_new_code()
			else
				zappkalogin()
			end
		end
	end
	if state == "main_page" then
		if button == "a" then
			rendercode()
		end
	end
end

function love.textinput(text)
    if changes == "code" then
	    codeinput = text
		add_new_name()
	elseif changes == "name" then
		nameinput = text
		save_code()
	elseif changes == "numtel" then
	    handle_authflow()
		numertel = text
		sendvercode(text)
		kod_sms()
	elseif changes == "smscode" then
		sendbackvercode(text)  
	end
end

function love.update(dt)
    love.graphics.origin()  
end