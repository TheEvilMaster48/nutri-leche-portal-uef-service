# 🥛 Nutri Leche Portal - Flutter & Spring Boot

## 📖 Descripción General

El **Portal de Empleados de Nutri Leche Ecuador** es una plataforma digital integral diseñada para optimizar la comunicación interna, la gestión documental y el acceso a información corporativa de los colaboradores de la empresa.  
Desarrollada con **Flutter/Dart (frontend)** y **Spring Boot (backend)**, la aplicación ofrece un entorno moderno, rápido y seguro, totalmente adaptable a diferentes dispositivos (Web y Android).

El sistema se integra con una base de datos **SQL Server 2022** desplegada mediante **Docker**, lo que garantiza portabilidad, estabilidad y facilidad de mantenimiento.  
Además, incorpora **WebSockets con el protocolo STOMP** para el envío y recepción de notificaciones en tiempo real, permitiendo una comunicación fluida entre el servidor y los usuarios.

El portal está orientado a mejorar la experiencia del empleado, simplificar procesos administrativos, centralizar recursos y fomentar una cultura organizacional digital, segura y colaborativa.

---

## 🎯 Objetivo General

Desarrollar un **sistema integral de gestión interna para empleados de Nutri Leche Ecuador**, que permita centralizar información corporativa, optimizar la comunicación interna, y facilitar el acceso a documentos, notificaciones y eventos en tiempo real, a través de una aplicación multiplataforma moderna y segura.

---

## 🎯 Objetivos Específicos

1. **Digitalizar la información interna** de la empresa mediante un portal accesible desde web o dispositivos móviles.  
2. **Implementar un sistema de autenticación local**, seguro y persistente con almacenamiento en caché de usuarios.  
3. **Permitir la gestión de eventos empresariales**, con soporte para archivos, descripciones y categorías dinámicas.  
4. **Habilitar un canal de comunicación en tiempo real** entre empleados y departamentos, utilizando WebSocket (STOMP).  
5. **Integrar un módulo de recursos corporativos**, que permita la descarga y edición de documentos en formato PDF.  
6. **Brindar un perfil de usuario personalizable**, con visualización de datos, área asignada, módulos habilitados e imagen de perfil dinámica.  
7. **Optimizar la infraestructura de despliegue**, utilizando Docker para la base de datos y configuración multiambiente entre desarrollo y producción.  

---

## 📦 Alcance Funcional del Sistema

El **Portal de Empleados Nutri Leche Ecuador** está compuesto por varios módulos principales que trabajan de forma interconectada:

| Módulo | Descripción | Tecnologías principales |
|--------|--------------|--------------------------|
| **Autenticación y Sesiones** | Permite el inicio de sesión, registro y persistencia local del usuario autenticado. | Flutter, SharedPreferences |
| **Perfil de Usuario** | Muestra la información personal, área y módulos del empleado, incluyendo foto de perfil dinámica cargada por cédula. | Flutter, Image.network |
| **Eventos Corporativos** | Gestiona eventos en tiempo real enviados desde el backend a través de STOMP WebSocket. | Spring Boot, Flutter, WebSocket |
| **Recursos Institucionales** | Permite descargar, visualizar y editar documentos internos en PDF con encabezado oficial y logo. | Flutter PDF & Printing |
| **Notificaciones** | Sistema de alertas automáticas para todas las acciones realizadas dentro de la app. | STOMP, NotificationBanner |
| **Chat Interno** | Comunicación privada entre empleados con estructura tipo mensajería instantánea. | Flutter, Provider, Local JSON |
| **Configuración y Ajustes** | Idioma, tema visual, y preferencias de usuario (almacenadas localmente). | Flutter, SharedPreferences |

---

## 🧱 Fundamentación Técnica

El sistema se basa en una **arquitectura cliente-servidor desacoplada**, donde el frontend (Flutter) se comunica con el backend (Spring Boot) mediante peticiones REST y canales WebSocket.  
Esta arquitectura permite:

- Escalabilidad horizontal mediante contenedores Docker.  
- Separación total de lógica de presentación y lógica de negocio.  
- Compatibilidad multiplataforma (Web, Android).  
- Integración directa con servicios externos (imágenes, APIs, almacenamiento local).  
- Comunicación bidireccional en tiempo real (WebSocket-STOMP).  

---

## 💡 Beneficios del Sistema

- 🌐 **Accesibilidad:** Disponible en navegador y dispositivos Android.  
- ⚡ **Rendimiento:** Flutter ofrece interfaces fluidas y nativas con una sola base de código.  
- 🔒 **Seguridad:** Autenticación controlada y cifrada en backend con validación de usuarios.  
- 🧩 **Modularidad:** Estructura escalable con servicios reutilizables (`auth_service`, `evento_service`, `notificacion_service`, etc.).  
- 🕒 **Tiempo real:** Integración con STOMP para recibir eventos y notificaciones instantáneamente.  
- 📄 **Documentación corporativa:** Generación de PDFs institucionales con logo, encabezado y metadatos automáticos.  
- 🧱 **Infraestructura moderna:** Base de datos SQL Server en contenedor Docker, fácilmente desplegable y mantenible.  

---

## 🧾 Resumen General del Proyecto

El **Portal de Empleados Nutri Leche Ecuador** constituye una herramienta digital estratégica que moderniza la comunicación y la gestión interna empresarial.  
Su diseño modular y su implementación técnica combinan:

- **Frontend Flutter:** interfaz moderna, reactiva y responsiva.  
- **Backend Spring Boot:** lógica de negocio, persistencia y mensajería en tiempo real.  
- **Base de datos SQL Server (Docker):** almacenamiento estructurado, confiable y portable.  
- **Canales STOMP/WebSocket:** interacción instantánea con usuarios activos.  

Con esta solución, la empresa logra **mejorar la eficiencia organizacional**, **reducir el uso de papel**, **aumentar la transparencia de información**, y **centralizar procesos administrativos**, aportando valor tangible tanto al personal operativo como a la gestión ejecutiva.

---

## 🧠 Arquitectura General

📦 nutri-leche-portal-main
│
├── lib/
│ ├── core/
│ │ ├── app_localizations.dart
│ │ ├── locale_provider.dart
│ │ ├── notification_banner.dart
│ │ └── realtime_manager.dart
│ ├── models/
│ │ ├── chat.dart
│ │ ├── evento.dart
│ │ ├── mensaje.dart
│ │ ├── notificacion.dart
│ │ ├── pais.dart
│ │ ├── recurso.dart
│ │ └── usuario.dart
│ ├── screens/
│ │ ├── acerca_screen.dart
│ │ ├── ayuda_screen.dart
│ │ ├── chat.dart
│ │ ├── chat_detalle.dart
│ │ ├── configuracion_screen.dart
│ │ ├── crear_evento.dart
│ │ ├── crear_publicacion.dart
│ │ ├── editar_perfil.dart
│ │ ├── eventos.dart
│ │ ├── login.dart
│ │ ├── menu.dart
│ │ ├── noticias.dart
│ │ ├── notificaciones.dart
│ │ ├── nuevo_chat.dart
│ │ ├── perfil.dart
│ │ ├── recursos.dart
│ │ └── registro.dart
│ ├── services/
│ │ ├── validators/
│ │ │ ├── empleado_validator.dart
│ │ │ └── telefono_validator.dart
│ │ ├── auth_service.dart
│ │ ├── chat_service.dart
│ │ ├── evento_service.dart
│ │ ├── global_notifier.dart
│ │ ├── language_service.dart
│ │ ├── notificacion_service.dart
│ │ ├── recurso_service.dart
│ │ ├── usuario_service.dart
│ │ └── realtime_service.dart
│ ├── widget/
│ │ └── menuItem.dart
│ └── main.dart
│
├── assets/icono/nutrileche.png
├── pubspec.yaml
└── README.md


---

## ⚙️ Tecnologías Utilizadas

### 🖥️ Frontend (Flutter)
- **Framework:** Flutter 3.35.6  
- **Lenguaje:** Dart 3.9.2  
- **Gestión de estado:** `provider`
- **Almacenamiento local:** `shared_preferences`
- **Internacionalización:** `intl`, `flutter_localizations`
- **Documentos PDF:** `pdf`, `printing`
- **Imágenes y archivos:** `image_picker`, `file_picker`
- **Comunicación en tiempo real:** `stomp_dart_client`
- **Compatibilidad:** Web, Android, Edge

### ⚙️ Backend (Spring Boot)
- **Framework:** Spring Boot 3.x
- **Lenguaje:** Java 17+
- **Seguridad:** Spring Security + JWT
- **Mensajería:** WebSocket STOMP (`/topic/eventos`)
- **Base de datos:** SQL Server 2022 (Docker)
- **Persistencia:** JPA / Hibernate
- **API REST:** JSON UTF-8

### 🗄️ Base de Datos (Docker + SQL Server)
- Imagen: `mcr.microsoft.com/mssql/server:2022-latest`
- Puerto: `8593`
- Usuario: `UEFServive`
- Password: `QAS`

---

## 🚀 Instalación y Configuración

### 1️⃣ Requisitos Previos

| Componente | Versión mínima | Descripción |
|-------------|----------------|--------------|
| Flutter SDK | 3.35.6 | Framework UI |
| Dart SDK | 3.9.2 | Lenguaje base |
| Java JDK | 17+ | Backend |
| Maven | 3.9+ | Build y dependencias |
| Docker | 25+ | Contenedor SQL Server |
| Android Studio / VS Code | — | IDEs recomendados |

---

### 2️⃣ Instalar dependencias Flutter

```powershell
flutter clean
flutter pub get

---

3️⃣ Ejecutar Backend (Spring Boot)
mvn spring-boot:run

---

4️⃣ Crear contenedor SQL Server (Docker)

Ejemplo
docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=FfSantdmm,44" `
  -p 8593:1433 `
  -v C:/Base/Data:/var/opt/mssql/data `
  -v C:/Base/Log:/var/opt/mssql/log `
  -v C:/Base/Secrets:/var/opt/mssql/secrets `
  --name sql2022dk `
  -d mcr.microsoft.com/mssql/server:2022-latest

---

5️⃣ Ejecutar Frontend en navegador Edge (sin CORS)
flutter run -d edge --web-browser-flag="--disable-web-security" --web-browser-flag="--user-data-dir=C:\Temp\EdgeDev"

En Android
flutter run -d android

---

🧩 Funcionalidades por Módulo

---

🔐 Autenticación
Registro de usuarios con validaciones.
Login persistente mediante SharedPreferences.
Identificación por cédula o código de empleado.

🟣 Eventos
Crear, editar y eliminar eventos.
Recepción de eventos en tiempo real desde el backend vía STOMP WebSocket.
Visualización agrupada por categoría o área.

🔔 Notificaciones
Se generan automáticamente por cada acción.
Sincronizadas entre frontend y backend.
Indicadores visuales de notificaciones no leídas.

💬 Chat
Mensajería en tiempo real entre empleados.
Lista de contactos y conversaciones activas.
Estilo visual tipo WhatsApp.

📄 Recursos
Descarga y edición de documentos PDF institucionales.
Encabezado oficial con logo Nutri Leche.
Control de permisos según área o módulo (RRHH, Producción, Bodega, Ventas).

👤 Perfil
Visualización completa de datos personales.
Foto de perfil dinámica (por cédula)
Edición de campos permitidos (nombre, cargo, área, teléfono).