# يضيف صلاحية الإنترنت ورابط العودة من تسجيل جوجل إلى AndroidManifest (آمن للتكرار)
import pathlib, re, sys
p = pathlib.Path('android/app/src/main/AndroidManifest.xml')
s = p.read_text(encoding='utf-8')
if 'io.supabase.nafis' in s:
    sys.exit(0)
s = s.replace('<application', '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
s = re.sub(r'android:label="[^"]*"', 'android:label="نافس"', s, count=1)
intent = '''<intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="io.supabase.nafis" android:host="login-callback"/>
            </intent-filter>
        </activity>'''
s = s.replace('</activity>', intent, 1)
p.write_text(s, encoding='utf-8')
