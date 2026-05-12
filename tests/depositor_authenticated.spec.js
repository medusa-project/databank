import { test, expect } from "@playwright/test";
import { authStatePath } from "./helpers/auth-state.js";

const baseUrl = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:3000";

test.describe("authenticated depositor flow", () => {
  test.use({ storageState: authStatePath("depositor") });

  async function goToDepositAgreement(page) {
    await page.goto(`${baseUrl}/datasets/pre_deposit`);
    await expect(page.locator("#continue-button")).toBeVisible();
    await page.click("#continue-button");
    await expect(page).toHaveURL(/\/datasets\/new/);
    await expect(
      page.getByRole("heading", { name: "Deposit Agreement", exact: true }),
    ).toBeVisible();
    await expect(page.locator("#agree-form")).toBeVisible();
    await expect(page.locator("#owner-yes")).toBeVisible();
  }

  test("continue from pre-deposit goes to dataset form without login prompt", async ({
    page,
  }) => {
    await goToDepositAgreement(page);
  });

  test("deposit agreement radio handlers update warning, hidden fields, and submit enablement", async ({
    page,
  }) => {
    await goToDepositAgreement(page);

    const warning = page.locator(".deposit-agreement-selection-warning");
    const agreeButton = page.getByRole("button", { name: "Submit" });
    const havePermission = page.locator("#dataset_have_permission");
    const removedPrivate = page.locator("#dataset_removed_private");
    const agreeValue = page.locator("#dataset_agree");

    await expect(agreeButton).toBeDisabled();

    await page.locator("#owner-no").check();
    await expect(havePermission).toHaveValue("no");
    await expect(warning).toContainText("Selection Alert");

    await page.locator("#owner-yes").check();
    await expect(havePermission).toHaveValue("yes");
    await expect(warning).not.toContainText("Selection Alert");

    await page.locator("#private-no").check();
    await expect(removedPrivate).toHaveValue("no");
    await expect(warning).toContainText("Selection Alert");

    await page.locator("#private-yes").check();
    await expect(removedPrivate).toHaveValue("yes");
    await expect(page.locator("#private-no")).not.toBeChecked();
    await expect(page.locator("#private-na")).not.toBeChecked();
    await expect(warning).not.toContainText("Selection Alert");

    await page.locator("#agree-no").check();
    await expect(agreeValue).toHaveValue("no");
    await expect(warning).toContainText("Selection Alert");
    await expect(agreeButton).toBeDisabled();

    await page.locator("#agree-yes").check();
    await expect(agreeValue).toHaveValue("yes");
    await expect(page.locator("#agree-no")).not.toBeChecked();
    await expect(warning).not.toContainText("Selection Alert");
    await expect(agreeButton).toBeEnabled();
  });

  test("private-not-applicable path can also enable submit", async ({
    page,
  }) => {
    await goToDepositAgreement(page);

    const agreeButton = page.getByRole("button", { name: "Submit" });
    const removedPrivate = page.locator("#dataset_removed_private");

    await page.locator("#owner-yes").check();
    await page.locator("#private-na").check();
    await page.locator("#agree-yes").check();

    await expect(removedPrivate).toHaveValue("na");
    await expect(page.locator("#private-yes")).not.toBeChecked();
    await expect(page.locator("#private-no")).not.toBeChecked();
    await expect(agreeButton).toBeEnabled();
  });

  test("submitting valid deposit agreement navigates to dataset edit form", async ({
    page,
  }) => {
    await goToDepositAgreement(page);

    await page.locator("#owner-yes").check();
    await page.locator("#private-na").check();
    await page.locator("#agree-yes").check();

    const agreeButton = page.getByRole("button", { name: "Submit" });
    await expect(agreeButton).toBeEnabled();
    await agreeButton.click();

    await expect(page).toHaveURL(/\/datasets\/[^/]+\/edit/);
    await expect(page.locator("#dataset_title")).toBeVisible();
    await expect(page.locator("form.dataset-form")).toBeVisible();
  });
});
