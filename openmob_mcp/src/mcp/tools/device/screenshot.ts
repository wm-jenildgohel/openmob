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
        "Capture the device screen as an image. Returns the actual screenshot so you can visually see what the user sees. " +
        "Use this AFTER every action (tap, swipe, type_text) to verify it worked. " +
        "Use this BEFORE deciding what to do next to understand the current screen state. " +
        "Returns: PNG image of the screen plus dimensions. " +
        "Related: get_ui_tree (read element text/positions), save_screenshot (save to file instead).",
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
