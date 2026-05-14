import { expect } from "@playwright/test";
import { BASE_URL } from "./config.js";

export async function goToDepositAgreement(page) {
  await page.goto(`${BASE_URL}/datasets/pre_deposit`);
  await expect(page.locator("#continue-button")).toBeVisible();
  await page.click("#continue-button");

  await expect(page).toHaveURL(/\/datasets\/new/);
  await expect(
    page.getByRole("heading", { name: "Deposit Agreement", exact: true }),
  ).toBeVisible();
  await expect(page.locator("#agree-form")).toBeVisible();
  await expect(page.locator("#owner-yes")).toBeVisible();
}
