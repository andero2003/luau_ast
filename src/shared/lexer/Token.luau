type TokenType = "SYMBOL" | "KEYWORD" | "NUMBER" | "STRING" | "IDENTIFIER" | "EOF"

return {
    Token = {
        __index = {
            new = function(self, type: TokenType, value: any, line: number, column: number)
                return setmetatable({
                    type = type,
                    value = value,
                    line = line,
                    column = column
                }, self)
            end,
            __tostring = function(self)
                return string.format("Token<%s>(%s)", self.type, self.value or '')
            end
        }
    },
    Tokens = {
        KEYWORD = {
            DO = "do",
            END = "end",
            WHILE = "while",
            REPEAT = "repeat",
            UNTIL = "until",
            IF = "if",
            THEN = "then",
            ELSEIF = "elseif",
            ELSE = "else",
            FOR = "for",
            IN = "in",
            FUNCTION = "function",
            LOCAL = "local",
            RETURN = "return",
            BREAK = "break",
            CONTINUE = "continue",
            EXPORT = "export",
            TYPE = "type",
            TRUE = "true",
            FALSE = "false",
            NIL = "nil",
        },

        SYMBOL = {
            PLUS = "+",
            MINUS = "-",
            STAR = "*",
            SLASH = "/",
            MOD = "%",
            CARET = "^",
            HASH = "#",
            EQ = "==",
            NEQ = "~=",
            LT = "<",
            GT = ">",
            LTE = "<=",
            GTE = ">=",
            ASSIGN = "=",
            LPAREN = "(",
            RPAREN = ")",
            LBRACKET = "[",
            RBRACKET = "]",
            LBRACE = "{",
            RBRACE = "}",
            SEMICOLON = ";",
            COLON = ":",
            COMMA = ",",
            DOT = ".",
            DOTDOT = "..",
            DOTDOTDOT = "...",
            AND = "and",
            OR = "or",
            NOT = "not",
            CONCAT = "..",
        }
    }
}