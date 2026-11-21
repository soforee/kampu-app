import { Injectable, signal } from '@angular/core';

export interface CotizacionLocal {
  codigo: string;
  clave: string;
  paquete: string;
  fecha: string;
  total: number;
  guardada: string;
}

const KEY = 'kampu.cotizaciones';

/**
 * "Guardar temporalmente": las cotizaciones del visitante quedan en ESTE navegador (código + clave) para
 * reabrirlas sin escribir la clave. Viven en el servidor; aquí solo se recuerda cómo entrar. Se pueden olvidar.
 * Sin almacenamiento disponible (modo privado), el visitante usa el código y la clave que anotó.
 */
@Injectable({ providedIn: 'root' })
export class CotizacionesLocales {
  lista = signal<CotizacionLocal[]>(this.leer());

  recordar(c: CotizacionLocal) {
    this.guardar([c, ...this.lista().filter(x => x.codigo !== c.codigo)].slice(0, 20));
  }

  actualizar(codigo: string, cambios: Partial<CotizacionLocal>) {
    if (this.lista().some(x => x.codigo === codigo)) this.guardar(this.lista().map(x => x.codigo === codigo ? { ...x, ...cambios } : x));
  }

  clave(codigo: string): string {
    return this.lista().find(x => x.codigo === codigo.toUpperCase())?.clave ?? '';
  }

  olvidar(codigo: string) {
    this.guardar(this.lista().filter(x => x.codigo !== codigo));
  }

  private guardar(l: CotizacionLocal[]) {
    this.lista.set(l);
    try { localStorage.setItem(KEY, JSON.stringify(l)); } catch { /* sin almacenamiento: queda solo en memoria */ }
  }

  private leer(): CotizacionLocal[] {
    try {
      const l = JSON.parse(localStorage.getItem(KEY) ?? '[]');
      return Array.isArray(l) ? l.filter(x => x && typeof x.codigo === 'string' && typeof x.clave === 'string') : [];
    } catch {
      return [];
    }
  }
}
