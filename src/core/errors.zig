//! The port's one error set (docs/DESIGN.md "Errors"). Units return
//! `errors.Error` (or a subset) rather than defining their own, so callers
//! across units compose without conversions.

pub const Error = error{
    /// An unchecked original limit would be exceeded (memory corruption in
    /// the original, not behaviour).
    LimitExceeded,
    /// A path that terminates the original program (FatalAppExit, exit(),
    /// a crash), or a `Fixes` flag that turns a message box into quitting.
    Fatal,
};
