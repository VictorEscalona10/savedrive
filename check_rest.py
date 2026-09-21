import urllib.request
import json

url = 'https://aqgesfbxiwuaijdujoai.supabase.co/rest/v1/'
apikey = 'sb_publishable_-DlwhfkPAMz16p3alkES8g_HrHj30Ji'

headers = {
    'apikey': apikey,
    'Authorization': f'Bearer {apikey}',
    'Content-Type': 'application/json'
}

for table in ['users', 'emergency_contacts', 'user_settings', 'alarm_types', 'trips']:
    try:
        req = urllib.request.Request(f'{url}{table}?select=*', headers=headers)
        with urllib.request.urlopen(req) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            print(f"Table '{table}': {len(data)} rows ->", data[:2])
    except urllib.error.HTTPError as e:
        print(f"Table '{table}' HTTP Error {e.code}: {e.read().decode('utf-8')}")
    except Exception as e:
        print(f"Table '{table}' Error: {e}")
