import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { hubPost } from "../hub-client.js";
import type { ActionResult } from "../types.js";

export function registerSwipe(server: McpServer): void {
  server.registerTool(
    "swipe",
    {
      description:
        "Perform a swipe gesture on the device screen from start point to end point.",
      inputSchema: {
        device_id: z.string().describe("Device ID"),
        x1: z.number().describe("Start X"),
        y1: z.number().describe("Start Y"),
        x2: z.number().describe("End X"),
        y2: z.number().describe("End Y"),
        duration: z.number().optional().describe("Duration in milliseconds (default 300)"),
      },
    },
    async ({ device_id, x1, y1, x2, y2, duration }) => {
      try {
        const result = await hubPost<ActionResult>(`/devices/${device_id}/swipe`, {
          x1,
          y1,
          x2,
          y2,
          duration,
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
