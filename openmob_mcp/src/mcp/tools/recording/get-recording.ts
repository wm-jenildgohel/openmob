import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HubClient } from "../../common/hub-client.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import { registerToolDual } from "../../common/dual-register.js";

export function registerGetRecording(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "get_recording",
    {
      description:
        "Get details about a specific recording — file path, duration, size, and all timestamped events that happened during the recording.",
      inputSchema: {
        recording_id: z.string().describe("Recording ID from start_recording"),
      },
    },
    async ({ recording_id }) => {
      try {
        const result = await hub.get<{
          data: { file_path?: string; duration_ms?: number; is_active?: boolean };
          events?: Array<{ action: string; description: string; timestamp: string }>;
        }>(`/recordings/${recording_id}`);

        const active = result.data?.is_active;
        const durationSec = ((result.data?.duration_ms ?? 0) / 1000).toFixed(1);
        const eventCount = result.events?.length ?? 0;

        const summary = active
          ? `Recording is still active (${eventCount} events so far)`
          : `Recording: ${durationSec}s, ${eventCount} events. File: ${result.data?.file_path ?? "unknown"}`;

        return createTextResponse(result, summary);
      } catch (error) {
        return createErrorResponse(error, "Recording not found");
      }
    }
  );
}
