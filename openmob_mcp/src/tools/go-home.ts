import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { hubPost } from "../hub-client.js";
import type { ActionResult } from "../types.js";

export function registerGoHome(server: McpServer): void {
  server.registerTool(
    "go_home",
    {
      description: "Navigate to the home screen on the device.",
      inputSchema: {
        device_id: z.string().describe("Device ID"),
      },
    },
    async ({ device_id }) => {
      try {
        const result = await hubPost<ActionResult>(`/devices/${device_id}/keyevent`, {
          keyCode: 3,
        });
        return {
          content: [{ type: "text" as const, text: JSON.stringify(result) }],
        };
      } catch (error) {
        return {
          content: [{ type: "text" as const, text: JSON.stringify({ error: String(error) }) }],
          isError: true,
        };
      }
    }
  );
}
