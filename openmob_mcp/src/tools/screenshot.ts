import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { hubGet } from "../hub-client.js";
import type { ScreenshotResult } from "../types.js";

export function registerGetScreenshot(server: McpServer): void {
  server.registerTool(
    "get_screenshot",
    {
      description:
        "Capture a screenshot from the specified device. Returns the screenshot as an image that can be viewed directly.",
      inputSchema: {
        device_id: z.string().describe("Device ID from list_devices"),
      },
    },
    async ({ device_id }) => {
      try {
        const data = await hubGet<ScreenshotResult>(`/devices/${device_id}/screenshot`);
        return {
          content: [
            {
              type: "image" as const,
              data: data.screenshot,
              mimeType: "image/png",
            },
          ],
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
