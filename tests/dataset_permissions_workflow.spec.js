import { test, expect } from "@playwright/test";
import { authStatePath } from "./helpers/auth-state.js";
import {
  goToDepositAgreement,
  submitDepositAgreement,
} from "./helpers/deposit-flow.js";

test.describe("curator dataset editor permissions", () => {
  test.use({ storageState: authStatePath("admin") });

  test.beforeEach(async ({ page }) => {
    await goToDepositAgreement(page);
    await submitDepositAgreement(page);
    await expect(page).toHaveURL(/\/datasets\/[^/]+\/edit/);
    await page.goto(page.url().replace(/\/edit$/, "/permissions"));
    await expect(page.getByLabel("New editor email address")).toBeVisible();
  });

  test("previews, saves and removes editors without removing reviewers", async ({
    page,
  }) => {
    const permissionsURL = page.url();
    const form = page.locator('form[action$="/update_permissions"]');
    const reviewerEmail = "permissions-reviewer@illinois.edu";
    const editorEmail = "researcher1@mailinator.com";
    const token = form.locator('input[name="authenticity_token"]');
    const csrf = (await token.count())
      ? { authenticity_token: await token.inputValue() }
      : {};
    const response = await page.request.post(await form.getAttribute("action"), {
      form: {
        ...csrf,
        "reviewer_emails[]": reviewerEmail,
      },
    });
    expect(response.ok()).toBeTruthy();
    await page.reload();

    await page.getByLabel("New editor email address").fill(` ${editorEmail} `);
    await page.getByRole("button", { name: "Add", exact: true }).click();

    const preview = page.locator("#newEditorsDiv");
    await expect(preview).toContainText(editorEmail);
    await expect(preview).not.toContainText("undefined");
    await expect(
      preview.getByRole("checkbox", { name: editorEmail, exact: true }),
    ).toBeChecked();
    await expect(preview.locator('input[name="editor_emails[]"]')).toHaveValue(
      editorEmail,
    );
    await expect(page.getByLabel("New editor email address")).toBeEmpty();
    await expect(page.getByLabel("New editor email address")).toBeFocused();

    await page.getByRole("button", { name: "Update", exact: true }).click();
    await expect(page).not.toHaveURL(permissionsURL);
    await expect(
      page.getByText("Permissions updated.", { exact: true }),
    ).toBeVisible();
    await page.goto(permissionsURL);
    await expect(
      page.getByRole("checkbox", { name: editorEmail, exact: true }),
    ).toBeChecked();
    await expect(
      page.locator(`input[name="reviewer_emails[]"][value="${reviewerEmail}"]`),
    ).toHaveCount(1);

    await page.getByRole("checkbox", { name: editorEmail, exact: true }).uncheck();
    await page.getByRole("button", { name: "Update", exact: true }).click();
    await expect(page).not.toHaveURL(permissionsURL);
    await page.goto(permissionsURL);
    await expect(
      page.getByRole("checkbox", { name: editorEmail, exact: true }),
    ).toHaveCount(0);
    await expect(
      page.locator(`input[name="reviewer_emails[]"][value="${reviewerEmail}"]`),
    ).toHaveCount(1);
  });

  test("rejects empty or invalid addresses and preserves apostrophes", async ({
    page,
  }) => {
    const input = page.getByLabel("New editor email address");
    const preview = page.locator("#newEditorsDiv");

    for (const email of ["", "not-an-email"]) {
      await input.fill(email);
      const dialogPromise = page.waitForEvent("dialog").then(async (dialog) => {
        expect(dialog.message()).toBe("email address must be in valid format");
        await dialog.accept();
      });
      await Promise.all([
        dialogPromise,
        page.getByRole("button", { name: "Add", exact: true }).click(),
      ]);
      await expect(preview.getByRole("checkbox")).toHaveCount(0);
      await expect(input).toBeFocused();
    }

    const email = "o'connor@example.edu";
    await input.fill(email);
    await page.getByRole("button", { name: "Add", exact: true }).click();
    await expect(preview).toHaveText(email);
    await expect(preview.getByRole("checkbox", { name: email })).toHaveValue(email);
  });
});
