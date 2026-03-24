use crate::server::AppState;
use axum::extract::{Query, State};
use axum::http::StatusCode;
use axum::response::IntoResponse;
use axum::Json;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;

// ---------- Request / Response types ----------

#[derive(Deserialize)]
pub struct InjectRequest {
    pub text: String,
    pub priority: Option<bool>,
}

#[derive(Serialize)]
pub struct InjectResponse {
    pub id: String,
    pub queued: bool,
    pub position: usize,
}

#[derive(Serialize)]
pub struct HealthResponse {
    pub status: String,
    pub version: String,
}

#[derive(Serialize)]
pub struct StatusResponse {
    pub idle: bool,
    pub queue_length: usize,
    pub child_running: bool,
    pub uptime_seconds: u64,
}

#[derive(Serialize)]
pub struct QueueClearResponse {
    pub cleared: usize,
}

#[derive(Serialize)]
pub struct ErrorResponse {
    pub error: String,
}

// ---------- Handlers ----------

/// GET /health -- returns 200 with status ok and version
pub async fn handle_health() -> Json<HealthResponse> {
    Json(HealthResponse {
        status: "ok".to_string(),
        version: env!("CARGO_PKG_VERSION").to_string(),
    })
}

/// GET /status -- returns idle state, queue length, child running, uptime
pub async fn handle_status(State(state): State<Arc<AppState>>) -> Json<StatusResponse> {
    let idle = state.bridge.is_idle().await;
    let queue_length = state.bridge.queue_len().await;
    let child_running = state.bridge.is_child_running();
    let uptime_seconds = state.bridge.uptime().as_secs();

    Json(StatusResponse {
        idle,
        queue_length,
        child_running,
        uptime_seconds,
    })
}

/// POST /inject -- accepts JSON with text field, queues injection.
/// Query param ?sync=true blocks until injection is delivered or times out with 408.
pub async fn handle_inject(
    State(state): State<Arc<AppState>>,
    Query(params): Query<HashMap<String, String>>,
    Json(body): Json<InjectRequest>,
) -> impl IntoResponse {
    // Validate text is not empty
    if body.text.trim().is_empty() {
        return (
            StatusCode::BAD_REQUEST,
            Json(serde_json::json!(ErrorResponse {
                error: "text field must not be empty".to_string(),
            })),
        )
            .into_response();
    }

    // Check child is running
    if !state.bridge.is_child_running() {
        return (
            StatusCode::SERVICE_UNAVAILABLE,
            Json(serde_json::json!(ErrorResponse {
                error: "child process not running".to_string(),
            })),
        )
            .into_response();
    }

    let priority = body.priority.unwrap_or(false);
    let is_sync = params.get("sync").map(|v| v == "true").unwrap_or(false);

    if is_sync {
        // Sync path: block until delivered or timeout
        let queue = state.bridge.queue();
        match queue.enqueue_sync(body.text, priority).await {
            Ok((id, rx)) => {
                state.bridge.notify_enqueue();
                let timeout = state.timeout;
                tokio::select! {
                    result = rx => {
                        match result {
                            Ok(()) => Json(serde_json::json!(InjectResponse {
                                id,
                                queued: false,
                                position: 0,
                            })).into_response(),
                            Err(_) => (
                                StatusCode::INTERNAL_SERVER_ERROR,
                                Json(serde_json::json!(ErrorResponse {
                                    error: "injection channel closed".to_string(),
                                })),
                            ).into_response(),
                        }
                    }
                    _ = tokio::time::sleep(timeout) => {
                        (
                            StatusCode::REQUEST_TIMEOUT,
                            Json(serde_json::json!(ErrorResponse {
                                error: "injection timeout".to_string(),
                            })),
                        ).into_response()
                    }
                }
            }
            Err(_) => (
                StatusCode::TOO_MANY_REQUESTS,
                Json(serde_json::json!(ErrorResponse {
                    error: "queue full (max 100)".to_string(),
                })),
            )
                .into_response(),
        }
    } else {
        // Async path: queue and return immediately
        let queue = state.bridge.queue();
        match queue.enqueue(body.text, priority).await {
            Ok((id, position)) => {
                state.bridge.notify_enqueue();
                Json(serde_json::json!(InjectResponse {
                    id,
                    queued: true,
                    position,
                }))
                .into_response()
            }
            Err(_) => (
                StatusCode::TOO_MANY_REQUESTS,
                Json(serde_json::json!(ErrorResponse {
                    error: "queue full (max 100)".to_string(),
                })),
            )
                .into_response(),
        }
    }
}

/// DELETE /queue -- clears the injection queue
pub async fn handle_queue_clear(State(state): State<Arc<AppState>>) -> Json<QueueClearResponse> {
    let cleared = state.bridge.queue().clear().await;
    Json(QueueClearResponse { cleared })
}
