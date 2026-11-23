import { HttpClient } from '@angular/common/http';
import { computed, inject, Injectable, signal, WritableSignal } from '@angular/core';
import { Observable } from 'rxjs';
import {
  ActividadItinerario, CalendarioDia, Cargo, Cliente, ClienteForm, FormaReembolso, MetodoPago, PuntoRecojo, SolicitudAnulacion, ContactoReserva, EstadoOperacion, EstadoOperacionInfo, EstadoTransaccion, EstimacionDuracion,
  Habitacion, HabitacionForm, HistorialOperacion, Lugar, LugarForm, LugarSugerido, Manifiesto, Moneda, Operacion, OperacionForm, PaqueteForm, PaqueteTour, Pago, PasajeroDraft,
  PasajeroReserva, Permiso, Personal, PersonalForm, Proveedor, ProveedorForm, RecursoCandidato, Reserva, ResumenPaquete, Rol,
  SalidaForm, SalidaProgramada, Sesion, Vehiculo, VehiculoForm
} from '../models';
import { redondear } from '../utils/moneda';
import { API, mensajeError } from '../utils/api';
import { AuthService } from './auth.service';

const LISTAS: { [lista: string]: Permiso | null } = {
  paquetes: null,
  salidas: null,
  proveedores: 'VER_LOGISTICA',
  personal: 'VER_LOGISTICA',
  vehiculos: 'VER_LOGISTICA',
  lugares: 'VER_LOGISTICA',
  habitaciones: 'VER_LOGISTICA',
  operaciones: 'VER_OPERACIONES',
  'operaciones/estados': 'VER_OPERACIONES',
  'resumen-paquetes': 'VER_RESUMEN',
  clientes: 'VER_CLIENTES',
  reservas: 'VER_RESERVAS',
  pasajeros: 'VER_RESERVAS',
  pagos: 'VER_MONTOS',
  'personal/cargos': 'VER_LOGISTICA',
  'solicitudes-anulacion': 'GESTIONAR_RESERVAS'
};

@Injectable({ providedIn: 'root' })
export class TourStore {
  private http = inject(HttpClient);
  private auth = inject(AuthService);

  paquetes = signal<PaqueteTour[]>([]);
  proveedores = signal<Proveedor[]>([]);
  personal = signal<Personal[]>([]);
  vehiculos = signal<Vehiculo[]>([]);
  lugares = signal<Lugar[]>([]);
  habitaciones = signal<Habitacion[]>([]);
  operaciones = signal<Operacion[]>([]);
  estadosOperacion = signal<EstadoOperacionInfo[]>([]);
  clientes = signal<Cliente[]>([]);
  salidas = signal<SalidaProgramada[]>([]);
  reservas = signal<Reserva[]>([]);
  pasajeros = signal<PasajeroReserva[]>([]);
  pagos = signal<Pago[]>([]);
  resumen = signal<ResumenPaquete[]>([]);
  cargos = signal<Cargo[]>([]);
  solicitudes = signal<SolicitudAnulacion[]>([]);

  guias = computed(() => this.personal().filter(p => p.funcion === 'GUIADO'));
  conductores = computed(() => this.personal().filter(p => p.funcion === 'TRANSPORTE'));

  ocupado = signal(false);
  resaltado = signal<string | null>(null);
  private temporizador?: ReturnType<typeof setTimeout>;
  resaltar(clave: string) {
    this.resaltado.set(clave);
    clearTimeout(this.temporizador);
    this.temporizador = setTimeout(() => this.resaltado.set(null), 3500);
  }
  cargado = signal(false);

  private cargando = false;
  private pendientes = 0;
  private errorCarga = '';
  private avisos: ((error: string) => void)[] = [];

  error(e: unknown): string {
    return mensajeError(e);
  }

  puede(lista: string): boolean {
    if (!(lista in LISTAS)) return false;
    const permiso = LISTAS[lista];
    return this.auth.autenticado() && (permiso === null || this.auth.puede(permiso));
  }

  cargar(forzar = false, alTerminar?: (error: string) => void) {
    if (alTerminar) this.avisos.push(alTerminar);
    if (this.cargado() && !forzar) {
      this.avisar();
      return;
    }
    if (this.cargando) return;
    const tareas: [string, WritableSignal<any[]>][] = [
      ['paquetes', this.paquetes], ['salidas', this.salidas],
      ['proveedores', this.proveedores], ['personal', this.personal], ['vehiculos', this.vehiculos],
      ['lugares', this.lugares], ['habitaciones', this.habitaciones], ['operaciones', this.operaciones], ['operaciones/estados', this.estadosOperacion],
      ['resumen-paquetes', this.resumen], ['clientes', this.clientes], ['reservas', this.reservas],
      ['pasajeros', this.pasajeros], ['pagos', this.pagos],
      ['personal/cargos', this.cargos], ['solicitudes-anulacion', this.solicitudes]
    ];
    const permitidas = tareas.filter(([url]) => this.puede(url));
    this.cargando = true;
    this.errorCarga = '';
    this.pendientes = permitidas.length;
    if (this.pendientes === 0) { this.terminoTabla(); return; }
    for (const [url, destino] of permitidas) this.cargarLista(url, destino, true);
  }

  private terminoTabla(e?: unknown, lista?: string) {
    if (e !== undefined && !this.errorCarga) this.errorCarga = (lista ? `No se cargó "${lista}": ` : '') + this.error(e);
    this.pendientes--;
    if (this.pendientes > 0) return;
    this.cargando = false;
    this.cargado.set(this.errorCarga === '');
    this.avisar();
  }

  private avisar() {
    const lista = this.avisos;
    this.avisos = [];
    for (const aviso of lista) aviso(this.errorCarga);
  }

  limpiar() {
    this.cargado.set(false);
    this.cargando = false;
    for (const s of [this.paquetes, this.proveedores, this.personal, this.vehiculos, this.lugares, this.habitaciones,
      this.operaciones, this.estadosOperacion, this.clientes, this.salidas, this.reservas, this.pasajeros, this.pagos,
      this.resumen, this.cargos, this.solicitudes] as WritableSignal<unknown[]>[]) {
      s.set([]);
    }
  }

  private cargarLista<T>(url: string, destino: WritableSignal<T[]>, contar: boolean) {
    if (!this.puede(url)) { if (contar) this.terminoTabla(); return; }
    this.http.get<T[]>(`${API}/${url}`).subscribe({
      next: data => { destino.set(data); if (contar) this.terminoTabla(); },
      error: e => { if (contar) this.terminoTabla(e, url); else this.error(e); }
    });
  }
  cargarPaquetes() { this.cargarLista('paquetes', this.paquetes, false); }
  cargarProveedores() { this.cargarLista('proveedores', this.proveedores, false); }
  cargarPersonal() { this.cargarLista('personal', this.personal, false); }
  cargarCargos() { this.cargarLista('personal/cargos', this.cargos, false); }
  cargarVehiculos() { this.cargarLista('vehiculos', this.vehiculos, false); }
  cargarLugares() { this.cargarLista('lugares', this.lugares, false); }
  cargarHabitaciones() { this.cargarLista('habitaciones', this.habitaciones, false); }
  cargarOperaciones() { this.cargarLista('operaciones', this.operaciones, false); }
  cargarResumen() { this.cargarLista('resumen-paquetes', this.resumen, false); }
  cargarClientes() { this.cargarLista('clientes', this.clientes, false); }
  cargarSalidas() { this.cargarLista('salidas', this.salidas, false); this.cargarResumen(); }
  cargarReservas() { this.cargarLista('reservas', this.reservas, false); }
  cargarPagos() { this.cargarLista('pagos', this.pagos, false); }
  cargarPasajeros() { this.cargarLista('pasajeros', this.pasajeros, false); }
  cargarSolicitudes() { this.cargarLista('solicitudes-anulacion', this.solicitudes, false); }

  getPaquete(id?: number | null) { return this.paquetes().find(p => p.paqueteId === id); }
  getGuia(id?: number | null) { return this.personal().find(p => p.personalId === id); }
  getPersonal(id?: number | null) { return this.personal().find(p => p.personalId === id); }
  getProveedor(id?: number | null) { return this.proveedores().find(p => p.proveedorId === id); }
  getLugar(id?: number | null) { return this.lugares().find(l => l.lugarId === id); }
  getVehiculo(id?: number | null) { return this.vehiculos().find(v => v.vehiculoId === id); }
  getEstadoOperacion(codigo?: string | null) { return this.estadosOperacion().find(e => e.codigo === codigo); }
  getCliente(id?: number | null) { return this.clientes().find(c => c.clienteId === id); }
  getSalida(id?: number | null) { return this.salidas().find(s => s.salidaId === id); }
  getReserva(id?: number | null) { return this.reservas().find(r => r.reservaId === id); }
  operacionesDe(salidaId: number) { return this.operaciones().filter(o => o.salidaId === salidaId); }
  nombreProveedor(id?: number | null): string {
    return id == null ? 'Kampu Tours (propio)' : this.getProveedor(id)?.nombreComercial ?? '—';
  }
  getCargo(codigo?: string | null) { return this.cargos().find(c => c.codigo === codigo); }
  nombreCargo(codigo?: string | null): string { return this.getCargo(codigo)?.nombre ?? codigo ?? ''; }

  nombreCliente(r?: Reserva | null): string {
    return r ? this.getCliente(r.clienteId)?.nombreCompleto ?? '' : '';
  }
  pasajerosDe(reservaId: number) { return this.pasajeros().filter(p => p.reservaId === reservaId); }
  pagosDe(reservaId: number) { return this.pagos().filter(p => p.reservaId === reservaId); }
  salidasDe(paqueteId: number) { return this.salidas().filter(s => s.paqueteId === paqueteId); }

  codigoReserva(id: number) {
    return this.getReserva(id)?.codigoReserva ?? 'R-' + String(id).padStart(4, '0');
  }
  saldo(r: Reserva): number {
    return r.estadoReserva === 'ANULADA' ? 0 : Math.max(redondear(r.montoTotal - r.montoPagado), 0);
  }

  private guardarEn<T>(url: string, d: unknown, id: number | null): Observable<T> {
    return id ? this.http.put<T>(`${API}/${url}/${id}`, d) : this.http.post<T>(`${API}/${url}`, d);
  }

  guardarPaquete(d: PaqueteForm, id: number | null) { return this.guardarEn<PaqueteTour>('paquetes', d, id); }
  eliminarPaquete(id: number) { return this.http.delete<void>(`${API}/paquetes/${id}`); }

  guardarProveedor(d: ProveedorForm, id: number | null) { return this.guardarEn<Proveedor>('proveedores', d, id); }
  eliminarProveedor(id: number) { return this.http.delete<void>(`${API}/proveedores/${id}`); }
  guardarPersonal(d: PersonalForm, id: number | null) { return this.guardarEn<Personal>('personal', d, id); }
  eliminarPersonal(id: number) { return this.http.delete<void>(`${API}/personal/${id}`); }
  cambiarEstadoPersonal(id: number, activo: boolean) { return this.http.patch<Personal>(`${API}/personal/${id}/estado`, { activo }); }
  guardarVehiculo(d: VehiculoForm, id: number | null) { return this.guardarEn<Vehiculo>('vehiculos', d, id); }
  eliminarVehiculo(id: number) { return this.http.delete<void>(`${API}/vehiculos/${id}`); }
  guardarLugar(d: LugarForm, id: number | null) { return this.guardarEn<Lugar>('lugares', d, id); }
  eliminarLugar(id: number) { return this.http.delete<void>(`${API}/lugares/${id}`); }
  buscarLugares(texto: string) { return this.http.get<LugarSugerido[]>(`${API}/lugares/buscar`, { params: { q: texto } }); }
  guardarHabitacion(d: HabitacionForm, id: number | null) { return this.guardarEn<Habitacion>('habitaciones', d, id); }
  eliminarHabitacion(id: number) { return this.http.delete<void>(`${API}/habitaciones/${id}`); }

  guardarOperacion(d: OperacionForm, id: number | null) { return this.guardarEn<Operacion>('operaciones', d, id); }
  cambiarEstadoOperacion(id: number, estado: EstadoOperacion, observacion: string): Observable<Operacion> {
    return this.http.patch<Operacion>(`${API}/operaciones/${id}/estado`, { estado: estado, observacion: observacion });
  }
  asignarAutomatico(id: number): Observable<Operacion> {
    return this.http.post<Operacion>(`${API}/operaciones/${id}/asignar-automatico`, {});
  }
  asignarRecursos(id: number, vehiculoId: number, conductorId: number): Observable<Operacion> {
    return this.http.patch<Operacion>(`${API}/operaciones/${id}/asignar`, { vehiculoId: vehiculoId, conductorId: conductorId });
  }
  candidatos(id: number): Observable<RecursoCandidato[]> {
    return this.http.get<RecursoCandidato[]>(`${API}/operaciones/${id}/candidatos`);
  }
  historialOperacion(id: number): Observable<HistorialOperacion[]> {
    return this.http.get<HistorialOperacion[]>(`${API}/operaciones/${id}/historial`);
  }
  estimarDuracion(origenId: number, destinoId: number): Observable<EstimacionDuracion> {
    return this.http.get<EstimacionDuracion>(`${API}/operaciones/estimar-duracion`,
      { params: { origenId: origenId, destinoId: destinoId } });
  }

  buscarClientes(texto: string): Observable<Cliente[]> {
    return this.http.get<Cliente[]>(`${API}/clientes/buscar`, { params: { q: texto } });
  }
  guardarCliente(d: ClienteForm, id: number | null) { return this.guardarEn<Cliente>('clientes', d, id); }
  eliminarCliente(id: number) { return this.http.delete<void>(`${API}/clientes/${id}`); }

  guardarSalida(d: SalidaForm, id: number | null) { return this.guardarEn<SalidaProgramada>('salidas', d, id); }
  cancelarSalida(id: number, motivo: string, formaReembolso: FormaReembolso | null): Observable<SalidaProgramada> {
    return this.http.patch<SalidaProgramada>(`${API}/salidas/${id}/cancelar`, { motivo: motivo, formaReembolso: formaReembolso });
  }
  marcarEjecucion(id: number, estado: 'GARANTIZADA' | 'COMPLETADA'): Observable<SalidaProgramada> {
    return this.http.patch<SalidaProgramada>(`${API}/salidas/${id}/ejecucion`, { estado: estado });
  }

  calendario(paqueteId: number, desde: string, dias = 60): Observable<CalendarioDia[]> {
    return this.http.get<CalendarioDia[]>(`${API}/paquetes/${paqueteId}/calendario`, { params: { desde: desde, dias: dias } });
  }
  puntosRecojo(paqueteId: number): Observable<PuntoRecojo[]> {
    return this.http.get<PuntoRecojo[]>(`${API}/paquetes/${paqueteId}/puntos-recojo`);
  }
  paquete(paqueteId: number): Observable<PaqueteTour> {
    return this.http.get<PaqueteTour>(`${API}/paquetes/${paqueteId}`);
  }
  itinerario(paqueteId: number): Observable<ActividadItinerario[]> {
    return this.http.get<ActividadItinerario[]>(`${API}/paquetes/${paqueteId}/itinerario`);
  }
  guardarActividad(paqueteId: number, d: unknown, id: number | null): Observable<ActividadItinerario> {
    return id ? this.http.put<ActividadItinerario>(`${API}/paquetes/${paqueteId}/itinerario/${id}`, d)
      : this.http.post<ActividadItinerario>(`${API}/paquetes/${paqueteId}/itinerario`, d);
  }
  eliminarActividad(paqueteId: number, id: number) {
    return this.http.delete<void>(`${API}/paquetes/${paqueteId}/itinerario/${id}`);
  }

  manifiesto(salidaId: number): Observable<Manifiesto> {
    return this.http.get<Manifiesto>(`${API}/salidas/${salidaId}/manifiesto`);
  }

  crearReserva(datos: {
    clienteId: number | null; contacto: ContactoReserva | null; paqueteId: number; fecha: string; cantidad: number;
    canal: 'PRESENCIAL' | 'TELEFONO' | 'WHATSAPP'; descuento: number; lugarRecojoId: number | null; observaciones: string;
    pasajeros: PasajeroDraft[];
  }): Observable<Reserva> {
    const cuerpo = { ...datos, pasajeros: datos.pasajeros.map(p => this.pasajero(p)) };
    return this.http.post<Reserva>(`${API}/reservas`, cuerpo);
  }
  agregarPasajero(reservaId: number, p: PasajeroDraft): Observable<PasajeroReserva> {
    return this.http.post<PasajeroReserva>(`${API}/reservas/${reservaId}/pasajeros`, this.pasajero(p));
  }
  eliminarPasajero(pasajeroId: number) { return this.http.delete<void>(`${API}/pasajeros/${pasajeroId}`); }
  cambiarRecojo(reservaId: number, lugarRecojoId: number | null): Observable<Reserva> {
    return this.http.patch<Reserva>(`${API}/reservas/${reservaId}/recojo`, { lugarRecojoId: lugarRecojoId });
  }
  private pasajero(p: PasajeroDraft) {
    return {
      nombreCompleto: p.nombreCompleto, tipoDocumento: p.tipoDocumento, numeroDocumento: p.numeroDocumento,
      nacionalidad: p.nacionalidad, fechaNacimiento: p.fechaNacimiento ? p.fechaNacimiento : null
    };
  }

  verBoleta(id: number): Observable<string> {
    return this.http.get(`${API}/reservas/${id}/boleta`, { responseType: 'text' });
  }
  enviarBoleta(id: number): Observable<{ destinatario: string; enviadaEn: string }> {
    return this.http.post<{ destinatario: string; enviadaEn: string }>(`${API}/reservas/${id}/boleta`, {});
  }
  anularReserva(id: number, motivo: string, formaReembolso: FormaReembolso | null): Observable<Reserva> {
    return this.http.patch<Reserva>(`${API}/reservas/${id}/anular`, { motivo: motivo, formaReembolso: formaReembolso });
  }
  atenderSolicitud(id: number, aprobar: boolean, formaReembolso: FormaReembolso | null, respuesta: string): Observable<SolicitudAnulacion> {
    return this.http.patch<SolicitudAnulacion>(`${API}/solicitudes-anulacion/${id}`,
      { aprobar: aprobar, formaReembolso: formaReembolso, respuesta: respuesta });
  }

  registrarPago(reservaId: number, monto: number, moneda: Moneda, metodoPago: MetodoPago,
                codigoTransaccion: string, estadoTransaccion: EstadoTransaccion): Observable<Pago> {
    const cuerpo = {
      reservaId: reservaId, monto: monto, moneda: moneda, metodoPago: metodoPago,
      codigoTransaccion: codigoTransaccion, estadoTransaccion: estadoTransaccion
    };
    return this.http.post<Pago>(`${API}/pagos`, cuerpo);
  }
  resolverPago(pagoId: number, estado: 'APROBADO' | 'RECHAZADO'): Observable<Pago> {
    return this.http.patch<Pago>(`${API}/pagos/${pagoId}/resolver`, { estado: estado });
  }
}
