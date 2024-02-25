local Lexer = require(game.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("lexer"))

local source = [[
    function thisIsSomething(test: string)
        print(test .. " is a string")
    end

    -- this is a comment
    
    local x = 10 -- this is another comment
    local y = 20
    print(x + y)
    
]]

local lexer = Lexer.new(source)
lexer:tokenize()
print(lexer.tokens)