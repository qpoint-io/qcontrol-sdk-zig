/**
 * @file qcontrol/net.h
 * @brief Network operation types for qcontrol SDK
 *
 * Defines the session-based network plugin model where:
 * - Configuration happens per-connection at connect/accept time
 * - State flows automatically between I/O operations on the same fd
 * - Discovery events (TLS, domain, protocol) enrich the session context
 * - Declarative transforms (prefix, suffix, replace) require zero code
 * - The agent handles heavy lifting; SDKs are thin wrappers
 *
 * Abstraction is at the connection level, not syscalls. Plugins see
 * logical events (connect, send, recv) regardless of underlying syscalls.
 *
 * NOTE: This API is v1 spec only. Callbacks currently return "not implemented".
 */

#ifndef QCONTROL_NET_H
#define QCONTROL_NET_H

#include <stddef.h>
#include <stdint.h>
#include <sys/types.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * Net Action Types
 * ============================================================================ */

/**
 * Action types returned by network operation callbacks.
 */
typedef enum {
    /** No interception, continue normally */
    QCONTROL_NET_ACTION_PASS = 0,
    /** Block the operation with EACCES */
    QCONTROL_NET_ACTION_BLOCK = 1,
    /** Block the operation with a specific errno */
    QCONTROL_NET_ACTION_BLOCK_ERRNO = 2,
    /** Intercept with full session config */
    QCONTROL_NET_ACTION_SESSION = 3,
    /** Track state only, no transforms */
    QCONTROL_NET_ACTION_STATE = 4,
} qcontrol_net_action_type_t;

/**
 * Connection direction.
 */
typedef enum {
    /** Outbound connection (connect) */
    QCONTROL_NET_OUTBOUND = 0,
    /** Inbound connection (accept) */
    QCONTROL_NET_INBOUND = 1,
} qcontrol_net_direction_t;

/* ============================================================================
 * Net Pattern Replacement
 * ============================================================================ */

/**
 * Pattern for string replacement in transform pipeline.
 */
typedef struct {
    const char* needle;
    size_t needle_len;
    const char* replacement;
    size_t replacement_len;
} qcontrol_net_pattern_t;

/* ============================================================================
 * Forward Declarations
 * ============================================================================ */

typedef struct qcontrol_buffer qcontrol_buffer_t;
typedef struct qcontrol_net_ctx qcontrol_net_ctx_t;
typedef struct qcontrol_net_rw_config qcontrol_net_rw_config_t;
typedef struct qcontrol_net_session qcontrol_net_session_t;
typedef struct qcontrol_net_action qcontrol_net_action_t;

/* ============================================================================
 * Net Transform Function Types
 * ============================================================================ */

/**
 * Transform function - called during send/recv to modify buffer.
 *
 * @param state Plugin-defined state (from session)
 * @param ctx Net context (fd, addresses, tls, domain, protocol)
 * @param buf Buffer containing data to transform
 * @return Action indicating whether to continue or block
 */
typedef qcontrol_net_action_t (*qcontrol_net_transform_fn)(
    void* state,
    qcontrol_net_ctx_t* ctx,
    qcontrol_buffer_t* buf
);

/**
 * Dynamic prefix function - returns prefix to prepend.
 *
 * @param state Plugin-defined state
 * @param ctx Net context
 * @param out_len Output parameter for prefix length
 * @return Prefix string (plugin-owned, must remain valid until close)
 */
typedef const char* (*qcontrol_net_prefix_fn)(
    void* state,
    qcontrol_net_ctx_t* ctx,
    size_t* out_len
);

/**
 * Dynamic suffix function - returns suffix to append.
 *
 * @param state Plugin-defined state
 * @param ctx Net context
 * @param out_len Output parameter for suffix length
 * @return Suffix string (plugin-owned, must remain valid until close)
 */
typedef const char* (*qcontrol_net_suffix_fn)(
    void* state,
    qcontrol_net_ctx_t* ctx,
    size_t* out_len
);

/* ============================================================================
 * Net Configuration Structures
 * ============================================================================ */

/**
 * Read/Write configuration for network I/O (send/recv).
 *
 * Transform order: prefix -> replace -> transform -> suffix
 */
struct qcontrol_net_rw_config {
    /** Static prefix to prepend (or NULL) */
    const char* prefix;
    size_t prefix_len;

    /** Static suffix to append (or NULL) */
    const char* suffix;
    size_t suffix_len;

    /** Dynamic prefix function (or NULL) */
    qcontrol_net_prefix_fn prefix_fn;

    /** Dynamic suffix function (or NULL) */
    qcontrol_net_suffix_fn suffix_fn;

    /** Pattern replacements array (or NULL) */
    const qcontrol_net_pattern_t* replace;
    size_t replace_count;

    /** Custom transform function (or NULL) */
    qcontrol_net_transform_fn transform;
};

/**
 * Session configuration for a network connection.
 * Returned from on_net_connect/on_net_accept to configure I/O behavior.
 */
struct qcontrol_net_session {
    /** Plugin-defined state (opaque, plugin owns memory) */
    void* state;

    /* === MODIFICATIONS (connect only, NULL = no change) === */

    /** Replace destination address */
    const char* set_addr;

    /** Replace destination port (0 = no change) */
    uint16_t set_port;

    /* === I/O TRANSFORM CONFIGS === */

    /** Send transform config (NULL if no transforms) */
    qcontrol_net_rw_config_t* send_config;

    /** Recv transform config (NULL if no transforms) */
    qcontrol_net_rw_config_t* recv_config;
};

/**
 * Action result returned from net callbacks.
 */
struct qcontrol_net_action {
    qcontrol_net_action_type_t type;
    union {
        /** errno value for BLOCK_ERRNO */
        int errno_val;
        /** Session config for SESSION */
        qcontrol_net_session_t session;
        /** State pointer for STATE (no config, state only) */
        void* state;
    };
};

/* ============================================================================
 * Net Action Convenience Macros
 * ============================================================================ */

/** Return PASS action (continue normally) */
#define QCONTROL_NET_PASS \
    ((qcontrol_net_action_t){ .type = QCONTROL_NET_ACTION_PASS })

/** Return BLOCK action (reject with EACCES) */
#define QCONTROL_NET_BLOCK \
    ((qcontrol_net_action_t){ .type = QCONTROL_NET_ACTION_BLOCK })

/** Return BLOCK_ERRNO action (reject with specific errno) */
#define QCONTROL_NET_BLOCK_WITH(e) \
    ((qcontrol_net_action_t){ .type = QCONTROL_NET_ACTION_BLOCK_ERRNO, .errno_val = (e) })

/** Return STATE action (track state, no transforms) */
#define QCONTROL_NET_STATE(s) \
    ((qcontrol_net_action_t){ .type = QCONTROL_NET_ACTION_STATE, .state = (s) })

/* ============================================================================
 * Net Event Structures
 * ============================================================================ */

/**
 * Event passed to on_net_connect callback.
 * Outbound connection being established.
 */
typedef struct {
    /** Socket file descriptor */
    int fd;

    /** Destination address (IP string, e.g., "192.168.1.1" or "::1") */
    const char* dst_addr;
    size_t dst_addr_len;

    /** Destination port */
    uint16_t dst_port;

    /** Local source address (may be NULL if not bound) */
    const char* src_addr;
    size_t src_addr_len;

    /** Local source port (0 if not bound) */
    uint16_t src_port;

    /** Result: 0 on success, -errno on failure */
    int result;
} qcontrol_net_connect_event_t;

/**
 * Event passed to on_net_accept callback.
 * Inbound connection accepted on a listening socket.
 */
typedef struct {
    /** Accepted socket file descriptor */
    int fd;

    /** Listening socket file descriptor */
    int listen_fd;

    /** Remote client address */
    const char* src_addr;
    size_t src_addr_len;

    /** Remote client port */
    uint16_t src_port;

    /** Local server address */
    const char* dst_addr;
    size_t dst_addr_len;

    /** Local server port */
    uint16_t dst_port;

    /** Result: fd on success, -errno on failure */
    int result;
} qcontrol_net_accept_event_t;

/**
 * Event passed to on_net_tls callback.
 * TLS handshake completed on a connection.
 */
typedef struct {
    /** Socket file descriptor */
    int fd;

    /** TLS version string (e.g., "TLSv1.2", "TLSv1.3") */
    const char* version;
    size_t version_len;

    /** Cipher suite (may be NULL) */
    const char* cipher;
    size_t cipher_len;
} qcontrol_net_tls_event_t;

/**
 * Event passed to on_net_domain callback.
 * Domain name discovered (from SNI, Host header, etc.)
 */
typedef struct {
    /** Socket file descriptor */
    int fd;

    /** Domain name */
    const char* domain;
    size_t domain_len;
} qcontrol_net_domain_event_t;

/**
 * Event passed to on_net_protocol callback.
 * Application protocol detected (from ALPN, content sniffing, etc.)
 */
typedef struct {
    /** Socket file descriptor */
    int fd;

    /** Protocol identifier (e.g., "http/1.1", "h2") */
    const char* protocol;
    size_t protocol_len;
} qcontrol_net_protocol_event_t;

/**
 * Event passed to on_net_send callback.
 * Data being sent on a connection.
 */
typedef struct {
    /** Socket file descriptor */
    int fd;

    /** Buffer containing data to send */
    const void* buf;

    /** Number of bytes */
    size_t count;
} qcontrol_net_send_event_t;

/**
 * Event passed to on_net_recv callback.
 * Data received on a connection.
 */
typedef struct {
    /** Socket file descriptor */
    int fd;

    /** Buffer containing received data */
    void* buf;

    /** Number of bytes requested */
    size_t count;

    /** Bytes actually received, or -errno on error */
    ssize_t result;
} qcontrol_net_recv_event_t;

/**
 * Event passed to on_net_close callback.
 * Connection closed.
 */
typedef struct {
    /** Socket file descriptor */
    int fd;

    /** Result: 0 on success, -errno on failure */
    int result;
} qcontrol_net_close_event_t;

/**
 * Net context passed to transform functions.
 * Contains all discovered information about the connection.
 */
struct qcontrol_net_ctx {
    /** Socket file descriptor */
    int fd;

    /** Connection direction */
    qcontrol_net_direction_t direction;

    /** Source (local for outbound, remote for inbound) */
    const char* src_addr;
    size_t src_addr_len;
    uint16_t src_port;

    /** Destination (remote for outbound, local for inbound) */
    const char* dst_addr;
    size_t dst_addr_len;
    uint16_t dst_port;

    /** TLS info (0/NULL if not TLS) */
    int is_tls;
    const char* tls_version;
    size_t tls_version_len;

    /** Domain name if discovered (may be NULL) */
    const char* domain;
    size_t domain_len;

    /** Protocol if detected (may be NULL) */
    const char* protocol;
    size_t protocol_len;
};

/* ============================================================================
 * Net Callback Signatures
 * ============================================================================ */

/**
 * Net connect callback - determines session configuration for outbound connections.
 *
 * Called after connect() completes. Return:
 * - PASS: no interception for this connection
 * - BLOCK: reject the connection
 * - SESSION: intercept with I/O config and/or modifications
 * - STATE: track state only, no transforms
 *
 * NOTE: Not yet implemented. Returns ENOSYS.
 */
typedef qcontrol_net_action_t (*qcontrol_net_connect_fn)(
    qcontrol_net_connect_event_t* event
);

/**
 * Net accept callback - determines session configuration for inbound connections.
 *
 * Called after accept() completes. Return:
 * - PASS: no interception for this connection
 * - BLOCK: close the accepted connection
 * - SESSION: intercept with I/O config
 * - STATE: track state only, no transforms
 *
 * NOTE: Not yet implemented. Returns ENOSYS.
 */
typedef qcontrol_net_action_t (*qcontrol_net_accept_fn)(
    qcontrol_net_accept_event_t* event
);

/**
 * Net TLS callback - called when TLS handshake completes.
 *
 * Provides TLS version and cipher information. Can update session
 * based on TLS properties.
 *
 * NOTE: Not yet implemented.
 */
typedef void (*qcontrol_net_tls_fn)(
    void* state,
    qcontrol_net_tls_event_t* event
);

/**
 * Net domain callback - called when domain name is discovered.
 *
 * Domain may come from SNI, Host header, or other sources.
 * Can update session based on domain.
 *
 * NOTE: Not yet implemented.
 */
typedef void (*qcontrol_net_domain_fn)(
    void* state,
    qcontrol_net_domain_event_t* event
);

/**
 * Net protocol callback - called when application protocol is detected.
 *
 * Protocol may come from ALPN or content sniffing.
 * Can update session based on protocol.
 *
 * NOTE: Not yet implemented.
 */
typedef void (*qcontrol_net_protocol_fn)(
    void* state,
    qcontrol_net_protocol_event_t* event
);

/**
 * Net send callback - observe or block sends.
 *
 * Called before data is sent. Can block but not modify.
 * Modification happens via session send_config transforms.
 *
 * NOTE: Not yet implemented. Returns ENOSYS.
 */
typedef qcontrol_net_action_t (*qcontrol_net_send_fn)(
    void* state,
    qcontrol_net_send_event_t* event
);

/**
 * Net recv callback - observe or block receives.
 *
 * Called after data is received. Can block but not modify.
 * Modification happens via session recv_config transforms.
 *
 * NOTE: Not yet implemented. Returns ENOSYS.
 */
typedef qcontrol_net_action_t (*qcontrol_net_recv_fn)(
    void* state,
    qcontrol_net_recv_event_t* event
);

/**
 * Net close callback - cleanup state.
 *
 * Called when connection is closed.
 * Plugin is responsible for freeing state here.
 *
 * NOTE: Not yet implemented.
 */
typedef void (*qcontrol_net_close_fn)(
    void* state,
    qcontrol_net_close_event_t* event
);

#ifdef __cplusplus
}
#endif

#endif /* QCONTROL_NET_H */
