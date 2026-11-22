// Textos para los códigos de los CHECK de la base de datos
export const ETIQUETAS: { [codigo: string]: string } = {
  // Proveedores, personal y vehículos
  SUSPENDIDO: 'Suspendido', BLOQUEADO: 'Bloqueado', DISPONIBLE: 'Disponible', OCUPADO: 'Ocupado', INACTIVO: 'Inactivo',
  OPERATIVO: 'Operativo', MANTENIMIENTO: 'En mantenimiento',
  GUIA: 'Guía', CONDUCTOR: 'Conductor', AMBOS: 'Guía y conductor',
  // Lugares
  AEROPUERTO: 'Aeropuerto', TERMINAL: 'Terminal', HOTEL: 'Hotel', ATRACTIVO: 'Atractivo', CIUDAD: 'Ciudad', OFICINA: 'Oficina', OTRO: 'Otro',
  // Salidas (v10) y su origen
  GARANTIZADA: 'Garantizada', SIN_SALIDA: 'Sin salida', MANUAL: 'Manual', RESERVA: 'Por reserva',
  // Canales de venta, métodos de pago y formas de reembolso (v10)
  WEB: 'Web', PRESENCIAL: 'Presencial', TELEFONO: 'Teléfono', WHATSAPP: 'WhatsApp',
  EFECTIVO: 'Efectivo', TRANSFERENCIA: 'Transferencia', DEPOSITO: 'Depósito', YAPE: 'Yape', PLIN: 'Plin', TARJETA: 'Tarjeta',
  PASARELA: 'Pasarela de pago', NOTA_CREDITO: 'Nota de crédito',
  // Funciones de los cargos y solicitudes de anulación
  GUIADO: 'Guiado', TRANSPORTE: 'Transporte', APOYO: 'Apoyo', APROBADA: 'Aprobada', RECHAZADA: 'Rechazada',
  // Tipos de vehículo
  AUTO: 'Auto', CAMIONETA_4X4: 'Camioneta 4x4', VAN: 'Van', MINIBUS: 'Minibús', BUS: 'Bus',
  // Operaciones de transporte (EstadoOperacion del backend)
  PROGRAMADO: 'Programado', ASIGNADO: 'Asignado', EMBARQUE: 'Embarque', EN_RUTA: 'En ruta', FINALIZADO: 'Finalizado', CANCELADO: 'Cancelado',
  // Portal del cliente
  POR_EMPEZAR: 'Por empezar', EN_CURSO: 'En curso', TERMINADO: 'Terminado',
  PAGADO_COMPLETO: 'Pagado completo', FALTA_PAGAR: 'Falta pagar', PENDIENTE_PAGO: 'Pendiente de pago', ANULADO: 'Anulado',
  // Roles
  ADMIN: 'Administrador', VENTAS: 'Ventas', CLIENTE: 'Cliente', INVITADO: 'Visitante',
  // (v11) Cotizaciones y servicios adicionales
  GENERADA: 'Generada', SOLICITADA: 'Solicitud pendiente', RESERVADA: 'Reservada', VENCIDA: 'Vencida',
  POR_PERSONA: 'Por persona', POR_GRUPO: 'Por grupo'
};

export function etiqueta(codigo?: string | null): string {
  if (!codigo) return '';
  return ETIQUETAS[codigo] ?? codigo.charAt(0) + codigo.slice(1).toLowerCase().replace(/_/g, ' ');
}

// Minutos -> "1 h 30 min"
export function duracion(minutos?: number | null): string {
  if (minutos === null || minutos === undefined) return '';
  const h = Math.floor(minutos / 60);
  const m = minutos % 60;
  return h ? (m ? `${h} h ${m} min` : `${h} h`) : `${m} min`;
}

// Ícono de cada tipo de lugar (chk_lug_tipo)
export function iconoLugar(tipo?: string | null): string {
  return ({ AEROPUERTO: 'plane', TERMINAL: 'train', HOTEL: 'bed', ATRACTIVO: 'mountain', CIUDAD: 'building', OFICINA: 'building' } as { [t: string]: string })[tipo ?? ''] ?? 'map-pin';
}

// Listas de los CHECK de kampu_bd.sql
export const METODOS_PAGO = ['EFECTIVO', 'TRANSFERENCIA', 'DEPOSITO', 'YAPE', 'PLIN', 'TARJETA', 'PASARELA'] as const;
export const FORMAS_REEMBOLSO = ['EFECTIVO', 'TRANSFERENCIA', 'YAPE', 'PLIN', 'TARJETA', 'NOTA_CREDITO'] as const;
export const CANALES_VENTA = ['PRESENCIAL', 'TELEFONO', 'WHATSAPP'] as const;
export const DIAS_SEMANA = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'] as const;
