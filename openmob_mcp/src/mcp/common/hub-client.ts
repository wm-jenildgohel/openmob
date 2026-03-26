const DEFAULT_PORTS = [8686, 8687, 8688, 8689, 8690];
const HEALTH_TIMEOUT_MS = 1500;

export interface HubClient {
  get<T = unknown>(path: string): Promise<T>;
  post<T = unknown>(path: string, body: Record<string, unknown>): Promise<T>;
  readonly hubUrl: string;
}

async function probePort(port: number): Promise<boolean> {
  try {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), HEALTH_TIMEOUT_MS);
    const res = await fetch(`http://127.0.0.1:${port}/health`, {
      signal: controller.signal,
    });
    clearTimeout(timer);
    if (!res.ok) return false;
    const body = await res.json() as Record<string, unknown>;
    return body.status === "ok";
  } catch {
    return false;
  }
}

async function discoverHubUrl(): Promise<string> {
  const explicit = process.env.OPENMOB_HUB_URL;
  if (explicit) return explicit;

  const explicitPort = process.env.OPENMOB_HUB_PORT;
  if (explicitPort) {
    const port = parseInt(explicitPort, 10);
    if (!isNaN(port)) return `http://127.0.0.1:${port}/api/v1`;
  }

  for (const port of DEFAULT_PORTS) {
    if (await probePort(port)) {
      console.error(`[openmob-mcp] Auto-detected Hub on port ${port}`);
      return `http://127.0.0.1:${port}/api/v1`;
    }
  }

  console.error(
    `[openmob-mcp] No Hub found on ports ${DEFAULT_PORTS.join(", ")}. ` +
    `Using default 8686. Set OPENMOB_HUB_URL or OPENMOB_HUB_PORT to override.`
  );
  return `http://127.0.0.1:${DEFAULT_PORTS[0]}/api/v1`;
}

export async function createHubClient(): Promise<HubClient> {
  const hubUrl = await discoverHubUrl();

  return {
    hubUrl,

    async get<T = unknown>(path: string): Promise<T> {
      const url = `${hubUrl}${path}`;
      const res = await fetch(url);
      if (!res.ok) {
        const body = await res.text();
        throw new Error(`Hub API error ${res.status}: ${body}`);
      }
      return res.json() as Promise<T>;
    },

    async post<T = unknown>(path: string, body: Record<string, unknown>): Promise<T> {
      const url = `${hubUrl}${path}`;
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
      if (!res.ok) {
        const bodyText = await res.text();
        throw new Error(`Hub API error ${res.status}: ${bodyText}`);
      }
      return res.json() as Promise<T>;
    },
  };
}
