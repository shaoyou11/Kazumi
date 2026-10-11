import hashlib,json,os,plistlib,subprocess,zipfile
from pathlib import Path
app=Path('build/ios/iphoneos/Runner.app')
info=plistlib.loads((app/'Info.plist').read_bytes())
assert info['CFBundleDisplayName']=='KazumiT'
ipa=Path('build/KazumiT.ipa')
with zipfile.ZipFile(ipa,'w',compression=zipfile.ZIP_DEFLATED) as z:
    for file in sorted(app.rglob('*')):
        if file.is_file(): z.write(file,Path('Payload/Runner.app')/file.relative_to(app))
meta={'kind':'kazumit-custom','repository':'shaoyou11/Kazumi','branch':'custom/ios','sourceCommit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'upstreamTag':Path('build/upstream-tag.txt').read_text(),'version':info['CFBundleShortVersionString'],'build':info['CFBundleVersion'],'bundleId':info['CFBundleIdentifier'],'sha256':hashlib.sha256(ipa.read_bytes()).hexdigest()}
Path('build/kazumit-build.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2))
Path('build/release-notes.txt').write_text('KazumiT iOS 定制版\n\n左右双击跳转、横屏时间电量、深色状态栏、系统画中画接力、NAS 签名更新入口。\n系统播放器内使用画中画，退出同步进度；不支持的片源返回原播放器。系统画中画不包含原播放器的弹幕及超分效果。\n\n上游：'+meta['upstreamTag']+'\n构建：'+meta['build']+'\n需个人证书签名安装，实机手势、画中画和覆盖安装待验收。\n')
