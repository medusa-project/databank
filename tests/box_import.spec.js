const { test, expect } = require("@playwright/test");
const { execFileSync } = require("node:child_process");
const path = require("node:path");

test("Box picker confirms one file, queues the import, and supports cancellation and notice clearing", async ({ page }) => {
  const jqueryRoot = execFileSync("bundle", ["show", "jquery-rails"], { encoding: "utf8" }).trim();
  await page.setContent(`
    <button data-dataset-action="import-box" disabled>Import from Box</button>
    <p id="box-import-availability" role="status"></p>
    <section id="box-imports" data-base-path="/datasets/test/box" tabindex="-1">
      <p id="box-error" role="alert"></p>
      <p id="box-import-announcement" role="status"></p>
      <ul id="box-import-list"></ul>
    </section>
    <dialog id="box-picker-dialog" aria-labelledby="box-picker-title">
      <h2 id="box-picker-title" tabindex="-1">Select one file from Box</h2>
      <div id="box-picker-container"></div><button id="box-picker-cancel">Cancel</button>
    </dialog>
    <dialog id="box-confirmation" aria-labelledby="box-confirmation-title" aria-describedby="box-selected-details">
      <h2 id="box-confirmation-title">Confirm Box import</h2>
      <dl id="box-selected-details"><dt>Filename</dt><dd id="box-selected-name"></dd>
        <dt>Size</dt><dd id="box-selected-size"></dd></dl>
      <button id="box-confirm">Start import</button><button id="box-dismiss">Cancel</button>
    </dialog>
  `);
  await page.route("https://cdn01.boxcdn.net/**", async route => {
    if (route.request().url().endsWith(".css")) {
      await route.fulfill({ contentType: "text/css", body: "" });
      return;
    }
    await route.fulfill({ contentType: "text/javascript", body: `
      window.Box = { FilePicker: class {
        constructor() { this.listeners = {}; }
        addListener(name, callback) { this.listeners[name] = callback; }
        hide() { document.getElementById("box-picker-container").replaceChildren(); }
        show(folder, token, options) {
          window.pickerOptions = options;
          window.pickerToken = token;
          const button = document.createElement("button");
          button.textContent = "Choose sample.csv";
          button.onclick = () => this.listeners.choose([{id: "12345", type: "file"}]);
          document.querySelector(options.container).append(button);
          button.focus();
        }
      }};
    ` });
  });
  await page.addScriptTag({ path: path.join(jqueryRoot, "vendor/assets/javascripts/jquery.js") });
  await page.evaluate(() => {
    window.imports = [];
    window.jQuery.ajax = options => {
      let data;
      if (options.url.endsWith("/authorize")) {
        data = { authorization_url: "about:blank#box-authorize" };
      } else if (options.url.endsWith("/picker")) {
        data = { access_token: "picker-only-token" };
      } else if (options.url.endsWith("/preview")) {
        data = { selection_id: "validated-selection", name: "sample.csv", size: 5 };
      } else if (options.type === "POST") {
        window.imports = [{ id: 1, name: "sample.csv", size: 5, bytes_downloaded: 0, status: "queued" }];
        data = window.imports[0];
      } else if (options.type === "DELETE") {
        if (options.url.endsWith("/authorization")) { data = {}; }
        else if (options.url.endsWith("/notice")) { window.imports = []; }
        else { window.imports[0].status = "cancelled"; }
        data = {};
      } else { data = window.imports; }
      queueMicrotask(() => options.success(structuredClone(data)));
    };
  });
  await page.addScriptTag({ path: path.resolve("app/assets/javascripts/cloud_import.js") });
  await page.addScriptTag({ path: path.resolve("app/assets/javascripts/google_drive_import.js") });
  await page.addScriptTag({ path: path.resolve("app/assets/javascripts/box_import.js") });

  const importButton = page.getByRole("button", { name: "Import from Box" });
  await expect(importButton).toBeEnabled();
  const popupPromise = page.waitForEvent("popup");
  await importButton.click();
  const popup = await popupPromise;
  await popup.waitForURL("about:blank#box-authorize");
  await popup.evaluate(() => {
    window.opener.postMessage({ type: "databank-box-authorized" }, "*");
  });
  await popup.close();
  await expect(page.getByRole("dialog", { name: "Select one file from Box" })).toBeVisible();
  await page.keyboard.press("Escape");
  await expect(page.getByRole("dialog", { name: "Select one file from Box" })).not.toBeVisible();
  await expect(importButton).toBeFocused();
  const secondPopupPromise = page.waitForEvent("popup");
  await importButton.click();
  const secondPopup = await secondPopupPromise;
  await secondPopup.waitForURL("about:blank#box-authorize");
  await secondPopup.evaluate(() => {
    window.opener.postMessage({ type: "databank-box-authorized" }, "*");
  });
  await secondPopup.close();
  await expect(page.getByRole("dialog", { name: "Select one file from Box" })).toBeVisible();
  expect(await page.evaluate(() => window.pickerToken)).toBe("picker-only-token");
  expect(await page.evaluate(() => window.pickerOptions.maxSelectable)).toBe(1);
  await page.getByRole("button", { name: "Choose sample.csv" }).click();
  const confirmation = page.getByRole("dialog", { name: "Confirm Box import" });
  await expect(confirmation).toBeVisible();
  await expect(confirmation).toHaveAccessibleDescription(/sample.csv.*5 bytes/);
  await expect(page.getByRole("button", { name: "Start import" })).toBeFocused();
  await page.getByRole("button", { name: "Start import" }).click();
  await expect(importButton).toBeDisabled();
  await expect(page.locator("#box-import-availability")).toContainText("queued or in progress");
  await page.getByRole("button", { name: "Cancel import of sample.csv" }).click();
  await expect(importButton).toBeEnabled();
  await expect(importButton).toBeFocused();
  await page.getByRole("button", { name: "Clear Notice for sample.csv (cancelled)", exact: true }).click();
  await expect(page.locator("#box-import-list")).toBeEmpty();
});
