# 🧩 Configuración local de Java 17 solo para Nutri Leche Portal
$env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-17.0.16.8-hotspot"
$env:PATH = "$env:JAVA_HOME\bin;" + $env:PATH

Write-Host "✅ Java configurado para Nutri Leche Portal (usando JDK 17)" -ForegroundColor Green
java -version
