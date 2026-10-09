### **_Copernicus Sentinel-2 \- Imágenes Level-2A en formato COG_**

|                 Campo                  |                                                                                                                                         Descripción                                                                                                                                          |
| :------------------------------------: | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |
|          Nombre del conjunto           |                                                                                             Sentinel-2 Cloud-Optimized GeoTIFFs, colección Sentinel-2 Collection 1 Level-2A \- sentinel-2-c1-l2a                                                                                             |
|                 Origen                 |                                                                                                                                Fuente pública institucional.                                                                                                                                 |
|          Entidad publicadora           |                                                                            Programa Copernicus y Agencia Espacial Europea \- ESA. Element 84 mantiene la distribución COG y el catálogo Earth Search utilizados.                                                                             |
|       Enlace o medio de entrega        | [Registro del conjunto en AWS](https://registry.opendata.aws/sentinel-2-l2a-cogs/?utm_source=chatgpt.com) y [colección STAC](https://earth-search.aws.element84.com/v1/collections/sentinel-2-c1-l2a?utm_source=chatgpt.com). Bucket s3://e84-earth-search-sentinel-data/, región us-west-2. |
|           Fecha de obtención           |                                                                                                                     Inspección remota realizada el 8 de octubre de 2026                                                                                                                      |
|     Licencia o condiciones de uso      |                                                                                                 Acceso libre, completo y abierto, sujeto al aviso legal de uso de datos Copernicus Sentinel.                                                                                                 |
| Período cubierto y número de registros |        Consulta piloto entre el 1 de enero y el 31 de marzo de 2023, sobre un área de Trujillo, con nubosidad máxima de escena del 20 %. Se recuperaron 13 escenas candidatas y se seleccionó una escena, adquirida el 5 de febrero de 2023, con cuatro activos: B04, B08, B11 y SCL.        |
|       Tamaño en disco y formato        |                               354 673 928 bytes en cuatro archivos GeoTIFF COG y 25 055 bytes de metadatos STAC JSON. Total del conjunto piloto: 354 698 983 bytes \- 338,267 MiB. Los activos raster inspeccionados utilizan EPSG:32717 y compresión Deflate.                               |

Diccionario de bandas RAW relevantes

| Banda original | Clave stac | Tipo observado | Resolución |                                                         Descripción                                                          |
| :------------: | :--------: | :------------: | :--------: | :--------------------------------------------------------------------------------------------------------------------------: |
|      B04       |    red     |     UInt16     |    10 m    |                                            Banda roja. Insumo para calcular NDVI.                                            |
|      B08       |    nir     |     UInt16     |    10 m    |                               Banda del infrarrojo cercano. Insumo para calcular NDVI y NDBI.                                |
|      B11       |   swir16   |     UInt16     |    20 m    |                                Banda del infrarrojo de onda corta. Insumo para calcular NDBI.                                |
|      SCL       |    scl     |     UInt8      |    20 m    | Clasificación de escena utilizada para identificar clases de superficie y condiciones que afectan la calidad de los píxeles. |

Diccionario de metadatos RAW relevantes

|          Campo original stac          |         Tipo          |                                      Descripción                                       |
| :-----------------------------------: | :-------------------: | :------------------------------------------------------------------------------------: |
|                  id                   |         Texto         |                Identificador único de la escena dentro de la colección.                |
|              collection               |         Texto         |                     Identificador de la colección de procedencia.                      |
|               geometry                |   Geometría GeoJSON   |                            Huella geográfica de la escena.                             |
|                 bbox                  |   Lista de números    |                           Extensión geográfica de la escena.                           |
|        **properties.datetime**        | Fecha y hora ISO 8601 |                          Momento de adquisición de la escena.                          |
|        **properties.platform**        |         Texto         |                          Satélite que realizó la adquisición.                          |
|     **properties.eo:cloud_cover**     |        Decimal        |                         Porcentaje de nubosidad de la escena.                          |
|       **properties.proj:epsg**        |        Entero         |                      Código del sistema de referencia proyectado.                      |
| **properties.s2:processing_baseline** |         Texto         |                         Versión de procesamiento del producto.                         |
|       **assets.\<clave\>.href**       |      Texto / URL      |                    Dirección del archivo correspondiente al activo.                    |
|    **assets.\<clave\>.proj:shape**    |   Lista de enteros    |                     Número de filas y columnas del activo raster.                      |
|  **assets.\<clave\>.proj:transform**  |   Lista de enteros    |               Transformación entre posiciones de píxeles y coordenadas.                |
|   **assets.\<clave\>.raster:bands**   |   Lista de objetos    | Metadatos de banda: tipo de dato, NoData, escala y desplazamiento, cuando corresponda. |
|    **assets.\<clave\>.file:size**     |        Entero         |                        Tamaño declarado del archivo, en bytes.                         |
|  **assets.\<clave\>.file:checksum**   |         Texto         |                Identificador de comprobación de integridad del activo.                 |
