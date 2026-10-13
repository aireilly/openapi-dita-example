# OpenDataHub MaaS API to Pages example

This repo converts the OpenDataHub Model as a Service (MaaS) back-end for the front end (BFF) API spec into DITA and builds a `Zensical` site. It uses the `com.redhat.openapi` and `com.redhat.zensical` DITA-OT plugins. GitHub Actions publishes the site to Pages on each push to `main`.

## Build locally

Install Podman, then run:

```bash
./scripts/build.sh
```

The script pulls `quay.io/rhn_support_aireilly/dita-ot`, installs both plugins in the container, and downloads the [MaaS BFF OpenAPI spec](https://github.com/opendatahub-io/odh-dashboard/blob/main/packages/maas/bff/openapi.yaml) from the [OpenDataHub Dashboard repository](https://github.com/opendatahub-io/odh-dashboard). It writes the site to `out/site`. The compact sidebar links to the home page; search and topic links reach the full reference. Set `OPENAPI_SPEC_URL` and `OPENAPI_SPEC_FILENAME` to build another spec.

This spec documents the MaaS backend in an OpenDataHub cluster. It needs a bearer token. GitHub Pages serves the docs, not the API. The header links to this repo, and the palette button switches between light and dark themes.

To preview the result, run `python3 -m http.server --directory out/site 8000` and open <http://localhost:8000>.

## Publish with GitHub Actions

The workflow checks out the `Zensical` plugin, downloads the latest `openapi2dita.zip` release, and runs the same script. In the repo settings, set GitHub Pages **Build and deployment** to **GitHub Actions**. The OpenDataHub MaaS spec builds a 3.2 MB site, far under GitHub Pages' 1 GB site limit.
