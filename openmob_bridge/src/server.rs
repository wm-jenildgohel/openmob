use crate::bridge::Bridge;
use crate::handlers::{handle_health, handle_inject, handle_queue_clear, handle_status};
use axum::routing::{delete, get, post};
use axum::Router;
use std::sync::Arc;
use std::time::Duration;
use tower_http::cors::CorsLayer;

/// Shared application state passed to all handlers.
pub struct AppState {
    pub bridge: Arc<Bridge>,
    pub timeout: Duration,
}

/// Build the axum Router with all routes and CORS middleware.
pub fn create_router(state: AppState) -> Router {
    let shared = Arc::new(state);

    Router::new()
        .route("/health", get(handle_health))
        .route("/status", get(handle_status))
        .route("/inject", post(handle_inject))
        .route("/queue", delete(handle_queue_clear))
        .layer(CorsLayer::permissive())
        .with_state(shared)
}

/// Start the HTTP server on `host:port`.
/// Binds to 127.0.0.1 by default (BRG-10).
pub async fn start_server(host: &str, port: u16, router: Router) -> anyhow::Result<()> {
    let addr = format!("{}:{}", host, port);
    eprintln!("AiBridge HTTP server listening on {}", addr);
    let listener = tokio::net::TcpListener::bind(&addr).await?;
    axum::serve(listener, router).await?;
    Ok(())
}
