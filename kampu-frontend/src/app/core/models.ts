export type EstadoSalida = 'PROGRAMADA' | 'GARANTIZADA' | 'COMPLETADA' | 'CANCELADA';
export type EstadoReserva = 'PENDIENTE' | 'CONFIRMADA' | 'ANULADA' | 'COMPLETADA';
export type EstadoPagoReserva = 'PENDIENTE' | 'PARCIAL' | 'PAGADO' | 'REEMBOLSADO';
export type EstadoTransaccion = 'PENDIENTE' | 'APROBADO' | 'RECHAZADO' | 'REEMBOLSADO';
export type TipoDocumento = 'DNI' | 'CE' | 'PASAPORTE';
export type TipoDocumentoCliente = TipoDocumento | 'RUC';
export type Moneda = 'PEN' | 'USD' | 'EUR';
export type Rol = 'ADMIN' | 'VENTAS' | 'GUIA' | 'CONDUCTOR' | 'CLIENTE';
export type EstadoRegistro = 'ACTIVO' | 'INACTIVO';
export type CategoriaLicencia = 'A-I' | 'A-IIa' | 'A-IIb' | 'A-IIIa' | 'A-IIIb' | 'A-IIIc';
export type EstadoProveedor = 'ACTIVO' | 'INACTIVO' | 'SUSPENDIDO';
export type TipoLugar = 'AEROPUERTO' | 'TERMINAL' | 'HOTEL' | 'ATRACTIVO' | 'CIUDAD' | 'OFICINA' | 'OTRO';
export type TipoVehiculo = 'AUTO' | 'CAMIONETA_4X4' | 'VAN' | 'MINIBUS' | 'BUS';
export type EstadoVehiculo = 'OPERATIVO' | 'MANTENIMIENTO' | 'INACTIVO';
export type RolPersonal = string;
export type FuncionCargo = 'GUIADO' | 'TRANSPORTE' | 'APOYO';
export type MetodoPago = 'EFECTIVO' | 'TRANSFERENCIA' | 'DEPOSITO' | 'YAPE' | 'PLIN' | 'TARJETA' | 'PASARELA';
export type FormaReembolso = 'EFECTIVO' | 'TRANSFERENCIA' | 'YAPE' | 'PLIN' | 'TARJETA' | 'NOTA_CREDITO';
export type CanalReserva = 'WEB' | 'PRESENCIAL' | 'TELEFONO' | 'WHATSAPP';
export type EstadoPersonal = 'DISPONIBLE' | 'OCUPADO' | 'INACTIVO';
export type EstadoOperacion = 'PROGRAMADO' | 'ASIGNADO' | 'EMBARQUE' | 'EN_RUTA' | 'FINALIZADO' | 'CANCELADO';
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
  cupoPorDefecto: number;
  minimoPasajeros: number;
  diasOperacion: string;
  anticipacionMinHoras: number;
  horaInicio: string;
  estado: EstadoRegistro;
  serviciosIncluidos: string;
}

export interface CalendarioDia {
  fecha: string;
  opera: boolean;
  salidaId: number | null;
  estadoSalida: 'SIN_SALIDA' | EstadoSalida;
  cuposDisponibles: number;
  faltanParaGarantizar: number;
  reservableWeb: boolean;
}

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

export interface Proveedor {
  proveedorId: number;
  nombreComercial: string;
  ruc: string;
  telefono: string;
  email: string;
  ofreceTransporte: boolean;
  ofreceGuiado: boolean;
  ofreceHospedaje: boolean;
  estado: EstadoProveedor;
  vehiculos: number;
  capacidadOperativa: number;
  conductores: number;
  guias: number;
}

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
  usuario: string | null;
  carneGuia: string | null;
  vencCarne: string | null;
  idiomas: string | null;
}

export interface Lugar {
  lugarId: number;
  nombre: string;
  tipoLugar: TipoLugar;
  ciudad: string;
  latitud: number | null;
  longitud: number | null;
  direccion: string;
  esPuntoRecojo: boolean;
  minutosAntesRecojo: number;
}

export interface LugarSugerido {
  nombre: string; tipoLugar: TipoLugar; ciudad: string; latitud: number; longitud: number; direccion: string; region: string;
}

export type ModalidadPrecio = 'POR_PERSONA' | 'POR_GRUPO';
export interface Habitacion {
  habitacionId: number;
  proveedorId: number;
  proveedor: string;
  nombre: string;
  descripcion: string;
  precioNoche: number;
  modalidadPrecio: ModalidadPrecio;
  imagen: string;
  estado: 'ACTIVO' | 'INACTIVO';
}
export interface HabitacionForm {
  proveedorId: number | null;
  nombre: string;
  descripcion: string;
  precioNoche: number | null;
  modalidadPrecio: ModalidadPrecio;
  imagen: string;
  estado: 'ACTIVO' | 'INACTIVO';
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
  vencSoat: string | null;
  vencRevision: string | null;
}

export interface EstimacionDuracion {
  minutos: number | null;
  distanciaKm: number | null;
  fuente: 'OSRM' | 'ESTIMADO' | 'SIN_COORDENADAS';
  detalle: string;
}

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
  cuentaWeb: boolean;
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
  origen: 'MANUAL' | 'RESERVA';
  minimoPasajeros: number | null;
  faltanParaGarantizar: number;
  operaciones: number;
  faltanteTransporte: string | null;
}

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
  montoAdicionales: number;
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
  solicitudPendienteId: number | null;
}

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
  registradoPor: 'ADMIN' | 'VENTAS' | 'CLIENTE';
  usuarioRegistraId: number | null;
  usuarioValidaId: number | null;
  fechaValidacion: string | null;
  observaciones: string;
}

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
  habitacion: string | null;
  hotel: string | null;
  montoHospedaje: number;
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
  serviciosIncluidos: string;
}

export interface ProveedorForm {
  nombreComercial: string;
  ruc: string;
  telefono: string;
  email: string;
  ofreceTransporte: boolean;
  ofreceGuiado: boolean;
  ofreceHospedaje: boolean;
  estado: EstadoProveedor;
}

export interface PersonalForm {
  proveedorId: number | null;
  numeroDocumento: string;
  nombreCompleto: string;
  cargo: RolPersonal;
  telefono: string;
  numLicencia: string;
  catLicencia: CategoriaLicencia | '';
  vencLicencia: string;
  estado: EstadoPersonal;
  carneGuia: string;
  vencCarne: string;
  idiomas: string;
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
  vencSoat: string;
  vencRevision: string;
}

export interface OperacionForm {
  salidaId: number | null;
  origenId: number | null;
  destinoId: number | null;
  vehiculoId: number | null;
  conductorId: number | null;
  paxProgramados: number | null;
  horaProgramadaSalida: string;
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

export interface Sesion {
  usuarioId: number | null;
  clienteId: number | null;
  username: string;
  nombre: string;
  rol: Rol;
  estado: string;
  permisos: Permiso[];
  token: string;
}

export type Permiso =
  | 'VER_USUARIOS' | 'GESTIONAR_USUARIOS' | 'VER_AUDITORIA'
  | 'VER_CLIENTES' | 'GESTIONAR_CLIENTES' | 'VER_RESERVAS' | 'GESTIONAR_RESERVAS' | 'VER_MONTOS' | 'REGISTRAR_PAGO'
  | 'GESTIONAR_CATALOGO' | 'ACTUALIZAR_EJECUCION' | 'VER_RESUMEN'
  | 'VER_LOGISTICA' | 'GESTIONAR_LOGISTICA' | 'VER_OPERACIONES' | 'GESTIONAR_OPERACIONES'
  | 'VER_PAQUETES_PROPIOS' | 'INFORMAR_PAGO'
  | 'VER_COTIZACIONES' | 'GESTIONAR_COTIZACIONES' | 'VER_ASIGNACIONES_PROPIAS';

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

export type RolInterno = 'ADMIN' | 'VENTAS' | 'GUIA' | 'CONDUCTOR';
export type EstadoUsuario = 'ACTIVO' | 'INACTIVO' | 'BLOQUEADO';

export interface UsuarioSistema {
  usuarioId: number;
  username: string;
  nombreCompleto: string;
  email: string;
  rol: RolInterno;
  estado: EstadoUsuario;
  intentosFallidos: number;
  ultimoAcceso: string | null;
  personalId: number | null;
  personalNombre: string | null;
}

export interface UsuarioForm {
  username: string;
  nombreCompleto: string;
  email: string;
  rol: RolInterno;
  numeroDocumento: string;
  telefono: string;
  numLicencia: string;
  catLicencia: CategoriaLicencia | '';
  vencLicencia: string;
  password: string;
  confirmacion: string;
}

export interface CambioRolForm {
  rol: RolInterno;
  numLicencia: string;
  catLicencia: CategoriaLicencia | '';
  vencLicencia: string;
}

export interface HabitacionElegida {
  habitacionId: number; nombre: string; hotel: string; imagen: string | null;
  modalidad: ModalidadPrecio; precioNoche: number; noches: number; subtotal: number;
}
export interface HabitacionCotizable {
  habitacionId: number; nombre: string; descripcion: string | null; hotel: string;
  imagen: string | null; modalidad: ModalidadPrecio; precioNoche: number;
}
export type EstadoCotizacion = 'GENERADA' | 'SOLICITADA' | 'RESERVADA' | 'RECHAZADA' | 'CANCELADA' | 'VENCIDA';

export interface ServicioAdicional {
  servicioId: number;
  paqueteId: number | null;
  nombre: string;
  descripcion: string;
  precio: number;
  modalidad: 'POR_PERSONA' | 'POR_GRUPO';
  estado: EstadoRegistro;
}

export interface ServicioElegido { servicioId: number; cantidad: number; }

export interface DatosCotizacion {
  paqueteId: number;
  fecha: string;
  adultos: number;
  ninos: number;
  habitacionId: number | null;
  servicios: ServicioElegido[];
  observaciones: string;
}

export interface LineaCotizacion {
  servicioId: number;
  nombre: string;
  modalidad: 'POR_PERSONA' | 'POR_GRUPO';
  cantidad: number;
  precioUnitario: number;
  subtotal: number;
}

export interface CalculoCotizacion {
  paqueteId: number; paquete: string; dias: number; noches: number;
  fechaInicio: string; fechaFin: string; horaInicio: string;
  adultos: number; ninos: number; cantidad: number;
  precioUnitario: number; montoPaquete: number; montoAdicionales: number; total: number;
  cuposDisponibles: number; estadoSalida: 'SIN_SALIDA' | 'PROGRAMADA' | 'GARANTIZADA'; faltanParaGarantizar: number;
  reservableWeb: boolean; anticipacionMinHoras: number;
  montoHospedaje: number; habitacion: HabitacionElegida | null;
  servicios: LineaCotizacion[];
}

export interface EventoCotizacion {
  fecha: string; campo: string; anterior: string | null; nuevo: string | null; detalle: string | null; actor: string;
}

export interface Cotizacion {
  cotizacionId: number | null;
  codigo: string;
  estado: EstadoCotizacion;
  origen: 'INVITADO' | 'CLIENTE';
  paqueteId: number; paquete: string; dias: number; noches: number; imagen: string | null;
  fechaViaje: string; fechaFin: string; horaInicio: string;
  adultos: number; ninos: number; cantidad: number;
  habitacion: HabitacionElegida | null;
  precioUnitario: number; montoPaquete: number; montoAdicionales: number; montoHospedaje: number; total: number;
  servicios: LineaCotizacion[];
  venceEn: string | null; observaciones: string | null;
  nombreContacto: string | null; tipoDocumento: string | null; numeroDocumento: string | null;
  email: string | null; telefono: string | null;
  fechaCreacion: string; fechaSolicitud: string | null; fechaAtencion: string | null;
  atendidaPor: string | null; motivoRechazo: string | null;
  reservaId: number | null; codigoReserva: string | null; estadoReserva: EstadoReserva | null; estadoPago: string | null;
  totalReserva: number | null; montoPagado: number | null;
  historial: EventoCotizacion[];
}

export interface CotizacionCreada { codigo: string; clave: string; cotizacion: Cotizacion; }

export interface SolicitudReserva {
  nombreCompleto: string; tipoDocumento: TipoDocumento; numeroDocumento: string;
  email: string; telefono: string; observaciones: string;
}

export interface MisAsignaciones {
  rol: 'GUIA' | 'CONDUCTOR';
  persona: { personalId: number; nombreCompleto: string; telefono: string | null; cargo: string; proveedor: string | null };
  salidas: {
    salidaId: number; paqueteId: number; paqueteNombre: string; dias: number; noches: number; horaInicio: string;
    fechaInicio: string; fechaFin: string; estado: EstadoSalida; pasajeros: number; traslados: number;
    estadoCampo: EstadoCampo | null; inicioReal: string | null; finReal: string | null; observacionCierre: string | null; atendidos: number;
  }[];
  traslados: TrasladoConductor[];
}

export type EstadoCampo = 'EN_CURSO' | 'EN_ATRACTIVO' | 'FINALIZADA';
export type EstadoAsistencia = 'PRESENTE' | 'NO_SHOW' | 'REZAGO';
export interface PasajeroAsistencia {
  pasajeroId: number; pasajero: string; tipoDocumento: string; numeroDocumento: string; nacionalidad: string | null;
  edadAlViajar: number | null; codigoReserva: string; puntoRecojo: string | null; horaRecojo: string | null;
  titular: string; telefonoTitular: string | null;
}
export interface AsistenciaSalida {
  pasajeros: PasajeroAsistencia[];
  marcas: { pasajeroId: number; dia: number; estado: EstadoAsistencia }[];
}
export interface TransporteSalida {
  operacionId: number; codigoOperacion: string; horaSalida: string; horaLlegada: string; estado: EstadoOperacion; paxProgramados: number;
  origen: string; destino: string; placa: string | null; marcaModelo: string | null; tipoVehiculo: string | null;
  conductor: string | null; conductorTelefono: string | null;
}
export interface TrasladoConductor {
  operacionId: number; codigoOperacion: string; salidaId: number | null; paqueteNombre: string | null;
  horaSalida: string; horaLlegada: string; estado: EstadoOperacion; paxProgramados: number;
  origen: string; origenDireccion: string | null; origenLatitud: number | null; origenLongitud: number | null;
  destino: string; destinoDireccion: string | null; destinoLatitud: number | null; destinoLongitud: number | null;
  vehiculoId: number | null; placa: string | null; tipoVehiculo: string | null; marcaModelo: string | null; capacidadPax: number | null;
  observaciones: string | null; guiaNombre: string | null; guiaTelefono: string | null;
  inicioReal: string | null; finReal: string | null; abordados: number;
}
export interface RecojoCampo {
  horaRecojo: string | null; puntoRecojo: string; direccion: string | null; latitud: number | null; longitud: number | null;
  codigoReserva: string; cantidadPasajeros: number; pasajeros: string | null; titular: string; telefonoTitular: string | null;
}
export interface PasajeroTraslado {
  pasajeroId: number; pasajero: string; tipoDocumento: string; numeroDocumento: string; codigoReserva: string;
  puntoRecojo: string | null; horaRecojo: string | null; abordo: number;
}
export type Combustible = 'LLENO' | '3/4' | '1/2' | '1/4' | 'RESERVA';
export interface JornadaVehiculo {
  fecha: string; kmInicial: number; combustibleInicial: Combustible; kmFinal: number | null; combustibleFinal: Combustible | null;
  observaciones: string | null;
}
export interface MiVehiculo {
  hoy?: boolean;
  vehiculo: {
    vehiculoId: number; placa: string; tipoVehiculo: string; marcaModelo: string | null; capacidadPax: number; estado: string;
    proxMantenimiento: string | null; vencSoat: string | null; vencRevision: string | null; proveedor: string | null;
  } | null;
  jornadas?: JornadaVehiculo[];
}
export type TipoIncidencia = 'TRAFICO' | 'RETRASO_VUELO' | 'FALLA_MECANICA' | 'NO_SHOW' | 'ACCIDENTE' | 'OTRO';
export interface Incidencia {
  incidenciaId: number; tipo: TipoIncidencia; descripcion: string; estado: 'ABIERTA' | 'ATENDIDA'; fechaReporte: string;
  respuesta: string | null; fechaAtencion: string | null; codigoOperacion: string | null;
  reportadoPor?: string; cargo?: string; telefono?: string | null; atendidaPor?: string | null; operacionId?: number | null;
}
export interface Disponibilidad {
  traslados: { operacionId: number; codigoOperacion: string; horaSalida: string; horaLlegada: string; origen: string; destino: string; estado: string; paqueteNombre: string | null }[];
  salidas: { salidaId: number; paqueteNombre: string; fechaInicio: string; fechaFin: string; horaInicio: string; estado: string }[];
  bloqueos: { bloqueoId: number; inicio: string; fin: string; motivo: string | null }[];
}
export interface Notificacion {
  notificacionId: number; tipo: string; titulo: string; detalle: string | null; operacionId: number | null;
  incidenciaId: number | null; fecha: string; leida: boolean;
}
