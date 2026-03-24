import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { hubPost } from "../hub-client.js";
import type { ActionResult } from "../types.js";

export function registerTap(server: McpServer): void {
  server.registerTool(
    "tap",
    {
      description:
        "Tap on the device screen. Provide either x,y coordinates or a UI element index from get_ui_tree.",
      inputSchema: {
        device_id: z.string().describe("Device ID"),
        x: z.number().optional().describe("X coordinate"),
        y: z.number().optional().describe("Y coordinate"),
        index: z.number().optional().describe("UI element index from get_ui_tree"),
      },
    },
    async ({ device_id, x, y, index }) => {
      try {
        const body: Record<string, unknown> =
          index !== undefined ? { index } : { x, y };
        const result = await hubPost<ActionResult>(`/devices/${device_id}/tap`, body);
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
