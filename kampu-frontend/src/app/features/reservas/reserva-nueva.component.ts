import { CurrencyPipe, DatePipe } from '@angular/common';
import { Component, signal, inject, OnInit } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router, RouterLink } from '@angular/router';
import { TourStore } from '../../core/services/tour-store.service';
import { AlertService } from '../../core/services/alert.service';
import { CalendarioDia, Cliente, ContactoReserva, PasajeroDraft, PuntoRecojo, TipoDocumento, TipoDocumentoCliente } from '../../core/models';
import { addDays, hoy } from '../../core/utils/date.util';
import { CANALES_VENTA, etiqueta } from '../../core/utils/etiquetas';
import { IconComponent } from '../../shared/icon.component';
import { MigasComponent } from '../../shared/migas.component';
import { filtrarEscritura, filtrarPegado } from '../../core/utils/filtro';
import { Errores, FormValidacion, V } from '../../core/utils/validacion';
import { ClienteSelectorComponent } from './cliente-selector.component';
import { TelefonoInputComponent } from '../../shared/telefono-input.component';
import { errorTelefonoPais } from '../../core/utils/paises';

import { PageHeaderComponent } from '../../shared/page-header.component';
@Component({
  selector: 'app-reserva-nueva',
  standalone: true,
  imports: [PageHeaderComponent, FormsModule, RouterLink, CurrencyPipe, DatePipe, IconComponent, ClienteSelectorComponent, TelefonoInputComponent, MigasComponent],
  templateUrl: './reserva-nueva.component.html'
})
export class ReservaNuevaComponent implements OnInit {
  store = inject(TourStore);
  private alerts = inject(AlertService);
  private router = inject(Router);
  private route = inject(ActivatedRoute);

  tipos: TipoDocumento[] = ['DNI', 'CE', 'PASAPORTE'];
  tiposCliente: TipoDocumentoCliente[] = ['DNI', 'CE', 'PASAPORTE', 'RUC'];
  canales = CANALES_VENTA;
  hoyTexto = hoy();
  etiqueta = etiqueta;
  modo: 'registrado' | 'invitado' = 'registrado';
  cliente: Cliente | null = null;
  contacto: ContactoReserva = { nombre: '', tipoDocumento: 'DNI' as TipoDocumentoCliente, numeroDocumento: '', email: '', telefono: '' };
  paqueteId: number | null = null;
  fecha = '';
  cantidad = 1;
  canal: 'PRESENCIAL' | 'TELEFONO' | 'WHATSAPP' = 'PRESENCIAL';
  descuento = 0;
  lugarRecojoId: number | null = null;
  calendario = signal<CalendarioDia[]>([]);
  puntos = signal<PuntoRecojo[]>([]);
  observaciones = '';
  pasajeros: PasajeroDraft[] = [];
  v = new FormValidacion(() => {
    const e: Errores = {
      cliente: this.modo === 'registrado' && !this.cliente ? 'Busca y selecciona un cliente.' : null,
      cNombre: this.modo === 'invitado' ? V.nombrePersona(this.contacto.nombre, 'El nombre del cliente') : null,
      cDocumento: this.modo === 'invitado'
        ? V.documento(this.contacto.tipoDocumento, this.contacto.numeroDocumento)
          ?? (this.store.clientes().some(c => c.numeroDocumento.toUpperCase() === this.contacto.numeroDocumento.trim().toUpperCase())
            ? 'Ya existe un cliente con ese documento: búscalo como registrado.' : null)
        : null,
      cEmail: this.modo === 'invitado'
        ? (this.contacto.email.trim() ? V.email(this.contacto.email) : 'El correo es obligatorio para enviarle la boleta.') : null,
      cTelefono: this.modo === 'invitado' ? errorTelefonoPais(this.contacto.telefono) : null,
      paquete: this.paqueteId ? null : 'Selecciona un paquete.',
      fecha: !this.fecha ? 'Elige la fecha del viaje.'
        : this.fecha < hoy() ? 'Elige una fecha de hoy en adelante.'
        : this.dia && !this.dia.opera ? 'El paquete no opera ese día de la semana.'
        : this.dia && this.dia.cuposDisponibles < this.cantidad ? `Ese día solo quedan ${this.dia.cuposDisponibles} cupo(s).` : null,
      cantidad: V.entero(this.cantidad, 'La cantidad de pasajeros', 1, 99),
      descuento: this.descuento < 0 ? 'El descuento no puede ser negativo.'
        : this.descuento > this.bruto ? 'El descuento no puede superar el importe.' : null,
      observaciones: this.observaciones.length > 500 ? 'Las observaciones admiten máximo 500 caracteres.' : null
    };
    const docs = new Set<string>();
    this.pasajeros.forEach((p, i) => {
      const doc = p.numeroDocumento.trim().toUpperCase();
      e['p' + i + 'nombre'] = V.nombrePersona(p.nombreCompleto, 'El nombre del pasajero');
      e['p' + i + 'documento'] = V.documento(p.tipoDocumento, p.numeroDocumento)
        ?? (docs.has(doc) ? 'Este documento ya está en otro pasajero de la reserva.' : null)
        ?? (this.yaViaja(p.tipoDocumento, doc) ? 'Este pasajero ya tiene una reserva activa en esta salida.' : null);
      if (doc) docs.add(doc);
      e['p' + i + 'nacionalidad'] = V.nacionalidad(p.nacionalidad);
      e['p' + i + 'nacimiento'] = V.fecha(p.fechaNacimiento, 'La fecha de nacimiento', false)
        ?? (p.fechaNacimiento && p.fechaNacimiento > this.ayer ? 'La fecha de nacimiento debe ser anterior a hoy.' : null)
        ?? (p.fechaNacimiento && p.fechaNacimiento < '1900-01-01' ? 'La fecha de nacimiento no puede ser anterior a 1900.' : null);
    });
    return e;
  });

  ayer = (() => { const d = new Date(); d.setDate(d.getDate() - 1); return d.toISOString().slice(0, 10); })();

  private vacio(): PasajeroDraft {
    return { nombreCompleto: '', tipoDocumento: 'DNI', numeroDocumento: '', nacionalidad: 'Peruana', fechaNacimiento: '' };
  }

  get paquetesActivos() { return this.store.paquetes().filter(p => p.estado === 'ACTIVO'); }
  get paquete() { return this.store.getPaquete(this.paqueteId); }
  get dia(): CalendarioDia | undefined { return this.calendario().find(d => d.fecha === this.fecha); }
  get salidaId(): number | null { return this.dia?.salidaId ?? null; }
  get salida() { return this.store.getSalida(this.salidaId); }
  get fechaFin(): string { return this.paquete && this.fecha ? addDays(this.fecha, this.paquete.dias - 1) : ''; }
  get fechasSugeridas(): CalendarioDia[] {
    return this.calendario().filter(d => d.opera && d.cuposDisponibles > 0 && d.estadoSalida !== 'COMPLETADA').slice(0, 8);
  }

  private yaViaja(tipo: string, doc: string): boolean {
    if (!this.salidaId || !doc) return false;
    const reservas = new Set(this.store.reservas()
      .filter(r => r.salidaId === this.salidaId && r.estadoReserva !== 'ANULADA').map(r => r.reservaId));
    return this.store.pasajeros().some(x => reservas.has(x.reservaId) && x.tipoDocumento === tipo
      && x.numeroDocumento.toUpperCase() === doc);
  }
  get bruto() { return (this.paquete?.precioBase ?? 0) * (this.cantidad || 0); }
  get total() { return Math.max(this.bruto - (this.descuento || 0), 0); }
  get excede() { return this.pasajeros.length > (this.cantidad || 0); }

  cambioPaquete() {
    this.calendario.set([]);
    this.puntos.set([]);
    this.lugarRecojoId = null;
    if (!this.paqueteId) return;
    const id = this.paqueteId;
    this.store.calendario(id, hoy(), 60).subscribe({
      next: dias => {
        this.calendario.set(dias);
        if (!this.fecha || !dias.some(d => d.fecha === this.fecha && d.opera)) this.fecha = this.fechasSugeridas[0]?.fecha ?? '';
      },
      error: e => this.alerts.error(this.store.error(e))
    });
    this.store.puntosRecojo(id).subscribe({ next: p => this.puntos.set(p) });
  }
  get tieneCliente() { return this.modo === 'registrado' ? !!this.cliente : !!this.contacto.nombre.trim(); }

  ngOnInit() {
    this.store.cargar(false, () => {
      const q = this.route.snapshot.queryParamMap;
      const salida = this.store.getSalida(Number(q.get('salida')));
      const idPaquete = Number(q.get('paquete')) || salida?.paqueteId;
      if (idPaquete) {
        this.paqueteId = idPaquete;
        this.fecha = q.get('fecha') ?? salida?.fechaInicio ?? '';
        this.cambioPaquete();
      }
    });
  }

  agregar() { if (this.pasajeros.length < this.cantidad) this.pasajeros.push(this.vacio()); }
  quitar(i: number) { this.pasajeros.splice(i, 1); }

  cambiarModo(modo: 'registrado' | 'invitado') {
    this.modo = modo;
    this.v.reiniciar();
  }

  elegirCliente(c: Cliente | null) {
    this.cliente = c;
    this.v.tocar('cliente');
    if (c && this.primeroVacio()) this.agregarCliente();
  }

  pasarAInvitado(texto: string) {
    this.modo = 'invitado';
    const t = texto.trim();
    if (t.includes('@')) this.contacto.email = t;
    else if (/^[a-zA-ZÀ-ÿ .'-]+$/.test(t)) this.contacto.nombre = t;
    this.v.reiniciar();
  }

  private primeroVacio(): boolean {
    const p = this.pasajeros[0];
    return this.pasajeros.length === 1 && !p.nombreCompleto.trim() && !p.numeroDocumento.trim();
  }

  agregarCliente() {
    let dato: PasajeroDraft;
    if (this.modo === 'registrado') {
      const c = this.cliente;
      if (!c) return;
      if (c.tipoDocumento === 'RUC') { this.alerts.toast('El cliente es una empresa (RUC): agrega a los pasajeros uno por uno', 'info'); return; }
      if (this.pasajeros.length >= this.cantidad) { this.alerts.toast('Ya registraste a todos los pasajeros de la reserva', 'info'); return; }
      dato = { nombreCompleto: c.nombreCompleto, tipoDocumento: c.tipoDocumento, numeroDocumento: c.numeroDocumento,
               nacionalidad: 'Peruana', fechaNacimiento: '' };
    } else {
      if (!this.contacto.nombre.trim()) return;
      if (this.contacto.tipoDocumento === 'RUC') { this.alerts.toast('El cliente es una empresa (RUC): agrega a los pasajeros uno por uno', 'info'); return; }
      if (this.pasajeros.length >= this.cantidad) { this.alerts.toast('Ya registraste a todos los pasajeros de la reserva', 'info'); return; }
      dato = { nombreCompleto: this.contacto.nombre.trim(), tipoDocumento: this.contacto.tipoDocumento as TipoDocumento,
               numeroDocumento: this.contacto.numeroDocumento.trim(), nacionalidad: 'Peruana', fechaNacimiento: '' };
    }
    if (this.primeroVacio()) this.pasajeros[0] = dato;
    else this.pasajeros.push(dato);
  }

  pasos = ['Cliente', 'Paquete y fecha', 'Pasajeros', 'Revisar'];
  paso = signal(1);
  private camposPaso(n: number): string[] {
    if (n === 1) return ['cliente', 'cNombre', 'cDocumento', 'cEmail', 'cTelefono'];
    if (n === 2) return ['paquete', 'fecha', 'cantidad', 'descuento', 'observaciones'];
    if (n === 3) return this.pasajeros.flatMap((_, i) => ['nombre', 'documento', 'nacionalidad', 'nacimiento'].map(c => 'p' + i + c));
    return [];
  }
  private pasoValido(n: number): boolean {
    return this.v.validos(this.camposPaso(n)) && !(n === 3 && this.excede);
  }
  siguiente() {
    if (!this.pasoValido(this.paso())) { this.alerts.toast('Revisa los campos marcados en rojo', 'error'); return; }
    this.paso.set(Math.min(this.paso() + 1, 4));
    window.scrollTo({ top: 0, behavior: 'smooth' });
  }
  anterior() { this.paso.set(Math.max(this.paso() - 1, 1)); }
  irA(n: number) {
    for (let i = 1; i < n; i++) {
      if (!this.pasoValido(i)) { this.paso.set(i); this.alerts.toast('Completa este paso primero', 'error'); return; }
    }
    this.paso.set(n);
  }
  nombreCliente(): string {
    return this.modo === 'registrado' ? (this.cliente?.nombreCompleto ?? '') : this.contacto.nombre.trim();
  }

  guardar() {
    if (this.store.ocupado()) return;
    if (!this.v.valido() || this.excede) { this.alerts.toast('Revisa los campos marcados en rojo', 'error'); return; }
    const lista: PasajeroDraft[] = this.pasajeros.map(p => ({
      nombreCompleto: p.nombreCompleto.trim(), tipoDocumento: p.tipoDocumento, numeroDocumento: p.numeroDocumento.trim(),
      nacionalidad: p.nacionalidad.trim(), fechaNacimiento: p.fechaNacimiento
    }));
    this.store.ocupado.set(true);
    const clienteId = this.modo === 'registrado' ? this.cliente!.clienteId : null;
    const contacto: ContactoReserva | null = this.modo === 'invitado'
      ? { nombre: this.contacto.nombre.trim(), tipoDocumento: this.contacto.tipoDocumento, numeroDocumento: this.contacto.numeroDocumento.trim(),
          email: this.contacto.email.trim().toLowerCase(), telefono: this.contacto.telefono.trim() }
      : null;
    this.store.crearReserva({
      clienteId: clienteId, contacto: contacto, paqueteId: this.paqueteId!, fecha: this.fecha, cantidad: this.cantidad,
      canal: this.canal, descuento: this.descuento || 0, lugarRecojoId: this.lugarRecojoId,
      observaciones: this.observaciones.trim(), pasajeros: lista
    }).subscribe({
      next: (reserva) => {
        this.store.ocupado.set(false);
        this.alerts.toast('Reserva creada');
        this.store.cargar(true, () => this.router.navigate(['/reservas', reserva.reservaId]));
      },
      error: (err) => {
        this.store.ocupado.set(false);
        this.alerts.error(this.store.error(err));
      }
    });
  }

  filtrar(evento: Event, tipo: string) { filtrarEscritura(evento, tipo); }
  pegar(evento: Event, tipo: string) { filtrarPegado(evento, tipo); }
}
