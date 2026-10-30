import json,subprocess,sys,os
all_devices=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','-j']))['devices']
choices=[]
for runtime,devices in all_devices.items():
 if 'iOS-' not in runtime:continue
 try:version=tuple(int(x) for x in runtime.split('iOS-')[1].split('-'))
 except ValueError:continue
 if version[0]<26:continue
 for device in devices:
  if device.get('isAvailable') and ('iPad' if '--ipad' in sys.argv else 'iPhone') in device['name']:
   score=(version, ('13-inch' in device['name']) if '--ipad' in sys.argv else ('Pro Max' in device['name']), 'Plus' in device['name'], device['name'])
   choices.append((score,device))
if not choices:sys.exit('No available requested simulator with iOS 26+ runtime')
device=max(choices,key=lambda x:x[0])[1]
print('destination=platform=iOS Simulator,id='+device['udid'])
print('device_name='+device['name'])
