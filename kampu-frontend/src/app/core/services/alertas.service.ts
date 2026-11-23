import { computed, inject, Injectable } from '@angular/core';
import { AuthService } from './auth.service';
import { Alerta } from '../models';
import { cuando, diasHasta } from '../utils/date.util';
import { TourStore } from './tour-store.service';

const DIAS_SALIDA = 7;
const DIAS_SIN_CONFIRMAR = 3;
const DIAS_LICENCIA = 30;
const DIAS_MANTENIMIENTO = 15;

@Injectable({ providedIn: 'root' })
export class AlertasService {
  private store = inject(TourStore);
  private auth = inject(AuthService);

  lista = computed<Alerta[]>(() => {
    const alertas: Alerta[] = [];
    if (!this.auth.puede('VER_RESUMEN')) return alertas;
    const activa = (estado: string) => estado === 'PROGRAMADA' || estado === 'GARANTIZADA';

    for (const sol of this.store.solicitudes()) {
      if (sol.estado !== 'PENDIENTE') continue;
      alertas.push({
        nivel: 'alta', icono: 'x', titulo: `${sol.cliente ?? 'Un cliente'} pidió anular ${sol.codigoReserva}`,
        detalle: `${sol.paquete ?? ''} · motivo: ${sol.motivo}`, ruta: ['/reservas', sol.reservaId]
      });
    }

    for (const s of this.store.salidas()) {
      if (!activa(s.estado)) continue;
      const nombre = this.store.getPaquete(s.paqueteId)?.nombre ?? 'Salida';
      const inicio = diasHasta(s.fechaInicio);
      const fin = diasHasta(s.fechaFin);
      const vendidos = s.cuposMaximos - s.cuposDisponibles;
      if (fin < 0) {
        alertas.push({
          nivel: 'media', icono: 'flag', titulo: `${nombre}: el viaje terminó ${cuando(fin)}`,
          detalle: vendidos > 0 ? 'Sigue abierta. Márcala como terminada para cerrar sus reservas.' : 'Sigue abierta y no tuvo pasajeros. Cancélala.',
          ruta: ['/salidas', s.salidaId]
        });
        continue;
      }
      if (inicio > DIAS_SALIDA) continue;
      const faltas: string[] = [];
      if (!s.guiaId) faltas.push('no tiene guía');
      if (s.faltanteTransporte) faltas.push('falta transporte');
      else if (vendidos > 0 && s.operaciones === 0) faltas.push('no tiene traslados programados');
      if (s.estado === 'PROGRAMADA' && vendidos > 0 && inicio <= DIAS_SIN_CONFIRMAR) faltas.push('aún no está confirmada');
      if (vendidos === 0 && inicio <= DIAS_SIN_CONFIRMAR && inicio >= 0) faltas.push('no tiene pasajeros');
      if (faltas.length > 0) {
        alertas.push({
          nivel: inicio <= DIAS_SIN_CONFIRMAR ? 'alta' : 'media', icono: 'calendar',
          titulo: `${nombre} ${inicio < 0 ? 'empezó ' + cuando(inicio) : 'sale ' + cuando(inicio)}`,
          detalle: this.frase(faltas), ruta: ['/salidas', s.salidaId]
        });
      }
    }

    for (const r of this.store.reservas()) {
      if (r.estadoReserva !== 'PENDIENTE') continue;
      const s = this.store.getSalida(r.salidaId);
      if (!s || !activa(s.estado)) continue;
      const inicio = diasHasta(s.fechaInicio);
      if (inicio > DIAS_SALIDA) continue;
      alertas.push({
        nivel: inicio <= DIAS_SIN_CONFIRMAR ? 'alta' : 'media', icono: 'ticket',
        titulo: `Reserva ${this.store.codigoReserva(r.reservaId)} sin confirmar`,
        detalle: `${this.store.nombreCliente(r)} · el viaje ${inicio < 0 ? 'empezó' : 'sale'} ${cuando(inicio)}. ${r.montoPagado > 0 ? 'Ya tiene un pago: confírmala.' : 'Cobra el adelanto o anúlala.'}`,
        ruta: ['/reservas', r.reservaId]
      });
    }

    const porValidar = this.store.pagos().filter(p => p.estadoTransaccion === 'PENDIENTE').length;
    if (porValidar > 0) {
      alertas.push({
        nivel: 'media', icono: 'card', titulo: porValidar === 1 ? '1 pago por validar' : `${porValidar} pagos por validar`,
        detalle: 'Revisa el comprobante y apruébalo o recházalo.', ruta: ['/pagos'], consulta: { estado: 'PENDIENTE' }
      });
    }

    for (const o of this.store.operaciones()) {
      if (o.salidaId !== null || o.estadoActual !== 'PROGRAMADO') continue;
      const dias = diasHasta(o.horaProgramadaSalida);
      if (dias < 0 || dias > DIAS_SIN_CONFIRMAR) continue;
      alertas.push({
        nivel: 'alta', icono: 'truck', titulo: `Traslado ${o.codigoOperacion} sin vehículo`,
        detalle: `${o.origen} → ${o.destino} · sale ${cuando(dias)}.`, ruta: ['/operaciones']
      });
    }

    for (const p of this.store.personal()) {
      if (p.estado === 'INACTIVO' || p.funcion !== 'TRANSPORTE' || !p.vencLicencia) continue;
      const dias = diasHasta(p.vencLicencia);
      if (dias > DIAS_LICENCIA) continue;
      alertas.push({
        nivel: dias < 0 ? 'alta' : 'media', icono: 'id',
        titulo: `Licencia de ${p.nombreCompleto} ${dias < 0 ? 'vencida' : 'por vencer'}`,
        detalle: `${dias < 0 ? 'Venció' : 'Vence'} ${cuando(dias)}. ${dias < 0 ? 'No debe conducir hasta renovarla.' : 'Pídele que la renueve.'}`,
        ruta: [p.proveedorId === null ? '/personal' : '/proveedores'], consulta: p.proveedorId === null ? {} : { tab: 'personal' }
      });
    }
    for (const v of this.store.vehiculos()) {
      if (v.estado !== 'OPERATIVO' || !v.proxMantenimiento) continue;
      const dias = diasHasta(v.proxMantenimiento);
      if (dias > DIAS_MANTENIMIENTO) continue;
      alertas.push({
        nivel: dias < 0 ? 'alta' : 'media', icono: 'truck',
        titulo: `Mantenimiento de ${v.placa} ${dias < 0 ? 'atrasado' : 'próximo'}`,
        detalle: `${v.marcaModelo || 'Vehículo'} · ${dias < 0 ? 'debía entrar' : 'entra'} ${cuando(dias)}.`,
        ruta: [v.proveedorId === null ? '/vehiculos' : '/proveedores'], consulta: v.proveedorId === null ? {} : { tab: 'vehiculos' }
      });
    }

    return alertas.sort((a, b) => (a.nivel === b.nivel ? 0 : a.nivel === 'alta' ? -1 : 1));
  });

  private frase(partes: string[]): string {
    const texto = partes.length === 1 ? partes[0] : partes.slice(0, -1).join(', ') + ' y ' + partes[partes.length - 1];
    return texto.charAt(0).toUpperCase() + texto.slice(1) + '.';
  }
}
