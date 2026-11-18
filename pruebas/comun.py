"""Utilidades comunes de las pruebas de la API (solo biblioteca estándar de Python 3)."""
import json, os, random, sys, threading, urllib.error, urllib.request

B = os.environ.get('KAMPU_API', 'http://localhost:8082/lp2_gp2/api/v1')


def cabeceras(sesion):
    """Lo que envía el frontend después del login: quién hace la petición (usuario, rol e id)."""
    if not sesion: return {}
    h = {'X-Usuario': sesion['username'], 'X-Rol': sesion['rol']}
    if sesion.get('usuarioId'): h['X-Usuario-Id'] = str(sesion['usuarioId'])
    if sesion.get('clienteId'): h['X-Cliente-Id'] = str(sesion['clienteId'])
    return h


def req(sesion, m, u, d=None):
    r = urllib.request.Request(B + u, method=m, data=None if d is None else json.dumps(d).encode(),
                               headers={'Content-Type': 'application/json', **cabeceras(sesion)})
    try:
        with urllib.request.urlopen(r, timeout=60) as x:
            b = x.read(); ct = x.headers.get('Content-Type', '')
            return x.status, (json.loads(b) if b and 'json' in ct else b.decode(errors='ignore'))
    except urllib.error.HTTPError as e:
        b = e.read()
        try: return e.code, json.loads(b)
        except Exception: return e.code, b.decode(errors='ignore')


def login(u, p):
    c, r = req(None, 'POST', '/auth/login', {'username': u, 'password': p})
    if c != 200: sys.exit(f'No se pudo iniciar sesión como {u} ({c}): {r}. ¿Backend arriba y datos de demostración instalados?')
    return r   # sesión: usuario, rol y permisos


def a_la_vez(funcs):
    """Ejecuta las funciones en hilos que arrancan juntos (barrera) y devuelve sus resultados en orden."""
    res = [None] * len(funcs); barrera = threading.Barrier(len(funcs))
    def run(i, f): barrera.wait(); res[i] = f()
    hs = [threading.Thread(target=run, args=(i, f)) for i, f in enumerate(funcs)]
    [h.start() for h in hs]; [h.join() for h in hs]; return res


# Documentos y nombres únicos en cada ejecución (los nombres solo admiten letras)
_doc = iter(range(random.randrange(40000000, 79000000, 1000), 99999999, 7))
_LETRAS = 'abcdefghijklmnopqrstuvwxyz'
def nombre():
    k = next(_doc); return 'Pasajero ' + ''.join(_LETRAS[(k // (26 ** i)) % 26] for i in range(5)).capitalize()
def pax(n):
    return [{'nombreCompleto': nombre(), 'tipoDocumento': 'DNI', 'numeroDocumento': str(next(_doc)),
             'nacionalidad': 'Peruana', 'fechaNacimiento': None} for _ in range(n)]
