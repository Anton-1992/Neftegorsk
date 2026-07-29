#!/usr/bin/env python3
"""
Create a Godot 4.3 PCK file containing PNG texture source files.
This PCK is loaded at runtime on Android via ProjectSettings.load_resource_pack()
to provide textures that Godot's headless CI can't import (no GPU for VRAM compression).

Godot 4.3 PCK format (version 2):
  Header: magic(GDPC) + version(2) + engine_ver(4.3.0) + flags(0) + file_base(0) + reserved(64) + file_count
  Per file: path_len(4) + path(utf8) + offset(8) + size(8) + md5(16) + flags(4)
  File data follows after all entries
"""
import struct
import os
import hashlib
import sys

MAGIC = 0x43504447  # "GDPC"
FORMAT_VERSION = 2
ENGINE_MAJOR = 4
ENGINE_MINOR = 3
ENGINE_PATCH = 0

def create_pck(output_path, files_to_add):
    """Create a Godot PCK file with the given files."""
    
    # Calculate file entry sizes and data layout
    entries = []
    header_size = 4 + 4 + 4 + 4 + 4 + 4 + 8 + 64 + 4  # magic+ver+eng+flags+base+reserved+count
    
    # Calculate total entry table size
    entry_table_size = 0
    for path, source_file in files_to_add:
        path_bytes = path.encode('utf-8')
        entry_table_size += 4 + len(path_bytes) + 8 + 8 + 16 + 4  # path_len+path+offset+size+md5+flags
    
    # Data starts after header + entry table
    data_start = header_size + entry_table_size
    
    # Calculate offsets for each file
    current_offset = data_start
    for path, source_file in files_to_add:
        file_size = os.path.getsize(source_file)
        # Read file and compute MD5
        with open(source_file, 'rb') as f:
            data = f.read()
            md5 = hashlib.md5(data).digest()
        entries.append((path, path.encode('utf-8'), current_offset, file_size, md5, data))
        current_offset += file_size
    
    # Write PCK file
    with open(output_path, 'wb') as f:
        # Header
        f.write(struct.pack('<I', MAGIC))
        f.write(struct.pack('<I', FORMAT_VERSION))
        f.write(struct.pack('<I', ENGINE_MAJOR))
        f.write(struct.pack('<I', ENGINE_MINOR))
        f.write(struct.pack('<I', ENGINE_PATCH))
        f.write(struct.pack('<I', 0))  # flags: no encryption, no REL_FILEBASE
        f.write(struct.pack('<Q', 0))  # file_base: 0 (offsets are absolute from PCK start)
        f.write(b'\x00' * 64)          # reserved: 16 × uint32 = 64 bytes
        f.write(struct.pack('<I', len(entries)))  # file_count
        
        # Entry table
        for path, path_bytes, offset, size, md5, data in entries:
            f.write(struct.pack('<I', len(path_bytes)))
            f.write(path_bytes)
            f.write(struct.pack('<Q', offset))
            f.write(struct.pack('<Q', size))
            f.write(md5)
            f.write(struct.pack('<I', 0))  # flags: normal file
        
        # File data
        for path, path_bytes, offset, size, md5, data in entries:
            f.write(data)
    
    pck_size = os.path.getsize(output_path)
    print(f"Created PCK: {output_path} ({pck_size} bytes, {pck_size/1024:.1f} KB)")
    print(f"Files in PCK: {len(entries)}")
    for path, _, _, size, _, _ in entries:
        print(f"  {path} ({size} bytes)")

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 pck_packer.py <output.pck> <project_dir>")
        sys.exit(1)
    
    output_path = sys.argv[1]
    project_dir = sys.argv[2]
    
    # Collect all PNG texture files
    files_to_add = []
    for root_dir, dirs, files in os.walk(os.path.join(project_dir, 'assets')):
        for f in sorted(files):
            if f.endswith('.png'):
                source_file = os.path.join(root_dir, f)
                # Convert filesystem path to res:// path
                rel_path = os.path.relpath(source_file, project_dir)
                res_path = 'res://' + rel_path.replace(os.sep, '/')
                files_to_add.append((res_path, source_file))
    
    if not files_to_add:
        print("ERROR: No PNG files found!")
        sys.exit(1)
    
    print(f"Found {len(files_to_add)} PNG texture files")
    create_pck(output_path, files_to_add)

if __name__ == '__main__':
    main()
