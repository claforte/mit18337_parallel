cd(@__DIR__)
using Pkg
Pkg.activate(".")

# Cache lines and row/column major
#-----------------------------

A = rand(1000,1000)
B = rand(1000,1000)
C = rand(1000,1000)
using BenchmarkTools
function inner_rows!(C,A,B)
    for i in 1:1000, j in 1:1000 # go through each row, then each column within each row - SLOW!
        #println("$i, $j")
        C[i,j] = A[i,j] + B[i,j]
    end
end
@btime inner_rows!(C,A,B)

function inner_cols!(C,A,B)
    for j in 1:1000, i in 1:1000
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