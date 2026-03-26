import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema } from "../../common/schemas.js";
import { createImageResponse, createErrorResponse } from "../../common/response.js";
import { registerToolDual } from "../../common/dual-register.js";
import type { ScreenshotResult } from "../../../types/index.js";

export function registerGetScreenshot(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "get_screenshot",
    {
      description:
        "Take a screenshot of what's currently shown on the device screen. Returns the image so you can see exactly what the user sees. Use this to verify UI state, check if an action worked, or see what's on screen before deciding what to do next.",
      inputSchema: {
        device_id: deviceIdSchema,
      },
    },
    async ({ device_id }) => {
      try {
        const data = await hub.get<ScreenshotResult>(`/devices/${device_id}/screenshot`);
        return createImageResponse(
          data.screenshot,
          "image/png",
          `Captured screenshot (${data.width}x${data.height})`
        );
      } catch (error) {
        return createErrorResponse(error, "Could not take screenshot — the device screen may be off");
      }
    }
  );
}
