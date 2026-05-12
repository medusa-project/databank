import { test, expect } from "@playwright/test";
import { authStatePath } from "./helpers/auth-state.js";

const baseUrl = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:3000";

test.use({ storageState: authStatePath("depositor") });

test("probe deposit agreement page", async ({ page }) => {
  await page.goto(`${baseUrl}/datasets/pre_deposit`);
  await page.click("#continue-button");
  await page.waitForURL(/\/datasets\/new/);

  await page.waitForLoadState("domcontentloaded");
  await expect(
    page.getByRole("heading", { name: "Deposit Agreement", exact: true }),
  ).toBeVisible();
  await expect(page.locator("#agree-form")).toBeVisible();
  await expect(page.locator("#owner-yes")).toBeVisible();
});
