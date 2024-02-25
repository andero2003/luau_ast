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

function Lexer:advance()
    self.pos += 1
    if self.pos > #self.source then
        error("Unexpected end of file")
    end
end

function Lexer:tokenize()
    while self.pos < #self.source do
        local char = self.source:sub(self.pos, self.pos)
        if char == " " then
            self:advance()
        elseif char == "\n" then
            self.line += 1
            self.column = 1
            self:advance()
        elseif char:match("%a") then
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
            self:symbol()           
        elseif char == "\"" or char == "\'" then
            self:string()
            -- TODO Add interpolation and multi-line strings
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
    while self.source:sub(self.pos, self.pos):match("%a") do
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
    local start = self.pos
    while self.source:sub(self.pos, self.pos):match("%d") do
        self:advance()
    end
    local value = self.source:sub(start, self.pos - 1)

    table.insert(self.tokens, Token.new("NUMBER", tonumber(value), self.line, self.column))
end

function Lexer:symbol()
    local start = self.pos
    while self.source:sub(self.pos, self.pos):match("[%+%-%*/%%^#=<>~%(%){}%[%];:,%.]") do
        self:advance()
    end
    local value = self.source:sub(start, self.pos - 1)

    -- Check if the symbol is a recognized symbol
    for tokenName, val in Tokens.SYMBOL do
        if val == value then
            table.insert(self.tokens, Token.new("SYMBOL<" .. tokenName .. ">", value, self.line, self.column))
            return
        end
    end
end

function Lexer:string()
    local start = self.pos
    local quote = self.source:sub(self.pos, self.pos)
    self:advance()
    while self.source:sub(self.pos, self.pos) ~= quote do
        self:advance()
    end
    local value = self.source:sub(start + 1, self.pos - 1)
    self:advance()

    table.insert(self.tokens, Token.new("STRING", value, self.line, self.column))
end

return Lexer