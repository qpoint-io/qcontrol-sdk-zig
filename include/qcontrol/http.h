/**
 * @file qcontrol/http.h
 * @brief HTTP operation types for qcontrol SDK
 *
 * Defines the exchange-based HTTP plugin model where:
 * - HTTP/1.x and HTTP/2 share one structured callback surface
 * - Request and response starts expose full normalized header blocks
 * - Bodies are streamed incrementally as decoded chunks
 * - Plugin state can be attached once per HTTP exchange
 * - The runtime handles protocol parsing and framing
 *
 * This header exposes one structured HTTP callback surface that supports both
 * read-only inspection and host-backed mutation for request and response data.
 */

#ifndef QCONTROL_HTTP_H
#define QCONTROL_HTTP_H

#include <stddef.h>
#include <stdint.h>

#include "net.h"

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * HTTP Action Types
 * ============================================================================ */

/**
 * Action types returned by HTTP callbacks.
 */
typedef enum {
    /** No interception, continue normally */
    QCONTROL_HTTP_ACTION_PASS = 0,
    /** Block the exchange */
    QCONTROL_HTTP_ACTION_BLOCK = 1,
    /** Track per-exchange state only */
    QCONTROL_HTTP_ACTION_STATE = 2,
} qcontrol_http_action_type_t;

/**
 * Normalized HTTP version.
 */
typedef enum {
    QCONTROL_HTTP_VERSION_UNKNOWN = 0,
    QCONTROL_HTTP_VERSION_1_0 = 1,
    QCONTROL_HTTP_VERSION_1_1 = 2,
    QCONTROL_HTTP_VERSION_2 = 3,
} qcontrol_http_version_t;

/**
 * Message kind within an HTTP exchange.
 */
typedef enum {
    QCONTROL_HTTP_MESSAGE_REQUEST = 0,
    QCONTROL_HTTP_MESSAGE_RESPONSE = 1,
} qcontrol_http_message_kind_t;

/**
 * Body event flags.
 */
typedef enum {
    /** No extra decoding flags */
    QCONTROL_HTTP_BODY_FLAG_NONE = 0,
    /** Transfer framing has been decoded (for example, chunked encoding) */
    QCONTROL_HTTP_BODY_FLAG_TRANSFER_DECODED = 1 << 0,
    /** Content encoding has been decoded (for example, gzip) */
    QCONTROL_HTTP_BODY_FLAG_CONTENT_DECODED = 1 << 1,
} qcontrol_http_body_flag_t;

/**
 * Body scheduling mode requested by one request or response head callback.
 */
typedef enum {
    /** Preserve the host's default body scheduling for this message. */
    QCONTROL_HTTP_BODY_MODE_DEFAULT = 0,
    /** Deliver decoded body callbacks incrementally as chunks arrive. */
    QCONTROL_HTTP_BODY_MODE_STREAM = 1,
    /** Buffer the decoded logical body before running body callbacks. */
    QCONTROL_HTTP_BODY_MODE_BUFFER = 2,
} qcontrol_http_body_mode_t;

/**
 * Exchange-close reason.
 */
typedef enum {
    /** Exchange completed normally */
    QCONTROL_HTTP_CLOSE_COMPLETE = 0,
    /** Exchange ended before protocol completion */
    QCONTROL_HTTP_CLOSE_ABORTED = 1,
    /** Streamer disabled after parse or desync failure */
    QCONTROL_HTTP_CLOSE_PARSE_ERROR = 2,
    /** Underlying connection closed before exchange completion */
    QCONTROL_HTTP_CLOSE_CONNECTION_CLOSED = 3,
} qcontrol_http_close_reason_t;

/**
 * Exchange-close flags.
 */
typedef enum {
    /** No completion flags were recorded */
    QCONTROL_HTTP_EXCHANGE_FLAG_NONE = 0,
    /** Request message reached its done callback */
    QCONTROL_HTTP_EXCHANGE_FLAG_REQUEST_DONE = 1 << 0,
    /** Response message reached its done callback */
    QCONTROL_HTTP_EXCHANGE_FLAG_RESPONSE_DONE = 1 << 1,
} qcontrol_http_exchange_flag_t;

/* ============================================================================
 * Forward Declarations
 * ============================================================================ */

typedef struct qcontrol_http_ctx qcontrol_http_ctx_t;
typedef struct qcontrol_http_action qcontrol_http_action_t;
typedef struct qcontrol_http_headers qcontrol_http_headers_t;
typedef struct qcontrol_http_request_head qcontrol_http_request_head_t;
typedef struct qcontrol_http_response_head qcontrol_http_response_head_t;

/* ============================================================================
 * HTTP Data Structures
 * ============================================================================ */

/**
 * Single normalized HTTP header.
 */
typedef struct {
    const char* name;
    size_t name_len;
    const char* value;
    size_t value_len;
} qcontrol_http_header_t;

/**
 * Context shared by all callbacks for one HTTP exchange.
 */
struct qcontrol_http_ctx {
    /** Underlying network metadata snapshot */
    qcontrol_net_ctx_t net;

    /** Runtime-assigned exchange identifier */
    uint64_t exchange_id;

    /** Native HTTP/2 stream identifier, or 0 for HTTP/1.x */
    uint32_t stream_id;

    /** Normalized HTTP version */
    qcontrol_http_version_t version;
};

/**
 * Action result returned from HTTP callbacks.
 */
struct qcontrol_http_action {
    qcontrol_http_action_type_t type;
    qcontrol_http_body_mode_t body_mode;
    union {
        /** State pointer for STATE (opaque, plugin owns memory) */
        void* state;
    };
};

/* ============================================================================
 * HTTP Action Convenience Macros
 * ============================================================================ */

/** Return PASS action (continue normally) */
#define QCONTROL_HTTP_PASS \
    ((qcontrol_http_action_t){ .type = QCONTROL_HTTP_ACTION_PASS, .body_mode = QCONTROL_HTTP_BODY_MODE_DEFAULT })

/** Return BLOCK action (reject the exchange) */
#define QCONTROL_HTTP_BLOCK \
    ((qcontrol_http_action_t){ .type = QCONTROL_HTTP_ACTION_BLOCK, .body_mode = QCONTROL_HTTP_BODY_MODE_DEFAULT })

/** Return STATE action (track per-exchange state) */
#define QCONTROL_HTTP_STATE(s) \
    ((qcontrol_http_action_t){ .type = QCONTROL_HTTP_ACTION_STATE, .body_mode = QCONTROL_HTTP_BODY_MODE_DEFAULT, .state = (s) })

/**
 * Apply one body scheduling request to an existing HTTP action.
 *
 * Request callbacks apply the selected mode to the request body for that
 * exchange. Response callbacks apply the selected mode to the response body
 * for that exchange. Other callbacks should leave the mode at DEFAULT.
 */
static inline qcontrol_http_action_t qcontrol_http_action_with_body_mode(
    qcontrol_http_action_t action,
    qcontrol_http_body_mode_t body_mode
) {
    action.body_mode = body_mode;
    return action;
}

/* ============================================================================
 * HTTP Event Structures
 * ============================================================================ */

/**
 * Event passed to on_http_request callback.
 */
typedef struct {
    qcontrol_http_ctx_t ctx;

    /** Raw request-target as seen on the wire */
    const char* raw_target;
    size_t raw_target_len;

    /** Normalized request method */
    const char* method;
    size_t method_len;

    /** Normalized request scheme, or NULL if unavailable */
    const char* scheme;
    size_t scheme_len;

    /** Normalized request authority, or NULL if unavailable */
    const char* authority;
    size_t authority_len;

    /** Normalized request path */
    const char* path;
    size_t path_len;

    /** Runtime-owned header array */
    const qcontrol_http_header_t* headers;
    size_t header_count;

    /** Mutable request head handle for host-backed edits, or NULL. */
    qcontrol_http_request_head_t* head;
} qcontrol_http_request_event_t;

/**
 * Event passed to on_http_response callback.
 */
typedef struct {
    qcontrol_http_ctx_t ctx;

    /** Response status code */
    uint16_t status_code;

    /** Response reason phrase, or NULL if unavailable */
    const char* reason;
    size_t reason_len;

    /** Runtime-owned header array */
    const qcontrol_http_header_t* headers;
    size_t header_count;

    /** Mutable response head handle for host-backed edits, or NULL. */
    qcontrol_http_response_head_t* head;
} qcontrol_http_response_event_t;

/**
 * Event passed to request/response body callbacks.
 *
 * The host owns body scheduling and forwarding semantics. Plugins should treat
 * `bytes` as the decoded input view for this callback and `body` as an
 * optional mutable output buffer supplied by hosts that support body editing.
 */
typedef struct {
    qcontrol_http_ctx_t ctx;

    /** Request or response body */
    qcontrol_http_message_kind_t kind;

    /** Direct read-only body bytes for this callback */
    const char* bytes;
    size_t bytes_len;

    /**
     * Mutable body buffer for host-backed edits, or NULL when this host/path
     * only supports read-only observation.
     */
    qcontrol_buffer_t* body;

    /** Decoded body offset within this message */
    uint64_t offset;

    /** qcontrol_http_body_flag_t bitset */
    uint32_t flags;

    /**
     * Non-zero when this callback carries the terminal body chunk for the
     * current message body.
     */
    int end_of_stream;
} qcontrol_http_body_event_t;

/**
 * Event passed to request/response trailers callbacks.
 */
typedef struct {
    qcontrol_http_ctx_t ctx;

    /** Request or response trailers */
    qcontrol_http_message_kind_t kind;

    /** Runtime-owned trailer array */
    const qcontrol_http_header_t* headers;
    size_t header_count;

    /** Mutable trailer block for host-backed edits, or NULL. */
    qcontrol_http_headers_t* header_block;
} qcontrol_http_trailers_event_t;

/**
 * Event passed to request/response done callbacks.
 */
typedef struct {
    qcontrol_http_ctx_t ctx;

    /** Request or response completion */
    qcontrol_http_message_kind_t kind;

    /** Total decoded body bytes observed for this message */
    uint64_t body_bytes;
} qcontrol_http_message_done_event_t;

/**
 * Event passed to on_http_exchange_close callback.
 */
typedef struct {
    qcontrol_http_ctx_t ctx;

    /** Terminal reason for exchange close */
    qcontrol_http_close_reason_t reason;

    /** qcontrol_http_exchange_flag_t bitset */
    uint32_t flags;
} qcontrol_http_exchange_close_event_t;

/* ============================================================================
 * HTTP Callback Signatures
 * ============================================================================ */

/**
 * HTTP request callback - request start and normalized request headers.
 *
 * Called once per HTTP exchange before any request body or trailers.
 * Return:
 * - PASS: observe only
 * - BLOCK: reject the exchange
 * - STATE: track per-exchange state
 *
 * When the returned action sets `body_mode` to STREAM or BUFFER, that mode
 * applies to the request body for this exchange.
 */
typedef qcontrol_http_action_t (*qcontrol_http_request_fn)(
    qcontrol_http_request_event_t* event
);

/**
 * HTTP request body callback - decoded request body chunk.
 *
 * Hosts that support body mutation provide a non-NULL `event->body` buffer.
 * Full-body rewrite requires host-managed body scheduling so every plugin can
 * observe the intended input without being affected by earlier mutations.
 */
typedef qcontrol_http_action_t (*qcontrol_http_request_body_fn)(
    void* state,
    qcontrol_http_body_event_t* event
);

/**
 * HTTP request trailers callback - complete request trailers block.
 */
typedef qcontrol_http_action_t (*qcontrol_http_request_trailers_fn)(
    void* state,
    qcontrol_http_trailers_event_t* event
);

/**
 * HTTP request done callback - final request message completion.
 *
 * This callback runs after the final body or trailers callback for the request
 * and is intended for bookkeeping and cleanup rather than body replacement.
 */
typedef void (*qcontrol_http_request_done_fn)(
    void* state,
    qcontrol_http_message_done_event_t* event
);

/**
 * HTTP response callback - response start and normalized response headers.
 *
 * When the returned action sets `body_mode` to STREAM or BUFFER, that mode
 * applies to the response body for this exchange.
 */
typedef qcontrol_http_action_t (*qcontrol_http_response_fn)(
    void* state,
    qcontrol_http_response_event_t* event
);

/**
 * HTTP response body callback - decoded response body chunk.
 *
 * Hosts that support body mutation provide a non-NULL `event->body` buffer.
 * Full-body rewrite requires host-managed body scheduling so every plugin can
 * observe the intended input without being affected by earlier mutations.
 */
typedef qcontrol_http_action_t (*qcontrol_http_response_body_fn)(
    void* state,
    qcontrol_http_body_event_t* event
);

/**
 * HTTP response trailers callback - complete response trailers block.
 */
typedef qcontrol_http_action_t (*qcontrol_http_response_trailers_fn)(
    void* state,
    qcontrol_http_trailers_event_t* event
);

/**
 * HTTP response done callback - final response message completion.
 *
 * This callback runs after the final body or trailers callback for the
 * response and is intended for bookkeeping and cleanup rather than body
 * replacement.
 */
typedef void (*qcontrol_http_response_done_fn)(
    void* state,
    qcontrol_http_message_done_event_t* event
);

/**
 * HTTP exchange close callback - terminal cleanup hook for exchange state.
 *
 * Called exactly once for tracked exchanges, including abnormal termination.
 * Plugin is responsible for freeing exchange state here if it did not already
 * do so in an earlier done callback.
 */
typedef void (*qcontrol_http_exchange_close_fn)(
    void* state,
    qcontrol_http_exchange_close_event_t* event
);

/* ============================================================================
 * HTTP Head and Header Accessors
 * ============================================================================ */

/**
 * Return the mutable header collection for one request head.
 */
qcontrol_http_headers_t* qcontrol_http_request_headers(
    qcontrol_http_request_head_t* head
);

/**
 * Return the mutable header collection for one response head.
 */
qcontrol_http_headers_t* qcontrol_http_response_headers(
    qcontrol_http_response_head_t* head
);

/**
 * Return the current request raw-target pointer.
 */
const char* qcontrol_http_request_raw_target(
    const qcontrol_http_request_head_t* head
);

/**
 * Return the current request raw-target length.
 */
size_t qcontrol_http_request_raw_target_len(
    const qcontrol_http_request_head_t* head
);

/**
 * Return the current request method pointer.
 */
const char* qcontrol_http_request_method(
    const qcontrol_http_request_head_t* head
);

/**
 * Return the current request method length.
 */
size_t qcontrol_http_request_method_len(
    const qcontrol_http_request_head_t* head
);

/**
 * Replace the request method.
 *
 * Returns 0 on success and non-zero when the host rejects the replacement.
 */
int qcontrol_http_request_set_method(
    qcontrol_http_request_head_t* head,
    const char* value,
    size_t value_len
);

/**
 * Return the current request scheme pointer.
 */
const char* qcontrol_http_request_scheme(
    const qcontrol_http_request_head_t* head
);

/**
 * Return the current request scheme length.
 */
size_t qcontrol_http_request_scheme_len(
    const qcontrol_http_request_head_t* head
);

/**
 * Replace the request scheme.
 *
 * Returns 0 on success and non-zero when the host rejects the replacement.
 */
int qcontrol_http_request_set_scheme(
    qcontrol_http_request_head_t* head,
    const char* value,
    size_t value_len
);

/**
 * Return the current request authority pointer.
 */
const char* qcontrol_http_request_authority(
    const qcontrol_http_request_head_t* head
);

/**
 * Return the current request authority length.
 */
size_t qcontrol_http_request_authority_len(
    const qcontrol_http_request_head_t* head
);

/**
 * Replace the request authority.
 *
 * Returns 0 on success and non-zero when the host rejects the replacement.
 */
int qcontrol_http_request_set_authority(
    qcontrol_http_request_head_t* head,
    const char* value,
    size_t value_len
);

/**
 * Return the current request path pointer.
 */
const char* qcontrol_http_request_path(
    const qcontrol_http_request_head_t* head
);

/**
 * Return the current request path length.
 */
size_t qcontrol_http_request_path_len(
    const qcontrol_http_request_head_t* head
);

/**
 * Replace the request path.
 *
 * Returns 0 on success and non-zero when the host rejects the replacement.
 */
int qcontrol_http_request_set_path(
    qcontrol_http_request_head_t* head,
    const char* value,
    size_t value_len
);

/**
 * Return the current response status code.
 */
uint16_t qcontrol_http_response_status_code(
    const qcontrol_http_response_head_t* head
);

/**
 * Replace the response status code.
 */
void qcontrol_http_response_set_status_code(
    qcontrol_http_response_head_t* head,
    uint16_t status_code
);

/**
 * Return the current response reason pointer.
 */
const char* qcontrol_http_response_reason(
    const qcontrol_http_response_head_t* head
);

/**
 * Return the current response reason length.
 */
size_t qcontrol_http_response_reason_len(
    const qcontrol_http_response_head_t* head
);

/**
 * Replace the response reason phrase.
 *
 * Returns 0 on success and non-zero when the host rejects the replacement.
 */
int qcontrol_http_response_set_reason(
    qcontrol_http_response_head_t* head,
    const char* value,
    size_t value_len
);

/**
 * Return the runtime-owned contiguous header view for the current callback.
 */
const qcontrol_http_header_t* qcontrol_http_headers_data(
    const qcontrol_http_headers_t* headers
);

/**
 * Return the number of headers in the current callback view.
 */
size_t qcontrol_http_headers_count(
    const qcontrol_http_headers_t* headers
);

/**
 * Append one header without removing any existing headers of the same name.
 *
 * Returns 0 on success and non-zero when the host rejects the mutation.
 */
int qcontrol_http_headers_add(
    qcontrol_http_headers_t* headers,
    const char* name,
    size_t name_len,
    const char* value,
    size_t value_len
);

/**
 * Replace all existing headers with the same name with one new header value.
 *
 * Returns 0 on success and non-zero when the host rejects the mutation.
 */
int qcontrol_http_headers_set(
    qcontrol_http_headers_t* headers,
    const char* name,
    size_t name_len,
    const char* value,
    size_t value_len
);

/**
 * Remove every header whose name matches the supplied byte sequence.
 *
 * Returns the number of removed headers.
 */
size_t qcontrol_http_headers_remove(
    qcontrol_http_headers_t* headers,
    const char* name,
    size_t name_len
);

#ifdef __cplusplus
}
#endif

#endif /* QCONTROL_HTTP_H */
