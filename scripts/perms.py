"""Android permissions of a generated app, kept in apps/<app>/perms.txt (one key per line, e.g. CAMERA).

The owner picks them in APK Fact (app page > الصلاحيات), generation adds the ones the request asks for,
and every build adds the ones the code uses. Each key becomes one or more Android permissions.

    python scripts/perms.py list APP                 -> the keys (perms.txt + what the code uses)
    python scripts/perms.py save APP [REQUEST_FILE]  -> adds what the request and the code need to perms.txt
    python scripts/perms.py manifest APP FILE        -> adds <uses-permission> lines to AndroidManifest.xml
    python scripts/perms.py flet APP                 -> prints --android-permissions arguments for flet build
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FILE = "perms.txt"

# Key -> Android permissions. INTERNET is always added (release Flutter builds don't have it by default).
ANDROID = {
    "CAMERA": ["CAMERA"],
    "LOCATION": ["ACCESS_FINE_LOCATION", "ACCESS_COARSE_LOCATION"],
    "BACKGROUND_LOCATION": ["ACCESS_FINE_LOCATION", "ACCESS_COARSE_LOCATION", "ACCESS_BACKGROUND_LOCATION"],
    "MICROPHONE": ["RECORD_AUDIO", "MODIFY_AUDIO_SETTINGS"],
    "NOTIFICATIONS": ["POST_NOTIFICATIONS"],
    "STORAGE": ["READ_MEDIA_IMAGES", "READ_MEDIA_VIDEO", "READ_EXTERNAL_STORAGE"],
    "VIBRATE": ["VIBRATE"],
    "CALL_PHONE": ["CALL_PHONE"],
    "SMS": ["SEND_SMS"],
    "CONTACTS": ["READ_CONTACTS"],
    "BLUETOOTH": ["BLUETOOTH_CONNECT", "BLUETOOTH_SCAN"],
    "WAKE_LOCK": ["WAKE_LOCK"],
    "BIOMETRIC": ["USE_BIOMETRIC"],
}
ALWAYS = ["INTERNET", "ACCESS_NETWORK_STATE"]

# What a request asks for (Arabic and English words).
REQUEST_WORDS = {
    "CAMERA": r"كاميرا|كاميره|تصوير|التقاط صور|مسح (?:ال)?باركود|باركود|كيو ?آر|\bqr\b|camera|barcode|scan|كشاف|فلاش|flashlight|torch",
    "LOCATION": r"الموقع الجغرافي|موقعي|موقع المستخدم|تحديد الموقع|خريطة|خرائط|\bgps\b|location|geolocation|\bmaps?\b|قبلة|qibla",
    "MICROPHONE": r"ميكروفون|مايك|تسجيل (?:ال)?صوت|تسجيل صوتي|ملاحظات صوتية|بحث صوتي|microphone|voice (?:note|record|search)|record audio|speech",
    "NOTIFICATIONS": r"إشعار|اشعار|تنبيه|تذكير|منبه|notification|reminder|alarm",
    "STORAGE": r"رفع (?:ال)?صور|اختيار صور|من المعرض|الاستديو|الاستوديو|ملفات|upload|gallery|pick (?:a )?(?:photo|image|file)",
    "VIBRATE": r"اهتزاز|هزاز|vibrat|haptic",
    "CALL_PHONE": r"اتصال مباشر|زر اتصال|اتصال بالرقم|phone call|call button",
    "SMS": r"رسالة نصية|رسائل نصية|\bsms\b",
    "CONTACTS": r"جهات الاتصال|contacts",
    "BLUETOOTH": r"بلوتوث|bluetooth",
    "WAKE_LOCK": r"إبقاء الشاشة|ابقاء الشاشة|الشاشة مضيئة|keep (?:the )?screen on|wake ?lock",
    "BIOMETRIC": r"بصمة|البصمة|fingerprint|biometric|face ?id",
}

# What the code uses, per code file.
CODE_USES = {
    "index.html": {
        "CAMERA": r"getUserMedia\s*\(\s*\{[^}]*video|\bcapture\s*=|BarcodeDetector|\btorch\b",
        "MICROPHONE": r"getUserMedia\s*\(\s*\{[^}]*audio|MediaRecorder|SpeechRecognition",
        "LOCATION": r"navigator\.geolocation",
        "NOTIFICATIONS": r"Notification\.requestPermission|new Notification\s*\(|showNotification|PushNotifications",
        "VIBRATE": r"navigator\.vibrate",
        "STORAGE": r"type\s*=\s*[\"']?file\b",
        "WAKE_LOCK": r"wakeLock",
    },
    "lib/main.dart": {
        "CAMERA": r"ImageSource\.camera|package:camera/|mobile_scanner",
        "LOCATION": r"package:geolocator|package:location/",
        "MICROPHONE": r"package:record/|speech_to_text",
        "NOTIFICATIONS": r"firebase_messaging|flutter_local_notifications",
        "STORAGE": r"image_picker|file_picker",
        "VIBRATE": r"HapticFeedback|package:vibration",
        "BIOMETRIC": r"local_auth",
    },
    "main.py": {
        "CAMERA": r"\bCamera\s*\(|plyer\.camera|ft\.Camera",
        "LOCATION": r"Geolocator|plyer\.gps|flet_geolocator",
        "MICROPHONE": r"AudioRecorder|flet_audio_recorder",
        "NOTIFICATIONS": r"plyer\.notification",
        "STORAGE": r"FilePicker",
        "VIBRATE": r"HapticFeedback|vibrat",
    },
    "MainActivity.kt": {
        "CAMERA": r"Manifest\.permission\.CAMERA|TakePicture|CameraX|androidx\.camera",
        "LOCATION": r"ACCESS_FINE_LOCATION|ACCESS_COARSE_LOCATION|LocationManager|FusedLocation",
        "MICROPHONE": r"RECORD_AUDIO|MediaRecorder|SpeechRecognizer",
        "NOTIFICATIONS": r"POST_NOTIFICATIONS|NotificationCompat|NotificationManager",
        "VIBRATE": r"Vibrator|VibrationEffect",
        "STORAGE": r"GetContent|PickVisualMedia|OpenDocument",
        "CALL_PHONE": r"ACTION_CALL\b",
        "SMS": r"SmsManager",
        "CONTACTS": r"ContactsContract",
        "WAKE_LOCK": r"WakeLock|FLAG_KEEP_SCREEN_ON",
        "BIOMETRIC": r"BiometricPrompt",
    },
}


def app_dir(app):
    if not re.fullmatch(r"[a-z0-9-]+", app):
        raise SystemExit("bad app name")
    return ROOT / "apps" / app


def chosen(app):
    """The keys in perms.txt (unknown words are ignored)."""
    p = app_dir(app) / FILE
    if not p.exists():
        return []
    words = re.findall(r"[A-Z_]+", p.read_text(encoding="utf-8").upper())
    return [w for w in dict.fromkeys(words) if w in ANDROID]


def from_code(app):
    d = app_dir(app)
    found = []
    for rel, rules in CODE_USES.items():
        f = d / rel
        if not f.exists():
            continue
        code = f.read_text(encoding="utf-8", errors="ignore")
        found += [k for k, rx in rules.items() if re.search(rx, code)]
    return found


def from_request(text):
    low = (text or "").lower()
    return [k for k, rx in REQUEST_WORDS.items() if re.search(rx, low)]


def keys(app):
    return list(dict.fromkeys(chosen(app) + from_code(app)))


def android_names(app):
    names = list(ALWAYS)
    for k in keys(app):
        names += ANDROID[k]
    return list(dict.fromkeys(names))


def save(app, request=""):
    ks = list(dict.fromkeys(chosen(app) + from_request(request) + from_code(app)))
    p = app_dir(app) / FILE
    if ks or p.exists():
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("".join(k + "\n" for k in ks), encoding="utf-8")
    print("Permissions: " + (", ".join(ks) or "none"))
    return ks


def manifest(app, path):
    p = Path(path)
    xml = p.read_text(encoding="utf-8")
    add = []
    for n in android_names(app):
        if f'"android.permission.{n}"' not in xml:
            add.append(f'    <uses-permission android:name="android.permission.{n}" />')
    ks = keys(app)
    # A permission alone would hide the app from phones without the hardware; make it optional.
    if "CAMERA" in ks and '"android.hardware.camera"' not in xml:
        add.append('    <uses-feature android:name="android.hardware.camera" android:required="false" />')
    if any(k in ks for k in ("LOCATION", "BACKGROUND_LOCATION")) and '"android.hardware.location.gps"' not in xml:
        add.append('    <uses-feature android:name="android.hardware.location.gps" android:required="false" />')
    if add:
        xml = re.sub(r"(\s*)<application\b", lambda m: "\n" + "\n".join(add) + m.group(1) + "<application", xml, count=1)
        p.write_text(xml, encoding="utf-8")
    print("Android permissions: " + ", ".join(sorted(set(re.findall(r'"android\.permission\.([A-Z_]+)"', xml)))))


def main():
    cmd, *a = sys.argv[1:] or ["help"]
    if cmd == "list" and a:
        print("\n".join(keys(a[0])))
    elif cmd == "save" and a:
        req = Path(a[1]).read_text(encoding="utf-8") if len(a) > 1 and Path(a[1]).exists() else ""
        save(a[0], req)
    elif cmd == "manifest" and len(a) == 2:
        manifest(a[0], a[1])
    elif cmd == "flet" and a:
        print(" ".join(f"android.permission.{n}=true" for n in android_names(a[0])))
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
