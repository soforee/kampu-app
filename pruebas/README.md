# Pruebas automatizadas de la API

Scripts en Python 3 (solo biblioteca estándar, sin dependencias) que prueban el backend en ejecución. Cada petición
lleva las mismas cabeceras que envía el frontend después del login (`X-Usuario`, `X-Rol`…).

> **Importante:** las pruebas crean, pagan, anulan y asignan registros. Ejecútalas solo sobre una base
> recién instalada con los datos de demostración, **nunca sobre una base con datos reales**.

## Cómo ejecutarlas

1. Reinstala la base: `01_schema.sql`, `02_data.sql` y `03_particionamiento_roles.sql`.
2. Arranca el backend (`cd kampu-backend && ./mvnw spring-boot:run`).
3. Desde la raíz del proyecto:

```bash
./pruebas/ejecutar.sh
```

Si el backend está en otra dirección: `KAMPU_API=http://host:puerto/lp2_gp2/api/v1 ./pruebas/ejecutar.sh`.
El script termina con código 0 solo si todas las pruebas pasan.

4. (Opcional) Ejecuta `pruebas/cuadre.sql` como dueño del esquema: las 4 consultas deben salir vacías
   (cupos frente a vendidos, monto pagado frente a pagos aprobados, reservas anuladas o confirmadas coherentes).

## Qué prueba cada script

| Script | Contenido |
|---|---|
| `api.py` | 157 pruebas: permisos que devuelve el login para cada rol (los usa el frontend para el menú y las pantallas), lecturas permitidas, endpoints públicos, CRUD con casos rechazados, reservas, pagos, boleta, tráfico, portal del cliente, borrados y auditoría. |
| `negativos.py` | 23 casos que deben rechazarse: cupos agotados, fechas pasadas, confirmar sin adelanto, cruces de guía y de vehículo, licencias, proveedores suspendidos, portal sin sesión de cliente, login incorrecto, anular un viaje iniciado e inutilizar un vehículo con traslado asignado. |
| `concurrencia.py` | Peticiones simultáneas: sobreventa de cupos, sobrepago, confirmar contra anular, doble asignación manual y automática de vehículo y conductor, aprobar contra rechazar un pago. |
