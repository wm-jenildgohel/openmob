import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import type { ActionResult } from "../../../types/index.js";

export function registerOpenUrl(server: McpServer, hub: HubClient): void {
  server.registerTool(
    "open_url",
    {
      description:
        "Open a URL or deep link on the device in the default browser or app handler.",
      inputSchema: {
        device_id: deviceIdSchema,
        url: z.string().describe("URL or deep link to open"),
      },
    },
    async ({ device_id, url }) => {
      try {
        const result = await hub.post<ActionResult>(`/devices/${device_id}/open-url`, { url });
        return createTextResponse(result);
      } catch (error) {
        return createErrorResponse(error);
      }
    }
  );
}
