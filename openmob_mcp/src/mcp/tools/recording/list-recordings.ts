import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HubClient } from "../../common/hub-client.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";

export function registerListRecordings(server: McpServer, hub: HubClient): void {
  server.registerTool(
    "list_recordings",
    {
      description:
        "List all screen recordings. Optionally filter by device. Shows file path, duration, and status for each.",
      inputSchema: {
        device_id: z.string().optional().describe("Filter by device. Omit to see all recordings."),
      },
    },
    async ({ device_id }) => {
      try {
        const params = device_id ? `?device_id=${device_id}` : "";
        const result = await hub.get<{
          recordings: Array<{ id: string; file_path: string; duration_ms?: number; is_active: boolean }>;
          count: number;
        }>(`/recordings/${params}`);

        const count = result.count ?? 0;
        const active = result.recordings?.filter((r) => r.is_active).length ?? 0;

        let summary: string;
        if (count === 0) {
          summary = "No recordings found — use start_recording to begin recording a device screen";
        } else if (active > 0) {
          summary = `${count} recording${count > 1 ? "s" : ""} (${active} currently recording)`;
        } else {
          summary = `${count} saved recording${count > 1 ? "s" : ""}`;
        }

        return createTextResponse(result, summary);
      } catch (error) {
        return createErrorResponse(error, "Could not list recordings");
      }
    }
  );
}
