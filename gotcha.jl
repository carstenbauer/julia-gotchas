# # Julia Gotchas

# ## 1) Global scope
a=2.0
b=3.0
function linearcombo()
  return 2a+b
end

linearcombo()

# Aboves code works fine and `7.0` is obviously the correct result.
# But it is *slow*! To see this let's look at the LLVM code for this block.
using InteractiveUtils
@code_llvm linearcombo()

# Even without knowing much about LLVM IR this really doesn't look like
# efficient low-level code for a simple multiplication and addition.
#
# The reason for this inefficiency is that global
# variables may change their value and, more importantly, their type at any
# point in time. Thus the compiler can't assume much about about `a` and `b`
# and has to produce generic, inefficient code that can handle all kinds of types.

# ### Solution: Work in local scope
# Wrapping everything in a function solves all the performance issues.
function outer()
    a=2.0; b=3.0
    function linearcombo()
      return 2a+b
    end
    return linearcombo()
end

outer()

#
@code_llvm linearcombo()


# ### 1b) Writing to global variables
# To the confusion of many newcomers, the following simple for loop
# doesn't work as expected.

a = 0
for i in 1:10
    a += 1
end

# In fact, it even throws an error.
# The reason for this arguably somewhat unintuitive behavior are Julia's
# [scoping rules](https://docs.julialang.org/en/latest/manual/variables-and-scoping).
# In short, one must be explicit about writing to global variables by putting
# a `global` keyword in front of the assignment.

a = 0
for i in 1:10
    global a += 1
end
a

# However, instead of being explicit about writing to a global
# in most cases we just shouldn't use globals in the first place!
# Note that the issue disappears automatically when working in local scopes.

function f()
    a = 0
    for i in 1:10
        a += 1
    end
    return a
end

f()

# ## 2) Type instabilities
