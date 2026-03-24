export function createTextResponse(data: unknown) {
  return {
    content: [{ type: "text" as const, text: JSON.stringify(data, null, 2) }],
  };
}

export function createImageResponse(base64: string, mimeType: string) {
  return {
    content: [
      {
        type: "image" as const,
        data: base64,
        mimeType,
      },
    ],
  };
}

export function createErrorResponse(error: unknown) {
  return {
    content: [{ type: "text" as const, text: JSON.stringify({ error: String(error) }) }],
    isError: true,
  };
}
