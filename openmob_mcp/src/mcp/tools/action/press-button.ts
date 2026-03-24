import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import type { ActionResult } from "../../../types/index.js";

export function registerPressButton(server: McpServer, hub: HubClient): void {
  server.registerTool(
    "press_button",
    {
      description:
        "Press a hardware or soft button on the device. Common key codes: 3=Home, 4=Back, 24=VolumeUp, 25=VolumeDown, 26=Power, 66=Enter, 82=Menu, 187=RecentApps.",
      inputSchema: {
        device_id: deviceIdSchema,
        key_code: z
          .number()
          .describe("Android key code (e.g., 3 for Home, 4 for Back, 26 for Power)"),
      },
    },
    async ({ device_id, key_code }) => {
      try {
        const result = await hub.post<ActionResult>(`/devices/${device_id}/keyevent`, {
          keyCode: key_code,
        });
        return createTextResponse(result);
      } catch (error) {
        return createErrorResponse(error);
      }
    }
  );
}
