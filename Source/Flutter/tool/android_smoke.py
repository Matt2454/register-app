"""Check a release APK on a disposable emulator, without personal accounts."""
from pathlib import Path
import os, re, subprocess, sys, time, xml.etree.ElementTree as ET

apk, out = (Path(p).resolve() for p in sys.argv[1:3])
out.mkdir(parents=True, exist_ok=True)
package = 'app.register.personal.r9457c4543606d986'
activity = package + '/it.digitalesregisterapp.MainActivity'
tools = Path(os.environ['ANDROID_HOME']) / 'build-tools/36.0.0'
key, signed = out/'test-key.p12', out/'smoke.apk'

def run(*args, **kwargs):
    return subprocess.check_output(args, **kwargs)

# This temporary CI key is used only on the test emulator and is never uploaded.
try:
    run('keytool', '-genkeypair', '-keystore', str(key), '-storepass', 'android',
        '-keypass', 'android', '-alias', 'smoke', '-dname', 'CN=Register CI',
        '-keyalg', 'RSA', '-validity', '1', stderr=subprocess.DEVNULL)
    run(str(tools/'apksigner'), 'sign', '--ks', str(key), '--ks-pass',
        'pass:android', '--out', str(signed), str(apk))
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
        nodes = [n for n in tree().iter('node') if any(
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
    # Android API 28+ exposes tooltips through getTooltipText(), which the
    # standard uiautomator XML dump omits. Find the toolbar control by bounds.
    root = tree()
    candidates = []
    width = max(int(re.findall(r'\d+', n.get('bounds', '[0,0][0,0]'))[2])
                for n in root.iter('node'))
    for node in root.iter('node'):
        b = list(map(int, re.findall(r'\d+', node.get('bounds', ''))))
        if len(b) == 4 and node.get('clickable') == 'true':
            x1,y1,x2,y2 = b
            if (x1+x2)/2 > width*.8 and y2-y1 < width*.25:
                candidates.append((y1,(x1+x2)//2,(y1+y2)//2))
    if not candidates:
        raise RuntimeError('Language toolbar control is missing')
    _, x, y = min(candidates)
    run('adb','shell','input','tap',str(x),str(y))
    wait_label('Italiano')

def screenshot(name):
    (out/name).write_bytes(run('adb', 'exec-out', 'screencap', '-p'))

try:
    launch()
    wait_label('Sign in')
    screenshot('Android-English.png')
    open_language(); tap('Italiano'); wait_label('Accedi')
    screenshot('Android-Italian.png')
    open_language(); tap('Deutsch'); wait_label('Login')
    screenshot('Android-German.png')
    run('adb', 'shell', 'am', 'force-stop', package)
    launch(); wait_label('Login')
    screenshot('Android-Cold-Launch.png')
    open_language(); tap('English'); wait_label('Sign in')
    print('Android release launch, three languages and persistence passed.')
finally:
    (out/'logcat.txt').write_bytes(run('adb', 'logcat', '-d', '-t', '1500'))
