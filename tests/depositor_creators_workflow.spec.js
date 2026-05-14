import { test, expect } from "@playwright/test";
import { authStatePath } from "./helpers/auth-state.js";
import {
  goToDepositAgreement,
  submitDepositAgreement,
} from "./helpers/deposit-flow.js";

test.describe("authenticated depositor creators workflow", () => {
  test.use({ storageState: authStatePath("depositor") });

  async function goToDatasetEdit(page) {
    await goToDepositAgreement(page);

    await submitDepositAgreement(page, {
      owner: "yes",
      removedPrivate: "na",
      agree: "yes",
    });

    await expect(page).toHaveURL(/\/datasets\/[^/]+\/edit/);
    await expect(page.locator("#creator_table")).toBeVisible();
  }

  test("add and remove creator rows updates table and action buttons", async ({
    page,
  }) => {
    await goToDatasetEdit(page);

    const rows = page.locator("#creator_table tbody tr");
    const addButton = page.locator("#creator_table button.btn-success", {
      hasText: "Add",
    });

    const beforeCount = await rows.count();
    await expect(addButton).toBeVisible();

    await addButton.click();
    await expect(rows).toHaveCount(beforeCount + 1);

    const removeButtons = page.locator("#creator_table button.btn-danger", {
      hasText: "Remove",
    });
    await removeButtons.last().click();

    await expect(rows).toHaveCount(beforeCount);
  });

  test("creator preview updates from family and given name", async ({
    page,
  }) => {
    await goToDatasetEdit(page);

    await page.fill("#dataset_creators_attributes_0_family_name", "Curie");
    await page.fill("#dataset_creators_attributes_0_given_name", "Marie");
    await page.locator("#dataset_creators_attributes_0_given_name").blur();

    await expect(page.locator("#creator-preview")).toContainText(
      "Curie, Marie",
    );
  });

  test("primary contact radio updates hidden is_contact fields", async ({
    page,
  }) => {
    await goToDatasetEdit(page);

    await page
      .locator("#creator_table button.btn-success", { hasText: "Add" })
      .click();

    await page.locator("input.contact_radio[value='1']").check();

    await expect(
      page.locator("#dataset_creators_attributes_1_is_contact"),
    ).toHaveValue("true");
    await expect(
      page.locator("#dataset_creators_attributes_0_is_contact"),
    ).toHaveValue("false");
  });
});
