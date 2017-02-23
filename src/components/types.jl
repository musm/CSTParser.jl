# abstract
# actions
#   add to current_scope
# linting
#   `arg` declares a variable
#   Capitalized
#   doesn't conflict with existing names


function parse_kw(ps::ParseState, ::Type{Val{Tokens.ABSTRACT}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg = parse_expression(ps)
    
    scope = Scope{Tokens.ABSTRACT}(get_id(arg), [])
    # push!(ps.current_scope.args, scope)

    return EXPR(kw, Expression[arg], ps.nt.startbyte - start)
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.BITSTYPE}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg1 = @closer ps ws parse_expression(ps) 
    arg2 = parse_expression(ps)
    
    scope = Scope{Tokens.BITSTYPE}(get_id(arg2), [])
    push!(ps.current_scope.args, scope)

    return EXPR(kw, Expression[arg1, arg2], ps.nt.startbyte - start, [], scope)
end

function parse_kw(ps::ParseState, ::Type{Val{Tokens.TYPEALIAS}})
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    arg1 = @closer ps ws parse_expression(ps) 
    arg2 = parse_expression(ps)

    scope = Scope{Tokens.TYPEALIAS}(get_id(arg1), [])
    push!(ps.current_scope.args, scope)

    return EXPR(kw, Expression[arg1, arg2], ps.nt.startbyte - start, [], scope)
end

# for 0.6 the above two can be merged to a `parse_type` function as 
#  argument orderings will be the same.s

parse_kw(ps::ParseState, ::Type{Val{Tokens.TYPE}}) = parse_struct(ps, TRUE)
parse_kw(ps::ParseState, ::Type{Val{Tokens.IMMUTABLE}}) = parse_struct(ps, FALSE)

function parse_struct(ps::ParseState, mutable)
    start = ps.t.startbyte
    kw = INSTANCE(ps)
    sig = @closer ps block @closer ps ws parse_expression(ps)
    block = parse_block(ps)
    next(ps)

    T = mutable==TRUE ? Tokens.TYPE : Tokens.IMMUTABLE
    scope = Scope{T}(get_id(sig), [])
    for a in block.args
        if declares_function(a)
        else
            id = get_id(a)
            t = get_t(a)
            push!(scope.args, Variable(id, t))
        end
    end
    push!(ps.current_scope.args, scope)

    return EXPR(kw, Expression[mutable, sig, block], ps.nt.startbyte - start, INSTANCE[INSTANCE(ps)], scope)
end

function next(x::EXPR, s::Iterator{:abstract})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    end
end

function next(x::EXPR, s::Iterator{:bitstype})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    elseif s.i == 3
        return x.args[2], +s
    end
end

function next(x::EXPR, s::Iterator{:type})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[2], +s
    elseif s.i == 3
        return x.args[3], +s
    elseif s.i == 4
        return x.punctuation[1], +s
    end
end

function next(x::EXPR, s::Iterator{:typealias})
    if s.i == 1
        return x.head, +s
    elseif s.i == 2
        return x.args[1], +s
    elseif s.i == 3
        return x.args[2], +s
    end
end
