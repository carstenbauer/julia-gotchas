# Julia Gotchas

## 1) Global scope

```julia
a=2.0
b=3.0
function linearcombo()
  return 2a+b
end

linearcombo()
```

## 2) Type instabilities

*This page was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*

