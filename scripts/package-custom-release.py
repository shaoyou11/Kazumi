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
Path('build/release-notes.txt').write_text('KazumiT iOS 定制版\n\n修复个人构建因缺少官方镜像授权导致搜索失败，并区分接口错误与真实空结果。\n片源搜索按名称、别名和季数排序，保留全部结果和手动选择。\n追番同步显示部分失败及完成数量，重试成功后清除提示。\n系统播放接力保留进度、倍速和暂停状态，防止旧播放器覆盖新集进度。\n\n保留双击手势、时间电量、画中画、AirPlay、DLNA、下载和更新入口。本次未加入 FVP。\n\n上游：'+meta['upstreamTag']+'\n构建：'+meta['build']+'\n需个人证书签名安装，真机播放与覆盖安装待验收。\n')
