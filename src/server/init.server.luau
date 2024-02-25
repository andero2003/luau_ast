local Lexer = require(game.ReplicatedStorage:WaitForChild("Shared"):WaitForChild("lexer"))

local source = [[
    local x = 10
    local y = 20
    print(x + y)
]]

local lexer = Lexer.new(source)
lexer:tokenize()
print(lexer.tokens)