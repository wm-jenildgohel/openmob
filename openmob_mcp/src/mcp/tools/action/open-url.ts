import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import { registerToolDual } from "../../common/dual-register.js";
import type { ActionResult } from "../../../types/index.js";

export function registerOpenUrl(server: McpServer, hub: HubClient): void {
  registerToolDual(server,
    "open_url",
    {
      description:
        "Open a website or deep link on the device — opens in the default browser or the app that handles that link.",
      inputSchema: {
        device_id: deviceIdSchema,
        url: z.string().describe("Web URL (https://...) or deep link (myapp://...)"),
      },
    },
    async ({ device_id, url }) => {
      try {
        const result = await hub.post<ActionResult>(`/devices/${device_id}/open-url`, { url });

        let summary: string;
        try {
          const parsed = new URL(url);
          if (parsed.protocol.startsWith("http")) {
            summary = `Opened ${parsed.hostname} in the browser`;
          } else {
            summary = `Opened deep link: ${parsed.protocol}//${parsed.hostname || parsed.pathname}`;
          }
        } catch {
          summary = `Opened: ${url}`;
        }

        return createTextResponse(result, summary);
      } catch (error) {
        return createErrorResponse(error, "Could not open the link — check if the URL is valid");
      }
    }
  );
}
