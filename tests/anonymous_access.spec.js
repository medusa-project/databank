// @ts-check
import { test, expect } from "@playwright/test";
import { BASE_URL } from "./helpers/config.js";
import { continueFromPreDeposit } from "./helpers/deposit-flow.js";

test.describe("anonymous deposit access", () => {
  test("deposit link takes anonymous user to pre_deposit page", async ({
    page,
  }) => {
    await page.goto(BASE_URL);
    await page.click("#deposit_link");
    await expect(page).toHaveURL(/\/datasets\/pre_deposit/);
  });

  test("cancel from pre_deposit returns anonymous user to root", async ({
    page,
  }) => {
    await page.goto(`${BASE_URL}/datasets/pre_deposit`);
    await expect(page.locator("#cancel-button")).toBeVisible();
    await page.click("#cancel-button");
    await expect(page).toHaveURL(`${BASE_URL}/`);
  });

  test("continue from pre_deposit shows restricted access and login prompt", async ({
    page,
  }) => {
    await continueFromPreDeposit(page);

    await expect(page).toHaveURL(/\/datasets\/new/);
    await expect(page.locator("body")).toContainText("Restricted Access");
    await expect(page.getByRole("button", { name: "Log in" })).toBeVisible();
  });
});
