import { Component, Input } from '@angular/core';
import { RouterLink } from '@angular/router';
import { IconComponent } from '../../../shared/icon.component';
import { LogoComponent } from '../../../shared/logo.component';
import { Contacto } from '../landing.models';

@Component({
  selector: 'app-landing-footer',
  standalone: true,
  imports: [RouterLink, IconComponent, LogoComponent],
  templateUrl: './landing-footer.component.html',
  styleUrl: './landing-footer.component.css'
})
export class LandingFooterComponent {
  @Input({ required: true }) contacto!: Contacto;

  anio = new Date().getFullYear();

  // Solo las redes configuradas en el backend; WhatsApp usa el teléfono de contacto
  get redes(): { nombre: string; url: string }[] {
    const whatsapp = this.contacto.telefono.replace(/\D/g, '');
    return [
      { nombre: 'Instagram', url: this.contacto.instagram ?? '' },
      { nombre: 'Facebook', url: this.contacto.facebook ?? '' },
      { nombre: 'WhatsApp', url: whatsapp ? 'https://wa.me/' + whatsapp : '' }
    ].filter(r => r.url);
  }

  get telefonoLink(): string {
    return 'tel:' + this.contacto.telefono.replace(/\s/g, '');
  }
}
