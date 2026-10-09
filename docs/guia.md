**UNIVERSIDAD PRIVADA ANTENOR ORREGO**

**FACULTAD DE INGENIERÍA**

**PROGRAMA DE ESTUDIO DE ING. COMPUTACIÓN Y SISTEMAS**

**PROYECTO DE BIG DATA Y ANALÍTICA DE DATOS**

**PARA LA EMPRESA «\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_»**

ASIGNATURA:  Big Data y Analítica de Datos

PERIODO ACADÉMICO:  2026-20          CICLO:  VIII

RUTA DE DESPLIEGUE:     ☐ On-premise        ☐ Nube

DOCENTE:  \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

**INTEGRANTES DEL EQUIPO**

1\.  \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_     Rol: \_\_\_\_\_\_\_\_\_\_\_\_\_\_

2\.  \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_     Rol: \_\_\_\_\_\_\_\_\_\_\_\_\_\_

3\.  \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_     Rol: \_\_\_\_\_\_\_\_\_\_\_\_\_\_

4\.  \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_     Rol: \_\_\_\_\_\_\_\_\_\_\_\_\_\_

Trujillo – Perú

**2026**


# <a name="_toc239449072"></a>**Índice**
*Para generar el índice: clic derecho sobre esta zona y elegir «Actualizar campos».*

[**Índice**	2](#_toc239449072)

[**Propósito y uso de este documento**	4](#_toc239449073)

[**Las dos ideas que sostienen todo el proyecto**	4](#_toc239449074)

[**Naturaleza del trabajo**	4](#_toc239449075)

[**Cómo se evalúa el proyecto**	4](#_toc239449076)

[**Hitos, instrumentos y forma de calificación**	4](#_toc239449077)

[**Composición de la nota de cada hito**	5](#_toc239449078)

[**Requisito de admisibilidad**	5](#_toc239449079)

[**Avance mínimo esperado a la Semana 7**	5](#_toc239449080)

[**Qué sección alimenta cada criterio de la medición final**	6](#_toc239449081)

[**Requisitos mínimos del proyecto**	7](#_toc239449082)

[**Sobre el volumen y la prueba de escalabilidad**	7](#_toc239449083)

[**Las dos rutas de despliegue**	8](#_toc239449084)

[**Estructura del informe**	9](#_toc239449085)

[**0. Ficha del proyecto y gestión del equipo**	9](#_toc239449086)

[**0.1. Equipo y roles**	9](#_toc239449087)

[**0.2. Cronograma**	9](#_toc239449088)

[**0.3. Riesgos y mitigación**	9](#_toc239449089)

[**0.4. Bitácora de decisiones**	9](#_toc239449090)

[**1. La empresa, el problema y la línea base**	9](#_toc239449091)

[**1.1. Resumen ejecutivo**	9](#_toc239449092)

[**1.2. La empresa y su contexto**	9](#_toc239449093)

[**1.3. Definición del problema de negocio**	9](#_toc239449094)

[**1.4. Línea base del negocio**	10](#_toc239449095)

[**1.5. Objetivos del proyecto**	10](#_toc239449096)

[**1.6. Alcance y limitaciones**	10](#_toc239449097)

[**1.7. Justificación del proyecto como problema de Big Data**	10](#_toc239449098)

[**2. Arquitectura de la solución**	10](#_toc239449099)

[**2.1. Arquitectura propuesta**	10](#_toc239449100)

[**2.2. Atributos de calidad del diseño**	10](#_toc239449101)

[**2.3. Prueba de sustitución de componentes**	11](#_toc239449102)

[**2.4. Stack tecnológico y equivalencia entre rutas**	11](#_toc239449103)

[**3. Implementación del pipeline de datos**	11](#_toc239449104)

[**3.1. Fuentes de datos y ficha de procedencia**	11](#_toc239449105)

[**3.2. Ingesta y organización del data lake**	12](#_toc239449106)

[**3.3. Procesamiento y limpieza**	12](#_toc239449107)

[**3.4. Control de calidad de los datos**	12](#_toc239449108)

[**3.5. Almacenamiento de datos procesados**	12](#_toc239449109)

[**3.6. Optimización del rendimiento**	12](#_toc239449110)

[**3.7. Prueba de escalabilidad**	12](#_toc239449111)

[**3.8. Seguridad de la plataforma**	13](#_toc239449112)

[**4. Análisis, modelado y capa de consumo**	13](#_toc239449113)

[**4.1. Análisis exploratorio de datos**	13](#_toc239449114)

[**4.2. Modelo base**	13](#_toc239449115)

[**4.3. Modelo definitivo, selección y evaluación**	13](#_toc239449116)

[**4.4. Modelo dimensional y capa de consumo**	13](#_toc239449117)

[**5. Ética, privacidad y gobierno de datos**	13](#_toc239449118)

[**5.1. Datos sensibles y protección aplicada**	14](#_toc239449119)

[**5.2. Linaje y gobierno del dato**	14](#_toc239449120)

[**5.3. Sesgos y consecuencias del modelo**	14](#_toc239449121)

[**5.4. Marco normativo aplicable**	14](#_toc239449122)

[**5.5. Aporte al desarrollo sostenible de la región**	14](#_toc239449123)

[**6. Valor generado, conclusiones y recomendaciones**	14](#_toc239449124)

[**6.1. Trazabilidad del valor**	14](#_toc239449125)

[**6.2. Conclusiones**	14](#_toc239449126)

[**6.3. Recomendaciones de negocio**	15](#_toc239449127)

[**6.4. Trabajo futuro**	15](#_toc239449128)

[**7. Anexos**	15](#_toc239449129)

[**Anexo A. Declaración de uso de herramientas de IA generativa**	16](#_toc239449130)

[**Anexo B. Lista de verificación previa a la entrega**	16](#_toc239449131)

[**Referencias sugeridas**	17](#_toc239449132)




# <a name="_toc239449073"></a>**Propósito y uso de este documento**
Este documento es la estructura obligatoria del informe del proyecto integrador del curso. Cada sección indica qué debe contener y con qué nivel de detalle. Las rúbricas con las que se califica se publican en el documento «Instrumentos de evaluación del proyecto», que acompaña a esta plantilla y se entrega en la misma fecha.

El proyecto es la evidencia integradora del curso y la fuente con la que se mide la competencia CE2 del perfil de egreso.

*Las secciones se desarrollan reemplazando el texto guía en cursiva por el contenido del equipo. El texto guía no debe permanecer en la versión entregada. Los valores entre ⟨corchetes angulares⟩ son parámetros que el docente confirma al inicio del semestre.*
## <a name="_toc239449074"></a>**Las dos ideas que sostienen todo el proyecto**
**La arquitectura es el fundamento y debe ser sólida.** Las herramientas que se colocan encima cambian con el tiempo: hoy Spark, mañana otro motor; hoy HDFS, mañana almacenamiento de objetos. Lo que debe mantenerse estable es el diseño: la separación entre almacenamiento y cómputo, los contratos entre capas, las zonas de datos y los atributos de calidad que se persiguen. Un proyecto que solo encadena herramientas no tiene arquitectura, y por eso se rompe apenas cambia una pieza.

**El propósito final es agregar valor al negocio.** La tecnología es el medio, no el fin. Un proyecto técnicamente impecable que no cambia ninguna decisión de la organización no aporta valor y no alcanza el nivel esperado en este curso. Toda recomendación debe poder trazarse hasta un objetivo, un hallazgo del análisis, una decisión concreta, un responsable y un efecto estimado sobre una línea base declarada.
## <a name="_toc239449075"></a>**Naturaleza del trabajo**
- Es un trabajo grupal, desarrollado durante todo el semestre y presentado en dos hitos evaluados.
- Adopta la perspectiva de un equipo consultor que diseña, construye y sustenta una solución de datos para una empresa real.
- Exige una implementación funcional. Un informe correcto sin solución ejecutable no alcanza la nota aprobatoria.
- Cada integrante debe poder explicar y defender el proyecto completo, no solo la parte que ejecutó.
# <a name="_toc239449076"></a>**Cómo se evalúa el proyecto**
El proyecto se evalúa en dos hitos. Cada hito comprende la entrega del informe en el estado que corresponda y una exposición con sustentación individual, en la que el docente pregunta a cada integrante por separado.
## <a name="_toc239449077"></a>**Hitos, instrumentos y forma de calificación**

|**Hito**|**Qué se entrega y se sustenta**|**Instrumento del informe**|**Calificación**|
| :- | :-: | :-: | :-: |
|<p>**Semana 7**</p><p>Unidad 1</p><p>*50 % del proyecto*</p>|Secciones 0 a 3 completas y las subsecciones 4.1 y 4.2: gestión del equipo, problema y línea base del negocio, arquitectura, pipeline funcionando sobre datos limpios, análisis exploratorio y modelo base.|Rúbrica del informe parcial (5 criterios)|<p>**Informe: grupal**</p><p>Sustentación: individual</p>|
|<p>**Semana 14**</p><p>Unidad 2</p><p>*50 % restante*</p>|Informe completo: secciones anteriores corregidas, modelo definitivo, capa de consumo, ética y gobierno de datos, conclusiones y recomendaciones de valor.|Rúbrica de Medición de Competencias del Perfil de Egreso (CE2)|<p>**Informe: individual**</p><p>Sustentación: individual</p>|

**Atención al cambio entre unidades.** En la Semana 7 el informe recibe una nota única para todo el equipo. En la Semana 14 el informe se califica de manera individual: aunque el documento sea uno solo, cada estudiante obtiene su propio puntaje según lo que demuestre dominar durante la sustentación y según su contribución verificable en el repositorio y en el rol declarado.
## <a name="_toc239449078"></a>**Composición de la nota de cada hito**

|**Componente**|**Semana 7**|**Semana 14**|
| :- | :-: | :-: |
|Informe escrito|⟨50 %⟩|⟨40 %⟩|
|Exposición y sustentación individual|⟨50 %⟩|⟨60 %⟩|

La sustentación pesa más que el informe porque es la evidencia más directa del aprendizaje de cada estudiante. El informe es un producto profesional necesario, pero puede elaborarse con apoyo de terceros o de herramientas de asistencia; lo que un estudiante sostiene frente a preguntas, sobre su propio código y sus propios datos, no.

Por eso el informe incorpora elementos que no pueden producirse sin haber hecho el trabajo: historial de contribuciones en el repositorio, mediciones de rendimiento antes y después de optimizar, prueba de escalabilidad, ficha de procedencia de los datos y evidencia de ejecución del pipeline.
## <a name="_toc239449079"></a>**Requisito de admisibilidad**
El hito no se recibe para evaluación, y por lo tanto no hay sustentación posible, si falta alguno de estos elementos:

|☐|Repositorio accesible, con README que permita reproducir la solución desde cero.|
| :-: | :- |
|☐|Pipeline ejecutable, con evidencia de al menos una corrida completa.|
|☐|Ficha de procedencia de los datos, con la fuente institucional o la constancia de autorización de la empresa.|
|☐|Declaración de uso de herramientas de IA generativa, firmada por todos los integrantes.|
## <a name="_toc239449080"></a>**Avance mínimo esperado a la Semana 7**
Un equipo que no cumpla estos puntos no puede alcanzar el nivel «Bueno» en el hito parcial.

|☐|El equipo está conformado, con roles asignados y cronograma en ejecución.|
| :-: | :- |
|☐|La empresa real está confirmada y el problema de negocio definido, con su línea base cuantificada.|
|☐|Las fuentes de datos están identificadas, obtenidas y documentadas con su ficha de procedencia.|
|☐|El entorno de trabajo está operativo y la ruta de despliegue está decidida y justificada.|
|☐|El diagrama de arquitectura corresponde a lo que ya está implementado.|
|☐|El pipeline ejecuta de extremo a extremo: ingesta, limpieza, integración y escritura en la zona procesada.|
|☐|Existe al menos una medición de rendimiento y la prueba de escalabilidad está ejecutada.|
|☐|El análisis exploratorio está hecho sobre los datos limpios, no sobre los crudos.|
|☐|Hay un modelo base entrenado y evaluado, con su línea base declarada.|
|☐|El repositorio está publicado, con historial de commits de todos los integrantes.|
## <a name="_toc239449081"></a>**Qué sección alimenta cada criterio de la medición final**
En la Semana 14 el informe se evalúa con la rúbrica de medición de competencias, que tiene dos criterios de desempeño con distinto peso. Esta tabla indica qué parte de su trabajo alimenta cada uno.

|**Criterio de desempeño**|**Puntaje máximo**|**Secciones del informe que lo evidencian**|
| :- | :-: | :-: |
|**CE2\_CD1 · Arquitectura, herramientas y seguridad de la información**|8 puntos|Secciones 2 y 3 completas, y las subsecciones 4.2 y 4.3 en lo referido al uso de técnicas avanzadas.|
|**CE2\_CD2 · Insights, valor para el negocio y uso ético de la información**|12 puntos|Subsecciones 4.1 y 4.4, y las secciones 5 y 6 completas.|

Note que el valor para el negocio y el uso ético de la información pesan más que la arquitectura y las herramientas. No es un descuido del instrumento: es la señal de qué se espera de un egresado.


# <a name="_toc239449082"></a>**Requisitos mínimos del proyecto**
Estos requisitos definen el piso de admisibilidad. Un proyecto que no los cumpla no puede alcanzar el nivel «Bueno» en la rúbrica, por bien redactado que esté el informe.

|**Aspecto**|**Requisito**|
| :- | :-: |
|**Equipo**|Cuatro integrantes por equipo. Cuando el total de matriculados no permita una división exacta, se admiten equipos de dos o tres y, excepcionalmente, de cinco. Los equipos de cinco asumen un alcance ampliado acordado con el docente en la Semana 2; los de dos, un alcance reducido en la misma oportunidad. Cada integrante asume un rol declarado en la sección 0 y los roles rotan al menos una vez durante el semestre.|
|**Empresa**|Debe ser una empresa u organización real, en operación e identificable, preferentemente peruana y de la región La Libertad. No se admiten empresas ficticias ni casos inventados.|
|**Origen de los datos**|Los datos deben ser reales. Se aceptan dos orígenes: datos cedidos por la organización, con constancia de autorización, o datos abiertos publicados por una fuente institucional identificable (INEI, Plataforma Nacional de Datos Abiertos, ministerios, BCRP, SENAMHI, municipalidades, organismos internacionales). Los repositorios de terceros solo se admiten si el conjunto es trazable hasta su fuente institucional original.|
|**Datos no admitidos**|No se aceptan datos sintéticos, generados, simulados ni inventados en ninguna parte del análisis. La única excepción es la réplica de datos reales para la prueba de escalabilidad, que se usa exclusivamente para medir rendimiento y nunca alimenta el análisis ni el modelo.|
|**Fuentes**|Mínimo dos fuentes distintas que deban integrarse mediante al menos una operación de unión. Se valora la combinación de formatos: estructurado, semiestructurado y no estructurado.|
|**Volumen**|Mínimo ⟨100 000 registros o 100 MB⟩ en el conjunto de las fuentes. El volumen se declara y se evidencia; no basta afirmarlo.|
|**Ruta de despliegue**|El equipo elige entre dos rutas alternativas y declara su elección en la portada, a más tardar en la Semana 7. Ambas son plenamente válidas, se califican con la misma rúbrica y ninguna otorga puntaje adicional. On-premise es la ruta por defecto.|
|**Repositorio**|Repositorio Git accesible, con README que permita reproducir la solución desde cero, historial de commits de todos los integrantes y datos de muestra si el conjunto completo no puede publicarse.|
|**Formato del informe**|Fuente Calibri o Arial 11, interlineado 1.5, citas y referencias en normas APA 7.ª edición. Extensión sugerida de ⟨25 a 35 páginas⟩ sin contar anexos. Entrega en PDF a través del aula virtual.|
## <a name="_toc239449083"></a>**Sobre el volumen y la prueba de escalabilidad**
El umbral de volumen es moderado a propósito, porque una empresa mediana rara vez cede a un grupo de estudiantes un conjunto de millones de registros, y la exigencia de datos reales tiene prioridad sobre la exigencia de tamaño.

Esa moderación se compensa con la prueba de escalabilidad de la subsección 3.7: el equipo replica su conjunto real hasta diez o cien veces su tamaño, mide cómo responde el pipeline y determina a partir de qué punto una sola máquina deja de alcanzar. Lo que se evalúa no es tener muchos datos, sino haber construido una arquitectura que soporte tenerlos.
## <a name="_toc239449084"></a>**Las dos rutas de despliegue**
El equipo decide con qué infraestructura construye su solución. No hay una ruta principal y una excepción: son dos alternativas legítimas, y la decisión misma forma parte de lo que se evalúa, porque exige sopesar costo, control y complejidad operativa.

**Ruta A · On-premise.** La solución se construye sobre el entorno de trabajo del curso: HDFS para el almacenamiento distribuido, YARN para la gestión de recursos, Apache Spark como motor de procesamiento y JupyterLab como entorno de desarrollo, ejecutados en contenedores o máquinas virtuales locales. Es la ruta por defecto y no requiere suscripción alguna.

**Ruta B · Nube.** La solución se implementa sobre servicios gestionados: almacenamiento de objetos, catálogo de metadatos, procesamiento distribuido y motor de consulta analítica. El equipo asume la gestión de credenciales, el control del gasto y la configuración de accesos, que forman parte de la evaluación de la seguridad.

Con independencia de la ruta elegida, la subsección 2.4 exige a todos los equipos el mapeo de la arquitectura entre ambos mundos y su estimación de costo. Los equipos de la ruta A lo resuelven como ejercicio de diseño con calculadoras públicas; los de la ruta B reportan además el costo real incurrido y lo contrastan con lo estimado. El curso de Data Engineering de AWS Academy que se cursa en paralelo aporta los fundamentos que sostienen esta sección.


# <a name="_toc239449085"></a>**Estructura del informe**
## <a name="_toc239449086"></a>**0. Ficha del proyecto y gestión del equipo**
*Esta sección demuestra que el proyecto se gestionó, no que simplemente ocurrió.*
### <a name="_toc239449087"></a>**0.1. Equipo y roles**
Integrantes con su rol principal: coordinación, ingeniería de datos, análisis y modelado, y calidad y documentación. Indique qué rol asumió cada uno en cada mitad del semestre. Si el equipo tiene menos o más de cuatro integrantes, indique cómo se distribuyeron los roles y qué alcance se acordó con el docente.
### <a name="_toc239449088"></a>**0.2. Cronograma**
Planificación por semanas desde la Semana 2 hasta la Semana 14, con los entregables intermedios y los responsables. Al cierre, contraste lo planificado con lo realmente ejecutado y explique las desviaciones.
### <a name="_toc239449089"></a>**0.3. Riesgos y mitigación**
Identifique al menos cuatro riesgos concretos, con su probabilidad, impacto y medida de mitigación. Al cierre indique cuáles se materializaron y cómo se manejaron.

*Riesgos frecuentes: la empresa demora o niega la entrega de los datos; el conjunto obtenido resulta insuficiente o de mala calidad; el entorno distribuido no arranca en las máquinas del equipo; el modelo no alcanza el desempeño comprometido; el gasto en la nube se dispara; un integrante se retira del curso.*
### <a name="_toc239449090"></a>**0.4. Bitácora de decisiones**
Registro breve de las decisiones técnicas relevantes, con fecha, alternativas evaluadas, criterio de elección y consecuencia. La elección de la ruta de despliegue debe figurar aquí con su justificación.
## <a name="_toc239449091"></a>**1. La empresa, el problema y la línea base**
*Escriba como un equipo consultor que presenta una propuesta a un cliente que no es especialista en datos.*
### <a name="_toc239449092"></a>**1.1. Resumen ejecutivo**
Un párrafo que resuma el problema, la solución construida, los resultados obtenidos y el valor para la empresa. Es lo último que se escribe y lo primero que se lee.
### <a name="_toc239449093"></a>**1.2. La empresa y su contexto**
A qué se dedica, en qué mercado opera, qué desafíos enfrenta y qué papel juegan hoy los datos en su operación. Identifique además quién sería, dentro de la organización, el destinatario real de los resultados de este proyecto.
### <a name="_toc239449094"></a>**1.3. Definición del problema de negocio**
Formule un problema específico y medible. «Queremos analizar datos» no es un problema. Ejemplos de formulación adecuada:

- La empresa presenta una tasa de abandono de clientes del 18 % anual y desconoce sus causas principales.
- Las campañas de marketing tienen un retorno bajo porque la segmentación no distingue perfiles de compra.
- La gestión de inventario genera sobrestock en unas sedes y quiebre de stock en otras, sin visibilidad consolidada.
### <a name="_toc239449095"></a>**1.4. Línea base del negocio**
Declare el valor actual de la métrica que el proyecto busca mejorar, con su fuente y su fecha de medición. Sin línea base no es posible demostrar valor al cierre: solo afirmarlo.

*Ejemplos de línea base: la tasa de abandono mensual es de 3.1 % según el reporte comercial de marzo; el quiebre de stock afecta al 12 % de los SKU según el inventario del último trimestre; el tiempo de elaboración del reporte de ventas es de dos días por cierre mensual.*
### <a name="_toc239449096"></a>**1.5. Objetivos del proyecto**
De dos a tres objetivos formulados como SMART, que respondan directamente al problema y sean verificables al cierre.

*Objetivo general de ejemplo: desarrollar un modelo que estime la probabilidad de abandono de un cliente en el mes siguiente, con un AUC superior a 0.80 sobre el conjunto de prueba. Objetivos específicos de ejemplo: identificar los tres factores de mayor influencia en el abandono; construir un tablero que permita al área comercial monitorear la cartera en riesgo.*
### <a name="_toc239449097"></a>**1.6. Alcance y limitaciones**
Qué incluye y qué queda expresamente fuera. Declare las limitaciones de los datos disponibles y del entorno de ejecución.
### <a name="_toc239449098"></a>**1.7. Justificación del proyecto como problema de Big Data**
Argumente con evidencia, no solo con definiciones. Precise cuáles de las cinco V están realmente presentes y cuáles no, y responda de forma explícita a la pregunta central:

**¿Los datos caben y rinden en una sola máquina, hoy y cuando crezcan?**

Sustente la respuesta con la medición de la subsección 3.7. Es aceptable —y se valora— que un equipo concluya que su volumen actual no exige procesamiento distribuido, siempre que demuestre en qué punto de crecimiento dejaría de bastar. Lo que no se acepta es afirmar que se trata de Big Data solo porque se usó Spark.
## <a name="_toc239449099"></a>**2. Arquitectura de la solución**
*Las herramientas cambian; la arquitectura permanece. Esta sección evalúa el diseño, no el catálogo de tecnologías utilizadas.*
### <a name="_toc239449100"></a>**2.1. Arquitectura propuesta**
Diagrama de alto nivel que muestre el recorrido completo del dato: fuentes, ingesta, zonas de almacenamiento, procesamiento, capa de consumo y visualización. El diagrama debe corresponder a lo efectivamente implementado; si difiere de lo planificado, explique por qué cambió.

*Flujo de referencia: fuentes (CSV, JSON, logs) → ingesta a la zona cruda del data lake → procesamiento para limpieza y transformación → zona procesada en formato columnar → modelado analítico y capa de consumo → tablero de indicadores.*
### <a name="_toc239449101"></a>**2.2. Atributos de calidad del diseño**
Declare qué atributos de calidad persigue su arquitectura y cómo el diseño los consigue. Como mínimo, pronúnciese sobre estos cinco:

- Escalabilidad: qué se hace cuando el volumen crece diez veces.
- Disponibilidad: qué ocurre si falla un componente y qué se pierde.
- Mantenibilidad: qué tan acoplada está una capa a la siguiente y cómo se define el contrato entre ellas.
- Seguridad: cómo se controla el acceso y cómo se protege el dato en reposo y en tránsito.
- Costo: qué decisiones de diseño reducen el consumo de recursos.
### <a name="_toc239449102"></a>**2.3. Prueba de sustitución de componentes**
Responda por escrito: si mañana la empresa decidiera reemplazar el motor de procesamiento por otro, o migrar el almacenamiento a otro sistema, ¿qué partes de su solución tendrían que rehacerse y cuáles seguirían funcionando sin cambios?

*Una arquitectura sólida sobrevive al cambio de herramientas porque las capas se comunican mediante contratos —formatos, esquemas, rutas, interfaces— y no mediante dependencias directas. Si la respuesta a esta prueba es que habría que rehacerlo todo, lo construido no es una arquitectura sino un encadenamiento de herramientas.*
### <a name="_toc239449103"></a>**2.4. Stack tecnológico y equivalencia entre rutas**
Enumere las herramientas con su versión y su función, distinguiendo las que se usaron de las que se evaluaron y descartaron. Presente además el mapeo entre los componentes on-premise y los servicios gestionados equivalentes, y estime el costo mensual de operar la solución en la nube. Los equipos de la ruta B reportan además el costo real incurrido y explican la diferencia respecto de lo estimado.

|**Función**|**Componente on-premise**|**Servicio gestionado equivalente**|
| :- | :-: | :-: |
|Almacenamiento|HDFS|Almacenamiento de objetos|
|Gestión de recursos|YARN|Servicio de clúster gestionado|
|Procesamiento|Spark sobre el clúster propio|Spark gestionado o servicio ETL sin servidor|
|Catálogo de metadatos|Hive Metastore o equivalente|Catálogo de datos gestionado|
|Consulta analítica|Spark SQL|Motor de consulta sobre el lago|

Complete con una consideración de eficiencia y sostenibilidad: qué decisiones de diseño reducen el consumo de recursos —particionado que evita lecturas innecesarias, formatos comprimidos, apagado de recursos ociosos, dimensionamiento ajustado a la carga real— y qué impacto tendrían sobre el costo y la huella energética.
## <a name="_toc239449104"></a>**3. Implementación del pipeline de datos**
*Incluya fragmentos de código relevantes, no el código completo: el código íntegro va al repositorio.*
### <a name="_toc239449105"></a>**3.1. Fuentes de datos y ficha de procedencia**
Para cada fuente complete la ficha siguiente. Sin ella el informe no se recibe.

|**Nombre del conjunto**||
| :- | :- |
|**Origen**|☐ Cedido por la empresa (adjuntar constancia)     ☐ Fuente pública institucional|
|**Entidad publicadora**||
|**Enlace o medio de entrega**||
|**Fecha de obtención**||
|**Licencia o condiciones de uso**||
|**Período cubierto y número de registros**||
|**Tamaño en disco y formato**||

Acompañe la ficha con el diccionario de las columnas relevantes de cada fuente.
### <a name="_toc239449106"></a>**3.2. Ingesta y organización del data lake**
Explique cómo se cargaron los datos y cómo organizó las zonas de almacenamiento. Documente la estructura de directorios y la convención de nombres adoptada.
### <a name="_toc239449107"></a>**3.3. Procesamiento y limpieza**
Detalle las transformaciones aplicadas para pasar de datos crudos a datos analíticos:

- Carga en DataFrames y verificación del esquema inferido frente al esperado.
- Tratamiento de valores nulos, duplicados y atípicos, con el criterio que justificó cada decisión.
- Corrección de tipos de datos y normalización de formatos, en particular fechas y categorías.
- Ingeniería de características: nuevas columnas derivadas y su razón de ser.
- Integración de las fuentes mediante uniones, indicando la clave utilizada y cómo se resolvieron los registros sin correspondencia.
### <a name="_toc239449108"></a>**3.4. Control de calidad de los datos**
Declare las reglas de calidad aplicadas y el resultado de su verificación: registros rechazados, porcentaje de completitud por campo crítico y comprobaciones de rango o coherencia. Esta es la evidencia de la V de veracidad.
### <a name="_toc239449109"></a>**3.5. Almacenamiento de datos procesados**
Indique dónde y en qué formato se guardaron los datos limpios, con el criterio de particionado elegido, y justifique el uso de un formato columnar frente a los formatos de intercambio.
### <a name="_toc239449110"></a>**3.6. Optimización del rendimiento**
Presente al menos una optimización aplicada y medida, con tiempos de ejecución antes y después y la explicación de por qué funcionó. Puede tratarse de caché, particionado, difusión de tablas pequeñas u otra técnica trabajada en el curso.
### <a name="_toc239449111"></a>**3.7. Prueba de escalabilidad**
Replique su conjunto real a ⟨10 y 100 veces⟩ su tamaño y ejecute el pipeline completo sobre cada réplica. Reporte los tiempos y el consumo de recursos en una tabla, y responda: ¿el crecimiento del tiempo es proporcional al del volumen o se degrada antes? ¿En qué punto una sola máquina dejaría de alcanzar?

*Los datos replicados sirven exclusivamente para medir el comportamiento del pipeline. No se usan en el análisis exploratorio, ni en el entrenamiento del modelo, ni en ninguna conclusión de negocio.*
### <a name="_toc239449112"></a>**3.8. Seguridad de la plataforma**
Describa las medidas de integridad y confidencialidad aplicadas o previstas: control de acceso, cifrado en reposo y en tránsito, y gestión de credenciales. Los equipos de la ruta B documentan la configuración real de permisos y el manejo de sus claves; los de la ruta A describen cómo se implementarían en un entorno productivo.
## <a name="_toc239449113"></a>**4. Análisis, modelado y capa de consumo**
*Las subsecciones 4.1 y 4.2 forman parte del hito de la Semana 7. Las subsecciones 4.3 y 4.4 se desarrollan para el hito final.*
### <a name="_toc239449114"></a>**4.1. Análisis exploratorio de datos**
Presente los hallazgos del análisis sobre los datos limpios, con al menos tres visualizaciones acompañadas de su interpretación. Cada gráfico debe responder a una pregunta; los gráficos que no sostienen ninguna afirmación sobran.
### <a name="_toc239449115"></a>**4.2. Modelo base**
Entrene un primer modelo pertinente al objetivo y evalúelo con la métrica adecuada al tipo de problema. Declare esa métrica como línea base técnica y señale qué mejoras intentará en la segunda mitad del semestre. Un modelo base sencillo y bien evaluado vale más que un modelo complejo sin evaluación.
### <a name="_toc239449116"></a>**4.3. Modelo definitivo, selección y evaluación**
Justifique el modelo final frente a al menos una alternativa descartada y documente la preparación de datos, la partición entre entrenamiento y prueba y el ajuste de hiperparámetros. Reporte las métricas e interprete cada una en términos del negocio; la interpretación es lo que se evalúa, no el valor numérico. Contraste el resultado con la línea base técnica declarada en la Semana 7.

*Un modelo con 85 % de exactitud sobre una población donde solo el 5 % abandona puede ser peor que inútil. Explique qué significa cada error para la organización: qué cuesta un falso positivo, qué cuesta un falso negativo, y cuál de los dos prefiere la operación.*
### <a name="_toc239449117"></a>**4.4. Modelo dimensional y capa de consumo**
Diseñe la capa que consumirá el negocio: modelo dimensional con su tabla de hechos, sus dimensiones y la granularidad declarada, más un tablero con ⟨tres a cinco⟩ indicadores derivados de los objetivos de la sección 1. Cada indicador debe tener definición, fórmula, frecuencia de actualización y responsable de la decisión asociada.

*Un tablero no es un conjunto de gráficos atractivos: es el instrumento con el que alguien toma una decisión periódica. Si no puede nombrar quién mira cada indicador y qué hace cuando se mueve, el indicador sobra.*
## <a name="_toc239449118"></a>**5. Ética, privacidad y gobierno de datos**
### <a name="_toc239449119"></a>**5.1. Datos sensibles y protección aplicada**
Identifique qué datos personales o sensibles contiene su conjunto. Describa y evidencie la técnica de protección aplicada —anonimización, seudonimización, enmascaramiento o hashing— y explique qué riesgo de reidentificación permanece después de aplicarla.
### <a name="_toc239449120"></a>**5.2. Linaje y gobierno del dato**
Documente la trazabilidad del dato desde su origen hasta el indicador final: quién es el responsable de cada conjunto, qué transformaciones lo modificaron y cómo se auditaría un valor concreto del tablero hasta su registro de origen.
### <a name="_toc239449121"></a>**5.3. Sesgos y consecuencias del modelo**
Analice qué sesgos puede contener el modelo, a quiénes podrían perjudicar y qué grupos quedan sub-representados en los datos de entrenamiento. Indique qué salvaguarda propondría antes de un uso real.

*Pregunta guía: si esta solución se pusiera en producción mañana y se equivocara sistemáticamente, ¿quién sería el perjudicado y quién respondería por ello?*
### <a name="_toc239449122"></a>**5.4. Marco normativo aplicable**
Identifique la normativa que rige el tratamiento de estos datos. Como mínimo, la Ley N.º 29733 de Protección de Datos Personales del Perú y su reglamento; cuando corresponda, referencias internacionales como el RGPD europeo. No basta citar la norma: indique qué obligación concreta le aplica a su proyecto y cómo la cumple.
### <a name="_toc239449123"></a>**5.5. Aporte al desarrollo sostenible de la región**
Explique de qué manera los hallazgos pueden aportar al desarrollo de la empresa, de su sector y de la región. Sea concreto y evite las afirmaciones genéricas sobre transformación digital.
## <a name="_toc239449124"></a>**6. Valor generado, conclusiones y recomendaciones**
*Esta es la sección que decide si el proyecto aportó valor o se quedó en el uso de tecnología. Es también la que más pesa en la medición final.*
### <a name="_toc239449125"></a>**6.1. Trazabilidad del valor**
Complete una fila por cada recomendación. Una recomendación que no pueda llenar todas las columnas todavía no está lista.

|**Objetivo**|**Hallazgo del análisis**|**Decisión propuesta**|**Responsable en la empresa**|**Efecto estimado sobre la línea base**|
| :- | :-: | :-: | :-: | :-: |
||||||
||||||
||||||

### <a name="_toc239449126"></a>**6.2. Conclusiones**
Responda uno por uno a los objetivos de la subsección 1.5, indicando si se cumplieron y con qué evidencia. Declare también lo que no se logró y por qué; un objetivo no alcanzado con un análisis honesto de la causa vale más que una afirmación de éxito sin respaldo.
### <a name="_toc239449127"></a>**6.3. Recomendaciones de negocio**
Desarrolle en prosa las recomendaciones de la tabla anterior. Cada una debe indicar qué hacer, sobre qué segmento, con qué resultado esperado y a partir de qué evidencia del análisis.

|**Formulación insuficiente**|**Formulación adecuada**|
| :- | :- |
|*«La empresa debe mejorar su estrategia de marketing.»*|*«Lanzar una campaña de retención con 20 % de descuento dirigida a clientes de 25 a 35 años sin compras en los últimos 60 días, segmento que el modelo identifica con 90 % de probabilidad de abandono y que concentra el 31 % de la facturación en riesgo. Responsable: jefatura comercial. Efecto estimado: reducir la tasa de abandono mensual de 3.1 % a 2.4 %.»*|

### <a name="_toc239449128"></a>**6.4. Trabajo futuro**
Señale qué haría a continuación con recursos adicionales: nuevas fuentes, modelos alternativos, automatización del pipeline o puesta en producción. Sea específico sobre qué problema resolvería cada mejora.
## <a name="_toc239449129"></a>**7. Anexos**
- Enlace al repositorio, con README que permita reproducir la solución desde cero: requisitos del entorno, pasos de instalación, orden de ejecución de los scripts y datos de muestra.
- Constancia de autorización de la empresa, cuando los datos hayan sido cedidos.
- Declaración de uso de herramientas de IA generativa, según el formato del Anexo A.
- Evidencias de la ejecución: capturas o registro de las corridas relevantes, de las mediciones de rendimiento y de la prueba de escalabilidad.
- Referencias bibliográficas y fuentes de datos, en normas APA 7.ª edición, incluida la licencia de uso de cada conjunto.


# <a name="_toc239449130"></a>**Anexo A. Declaración de uso de herramientas de IA generativa**
El uso de herramientas de inteligencia artificial generativa está permitido en este curso como apoyo al trabajo, y debe declararse. Lo que se evalúa es la comprensión y la responsabilidad del equipo sobre el resultado: todo contenido asistido por estas herramientas debe haber sido verificado por los autores, quienes responden por su exactitud. Tenga presente que la sustentación individual pesa más que el informe precisamente porque mide lo que cada estudiante comprende, con independencia de cómo se haya redactado el documento. La omisión de esta declaración se trata como falta a la integridad académica conforme al reglamento de la universidad.

|**Herramienta**|**Uso que se le dio**|**Sección del informe**|**Verificación realizada**|
| :- | :-: | :-: | :-: |
|||||
|||||
|||||
|||||

Los integrantes declaran que el contenido de este informe fue revisado y verificado por el equipo, y asumen la responsabilidad académica correspondiente.

\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_          \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_          \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_          \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_
# <a name="_toc239449131"></a>**Anexo B. Lista de verificación previa a la entrega**
Revise estos puntos antes de subir el informe. Los cuatro primeros son requisitos de admisibilidad.

- El repositorio es accesible y el README permite reproducir la solución desde cero.
- Existe evidencia de al menos una corrida completa del pipeline.
- La ficha de procedencia está completa para cada fuente, con su entidad publicadora o la constancia de la empresa.
- La declaración del Anexo A está completa y firmada por todos los integrantes.
- La empresa es real y está identificada; no hay datos sintéticos en el análisis ni en el modelo.
- La línea base del negocio está declarada con su fuente y su fecha.
- La prueba de escalabilidad está ejecutada y reportada con tiempos.
- La prueba de sustitución de componentes está respondida por escrito.
- Cada recomendación completa las cinco columnas de la tabla de trazabilidad del valor.
- El texto guía en cursiva de la plantilla fue eliminado en su totalidad.
- Los diagramas corresponden a lo implementado y no a la versión inicial del diseño.
- Las métricas del informe coinciden con las que produce el código del repositorio.
- Ningún dato personal identificable aparece en el informe, en las capturas ni en el repositorio.

# <a name="_toc239449132"></a>**Referencias sugeridas**
Chambers, B., y Zaharia, M. (2018). Spark: The Definitive Guide: Big Data Processing Made Simple. O'Reilly Media.

White, T. (2015). Hadoop: The Definitive Guide (4.ª ed.). O'Reilly Media.

Kleppmann, M. (2017). Designing Data-Intensive Applications. O'Reilly Media.

Géron, A. (2023). Hands-On Machine Learning with Scikit-Learn, Keras & TensorFlow (3.ª ed.). O'Reilly Media.

James, G., Witten, D., Hastie, T., y Tibshirani, R. (2021). An Introduction to Statistical Learning (2.ª ed.). Springer.

Congreso de la República del Perú. (2011). Ley N.º 29733, Ley de Protección de Datos Personales.
Plantilla de Proyecto · Big Data y Analítica de Datos · UPAO · 2026-20 · Página 1
