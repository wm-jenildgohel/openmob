import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { hubGet } from "../hub-client.js";
import type { Device } from "../types.js";

export function registerListDevices(server: McpServer): void {
  server.registerTool(
    "list_devices",
    {
      description:
        "List all connected mobile devices (Android and iOS) with metadata including model, OS version, screen size, and connection status",
    },
    async () => {
      try {
        const devices = await hubGet<Device[]>("/devices");
        return {
          content: [{ type: "text" as const, text: JSON.stringify(devices, null, 2) }],
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
