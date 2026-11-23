import { DatePipe, DecimalPipe } from '@angular/common';
import { ActivatedRoute } from '@angular/router';
import { Component, computed, inject, OnDestroy, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Observable } from 'rxjs';
import {
  CategoriaLicencia, EstadoPersonal, EstadoProveedor, EstadoVehiculo, HabitacionForm, Lugar, LugarForm, LugarSugerido, PersonalForm, ProveedorForm,
  RolPersonal, TipoLugar, TipoVehiculo, VehiculoForm
} from '../../core/models';
import { TourStore } from '../../core/services/tour-store.service';
import { AlertService } from '../../core/services/alert.service';
import { AuthService } from '../../core/services/auth.service';
import { IconComponent } from '../../shared/icon.component';
import { BadgeComponent } from '../../shared/badge.component';
import { filtrarEscritura, filtrarPegado, sinRueda } from '../../core/utils/filtro';
import { FormValidacion, telefonoRepetido, V } from '../../core/utils/validacion';
import { etiqueta, iconoLugar } from '../../core/utils/etiquetas';
import { addDays, hoy } from '../../core/utils/date.util';
import { ModalComponent } from '../../shared/modal.component';
import { ImagenService } from '../../core/services/imagen.service';
import { of, switchMap } from 'rxjs';

type Tab = 'proveedores' | 'personal' | 'vehiculos' | 'habitaciones' | 'lugares';
type Seccion = 'personal' | 'vehiculos' | 'proveedores';

import { PageHeaderComponent } from '../../shared/page-header.component';
@Component({
  selector: 'app-recursos',
  standalone: true,
  imports: [PageHeaderComponent, FormsModule, DatePipe, DecimalPipe, IconComponent, BadgeComponent, ModalComponent],
  templateUrl: './recursos.component.html'
})
export class RecursosComponent implements OnDestroy {
  store = inject(TourStore);
  private alerts = inject(AlertService);
  private auth = inject(AuthService);
  imagenes = inject(ImagenService);
  foto: File | null = null;
  vistaFoto = signal<string | null>(null);

  private ruta = inject(ActivatedRoute);
  seccion: Seccion = (this.ruta.snapshot.data['seccion'] as Seccion) ?? 'proveedores';
  propio = this.seccion !== 'proveedores';
  encabezado = {
    personal: { titulo: 'Personal', subtitulo: 'Guías y conductores propios de la agencia. Se registran en Usuarios al crear su cuenta.' },
    vehiculos: { titulo: 'Vehículos', subtitulo: 'Flota propia de la agencia.' },
    proveedores: { titulo: 'Proveedores', subtitulo: 'Proveedores externos con sus guías, conductores, vehículos y habitaciones de hotel, y los lugares de la operación.' }
  }[this.seccion];

  tabs: { id: Tab; texto: string; icono: string; singular: string; nueva?: boolean }[] = this.seccion === 'personal'
    ? [{ id: 'personal', texto: 'Personal', icono: 'id', singular: 'guía o conductor' }]
    : this.seccion === 'vehiculos'
      ? [{ id: 'vehiculos', texto: 'Vehículos', icono: 'truck', singular: 'vehículo' }]
      : [
        { id: 'proveedores', texto: 'Proveedores', icono: 'flag', singular: 'proveedor' },
        { id: 'personal', texto: 'Personal de proveedores', icono: 'id', singular: 'guía o conductor del proveedor' },
        { id: 'vehiculos', texto: 'Vehículos de proveedores', icono: 'truck', singular: 'vehículo del proveedor' },
        { id: 'habitaciones', texto: 'Habitaciones de hotel', icono: 'bed', singular: 'habitación de hotel', nueva: true },
        { id: 'lugares', texto: 'Lugares', icono: 'map-pin', singular: 'lugar' }
      ];
  categorias: CategoriaLicencia[] = ['A-I', 'A-IIa', 'A-IIb', 'A-IIIa', 'A-IIIb', 'A-IIIc'];
  estadosProveedor: EstadoProveedor[] = ['ACTIVO', 'INACTIVO', 'SUSPENDIDO'];
  estadosPersonal: EstadoPersonal[] = ['DISPONIBLE', 'OCUPADO', 'INACTIVO'];
  tiposVehiculo: TipoVehiculo[] = ['AUTO', 'CAMIONETA_4X4', 'VAN', 'MINIBUS', 'BUS'];
  estadosVehiculo: EstadoVehiculo[] = ['OPERATIVO', 'MANTENIMIENTO', 'INACTIVO'];
  tiposLugar: TipoLugar[] = ['AEROPUERTO', 'TERMINAL', 'HOTEL', 'ATRACTIVO', 'CIUDAD', 'OFICINA', 'OTRO'];
  etiqueta = etiqueta;
  iconoLugar = iconoLugar;
  hoy = hoy();
  pronto = addDays(hoy(), 30);

  tab = signal<Tab>(this.tabInicial());
  private tabInicial(): Tab {
    if (this.seccion !== 'proveedores') return this.seccion;
    const t = this.ruta.snapshot.queryParamMap.get('tab');
    return t === 'personal' || t === 'vehiculos' || t === 'habitaciones' || t === 'lugares' ? t : 'proveedores';
  }
  filtroProveedor = signal<number | null>(null);
  filtroRol = signal<'' | 'GUIA' | 'CONDUCTOR'>('');
  abierto = signal(false);
  editId: number | null = null;

  constructor() {
    this.store.cargarPersonal();
    this.store.cargarCargos();
    this.store.cargarVehiculos();
    this.store.cargarProveedores();
    if (this.seccion === 'proveedores') this.store.cargarHabitaciones();
  }

  ngOnDestroy() {
    if (this.temporizadorBusqueda) clearTimeout(this.temporizadorBusqueda);
    this.numeroBusqueda++;
  }

  busqueda = '';
  private temporizadorBusqueda: ReturnType<typeof setTimeout> | null = null;
  private ultimaBusqueda: string | null = null;
  private numeroBusqueda = 0;
  sugerencias = signal<LugarSugerido[]>([]);
  buscando = signal(false);
  sinResultados = signal(false);
  buscar(texto: string) {
    this.sinResultados.set(false);
    if (texto.trim().length < 3) this.sugerencias.set([]);
    this.programarBusqueda(texto.trim());
  }
  usarSugerencia(s: LugarSugerido) {
    const tipo = this.lugar.tipoLugar === 'OFICINA' && this.editId ? 'OFICINA' : s.tipoLugar;
    this.lugar = { ...this.lugar, nombre: s.nombre.slice(0, 150), tipoLugar: tipo, ciudad: (s.ciudad || this.lugar.ciudad).slice(0, 100),
      latitud: s.latitud, longitud: s.longitud, direccion: (s.direccion || this.lugar.direccion).slice(0, 200) };
    this.limpiarBusqueda();
    this.v.tocar('lNombre'); this.v.tocar('lCiudad'); this.v.tocar('lLatitud'); this.v.tocar('lLongitud');
  }
  private limpiarBusqueda() {
    this.busqueda = '';
    this.sugerencias.set([]);
    this.sinResultados.set(false);
    this.programarBusqueda('');
  }
  private programarBusqueda(q: string) {
    if (this.temporizadorBusqueda) clearTimeout(this.temporizadorBusqueda);
    this.temporizadorBusqueda = setTimeout(() => this.consultarLugares(q), 450);
  }
  private consultarLugares(q: string) {
    if (q === this.ultimaBusqueda) return;
    this.ultimaBusqueda = q;
    const numero = ++this.numeroBusqueda;
    if (q.length < 3) {
      this.buscando.set(false);
      this.sugerencias.set([]);
      this.sinResultados.set(false);
      return;
    }
    this.buscando.set(true);
    this.store.buscarLugares(q).subscribe({
      next: r => {
        if (numero !== this.numeroBusqueda) return;
        this.buscando.set(false);
        this.sugerencias.set(r);
        this.sinResultados.set(r.length === 0);
      },
      error: () => {
        if (numero !== this.numeroBusqueda) return;
        this.buscando.set(false);
        this.sugerencias.set([]);
        this.sinResultados.set(true);
      }
    });
  }

  proveedor: ProveedorForm = this.proveedorVacio();
  persona: PersonalForm = this.personaVacia();
  vehiculo: VehiculoForm = this.vehiculoVacio();
  lugar: LugarForm = this.lugarVacio();
  habitacion: HabitacionForm = this.habitacionVacia();

  puedeEditar = computed(() => this.auth.puede('GESTIONAR_LOGISTICA'));

  v = new FormValidacion(() => {
    switch (this.tab()) {
      case 'proveedores': {
        const p = this.proveedor;
        return {
          pNombre: V.texto(p.nombreComercial, 'El nombre comercial', 150, true),
          pRuc: V.ruc(p.ruc),
          pTelefono: V.telefono(p.telefono)
            ?? (telefonoRepetido(p.telefono, this.store.proveedores(), x => x.telefono, x => x.proveedorId === this.editId)
              ? 'Ese teléfono ya está registrado para otro proveedor.' : null),
          pEmail: p.email.trim() ? V.email(p.email) : null,
          pServicio: p.ofreceTransporte || p.ofreceGuiado || p.ofreceHospedaje
            ? null : 'Marca al menos un soporte que brinda.'
        };
      }
      case 'personal': {
        const p = this.persona;
        const conduce = this.requiereLicencia;
        const lic = p.numLicencia.trim();
        const prov = this.store.getProveedor(p.proveedorId);
        const funcion = this.store.getCargo(p.cargo)?.funcion;
        return {
          rProveedor: !prov ? 'Elige el proveedor.'
            : funcion === 'TRANSPORTE' && !prov.ofreceTransporte ? 'Ese proveedor no brinda transporte.'
            : funcion === 'GUIADO' && !prov.ofreceGuiado ? 'Ese proveedor no brinda guiado.' : null,
          rCargo: p.cargo ? null : 'Elige el cargo.',
          rDocumento: !p.numeroDocumento.trim() || /^[A-Za-z0-9]{6,20}$/.test(p.numeroDocumento.trim()) ? null
            : 'El documento solo admite letras y números (6 a 20 caracteres).',
          rNombre: V.nombrePersona(p.nombreCompleto),
          rTelefono: V.telefono(p.telefono)
            ?? (telefonoRepetido(p.telefono, this.store.personal(), x => x.telefono, x => x.personalId === this.editId)
              ? 'Ese teléfono ya está registrado para otra persona.' : null),
          rLicencia: !conduce && !lic ? null
            : (!lic ? 'Quien conduce necesita número de licencia.'
              : (/^[A-Za-z0-9]{6,20}$/.test(lic) ? null : 'La licencia solo admite letras y números (6 a 20 caracteres).')),
          rCategoria: conduce && !p.catLicencia ? 'Elige la categoría de la licencia.' : null,
          rCarne: !this.esGuia || (!p.carneGuia.trim() && !p.vencCarne) ? null
            : !/^[A-Za-z0-9-]{3,30}$/.test(p.carneGuia.trim()) ? 'El carné solo admite letras, números y guion (3 a 30).'
            : !p.vencCarne ? 'Indica el vencimiento del carné.' : null,
          rIdiomas: this.esGuia ? V.texto(p.idiomas, 'Los idiomas', 200) : null,
          rVencimiento: conduce ? (V.fecha(p.vencLicencia, 'La fecha de vencimiento')
            ?? (p.vencLicencia < hoy() ? 'La licencia está vencida.' : null)) : null
        };
      }
      case 'vehiculos': return {
        vProveedor: this.propio ? null : !this.vehiculo.proveedorId ? 'Elige el proveedor.'
          : !this.store.getProveedor(this.vehiculo.proveedorId)?.ofreceTransporte ? 'Ese proveedor no brinda transporte.' : null,
        vPlaca: V.placa(this.vehiculo.placa),
        vMarca: V.texto(this.vehiculo.marcaModelo, 'La marca/modelo', 100),
        vCapacidad: V.entero(this.vehiculo.capacidadPax, 'La capacidad', 1, 80),
        vMantenimiento: V.fecha(this.vehiculo.proxMantenimiento, 'La fecha del próximo mantenimiento', false),
        vSoat: V.fecha(this.vehiculo.vencSoat, 'El vencimiento del SOAT', false),
        vRevision: V.fecha(this.vehiculo.vencRevision, 'El vencimiento de la revisión técnica', false)
      };
      case 'habitaciones': {
        const h = this.habitacion;
        return {
          hProveedor: !h.proveedorId ? 'Elige el proveedor de hospedaje.'
            : !this.store.getProveedor(h.proveedorId)?.ofreceHospedaje ? 'Ese proveedor no brinda hospedaje.' : null,
          hNombre: V.texto(h.nombre, 'El nombre', 150, true),
          hDescripcion: V.texto(h.descripcion, 'La descripción', 300),
          hPrecio: h.precioNoche === null || (h.precioNoche as unknown) === '' ? 'Ingresa el precio por noche.'
            : h.precioNoche <= 0 ? 'El precio por noche debe ser mayor a 0.' : null
        };
      }
      case 'lugares': {
        const l = this.lugar;
        const vacioLat = l.latitud === null || (l.latitud as unknown) === '';
        const vacioLon = l.longitud === null || (l.longitud as unknown) === '';
        return {
          lNombre: V.texto(l.nombre, 'El nombre', 150, true),
          lCiudad: V.texto(l.ciudad, 'La ciudad', 100, true),
          lDireccion: V.texto(l.direccion, 'La dirección', 200),
          lMinutos: l.esPuntoRecojo || l.tipoLugar === 'OFICINA' ? V.entero(l.minutosAntesRecojo, 'Los minutos', 0, 240) : null,
          lLatitud: vacioLat ? (vacioLon ? null : 'Indica también la latitud.') : (l.latitud! < -90 || l.latitud! > 90 ? 'La latitud va de -90 a 90.' : null),
          lLongitud: vacioLon ? (vacioLat ? null : 'Indica también la longitud.') : (l.longitud! < -180 || l.longitud! > 180 ? 'La longitud va de -180 a 180.' : null)
        };
      }
    }
  });

  personalFiltrado = computed(() => {
    const p = this.filtroProveedor();
    const r = this.filtroRol();
    const funcion = r === 'GUIA' ? 'GUIADO' : r === 'CONDUCTOR' ? 'TRANSPORTE' : '';
    return this.store.personal().filter(x => (this.propio ? x.proveedorId === null : x.proveedorId !== null && (p === null || x.proveedorId === p))
      && (!funcion || x.funcion === funcion));
  });
  vehiculosFiltrados = computed(() => {
    const p = this.filtroProveedor();
    return this.store.vehiculos().filter(v => this.propio ? v.proveedorId === null : v.proveedorId !== null && (p === null || v.proveedorId === p));
  });
  lugaresPorCiudad = computed(() => {
    const grupos: { ciudad: string; lugares: Lugar[] }[] = [];
    for (const l of this.store.lugares()) {
      let g = grupos.find(x => x.ciudad === l.ciudad);
      if (!g) { g = { ciudad: l.ciudad, lugares: [] }; grupos.push(g); }
      g.lugares.push(l);
    }
    return grupos;
  });
  habitacionesFiltradas = computed(() => {
    const p = this.filtroProveedor();
    return this.store.habitaciones().filter(h => p === null || h.proveedorId === p);
  });
  proveedoresActivos = computed(() => this.store.proveedores().filter(p => p.estado !== 'INACTIVO'));

  get actual() { return this.tabs.find(t => t.id === this.tab())!; }

  private proveedorVacio(): ProveedorForm {
    return { nombreComercial: '', ruc: '', telefono: '', email: '', ofreceTransporte: true, ofreceGuiado: false,
      ofreceHospedaje: false, estado: 'ACTIVO' };
  }
  private proveedorFiltro(): number | null { return this.propio ? null : this.filtroProveedor(); }
  private personaVacia(): PersonalForm {
    return { proveedorId: this.proveedorFiltro(), numeroDocumento: '', nombreCompleto: '', cargo: 'GUIA', telefono: '',
      numLicencia: '', catLicencia: '', vencLicencia: '', estado: 'DISPONIBLE', carneGuia: '', vencCarne: '', idiomas: '' };
  }
  private vehiculoVacio(): VehiculoForm {
    return { proveedorId: this.proveedorFiltro(), placa: '', tipoVehiculo: 'VAN', marcaModelo: '',
      capacidadPax: 12, proxMantenimiento: addDays(hoy(), 180), estado: 'OPERATIVO', vencSoat: '', vencRevision: '' };
  }
  private lugarVacio(): LugarForm {
    return { nombre: '', tipoLugar: 'HOTEL', ciudad: '', latitud: null, longitud: null, direccion: '', esPuntoRecojo: false, minutosAntesRecojo: 0 };
  }
  private habitacionVacia(): HabitacionForm {
    const p = this.store.getProveedor(this.filtroProveedor());
    return { proveedorId: p?.ofreceHospedaje ? p.proveedorId : null, nombre: '', descripcion: '', precioNoche: null,
      modalidadPrecio: 'POR_PERSONA', imagen: '', estado: 'ACTIVO' };
  }
  proveedoresHospedaje = computed(() => this.store.proveedores().filter(p => p.ofreceHospedaje && p.estado === 'ACTIVO'));
  elegirFoto(evento: Event) {
    const file = (evento.target as HTMLInputElement).files?.[0];
    if (!file) return;
    const error = this.imagenes.validar(file);
    if (error) { this.alerts.toast(error, 'error'); return; }
    this.foto = file;
    this.vistaFoto.set(URL.createObjectURL(file));
  }
  quitarFoto() {
    this.foto = null;
    this.vistaFoto.set(null);
    this.habitacion.imagen = '';
  }
  get esGuia(): boolean { return this.store.getCargo(this.persona.cargo)?.funcion === 'GUIADO'; }
  get requiereLicencia(): boolean { return !!this.store.getCargo(this.persona.cargo)?.requiereLicencia; }

  private abrir() { this.limpiarBusqueda(); this.v.reiniciar(); this.abierto.set(true); }

  nuevo() {
    this.editId = null;
    this.proveedor = this.proveedorVacio();
    this.persona = this.personaVacia();
    this.vehiculo = this.vehiculoVacio();
    this.lugar = this.lugarVacio();
    this.habitacion = this.habitacionVacia();
    this.foto = null;
    this.vistaFoto.set(null);
    this.abrir();
  }

  editarProveedor(id: number) {
    const p = this.store.getProveedor(id)!;
    this.editId = id;
    this.proveedor = { nombreComercial: p.nombreComercial, ruc: p.ruc, telefono: p.telefono, email: p.email,
      ofreceTransporte: p.ofreceTransporte, ofreceGuiado: p.ofreceGuiado, ofreceHospedaje: p.ofreceHospedaje,
      estado: p.estado };
    this.abrir();
  }
  editarPersona(id: number) {
    const p = this.store.getPersonal(id)!;
    this.editId = id;
    this.persona = { proveedorId: p.proveedorId, numeroDocumento: p.numeroDocumento, nombreCompleto: p.nombreCompleto, cargo: p.cargo, telefono: p.telefono,
      numLicencia: p.numLicencia ?? '', catLicencia: p.catLicencia ?? '', vencLicencia: p.vencLicencia ?? '', estado: p.estado,
      carneGuia: p.carneGuia ?? '', vencCarne: p.vencCarne ?? '', idiomas: p.idiomas ?? '' };
    this.abrir();
  }
  editarVehiculo(id: number) {
    const x = this.store.getVehiculo(id)!;
    this.editId = id;
    this.vehiculo = { proveedorId: x.proveedorId, placa: x.placa, tipoVehiculo: x.tipoVehiculo, marcaModelo: x.marcaModelo,
      capacidadPax: x.capacidadPax, proxMantenimiento: x.proxMantenimiento ?? '', estado: x.estado,
      vencSoat: x.vencSoat ?? '', vencRevision: x.vencRevision ?? '' };
    this.abrir();
  }
  editarLugar(id: number) {
    const l = this.store.getLugar(id)!;
    this.editId = id;
    this.lugar = { nombre: l.nombre, tipoLugar: l.tipoLugar, ciudad: l.ciudad, latitud: l.latitud, longitud: l.longitud,
      direccion: l.direccion, esPuntoRecojo: l.esPuntoRecojo, minutosAntesRecojo: l.minutosAntesRecojo };
    this.abrir();
  }
  editarHabitacion(id: number) {
    const h = this.store.habitaciones().find(x => x.habitacionId === id)!;
    this.editId = id;
    this.habitacion = { proveedorId: h.proveedorId, nombre: h.nombre, descripcion: h.descripcion, precioNoche: h.precioNoche,
      modalidadPrecio: h.modalidadPrecio, imagen: h.imagen ?? '', estado: h.estado };
    this.foto = null;
    this.vistaFoto.set(h.imagen ? this.imagenes.url(h.imagen) : null);
    this.abrir();
  }

  guardar() {
    if (this.store.ocupado()) return;
    if (!this.v.valido()) { this.alerts.toast('Revisa los campos marcados en rojo', 'error'); return; }
    const t = (s: string) => (s ?? '').trim();
    const num = (x: number | null) => x === null || (x as unknown) === '' ? null : x;
    let peticion: Observable<unknown>;
    switch (this.tab()) {
      case 'proveedores': {
        const p = this.proveedor;
        peticion = this.store.guardarProveedor({ ...p, nombreComercial: t(p.nombreComercial), ruc: t(p.ruc), telefono: t(p.telefono),
          email: t(p.email).toLowerCase() }, this.editId);
        break;
      }
      case 'personal': {
        const p = this.persona;
        const conduce = this.requiereLicencia;
        const lic = t(p.numLicencia).toUpperCase();
        peticion = this.store.guardarPersonal({ ...p, nombreCompleto: t(p.nombreCompleto), telefono: t(p.telefono),
          numeroDocumento: t(p.numeroDocumento).toUpperCase(),
          numLicencia: conduce || lic ? lic : '', catLicencia: conduce || lic ? p.catLicencia : '',
          vencLicencia: conduce || lic ? p.vencLicencia : '',
          carneGuia: this.esGuia ? t(p.carneGuia).toUpperCase() : '', vencCarne: this.esGuia && t(p.carneGuia) ? p.vencCarne : '',
          idiomas: this.esGuia ? t(p.idiomas) : '' }, this.editId);
        break;
      }
      case 'vehiculos': {
        const x = this.vehiculo;
        peticion = this.store.guardarVehiculo({ ...x, proveedorId: this.propio ? null : x.proveedorId,
          placa: t(x.placa).toUpperCase(), marcaModelo: t(x.marcaModelo),
          proxMantenimiento: x.proxMantenimiento || '', vencSoat: x.vencSoat || '', vencRevision: x.vencRevision || '' }, this.editId);
        break;
      }
      case 'habitaciones': {
        const h = this.habitacion;
        const id = this.editId;
        const subida = this.foto ? this.imagenes.subirHabitacion(this.foto) : of({ imagen: h.imagen });
        peticion = subida.pipe(switchMap(r => this.store.guardarHabitacion({ ...h, nombre: t(h.nombre),
          descripcion: t(h.descripcion), precioNoche: num(h.precioNoche), imagen: r.imagen }, id)));
        break;
      }
      default: {
        const l = this.lugar;
        const recojo = l.esPuntoRecojo || l.tipoLugar === 'OFICINA';
        peticion = this.store.guardarLugar({ ...l, nombre: t(l.nombre), ciudad: t(l.ciudad), latitud: num(l.latitud), longitud: num(l.longitud),
          direccion: t(l.direccion), esPuntoRecojo: recojo, minutosAntesRecojo: recojo ? num(l.minutosAntesRecojo) ?? 0 : 0 }, this.editId);
      }
    }
    this.store.ocupado.set(true);
    peticion.subscribe({
      next: () => {
        this.store.ocupado.set(false);
        this.recargar();
        this.abierto.set(false);
        this.alerts.toast('Guardado');
      },
      error: (err) => {
        this.store.ocupado.set(false);
        this.alerts.error(this.store.error(err));
      }
    });
  }

  private recargar() {
    if (this.tab() === 'lugares') { this.store.cargarLugares(); return; }
    if (this.tab() === 'habitaciones') { this.store.cargarHabitaciones(); return; }
    if (this.tab() === 'personal') { this.store.cargarPersonal(); this.store.cargarVehiculos(); }
    if (this.tab() === 'vehiculos') this.store.cargarVehiculos();
    this.store.cargarProveedores();
  }

  async eliminar(id: number) {
    const tab = this.tab();
    const texto = tab === 'lugares' ? 'Esta acción no se puede deshacer.' : 'Quedará INACTIVO: no se borra para conservar su historial.';
    if (!(await this.alerts.confirm(texto, (tab === 'lugares' ? 'Eliminar ' : 'Dar de baja ') + this.actual.singular))) return;
    const peticiones: { [t in Tab]: () => Observable<void> } = {
      proveedores: () => this.store.eliminarProveedor(id),
      personal: () => this.store.eliminarPersonal(id),
      vehiculos: () => this.store.eliminarVehiculo(id),
      habitaciones: () => this.store.eliminarHabitacion(id),
      lugares: () => this.store.eliminarLugar(id)
    };
    peticiones[tab]().subscribe({
      next: () => { this.recargar(); this.alerts.toast(tab === 'lugares' ? 'Eliminado' : 'Dado de baja'); },
      error: (err) => this.alerts.error(this.store.error(err))
    });
  }

  async cambiarEstado(id: number) {
    const p = this.store.getPersonal(id);
    if (!p) return;
    const activar = p.estado === 'INACTIVO';
    const texto = activar
      ? `${p.nombreCompleto} volverá a estar disponible${p.usuario ? ' y podrá iniciar sesión (' + p.usuario + ')' : ''}.`
      : `${p.nombreCompleto} quedará inactivo${p.usuario ? ' y su cuenta (' + p.usuario + ') no podrá iniciar sesión' : ''}. Sus registros se conservan.`;
    if (!(await this.alerts.confirm(texto, activar ? 'Activar personal' : 'Desactivar personal', activar ? 'Sí, activar' : 'Sí, desactivar'))) return;
    this.store.cambiarEstadoPersonal(id, activar).subscribe({
      next: () => { this.store.cargarPersonal(); this.alerts.toast(activar ? 'Personal activado' : 'Personal desactivado'); },
      error: (err) => this.alerts.error(this.store.error(err))
    });
  }

  filtrar(evento: Event, tipo: string) { filtrarEscritura(evento, tipo); }
  pegar(evento: Event, tipo: string) { filtrarPegado(evento, tipo); }
  rueda(evento: Event) { sinRueda(evento); }
}
