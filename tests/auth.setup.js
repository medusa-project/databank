import fs from "node:fs/promises";
import path from "node:path";
import { test as setup, expect } from "@playwright/test";
import {
  PLAYWRIGHT_ROLES,
  NAMED_USERS,
  authStatePath,
  namedAuthStatePath,
} from "./helpers/auth-state.js";
import { BASE_URL } from "./helpers/config.js";

async function fillUsingAnySelector(page, selectors, value) {
  for (const selector of selectors) {
    const field = page.locator(selector).first();
    if (await field.count()) {
      await field.fill(value);
      return;
    }
  }
  throw new Error(
    `Unable to find input for selectors: ${selectors.join(", ")}`,
  );
}

async function setRoleField(page, role) {
  const roleSelect = page.locator('select[name="role"]').first();
  if (await roleSelect.count()) {
    await roleSelect.selectOption(role);
    return;
  }

  await fillUsingAnySelector(page, ['input[name="role"]', "#role"], role);
}

async function submitDeveloperLogin(page) {
  const submit = page
    .locator('button[type="submit"], input[type="submit"]')
    .first();
  await Promise.all([page.waitForLoadState("networkidle"), submit.click()]);
}

async function loginAsDeveloperUser(page, { name, email, role }) {
  await page.goto(`${BASE_URL}/auth/developer`);
  await fillUsingAnySelector(page, ['input[name="name"]', "#name"], name);
  await fillUsingAnySelector(page, ['input[name="email"]', "#email"], email);
  await setRoleField(page, role);
  await submitDeveloperLogin(page);
}

async function loginAsNamedUser(page, name, email, role) {
  await loginAsDeveloperUser(page, { name, email, role });
}

async function loginAsRole(page, role) {
  const email = `playwright-${role}@example.edu`;
  const name = `Playwright ${role}`;

  await loginAsDeveloperUser(page, { name, email, role });
}

async function authStateExists(targetPath) {
  try {
    await fs.access(targetPath);
    return true;
  } catch {
    return false;
  }
}

setup("create role-based authenticated storage states", async ({ browser }) => {
  const authDir = path.join(process.cwd(), "playwright", ".auth");
  await fs.mkdir(authDir, { recursive: true });

  for (const role of PLAYWRIGHT_ROLES) {
    const targetPath = authStatePath(role);
    if (await authStateExists(targetPath)) {
      await fs.unlink(targetPath);
    }

    const context = await browser.newContext();
    const page = await context.newPage();

    await loginAsRole(page, role);

    const cookies = await context.cookies(BASE_URL);
    expect(
      cookies.some((cookie) => cookie.name.includes("session")),
    ).toBeTruthy();

    await context.storageState({ path: targetPath });
    await context.close();
  }
});

setup("create named user authenticated storage states", async ({ browser }) => {
  const authDir = path.join(process.cwd(), "playwright", ".auth");
  await fs.mkdir(authDir, { recursive: true });

  for (const { role, name, email } of NAMED_USERS) {
    const targetPath = namedAuthStatePath(role, email);
    if (await authStateExists(targetPath)) {
      await fs.unlink(targetPath);
    }

    const context = await browser.newContext();
    const page = await context.newPage();

    await loginAsNamedUser(page, name, email, role);

    const cookies = await context.cookies(BASE_URL);
    expect(
      cookies.some((cookie) => cookie.name.includes("session")),
    ).toBeTruthy();

    await context.storageState({ path: targetPath });
    await context.close();
  }
});
