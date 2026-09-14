# Changelog

Release notes for the published Thoth images. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-09-14

First published release. `ghcr.io/root-chain-ventures-llc/thoth:0.1.0`

### Added

- **Contacts** — search-first home page, full directory with filters, contact detail and
  edit, photo upload, custom fields, duplicate hint on create, supervisor links and an org
  chart, CSV/vCard import and export, group management.
- **Calendar** — birthdays and anniversaries from contact dates, subscribed external
  calendars (ICS) refreshed on a loop, month and upcoming views, and a published ICS feed.
- **Family and work modes** — work mode turns on the work fields (department, job title,
  supervisor, work email) and stores birth month only; family mode asks for full birthdates.
  Partial vCard dates (`--MM-DD`, `--MM`) are first class.
- **Portal page** — configurable link tiles for a work landing page.
- **Accounts and SSO** — local accounts with invitations and password reset over SMTP, OIDC
  sign-in for Microsoft Entra ID and Authentik with ID tokens verified against the provider
  JWKS, and group-to-role mapping (admin / editor / viewer) re-applied on every sign-in,
  guarded so a wrong group ID cannot orphan the last admin.
- **Microsoft 365 directory sync** — Graph sync of directory users into contacts, with
  status reporting.
- **CardDAV** — RFC 6352 endpoint at `/dav` with app passwords, so phones and Contacts.app
  sync the directory.
- **Email** — SMTP settings, invitation and reset mail, and a birthday digest scheduled in a
  configurable time zone.
- **HTTPS everywhere** — one listener serves TLS and answers plain HTTP with a 301 (plus
  `/api/health` for probes), a self-signed certificate is generated into the data volume when
  none is supplied, HSTS and `upgrade-insecure-requests` are always on, and an `http://`
  `BASE_URL` refuses to start.
- **Themes** — light, dark and hacker-green, applied before first paint, with no external
  fonts or CDNs.
- **Branding** — instance name, logo and colour for white-labelling.
- **Operations** — activity log, one-click SQLite backup, and a build stamp reported at
  Settings → Maintenance → *About this instance* and `GET /api/version`.

[0.1.0]: https://github.com/Root-Chain-Ventures-LLC/RCV-Thoth/releases/tag/v0.1.0
