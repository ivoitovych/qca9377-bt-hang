import json
import sys

# usage: summarize_issue.py ISSUE.json [NOTES.json] [maxchars]
d = json.load(open(sys.argv[1]))
mx = int(sys.argv[3]) if len(sys.argv) > 3 else 1500
if isinstance(d, list):
    for i in d:
        print(i['iid'], i['state'], i['created_at'][:10], i['updated_at'][:10], i['title'])
    sys.exit(0)
print('TITLE:', d['title'])
print('STATE:', d['state'], 'created', d['created_at'][:10], 'updated', d['updated_at'][:10],
      'closed', (d.get('closed_at') or '-')[:10], 'labels', d.get('labels'))
print('URL:', d['web_url'])
print('DESC:', (d.get('description') or '')[:mx])
if len(sys.argv) > 2 and sys.argv[2] != '-':
    n = json.load(open(sys.argv[2]))
    print('NOTES:', len(n))
    for x in reversed(n):
        if x.get('system'):
            continue
        print('--', x['created_at'][:10], x['author']['username'], ':', x['body'][:400].replace('\n', ' '))
