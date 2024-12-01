require "lib.text-draw"
font = love.graphics.newFont("assets/clacon2.ttf", 12, "normal", 4) 
local json = require("lib.json")
local qrcode = require('lib.loveqrcode')
local zappkacode = require('lib.zappkacode')
local https = require("https")
local uuidgen = require("lib.uuid")
local ltn12 = require("ltn12")
local bit = require("bit")    
local sha1 = require("sha1")
local struct = require("lib.struct")
local jsonread = true
local code128 = require("lib.bar128") 
local EAN13 = require("lib.ean13")
local itfbarcode = require("lib.i25")
local SCREEN_WIDTH = 400
local SCREEN_HEIGHT = 240
local theme = "light"
local codes = {}
local exists = "dunno"
local pagegap = 0
local buttons = {}
local music = love.audio.newSource("assets/bgm.ogg", "stream")
local sfx = love.audio.newSource("assets/cursor.ogg", "static")
local gonotfish = love.audio.newSource("assets/back.ogg", "static")
local sfx2 = love.audio.newSource("assets/accept.ogg", "static")
love.graphics.setDefaultFilter("nearest")
kodyexist = love.filesystem.exists("kody.json")
local stars = {}
local numStars = 200
local centerX, centerY
local xPos
local speed = 300 
local frequency = 5 
if love._potion_version == nil then
	local nest = require("nest").init({ console = "switch", scale = 1 })
	love._nest = true
    love._console_name = "Switch"
end
if love._console == "3DS" then
    charWidth = 45 
	amplitude = 25 
	SCREEN_WIDTH = 400
	SCREEN_HEIGHT = 240
	QR_SCALE_BASE = 214.5
	BAR_SCALE = 2.5
	BUTTONSCALE = 1
	theme = "light"
	text = "CTRWallet"
elseif love._console == "Switch" then
	charWidth = 90 
	amplitude = 50 
	SCREEN_WIDTH = 1280
	SCREEN_HEIGHT = 720
	QR_SCALE_BASE = 504.5
	BAR_SCALE = 6
	BUTTONSCALE = 2
	theme = "dark"
	text = "NXWallet"
elseif love._console == "Wii U" then
	SCREEN_WIDTH = 854
	SCREEN_HEIGHT = 480
	QR_SCALE_BASE = 344.5
	BAR_SCALE = 4
	BUTTONSCALE = 2
end
function love.load()
	debugtext = ""
	jsonread = false
	refresh_data("https://zabka-snrs.zabka.pl/v4/server/time", data, {["api-version"] = "4.4", ["application-id"] = "%C5%BCappka", ["user-agent"] = "Synerise Android SDK 5.9.0 pl.zabka.apb2c", ["accept"] = "application/json", ["mobile-info"] = "horizon;28;AW700000000;9;CTR-001;nintendo;5.9.0", ["content-type"] = "application/json; charset=UTF-8", ["authorization"] = authtoken}, "GET")
	if not string.find(body, "serverTime") then
		intranet = "true"
	else	
		intranet = "false"
	end
	jsonread = true
	showcode = false
	codetypes = {"CODE128", "CODEI25", "ZAPPKA", "QRCODE", "EAN13", "CODE128SUB", "IMAGE"}
    state = "main_page"
    code_type = 0
	selectioncode = 1
    checkforcodes()
	if love._console == "Switch" then
		table.insert(buttons, createButton(SCREEN_WIDTH / 1.25, SCREEN_WIDTH / 2, "assets/add.png", addcode, "main_page", "barcode"))
	elseif love._console == "3DS" then
		table.insert(buttons, createButton(195, 195, "assets/add.png", addcode, "main_page", "barcode"))
	elseif love._console == "Wii U" then
		table.insert(buttons, createButton(SCREEN_WIDTH / 1.4, SCREEN_WIDTH / 2.2, "assets/add.png", addcode, "main_page", "barcode"))
	end
	xPos = love.graphics.getWidth() 
	table.insert(buttons, createButton(10, 10, "assets/back.png", goback, "whatcodetype", "barcode"))
	centerX, centerY = SCREEN_WIDTH / 2, SCREEN_HEIGHT / 2
	for i = 1, numStars do
		createStar()
	end

	for i = 1, numStars do
		local distance = love.math.random(0, math.min(SCREEN_WIDTH, SCREEN_HEIGHT) / 2)
		local angle = love.math.random() * 2 * math.pi
		stars[i] = {
			x = centerX + math.cos(angle) * distance,
			y = centerY + math.sin(angle) * distance,
			distance = distance,
			speed = love.math.random(50, 150) / 100, 
			size = love.math.random(1, 3)
		}
	end
	music:setLooping(true)
    music:play()
	music:setVolume(1)
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

    
    local days = 0
    for y = 1970, year - 1 do
        days = days + (isLeapYear(y) and 366 or 365)
    end

    for m = 1, month - 1 do
        days = days + daysInMonth(m, year)
    end

    days = days + (day - 1)

    
    local totalSeconds = days * 86400 + hour * 3600 + min * 60 + sec

    return totalSeconds
end
function createButton(x, y, imagePath, callback, statename, secstatename, thrdstate)
    local image = love.graphics.newImage(imagePath) 
    return {
        x = x,
        y = y,
        width = image:getWidth() * BUTTONSCALE,
        height = image:getHeight() * BUTTONSCALE,
        image = image,
        callback = callback,
        draw = function(self)
            
			if state == statename or state == secstatename then
				love.graphics.draw(self.image, self.x, self.y, 0, BUTTONSCALE)
			end
        end,
        isTouched = function(self, touchX, touchY)
            
			if state == statename or state == secstatename then
				return touchX > self.x and touchX < self.x + self.width and
					touchY > self.y and touchY < self.y + self.height
			end
        end
    }
end
function calculatetotp()
	local javaIntMax = 2147483647

	local function c(arr, index)
		local result = 0
		for i = index, index + 3 do  
			result = bit.bor(bit.lshift(result, 8), bit.band(arr:byte(i), 0xFF))
		end
		return result
	end

	local secretHex = codes[selectioncode + pagegap].qrsecret
	local secret = (secretHex:gsub('..', function(hex)
		return string.char(tonumber(hex, 16))
	end))

	if intranet == "true" then
		czas = alt_kalibracja()
	else
		czas = updatetime_withserver()
		print("internet: " .. czas)
	end

	ts = math.floor(czas / 30)
	print(ts)

	local msg = struct.pack(">L8", ts)
	local outputBytes = sha1.hmac_binary(secret, msg)

	if outputBytes ~= nil then
		if #outputBytes >= 4 then
			local byteIndex = outputBytes:byte(#outputBytes)
			local offset = bit.band(byteIndex, 15)
			print("byteIndex: " .. byteIndex)
			print("offset: " .. offset)
			local magicNumber = bit.band(c(outputBytes, offset + 1), javaIntMax) % 1000000  
			totp = string.format("%06d", magicNumber)
			print(totp)
			print("https://srln.pl/view/dashboard?ploy=" .. codes[selectioncode + pagegap].zappkaid .. "&loyal=" .. totp)
			qr1 = zappkacode("https://srln.pl/view/dashboard?ploy=" .. codes[selectioncode + pagegap].zappkaid .. "&loyal=" .. totp, 4)
			generated_once = true
		else
			print("outputBytes too short: " .. #outputBytes)
			generated_once = false
		end
	else
		print("Failed to generate HMAC")
		generated_once = false
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
	local request_body = request 
    response_body = {}
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
	if love._console ~= "Switch" then
		if screen == "bottom" then
			draw_bottom_screen()
		else
			draw_top_screen()
		end
	else
		if love._console == "Switch" then
			draw_top_screen()
		elseif love._console == "Wii U" then
			if screen == "gamepad" then
				draw_top_screen()
			end
		end
	end
end 
function zappkalogin()
	declarecode = codetypes[selectioncode]
	changes = "numtel"
	love.keyboard.setTextInput(true, {type = "numpad", hint = "Phone Number"})
	love.keyboard.setTextInput(false)
end
function kod_sms()
	declarecode = codetypes[selectioncode]
	changes = "smscode"
	love.keyboard.setTextInput(true, {type = "numpad", hint = "SMS Code"})
	love.keyboard.setTextInput(false)
end
function add_new_code()
	declarecode = codetypes[selectioncode]
	changes = "code"
	if love._potion_version ~= nil then
		if declarecode == "QRCODE" or declarecode == "CODE128" or declarecode == "CODE128SUB" then
			love.keyboard.setTextInput(true, {hint = "Code Data"})
		elseif declarecode == "EAN13" or declarecode == "CODEI25" then
			love.keyboard.setTextInput(true, {type = "numpad", hint = "Code Numbers"})
		elseif declarecode == "IMAGE" then
			love.keyboard.setTextInput(true, {hint = "Image URL"})
		end
	else
		love.keyboard.setTextInput(true, 200, 100, 40, 30)
	end
	love.keyboard.setTextInput(false)
end

function add_new_name()
	changes = "name"
	love.keyboard.setTextInput(true, {hint = "Code Name"})
	love.keyboard.setTextInput(false)
end

function save_code()
	if declarecode == "IMAGE" then
		table.insert(codes, {url = codeinput, codetype = declarecode, name = nameinput})
	else
		table.insert(codes, {code = codeinput, codetype = declarecode, name = nameinput})
	end
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
function goback()
	gonotfish:play()
	selectioncode = 1
	state = "main_page"
end
function addcode()
	sfx2:play()
	selectioncode = 1
	state = "whatcodetype"
end

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
	
	
	local tokentemp = responded.data.signIn.customToken
	local data = json.encode({token = tokentemp, returnSecureToken = "true"})
	refresh_data("https://www.googleapis.com/identitytoolkit/v3/relyingparty/verifyCustomToken?key=AIzaSyDe2Fgxn_8HJ6NrtJtp69YqXwocutAoa9Q", data, {["content-type"] = "application/json"}, "POST")
	local tokentemp = responded.idToken
	local data = json.encode({idToken = tokentemp})
	refresh_data("https://www.googleapis.com/identitytoolkit/v3/relyingparty/getAccountInfo?key=AIzaSyDe2Fgxn_8HJ6NrtJtp69YqXwocutAoa9Q", data, {["content-type"] = "application/json"}, "POST")
	loadingtext = "Logowanie 45%..."
	uuidgen.seed()
	local data = json.encode({operationName = "SignIn",query = "mutation SignIn($signInInput: SignInInput!) { signIn(signInInput: $signInInput) { profile { __typename ...UserProfileParts } } }  fragment UserProfileParts on UserProfile { email gender }",variables = {signInInput = {sessionId = "65da013a-0d7d-3ad4-82bd-2bc15077d7f5"}}})
	refresh_data("https://api.spapp.zabka.pl/", data, {["user-agent"] = "Zappka/40038 (Horizon; nintendo/ctr; 56c41945-ba88-4543-a525-4e8f7d4a5812) REL/28", ["accept"] = "application/json", ["content-type"] = "application/json", ["authorization"] = "Bearer " .. tokentemp}, "POST")
	loadingtext = "Logowanie 65%..."
	authtoken = tokentemp
	print(authtoken)
	local data = json.encode({operationName = "QrCode", query ="query QrCode { qrCode { loyalSecret paySecret ployId } }", variables = {}})
	local data = data:gsub('"variables":%[%]', '"variables":{}')
	refresh_data("https://api.spapp.zabka.pl/", data, {["user-agent"] = "Zappka/40038 (Horizon; nintendo/ctr; 56c41945-ba88-4543-a525-4e8f7d4a5812) REL/28", ["accept"] = "application/json", ["content-type"] = "application/json", ["authorization"] = "Bearer " .. authtoken}, "POST")
	id = responded.data.qrCode.ployId
	secret = responded.data.qrCode.loyalSecret
	local data = json.encode({operationName = "GetProfile", query = "query GetProfile { profile { id firstName birthDate phoneNumber { countryCode nationalNumber } email } }",variables = {}})
	local data = data:gsub('"variables":%[%]', '"variables":{}')
	refresh_data("https://super-account.spapp.zabka.pl/", data, {["user-agent"] = "Zappka/40038 (Horizon; nintendo/ctr; 56c41945-ba88-4543-a525-4e8f7d4a5812) REL/28", ["accept"] = "application/json", ["content-type"] = "application/json", ["authorization"] = "Bearer " .. tokentemp}, "POST")	
	zappkaname = responded.data.profile.firstName
	table.insert(codes, {qrsecret = secret, codetype = declarecode, name = "Żappka " .. "( " .. zappkaname .. " )", zappkaid = id})
	love.filesystem.write("kody.json", json.encode(codes))
	state = "restartplz"
end
function downloadimage(url)
	jsonread = false
	if love._console == "3DS" then
		local data = json.encode({url = url})
		refresh_data("https://api.szprink.xyz/t3x/convert", data, {["api-version"] = "4.4", ["application-id"] = "%C5%BCappka", ["user-agent"] = "Synerise Android SDK 5.9.0 pl.zabka.apb2c", ["accept"] = "application/json", ["mobile-info"] = "horizon;28;AW700000000;9;CTR-001;nintendo;5.9.0", ["content-type"] = "application/json"}, "POST")
		local imageData = love.image.newImageData(love.filesystem.newFileData(body, "image.t3x"))
		kuponimage = love.graphics.newImage(imageData)
	else
		refresh_data(url, "", {}, "GET")
		local imageData = love.image.newImageData(love.filesystem.newFileData(body, "image.png"))
		kuponimage = love.graphics.newImage(imageData)
	end
end
function draw_top_screen()
    
    if theme == "light" then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
		themecolor = {0,0,0,1}
    else
        if theme == "dark" then
            love.graphics.setColor(0.19, 0.20, 0.22, 1)
            love.graphics.rectangle("fill", 0, 0, SCREEN_WIDTH, SCREEN_HEIGHT)
			themecolor = {1,1,1,1}
        end 
    end
	if theme == "dark" then
		love.graphics.setColor(1,1,1,0.4) 
		for _, star in ipairs(stars) do
			love.graphics.circle("fill", star.x, star.y, 2)
		end
	end	
	if theme == "dark" then
		love.graphics.setColor(1,1,1,0.7)
		
		local offset = love.graphics.getHeight() / 2

		for i = 1, #text do
			local letter = text:sub(i, i)
			local letterX = xPos + (i - 1) * charWidth
			local letterY = offset + amplitude * math.sin((i + love.timer.getTime()) * frequency)
			local sineshit = (math.sin((i + love.timer.getTime()) * frequency) ) / 4
			love.graphics.setColor(0,0,0,0.4)
			love.graphics.print(letter, letterX + 5, letterY - 25,sineshit,BAR_SCALE * 1.5,BAR_SCALE * 1.5)
			love.graphics.setColor(1,1,1,0.7)
			love.graphics.print(letter, letterX, letterY - 30,sineshit,BAR_SCALE * 1.5,BAR_SCALE * 1.5)
		end
	end
    if state == "main_page" then
		if showcode == true then
			if codeteraz == "CODE128" then
				love.graphics.setColor(0, 0, 0, 1)
				local y = (SCREEN_HEIGHT) / 3
				barcode:draw('notext', y, SCREEN_WIDTH)
			elseif codeteraz == "CODEI25" then
				love.graphics.setColor(1, 1, 1, 1)
				local imageWidth = barcodeImage:getWidth()
				local currentX2 = (SCREEN_WIDTH - imageWidth) / 2
				local y = (SCREEN_HEIGHT) / 3
				love.graphics.draw(barcodeImage, currentX2, y)
			elseif codeteraz == "ZAPPKA" or codeteraz == "QRCODE" then
				if qr1 ~= nil then
					
					local qrSize = qr1:getSize()
					local scale = QR_SCALE_BASE / qrSize 
					
					local x = (SCREEN_WIDTH - qrSize) / 2
					local y = (SCREEN_HEIGHT - qrSize) / 2
					love.graphics.setColor(1,1,1,1)
					qr1:draw(x + 15,y + 10,0,scale, scale, qrSize / 2, qrSize / 2)
				else
					TextDraw.DrawTextCentered("Sorry the TOTP Generation Failed. Try Again Later", SCREEN_WIDTH/2, SCREEN_HEIGHT / 2, themecolor, font, 2, true)
				end
			elseif codeteraz == "CODE128SUB" then
				love.graphics.setColor(0, 0, 0, 1)
				local y = (SCREEN_HEIGHT) / 3
				barcode:draw('notext', y, SCREEN_WIDTH)
			elseif codeteraz == "EAN13" then
				love.graphics.setColor(1, 1, 1, 1)
				EAN13.render_image(barcode_image, SCREEN_WIDTH, SCREEN_HEIGHT, BAR_SCALE)
			elseif codeteraz == "IMAGE" then
				love.graphics.setColor(1, 1, 1, 1)
				local imageWidth = kuponimage:getWidth()
				local imageHeight = kuponimage:getHeight()
				local x = (SCREEN_WIDTH - imageWidth) / 2
				local y = (SCREEN_HEIGHT - imageHeight) / 2
				-- Draw the image at the calculated position
				love.graphics.draw(kuponimage, x, y)
			end
		else
			if love._console == "3DS" then
				TextDraw.DrawTextCentered("CTRWallet", SCREEN_WIDTH/2, 16, themecolor, font, 2.3, true)
			else 
				TextDraw.DrawTextCentered("NXWallet", SCREEN_WIDTH/2, 16, themecolor, font, 2.3, true)
			end
			TextDraw.DrawTextCentered("by TehFridge", SCREEN_WIDTH/2, 42, themecolor, font, 1.9, true)
		end
    end
	if love._console == "Switch" or love._console == "Wii U" then
		if state == "main_page" then
			TextDraw.DrawText("Your Codes/Tickets", 60, 25, themecolor, font, 3, true)
			TextDraw.DrawText("->", 5, 55 + selectioncode * 30, themecolor, font, 1.9, true)
			if #codes < 6 then
				for i = 1, #codes do
					TextDraw.DrawText(codes[i + pagegap].name, 27, 55 + 30 * i, themecolor, font, 2.3, true)
				end
			else 
				for i = 1, 6 do
					TextDraw.DrawText(codes[i + pagegap].name, 27, 55 + 30 * i, themecolor, font, 1.9, true)
				end
			end
		end 
		if state == "whatcodetype" then
			TextDraw.DrawText("->", 5, 120 + selectioncode * 20, themecolor, font, 1.9, true)
			TextDraw.DrawText("Code128", 27, 140, themecolor, font, 1.9, true)
			TextDraw.DrawText("Code I2/5", 27, 160, themecolor, font, 1.9, true)
			TextDraw.DrawText("Żappka (Requires Internet)", 27, 180, themecolor, font, 1.9, true)
			TextDraw.DrawText("QR Code", 27, 200, themecolor, font, 1.9, true)
			TextDraw.DrawText("EAN13 Barcode", 27, 220, themecolor, font, 1.9, true)
			TextDraw.DrawText("Code128 w/ Subset Switching", 27, 240, themecolor, font, 1.9, true)
			TextDraw.DrawText("Image (Requires Internet)", 27, 260, themecolor, font, 1.9, true)
		end 		
		for _, button in ipairs(buttons) do
			love.graphics.setColor(1, 1, 1, 1)
			button:draw()
		end	
	end
	if state == "whatcodetype" then
        TextDraw.DrawTextCentered("Select a code type", SCREEN_WIDTH/2, 106, themecolor, font, 2.3, true)
    end
	if state == "restartplz" then
        TextDraw.DrawTextCentered("Restart the app plz.", SCREEN_WIDTH/2, 106, themecolor, font, 2.3, true)
    end
	TextDraw.DrawText("BGM: funky lesbians (LVS OST) - ida", 1, SCREEN_HEIGHT - 20, themecolor, font, 1.3, true)
end
       
function draw_bottom_screen()
    SCREEN_WIDTH = 400
    SCREEN_HEIGHT = 240
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
        TextDraw.DrawTextCentered("Your Codes/Tickets", SCREEN_WIDTH/2.5, 20, themecolor, font, 2.3, true)
		TextDraw.DrawText("->", 5, 50 + selectioncode * 20, themecolor, font, 1.9, true)
		if #codes < 6 then
			for i = 1, #codes do
				TextDraw.DrawText(codes[i + pagegap].name, 27, 50 + 20 * i, themecolor, font, 1.9, true)
			end
		else 
			for i = 1, 6 do
				TextDraw.DrawText(codes[i + pagegap].name, 27, 50 + 20 * i, themecolor, font, 1.9, true)
			end
		end
    end 
	if state == "whatcodetype" then
		TextDraw.DrawText("->", 5, 50 + selectioncode * 20, themecolor, font, 1.9, true)
        TextDraw.DrawText("Code128", 27, 70, themecolor, font, 1.9, true)
		TextDraw.DrawText("Code I2/5", 27, 90, themecolor, font, 1.9, true)
		TextDraw.DrawText("Żappka (Requires Internet)", 27, 110, themecolor, font, 1.9, true)
		TextDraw.DrawText("QR Code", 27, 130, themecolor, font, 1.9, true)
		TextDraw.DrawText("EAN13 Barcode", 27, 150, themecolor, font, 1.9, true)
		TextDraw.DrawText("Code128 w/ Subset Switching", 27, 170, themecolor, font, 1.9, true)
		TextDraw.DrawText("Image (Requires Internet)", 27, 190, themecolor, font, 1.9, true)
    end 

	for _, button in ipairs(buttons) do
		love.graphics.setColor(1, 1, 1, 1)
		button:draw()
	end	
end
function rendercode()
	collectgarbage("collect")
	jsonread = true
	if codes[selectioncode + pagegap].codetype == "CODE128" then
		barcode = code128(codes[selectioncode + pagegap].code, 30 * BAR_SCALE, BAR_SCALE, nil, false)
	elseif codes[selectioncode + pagegap].codetype == "CODEI25" then
		barcodeImage = itfbarcode.generateImage(codes[selectioncode + pagegap].code, config, BAR_SCALE)
	elseif codes[selectioncode + pagegap].codetype == "ZAPPKA" then
		calculatetotp()
	elseif codes[selectioncode + pagegap].codetype == "QRCODE" then
		qr1 = qrcode(codes[selectioncode + pagegap].code)
	elseif codes[selectioncode + pagegap].codetype == "EAN13" then
		barcode_image = EAN13.create_image(codes[selectioncode + pagegap].code, 3, 67)
	elseif codes[selectioncode + pagegap].codetype == "wavetest" then
		barcodeImage = itfbarcode.generateImage(codes[selectioncode + pagegap].code, config, BAR_SCALE)
	elseif codes[selectioncode + pagegap].codetype == "CODE128SUB" then
		barcode = code128(codes[selectioncode + pagegap].code, 30 * BAR_SCALE, BAR_SCALE - 0.3, nil, true)
	elseif codes[selectioncode + pagegap].codetype == "IMAGE" then
		downloadimage(codes[selectioncode + pagegap].url)
	end
	codeteraz = codes[selectioncode + pagegap].codetype
	showcode = true
end
function love.touchpressed(id, x, y, dx, dy, pressure)
    
    for _, button in ipairs(buttons) do
        if button:isTouched(x, y) then
            button.callback() 
        end
    end
end
function love.gamepadpressed(joystick, button)
	if state == "main_page" then
		if button == "dpup" then
			if #codes < 6 then
				if selectioncode ~= 1 then
					sfx:play()
					selectioncode = selectioncode - 1
				end
			else 	
				if selectioncode ~= 1 then
					sfx:play()
					selectioncode = selectioncode - 1
				elseif (selectioncode + pagegap) ~= 1 and selectioncode >= 1 then
					sfx:play()
					pagegap = pagegap - 1
				end
			end
		end
		if button == "dpdown" then
			if #codes < 6 then
				if selectioncode ~= #codes then
					sfx:play()
					selectioncode = selectioncode + 1
				end
			else 	
				if selectioncode ~= 6 then
					sfx:play()
					selectioncode = selectioncode + 1
				elseif (selectioncode + pagegap) ~= #codes and selectioncode >= 6 then
					sfx:play()
					pagegap = pagegap + 1
				end
			end
		end
		if button == "x" then
			if #codes ~= 1 then
				if #codes > 6 then
					table.remove(codes, selectioncode + pagegap)
					if pagegap >= 1 then
						pagegap = pagegap - 1
					end
					love.filesystem.write("kody.json", json.encode(codes))
				else
					table.remove(codes, selectioncode)
					if selectioncode ~= 1 then
						selectioncode = selectioncode - 1
					end
					love.filesystem.write("kody.json", json.encode(codes))
			    end
			end
		end
	elseif state == "whatcodetype" then
		if button == "dpup" then
			if selectioncode ~= 1 then
				sfx:play()
				selectioncode = selectioncode - 1
			end
		end
		if button == "dpdown" then
			if selectioncode ~= #codetypes then
				sfx:play()
				selectioncode = selectioncode + 1
			end
		end
	end
	if state == "whatcodetype" then
		if button == "a" then
			sfx2:play()
			if selectioncode ~= 3 then
				add_new_code()
			else
				zappkalogin()
			end
		end
	end
	if state == "main_page" then
		if button == "a" then
			sfx2:play()
			rendercode()
		end
	end
	if button == "start" then
		love.event.quit()
    end
	if button == "leftshoulder" then
		if theme == "light" then
			theme = "dark"
		else
			theme = "light"
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
	elseif changes == "imageadd" then
		codeinput = text
		add_new_name()
	end
end
function shiftRight(t)
    local last = t[#t]
    for i = #t, 2, -1 do
        t[i] = t[i-1]
    end
    t[1] = last
end
function createStar()
    local distance = love.math.random(0, math.min(SCREEN_WIDTH, SCREEN_HEIGHT) / 2)
    local angle = love.math.random() * 2 * math.pi
    table.insert(stars, {
        x = centerX + math.cos(angle) * distance,
        y = centerY + math.sin(angle) * distance,
        distance = distance,
        speed = love.math.random(50, 150) / 100, 
        size = love.math.random(1, 3)
    })
end
function love.update(dt)
	if theme == "dark" then
		for i, star in ipairs(stars) do
			local directionX = (star.x - centerX) * star.speed * dt
			local directionY = (star.y - centerY) * star.speed * dt
			star.x = star.x + directionX
			star.y = star.y + directionY
			star.size = star.size * (1 - dt * 0.2)	
			if star.x < 0 or star.x > SCREEN_WIDTH or star.y < 0 or star.y > SCREEN_HEIGHT or star.size < 0.5 then
				table.remove(stars, i) 
				createStar() 
			end
		end
	end
	if theme == "dark" then
		xPos = xPos - speed * dt
		if xPos < -(#text * charWidth) then
			xPos = love.graphics.getWidth()
		end
	end
    love.graphics.origin()  
end