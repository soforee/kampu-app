import { Component, Input } from '@angular/core';

@Component({
  selector: 'app-logo',
  standalone: true,
  templateUrl: './logo.component.html'
})
export class LogoComponent {
  @Input() variante: 'isotipo' | 'horizontal' | 'vertical' = 'horizontal';
  @Input() oscuro = false;
  @Input() alto = 32;
  @Input() colorCarpa?: string;

  // Verde oliva de la marca; "oscuro" = versión clara para fondos oscuros o fotos
  get marca() { return this.colorCarpa ?? (this.oscuro ? '#FDF8E6' : '#4A5230'); }
  get texto() { return this.oscuro ? '#FDF8E6' : '#4A5230'; }
}
