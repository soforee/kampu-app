"""Pruebas de concurrencia: peticiones simultáneas que no deben dejar datos incoherentes."""
import datetime as dt, sys
from comun import req, login, a_la_vez, pax
V = login('ventas', 'ventas123'); O = login('operador', 'operador123')
fallas = 0
# 1) Sobreventa: salida 3 tiene 12 cupos libres; 10 reservas simultáneas de 2 pasajeros
s,sal=req(V,'GET','/salidas/3'); libres=sal['cuposDisponibles']
res=a_la_vez([lambda: req(V,'POST','/reservas',{'clienteId':5,'contacto':None,'salidaId':3,'observaciones':'','pasajeros':pax(2)}) for _ in range(10)])
ok=sum(1 for c,_ in res if c==201); s,sal2=req(V,'GET','/salidas/3')
bien=ok==libres//2 and sal2['cuposDisponibles']==libres-2*ok and sal2['cuposDisponibles']>=0
fallas+=not bien
print(f'1) Sobreventa: libres antes {libres}, 10 x 2 pax simultáneas -> {ok} creadas, libres después {sal2["cuposDisponibles"]}',
      'OK' if bien else 'FALLA')
# 2) Sobrepago: reserva 9; 6 pagos aprobados de 1000 a la vez sobre su saldo
sello=dt.datetime.now().strftime('%H%M%S')
_,r0=req(V,'GET','/reservas/9'); antes=float(r0['montoPagado']); total=float(r0['montoTotal'])
res=a_la_vez([lambda i=i: req(V,'POST','/pagos',{'reservaId':9,'monto':1000,'moneda':'PEN','metodoPago':'Yape','codigoTransaccion':f'CC-{sello}-{i}','estadoTransaccion':'APROBADO'}) for i in range(6)])
ok=sum(1 for c,_ in res if c==201); s,r9=req(V,'GET','/reservas/9')
bien=ok==int((total-antes)//1000) and float(r9['montoPagado'])==antes+1000*ok<=total
fallas+=not bien
print(f'2) Sobrepago: 6 pagos de 1000 sobre saldo {total-antes:.0f} -> {ok} aceptados, pagado {r9["montoPagado"]} de {total:.0f}, estado {r9["estadoPago"]}',
      'OK' if bien else 'FALLA')
# 3) Confirmar vs anular a la vez (8 reservas con adelanto). Que ambas respondan 200 es válido si se
#    serializan (se confirma y luego se anula); lo que no puede quedar es un estado incoherente.
ids=[]
for _ in range(8):
    c,r=req(V,'POST','/reservas',{'clienteId':6,'contacto':None,'salidaId':2,'observaciones':'','pasajeros':pax(1)})
    if c==201:
        req(V,'POST','/pagos',{'reservaId':r['reservaId'],'monto':100,'moneda':'PEN','metodoPago':'Yape','codigoTransaccion':f"AD-{sello}-{r['reservaId']}",'estadoTransaccion':'APROBADO'}); ids.append(r['reservaId'])
incoherentes=[]; resultados=[]
for rid in ids:
    a,b=a_la_vez([lambda: req(V,'PATCH',f'/reservas/{rid}/confirmar'), lambda: req(V,'PATCH',f'/reservas/{rid}/anular',{'formaReembolso':'Yape','usuarioId':None})])
    c,r=req(V,'GET',f'/reservas/{rid}'); c,pagos=req(V,'GET',f'/pagos?reservaId={rid}')
    aprobados=[p for p in pagos if p['estadoTransaccion']=='APROBADO']
    resultados.append((a[0],b[0],r['estadoReserva']))
    if (r['estadoReserva']=='ANULADA' and (float(r['montoPagado'])!=0 or aprobados)) or        (r['estadoReserva']=='CONFIRMADA' and float(r['montoPagado'])<=0) or b[0]==200 and r['estadoReserva']!='ANULADA':
        incoherentes.append(rid)
fallas+=bool(incoherentes) or len(ids)!=8
print(f'3) Confirmar vs anular: {len(ids)} carreras (confirmar, anular, final) {resultados}', 'INCOHERENTES '+str(incoherentes) if incoherentes else 'OK')
dia=(dt.date.today()+dt.timedelta(days=12)).isoformat()
def op(h): return req(O,'POST','/operaciones',{'salidaId':None,'origenId':1,'destinoId':2,'vehiculoId':None,'conductorId':None,'paxProgramados':2,'horaProgramadaSalida':f'{dia}T{h}','horaEstimadaLlegada':f'{dia}T{h[:2]}:50','observaciones':''})[1]['operacionId']
# 4) Asignación manual simultánea del mismo vehículo y conductor a dos traslados que se cruzan
for h in ['08:00','11:00','14:00']:
    a,b=op(h),op(h)
    r=a_la_vez([lambda x=a: req(O,'PATCH',f'/operaciones/{x}/asignar',{'vehiculoId':2,'conductorId':3}), lambda x=b: req(O,'PATCH',f'/operaciones/{x}/asignar',{'vehiculoId':2,'conductorId':3})])
    ok=[c for c,_ in r].count(200)
    if ok==2: fallas+=1
    print(f'4) manual {h}: respuestas {[c for c,_ in r]}', 'DOBLE ASIGNACIÓN' if ok==2 else 'OK')
# 5) Asignación automática simultánea de 6 traslados en el mismo horario
ids=[op('17:00') for _ in range(6)]
r=a_la_vez([lambda x=x: req(O,'POST',f'/operaciones/{x}/asignar-automatico') for x in ids])
placas=[b.get('placa') for c,b in r if c==200]; conductores=[b.get('conductor') for c,b in r if c==200]
dup=len(placas)!=len(set(placas)) or len(conductores)!=len(set(conductores))
print(f'5) automática x6 simultáneas: asignadas {len(placas)} -> placas {placas} conductores {conductores}', 'CONFLICTO' if dup else 'OK')
fallas+=dup or len(placas)==0
# 6) Aprobar y rechazar a la vez el mismo pago pendiente: solo una de las dos debe aplicarse
c,res=req(V,'POST','/reservas',{'clienteId':5,'contacto':None,'salidaId':3,'observaciones':'','pasajeros':pax(1)})
if c!=201: c,res=req(V,'POST','/reservas',{'clienteId':5,'contacto':None,'salidaId':5,'observaciones':'','pasajeros':pax(1)})
carreras=[]
for i in range(6):
    c,p=req(V,'POST','/pagos',{'reservaId':res['reservaId'],'monto':10,'moneda':'PEN','metodoPago':'Yape','codigoTransaccion':f'RS-{sello}-{i}','estadoTransaccion':'PENDIENTE'})
    a,b=a_la_vez([lambda x=p['pagoId']: req(V,'PATCH',f'/pagos/{x}/resolver',{'estado':'APROBADO'})[0], lambda x=p['pagoId']: req(V,'PATCH',f'/pagos/{x}/resolver',{'estado':'RECHAZADO'})[0]])
    carreras.append((a,b))
c,r=req(V,'GET',f"/reservas/{res['reservaId']}"); c,pagos=req(V,'GET',f"/pagos?reservaId={res['reservaId']}")
aprobados=sum(1 for x in pagos if x['estadoTransaccion']=='APROBADO')
bien=all(sorted(x)==[200,400] for x in carreras) and float(r['montoPagado'])==10*aprobados
fallas+=not bien
print(f'6) Aprobar vs rechazar x6: respuestas {carreras}; pagado {r["montoPagado"]} = {aprobados} aprobados x 10', 'OK' if bien else 'FALLA')
sys.exit(1 if fallas else 0)
