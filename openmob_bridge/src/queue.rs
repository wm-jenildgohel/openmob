use std::collections::VecDeque;
use std::fmt;
use std::sync::Arc;
use tokio::sync::Mutex;

const MAX_QUEUE_SIZE: usize = 100;

/// An item queued for injection into the PTY.
pub struct Injection {
    #[allow(dead_code)]
    pub id: String,
    pub text: String,
    #[allow(dead_code)]
    pub priority: bool,
    pub sync_tx: Option<tokio::sync::oneshot::Sender<()>>,
}

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

/// FIFO injection queue with priority support and max capacity of 100.
/// Uses VecDeque for O(1) front removal instead of Vec's O(n).
#[derive(Clone)]
pub struct InjectionQueue {
    items: Arc<Mutex<VecDeque<Injection>>>,
}

impl InjectionQueue {
    pub fn new() -> Self {
        Self {
            items: Arc::new(Mutex::new(VecDeque::new())),
        }
    }

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
            items.push_front(injection);
            Ok((id, 0))
        } else {
            let pos = items.len();
            items.push_back(injection);
            Ok((id, pos))
        }
    }

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
            items.push_front(injection);
        } else {
            items.push_back(injection);
        }
        Ok((id, rx))
    }

    pub async fn dequeue(&self) -> Option<Injection> {
        let mut items = self.items.lock().await;
        items.pop_front() // O(1) instead of Vec::remove(0) which is O(n)
    }

    pub async fn clear(&self) -> usize {
        let mut items = self.items.lock().await;
        let count = items.len();
        items.clear();
        count
    }

    pub async fn len(&self) -> usize {
        let items = self.items.lock().await;
        items.len()
    }
}
