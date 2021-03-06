"""
    parse_string(ps)

When trying to make an `INSTANCE` from a string token we must check for 
interpolating operators.
"""
function parse_string(ps::ParseState, prefixed = false)
    startbyte = ps.t.startbyte
    
    span = ps.nt.startbyte - ps.t.startbyte
    istrip = ps.t.kind == Tokens.TRIPLE_STRING
    
    if ps.errored
        return EXPR{ERROR}([], 0, [], ps.t.val)
    end

    if istrip
        lit = unindent_triple_string(ps)
    else
        lit = EXPR{LITERAL{ps.t.kind}}(Expr[], span, Variable[], ps.t.val[2:end - 1])   
    end

    # there are interpolations in the string
    if prefixed != false
        if prefixed.val == :r
            lit.val = replace(lit.val, "\\\"", "\"")
        end
        return lit
    elseif ismatch(r"(?<!\\)\$", lit.val) # _has_interp(lit.val)
        io = IOBuffer(lit.val)
        ret = EXPR{StringH}(EXPR[], lit.span, Variable[], "")
        lc = ' '
        while !eof(io)
            io2 = IOBuffer()
            # conseq_slash = 0
            while !eof(io)
                c = read(io, Char)
                write(io2, c)
                if c == '$' && lc != '\\' # && iseven(conseq_slash) 
                    break
                end
                lc = c
                # if c == '\\'
                #     conseq_slash +=1
                # else
                #     conseq_slash = 0
                # end
            end
            str1 = String(take!(io2))

            if length(str1) > 0 && last(str1) === '$' && (length(str1) == 1 || str1[chr2ind(str1, length(str1) - 1)] != '\\')
                lit2 = EXPR{LITERAL{Tokens.STRING}}(EXPR[], endof(str1) - 1, Variable[], unescape_string(str1[1:end - 1]))
                if !isempty(lit2.val)
                    push!(ret.args, lit2)
                end
                if peekchar(io) == '('
                    ps1 = ParseState(lit.val[io.ptr + 1:end])
                    leading_ws_span = 0
                    if ps1.nt.kind == Tokens.WHITESPACE
                        next(ps1)
                        leading_ws_span = ps1.nt.startbyte - ps1.t.startbyte
                    end
                    @catcherror ps startbyte interp = @closer ps1 paren parse_expression(ps1)
                    push!(ret.args, interp)
                    skip(io, interp.span + 2 + leading_ws_span)
                else
                    ps1 = ParseState(lit.val[io.ptr:end])
                    next(ps1)
                    interp = INSTANCE(ps1)
                    push!(ret.args, interp)
                    
                    skip(io, interp.span - length(ps1.ws.val))
                end
            else
                push!(ret.args, EXPR{LITERAL{Tokens.STRING}}(EXPR[], sizeof(str1) - 1, Variable[], unescape_string(str1)))
            end
        end
        return ret
    else
        lit.val = unescape_string(lit.val)
        return lit
    end
    ret.span = span
    return ret
end

function _has_interp(str)
    i = 1
    conseq_slash = 0
    while i < endof(str)
        if str[i] == '$' && iseven(conseq_slash)
            return true
        elseif str[i] == '\\'
            conseq_slash += 1
        else 
            conseq_slash = 0
        end
        i = nextind(str, i)
    end
    return false
end

function unindent_triple_string(ps::ParseState)
    indent = -1
    leading_newline = startswith(ps.t.val, "\"\"\"\n")
    val = leading_newline ? ps.t.val[5:end - 3] : ps.t.val[4:end - 3]
    io = IOBuffer(val)
    while !eof(io)
        c = readuntil(io, '\n')
        eof(io) && break
        peekchar(io) == '\n' && skip(io, 1)
        cnt = 0
        while iswhitespace(peekchar(io)) && peekchar(io) != '\n'
            read(io, Char)
            cnt += 1
        end
        indent = indent == -1 ? cnt : min(indent, cnt)
    end
    if indent > -1
        val = Base.unindent(val, indent)
        # if !leading_newline
        #     val = string(" "^indent, val)
        # end
    end
    lit = EXPR{LITERAL{ps.t.kind}}(EXPR[], ps.nt.startbyte - ps.t.startbyte - ps.ndot, Variable[], val)
end
