La solución adopta una arquitectura en Amazon Web Services (AWS) que separa la adquisición de datos, el almacenamiento persistente, el procesamiento distribuido, el entrenamiento del modelo y el consumo de resultados. Esta separación permite mantener la trazabilidad de las transformaciones, repetir las ejecuciones y modificar componentes sin alterar innecesariamente las demás capas.

El procesamiento de las fuentes se realizará por lotes, considerando sus periodos de actualización y disponibilidad. La unidad principal de integración será el distrito por trimestre. El modelo estimará la velocidad media de descarga observada en pruebas móviles durante el trimestre siguiente, mientras que la priorización territorial combinará el pronóstico con indicadores de cobertura, infraestructura reportada y población.

Amazon S3 proporcionará el almacenamiento persistente del Data Lake. Amazon EMR sobre EC2 ejecutará los trabajos de Apache Spark, Apache Sedona y Spark MLlib, realizando la inferencia trimestral masiva. AWS Glue Data Catalog mantendrá los metadatos de las tablas analíticas, Amazon Athena permitirá consultarlas mediante SQL, Amazon SageMaker AI alojará el endpoint bajo demanda para simulaciones interactivas y Amazon QuickSight presentará los indicadores territoriales.

Enlace: diagrama.svg

La infraestructura se plantea en la región AWS us-east-1, manteniendo en ella los recursos propios de almacenamiento, procesamiento, catálogo, consulta y despliegue del modelo. Las fuentes externas conservarán sus ubicaciones originales y se accederá a ellas mediante los mecanismos oficiales disponibles.
