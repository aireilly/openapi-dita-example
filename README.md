# OpenAPI to Pages example

This repo turns the Open-Meteo weather forecast API spec into DITA, then builds a Zensical site. It uses the `com.redhat.openapi` and `com.redhat.zensical` DITA-OT plugins. GitHub Actions publishes the site to Pages on each push to `main`.

## Build locally

Install Podman. Keep both plugin repos next to this repo at `../com.redhat.openapi` and `../com.redhat.zensical`. Then run:

```bash
./scripts/build.sh
```

The script pulls `quay.io/rhn_support_aireilly/dita-ot`, installs both plugins in the container, and downloads the [Open-Meteo forecast spec](https://github.com/open-meteo/open-meteo/blob/main/openapi/forecast.yml). It writes the site to `out/site`. The compact sidebar links to the home page; search and topic links reach the full reference. Set `OPENAPI_PLUGIN_DIR` and `ZENSICAL_PLUGIN_DIR` to use plugin checkouts at other paths. Set `OPENAPI_SPEC_URL` and `OPENAPI_SPEC_FILENAME` to build another spec.

To preview the result, run `python3 -m http.server --directory out/site 8000` and open <http://localhost:8000>.

## Publish with GitHub Actions

The workflow checks out the Zensical plugin, downloads the latest `openapi2dita.zip` release, and runs the same script. In the repo settings, set GitHub Pages **Build and deployment** to **GitHub Actions**. The Open-Meteo spec describes its live forecast API and is small enough for the Pages site limit.
