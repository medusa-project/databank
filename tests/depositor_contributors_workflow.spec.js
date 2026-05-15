import { test, expect } from "@playwright/test";
import { authStatePath } from "./helpers/auth-state.js";
import {
  goToDepositAgreement,
  submitDepositAgreement,
} from "./helpers/deposit-flow.js";

test.describe("authenticated contributors workflow", () => {
  test.use({ storageState: authStatePath("admin") });

  async function goToDatasetEdit(page) {
    await goToDepositAgreement(page);

    await submitDepositAgreement(page, {
      owner: "yes",
      removedPrivate: "na",
      agree: "yes",
    });

    await expect(page).toHaveURL(/\/datasets\/[^/]+\/edit/);
    await expect(
      page.locator("#creator_table, #contributor_table").first(),
    ).toBeVisible();
  }

  async function currentAuthorTable(page) {
    if (await page.locator("#contributor_table").count()) {
      return "#contributor_table";
    }
    return "#creator_table";
  }

  test("add and remove contributor rows updates table and action buttons", async ({
    page,
  }) => {
    await goToDatasetEdit(page);

    const tableSelector = await currentAuthorTable(page);
    const rows = page.locator(`${tableSelector} tbody tr`);
    const addButton = page.locator(`${tableSelector} button.btn-success`, {
      hasText: "Add",
    });

    const beforeCount = await rows.count();
    await expect(addButton).toBeVisible();

    await addButton.click();
    await expect(rows).toHaveCount(beforeCount + 1);

    const removeButtons = page.locator(`${tableSelector} button.btn-danger`, {
      hasText: "Remove",
    });
    await removeButtons.last().click();

    await expect(rows).toHaveCount(beforeCount);
  });

  test("orcid contributor modal opens and supports search input", async ({
    page,
  }) => {
    await goToDatasetEdit(page);

    const tableSelector = await currentAuthorTable(page);
    const isContributorMode = tableSelector === "#contributor_table";
    const modalSelector = isContributorMode
      ? "#orcid_contributor_search"
      : "#orcid_creator_search";
    const familyInputSelector = isContributorMode
      ? "#contributor-family"
      : "#creator-family";
    const givenInputSelector = isContributorMode
      ? "#contributor-given"
      : "#creator-given";

    const lookUpButton = page
      .locator(`${tableSelector} .orcid-search-btn`)
      .first();
    await expect(lookUpButton).toBeVisible();
    await lookUpButton.click();

    await expect(page.locator(modalSelector)).toBeVisible();
    await expect(page.locator(familyInputSelector)).toBeVisible();
    await expect(page.locator(givenInputSelector)).toBeVisible();

    await page.fill(familyInputSelector, "Curie");
    await page.fill(givenInputSelector, "Marie");

    await expect(page.locator(familyInputSelector)).toHaveValue("Curie");
    await expect(page.locator(givenInputSelector)).toHaveValue("Marie");
  });
});
