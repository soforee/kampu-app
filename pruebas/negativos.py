"""Casos que el sistema debe rechazar (reglas de negocio y seguridad)."""
import datetime as dt, sys
from comun import req, login, pax
V = login('ventas', 'ventas123'); O = login('operador', 'operador123')
A=login('admin','admin123'); ok=0; mal=[]
def esp(nombre,cond,extra=''):
    global ok
    if cond: ok+=1
    else: mal.append((nombre,str(extra)[:200]))
hoy=dt.date.today()
esp('cupos agotados', req(V,'POST','/reservas',{'clienteId':5,'contacto':None,'salidaId':6,'observaciones':'','pasajeros':pax(11)})[0]==400)
esp('salida con fecha pasada', req(V,'POST','/salidas',{'paqueteId':2,'fechaInicio':str(hoy-dt.timedelta(days=1)),'cuposMaximos':10,'guiaId':None,'estado':'PROGRAMADA'})[0]==400)
esp('reserva en salida cancelada', req(V,'POST','/reservas',{'clienteId':5,'contacto':None,'salidaId':9,'observaciones':'','pasajeros':pax(1)})[0]==400)
esp('reserva sin pasajeros', req(V,'POST','/reservas',{'clienteId':5,'contacto':None,'salidaId':3,'observaciones':'','pasajeros':[]})[0]==400)
esp('pago negativo', req(V,'POST','/pagos',{'reservaId':9,'monto':-5,'moneda':'PEN','metodoPago':'Yape','codigoTransaccion':'X','estadoTransaccion':'APROBADO'})[0]==400)
esp('pago a reserva anulada', req(V,'POST','/pagos',{'reservaId':7,'monto':5,'moneda':'PEN','metodoPago':'Yape','codigoTransaccion':'X','estadoTransaccion':'APROBADO'})[0]==400)
_c,_r=req(V,'POST','/reservas',{'clienteId':5,'contacto':None,'salidaId':5,'observaciones':'','pasajeros':pax(1)})
esp('confirmar sin adelanto', _c==201 and req(V,'PATCH','/reservas/%s/confirmar'%_r['reservaId'])[0]==400)
esp('completar viaje futuro', req(V,'PATCH','/reservas/5/completar')[0]==400)
esp('salida con cupos menores a vendidos', req(V,'PUT','/salidas/1',{'paqueteId':1,'fechaInicio':str(hoy-dt.timedelta(days=1)),'cuposMaximos':1,'guiaId':1,'estado':'CONFIRMADA'})[0]==400)
esp('cancelar salida con reservas', req(V,'PATCH','/salidas/1/ejecucion',{'estado':'CANCELADA'})[0] == 400)
esp('guía en dos salidas cruzadas', req(V,'POST','/salidas',{'paqueteId':2,'fechaInicio':str(hoy+dt.timedelta(days=4)),'cuposMaximos':10,'guiaId':2,'estado':'PROGRAMADA'})[0]==400)
dia=(hoy+dt.timedelta(days=15)).isoformat()
c,o=req(O,'POST','/operaciones',{'salidaId':None,'origenId':7,'destinoId':8,'vehiculoId':None,'conductorId':None,'paxProgramados':30,'horaProgramadaSalida':dia+'T09:00','horaEstimadaLlegada':dia+'T09:40','observaciones':''})
oid=o['operacionId']
esp('vehículo en mantenimiento', req(O,'PATCH',f'/operaciones/{oid}/asignar',{'vehiculoId':7,'conductorId':10})[0]==400)
esp('capacidad insuficiente', req(O,'PATCH',f'/operaciones/{oid}/asignar',{'vehiculoId':6,'conductorId':10})[0]==400)
esp('conductor de otro proveedor', req(O,'PATCH',f'/operaciones/{oid}/asignar',{'vehiculoId':4,'conductorId':10})[0]==400)
esp('conductor OCUPADO', req(O,'PATCH',f'/operaciones/{oid}/asignar',{'vehiculoId':4,'conductorId':9})[0]==400)
esp('proveedor suspendido', req(O,'PATCH',f'/operaciones/{oid}/asignar',{'vehiculoId':8,'conductorId':11})[0]==400)
esp('llegada antes de salida', req(O,'POST','/operaciones',{'salidaId':None,'origenId':7,'destinoId':8,'vehiculoId':None,'conductorId':None,'paxProgramados':2,'horaProgramadaSalida':dia+'T10:00','horaEstimadaLlegada':dia+'T09:00','observaciones':''})[0]==400)
esp('cliente: sin permisos internos', 'VER_CLIENTES' not in login('ana.ramirez@mail.com','cliente123')['permisos'])
esp('portal sin sesión de cliente', req(None,'GET','/portal/paquetes')[0] in (400,403))
esp('login incorrecto', req(None,'POST','/auth/login',{'username':'admin','password':'mala'})[0] == 400)
# Reglas operativas (datos de demostración: la salida 1 empezó ayer; el traslado KMP-006 usa el vehículo 5)
esp('anular reserva con salida iniciada (Ventas)', req(V,'PATCH','/reservas/4/anular',{'formaReembolso':None,'usuarioId':None})[0]==400)
_A=login('admin','admin123'); _c,_v=req(_A,'GET','/vehiculos/5'); _v['estado']='MANTENIMIENTO'
esp('vehículo con traslado asignado a mantenimiento', req(_A,'PUT','/vehiculos/5',_v)[0]==400)
esp('vehículo sigue OPERATIVO', req(_A,'GET','/vehiculos/5')[1]['estado']=='OPERATIVO')
print(f'NEGATIVOS: {ok} correctos, {len(mal)} fallidos'); [print('  FALLA',m) for m in mal]
sys.exit(1 if mal else 0)
