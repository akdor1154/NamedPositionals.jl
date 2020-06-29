# NamedPositionals.jl

**Alpha software. There are still a couple of edge cases.**

Allows you to call Julia functions with named positional parameters:

```jl

function train_model(model, max_iters, k_weight, j_weight) begin
    ...
end

@np train_model(myModel, max_iters=100, k_weight=0.4, j_weight=0.2;)

```

## Rationale

This feature is in many languages that I enjoy and feel are well-designed (e.g. Python, Swift, C#), and I miss it when coding Julia. I feel that there are certain situations where this makes my code far more easy to read, which is something I think aligns well with Julia's goals.

Obviously you can go overboard with this; personally I would advise sprinkling it in your code when you find yourself refering to the docs/your IDE for "what the hell do these five floats at the end of this SomeLibrary.fn do again?"

## Usage

Just prefix your call with `@np`, and remember to add a trailing semicolon.

```jl
using NamedPositionals

function myFunc(a::Int, b::Int, mult_by=3; c::Int=0) begin
    return a+b*mult_by
end

@np myFunc(a=2, b=2, mult_by=3;)
```

Parameter names are optional, you don't need to provide all (or any) of them:

```jl
@np myFunc(2, 2, mult_by=3;)
```

If you get your argument names wrong, you'll get a warning printed:

```jl
@np myFunc(um=2, b=2)
┌ Warning: In your call testFn(um = 2, b = 1; ): `um` should have been `a`
└ @ Main your_file.jl:42
```

## Non-goals

- Allowing the caller to re-order arguments: nope. Argument order is hugely important in Julia, it shouldn't be hidden or abstracted. Hiding this is potentially a huge footgun, and would yield major WTFs from anybody who ever reads your code.

- Allowing the caller to omit the trailing semi / separating semi between pos and kwargs: nope. This is required for unambiguous call parsing. Requiring it also makes the separation between positional and kwargs visible, which IMO is again useful for code readability, given the distinction between these is so important to be able to use Julia without head-scratching.

## Known issues

- None, yet. Can you find some?
