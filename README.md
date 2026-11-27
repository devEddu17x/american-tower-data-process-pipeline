# Plataforma Big Data y Analitica de Datos - American Tower del Peru

Repositorio oficial del proyecto de Big Data y Analitica de Datos (Universidad Privada Antenor Orrego, Periodo 2026, Ciclo VIII).

* Enlace oficial al repositorio: https://github.com/devEddu17x/american-tower-data-process-pipeline.git
* Empresa de referencia: American Tower del Peru S.A.C.
* Caso de uso: Prediccion de la velocidad media de descarga movil distrital a un trimestre de anticipacion y estructuracion del Indice de Prioridad Territorial sobre los 1,890 distritos del Peru.

---

## 1. Descripcion General de la Solucion

La plataforma implementa una arquitectura distribuida desacoplada en Amazon Web Services (Ruta B) sobre un cluster hibrido de Amazon EMR (`emr-7.1.0`) con Apache Spark 3.5.0 y Hadoop/YARN 3.3.6. La solucion ingesta, verifica con SHA-256, limpia, cruza espacialmente e integra fuentes oficiales del Peru (Ookla Speedtest Mobile, OSIPTEL Cobertura Movil, INEI Limites Distritales y WorldPop 2020), estructurando un Data Lake Medallion (Bronze, Silver y Gold) con linaje encadenado mediante manifiestos `_SUCCESS.json` en Amazon S3, cuarentenas de calidad y asignacion espacial, pruebas de optimizacion y escalabilidad de 1x a 100x sobre el pipeline completo, analisis exploratorio y evaluacion de un modelo base supervisado en Spark MLlib.

---

## 2. Requisitos del Entorno

### 2.1. Entorno Local de Control y Despliegue
* Sistema Operativo: Linux (Ubuntu 22.04 LTS o Amazon Linux 2023 recomendado), macOS o WSL2 en Windows.
* Herramientas de linea de comandos:
  * Git >= 2.34
  * AWS CLI v2 >= 2.15 (configurado con credenciales de acceso a la cuenta AWS)
  * Terraform >= 1.5.0
  * OpenSSH Client >= 8.9 (para tuneles seguros hacia el nodo maestro)
  * Python >= 3.9

### 2.2. Infraestructura en la Nube (AWS EMR y Amazon S3)
* Region de despliegue: AWS `us-east-1`.
* Topologia del Cluster Amazon EMR (release `emr-7.1.0`):
  * Total nodos: 11 instancias `m5.xlarge` (44 vCPUs y 176 GB de RAM en conjunto).
  * 1 Nodo Maestro (`m5.xlarge`, On-Demand): Coordinacion de YARN, ejecucion de Spark Driver y servidor Jupyter.
  * 2 Nodos de Nucleo (`m5.xlarge`, On-Demand): Almacenamiento distribuido HDFS y computo permanente.
  * 8 Nodos de Tareas (`m5.xlarge`, Spot): Computo elastico sin almacenamiento HDFS.
* Topologia de red: Amazon VPC (`10.0.0.0/16`) con subred privada y punto de enlace S3 VPC Gateway Endpoint.
* Almacenamiento (Amazon S3): 5 depositos dedicados con cifrado en reposo SSE-S3 AES-256:
  * `american-tower-dev-bronze-...` (Zona de datos crudos e inmutables bajo `run_id=.../<fuente>/`)
  * `american-tower-dev-silver-...` (Zona de tablas saneadas y tipificadas en Parquet Snappy)
  * `american-tower-dev-gold-...` (Panel distrito-trimestre y contexto territorial en Parquet Snappy)
  * `american-tower-dev-operations-...` (Manifiestos `_SUCCESS.json`, cuarentenas, eventos Spark, benchmarks y graficas)
  * `american-tower-dev-artifacts-...` (Scripts de bootstrap y entorno virtual precompilado)

### 2.3. Entorno de Ejecucion Distribuido (EMR Master)
* Motor distribuido: Apache Spark 3.5.0 (`3.5.0-amzn-1`) y Apache Hadoop/YARN 3.3.6.
* Kernel Jupyter registrado: `American Tower - PySpark` (`/opt/american-tower/venv`).
* Dependencias principales: GeoPandas, Shapely (STRtree), Rasterio, PyProj, PyArrow, Pandas, NumPy, Matplotlib, Boto3 y utilitario del sistema `bsdtar`.

---

## 3. Pasos de Instalacion y Aprovisionamiento

### Paso 1: Clonar el Repositorio
```bash
git clone https://github.com/devEddu17x/american-tower-data-process-pipeline.git
cd american-tower-data-process-pipeline
```

### Paso 2: Configurar Credenciales de AWS
```bash
aws configure --profile bigdata
export AWS_PROFILE="bigdata"
export AWS_REGION="us-east-1"
```

### Paso 3: Aprovisionar Infraestructura como Codigo (Terraform)
```bash
cd terraform/envs/dev
terraform init
terraform apply -var="enable_emr=true" -auto-approve
cd ../../..
```
Durante el arranque del cluster, el script `terraform/services/emr/bootstrap.sh` (publicado en S3) instala el entorno virtual en `/opt/american-tower/venv` y registra el kernel `American Tower - PySpark`.

### Paso 4: Conexion Remota Segura con el Cluster
El script `scripts/connect_emr.sh` obtiene la llave privada desde AWS SSM Parameter Store (`/american-tower/dev/emr_ssh_key`), configura `Host emr-studio` en `~/.ssh/config` y habilita los tuneles locales hacia las interfaces de monitoreo:
```bash
./scripts/connect_emr.sh --vscode
# O en modo terminal:
./scripts/connect_emr.sh --terminal
```

---

## 4. Fuentes de Datos Oficiales

El pipeline opera exclusivamente sobre fuentes publicas institucionales verificadas mediante suma SHA-256 en Bronze (35 objetos, 6.41 GB en total):

| Fuente Institucional | Formato Original | Volumen en Bronze | Uso en Silver y Gold |
| :--- | :--- | :--- | :--- |
| Ookla Speedtest Mobile Network | Apache Parquet (29 trimestres, 2019-T1 a 2026-T1) | 29 archivos (5.68 GB) | 555,697 teselas candidatas en Peru; 417,420 asignadas a distritos |
| INEI Limites Politico-Administrativos | RAR con GeoPackage (EPSG:4326) | 3 archivos (21.4 MB) | 1,890 poligonos distritales validos con superficie en km2 |
| WorldPop Population Counts Peru 2020 | Raster GeoTIFF (15214 x 21977, 100 m) | 1 archivo (705 MB) | 151,864,618 pixeles validos agregados por distrito (`poblacion_2020`) |
| OSIPTEL Cobertura Movil por Operadora | CSV delimitado por `;` (`windows-1252`) | 1 archivo (7.59 MB) | 51,366 registros (periodo `202303`, corte `2023-06-13`), presencia 4G |
| OSIPTEL Estaciones Base por Tecnologia | Hoja de calculo XLSX | 1 archivo (740 KB) | Ingestado y verificado en Bronze; pendiente de integracion en Unidad 2 |

---

## 5. Orden de Ejecucion del Pipeline (6 Libretas)

Las libretas en `notebooks/` deben ejecutarse en orden en el nodo primario de EMR con el kernel **American Tower - PySpark**. Cada etapa publica un manifiesto `_SUCCESS.json` en el bucket `operations` que sirve como entrada trazable para la siguiente:

```text
01_ingesta_bronze.ipynb                   --> 35 objetos en Bronze + bronze/_SUCCESS.json
        |
02_silver_limpieza_y_calidad.ipynb        --> 5 tablas Silver + cuarentenas + silver/_SUCCESS.json
        |
03_gold_integracion_distrital.ipynb       --> panel_distrital + contexto_territorial + gold/_SUCCESS.json
        |
        +--> 04_optimizacion_y_escalabilidad.ipynb      --> Benchmark Broadcast vs. Shuffle y escala 1x/10x/100x
        +--> 05_analisis_exploratorio_y_modelo_base.ipynb --> EDA (2020-2024), 6 graficas y Modelo Base MLlib
        +--> 06_modelo_gbt_regressor.ipynb              --> GBTRegressor (Duan), estabilidad, mapa y predicciones Gold
```

### 1. Ingesta Bronze (`notebooks/01_ingesta_bronze.ipynb`)
Descarga los 35 archivos originales desde las fuentes oficiales, verifica integridad criptografica SHA-256 y tamano en bytes, sube los originales a S3 Bronze bajo `run_id=.../<fuente>/` y publica `BRONZE_RUN_URI`.

### 2. Limpieza y Calidad en Silver (`notebooks/02_silver_limpieza_y_calidad.ipynb`)
* Valida los recibos SHA-256 de Bronze.
* Filtra las teselas Ookla mediante prefijos `quadkey` de zoom 6 y bounding box del Peru (555,697 candidatas), aplica reglas de calidad tabular (100 % validas) y realiza la asignacion espacial real (`shapely.STRtree`, `covered_by`) sobre los 1,890 poligonos distritales del INEI: **417,420 teselas asignadas** y **138,277 fuera de poligonos** aisladas en `silver/cuarentena/espacial`.
* Normaliza `cobertura_osiptel.csv` (51,366 filas, UBIGEO de 6 digitos, `declara_4g` binario) y calcula la poblacion distrital real desde el raster `per_ppp_2020.tif` mediante `rasterio.mask` (151,864,618 pixeles validos).
* Persiste 5 tablas Parquet Snappy en Silver (`ookla_teselas`, `distritos`, `trimestres`, `osiptel_cobertura`, `worldpop_2020`) y publica `SILVER_RUN_URI`.

### 3. Integracion Distrital en Gold (`notebooks/03_gold_integracion_distrital.ipynb`)
Construye y valida dos productos analiticos en Parquet Snappy:
* `panel_distrital` (particionada por `year`): **54,810 filas** (1,890 distritos x 29 trimestres), velocidad de descarga ponderada por `tests`, con **41,434** pares observados y **13,376** sin medicion (conservados como `NULL`).
* `contexto_territorial`: **1,890 filas** (una por distrito), 100 % con `poblacion_2020` de WorldPop y **1,663** con cobertura declarada de OSIPTEL (227 distritos sin reporte).
* Publica `GOLD_RUN_URI`.

### 4. Optimizacion y Escalabilidad (`notebooks/04_optimizacion_y_escalabilidad.ipynb`)
* **Optimizacion de union (BroadcastHashJoin vs. SortMergeJoin):** 3 repeticiones alternadas sobre las 417,420 teselas Silver contra los 1,890 distritos Gold. Mediana Shuffle: **0.838 s**; Mediana Broadcast: **0.381 s** (**54.48 % de reduccion de tiempo**).
* **Escalabilidad (Bronze a Gold completo, 8 workers activos, 0 bytes derramados a memoria o disco):**
  * `1x` (555,697 candidatas): **185.24 s** (1.33 GB leidos).
  * `10x` (5,556,970 candidatas): **236.86 s** (1.28x respecto a 1x, 2.37 GB leidos).
  * `100x` (55,569,700 candidatas / 41.74M asignadas): **838.08 s** (4.52x respecto a 1x, 9.70 GB leidos, 1.34 GB shuffle).

### 5. Analisis Exploratorio y Modelo Base (`notebooks/05_analisis_exploratorio_y_modelo_base.ipynb`)
* **EDA (2020-T1 a 2024-T4, 20 trimestres):** Evalua 37,800 filas distrito-trimestre (29,161 observadas, 77.15 %). Genera 6 graficas exportadas a S3 y `docs/images/`: `eda_trimestres.png`, `eda_departamentos.png`, `eda_distribucion_2024_t4.png`, `eda_poblacion_pruebas.png`, `eda_osiptel_4g.png` y `modelo_errores.png`.
* **Modelo Base (pares consecutivos t -> t+1):** Particion cronologica estricta en Entrenamiento `2020-2022` (13,660 pares), Validacion `2023` (5,248 pares) y Prueba `2024` (5,666 pares). Contrasta **Persistencia** contra **Regresion lineal** (Spark MLlib):
  * Validacion 2023: Persistencia MAE **13.28 Mbps** vs. Regresion lineal MAE **11.64 Mbps** (RMSE 19.08, R2 = 0.028).
  * Prueba 2024: Persistencia MAE **14.65 Mbps** vs. Regresion lineal MAE **13.03 Mbps** (RMSE 20.22, R2 = -0.083, sesgo -7.68 Mbps).

### 6. Modelo GBTRegressor e Indice de Preseleccion Territorial (`notebooks/06_modelo_gbt_regressor.ipynb`)
* **Modelo Spark MLlib (`GBTRegressor`):** Entrenado sobre crecimiento logaritmico ponderado por `log1p(tests)` con calibracion de Duan integrada en `SQLTransformer`.
  * Evaluacion cronologica en Prueba 2024 (todos los pares, n=5,666): MAE **11.94 Mbps**, RMSE **19.17 Mbps**, R2 = **+0.0275**; en distritos con suficiencia (`tests >= 10`, n=3,990): MAE **9.98 Mbps**, RMSE **14.77 Mbps**, sesgo **-0.77 Mbps**, R2 = **+0.0845**.
  * Modelo productivo reentrenado sobre 35,557 pares historicos hasta `2026-T1`, guardado en `s3://<artifacts>/models/gbt_regressor/` y publicado en `s3://<gold>/predicciones_modelos/modelo_gbt_regressor.parquet` (1,564 predicciones para `2026-T2`, delta promedio **+1.99 Mbps**).
* **Priorizacion y estabilidad:** Indice territorial con criterio de suficiencia, estabilidad temporal (`2025-T4` vs `2026-T1`, 72 % overlap Top 50, Spearman 0.8389), sensibilidad de pesos (86-94 % overlap Top 50) y mapa distrital del Peru.

---

## 6. Monitoreo y Verificacion Operativa

Con la sesion SSH activa (`scripts/connect_emr.sh`), las interfaces de monitoreo quedan disponibles localmente:
* Spark History Server: `http://localhost:18080`
* Spark Active Application UI: `http://localhost:4040`
* YARN ResourceManager: `http://localhost:8088`

Todos los eventos Spark, manifiestos `_SUCCESS.json`, metricas JSON y graficas PNG quedan persistidos en el bucket `american-tower-dev-operations-...` bajo su respectivo `run_id`.

---

## 7. Estructura del Repositorio

```text
american-tower-data-process-pipeline/
├── datasets/osiptel/                           # Respaldo local de fuentes OSIPTEL
├── docs/
│   ├── images/                                 # Diagrama de arquitectura y 6 graficas del Notebook 05
│   ├── guia.md                                 # Rubrica oficial UPAO
│   └── linea-base.md                           # Linea base del negocio auditada
├── notebooks/
│   ├── 01_ingesta_bronze.ipynb
│   ├── 02_silver_limpieza_y_calidad.ipynb
│   ├── 03_gold_integracion_distrital.ipynb
│   ├── 04_optimizacion_y_escalabilidad.ipynb
│   ├── 05_analisis_exploratorio_y_modelo_base.ipynb
│   └── 06_modelo_gbt_regressor.ipynb
├── scripts/
│   ├── connect_emr.sh                          # Conexion SSH automatica y tunelaje (operador)
│   └── rollback_quarter.sh                     # Rollback de trimestre incremental (operador)
├── terraform/                                  # Infraestructura como Codigo (VPC, S3, IAM, EMR, Catalog, Lambda, SageMaker)
│   ├── modules/                                # Modulos HCL puros
│   └── services/                               # Codigo desplegado en servicios AWS (EMR, Lambda y SageMaker)
├── AGENTS.md                                   # Contexto operativo del proyecto
└── README.md                                   # Guia de reproduccion desde cero
```

---

## 8. Licencia y Terminos de Uso

Este proyecto se distribuye con fines academicos y de investigacion aplicada bajo licencia MIT. Los datos pertenecen a sus respectivas entidades publicadoras (Ookla Open Data Initiative CC BY-NC-SA 4.0; OSIPTEL e INEI Datos Abiertos del Peru; WorldPop CC BY 4.0).
