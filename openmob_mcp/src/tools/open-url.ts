import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { hubPost } from "../hub-client.js";
import type { ActionResult } from "../types.js";

export function registerOpenUrl(server: McpServer): void {
  server.registerTool(
    "open_url",
    {
      description:
        "Open a URL or deep link on the device in the default browser or app handler.",
      inputSchema: {
        device_id: z.string().describe("Device ID"),
        url: z.string().describe("URL or deep link to open"),
      },
    },
    async ({ device_id, url }) => {
      try {
        const result = await hubPost<ActionResult>(`/devices/${device_id}/open-url`, { url });
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
