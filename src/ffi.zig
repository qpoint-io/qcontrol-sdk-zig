//! Internal FFI layer for C interop.
//!
//! This module imports C SDK headers and provides raw types.
//! It is not part of the public API.

// Import plugin.h which includes common.h and file.h
pub const c = @cImport({
    @cInclude("qcontrol/plugin.h");
});
