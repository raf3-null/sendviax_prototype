#!/usr/bin/env python3
"""Generate a self-contained Xcode project; no third-party dependencies/downloads."""
import argparse
import shutil
import hashlib
import json
import plistlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PROJECT = ROOT / 'Sendviax.xcodeproj'
objects = {}

def object_id(name):
    return hashlib.sha256(name.encode()).hexdigest()[:24].upper()

def add(identity, isa, **values):
    key = object_id(identity)
    objects[key] = dict(isa=isa, **values)
    return key

def encode(value, depth=0):
    if isinstance(value, dict):
        return '{\n' + ''.join('\t' * (depth+1) + json.dumps(k) + ' = ' + encode(v, depth+1) + ';\n' for k,v in value.items()) + '\t' * depth + '}'
    if isinstance(value, list):
        return '(\n' + ''.join('\t' * (depth+1) + encode(v, depth+1) + ',\n' for v in value) + '\t' * depth + ')'
    return json.dumps(str(value))

def plist(name, value):
    with (ROOT / name).open('wb') as out:
        plistlib.dump(value, out)

def configuration_list(name, settings):
    configs=[]
    for mode in ('Debug', 'Release'):
        extra={'SWIFT_OPTIMIZATION_LEVEL': '-Onone' if mode=='Debug' else '-O'}
        configs.append(add(name+mode, 'XCBuildConfiguration', name=mode, buildSettings={**settings, **extra}))
    return add(name+'configlist', 'XCConfigurationList', buildConfigurations=configs, defaultConfigurationIsVisible=0, defaultConfigurationName='Debug')

def main():
    global ROOT, PROJECT
    parser=argparse.ArgumentParser()
    parser.add_argument('--output', help='Generate an isolated kit, preserving existing Xcode signing settings')
    parser.add_argument('--without-app-group', action='store_true', help='Sample keyboard tests only; shared inbox unavailable')
    args=parser.parse_args()
    if args.output:
        source=ROOT; ROOT=Path(args.output).resolve(); ROOT.mkdir(parents=True,exist_ok=True)
        for filename in ('App.swift','Shared.swift','ShareController.swift','KeyboardController.swift'):
            shutil.copy2(source/filename,ROOT/filename)
        PROJECT=ROOT/'Sendviax.xcodeproj'
    PROJECT.mkdir(exist_ok=True)
    common={'CFBundleDevelopmentRegion':'en', 'CFBundleExecutable':'$(EXECUTABLE_NAME)', 'CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)', 'CFBundleInfoDictionaryVersion':'6.0', 'CFBundleName':'$(PRODUCT_NAME)', 'CFBundleShortVersionString':'0.2', 'CFBundleVersion':'2'}
    plist('App-Info.plist', {**common, 'CFBundlePackageType':'APPL', 'CFBundleDisplayName':'Sendviax', 'SendviaxRelayURL':'$(SENDVIAX_RELAY_URL)', 'SendviaxKeychainGroup':'$(AppIdentifierPrefix)dev.sendviax.mobile.session', 'UILaunchScreen':{}, 'UISupportedInterfaceOrientations':['UIInterfaceOrientationPortrait','UIInterfaceOrientationLandscapeLeft','UIInterfaceOrientationLandscapeRight']})
    plist('Share-Info.plist', {**common, 'CFBundlePackageType':'XPC!', 'CFBundleDisplayName':'Sendviax', 'NSExtension':{'NSExtensionPointIdentifier':'com.apple.share-services', 'NSExtensionPrincipalClass':'$(PRODUCT_MODULE_NAME).ShareController', 'NSExtensionAttributes':{'NSExtensionActivationRule':{'NSExtensionActivationSupportsText':True,'NSExtensionActivationSupportsWebURLWithMaxCount':1}}}})
    plist('Keyboard-Info.plist', {**common, 'CFBundlePackageType':'XPC!', 'CFBundleDisplayName':'Sendviax Keyboard', 'SendviaxKeychainGroup':'$(AppIdentifierPrefix)dev.sendviax.mobile.session', 'NSExtension':{'NSExtensionPointIdentifier':'com.apple.keyboard-service','NSExtensionPrincipalClass':'$(PRODUCT_MODULE_NAME).KeyboardController','NSExtensionAttributes':{'IsASCIICapable':False,'PrefersRightToLeft':False,'PrimaryLanguage':'th','RequestsOpenAccess':True}}})
    for target in ('App', 'Share', 'Keyboard'):
        plist(target+'.entitlements', {} if args.without_app_group else {'com.apple.security.application-groups':['group.dev.sendviax.mobile'], **({'keychain-access-groups':['$(AppIdentifierPrefix)dev.sendviax.mobile.session']} if target in ('App','Keyboard') else {})})
    refs=[]
    for name in ('App.swift','Shared.swift','ShareController.swift','App-Info.plist','Share-Info.plist','App.entitlements','Share.entitlements','KeyboardController.swift','Keyboard-Info.plist','Keyboard.entitlements'):
        kind='sourcecode.swift' if name.endswith('.swift') else 'text.plist.xml'
        refs.append(add(name, 'PBXFileReference', lastKnownFileType=kind, path=name, sourceTree='<group>'))
    refs.append(add('Assets.xcassets','PBXFileReference',lastKnownFileType='folder.assetcatalog',path='Assets.xcassets',sourceTree='<group>'))
    app_product=add('app-product','PBXFileReference', explicitFileType='wrapper.application', path='Sendviax.app', sourceTree='BUILT_PRODUCTS_DIR')
    share_product=add('share-product','PBXFileReference', explicitFileType='wrapper.app-extension', path='SendviaxShare.appex', sourceTree='BUILT_PRODUCTS_DIR')
    keyboard_product=add('keyboard-product','PBXFileReference', explicitFileType='wrapper.app-extension', path='SendviaxKeyboard.appex', sourceTree='BUILT_PRODUCTS_DIR')
    products=add('products','PBXGroup', name='Products', children=[app_product,share_product,keyboard_product], sourceTree='<group>')
    group=add('rootgroup','PBXGroup', children=refs+[products], sourceTree='<group>')
    base={'SDKROOT':'iphoneos','IPHONEOS_DEPLOYMENT_TARGET':'16.0','SWIFT_VERSION':'5.0','TARGETED_DEVICE_FAMILY':'1,2','CLANG_ENABLE_MODULES':'YES','CODE_SIGN_STYLE':'Automatic','GENERATE_INFOPLIST_FILE':'NO','SUPPORTED_PLATFORMS':'iphoneos iphonesimulator','SWIFT_EMIT_LOC_STRINGS':'NO'}
    share_id=object_id('share-target')
    proxy=add('share-proxy','PBXContainerItemProxy',containerPortal=object_id('project'),proxyType=1,remoteGlobalIDString=share_id,remoteInfo='SendviaxShare')
    dependency=add('share-dependency','PBXTargetDependency',target=share_id,targetProxy=proxy)
    embed=add('embedbuild','PBXBuildFile', fileRef=share_product, settings={'ATTRIBUTES':['RemoveHeadersOnCopy']})
    embed_phase=add('embedphase','PBXCopyFilesBuildPhase',buildActionMask=2147483647,dstPath='',dstSubfolderSpec=13,files=[embed],name='Embed App Extensions',runOnlyForDeploymentPostprocessing=0)
    keyboard_id=object_id('keyboard-target')
    keyboard_proxy=add('keyboard-proxy','PBXContainerItemProxy',containerPortal=object_id('project'),proxyType=1,remoteGlobalIDString=keyboard_id,remoteInfo='SendviaxKeyboard')
    keyboard_dependency=add('keyboard-dependency','PBXTargetDependency',target=keyboard_id,targetProxy=keyboard_proxy)
    keyboard_embed=add('keyboard-embed','PBXBuildFile',fileRef=keyboard_product,settings={'ATTRIBUTES':['RemoveHeadersOnCopy']})
    objects[embed_phase]['files'].append(keyboard_embed)
    targets=[]
    for target, name, sources, product, bundle in [('app-target','Sendviax',['App.swift','Shared.swift'],app_product,'dev.sendviax.mobile'),('share-target','SendviaxShare',['ShareController.swift','Shared.swift'],share_product,'dev.sendviax.mobile.share'),('keyboard-target','SendviaxKeyboard',['KeyboardController.swift','Shared.swift'],keyboard_product,'dev.sendviax.mobile.keyboard')]:
        is_app=target=='app-target'; prefix='App' if is_app else ('Keyboard' if target=='keyboard-target' else 'Share')
        builds=[add(target+s,'PBXBuildFile',fileRef=object_id(s)) for s in sources]
        phase=add(target+'sources','PBXSourcesBuildPhase',buildActionMask=2147483647,files=builds,runOnlyForDeploymentPostprocessing=0)
        frameworks=add(target+'frameworks','PBXFrameworksBuildPhase',buildActionMask=2147483647,files=[],runOnlyForDeploymentPostprocessing=0)
        settings={**base,'PRODUCT_NAME':name,'PRODUCT_BUNDLE_IDENTIFIER':bundle,'INFOPLIST_FILE':prefix+'-Info.plist','CODE_SIGN_ENTITLEMENTS':prefix+'.entitlements','LD_RUNPATH_SEARCH_PATHS':'$(inherited) @executable_path/Frameworks @executable_path/../../Frameworks'}
        if is_app: settings['ASSETCATALOG_COMPILER_APPICON_NAME']='AppIcon'
        if not is_app: settings.update(SKIP_INSTALL='YES',APPLICATION_EXTENSION_API_ONLY='YES')
        config=configuration_list(target,settings)
        resource_files=[add('icon-build','PBXBuildFile',fileRef=object_id('Assets.xcassets'))] if is_app else []
        resources=add(target+'resources','PBXResourcesBuildPhase',buildActionMask=2147483647,files=resource_files,runOnlyForDeploymentPostprocessing=0)
        targets.append(add(target,'PBXNativeTarget',name=name,productName=name,productReference=product,productType='com.apple.product-type.application' if is_app else 'com.apple.product-type.app-extension',buildConfigurationList=config,buildPhases=[phase,frameworks,resources]+([embed_phase] if is_app else []),buildRules=[],dependencies=[dependency,keyboard_dependency] if is_app else []))
    project_config=configuration_list('project', {'CLANG_ENABLE_MODULES':'YES'})
    project=add('project','PBXProject',attributes={'LastUpgradeCheck':'1600'},buildConfigurationList=project_config,compatibilityVersion='Xcode 14.0',developmentRegion='en',hasScannedForEncodings=0,knownRegions=['en','Base'],mainGroup=group,productRefGroup=products,projectDirPath='',projectRoot='',targets=targets)
    data={'archiveVersion':1,'classes':{},'objectVersion':56,'objects':objects,'rootObject':project}
    (PROJECT/'project.pbxproj').write_text('// !$*UTF8*$!\n'+encode(data)+'\n')
    print(PROJECT)

if __name__=='__main__': main()
