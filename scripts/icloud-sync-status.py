import plistlib, os, sys

plist_path = os.path.expanduser("~/Library/Preferences/MobileMeAccounts.plist")
try:
    with open(plist_path, "rb") as f:
        data = plistlib.load(f)
    accounts = data.get("Accounts", [])
    for acct in accounts:
        print(f"Apple ID: {acct.get('AccountID')}")
        for svc in acct.get("Services", []):
            print(f"  {svc.get('Name')}: enabled={svc.get('Enabled', False)}")
except FileNotFoundError:
    print("No iCloud account found")
