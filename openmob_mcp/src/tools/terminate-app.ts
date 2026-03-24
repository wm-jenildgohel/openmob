import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { hubPost } from "../hub-client.js";
import type { ActionResult } from "../types.js";

export function registerTerminateApp(server: McpServer): void {
  server.registerTool(
    "terminate_app",
    {
      description: "Force-stop a running app on the device.",
      inputSchema: {
        device_id: z.string().describe("Device ID"),
        package: z.string().describe("Package name (Android) or bundle ID (iOS)"),
      },
    },
    async ({ device_id, package: pkg }) => {
      try {
        const result = await hubPost<ActionResult>(`/devices/${device_id}/terminate`, {
          package: pkg,
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
