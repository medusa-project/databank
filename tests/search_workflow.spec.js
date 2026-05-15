import { test, expect } from "@playwright/test";
import { BASE_URL } from "./helpers/config.js";

test.describe("dataset search workflow", () => {
  test("clear search term button removes the query and resets the input", async ({
    page,
  }) => {
    await page.goto(`${BASE_URL}/datasets?q=climate`);

    const searchInput = page.locator("input[name='q']");
    await expect(searchInput).toHaveValue("climate");

    await page.locator("#clearSearchTermBtn").click();

    await expect(page).toHaveURL(/\/datasets(?:\?.*)?$/);
    await expect(searchInput).toHaveValue("");
    await expect(page).not.toHaveURL(/\bq=climate\b/);
  });

  test("checking a search facet submits the form with that facet value", async ({
    page,
  }) => {
    await page.goto(`${BASE_URL}/datasets`);

    const firstFacet = page.locator(".checkFacetGroup").first();
    await expect(firstFacet).toBeVisible();

    const facetName = await firstFacet.getAttribute("name");
    const facetValue = await firstFacet.getAttribute("value");

    expect(facetName).not.toBeNull();
    expect(facetValue).not.toBeNull();

    await firstFacet.check();

    await expect(page).toHaveURL(
      new RegExp(`${encodeURIComponent(facetName)}=`),
    );
    await expect(page).toHaveURL(new RegExp(encodeURIComponent(facetValue)));
  });
});
