# Releasing Object::PadX::Enum to CPAN

This dist uses plain `ExtUtils::MakeMaker` plus
[`cpan-upload`](https://metacpan.org/pod/cpan-upload) (from
`CPAN::Uploader`). No Dist::Zilla, no Minilla, no surprises.

## Per-release checklist

1. Make sure the working tree is clean and on `master`:

   ```sh
   git status
   git pull --ff-only
   ```

2. Bump `$VERSION` in `lib/Object/PadX/Enum.pm`.

3. Update `Changes`: replace the date on the new version's heading and
   add bullet points describing the changes since the last release.

4. Regenerate the GitHub-facing README from the pod and commit it if it
   changed (`README.md` is not in the dist, so `distcheck` cannot flag
   drift):

   ```sh
   make readme
   ```

5. Sanity-build from a clean slate:

   ```sh
   make distclean 2>/dev/null || true
   perl Makefile.PL
   make
   make test
   ```

6. Commit the release, push it and wait for CI to pass on that commit.
   `make release` refuses to run on a dirty tree, so this has to happen
   first anyway:

   ```sh
   git commit -am "Release v$(perl -Ilib -MObject::PadX::Enum -e 'print $Object::PadX::Enum::VERSION')"
   git push
   gh run watch --exit-status \
       "$(gh run list --workflow ci.yml --commit "$(git rev-parse HEAD)" --limit 1 --json databaseId --jq '.[0].databaseId')"
   ```

   If `gh run list` finds no run yet, wait a few seconds: GitHub
   creates it shortly after the push. Upload only when every job is
   green; `make release` refuses to upload otherwise. If one fails,
   fix the cause, commit, push and watch again.

7. Cut and upload the release:

   ```sh
   make release
   ```

   The `release` target:

   - Runs `make disttest` (builds the dist directory, configures it,
     and runs its tests - this is what catches missing `MANIFEST`
     entries before they reach CPAN).
   - Runs `make dist` in a second sub-make to build the tarball from
     a fresh dist directory (`disttest` alone does not create one,
     and running both as prerequisites of a single target would pack
     the `blib/` left behind by `disttest`).
   - Refuses to upload if the tarball is missing or contains build
     artefacts. PAUSE does not index such tarballs.
   - Refuses to proceed if the git working tree is dirty.
   - Refuses to proceed if a tag `v$(VERSION)` already exists.
   - Refuses to proceed unless the GitHub CI run of `HEAD` has passed
     (`make ci-check`, which needs an authenticated `gh`).
   - Runs `cpan-upload` on the freshly built tarball.

8. Tag and push:

   ```sh
   git tag -a "v$(perl -Ilib -MObject::PadX::Enum -e 'print $Object::PadX::Enum::VERSION')" \
          -m "Release v$(perl -Ilib -MObject::PadX::Enum -e 'print $Object::PadX::Enum::VERSION')"
   git push --follow-tags
   ```

   The tag must be annotated (`-a`): `git push --follow-tags` only
   pushes annotated tags, so a lightweight tag would silently stay
   local.

9. Wait ~1 hour, then verify on
   [MetaCPAN](https://metacpan.org/dist/Object-PadX-Enum).

## Recovery

- **Upload failed mid-way.** `cpan-upload` is idempotent against PAUSE
  re-uploads of the *same* tarball; just run `make release` again.
- **Uploaded a broken release.** You have 72 hours to delete it from
  PAUSE via the web UI (`https://pause.perl.org/` -> "Delete
  Files"). After that it's permanent in the BackPAN archive. Either
  way, **never reuse a version number** - bump and re-release.
- **Forgot to bump `$VERSION`.** The `release` target's "tag already
  exists" guard will catch this on the second run, but the tarball
  will already exist locally. Delete it (`rm Object-PadX-Enum-*.tar.gz`),
  bump the version, and start over.

## Notes on Object::Pad / XS::Parse::Keyword dependencies

- `Object::PadX::Enum` is an XS extension to `Object::Pad` that registers
  keywords via `XS::Parse::Keyword`. `perl Makefile.PL` captures the
  include paths from `Object::Pad::ExtensionBuilder->extra_compiler_flags`
  and `XS::Parse::Keyword::Builder->extra_compiler_flags` and feeds them
  to EUMM via `INC`. Both builder modules must be installed on the build
  host; they are declared in `CONFIGURE_REQUIRES`.
- A given release is reproducible against whichever `Object::Pad` and
  `XS::Parse::Keyword` versions were installed at build time. If you
  rely on a newer Object::Pad MOP or XPK feature, bump the minimum
  version in `PREREQ_PM` before releasing.
- `make disttest` builds and links against the installed Object::Pad
  and XS::Parse::Keyword headers, so the release step is fast and
  offline-capable as long as both are installed.
