"""Pruebas funcionales de la API: permisos por rol, CRUD, reservas, pagos, tráfico, portal y auditoría."""
import datetime as dt, sys
from comun import req
ok=fail=0
def chk(nombre,cond,extra=''):
    global ok,fail
    if cond: ok+=1
    else: fail+=1; print('  FALLA:',nombre,str(extra)[:300])
def login(u,p): return req(None,'POST','/auth/login',{'username':u,'password':p})[1]['token']
T={r:login(u,p) for r,u,p in [('ADMIN','admin','admin123'),('VENDEDOR','ventas','ventas123'),('OPERADOR','operador','operador123'),('CLIENTE','ana.ramirez@mail.com','cliente123')]}
hoy=dt.date.today()
# 1. Lecturas por rol (matriz de permisos)
lecturas={'/usuarios':'A','/auditoria':'A','/clientes':'AV','/reservas':'AV','/pasajeros':'AV','/pagos':'AV',
 '/proveedores':'AVO','/personal':'AVO','/vehiculos':'AVO','/lugares':'AVO','/operaciones':'AVO','/operaciones/estados':'AVO',
 '/resumen-paquetes':'AVO','/paquetes':'AVOC','/salidas':'AVOC','/portal/paquetes':'C','/salidas/1/manifiesto':'AVO','/auditoria/filtros':'A'}
letra={'ADMIN':'A','VENDEDOR':'V','OPERADOR':'O','CLIENTE':'C'}
for u,quien in lecturas.items():
    for rol,t in T.items():
        s,b=req(t,'GET',u); esperado=200 if letra[rol] in quien else 403
        chk(f'GET {u} {rol}',s==esperado,(s,b))
chk('sin token 401',req(None,'GET','/reservas')[0]==401)
A=T['ADMIN']; V=T['VENDEDOR']; O=T['OPERADOR']; C=T['CLIENTE']
# 2. Proveedor CRUD
s,p=req(A,'POST','/proveedores',{'nombreComercial':'Prueba Transportes SAC','ruc':'20999888777','telefono':'+51 977000111','esPropio':False,'estado':'ACTIVO'}); chk('crear proveedor',s==201,p)
pid=p['proveedorId']
chk('RUC duplicado 409',req(A,'POST','/proveedores',{'nombreComercial':'X','ruc':'20999888777','telefono':'','esPropio':False,'estado':'ACTIVO'})[0]==409)
chk('segundo propio rechazado',req(A,'POST','/proveedores',{'nombreComercial':'X','ruc':'20999888711','telefono':'','esPropio':True,'estado':'ACTIVO'})[0]==400)
s,_=req(A,'PUT',f'/proveedores/{pid}',{'nombreComercial':'Prueba Transportes SAC','ruc':'20999888777','telefono':'+51 977000111','esPropio':False,'estado':'SUSPENDIDO'}); chk('editar proveedor',s==200)
chk('ventas no gestiona logística 403',req(V,'POST','/proveedores',{'nombreComercial':'X','ruc':'20999888712','telefono':'','esPropio':False,'estado':'ACTIVO'})[0]==403)
# 3. Personal y vehículo del proveedor (proveedor ACTIVO de nuevo)
req(A,'PUT',f'/proveedores/{pid}',{'nombreComercial':'Prueba Transportes SAC','ruc':'20999888777','telefono':'+51 977000111','esPropio':False,'estado':'ACTIVO'})
s,c=req(O,'POST','/personal',{'proveedorId':pid,'nombreCompleto':'Mario Prueba Soto','rol':'CONDUCTOR','telefono':'+51 966000222','numLicencia':'P12345678','catLicencia':'A-IIIb','vencLicencia':str(hoy+dt.timedelta(days=400)),'estado':'DISPONIBLE'}); chk('crear conductor',s==201,c)
chk('conductor sin licencia 400',req(O,'POST','/personal',{'proveedorId':pid,'nombreCompleto':'Sin Licencia','rol':'CONDUCTOR','telefono':'','numLicencia':'','catLicencia':'','vencLicencia':None,'estado':'DISPONIBLE'})[0]==400)
s,v=req(O,'POST','/vehiculos',{'proveedorId':pid,'placa':'PRB-001','tipoVehiculo':'VAN','marcaModelo':'Toyota Hiace','capacidadPax':12,'proxMantenimiento':str(hoy+dt.timedelta(days=200)),'estado':'OPERATIVO'}); chk('crear vehículo',s==201,v)
chk('placa duplicada 409',req(O,'POST','/vehiculos',{'proveedorId':pid,'placa':'PRB-001','tipoVehiculo':'VAN','marcaModelo':'','capacidadPax':12,'proxMantenimiento':None,'estado':'OPERATIVO'})[0]==409)
chk('borrar proveedor con flota rechazado',req(A,'DELETE',f'/proveedores/{pid}')[0] in (400,409))
# 4. Lugar CRUD
s,l=req(O,'POST','/lugares',{'nombre':'Hotel Prueba','tipoLugar':'HOTEL','ciudad':'Cusco','latitud':-13.52,'longitud':-71.97}); chk('crear lugar',s==201,l)
chk('coordenada sola 400',req(O,'POST','/lugares',{'nombre':'X','tipoLugar':'HOTEL','ciudad':'Cusco','latitud':-13.5,'longitud':None})[0]==400)
s,_=req(O,'PUT',f"/lugares/{l['lugarId']}",{'nombre':'Hotel Prueba Centro','tipoLugar':'HOTEL','ciudad':'Cusco','latitud':-13.52,'longitud':-71.97}); chk('editar lugar',s==200)
# 5. Paquete y salida
s,pq=req(V,'POST','/paquetes',{'nombre':'Paquete de Prueba','descripcion':'Prueba','precioBase':500,'dias':2,'noches':1,'imagen':None,'estado':'ACTIVO'}); chk('crear paquete',s==201,pq)
chk('noches > días 400',req(V,'POST','/paquetes',{'nombre':'Malo','descripcion':'','precioBase':500,'dias':1,'noches':3,'imagen':None,'estado':'ACTIVO'})[0]==400)
s,sal=req(V,'POST','/salidas',{'paqueteId':pq['paqueteId'],'fechaInicio':str(hoy+dt.timedelta(days=20)),'cuposMaximos':10,'guiaId':1,'estado':'PROGRAMADA'}); chk('crear salida',s==201,sal)
chk('fecha_fin calculada',sal.get('fechaFin')==str(hoy+dt.timedelta(days=21)),sal.get('fechaFin'))
chk('operador no crea salidas 403',req(O,'POST','/salidas',{'paqueteId':pq['paqueteId'],'fechaInicio':str(hoy+dt.timedelta(days=20)),'cuposMaximos':10,'guiaId':None,'estado':'PROGRAMADA'})[0]==403)
# 6. Cliente CRUD
s,cl=req(V,'POST','/clientes',{'nombreCompleto':'Cliente Prueba Ruiz','tipoDocumento':'DNI','numeroDocumento':'40001122','email':'cliente.prueba@mail.com','telefono':'+51 955001122'}); chk('crear cliente',s==201,cl)
chk('correo duplicado 409',req(V,'POST','/clientes',{'nombreCompleto':'Otro','tipoDocumento':'DNI','numeroDocumento':'40001123','email':'cliente.prueba@mail.com','telefono':'+51 955001123'})[0]==409)
chk('documento duplicado otro tipo 409',req(V,'POST','/clientes',{'nombreCompleto':'Otro','tipoDocumento':'CE','numeroDocumento':'40001122','email':'otro.x@mail.com','telefono':'+51 955001124'})[0] in (400,409))
s,_=req(V,'PUT',f"/clientes/{cl['clienteId']}",{'nombreCompleto':'Cliente Prueba Ruiz Editado','tipoDocumento':'DNI','numeroDocumento':'40001122','email':'cliente.prueba@mail.com','telefono':'+51 955001122'}); chk('editar cliente',s==200)
# 7. Reserva → pago → confirmación → cupos
s,r=req(V,'POST','/reservas',{'clienteId':cl['clienteId'],'contacto':None,'salidaId':sal['salidaId'],'observaciones':'',
  'pasajeros':[{'nombreCompleto':'Cliente Prueba Ruiz','tipoDocumento':'DNI','numeroDocumento':'40001122','nacionalidad':'Peruana','fechaNacimiento':'1990-01-01'},
               {'nombreCompleto':'Acompañante Prueba','tipoDocumento':'DNI','numeroDocumento':'40001199','nacionalidad':'Peruana','fechaNacimiento':'1992-01-01'}]}); chk('crear reserva',s==201,r)
rid=r['reservaId']; chk('monto = 2 x 500',float(r['montoTotal'])==1000,r.get('montoTotal'))
s,sal2=req(V,'GET',f"/salidas/{sal['salidaId']}"); chk('cupos descontados',sal2['cuposDisponibles']==8,sal2.get('cuposDisponibles'))
chk('pasajero repetido 400',req(V,'POST','/reservas',{'clienteId':cl['clienteId'],'contacto':None,'salidaId':sal['salidaId'],'observaciones':'','pasajeros':[{'nombreCompleto':'A B','tipoDocumento':'DNI','numeroDocumento':'40001155','nacionalidad':'','fechaNacimiento':None},{'nombreCompleto':'A C','tipoDocumento':'DNI','numeroDocumento':'40001155','nacionalidad':'','fechaNacimiento':None}]})[0] in (400,409))
s,pg=req(V,'POST','/pagos',{'reservaId':rid,'monto':400,'moneda':'PEN','metodoPago':'Yape','codigoTransaccion':'YP-TEST1','estadoTransaccion':'APROBADO'}); chk('registrar pago',s==201,pg)
chk('pago mayor al saldo 400',req(V,'POST','/pagos',{'reservaId':rid,'monto':5000,'moneda':'PEN','metodoPago':'Yape','codigoTransaccion':'YP-TEST2','estadoTransaccion':'APROBADO'})[0]==400)
s,rr=req(V,'GET',f'/reservas/{rid}'); chk('monto pagado y estado parcial',float(rr['montoPagado'])==400 and rr['estadoPago']=='PARCIAL',rr)
s,_=req(V,'PATCH',f'/reservas/{rid}/confirmar'); chk('confirmar reserva',s==200,_)
s,b=req(V,'GET',f'/reservas/{rid}/boleta'); chk('boleta html',s==200 and 'html' in str(b).lower()[:400])
# 8. Operación de transporte de la salida
ini=dt.datetime.combine(hoy+dt.timedelta(days=20),dt.time(8,0))
s,op=req(O,'POST','/operaciones',{'salidaId':sal['salidaId'],'origenId':1,'destinoId':l['lugarId'],'vehiculoId':None,'conductorId':None,'paxProgramados':2,'horaProgramadaSalida':ini.isoformat(timespec='minutes'),'horaEstimadaLlegada':None,'observaciones':''}); chk('crear operación (llegada calculada)',s==201,op)
oid=op['operacionId']
chk('solo vehículo sin conductor 400',req(O,'PUT',f'/operaciones/{oid}',{'salidaId':sal['salidaId'],'origenId':1,'destinoId':l['lugarId'],'vehiculoId':v['vehiculoId'],'conductorId':None,'paxProgramados':2,'horaProgramadaSalida':ini.isoformat(timespec='minutes'),'horaEstimadaLlegada':None,'observaciones':''})[0]==400)
s,cand=req(O,'GET',f'/operaciones/{oid}/candidatos'); chk('candidatos',s==200 and len(cand)>0)
chk('EMBARQUE sin recursos rechazado',req(O,'PATCH',f'/operaciones/{oid}/estado',{'estado':'EN_RUTA','observacion':''})[0]==400)
s,op2=req(O,'POST',f'/operaciones/{oid}/asignar-automatico'); chk('asignación automática',s==200 and op2.get('placa'),op2)
for e in ['EMBARQUE','EN_RUTA','FINALIZADO']:
    s,x=req(O,'PATCH',f'/operaciones/{oid}/estado',{'estado':e,'observacion':'prueba'}); chk('estado '+e,s==200,x)
chk('transición desde FINALIZADO rechazada',req(O,'PATCH',f'/operaciones/{oid}/estado',{'estado':'CANCELADO','observacion':''})[0]==400)
s,h=req(O,'GET',f'/operaciones/{oid}/historial'); chk('historial 5 estados',s==200 and len(h)==5,len(h) if isinstance(h,list) else h)
s,e=req(O,'GET','/operaciones/estimar-duracion?origenId=1&destinoId=2'); chk('estimar duración',s==200 and e.get('minutos'),e)
# 9. Portal del cliente
s,lst=req(C,'GET','/portal/paquetes'); chk('portal lista',s==200 and len(lst)>=2,lst)
s,det=req(C,'GET','/portal/paquetes/9'); chk('portal detalle propio',s==200,det)
chk('portal reserva ajena bloqueada',req(C,'GET',f'/portal/paquetes/{rid}')[0] in (403,404,400))
s,ip=req(C,'POST','/portal/paquetes/9/pagos',{'monto':100,'metodoPago':'Yape','codigoTransaccion':'YP-CLI-1'}); chk('cliente informa pago',s in (200,201),ip)
s,pagos=req(V,'GET','/pagos'); pend=[x for x in pagos if x.get('codigoTransaccion')=='YP-CLI-1']
chk('pago informado visible PENDIENTE',pend and pend[0]['estadoTransaccion']=='PENDIENTE',pend)
if pend:
    s,x=req(V,'PATCH',f"/pagos/{pend[0]['pagoId']}/resolver",{'estado':'APROBADO'}); chk('ventas aprueba pago',s==200,x)
# 10. Anulación devuelve cupos
s,x=req(V,'PATCH',f'/reservas/{rid}/anular',{'formaReembolso':'Yape','usuarioId':2}); chk('anular reserva',s==200,x)
s,sal3=req(V,'GET',f"/salidas/{sal['salidaId']}"); chk('cupos devueltos',sal3['cuposDisponibles']==10,sal3.get('cuposDisponibles'))
# 11. Borrados con dependencias y limpieza
chk('borrar cliente con reservas rechazado',req(V,'DELETE',f"/clientes/{cl['clienteId']}")[0] in (400,409))
s,c2=req(V,'POST','/clientes',{'nombreCompleto':'Para Borrar','tipoDocumento':'DNI','numeroDocumento':'40009988','email':'borrar@mail.com','telefono':'+51 955009988'})
chk('borrar cliente libre',req(V,'DELETE',f"/clientes/{c2['clienteId']}")[0]==204)
s,l2=req(O,'POST','/lugares',{'nombre':'Lugar Temporal','tipoLugar':'OTRO','ciudad':'Lima','latitud':None,'longitud':None})
chk('borrar lugar libre',req(O,'DELETE',f"/lugares/{l2['lugarId']}")[0]==204)
chk('borrar lugar en uso rechazado',req(O,'DELETE',f"/lugares/{l['lugarId']}")[0] in (400,409))
s,v2=req(O,'POST','/vehiculos',{'proveedorId':pid,'placa':'PRB-002','tipoVehiculo':'AUTO','marcaModelo':'','capacidadPax':4,'proxMantenimiento':None,'estado':'OPERATIVO'})
chk('borrar vehículo libre',req(O,'DELETE',f"/vehiculos/{v2['vehiculoId']}")[0]==204)
s,au=req(A,'GET','/auditoria?tamanio=5'); chk('auditoría registra cambios',s==200 and au.get('total',0)>0,au if s!=200 else '')
print(f'\nRESULTADO: {ok} pruebas correctas, {fail} fallidas')
sys.exit(1 if fail else 0)
