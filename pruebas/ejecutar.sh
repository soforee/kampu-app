#!/usr/bin/env bash
# Ejecuta las pruebas de la API en orden. Requiere el backend arriba y la base recién instalada
# con 01_schema.sql, 02_data.sql y 03_particionamiento_roles.sql (las pruebas crean y modifican datos:
# NUNCA ejecutarlas contra una base con datos reales).
#   KAMPU_API=http://localhost:8082/lp2_gp2/api/v1 ./pruebas/ejecutar.sh
cd "$(dirname "$0")"
estado=0
for p in api.py negativos.py concurrencia.py; do
  echo "== $p"
  python3 "$p" || estado=1
done
echo
if [ $estado -eq 0 ]; then echo "TODAS LAS PRUEBAS CORRECTAS"; else echo "HAY PRUEBAS FALLIDAS (ver arriba)"; fi
echo "Opcional: ejecuta pruebas/cuadre.sql en Oracle; todas sus consultas deben salir vacías."
exit $estado
