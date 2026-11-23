export const ETIQUETAS: { [codigo: string]: string } = {
  SUSPENDIDO: 'Suspendido', BLOQUEADO: 'Bloqueado', DISPONIBLE: 'Disponible', OCUPADO: 'Ocupado', INACTIVO: 'Inactivo',
  OPERATIVO: 'Operativo', MANTENIMIENTO: 'En mantenimiento',
  GUIA: 'Guía', CONDUCTOR: 'Conductor', AMBOS: 'Guía y conductor',
  AEROPUERTO: 'Aeropuerto', TERMINAL: 'Terminal', HOTEL: 'Hotel', ATRACTIVO: 'Atractivo', CIUDAD: 'Ciudad', OFICINA: 'Oficina', OTRO: 'Otro',
  GARANTIZADA: 'Garantizada', SIN_SALIDA: 'Sin salida', MANUAL: 'Manual', RESERVA: 'Por reserva',
  WEB: 'Web', PRESENCIAL: 'Presencial', TELEFONO: 'Teléfono', WHATSAPP: 'WhatsApp',
  EFECTIVO: 'Efectivo', TRANSFERENCIA: 'Transferencia', DEPOSITO: 'Depósito', YAPE: 'Yape', PLIN: 'Plin', TARJETA: 'Tarjeta',
  PASARELA: 'Pasarela de pago', NOTA_CREDITO: 'Nota de crédito',
  GUIADO: 'Guiado', TRANSPORTE: 'Transporte', APOYO: 'Apoyo', APROBADA: 'Aprobada', RECHAZADA: 'Rechazada',
  AUTO: 'Auto', CAMIONETA_4X4: 'Camioneta 4x4', VAN: 'Van', MINIBUS: 'Minibús', BUS: 'Bus',
  PROGRAMADO: 'Programado', ASIGNADO: 'Asignado', EMBARQUE: 'Embarque', EN_RUTA: 'En ruta', FINALIZADO: 'Finalizado', CANCELADO: 'Cancelado',
  POR_EMPEZAR: 'Por empezar', EN_CURSO: 'En curso', TERMINADO: 'Terminado',
  PAGADO_COMPLETO: 'Pagado completo', FALTA_PAGAR: 'Falta pagar', PENDIENTE_PAGO: 'Pendiente de pago', ANULADO: 'Anulado',
  ADMIN: 'Administrador', VENTAS: 'Ventas', CLIENTE: 'Cliente', INVITADO: 'Visitante',
  GENERADA: 'Generada', SOLICITADA: 'Solicitud pendiente', RESERVADA: 'Reservada', VENCIDA: 'Vencida',
  POR_PERSONA: 'Por persona', POR_GRUPO: 'Por grupo',
  TRAFICO: 'Tráfico pesado', RETRASO_VUELO: 'Retraso de vuelo', FALLA_MECANICA: 'Falla mecánica',
  NO_SHOW: 'Pasajero no se presentó', ACCIDENTE: 'Accidente', ABIERTA: 'Abierta', ATENDIDA: 'Atendida'
};

export function etiqueta(codigo?: string | null): string {
  if (!codigo) return '';
  return ETIQUETAS[codigo] ?? codigo.charAt(0) + codigo.slice(1).toLowerCase().replace(/_/g, ' ');
}

export function duracion(minutos?: number | null): string {
  if (minutos === null || minutos === undefined) return '';
  const h = Math.floor(minutos / 60);
  const m = minutos % 60;
  return h ? (m ? `${h} h ${m} min` : `${h} h`) : `${m} min`;
}

export function iconoLugar(tipo?: string | null): string {
  return ({ AEROPUERTO: 'plane', TERMINAL: 'train', HOTEL: 'bed', ATRACTIVO: 'mountain', CIUDAD: 'building', OFICINA: 'building' } as { [t: string]: string })[tipo ?? ''] ?? 'map-pin';
}

export const METODOS_PAGO = ['EFECTIVO', 'TRANSFERENCIA', 'DEPOSITO', 'YAPE', 'PLIN', 'TARJETA', 'PASARELA'] as const;
export const FORMAS_REEMBOLSO = ['EFECTIVO', 'TRANSFERENCIA', 'YAPE', 'PLIN', 'TARJETA', 'NOTA_CREDITO'] as const;
export const CANALES_VENTA = ['PRESENCIAL', 'TELEFONO', 'WHATSAPP'] as const;
export const DIAS_SEMANA = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'] as const;
