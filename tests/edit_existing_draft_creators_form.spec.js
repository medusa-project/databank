import { test, expect } from "@playwright/test";
import { BASE_URL } from "./helpers/config.js";

async function loginAsDeveloperUser(page, { name, email, role }) {
  await page.goto(`${BASE_URL}/auth/developer`);
  await page.fill("#email", email);
  await page.fill("#name", name);
  await page.selectOption('select[name="role"]', role);

  await Promise.all([
    page.waitForLoadState("networkidle"),
    page.getByRole("button", { name: "Sign in" }).click(),
  ]);
}

test.describe("draft edit creators form", () => {
  test("existing draft edit view shows creators form", async ({ page }) => {
    await loginAsDeveloperUser(page, {
      name: "Researcher1",
      email: "researcher1@mailinator.com",
      role: "depositor",
    });

    await page.goto(`${BASE_URL}/datasets/pre_deposit`);
    await page.locator("#continue-button").click();

    await expect(
      page.getByRole("heading", { name: "Deposit Agreement", exact: true }),
    ).toBeVisible();

    await page.locator("#owner-yes").check();
    await page.locator("#private-na").check();
    await page.locator("#agree-yes").check();
    await page.locator("#agree-button").click();

    await expect(page).toHaveURL(/\/datasets\/[^/]+\/edit/);
    const datasetKeyMatch = page.url().match(/\/datasets\/([^/]+)\/edit/);
    expect(datasetKeyMatch).not.toBeNull();
    const datasetKey = datasetKeyMatch[1];

    // Persist at least one metadata field so this is an existing draft dataset.
    await page.fill("#dataset_title", `Playwright creator form ${Date.now()}`);

    await Promise.all([
      page.waitForURL(new RegExp(`/datasets/${datasetKey}(\\?.*)?$`)),
      page.locator("#update-save-button").click(),
    ]);

    await page.goto(`${BASE_URL}/datasets/${datasetKey}/edit`);
    await expect(page).toHaveURL(
      new RegExp(`/datasets/${datasetKey}/edit(\\?.*)?$`),
    );

    await expect(page.locator("#creator_table")).toBeVisible();
    await expect(page.locator("#creator_table tbody tr").first()).toBeVisible();

    const creatorNameField = page.locator(
      "#creator_table tbody tr input[id$='_family_name'], #creator_table tbody tr input[id$='_institution_name']",
    );
    await expect(creatorNameField.first()).toBeVisible();
  });

  test("existing draft edit view shows organizational creators form after toggle", async ({
    page,
  }) => {
    await loginAsDeveloperUser(page, {
      name: "Curator1",
      email: "curator1@mailinator.com",
      role: "admin",
    });

    await page.goto(`${BASE_URL}/datasets/pre_deposit`);
    await page.locator("#continue-button").click();

    await expect(
      page.getByRole("heading", { name: "Deposit Agreement", exact: true }),
    ).toBeVisible();

    await page.locator("#owner-yes").check();
    await page.locator("#private-na").check();
    await page.locator("#agree-yes").check();
    await page.locator("#agree-button").click();

    await expect(page).toHaveURL(/\/datasets\/[^/]+\/edit/);
    const datasetKeyMatch = page.url().match(/\/datasets\/([^/]+)\/edit/);
    expect(datasetKeyMatch).not.toBeNull();
    const datasetKey = datasetKeyMatch[1];

    await page.fill(
      "#dataset_title",
      `Playwright org creator form ${Date.now()}`,
    );

    // Add a creator row with sample data to ensure dataset has valid creator for conversion
    const creatorFamilyNameInputs = page.locator(
      "#creator_table tbody tr input[id$='_family_name']",
    );
    if ((await creatorFamilyNameInputs.count()) > 0) {
      await creatorFamilyNameInputs.first().fill("TestFamily");
    }
    const creatorGivenNameInputs = page.locator(
      "#creator_table tbody tr input[id$='_given_name']",
    );
    if ((await creatorGivenNameInputs.count()) > 0) {
      await creatorGivenNameInputs.first().fill("TestGiven");
    }

    // Save dataset before toggling to avoid unsaved changes during conversion
    await page.locator("#update-save-button").click();
    await page.waitForLoadState("networkidle");

    // Ensure we're on the edit page after save
    await page.goto(`${BASE_URL}/datasets/${datasetKey}/edit`);
    await page.waitForLoadState("networkidle");

    const switchToOrgButton = page.getByRole("button", {
      name: /Switch to Organization Creators/i,
    });
    await expect(switchToOrgButton).toBeVisible();

    page.once("dialog", async (dialog) => {
      await dialog.accept();
    });

    await switchToOrgButton.click();
    await page.waitForLoadState("networkidle");

    // After toggle, the form submission redirects back to edit page automatically
    // Don't navigate again - just check the current page state
    await expect(page).toHaveURL(
      new RegExp(`/datasets/${datasetKey}/edit(\\?.*)?$`),
    );

    await expect(page.locator("#dataset_org_creators")).toHaveValue("true");
    await expect(page.locator("#creator_table")).toBeVisible();
    await expect(page.locator("#creator_table tbody tr").first()).toBeVisible();
    await expect(
      page
        .locator("#creator_table tbody tr input[id$='_institution_name']")
        .first(),
    ).toBeVisible();
  });
});
