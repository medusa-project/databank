import { test, expect } from "@playwright/test";
import { authStatePath } from "./helpers/auth-state.js";
import { BASE_URL } from "./helpers/config.js";

test.describe("authenticated admin flow", () => {
  test.use({ storageState: authStatePath("admin") });

  test("admin sees Curator and Admin Dashboard link on home", async ({
    page,
  }) => {
    await page.goto(BASE_URL);

    await expect(
      page.getByRole("link", { name: /Curator and Admin Dashboard/i }),
    ).toBeVisible();
  });
});

test.describe("authenticated guest flow", () => {
  test.use({ storageState: authStatePath("guest") });

  test("guest is shown restricted access when continuing to dataset form", async ({
    page,
  }) => {
    await page.goto(`${BASE_URL}/datasets/pre_deposit`);
    await page.click("#continue-button");

    await expect(page).toHaveURL(/\/datasets\/new/);
    await expect(page.locator("body")).toContainText("Restricted Access");
  });
});

test.describe("authenticated no_deposit flow", () => {
  test.use({ storageState: authStatePath("no_deposit") });

  test("no_deposit user is redirected and shown eligibility warning", async ({
    page,
  }) => {
    await page.goto(`${BASE_URL}/datasets/pre_deposit`);
    await page.click("#continue-button");

    await expect(page).toHaveURL(/\/datasets\/pre_deposit/);
    await expect(page.locator("body")).toContainText(
      "ACCOUNT NOT ELIGIBLE TO DEPOSIT DATA",
    );
  });
});
