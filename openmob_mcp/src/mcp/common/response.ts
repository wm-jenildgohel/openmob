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
  const content: Array<{ type: "image" | "text"; data?: string; mimeType?: string; text?: string }> = [
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
  if (error.includes("ECONNREFUSED")) return "Cannot connect to the device — is OpenMob Hub running?";
  if (error.includes("404")) return "Device not found — it may have been disconnected";
  if (error.includes("timeout")) return "The device took too long to respond — try again";
  if (error.includes("uiautomator")) return "Could not read the screen — the app may be loading";
  if (error.includes("not found")) return "The requested item was not found on the device";
  return `Something went wrong: ${error}`;
}
