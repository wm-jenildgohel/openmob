import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { hubPost } from "../hub-client.js";
import type { ActionResult } from "../types.js";

export function registerTypeText(server: McpServer): void {
  server.registerTool(
    "type_text",
    {
      description: "Type text into the currently focused input field on the device.",
      inputSchema: {
        device_id: z.string().describe("Device ID"),
        text: z.string().describe("Text to type"),
      },
    },
    async ({ device_id, text }) => {
      try {
        const result = await hubPost<ActionResult>(`/devices/${device_id}/type`, { text });
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
