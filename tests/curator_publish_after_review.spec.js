import { test, expect } from "@playwright/test";
import fs from "node:fs/promises";
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

async function logout(page) {
  await page.goto(`${BASE_URL}/logout`);
}

test.describe("depositor to curator publish flow", () => {
  test("curator publish from show view redirects to confirmation", async ({
    page,
  }, testInfo) => {
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

    await page.fill(
      "#dataset_title",
      `Playwright curator publish ${Date.now()}`,
    );
    await page.selectOption("#dataset_license", { index: 1 });
    await page.fill("#dataset_creators_attributes_0_family_name", "Researcher");
    await page.fill("#dataset_creators_attributes_0_given_name", "One");
    await page.fill(
      "#dataset_creators_attributes_0_email",
      "researcher1@mailinator.com",
    );
    // select this creator as the contact person for the dataset by choosing the radio button in the "Is Contact?" column of the creator table
    // radio button has name of "primary_contact" and value of "0" since this is the first creator in the table (index starts at 0)
    await page.locator('input[name="primary_contact"][value="0"]').check();

    const uploadFileName = "playwright-small-upload.txt";
    const uploadPath = testInfo.outputPath(uploadFileName);
    await fs.writeFile(uploadPath, "small upload for curator publish test\n");

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

    // Must fail if button is not visible - do not fall back on url
    const reviewButton = page.getByRole("button", {
      name: /Pre-Publication Review/i,
    });
    const reviewBtnVisible = await reviewButton.isVisible().catch(() => false);
    console.log(
      `[DIAG] Pre-Publication Review button visible: ${reviewBtnVisible}`,
    );
    if (!reviewBtnVisible) {
      const allButtons = await page.getByRole("button").allTextContents();
      console.log(
        `[DIAG] All buttons on dataset show page: ${JSON.stringify(allButtons)}`,
      );
    }
    await expect(reviewButton).toBeVisible();
    await reviewButton.click();
    console.log(`[DIAG] Clicked Pre-Publication Review button`);
    await page.locator("#review-btn").click();
    console.log(`[DIAG] Clicked #review-btn, URL: ${page.url()}`);

    await expect(page).toHaveURL(
      new RegExp(`/datasets/${datasetKey}/request_review(\\?.*)?$`),
    );
    await expect(page.locator("body")).toContainText(
      /Pre-Publication Review Request Received/i,
    );

    await logout(page);

    await loginAsDeveloperUser(page, {
      name: "Curator1",
      email: "curator1@mailinator.com",
      role: "admin",
    });

    await page.goto(`${BASE_URL}/datasets/${datasetKey}`);
    console.log(`[DIAG] Curator navigated to dataset show: ${page.url()}`);

    const curatorPublishButton = page.locator("#curator-publish-button");
    const cpbVisible = await curatorPublishButton
      .isVisible()
      .catch(() => false);
    console.log(`[DIAG] #curator-publish-button visible: ${cpbVisible}`);
    if (!cpbVisible) {
      const bodyText = await page.locator("body").textContent();
      const statusMatch = bodyText.match(
        /(draft|review|published|suppressed)/gi,
      );
      console.log(`[DIAG] Status words found in body: ${statusMatch}`);
      const allButtons = await page.getByRole("button").allTextContents();
      console.log(`[DIAG] All buttons on page: ${JSON.stringify(allButtons)}`);
    }
    await expect(curatorPublishButton).toBeVisible();
    await curatorPublishButton.click();
    console.log(`[DIAG] Clicked #curator-publish-button`);

    // Wait for the publish button inside the modal to be visible, confirming the modal opened
    await expect(page.locator("#publish-button")).toBeVisible();
    console.log(
      `[DIAG] Publish confirmation dialog is open (#publish-button visible)`,
    );

    await page.locator("#publish-button").click();
    console.log(`[DIAG] Clicked #publish-button, current URL: ${page.url()}`);

    console.log(`[DIAG] After publish click, URL: ${page.url()}`);
    const alertText = await page
      .locator(".alert")
      .textContent()
      .catch(() => "(no .alert found)");
    console.log(`[DIAG] Alert text: ${alertText}`);
    await expect(page).toHaveURL(
      new RegExp(`/datasets/${datasetKey}(\\?.*)?$`),
    );
    await expect(page.locator("body")).not.toContainText(
      "The page you were looking for doesn't exist.",
    );
    await expect(page.locator(".alert")).toContainText(
      /successfully published/i,
    );
  });
});
