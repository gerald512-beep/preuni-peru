#!/bin/bash
# LOCAL ONLY. Compile + publish the preuni plugin bundle inside the Discourse container.
# Run after docker cp of the changed files:  wsl -d Ubuntu -- sudo docker cp deploy_plugin_local.sh app:/tmp/ ; sudo docker exec app bash /tmp/deploy_plugin_local.sh
set -e
set -o pipefail
P=/var/www/discourse/plugins/preuni-question-widget
D=/var/www/discourse

ruby -c $P/plugin.rb
ruby -c $P/app/controllers/preuni_errores_controller.rb

cd $D

# Step 1: compile just this plugin's JS into app/assets/generated/ (fast, ~10s).
BUNDLE_WITHOUT=development:test RAILS_ENV=production su discourse -c "bundle exec rails assets:precompile:build_plugins" 2>&1 | tail -15

GEN=$D/app/assets/generated/preuni-question-widget/js/plugins
NEWFILE=$(ls -t $GEN/*.js | head -1)
SIZE=$(stat -c %s "$NEWFILE")
echo "bundle: $NEWFILE ($SIZE bytes)"
if [ "$SIZE" -lt 5000 ]; then
  echo "COMPILE ERROR (bundle too small)"
  head -c 2000 "$NEWFILE"
  exit 1
fi

# Step 2: Propshaft's own precompile step -- copies app/assets/generated/** into
# public/assets/, brotli-compresses it, and rewrites public/assets/.manifest.json.
# This is what assets:precompile:build_plugins does NOT do on its own; running
# it standalone (instead of the full, slow `rails assets:precompile`, which also
# rebuilds the ember app, recompiles all CSS and tries a MaxMind download) is
# the fast path that actually makes the new bundle get served.
BUNDLE_WITHOUT=development:test RAILS_ENV=production su discourse -c "bundle exec rails runner 'Rails.application.assets.processor.process'"

sv restart unicorn
echo DONE
