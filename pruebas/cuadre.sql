-- Consultas de cuadre: todas deben devolver "no rows selected".
-- Ejecutar como dueño del esquema después de las pruebas, p. ej.: sqlplus USUARIO/CLAVE@//localhost:1521/XEPDB1 @cuadre.sql
set pages 100 lines 200
prompt anuladas con pagos aprobados o monto>0
select r.reserva_id, r.monto_pagado from reservas r where r.estado_reserva='ANULADA' and (r.monto_pagado<>0 or exists(select 1 from pagos p where p.reserva_id=r.reserva_id and p.estado_transaccion='APROBADO'));
prompt confirmadas sin pago
select reserva_id from reservas where estado_reserva='CONFIRMADA' and monto_pagado=0;
prompt cupos vs vendidos
select s.salida_id, s.cupos_disponibles, s.cupos_maximos - nvl((select sum(d.cantidad) from detalle_reserva d join reservas r on r.reserva_id=d.reserva_id where d.salida_id=s.salida_id and r.estado_reserva<>'ANULADA'),0) esperado from salidas_programadas s where s.cupos_disponibles <> s.cupos_maximos - nvl((select sum(d.cantidad) from detalle_reserva d join reservas r on r.reserva_id=d.reserva_id where d.salida_id=s.salida_id and r.estado_reserva<>'ANULADA'),0);
prompt monto_pagado vs pagos
select r.reserva_id from reservas r where r.monto_pagado <> nvl((select sum(p.monto_pen) from pagos p where p.reserva_id=r.reserva_id and p.estado_transaccion='APROBADO'),0);
