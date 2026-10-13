#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
image="${DITA_OT_IMAGE:-quay.io/rhn_support_aireilly/dita-ot}"
spec_url="${OPENAPI_SPEC_URL:-https://raw.githubusercontent.com/open-meteo/open-meteo/main/openapi/forecast.yml}"
spec_filename="${OPENAPI_SPEC_FILENAME:-open-meteo-forecast.yml}"
site_name="${SITE_NAME:-Open-Meteo Weather Forecast API}"
site_description="${SITE_DESCRIPTION:-Reference documentation for the Open-Meteo Weather Forecast API}"
openapi_plugin_zip="${OPENAPI_PLUGIN_ZIP:-}"
openapi_plugin="${OPENAPI_PLUGIN_DIR:-$repo_root/../com.redhat.openapi}"
zensical_plugin="${ZENSICAL_PLUGIN_DIR:-$repo_root/../com.redhat.zensical}"
site_url="${SITE_URL:-https://aireilly.github.io/openapi-dita-example/}"
site_url="${site_url%/}/"
output_dir="${OUTPUT_DIR:-$repo_root/out}"

if [[ -n "$openapi_plugin_zip" ]]; then
  if [[ ! -f "$openapi_plugin_zip" ]]; then
    echo "OpenAPI DITA-OT plugin ZIP not found: $openapi_plugin_zip" >&2
    exit 1
  fi
elif [[ ! -f "$openapi_plugin/plugin.xml" ]]; then
  echo "OpenAPI DITA-OT plugin not found: $openapi_plugin/plugin.xml" >&2
  exit 1
fi
if [[ ! -f "$zensical_plugin/plugin.xml" ]]; then
  echo "Zensical DITA-OT plugin not found: $zensical_plugin/plugin.xml" >&2
  exit 1
fi

build_dir="$(mktemp -d "${TMPDIR:-/tmp}/openapi-dita-example.XXXXXX")"
trap 'rm -rf "$build_dir"' EXIT
if [[ -n "$openapi_plugin_zip" ]]; then
  cp -a "$openapi_plugin_zip" "$build_dir/openapi2dita.zip"
else
  mkdir -p "$build_dir/plugins/openapi"
  cp -a "$openapi_plugin/plugin.xml" "$openapi_plugin/build_openapi2dita.xml" \
    "$openapi_plugin/lib" "$openapi_plugin/xsl" "$build_dir/plugins/openapi/"
fi
mkdir -p "$build_dir/plugins/zensical"
cp -a "$zensical_plugin/plugin.xml" "$zensical_plugin/build_zensical.xml" \
  "$zensical_plugin/conductor.xml" "$zensical_plugin/xsl" \
  "$zensical_plugin/python" "$zensical_plugin/resources" "$build_dir/plugins/zensical/"

podman pull "$image"
podman run --rm \
  --volume "$build_dir:/build:Z" \
  --env "OPENAPI_SPEC_URL=$spec_url" \
  --env "OPENAPI_SPEC_FILENAME=$spec_filename" \
  --env "SITE_NAME=$site_name" \
  --env "SITE_DESCRIPTION=$site_description" \
  --env "SITE_URL=$site_url" \
  "$image" bash -euc '
    apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq --no-install-recommends \
      ca-certificates curl python3 python3-venv zip

    python3 -m venv /tmp/zensical-venv
    /tmp/zensical-venv/bin/pip install --disable-pip-version-check "zensical==0.0.69"
    export PATH="/tmp/zensical-venv/bin:$PATH"

    spec="/build/$OPENAPI_SPEC_FILENAME"
    curl --fail --location --retry 3 --silent --show-error \
      "$OPENAPI_SPEC_URL" \
      --output "$spec"

    cat > /build/zensical.toml <<EOF
[project]
site_name = "$SITE_NAME"
site_url = "$SITE_URL"
site_description = "$SITE_DESCRIPTION"
nav = ["index.md"]
EOF

    if [[ ! -f /build/openapi2dita.zip ]]; then
      (cd /build/plugins/openapi && zip -qr /build/openapi2dita.zip plugin.xml build_openapi2dita.xml lib xsl)
    fi
    (cd /build/plugins/zensical && zip -qr /build/com.redhat.zensical.zip plugin.xml build_zensical.xml conductor.xml xsl python resources)
    dita install /build/openapi2dita.zip
    dita install /build/com.redhat.zensical.zip

    dita --input="$spec" --format=openapi2dita --output=/build/api-dita
    map_name="${OPENAPI_SPEC_FILENAME%.*}"
    map="/build/api-dita/${map_name}.ditamap"
    test -f "$map"
    dita --input="$map" --format=zensical --output=/build/site-root \
      -Dzensical.config=/build/zensical.toml
    test -f /build/site-root/site/index.html
  '

mkdir -p "$output_dir"
rm -rf "$output_dir/site"
cp -a "$build_dir/site-root/site" "$output_dir/site"
echo "Built $site_name Pages site at $output_dir/site"
