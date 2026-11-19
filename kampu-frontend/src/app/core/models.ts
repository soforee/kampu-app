// v10: PROGRAMADA -> GARANTIZADA (llegó al mínimo de pasajeros) -> COMPLETADA | CANCELADA
export type EstadoSalida = 'PROGRAMADA' | 'GARANTIZADA' | 'COMPLETADA' | 'CANCELADA';
export type EstadoReserva = 'PENDIENTE' | 'CONFIRMADA' | 'ANULADA' | 'COMPLETADA';
export type EstadoPagoReserva = 'PENDIENTE' | 'PARCIAL' | 'PAGADO' | 'REEMBOLSADO';
export type EstadoTransaccion = 'PENDIENTE' | 'APROBADO' | 'RECHAZADO' | 'REEMBOLSADO';
export type TipoDocumento = 'DNI' | 'CE' | 'PASAPORTE';
// Los clientes también pueden ser empresas (RUC); los pasajeros no
export type TipoDocumentoCliente = TipoDocumento | 'RUC';
export type Moneda = 'PEN' | 'USD' | 'EUR';
// chk_usu_rol (personal interno) + CLIENTE (portal web)
export type Rol = 'ADMIN' | 'VENDEDOR' | 'OPERADOR' | 'CLIENTE';
export type EstadoRegistro = 'ACTIVO' | 'INACTIVO';
export type CategoriaLicencia = 'A-I' | 'A-IIa' | 'A-IIb' | 'A-IIIa' | 'A-IIIb' | 'A-IIIc';
export type EstadoProveedor = 'ACTIVO' | 'INACTIVO' | 'SUSPENDIDO';
export type TipoLugar = 'AEROPUERTO' | 'TERMINAL' | 'HOTEL' | 'ATRACTIVO' | 'CIUDAD' | 'OFICINA' | 'OTRO';
export type TipoVehiculo = 'AUTO' | 'CAMIONETA_4X4' | 'VAN' | 'MINIBUS' | 'BUS';
export type EstadoVehiculo = 'OPERATIVO' | 'MANTENIMIENTO' | 'INACTIVO';
// Cargo del personal: catálogo CARGOS (v10). Por defecto GUIA y CONDUCTOR
export type RolPersonal = string;
export type FuncionCargo = 'GUIADO' | 'TRANSPORTE' | 'APOYO';
// chk_pag_metodo (v10)
export type MetodoPago = 'EFECTIVO' | 'TRANSFERENCIA' | 'DEPOSITO' | 'YAPE' | 'PLIN' | 'TARJETA' | 'PASARELA';
// chk_res_reembolso (v10)
export type FormaReembolso = 'EFECTIVO' | 'TRANSFERENCIA' | 'YAPE' | 'PLIN' | 'TARJETA' | 'NOTA_CREDITO';
export type CanalReserva = 'WEB' | 'PRESENCIAL' | 'TELEFONO' | 'WHATSAPP';
export type EstadoPersonal = 'DISPONIBLE' | 'OCUPADO' | 'INACTIVO';
// Estados de tráfico v4 (EstadoOperacion.java)
export type EstadoOperacion = 'PROGRAMADO' | 'ASIGNADO' | 'EMBARQUE' | 'EN_RUTA' | 'FINALIZADO' | 'CANCELADO';
// Portal del cliente (VW_PAQUETES_CLIENTE)
export type EstadoEjecucion = 'POR_EMPEZAR' | 'EN_CURSO' | 'TERMINADO' | 'CANCELADO';
export type EstadoPagoPaquete = 'PAGADO_COMPLETO' | 'FALTA_PAGAR' | 'PENDIENTE_PAGO' | 'ANULADO';

export interface PaqueteTour {
  paqueteId: number;
  nombre: string;
  descripcion: string;
  precioBase: number;
  dias: number;
  noches: number;
  imagen: string;
  // v10: reglas con las que la BD crea la salida al reservar una fecha nueva
  cupoPorDefecto: number;
  minimoPasajeros: number;
  diasOperacion: string;          // L M M J V S D (1 = opera)
  anticipacionMinHoras: number;
  horaInicio: string;             // HH:MM del día 1
  estado: EstadoRegistro;
}

// Día del calendario de un paquete (PKG_RESERVAS.calendario)
export interface CalendarioDia {
  fecha: string;
  opera: boolean;
  salidaId: number | null;
  estadoSalida: 'SIN_SALIDA' | EstadoSalida;
  cuposDisponibles: number;
  faltanParaGarantizar: number;
  reservableWeb: boolean;
}

// Punto de recojo y hora a la que pasa la movilidad
export interface PuntoRecojo {
  lugarId: number;
  nombre: string;
  tipoLugar: TipoLugar;
  ciudad: string;
  direccion: string;
  minutosAntesRecojo: number;
  horaRecojo: string;
  porDefecto: boolean;
}

export interface ActividadItinerario {
  itinerarioId: number;
  paqueteId: number;
  diaNumero: number;
  orden: number;
  lugarId: number | null;
  lugar: string | null;
  titulo: string;
  descripcion: string;
  horaInicio: string | null;
}

export interface Cargo {
  codigo: string;
  nombre: string;
  funcion: FuncionCargo;
  requiereLicencia: boolean;
  estado: EstadoRegistro;
}

// ---------- Proveedores (v10): solo terceros; lo propio de Kampu no tiene proveedor ----------
export interface Proveedor {
  proveedorId: number;
  nombreComercial: string;
  ruc: string;
  telefono: string;
  email: string;
  ofreceTransporte: boolean;
  ofreceGuiado: boolean;
  ofreceHospedaje: boolean;
  ofreceAlimentacion: boolean;
  estado: EstadoProveedor;
  vehiculos: number;
  capacidadOperativa: number;
  conductores: number;
  guias: number;
}

// Personal (v10): cargo del catálogo; proveedorId null = propio de Kampu Tours
export interface Personal {
  personalId: number;
  proveedorId: number | null;
  numeroDocumento: string;
  nombreCompleto: string;
  cargo: RolPersonal;
  funcion: FuncionCargo | null;
  telefono: string;
  numLicencia: string | null;
  catLicencia: CategoriaLicencia | null;
  vencLicencia: string | null;
  estado: EstadoPersonal;
}

export interface Lugar {
  lugarId: number;
  nombre: string;
  tipoLugar: TipoLugar;
  ciudad: string;
  // Coordenadas reales: con ellas se calcula la duración de las rutas
  latitud: number | null;
  longitud: number | null;
  // v10: punto de recojo (la movilidad pasa minutosAntesRecojo antes de la hora de inicio)
  direccion: string;
  esPuntoRecojo: boolean;
  minutosAntesRecojo: number;
}

export interface Vehiculo {
  vehiculoId: number;
  proveedorId: number | null;
  placa: string;
  tipoVehiculo: TipoVehiculo;
  marcaModelo: string;
  capacidadPax: number;
  proxMantenimiento: string | null;
  estado: EstadoVehiculo;
}

// Duración calculada con datos reales: OSRM (OpenStreetMap) o ESTIMADO (coordenadas)
export interface EstimacionDuracion {
  minutos: number | null;
  distanciaKm: number | null;
  fuente: 'OSRM' | 'ESTIMADO' | 'SIN_COORDENADAS';
  detalle: string;
}

// ---------- Tráfico (OPERACIONES_TRANSPORTE) ----------
export interface Operacion {
  operacionId: number;
  codigoOperacion: string;
  salidaId: number | null;
  origenId: number;
  destinoId: number;
  vehiculoId: number | null;
  conductorId: number | null;
  paxProgramados: number;
  horaProgramadaSalida: string;
  horaEstimadaLlegada: string;
  estadoActual: EstadoOperacion;
  observaciones: string;
  origen: string;
  destino: string;
  proveedorId: number | null;
  proveedor: string | null;
  proveedorPropio: boolean;
  placa: string | null;
  conductor: string | null;
  estadoNombre: string;
  ordenEstado: number;
  horaRealSalida: string | null;
  horaRealLlegada: string | null;
  minRetrasoSalida: number | null;
  minRetrasoLlegada: number | null;
}

export interface EstadoOperacionInfo {
  codigo: EstadoOperacion;
  nombre: string;
  orden: number;
  requiereRecursos: boolean;
  ocupaRecursos: boolean;
  esFinal: boolean;
  siguientes: EstadoOperacion[];
}

export interface HistorialOperacion {
  historialId: number;
  operacionId: number;
  estadoAnterior: EstadoOperacion | null;
  estadoNuevo: EstadoOperacion;
  fechaCambio: string;
  usuarioRegistro: string;
  observacion: string;
}

// Vehículo o conductor posible para una operación (motivo = null: elegible)
export interface RecursoCandidato {
  tipoRecurso: 'VEHICULO' | 'CONDUCTOR';
  recursoId: number;
  proveedorId: number | null;
  proveedor: string;
  proveedorPropio: boolean;
  descripcion: string;
  capacidadPax: number | null;
  horasDia: number | null;
  motivo: string | null;
}

export interface Cliente {
  clienteId: number;
  nombreCompleto: string;
  tipoDocumento: TipoDocumentoCliente;
  numeroDocumento: string;
  email: string;
  telefono: string;
  cuentaWeb: boolean;       // ya se registró en el portal
  estadoCuenta: string;
  fechaRegistro: string | null;
  nacionalidad: string;
}

export interface SalidaProgramada {
  salidaId: number;
  paqueteId: number;
  fechaInicio: string;
  fechaFin: string;
  cuposMaximos: number;
  cuposDisponibles: number;
  guiaId?: number | null;
  estado: EstadoSalida;
  // MANUAL (abierta por la agencia) o RESERVA (la creó la BD al reservar una fecha nueva)
  origen: 'MANUAL' | 'RESERVA';
  minimoPasajeros: number | null;
  faltanParaGarantizar: number;
  // Operaciones de transporte vigentes y tramo sin transporte suficiente (null = alcanza)
  operaciones: number;
  faltanteTransporte: string | null;
}

// Reserva (v10): un paquete en una fecha (salida). numeroViajeros = cupos tomados
export interface Reserva {
  reservaId: number;
  codigoReserva: string;
  clienteId: number | null;
  salidaId: number;
  paqueteId: number | null;
  fechaReserva: string;
  numeroViajeros: number;
  pasajerosRegistrados: number;
  precioUnitario: number;
  descuento: number;
  montoTotal: number;
  montoPagado: number;
  saldo: number;
  estadoReserva: EstadoReserva;
  estadoPago: EstadoPagoReserva;
  canal: CanalReserva;
  observaciones: string;
  formaReembolso?: string;
  motivoAnulacion?: string | null;
  fechaAnulacion?: string | null;
  usuarioAnulaId?: number;
  usuarioAnula?: string | null;
  usuarioRegistra?: string | null;
  lugarRecojoId: number | null;
  puntoRecojo: string | null;
  boletaEnviadaEn?: string | null;
  // Solicitud de anulación del portal pendiente (null si no hay)
  solicitudPendienteId: number | null;
}

// Solicitud de anulación del portal (SOLICITUDES_ANULACION)
export interface SolicitudAnulacion {
  solicitudId: number;
  reservaId: number;
  codigoReserva: string;
  clienteId: number | null;
  cliente: string | null;
  paquete: string | null;
  fechaViaje: string | null;
  montoPagado: number;
  motivo: string;
  estado: 'PENDIENTE' | 'APROBADA' | 'RECHAZADA';
  fechaSolicitud: string;
  atendidaPor: string | null;
  fechaAtencion: string | null;
  respuesta: string | null;
}

// Cliente nuevo que se registra al reservar (v4: toda reserva tiene cliente)
export interface ContactoReserva {
  nombre: string;
  tipoDocumento: TipoDocumentoCliente;
  numeroDocumento: string;
  email: string;
  telefono: string;
}

export interface PasajeroReserva {
  pasajeroId: number;
  reservaId: number;
  nombreCompleto: string;
  tipoDocumento: TipoDocumento;
  numeroDocumento: string;
  nacionalidad: string;
  fechaNacimiento: string;
}

export interface Pago {
  pagoId: number;
  reservaId: number;
  monto: number;
  moneda: Moneda;
  tipoCambio: number;
  montoPen: number;
  metodoPago: string;
  codigoTransaccion: string;
  fechaPago: string;
  estadoTransaccion: EstadoTransaccion;
  registradoPor: 'ADMIN' | 'VENDEDOR' | 'CLIENTE';
  usuarioRegistraId: number | null;
  usuarioValidaId: number | null;
  fechaValidacion: string | null;
  observaciones: string;
}

// ---------- Portal del cliente ----------
export interface PortalPaquete {
  reservaId: number;
  codigoReserva: string;
  salidaId: number;
  paqueteId: number;
  paqueteNombre: string;
  imagen: string;
  dias: number;
  noches: number;
  fechaInicio: string;
  fechaFin: string;
  estadoSalida: EstadoSalida;
  salidaGarantizada: boolean;
  pasajeros: number;
  precioUnitario: number;
  descuento: number;
  fechaReserva: string;
  estadoReserva: EstadoReserva;
  estadoEjecucion: EstadoEjecucion;
  estadoPago: EstadoPagoPaquete;
  montoTotal: number;
  montoPagado: number;
  saldo: number;
  montoPorValidar: number;
  puntoRecojo: string | null;
  direccionRecojo: string | null;
  horaRecojo: string | null;
}

export interface PortalPasajero {
  pasajeroId: number;
  nombreCompleto: string;
  tipoDocumento: string;
  numeroDocumento: string;
  nacionalidad: string;
  fechaNacimiento: string | null;
}

export interface PortalDetalle {
  paquete: PortalPaquete;
  descripcion: string;
  guia: string | null;
  pasajeros: PortalPasajero[];
  pagos: Pago[];
  itinerario: ActividadItinerario[];
  solicitud: SolicitudAnulacion | null;
}

// VW_RESUMEN_PAQUETES_POR_ROL (montos nulos para el Operador)
export interface ResumenPaquete {
  salidaId: number;
  paqueteId: number;
  paqueteNombre: string;
  fechaInicio: string;
  fechaFin: string;
  estadoSalida: EstadoSalida;
  origenSalida: 'MANUAL' | 'RESERVA';
  estadoEjecucion: EstadoEjecucion;
  cuposMaximos: number;
  cuposDisponibles: number;
  pasajeros: number;
  minimoPasajeros: number;
  faltanParaGarantizar: number;
  reservasActivas: number;
  operaciones: number;
  guia: string | null;
  montoVendido: number | null;
  montoCobrado: number | null;
}

// Manifiesto de una salida (GET /salidas/{id}/manifiesto). estadoPago y saldo solo llegan con VER_MONTOS.
export interface PasajeroManifiesto {
  pasajeroId: number;
  nombreCompleto: string;
  tipoDocumento: TipoDocumento;
  numeroDocumento: string;
  nacionalidad: string | null;
  edad: number | null;
  reservaId: number;
  estadoReserva: EstadoReserva;
  titular: string | null;
  titularTelefono: string | null;
  observaciones: string | null;
  estadoPago: EstadoPagoReserva | null;
  saldo: number | null;
}

export interface Manifiesto {
  salidaId: number;
  paquete: string;
  fechaInicio: string;
  fechaFin: string;
  estado: EstadoSalida;
  guia: string | null;
  guiaTelefono: string | null;
  cuposMaximos: number;
  pasajerosConfirmados: number;
  pasajerosPendientes: number;
  pasajeros: PasajeroManifiesto[];
}

// Aviso del panel "Requiere atención"
export interface Alerta {
  nivel: 'alta' | 'media';
  icono: string;
  titulo: string;
  detalle: string;
  ruta: (string | number)[];
  consulta?: { [clave: string]: string | number };
}

export interface RegistroForm {
  nombreCompleto: string;
  tipoDocumento: TipoDocumento;
  numeroDocumento: string;
  email: string;
  telefono: string;
  password: string;
  confirmacion: string;
}

export interface PaqueteForm {
  nombre: string;
  descripcion: string;
  precioBase: number;
  dias: number;
  noches: number;
  imagen: string;
  estado: EstadoRegistro;
  cupoPorDefecto: number | null;
  minimoPasajeros: number | null;
  diasOperacion: string;
  anticipacionMinHoras: number | null;
  horaInicio: string;
}


export interface ProveedorForm {
  nombreComercial: string;
  ruc: string;
  telefono: string;
  email: string;
  ofreceTransporte: boolean;
  ofreceGuiado: boolean;
  ofreceHospedaje: boolean;
  ofreceAlimentacion: boolean;
  estado: EstadoProveedor;
}

export interface PersonalForm {
  proveedorId: number | null;       // null = personal propio
  numeroDocumento: string;
  nombreCompleto: string;
  cargo: RolPersonal;
  telefono: string;
  numLicencia: string;
  catLicencia: CategoriaLicencia | '';
  vencLicencia: string;
  estado: EstadoPersonal;
}

export interface LugarForm {
  nombre: string;
  tipoLugar: TipoLugar;
  ciudad: string;
  latitud: number | null;
  longitud: number | null;
  direccion: string;
  esPuntoRecojo: boolean;
  minutosAntesRecojo: number | null;
}

export interface VehiculoForm {
  proveedorId: number | null;
  placa: string;
  tipoVehiculo: TipoVehiculo;
  marcaModelo: string;
  capacidadPax: number | null;
  proxMantenimiento: string;
  estado: EstadoVehiculo;
}

export interface OperacionForm {
  salidaId: number | null;
  origenId: number | null;
  destinoId: number | null;
  vehiculoId: number | null;
  conductorId: number | null;
  paxProgramados: number | null;
  horaProgramadaSalida: string;      // 'YYYY-MM-DDTHH:mm'
  horaEstimadaLlegada: string | null;
  observaciones: string;
}

export interface ClienteForm {
  nombreCompleto: string;
  tipoDocumento: TipoDocumentoCliente;
  numeroDocumento: string;
  email: string;
  telefono: string;
  nacionalidad: string;
}

// La fecha fin y los cupos disponibles los calcula la BD (TRG_SALIDAS_VALIDAR)
export interface SalidaForm {
  paqueteId: number;
  fechaInicio: string;
  cuposMaximos: number;
  guiaId?: number | null;
  estado: EstadoSalida;
}

export interface PasajeroDraft {
  nombreCompleto: string;
  tipoDocumento: TipoDocumento;
  numeroDocumento: string;
  nacionalidad: string;
  fechaNacimiento: string;
}

// Personal interno (usuarioId) o cliente del portal (clienteId), con el rol y sus permisos
export interface Sesion {
  usuarioId: number | null;
  clienteId: number | null;
  username: string;
  nombre: string;
  rol: Rol;
  estado: string;
  // Acciones permitidas por PKG_SEGURIDAD_ROLES (VER_LOGISTICA, GESTIONAR_RESERVAS, ...)
  permisos: Permiso[];
}

export type Permiso =
  | 'VER_USUARIOS' | 'GESTIONAR_USUARIOS' | 'VER_AUDITORIA'
  | 'VER_CLIENTES' | 'GESTIONAR_CLIENTES' | 'VER_RESERVAS' | 'GESTIONAR_RESERVAS' | 'VER_MONTOS' | 'REGISTRAR_PAGO'
  | 'GESTIONAR_CATALOGO' | 'ACTUALIZAR_EJECUCION' | 'VER_RESUMEN'
  | 'VER_LOGISTICA' | 'GESTIONAR_LOGISTICA' | 'VER_OPERACIONES' | 'GESTIONAR_OPERACIONES'
  | 'VER_PAQUETES_PROPIOS' | 'INFORMAR_PAGO';

// ---------- Auditoría (solo ADMIN) ----------
export type AccionAuditoria = 'CREAR' | 'ACTUALIZAR' | 'ELIMINAR' | 'REGISTRO' | 'LOGIN' | 'LOGOUT' | 'LOGIN_FALLIDO';

export interface RegistroAuditoria {
  auditoriaId: number;
  accion: AccionAuditoria;
  entidad: string;
  entidadId: number | null;
  campo: string | null;
  valorAnterior: string | null;
  valorNuevo: string | null;
  detalle: string | null;
  usuario: string;
  rolUsuario: Rol | 'SISTEMA';
  origen: 'BD' | 'APP';
  fecha: string;
}

export interface FiltroAuditoria {
  desde: string;
  hasta: string;
  rol: string;
  accion: string;
  entidad: string;
  usuario: string;
  q: string;
  entidadId?: number | null;
}

export interface Pagina<T> {
  contenido: T[];
  total: number;
  pagina: number;
  tamanio: number;
}
