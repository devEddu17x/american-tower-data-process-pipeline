# Plataforma Big Data y Analitica de Datos - American Tower del Peru

Repositorio oficial del proyecto de Big Data y Analitica de Datos (Universidad Privada Antenor Orrego, Periodo 2026, Ciclo VIII).

* Enlace oficial al repositorio: https://github.com/devEddu17x/american-tower-data-process-pipeline.git
* Empresa de referencia: American Tower del Peru S.A.C.
* Caso de uso: Prediccion de rendimiento movil celular distrital a un trimestre de anticipacion y estructuracion del Indice de Prioridad Territorial sobre los 1,890 distritos del Peru.

---

## 1. Descripcion General de la Solucion

La plataforma implementa una arquitectura distribuida desacoplada en Amazon Web Services (Ruta B) sobre un cluster hibrido de Amazon EMR con Apache Spark 3.5.0 y Apache Sedona. La solucion procesa e integra cinco fuentes de datos institucionales oficiales (482,368 teselas atomicas de Ookla, 51,366 centros poblados de OSIPTEL, 11,099 estaciones base de OSIPTEL, 1,890 distritos del INEI y 152 millones de celdas demograficas de WorldPop), estructurando un Data Lake de tres capas (Bronze, Silver y Gold) con controles de calidad automatizados, optimizacion distribuida mediante Broadcast Hash Join, prueba de escalabilidad factorial hasta 100x y entrenamiento de un modelo base supervisado con Spark MLlib.

---

## 2. Requisitos del Entorno

### 2.1. Entorno Local de Control y Despliegue
* Sistema Operativo: Linux (Ubuntu 22.04 LTS o Amazon Linux 2023 recomendado), macOS o WSL2 en Windows.
* Herramientas de linea de comandos:
  * Git >= 2.34
  * AWS CLI v2 >= 2.15 (configurado con credenciales de acceso a la cuenta AWS)
  * Terraform >= 1.5.0
  * OpenSSH Client >= 8.9 (para tuneles seguros hacia el nodo maestro)
  * Python >= 3.9 (con soporte para venv)
  * jq >= 1.6 (utilitario para parseo de JSON en scripts de automatizacion)

### 2.2. Infraestructura en la Nube (AWS EMR y Amazon S3)
* Region de despliegue: AWS `us-east-1`.
* Topologia del Cluster Amazon EMR (release `emr-7.1.0`):
  * Total nodos: 11 instancias de computo (44 vCPUs y 176 GB de memoria RAM en conjunto).
  * 1 Nodo Maestro (Instancia `m5.xlarge`, On-Demand): Coordinacion de YARN, ejecucion de Spark Driver y servidor Jupyter.
  * 2 Nodos de Nucleo (Instancias `m5.xlarge`, On-Demand): Almacenamiento persistente HDFS y computo permanente.
  * 8 Nodos de Tareas (Instancias `m5.xlarge`, Spot): Nodos de computo elastico sin almacenamiento HDFS.
* Cuotas de computo verificadas en cuenta: Minimo 12 vCPUs On-Demand y 32 vCPUs Spot autorizadas en `us-east-1`.
* Topologia de red: Amazon VPC (`10.0.0.0/16`) con subred privada (`10.0.0.20/24`) y punto de enlace gratuito S3 VPC Gateway Endpoint.
* Almacenamiento (Amazon S3): 5 depósitos dedicados con cifrado en reposo SSE-S3 AES-256:
  * `american-tower-dev-bronze-...` (Zona de datos crudos e inmutables)
  * `american-tower-dev-silver-...` (Zona de datos limpios y tipificados)
  * `american-tower-dev-gold-...` (Zona de tablones analiticos integrados)
  * `american-tower-dev-operations-...` (Cuarentena de calidad y evidencias de ejecucion)
  * `american-tower-dev-artifacts-...` (Scripts de bootstrap, entornos virtuales y configuraciones)

### 2.3. Entorno de Ejecucion Distribuido (EMR Master)
* Motor distribuido: Apache Spark 3.5.0 y Apache Hadoop/YARN 3.3.6.
* Entorno virtual de Python (`/opt/american-tower/venv`):
  * Apache Sedona 1.7.2, GeoPandas 1.0.1, Shapely 2.0.6, PyProj 3.6.1
  * PyArrow 17.0.0, OpenPyXL 3.1.5, Pandas 2.2.3, NumPy 1.26.4
  * Matplotlib 3.9.4, Seaborn 0.13.2, Boto3

---

## 3. Pasos de Instalacion y Aprovisionamiento

### Paso 1: Clonar el Repositorio
```bash
git clone https://github.com/devEddu17x/american-tower-data-process-pipeline.git
cd american-tower-data-process-pipeline
```

### Paso 2: Configurar Credenciales de AWS
Verificar que la estacion de trabajo cuente con credenciales activas con permisos de administrador o ingeniero de datos:
```bash
aws configure --profile bigdata
# Indicar AWS Access Key ID, Secret Access Key y region por defecto (us-east-1)
export AWS_PROFILE="bigdata"
export AWS_REGION="us-east-1"
```

### Paso 3: Aprovisionar Infraestructura como Codigo (Terraform)
El despliegue de los 5 buckets S3, roles IAM, redes VPC y el cluster de 11 nodos se realiza de forma declarativa:
```bash
cd terraform/envs/dev
terraform init
terraform apply -var="enable_emr=true" -auto-approve
cd ../../..
```
El aprovisionamiento del cluster EMR toma aproximadamente entre 7 y 10 minutos. Durante el arranque, el script de bootstrap descarga y descomprime el entorno virtual precompilado en `/opt/american-tower/venv` y registra el kernel `American Tower - PySpark`.

### Paso 4: Establecer Conexion Remota Segura con el Cluster
El proyecto incluye un script de automatizacion que descarga la llave privada desde AWS SSM Parameter Store (`/american-tower/dev/emr_ssh_key`), configura el bloque `Host emr-studio` en `~/.ssh/config` y habilita el reenvio de puertos locales:
```bash
# Modo 1: Abrir Visual Studio Code conectado via Remote-SSH
./scripts/connect_emr.sh --vscode

# Modo 2: Abrir una sesion interactiva SSH en la terminal
./scripts/connect_emr.sh --terminal
```

---

## 4. Fuentes de Datos Oficiales y Datos de Muestra

El pipeline no utiliza datos sinteticos para el analisis ni el modelo. Opera sobre 5 fuentes institucionales auditadas:

| Fuente Institucional | Formato Original | Volumen Registrado | Ubicacion en Bronze |
| :--- | :--- | :--- | :--- |
| Ookla Speedtest Mobile Network | Apache Parquet (EPSG:4326) | 482,368 teselas nacionales (2020-T1 a 2026-T1) | `s3://<bucket-bronze>/ookla/snapshot_id=<id>/` |
| OSIPTEL Cobertura Movil | Archivo CSV delimitado | 51,366 registros distritales | `s3://<bucket-bronze>/osiptel_cobertura/snapshot_id=<id>/` |
| OSIPTEL Estaciones Base | Archivo XLSX | 11,099 registros de tecnologia | `s3://<bucket-bronze>/osiptel_estaciones/snapshot_id=<id>/` |
| INEI Limites Distritales | Cartografia oficial GPKG/SHP | 1,890 distritos unicos | `s3://<bucket-bronze>/inei/snapshot_id=<id>/` |
| WorldPop Population Counts | Raster GeoTIFF (100 metros) | 152.1 millones de celdas validas | `s3://<bucket-bronze>/worldpop/snapshot_id=<id>/` |

### Datos de Muestra y Configuracion Versionada
Para pruebas en entornos locales o de desarrollo sin descargar la totalidad de particiones globales, el archivo de configuracion `notebooks/bronze_config.completed.json` define los identificadores unicos de version (`snapshot_id`), las rutas S3 activas y las sumas de comprobacion criptografica SHA-256 auditadas de cada insumo.

---

## 5. Orden de Ejecucion del Pipeline de Datos

El pipeline se encuentra modularizado en 4 libretas interactivas Jupyter ubicadas en el directorio `notebooks/`, las cuales deben ejecutarse estrictamente en la siguiente secuencia:

```text
[01_ingesta_bronze_refactorizada.ipynb]  -->  Descarga cruda y auditoria SHA-256 en S3 Bronze
                    |
[02_pipeline_limpieza_calidad_almacenamiento.ipynb]  -->  Saneamiento, calidad, cuarentena y persistencia Silver/Gold
                    |
[03_optimizacion_y_escalabilidad.ipynb]  -->  Benchmark Broadcast Join y prueba de estres hasta 100x
                    |
[04_analisis_exploratorio_y_modelo_base.ipynb]  -->  EDA (3 graficos PNG) y Modelo Base RandomForest MLlib
```

### Fase 1: Ingesta Inmutable a S3 Bronze
* Libreta: `notebooks/01_ingesta_bronze_refactorizada.ipynb`
* Proposito: Conecta con los origenes institucionales (AWS Open Data en `us-west-2` y portales de datos abiertos de OSIPTEL e INEI), transfiere los datos hacia S3 Bronze en `us-east-1` calculando sumas de comprobacion criptografica SHA-256 en tiempo real y genera el manifiesto formal de ingesta.
* Salida auditada: 64 objetos crudos asegurados con marcador `_SUCCESS` en `s3://<bucket-bronze>/`.

### Fase 2: Procesamiento, Limpieza, Calidad y Almacenamiento
* Libreta: `notebooks/02_pipeline_limpieza_calidad_almacenamiento.ipynb`
* Proposito:
  * Estandarizacion de esquemas y tipos de datos.
  * Evaluacion de reglas de veracidad: sobre 482,368 registros evaluados, se identificaron 482,347 registros conformes (99.99 %) y se aislaron 21 registros anomalos (0.01 %) en `s3://<bucket-operations>/quarantine/ookla/`.
  * Integracion multifuente sobre la dimension completa de 1,890 distritos del INEI cruzada con los 24 trimestres historicos de Ookla.
  * Persistencia columnar particionada en formato Apache Parquet con compresion Snappy: tablas limpias en S3 Silver y tablon maestro integrado con 45,360 observaciones en `s3://<bucket-gold>/metricas_distritales_trimestrales/`.

### Fase 3: Optimizacion de Rendimiento y Prueba de Escalabilidad
* Libreta: `notebooks/03_optimizacion_y_escalabilidad.ipynb`
* Proposito:
  * Evaluacion de la optimizacion de difusion en memoria (`Broadcast Join`): redujo el tiempo de union de 482 mil teselas frente a 1,890 distritos de 2.58 s a 1.62 s (37.39 % de reduccion de latencia, 1.60x de aceleracion).
  * Prueba de escalabilidad factorial sobre el conjunto atomico nacional:
    * Escala 1x (482,368 registros): 2.25 s
    * Escala 5x (2,411,840 registros): 2.43 s
    * Escala 10x (4,823,680 registros): 3.20 s
    * Escala 100x (48,236,800 registros): 29.29 s (escalabilidad lineal sobre los 10 nodos trabajadores)
    * Escala 1,000x (482,368,000 registros): Determinacion empirica del punto de quiebre fisico por saturacion de memoria Java Heap en el nodo maestro (47,000 tareas en grafo DAG).

### Fase 4: Analisis Exploratorio de Datos y Modelo Base Predictivo
* Libreta: `notebooks/04_analisis_exploratorio_y_modelo_base.ipynb` (o script equivalente `scripts/ejecutar_eda_y_modelo.py`)
* Proposito:
  * Generacion de las tres visualizaciones analiticas obligatorias sobre datos limpios de Gold (guardadas en `docs/images/`):
    * `eda_1_velocidad_departamentos.png`: Distribucion departamental de velocidad y latencia.
    * `eda_2_poblacion_vs_estaciones.png`: Dispersion logaritmica de demanda frente a estaciones 4G instaladas.
    * `eda_3_evolucion_temporal.png`: Serie temporal trimestral 2020 a 2026.
  * Formulacion del problema supervisado con variable objetivo proyectada al trimestre siguiente ($t+1$) mediante funciones de ventana cronologica (43,470 observaciones supervisadas).
  * Particion temporal estricta para evitar fuga de informacion:
    * Conjunto de Entrenamiento (2020 a 2023): 28,350 observaciones (65.2 %).
    * Conjunto de Evaluacion (2024): 7,560 observaciones independientes (17.4 %).
  * Evaluacion comparativa entre la linea base ingenua (persistencia) y un modelo de aprendizaje automatico distribuido con `RandomForestRegressor` en Spark MLlib (50 arboles, profundidad 8).
  * Declaracion formal de la linea base tecnica: **MAE = 1.35 Mbps** y **R2 = 0.9603**, demostrando que la latencia (28.60 %) y las estaciones 4G (27.56 %) explican mas del 56 % de la velocidad movil distrital.

---

## 6. Monitoreo y Verificacion Operativa

El clúster EMR cuenta con tuneles SSH automáticos que permiten supervisar la ejecucion distribuida en tiempo real desde el navegador local:

* Spark History Server (Registro persistente de etapas, DAG y ejecucion de jobs): `http://localhost:18080`
* Spark Active Application UI (Monitoreo en vivo de tareas activas): `http://localhost:4040`
* YARN ResourceManager (Estado de memoria de contenedores y nodos de trabajo): `http://localhost:8088`

Para verificar la integridad de las capas de datos directamente desde AWS CLI:
```bash
# Validar objetos en Bronze
aws s3 ls s3://american-tower-dev-bronze-b7f9699786f4c119558b9d30f9/ --recursive --summarize

# Validar tablas depuradas en Silver
aws s3 ls s3://american-tower-dev-silver-2ad71fded155d2bd52df8f836e/ --recursive --summarize

# Validar tablon Gold particionado
aws s3 ls s3://american-tower-dev-gold-00f4f2b4cf37bac32a9ec520ee/metricas_distritales_trimestrales/
```

---

## 7. Estructura del Repositorio

```text
american-tower-data-process-pipeline/
├── docs/                                       # Documentacion academica del proyecto (UPAO)
│   ├── 1/                                      # Capitulo 1: Empresa, problema y linea base
│   ├── 2/                                      # Capitulo 2: Arquitectura de la solucion (Ruta B)
│   ├── 3/                                      # Capitulo 3: Implementacion del pipeline de datos
│   │   ├── 3.1/ a 3.8/                         # Fichas de procedencia, ingesta, calidad, seguridad
│   ├── 4/                                      # Capitulo 4: Analisis exploratorio y modelo base
│   │   ├── 4.1/4.1.analisis-exploratorio-datos.md
│   │   ├── 4.2/4.2.modelo-base.md
│   │   └── 4.2/explicacion-modelo-base.md     # Guia explicativa para perfiles de negocio
│   ├── images/                                 # Visualizaciones analiticas de alta resolucion (PNG)
│   ├── guia.md                                 # Rubrica oficial de evaluacion UPAO
│   └── linea-base.md                           # Linea base del negocio auditada
├── notebooks/                                  # Libretas interactivas Jupyter en Amazon EMR
│   ├── 01_ingesta_bronze_refactorizada.ipynb   # Fase 1: Ingesta inmutable a Bronze
│   ├── 02_pipeline_limpieza_calidad_almacenamiento.ipynb # Fase 2: Limpieza, calidad y Gold
│   ├── 03_optimizacion_y_escalabilidad.ipynb   # Fase 3: Benchmark Broadcast y estres 100x
│   ├── 04_analisis_exploratorio_y_modelo_base.ipynb # Fase 4: EDA y Modelo Base MLlib
│   └── bronze_config.completed.json            # Metadatos auditados y configuracion S3
├── scripts/                                    # Scripts de soporte y automatizacion
│   ├── bootstrap.sh                            # Bootstrap script del cluster Amazon EMR
│   ├── connect_emr.sh                          # Conexion automatica SSH y tunelaje web
│   └── ejecutar_eda_y_modelo.py                # Script batch de ejecucion de EDA y Modelo Base
├── terraform/                                  # Infraestructura como Codigo (IaC) en AWS
│   ├── envs/dev/                               # Definicion del entorno de desarrollo
│   └── modules/                                # Modulos de red, almacenamiento, EMR e IAM
├── resultados.txt                              # Registro de ejecucion auditado de la Libreta 02
├── resultados-02.txt                           # Registro de ejecucion auditado de la Libreta 03
├── AGENTS.md                                   # Manual de contexto operativo para agentes
└── README.md                                   # Guia principal de reproduccion de la solucion
```

---

## 8. Licencia y Terminos de Uso

Este proyecto se distribuye exclusivamente con fines academicos y de investigacion aplicada bajo los terminos de la licencia MIT. Los conjuntos de datos utilizados son propiedad de sus respectivas entidades publicadoras (Ookla Open Data Initiative bajo licencia CC BY-NC-SA 4.0; OSIPTEL e INEI bajo politicas de Datos Abiertos de la Republica del Peru; y WorldPop bajo licencia CC BY 4.0).
