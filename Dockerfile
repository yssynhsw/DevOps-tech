# Dockerfile optimisé
FROM eclipse-temurin:21-jdk-alpine AS builder
# Étape de build séparée pour réduire la taille de l'image finale
WORKDIR /app
COPY target/student-management-*.jar app.jar
# Étape d'exécution (plus légère)
FROM eclipse-temurin:17-jre-alpine
# Variables d'environnement
ENV JAVA_OPTS="-Xmx512m -Xms256m"
ENV SPRING_PROFILES_ACTIVE="docker"
# Créer un utilisateur non-root
RUN addgroup -S spring && adduser -S spring -G spring
# Répertoire de travail
WORKDIR /app
# Copier le jar depuis l'étape de build
COPY --from=builder /app/app.jar app.jar
# Changer les permissions
RUN chown -R spring:spring /app
USER spring:spring
# Port exposé
EXPOSE 8080
# Health check (pour vérifier si l'application est en bonne santé)
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1
# Point d'entrée avec variables d'environnement
ENTRYPOINT ["sh", "-c", "java ${JAVA_OPTS} -jar /app/app.jar"]
