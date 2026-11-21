# Pruebas de API v11 contra el backend real (Oracle con kampu_tours_v11.sql recién instalado).
# Uso: python3 pruebas/api_v11.py   (KAMPU_API cambia la URL base)
import json, urllib.request, urllib.error, datetime, sys
import os
B = os.environ.get("KAMPU_API", "http://localhost:8082/lp2_gp2/api/v1")
ok = fallas = 0
def req(m, path, body=None, token=None, headers=None, raw=False):
    h = {"Content-Type": "application/json"}
    if token: h["Authorization"] = "Bearer " + token
    if headers: h.update(headers)
    r = urllib.request.Request(B + path, data=None if body is None else json.dumps(body).encode(), method=m, headers=h)
    try:
        with urllib.request.urlopen(r) as resp:
            data = resp.read()
            return resp.status, (data if raw else (json.loads(data) if data else None))
    except urllib.error.HTTPError as e:
        d = e.read()
        try: d = json.loads(d)
        except Exception: pass
        return e.code, d
def check(nombre, cond, extra=""):
    global ok, fallas
    if cond: ok += 1; print("[OK]   ", nombre, extra)
    else: fallas += 1; print("[FALLA]", nombre, extra)
def login(u): 
    s, d = req("POST", "/auth/login", {"username": u, "password": "Kampu2026*"}); assert s == 200, (u, s, d); return d
hoy = datetime.date.today()

print("== 1. Seguridad: el hueco de las cabeceras X-* esta cerrado")
s, d = req("GET", "/usuarios", headers={"X-Usuario": "kadmin", "X-Rol": "ADMIN", "X-Usuario-Id": "1"})
check("Cabeceras X-Rol: ADMIN sin sesion -> 401", s == 401, str(s))
s, d = req("GET", "/reservas"); check("Reservas sin sesion -> 401 (antes era publico)", s == 401, str(s))
s, d = req("GET", "/clientes", token="abc.def"); check("Token falsificado -> 401", s == 401, str(s))
adm = login("kadmin"); ven = login("kventas"); ope = login("koperador")
tk = adm["token"]; partes = tk.split(".")
import base64
cuerpo = base64.urlsafe_b64decode(partes[0] + "==").decode().replace("|ADMIN|", "|ADMIN|")
falso = base64.urlsafe_b64encode(base64.urlsafe_b64decode(partes[0]+"==").decode().replace("|VENDEDOR|","|ADMIN|").encode()).decode().rstrip("=")
s, d = req("GET", "/usuarios", token=falso + "." + ven["token"].split(".")[1])
check("Token de Ventas editado a ADMIN (firma invalida) -> 401", s == 401, str(s))
s, d = req("GET", "/usuarios", token=adm["token"]); check("Admin lista usuarios -> 200", s == 200, str(s))
s, d = req("GET", "/usuarios", token=ven["token"]); check("Ventas lista usuarios -> 403", s == 403, f"{s} {d}")
s, d = req("GET", "/reservas", token=ope["token"]); check("Operador ve reservas -> 403 (no tiene VER_RESERVAS)", s == 403, str(s))
s, d = req("POST", "/pagos", {"reservaId": 1, "monto": 1, "metodoPago": "EFECTIVO"}, token=ope["token"])
check("Operador registra un pago -> 403", s == 403, str(s))

print("== 2. Visitante sin cuenta: personaliza y calcula")
s, paquetes = req("GET", "/paquetes"); laguna = next(p for p in paquetes if p["nombre"] == "Laguna Azul Full Day")
check("Paquete trae servicios incluidos", "Paseo en bote" in laguna["serviciosIncluidos"])
s, srv = req("GET", f"/servicios-adicionales/paquete/{laguna['paqueteId']}")
kayak = next(x for x in srv if x["nombre"] == "Kayak en la laguna"); foto = next(x for x in srv if x["nombre"] == "Fotografia profesional")
check("Servicios del paquete + generales, sin inactivos", all(x["estado"] == "ACTIVO" for x in srv) and len(srv) == 3, str([x["nombre"] for x in srv]))
fecha = str(hoy + datetime.timedelta(days=8))
datos = {"paqueteId": laguna["paqueteId"], "fecha": fecha, "adultos": 2, "ninos": 2, "lugarRecojoId": None,
         "servicios": [{"servicioId": kayak["servicioId"], "cantidad": 4}, {"servicioId": foto["servicioId"], "cantidad": 1}],
         "observaciones": "Dos ninos de 6 y 9 anios"}
s, calc = req("POST", "/cotizaciones/calcular", datos)
check("Calculo en servidor: 4x120 + 4x35 + 150 = 770", s == 200 and float(calc["total"]) == 770.0, f"{s} total={calc.get('total') if isinstance(calc,dict) else calc}")
mal = dict(datos, servicios=[{"servicioId": foto["servicioId"], "cantidad": 3}])
s, d = req("POST", "/cotizaciones/calcular", mal); check("Foto (por grupo) x3 -> 400", s == 400, str(d))
datos_precio = dict(datos); datos_precio["precioUnitario"] = 1
s, calc2 = req("POST", "/cotizaciones/calcular", datos_precio)
check("Un precio enviado por el navegador se ignora", s == 200 and float(calc2["total"]) == 770.0)

print("== 3. Guardar, recuperar, modificar y PDF")
s, cre = req("POST", "/cotizaciones", datos); codigo, clave = cre["codigo"], cre["clave"]
check("Guardar -> codigo + clave", s == 201 and codigo.startswith("KC-") and len(clave) == 14, f"{codigo} {clave}")
check("Origen INVITADO y estado GENERADA", cre["cotizacion"]["origen"] == "INVITADO" and cre["cotizacion"]["estado"] == "GENERADA")
check("La respuesta publica no expone ids internos", cre["cotizacion"]["cotizacionId"] is None)
s, d = req("POST", "/cotizaciones/acceso", {"codigo": codigo, "clave": "AAAA-BBBB-CCCC"}); check("Clave ajena -> 403", s == 403, f"{s} {d}")
s, d = req("POST", "/cotizaciones/acceso", {"codigo": "KC-2026-000002", "clave": clave}); check("Mi clave en cotizacion ajena -> 403", s == 403, str(s))
s, d = req("POST", "/cotizaciones/acceso", {"codigo": codigo.lower(), "clave": clave.lower().replace("-", "")})
check("Recuperar con codigo + clave (sin importar mayusculas/guiones)", s == 200 and d["codigo"] == codigo)
m = dict(datos, adultos=3, ninos=0, servicios=[{"servicioId": kayak["servicioId"], "cantidad": 2}])
s, d = req("PUT", f"/cotizaciones/{codigo}", {"clave": clave, "datos": m})
check("Modificar recalcula: 3x120 + 2x35 = 430", s == 200 and float(d["total"]) == 430.0, str(d.get("total") if isinstance(d,dict) else d))
check("Historial: alta + modificacion", len(d["historial"]) == 2 and d["historial"][1]["actor"] == "Tú", str(d["historial"]))
s, pdf = req("POST", f"/cotizaciones/{codigo}/pdf", {"clave": clave}, raw=True)
check("PDF descargable", s == 200 and pdf[:4] == b"%PDF", f"{s} {len(pdf)} bytes")
open("cotizacion-prueba.pdf", "wb").write(pdf)
s, d = req("POST", f"/cotizaciones/{codigo}/pdf", {"clave": "XXXX-XXXX-XXXX"}, raw=True); check("PDF sin la clave -> 403", s == 403, str(s))

print("== 4. Solicitar la reserva sin cuenta")
sol = {"clave": clave, "nombreCompleto": "Rocio Paredes Lopez", "tipoDocumento": "DNI", "numeroDocumento": "74125896",
       "email": "rocio.paredes@example.com", "telefono": "+51 912345678", "observaciones": "Llegamos un dia antes"}
s, d = req("POST", f"/cotizaciones/{codigo}/solicitud", dict(sol, numeroDocumento="123")); check("DNI invalido -> 400", s == 400 and "DNI" in d["error"], str(d))
s, d = req("POST", f"/cotizaciones/{codigo}/solicitud", sol); check("Solicitud -> SOLICITADA", s == 200 and d["estado"] == "SOLICITADA", str(s))
s, d = req("PUT", f"/cotizaciones/{codigo}", {"clave": clave, "datos": m}); check("Modificar tras solicitar -> 400", s == 400, str(d))
s, d = req("POST", "/auth/login", {"username": "rocio.paredes@example.com", "password": "x"})
check("No se creo una cuenta para el visitante", s == 400 and "Usuario o contraseña" in d["error"], str(d))

print("== 5. El operador ve y gestiona la solicitud")
s, lista = req("GET", "/cotizaciones?estado=SOLICITADA", token=ope["token"])
mia = next((c for c in lista if c["codigo"] == codigo), None)
check("Operador ve la solicitud con contacto", s == 200 and mia and mia["email"] == "rocio.paredes@example.com")
s, d = req("POST", f"/cotizaciones/gestion/{mia['cotizacionId']}/confirmar", token=ven["token"] if False else None)
check("Confirmar sin sesion -> 401", s == 401, str(s))
gu = login("kguia")
s, d = req("POST", f"/cotizaciones/gestion/{mia['cotizacionId']}/confirmar", token=gu["token"]); check("Guia confirma -> 403", s == 403, str(s))
s, d = req("POST", f"/cotizaciones/gestion/{mia['cotizacionId']}/confirmar", token=ope["token"])
check("Operador confirma -> RESERVADA con reserva PENDIENTE", s == 200 and d["estado"] == "RESERVADA" and d["estadoReserva"] == "PENDIENTE", f"{s} {d.get('codigoReserva') if isinstance(d,dict) else d}")
check("Reserva por S/ 430 (adicionales incluidos)", float(d["totalReserva"]) == 430.0, str(d.get("totalReserva")))
s, d2 = req("POST", "/cotizaciones/acceso", {"codigo": codigo, "clave": clave})
check("El visitante ve su reserva con el codigo", d2["codigoReserva"] == d["codigoReserva"] and d2["estadoReserva"] == "PENDIENTE")
s, res = req("GET", "/reservas", token=ven["token"]); r = next(x for x in res if x["codigoReserva"] == d["codigoReserva"])
check("Ventas ve la reserva: canal WEB, adicionales 70", r["canal"] == "WEB" and float(r["montoAdicionales"]) == 70.0, f"{r['canal']} {r['montoAdicionales']}")
s, cli = req("GET", "/clientes", token=ven["token"]); c = next(x for x in cli if x["numeroDocumento"] == "74125896")
check("Cliente creado SIN cuenta web", c.get("cuentaWeb") is False, str(c.get("cuentaWeb")))
s, dd = req("POST", f"/cotizaciones/gestion/{mia['cotizacionId']}/rechazar", {"motivo": "x"}, token=ope["token"])
check("No se rechaza una ya reservada -> 400", s == 400, str(dd))

print("== 6. Guia y conductor diferenciados")
s, a = req("GET", "/mis-asignaciones", token=gu["token"])
check("Guia ve sus salidas y ningun traslado", s == 200 and len(a["salidas"]) > 0 and a["traslados"] == [], f"{len(a['salidas'])} salidas")
sal = a["salidas"][0]["salidaId"]
s, pas = req("GET", f"/mis-asignaciones/salidas/{sal}/pasajeros", token=gu["token"]); check("Guia ve el manifiesto de su salida", s == 200, f"{len(pas)} pasajeros")
check("Manifiesto sin montos ni contacto", all("montoTotal" not in p and "email" not in p for p in pas))
s, sal_todas = req("GET", "/salidas"); otra = next(x["salidaId"] for x in sal_todas if x["salidaId"] not in [y["salidaId"] for y in a["salidas"]])
s, d = req("GET", f"/mis-asignaciones/salidas/{otra}/pasajeros", token=gu["token"]); check("Guia y salida ajena -> 403", s == 403, str(s))
for ruta in ["/reservas", "/clientes", "/pagos", "/cotizaciones", "/usuarios", "/resumen-paquetes"]:
    s, d = req("GET", ruta, token=gu["token"]); check(f"Guia GET {ruta} -> 403", s == 403, str(s))
co = login("kconductor")
s, a2 = req("GET", "/mis-asignaciones", token=co["token"])
check("Conductor ve sus traslados (vehiculo y ruta) y ninguna salida de guia", s == 200 and len(a2["traslados"]) > 0 and a2["salidas"] == [] and a2["traslados"][0]["placa"], f"{len(a2['traslados'])} traslados")
s, d = req("GET", "/mis-asignaciones", token=ope["token"]); check("Operador en mis-asignaciones -> 403", s == 403, str(s))
check("Permisos de la sesion: guia solo VER_ASIGNACIONES_PROPIAS", gu["permisos"] == ["VER_ASIGNACIONES_PROPIAS"], str(gu["permisos"]))

print("== 7. Admin da cuenta a un guia sin cuenta (opcional) y la revoca")
s, sin = req("GET", "/usuarios/personal-sin-cuenta", token=adm["token"])
carlos = next(p for p in sin if p["nombreCompleto"].startswith("Carlos"))
check("Carlos (guia) aparece sin cuenta; Rosa no", not any(p["nombreCompleto"].startswith("Rosa") for p in sin))
s, d = req("POST", "/usuarios", {"username": "csangama", "nombreCompleto": "Carlos Sangama Amasifuen", "email": "carlos@kampu.pe",
          "rol": "CONDUCTOR", "personalId": carlos["personalId"], "password": "Kampu2026*", "confirmacion": "Kampu2026*"}, token=adm["token"])
check("Guia como CONDUCTOR -> 400", s == 400, str(d))
s, d = req("POST", "/usuarios", {"username": "csangama", "nombreCompleto": "Carlos Sangama Amasifuen", "email": "carlos@kampu.pe",
          "rol": "GUIA", "password": "Kampu2026*", "confirmacion": "Kampu2026*"}, token=adm["token"])
check("GUIA sin persona -> 400", s == 400, str(d))
s, nuevo = req("POST", "/usuarios", {"username": "csangama", "nombreCompleto": "Carlos Sangama Amasifuen", "email": "carlos@kampu.pe",
          "rol": "GUIA", "personalId": carlos["personalId"], "password": "Kampu2026*", "confirmacion": "Kampu2026*"}, token=adm["token"])
check("Cuenta GUIA ligada a Carlos", s == 201 and nuevo["personalNombre"].startswith("Carlos"), str(s))
cs = login("csangama"); s, a3 = req("GET", "/mis-asignaciones", token=cs["token"])
check("Carlos ve solo SUS salidas", s == 200 and all(x["salidaId"] not in [y["salidaId"] for y in a["salidas"]] for x in a3["salidas"]), f"{len(a3['salidas'])}")
s, d = req("PATCH", f"/usuarios/{nuevo['usuarioId']}/acceso", {"activo": False}, token=adm["token"])
s, d = req("GET", "/mis-asignaciones", token=cs["token"]); check("Cuenta desactivada: su token deja de valer al instante -> 401", s == 401, str(s))

print("== 8. Regresiones: cuentas existentes")
s, d = req("GET", "/reservas", token=ven["token"]); check("Ventas: reservas", s == 200)
s, d = req("GET", "/operaciones", token=ope["token"]); check("Operador: trafico", s == 200)
s, d = req("GET", "/auditoria?pagina=0&tamanio=5", token=adm["token"]); check("Admin: auditoria", s == 200, str(s))
mar = login("maria.rios@example.com"); s, d = req("GET", "/portal/paquetes", token=mar["token"]); check("Cliente: mis paquetes", s == 200 and len(d) > 0)
s, d = req("GET", "/reservas", token=mar["token"]); check("Cliente ve reservas de otros -> 403", s == 403, str(s))
s, cre2 = req("POST", "/cotizaciones", datos, token=mar["token"]); check("Cliente con cuenta cotiza -> origen CLIENTE", cre2["cotizacion"]["origen"] == "CLIENTE", cre2["cotizacion"]["origen"])
s, mias = req("GET", "/cotizaciones/mias", token=mar["token"]); check("Cliente lista sus cotizaciones", any(c["codigo"] == cre2["codigo"] for c in mias))
s, d = req("POST", "/cotizaciones/acceso", {"codigo": cre2["codigo"], "clave": ""}, token=mar["token"]); check("Cliente abre la suya sin clave", s == 200)
s, d = req("POST", "/cotizaciones/acceso", {"codigo": codigo, "clave": ""}, token=mar["token"]); check("Cliente abre una ajena sin clave -> 403", s == 403, str(s))
print(f"\nRESULTADO: {ok} OK, {fallas} FALLAS")
