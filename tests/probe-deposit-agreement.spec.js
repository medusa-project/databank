import { test, expect } from "@playwright/test";
import { authStatePath } from "./helpers/auth-state.js";
import { goToDepositAgreement } from "./helpers/deposit-flow.js";

test.use({ storageState: authStatePath("depositor") });

test("probe deposit agreement page", async ({ page }) => {
  await goToDepositAgreement(page);
});
