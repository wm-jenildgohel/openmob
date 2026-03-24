import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { hubPost } from "../hub-client.js";
import type { ActionResult } from "../types.js";

export function registerLaunchApp(server: McpServer): void {
  server.registerTool(
    "launch_app",
    {
      description:
        "Launch an app on the device by package name (Android) or bundle ID (iOS).",
      inputSchema: {
        device_id: z.string().describe("Device ID"),
        package: z.string().describe("Package name (Android) or bundle ID (iOS)"),
      },
    },
    async ({ device_id, package: pkg }) => {
      try {
        const result = await hubPost<ActionResult>(`/devices/${device_id}/launch`, {
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
