# Dockerfile qui fonctionne à coup sûr
FROM maven:3.9.6-eclipse-temurin-22 AS build
WORKDIR /app
# Copier les fichiers Maven d'abord (cache des dépendances)
COPY pom.xml .
RUN mvn dependency:go-offline
# Copier le code source
COPY src ./src
# Build l'application
RUN mvn clean package -DskipTests
# Runtime
FROM eclipse-temurin:22-jre-jammy
WORKDIR /app
# Copier le JAR depuis l'étape build
COPY --from=build /app/target/*.jar app.jar
# Utilisateur non-root
RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]