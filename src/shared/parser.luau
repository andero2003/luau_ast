local TokenModule = require(script.Parent:WaitForChild('lexer'):WaitForChild('Token'))
local Token = TokenModule.Token
local Tokens = TokenModule.Tokens

local Parser = {}
Parser.__index = Parser

function Parser.new(tokens)
    local self = setmetatable({}, Parser)
    self.tokens = tokens
    self.pos = 1
    return self
end

function Parser:advance(by)
    by = by or 1
    self.pos += by
    if self.pos > #self.tokens then
        error("Unexpected end of file")
    end
end

function Parser:parseBlock()
    local statements = {}
    while self.pos < #self.tokens do
        local statement = self:parseStatement()
        if statement then
            table.insert(statements, statement)
        else
            break
        end
        if self:match("SYMBOL<SEMICOLON>") then
            self:advance()
        end
    end
    return statements
end

function Parser:match(type)
    local token = self.tokens[self.pos]
    if token.type == type then
        self:advance()
        return token
    end
end

function Parser:peek()
    return self.tokens[self.pos + 1]
end

function Parser:parseStatement()
    if self:match("KEYWORD<FUNCTION>") then
       return self:parseFunctionDeclaration()
    end
    if self:match("KEYWORD<LOCAL>") then
        return self:parseLocalDeclaration()
    end
    if self:match("KEYWORD<EXPORT>") then
        return self:parseExportStatement()
    end
    if self:match("KEYWORD<TYPE>") then
        return self:parseTypeDeclaration()
    end
    if self:match("KEYWORD<IF>") then
        return self:parseIfStatement()
    end
    if self:match("KEYWORD<WHILE>") then
        return self:parseWhileStatement()
    end
    if self:match("KEYWORD<REPEAT>") then
        return self:parseRepeatStatement()
    end
    if self:match("KEYWORD<FOR>") then
        return self:parseForStatement()
    end
    if self:match("KEYWORD<DO>") then
        return self:parseDoStatement()
    end
    if self:match("IDENTIFIER") then
        self:advance(-1)
        return self:parseAssignmentOrCallStatement()
    end
    local lastStatement = self:parseLastStatement()
    if lastStatement then
        return lastStatement
    end
    if self:match('EOF') then
        return
    end
    return
end

function Parser:parseDoStatement()
    local block = self:parseBlock()
    self:match("KEYWORD<END>")
    return { type = "DO_STATEMENT", block = block }
end

function Parser:parseWhileStatement()
    local condition = self:parseExpression()
    self:match("KEYWORD<DO>")
    local block = self:parseBlock()
    self:match("KEYWORD<END>")
    return { type = "WHILE_STATEMENT", condition = condition, block = block }
end

-- 'for' binding '=' exp ',' exp [',' exp] 'do' block 'end' |
-- 'for' bindinglist 'in' explist 'do' block 'end' |
function Parser:parseForStatement()
    local binding = self:parseBinding()
    if self:match("SYMBOL<ASSIGN>") then
        local start = self:parseExpression()
        self:match("SYMBOL<COMMA>")
        local endValue = self:parseExpression()
        local step
        if self:match("SYMBOL<COMMA>") then
            step = self:parseExpression()
        end
        self:match("KEYWORD<DO>")
        local block = self:parseBlock()
        self:match("KEYWORD<END>")
        return { type = "NUMERIC_FOR_STATEMENT", binding = binding, start = start, endValue = endValue, step = step, block = block }
    end    
    --Check for bindinglist
    local bindingList = { binding }
    while self:match("SYMBOL<COMMA>") do
        table.insert(bindingList, self:parseBinding())
    end
    self:match("KEYWORD<IN>")
    local expression = self:parseExpression()
    local expressions = { expression }
    while self:match("SYMBOL<COMMA>") do
        table.insert(expressions, self:parseExpression())
    end
    self:match("KEYWORD<DO>")
    local block = self:parseBlock()
    self:match("KEYWORD<END>")
    return { type = "GENERIC_FOR_STATEMENT", binding = binding, expressions = expressions, block = block }
end

function Parser:parseAssignmentOrCallStatement()
    --TODO check for function call
    local pos = self.pos
    local var = self:parseVariable()
    if var.type == "METHOD_CALL" or self.tokens[self.pos].type == 'SYMBOL<LPAREN>' then
        local args = self:parseFunctionArgs()
        return { type = "FUNCTION_CALL", prefix = var, args = args }
    end
    self.pos = pos
    return self:parseAssignmentStatement()
end

function Parser:parseAssignmentStatement()
    print('parsing assignment statement')
    local variable = self:parseVariable()
    print('parsed variable', variable)
    if self:matchCompoundOperator() then
        local operator = self:getPreviousToken()
        local expression = self:parseExpression()
        return { type = "COMPOUND_ASSIGNMENT_STATEMENT", variable = variable, operator = operator, expression = expression }
    end
    local variables = { variable }
    while self:match("SYMBOL<COMMA>") do
        table.insert(variables, self:parseVariable())
    end
    self:match("SYMBOL<ASSIGN>")
    local exp = self:parseExpression()
    print('parsed expression', exp)
    local expressions = { exp }
    while self:match("SYMBOL<COMMA>") do
        table.insert(expressions, self:parseExpression())
    end
    return { type = "ASSIGNMENT_STATEMENT", variables = variables, expressions = expressions }
end

function Parser:parseVariableList()
    local variables = { self:parseVariable() }
    while self:match("SYMBOL<COMMA>") do
        table.insert(variables, self:parseVariable())
    end
    return variables
end

function Parser:parseRepeatStatement()
    local block = self:parseBlock()
    self:match("KEYWORD<UNTIL>")
    local condition = self:parseExpression()
    return { type = "REPEAT_STATEMENT", block = block, condition = condition }
end

function Parser:parseIfStatement()
    local condition = self:parseExpression()
    self:match("KEYWORD<THEN>")
    local block = self:parseBlock()
    local elseIfs
    while self:match("KEYWORD<ELSEIF>") do
        local condition = self:parseExpression()
        self:match("KEYWORD<THEN>")
        local block = self:parseBlock()
        elseIfs = elseIfs or {}
        table.insert(elseIfs, { condition = condition, block = block })
    end
    local elseBlock
    if self:match("KEYWORD<ELSE>") then
        elseBlock = self:parseBlock()
    end
    self:match("KEYWORD<END>")
    return { type = "IF_STATEMENT", condition = condition, block = block, elseIfs = elseIfs, elseBlock = elseBlock }
end

function Parser:parseFunctionDeclaration()
    local name = self:parseFunctionName()
    local body = self:parseFunctionBody()
    return { type = "FUNCTION_DECLARATION", name = name, body = body }
end

function Parser:parseLastStatement()
    if self:match("KEYWORD<RETURN>") then
        return self:parseReturnStatement()
    end
    if self:match("KEYWORD<BREAK>") then
        return self:parseBreakStatement()
    end
    if self:match("KEYWORD<CONTINUE>") then
        return self:parseContinueStatement()
    end
end

function Parser:parseReturnStatement()
    local expressions = { self:parseExpression() }
    while self:match("SYMBOL<COMMA>") do
        table.insert(expressions, self:parseExpression())
    end
    return { type = "RETURN_STATEMENT", expressions = expressions }
end

function Parser:parseLocalDeclaration()
    local name = self:match("IDENTIFIER")
    if name then
        return self:parseLocalVariableDeclarationOrBindingList(name)    
    end
    if self:match("KEYWORD<FUNCTION>") then
        return self:parseLocalFunctionDeclaration(name)
    end
end

function Parser:parseLocalFunctionDeclaration(name)
    local body = self:parseFunctionBody()
    return { type = "LOCAL_FUNCTION_DECLARATION", name = name, body = body }
end

function Parser:parseBinding()
    local name = self:match("IDENTIFIER")
    if self:match("SYMBOL<COLON>") then
        local type = self:parseType()
        return {type = "TYPED_BINDING", name = name, valueType = type}
    end
    return {type = "BINDING", name = name}
end

function Parser:parseBindingList()
    local bindings = { self:parseBinding() }
    while self:match("SYMBOL<COMMA>") do
        table.insert(bindings, self:parseBinding())
    end
    return bindings
end

function Parser:parseLocalVariableDeclarationOrBindingList(name)
    if self:match("SYMBOL<ASSIGN>") then
        print("local variable declaration")
        local value = self:parseExpression()
        return { type = "LOCAL_VARIABLE_DECLARATION", name = name.value, value = value }
    end
    local names = { name.value }
    while self:match("SYMBOL<COMMA>") do
        local name = self:match("IDENTIFIER")
        if name then
            table.insert(names, name.value)
        end
    end
    if self:match("SYMBOL<ASSIGN>") then
        local values = { }
        repeat
            local exp = self:parseExpression()
            print('parsed expression', exp)
            table.insert(values, exp)
        until not self:match("SYMBOL<COMMA>")
        return { type = "LOCAL_VARIABLE_BINDING_LIST", names = names, values = values }
    end
    return { type = "LOCAL_VARIABLE_DECLARATION", names = names }
end

function Parser:getPreviousToken()
    return self.tokens[self.pos - 1]
end

function Parser:parseSimpleExpression()
    print('Simple expression')
    if self:match("NUMBER") then
        return { type = "NUM_LITERAL", value = self:getPreviousToken().value }
    end
    if self:match("STRING") then
        return { type = "STRING_LITERAL", value = self:getPreviousToken().value }
    end
    if self:match("KEYWORD<TRUE>") then
        return { type = "BOOLEAN_LITERAL", value = true }
    end
    if self:match("KEYWORD<FALSE>") then
        return { type = "BOOLEAN_LITERAL", value = false }
    end
    if self:match("KEYWORD<NIL>") then
        return { type = "NIL_LITERAL" }
    end
    if self:match("SYMBOL<SPREAD") then
        return { type = "VAR_ARGS" }
    end
    if self:match("SYMBOL<LBRACE>") then
        print('parsing table constructor')
        return self:parseTableConstructor()
    end
    if self:match("KEYWORD<FUNCTION>") then
        return self:parseFunctionExpression()
    end
    if self:match("KEYWORD<IF") then
        return self:parseIfElseExpression()
    end
    if self:match("SYMBOL<LPAREN>") then
        local expression = self:parseExpression()
        self:match("SYMBOL<RPAREN>")
        return expression
    end
    --TODO string interpolation
    return self:parsePrefixExpression()
end

function Parser:parseVariable()
    local name = self:match("IDENTIFIER")
    if name then
        local next = self.tokens[self.pos]
        if not (next.type == "SYMBOL<DOT>" 
        or next.type == "SYMBOL<COLON>" 
        or next.type == "SYMBOL<LBRACKET>"
        or next.type == "SYMBOL<COMMA>"
        or next.type == "SYMBOL<LPAREN>")
        then
            return { type = "SIMPLE_VARIABLE", name = name.value }
        end

        while self.tokens[self.pos].type == 'SYMBOL<DOT>' or self.tokens[self.pos].type == 'SYMBOL<LBRACKET>' do
            if self:match("SYMBOL<DOT>") then
                local var = self:match("IDENTIFIER")
                name = { type = "FIELD_VARIABLE", prefix = name, field = var.value }
            end
            if self:match("SYMBOL<LBRACKET>") then
                local expression = self:parseExpression()
                self:match("SYMBOL<RBRACKET>")
                name = { type = "INDEX_VARIABLE", prefix = name, expression = expression }
            end
        end
        if self:match("SYMBOL<COLON>") then
            local method = self:match("IDENTIFIER")
            if method then
                return { type = "METHOD_CALL", prefix = name, method = method.value }
            end
        end
        return name
    end
end

function Parser:parsePrefixExpression()
    if self:match("SYMBOL<LPAREN>") then
        local expression = self:parseExpression()
        self:match("SYMBOL<RPAREN>")
        return expression
    end
   
    local var = self:parseVariable()
    if var then
        if var.type == "METHOD_CALL" or self.tokens[self.pos].type == 'SYMBOL<LPAREN>' then
            local args = self:parseFunctionArgs()
            return { type = "FUNCTION_CALL", prefix = var, args = args }
        end
        return var
    end
end

function Parser:parseFunctionName()
    local name = self:match("IDENTIFIER")
    if name then
        local fields = {}
        while self:match("SYMBOL<DOT>") do
            local field = self:match("IDENTIFIER")
            if field then
                table.insert(fields, field.value)
            end
        end
        if self:match("SYMBOL<COLON>") then
            local method = self:match("IDENTIFIER")
            if method then
                table.insert(fields, method.value)
            end
        end
        return { name = name.value, fields = fields }
    end   
end

function Parser:parseFunctionBody()
    local generics, returnType
    if self:match("SYMBOL<LT>") then
        generics = {} --self:parseGenericTypeList()
    end
    self:match("SYMBOL<LPAREN>")
    local parameters = {} -- self:parseParameterList()
    self:match("SYMBOL<RPAREN>")
    if self:match("SYMBOL<COLON>") then
        returnType = {} -- self:parseReturnType()
    end
    local block = self:parseBlock()
    print('parsed function body', self.tokens[self.pos])
    self:match("KEYWORD<END>")
    return { type = "FUNCTION_BODY", parameters = parameters, block = block, generics = generics, returnType = returnType }
end

function Parser:parseIfElseExpression()
    local condition = self:parseExpression()
    self:match("KEYWORD<THEN>")
    local trueExpression = self:parseExpression()
    local elseIfs = {}
    while self:match("KEYWORD<ELSEIF>") do
        local condition = self:parseExpression()
        self:match("KEYWORD<THEN>")
        local expression = self:parseExpression()
        table.insert(elseIfs, { condition = condition, expression = expression })
    end
    local elseExpression
    if self:match("KEYWORD<ELSE>") then
        elseExpression = self:parseExpression()
    end
    return { type = "IF_ELSE_EXPRESSION", condition = condition, trueExpression = trueExpression, elseIfs = elseIfs, elseExpression = elseExpression }
end

function Parser:parseTableConstructor()
    local fields = {}
    while not self:match("SYMBOL<RBRACE>") do
        print('parsing field')
        local field = self:parseField()
        table.insert(fields, field)
        if not self:match("SYMBOL<COMMA>") or not self:match("SYMBOL<SEMICOLON>") then
            break
        end
    end
    return { type = "TABLE_CONSTRUCTOR", fields = fields }
end

function Parser:parseField()
    if self:match("SYMBOL<LBRACKET>") then
        local key = self:parseExpression()
        self:match("SYMBOL<RBRACKET>")
        self:match("SYMBOL<ASSIGN>")
        local value = self:parseExpression()
        return { type = "KEY_VALUE_FIELD", key = key, value = value }
    end
    if self:match("IDENTIFIER") then
        local key = self:getPreviousToken()
        if self:match("SYMBOL<ASSIGN>") then
            local value = self:parseExpression()
            return { type = "KEY_VALUE_FIELD", key = key, value = value }
        end
        return { type = "KEY_FIELD", key = key }
    end
end

function Parser:matchCompoundOperator()
    return self:match("SYMBOL<ADD_ASSIGN>") 
    or self:match("SYMBOL<SUB_ASSIGN>") 
    or self:match("SYMBOL<MUL_ASSIGN>")
    or self:match("SYMBOL<DIV_ASSIGN>")
    or self:match("SYMBOL<MOD_ASSIGN>")
    or self:match("SYMBOL<POW_ASSIGN>")
    or self:match("SYMBOL<CONCAT_ASSIGN>")
end

function Parser:matchBinaryOperator()
    return self:match("SYMBOL<OR>")
    or self:match("SYMBOL<AND>")
    or self:match("SYMBOL<PLUS>")
    or self:match("SYMBOL<MINUS>")
    or self:match("SYMBOL<STAR>")
    or self:match("SYMBOL<SLASH>")
    or self:match("SYMBOL<MOD>")
    or self:match("SYMBOL<CARET>")
    or self:match("SYMBOL<CONCAT>")
    or self:match("SYMBOL<EQ>")
    or self:match("SYMBOL<NEQ>")
    or self:match("SYMBOL<LT>")
    or self:match("SYMBOL<GT>")
    or self:match("SYMBOL<LTE>")
    or self:match("SYMBOL<GTE>")
end

function Parser:matchUnaryOperator()
    return self:match("SYMBOL<MINUS>")
    or self:match("SYMBOL<NOT>")
    or self:match("SYMBOL<HASH>")
end

function Parser:parseExpression()
    --check unary operators
    if self:matchUnaryOperator() then
        local unaryOperator = self:getPreviousToken()
        local expression = self:parseExpression()
        if self:matchBinaryOperator() then
            local binaryOperator = self:getPreviousToken()
            local rightExpression = self:parseExpression()
            return { type = "BINARY_EXPRESSION", operator = binaryOperator, left = { type = "UNARY_EXPRESSION", operator = unaryOperator, expression = expression }, right = rightExpression }
        end
        return { type = "UNARY_EXPRESSION", operator = unaryOperator, expression = expression }
    end
    local exp = self:parseAsExpression()
    if self:matchBinaryOperator() then
        local operator = self:getPreviousToken()
        local rightExpression = self:parseExpression()
        return { type = "BINARY_EXPRESSION", operator = operator, left = exp, right = rightExpression }
    end
    return exp
end

function Parser:parseAsExpression()
    local expression = self:parseSimpleExpression()
    if self:match("SYMBOL<CAST>") then
        local type = self:parseType()
        return {type = "TYPED_EXPRESSION", expression = expression, valueType = type}
    end
    return expression
end

function Parser:parseFunctionArgs()
    if self:match("SYMBOL<LPAREN>") then
        local expressions = {}
        if not self:match("SYMBOL<RPAREN>") then
            table.insert(expressions, self:parseExpression())
            while self:match("SYMBOL<COMMA>") do
                table.insert(expressions, self:parseExpression())
            end
            self:match("SYMBOL<RPAREN>")
        end
        return expressions
    end
    if self:match("SYMBOL<LBRACE>") then
        return {self:parseTableConstructor()}
    end
    if self:match("SYMBOL<STRING>") then
        return {{type = "STRING_LITERAL", value = self:getPreviousToken().value}}
    end
end

return Parser
