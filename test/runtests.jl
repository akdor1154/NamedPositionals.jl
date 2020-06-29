
using NamedPositionals
import Test: @testset, @test, @test_logs, @test_broken, @test_throws

@testset "Result tests" begin

    @testset "Optional KWargs" begin

        function testFn(a::Int, b::Int; c::Int=0)
            return a*b + c
        end

        @test (@np testFn(1,2;c=3)) == 5

        @test (@np testFn(1,2;)) == 2

        @test (@np testFn(a=1,b=2;)) == 2

    end

    @testset "expr arg evaluation" begin

        function testFn(a::Int, b::Int;)
            return a*b
        end

        function generate3()
            return 3
        end

        @test (@np testFn(a=1,b=generate3();)) == 3
    end

    @testset "No KWargs" begin

        function testFn(a::Int, b::Int;)
            return a*b
        end

        @test (@np testFn(1,2;)) == 2
        @test (@np testFn(a=1,b=2;)) == 2
    
    end

    @testset "Required kwargs" begin
        function testFn(a::Int, b::Int; c::Int)
            return a*b+c
        end

        @test (@np testFn(a=1,b=2;c=10)) == 12
    end


end

@testset "Warning tests" begin
    function testFn(a::Int, b::Int; c::Int=0)
        return a*b + c
    end

    @test_logs (:warn, Regex("`aa` should have been `a`")) @np testFn(aa=1,b=1;)
    @test_logs (:warn, Regex("`aa` should have been `a`")) @np testFn(aa=1,1;)
    @test_logs @np testFn(a=1,b=1;)
    @test_logs @np testFn(1,1;)
end

@testset "Semi usage tests" begin
    

    function testFn(a::Int, b::Int; c::Int=0)
        return a*b + c
    end

    # TODO: catch this better and give a proper exception
    # missing trailing semi
    @test_throws ErrorException (@np testFn(1,2)) == 5

    # TODO: catch this better and give a proper exception
    # TODO: don't log mismatch warning here
    # missing separator semi
    @test_throws MethodError (@np testFn(1,2,c=1)) == 2

end

@testset "Single arg evaluation" begin
    # given something like @np f(arg=b()),
    # make sure b() is only called once.

    function testFn(a::Int, b::Int; c::Int=0)
        return a*b + c
    end
    
    _count = 0
    function generate3AndCountCalls()
        _count = _count+1
        return 3
    end

    @test (@np testFn(a=1,b=generate3AndCountCalls();)) == 3
    @test _count == 1
end

@testset "Single param names check" begin
    # given repeated calls to the same @np site,
    # make sure the check is only done on the first time.
    # This is for performance reasons.

    _count = 0
    function testFn2(a::Int, b::Int; c::Int=0)
        _count = _count+1
        return a*b+c
    end

    function callTestFn2()
        @np testFn2(aa=1,b=1;)
    end

    @test_logs (:warn, Regex("`aa` should have been `a`")) callTestFn2()
    @test_logs callTestFn2()

end
