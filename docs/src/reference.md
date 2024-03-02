# Formal API

The formal API of Chairmarks is defined by the docstrings of public symbols. Any behavior
promised by these docstrings should remain in all future non-breaking releases, and any
deviation is a bug.

Specific display behavior is not part of the API, nor are the internal fields of the
`Sample` type. Please open an issue or a pull request if you would like to rely on internal
behavior and we can make it public.

```@index
```

```@autodocs
Modules = [Chairmarks]
```
