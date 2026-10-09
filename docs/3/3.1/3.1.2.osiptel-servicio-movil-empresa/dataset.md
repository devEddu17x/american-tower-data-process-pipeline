### **_OSIPTEL \- Cobertura de servicio móvil por empresa operadora_**

|                 Campo                  |                                                                                                                                                              Descripción                                                                                                                                                              |
| :------------------------------------: | :-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: |
|          Nombre del conjunto           |                                                                                                                                          Cobertura de servicio móvil por empresa operadora.                                                                                                                                           |
|                 Origen                 |                                                                                                                                                     Fuente pública institucional.                                                                                                                                                     |
|          Entidad publicadora           |                                                                                                                              Organismo Supervisor de Inversión Privada en Telecomunicaciones \- OSIPTEL.                                                                                                                              |
|       Enlace o medio de entrega        | [Ficha oficial](https://www.datosabiertos.gob.pe/dataset/cobertura-de-servicio-m%C3%B3vil-por-empresa-operadora) y [archivo CSV](https://www.datosabiertos.gob.pe/sites/default/files/Cobertura%20m%C3%B3vil%20por%20empresa%20operadora.csv). Documentación complementaria: diccionario XLSX y metadatos PDF publicados por OSIPTEL. |
|           Fecha de obtención           |                                                                                                                                         Inspección remota realizada el 8 de octubre de 2026\.                                                                                                                                         |
|     Licencia o condiciones de uso      |                                                                                                                                            Open Data Commons Attribution License \- ODC-By                                                                                                                                            |
| Período cubierto y número de registros |                                51 366 registros correspondientes al período 202303, asociado al cierre del primer trimestre de 2023\. El campo FECHA_CORTE contiene 20230613\. Se identificaron cuatro operadoras, 31 439 códigos distintos de centros poblados y 1 664 códigos distritales distintos.                                |
|       Tamaño en disco y formato        |                                                                                   7 590 550 bytes, equivalentes aproximadamente a 7,591 MB o 7,239 MiB. Formato CSV, con 25 columnas, separador punto y coma y lectura compatible con Windows-1252.                                                                                   |

| Campo original documentado |  Tipo lógico / representación  |                                       Descripción                                       |
| :------------------------: | :----------------------------: | :-------------------------------------------------------------------------------------: |
|            NUM             |             Entero             |                            Número correlativo del registro.                             |
|        FECHA_CORTE         | Fecha codificada como AAAAMMDD |                            Fecha de generación del dataset.                             |
|          PERIODO           | Período codificado como AAAAMM |                  Período al que corresponde la información declarada.                   |
|     EMPRESA_OPERADORA      |             Texto              |                          Razón social de la empresa operadora.                          |
|        UBIGEO_CCPP         |     Texto de 10 caracteres     |                          Código geográfico del centro poblado.                          |
|      UBIGEO_DISTRITO       |     Texto de 6 caracteres      |                             Código geográfico del distrito.                             |
|        DEPARTAMENTO        |             Texto              |                   Departamento donde se encuentra el centro poblado.                    |
|         PROVINCIA          |             Texto              |                     Provincia donde se encuentra el centro poblado.                     |
|          DISTRITO          |             Texto              |                     Distrito donde se encuentra el centro poblado.                      |
|       CENTRO_POBLADO       |             Texto              |                               Nombre del centro poblado.                                |
|          LATITUD           |            Decimal             |                               Latitud del centro poblado.                               |
|          LONGITUD          |            Decimal             |                              Longitud del centro poblado.                               |
|             2G             |      Entero binario, 0/1       |                   Indicador de cobertura declarada con tecnología 2G.                   |
|             3G             |      Entero binario, 0/1       |                   Indicador de cobertura declarada con tecnología 3G.                   |
|             4G             |      Entero binario, 0/1       |                   Indicador de cobertura declarada con tecnología 4G.                   |
|             5G             |      Entero binario, 0/1       |                   Indicador de cobertura declarada con tecnología 5G.                   |
|            VOZ             |      Entero binario, 0/1       |               Indicador de disponibilidad declarada del servicio de voz.                |
|            SMS             |      Entero binario, 0/1       |               Indicador de disponibilidad declarada de mensajes de texto.               |
|            MMS             |      Entero binario, 0/1       |              Indicador de disponibilidad declarada de mensajes multimedia.              |
|        HASTA_1_MBPS        |      Entero binario, 0/1       |         Indicador de servicio de internet móvil con velocidad de hasta 1 Mbps.          |
|       MÁS_DE_1_MBPS        |      Entero binario, 0/1       |        Indicador de servicio de internet móvil con velocidad superior a 1 Mbps.         |
|         CANT_EB_2G         |             Entero             | Cantidad declarada de estaciones base que pueden brindar servicio 2G al centro poblado. |
|         CANT_EB_3G         |             Entero             | Cantidad declarada de estaciones base que pueden brindar servicio 3G al centro poblado. |
|         CANT_EB_4G         |             Entero             | Cantidad declarada de estaciones base que pueden brindar servicio 4G al centro poblado. |
|         CANT_EB_5G         |             Entero             | Cantidad declarada de estaciones base que pueden brindar servicio 5G al centro poblado. |
