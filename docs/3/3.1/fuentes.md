1. Ookla — Mobile Network Performance

Es la fuente principal de rendimiento móvil. Ookla distribuye las capas móviles como Parquet y Shapefile, con datos trimestrales desde Q1 2019 hasta Q1 2026.

Ookla Open Data — dataset y documentación oficial

Para descarga, el repositorio proporciona directamente el acceso al bucket S3 ookla-open-data y al patrón de archivos por año/trimestre.

https://registry.opendata.aws/speedtest-global-performance/

Link directo (datos para s3):
Resource type
S3 Bucket
Amazon Resource Name (ARN)
arn:aws:s3:::e84-earth-search-sentinel-data
AWS Region
us-west-2
AWS CLI Access (No AWS account required)
aws s3 ls --no-sign-request s3://e84-earth-search-sentinel-data/

2. OSIPTEL — Cobertura de servicio móvil por empresa operadora

Contiene cobertura y cantidad de estaciones base declaradas por las operadoras a nivel de centros poblados, con información territorial y geolocalización.
https://www.datosabiertos.gob.pe/dataset/cobertura-de-servicio-m%C3%B3vil-por-empresa-operadora

Link directo:
https://www.datosabiertos.gob.pe/sites/default/files/Cobertura%20m%C3%B3vil%20por%20empresa%20operadora.csv

3. OSIPTEL — Cantidad de estaciones base por tecnología

Contiene las estaciones base declaradas por tecnología 2G, 3G, 4G y 5G a nivel de centro poblado.

https://www.datosabiertos.gob.pe/dataset/cantidad-de-estaciones-base-por-tecnolog%C3%ADa-osiptel

Link directo:
https://osiptelgobpe.sharepoint.com/sites/RepositoriodeDatosAbiertosdelOSIPTEL/_layouts/15/download.aspx?UniqueId=46f3863d%2D003e%2D461e%2D9979%2D4a28383fd5a0

4. INEI — Límites administrativos

El portal geoespacial del INEI dispone de capas departamentales, provinciales y distritales actualizadas, además de servicios WMS/WFS y descarga de capas vectoriales.

https://ide.inei.gob.pe
Link directo:

- departamental: https://ide.inei.gob.pe/files/Departamento.rar
- provincial: https://ide.inei.gob.pe/files/Provincia.rar
- distrital: https://ide.inei.gob.pe/files/Distrito.rar

5. WorldPop — Population Counts Perú

Para este proyecto recomiendo utilizar el producto de Perú de 100 metros, porque aporta mucha más densidad espacial que el producto de 1 km. El conjunto está disponible en GeoTIFF y tiene aproximadamente 672,32 MB para Perú.

https://hub.worldpop.org/geodata/summary?id=6416&
Link directo: https://data.worldpop.org/GIS/Population/Global_2000_2020/2020/PER/per_ppp_2020.tif

6. Copernicus Sentinel-2

Detectar obstáculos de señal (Índice de Vegetación / NDVI): Medir áreas con follaje denso o masa arbórea que atenúan y degradan la propagación de frecuencias 4G y 5G.

Identificar expansión urbana (Índice de Construcción / NDBI): Mapear el crecimiento de edificaciones y zonas habitadas para justificar y priorizar la instalación y el arriendo de nuevas torres de telecomunicaciones.
https://registry.opendata.aws/sentinel-2-l2a-cogs/

Link directo (datos para s3):
Resource type
S3 Bucket
Amazon Resource Name (ARN)
arn:aws:s3:::e84-earth-search-sentinel-data
AWS Region
us-west-2
AWS CLI Access (No AWS account required)
aws s3 ls --no-sign-request s3://e84-earth-search-sentinel-data/
