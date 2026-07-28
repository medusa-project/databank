import { test, expect } from "@playwright/test";
import { authStatePath } from "./helpers/auth-state.js";
import { BASE_URL } from "./helpers/config.js";

test.describe("Metrics Download Page", () => {
  test.use({ storageState: authStatePath("admin") });

  test("should display download metrics page with all sections", async ({
    page,
  }) => {
    // Navigate to download metrics page
    await page.goto(`${BASE_URL}/download_metrics`);

    // Verify page loads with proper title using specific locator (strict mode safe)
    await expect(
      page.getByRole("heading", { name: "Download Metrics" })
    ).toBeVisible();

    // Verify sections exist
    await expect(
      page.getByRole("heading", { name: "Dataset Downloads" })
    ).toBeVisible();
    await expect(
      page.getByRole("heading", { name: "Datafile Downloads" })
    ).toBeVisible();
  });

  test("should have current year download links", async ({ page }) => {
    await page.goto(`${BASE_URL}/download_metrics`);

    // Current year dataset links
    const datasetCalendarLink = page.locator(
      '[data-testid="metric-download-dataset-2026-calendar"]'
    );
    const datasetFiscalLink = page.locator(
      '[data-testid="metric-download-dataset-FY26-fiscal"]'
    );

    await expect(datasetCalendarLink).toBeVisible();
    await expect(datasetCalendarLink).toHaveAttribute(
      "href",
      "/public/dataset_downloads_2026.csv"
    );

    await expect(datasetFiscalLink).toBeVisible();
    await expect(datasetFiscalLink).toHaveAttribute(
      "href",
      "/public/dataset_downloads_FY26.csv"
    );
  });

  test("should have prior year archived links", async ({ page }) => {
    await page.goto(`${BASE_URL}/download_metrics`);

    // Prior year dataset links (from archived endpoint)
    const priorYearLink = page.locator(
      '[data-testid="metric-download-dataset-2025-calendar"]'
    );
    const priorYearFiscalLink = page.locator(
      '[data-testid="metric-download-dataset-FY25-fiscal"]'
    );

    await expect(priorYearLink).toBeVisible();
    await expect(priorYearLink).toHaveAttribute(
      "href",
      "/metrics/archived/dataset_downloads/2025/calendar"
    );

    await expect(priorYearFiscalLink).toBeVisible();
    await expect(priorYearFiscalLink).toHaveAttribute(
      "href",
      "/metrics/archived/dataset_downloads/FY25/fiscal"
    );
  });

  test("should have datafile download links", async ({ page }) => {
    await page.goto(`${BASE_URL}/download_metrics`);

    // Current year datafile links
    const datafileCalendarLink = page.locator(
      '[data-testid="metric-download-datafile-2026-calendar"]'
    );
    const datafileFiscalLink = page.locator(
      '[data-testid="metric-download-datafile-FY26-fiscal"]'
    );

    // Scroll to ensure visibility
    await datafileCalendarLink.scrollIntoViewIfNeeded();

    await expect(datafileCalendarLink).toBeVisible();
    await expect(datafileCalendarLink).toHaveAttribute(
      "href",
      "/public/datafile_downloads_2026.csv"
    );

    await expect(datafileFiscalLink).toBeVisible();
    await expect(datafileFiscalLink).toHaveAttribute(
      "href",
      "/public/datafile_downloads_FY26.csv"
    );
  });
});
