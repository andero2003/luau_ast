local Lexer = require(game.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("lexer"))
local Parser = require(game.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("parser"))

local source = [[
    function thisIsSomething<GENERIC>(test: string, ...)
        print(test .. " is a string")
    end

    local example = `interpolated example {1+1==2 and "hello" or "world"} end of example`

    -- this is a comment
    
    local x = 10 -- this is another comment
    local y = 20
    print(x + y)

    x += 10

    for i = 1, 10 do
        print(i)
    end
]]

local source2 = [[
    local myClass = {}
    myClass.__index = myClass
]]

--[[
    function myClass.new()
        return setmetatable({}, myClass)
    end

    function myClass:hello()
        print("hello")

        return 0b101100
    end

    local instance = myClass.new()
    instance:hello()
]]

local lexer = Lexer.new(source2)
lexer:tokenize()
print(lexer.tokens)

local parser = Parser.new(lexer.tokens)
local ast = parser:parseBlock()
print(ast)