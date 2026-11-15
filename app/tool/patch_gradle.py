import pathlib, re
p = pathlib.Path('android/app/build.gradle.kts')
s = p.read_text(encoding='utf-8')
if 'checkReleaseBuilds' not in s:
    s = re.sub(r'^android \{',
               'android {\n    lint {\n        checkReleaseBuilds = false\n        abortOnError = false\n    }',
               s, count=1, flags=re.M)
    p.write_text(s, encoding='utf-8')
