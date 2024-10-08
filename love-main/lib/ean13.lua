local EAN13 = {}

EAN13.encodings = {
    L = {
        "0001101", "0011001", "0010011", "0111101", "0100011",
        "0110001", "0101111", "0111011", "0110111", "0001011"
    },
    G = {
        "0100111", "0110011", "0011011", "0100001", "0011101",
        "0111001", "0000101", "0010001", "0001001", "0010111"
    },
    R = {
        "1110010", "1100110", "1101100", "1000010", "1011100",
        "1001110", "1010000", "1000100", "1001000", "1110100"
    }
}

EAN13.parity_pattern = {
    "LLLLLL", "LLGLGG", "LLGGLG", "LLGGGL", "LGLLGG",
    "LGGLLG", "LGGGLL", "LGLGLG", "LGLGGL", "LGGLGL"
}

function EAN13.encode(barcode)
    assert(#barcode == 13, "EAN-13 barcode must be 13 digits long")

    local first_digit = tonumber(barcode:sub(1, 1))
    local left_side = barcode:sub(2, 7)
    local right_side = barcode:sub(8, 13)
    local pattern = EAN13.parity_pattern[first_digit + 1]

    local encoded = "101"  -- Start guard pattern

    -- Encode the left side
    for i = 1, #left_side do
        local digit = tonumber(left_side:sub(i, i))
        local parity = pattern:sub(i, i)
        encoded = encoded .. EAN13.encodings[parity][digit + 1]
    end

    encoded = encoded .. "01010"  -- Middle guard pattern

    -- Encode the right side
    for i = 1, #right_side do
        local digit = tonumber(right_side:sub(i, i))
        encoded = encoded .. EAN13.encodings.R[digit + 1]
    end

    encoded = encoded .. "101"  -- End guard pattern
    return encoded
end

-- Function to create the barcode image (Canvas)
function EAN13.create_image(barcode, width, height)
    local encoded_barcode = EAN13.encode(barcode)
    local barcode_width = #encoded_barcode * width  -- Calculate total width of the barcode
    local barcode_height = height

    -- Create a Canvas to draw the barcode
    local barcode_canvas = love.graphics.newCanvas(barcode_width, barcode_height)
    love.graphics.setCanvas(barcode_canvas)
    love.graphics.clear()

    local current_x = 0

    -- Draw the encoded barcode to the canvas
    for i = 1, #encoded_barcode do
        local bit = encoded_barcode:sub(i, i)
        if bit == "1" then
            love.graphics.rectangle("fill", current_x, 0, width, height)
        end
        current_x = current_x + width
    end

    love.graphics.setCanvas()  -- Reset to default canvas
    return barcode_canvas  -- Return the generated canvas
end

-- Function to render the barcode image at the center of the screen
function EAN13.render_image(canvas, screen_width, screen_height)
    local canvas_width, canvas_height = canvas:getDimensions()

    -- Calculate the position to center the barcode on the screen
    local x = (screen_width - canvas_width) / 2
    local y = (screen_height - canvas_height) / 2

    -- Draw the barcode canvas to the screen, centered
    love.graphics.draw(canvas, x, y)
end

return EAN13
