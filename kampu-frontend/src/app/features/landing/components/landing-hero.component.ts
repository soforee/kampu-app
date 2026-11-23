import { Component, Input, OnDestroy, OnInit, signal } from '@angular/core';
import { IconComponent } from '../../../shared/icon.component';
import { FOTOS_DESTINOS } from '../landing.models';

@Component({
  selector: 'app-landing-hero',
  standalone: true,
  imports: [IconComponent],
  templateUrl: './landing-hero.component.html',
  styleUrl: './landing-hero.component.css'
})
export class LandingHeroComponent implements OnInit, OnDestroy {
  @Input() totalTours = 0;
  @Input() totalSalidas = 0;

  fotos = FOTOS_DESTINOS.filter(f => ['machu', 'colca', 'titicaca', 'huacachina', 'tambopata'].includes(f.clave));
  indice = signal(0);
  desplazamiento = signal(0);
  private intervalo?: ReturnType<typeof setInterval>;
  private sinMovimiento = window.matchMedia?.('(prefers-reduced-motion: reduce)').matches ?? false;

  ngOnInit() {
    if (!this.sinMovimiento) this.reiniciar();
  }

  ngOnDestroy() {
    clearInterval(this.intervalo);
  }

  ir(i: number) {
    this.indice.set(i);
    if (!this.sinMovimiento) this.reiniciar();
  }

  private reiniciar() {
    clearInterval(this.intervalo);
    this.intervalo = setInterval(() => this.indice.set((this.indice() + 1) % this.fotos.length), 6500);
  }

  alHacerScroll() {
    if (this.sinMovimiento) return;
    const y = window.scrollY;
    if (y < window.innerHeight) this.desplazamiento.set(Math.round(y * 0.25));
  }

  get textoCta(): string {
    if (this.totalTours === 1) return 'Ver 1 tour';
    if (this.totalTours > 1) return `Ver ${this.totalTours} tours`;
    return 'Ver tours';
  }
}
