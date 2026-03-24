import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { hubGet } from "../hub-client.js";
import type { UiTreeResult } from "../types.js";

export function registerGetUiTree(server: McpServer): void {
  server.registerTool(
    "get_ui_tree",
    {
      description:
        "Get the UI accessibility tree from a device. Returns elements with index numbers that can be used with the tap tool. Optionally filter by text pattern or visibility.",
      inputSchema: {
        device_id: z.string().describe("Device ID"),
        text_filter: z.string().optional().describe("Regex pattern to filter elements by text"),
        visible_only: z.boolean().optional().describe("Only return visible elements"),
      },
    },
    async ({ device_id, text_filter, visible_only }) => {
      try {
        const params = new URLSearchParams();
        if (text_filter !== undefined) params.set("text", text_filter);
        if (visible_only !== undefined) params.set("visible", String(visible_only));
        const queryString = params.toString() ? `?${params.toString()}` : "";

        const data = await hubGet<UiTreeResult>(`/devices/${device_id}/ui-tree${queryString}`);
        return {
          content: [{ type: "text" as const, text: JSON.stringify(data.nodes, null, 2) }],
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
