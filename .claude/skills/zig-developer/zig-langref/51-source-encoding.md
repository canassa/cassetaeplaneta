## [Source Encoding](#toc-Source-Encoding) [§](#Source-Encoding)

Zig source code is UTF-8 encoded. Invalid UTF-8 byte sequences are not allowed anywhere.

Some code points are never allowed, even in [Comments](#Comments):

- ASCII control characters, except for U+000a (LF): U+0000...U+0009, U+000b...U+0001f, U+007f.
- Non-ASCII Unicode line endings: U+0085 (NEL), U+2028 (LS), U+2029 (PS).
- Byte order marks: U+FEFF (BOM).

LF (byte value 0x0a, code point U+000a, `'\n'`) is the line terminator in Zig source code. This byte value terminates every line of Zig source code, including last line of the file.

These conservative rules mean that third party tools reading already-validated Zig source code may make simplifying assumptions, such as naively separating lines based on `'\n'`. However, tooling such as zig fmt provides convenience functionality to convert invalid source encodings to valid source encodings, for instance by stripping byte order marks and carriage returns.
