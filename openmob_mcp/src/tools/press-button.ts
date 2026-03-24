import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { hubPost } from "../hub-client.js";
import type { ActionResult } from "../types.js";

export function registerPressButton(server: McpServer): void {
  server.registerTool(
    "press_button",
    {
      description:
        "Press a hardware or soft button on the device. Common key codes: 3=Home, 4=Back, 24=VolumeUp, 25=VolumeDown, 26=Power, 66=Enter, 82=Menu, 187=RecentApps.",
      inputSchema: {
        device_id: z.string().describe("Device ID"),
        key_code: z
          .number()
          .describe("Android key code (e.g., 3 for Home, 4 for Back, 26 for Power)"),
      },
    },
    async ({ device_id, key_code }) => {
      try {
        const result = await hubPost<ActionResult>(`/devices/${device_id}/keyevent`, {
          keyCode: key_code,
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
