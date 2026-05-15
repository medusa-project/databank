import { test, expect } from "@playwright/test";
import fs from "node:fs/promises";
import { authStatePath } from "./helpers/auth-state.js";
import {
  goToDepositAgreement,
  submitDepositAgreement,
} from "./helpers/deposit-flow.js";

test.describe("authenticated depositor remote ingest workflow", () => {
  test.use({ storageState: authStatePath("depositor") });

  async function createDraftWithUploadedFile(page, testInfo) {
    await goToDepositAgreement(page);

    await submitDepositAgreement(page, {
      owner: "yes",
      removedPrivate: "na",
      agree: "yes",
    });

    await expect(page).toHaveURL(/\/datasets\/[^/]+\/edit/);

    await page.fill("#dataset_title", `Playwright remote ingest ${Date.now()}`);
    await page.selectOption("#dataset_license", { index: 1 });
    await page.fill("#dataset_creators_attributes_0_family_name", "Researcher");
    await page.fill("#dataset_creators_attributes_0_given_name", "One");
    await page.fill(
      "#dataset_creators_attributes_0_email",
      "researcher1@mailinator.com",
    );
    await page.locator('input[name="primary_contact"][value="0"]').check();

    const uploadFileName = "playwright-remote-source.txt";
    const uploadPath = testInfo.outputPath(uploadFileName);
    await fs.writeFile(
      uploadPath,
      "existing file for duplicate-name remote ingest\n",
    );

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

    return { uploadFileName };
  }

  async function openRemoteFileModal(page) {
    const advancedUploadAccordion = page.getByRole("button", {
      name: /Advanced Upload Options/i,
    });
    await expect(advancedUploadAccordion).toBeVisible();
    await advancedUploadAccordion.click();

    await page.evaluate(() => {
      openRemoteFileModal();
    });

    await expect(page.locator("#remote-file-modal")).toBeVisible();
    await expect(page.locator("#remote_filename")).toBeVisible();
    await expect(page.locator("#remote_url")).toBeVisible();
  }

  test("duplicate remote filename shows client-side alert", async ({
    page,
  }, testInfo) => {
    const { uploadFileName } = await createDraftWithUploadedFile(
      page,
      testInfo,
    );

    await openRemoteFileModal(page);
    await page.fill("#remote_filename", uploadFileName);
    await page.fill("#remote_url", "https://example.org/files/duplicate.txt");

    let dialogMessage = null;
    page.once("dialog", async (dialog) => {
      dialogMessage = dialog.message();
      await dialog.accept();
    });

    await page.locator("#remote-file-start-btn").click();

    await expect
      .poll(() => dialogMessage)
      .toContain(`Duplicate filename error: A file named ${uploadFileName}`);
  });

  test("oversized remote file shows support alert from content-length check", async ({
    page,
  }, testInfo) => {
    await createDraftWithUploadedFile(page, testInfo);

    await page.route("**/datafiles/remote_content_length", async (route) => {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          status: "ok",
          remote_content_length: 100000000001,
        }),
      });
    });

    await openRemoteFileModal(page);
    await page.fill("#remote_filename", "huge-remote-file.txt");
    await page.fill("#remote_url", "https://example.org/files/huge-file.txt");

    let dialogMessage = null;
    page.once("dialog", async (dialog) => {
      dialogMessage = dialog.message();
      await dialog.accept();
    });

    await page.locator("#remote-file-start-btn").click();

    await expect
      .poll(() => dialogMessage)
      .toBe(
        "For files larger than 100 GB, please contact the Research Data Service.",
      );
  });
});
