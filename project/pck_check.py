#!/usr/bin/env python3
"""
Parse Godot 4.3 PCK file embedded in APK and list all resource paths.
Verifies that PNG textures are included (force-included via include_filter)
and that PNG .import files are NOT present (deleted to force direct PNG loading).

Godot 4.3 PCK format (version 2):
  - Magic: 0x43504447 ("GDPC")
  - Format version: uint32 (= 2)
  - Engine version: major(uint32), minor(uint32), patch(uint32)
  - Pack flags: uint32 (ENCRYPTED=bit0, REL_FILEBASE=bit1)
  - File base: uint64 (base offset for file data, 0 if REL_FILEBASE)
  - Reserved: 16 * uint32 (= 64 bytes)
  - File count: uint32
  - Per file: 
      path_len(uint32), path(utf8), offset(uint64), size(uint64), 
      md5(16 bytes), flags(uint32)
  
  For embedded PCK (appended to APK/exe):
  - Footer at end of file: [ds(uint64)] [GDPC(uint32)]
  - ds = size of PCK section (from header start to footer)
  - PCK header is at: file_end - 12 - ds
"""
import struct
import sys
import os

MAGIC = 0x43504447  # "GDPC" in little-endian
FORMAT_V2 = 2

def find_embedded_pck(filepath):
    """Find PCK footer at end of file, then locate PCK header."""
    with open(filepath, 'rb') as f:
        f.seek(0, 2)
        file_size = f.tell()
        
        if file_size < 12:
            print("ERROR: File too small to contain PCK!")
            return None
        
        f.seek(file_size - 4)
        magic = struct.unpack('<I', f.read(4))[0]
        if magic != MAGIC:
            print(f"ERROR: No GDPC magic at end of file! Last 4 bytes: 0x{magic:08x}")
            return None
        
        f.seek(file_size - 12)
        ds = struct.unpack('<Q', f.read(8))[0]
        
        pck_offset = file_size - 12 - ds
        
        f.seek(pck_offset)
        header_magic = struct.unpack('<I', f.read(4))[0]
        if header_magic != MAGIC:
            print(f"ERROR: No GDPC magic at offset {pck_offset} (0x{pck_offset:x})")
            for i in range(8):
                f.seek(pck_offset + i)
                test_magic = struct.unpack('<I', f.read(4))[0]
                if test_magic == MAGIC:
                    pck_offset = pck_offset + i
                    print(f"Found GDPC at adjusted offset {pck_offset}")
                    break
            else:
                return None
        
        print(f"PCK embedded at offset: {pck_offset} (0x{pck_offset:x})")
        print(f"PCK size (ds): {ds} bytes ({ds/1024:.1f} KB)")
        return pck_offset

def parse_pck(filepath, pck_offset):
    """Parse PCK starting at given offset."""
    files = []
    with open(filepath, 'rb') as f:
        f.seek(pck_offset)
        
        magic = struct.unpack('<I', f.read(4))[0]
        if magic != MAGIC:
            print("ERROR: Invalid PCK magic!")
            return files
        
        fmt_version = struct.unpack('<I', f.read(4))[0]
        eng_major = struct.unpack('<I', f.read(4))[0]
        eng_minor = struct.unpack('<I', f.read(4))[0]
        eng_patch = struct.unpack('<I', f.read(4))[0]
        pack_flags = struct.unpack('<I', f.read(4))[0]
        file_base = struct.unpack('<Q', f.read(8))[0]
        reserved = f.read(64)
        file_count = struct.unpack('<I', f.read(4))[0]
        
        print(f"PCK format version: {fmt_version}")
        print(f"Engine version: {eng_major}.{eng_minor}.{eng_patch}")
        print(f"Pack flags: {pack_flags}")
        print(f"File base: {file_base}")
        print(f"File count: {file_count}")
        print("---")
        
        is_rel_filebase = bool(pack_flags & 2)
        
        for i in range(file_count):
            path_len = struct.unpack('<I', f.read(4))[0]
            path_bytes = f.read(path_len)
            try:
                path = path_bytes.decode('utf-8')
            except:
                path = path_bytes.decode('utf-8', errors='replace')
            
            ofs = struct.unpack('<Q', f.read(8))[0]
            size = struct.unpack('<Q', f.read(8))[0]
            md5 = f.read(16)
            file_flags = struct.unpack('<I', f.read(4))[0]
            
            if is_rel_filebase:
                actual_offset = pck_offset + file_base + ofs
            else:
                actual_offset = file_base + ofs
            
            files.append((path, actual_offset, size, file_flags))
        
        return files

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 pck_check.py <apk_or_pck_file>")
        sys.exit(1)
    
    filepath = sys.argv[1]
    if not os.path.exists(filepath):
        print(f"ERROR: File not found: {filepath}")
        sys.exit(2)
    
    apk_size = os.path.getsize(filepath)
    print(f"File size: {apk_size / 1024 / 1024:.2f} MB ({apk_size} bytes)")
    
    with open(filepath, 'rb') as f:
        start = f.read(4)
        start_magic = struct.unpack('<I', start)[0]
        if start_magic == MAGIC:
            pck_offset = 0
            print("Standalone PCK file detected")
        else:
            pck_offset = find_embedded_pck(filepath)
            if pck_offset is None:
                sys.exit(1)
    
    files = parse_pck(filepath, pck_offset)
    
    if len(files) == 0:
        print("ERROR: No files found in PCK!")
        sys.exit(1)
    
    # Categorize files
    tscn_files = []
    gd_files = []
    png_files = []
    ctex_files = []
    import_files = []
    other_files = []
    
    for path, offset, size, flags in files:
        if path.endswith('.tscn') or path.endswith('.scn'):
            tscn_files.append((path, size))
        elif path.endswith('.gd') or path.endswith('.gdc') or path.endswith('.gde'):
            gd_files.append((path, size))
        elif path.endswith('.png'):
            png_files.append((path, size))
        elif path.endswith('.ctex') or path.endswith('.stex'):
            ctex_files.append((path, size))
        elif path.endswith('.import'):
            import_files.append((path, size))
        else:
            other_files.append((path, size))
    
    print(f"\n=== TSCN/SCN scenes ({len(tscn_files)}) ===")
    for path, size in sorted(tscn_files):
        print(f"  {path} ({size} bytes)")
    
    print(f"\n=== GD/GDC scripts ({len(gd_files)}) ===")
    for path, size in sorted(gd_files):
        print(f"  {path} ({size} bytes)")
    
    print(f"\n=== PNG textures ({len(png_files)}) — CRITICAL! ===")
    for path, size in sorted(png_files):
        print(f"  {path} ({size} bytes)")
    
    print(f"\n=== CTEX/STEX imported textures ({len(ctex_files)}) ===")
    for path, size in sorted(ctex_files):
        print(f"  {path} ({size} bytes)")
    
    print(f"\n=== .import files ({len(import_files)}) — should NOT have PNG .import! ===")
    for path, size in sorted(import_files):
        has_png = '.png.import' in path or '.svg.import' in path
        marker = " *** BAD! Should be deleted! ***" if has_png else ""
        print(f"  {path} ({size} bytes){marker}")
    
    print(f"\n=== Other files ({len(other_files)}) ===")
    for path, size in sorted(other_files)[:20]:
        print(f"  {path} ({size} bytes)")
    if len(other_files) > 20:
        print(f"  ... and {len(other_files) - 20} more")
    
    print(f"\n=== SUMMARY ===")
    print(f"Total files in PCK: {len(files)}")
    print(f"TSCN scenes: {len(tscn_files)}")
    print(f"GD scripts: {len(gd_files)}")
    print(f"PNG textures: {len(png_files)} (expect >= 25)")
    print(f"CTEX imports: {len(ctex_files)} (expect 0 — deleted)")
    print(f".import files: {len(import_files)} (no PNG .import)")
    
    # Check for expected game files
    expected_scenes = [
        "res://scenes/main_menu/main_menu.tscn",
        "res://scenes/district_map/district_map.tscn",
        "res://scenes/level/level.tscn",
        "res://scenes/level/station_node.tscn",
        "res://scenes/upgrade_tree/upgrade_tree.tscn",
        "res://autoload/boot_loader.tscn",
    ]
    expected_scripts = [
        "res://autoload/boot_loader.gd",
        "res://autoload/debug_logger.gd",
        "res://autoload/game_manager.gd",
        "res://scenes/main_menu/main_menu.gd",
    ]
    expected_pngs = [
        "res://assets/ui/map_background.png",
        "res://assets/ui/district_bg.png",
        "res://assets/ui/station_icon.png",
        "res://assets/icons/app_icon.png",
        "res://assets/ui/station_standard.png",
        "res://assets/maps/tileset_ground.png",
        "res://assets/maps/tileset_roads.png",
    ]
    
    all_paths = set(p for p, _, _, _ in files)
    
    print(f"\n=== EXPECTED SCENES ===")
    for exp in expected_scenes:
        found = exp in all_paths
        if not found:
            alt = exp.replace('.tscn', '.scn')
            found = alt in all_paths
        print(f"  {exp}: {'FOUND' if found else 'MISSING!'}")
    
    print(f"\n=== EXPECTED SCRIPTS ===")
    for exp in expected_scripts:
        found = exp in all_paths
        if not found:
            alt = exp.replace('.gd', '.gdc')
            found = alt in all_paths
        print(f"  {exp}: {'FOUND' if found else 'MISSING!'}")
    
    print(f"\n=== EXPECTED PNG TEXTURES — MOST CRITICAL! ===")
    png_missing = 0
    for exp in expected_pngs:
        found = exp in all_paths
        if not found:
            png_missing += 1
        print(f"  {exp}: {'FOUND' if found else 'MISSING! ***'}")
    
    # Check that PNG .import files are NOT in PCK
    png_import_in_pck = [p for p, _, _, _ in files if '.png.import' in p or '.svg.import' in p]
    print(f"\n=== PNG .import files in PCK (should be 0!) ===")
    if png_import_in_pck:
        print(f"  BAD! Found {len(png_import_in_pck)} PNG/SVG .import files in PCK!")
        for p in png_import_in_pck:
            print(f"    {p}")
    else:
        print(f"  GOOD! No PNG/SVG .import files in PCK — ResourceLoader will load PNGs directly")
    
    if png_missing > 0:
        print(f"\n*** CRITICAL: {png_missing} expected PNG textures MISSING from PCK! ***")
    elif png_import_in_pck:
        print(f"\n*** WARNING: PNG .import files found in PCK — will redirect to broken .ctex! ***")
    else:
        print(f"\n*** All PNG textures FOUND, no .import redirects — GAME SHOULD WORK! ***")

if __name__ == '__main__':
    main()
