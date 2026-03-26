import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";

export function registerStopRecording(server: McpServer, hub: HubClient): void {
  server.registerTool(
    "stop_recording",
    {
      description:
        "Stop recording the device screen. Returns the saved file path, duration, and file size. " +
        "If actions were performed during recording, an SRT subtitle file is also generated with timestamps.",
      inputSchema: {
        device_id: deviceIdSchema,
        recording_id: z.string().optional().describe("Specific recording ID. If omitted, stops the active recording for this device."),
      },
    },
    async ({ device_id, recording_id }) => {
      try {
        const result = await hub.post<{
          data: { duration_ms?: number; file_size_bytes?: number; file_path?: string };
          summary?: string;
        }>("/recordings/stop", { device_id, recording_id });

        const durationSec = ((result.data?.duration_ms ?? 0) / 1000).toFixed(1);
        const sizeMb = ((result.data?.file_size_bytes ?? 0) / (1024 * 1024)).toFixed(1);
        const path = result.data?.file_path ?? "unknown";

        return createTextResponse(
          result,
          `Recording saved (${durationSec}s, ${sizeMb}MB) at: ${path}`
        );
      } catch (error) {
        return createErrorResponse(
          error,
          "Could not stop recording — there may be no active recording for this device"
        );
      }
    }
  );
}
