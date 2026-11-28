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

## 2. Fuentes de Datos Oficiales (5 Conjuntos Auditados en Bronze, 4 Integrados en Silver/Gold)

1. **Ookla — Speedtest Mobile Network Performance:**
   - Capa móvil (`type=mobile` en `https://ookla-open-data.s3.us-west-2.amazonaws.com/parquet/performance/type=mobile/`).
   - 29 archivos Parquet trimestrales (2019-T1 a 2026-T1, 5.68 GB totales en Bronze).
   - Filtro territorial por `quadkey` de zoom 6 y bounding box del Perú: 555,697 teselas candidatas (100 % válidas en calidad tabular), de las cuales **417,420** se asignan exactamente a los 1,890 polígonos distritales y 138,277 (mar/fronteras) pasan a cuarentena espacial.
   - **Regla clave:** Solo se utiliza la capa móvil (`type=mobile`). La capa fija se descarta por diseño.
2. **OSIPTEL — Cobertura de servicio móvil por empresa operadora:**
   - Archivo CSV institucional (`cobertura_osiptel.csv`, 7.59 MB), **51,366 registros**, período `202303`, fecha de corte `2023-06-13`.
   - Declaración binaria de presencia 4G (`declara_4g`) por centro poblado y empresa operadora; cubre **1,663 distritos** en Gold (dejando 227 distritos sin reporte declarado, ~12.0 % de punto ciego).
3. **OSIPTEL — Cantidad de estaciones base por tecnología:**
   - Archivo XLSX institucional (`osiptel_estaciones.xlsx`, 740 KB).
   - **Estado actual en el pipeline:** Ingestado y verificado con SHA-256 en Bronze (Notebook 01), pero aún no procesado ni integrado en Silver/Gold (reservado como insumo adicional para la Unidad 2).
4. **INEI — Límites político-administrativos del Perú:**
   - Capa cartográfica oficial (`Distrito.rar` con GeoPackage en EPSG:4326, más `Provincia.rar` y `Departamento.rar` en Bronze).
   - Totaliza exactamente **1,890 distritos** con polígonos reparados y superficie calculada en `EPSG:6933` (`superficie_km2`).
5. **WorldPop — Population Counts Perú 2020:**
   - Raster GeoTIFF (`per_ppp_2020.tif`, 705 MB, dimensiones `15214 × 21977`, CRS `EPSG:4326`, NoData `-99999.0`).
   - Agregado zonal real con `rasterio.mask` sobre los **1,890 distritos** sumando **151,864,618 píxeles válidos** (`poblacion_2020`).
- **Nota sobre Copernicus Sentinel-2:** Excluido del pipeline implementado.

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
- **Almacenamiento (Data Lake):** Amazon S3 desacoplado en 5 buckets dedicados para aislar políticas de seguridad, permisos y ciclos de vida:

| Bucket / Ruta | Contenido |
| --- | --- |
| `bronze` (`<fuente>/snapshot_id=<id>/`) | Archivos originales y metadatos de la versión incorporada. |
| `silver` (`<tabla>/version=<id>/`) | Datos normalizados por fuente. |
| `gold` (`<tabla>/version=<id>/`) | Tablas integradas y aprobadas para consumo. |
| `operations` (`quarantine/<fuente>/run_id=<id>/`) | Registros rechazados y motivos de rechazo. |
| `operations` (`evidence/run_id=<id>/`) | Manifiestos, calidad, métricas y reportes de ejecución. |
| `operations` (`benchmarks/escenario=<factor>/`) | Entradas y salidas exclusivas de las pruebas de rendimiento. |
| `artifacts` (`config/`) | Configuraciones y contratos de datos versionados. |
| `artifacts` (`models/`) | Modelos y transformaciones, cuando se desarrolle el punto 4. |
| `artifacts` (`logs/`) | Registros de ejecución y eventos de Spark y EMR. |
| `artifacts` (`scripts/`) | Scripts de bootstrap y dependencias del clúster. |
- **Motor unificado de cómputo y topología escalada:**
  - Amazon EMR sobre EC2 (release `emr-7.1.0`) con **Apache Spark 3.5.0**, **Apache Hadoop/YARN 3.3.6** y **Apache Sedona 1.7.2**.
  - Topología híbrida de **11 nodos totales (44 vCPUs y 176 GB de memoria RAM)** distribuidos para procesamiento masivo distribuido:
    - 1 Nodo maestro (`m5.xlarge`, On-Demand): Coordinación de YARN, ejecución del driver PySpark y servidor de libretas interactivas.
    - 2 Nodos de núcleo (`m5.xlarge`, On-Demand): Almacenamiento distribuido HDFS y soporte de cómputo permanente.
    - 8 Nodos de tareas (`m5.xlarge`, Spot): Cómputo exclusivo sin persistencia HDFS con precio de oferta fijado al 100 % del precio base (\$0.192 USD) para mitigar interrupciones por volatilidad.
  - Cumplimiento estricto de las cuotas de cómputo auditadas en la cuenta: 12 de 16 vCPUs On-Demand consumidas (25 % de margen libre) y 32 de 32 vCPUs Spot consumidas. Habilitación del rol de servicio institucional `AWSServiceRoleForEC2Spot`.
- **Aceleración del arranque y distribución de dependencias:**
  - Almacenamiento del entorno virtual compilado en `s3://<artifacts_bucket>/envs/american-tower-venv.tar.gz` (174 MB), reduciendo el tiempo de inicialización de dependencias de 15 minutos a aproximadamente 3 segundos por nodo.
  - Inclusión del utilitario del sistema `bsdtar` y homologación de bibliotecas geoespaciales (Apache Sedona 1.7.2, GeoPandas 1.0.1, Rasterio 1.3.11, Shapely 2.0.6, PyProj 3.6.1, PyArrow 17.0.0, OpenPyXL 3.1.5 y Boto3).
  - Registro automático del kernel de Jupyter `American Tower - PySpark` en `/home/hadoop/.local/share/jupyter/kernels/american-tower`.
- **Conectividad segura y supervisión de trabajos:**
  - Cumplimiento de la directriz de AWS EMR de bloqueo de acceso público (*Block Public Access*), manteniendo únicamente el puerto 22 abierto hacia el exterior.
  - Automatización de acceso mediante [scripts/connect_emr.sh](file:///home/eddu/dev/american-tower-data-process-pipeline/scripts/connect_emr.sh), obteniendo la llave privada desde AWS Systems Manager Parameter Store (`/american-tower/dev/emr_ssh_key`) e iniciando Visual Studio Code Remote-SSH.
  - Túneles seguros SSH (`LocalForward`) dirigidos hacia el nombre DNS del nodo maestro para evitar rechazos por enlace de red en YARN.
  - Supervisión operativa mediante Spark History Server en el puerto local 18080 (interfaz gráfica completa y oficial de Spark con persistencia de eventos) y YARN ResourceManager en el puerto local 8088.
- **Decisión de diseño para la Ingesta (Nodo 1 del Diagrama):**
  - **Ratificación:** Se utiliza estrictamente **Amazon EMR (Spark)** para la ingesta, manteniendo total fidelidad con el diagrama de arquitectura validado.
  - **Estrategia técnica interna en EMR (Paso 1):**
    - _Fuentes HTTP institucionales (OSIPTEL CSV/XLSX, INEI GPKG, WorldPop GeoTIFF):_ Un paso de comando/Python en el nodo primario de EMR descarga los archivos en streaming hacia S3 Bronze, calcula la suma de comprobación criptográfica SHA-256 en tiempo real y genera el archivo formal `manifest.json`.
    - _Fuentes masivas en AWS Open Data (Ookla y Sentinel-2):_ Una aplicación PySpark distribuida monta los depósitos públicos en `us-west-2` y transfiere selectivamente las particiones trimestrales de estudio hacia S3 Bronze en `us-east-1`, dividiendo el procesamiento entre los 10 nodos trabajadores simultáneos.
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
  - Costo por hora del clúster de 11 nodos: Aproximadamente **$1.35 USD/hora** (frente a un saldo de créditos auditado de ~$95 USD).
  - Justificación del bajo costo: Gestión mediante Infraestructura como Código (IaC) y clústeres efímeros de EMR que se crean y destruyen bajo demanda mediante el interruptor `enable_emr`, sin recursos ociosos.

---

## 5. Estructura Actual del Repositorio

```text
american-tower-data-process-pipeline/
├── docs/
│   ├── images/                                 # Gráficas oficiales del pipeline y arquitectura
│   │   ├── architecture.png
│   │   ├── eda_trimestres.png
│   │   ├── eda_departamentos.png
│   │   ├── eda_distribucion_2024_t4.png
│   │   ├── eda_poblacion_pruebas.png
│   │   ├── eda_osiptel_4g.png
│   │   └── modelo_errores.png
│   ├── guia.md                                 # Rúbrica y estructura académica UPAO
│   └── linea-base.md                           # Línea base del negocio auditada
├── notebooks/                                  # Pipeline ejecutable de 7 libretas en EMR
│   ├── 01_ingesta_bronze.ipynb                 # Ingesta cruda (35 objetos, 6.41 GB, SHA-256)
│   ├── 02_silver_limpieza_y_calidad.ipynb      # Limpieza, cruce espacial, WorldPop y cuarentenas
│   ├── 03_gold_integracion_distrital.ipynb     # Panel distrital (54,810) y contexto (1,890)
│   ├── 04_optimizacion_y_escalabilidad.ipynb   # Broadcast vs. Shuffle y escalabilidad 1x/10x/100x
│   ├── 05_analisis_exploratorio_y_modelo_base.ipynb # EDA (2020-2024) y Modelo Base (Persistencia vs. Regresión)
│   ├── 06_modelo_gbt_regressor.ipynb           # Modelo GBTRegressor (Spark MLlib + Duan), priorización y mapa
│   └── 07_Huber_L2_Interacciones.ipynb         # Modelo de Alba Malca (Spark MLlib), evaluación por etapas y mapa
├── scripts/
│   ├── connect_emr.sh                          # Conexión SSH y túneles a EMR (operador)
│   └── rollback_quarter.sh                     # Rollback de trimestre incremental (operador)
├── terraform/                                  # Infraestructura como Código (VPC, S3, IAM, EMR, Catalog, Lambda, SageMaker)
│   ├── modules/                                # Módulos HCL puros (networking, iam, s3, emr, catalog, lambda, sagemaker)
│   └── services/                               # Código desplegado en servicios AWS (emr, lambda, sagemaker/inference)
├── README.md                                   # Guía de reproducción desde cero
└── AGENTS.md                                   # Este manual de contexto operativo
```

---

## 6. Estado Actual del Proyecto y Resultados Auditados

Las primeras cinco libretas fueron reescritas durante la reingeniería PR #17. Las ejecuciones de los modelos 06 y 07 amplían ese avance sobre Amazon EMR (`emr-7.1.0`, Spark `3.5.0-amzn-1`), con linaje mediante manifiestos `_SUCCESS.json` en `s3://american-tower-dev-operations-1dd72256126674a5893dfca3df/` y resultados conservados en las libretas:

- **Notebook 01 (`01_ingesta_bronze.ipynb`):**
  - Corrida `20261125T071603Z-190d23d89e`: **35 objetos verificados** (6,410,857,344 bytes / 6.41 GB) con SHA-256: 29 parquets Ookla (`2019-T1` a `2026-T1`), 3 cartografías INEI, 2 archivos OSIPTEL y 1 raster WorldPop 2020.
- **Notebook 02 (`02_silver_limpieza_y_calidad.ipynb`):**
  - Corrida `20261125T072542Z-e92a810559`: 555,697 teselas candidatas (100 % válidas en reglas tabulares), **417,420 asignadas** a los 1,890 distritos del INEI mediante `shapely.STRtree` (`covered_by`) y 138,277 enviadas a cuarentena espacial (`fuera_de_poligonos`). WorldPop 2020 agrega **151,864,618 píxeles válidos** sobre los 1,890 distritos. OSIPTEL Cobertura limpia 51,366 registros (`periodo=202303`, `fecha_corte=2023-06-13`). Publica **5 tablas Silver** en Parquet Snappy.
- **Notebook 03 (`03_gold_integracion_distrital.ipynb`):**
  - Corrida `20261125T073334Z-7ea4f607ff`: genera **2 tablas Gold**:
    - `panel_distrital` (particionada por `year`): **54,810 filas** ($1,890 \times 29$ trimestres), velocidad ponderada por `tests`, **41,434** pares observados y **13,376** sin medición (`NULL`).
    - `contexto_territorial`: **1,890 filas**, 100 % con `poblacion_2020` (WorldPop) y **1,663** con cobertura declarada de OSIPTEL (227 sin reporte).
- **Notebook 04 (`04_optimizacion_y_escalabilidad.ipynb`):**
  - Corrida `20261125T073537Z-c20fc75eae`:
    - **Optimización:** `BroadcastHashJoin` (mediana **0.381 s**) vs. `SortMergeJoin` (mediana **0.838 s**) sobre 417,420 filas → **54.48 % de reducción de tiempo** (~2.20×).
    - **Escalabilidad (Bronze → Silver → Gold completo, 8 workers activos, 0 spill):**
      - `1×` (555,697 candidatas): **185.24 s** (1.33 GB leídos).
      - `10×` (5,556,970 candidatas): **236.86 s** (`1.28×` vs. `1×`, 2.37 GB leídos).
      - `100×` (55,569,700 candidatas / 41.74M asignadas): **838.08 s** (`4.52×` vs. `1×`, 9.70 GB leídos, 1.34 GB shuffle, 0 spill).
- **Notebook 05 (`05_analisis_exploratorio_y_modelo_base.ipynb`):**
  - Corrida `20261125T080507Z-f8de12bfa0`:
    - **EDA (`2020-T1` a `2024-T4`, 20 trimestres):** 37,800 filas distrito-trimestre, 29,161 observadas (77.15 %). 6 gráficas generadas y extraídas en `docs/images/`. Mediana nacional subió de **14.08 Mbps** (`2020-T1`) a **30.45 Mbps** (`2024-T4`). Correlación de Spearman población vs. pruebas = **0.706**.
    - **Modelo Base (pares consecutivos $t \rightarrow t+1$):** Train `2020–2022` (13,660 pares), Val `2023` (5,248 pares), Test `2024` (5,666 pares).
      - Validación 2023: Persistencia MAE **13.28 Mbps** ($R^2 = -0.259$) vs. Regresión lineal simple MAE **11.64 Mbps** ($R^2 = 0.028$).
      - Prueba 2024: Persistencia MAE **14.65 Mbps** ($R^2 = -0.480$) vs. Regresión lineal simple MAE **13.03 Mbps** (RMSE **20.22**, $R^2 = -0.083$, sesgo **$-7.68$ Mbps**).
- **Notebook 06 (`06_modelo_gbt_regressor.ipynb`):**
  - Modelo `GBTRegressor` en Spark MLlib (`max_depth=3, max_iter=40, step_size=0.08`) entrenado sobre `objetivo_log_delta` ponderado por `log1p(tests)` con estimador de calibración de Duan integrado en `SQLTransformer`.
  - Evaluación cronológica estricta (`2020–2022` → `2023` val → `2024` test, Duan `1.1448`):
    - Prueba 2024 todos los pares (5,666): MAE **11.94 Mbps**, RMSE **19.17 Mbps**, sesgo **$-2.63$ Mbps**, $R^2 = +0.0275$.
    - Prueba 2024 con suficiencia (`tests >= 10`, 3,990 pares): MAE **9.98 Mbps**, RMSE **14.77 Mbps**, sesgo **$-0.77$ Mbps**, $R^2 = +0.0845$ (Validación 2023: MAE **9.31**, $R^2 = +0.149$).
  - Modelo productivo reentrenado sobre los **35,557 pares** hasta `2026-T1` (Duan `1.1326`), guardado en `s3://<artifacts>/models/gbt_regressor/` y publicado en `s3://<gold>/predicciones_modelos/modelo_gbt_regressor.parquet` (1,564 predicciones para `2026-T2`, delta promedio **+1.99 Mbps** en QuickSight).
  - Estabilidad del índice de preselección territorial: temporal (`2025-T4` vs. `2026-T1`) **72.0 %** overlap Top 50 (Spearman **0.8389**); sensibilidad de pesos ($\pm 10\%$) **86 % – 94 %** overlap Top 50 (Spearman **0.951 – 0.985**).
- **Infraestructura de Consumo, Automatización e Inferencia (Terraform):**
  - `terraform/modules/catalog`: Glue Data Catalog (`american_tower_dev_gold`, tablas `panel_distrital` con Partition Projection, `contexto_territorial`, `predicciones_modelos`), Athena Workgroup v3 y QuickSight (Data Source + Dataset SPICE `Panel Distrital Enriquecido` + Dataset `DIRECT_QUERY` `Inferencias de Modelos`) desplegados y verificados en vivo.
  - `terraform/modules/lambda`: Trigger S3 (`incoming/ookla/*.parquet`) → Lambda → EMR Step (`terraform/services/emr/process_incremental_ookla.py`) + refresh SPICE, y `scripts/rollback_quarter.sh` para revertir trimestres incrementales.
  - `terraform/modules/sagemaker`: ECR + IAM Role + SageMaker Serverless CPU (`3072 MB`, toggle `enable_sagemaker = false`) y contenedor Spark MLlib en `terraform/services/sagemaker/inference/`.
- **Documentación del informe:** Los borradores `.md` antiguos bajo `docs/1/` a `docs/7/` fueron eliminados por el usuario para evitar desfase; queda pendiente reescribirlos cuando el usuario lo indique.

---

**Notebook 07 · Regresión Huber + L2 + interacciones**

La libreta `notebooks/07_Huber_L2_Interacciones.ipynb`, de Alba Malca, conserva la ejecución `20261128T113553Z-c922621085` del 28 de noviembre de 2026. El modelo y las transformaciones de aprendizaje utilizan únicamente Spark MLlib. La etiqueta es el cambio trimestral de velocidad en Mbps; la velocidad futura se reconstruye sumando el cambio a la velocidad actual y limitando el resultado a valores no negativos.

Se utilizan 19 predictores numéricos, codificación departamental y tres interacciones. La imputación y la codificación se ajustan con entrenamiento; `LinearRegression` utiliza `loss="huber"`, `elasticNetParam=0.0`, `solver="l-bfgs"`, estandarización interna y pesos `log1p(tests_t)`. Las ventanas se calculan sobre el calendario completo. OSIPTEL 2023 queda reservado al índice territorial; WorldPop 2020 se trata como contexto fijo retrospectivo.

La evaluación reproduce los pares del notebook 05, con 13,660 en entrenamiento 2020–2022, 5,248 en validación 2023 y 5,666 en prueba 2024, según año objetivo. Se comparan L2, Huber + L2 y Huber + L2 con interacciones mediante 21 configuraciones. La selección del modelo principal utiliza exclusivamente validación y obtiene `regParam=0.01`, `epsilon=1.8` y 35 iteraciones de evaluación.

| Resultado guardado | Pares | MAE (Mbps) | RMSE (Mbps) | Sesgo (Mbps) | R² |
| --- | ---: | ---: | ---: | ---: | ---: |
| Huber con interacciones, validación completa | 5,248 | 11.2486 | 18.6789 | -2.5129 | 0.0690 |
| Huber con interacciones, prueba completa | 5,666 | 12.1837 | 19.9154 | -2.9258 | -0.0501 |
| Huber con interacciones, prueba con suficiencia | 3,990 | 9.7610 | 14.6869 | -2.4549 | 0.0951 |
| Regresión multivariable L2, prueba completa | 5,666 | 12.1516 | 19.6272 | -1.1467 | -0.0200 |

La fuente de estas cifras son las salidas guardadas de búsqueda y evaluación del notebook 07. El modelo principal mejora persistencia y regresión simple, pero no supera a L2 en prueba. Las interacciones aportan una reducción marginal del MAE frente a Huber sin interacciones. No se ha cuantificado la incertidumbre de esas diferencias ni corresponde afirmar superioridad estadística.

El modelo productivo utiliza 35,557 pares y genera 1,564 predicciones para `2026-T2`. Se obtienen 1,019 distritos aptos para el índice, 545 predicciones con índice nulo y 326 distritos sin telemetría. La suficiencia exige diez pruebas y dos teselas; los pesos del índice son 40/35/25. La estabilidad retrospectiva conserva 35 de los 50 distritos, con Spearman 0.7966 entre 866 distritos comunes. Los escenarios de pesos conservan entre el 82 % y el 90 % del Top 50; no representan intervalos de precisión del pronóstico.

Los PipelineModel se guardan por corrida bajo `models/huber_l2_interacciones/run_id=<corrida>/evaluacion` y `productivo` en Artifacts. La publicación Gold utiliza `predicciones_modelos/modelo_huber_l2_interacciones.parquet`; las evidencias se registran en `run_id=<corrida>/modelo_huber_l2_interacciones/` de Operations.

La celda final sigue el patrón de publicación del notebook 06 y solo utiliza S3. Si el archivo local ya generado está disponible y la publicación está habilitada, lo valida y publica; de lo contrario verifica la publicación existente. La ejecución guardada de esa celda confirma 1,564 filas de Alba Malca para `2026-T2` y 545 índices nulos. No llama a `DescribeDataSet` ni a `CreateIngestion`; la llamada anterior a `DescribeDataSet` fue retirada tras el error de autorización del rol EMR. No se modificaron políticas IAM para esta corrección. La presencia en S3 no certifica la visualización del modelo en QuickSight.

El dataset de inferencias se configura como DIRECT_QUERY en `terraform/modules/catalog/quicksight.tf`; corresponde distinguirlo del dataset SPICE del panel histórico y revisar sus filtros por modelo, autora y periodo. El notebook e instalador anteriores de XGBoost se retiraron del repositorio y el bootstrap recuperó sus dependencias originales. No se limpiaron paquetes del EMR activo ni la caché remota.

La validación con varios cortes temporales, el remuestreo por distrito, los cuantiles de errores extremos y la sensibilidad a umbrales de telemetría e imputación OSIPTEL fueron propuestos y explicados, pero permanecen sin implementar. La carga del PipelineModel por corrida en el servicio SageMaker también permanece pendiente de verificar. No se deben presentar estos elementos como resultados terminados.

---

## 7. Reglas de Estilo y Trabajo Obligatorias para Cualquier Agente

1. **Listo para copiar y pegar en Word:** Todo texto debe redactarse en tercera persona formal, con tono de consultoría técnica académica, sin comentarios conversacionales dirigidos al usuario dentro de los archivos.
2. **Sin subnumeraciones anidadas:** El encabezado del archivo es el nivel máximo (ej. `## Línea base del negocio` o `### 1.4. Línea base del negocio`). Queda estrictamente prohibido crear niveles como `1.4.1`, `1.4.2`, etc. Las subdivisiones se hacen con subtítulos en negrita (`**Objetivo general**`, `**Fuera del alcance**`, etc.).
3. **Prohibido el formato `Etiqueta: texto` en viñetas:** No escribir listas con el patrón `- Nombre del punto: texto explicativo...`. Las viñetas deben ser oraciones continuas, fluidas, completas y gramaticalmente naturales.
4. **Prohibidas las traducciones bilingües redundantes entre paréntesis:** No escribir términos como «infraestructura compartida (multitenant)» o «nuevos sitios (Build-to-Suit)». Usar directamente la terminología técnica limpia y precisa en español.
5. **No volcar datos pesados al contexto:** NUNCA ejecutar comandos tipo `cat dataset.csv` o usar herramientas de lectura directa sobre archivos grandes. Cualquier análisis de datos debe hacerse mediante scripts temporales de Python (usando la biblioteca estándar `csv`, `sqlite3`, etc.) o comandos de consola que impriman únicamente resúmenes agregados y esquemas para no saturar la ventana de contexto.
6. **Cero supuestos no auditables:** Toda afirmación de negocio, cifra de mercado o métrica cuantitativa debe provenir de documentos oficiales con fuente, autor y fecha comprobable.
7. **Metodología paso a paso:** Trabajar únicamente sobre la sección desbloqueada por el usuario sin adelantarse a capítulos futuros.
