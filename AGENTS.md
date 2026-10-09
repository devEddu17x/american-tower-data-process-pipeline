# Contexto del Proyecto y Manual de Operación para Agentes

Este documento contiene el contexto completo, las decisiones arquitectónicas, las fuentes de datos, las métricas auditadas, el estado del avance y las directrices obligatorias de estilo para la continuidad del proyecto de **Big Data y Analítica de Datos** (UPAO, Periodo 2026, Ciclo VIII).

---

## 1. Organización y Problema de Negocio

- **Empresa de referencia:** **American Tower del Perú S.A.C.**, subsidiaria local de American Tower Corporation (NYSE: AMT).
- **Modelo de negocio:** Proveedor independiente de infraestructura pasiva compartida de telecomunicaciones. Desarrolla, adquiere y opera torres autosoportadas, monopolos, azoteas y sistemas urbanos DAS, arrendando espacios físicos a empresas operadoras móviles (Claro, Movistar, Entel, Bitel).
- **Problema de negocio:** Riesgo financiero en la asignación de capital de inversión (CAPEX) y lentitud en la prospección territorial. La empresa opera tradicionalmente de forma reactiva (a solicitud expresa de las operadoras o con estudios manuales de campo aislados), lo que genera un punto ciego en distritos sin solicitudes formales.
- **Requerimiento analítico:** Predecir con un trimestre de anticipación la velocidad media de descarga móvil a nivel distrital y estructurar un índice de prioridad territorial que combine el rendimiento proyectado, la concentración poblacional, las barreras biofísicas y la infraestructura existente sobre los **1,890 distritos del Perú**.
- **Destinatarios internos:** Jefaturas de **Desarrollo de Sitios** (evaluación de factibilidad y búsqueda de predios) y **Desarrollo de Negocios** (propuestas comerciales de coubicación a operadoras).

---

## 2. Fuentes de Datos Oficiales (6 Conjuntos Auditados)

1. **Ookla — Speedtest Mobile Network Performance:**
   - Capa móvil (`type=mobile` en `s3://ookla-open-data/parquet/performance/type=mobile/`, región `us-west-2`).
   - 110.5 millones de registros de teselas a nivel global (2019-T1 a 2026-T1).
   - Formato Apache Parquet con geometrías WKT (EPSG:4326).
   - **Regla clave:** Solo se utiliza la capa móvil. La capa fija (`type=fixed`, 180M de registros de Wi-Fi/cable) se descarta por diseño, ya que las torres de American Tower prestan servicio a redes celulares móviles, no a conexiones fijas residenciales.
2. **OSIPTEL — Cobertura de servicio móvil por empresa operadora:**
   - Archivo CSV institucional (`Cobertura móvil por empresa operadora.csv`), 51,366 registros, corte marzo 2023.
   - Declaración de presencia de tecnologías (2G, 3G, 4G, 5G) y cantidad de estaciones base por centro poblado.
   - Registra presencia en **1,664 distritos únicos**.
3. **OSIPTEL — Cantidad de estaciones base por tecnología:**
   - Archivo XLSX institucional, 11,099 registros (2022 a 2026).
4. **INEI — Límites político-administrativos del Perú:**
   - Capa cartográfica oficial (`DISTRITO.gpkg`), EPSG:4326.
   - Totaliza exactamente **1,890 distritos** a nivel nacional.
5. **WorldPop — Population Counts Perú 2020:**
   - Raster GeoTIFF (`per_ppp_2020.tif`) a resolución espacial de 100 metros (~672 MB).
   - 334.3 millones de celdas totales (152.1 millones de celdas con datos válidos).
6. **Copernicus Sentinel-2 — Cloud-Optimized GeoTIFFs (Level-2A):**
   - Catálogo Earth Search en AWS (`s3://e84-earth-search-sentinel-data/`, región `us-west-2`).
   - Bandas B04 (Roja), B08 (NIR), B11 (SWIR) y capa SCL para el cálculo de índices de vegetación (NDVI) y edificación (NDBI).

---

## 3. Línea Base del Negocio (Subsección 1.4 Auditada)

No se admiten supuestos inventados ni valores «0». La línea base se sostiene en tres métricas oficiales auditadas:

| Indicador                                                  | Definición y forma de cálculo                                                                    | Fuente institucional auditable                                                                                                                                                                | Fecha de corte          | Valor inicial (Línea base)                                                                            |
| :--------------------------------------------------------- | :----------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :---------------------- | :---------------------------------------------------------------------------------------------------- |
| **Déficit nacional de Estaciones Base Celular**            | Diferencia entre la demanda requerida nacional y el parque instalado existente.                  | OSIPTEL, Documento de Trabajo N.º 50 (_More & Gavilano, 2020_): [Handle 20.500.12630/746](https://repositorio.osiptel.gob.pe/handle/20.500.12630/746).                                        | Proyección al 2025      | **36,695 estaciones base celular de déficit** (demanda de 60,771 EBC frente a 24,076 EBC instaladas). |
| **Portafolio de infraestructura pasiva de American Tower** | Número total de sitios de comunicaciones operados en Perú respecto al parque total estimado.     | American Tower Corporation, _Annual Report Form 10-K_ ante la SEC de EE.UU. ([Reporte 10-K](https://fortune.com/company-assets/899/quartr/annual-report-10-k-55649-2025-02-25-09-44-18.pdf)). | 31 de diciembre de 2024 | **Más de 4,400 sitios de comunicaciones** (~18.3 % del parque nacional de soportes físicos).          |
| **Punto ciego distrital en infraestructura declarada**     | Proporción de distritos del país sin registros de estaciones base declaradas por las operadoras. | Cruce auditado INEI (`DISTRITO.gpkg`: 1,890 distritos) vs. OSIPTEL (`Cobertura móvil...csv`: 1,664 distritos).                                                                                | Marzo de 2023           | **12.0 % del territorio nacional** (226 distritos de los 1,890 no figuran con presencia declarada).   |

---

## 4. Arquitectura de la Solución (Capítulo 2 - Ruta B en AWS)

- **Región:** AWS `us-east-1`.
- **Topología de red:** VPC `10.0.0.0/16` con subred privada `10.0.0.20/24`. Conectividad hacia S3 resuelta mediante VPC Gateway Endpoint (gratuito).
- **Almacenamiento (Data Lake):** Amazon S3 organizado en prefijos lógicos inmutables según la siguiente convención:

| Prefijo propuesto | Contenido |
| --- | --- |
| `bronze/<fuente>/snapshot_id=<id>/` | Archivos originales y metadatos de la versión incorporada. |
| `silver/<tabla>/version=<id>/` | Datos normalizados por fuente. |
| `gold/<tabla>/version=<id>/` | Tablas integradas y aprobadas para consumo. |
| `quarantine/<fuente>/run_id=<id>/` | Registros rechazados y motivos de rechazo. |
| `artifacts/config/` | Configuraciones y contratos de datos versionados. |
| `artifacts/models/` | Modelos y transformaciones, cuando se desarrolle el punto 4. |
| `evidence/run_id=<id>/` | Manifiestos, calidad, métricas y reportes de ejecución. |
| `benchmarks/escenario=<factor>/` | Entradas y salidas exclusivas de las pruebas de rendimiento. |
| `logs/` | Registros de ejecución y eventos de Spark. |
- **Motor unificado de cómputo:** Amazon EMR sobre EC2 (release `emr-7.10.0`) con **Apache Spark 3.5.5**, **Apache Hadoop/YARN 3.4.1** y **Apache Sedona 1.7.2**.
- **Decisión de diseño para la Ingesta (Nodo 1 del Diagrama):**
  - **Ratificación:** Se utiliza estrictamente **Amazon EMR (Spark)** para la ingesta, manteniendo total fidelidad con el diagrama de arquitectura validado.
  - **Estrategia técnica interna en EMR (Paso 1):**
    - _Fuentes HTTP institucionales (OSIPTEL CSV/XLSX, INEI GPKG, WorldPop GeoTIFF):_ Un paso de comando/Python en el nodo primario de EMR descarga los archivos en streaming hacia S3 Bronze, calcula la suma de comprobación criptográfica SHA-256 en tiempo real y genera el archivo formal `manifest.json`.
    - _Fuentes masivas en AWS Open Data (Ookla y Sentinel-2):_ Una aplicación PySpark distribuida monta los depósitos públicos en `us-west-2` y transfiere selectivamente las particiones trimestrales de estudio hacia S3 Bronze en `us-east-1`, evitando la copia de millones de registros mundiales redundantes.
    - _Aislamiento funcional:_ La ingesta culmina dejando los datos crudos asegurados en la zona Bronze con su marcador de éxito `_SUCCESS`, permitiendo que el paso de procesamiento pesado hacia Silver (Paso 3 con Apache Sedona) opere de forma desacoplada.
- **Catálogo de metadatos:** AWS Glue Data Catalog.
- **Consulta analítica:** Amazon Athena (motor v3) ejecutando consultas serverless sobre tablas Gold.
- **Modelo y estrategia de inferencia:**
  - **Inferencia masiva trimestral:** Se computa estrictamente por lotes (batch) en Apache Spark dentro de EMR al cierre de cada trimestre, persistiendo las predicciones para los 1,890 distritos en la zona Gold.
  - **Amazon SageMaker AI:** Opera como endpoint bajo demanda aprovisionado de forma transitoria para simulaciones interactivas ad-hoc del área de Desarrollo de Negocios (evaluación de escenarios hipotéticos), evitando costos fijos de un servicio 24/7.
  - Empaquetado del contenedor de inferencia en Amazon ECR.
- **Visualización:** Amazon QuickSight consumiendo vistas de Athena.
- **Control financiero y costos:**
  - Presupuesto mensual estimado (AWS Pricing Calculator): **$320.99 USD/mes**.
  - Gasto real acumulado (Semanas 2 a 7): **$18.65 USD** [valor auditable a la fecha de corte].
  - Justificación del bajo costo: Gestión mediante Infraestructura como Código (IaC) y clústeres efímeros de EMR que se crean y destruyen bajo demanda para las pruebas, sin recursos ociosos.

---

## 5. Estructura de Directorios del Repositorio

```text
american-tower-data-process-pipeline/docs/
├── 1/                                          # Capítulo 1: La empresa, el problema y la línea base (COMPLETADO)
│   ├── 1.2/1.2.empresa-contexto.md
│   ├── 1.3/1.3.problema.md
│   ├── 1.4/1.4.linea-base.md
│   ├── 1.5/1.5.objetivos.md
│   ├── 1.6/1.6.alcance-limitaciones.md
│   └── 1.7/1.7.justificacion-big-data.md
├── 2/                                          # Capítulo 2: Arquitectura de la solución (COMPLETADO)
│   ├── 2.1/                                    # 2.1 Arquitectura propuesta y componentes
│   │   ├── arquitectura-propuesta.md
│   │   ├── 2.1.1.fuentes-ingesta.md
│   │   ├── 2.1.2.organizacion-data-lake.md
│   │   ├── 2.1.3.procesamiento-integracion.md
│   │   ├── 2.1.4.analisis-entrenamiento-publicacion-modelo.md
│   │   └── 2.1.5.catalogo-consulta-visualizacion.md
│   ├── 2.2/tabla.md                            # 2.2 Atributos de calidad
│   ├── 2.3/tabla.md                            # 2.3 Prueba de sustitución de componentes
│   └── 2.4/                                    # 2.4 Stack tecnológico y costos
│       ├── 2.4.1.stack-tecnologico.md
│       ├── 2.4.2.tecnologias-descartadas.md
│       ├── 2.4.3.equivalencia-funcional-entre-rutas.md
│       ├── 2.4.4.estimacion-costos-presupuesto.md
│       └── 2.4.5.eficiencia-sostenibilidad.md
├── 3/                                          # Capítulo 3: Implementación del pipeline de datos (EN CURSO)
│   ├── 3.1/                                    # 3.1 Fuentes de datos y ficha de procedencia (COMPLETADO)
│   │   ├── 3.1.1.ookla/dataset.md
│   │   ├── 3.1.2.osiptel-servicio-movil-empresa/dataset.md
│   │   ├── 3.1.3.cantidad-estaciones-base-tecnologia/dataset.md
│   │   ├── 3.1.4.inei/dataset.md
│   │   ├── 3.1.5.world-pop/dataset.md
│   │   └── 3.1.6.sentinel/dataset.md
│   ├── 3.2/                                    # 3.2 Ingesta y organización del Data Lake (ACTUAL)
│   ├── 3.3/                                    # 3.3 Procesamiento y limpieza (PENDIENTE)
│   ├── 3.4/                                    # 3.4 Control de calidad de los datos (PENDIENTE)
│   ├── 3.5/                                    # 3.5 Almacenamiento de datos procesados (PENDIENTE)
│   ├── 3.6/                                    # 3.6 Optimización del rendimiento (PENDIENTE)
│   ├── 3.7/                                    # 3.7 Prueba de escalabilidad (PENDIENTE)
│   └── 3.8/                                    # 3.8 Seguridad de la plataforma (PENDIENTE)
├── fuentes.md                                  # Descripcion breve y links de descarga de datasets
├── guia.md                                     # Rúbrica y estructura académica UPAO
└── AGENTS.md                                   # Este manual de contexto operativo
```

---

## 6. Estado Actual del Proyecto y Próximos Pasos

- **Capítulo 1 y Capítulo 2:** Concluidos íntegramente y auditados.
- **Sección 3.1 (Fuentes de datos y ficha de procedencia):** Concluida. Cada fuente cuenta con ficha institucional, enlaces directos, cantidad de registros, volumen en disco y diccionario de variables auditado.
- **Sección 3.2 (Ingesta y organización del Data Lake):**
  - _Decisión tomada:_ Se ratifica el uso de **Amazon EMR (Spark)** para la ingesta, ejecutado mediante pasos híbridos (scripts Python en nodo primario para descargas web + PySpark para sincronización de Parquet/COG de S3 a S3).
  - _Estructura definida para S3 Bronze:_ Particionamiento jerárquico por fuente y fecha (`bronze/<fuente>/<particion>/`) con manifiesto `manifest.json` (SHA-256, tamaño, fecha UTC, URL de procedencia y motor de ejecución).
  - _Siguiente acción en el nuevo repositorio:_ Redactar el documento final de la sección 3.2 y codificar los scripts/pasos de EMR para la ingesta.

---

## 7. Reglas de Estilo y Trabajo Obligatorias para Cualquier Agente

1. **Listo para copiar y pegar en Word:** Todo texto debe redactarse en tercera persona formal, con tono de consultoría técnica académica, sin comentarios conversacionales dirigidos al usuario dentro de los archivos.
2. **Sin subnumeraciones anidadas:** El encabezado del archivo es el nivel máximo (ej. `## Línea base del negocio` o `### 1.4. Línea base del negocio`). Queda estrictamente prohibido crear niveles como `1.4.1`, `1.4.2`, etc. Las subdivisiones se hacen con subtítulos en negrita (`**Objetivo general**`, `**Fuera del alcance**`, etc.).
3. **Prohibido el formato `Etiqueta: texto` en viñetas:** No escribir listas con el patrón `- Nombre del punto: texto explicativo...`. Las viñetas deben ser oraciones continuas, fluidas, completas y gramaticalmente naturales.
4. **Prohibidas las traducciones bilingües redundantes entre paréntesis:** No escribir términos como «infraestructura compartida (multitenant)» o «nuevos sitios (Build-to-Suit)». Usar directamente la terminología técnica limpia y precisa en español.
5. **No volcar datos pesados al contexto:** NUNCA ejecutar comandos tipo `cat dataset.csv` o usar herramientas de lectura directa sobre archivos grandes. Cualquier análisis de datos debe hacerse mediante scripts temporales de Python (usando la biblioteca estándar `csv`, `sqlite3`, etc.) o comandos de consola que impriman únicamente resúmenes agregados y esquemas para no saturar la ventana de contexto.
6. **Cero supuestos no auditables:** Toda afirmación de negocio, cifra de mercado o métrica cuantitativa debe provenir de documentos oficiales con fuente, autor y fecha comprobable.
7. **Metodología paso a paso:** Trabajar únicamente sobre la sección desbloqueada por el usuario sin adelantarse a capítulos futuros.
