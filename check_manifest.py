import json
MANIFEST = '/var/www/discourse/public/assets/.manifest.json'
with open(MANIFEST) as f:
    m = json.load(f)
print(m['assets']['discourse/plugins/preuni-question-widget'])
