import { test, expect } from "@playwright/test";
import { authStatePath } from "./helpers/auth-state.js";
import {
  goToDepositAgreement,
  submitDepositAgreement,
} from "./helpers/deposit-flow.js";

test.describe("authenticated depositor funders workflow", () => {
  test.use({ storageState: authStatePath("depositor") });

  async function goToDatasetEdit(page) {
    await goToDepositAgreement(page);

    await submitDepositAgreement(page, {
      owner: "yes",
      removedPrivate: "na",
      agree: "yes",
    });

    await expect(page).toHaveURL(/\/datasets\/[^/]+\/edit/);

    const funderAccordion = page.getByRole("button", { name: /Funder/i });
    await expect(funderAccordion).toBeVisible();
    await funderAccordion.click();

    await expect(page.locator("#funder_table")).toBeVisible();
  }

  test("add and remove funder rows updates table and action buttons", async ({
    page,
  }) => {
    await goToDatasetEdit(page);

    const rows = page.locator("#funder_table tbody tr");
    const addButton = page.locator("#funder_table button.btn-success", {
      hasText: "Add",
    });

    const beforeCount = await rows.count();
    await expect(addButton).toBeVisible();

    await addButton.click();
    await expect(rows).toHaveCount(beforeCount + 1);

    const removeButtons = page.locator("#funder_table button.btn-danger", {
      hasText: "Remove",
    });
    await removeButtons.last().click();

    await expect(rows).toHaveCount(beforeCount);
  });

  test("selecting a standard funder fills name and identifier fields", async ({
    page,
  }) => {
    await goToDatasetEdit(page);

    await page.selectOption("#dataset_funders_attributes_0_code", "NSF");

    await expect(
      page.locator("#dataset_funders_attributes_0_name"),
    ).toHaveValue("U.S. National Science Foundation (NSF)");
    await expect(
      page.locator("#dataset_funders_attributes_0_identifier"),
    ).toHaveValue("10.13039/100000001");
    await expect(
      page.locator("#dataset_funders_attributes_0_identifier_scheme"),
    ).toHaveValue("DOI");
  });

  test("selecting other reveals custom funder name input", async ({ page }) => {
    await goToDatasetEdit(page);

    const funderNameInput = page.locator("#dataset_funders_attributes_0_name");
    await page.selectOption("#dataset_funders_attributes_0_code", "other");

    await expect(funderNameInput).toBeVisible();
    await expect(funderNameInput).toBeFocused();

    await funderNameInput.fill("Example Research Sponsor");
    await expect(funderNameInput).toHaveValue("Example Research Sponsor");
    await expect(
      page.locator("#dataset_funders_attributes_0_identifier"),
    ).toHaveValue("");
    await expect(
      page.locator("#dataset_funders_attributes_0_identifier_scheme"),
    ).toHaveValue("");
  });
});
