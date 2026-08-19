#!/usr/bin/env python3
"""Ajusta el proyecto Flutter recién creado (build_app) para Reino de Niebla:
- Inyecta permisos de ubicación e internet en AndroidManifest.xml
- Cambia el nombre visible de la app
- Copia los íconos
- Sustituye analysis_options.yaml por uno sin dependencia de flutter_lints
"""
import os
import re
import shutil
import sys

project = sys.argv[1] if len(sys.argv) > 1 else "build_app"
repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

manifest_path = os.path.join(project, "android", "app", "src", "main", "AndroidManifest.xml")
with open(manifest_path) as f:
    manifest = f.read()

PERMISSIONS = """    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
    <uses-permission android:name="android.permission.WAKE_LOCK"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
"""

if "ACCESS_FINE_LOCATION" not in manifest:
    manifest = manifest.replace("<application", PERMISSIONS + "    <application", 1)

manifest = re.sub(r'android:label="[^"]*"', 'android:label="Reino de Niebla"', manifest, count=1)

with open(manifest_path, "w") as f:
    f.write(manifest)
print("Manifest actualizado.")

# Íconos
res_src = os.path.join(repo, "android_res")
res_dst = os.path.join(project, "android", "app", "src", "main", "res")
copied = 0
for folder in os.listdir(res_src):
    src_dir = os.path.join(res_src, folder)
    if not os.path.isdir(src_dir) or not folder.startswith("mipmap-"):
        continue
    dst_dir = os.path.join(res_dst, folder)
    os.makedirs(dst_dir, exist_ok=True)
    for name in os.listdir(src_dir):
        shutil.copy2(os.path.join(src_dir, name), os.path.join(dst_dir, name))
        copied += 1
print(f"Íconos copiados: {copied}")

# analysis_options.yaml sin flutter_lints
with open(os.path.join(project, "analysis_options.yaml"), "w") as f:
    f.write("analyzer:\n  errors:\n    unused_import: warning\n")
print("analysis_options.yaml reemplazado.")
