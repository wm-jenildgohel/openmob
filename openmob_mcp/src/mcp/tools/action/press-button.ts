import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import { registerToolDual } from "../../common/dual-register.js";
import type { ActionResult } from "../../../types/index.js";

const KEY_NAMES: Record<number, string> = {
  3: "Home",
  4: "Back",
  24: "Volume Up",
  25: "Volume Down",
  26: "Power",
  66: "Enter",
  82: "Menu",
  187: "Recent Apps",
};

export function registerPressButton(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "press_button",
    {
      description:
        "Press a device button — Home (3), Back (4), Volume Up (24), Volume Down (25), Power (26), Enter (66), Menu (82), Recent Apps (187). Use the key number.",
      inputSchema: {
        device_id: deviceIdSchema,
        key_code: z.number().describe("Button to press: 3=Home, 4=Back, 24=VolumeUp, 25=VolumeDown, 26=Power, 66=Enter"),
      },
    },
    async ({ device_id, key_code }) => {
      try {
        const result = await hub.post<ActionResult>(`/devices/${device_id}/keyevent`, {
          keyCode: key_code,
        });
        const keyName = KEY_NAMES[key_code] || `key ${key_code}`;
        return createTextResponse(result, `Pressed the ${keyName} button`);
      } catch (error) {
        return createErrorResponse(error, "Could not press the button — check device connection");
      }
    }
  );
}
