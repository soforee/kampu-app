import { AfterViewInit, Component, ElementRef, EventEmitter, Input, OnDestroy, Output, inject, signal } from '@angular/core';
import { IconComponent } from './icon.component';

let siguienteId = 0;
const ENFOCABLES = 'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

@Component({
  selector: 'app-modal',
  standalone: true,
  imports: [IconComponent],
  templateUrl: './modal.component.html'
})
export class ModalComponent implements AfterViewInit, OnDestroy {
  @Input({ required: true }) titulo = '';
  @Input() subtitulo = '';
  @Input() icono = '';
  @Input() ancho: 'sm' | 'md' | 'lg' = 'md';
  @Output() cerrar = new EventEmitter<void>();

  idTitulo = 'modal-titulo-' + (++siguienteId);
  saliendo = signal(false);
  private el = inject(ElementRef<HTMLElement>);
  private previo = document.activeElement as HTMLElement | null;

  ngAfterViewInit() {
    const panel = this.el.nativeElement.querySelector('[data-panel]') as HTMLElement;
    const campos = this.enfocables();
    const primero = campos.find(e => !e.matches('[data-cerrar]')) ?? campos[0];
    setTimeout(() => (primero ?? panel)?.focus({ preventScroll: true }));
  }

  pedirCierre() {
    if (this.saliendo()) return;
    const reducido = typeof matchMedia !== 'undefined' && matchMedia('(prefers-reduced-motion: reduce)').matches;
    if (reducido) { this.cerrar.emit(); return; }
    this.saliendo.set(true);
    setTimeout(() => this.cerrar.emit(), 160);
  }

  ngOnDestroy() {
    this.previo?.focus?.({ preventScroll: true });
  }

  teclado(e: KeyboardEvent) {
    if (e.key === 'Escape') { e.stopPropagation(); this.pedirCierre(); return; }
    if (e.key !== 'Tab') return;
    const campos = this.enfocables();
    if (!campos.length) return;
    const primero = campos[0], ultimo = campos[campos.length - 1];
    if (e.shiftKey && document.activeElement === primero) { e.preventDefault(); ultimo.focus(); }
    else if (!e.shiftKey && document.activeElement === ultimo) { e.preventDefault(); primero.focus(); }
  }

  private enfocables(): HTMLElement[] {
    return Array.from(this.el.nativeElement.querySelectorAll(ENFOCABLES) as NodeListOf<HTMLElement>)
      .filter(e => e.offsetParent !== null);
  }
}
