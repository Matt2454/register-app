"""Check a release APK on a disposable emulator, without personal accounts."""
from pathlib import Path
import os, re, subprocess, sys, time, xml.etree.ElementTree as ET

apk, out = (Path(p).resolve() for p in sys.argv[1:3])
out.mkdir(parents=True, exist_ok=True)
package = 'app.register.personal.r9457c4543606d986'
activity = package + '/it.digitalesregisterapp.MainActivity'
signer = apk.parent/'apksigner.jar'
key, signed = out/'test-key.p12', out/'smoke.apk'

def run(*args, **kwargs):
    return subprocess.check_output(args, **kwargs)

# This temporary CI key is used only on the test emulator and is never uploaded.
try:
    run('keytool', '-genkeypair', '-keystore', str(key), '-storepass', 'android',
        '-keypass', 'android', '-alias', 'smoke', '-dname', 'CN=Register CI',
        '-keyalg', 'RSA', '-validity', '1', stderr=subprocess.DEVNULL)
    run('java', '-jar', str(signer), 'sign', '--ks', str(key), '--ks-pass',
        'pass:android', '--v4-signing-enabled', 'false', '--out', str(signed), str(apk))
    run('adb', 'install', '-r', str(signed))
finally:
    key.unlink(missing_ok=True)
    signed.unlink(missing_ok=True)

run('adb', 'logcat', '-c')

def launch():
    run('adb', 'shell', 'am', 'start', '-W', '-n', activity)

def tree():
    run('adb', 'shell', 'uiautomator', 'dump', '/sdcard/register-window.xml',
        stderr=subprocess.DEVNULL)
    data = run('adb', 'exec-out', 'cat', '/sdcard/register-window.xml')
    (out/'last-window.xml').write_bytes(data)
    return ET.fromstring(data)

def wait_label(label, timeout=60):
    until = time.monotonic() + timeout
    while time.monotonic() < until:
        if not run('adb', 'shell', 'pidof', package).strip():
            raise RuntimeError('Android app process exited')
        root = tree()
        # A fresh Google APIs image can show a Launcher ANR during boot.
        # Dismiss only that unrelated system dialog; app ANRs still fail.
        if any("Pixel Launcher isn't responding" in n.get('text', '')
               for n in root.iter('node')):
            close = next((n for n in root.iter('node') if n.get('text') == 'Close app'), None)
            if close is not None:
                x1,y1,x2,y2 = map(int, re.findall(r'\d+', close.get('bounds', '')))
                run('adb','shell','input','tap',str((x1+x2)//2),str((y1+y2)//2))
                launch()
                continue
        nodes = [n for n in root.iter('node') if any(
            n.get(a, '').strip() == label for a in ['text', 'content-desc'])]
        if nodes:
            return nodes
        time.sleep(1)
    raise RuntimeError('Android control did not appear: ' + label)

def tap(label):
    nodes = wait_label(label)
    nodes.sort(key=lambda n: n.get('clickable') != 'true')
    bounds = re.findall(r'\d+', nodes[0].get('bounds', ''))
    if len(bounds) != 4:
        raise RuntimeError('Missing bounds for ' + label)
    x1, y1, x2, y2 = map(int, bounds)
    run('adb', 'shell', 'input', 'tap', str((x1+x2)//2), str((y1+y2)//2))

def open_language():
    root = tree()
    for label in ['Language', 'Lingua', 'Sprache']:
        if any(n.get('content-desc', '').strip() == label for n in root.iter('node')):
            tap(label)
            wait_label('Italiano')
            return
    raise RuntimeError('Language toolbar control is missing')


def screenshot(name):
    (out/name).write_bytes(run('adb', 'exec-out', 'screencap', '-p'))

try:
    launch()
    wait_label('Language')
    screenshot('Android-English.png')
    open_language(); tap('Italiano'); wait_label('Lingua')
    screenshot('Android-Italian.png')
    open_language(); tap('Deutsch'); wait_label('Sprache')
    screenshot('Android-German.png')
    run('adb', 'shell', 'am', 'force-stop', package)
    launch(); wait_label('Sprache')
    screenshot('Android-Cold-Launch.png')
    open_language(); tap('English'); wait_label('Language')
    print('Android release launch, three languages and persistence passed.')
finally:
    screenshot('Android-Final-State.png')
    (out/'logcat.txt').write_bytes(run('adb', 'logcat', '-d', '-t', '3000'))
