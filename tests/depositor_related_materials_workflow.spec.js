import { test, expect } from "@playwright/test";
import { authStatePath } from "./helpers/auth-state.js";
import {
  goToDepositAgreement,
  submitDepositAgreement,
} from "./helpers/deposit-flow.js";

test.describe("authenticated depositor related materials workflow", () => {
  test.use({ storageState: authStatePath("depositor") });

  async function goToDatasetEdit(page) {
    await goToDepositAgreement(page);

    await submitDepositAgreement(page, {
      owner: "yes",
      removedPrivate: "na",
      agree: "yes",
    });

    await expect(page).toHaveURL(/\/datasets\/[^/]+\/edit/);

    const materialsAccordion = page.getByRole("button", {
      name: /Relationships with articles, code, other datasets/i,
    });
    await expect(materialsAccordion).toBeVisible();
    await materialsAccordion.click();

    await expect(page.locator("#material_table")).toBeVisible();
  }

  test("add and remove related material rows updates table and action buttons", async ({
    page,
  }) => {
    await goToDatasetEdit(page);

    const rows = page.locator("#material_table tbody tr.item");
    const addButton = page.locator("#material_table button.btn-success", {
      hasText: "Add",
    });

    const beforeCount = await rows.count();
    await expect(addButton).toBeVisible();

    await addButton.click();
    await expect(rows).toHaveCount(beforeCount + 1);

    const removeButtons = page.locator("#material_table button.btn-danger", {
      hasText: "Remove",
    });
    await removeButtons.last().click();

    await expect(rows).toHaveCount(beforeCount);
  });

  test("selecting article keeps material type in hidden field", async ({
    page,
  }) => {
    await goToDatasetEdit(page);

    await page.selectOption(
      "#dataset_related_materials_attributes_0_selected_type",
      "Article",
    );

    await expect(
      page.locator("#dataset_related_materials_attributes_0_material_type"),
    ).toHaveValue("Article");
  });

  test("selecting other replaces hidden field with visible custom type input", async ({
    page,
  }) => {
    await goToDatasetEdit(page);

    await page.selectOption(
      "#dataset_related_materials_attributes_0_selected_type",
      "Other",
    );

    const materialTypeInput = page.locator(
      "#dataset_related_materials_attributes_0_material_type",
    );
    await expect(materialTypeInput).toBeVisible();
    await expect(materialTypeInput).toBeFocused();

    await materialTypeInput.fill("Protocol");
    await expect(materialTypeInput).toHaveValue("Protocol");
  });
});
