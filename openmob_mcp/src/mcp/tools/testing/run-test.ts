import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import type { HubClient } from "../../common/hub-client.js";
import { deviceIdSchema } from "../../common/schemas.js";
import { createTextResponse, createErrorResponse } from "../../common/response.js";
import type { TestResult } from "../../../types/index.js";

export function registerRunTest(server: McpServer, hub: HubClient): void {
  server.registerTool(
    "run_test",
    {
      description:
        "Execute a test scenario on a device. Provide a sequence of actions " +
        "(tap, swipe, type_text, press_key, launch_app, go_home, wait, etc.) " +
        "with optional assertions. Returns structured pass/fail results with " +
        "timing and failure screenshots.",
      inputSchema: {
        device_id: deviceIdSchema,
        name: z.string().describe("Test name for identification"),
        steps: z
          .array(
            z.object({
              action: z
                .string()
                .describe(
                  "Action: tap, swipe, type_text, press_key, launch_app, " +
                  "terminate_app, open_url, go_home, gesture, wait"
                ),
              params: z
                .record(z.unknown())
                .describe("Action parameters (x, y, text, package, url, duration, etc.)"),
              assertion: z
                .object({
                  type: z
                    .string()
                    .describe(
                      "Assertion type: element_exists, element_text, screenshot_match, none"
                    ),
                })
                .passthrough()
                .optional()
                .describe("Optional assertion to verify after action"),
              description: z
                .string()
                .optional()
                .describe("Human-readable step description"),
            })
          )
          .describe("Ordered list of test steps to execute"),
      },
    },
    async ({ device_id, name, steps }) => {
      try {
        const script = await hub.post<{ id: string }>("/tests/", {
          name,
          deviceId: device_id,
          steps,
        });
        const result = await hub.post<TestResult>(`/tests/${script.id}/run`, {});
        return createTextResponse(result);
      } catch (error) {
        return createErrorResponse(error);
      }
    }
  );
}
