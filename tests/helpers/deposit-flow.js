import { expect } from "@playwright/test";
import { BASE_URL } from "./config.js";

export async function continueFromPreDeposit(page, options = {}) {
  const expectedPathPattern = options.expectedPathPattern || /\/datasets\/new/;

  await page.goto(`${BASE_URL}/datasets/pre_deposit`);
  await expect(page.locator("#continue-button")).toBeVisible();
  await page.click("#continue-button");
  await expect(page).toHaveURL(expectedPathPattern);
}

export async function goToDepositAgreement(page) {
  await continueFromPreDeposit(page);

  await expect(
    page.getByRole("heading", { name: "Deposit Agreement", exact: true }),
  ).toBeVisible();
  await expect(page.locator("#agree-form")).toBeVisible();
  await expect(page.locator("#owner-yes")).toBeVisible();
}

export async function submitDepositAgreement(page, options = {}) {
  var owner = options.owner || "yes";
  var removedPrivate = options.removedPrivate || "na";
  var agree = options.agree || "yes";

  await page.locator(`#owner-${owner}`).check();
  await page.locator(`#private-${removedPrivate}`).check();
  await page.locator(`#agree-${agree}`).check();

  await page.locator("#agree-button").click();
}
