using ChainRulesCore, Test
using LinearAlgebra, SparseArrays, Random

@testset "projection" begin

    @testset "Base: numbers" begin
        # real / complex
        @test ProjectTo(1.0)(2.0 + 3im) === 2.0
        @test ProjectTo(1.0 + 2.0im)(3.0) === 3.0 + 0.0im

        # storage
        @test ProjectTo(1)(pi) === Float64(pi)
        @test ProjectTo(1f0)(1/2) === Float32(1/2)
        @test ProjectTo(1f0+2im)(3) === Float32(3) + 0im
        @test ProjectTo(big(1.0))(2) isa BigFloat
    end

    @testset "Base: arrays" begin
        pvec3 = ProjectTo([1,2,3])
        @test pvec3(1.0:3.0) === 1.0:3.0
        @test pvec3(1:3) == 1.0:3.0  # would prefer ===, map(Float64, dx) would do that, not important
        @test pvec3([1,2,3+4im]) == 1:3
        @test eltype(pvec3([1,2,3f0])) === Float64

        # reshape
        @test pvec3(reshape([1,2,3],3,1)) isa Vector
        @test_throws DimensionMismatch pvec3(reshape([1,2,3],1,3))
        @test_throws DimensionMismatch pvec3([1,2,3,4])

        pmat = ProjectTo(rand(2,2) .+ im)
        @test pmat([1 2; 3 4.0 + 5im]') isa Adjoint     # pass-through
        @test pmat([1 2; 3 4]') isa Matrix{ComplexF64}  # broadcast type change

        # arrays of arrays
        pvecvec = ProjectTo([[1,2], [3,4,5]])
        @test pvecvec([1:2, 3:5])[1] == 1:2
        @test pvecvec([[1,2+3im], [4+5im,6,7]])[2] == [4,6,7]
        @test pvecvec(hcat([1:2, hcat(3:5)]))[2] isa Vector  # reshape inner & outer

        # arrays of unknown things
        @test ProjectTo([:x, :y])(1:2) === 1:2  # no element handling,
        @test ProjectTo([:x, :y])(reshape(1:2,2,1,1)) == 1:2  # but still reshapes container
        @test ProjectTo(Any[1, 2])(1:2) === 1:2  # goes by eltype, hence ignores contents.
    end

    @testset "Base: zero-arrays & Ref" begin
        pzed = ProjectTo(fill(1.0))
        @test pzed(fill(3.14)) == fill(3.14)  # easy
        @test pzed(fill(3)) == fill(3.0)      # broadcast type change must not produce number
        @test pzed(hcat(3.14)) == fill(3.14)  # reshape of length-1 array
        @test pzed(3.14 + im) == fill(3.14)   # re-wrap of a scalar number

        pref = ProjectTo(Ref(2.0))
        @test pref(Ref(3+im))[] === 3.0
        @test pref(4)[] === 4.0
        @test pref(Ref{Any}(5.0)) isa Base.RefValue{Float64}
    end

    @testset "LinearAlgebra: $adj" for adj in [transpose, adjoint]
        # adjoint vectors
        padj = ProjectTo(adj([1,2,3]))
        adjT = typeof(adj([1,2,3.0]))
        @test padj(transpose(1:3)) isa adjT
        @test padj([4 5 6+7im]) isa adjT

        @test_throws DimensionMismatch padj([1,2,3])
        @test_throws DimensionMismatch padj([1 2 3]')
        @test_throws DimensionMismatch padj([1 2 3 4])

        padj_complex = ProjectTo(adj([1,2,3+4im]))
        @test padj_complex([4 5 6+7im]) == [4 5 6+7im]
        @test padj_complex(transpose([4, 5, 6+7im])) == [4 5 6+7im]
        @test padj_complex(adjoint([4, 5, 6+7im])) == [4 5 6-7im]
    end

    @testset "LinearAlgebra: structured matrices" begin
        @test_broken false
    end

    @testset "SparseArrays" begin
        # vector
        v = sprand(30, 0.3)
        pv = ProjectTo(v)

        @test pv(v) == v
        @test pv(v .* (1+im)) ≈ v
        o = pv(ones(Int, 30, 1))
        @test nnz(o) == nnz(v)

        # matrix
        m = sprand(10, 10, 0.3)
        pm = ProjectTo(m)

        @test pm(m) == m
        @test pm(m .* (1+im)) ≈ m
        om = pm(ones(Int, 10, 10))
        @test nnz(om) == nnz(m)

        @test_throws DimensionMismatch pv(ones(Int, 1, 30))
        @test_throws DimensionMismatch pm(ones(Int, 5, 20))
    end

    @testset "AbstractZero" begin
        pz = ProjectTo(ZeroTangent())
        pz(0) == ZeroTangent()

        pb = ProjectTo(true) # Bool is categorical
        @test pb(2) === ZeroTangent()

        # all projectors preserve Zero:
        ProjectTo(pi)(ZeroTangent()) === ZeroTangent()
        pv = ProjectTo(sprand(30, 0.3))
        pv(ZeroTangent()) === ZeroTangent()
    end

    @testset "Thunk" begin
        th = @thunk 1+2+3
        pth = ProjectTo(4+5im)(th)
        @test pth isa Thunk
        @test unthunk(pth) === 6.0 + 0.0im
    end

    @testset "display" begin
        @test repr(ProjectTo(1.1)) == "ProjectTo{Float64}()"
        @test occursin("ProjectTo{AbstractArray}(element", repr(ProjectTo([1,2,3])))
    end
end
