import { DatePipe, DecimalPipe } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { Cotizacion, SolicitudReserva, TipoDocumento } from '../../core/models';
import { AlertService } from '../../core/services/alert.service';
import { AuthService } from '../../core/services/auth.service';
import { CotizacionService, guardarArchivo } from '../../core/services/cotizacion.service';
import { CotizacionesLocales } from '../../core/services/cotizaciones-locales.service';
import { mensajeError } from '../../core/utils/api';
import { errorTelefonoPais } from '../../core/utils/paises';
import { FormValidacion, V } from '../../core/utils/validacion';
import { BadgeComponent } from '../../shared/badge.component';
import { IconComponent } from '../../shared/icon.component';
import { TelefonoInputComponent } from '../../shared/telefono-input.component';
import { PortalHeaderComponent } from '../portal/portal-header.component';

interface Paso { titulo: string; detalle: string; estado: 'hecho' | 'actual' | 'pendiente' | 'cortado'; }

/**
 * (v11) Una cotización guardada: estado y seguimiento, desglose, historial y acciones.
 * Acceso: clave recordada en este navegador, la recién creada (estado de la navegación), la que escribe
 * el visitante o, para un cliente con sesión, su cuenta. Sin clave no se muestra nada.
 */
@Component({
  selector: 'app-cotizacion-detalle',
  standalone: true,
  imports: [FormsModule, RouterLink, DatePipe, DecimalPipe, IconComponent, BadgeComponent, TelefonoInputComponent, PortalHeaderComponent],
  templateUrl: './cotizacion-detalle.component.html',
  styles: [`@media print { app-portal-header, .no-print { display: none !important; } .card { box-shadow: none !important; } }`]
})
export class CotizacionDetalleComponent {
  private api = inject(CotizacionService);
  private locales = inject(CotizacionesLocales);
  private alerts = inject(AlertService);
  private router = inject(Router);
  auth = inject(AuthService);

  codigo = (inject(ActivatedRoute).snapshot.paramMap.get('codigo') ?? '').toUpperCase();
  private estadoNav = (this.router.getCurrentNavigation()?.extras.state ?? history.state ?? {}) as { clave?: string; nueva?: boolean; aviso?: string };
  nueva = !!this.estadoNav.nueva;
  aviso = this.estadoNav.aviso ?? '';
  clave = signal(this.estadoNav.clave ?? this.locales.clave(this.codigo));
  claveEscrita = '';
  recordada = computed(() => this.locales.lista().some(x => x.codigo === this.codigo));

  cot = signal<Cotizacion | null>(null);
  cargando = signal(false);
  error = signal('');
  pedirClave = signal(false);
  ocupado = signal(false);

  // Solicitud de reserva (sin cuenta)
  solicitando = signal(false);
  tipos: TipoDocumento[] = ['DNI', 'CE', 'PASAPORTE'];
  sol: SolicitudReserva = { nombreCompleto: '', tipoDocumento: 'DNI', numeroDocumento: '', email: '', telefono: '', observaciones: '' };
  v = new FormValidacion(() => ({
    nombre: V.nombrePersona(this.sol.nombreCompleto, 'El nombre'),
    documento: V.documento(this.sol.tipoDocumento, this.sol.numeroDocumento),
    email: this.sol.email.trim() ? V.email(this.sol.email) : 'El correo es obligatorio para coordinar la reserva.',
    telefono: errorTelefonoPais(this.sol.telefono)
  }));

  constructor() {
    if (this.clave() || this.auth.esCliente()) this.cargar();
    else this.pedirClave.set(true);
  }

  cargar() {
    this.cargando.set(true);
    this.error.set('');
    this.api.abrir(this.codigo, this.clave()).subscribe({
      next: c => {
        this.cot.set(c);
        this.cargando.set(false);
        this.pedirClave.set(false);
        this.locales.actualizar(c.codigo, { fecha: c.fechaViaje, total: c.total });
      },
      error: e => {
        this.cargando.set(false);
        this.error.set(mensajeError(e));
        this.pedirClave.set(true);
      }
    });
  }

  entrar() {
    if (!this.claveEscrita.trim()) return;
    this.clave.set(this.claveEscrita.trim().toUpperCase());
    this.cargar();
  }

  recordar() {
    const c = this.cot();
    if (!c || !this.clave()) return;
    this.locales.recordar({ codigo: c.codigo, clave: this.clave(), paquete: c.paquete, fecha: c.fechaViaje, total: c.total,
      guardada: new Date().toISOString() });
    this.alerts.toast('Guardada en este navegador');
  }

  olvidar() {
    this.locales.olvidar(this.codigo);
    this.alerts.toast('Este navegador ya no recuerda la clave');
  }

  copiar(texto: string) {
    navigator.clipboard?.writeText(texto).then(() => this.alerts.toast('Copiado'), () => undefined);
  }

  // Seguimiento: cotización -> solicitud -> confirmada por la agencia -> reserva pagada
  pasos = computed<Paso[]>(() => {
    const c = this.cot();
    if (!c) return [];
    const e = c.estado;
    const cortado = ['RECHAZADA', 'CANCELADA', 'VENCIDA'].includes(e);
    const solicitada = !!c.fechaSolicitud;
    const reservada = e === 'RESERVADA';
    const anulada = c.estadoReserva === 'ANULADA';
    const pagada = c.estadoReserva === 'CONFIRMADA' || c.estadoReserva === 'COMPLETADA';
    return [
      { titulo: 'Cotización generada', detalle: 'Precio calculado y guardado', estado: 'hecho' },
      { titulo: 'Solicitud de reserva', detalle: solicitada ? 'Enviada a la agencia' : 'Acepta la cotización y pide tu reserva',
        estado: solicitada ? 'hecho' : cortado ? 'cortado' : 'actual' },
      { titulo: 'Confirmación de la agencia', detalle: reservada ? 'Reserva ' + c.codigoReserva + ' creada' : e === 'RECHAZADA' ? 'No se pudo atender' : 'Revisa la disponibilidad y crea tu reserva',
        estado: reservada ? 'hecho' : cortado ? 'cortado' : solicitada ? 'actual' : 'pendiente' },
      { titulo: anulada ? 'Reserva cancelada' : 'Reserva confirmada', detalle: anulada ? 'La reserva fue anulada' : pagada ? 'Pago validado' : 'Se confirma con tu primer pago (adelanto)',
        estado: anulada ? 'cortado' : pagada ? 'hecho' : reservada ? 'actual' : cortado ? 'cortado' : 'pendiente' }
    ];
  });

  textoEstado = computed(() => {
    const c = this.cot();
    if (!c) return '';
    if (c.estado === 'RESERVADA') {
      return c.estadoReserva === 'ANULADA' ? 'Reserva cancelada' : c.estadoReserva === 'PENDIENTE' ? 'Reserva pendiente de pago'
        : c.estadoReserva === 'COMPLETADA' ? 'Viaje realizado' : 'Reserva confirmada';
    }
    return ({ GENERADA: 'Cotización disponible', SOLICITADA: 'Solicitud de reserva pendiente', RECHAZADA: 'Solicitud no atendida',
      CANCELADA: 'Cotización cancelada', VENCIDA: 'Cotización vencida' } as Record<string, string>)[c.estado] ?? c.estado;
  });

  modificar() {
    const c = this.cot();
    if (!c) return;
    // El cotizador necesita la clave para guardar: si este navegador no la recuerda, se recuerda ahora
    if (this.clave() && !this.recordada()) this.recordar();
    this.router.navigate(['/cotizar', c.paqueteId], { queryParams: { editar: c.codigo } });
  }

  descargar() {
    this.ocupado.set(true);
    this.api.pdf(this.codigo, this.clave()).subscribe({
      next: b => { this.ocupado.set(false); guardarArchivo(b, `cotizacion-${this.codigo}.pdf`); },
      error: e => { this.ocupado.set(false); this.alerts.error(mensajeError(e)); }
    });
  }

  imprimir() { window.print(); }

  abrirSolicitud() {
    const u = this.auth.esCliente() ? this.auth.usuario() : null;
    if (u && !this.sol.nombreCompleto) { this.sol.nombreCompleto = u.nombre; this.sol.email = u.username; }
    this.v.reiniciar();
    this.solicitando.set(true);
  }

  solicitar() {
    if (!this.v.valido() || this.ocupado()) { this.alerts.toast('Revisa los campos marcados en rojo', 'error'); return; }
    this.ocupado.set(true);
    const s: SolicitudReserva = { ...this.sol, nombreCompleto: this.sol.nombreCompleto.trim(), numeroDocumento: this.sol.numeroDocumento.trim().toUpperCase(),
      email: this.sol.email.trim().toLowerCase(), observaciones: this.sol.observaciones.trim() };
    this.api.solicitar(this.codigo, this.clave(), s).subscribe({
      next: c => { this.ocupado.set(false); this.solicitando.set(false); this.cot.set(c);
        this.alerts.success('La agencia revisará la disponibilidad y te escribirá a ' + c.email + '. Sigue el estado aquí con tu código.', 'Solicitud enviada'); },
      error: e => { this.ocupado.set(false); this.alerts.error(mensajeError(e)); }
    });
  }

  async cancelar() {
    const c = this.cot();
    if (!c) return;
    const ok = await this.alerts.confirm(c.estado === 'SOLICITADA' ? 'Se retirará tu solicitud de reserva.' : 'La cotización dejará de estar disponible.',
      'Cancelar cotización', 'Sí, cancelar');
    if (!ok) return;
    this.api.cancelar(this.codigo, this.clave()).subscribe({
      next: r => { this.cot.set(r); this.alerts.toast('Cotización cancelada'); },
      error: e => this.alerts.error(mensajeError(e))
    });
  }

  etiquetaCampo(e: { campo: string; anterior: string | null; nuevo: string | null }): string {
    if (e.campo === 'VIAJE') return `Modificada: ${e.anterior} → ${e.nuevo}`;
    const t: Record<string, string> = { GENERADA: 'Cotización generada', SOLICITADA: 'Solicitud de reserva enviada', RESERVADA: 'Reserva creada por la agencia',
      RECHAZADA: 'Solicitud rechazada', CANCELADA: 'Cancelada', VENCIDA: 'Venció' };
    return t[e.nuevo ?? ''] ?? `${e.anterior ?? ''} → ${e.nuevo ?? ''}`;
  }
}
