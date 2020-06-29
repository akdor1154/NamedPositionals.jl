module NamedPositionals

import Base.Meta
import Logging

const NamedPositionalArgument = Union{Tuple{Nothing, <:Any}, Tuple{Symbol, <:Any}}

struct NamedPositionalCall
    fn
    args::Array{NamedPositionalArgument}
end

function findNamedPositionalMismatches(userCall::NamedPositionalCall) :: Array{Tuple{Int, Symbol, Symbol}}
    
    local passedNames = [k for (k,v) in userCall.args]
    local argTypes = [typeof(v) for (k, v) in userCall.args]

    local methodCodes = code_lowered(userCall.fn, argTypes)
    local possibleMethods = methods(userCall.fn, argTypes)

    if length(methodCodes) < 1 || length(possibleMethods) < 1
        error("No method found for $(userCall.fn), $argTypes !")
    end

    local resolvedMethodCode::Base.CodeInfo = methodCodes[1]
    local resolvedMethod = first(possibleMethods)
    local methodParamNames = resolvedMethodCode.slotnames[2:end]

    if length(methodParamNames) != length(passedNames)
        error("method param names $(methodParamNames) is a diff length from $(passedNames). This should never happen.")
    end

    local mismatches = (
        (i, passed, wanted)
        for (i, (passed, wanted)) in enumerate(zip(passedNames, methodParamNames))
        if passed !== nothing && passed != wanted
    ) |> collect
end

macro np(callExpr::Expr)
    @assert callExpr.head == :call
    @assert callExpr.args[1] isa Symbol # disallow f()() for now!

    namedParamKVs::Array{NamedPositionalArgument} = [
        begin
            if p isa Expr
                @assert p.head == :kw
                (k, v) = p.args
                (k, v)
            else
                v = p
                (nothing, p)
            end :: Union{Tuple{Symbol, <:Any}, Tuple{Nothing, <:Any}}
        end
        for p in callExpr.args[3:end]
    ]

    unnamedExpr = Expr(
        :call,
        callExpr.args[1],
        callExpr.args[2],
        [v for (k,v) in namedParamKVs]...
    )
    fnName = callExpr.args[1]
    callKWargs = callExpr.args[2]

    # we want to make sure each macro only gets its args checked once,
    # for performance.
    argsCheckedVarSym = gensym("NamedParameters_argsChecked")
    __module__.eval( :($argsCheckedVarSym = false) ) 
    argsCheckedVar = esc(argsCheckedVarSym)

    # unsure why this is needed, see
    # https://stackoverflow.com/questions/57925973/implicit-source-argument-to-julia-macro-cant-be-used-within-quote-block
    local sourceLine::Int = __source__.line
    local sourceFile::String = string(__source__.file)

    return quote
        global $argsCheckedVar
        if $argsCheckedVar == false

            # local evaluatedArgsVales = [
            #     $([
            #         let 
            #             evaluated =
            #                 if v isa Symbol || v isa Expr
            #                     # user passed a variable or expr
            #                     println("got expr")
            #                     v
            #                 elseif v isa QuoteNode
            #                     # user actually passed a symbol
            #                     esc(v.value)
            #                 else
            #                     v
            #                 end;
            #             evaluated
            #         end
            #         for (k,v) in namedParamKVs
            #     ]...)]
            local kws = [$((QuoteNode(k) for (k,v) in namedParamKVs)...)]
            local argValues = [$((esc(v) for (k,v) in namedParamKVs)...)]
            local evaluatedArgs :: Array{NamedPositionalArgument} = [
                kv for kv in zip(kws,argValues)
            ]

            local fn = $(esc(fnName))
            local userCall = NamedPositionalCall(fn, evaluatedArgs)
            local mismatches = findNamedPositionalMismatches(userCall)

            if length(mismatches) > 0
                local userCall = $(string(callExpr))
                local errorStrs = ["`$passed` should have been `$wanted`" for (i, passed, wanted) in mismatches]
                Logging.@warn "In your call $userCall: $(join(errorStrs, ", "))" _file=$sourceFile _line=$sourceLine
            end

            $argsCheckedVar = true

            # construct a new arg call that uses our pre-evaluated
            # arguments from above (to avoid evaluating args twice)
            local preEvalArgsCall = $(Expr(
                :call,
                (esc(fnName)),
                (esc(callKWargs)),
                :((v for (k,v) in evaluatedArgs)...)
            ))

        else
            $(esc(unnamedExpr))
        end
    end
end

export @np

end # module
