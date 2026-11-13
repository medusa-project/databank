const { test, expect } = require("@playwright/test");
const { execFileSync } = require("node:child_process");
const path = require("node:path");

test.beforeEach(async ({ page }) => {
  const jqueryRoot = execFileSync("bundle", ["show", "jquery-rails"], { encoding: "utf8" }).trim();
  await page.setContent(`
    <label>Dataset title <input id="dataset-title"></label>
    <button data-dataset-action="import-google-drive" disabled>Import from Google Drive</button>
    <p id="google-drive-import-availability" role="status">Checking Google Drive import status</p>
    <section id="google-drive-imports" data-base-path="/datasets/test/google_drive" tabindex="-1">
      <p id="google-drive-error" role="alert"></p>
      <p id="google-drive-import-announcement" role="status" aria-atomic="true"></p>
      <ul id="google-drive-import-list"></ul>
    </section>
    <dialog id="google-drive-confirmation">
      <button id="google-drive-confirm">Confirm</button>
      <button id="google-drive-dismiss">Dismiss</button>
    </dialog>
  `);
  await page.addScriptTag({ path: path.join(jqueryRoot, "vendor/assets/javascripts/jquery.js") });
  await page.evaluate(() => {
    window.imports = [{ id: 1, name: "test.csv", size: 5, bytes_downloaded: 0, status: "queued" }];
    const originalTimeout = window.setTimeout;
    window.setTimeout = (callback, delay, ...args) =>
      originalTimeout(callback, delay === 5000 || delay === 15000 ? 50 : delay, ...args);
    window.jQuery.ajax = (options) => {
      if (window.failPolling && options.type === "GET") {
        queueMicrotask(() => options.error({ responseJSON: { error: "Status temporarily unavailable" } }));
        return;
      }
      if (options.type === "DELETE") {
        window.imports[0].status = "cancelled";
        queueMicrotask(() => options.success({}));
      } else {
        queueMicrotask(() => options.success(structuredClone(window.imports)));
      }
    };
  });
  await page.addScriptTag({ path: path.resolve("app/assets/javascripts/google_drive_import.js") });
});

test("disables Drive imports while a dataset import is active and re-enables afterward", async ({ page }) => {
  const button = page.getByRole("button", { name: "Import from Google Drive" });
  const availability = page.locator("#google-drive-import-availability");
  await expect(button).toBeDisabled();
  await expect(availability).toContainText("queued or in progress");
  await page.getByRole("button", { name: "Cancel import of test.csv" }).click();
  await expect(button).toBeEnabled();
  await expect(button).toBeFocused();
  await expect(availability).toBeEmpty();

  await page.evaluate(() => { window.imports[0].status = "importing"; });
  await expect(button).toBeDisabled();
  await expect(page.locator("#google-drive-imports")).toBeFocused();
  await page.evaluate(() => { window.imports[0].status = "complete"; });
  await expect(button).toBeEnabled();
  await expect(availability).toBeEmpty();
});

test("keeps progress controls stable and restores focus when an import finishes", async ({ page }) => {
  const cancel = page.getByRole("button", { name: "Cancel import of test.csv" });
  await cancel.focus();
  await page.evaluate(() => {
    window.cancelControl = document.activeElement;
    window.imports[0].bytes_downloaded = 3;
    window.announcementMutations = 0;
    new MutationObserver(() => { window.announcementMutations++; }).observe(
      document.getElementById("google-drive-import-announcement"), { childList: true, subtree: true, characterData: true }
    );
  });
  await expect(page.locator("progress")).toHaveAttribute("value", "3");
  await expect(cancel).toBeFocused();
  expect(await page.evaluate(() => document.activeElement === window.cancelControl)).toBe(true);
  expect(await page.evaluate(() => window.announcementMutations)).toBe(0);

  await page.evaluate(() => { window.imports[0].status = "complete"; });
  await expect(page.getByRole("button", { name: "Import from Google Drive" })).toBeFocused();
  await expect(page.locator("#google-drive-import-announcement")).toContainText("complete");
  await expect(page.getByRole("button", { name: "Clear Notice for test.csv (complete)", exact: true })).toBeVisible();
});

test("background polling errors announce the error without stealing focus", async ({ page }) => {
  await expect(page.getByRole("button", { name: "Cancel import of test.csv" })).toBeVisible();
  await page.locator("#dataset-title").focus();
  await page.evaluate(() => { window.failPolling = true; });
  await expect(page.getByRole("alert")).toHaveText("Status temporarily unavailable");
  await expect(page.locator("#dataset-title")).toBeFocused();
});
