import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import { registerToolDual } from "../../common/dual-register.js";
import type { ActionResult } from "../../../types/index.js";

export function registerTypeText(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "type_text",
    {
      description:
        "Type text into the currently focused input field on the device. You MUST tap a text field first to focus it before calling this. " +
        "Set submit=true to press Enter/Return after typing (useful for search boxes, login forms, chat messages). " +
        "For special characters or emojis, the device's keyboard encoding is used. " +
        "Returns: Confirmation of what was typed and whether Enter was pressed. " +
        "Related: tap (focus a field first), get_ui_tree (find input fields), press_button (press Enter separately with key_code=66).",
      inputSchema: {
        device_id: deviceIdSchema,
        text: z.string().describe("Text to type into the focused field"),
        submit: z.boolean().optional().describe("Press Enter after typing (default: false). Useful for search boxes and form submissions."),
      },
    },
    async ({ device_id, text, submit }) => {
      try {
        const result = await hub.post<ActionResult>(`/devices/${device_id}/type`, { text, submit: submit ?? false });
        const preview = text.length > 30 ? text.substring(0, 30) + "..." : text;
        const suffix = submit ? " and pressed Enter" : "";
        return createTextResponse(result, `Typed "${preview}" into the input field${suffix}`);
      } catch (error) {
        return createErrorResponse(error, "Could not type text — make sure an input field is focused first");
      }
    }
  );
}
