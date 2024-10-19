-- itfbarcode.lua
local itfbarcode = {}

-- Encodings for each digit 0-9
local encodings = {
    ["0"] = "nnwwn", ["1"] = "wnnnw", ["2"] = "nwnnw", ["3"] = "wwnnn",
    ["4"] = "nnwnw", ["5"] = "wnwnn", ["6"] = "nwwnn", ["7"] = "nnnww",
    ["8"] = "wnnwn", ["9"] = "nwnwn"
}

-- Start and Stop codes
local startCode = "nnnn"
local stopCode = "wnn"

-- Default configuration
local defaultConfig = {
    narrowWidth = 2.5,    -- Width of narrow bars in pixels
    wideWidth = 7,      -- Width of wide bars in pixels
    barHeight = 20,    -- Height of the barcode in pixels
    barColor = {0, 0, 0, 255},       -- Black bars (RGBA)
    backgroundColor = {255, 255, 255, 178}  -- White background (RGBA)
}

-- Helper function to validate and pad the number
local function validateNumber(number)
    if #number % 2 ~= 0 then
        number = "0" .. number  -- Pad with leading zero if odd length
    end
    return number
end

-- Private function to get the encoding for a pair of digits
local function getEncoding(pair)
    local encoding = ""
    local firstDigit = pair:sub(1, 1)
    local secondDigit = pair:sub(2, 2)
    local firstEncoding = encodings[firstDigit]
    local secondEncoding = encodings[secondDigit]

    if not firstEncoding or not secondEncoding then
        error("Invalid digits in barcode number.")
    end

    -- Interleave first and second encodings
    for i = 1, #firstEncoding do
        encoding = encoding .. firstEncoding:sub(i, i) .. secondEncoding:sub(i, i)
    end
    return encoding
end

-- Function to generate the full barcode encoding
local function generateEncoding(number)
    number = validateNumber(number)
    local fullEncoding = startCode
    for i = 1, #number, 2 do
        local pair = number:sub(i, i + 1)
        fullEncoding = fullEncoding .. getEncoding(pair)
    end
    fullEncoding = fullEncoding .. stopCode
    return fullEncoding
end

-- Function to generate ImageData for the barcode
function itfbarcode.generateImageData(number, config, scale)
    config = config or {}
    -- Merge default config with user config
    local narrowWidth = config.narrowWidth or defaultConfig.narrowWidth * (scale / 2.5)
    local wideWidth = config.wideWidth or defaultConfig.wideWidth * (scale / 2.5)
    local barHeight = config.barHeight or defaultConfig.barHeight * scale * 1.5
    local barColor = config.barColor or defaultConfig.barColor
    local backgroundColor = config.backgroundColor or defaultConfig.backgroundColor

    -- Generate the barcode pattern
    local barcodePattern = generateEncoding(number)

    -- Calculate total width
    local totalWidth = 0
    for i = 1, #barcodePattern do
        local barType = barcodePattern:sub(i, i)
        local barWidth = (barType == "n") and narrowWidth or wideWidth
        totalWidth = totalWidth + barWidth
    end

    -- Create ImageData with the calculated dimensions
    local imageData = love.image.newImageData(totalWidth, barHeight)

    -- Fill background
    imageData:mapPixel(function(x, y, r, g, b, a)
        return backgroundColor[1]/255, backgroundColor[2]/255, backgroundColor[3]/255, backgroundColor[4]/255
    end)

    -- Draw the barcode bars
    local currentX = 0
    for i = 1, #barcodePattern do
        local barType = barcodePattern:sub(i, i)
        local barWidth = (barType == "n") and narrowWidth or wideWidth

        if i % 2 == 1 then
            -- Black bar
            for x = currentX, currentX + barWidth - 1 do
                for y = 0, barHeight - 1 do
                    imageData:setPixel(x, y, barColor[1]/255, barColor[2]/255, barColor[3]/255, barColor[4]/255)
                end
            end
        end
        currentX = currentX + barWidth
    end

    return imageData
end

-- Function to generate an Image from the barcode
function itfbarcode.generateImage(number, config, skala)
    local imageData = itfbarcode.generateImageData(number, config, skala)
    return love.graphics.newImage(imageData)
end

return itfbarcode