/**
 * MCP response helpers with NLP-friendly descriptions.
 * Every response includes a human-readable `summary` so non-technical
 * QA testers can understand what the AI agent is doing.
 */

export function createTextResponse(data: unknown, summary?: string) {
  const payload: Record<string, unknown> = {
    ...(typeof data === "object" && data !== null ? data as Record<string, unknown> : { result: data }),
  };
  if (summary) {
    payload.summary = summary;
  }
  return {
    content: [{ type: "text" as const, text: JSON.stringify(payload, null, 2) }],
  };
}

export function createImageResponse(base64: string, mimeType: string, summary?: string) {
  const content: Array<
    | { type: "image"; data: string; mimeType: string }
    | { type: "text"; text: string }
  > = [
    {
      type: "image" as const,
      data: base64,
      mimeType,
    },
  ];
  if (summary) {
    content.push({ type: "text" as const, text: summary });
  }
  return { content };
}

export function createErrorResponse(error: unknown, summary?: string) {
  const msg = String(error);
  const friendlyMsg = summary || humanizeError(msg);
  return {
    content: [{ type: "text" as const, text: JSON.stringify({ error: msg, summary: friendlyMsg }) }],
    isError: true,
  };
}

/** Convert technical errors into QA-friendly language */
function humanizeError(error: string): string {
  if (error.includes("ECONNREFUSED")) return "Cannot connect to OpenMob Hub — is it running?";

  // Extract HTTP status from Hub API errors like "Hub API error 404: ..."
  const httpMatch = error.match(/Hub API error (\d{3}):\s*(.*)/);
  if (httpMatch) {
    const status = httpMatch[1];
    const body = httpMatch[2] || "no details";
    return `Hub returned HTTP ${status} — ${body}`;
  }

  if (error.includes("404")) return "Route not found on Hub — check the API endpoint or Hub version";
  if (error.includes("timeout")) return "The device took too long to respond — try again";
  if (error.includes("uiautomator")) return "Could not read the screen — the app may be loading";
  if (error.includes("not found")) return "The requested item was not found on the device";
  return `Something went wrong: ${error}`;
}
