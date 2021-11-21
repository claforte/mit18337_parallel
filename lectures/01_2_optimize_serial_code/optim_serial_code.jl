cd(@__DIR__)
using Pkg
Pkg.activate(".")

# Cache lines and row/column major
#-----------------------------

A = rand(100,100)
B = rand(100,100)
C = rand(100,100)
using BenchmarkTools
function inner_rows!(C,A,B)
    for i in 1:100, j in 1:100 # go through each row, then each column within each row - SLOW!
        #println("$i, $j")
        C[i,j] = A[i,j] + B[i,j]
    end
end
@btime inner_rows!(C,A,B)

function inner_cols!(C,A,B)
    for j in 1:100, i in 1:100
        C[i,j] = A[i,j] + B[i,j]
    end
end
@btime inner_cols!(C,A,B)


# Heap allocations and Speed
#-----------------------------

function inner_alloc!(C,A,B)
    for j in 1:100, i in 1:100
        val = [A[i,j] + B[i,j]] # size of the array could change (e.g. if an element is added) -- can't be allocated on stack!
        C[i,j] = val[1]
    end
end
@btime inner_alloc!(C,A,B)

function inner_noalloc!(C,A,B)
    for j in 1:100, i in 1:100
        val = A[i,j] + B[i,j] # size is known - Float64 - can be allocated on stack!
        C[i,j] = val[1]
    end
end
@btime inner_noalloc!(C,A,B)

# can use StaticArrays to get statically-sized arrays which can be stack-allocated!
using StaticArrays
function static_inner_alloc!(C,A,B)
    for j in 1:100, i in 1:100
        val = @SVector [A[i,j] + B[i,j]] # automatically encodes the size in the Type! so it can allocate on the stack!
        C[i,j] = val[1]
    end
end
@btime static_inner_alloc!(C,A,B)

@macroexpand @SVector [A[i,j] + B[i,j]]

# Mutation to avoid heap allocations
#-----------------------------------

function inner_noalloc!(C,A,B)
    for j in 1:100, i in 1:100
        val = A[i,j] + B[i,j]
        C[i,j] = val[1] # claforte: not sure why [1]?
    end
end
@btime inner_noalloc!(C,A,B)

function inner_alloc(A,B)
    C = similar(A)
    for j in 1:100, i in 1:100
        val = A[i,j] + B[i,j]
        C[i,j] = val[1]
    end
end
@btime inner_alloc(A,B)

# reuse the previous mutating function, instead of re-implementing the same code
function inner_alloc(A,B)
    C = similar(A)
    inner_noalloc!(C,A,B) # claforte: surprisingly this seems to be faster than the above (inlined?) implementation... ?!
end
@btime inner_alloc(A,B)


# 10*(A+B) done the hard way...
#-------------------------------

@btime sum([A + B for k in 1:10]); # ~ 62.337 μs (41 allocations: 1.45 MiB)


@btime sum([A .+ B for k in 1:10]); # ~ 69.381 μs (61 allocations: 1.45 MiB)

zeros(1)

# Slightly better version, to illustrate single-time initialization:
function reuse_alloc(A,B)
    C = zeros(size(A))
    for k in 1:10
        C .+= A .+ B
    end
    C
end

@btime reuse_alloc(A,B);

# (A .* B) .* C
function dotstar(A,B,C)
    tmp = similar(A)
    for i in 1:length(A)
        tmp[i] = A[i] * B[i]
    end
    
    tmp2 = similar(C)
    for i in 1:length(C)
        tmp2[i] = tmp[i]
    end
end
@btime dotstar(A,B,C) # 14μs (4 allocations: 156.41 KiB)

# (A .* B) .* C
function dotstar2(A,B,C)
    tmp = similar(A)
    for i in 1:length(A)
        tmp[i] = A[i] * B[i] * C[i]
    end
end
@btime dotstar2(A,B,C) # 8.4μs (2 allocations: 78.20 KiB)
# equivalent to:
map((a,b,c)->a*b,A,B,C)



function unfused(A,B,C)
    tmp = A .+ B
    tmp .+ C
end
@btime unfused(A,B,C); # 11.481 μs (4 allocations: 156.41 KiB)

fused(A,B,C) = A .+ B .+ C
@btime fused(A,B,C); # 5.512 μs (2 allocations: 78.20 KiB)

function dotstar3!(tmp,A,B,C)
    for i in 1:length(A)
        tmp[i] = A[i] * B[i] * C[i]
    end
    tmp
end
tmp = similar(A)
@btime dotstar3!(tmp,A,B,C); # 4.599 μs (0 allocations: 0 bytes)


function realdotstar3!(tmp,A,B,C)
    tmp .= A .* B .* C
    tmp
end 
@btime realdotstar3!(tmp,A,B,C); #  2.443 μs (0 allocations: 0 bytes)


# @inbounds
#----------

function vectorized!(tmp,A,B,C)
    tmp .= A .* B .* C
    nothing
end
@btime vectorized!(tmp,A,B,C) # 2.740 μs (0 allocations: 0 bytes)

function non_vectorized!(tmp,A,B,C)
    for i in 1:length(tmp)
        tmp[i] = A[i] * B[i] * C[i]  # more costly (primarily?) because of array bounds checking
    end
    nothing
end
@btime non_vectorized!(tmp,A,B,C) # 4.590 μs (0 allocations: 0 bytes)

function non_vectorized_inbounds!(tmp,A,B,C)
    @inbounds for i in 1:length(tmp) # @inbounds does bounds checking once (using @boundscheck)
        tmp[i] = A[i] * B[i] * C[i]  
    end
    nothing
end
@btime non_vectorized_inbounds!(tmp,A,B,C) # 2.823 μs (0 allocations: 0 bytes)

@btime A[50,50]

@btime A[1:5, 1:5]
@btime @view A[1:5, 1:5]
# equivalent to:
@btime view(A,1:5,1:5)

function ff7(A)
    A[1:5, 1:5]
end
@btime ff7(A)

function ff8(A)
    @view A[1:5,1:5] # allocates only 1 pointer
end
@btime ff8(A)

B = @view A[1:5,1:5]
B[1,1] = 2 # overwrite A
A # verify A[1,1] == 2

@btime 5000000000000000000000000000000000000000000
typeof(5000000000000000000000000000000000000000000)
typeof(1:500000000000000000000000000000000)
r = 1:500000000000000000000000000000000 # range object
r.start
r.stop
r[400]
@which r[400]
# something like:
# getindex(v::UnitRange, i::Integer) = (@boundscheck start + i)



# Asymptotic cost of heap allocations
#------------------------------------

# element-wise array multiplication is O(n), 
# and memory allocations are usually O(n) too, so it's an important factor in performance.
using LinearAlgebra, BenchmarkTools
function alloc_timer(n)
    A = rand(n,n)
    B = rand(n,n)
    C = rand(n,n)
    t1 = @belapsed $A .* $B # allocating form of A .* B
    t2 = @belapsed ($C .= $A .* $B) # non-allocating form of A .* B
    t1,t2
end
ns = 2 .^ (2:11)
res = [alloc_timer(n) for n in ns]
alloc   = [x[1] for x in res]
noalloc = [x[2] for x in res]

using Plots
plot(ns,alloc,label="=",xscale=:log10,yscale=:log10,legend=:bottomright,
     title="Micro-optimizations matter for BLAS1")
plot!(ns,noalloc,label=".=")


# Array multiplication is O(n^3)
using LinearAlgebra, BenchmarkTools
function alloc_timer(n)
    A = rand(n,n)
    B = rand(n,n)
    C = rand(n,n)
    t1 = @belapsed $A*$B
    t2 = @belapsed mul!($C,$A,$B)
    t1,t2
end
ns = 2 .^ (2:7)
res = [alloc_timer(n) for n in ns]
alloc   = [x[1] for x in res]
noalloc = [x[2] for x in res]

using Plots
plot(ns,alloc,label="*",xscale=:log10,yscale=:log10,legend=:bottomright,
     title="Micro-optimizations only matter for small matmuls")
plot!(ns,noalloc,label="mul!")