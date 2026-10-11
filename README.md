# Ritual One

Reading, meditation and exercise. A playful habit app with Supabase accounts,
private reflections, daily check-ins and per-category longest-streak leaderboards.

Prepared for **https://github.com/raghav95nanda/ritualone**.
Expected Pages URL: **https://raghav95nanda.github.io/ritualone/**.
This is a static React/Vite export of the latest Ritual One design. It needs no
Node server or `/api/config` endpoint at runtime.

## Publish without installing anything

1. Extract this ZIP on your computer.
2. Open your GitHub repository and use **Add file > Upload files**. Upload the
   contents of the extracted folder into the repository root, including `docs/`.
   Do not upload the ZIP itself or nest everything inside another folder.
3. Commit to `main` (or your repository's default branch).
4. Open **Settings > Pages**. Set **Source** to **Deploy from a branch**.
   Select the branch you uploaded to and the **/docs** folder, then Save.
5. Wait for the GitHub Pages deployment to finish. Open
   https://raghav95nanda.github.io/ritualone/.

The compiled site is already in `docs/`. Its `index.html`, `assets/`, images and
favicon must all stay together. `docs/` is the publishing folder, but it does not
appear as `/docs/` in the public URL.

This ZIP also contains source code and an optional `.github/workflows/deploy.yml`.
If hidden folders are not included by a browser upload, the **/docs** method above
still works. The custom workflow only runs when manually started, so it does not
interfere with branch-based publishing.

## Supabase configuration

Open the existing project:
https://supabase.com/dashboard/project/rslxrwaqvjnxrufarfok

1. If the Ritual One setup has not already been applied, use **SQL Editor** to run
   `supabase/ritual-one-setup.sql`. This creates the app's namespaced tables,
   profile trigger, ownership policies and aggregate leaderboard function.
   Keep existing project data. Do not recreate the project for GitHub Pages.
2. In **Authentication > URL Configuration > Redirect URLs**, add exactly:
   `https://raghav95nanda.github.io/ritualone/`
3. Keep existing redirect entries, including the current ChatGPT-hosted site if
   you still use it. If this project serves other apps, preserve its current
   **Site URL**. If Ritual One is its only app, the Site URL can be the Pages URL.
4. Keep email/password signups available and keep email confirmation enabled.
5. If you have customized confirmation/reset email templates, links should use
   `{{ .ConfirmationURL }}` so Supabase verifies them and redirects to the
   full `/ritualone/` address supplied by this app. A direct `/auth/confirm`
   frontend route is not part of this static app.

The supplied project URL and **publishable** key are already configured in
`src/config.ts`. These are public frontend values. No secret or service-role
key is included. Existing RLS policies protect private records. Every check-in
and reflection remains in the same Supabase project, so existing member data
is retained. Members will need to sign in on the new domain because browser
sessions are stored separately for each domain.

## Future edits

Use Node 24 and the pinned pnpm version:

```sh
corepack enable
corepack prepare pnpm@11.25.0 --activate
pnpm install --frozen-lockfile
pnpm run check
pnpm run build
```

The build updates `docs/`. Commit both the edited source and the rebuilt `docs/`
folder for branch-based publishing. Local development is `pnpm run dev`.

For optional local auth testing, also allow `http://localhost:5173/ritualone/`
in Supabase Redirect URLs.

## Optional GitHub Actions deployment

To build from source on GitHub instead of committing compiled output:

1. Ensure `.github/workflows/deploy.yml` and `pnpm-lock.yaml` are in the repo.
2. Set **Settings > Pages > Source** to **GitHub Actions**.
3. In **Actions**, choose **Build and deploy Ritual One**, then **Run workflow**.
4. The workflow installs locked dependencies, runs checks, builds `docs/`, and
   publishes it. Run it again after future source changes.

The workflow does not require Supabase secrets: it builds with the supplied
public configuration. To use another project, update `src/config.ts` and rebuild,
or provide `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` at build time.

## Changing the repository name or using a custom domain

The default Vite base is `/ritualone/`. Change `base` in `vite.config.ts` to your
new repository path, or `/` for a root custom domain. Rebuild `docs/`, and add the
new full URL to Supabase Redirect URLs. Asset links and confirmation/reset
redirects use this same base automatically.

## Checks and limitations

The package was checked with TypeScript, the production Vite build, existing
streak tests, and base-path/asset/auth-redirect tests. Visual browser QA and
live email confirmation/password recovery were not available in this session.
After deployment, test signup, confirmation, a saved check-in and password reset.
Timers need the page to remain open; an unsaved session ends on reload.

## References

- https://vite.dev/guide/static-deploy.html#github-pages
- https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site
- https://supabase.com/docs/guides/auth/redirect-urls
- https://supabase.com/docs/guides/getting-started/api-keys
