import { CurrencyPipe } from '@angular/common';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { TourStore } from '../../core/services/tour-store.service';
import { AlertService } from '../../core/services/alert.service';
import { ImagenService } from '../../core/services/imagen.service';
import { ActividadItinerario, PaqueteForm } from '../../core/models';
import { DIAS_SEMANA } from '../../core/utils/etiquetas';
import { hoy } from '../../core/utils/date.util';
import { BadgeComponent } from '../../shared/badge.component';
import { IconComponent } from '../../shared/icon.component';
import { filtrarEscritura, filtrarPegado, sinRueda } from '../../core/utils/filtro';
import { FormValidacion, V } from '../../core/utils/validacion';
import { ModalComponent } from '../../shared/modal.component';

import { PageHeaderComponent } from '../../shared/page-header.component';
import { BuscadorComponent } from '../../shared/buscador.component';
@Component({
  selector: 'app-paquetes',
  standalone: true,
  imports: [BuscadorComponent, PageHeaderComponent, FormsModule, RouterLink, CurrencyPipe, BadgeComponent, IconComponent, ModalComponent],
  templateUrl: './paquetes.component.html'
})
export class PaquetesComponent {
  store = inject(TourStore);
  private alerts = inject(AlertService);
  imagenes = inject(ImagenService);


  texto = signal('');
  abierto = signal(false);
  fotoSeleccionada: File | null = null;
  vistaNueva = signal<string | null>(null);
  quitar = signal(false);
  editId: number | null = null;
  form: PaqueteForm = this.vacio();
  v = new FormValidacion(() => ({
    nombre: V.texto(this.form.nombre, 'El nombre', 100, true),
    descripcion: (this.form.descripcion ?? '').length > 4000 ? 'La descripción admite máximo 4000 caracteres.' : null,
    dias: V.entero(this.form.dias, 'Los días', 1, 99),
    noches: V.entero(this.form.noches, 'Las noches', 0, 99)
      ?? (this.form.noches > this.form.dias ? 'Las noches no pueden ser más que los días.' : null),
    precio: V.importe(this.form.precioBase, 'El precio base'),
    // Reglas de venta (v10): la BD las usa al crear una salida cuando se reserva una fecha nueva
    cupo: V.entero(this.form.cupoPorDefecto, 'El cupo por defecto', 1, 999),
    minimo: V.entero(this.form.minimoPasajeros, 'El mínimo de pasajeros', 1, 999)
      ?? ((this.form.minimoPasajeros ?? 0) > (this.form.cupoPorDefecto ?? 0) ? 'El mínimo no puede superar el cupo por defecto.' : null),
    diasOperacion: this.form.diasOperacion.includes('1') ? null : 'Elige al menos un día de operación.',
    anticipacion: V.entero(this.form.anticipacionMinHoras, 'La anticipación', 0, 720),
    hora: /^([01][0-9]|2[0-3]):[0-5][0-9]$/.test(this.form.horaInicio) ? null : 'Indica la hora de inicio (HH:MM).'
  }));
  diasSemana = DIAS_SEMANA;

  // Itinerario del paquete (PAQUETE_ITINERARIO), solo al editar
  itinerario = signal<ActividadItinerario[]>([]);
  actividad = { diaNumero: 1, titulo: '', horaInicio: '', lugarId: null as number | null };

  private vacio(): PaqueteForm {
    return { nombre: '', descripcion: '', precioBase: 0, dias: 1, noches: 0, imagen: '', estado: 'ACTIVO',
      cupoPorDefecto: 12, minimoPasajeros: 2, diasOperacion: '1111111', anticipacionMinHoras: 48, horaInicio: '08:00', serviciosIncluidos: '' };
  }

  // Días de operación: L M M J V S D como '1'/'0'
  opera(i: number) { return this.form.diasOperacion.charAt(i) === '1'; }
  alternarDia(i: number) {
    const d = this.form.diasOperacion.split('');
    d[i] = d[i] === '1' ? '0' : '1';
    this.form.diasOperacion = d.join('');
    this.v.tocar('diasOperacion');
  }

  private cargarItinerario(id: number) {
    this.store.itinerario(id).subscribe({ next: a => this.itinerario.set(a) });
  }
  agregarActividad() {
    if (!this.editId) return;
    if (!this.actividad.titulo.trim()) { this.alerts.toast('Escribe el título de la actividad', 'error'); return; }
    const id = this.editId;
    const datos = { diaNumero: this.actividad.diaNumero, orden: this.itinerario().filter(a => a.diaNumero === this.actividad.diaNumero).length + 1,
      lugarId: this.actividad.lugarId, titulo: this.actividad.titulo.trim(), descripcion: '', horaInicio: this.actividad.horaInicio };
    this.store.guardarActividad(id, datos, null).subscribe({
      next: () => { this.actividad = { diaNumero: this.actividad.diaNumero, titulo: '', horaInicio: '', lugarId: null }; this.cargarItinerario(id); },
      error: err => this.alerts.error(this.store.error(err))
    });
  }
  quitarActividad(a: ActividadItinerario) {
    this.store.eliminarActividad(a.paqueteId, a.itinerarioId).subscribe({
      next: () => this.cargarItinerario(a.paqueteId),
      error: err => this.alerts.error(this.store.error(err))
    });
  }

  filas = computed(() => {
    const t = this.texto().toLowerCase().trim();
    const hoyStr = hoy();
    return this.store.paquetes()
      .filter(p => !t || p.nombre.toLowerCase().includes(t) || p.descripcion.toLowerCase().includes(t))
      .map(p => ({
        paquete: p,
        proximas: this.store.salidasDe(p.paqueteId)
          .filter(s => (s.estado === 'PROGRAMADA' || s.estado === 'GARANTIZADA') && s.fechaInicio >= hoyStr && s.cuposDisponibles > 0).length
      }));
  });

  get vistaPrevia(): string | null {
    if (this.quitar()) return null;
    if (this.vistaNueva()) return this.vistaNueva();
    return this.imagenes.url(this.form.imagen);
  }

  elegir(event: any) {
    const file = event.target.files[0];
    event.target.value = '';
    if (file) this.procesar(file);
  }

  soltar(event: DragEvent) {
    event.preventDefault();
    if (event.dataTransfer && event.dataTransfer.files.length > 0) this.procesar(event.dataTransfer.files[0]);
  }

  private procesar(file: File) {
    const error = this.imagenes.validar(file);
    if (error) {
      this.alerts.error(error);
      return;
    }
    this.fotoSeleccionada = file;
    this.vistaNueva.set(URL.createObjectURL(file));
    this.quitar.set(false);
  }

  quitarImagen() {
    this.fotoSeleccionada = null;
    this.vistaNueva.set(null);
    this.quitar.set(true);
  }

  nuevo() {
    this.editId = null;
    this.form = this.vacio();
    this.itinerario.set([]);
    this.reiniciarImagen();
    this.v.reiniciar();
    this.abierto.set(true);
  }

  private reiniciarImagen() {
    this.fotoSeleccionada = null;
    this.vistaNueva.set(null);
    this.quitar.set(false);
  }

  editar(id: number) {
    const p = this.store.getPaquete(id)!;
    this.editId = p.paqueteId;
    this.form = {
      nombre: p.nombre, descripcion: p.descripcion, precioBase: p.precioBase, dias: p.dias, noches: p.noches,
      imagen: this.imagenes.url(p.imagen) ? p.imagen : '', estado: p.estado,
      cupoPorDefecto: p.cupoPorDefecto, minimoPasajeros: p.minimoPasajeros, diasOperacion: p.diasOperacion,
      anticipacionMinHoras: p.anticipacionMinHoras, horaInicio: p.horaInicio, serviciosIncluidos: p.serviciosIncluidos ?? ''
    };
    this.itinerario.set([]);
    this.cargarItinerario(p.paqueteId);
    this.reiniciarImagen();
    this.v.reiniciar();
    this.abierto.set(true);
  }

  sugerirNoches() {
    if (!this.editId && this.form.dias >= 1) this.form.noches = this.form.dias - 1;
  }

  guardar() {
    if (this.store.ocupado()) return;
    if (!this.v.valido()) { this.alerts.toast('Revisa los campos marcados en rojo', 'error'); return; }
    this.store.ocupado.set(true);
    if (this.fotoSeleccionada) {
      this.imagenes.subir(this.fotoSeleccionada).subscribe({
        next: (r) => this.enviarPaquete(r.imagen),
        error: (err) => this.fallo(err)
      });
    } else {
      this.enviarPaquete(this.quitar() ? '' : this.form.imagen);
    }
  }

  private enviarPaquete(imagen: string) {
    const f = this.form;
    const datos: PaqueteForm = {
      nombre: f.nombre.trim(), descripcion: (f.descripcion ? f.descripcion : '').trim(), precioBase: f.precioBase,
      dias: f.dias, noches: f.noches, imagen: imagen, estado: f.estado,
      cupoPorDefecto: f.cupoPorDefecto, minimoPasajeros: f.minimoPasajeros, diasOperacion: f.diasOperacion,
      anticipacionMinHoras: f.anticipacionMinHoras, horaInicio: f.horaInicio, serviciosIncluidos: (f.serviciosIncluidos ?? '').trim()
    };
    const editando = this.editId !== null;
    this.store.guardarPaquete(datos, this.editId).subscribe({
      next: (p) => {
        this.store.resaltar('paquete-' + p.paqueteId);
        this.store.ocupado.set(false);
        this.store.cargarPaquetes();
        this.abierto.set(false);
        this.alerts.toast(editando ? 'Paquete actualizado' : 'Paquete creado');
      },
      error: (err) => this.fallo(err)
    });
  }

  private fallo(err: unknown) {
    this.store.ocupado.set(false);
    this.alerts.error(this.store.error(err));
  }

  async eliminar(id: number) {
    // v10 no otorga DELETE sobre PAQUETES_TOUR: el paquete se retira de la venta (INACTIVO)
    if (!(await this.alerts.confirm('Quedará INACTIVO: no se vende más, pero se conservan sus salidas y reservas.', 'Retirar paquete'))) return;
    this.store.eliminarPaquete(id).subscribe({
      next: () => {
        this.store.cargarPaquetes();
        this.alerts.toast('Paquete retirado de la venta');
      },
      error: (err) => this.alerts.error(this.store.error(err))
    });
  }

  filtrar(evento: Event, tipo: string) { filtrarEscritura(evento, tipo); }
  pegar(evento: Event, tipo: string) { filtrarPegado(evento, tipo); }
  rueda(evento: Event) { sinRueda(evento); }
}
