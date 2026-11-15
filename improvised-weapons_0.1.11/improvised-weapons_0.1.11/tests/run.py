"""Run simulated Lua regression tests using Lua 5.4 (binary or shared library)."""
import ctypes
import ctypes.util
from pathlib import Path
import shutil
import subprocess

root = Path(__file__).resolve().parents[1]
program = "MOD_ROOT = [=[" + str(root) + "]=]; dofile(MOD_ROOT .. '/tests/runtime.lua')"
binary = shutil.which("lua5.4") or shutil.which("lua")
if binary:
    subprocess.run([binary, "-e", program], check=True)
else:
    library = ctypes.util.find_library("lua5.4")
    if not library:
        raise SystemExit("Install Lua 5.4 to run the simulated tests.")
    lua = ctypes.CDLL(library)
    lua.luaL_newstate.restype = ctypes.c_void_p
    lua.luaL_openlibs.argtypes = [ctypes.c_void_p]
    lua.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
    lua.luaL_loadstring.restype = ctypes.c_int
    lua.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_longlong, ctypes.c_void_p]
    lua.lua_pcallk.restype = ctypes.c_int
    lua.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.POINTER(ctypes.c_size_t)]
    lua.lua_tolstring.restype = ctypes.c_char_p
    lua.lua_close.argtypes = [ctypes.c_void_p]
    state = lua.luaL_newstate()
    if not state:
        raise SystemExit("Could not initialize Lua.")
    try:
        lua.luaL_openlibs(state)
        if lua.luaL_loadstring(state, program.encode()) or lua.lua_pcallk(state, 0, 0, 0, 0, None):
            raise SystemExit(lua.lua_tolstring(state, -1, None).decode())
    finally:
        lua.lua_close(state)
