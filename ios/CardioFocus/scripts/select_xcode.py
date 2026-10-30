import pathlib,subprocess,re,sys
choices=[]
for app in pathlib.Path('/Applications').glob('Xcode*.app'):
 developer=app/'Contents/Developer'
 p=subprocess.run(['xcodebuild','-version'],env={**__import__('os').environ,'DEVELOPER_DIR':str(developer)},capture_output=True,text=True)
 m=re.search(r'Xcode (\d+)\.(\d+)',p.stdout)
 if p.returncode==0 and m and int(m[1])>=26:choices.append(((int(m[1]),int(m[2])),developer))
if not choices:sys.exit('No Xcode 26+ installation available. Current App Store SDK requirement is not met.')
selected=sorted(choices,key=lambda x:x[0],reverse=True)[0][1]
subprocess.run(['sudo','xcode-select','--switch',str(selected)],check=True)
print('Selected',selected)
