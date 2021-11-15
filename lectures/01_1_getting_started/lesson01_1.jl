# start with `julia --threads auto`

# See my Remnote entry for 18.337 for extra links, notes, etc.

using Base.Threads # Press Shift-Enter to execute
Threads.nthreads() # should be >1 !

# ] activate .
# add FiniteDiff ForwardDiff

# using PkgTemplates


# In Demo1.jl:

# module Demo1

# using ForwardDiff, FiniteDiff
# f(x) = 2x^2 + x
# g(x) = ForwardDiff.derivative(f, x)
# h(x) = FiniteDiff.finite_difference_derivative(f, x)

# export f,g,h

# end


