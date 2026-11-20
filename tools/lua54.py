"""Run Lua 5.4 code through the system liblua5.4 (no lua binary needed).
    python3 tools/lua54.py file.lua [more.lua]   -> syntax check
    run(code) -> (ok, message)                    -> execute a chunk
"""
import ctypes, ctypes.util, sys
_lib = ctypes.CDLL("liblua5.4.so.0")
_lib.luaL_newstate.restype = ctypes.c_void_p
_lib.luaL_openlibs.argtypes = [ctypes.c_void_p]
_lib.luaL_loadstring.argtypes = [ctypes.c_void_p, ctypes.c_char_p]
_lib.luaL_loadbufferx.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p, ctypes.c_char_p]
_lib.lua_pcallk.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_void_p, ctypes.c_void_p]
_lib.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
_lib.lua_tolstring.restype = ctypes.c_char_p
_lib.lua_close.argtypes = [ctypes.c_void_p]

def run(code, name="chunk", check_only=False):
    L = _lib.luaL_newstate(); _lib.luaL_openlibs(L)
    b = code.encode()
    r = _lib.luaL_loadbufferx(L, b, len(b), ("=" + name).encode(), None)
    if r == 0 and not check_only:
        r = _lib.lua_pcallk(L, 0, 0, 0, None, None)
    msg = None if r == 0 else _lib.lua_tolstring(L, -1, None).decode(errors="replace")
    _lib.lua_close(L)
    return r == 0, msg

if __name__ == "__main__":
    bad = 0
    for f in sys.argv[1:]:
        ok, msg = run(open(f).read(), f, check_only=True)
        print(f, "OK" if ok else msg); bad += not ok
    sys.exit(1 if bad else 0)
