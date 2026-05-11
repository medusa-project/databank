// @ts-check
import { test, expect } from "@playwright/test";

const baseUrl = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:3000";

test.describe("anonymous deposit access", () => {
  test("deposit link takes anonymous user to pre_deposit page", async ({ page }) => {
    await page.goto(baseUrl);
    await page.click("#deposit_link");
    await expect(page).toHaveURL(/\/datasets\/pre_deposit/);
  });

  test("cancel from pre_deposit returns anonymous user to root", async ({ page }) => {
    await page.goto(`${baseUrl}/datasets/pre_deposit`);
    await expect(page.locator("#cancel-button")).toBeVisible();
    await page.click("#cancel-button");
    await expect(page).toHaveURL(`${baseUrl}/`);
  });

  test("continue from pre_deposit shows restricted access and login prompt", async ({
    page,
  }) => {
    await page.goto(`${baseUrl}/datasets/pre_deposit`);
    await expect(page.locator("#continue-button")).toBeVisible();

    await page.click("#continue-button");

    await expect(page).toHaveURL(/\/datasets\/new/);
    await expect(page.locator("body")).toContainText("Restricted Access");
    await expect(page.getByRole("button", { name: "Log in" })).toBeVisible();
  });
});
