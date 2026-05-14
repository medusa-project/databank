// @ts-check
import { test, expect } from "@playwright/test";

test("root path contains Illinois Data Bank", async ({ page }) => {
  const baseUrl = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:3000";

  await page.goto(baseUrl);
  await expect(page.locator("body")).toContainText("Illinois Data Bank");
});
