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
        "Run a test on the device — provide a name and a sequence of steps (tap, type, swipe, etc.) with optional checks after each step. " +
        "Returns whether the test passed or failed, with timing and screenshots of any failures. " +
        "Great for verifying login flows, form submissions, navigation, or any user journey.",
      inputSchema: {
        device_id: deviceIdSchema,
        name: z.string().describe("A descriptive name for this test (e.g., 'Login with valid credentials')"),
        steps: z
          .array(
            z.object({
              action: z
                .string()
                .describe(
                  "What to do: tap, swipe, type_text, press_key, launch_app, " +
                  "terminate_app, open_url, go_home, wait"
                ),
              params: z
                .record(z.unknown())
                .describe("Settings for the action (x, y, text, package, url, duration, etc.)"),
              assertion: z
                .object({
                  type: z
                    .string()
                    .describe("What to check: element_exists (look for an element), element_text (check text content), screenshot_match, none"),
                })
                .passthrough()
                .optional()
                .describe("Optional check to verify the action worked"),
              description: z
                .string()
                .optional()
                .describe("What this step does in plain English (e.g., 'Tap the Login button')"),
            })
          )
          .describe("Steps to perform in order"),
      },
    },
    async ({ device_id, name, steps }) => {
      try {
        const script = await hub.post<{ id: string }>("/tests/", {
          name,
          device_id: device_id,
          steps,
        });
        const result = await hub.post<TestResult>(`/tests/${script.id}/run`, {});

        const passed = result.status === "passed";
        const summary = passed
          ? `Test "${name}" passed — all ${steps.length} steps completed successfully in ${result.duration || "?"}ms`
          : `Test "${name}" failed at step ${result.failedStep || "?"}: ${result.failureReason || "Unknown error"}`;

        return createTextResponse(result, summary);
      } catch (error) {
        return createErrorResponse(error, `Could not run test "${name}" — check if the device is connected and the app is open`);
      }
    }
  );
}
