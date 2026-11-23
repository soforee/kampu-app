import { AfterViewInit, Directive, ElementRef, Input, OnDestroy, inject } from '@angular/core';

@Directive({ selector: '[appRevelar]', standalone: true })
export class RevelarDirective implements AfterViewInit, OnDestroy {
  @Input() retraso = 0;
  private el = inject(ElementRef<HTMLElement>);
  private observador?: IntersectionObserver;

  ngAfterViewInit() {
    const nodo = this.el.nativeElement as HTMLElement;
    const sinMovimiento = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches;
    if (sinMovimiento || typeof IntersectionObserver === 'undefined') return;
    nodo.classList.add('revelar');
    if (this.retraso) nodo.style.transitionDelay = `${this.retraso}ms`;
    this.observador = new IntersectionObserver(entradas => {
      for (const e of entradas) {
        if (e.isIntersecting) {
          nodo.classList.add('revelado');
          this.observador?.disconnect();
        }
      }
    }, { threshold: 0.12, rootMargin: '0px 0px -40px 0px' });
    this.observador.observe(nodo);
  }

  ngOnDestroy() {
    this.observador?.disconnect();
  }
}
