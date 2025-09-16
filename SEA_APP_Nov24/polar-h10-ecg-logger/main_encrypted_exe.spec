# -*- mode: python ; coding: utf-8 -*-


a = Analysis(
    ['src/main_encrypted.py'],
    pathex=[],
    binaries=[('/home/georgiac/miniconda3/envs/ctl_polarh10_logger_conda_env_2024/lib/libmkl_core.so.2', '.bin'), ('/home/georgiac/miniconda3/envs/ctl_polarh10_logger_conda_env_2024/lib/libmkl_intel_thread.so.2', '.bin'), ('/home/georgiac/miniconda3/envs/ctl_polarh10_logger_conda_env_2024/lib/libmkl_def.so.2', '.bin'), ('/home/georgiac/miniconda3/envs/ctl_polarh10_logger_conda_env_2024/lib/libiomp5.so', '.bin'), ('/home/georgiac/miniconda3/envs/ctl_polarh10_logger_conda_env_2024/lib/libtinfo.so.6', '.bin')],
    datas=[('src', 'src')],
    hiddenimports=['asyncio', 'json', 'polarh10_ecg_logger', 'mkl'],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name='main_encrypted',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)
