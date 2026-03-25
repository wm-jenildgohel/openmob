import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import type { ActionResult } from "../../../types/index.js";

export function registerTypeText(server: McpServer, hub: HubClient): void {
  server.registerTool(
    "type_text",
    {
      description: "Type text into the currently focused input field on the device — like typing on the keyboard. First tap a text field to focus it, then use this to enter text.",
      inputSchema: {
        device_id: deviceIdSchema,
        text: z.string().describe("Text to type into the focused field"),
      },
    },
    async ({ device_id, text }) => {
      try {
        const result = await hub.post<ActionResult>(`/devices/${device_id}/type`, { text });
        const preview = text.length > 30 ? text.substring(0, 30) + "..." : text;
        return createTextResponse(result, `Typed "${preview}" into the input field`);
      } catch (error) {
        return createErrorResponse(error, "Could not type text — make sure an input field is focused first");
      }
    }
  );
}
