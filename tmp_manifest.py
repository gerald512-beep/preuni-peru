import json
MANIFEST = '/var/www/discourse/public/assets/.manifest.json'
OLD = 'preuni-question-widget_main.CEIJgR-kdgmwujt.digested.js'
NEW = 'preuni-question-widget_main.BKbK8u-jlgssgi9.digested.js'
with open(MANIFEST) as f: m = json.load(f)
m['assets']['discourse/plugins/preuni-question-widget'] = 'js/plugins/' + NEW
m['js/plugins/' + NEW] = {'digested_path': 'js/plugins/' + NEW, 'integrity': None}
m['js/plugins/' + NEW + '.gz'] = {'digested_path': 'js/plugins/' + NEW + '.gz', 'integrity': None}
for s in ['', '.gz']:
    m.pop('js/plugins/' + OLD + s, None)
with open(MANIFEST, 'w') as f: json.dump(m, f)
print('Manifest updated: ' + OLD + ' -> ' + NEW)
