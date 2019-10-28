# # Julia Gotchas

# ### Gotcha 1: Global scope
# To the confusion of many newcomers, the following simple for loop
# doesn't work as expected.

a = 0
for i in 1:10
    a += 1
end

# #### Solution 1: Be explicit about writing to globals

# The reason for this arguably somewhat unintuitive behavior are Julia's
# [scoping rules](https://docs.julialang.org/en/latest/manual/variables-and-scoping).
# In short, one must be explicit about writing to global variables by putting
# a `global` keyword in front of the assignment.

a = 0
for i in 1:10
    global a += 1
end
a

# #### Solution 2: Work in local scopes

# However, instead of being explicit about writing to a global
# in most cases we just shouldn't use globals in the first place (see the next gotcha)!
# Note that the issue disappears automatically when working in local scopes.

function outer()
    a = 0
    for i in 1:10
        a += 1
    end
    return a
end

outer()

# ## Gotcha 2: Global variables
a=2.0
b=3.0
function linearcombo()
  return 2a+b
end

linearcombo()

# This code works fine and `7.0` is obviously the correct result.
# So, what's the issue?
#
# Let's inspect the LLVM code that Julia produces for `linearcombo`.
using InteractiveUtils
@code_llvm linearcombo()

# Even without knowing much about LLVM IR this really doesn't look like
# efficient low-level code for a simple multiplication and addition.
# Thus, our function `linearcombo` will be *slow*!
#
# The reason for this inefficiency is that `a` and `b` in `linearcombo` are global
# variables which may change their value and, more importantly, their type at any
# point in time. Thus the compiler can't assume much about about `a` and `b`
# and has to produce generic, inefficient code that can handle all kinds of types.


# #### Solution 1: Work in local scope
# Wrapping everything in a function (a local scope) solves all the performance
# issues.
function outer()
    a=2.0; b=3.0
    function linearcombo()
      return 2a+b
    end
    return linearcombo()
end

outer()

#
@code_llvm outer()

# This is fast. In fact, it's not just fast, but pretty much as fast as it can be!
# Julia has figured out the result of the calculation at compile-time and simply
# returns the result `7.0` when `outer` gets called!

# #### Solution 2: Use constant globals

# By making `a` and `b` `const`ants, their value and type information
# is fixed at compile-time and efficient code can be produced.

const A=2.0
const B=3.0

function linearcombo()
  return 2A+B
end

@code_llvm linearcombo()

# ## Gotcha 3: Type instabilities

# What's bad for performance in the following function `g`?

function g()
  x=1
  for i = 1:10
    x = x/2
  end
  return x
end

# We can figure out what's going on by inspecting the output of `@code_warntype`.

@code_warntype g()

# The line `x::Union{Float64, Int64}`, highlighted in red, indicates that the
# variable `x` doesn't have a single concrete type but instead has been *inferred*
# to be either a `Float64` or a `Int64`. Note that we have initialized `x` as an integer,
# `typeof(1) == Int64`, but `x = x/2` will certainly make it a floating point number
# in the first iteration of the loop.
#
# The fact, that the type of a variable can vary within a function is called
# a *type instability*.
#
# A more drastic example is the following

f() = rand([1.0, 2, "3"])

@code_warntype f()

# The return type of `f` is inherently random - there is no way for the compiler
# to anticipate it and produce type stable code.

# #### Solution 1: Avoid type changes

# Clearly, we can readily remove the type instability by initializing `x` appropriately.

function g()
  x=1.0 # initialize x as Float64
  for i = 1:10
    x = x/2
  end
  return x
end

@code_llvm g()

# Note how the result has once again been determined at compile time!

# #### Solution 2: Specify types explicitly (not recommended)

function g()
  x::Float64 = 1
  for i = 1:10
    x = x/2
  end
  return x
end

@code_llvm g()


# #### "Solution" 3: Function barriers

# Sometimes type instabilities are unavoidable. For example, think of user input
# or file reading where we might have to process a unkown mixture of integers and floats.
# Let's model this scenario. We assume we have the following input data:

data = Union{Int64,Float64,String}[4, 2.0, "test", 3.2, 1]

# Let's further assume that our goal is to calculate the square of every element.
# A naive implementation would look as follows.

function calc_square(x)
  for i in eachindex(x)
    val = x[i]
    val^2
  end
end

@code_warntype calc_square(data)

# Unsurprisingly, as indicated by `val::Union{Float64, Int64, String}`, this
# implementation has a (unavoidable) type instability. The issue really is that this
# instability occurs in a hot loop: when trying to produce code that calculates `val^2`
# the compiler does not know whether `val` is a `Int64`, a `Float64`, or a `String`.
# It therefore has to produce generic code with branches for the different cases,
# which gets called over and over in each iteration at runtime.
#
# We can do better than this! The crucial point is to separate the type-instability
# from the actual, potentially heavy computations.

function calc_square_outer(x)
  for i in eachindex(x)
    calc_square_inner(x[i])
  end
end

calc_square_inner(x) = x^2

# By separating the reading from the actual calculation - taking the square -
# we allow the compiler to specialize the calculation for
# every possible input type. This way, only the reading
# will be type instable whereas the computation function `calc_square_inner`
# can be compiled to type-stable, efficient code.

@code_warntype calc_square_inner(data[1])

# ## Gotcha 4: Array slices produce copies

using BenchmarkTools, LinearAlgebra

M = rand(3,3);
x = rand(3);

# Say we were facing the following task: Given a 3x3 matrix `M` and a vector `v`
# calculate the dot product between the first column of `M` and `v`.
#
# A straightforward way to solve this task is

f(x,M) = dot(M[1:3,1], x)
@btime f($x,$M);

# A common Julia gotcha here is that array slices produce data copies!
# `M[1:3,1]` allocates a new vector and fills it with the first column
# of `M` before the dot product is taken.
#
# Clearly, this copy is unnecessary. What we really want is to use the actual first column of `M`.
# We can tell Julia to do so by using the `view` function.

g(x,M) = dot(view(M, 1:3,1), x)
@btime g($x, $M);

# Note that this is much more efficient! Writing `view`s explicitly can become annoying quickly.
# Fortunately, there is a nice little convenience macro `@views` which automatically replaces all
# array slices in an expression by views.

g(x,M) = @views dot(M[1:3,1], x)
@btime g($x, $M);


# ## Gotcha 5: Temporary allocations in "vectorized" code

# Often people (like to) write code like this.

function f()
  x = [1,5,6]
  for i in 1:100_000
    x = x + 2*x # "vectorized" style
  end
  return x
end

# The issue here is that `x = x + 2*x`, while nicealy readable and compact,
# allocates temporary arrays, which often spoils performance.

@btime f();

# As we can see, there are a total number of 200001 allocations(!). This indicates that
# there are 2 allocations per loop, one for the `2*x` and another one for the result
# of the addition. While it looks like `x`, that is its content, is overwritten in every iteration
# what really happens is that only the label `x` gets reassigned to a new piece of memory
# (and the old memory is discarded).

# #### Solution 1: Write out loops - they are fast

function f()
    x = [1,5,6]
    for i in 1:100_000
        for k in 1:3
            x[k] = x[k] + 2 * x[k]
        end
    end
    return x
end

# Abandoning "vectorized" style, we can simply write out the loops explicitly to
# get great performance without temporary allocations.

@btime f();

# On my machine, this implementation is 45 times faster! Note that the single
# allocation is the `x` that we eventually return.

# #### Solution 2: Broadcasting aka "more dots"

# We can use broadcasting to (basically) let Julia write the for loops for us.
# We only have to indicate elementwise operations by prepending them with a `.`.

function f()
    x = [1,5,6]
    for i in 1:100_000
        x .= x .+ 2 .* x # broadcasting / loop fusion
    end
    return x
end

@btime f();

# Although it doesn't quite reach the performance of the explicit-loops variant above,
# this approach provides a good compromise between speed and convenience. We can
# write "vectorized" code but avoid unnecessary temporary allocations that typically comes
# with it. (Tipp: `@.` is a nice little macro that puts dots on every operation
# so that you don't have to write them yourself.)

# Check out this [great blog post](https://julialang.org/blog/2017/01/moredots) by Steven G. Johnson on this topic (related notebook).

# ## Gotcha 6: Abstract fields

struct MyType
  x::AbstractFloat
end

f(a::MyType) = a.x^2 + sqrt(a.x) # some operation on our type

a = MyType(3.0);

# The issue here is very much similar to what we have discussed above as type instabilities.

@code_warntype f(a)

# Since `x` can be any subtype of `AbstractFloat` the compiler can't assume much about
# `x`s concrete structure. It therefore can only produce slow code.


@btime f($a);

# Compare this to

@btime sqrt(3.0);

# #### Solution 1: Specify concrete types for all fields

# By specifying a concrete type for the field `x` we give the compiler the
# necessary information to produce efficient code.

struct MyTypeConcrete
    x::Float64
end

f(b::MyTypeConcrete) = b.x^2 + sqrt(b.x)

b = MyTypeConcrete(3.0)

@code_warntype f(b)

# Note that this implementation is more than 30x faster!

@btime f($b);

# #### Solution 2:

# But what if I want to accept any kind of `AbstractFloat` in my type?
#
# Use a type parameter!

struct MyTypeParametric{A<:AbstractFloat}
    x::A
end

f(c::MyTypeParametric) = c.x^2 + sqrt(c.x)

c = MyTypeParametric(3.0)

@code_warntype f(c)
@btime f($c);

# From the type alone the compiler knows what the structure contains and can produce optimal code.

c = MyTypeParametric(Float32(3.0))

@code_warntype f(c)
@btime f($c);
