import { test, expect } from "@playwright/test";
import { BASE_URL } from "./helpers/config.js";

test.describe("help pages workflow", () => {
  test("policies page renders help sidebar and in-page anchors", async ({
    page,
  }) => {
    await page.goto(`${BASE_URL}/policies`);

    await expect(
      page.getByRole("heading", {
        name: /Illinois Data Bank Policy Framework and Definitions/i,
      }),
    ).toBeVisible();
    await expect(page.locator(".bs-docs-sidebar")).toBeVisible();
    await expect(page.locator("#sidebar")).toBeVisible();

    const accessLink = page.locator('#sidebar a[href="#access_and_use"]');
    await expect(accessLink).toBeVisible();
    await accessLink.click();

    await expect(page).toHaveURL(/#access_and_use$/);
  });

  test("guides page renders help sidebar and in-page anchors", async ({
    page,
  }) => {
    await page.goto(`${BASE_URL}/guides`);

    await expect(
      page.getByRole("heading", {
        name: "Guides",
        exact: true,
      }),
    ).toBeVisible();
    await expect(page.locator(".bs-docs-sidebar")).toBeVisible();
    await expect(page.locator("#sidebar")).toHaveCount(1);
    await expect(page.locator("#help-layout")).toBeVisible();
  });
});
