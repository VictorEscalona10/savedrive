import urllib.request
import json

base_url = 'https://aqgesfbxiwuaijdujoai.supabase.co'
apikey = 'sb_publishable_-DlwhfkPAMz16p3alkES8g_HrHj30Ji'

headers = {
    'apikey': apikey,
    'Authorization': f'Bearer {apikey}'
}

req = urllib.request.Request(f'{base_url}/rest/v1/?apikey={apikey}', headers=headers)
with urllib.request.urlopen(req) as resp:
    spec = json.loads(resp.read().decode('utf-8'))
    print("Definitions:", list(spec.get('definitions', {}).keys()))
    for d in ['users', 'emergency_contacts', 'user_settings', 'alarm_types']:
        schema = spec.get('definitions', {}).get(d, {})
        print(f"\n--- Table {d} ---")
        print("Required:", schema.get('required', []))
        print("Properties:", schema.get('properties', {}))
