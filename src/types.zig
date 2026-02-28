//! Core types for qcontrol plugins.

const ffi = @import("ffi.zig");

/// Result of a filter callback.
pub const FilterResult = enum {
    /// Continue to the next filter in the chain
    pass,
    /// Continue but apply any modifications made
    modify,
    /// Block the operation (returns error to caller)
    block,

    pub fn toRaw(self: FilterResult) ffi.c.qcontrol_status_t {
        return switch (self) {
            .pass => ffi.c.QCONTROL_STATUS_CONTINUE,
            .modify => ffi.c.QCONTROL_STATUS_MODIFY,
            .block => ffi.c.QCONTROL_STATUS_BLOCK,
        };
    }
};

/// Errors from SDK operations.
pub const Error = error{
    /// An invalid argument was provided.
    InvalidArg,
    /// Memory allocation failed.
    NoMemory,
    /// The SDK is not initialized.
    NotInitialized,
    /// Filter registration failed.
    RegisterFailed,
};

/// Phase of the operation.
pub const Phase = enum {
    /// Before the operation executes
    enter,
    /// After the operation completes
    leave,
};
