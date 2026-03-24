const HUB_URL = process.env.OPENMOB_HUB_URL || "http://127.0.0.1:8686/api/v1";

export async function hubGet<T = unknown>(path: string): Promise<T> {
  const url = `${HUB_URL}${path}`;
  const res = await fetch(url);
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Hub API error ${res.status}: ${body}`);
  }
  return res.json() as Promise<T>;
}

export async function hubPost<T = unknown>(path: string, body: Record<string, unknown>): Promise<T> {
  const url = `${HUB_URL}${path}`;
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
}
