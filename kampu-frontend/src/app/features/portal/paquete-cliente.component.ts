import { DatePipe, DecimalPipe } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { PasajeroDraft, PortalDetalle, PuntoRecojo, TipoDocumento } from '../../core/models';
import { TourStore } from '../../core/services/tour-store.service';
import { AlertService } from '../../core/services/alert.service';
import { etiqueta, METODOS_PAGO } from '../../core/utils/etiquetas';
import { hoy } from '../../core/utils/date.util';
import { ImagenService } from '../../core/services/imagen.service';
import { PortalService } from '../../core/services/portal.service';
import { mensajeError } from '../../core/utils/api';
import { cuentaRegresiva, lineaViaje, porcentajePagado } from '../../core/utils/viaje';
import { FormValidacion, V } from '../../core/utils/validacion';
import { BadgeComponent } from '../../shared/badge.component';
import { IconComponent } from '../../shared/icon.component';
import { MigasComponent } from '../../shared/migas.component';
import { PortalHeaderComponent } from './portal-header.component';

// Detalle de un paquete del cliente: GET /portal/paquetes/{id}
// (PKG_GESTION_PAQUETES_CLIENTE.detalle_paquete; exigir_propietario impide ver reservas ajenas).
// v10: hasta antes del viaje el cliente registra o quita pasajeros, cambia su punto de recojo y pide la
// anulación (sin pagos aprobados se anula al instante; con pagos queda una solicitud para Ventas).
// Sus pagos informados quedan PENDIENTES hasta que Ventas los valide.
@Component({
  selector: 'app-paquete-cliente',
  standalone: true,
  imports: [FormsModule, RouterLink, DatePipe, DecimalPipe, BadgeComponent, IconComponent, PortalHeaderComponent, MigasComponent],
  templateUrl: './paquete-cliente.component.html'
})
export class PaqueteClienteComponent {
  private portal = inject(PortalService);
  private imagenes = inject(ImagenService);
  private id = Number(inject(ActivatedRoute).snapshot.paramMap.get('id'));
  private store = inject(TourStore);
  private alerts = inject(AlertService);
  etiqueta = etiqueta;

  detalle = signal<PortalDetalle | null>(null);
  cargando = signal(true);
  error = signal('');

  // chk_pag_metodo (v10)
  metodos = METODOS_PAGO.filter(m => m !== 'EFECTIVO');
  pago = { monto: null as number | null, metodoPago: 'TRANSFERENCIA', codigoTransaccion: '' };
  informando = signal(false);
  enviando = signal(false);
  errorPago = signal('');
  okPago = signal('');

  paquete = computed(() => this.detalle()?.paquete ?? null);
  linea = computed(() => this.paquete() ? lineaViaje(this.paquete()!) : []);
  faltan = computed(() => this.paquete() ? cuentaRegresiva(this.paquete()!) : null);
  // Lo que todavía se puede informar: saldo menos lo que ya está por validar
  maximo = computed(() => {
    const p = this.paquete();
    return p ? Math.max(0, Math.round((p.saldo - p.montoPorValidar) * 100) / 100) : 0;
  });
  puedeInformar = computed(() => {
    const p = this.paquete();
    return !!p && p.estadoPago !== 'ANULADO' && p.estadoEjecucion !== 'CANCELADO' && p.estadoEjecucion !== 'TERMINADO' && this.maximo() > 0;
  });
  porcentaje = computed(() => this.paquete() ? porcentajePagado(this.paquete()!) : 0);

  // Editable desde el portal: reserva abierta cuyo viaje aún no empieza
  editable = computed(() => {
    const p = this.paquete();
    return !!p && (p.estadoReserva === 'PENDIENTE' || p.estadoReserva === 'CONFIRMADA') && p.fechaInicio > hoy();
  });
  faltanPasajeros = computed(() => Math.max((this.paquete()?.pasajeros ?? 0) - (this.detalle()?.pasajeros.length ?? 0), 0));
  solicitudPendiente = computed(() => this.detalle()?.solicitud?.estado === 'PENDIENTE');

  // Pasajeros
  tipos: TipoDocumento[] = ['DNI', 'CE', 'PASAPORTE'];
  nuevo: PasajeroDraft = this.pasajeroVacio();
  agregando = signal(false);
  private pasajeroVacio(): PasajeroDraft {
    return { nombreCompleto: '', tipoDocumento: 'DNI', numeroDocumento: '', nacionalidad: '', fechaNacimiento: '' };
  }
  vp = new FormValidacion(() => ({
    nombre: V.nombrePersona(this.nuevo.nombreCompleto, 'El nombre'),
    documento: V.documento(this.nuevo.tipoDocumento, this.nuevo.numeroDocumento),
    nacionalidad: V.nacionalidad(this.nuevo.nacionalidad)
  }));

  // Punto de recojo
  puntos = signal<PuntoRecojo[]>([]);
  recojoSel: number | null = null;

  v = new FormValidacion(() => ({
    monto: V.importe(this.pago.monto, 'El monto')
      ?? ((this.pago.monto ?? 0) > this.maximo() ? `El monto no puede superar S/ ${this.maximo().toFixed(2)}.` : null),
    codigo: this.pago.codigoTransaccion.trim() ? V.codigo(this.pago.codigoTransaccion) : 'Ingresa el número de operación.'
  }));

  constructor() {
    this.cargar();
  }

  cargar() {
    this.cargando.set(true);
    this.portal.detalle(this.id).subscribe({
      next: d => {
        this.detalle.set(d);
        this.cargando.set(false);
        if (!this.puntos().length) {
          this.store.puntosRecojo(d.paquete.paqueteId).subscribe({
            next: p => {
              this.puntos.set(p);
              this.recojoSel = p.find(x => x.nombre === d.paquete.puntoRecojo)?.lugarId ?? null;
            }
          });
        }
      },
      error: err => { this.error.set(mensajeError(err)); this.cargando.set(false); }
    });
  }

  imagen() { return this.imagenes.url(this.paquete()?.imagen); }

  abrirPago() {
    this.pago = { monto: this.maximo(), metodoPago: 'TRANSFERENCIA', codigoTransaccion: '' };
    this.v.reiniciar();
    this.errorPago.set('');
    this.informando.set(true);
  }

  informar() {
    this.errorPago.set('');
    if (!this.v.valido()) return;
    this.enviando.set(true);
    this.portal.informarPago(this.id, this.pago.monto!, this.pago.metodoPago, this.pago.codigoTransaccion.trim()).subscribe({
      next: () => {
        this.enviando.set(false);
        this.informando.set(false);
        this.okPago.set('Recibimos tu pago. Quedará como "por validar" hasta que la agencia lo confirme.');
        this.cargar();
      },
      error: err => { this.errorPago.set(mensajeError(err)); this.enviando.set(false); }
    });
  }

  registrarPasajero() {
    if (!this.vp.valido()) return;
    const n = this.nuevo;
    this.enviando.set(true);
    this.portal.registrarPasajero(this.id, { ...n, nombreCompleto: n.nombreCompleto.trim(), numeroDocumento: n.numeroDocumento.trim(),
      nacionalidad: n.nacionalidad.trim() }).subscribe({
      next: () => {
        this.enviando.set(false);
        this.agregando.set(false);
        this.nuevo = this.pasajeroVacio();
        this.vp.reiniciar();
        this.alerts.toast('Pasajero registrado');
        this.cargar();
      },
      error: err => { this.enviando.set(false); this.alerts.error(mensajeError(err)); }
    });
  }

  async quitarPasajero(pasajeroId: number, nombre: string) {
    if (!(await this.alerts.confirm(`${nombre} dejará de figurar en tu reserva.`, 'Quitar pasajero', 'Quitar'))) return;
    this.portal.eliminarPasajero(pasajeroId).subscribe({
      next: () => { this.alerts.toast('Pasajero quitado'); this.cargar(); },
      error: err => this.alerts.error(mensajeError(err))
    });
  }

  cambiarRecojo() {
    if (!this.recojoSel) return;
    this.portal.cambiarRecojo(this.id, this.recojoSel).subscribe({
      next: () => { this.alerts.toast('Punto de recojo actualizado'); this.cargar(); },
      error: err => this.alerts.error(mensajeError(err))
    });
  }

  async solicitarAnulacion() {
    const p = this.paquete();
    if (!p) return;
    const conPagos = p.montoPagado > 0;
    const motivo = await this.alerts.texto(conPagos ? 'Solicitar anulación' : 'Anular reserva',
      conPagos ? 'Tu reserva tiene pagos: la agencia revisará tu pedido y te indicará el reembolso.'
        : 'Se anulará tu reserva y se liberarán los cupos.', 'Cuéntanos el motivo', conPagos ? 'Enviar solicitud' : 'Anular', true);
    if (!motivo) return;
    this.portal.solicitarAnulacion(this.id, motivo).subscribe({
      next: r => {
        this.alerts.toast(r.resultado === 'ANULADA' ? 'Reserva anulada' : 'Solicitud enviada a la agencia');
        this.cargar();
      },
      error: err => this.alerts.error(mensajeError(err))
    });
  }
}
