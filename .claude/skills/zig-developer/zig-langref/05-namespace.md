## [Namespace](#toc-Namespace) [§](#Namespace)

A namespace in Zig is created by [struct](#struct), [enum](#enum), [union](#union), and [opaque](#opaque).

They contain [Namespace Level Variables](#Namespace-Level-Variables), [function](#Functions) declarations, and [comptime](#comptime) blocks.

Although namespaces use curly braces to surround their definition, they should not be confused with [blocks](#Blocks) or function bodies.

**Every Zig source file is implicitly a struct**, with the keyword `struct` and curly braces omitted.
