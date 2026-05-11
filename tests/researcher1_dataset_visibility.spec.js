import { test, expect } from "@playwright/test";
import { spawnSync } from "node:child_process";
import { getNamedAuthState, namedAuthStatePath } from "./helpers/auth-state.js";

const baseUrl = process.env.PLAYWRIGHT_BASE_URL || "http://127.0.0.1:3000";
const researcherRole = "depositor";
const researcherEmail = "researcher1@mailinator.com";

const ownDraftKey = `PW-OWN-DRAFT-${Date.now()}`;
const otherDraftKey = `PW-OTHER-DRAFT-${Date.now()}`;
const otherReleasedKey = `PW-OTHER-REL-${Date.now()}`;

function runRails(code) {
  const result = spawnSync("bundle", ["exec", "rails", "runner", code], {
    cwd: process.cwd(),
    encoding: "utf8",
  });

  if (result.status !== 0) {
    throw new Error(
      `rails runner failed:\n${result.stdout || ""}\n${result.stderr || ""}`,
    );
  }
}

function createDatasetRuby({ key, title, depositorEmail, publicationState }) {
  return `
Dataset.create!(
  key: "${key}",
  title: "${title}",
  depositor_name: "Playwright Depositor",
  depositor_email: "${depositorEmail}",
  publisher: "University of Illinois Urbana-Champaign",
  description: "Playwright visibility fixture",
  license: "CC01",
  corresponding_creator_name: "Playwright Depositor",
  corresponding_creator_email: "${depositorEmail}",
  publication_state: "${publicationState}",
  embargo: "none",
  have_permission: "yes",
  removed_private: "na",
  agree: "yes",
  is_test: false,
  is_import: false,
  hold_state: "none"
)
`;
}

function cleanupDatasetsRuby(keys) {
  const quotedKeys = keys.map((key) => `"${key}"`).join(", ");
  return `Dataset.where(key: [${quotedKeys}]).destroy_all`;
}

test.describe("named user visibility: researcher1", () => {
  const statePath = namedAuthStatePath(researcherRole, researcherEmail);
  test.use({ storageState: statePath });

  test.beforeAll(() => {
    if (!getNamedAuthState(researcherRole, researcherEmail)) {
      throw new Error(
        "Missing named auth state for researcher1. Run `npm run playwright:auth:setup` first.",
      );
    }

    runRails(
      createDatasetRuby({
        key: ownDraftKey,
        title: "Playwright Own Draft Dataset",
        depositorEmail: researcherEmail,
        publicationState: "draft",
      }),
    );

    runRails(
      createDatasetRuby({
        key: otherDraftKey,
        title: "Playwright Other Draft Dataset",
        depositorEmail: "other-user@mailinator.com",
        publicationState: "draft",
      }),
    );

    runRails(
      createDatasetRuby({
        key: otherReleasedKey,
        title: "Playwright Other Released Dataset",
        depositorEmail: "other-user@mailinator.com",
        publicationState: "released",
      }),
    );
  });

  test.afterAll(() => {
    runRails(
      cleanupDatasetsRuby([ownDraftKey, otherDraftKey, otherReleasedKey]),
    );
  });

  test("can view own draft, cannot view others' draft, but can view released dataset", async ({
    page,
  }) => {
    await page.goto(`${baseUrl}/datasets/${ownDraftKey}`);
    await expect(page.locator("body")).toContainText(
      "Playwright Own Draft Dataset",
    );
    await expect(page.locator("body")).not.toContainText("Restricted Access");

    await page.goto(`${baseUrl}/datasets/${otherDraftKey}`);
    await expect(page.locator("body")).toContainText("Restricted Access");

    await page.goto(`${baseUrl}/datasets/${otherReleasedKey}`);
    await expect(page.locator("body")).toContainText(
      "Playwright Other Released Dataset",
    );
    await expect(page.locator("body")).not.toContainText("Restricted Access");
  });
});
