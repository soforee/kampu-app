import { DatePipe, DecimalPipe } from '@angular/common';
import { ActivatedRoute } from '@angular/router';
import { Component, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Observable } from 'rxjs';
import {
  CategoriaLicencia, EstadoPersonal, EstadoProveedor, EstadoVehiculo, HabitacionForm, Lugar, LugarForm, PersonalForm, ProveedorForm,
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
// Sección del menú (data.seccion de la ruta):
//  - personal: personal PROPIO (nace en Usuarios con su cuenta); aquí solo se activa o desactiva.
//  - vehiculos: flota PROPIA (sin proveedor).
//  - proveedores: terceros, con su personal, su flota, las habitaciones de hotel y los lugares.
type Seccion = 'personal' | 'vehiculos' | 'proveedores';

/**
 * Logística dividida en tres secciones que comparten este componente (proveedor_id NULL = propio de la agencia).
 */
import { PageHeaderComponent } from '../../shared/page-header.component';
@Component({
  selector: 'app-recursos',
  standalone: true,
  imports: [PageHeaderComponent, FormsModule, DatePipe, DecimalPipe, IconComponent, BadgeComponent, ModalComponent],
  templateUrl: './recursos.component.html'
})
export class RecursosComponent {
  store = inject(TourStore);
  private alerts = inject(AlertService);
  private auth = inject(AuthService);
  imagenes = inject(ImagenService);
  // Foto de la habitación elegida en el formulario (se sube al guardar)
  foto: File | null = null;
  vistaFoto = signal<string | null>(null);

  private ruta = inject(ActivatedRoute);
  seccion: Seccion = (this.ruta.snapshot.data['seccion'] as Seccion) ?? 'proveedores';
  // Personal y Vehículos muestran solo lo propio; Proveedores, solo lo de terceros
  propio = this.seccion !== 'proveedores';
  encabezado = {
    personal: { titulo: 'Personal', subtitulo: 'Guías y conductores propios de la agencia. Se registran en Usuarios al crear su cuenta.' },
    vehiculos: { titulo: 'Vehículos', subtitulo: 'Flota propia de la agencia.' },
    proveedores: { titulo: 'Proveedores', subtitulo: 'Proveedores externos con sus guías, conductores, vehículos y habitaciones de hotel, y los lugares de la operación.' }
  }[this.seccion];

  // nueva: el botón dice «Nueva …» (femenino)
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
  // Cargos del catálogo CARGOS (v10): store.cargos()
  estadosPersonal: EstadoPersonal[] = ['DISPONIBLE', 'OCUPADO', 'INACTIVO'];
  tiposVehiculo: TipoVehiculo[] = ['AUTO', 'CAMIONETA_4X4', 'VAN', 'MINIBUS', 'BUS'];
  estadosVehiculo: EstadoVehiculo[] = ['OPERATIVO', 'MANTENIMIENTO', 'INACTIVO'];
  tiposLugar: TipoLugar[] = ['AEROPUERTO', 'TERMINAL', 'HOTEL', 'ATRACTIVO', 'CIUDAD', 'OFICINA', 'OTRO'];
  etiqueta = etiqueta;
  iconoLugar = iconoLugar;
  hoy = hoy();
  pronto = addDays(hoy(), 30);

  // ?tab=personal|vehiculos|lugares (sección Proveedores): llega desde los avisos del panel
  tab = signal<Tab>(this.tabInicial());
  private tabInicial(): Tab {
    if (this.seccion !== 'proveedores') return this.seccion;
    const t = this.ruta.snapshot.queryParamMap.get('tab');
    return t === 'personal' || t === 'vehiculos' || t === 'habitaciones' || t === 'lugares' ? t : 'proveedores';
  }
  // null = todos los proveedores · n = un proveedor
  filtroProveedor = signal<number | null>(null);
  // '' = todos · GUIA = función GUIADO · CONDUCTOR = función TRANSPORTE
  filtroRol = signal<'' | 'GUIA' | 'CONDUCTOR'>('');
  abierto = signal(false);
  editId: number | null = null;


  // Al entrar se piden de nuevo: el personal propio se crea desde Usuarios (otra pantalla)
  constructor() {
    this.store.cargarPersonal();
    this.store.cargarVehiculos();
    this.store.cargarProveedores();
    if (this.seccion === 'proveedores') this.store.cargarHabitaciones();
  }

  proveedor: ProveedorForm = this.proveedorVacio();
  persona: PersonalForm = this.personaVacia();
  vehiculo: VehiculoForm = this.vehiculoVacio();
  lugar: LugarForm = this.lugarVacio();
  habitacion: HabitacionForm = this.habitacionVacia();

  // GESTIONAR_LOGISTICA (PKG_SEGURIDAD_ROLES): solo Admin; Ventas solo consulta (VER_LOGISTICA)
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
          // chk_prov_servicio: todo proveedor brinda al menos un soporte
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
          // Personal de proveedores: el proveedor es obligatorio y debe brindar el soporte del cargo (TRG_PERSONAL_VALIDAR)
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
        vMantenimiento: V.fecha(this.vehiculo.proxMantenimiento, 'La fecha del próximo mantenimiento', false)
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

  // ---------- Formularios ----------
  private proveedorVacio(): ProveedorForm {
    return { nombreComercial: '', ruc: '', telefono: '', email: '', ofreceTransporte: true, ofreceGuiado: false,
      ofreceHospedaje: false, estado: 'ACTIVO' };
  }
  // Propio: sin proveedor · Proveedores: el que está filtrado (o ninguno, y se elige en el formulario)
  private proveedorFiltro(): number | null { return this.propio ? null : this.filtroProveedor(); }
  private personaVacia(): PersonalForm {
    return { proveedorId: this.proveedorFiltro(), numeroDocumento: '', nombreCompleto: '', cargo: 'GUIA', telefono: '',
      numLicencia: '', catLicencia: '', vencLicencia: '', estado: 'DISPONIBLE' };
  }
  private vehiculoVacio(): VehiculoForm {
    return { proveedorId: this.proveedorFiltro(), placa: '', tipoVehiculo: 'VAN', marcaModelo: '',
      capacidadPax: 12, proxMantenimiento: addDays(hoy(), 180), estado: 'OPERATIVO' };
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
  // Licencia: la exige el cargo (CARGOS.requiere_licencia)
  get requiereLicencia(): boolean { return !!this.store.getCargo(this.persona.cargo)?.requiereLicencia; }

  private abrir() { this.v.reiniciar(); this.abierto.set(true); }

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
      numLicencia: p.numLicencia ?? '', catLicencia: p.catLicencia ?? '', vencLicencia: p.vencLicencia ?? '', estado: p.estado };
    this.abrir();
  }
  editarVehiculo(id: number) {
    const x = this.store.getVehiculo(id)!;
    this.editId = id;
    this.vehiculo = { proveedorId: x.proveedorId, placa: x.placa, tipoVehiculo: x.tipoVehiculo, marcaModelo: x.marcaModelo,
      capacidadPax: x.capacidadPax, proxMantenimiento: x.proxMantenimiento ?? '', estado: x.estado };
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
          vencLicencia: conduce || lic ? p.vencLicencia : '' }, this.editId);
        break;
      }
      case 'vehiculos': {
        const x = this.vehiculo;
        peticion = this.store.guardarVehiculo({ ...x, proveedorId: this.propio ? null : x.proveedorId,
          placa: t(x.placa).toUpperCase(), marcaModelo: t(x.marcaModelo),
          proxMantenimiento: x.proxMantenimiento || '' }, this.editId);
        break;
      }
      case 'habitaciones': {
        const h = this.habitacion;
        const id = this.editId;
        // La foto se sube primero; luego se guarda la habitación con su ruta
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

  // La flota y el personal cambian los totales de cada proveedor
  private recargar() {
    if (this.tab() === 'lugares') { this.store.cargarLugares(); return; }
    if (this.tab() === 'habitaciones') { this.store.cargarHabitaciones(); return; }
    if (this.tab() === 'personal') { this.store.cargarPersonal(); this.store.cargarVehiculos(); }
    if (this.tab() === 'vehiculos') this.store.cargarVehiculos();
    this.store.cargarProveedores();
  }

  async eliminar(id: number) {
    const tab = this.tab();
    // v10 no otorga DELETE sobre proveedores, personal ni vehículos: la baja los deja INACTIVOS (el historial se conserva)
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

  // Personal propio: activar o desactivar (su cuenta de acceso queda en el mismo estado)
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
