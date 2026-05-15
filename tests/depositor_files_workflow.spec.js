import { test, expect } from "@playwright/test";
import fs from "node:fs/promises";
import { authStatePath } from "./helpers/auth-state.js";
import {
  goToDepositAgreement,
  submitDepositAgreement,
} from "./helpers/deposit-flow.js";
import { BASE_URL } from "./helpers/config.js";

test.describe("authenticated depositor files workflow", () => {
  test.use({ storageState: authStatePath("depositor") });

  async function createDraftWithUploadedTextFile(page, testInfo) {
    await goToDepositAgreement(page);

    await submitDepositAgreement(page, {
      owner: "yes",
      removedPrivate: "na",
      agree: "yes",
    });

    await expect(page).toHaveURL(/\/datasets\/[^/]+\/edit/);
    const datasetKeyMatch = page.url().match(/\/datasets\/([^/]+)\/edit/);
    expect(datasetKeyMatch).not.toBeNull();
    const datasetKey = datasetKeyMatch[1];

    await page.fill(
      "#dataset_title",
      `Playwright files workflow ${Date.now()}`,
    );
    await page.selectOption("#dataset_license", { index: 1 });
    await page.fill("#dataset_creators_attributes_0_family_name", "Researcher");
    await page.fill("#dataset_creators_attributes_0_given_name", "One");
    await page.fill(
      "#dataset_creators_attributes_0_email",
      "researcher1@mailinator.com",
    );
    await page.locator('input[name="primary_contact"][value="0"]').check();

    const uploadFileName = "playwright-file-workflow.txt";
    const uploadContents = "preview line one\npreview line two\n";
    const uploadPath = testInfo.outputPath(uploadFileName);
    await fs.writeFile(uploadPath, uploadContents);

    const fileInput = page
      .locator('#file-select-area input[type="file"]')
      .first();
    await expect(fileInput).toBeAttached();
    await fileInput.setInputFiles(uploadPath);

    await expect(page.locator("#datafiles")).toContainText(uploadFileName, {
      timeout: 120000,
    });
    await expect(page.locator(".progress-bar")).toHaveCount(0, {
      timeout: 120000,
    });

    await Promise.all([
      page.waitForURL(new RegExp(`/datasets/${datasetKey}(\\?.*)?$`)),
      page.locator("#update-save-button").click(),
    ]);

    await expect(page).toHaveURL(
      new RegExp(`/datasets/${datasetKey}(\\?.*)?$`),
    );

    return { datasetKey, uploadFileName, uploadContents };
  }

  test("text file preview toggles open on dataset show page", async ({
    page,
  }, testInfo) => {
    const { datasetKey, uploadFileName, uploadContents } =
      await createDraftWithUploadedTextFile(page, testInfo);

    await page.goto(`${BASE_URL}/datasets/${datasetKey}`);
    await expect(page.locator("body")).toContainText(uploadFileName);

    const previewButton = page.locator("button[id^='preview_btn_']").first();
    await expect(previewButton).toBeVisible();
    await previewButton.click();

    const previewPanel = page.locator(".preview").first();
    await expect(previewPanel).toBeVisible();
    await expect(previewPanel).toContainText(uploadContents.trim());
    await expect(previewButton).toHaveAttribute("aria-expanded", "true");
    await expect(previewButton).toHaveAttribute(
      "data-file-action",
      "hide-preview-text",
    );

    await previewButton.click();
    await expect(previewButton).toHaveAttribute(
      "data-file-action",
      "preview-text",
    );
    await expect(previewPanel).toBeHidden();
  });

  test("delete selected removes uploaded file from edit view", async ({
    page,
  }, testInfo) => {
    const { datasetKey, uploadFileName } =
      await createDraftWithUploadedTextFile(page, testInfo);

    await page.goto(`${BASE_URL}/datasets/${datasetKey}/edit`);
    await expect(page.locator("#datafiles")).toContainText(uploadFileName);

    const fileCheckbox = page.locator("input.checkFile").first();
    await fileCheckbox.check();
    await expect(page.locator(".checkFileSelectedCount")).toContainText("(1)");

    page.once("dialog", async (dialog) => {
      await dialog.accept();
    });

    await page.getByRole("button", { name: /Delete Selected/i }).click();

    await expect(page.locator("#datafiles")).not.toContainText(uploadFileName, {
      timeout: 120000,
    });
    await expect(page.locator("#datafilesCount")).toContainText("0");
  });
});
