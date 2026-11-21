import { DatePipe, DecimalPipe } from '@angular/common';
import { Component, EventEmitter, Input, OnInit, Output, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { CalendarioDia, Cotizacion, PaqueteTour, PuntoRecojo } from '../../../core/models';
import { AuthService } from '../../../core/services/auth.service';
import { CotizacionService } from '../../../core/services/cotizacion.service';
import { TourStore } from '../../../core/services/tour-store.service';
import { mensajeError } from '../../../core/utils/api';
import { hoy } from '../../../core/utils/date.util';
import { IconComponent } from '../../../shared/icon.component';
import { ModalComponent } from '../../../shared/modal.component';
import { Contacto } from '../landing.models';

/**
 * Cotizar un paquete desde la página principal, sin cuenta.
 * 1) El visitante elige fecha (calendario real del paquete), pasajeros y punto de recojo.
 * 2) POST /cotizaciones calcula el total con las reglas de la base de datos (no guarda nada).
 * 3) Con la cotización puede escribir a la agencia por WhatsApp o correo (mensaje ya armado)
 *    o crear su cuenta / iniciar sesión para reservar ese paquete.
 */
@Component({
  selector: 'app-landing-cotizar',
  standalone: true,
  imports: [FormsModule, DatePipe, DecimalPipe, IconComponent, ModalComponent],
  templateUrl: './landing-cotizar.component.html'
})
export class LandingCotizarComponent implements OnInit {
  @Input({ required: true }) paquete!: PaqueteTour;
  @Input({ required: true }) contacto!: Contacto;
  @Output() cerrar = new EventEmitter<void>();

  private store = inject(TourStore);
  private api = inject(CotizacionService);
  private router = inject(Router);
  auth = inject(AuthService);

  calendario = signal<CalendarioDia[]>([]);
  puntos = signal<PuntoRecojo[]>([]);
  cargandoFechas = signal(true);
  // Fechas que se pueden cotizar: el paquete opera, quedan cupos y la salida sigue abierta
  fechas = computed(() => this.calendario().filter(d => d.opera && d.cuposDisponibles > 0
    && ['SIN_SALIDA', 'PROGRAMADA', 'GARANTIZADA'].includes(d.estadoSalida)));

  fecha = '';
  cantidad = 2;
  lugarRecojoId: number | null = null;
  nombre = '';
  comentario = '';

  calculando = signal(false);
  error = signal('');
  cotizacion = signal<Cotizacion | null>(null);

  get dia(): CalendarioDia | undefined { return this.fechas().find(d => d.fecha === this.fecha); }
  get estimado(): number { return this.paquete.precioBase * (this.cantidad || 0); }
  get whatsapp(): string { return (this.contacto.telefono ?? '').replace(/\D/g, ''); }

  ngOnInit() {
    this.store.calendario(this.paquete.paqueteId, hoy(), 120).subscribe({
      next: d => {
        this.calendario.set(d);
        // Primera fecha que además se puede reservar por la web; si no hay, la primera con cupos
        this.fecha = (d.find(x => x.reservableWeb) ?? this.fechas()[0])?.fecha ?? '';
        this.cargandoFechas.set(false);
      },
      error: e => { this.error.set(mensajeError(e)); this.cargandoFechas.set(false); }
    });
    this.store.puntosRecojo(this.paquete.paqueteId).subscribe({ next: p => this.puntos.set(p), error: () => this.puntos.set([]) });
  }

  cambiarCantidad(delta: number) {
    const tope = Math.min(99, this.dia?.cuposDisponibles ?? 99);
    this.cantidad = Math.max(1, Math.min(tope, (this.cantidad || 0) + delta));
    this.error.set('');
  }

  cotizar() {
    this.error.set('');
    if (!this.fecha) { this.error.set('Elige la fecha del viaje.'); return; }
    if (!Number.isInteger(this.cantidad) || this.cantidad < 1 || this.cantidad > 99) { this.error.set('Indica entre 1 y 99 pasajeros.'); return; }
    this.calculando.set(true);
    this.api.cotizar(this.paquete.paqueteId, this.fecha, this.cantidad, this.lugarRecojoId).subscribe({
      next: c => { this.cotizacion.set(c); this.calculando.set(false); },
      error: e => { this.error.set(mensajeError(e)); this.calculando.set(false); }
    });
  }

  editar() { this.cotizacion.set(null); }

  // Texto de la cotización para WhatsApp y correo
  private mensaje(c: Cotizacion): string {
    const dmy = (iso: string) => iso.split('-').reverse().join('/');
    const soles = (n: number) => 'S/ ' + n.toLocaleString('es-PE', { minimumFractionDigits: 2, maximumFractionDigits: 2 });
    const lineas = [
      `Hola${this.nombre.trim() ? ', soy ' + this.nombre.trim() : ''}. Quiero reservar este tour que coticé en la web:`,
      `• Paquete: ${c.paquete} (${c.dias}D/${c.noches}N)`,
      `• Fecha: ${dmy(c.fechaInicio)}${c.fechaFin !== c.fechaInicio ? ' al ' + dmy(c.fechaFin) : ''}`,
      `• Pasajeros: ${c.cantidad}`,
      `• Recojo: ${c.puntoRecojo ?? 'Oficina de la agencia'}${c.horaRecojo ? ' (' + c.horaRecojo + ')' : ''}`,
      `• Total: ${soles(c.total)} (${soles(c.precioUnitario)} por persona)`
    ];
    if (this.comentario.trim()) lineas.push('', 'Comentarios: ' + this.comentario.trim());
    return lineas.join('\n');
  }

  enlaceWhatsapp(c: Cotizacion): string {
    return `https://wa.me/${this.whatsapp}?text=${encodeURIComponent(this.mensaje(c))}`;
  }

  enlaceCorreo(c: Cotizacion): string {
    return `mailto:${this.contacto.email}?subject=${encodeURIComponent('Cotización: ' + c.paquete)}&body=${encodeURIComponent(this.mensaje(c))}`;
  }

  // Cliente con sesión -> reserva en su portal · Visitante -> crea su cuenta (o inicia sesión) y sigue a la reserva
  // La fecha y la cantidad cotizadas viajan en la URL y llegan ya elegidas al formulario de reserva
  reservar(c: Cotizacion, destino: 'registro' | 'login' = 'registro') {
    const datos = { reservar: c.paqueteId, fecha: c.fechaInicio, cantidad: c.cantidad };
    this.router.navigate([this.auth.esCliente() ? '/mi-cuenta' : '/' + destino], { queryParams: datos });
  }
}
