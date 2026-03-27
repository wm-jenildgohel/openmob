import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import { registerToolDual } from "../../common/dual-register.js";
import type { ActionResult } from "../../../types/index.js";

export function registerGoHome(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "go_home",
    {
      description:
        "Navigate to the device home screen. Equivalent to pressing the physical Home button. " +
        "Use this to reset navigation, exit an app, or return to a known starting point. " +
        "Returns: Confirmation that the home screen is now showing. " +
        "Related: press_button (press any hardware button), launch_app (open a specific app), get_screenshot (verify home screen).",
      inputSchema: {
        device_id: deviceIdSchema,
      },
    },
    async ({ device_id }) => {
      try {
        const result = await hub.post<ActionResult>(`/devices/${device_id}/keyevent`, {
          keyCode: 3,
        });
        return createTextResponse(result, "Navigated to the home screen");
      } catch (error) {
        return createErrorResponse(error, "Could not go to home screen — check device connection");
      }
    }
  );
}
