import { PaqueteTour } from '../../core/models';

export type TipoTour = '' | 'FULL_DAY' | 'ESCAPADA' | 'EXPEDICION';

export interface FiltroBusqueda {
  destino: string;
  fecha: string;
  tipo: TipoTour;
}

export interface TourCard {
  paquete: PaqueteTour;
  gradiente: string;
  duracion: string;
  proximaSalida: string | null;
}

export interface Contacto {
  email: string;
  telefono: string;
  ciudad: string;
  instagram?: string;
  facebook?: string;
}

/**
 * Fotos de destinos de la página principal (public/destinos). Son de Wikimedia Commons con licencia libre;
 * los créditos se muestran en la galería y en docs/ATRIBUCIONES_FOTOS.md.
 * palabras: si un paquete no tiene imagen propia, se usa la foto del destino que aparece en su nombre o descripción.
 */
export interface FotoDestino {
  clave: string;
  lugar: string;
  region: string;
  src: string;
  autor: string;
  licencia: string;
  fuente: string;
  palabras: string[];
}

export const FOTOS_DESTINOS: FotoDestino[] = [
  { clave: 'machu', lugar: 'Machu Picchu', region: 'Cusco', src: 'machu-picchu-panorama.jpg', autor: 'Martin St-Amant', licencia: 'CC BY-SA 3.0',
    fuente: 'https://commons.wikimedia.org/wiki/File:99_-_Machu_Picchu_-_Juin_2009.edit3.jpg', palabras: ['machu', 'cusco', 'valle sagrado'] },
  { clave: 'colca', lugar: 'Cañón del Colca', region: 'Arequipa', src: 'destinos/colca.jpg', autor: 'Thomas Fuhrmann', licencia: 'CC BY-SA 4.0',
    fuente: 'https://commons.wikimedia.org/wiki/File:Peru_-_Colca_Canyon_01.jpg', palabras: ['colca', 'arequipa'] },
  { clave: 'huacachina', lugar: 'Oasis de Huacachina', region: 'Ica', src: 'destinos/huacachina.jpg', autor: 'Diego Delso', licencia: 'CC BY-SA 4.0',
    fuente: 'https://commons.wikimedia.org/wiki/File:Oasis_de_Huacachina,_Ica,_Per%C3%BA,_2015-07-29,_DD_18.JPG', palabras: ['huacachina'] },
  { clave: 'titicaca', lugar: 'Islas de los Uros', region: 'Puno', src: 'destinos/titicaca.jpg', autor: 'Diego Delso', licencia: 'CC BY-SA 4.0',
    fuente: 'https://commons.wikimedia.org/wiki/File:Islas_flotantes_de_los_Uros,_Lago_Titicaca,_Per%C3%BA,_2015-08-01,_DD_17.JPG', palabras: ['titicaca', 'puno', 'uros'] },
  { clave: 'tambopata', lugar: 'Lago Sandoval', region: 'Madre de Dios', src: 'destinos/tambopata.jpg', autor: 'Ozesama', licencia: 'CC BY-SA 4.0',
    fuente: 'https://commons.wikimedia.org/wiki/File:Lago_Sandoval.jpg', palabras: ['tambopata', 'amazon', 'sandoval', 'selva'] },
  { clave: 'paracas', lugar: 'Reserva de Paracas', region: 'Ica', src: 'destinos/paracas.jpg', autor: 'Mojnsen', licencia: 'CC BY-SA 4.0',
    fuente: 'https://commons.wikimedia.org/wiki/File:Paracas_National_Reserve.jpg', palabras: ['paracas', 'ballestas'] },
  { clave: 'lima', lugar: 'Costa de Lima', region: 'Lima', src: 'destinos/lima.jpg', autor: 'Checo890', licencia: 'CC BY-SA 3.0',
    fuente: 'https://commons.wikimedia.org/wiki/File:Coast_of_Lima_Peru.jpg', palabras: ['lima', 'barranco', 'miraflores'] },
  { clave: 'ollantaytambo', lugar: 'Ollantaytambo', region: 'Cusco', src: 'destinos/ollantaytambo.jpg', autor: 'Bernard Gagnon', licencia: 'CC BY-SA 3.0',
    fuente: 'https://commons.wikimedia.org/wiki/File:Ollantaytambo,_Peru.jpg', palabras: ['ollantaytambo'] }
];

/** Foto de referencia de un paquete sin imagen propia: el primer destino mencionado en su nombre o descripción. */
export function fotoDePaquete(nombre: string, descripcion: string): FotoDestino | null {
  // Compara palabras completas (sin tildes): así "ica" no coincide con "gastronómica".
  // Primero se busca en el nombre del paquete y, si no hay coincidencia, en su descripción.
  const palabras = (texto: string) => new Set(texto.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().split(/[^a-z0-9]+/));
  const buscar = (texto: string) => {
    const lista = palabras(texto);
    return FOTOS_DESTINOS.find(f => f.palabras.some(p => p.split(' ').every(x => lista.has(x)))) ?? null;
  };
  return buscar(nombre) ?? buscar(descripcion ?? '');
}
