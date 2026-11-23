import { Component, ElementRef, EventEmitter, Input, OnDestroy, Output, ViewChild, inject, signal } from '@angular/core';
import { Cliente } from '../../core/models';
import { TourStore } from '../../core/services/tour-store.service';
import { IconComponent } from '../../shared/icon.component';

interface Trozo { texto: string; marca: boolean; }

@Component({
  selector: 'app-cliente-selector',
  standalone: true,
  imports: [IconComponent],
  templateUrl: './cliente-selector.component.html',
  styleUrl: './cliente-selector.component.css'
})
export class ClienteSelectorComponent implements OnDestroy {
  @Input() seleccionado: Cliente | null = null;
  @Input() invalido = false;
  @Output() seleccionar = new EventEmitter<Cliente | null>();
  @Output() sinRegistro = new EventEmitter<string>();
  @Output() tocado = new EventEmitter<void>();
  @ViewChild('entrada') entrada?: ElementRef<HTMLInputElement>;

  private store = inject(TourStore);
  private temporizador: ReturnType<typeof setTimeout> | null = null;
  private ultimoTexto: string | null = null;
  private numeroBusqueda = 0;

  texto = signal('');
  resultados = signal<Cliente[]>([]);
  abierto = signal(false);
  cargando = signal(false);
  buscado = signal(false);
  activo = signal(-1);
  error = signal('');

  ngOnDestroy() {
    if (this.temporizador) clearTimeout(this.temporizador);
    this.numeroBusqueda++;
  }

  private programarBusqueda(valor: string) {
    if (this.temporizador) clearTimeout(this.temporizador);
    this.temporizador = setTimeout(() => this.buscar(valor.trim()), 300);
  }

  private buscar(t: string) {
    if (t === this.ultimoTexto) return;
    this.ultimoTexto = t;
    this.error.set('');
    if (t.length < 2) {
      this.numeroBusqueda++;
      this.resultados.set([]);
      this.buscado.set(false);
      this.cargando.set(false);
      return;
    }
    this.cargando.set(true);
    const numero = ++this.numeroBusqueda;
    this.store.buscarClientes(t).subscribe({
      next: lista => {
        if (numero !== this.numeroBusqueda) return;
        this.mostrar(lista);
      },
      error: e => {
        if (numero !== this.numeroBusqueda) return;
        this.error.set(this.store.error(e));
        this.mostrar([]);
      }
    });
  }

  private mostrar(lista: Cliente[]) {
    this.cargando.set(false);
    this.buscado.set(true);
    this.resultados.set(lista);
    this.activo.set(lista.length > 0 ? 0 : -1);
  }

  escribir(valor: string) {
    this.texto.set(valor);
    this.abierto.set(true);
    if (valor.trim().length >= 2) this.cargando.set(true);
    this.programarBusqueda(valor);
  }

  teclear(evento: KeyboardEvent) {
    const n = this.resultados().length;
    if (evento.key === 'ArrowDown') {
      evento.preventDefault();
      this.abierto.set(true);
      if (n > 0) this.activo.set((this.activo() + 1) % n);
    } else if (evento.key === 'ArrowUp') {
      evento.preventDefault();
      if (n > 0) this.activo.set((this.activo() - 1 + n) % n);
    } else if (evento.key === 'Enter') {
      if (this.abierto() && this.activo() >= 0 && this.activo() < n) {
        evento.preventDefault();
        this.elegir(this.resultados()[this.activo()]);
      }
    } else if (evento.key === 'Escape') {
      this.abierto.set(false);
    }
  }

  salir() {
    this.abierto.set(false);
    this.tocado.emit();
  }

  elegir(c: Cliente) {
    this.seleccionar.emit(c);
    this.abierto.set(false);
    this.texto.set('');
    this.resultados.set([]);
    this.buscado.set(false);
    this.programarBusqueda('');
  }

  cambiar() {
    this.seleccionar.emit(null);
    setTimeout(() => this.entrada?.nativeElement.focus());
  }

  invitado() {
    this.abierto.set(false);
    this.sinRegistro.emit(this.texto().trim());
  }

  resaltar(valor: string): Trozo[] {
    const q = this.texto().trim();
    if (!valor || q.length < 2) return [{ texto: valor ?? '', marca: false }];
    const i = valor.toLowerCase().indexOf(q.toLowerCase());
    if (i < 0) return [{ texto: valor, marca: false }];
    return [
      { texto: valor.slice(0, i), marca: false },
      { texto: valor.slice(i, i + q.length), marca: true },
      { texto: valor.slice(i + q.length), marca: false }
    ];
  }
}
