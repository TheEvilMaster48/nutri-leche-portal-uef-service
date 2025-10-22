# 🥛 Nutri Leche Portal - Flutter & Spring Boot

**Portal de Empleados para Nutri Leche Ecuador**, desarrollado en **Flutter/Dart (frontend)** y **Spring Boot (backend)** con integración a **SQL Server 2022 (Docker)**.

El sistema permite a los empleados acceder a información interna, descargar documentos institucionales, recibir notificaciones en tiempo real mediante WebSockets (STOMP), y mantener un perfil personal con autenticación local.

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