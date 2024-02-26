local TokenModule = require(script:WaitForChild("Token"))
local Token = TokenModule.Token
local Tokens = TokenModule.Tokens

local Lexer = {}
Lexer.__index = Lexer

function Lexer.new(source: string)
    local self = setmetatable({}, Lexer)
    self.source = source
    self.tokens = {}
    self.pos = 1
    self.line = 1
    return self
end

function Lexer:advance(by: number)
    by = by or 1
    self.pos += by
    if self.pos > #self.source then
        print(self.tokens)
        error("Unexpected end of file")
    end
end

function Lexer:tokenize()
    local interpolating = false
    
    while self.pos < #self.source do
        local char = self.source:sub(self.pos, self.pos)
        if char == " " then
            self:advance()
        elseif char == "\n" then
            self.line += 1
            self.column = 1
            self:advance()
        elseif char:match("[%a_]") then
            self:identifier()
        elseif char:match("%d") then
            self:number()
        elseif char:match("%s") then
            self:advance()
        elseif char == '-' and self:peekNextChar() == '-' then
            -- Ignore comments
            if self:peekNextChar(2) == '[' then
                local start = self.pos
                while self.source:sub(self.pos, self.pos + 1) ~= "]]" do
                    self:advance()
                end
                self:advance()
                self:advance()
            else
                while self.source:sub(self.pos, self.pos) ~= "\n" do
                    self:advance()
                end    
            end
        elseif char:match("[+%-%*/%%%^#=<>()%[%]{};:,%.]") then
            if char == '}' and interpolating then
                interpolating = false
            end
            self:symbol()           
        elseif char == "\"" or char == "\'" then
            self:string()
        elseif char == '`' then
            self:advance()
            local start = self.pos
            while self.source:sub(self.pos, self.pos) ~= '`' do
                if self.pos > #self.source then
                    error("Unexpected end of file")
                end
                if self.source:sub(self.pos, self.pos) == '{' then
                    -- add string so far to tokens
                    local value = self.source:sub(start, self.pos - 1)
                    table.insert(self.tokens, Token.new("STRING", value, self.line, self.column))
                    
                    start = self.pos
                    self:symbol()
                    while self.source:sub(self.pos, self.pos) ~= '}' do
                        if self.pos > #self.source then
                            error("Unexpected end of file")
                        end
                        self:advance()
                    end
                    
                    local value = self.source:sub(start + 1, self.pos - 1) -- This is the expression inside the curly braces
                    
                    --recursive call to tokenize the expression
                    local lexer = Lexer.new(value)
                    lexer:tokenize()
                    for _, token in lexer.tokens do
                        if token.type == 'EOF' then continue end
                        table.insert(self.tokens, token)
                    end

                    self:symbol()

                    start = self.pos
                end
                self:advance()
            end
            if start < self.pos then
                local value = self.source:sub(start, self.pos - 1)
                table.insert(self.tokens, Token.new("STRING", value, self.line, self.column))
            end
            self:advance()
        else
            error("Unexpected character: " .. char .. " at line " .. self.line .. " column " .. self.column)
        end
    end

    table.insert(self.tokens, Token.new("EOF", nil, self.line, self.column))
end

function Lexer:peekNextChar(offset)
    offset = offset or 1
    return self.source:sub(self.pos + offset, self.pos + offset)
end

function Lexer:identifier()
    local start = self.pos
    while self.source:sub(self.pos, self.pos):match("[%a_]") do
        self:advance()
    end
    local value = self.source:sub(start, self.pos - 1)

    local tokenType = "IDENTIFIER"
    for tokenName, val in Tokens.KEYWORD do
        if val == value then
            tokenType = "KEYWORD<" .. tokenName .. ">"
            break
        end
    end

    table.insert(self.tokens, Token.new(tokenType, value, self.line, self.column))
end

function Lexer:number()
    local base = 10 -- Default to decimal

    if self.source:sub(self.pos, self.pos + 1):lower() == "0x" then
        -- Hexadecimal
        base = 16
        self:advance(2) -- Skip the prefix
    elseif self.source:sub(self.pos, self.pos + 1):lower() == "0b" then
        -- Binary
        base = 2
        self:advance(2) -- Skip the prefix
    end
    local start = self.pos

    while self.source:sub(self.pos, self.pos):match("[%da-fA-F_]") do
        self:advance()
    end

    local value = self.source:sub(start, self.pos - 1):gsub("_", "") -- Remove underscores

    table.insert(self.tokens, Token.new("NUMBER", tonumber(value, base), self.line, self.column))
end

function Lexer:getCurrentChar()
    return self.source:sub(self.pos, self.pos)
end

function Lexer:symbol()
    local compoundSymbolsSorted = {}
    for tokenName, val in Tokens.SYMBOL do
        if #val > 1 then
            table.insert(compoundSymbolsSorted, {tokenName, val})
        end
    end
    table.sort(compoundSymbolsSorted, function(a, b)
        return #a[2] > #b[2]
    end)

    local function checkCompoundSymbol()
        for _, element in compoundSymbolsSorted do
            local symbol, value = unpack(element)
            local symbolLength = #value
            local lookaheadSymbol = self.source:sub(self.pos, self.pos + symbolLength - 1)
            if lookaheadSymbol == value then
                return symbol, symbolLength
            end
        end
        return nil, 0
    end

    local symbol, symbolLength = checkCompoundSymbol(compoundSymbolsSorted)
    if symbol then
        table.insert(self.tokens, Token.new("SYMBOL<" .. symbol .. ">", Tokens.SYMBOL[symbol], self.line, self.column))
        self:advance(symbolLength) -- Advance by the length of the compound symbol
        return
    end

    local value = self:getCurrentChar()
    -- Check if the symbol is a recognized symbol
    for tokenName, val in Tokens.SYMBOL do
        if val == value then
            table.insert(self.tokens, Token.new("SYMBOL<" .. tokenName .. ">", value, self.line, self.column))
            break
        end
    end
    self:advance()
end

function Lexer:string()
    local start = self.pos
    local quote = self.source:sub(self.pos, self.pos)
    self:advance()
    while self.source:sub(self.pos, self.pos) ~= quote do
        self:advance()
    end
    local value = self.source:sub(start + 1, self.pos - 1)
    table.insert(self.tokens, Token.new("STRING", value, self.line, self.column))

    if self.pos < #self.source then
        self:advance()
    end
end

return Lexer