require "lib.text-draw"
local SCREEN_WIDTH = 400
local SCREEN_HEIGHT = 240
local theme = "light"
local codes = {}
local exists = "dunno"


function love.load()
    menu = 0
    code_type = 0
    checkforcodes()
end
 
function love.draw(screen)
    if screen == "bottom" then
        draw_bottom_screen()
    else
        draw_top_screen()
    end
end 

function add_new_code()
    love.keyboard.setTextInput(true, {hint = "Write your code here."})
    love.filesystem.write("codes.txt", codetosave)
end

function checkforcodes()
    for line in love.filesystem.lines("codes.txt") do
        local stringxd = line
        table.insert(codes, stringxd)
    end
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

    if menu == 0 then
        TextDraw.DrawTextCentered("Ticket Manager", SCREEN_WIDTH/2, 16, {0, 0, 0, 1}, font, 2.3)
        TextDraw.DrawTextCentered("by TehFridge", SCREEN_WIDTH/2, 42, {0, 0, 0, 1}, font, 1.9)
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
    if menu == 0 then
        TextDraw.DrawTextCentered("Your Codes/Tickets", SCREEN_WIDTH/2.5, 20, {0, 0, 0, 1}, font, 2.3)
        TextDraw.DrawText(codes, 20, 70, {0, 0, 0, 1}, font, 1.9)
    end   
end

function love.gamepadpressed(joystick, button)
    if button == "a" then  
        add_new_code()
    end
end

function love.textinput(text)
    codetosave = text
end

function love.update(dt)
    love.graphics.origin()  
end