function parse_kw(ps::ParseState, ::Type{Val{Tokens.QUOTE}})
    startbyte = ps.t.startbyte
    start_col = ps.t.startpos[2] + 4

    # Parsing
    kw = INSTANCE(ps)
    format_kw(ps)
    arg = EXPR{Block}(EXPR[], 0, Variable[], "")
    @catcherror ps startbyte @default ps parse_block(ps, arg, start_col)
    next(ps)

    # Construction
    ret = EXPR{Quote}(EXPR[kw, arg, INSTANCE(ps)], ps.nt.startbyte - startbyte, Variable[], "")
    
    return ret
end
