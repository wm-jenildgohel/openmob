import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema } from "../../common/schemas.js";
import { createImageResponse, createErrorResponse } from "../../common/response.js";
import type { ScreenshotResult } from "../../../types/index.js";

export function registerGetScreenshot(server: McpServer, hub: HubClient): void {
  server.registerTool(
    "get_screenshot",
    {
      description:
        "Capture a screenshot from the specified device. Returns the screenshot as an image that can be viewed directly.",
      inputSchema: {
        device_id: deviceIdSchema,
      },
    },
    async ({ device_id }) => {
      try {
        const data = await hub.get<ScreenshotResult>(`/devices/${device_id}/screenshot`);
        return createImageResponse(data.screenshot, "image/png");
      } catch (error) {
        return createErrorResponse(error);
      }
    }
  );
}
