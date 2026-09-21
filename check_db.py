import os
from supabase import create_client

url = 'https://aqgesfbxiwuaijdujoai.supabase.co'
key = 'sb_publishable_-DlwhfkPAMz16p3alkES8g_HrHj30Ji'

supa = create_client(url, key)

print("--- Testing 'users' table ---")
try:
    res = supa.from_('users').select('*').execute()
    print("users count:", len(res.data))
    print("users sample:", res.data[:3])
except Exception as e:
    print("Error querying users:", e)

print("--- Testing 'emergency_contacts' table ---")
try:
    res = supa.from_('emergency_contacts').select('*').execute()
    print("emergency_contacts count:", len(res.data))
    print("emergency_contacts sample:", res.data[:3])
except Exception as e:
    print("Error querying emergency_contacts:", e)

print("--- Testing 'user_settings' table ---")
try:
    res = supa.from_('user_settings').select('*').execute()
    print("user_settings count:", len(res.data))
    print("user_settings sample:", res.data[:3])
except Exception as e:
    print("Error querying user_settings:", e)
