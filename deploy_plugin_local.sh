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

NEW=$(basename "$NEWFILE")
cp "$NEWFILE" $D/public/assets/js/plugins/$NEW
gzip -f -c -9 $D/public/assets/js/plugins/$NEW > $D/public/assets/js/plugins/$NEW.gz

python3 - "$NEW" <<'PY'
import json, sys
NEW = sys.argv[1]
MANIFEST = '/var/www/discourse/public/assets/.manifest.json'
m = json.load(open(MANIFEST))
old = m['assets'].get('discourse/plugins/preuni-question-widget', '')
OLD = old.split('/')[-1]
m['assets']['discourse/plugins/preuni-question-widget'] = 'js/plugins/' + NEW
for s in ['', '.gz']:
    m['js/plugins/' + NEW + s] = {'digested_path': 'js/plugins/' + NEW + s, 'integrity': None}
    if OLD and OLD != NEW:
        m.pop('js/plugins/' + OLD + s, None)
json.dump(m, open(MANIFEST, 'w'))
print('manifest', OLD, '->', NEW)
PY

sv restart unicorn
echo DONE
