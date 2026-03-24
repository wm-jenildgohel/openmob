use std::fmt;
use std::sync::Arc;
use tokio::sync::Mutex;

const MAX_QUEUE_SIZE: usize = 100;

/// An item queued for injection into the PTY.
pub struct Injection {
    pub id: String,
    pub text: String,
    pub priority: bool,
    pub sync_tx: Option<tokio::sync::oneshot::Sender<()>>,
}

/// Error returned when the queue is at capacity.
#[derive(Debug)]
pub enum QueueError {
    Full,
}

impl fmt::Display for QueueError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            QueueError::Full => write!(f, "queue full (max {})", MAX_QUEUE_SIZE),
        }
    }
}

impl std::error::Error for QueueError {}

/// FIFO injection queue with priority support and a max capacity of 100.
/// Priority items are prepended to the front; normal items are appended.
#[derive(Clone)]
pub struct InjectionQueue {
    items: Arc<Mutex<Vec<Injection>>>,
}

impl InjectionQueue {
    pub fn new() -> Self {
        Self {
            items: Arc::new(Mutex::new(Vec::new())),
        }
    }

    /// Enqueue text for async injection.
    /// Returns (id, position) on success or QueueError::Full.
    pub async fn enqueue(
        &self,
        text: String,
        priority: bool,
    ) -> Result<(String, usize), QueueError> {
        let mut items = self.items.lock().await;
        if items.len() >= MAX_QUEUE_SIZE {
            return Err(QueueError::Full);
        }
        let id = uuid::Uuid::new_v4().to_string();
        let injection = Injection {
            id: id.clone(),
            text,
            priority,
            sync_tx: None,
        };
        if priority {
            items.insert(0, injection);
            Ok((id, 0))
        } else {
            let pos = items.len();
            items.push(injection);
            Ok((id, pos))
        }
    }

    /// Enqueue text for synchronous injection.
    /// Returns (id, oneshot::Receiver) so the caller can await completion.
    pub async fn enqueue_sync(
        &self,
        text: String,
        priority: bool,
    ) -> Result<(String, tokio::sync::oneshot::Receiver<()>), QueueError> {
        let mut items = self.items.lock().await;
        if items.len() >= MAX_QUEUE_SIZE {
            return Err(QueueError::Full);
        }
        let id = uuid::Uuid::new_v4().to_string();
        let (tx, rx) = tokio::sync::oneshot::channel();
        let injection = Injection {
            id: id.clone(),
            text,
            priority,
            sync_tx: Some(tx),
        };
        if priority {
            items.insert(0, injection);
        } else {
            items.push(injection);
        }
        Ok((id, rx))
    }

    /// Remove and return the first item in the queue, or None if empty.
    pub async fn dequeue(&self) -> Option<Injection> {
        let mut items = self.items.lock().await;
        if items.is_empty() {
            None
        } else {
            Some(items.remove(0))
        }
    }

    /// Clear all items from the queue. Returns how many were removed.
    pub async fn clear(&self) -> usize {
        let mut items = self.items.lock().await;
        let count = items.len();
        items.clear();
        count
    }

    /// Returns the current number of items in the queue.
    pub async fn len(&self) -> usize {
        let items = self.items.lock().await;
        items.len()
    }
}
