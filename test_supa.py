import os
from supabase import create_client

url = 'https://aqgesfbxiwuaijdujoai.supabase.co'
key = 'sb_publishable_-DlwhfkPAMz16p3alkES8g_HrHj30Ji'

supa = create_client(url, key)
print("Connected to Supabase client successfully")
