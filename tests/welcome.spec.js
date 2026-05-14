// @ts-check
import { test, expect } from "@playwright/test";
import { BASE_URL } from "./helpers/config.js";

test("root path contains Illinois Data Bank", async ({ page }) => {
  await page.goto(BASE_URL);
  await expect(page.locator("body")).toContainText("Illinois Data Bank");
});
