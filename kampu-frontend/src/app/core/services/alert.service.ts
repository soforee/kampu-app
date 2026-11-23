import { Injectable } from '@angular/core';
import Swal from 'sweetalert2';

const BRAND = '#4B5B1D';
const DANGER = '#B4533F';
const CANCEL = '#FFFFFF';

@Injectable({ providedIn: 'root' })
export class AlertService {
  success(message: string, title: string = '¡Listo!') {
    Swal.fire({ title, text: message, icon: 'success', confirmButtonColor: BRAND });
  }

  error(message: string, title: string = 'No se pudo completar') {
    Swal.fire({ title, text: message, icon: 'error', confirmButtonColor: DANGER });
  }

  async confirm(message: string, title: string = '¿Estás seguro?', confirmText: string = 'Sí, continuar'): Promise<boolean> {
    const result = await Swal.fire({
      title, text: message, icon: 'warning', showCancelButton: true,
      confirmButtonColor: BRAND, cancelButtonColor: CANCEL, reverseButtons: true,
      confirmButtonText: confirmText, cancelButtonText: 'Cancelar'
    });
    return result.isConfirmed;
  }

  async select(title: string, text: string, options: string[]): Promise<string | null> {
    const inputOptions: { [opcion: string]: string } = {};
    options.forEach(o => (inputOptions[o] = o));
    const result = await Swal.fire({
      title, text, input: 'select', inputOptions, inputPlaceholder: 'Selecciona una opción',
      showCancelButton: true, confirmButtonColor: DANGER, cancelButtonColor: CANCEL, reverseButtons: true,
      confirmButtonText: 'Anular reserva', cancelButtonText: 'Volver',
      inputValidator: v => (v ? null : 'Elige una opción')
    });
    return result.isConfirmed ? (result.value as string) : null;
  }

  async texto(title: string, text: string, placeholder: string, confirmText: string, peligro = false): Promise<string | null> {
    const result = await Swal.fire({
      title, text, input: 'textarea', inputPlaceholder: placeholder, inputAttributes: { maxlength: '300' },
      showCancelButton: true, confirmButtonColor: peligro ? DANGER : BRAND, cancelButtonColor: CANCEL, reverseButtons: true,
      confirmButtonText: confirmText, cancelButtonText: 'Volver',
      inputValidator: v => (v && v.trim() ? null : 'Este dato es obligatorio')
    });
    return result.isConfirmed ? (result.value as string).trim() : null;
  }

  async anulacion(title: string, text: string, formas: [string, string][] | null, confirmText: string):
    Promise<{ motivo: string; formaReembolso: string | null } | null> {
    const opciones = formas ? formas.map(([c, t]) => `<option value="${c}">${t}</option>`).join('') : '';
    const result = await Swal.fire({
      title, icon: 'warning',
      html: `<p style="margin:0 0 10px">${text}</p>`
        + `<textarea id="swal-motivo" class="swal2-textarea" maxlength="300" placeholder="Motivo"></textarea>`
        + (formas ? `<select id="swal-forma" class="swal2-select"><option value="">Forma de reembolso</option>${opciones}</select>` : ''),
      showCancelButton: true, confirmButtonColor: DANGER, cancelButtonColor: CANCEL, reverseButtons: true,
      confirmButtonText: confirmText, cancelButtonText: 'Volver',
      preConfirm: () => {
        const motivo = (document.getElementById('swal-motivo') as HTMLTextAreaElement).value.trim();
        const forma = formas ? (document.getElementById('swal-forma') as HTMLSelectElement).value : '';
        if (!motivo) { Swal.showValidationMessage('Indica el motivo'); return false; }
        if (formas && !forma) { Swal.showValidationMessage('Elige la forma de reembolso'); return false; }
        return { motivo, formaReembolso: forma || null };
      }
    });
    return result.isConfirmed ? result.value as { motivo: string; formaReembolso: string | null } : null;
  }

  toast(message: string, icon: 'success' | 'error' | 'info' = 'success') {
    Swal.mixin({ toast: true, position: 'top-end', showConfirmButton: false, timer: 2500, timerProgressBar: true })
      .fire({ icon, title: message });
  }
}
